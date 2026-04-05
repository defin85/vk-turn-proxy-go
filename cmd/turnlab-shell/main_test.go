package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRunTurnlabShellPrintsDescriptorAndStops(t *testing.T) {
	stdout := tempFile(t, "turnlab-shell-stdout-*")
	defer stdout.Close()
	stderr := tempFile(t, "turnlab-shell-stderr-*")
	defer stderr.Close()

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan int, 1)
	go func() {
		done <- runTurnlabShell(ctx, stdout, stderr, nil)
	}()

	waitForFileContains(t, stdout.Name(), "provider=generic-turn")
	waitForFileContains(t, stdout.Name(), "peer_addr=127.0.0.1:")
	waitForFileContains(t, stdout.Name(), "link=generic-turn://")

	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Fatalf("runTurnlabShell() code = %d", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runTurnlabShell() did not stop after cancellation")
	}
}

func TestRunTurnlabShellEmitsJSONDescriptor(t *testing.T) {
	stdout := tempFile(t, "turnlab-shell-json-stdout-*")
	defer stdout.Close()
	stderr := tempFile(t, "turnlab-shell-json-stderr-*")
	defer stderr.Close()

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan int, 1)
	go func() {
		done <- runTurnlabShell(ctx, stdout, stderr, []string{"-json", "-allocation-lifetime", "2s"})
	}()

	waitForFileContains(t, stdout.Name(), "\"generic_turn_link\":")

	payload, err := os.ReadFile(stdout.Name())
	if err != nil {
		cancel()
		t.Fatalf("ReadFile(stdout): %v", err)
	}
	var descriptor shellDescriptor
	if err := json.Unmarshal(payload, &descriptor); err != nil {
		cancel()
		t.Fatalf("Unmarshal(stdout): %v", err)
	}
	if !strings.HasPrefix(descriptor.GenericTurnLink, "generic-turn://") {
		cancel()
		t.Fatalf("unexpected generic turn link %q", descriptor.GenericTurnLink)
	}
	if descriptor.PeerAddress == "" {
		cancel()
		t.Fatal("peer address is empty")
	}
	if descriptor.AllocationLifetimeMS != 2000 {
		cancel()
		t.Fatalf("allocation lifetime = %d, want 2000", descriptor.AllocationLifetimeMS)
	}

	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Fatalf("runTurnlabShell() code = %d", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runTurnlabShell() did not stop after cancellation")
	}
}

func TestRunTurnlabShellPrintsExplicitBindAndAdvertiseAddresses(t *testing.T) {
	stdout := tempFile(t, "turnlab-shell-addresses-stdout-*")
	defer stdout.Close()
	stderr := tempFile(t, "turnlab-shell-addresses-stderr-*")
	defer stderr.Close()

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan int, 1)
	go func() {
		done <- runTurnlabShell(ctx, stdout, stderr, []string{
			"-bind-address", "0.0.0.0",
			"-advertise-address", "127.0.0.1",
		})
	}()

	waitForFileContains(t, stdout.Name(), "bind_addr=0.0.0.0")
	waitForFileContains(t, stdout.Name(), "advertise_addr=127.0.0.1")
	waitForFileContains(t, stdout.Name(), "peer_addr=127.0.0.1:")
	waitForFileContains(t, stdout.Name(), "link=generic-turn://turn-lab-user:turn-lab-pass@127.0.0.1:")

	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Fatalf("runTurnlabShell() code = %d", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runTurnlabShell() did not stop after cancellation")
	}
}

func TestResolveTurnlabOptionsUsesDetectedAddressForWindowsGUI(t *testing.T) {
	opts, bindAddress, advertiseAddress, err := resolveTurnlabOptions(shellConfig{
		windowsGUI: true,
	}, func() (string, error) {
		return "172.29.240.1", nil
	})
	if err != nil {
		t.Fatalf("resolveTurnlabOptions() error = %v", err)
	}
	if got, want := bindAddress, "172.29.240.1"; got != want {
		t.Fatalf("bindAddress = %q, want %q", got, want)
	}
	if got, want := advertiseAddress, "172.29.240.1"; got != want {
		t.Fatalf("advertiseAddress = %q, want %q", got, want)
	}
	if got, want := opts.BindAddress, "172.29.240.1"; got != want {
		t.Fatalf("opts.BindAddress = %q, want %q", got, want)
	}
	if got, want := opts.AdvertiseAddress, "172.29.240.1"; got != want {
		t.Fatalf("opts.AdvertiseAddress = %q, want %q", got, want)
	}
}

func TestResolveTurnlabOptionsPreservesExplicitBindWithWindowsGUI(t *testing.T) {
	opts, bindAddress, advertiseAddress, err := resolveTurnlabOptions(shellConfig{
		windowsGUI:  true,
		bindAddress: "0.0.0.0",
	}, func() (string, error) {
		return "172.29.240.1", nil
	})
	if err != nil {
		t.Fatalf("resolveTurnlabOptions() error = %v", err)
	}
	if got, want := bindAddress, "0.0.0.0"; got != want {
		t.Fatalf("bindAddress = %q, want %q", got, want)
	}
	if got, want := advertiseAddress, "172.29.240.1"; got != want {
		t.Fatalf("advertiseAddress = %q, want %q", got, want)
	}
	if got, want := opts.BindAddress, "0.0.0.0"; got != want {
		t.Fatalf("opts.BindAddress = %q, want %q", got, want)
	}
	if got, want := opts.AdvertiseAddress, "172.29.240.1"; got != want {
		t.Fatalf("opts.AdvertiseAddress = %q, want %q", got, want)
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

func waitForFileContains(t *testing.T, path string, want string) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		payload, err := os.ReadFile(path)
		if err == nil && strings.Contains(string(payload), want) {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	payload, _ := os.ReadFile(path)
	t.Fatalf("timed out waiting for %q in %s; got %q", want, path, string(payload))
}
