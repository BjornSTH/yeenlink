// Package server — сервер YeenLink фазы 2: /.well-known/yeenlink, WebSocket
// /ws с входом hello → challenge → auth → ready/resumed, сессии и события для
// resume, ключ администратора, профиль и список устройств (spec/auth.md,
// spec/server.md).
package server

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"yeenlink/server/internal/admintoken"
	"yeenlink/server/internal/config"
	"yeenlink/server/internal/store"
	"yeenlink/server/internal/tlsmode"
	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

// Server — всё состояние работающего сервера.
type Server struct {
	cfg     config.Config
	store   *store.Store
	key     ed25519.PrivateKey
	pub     []byte
	info    []byte // подписанный server_info (CBOR)
	tls     *tlsmode.Setup
	wire    codec.Wire
	log     *slog.Logger
	version string
	now     func() time.Time

	trusted []*net.IPNet

	mu        sync.Mutex
	sessions  map[string]*session // по hex id
	conns     map[*conn]struct{}
	events    []event // кольцо за ResumeWindow
	nextEvent uint64
	claims    *limiter
}

type session struct {
	id         []byte
	master     []byte
	device     []byte
	conn       *conn     // nil — отключён
	detachedAt time.Time // когда отключился
}

type event struct {
	id    uint64
	at    time.Time
	frame []byte // CBOR кадра события
	to    []byte // nil — всем, иначе одному участнику
}

// Options — то, что передаёт ylsrv run (и тесты).
type Options struct {
	Config  config.Config
	Store   *store.Store
	Key     ed25519.PrivateKey
	TLS     *tlsmode.Setup
	Log     *slog.Logger
	Version string
	Now     func() time.Time // по умолчанию time.Now
}

// New собирает сервер и подписывает server_info.
func New(o Options) (*Server, error) {
	if o.Now == nil {
		o.Now = time.Now
	}
	wire, err := codec.ParseWire(o.Config.Codec)
	if err != nil {
		return nil, err
	}
	s := &Server{
		cfg: o.Config, store: o.Store, key: o.Key, tls: o.TLS, wire: wire, log: o.Log,
		version: o.Version, now: o.Now,
		pub:      []byte(o.Key.Public().(ed25519.PublicKey)),
		sessions: map[string]*session{},
		conns:    map[*conn]struct{}{},
		claims:   newLimiter(protocol.ClaimLimitPerMin, time.Minute),
	}
	for _, t := range o.Config.TrustedProxies {
		if !strings.Contains(t, "/") {
			if strings.Contains(t, ":") {
				t += "/128"
			} else {
				t += "/32"
			}
		}
		_, n, err := net.ParseCIDR(t)
		if err != nil {
			return nil, err
		}
		s.trusted = append(s.trusted, n)
	}
	signed, err := identity.Sign(identity.TypeServerInfo, identity.ServerInfo{
		V: 1, ServerPub: s.pub, Name: identity.NormalizeText(o.Config.Name), Version: o.Version,
	}, o.Key)
	if err != nil {
		return nil, err
	}
	if s.info, err = signed.Encode(); err != nil {
		return nil, err
	}
	return s, nil
}

// EnsureAdminToken — если у сервера нет владельца и действующего ключа — создаёт
// ключ, кладёт его в файл 0600 и пишет в журнал только путь (сам ключ
// печатает лишь ylsrv init / admin-token в терминал). true — ключ создан.
func (s *Server) EnsureAdminToken(ctx context.Context) (bool, error) {
	owner, err := s.store.Owner(ctx)
	if err != nil || owner != nil {
		return false, err
	}
	active, err := s.store.HasActiveAdminToken(ctx)
	if err != nil || active {
		return false, err
	}
	if _, err := IssueAdminToken(ctx, s.store, s.cfg.AdminTokenPath(), s.now()); err != nil {
		return false, err
	}
	s.log.Info("у сервера нет владельца — ключ администратора записан в файл", "file", s.cfg.AdminTokenPath())
	return true, nil
}

// IssueAdminToken создаёт новый ключ (прежний перестаёт действовать), кладёт
// в файл и возвращает — для печати в терминал.
func IssueAdminToken(ctx context.Context, st *store.Store, path string, now time.Time) (string, error) {
	token, err := admintoken.New()
	if err != nil {
		return "", err
	}
	if err := admintoken.WriteFile(path, token); err != nil {
		return "", err
	}
	if err := st.SetAdminToken(ctx, admintoken.Hash(token), now.UnixMilli()); err != nil {
		return "", err
	}
	return token, nil
}

