package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSaveLoadRoundTrip(t *testing.T) {
	p := filepath.Join(t.TempDir(), "ylsrv.toml")
	c := Default()
	c.Name, c.Host, c.TLS.Mode = "Логово", "203.0.113.7", TLSSelfSigned
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
	if err := Save(p, c); err != nil {
		t.Fatal(err)
	}
	if st, _ := os.Stat(p); st.Mode().Perm() != 0o600 {
		t.Fatalf("права %v", st.Mode().Perm())
	}
	got, err := Load(p)
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != c.Name || got.Host != c.Host || got.TLS.Mode != c.TLS.Mode || got.Listen != c.Listen {
		t.Fatalf("%+v", got)
	}
}

func TestUnknownKeyRejected(t *testing.T) {
	p := filepath.Join(t.TempDir(), "ylsrv.toml")
	if err := os.WriteFile(p, []byte("name = \"x\"\nlisten_addr = \":443\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(p); err == nil || !strings.Contains(err.Error(), "listen_addr") {
		t.Fatalf("опечатка в ключе не замечена: %v", err)
	}
}

func TestValidate(t *testing.T) {
	cases := []struct {
		name string
		edit func(*Config)
		ok   bool
	}{
		{"acme с доменом", func(c *Config) { c.Host = "chat.example.org" }, true},
		{"acme с IP", func(c *Config) { c.Host = "203.0.113.7" }, false},
		{"file без путей", func(c *Config) { c.TLS.Mode = TLSFile }, false},
		{"proxy", func(c *Config) { c.TLS.Mode = TLSProxy; c.Listen = "127.0.0.1:8080" }, true},
		{"без имени", func(c *Config) { c.Name = " "; c.Host = "chat.example.org" }, false},
		{"плохой codec", func(c *Config) { c.Host = "chat.example.org"; c.Codec = "xml" }, false},
	}
	for _, tc := range cases {
		c := Default()
		c.Name = "Логово"
		tc.edit(&c)
		if err := c.Validate(); (err == nil) != tc.ok {
			t.Errorf("%s: %v", tc.name, err)
		}
	}
}
