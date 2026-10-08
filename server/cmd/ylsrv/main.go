// Команда ylsrv — сервер YeenLink (spec/server.md):
//
//	ylsrv init         первый запуск: конфиг, ключ сервера, база, ключ администратора
//	ylsrv run          работа (под systemd)
//	ylsrv admin-token  новый ключ администратора (прежний перестаёт действовать)
//	ylsrv check-ports  какие порты свободны
//	ylsrv version
//
// Ключ администратора печатается только в терминал (init, admin-token);
// демон пишет в журнал лишь путь к файлу.
package main

import (
	"bufio"
	"context"
	"crypto/ed25519"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime/debug"
	"strconv"
	"strings"
	"syscall"
	"time"

	"yeenlink/server/internal/config"
	"yeenlink/server/internal/firstrun"
	"yeenlink/server/internal/server"
	"yeenlink/server/internal/serverkey"
	"yeenlink/server/internal/store"
	"yeenlink/server/internal/tlsmode"
	"yeenlink/server/pkg/identity"
)

// version подставляется при сборке: -ldflags "-X main.version=…".
var version = "dev"

func main() {
	cmd := "run"
	args := os.Args[1:]
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		cmd, args = args[0], args[1:]
	}
	var err error
	switch cmd {
	case "init":
		err = cmdInit(args)
	case "run":
		err = cmdRun(args)
	case "admin-token":
		err = cmdAdminToken(args)
	case "check-ports":
		cmdCheckPorts(args)
	case "version", "--version", "-version":
		fmt.Println("ylsrv", version)
	default:
		err = fmt.Errorf("неизвестная команда %q: init, run, admin-token, check-ports, version", cmd)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "ylsrv:", err)
		os.Exit(1)
	}
}

func isTerminal(f *os.File) bool {
	st, err := f.Stat()
	return err == nil && st.Mode()&os.ModeCharDevice != 0
}

func newLog() *slog.Logger { return slog.New(slog.NewTextHandler(os.Stderr, nil)) }

func loadConfig(path string) (config.Config, error) {
	c, err := config.Load(path)
	if errors.Is(err, fs.ErrNotExist) {
		return c, fmt.Errorf("нет конфига %s — сначала ylsrv init", path)
	}
	if err != nil {
		return c, err
	}
	return c, c.Validate()
}

func cmdRun(args []string) error {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	path := fs.String("config", config.DefaultPath, "конфиг")
	codecFlag := fs.String("codec", "", "формат кадров: cbor или json (json — только для отладки)")
	_ = fs.Parse(args)
	c, err := loadConfig(*path)
	if err != nil {
		return err
	}
	if *codecFlag != "" {
		c.Codec = *codecFlag
	}
	if os.Getenv("GOMEMLIMIT") == "" && c.MemoryLimitMiB > 0 {
		debug.SetMemoryLimit(int64(c.MemoryLimitMiB) << 20)
	}
	log := newLog()
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	st, err := store.Open(ctx, c.DBPath())
	if err != nil {
		return err
	}
	defer func() { _ = st.Close() }()
	key, created, err := serverkey.LoadOrCreate(c.ServerKeyPath())
	if err != nil {
		return err
	}
	if created {
		log.Warn("ключ сервера создан заново — клиенты, закрепившие прежний, не войдут", "file", c.ServerKeyPath())
	}
	tlsCtx, cancel := context.WithTimeout(ctx, 3*time.Minute)
	setup, err := tlsmode.Build(tlsCtx, c, log)
	cancel()
	if err != nil {
		return err
	}
	srv, err := server.New(server.Options{Config: c, Store: st, Key: key, TLS: setup, Log: log, Version: version})
	if err != nil {
		return err
	}
	if _, err := srv.EnsureAdminToken(ctx); err != nil {
		return err
	}
	if setup.HTTPChallenge != nil && c.TLS.HTTPPort > 0 {
		hs := &http.Server{Addr: ":" + strconv.Itoa(c.TLS.HTTPPort), Handler: setup.HTTPChallenge, ReadHeaderTimeout: 10 * time.Second}
		go func() {
			if err := hs.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				log.Warn("порт HTTP-01 недоступен — продлевать буду через TLS-ALPN-01", "port", c.TLS.HTTPPort, "err", err)
			}
		}()
		defer func() { _ = hs.Close() }()
	}
	ln, err := net.Listen("tcp", c.Listen)
	if err != nil {
		return err
	}
	log.Info("сервер запущен", "listen", c.Listen, "tls", c.TLS.Mode, "codec", c.Codec,
		"server_key", identity.Fingerprint(key.Public().(ed25519.PublicKey)), "version", version)
	return srv.Serve(ctx, ln)
}

