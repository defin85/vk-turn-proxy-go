package turnrest

import (
	"testing"
	"time"
)

func TestParseExpiryCandidateTimestampOnly(t *testing.T) {
	t.Parallel()

	candidate, ok := ParseExpiryCandidate("1712745600")
	if !ok {
		t.Fatal("ParseExpiryCandidate() ok=false, want true")
	}
	if candidate.Format != FormatTimestampOnly {
		t.Fatalf("candidate.Format = %q, want %q", candidate.Format, FormatTimestampOnly)
	}
	if candidate.Suffix != "" {
		t.Fatalf("candidate.Suffix = %q, want empty", candidate.Suffix)
	}
	if candidate.Expiry != time.Unix(1712745600, 0).UTC() {
		t.Fatalf("candidate.Expiry = %s, want %s", candidate.Expiry, time.Unix(1712745600, 0).UTC())
	}
}

func TestParseExpiryCandidateTimestampUsername(t *testing.T) {
	t.Parallel()

	candidate, ok := ParseExpiryCandidate("1712745600:alice")
	if !ok {
		t.Fatal("ParseExpiryCandidate() ok=false, want true")
	}
	if candidate.Format != FormatTimestampUsername {
		t.Fatalf("candidate.Format = %q, want %q", candidate.Format, FormatTimestampUsername)
	}
	if candidate.Suffix != "alice" {
		t.Fatalf("candidate.Suffix = %q, want %q", candidate.Suffix, "alice")
	}
}

func TestParseExpiryCandidateRejectsInvalidInput(t *testing.T) {
	t.Parallel()

	cases := []string{
		"",
		"alice",
		"99999999",
		"99999999999",
		"alice:1712745600",
		":alice",
	}

	for _, input := range cases {
		input := input
		t.Run(input, func(t *testing.T) {
			t.Parallel()
			if candidate, ok := ParseExpiryCandidate(input); ok {
				t.Fatalf("ParseExpiryCandidate(%q) = %+v, true, want false", input, candidate)
			}
		})
	}
}
