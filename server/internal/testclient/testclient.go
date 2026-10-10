// Package testclient — клиент YeenLink на Go для тестов и проверки установки
// (ylsrv-smoke): проверяет server_info и закреплённый ключ, сам считает хеш
// сертификата TLS, проходит challenge и auth.
package testclient

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

// Identity — личность клиента: главный ключ, ключ устройства, сертификат.
type Identity struct {
	Master ed25519.PrivateKey
	Device ed25519.PrivateKey
	Cert   []byte // Signed device_cert (CBOR)
}

// NewIdentity — личность из энтропии фразы и seed устройства.
func NewIdentity(entropy, deviceSeed []byte) (*Identity, error) {
	id, err := identity.FromEntropy(entropy)
	if err != nil {
		return nil, err
	}
	dev := ed25519.NewKeyFromSeed(deviceSeed)
	s, err := identity.Sign(identity.TypeDeviceCert, identity.DeviceCert{
		DevicePub: dev.Public().(ed25519.PublicKey), Name: "Тест · Go", Platform: "linux",
		Created: uint64(time.Now().UnixMilli()), // #nosec G115
	}, id.Master)
	if err != nil {
		return nil, err
	}
	cert, err := s.Encode()
	if err != nil {
		return nil, err
	}
	return &Identity{Master: id.Master, Device: dev, Cert: cert}, nil
}

// MasterPub — открытый главный ключ.
func (i *Identity) MasterPub() []byte { return i.Master.Public().(ed25519.PublicKey) }

// Client — вошедший клиент.
type Client struct {
	ws        *websocket.Conn
	ServerPub []byte
	Unbound   bool // сервер не знает свой сертификат (за прокси без proxy_cert)
	Ready     *protocol.Ready
	Resumed   *protocol.Resumed

	mu      sync.Mutex
	nextID  uint64
	pending map[uint64]chan *codec.Frame
	Events  chan *codec.Frame
	done    chan struct{}
	life    context.Context
	stop    context.CancelFunc
}

// ErrNotSameServer — ключ сервера не совпал с закреплённым.
var ErrNotSameServer = errors.New("testclient: это не тот сервер")

// Fetch читает /.well-known/yeenlink и проверяет подпись server_info.
func Fetch(ctx context.Context, base string, hc *http.Client) (*identity.ServerInfo, error) {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(base, "/")+"/.well-known/yeenlink", nil)
	resp, err := hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return nil, err
	}
	s, err := identity.DecodeSigned(b)
	if err != nil {
		return nil, err
	}
	return identity.OpenServerInfo(s)
}

// Dial подключается и входит. pinned — закреплённый ключ сервера (nil —
// доверие с первого раза: берётся из server_info).
func Dial(ctx context.Context, base string, pinned []byte, id *Identity, resume *protocol.Resume) (*Client, error) {
	var seen []byte
	var seenMu sync.Mutex
	tlsCfg := &tls.Config{
		// Доверие — к ключу сервера, а не к цепочке сертификата: хеш
		// сертификата проверяется подписью сервера в challenge.
		InsecureSkipVerify: true, // #nosec G402
		VerifyConnection: func(cs tls.ConnectionState) error {
			if len(cs.PeerCertificates) > 0 {
				seenMu.Lock()
				seen = protocol.CertHash(cs.PeerCertificates[0].Raw)
				seenMu.Unlock()
			}
			return nil
		},
	}
	hc := &http.Client{Transport: &http.Transport{TLSClientConfig: tlsCfg, DisableKeepAlives: true}, Timeout: 15 * time.Second}
	info, err := Fetch(ctx, base, hc)
	if err != nil {
		return nil, fmt.Errorf("server_info: %w", err)
	}
	if pinned == nil {
		pinned = info.ServerPub
	} else if !equal(pinned, info.ServerPub) {
		return nil, ErrNotSameServer
	}
	u, _ := url.Parse(base)
	if u.Scheme == "https" {
		u.Scheme = "wss"
	} else {
		u.Scheme = "ws"
	}
	u.Path = "/ws"
	seenMu.Lock()
	seen = nil // хеш берём именно у соединения WebSocket
	seenMu.Unlock()
	ws, hresp, err := websocket.Dial(ctx, u.String(), &websocket.DialOptions{HTTPClient: hc, CompressionMode: websocket.CompressionContextTakeover})
	if hresp != nil && hresp.Body != nil {
		_ = hresp.Body.Close()
	}
	if err != nil {
		return nil, err
	}
	ws.SetReadLimit(protocol.MaxFrameBytes)
	life, stop := context.WithCancel(context.Background())
	c := &Client{ws: ws, ServerPub: pinned, pending: map[uint64]chan *codec.Frame{}, Events: make(chan *codec.Frame, 64), done: make(chan struct{}), life: life, stop: stop}

	clientNonce := make([]byte, protocol.NonceSize)
	_, _ = rand.Read(clientNonce)
	hello := protocol.Hello{Proto: protocol.Proto, MasterPub: id.MasterPub(), DevicePub: id.Device.Public().(ed25519.PublicKey), DeviceCert: id.Cert, ClientNonce: clientNonce, Resume: resume}
	chFrame, err := c.roundTrip(ctx, protocol.OpHello, hello)
	if err != nil {
		_ = ws.CloseNow()
		return nil, err
	}
	var ch protocol.Challenge
	if err := chFrame.DecodeD(&ch); err != nil {
		_ = ws.CloseNow()
		return nil, err
	}
	seenMu.Lock()
	seenHash := seen
	seenMu.Unlock()
	if c.Unbound, err = protocol.VerifyChallenge(ch, pinned, clientNonce, seenHash); err != nil {
		_ = ws.CloseNow()
		return nil, err
	}
	resp, err := c.roundTrip(ctx, protocol.OpAuth, protocol.SignAuth(id.Device, ch.Nonce, pinned, ch.TS))
	if err != nil {
		_ = ws.CloseNow()
		return nil, err
	}
	switch resp.Op {
	case protocol.OpReady:
		c.Ready = &protocol.Ready{}
		err = resp.DecodeD(c.Ready)
	case protocol.OpResumed:
		c.Resumed = &protocol.Resumed{}
		err = resp.DecodeD(c.Resumed)
	default:
		err = fmt.Errorf("testclient: после auth пришёл %s", resp.Op)
	}
	if err != nil {
		_ = ws.CloseNow()
		return nil, err
	}
	go c.readLoop()
	return c, nil
}