func cmdAdminToken(args []string) error {
	fs := flag.NewFlagSet("admin-token", flag.ExitOnError)
	path := fs.String("config", config.DefaultPath, "конфиг")
	_ = fs.Parse(args)
	c, err := loadConfig(*path)
	if err != nil {
		return err
	}
	ctx := context.Background()
	st, err := store.Open(ctx, c.DBPath())
	if err != nil {
		return err
	}
	defer func() { _ = st.Close() }()
	token, err := server.IssueAdminToken(ctx, st, c.AdminTokenPath(), time.Now())
	if err != nil {
		return err
	}
	printToken(os.Stdout, token, c.AdminTokenPath())
	fmt.Println("Прежний ключ больше не действует. Кто введёт этот, станет Владельцем вместо нынешнего.")
	return nil
}

// printToken печатает ключ только в терминал; в файл/журнал — лишь путь.
func printToken(w *os.File, token, file string) {
	if isTerminal(w) {
		fmt.Fprintf(w, "\nКлюч администратора (показывается один раз):\n\n    %s\n\n", token)
		fmt.Fprintf(w, "Он же лежит в %s (права 0600) и сгорит после использования.\n", file)
		return
	}
	fmt.Fprintf(w, "Ключ администратора записан в %s (права 0600). Здесь он не печатается: вывод — не терминал.\n", file)
}

func cmdCheckPorts(args []string) {
	fs := flag.NewFlagSet("check-ports", flag.ExitOnError)
	listen := fs.String("listen", ":443", "адрес API")
	httpPort := fs.Int("http-port", 80, "порт HTTP-01 (0 — не проверять)")
	_ = fs.Parse(args)
	printPorts(os.Stdout, firstrun.CheckPorts(*listen, *httpPort))
}

func printPorts(w io.Writer, ports []firstrun.Port) {
	fmt.Fprintln(w, "Порты:")
	for _, p := range ports {
		fmt.Fprintln(w, "  "+p.Describe())
	}
}

type initFlags struct {
	path, name, host, listen, mode, email, dataDir, certFile, keyFile, proxyCert string
	httpPort                                                                     int
	nonInteractive                                                               bool
}

