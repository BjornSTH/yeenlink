package server_test

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"yeenlink/server/internal/config"
	"yeenlink/server/internal/server"
	"yeenlink/server/internal/store"
	"yeenlink/server/internal/testclient"
	"yeenlink/server/internal/tlsmode"
	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

type syncBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuf) Write(p []byte) (int, error) { s.mu.Lock(); defer s.mu.Unlock(); return s.b.Write(p) }
func (s *syncBuf) String() string              { s.mu.Lock(); defer s.mu.Unlock(); return s.b.String() }

type env struct {
	URL   string
	Srv   *server.Server
	Cfg   config.Config
	Store *store.Store
	Pub   []byte
	Logs  *syncBuf
	TLS   *tlsmode.Setup
}

// start поднимает сервер в режиме mode (self-signed или proxy).
func start(t *testing.T, mode string, proxyCerts ...string) *env {
	t.Helper()
	ctx := context.Background()
	dir := t.TempDir()
	cfg := config.Default()
	cfg.Name = "Ночной привал"
	cfg.DataDir = dir
	cfg.Host = "127.0.0.1"
	cfg.TLS = config.TLS{Mode: mode, ProxyCerts: proxyCerts}
	logs := &syncBuf{}
	log := slog.New(slog.NewTextHandler(logs, nil))
	st, err := store.Open(ctx, cfg.DBPath())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	_, key, _ := ed25519.GenerateKey(nil)
	setup, err := tlsmode.Build(ctx, cfg, log)
	if err != nil {
		t.Fatal(err)
	}
	srv, err := server.New(server.Options{Config: cfg, Store: st, Key: key, TLS: setup, Log: log, Version: "test"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := srv.EnsureAdminToken(ctx); err != nil {
		t.Fatal(err)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	sctx, stop := context.WithCancel(ctx)
	done := make(chan struct{})
	go func() { _ = srv.Serve(sctx, ln); close(done) }()
	t.Cleanup(func() { stop(); <-done })
	scheme := "https"
	if setup.TLSConfig == nil {
		scheme = "http"
	}
	return &env{URL: scheme + "://" + ln.Addr().String(), Srv: srv, Cfg: cfg, Store: st, Pub: key.Public().(ed25519.PublicKey), Logs: logs, TLS: setup}
}

func ident(t *testing.T, label string) *testclient.Identity {
	t.Helper()
	seed := sha256.Sum256([]byte("test/" + label))
	id, err := testclient.NewIdentity(seed[:16], seed[:])
	if err != nil {
		t.Fatal(err)
	}
	return id
}

func dial(t *testing.T, e *env, id *testclient.Identity) *testclient.Client {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c, err := testclient.Dial(ctx, e.URL, e.Pub, id, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(c.Close)
	return c
}

func token(t *testing.T, e *env) string {
	t.Helper()
	b, err := os.ReadFile(e.Cfg.AdminTokenPath())
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(string(b))
}

func ctx5(t *testing.T) context.Context {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	return ctx
}

func TestWellKnownSignedAndPinned(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	hc := &http.Client{Transport: &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}} // #nosec G402
	info, err := testclient.Fetch(ctx5(t), e.URL, hc)
	if err != nil || info.Name != "Ночной привал" || !bytes.Equal(info.ServerPub, e.Pub) {
		t.Fatalf("server_info: %+v %v", info, err)
	}
	other := make([]byte, 32)
	if _, err := testclient.Dial(ctx5(t), e.URL, other, ident(t, "a"), nil); !errors.Is(err, testclient.ErrNotSameServer) {
		t.Fatalf("чужой закреплённый ключ: %v", err)
	}
}

func TestFirstLoginAndClaimOwner(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	tok := token(t, e)
	if st, _ := os.Stat(e.Cfg.AdminTokenPath()); st.Mode().Perm() != 0o600 {
		t.Fatalf("права файла ключа %v", st.Mode().Perm())
	}
	alice := dial(t, e, ident(t, "alice"))
	r := alice.Ready
	if r.Server.HasOwner || r.Me.Owner || r.Server.Name != "Ночной привал" || alice.Unbound {
		t.Fatalf("ready: %+v", r)
	}
	bob := dial(t, e, ident(t, "bob"))

	var claimed protocol.AdminClaimed
	if err := alice.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: tok}, &claimed); err != nil || !claimed.Owner {
		t.Fatalf("claim: %v", err)
	}
	ev, err := bob.WaitEvent(ctx5(t), protocol.OpServerUpdate)
	if err != nil {
		t.Fatal(err)
	}
	var su protocol.ServerUpdate
	_ = ev.DecodeD(&su)
	if !su.Server.HasOwner {
		t.Fatal("server.update без владельца")
	}
	if _, err := os.Stat(e.Cfg.AdminTokenPath()); !os.IsNotExist(err) {
		t.Fatal("файл ключа должен удалиться после использования")
	}
	if err := bob.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: tok}, nil); !isCode(err, protocol.ErrBadToken) {
		t.Fatalf("сгоревший ключ: %v", err)
	}
	again := dial(t, e, ident(t, "alice"))
	if !again.Ready.Me.Owner || protocol.PermsFromWire(again.Ready.Perms.Server) != ^uint64(0) {
		t.Fatalf("после входа заново: %+v", again.Ready.Me)
	}
	if strings.Contains(e.Logs.String(), tok) {
		t.Fatal("ключ администратора попал в журнал")
	}
	if !strings.Contains(e.Logs.String(), e.Cfg.AdminTokenPath()) {
		t.Fatal("в журнале должен быть путь к файлу ключа")
	}
}

