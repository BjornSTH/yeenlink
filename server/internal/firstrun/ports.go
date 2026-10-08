// Package firstrun — проверки первого запуска: свободные порты.
package firstrun

import (
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"syscall"
)

// Port — что проверяли и что вышло.
type Port struct {
	Proto, Addr, Purpose string
	Required             bool
	Status               string // free | busy | denied | error
	Err                  error
}

// CheckPorts пробует занять порты сервера (docs/spec.md, «Порты»): API,
// HTTP-01, голос UDP 7882 и TCP 7881. Ничего не держит — сразу отпускает.
func CheckPorts(listen string, httpPort int) []Port {
	ports := []Port{{Proto: "tcp", Addr: listen, Purpose: "API и WebSocket", Required: true}}
	if httpPort > 0 {
		ports = append(ports, Port{Proto: "tcp", Addr: ":" + strconv.Itoa(httpPort), Purpose: "Let's Encrypt HTTP-01"})
	}
	ports = append(ports,
		Port{Proto: "udp", Addr: ":7882", Purpose: "голос и видео (фаза 5)", Required: true},
		Port{Proto: "tcp", Addr: ":7881", Purpose: "медиа по TCP (фаза 5)"},
	)
	for i := range ports {
		p := &ports[i]
		var err error
		if p.Proto == "udp" {
			var c net.PacketConn
			if c, err = net.ListenPacket("udp", p.Addr); err == nil {
				_ = c.Close()
			}
		} else {
			var l net.Listener
			if l, err = net.Listen("tcp", p.Addr); err == nil {
				_ = l.Close()
			}
		}
		p.Err = err
		switch {
		case err == nil:
			p.Status = "free"
		case errors.Is(err, syscall.EADDRINUSE):
			p.Status = "busy"
		case errors.Is(err, syscall.EACCES) || errors.Is(err, os.ErrPermission):
			p.Status = "denied"
		default:
			p.Status = "error"
		}
	}
	return ports
}

// Describe — строка для человека.
func (p Port) Describe() string {
	what := map[string]string{
		"free":   "свободен",
		"busy":   "занят другой программой",
		"denied": "нет прав: нужен root или CAP_NET_BIND_SERVICE",
		"error":  "ошибка",
	}[p.Status]
	req := ""
	if p.Required {
		req = " (обязателен)"
	}
	s := fmt.Sprintf("%s %-8s %-28s %s%s", p.Proto, p.Addr, p.Purpose, what, req)
	if p.Status == "error" && p.Err != nil {
		s += ": " + p.Err.Error()
	}
	return s
}