func cmdInit(args []string) error {
	var f initFlags
	fs := flag.NewFlagSet("init", flag.ExitOnError)
	fs.StringVar(&f.path, "config", config.DefaultPath, "куда записать конфиг")
	fs.StringVar(&f.name, "name", "", "название сервера")
	fs.StringVar(&f.host, "host", "", "домен или IP, под которым сервер виден снаружи")
	fs.StringVar(&f.listen, "listen", "", "адрес API (по умолчанию :443)")
	fs.StringVar(&f.mode, "tls", "", "acme | file | self-signed | proxy (по умолчанию: acme для домена, self-signed для IP)")
	fs.StringVar(&f.email, "email", "", "почта для Let's Encrypt (необязательно)")
	fs.IntVar(&f.httpPort, "http-port", 80, "порт HTTP-01 для Let's Encrypt (0 — только TLS-ALPN-01)")
	fs.StringVar(&f.dataDir, "data-dir", "", "папка данных (по умолчанию /var/lib/yeenlink)")
	fs.StringVar(&f.certFile, "cert-file", "", "tls=file: сертификат")
	fs.StringVar(&f.keyFile, "key-file", "", "tls=file: ключ")
	fs.StringVar(&f.proxyCert, "proxy-cert", "", "tls=proxy: сертификат, который отдаёт прокси")
	fs.BoolVar(&f.nonInteractive, "non-interactive", false, "ничего не спрашивать")
	_ = fs.Parse(args)

	if _, err := os.Stat(f.path); err == nil {
		return fmt.Errorf("%s уже есть — сервер настроен. Новый ключ администратора: ylsrv admin-token", f.path)
	}
	c := config.Default()
	ask := !f.nonInteractive && isTerminal(os.Stdin)
	in := bufio.NewReader(os.Stdin)
	prompt := func(q, def string) string {
		if !ask {
			return def
		}
		if def != "" {
			fmt.Printf("%s [%s]: ", q, def)
		} else {
			fmt.Printf("%s: ", q)
		}
		line, _ := in.ReadString('\n')
		if line = strings.TrimSpace(line); line != "" {
			return line
		}
		return def
	}
	c.Name = prompt("Название сервера", f.name)
	c.Host = prompt("Домен или IP-адрес сервера", f.host)
	if f.listen != "" {
		c.Listen = f.listen
	}
	if f.dataDir != "" {
		c.DataDir = f.dataDir
	}
	mode := f.mode
	if mode == "" {
		mode = config.TLSACME
		if net.ParseIP(c.Host) != nil {
			mode = config.TLSSelfSigned
		}
	}
	c.TLS.Mode = prompt("Сертификат: acme, file, self-signed или proxy", mode)
	c.TLS.Email, c.TLS.CertFile, c.TLS.KeyFile = f.email, f.certFile, f.keyFile
	if f.proxyCert != "" {
		c.TLS.ProxyCerts = []string{f.proxyCert}
	}

	// Порт HTTP-01 нужен только для Let's Encrypt.
	c.TLS.HTTPPort = 0
	if c.TLS.Mode == config.TLSACME {
		c.TLS.HTTPPort = f.httpPort
	}

	ports := firstrun.CheckPorts(c.Listen, c.TLS.HTTPPort)
	printPorts(os.Stdout, ports)
	if ports[0].Status == "busy" {
		fmt.Println("Порт API занят: укажите другой (--listen :8443, его же — в приглашениях),")
		fmt.Println("или поставьте сервер за nginx/Caddy (--tls proxy --listen 127.0.0.1:8080 --proxy-cert …).")
		if !ask {
			return errors.New("порт API занят")
		}
		c.Listen = prompt("Адрес API", ":8443")
	}
	if c.TLS.HTTPPort > 0 && len(ports) > 1 && ports[1].Status != "free" {
		fmt.Println("Порт 80 недоступен — сертификат Let's Encrypt буду получать через TLS-ALPN-01 на порту API.")
		c.TLS.HTTPPort = 0
	}

	if err := c.Validate(); err != nil {
		return err
	}

	if err := os.MkdirAll(c.DataDir, 0o700); err != nil {
		return err
	}
	key, _, err := serverkey.LoadOrCreate(c.ServerKeyPath())
	if err != nil {
		return err
	}
	ctx := context.Background()
	st, err := store.Open(ctx, c.DBPath())
	if err != nil {
		return err
	}
	defer func() { _ = st.Close() }()
	now := time.Now()
	if err := st.SetMeta(ctx, store.MetaName, c.Name); err != nil {
		return err
	}
	if err := st.SetMeta(ctx, store.MetaCreated, strconv.FormatInt(now.UnixMilli(), 10)); err != nil {
		return err
	}
	var fingerprint string
	if c.TLS.Mode == config.TLSSelfSigned || c.TLS.Mode == config.TLSFile {
		setup, err := tlsmode.Build(ctx, c, newLog())
		if err != nil {
			return err
		}
		fingerprint = setup.Fingerprint
	}
	if err := config.Save(f.path, c); err != nil {
		return err
	}
	token, err := server.IssueAdminToken(ctx, st, c.AdminTokenPath(), now)
	if err != nil {
		return err
	}

	fmt.Printf("\nГотово. Конфиг: %s, данные: %s\n", f.path, c.DataDir)
	fmt.Printf("\nКлюч сервера — сверьте его в приложении при первом подключении:\n\n    %s\n", identity.Fingerprint(key.Public().(ed25519.PublicKey)))
	if fingerprint != "" {
		fmt.Printf("\nСертификат TLS (SHA-256): %s\n", fingerprint)
	}
	printToken(os.Stdout, token, c.AdminTokenPath())
	fmt.Println("\nЗапуск: systemctl enable --now ylsrv   (или вручную: ylsrv run)")
	return nil
}
