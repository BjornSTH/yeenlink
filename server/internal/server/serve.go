package server

import (
	"context"
	"crypto/tls"
	"errors"
	"net"
	"net/http"
	"time"
)

// Serve обслуживает ln до отмены ctx. TLS — свой слушатель поверх ln (если
// режим не proxy), чтобы сервер знал отданный сертификат каждого соединения
// для server_sig. Возвращает после корректной остановки.
func (s *Server) Serve(ctx context.Context, ln net.Listener) error {
	if s.tls.TLSConfig != nil {
		ln = tls.NewListener(ln, s.tls.TLSConfig)
	}
	hs := &http.Server{
		Handler:           s.Handler(),
		ConnContext:       s.tls.ConnContext,
		ConnState:         s.tls.ConnState,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
		ErrorLog:          nil,
	}
	errc := make(chan error, 1)
	go func() { errc <- hs.Serve(ln) }()
	select {
	case err := <-errc:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shut, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return hs.Shutdown(shut)
	}
}
