package server

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/coder/websocket"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

type connState int

const (
	awaitHello connState = iota
	awaitAuth
	authed
)

// conn — одно соединение WebSocket.
type conn struct {
	srv    *Server
	ws     *websocket.Conn
	r      *http.Request
	ip     string
	ctx    context.Context
	cancel context.CancelFunc

	state     connState
	hello     protocol.Hello
	nonce     []byte
	ts        uint64
	sess      *session
	lastEvent uint64 // последнее событие, отправленное этому соединению

	sendMu sync.Mutex
	send   chan []byte
	closed bool
}

const sendQueue = 64

func (s *Server) serveWS(w http.ResponseWriter, r *http.Request) {
	ws, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		CompressionMode: websocket.CompressionContextTakeover,
		// Происхождение (Origin) не проверяем: клиент — приложение, не браузер;
		// вход всё равно по ключу.
		InsecureSkipVerify: true,
	})
	if err != nil {
		return
	}
	defer s.tls.Forget(r)
	ws.SetReadLimit(protocol.MaxFrameBytes)
	ctx, cancel := context.WithCancel(r.Context())
	c := &conn{srv: s, ws: ws, r: r, ip: s.clientIP(r), ctx: ctx, cancel: cancel, send: make(chan []byte, sendQueue)}
	s.mu.Lock()
	s.conns[c] = struct{}{}
	s.mu.Unlock()
	defer c.detach()

	go c.writer()
	c.reader()
}

func (c *conn) reader() {
	defer c.cancel()
	for {
		typ, data, err := c.ws.Read(c.ctx)
		if err != nil {
			return
		}
		if (c.srv.wire == codec.WireCBOR) != (typ == websocket.MessageBinary) {
			c.closeWith(protocol.ErrBadFrame, "тип сообщения не совпадает с форматом сервера")
			return
		}
		f, err := c.srv.wire.DecodeFrame(data)
		if err != nil {
			c.closeWith(protocol.ErrBadFrame, err.Error())
			return
		}
		if err := c.handle(f); err != nil {
			return
		}
	}
}

// writer отправляет кадры и пингует; при 90 с без ответа на ping — закрывает.
func (c *conn) writer() {
	ping := time.NewTicker(time.Duration(protocol.PingIntervalMs) * time.Millisecond)
	defer ping.Stop()
	for {
		select {
		case <-c.ctx.Done():
			return
		case b, ok := <-c.send:
			if !ok {
				return
			}
			typ := websocket.MessageBinary
			if c.srv.wire == codec.WireJSON {
				typ = websocket.MessageText
			}
			ctx, cancel := context.WithTimeout(c.ctx, 10*time.Second)
			err := c.ws.Write(ctx, typ, b)
			cancel()
			if err != nil {
				c.cancel()
				return
			}
		case <-ping.C:
			ctx, cancel := context.WithTimeout(c.ctx, time.Duration(protocol.IdleTimeoutMs-protocol.PingIntervalMs)*time.Millisecond)
			err := c.ws.Ping(ctx)
			cancel()
			if err != nil {
				c.cancel()
				return
			}
		}
	}
}

// queue ставит кадр в очередь; переполнение — клиент не успевает, отключаем.
func (c *conn) queue(f *codec.Frame) {
	b, err := c.srv.wire.EncodeFrame(f)
	if err != nil {
		c.srv.log.Error("кадр не закодирован", "op", f.Op, "err", err)
		return
	}
	c.sendMu.Lock()
	defer c.sendMu.Unlock()
	if c.closed {
		return
	}
	select {
	case c.send <- b:
	default:
		c.closed = true
		close(c.send)
		c.cancel()
	}
}

func (c *conn) reply(id *uint64, op string, d any) {
	f, err := codec.NewFrame(op, id, d)
	if err != nil {
		c.srv.log.Error("ответ не закодирован", "op", op, "err", err)
		return
	}
	c.queue(f)
}

func (c *conn) fail(id *uint64, op, code, msg string) {
	c.queue(&codec.Frame{Op: op, ID: id, E: &codec.FrameError{Code: code, Msg: msg}})
}

func (c *conn) sendEvent(ev event) {
	f, err := codec.DecodeFrame(ev.frame)
	if err != nil {
		return
	}
	c.srv.mu.Lock()
	if ev.id <= c.lastEvent {
		c.srv.mu.Unlock()
		return
	}
	c.lastEvent = ev.id
	c.srv.mu.Unlock()
	c.queue(f)
}

