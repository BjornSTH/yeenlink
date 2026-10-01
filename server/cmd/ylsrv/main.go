// Команда ylsrv — сервер YeenLink. В фазе 0 это каркас: разбор флагов и
// версия; WebSocket, хранилище и вход появятся в фазе 2 (docs/spec.md).
package main

import (
	"flag"
	"fmt"
	"os"

	"yeenlink/server/pkg/codec"
)

// version подставляется при сборке: -ldflags "-X main.version=…".
var version = "dev"

func main() {
	codecFlag := flag.String("codec", "cbor", "формат кадров: cbor или json (json — только для отладки)")
	showVersion := flag.Bool("version", false, "показать версию и выйти")
	flag.Parse()

	if *showVersion {
		fmt.Println("ylsrv", version)
		return
	}
	wire, err := codec.ParseWire(*codecFlag)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ylsrv:", err)
		os.Exit(2)
	}
	fmt.Fprintf(os.Stderr, "ylsrv %s: кадры %s. Сервер пока не умеет принимать подключения — это фаза 2.\n", version, wire)
}
