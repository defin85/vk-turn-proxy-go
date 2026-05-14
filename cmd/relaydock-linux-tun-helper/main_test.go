package main

import (
	"bytes"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/linuxtunhelper"
)

func TestHelperCommandRejectsUnknownCommand(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	code := linuxtunhelper.Run(strings.NewReader(`{}`), &stdout, &stderr, []string{"serve"})

	if code == 0 {
		t.Fatal("runForTest() code = 0, want usage failure")
	}
	if !strings.Contains(stdout.String(), "unknown command") {
		t.Fatalf("stdout = %q, want unknown command response", stdout.String())
	}
}
