package main

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestValidateLoopbackListen(t *testing.T) {
	for _, addr := range []string{"127.0.0.1:7777", "localhost:7777", "[::1]:7777"} {
		if err := validateLoopbackListen(addr); err != nil {
			t.Fatalf("validateLoopbackListen(%q) error = %v", addr, err)
		}
	}
	if err := validateLoopbackListen("0.0.0.0:7777"); err == nil {
		t.Fatal("expected non-loopback validation error")
	}
}

func TestRunClientdServesHostInfo(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve listen addr: %v", err)
	}
	addr := listener.Addr().String()
	listener.Close()

	stdout := tempFile(t, "clientd-stdout-*")
	defer stdout.Close()
	stderr := tempFile(t, "clientd-stderr-*")
	defer stderr.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan int, 1)
	go func() {
		done <- runClientd(ctx, stdout, stderr, []string{"-listen", addr})
	}()

	var info clientcontrol.HostInfo
	deadline := time.After(3 * time.Second)
	for {
		resp, err := http.Get("http://" + addr + "/v1/host")
		if err == nil {
			decodeErr := json.NewDecoder(resp.Body).Decode(&info)
			resp.Body.Close()
			if decodeErr != nil {
				t.Fatalf("decode /v1/host: %v", decodeErr)
			}
			break
		}
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for clientd: %v", err)
		case <-time.After(20 * time.Millisecond):
		}
	}
	if info.Version != clientcontrol.ContractVersion {
		t.Fatalf("version = %q, want %q", info.Version, clientcontrol.ContractVersion)
	}

	cancel()
	select {
	case code := <-done:
		if code != 0 {
			t.Fatalf("runClientd() code = %d", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runClientd() did not stop after cancellation")
	}
}

func tempFile(t *testing.T, pattern string) *os.File {
	t.Helper()
	dir := t.TempDir()
	file, err := os.CreateTemp(dir, pattern)
	if err != nil {
		t.Fatalf("CreateTemp(%q) error = %v", filepath.Join(dir, pattern), err)
	}
	return file
}
