package main

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func TestRunSkipNetworkTextOutput(t *testing.T) {
	t.Parallel()

	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	exitCode := run(context.Background(), stdout, stderr, []string{
		"-link", "generic-turn://1712745600%3Aalice:s3cret@turn.example.test:3478",
		"-skip-network",
	})
	if exitCode != 0 {
		t.Fatalf("run() exitCode = %d, want 0, stderr=%s", exitCode, stderr.String())
	}

	output := stdout.String()
	if !strings.Contains(output, "username_format=timestamp_username") {
		t.Fatalf("stdout missing username_format, got %q", output)
	}
	if !strings.Contains(output, "candidate_expiry=2024-04-10T10:40:00Z") {
		t.Fatalf("stdout missing candidate_expiry, got %q", output)
	}
	if !strings.Contains(output, "allocate_now=skipped") {
		t.Fatalf("stdout missing allocate_now=skipped, got %q", output)
	}
}

func TestRunSkipNetworkJSONOutput(t *testing.T) {
	t.Parallel()

	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	exitCode := run(context.Background(), stdout, stderr, []string{
		"-link", "generic-turn://1712745600:s3cret@turn.example.test:3478",
		"-skip-network",
		"-json",
	})
	if exitCode != 0 {
		t.Fatalf("run() exitCode = %d, want 0, stderr=%s", exitCode, stderr.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(stdout.Bytes(), &payload); err != nil {
		t.Fatalf("json.Unmarshal() error = %v, stdout=%s", err, stdout.String())
	}
	if got := payload["username_format"]; got != "timestamp_only" {
		t.Fatalf("payload[username_format] = %#v, want %q", got, "timestamp_only")
	}
	allocateNow, ok := payload["allocate_now"].(map[string]any)
	if !ok {
		t.Fatalf("payload[allocate_now] = %#v, want object", payload["allocate_now"])
	}
	if got := allocateNow["attempted"]; got != false {
		t.Fatalf("payload[allocate_now][attempted] = %#v, want false", got)
	}
}

func TestRunRejectsMissingLink(t *testing.T) {
	t.Parallel()

	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	exitCode := run(context.Background(), stdout, stderr, []string{"-skip-network"})
	if exitCode != 2 {
		t.Fatalf("run() exitCode = %d, want 2", exitCode)
	}
}
