package genericturn

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func TestResolveValidStaticLink(t *testing.T) {
	adapter := New()

	resolution, err := adapter.Resolve(context.Background(), "generic-turn://alice:s3cret@turn.example.test:3478")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolution.Credentials.Username != "alice" {
		t.Fatalf("unexpected username %q", resolution.Credentials.Username)
	}
	if resolution.Credentials.Password != "s3cret" {
		t.Fatalf("unexpected password %q", resolution.Credentials.Password)
	}
	if resolution.Credentials.Address != "turn.example.test:3478" {
		t.Fatalf("unexpected address %q", resolution.Credentials.Address)
	}
	if got := resolution.Metadata["provider"]; got != providerName {
		t.Fatalf("unexpected provider metadata %q", got)
	}
	if got := resolution.Metadata["resolution_method"]; got != "static_link" {
		t.Fatalf("unexpected resolution method %q", got)
	}
	if resolution.Artifact == nil {
		t.Fatal("expected artifact")
	}
	if resolution.Artifact.Input.LinkRedacted != "generic-turn://<redacted:turn-username>:<redacted:turn-password>@turn.example.test:3478" {
		t.Fatalf("unexpected redacted link %q", resolution.Artifact.Input.LinkRedacted)
	}
	if len(resolution.Artifact.Stages) != 1 {
		t.Fatalf("unexpected stage count %d", len(resolution.Artifact.Stages))
	}
	if resolution.Artifact.Stages[0].Request.Method != methodStaticParse {
		t.Fatalf("unexpected stage method %q", resolution.Artifact.Stages[0].Request.Method)
	}
}

func TestResolveRejectsMalformedStaticLinks(t *testing.T) {
	adapter := New()
	testCases := []struct {
		name string
		link string
		want string
	}{
		{name: "empty", link: "", want: "empty input"},
		{name: "wrong scheme", link: "https://turn.example.test:3478", want: "expected scheme"},
		{name: "missing username", link: "generic-turn://:secret@turn.example.test:3478", want: "missing username"},
		{name: "missing password", link: "generic-turn://alice@turn.example.test:3478", want: "missing password"},
		{name: "missing host", link: "generic-turn://alice:secret@", want: "missing host"},
		{name: "missing port", link: "generic-turn://alice:secret@turn.example.test", want: "missing port"},
		{name: "invalid port", link: "generic-turn://alice:secret@turn.example.test:abc", want: "invalid port"},
		{name: "trailing slash", link: "generic-turn://alice:secret@turn.example.test:3478/", want: "path is not supported"},
		{name: "path segment", link: "generic-turn://alice:secret@turn.example.test:3478/extra", want: "path is not supported"},
		{name: "query", link: "generic-turn://alice:secret@turn.example.test:3478?debug=1", want: "query is not supported"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := adapter.Resolve(context.Background(), tc.link)
			if err == nil {
				t.Fatal("Resolve() expected error")
			}
			if !strings.Contains(err.Error(), "invalid generic-turn link:") {
				t.Fatalf("unexpected error %q", err)
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("expected error to contain %q, got %q", tc.want, err)
			}
		})
	}
}

func TestResolveArtifactRedactsCredentials(t *testing.T) {
	adapter := New()

	resolution, err := adapter.Resolve(context.Background(), "generic-turn://alice:s3cret@turn.example.test:3478")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	data, err := json.Marshal(resolution.Artifact)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}
	text := string(data)
	if strings.Contains(text, "alice") {
		t.Fatalf("artifact leaked username: %s", text)
	}
	if strings.Contains(text, "s3cret") {
		t.Fatalf("artifact leaked password: %s", text)
	}
	if got := resolution.Artifact.Outcome.Resolution.UsernameRedacted; got != placeholderUsername {
		t.Fatalf("unexpected redacted username %q", got)
	}
	if got := resolution.Artifact.Outcome.Resolution.PasswordRedacted; got != placeholderPassword {
		t.Fatalf("unexpected redacted password %q", got)
	}
	if got := resolution.Artifact.Stages[0].Outcome.Extracted["username"]; got != placeholderUsername {
		t.Fatalf("unexpected extracted username %#v", got)
	}
	if got := resolution.Artifact.Stages[0].Outcome.Extracted["password"]; got != placeholderPassword {
		t.Fatalf("unexpected extracted password %#v", got)
	}
}