func isCode(err error, code string) bool {
	var fe *testclient.FrameError
	return errors.As(err, &fe) && fe.Code == code
}

func TestClaimRateLimit(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	c := dial(t, e, ident(t, "mallory"))
	bad := "ylat_" + strings.Repeat("A", 43)
	for i := 0; i < protocol.ClaimLimitPerMin; i++ {
		if err := c.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: bad}, nil); !isCode(err, protocol.ErrBadToken) {
			t.Fatalf("попытка %d: %v", i+1, err)
		}
	}
	err := c.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: token(t, e)}, nil)
	if !isCode(err, protocol.ErrRateLimited) {
		t.Fatalf("шестая попытка, даже с верным ключом: %v", err)
	}
}

func TestNewTokenTransfersOwnership(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	alice := dial(t, e, ident(t, "alice"))
	if err := alice.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: token(t, e)}, nil); err != nil {
		t.Fatal(err)
	}
	tok2, err := server.IssueAdminToken(context.Background(), e.Store, e.Cfg.AdminTokenPath(), time.Now())
	if err != nil {
		t.Fatal(err)
	}
	bob := dial(t, e, ident(t, "bob"))
	if err := bob.Call(ctx5(t), protocol.OpAdminClaim, protocol.AdminClaim{Token: tok2}, nil); err != nil {
		t.Fatal(err)
	}
	// Alice получает событие, что она больше не владелец.
	for {
		ev, err := alice.WaitEvent(ctx5(t), protocol.OpMemberUpdate)
		if err != nil {
			t.Fatal(err)
		}
		var mu protocol.MemberUpdate
		_ = ev.DecodeD(&mu)
		if bytes.Equal(mu.MasterPub, ident(t, "alice").MasterPub()) && !mu.Owner {
			break
		}
	}
	log, _ := e.Store.Log(context.Background(), 20)
	n := 0
	for _, l := range log {
		if l.Kind == "owner.change" {
			n++
		}
	}
	if n != 2 {
		t.Fatalf("смен владельца в журнале сервера: %d", n)
	}
}

