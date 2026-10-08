package server

import (
	"context"
	"errors"
	"fmt"
	"math"

	"yeenlink/server/internal/admintoken"
	"yeenlink/server/internal/store"
	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

func (s *Server) serverState(ctx context.Context) (protocol.Server, error) {
	owner, err := s.store.Owner(ctx)
	if err != nil {
		return protocol.Server{}, err
	}
	var si identity.ServerInfo
	signed, _ := identity.DecodeSigned(s.info)
	_ = codec.Unmarshal(signed.P, &si)
	return protocol.Server{Pub: s.pub, Name: si.Name, Version: s.version, HasOwner: owner != nil, Info: s.info}, nil
}

func (s *Server) readyFor(ctx context.Context, master []byte) (protocol.Ready, error) {
	srv, err := s.serverState(ctx)
	if err != nil {
		return protocol.Ready{}, err
	}
	owner, err := s.store.Owner(ctx)
	if err != nil {
		return protocol.Ready{}, err
	}
	me := protocol.Me{MasterPub: master, Owner: equal(owner, master)}
	if p, err := s.store.Profile(ctx, master); err != nil {
		return protocol.Ready{}, err
	} else if p != nil {
		me.Profile = p.Signed
	}
	if d, err := s.store.Devices(ctx, master); err != nil {
		return protocol.Ready{}, err
	} else if d != nil {
		me.Devices = d.Signed
	}
	roles, err := s.store.Roles(ctx)
	if err != nil {
		return protocol.Ready{}, err
	}
	var everyone uint64
	out := make([]protocol.Role, 0, len(roles))
	for _, r := range roles {
		out = append(out, protocol.Role{ID: uint64(r.ID), Name: r.Name, Position: uint64(r.Position), Perms: protocol.PermsToWire(r.Perms), Builtin: r.Builtin}) // #nosec G115
		if r.Builtin == "everyone" {
			everyone = r.Perms
		}
	}
	perms := everyone
	if me.Owner {
		perms = math.MaxUint64 // владелец — все биты
	}
	return protocol.Ready{
		Server: srv, Me: me, Roles: out,
		Channels:  []any{},
		Perms:     protocol.Perms{Server: protocol.PermsToWire(perms), Channels: map[string]int64{}},
		Addresses: []any{},
	}, nil
}

func (c *conn) onOp(f *codec.Frame) error {
	switch f.Op {
	case protocol.OpAdminClaim:
		return c.onAdminClaim(f)
	case protocol.OpProfilePush:
		return c.onProfilePush(f)
	case protocol.OpDevicesPush:
		return c.onDevicesPush(f)
	case protocol.OpRevokePush:
		return c.onRevokePush(f)
	}
	c.fail(f.ID, f.Op, protocol.ErrUnknownOp, fmt.Sprintf("операция %q не поддерживается", f.Op))
	return nil
}

func (c *conn) onAdminClaim(f *codec.Frame) error {
	s := c.srv
	now := s.now()
	if ok, wait := s.claims.allow(c.ip, now); !ok {
		c.fail(f.ID, f.Op, protocol.ErrRateLimited, fmt.Sprintf("слишком много попыток, повторите через %d с", int(wait.Seconds())+1))
		return nil
	}
	var req protocol.AdminClaim
	if err := f.DecodeD(&req); err != nil || !admintoken.Valid(req.Token) {
		c.fail(f.ID, f.Op, protocol.ErrBadToken, "это не ключ администратора")
		return nil
	}
	previous, ok, err := s.store.ClaimOwner(c.ctx, admintoken.Hash(req.Token), c.sess.master, now.UnixMilli())
	if err != nil {
		return err
	}
	if !ok {
		c.fail(f.ID, f.Op, protocol.ErrBadToken, "ключ не подошёл")
		return nil
	}
	if err := admintoken.RemoveFile(s.cfg.AdminTokenPath()); err != nil {
		s.log.Warn("не удалось удалить файл ключа администратора", "file", s.cfg.AdminTokenPath(), "err", err)
	}
	s.log.Info("владелец сервера сменился", "owner", identity.Fingerprint(c.sess.master), "previous", fingerprintOrEmpty(previous))
	c.reply(f.ID, f.Op, protocol.AdminClaimed{Owner: true})
	if srv, err := s.serverState(c.ctx); err == nil {
		s.publish(protocol.OpServerUpdate, protocol.ServerUpdate{Server: srv}, nil)
	}
	s.publish(protocol.OpMemberUpdate, protocol.MemberUpdate{MasterPub: c.sess.master, Owner: true}, nil)
	if previous != nil {
		s.publish(protocol.OpMemberUpdate, protocol.MemberUpdate{MasterPub: previous, Owner: false}, nil)
	}
	return nil
}

func fingerprintOrEmpty(b []byte) string {
	if b == nil {
		return ""
	}
	return identity.Fingerprint(b)
}

func (c *conn) openSigned(f *codec.Frame, raw []byte) (*identity.Signed, bool) {
	s, err := identity.DecodeSigned(raw)
	if err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil, false
	}
	return s, true
}