// Handler — HTTP: /.well-known/yeenlink и /ws.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /.well-known/yeenlink", s.wellKnown)
	mux.HandleFunc("GET /ws", s.serveWS)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok\n")) })
	return mux
}

func (s *Server) wellKnown(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if r.URL.Query().Has("json") {
		js, err := codec.ToJSON(s.info, codec.JSONOptions{Indent: "  "})
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(js)
		return
	}
	w.Header().Set("Content-Type", "application/cbor")
	_, _ = w.Write(s.info)
}

// clientIP — адрес клиента; X-Forwarded-For учитывается, только если запрос
// пришёл от доверенного прокси.
func (s *Server) clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	ip := net.ParseIP(host)
	for _, n := range s.trusted {
		if ip != nil && n.Contains(ip) {
			if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
				parts := strings.Split(xff, ",")
				return strings.TrimSpace(parts[len(parts)-1])
			}
		}
	}
	return host
}

// publish рассылает событие и кладёт его в кольцо для resume. to — одному
// участнику (адресные события появятся в фазе 3), nil — всем.
//
//nolint:unparam // to пригодится в фазе 3
func (s *Server) publish(op string, d any, to []byte) {
	f, err := codec.NewFrame(op, nil, d)
	if err != nil {
		s.log.Error("событие не закодировано", "op", op, "err", err)
		return
	}
	frame, err := f.Encode()
	if err != nil {
		s.log.Error("событие не закодировано", "op", op, "err", err)
		return
	}
	s.mu.Lock()
	s.nextEvent++
	ev := event{id: s.nextEvent, at: s.now(), frame: frame, to: to}
	s.events = append(s.events, ev)
	s.trimEventsLocked()
	var targets []*conn
	for c := range s.conns {
		if c.sess != nil && (to == nil || equal(c.sess.master, to)) {
			targets = append(targets, c)
		}
	}
	s.mu.Unlock()
	for _, c := range targets {
		c.sendEvent(ev)
	}
}

func (s *Server) trimEventsLocked() {
	cut := s.now().Add(-time.Duration(protocol.ResumeWindowMs) * time.Millisecond)
	i := 0
	for i < len(s.events) && s.events[i].at.Before(cut) {
		i++
	}
	s.events = s.events[i:]
	for k, sess := range s.sessions {
		if sess.conn == nil && sess.detachedAt.Before(cut) {
			delete(s.sessions, k)
		}
	}
}

// eventsSince — события после last для участника; ok = false, если часть уже
// выпала из кольца (тогда нужен полный ready).
func (s *Server) eventsSinceLocked(last uint64, master []byte) ([][]byte, bool) {
	if last > s.nextEvent {
		return nil, false
	}
	if len(s.events) > 0 && s.events[0].id > last+1 {
		return nil, false
	}
	if len(s.events) == 0 && last < s.nextEvent {
		return nil, false
	}
	out := [][]byte{}
	for _, e := range s.events {
		if e.id > last && (e.to == nil || equal(e.to, master)) {
			out = append(out, e.frame)
		}
	}
	return out, true
}

// dropDevice разрывает соединения и сессии отозванного устройства.
func (s *Server) dropDevice(device []byte) {
	s.mu.Lock()
	var victims []*conn
	for k, sess := range s.sessions {
		if equal(sess.device, device) {
			if sess.conn != nil {
				victims = append(victims, sess.conn)
			}
			delete(s.sessions, k)
		}
	}
	s.mu.Unlock()
	for _, c := range victims {
		c.closeWith(protocol.ErrDeviceRevoked, "устройство отозвано")
	}
}

func equal(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func hexID(b []byte) string { return hex.EncodeToString(b) }

// limiter — не больше n событий за окно на ключ (адрес клиента).
type limiter struct {
	mu     sync.Mutex
	n      int
	window time.Duration
	hits   map[string][]time.Time
}

func newLimiter(n int, window time.Duration) *limiter {
	return &limiter{n: n, window: window, hits: map[string][]time.Time{}}
}

// allow регистрирует попытку; false и время ожидания — если лимит исчерпан.
func (l *limiter) allow(key string, now time.Time) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cut := now.Add(-l.window)
	hs := l.hits[key]
	i := 0
	for i < len(hs) && !hs[i].After(cut) {
		i++
	}
	hs = hs[i:]
	if len(hs) >= l.n {
		l.hits[key] = hs
		return false, hs[0].Add(l.window).Sub(now)
	}
	l.hits[key] = append(hs, now)
	if len(l.hits) > 10000 { // не копить память на тысячах адресов
		for k, v := range l.hits {
			if len(v) == 0 || !v[len(v)-1].After(cut) {
				delete(l.hits, k)
			}
		}
	}
	return true, 0
}