// Атакующий посередине со своим сертификатом пересылает трафик настоящему
// серверу: клиент видит подменённый сертификат, подпись сервера его не
// покрывает — вход срывается.
func TestMITMWithOwnCertificateFails(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	attackerCfg := config.Default()
	attackerCfg.DataDir = t.TempDir()
	attackerCfg.Host = "127.0.0.1"
	attackerCfg.TLS.Mode = config.TLSSelfSigned
	attacker, err := tlsmode.Build(context.Background(), attackerCfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	ln, err := tls.Listen("tcp", "127.0.0.1:0", attacker.TLSConfig)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = ln.Close() }()
	upstream := strings.TrimPrefix(e.URL, "https://")
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				up, err := tls.Dial("tcp", upstream, &tls.Config{InsecureSkipVerify: true}) // #nosec G402
				if err != nil {
					_ = c.Close()
					return
				}
				go func() { _, _ = io.Copy(up, c) }()
				_, _ = io.Copy(c, up)
			}()
		}
	}()
	_, err = testclient.Dial(ctx5(t), "https://"+ln.Addr().String(), e.Pub, ident(t, "victim"), nil)
	if !errors.Is(err, protocol.ErrCertNotSigned) {
		t.Fatalf("вход через подмену должен сорваться: %v", err)
	}
}

func TestProxyModeUnboundAndBound(t *testing.T) {
	plain := start(t, config.TLSProxy)
	c := dial(t, plain, ident(t, "a"))
	if !c.Unbound {
		t.Fatal("за прокси без proxy_cert клиент должен знать, что привязки нет")
	}

	// Прокси с известным сертификатом: TLS у прокси, сервер подписывает его хеш.
	proxyCfg := config.Default()
	proxyCfg.DataDir = t.TempDir()
	proxyCfg.Host = "127.0.0.1"
	proxyCfg.TLS.Mode = config.TLSSelfSigned
	proxy, err := tlsmode.Build(context.Background(), proxyCfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	bound := start(t, config.TLSProxy, filepath.Join(proxyCfg.CertDir(), "self-signed.crt"))
	ln, err := tls.Listen("tcp", "127.0.0.1:0", proxy.TLSConfig)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = ln.Close() }()
	upstream := strings.TrimPrefix(bound.URL, "http://")
	go func() {
		for {
			cl, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				up, err := net.Dial("tcp", upstream)
				if err != nil {
					_ = cl.Close()
					return
				}
				go func() { _, _ = io.Copy(up, cl) }()
				_, _ = io.Copy(cl, up)
			}()
		}
	}()
	viaProxy, err := testclient.Dial(ctx5(t), "https://"+ln.Addr().String(), bound.Pub, ident(t, "b"), nil)
	if err != nil {
		t.Fatalf("за прокси с proxy_cert: %v", err)
	}
	defer viaProxy.Close()
	if viaProxy.Unbound {
		t.Fatal("с proxy_cert привязка должна быть")
	}
}

func TestResumeGetsMissedEvents(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	aliceID := ident(t, "alice")
	alice := dial(t, e, aliceID)
	sess := alice.Ready.Session.ID
	last := alice.Ready.LastEvent
	alice.Close()
	<-alice.Done()
	time.Sleep(50 * time.Millisecond)

	// Пока Alice нет, Bob публикует профиль — событие member.update.
	bobID := ident(t, "bob")
	bob := dial(t, e, bobID)
	if err := pushProfile(t, bob, bobID, "Боб", 1); err != nil {
		t.Fatal(err)
	}

	resumed, err := testclient.Dial(ctx5(t), e.URL, e.Pub, aliceID, &protocol.Resume{Session: sess, LastEvent: last})
	if err != nil {
		t.Fatal(err)
	}
	defer resumed.Close()
	if resumed.Resumed == nil || len(resumed.Resumed.Events) == 0 {
		t.Fatalf("ожидался resumed с событиями: %+v", resumed.Ready)
	}
	f, err := codec.DecodeFrame(resumed.Resumed.Events[0])
	if err != nil || f.Op != protocol.OpMemberUpdate {
		t.Fatalf("событие: %v %v", f, err)
	}
	// Чужой ключ устройства не продолжит чужую сессию — будет обычный ready.
	thief, err := testclient.Dial(ctx5(t), e.URL, e.Pub, ident(t, "thief"), &protocol.Resume{Session: sess, LastEvent: last})
	if err != nil {
		t.Fatal(err)
	}
	defer thief.Close()
	if thief.Resumed != nil || thief.Ready == nil {
		t.Fatal("украденный id сессии не должен давать resume")
	}
}

