//go:build !linux

package main

import "errors"

const (
	serviceUser = "yeenlink"
	installBin  = "/usr/local/bin/ylsrv"
)

func canInstallService() bool { return false }

func installService(_, _ string) error {
	return errors.New("служба ставится только на Linux")
}

func chownLikeDir(string) error { return nil }