// FrameError — ответ сервера с ошибкой.
type FrameError struct{ Code, Msg string }

func (e *FrameError) Error() string { return e.Code + ": " + e.Msg }

// roundTrip до readLoop: читает напрямую, ожидая ответ на свой id.
func (c *Client) roundTrip(ctx context.Context, op string, d any) (*codec.Frame, error) {
	c.nextID++
	id := c.nextID
	if err := c.write(ctx, op, id, d); err != nil {
		return nil, err
	}
	for {
		_, data, err := c.ws.Read(ctx)
		if err != nil {
			return nil, err
		}
		f, err := codec.DecodeFrame(data)
		if err != nil {
			return nil, err
		}
		if f.E != nil {
			return nil, &FrameError{f.E.Code, f.E.Msg}
		}
		if f.ID != nil && *f.ID == id {
			return f, nil
		}
	}
}

func (c *Client) write(ctx context.Context, op string, id uint64, d any) error {
	f, err := codec.NewFrame(op, codec.ID(id), d)
	if err != nil {
		return err
	}
	b, err := f.Encode()
	if err != nil {
		return err
	}
	return c.ws.Write(ctx, websocket.MessageBinary, b)
}

func (c *Client) readLoop() {
	defer close(c.done)
	for {
		_, data, err := c.ws.Read(c.life)
		if err != nil {
			c.mu.Lock()
			for id, ch := range c.pending {
				close(ch)
				delete(c.pending, id)
			}
			c.mu.Unlock()
			return
		}
		f, err := codec.DecodeFrame(data)
		if err != nil {
			continue
		}
		if f.ID == nil {
			select {
			case c.Events <- f:
			default:
			}
			continue
		}
		c.mu.Lock()
		ch := c.pending[*f.ID]
		delete(c.pending, *f.ID)
		c.mu.Unlock()
		if ch != nil {
			ch <- f
		}
	}
}

// Call — запрос после входа; ответ с e — *FrameError.
func (c *Client) Call(ctx context.Context, op string, d any, out any) error {
	c.mu.Lock()
	c.nextID++
	id := c.nextID
	ch := make(chan *codec.Frame, 1)
	c.pending[id] = ch
	c.mu.Unlock()
	if err := c.write(ctx, op, id, d); err != nil {
		return err
	}
	select {
	case f, ok := <-ch:
		if !ok {
			return errors.New("testclient: соединение закрыто")
		}
		if f.E != nil {
			return &FrameError{f.E.Code, f.E.Msg}
		}
		if out != nil {
			return f.DecodeD(out)
		}
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// WaitEvent ждёт событие op.
func (c *Client) WaitEvent(ctx context.Context, op string) (*codec.Frame, error) {
	for {
		select {
		case f := <-c.Events:
			if f.Op == op {
				return f, nil
			}
		case <-c.done:
			return nil, errors.New("testclient: соединение закрыто")
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
}

// Done — закрывается, когда сервер разорвал соединение.
func (c *Client) Done() <-chan struct{} { return c.done }

// Close закрывает соединение.
func (c *Client) Close() {
	_ = c.ws.Close(websocket.StatusNormalClosure, "")
	c.stop()
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
