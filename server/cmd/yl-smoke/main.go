// Команда yl-smoke — проверка живого сервера (CI vps-smoke и ручная): входит
// новым случайным ключом, забирает роль Владельца ключом администратора и
// убеждается, что после повторного входа роль на месте.
//
//	yl-smoke --url https://127.0.0.1:8443 --token-file /var/lib/yeenlink/admin-token [--expect-key F289·E973·4BB5·DB0C]
package main

import (
	"context"
	"crypto/rand"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"yeenlink/server/internal/testclient"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "yl-smoke:", err)
		os.Exit(1)
	}
}

func run() error {
	base := flag.String("url", "", "адрес сервера, https://host:port")
	tokenFile := flag.String("token-file", "", "файл ключа администратора")
	expect := flag.String("expect-key", "", "отпечаток ключа сервера из ylsrv init (необязательно)")
	flag.Parse()
	if *base == "" || *tokenFile == "" {
		flag.Usage()
		return errors.New("нужны --url и --token-file")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	entropy, seed := make([]byte, 16), make([]byte, 32)
	_, _ = rand.Read(entropy)
	_, _ = rand.Read(seed)
	id, err := testclient.NewIdentity(entropy, seed)
	if err != nil {
		return err
	}
	c, err := testclient.Dial(ctx, *base, nil, id, nil)
	if err != nil {
		return fmt.Errorf("вход: %w", err)
	}
	fp := identity.Fingerprint(c.ServerPub)
	fmt.Println("ключ сервера:", fp)
	if *expect != "" && *expect != fp {
		return fmt.Errorf("ключ сервера %s, ожидался %s", fp, *expect)
	}
	if c.Unbound {
		fmt.Println("внимание: сервер не знает свой сертификат (proxy без proxy_cert)")
	}
	fmt.Printf("вход: ready, владелец есть: %v\n", c.Ready.Server.HasOwner)

	tok, err := os.ReadFile(*tokenFile)
	if err != nil {
		return err
	}
	var claimed protocol.AdminClaimed
	if err := c.Call(ctx, protocol.OpAdminClaim, protocol.AdminClaim{Token: strings.TrimSpace(string(tok))}, &claimed); err != nil {
		return fmt.Errorf("admin.claim: %w", err)
	}
	c.Close()
	if !claimed.Owner {
		return errors.New("admin.claim: роль не выдана")
	}
	if _, err := os.Stat(*tokenFile); err == nil {
		return errors.New("файл ключа не удалён после admin.claim")
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	again, err := testclient.Dial(ctx, *base, c.ServerPub, id, nil)
	if err != nil {
		return fmt.Errorf("повторный вход: %w", err)
	}
	defer again.Close()
	if !again.Ready.Me.Owner || protocol.PermsFromWire(again.Ready.Perms.Server) != ^uint64(0) {
		return fmt.Errorf("после повторного входа роль не на месте: %+v", again.Ready.Me)
	}
	fmt.Println("ok: роль Владельца получена и сохраняется")
	return nil
}
