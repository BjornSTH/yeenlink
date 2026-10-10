package main

import (
	_ "embed"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

//go:embed ylsrv.service
var unitTemplate string

const (
	serviceUser = "yeenlink"
	installBin  = "/usr/local/bin/ylsrv"
	unitPath    = "/etc/systemd/system/ylsrv.service"
)

// canInstallService — init запущен под root на системе с systemd.
func canInstallService() bool {
	if os.Geteuid() != 0 {
		return false
	}
	st, err := os.Stat("/run/systemd/system")
	return err == nil && st.IsDir()
}

// installService ставит сервер как службу: системный пользователь yeenlink,
// бинарник в /usr/local/bin, unit systemd; data_dir — пользователю службы,
// конфиг — root:yeenlink 0640 (служба читает, но не меняет).
func installService(cfgPath, dataDir string) error {
	u, err := user.Lookup(serviceUser)
	var unknown user.UnknownUserError
	if errors.As(err, &unknown) {
		out, err := exec.Command("useradd", "--system", "--user-group", "--home-dir", dataDir,
			"--no-create-home", "--shell", "/usr/sbin/nologin", serviceUser).CombinedOutput() // #nosec G204 -- аргументы постоянные
		if err != nil {
			return fmt.Errorf("useradd: %w: %s", err, out)
		}
		u, err = user.Lookup(serviceUser)
		if err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	uid, _ := strconv.Atoi(u.Uid)
	gid, _ := strconv.Atoi(u.Gid)

	if err := installSelf(); err != nil {
		return fmt.Errorf("бинарник в %s: %w", installBin, err)
	}
	// os.Root: обход не выйдет за data_dir по подложенной ссылке.
	root, err := os.OpenRoot(dataDir)
	if err != nil {
		return err
	}
	defer func() { _ = root.Close() }()
	if err := fs.WalkDir(root.FS(), ".", func(p string, _ fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		return root.Lchown(p, uid, gid)
	}); err != nil {
		return err
	}
	if err := os.Chown(cfgPath, 0, gid); err != nil {
		return err
	}
	if err := os.Chmod(cfgPath, 0o640); err != nil { // #nosec G302 -- секретов в конфиге нет; группа — только служба
		return err
	}
	if dir := filepath.Dir(cfgPath); dir != "/etc" && dir != "/" {
		if err := os.Chown(dir, 0, gid); err != nil {
			return err
		}
		if err := os.Chmod(dir, 0o750); err != nil { // #nosec G302 -- см. выше
			return err
		}
	}
	unit := strings.NewReplacer("@CONFIG@", cfgPath, "@DATA_DIR@", dataDir).Replace(unitTemplate)
	if err := os.WriteFile(unitPath, []byte(unit), 0o644); err != nil { // #nosec G306 -- unit читают все
		return err
	}
	if out, err := exec.Command("systemctl", "daemon-reload").CombinedOutput(); err != nil {
		return fmt.Errorf("systemctl daemon-reload: %w: %s", err, out)
	}
	return nil
}

// installSelf копирует запущенный бинарник в /usr/local/bin/ylsrv, если он не там.
func installSelf() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	if exe, err = filepath.EvalSymlinks(exe); err != nil {
		return err
	}
	if exe == installBin {
		return nil
	}
	src, err := os.ReadFile(exe) // #nosec G304 -- собственный бинарник
	if err != nil {
		return err
	}
	tmp := installBin + ".new"
	if err := os.WriteFile(tmp, src, 0o755); err != nil { // #nosec G306 G703 -- путь постоянный, файл исполняемый
		return err
	}
	return os.Rename(tmp, installBin)
}

// chownLikeDir отдаёт файл владельцу каталога — чтобы `sudo ylsrv admin-token`
// не оставил службе файл, принадлежащий root.
func chownLikeDir(path string) error {
	if os.Geteuid() != 0 {
		return nil
	}
	st, err := os.Stat(filepath.Dir(path))
	if err != nil {
		return err
	}
	uid, gid, ok := fileOwner(st)
	if !ok || uid == 0 {
		return nil
	}
	return os.Chown(path, uid, gid)
}

func fileOwner(st os.FileInfo) (uid, gid int, ok bool) {
	s, ok := st.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, 0, false
	}
	return int(s.Uid), int(s.Gid), true
}