func (c *conn) onProfilePush(f *codec.Frame) error {
	var req protocol.ProfilePush
	if err := f.DecodeD(&req); err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	signed, ok := c.openSigned(f, req.Profile)
	if !ok {
		return nil
	}
	p, err := identity.OpenProfile(signed)
	if err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	if !equal(p.Master, c.sess.master) {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, "это профиль другого человека")
		return nil
	}
	err = c.srv.store.SaveProfile(c.ctx, p.Master, p.Seq, req.Profile, c.srv.now().UnixMilli())
	if errors.Is(err, store.ErrStale) {
		c.failStale(f, "profile", c.srv.store.Profile)
		return nil
	}
	if err != nil {
		return err
	}
	c.reply(f.ID, f.Op, protocol.SeqAck{Seq: p.Seq})
	c.srv.publish(protocol.OpMemberUpdate, protocol.MemberUpdate{MasterPub: p.Master, Profile: req.Profile, Owner: c.isOwner()}, nil)
	return nil
}

func (c *conn) failStale(f *codec.Frame, what string, get func(context.Context, []byte) (*store.Signed, error)) {
	cur, _ := get(c.ctx, c.sess.master)
	var seq uint64
	if cur != nil {
		seq = cur.Seq
	}
	c.fail(f.ID, f.Op, protocol.ErrStale, fmt.Sprintf("%s: на сервере seq %d, нужен больше", what, seq))
}

func (c *conn) isOwner() bool {
	owner, _ := c.srv.store.Owner(c.ctx)
	return equal(owner, c.sess.master)
}

func (c *conn) onDevicesPush(f *codec.Frame) error {
	var req protocol.DevicesPush
	if err := f.DecodeD(&req); err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	signed, ok := c.openSigned(f, req.Devices)
	if !ok {
		return nil
	}
	d, err := identity.OpenDevices(signed, c.sess.master)
	if err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	err = c.srv.store.SaveDevices(c.ctx, c.sess.master, d.Seq, req.Devices, d.Revoked, c.srv.now().UnixMilli())
	if errors.Is(err, store.ErrStale) {
		c.failStale(f, "devices", c.srv.store.Devices)
		return nil
	}
	if err != nil {
		return err
	}
	c.reply(f.ID, f.Op, protocol.SeqAck{Seq: d.Seq})
	for _, dev := range d.Revoked {
		c.srv.dropDevice(dev)
	}
	return nil
}

func (c *conn) onRevokePush(f *codec.Frame) error {
	var req protocol.RevokePush
	if err := f.DecodeD(&req); err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	signed, ok := c.openSigned(f, req.Revoke)
	if !ok {
		return nil
	}
	r, err := identity.OpenRevoke(signed, c.sess.master)
	if err != nil {
		c.fail(f.ID, f.Op, protocol.ErrBadPayload, err.Error())
		return nil
	}
	if err := c.srv.store.Revoke(c.ctx, r.DevicePub, c.sess.master, c.srv.now().UnixMilli()); err != nil {
		return err
	}
	c.reply(f.ID, f.Op, map[string]any{})
	c.srv.dropDevice(r.DevicePub)
	return nil
}