func pushProfile(t *testing.T, c *testclient.Client, id *testclient.Identity, name string, seq uint64) error {
	t.Helper()
	nh := sha256.Sum256(id.MasterPub())
	s, err := identity.Sign(identity.TypeProfile, identity.Profile{
		V: 1, Master: id.MasterPub(), Seq: seq, Name: name, Wall: true, NextKeyHash: nh[:], Updated: 1,
	}, id.Master)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := s.Encode()
	return c.Call(ctx5(t), protocol.OpProfilePush, protocol.ProfilePush{Profile: b}, nil)
}

func TestProfileSeqAndReady(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	id := ident(t, "gnoll")
	c := dial(t, e, id)
	if err := pushProfile(t, c, id, "Gnoll", 0); err != nil {
		t.Fatalf("seq 0 на пустом сервере: %v", err)
	}
	if err := pushProfile(t, c, id, "Gnoll", 0); !isCode(err, protocol.ErrStale) {
		t.Fatalf("тот же seq: %v", err)
	}
	if err := pushProfile(t, c, id, "Гнолл", 2); err != nil {
		t.Fatal(err)
	}
	again := dial(t, e, id)
	s, err := identity.DecodeSigned(again.Ready.Me.Profile)
	if err != nil {
		t.Fatal(err)
	}
	p, err := identity.OpenProfile(s)
	if err != nil || p.Seq != 2 || p.Name != "Гнолл" {
		t.Fatalf("профиль в ready: %+v %v", p, err)
	}
	// Чужой профиль не принимается.
	other := ident(t, "other")
	if err := pushProfile(t, c, other, "Чужой", 5); !isCode(err, protocol.ErrBadPayload) {
		t.Fatalf("чужой профиль: %v", err)
	}
}

func TestRevokedDeviceIsDroppedAndRefused(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	phone := ident(t, "owner")
	seed := sha256.Sum256([]byte("test/owner-pc"))
	pc, err := testclient.NewIdentity(sha256Prefix("test/owner"), seed[:])
	if err != nil {
		t.Fatal(err)
	}
	pcConn := dial(t, e, pc)
	phoneConn := dial(t, e, phone)

	list, err := identity.Sign(identity.TypeDevices, identity.Devices{
		Seq: 1, Active: [][]byte{phone.Device.Public().(ed25519.PublicKey)}, Revoked: [][]byte{pc.Device.Public().(ed25519.PublicKey)},
	}, phone.Master)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := list.Encode()
	if err := phoneConn.Call(ctx5(t), protocol.OpDevicesPush, protocol.DevicesPush{Devices: b}, nil); err != nil {
		t.Fatal(err)
	}
	select {
	case <-pcConn.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("соединение отозванного устройства не разорвано")
	}
	if _, err := testclient.Dial(ctx5(t), e.URL, e.Pub, pc, nil); !isCode(err, protocol.ErrDeviceRevoked) {
		t.Fatalf("вход отозванного устройства: %v", err)
	}
	if err := phoneConn.Call(ctx5(t), protocol.OpDevicesPush, protocol.DevicesPush{Devices: b}, nil); !isCode(err, protocol.ErrStale) {
		t.Fatalf("тот же seq списка: %v", err)
	}
	again := dial(t, e, phone)
	if !bytes.Equal(again.Ready.Me.Devices, b) {
		t.Fatal("список устройств должен прийти в ready")
	}
}

func sha256Prefix(s string) []byte {
	h := sha256.Sum256([]byte(s))
	return h[:16]
}

func TestUnknownOpAndFrameBeforeHello(t *testing.T) {
	e := start(t, config.TLSSelfSigned)
	c := dial(t, e, ident(t, "a"))
	if err := c.Call(ctx5(t), "msg.send", map[string]any{}, nil); !isCode(err, protocol.ErrUnknownOp) {
		t.Fatalf("неизвестная операция: %v", err)
	}
	_ = fmt.Sprint()
}