// closeWith отправляет ошибку без id и закрывает соединение.
func (c *conn) closeWith(code, msg string) {
	f := &codec.Frame{Op: "error", E: &codec.FrameError{Code: code, Msg: msg}}
	if b, err := c.srv.wire.EncodeFrame(f); err == nil {
		typ := websocket.MessageBinary
		if c.srv.wire == codec.WireJSON {
			typ = websocket.MessageText
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_ = c.ws.Write(ctx, typ, b)
		cancel()
	}
	_ = c.ws.Close(websocket.StatusPolicyViolation, code)
	c.cancel()
}

func (c *conn) detach() {
	c.srv.mu.Lock()
	delete(c.srv.conns, c)
	if c.sess != nil && c.sess.conn == c {
		c.sess.conn = nil
		c.sess.detachedAt = c.srv.now()
	}
	c.srv.mu.Unlock()
	c.sendMu.Lock()
	if !c.closed {
		c.closed = true
		close(c.send)
	}
	c.sendMu.Unlock()
	_ = c.ws.CloseNow()
}

var errStop = errors.New("stop")

// handle — машина состояний входа и операции после него.
func (c *conn) handle(f *codec.Frame) error {
	switch c.state {
	case awaitHello:
		if f.Op != protocol.OpHello {
			c.closeWith(protocol.ErrNotAuthenticated, "сначала hello")
			return errStop
		}
		return c.onHello(f)
	case awaitAuth:
		if f.Op != protocol.OpAuth {
			c.closeWith(protocol.ErrNotAuthenticated, "ожидался auth")
			return errStop
		}
		return c.onAuth(f)
	}
	return c.onOp(f)
}

func (c *conn) onHello(f *codec.Frame) error {
	var h protocol.Hello
	if err := f.DecodeD(&h); err != nil {
		c.closeWith(protocol.ErrBadFrame, err.Error())
		return errStop
	}
	if h.Proto != protocol.Proto {
		c.fail(f.ID, f.Op, protocol.ErrProto, fmt.Sprintf("сервер говорит на версии %d", protocol.Proto))
		c.closeWith(protocol.ErrProto, "версия протокола")
		return errStop
	}
	if len(h.MasterPub) != 32 || len(h.DevicePub) != 32 || len(h.ClientNonce) != protocol.NonceSize {
		c.closeWith(protocol.ErrBadFrame, "длины ключей или client_nonce")
		return errStop
	}
	signed, err := identity.DecodeSigned(h.DeviceCert)
	if err == nil {
		var cert *identity.DeviceCert
		if cert, err = identity.OpenDeviceCert(signed, h.MasterPub); err == nil && !equal(cert.DevicePub, h.DevicePub) {
			err = errors.New("сертификат выдан другому устройству")
		}
	}
	if err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadCert, err.Error())
		c.closeWith(protocol.ErrBadCert, "сертификат устройства")
		return errStop
	}
	revoked, err := c.srv.store.IsRevoked(c.ctx, h.DevicePub)
	if err != nil {
		return err
	}
	if revoked {
		c.fail(f.ID, f.Op, protocol.ErrDeviceRevoked, "это устройство отвязано от профиля")
		c.closeWith(protocol.ErrDeviceRevoked, "устройство отозвано")
		return errStop
	}
	c.hello = h
	c.nonce = make([]byte, protocol.NonceSize)
	_, _ = rand.Read(c.nonce)
	c.ts = uint64(c.srv.now().UnixMilli()) // #nosec G115 -- время после 1970
	ch := protocol.SignChallenge(c.srv.key, h.ClientNonce, c.nonce, c.ts, c.srv.tls.CertHashes(c.r))
	c.state = awaitAuth
	c.reply(f.ID, protocol.OpChallenge, ch)
	return nil
}

func (c *conn) onAuth(f *codec.Frame) error {
	var a protocol.Auth
	if err := f.DecodeD(&a); err != nil {
		c.closeWith(protocol.ErrBadFrame, err.Error())
		return errStop
	}
	now := c.srv.now()
	nonce := c.nonce
	c.nonce = nil                                                                                                      // одноразовый
	if err := protocol.VerifyAuth(a, c.hello.DevicePub, nonce, c.srv.pub, c.ts, uint64(now.UnixMilli())); err != nil { // #nosec G115
		code := protocol.ErrBadSig
		if err.Error() != protocol.ErrBadSig {
			code = protocol.ErrChallengeExpired
		}
		c.fail(f.ID, f.Op, code, err.Error())
		c.closeWith(code, "вход не прошёл")
		return errStop
	}
	ctx := c.ctx
	if err := c.srv.store.SaveDeviceCert(ctx, c.hello.DevicePub, c.hello.MasterPub, c.hello.DeviceCert, now.UnixMilli()); err != nil {
		return err
	}
	if _, err := c.srv.store.TouchMember(ctx, c.hello.MasterPub, now.UnixMilli()); err != nil {
		return err
	}
	c.state = authed

	if c.hello.Resume != nil {
		if resumed := c.tryResume(f.ID); resumed {
			return nil
		}
	}
	return c.sendReady(f.ID)
}

func (c *conn) tryResume(id *uint64) bool {
	r := c.hello.Resume
	s := c.srv
	s.mu.Lock()
	sess, ok := s.sessions[hexID(r.Session)]
	if !ok || !equal(sess.master, c.hello.MasterPub) || !equal(sess.device, c.hello.DevicePub) {
		s.mu.Unlock()
		return false
	}
	events, ok := s.eventsSinceLocked(r.LastEvent, sess.master)
	if !ok {
		s.mu.Unlock()
		return false
	}
	old := sess.conn
	sess.conn = c
	c.sess = sess
	c.lastEvent = s.nextEvent
	last := s.nextEvent
	s.mu.Unlock()
	if old != nil && old != c {
		old.closeWith(protocol.ErrReplaced, "сессия продолжена в другом соединении")
	}
	c.reply(id, protocol.OpResumed, protocol.Resumed{
		Session: protocol.Session{ID: sess.id, ResumeMs: protocol.ResumeWindowMs}, Events: events, LastEvent: last,
	})
	return true
}

func (c *conn) sendReady(id *uint64) error {
	s := c.srv
	ready, err := s.readyFor(c.ctx, c.hello.MasterPub)
	if err != nil {
		return err
	}
	sid := make([]byte, protocol.SessionIDSize)
	_, _ = rand.Read(sid)
	sess := &session{id: sid, master: c.hello.MasterPub, device: c.hello.DevicePub, conn: c}
	s.mu.Lock()
	s.trimEventsLocked()
	s.sessions[hexID(sid)] = sess
	c.sess = sess
	c.lastEvent = s.nextEvent
	ready.LastEvent = s.nextEvent
	s.mu.Unlock()
	ready.Session = protocol.Session{ID: sid, ResumeMs: protocol.ResumeWindowMs}
	c.reply(id, protocol.OpReady, ready)
	return nil
}
