package wbstream

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestDescriptorDescribesWBStreamConferenceRoomHandoff(t *testing.T) {
	descriptor := New().Descriptor()

	if descriptor.ID != providerName {
		t.Fatalf("descriptor.ID = %q, want %q", descriptor.ID, providerName)
	}
	if descriptor.InputKind != provider.ProviderInputKindLink {
		t.Fatalf("descriptor.InputKind = %q, want %q", descriptor.InputKind, provider.ProviderInputKindLink)
	}
	if descriptor.AuthPosture != provider.ProviderAuthPostureGuestOrAccount {
		t.Fatalf("descriptor.AuthPosture = %q, want %q", descriptor.AuthPosture, provider.ProviderAuthPostureGuestOrAccount)
	}
	if descriptor.BrowserPolicy != provider.ProviderBrowserPolicyExternalRequired {
		t.Fatalf("descriptor.BrowserPolicy = %q, want %q", descriptor.BrowserPolicy, provider.ProviderBrowserPolicyExternalRequired)
	}
	if len(descriptor.ChallengeModes) != 0 {
		t.Fatalf("descriptor.ChallengeModes = %#v, want none for external open-room handoff", descriptor.ChallengeModes)
	}
	if len(descriptor.ArtifactFamilies) != 1 || descriptor.ArtifactFamilies[0] != provider.ArtifactFamilyConferenceRoom {
		t.Fatalf("descriptor.ArtifactFamilies = %#v, want [%q]", descriptor.ArtifactFamilies, provider.ArtifactFamilyConferenceRoom)
	}
	if len(descriptor.CapabilityHints.PotentialActions) != 1 ||
		descriptor.CapabilityHints.PotentialActions[0] != provider.ArtifactActionOpenRoom {
		t.Fatalf("descriptor.CapabilityHints.PotentialActions = %#v, want [open_room]", descriptor.CapabilityHints.PotentialActions)
	}
	if descriptor.CapabilityHints.RedactionPolicy != provider.SummaryOnlyArtifactRedactionPolicy() {
		t.Fatalf("descriptor.CapabilityHints.RedactionPolicy = %#v, want summary-only policy", descriptor.CapabilityHints.RedactionPolicy)
	}
}

func TestResolveAcceptedRoomLinks(t *testing.T) {
	adapter := New()
	testCases := []struct {
		name           string
		link           string
		wantRoomURL    string
		wantRedacted   string
		wantPathShape  string
		wantExtractURL string
	}{
		{
			name:           "rooms path",
			link:           "https://stream.wb.ru/rooms/team-sync",
			wantRoomURL:    "https://stream.wb.ru/rooms/team-sync",
			wantRedacted:   "https://stream.wb.ru/rooms/<redacted:wb-stream-room-link>",
			wantPathShape:  "/rooms/<redacted:wb-stream-room-link>",
			wantExtractURL: "https://stream.wb.ru/rooms/team-sync",
		},
		{
			name:           "uppercase host and meeting path",
			link:           "https://STREAM.WB.RU/Meeting/ABC_123",
			wantRoomURL:    "https://stream.wb.ru/meeting/ABC_123",
			wantRedacted:   "https://stream.wb.ru/meeting/<redacted:wb-stream-room-link>",
			wantPathShape:  "/meeting/<redacted:wb-stream-room-link>",
			wantExtractURL: "https://stream.wb.ru/meeting/ABC_123",
		},
		{
			name:           "join path",
			link:           " https://stream.wb.ru/join/guest-123 ",
			wantRoomURL:    "https://stream.wb.ru/join/guest-123",
			wantRedacted:   "https://stream.wb.ru/join/<redacted:wb-stream-room-link>",
			wantPathShape:  "/join/<redacted:wb-stream-room-link>",
			wantExtractURL: "https://stream.wb.ru/join/guest-123",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			resolution, err := adapter.Resolve(context.Background(), tc.link)
			if err != nil {
				t.Fatalf("Resolve() error = %v", err)
			}
			if resolution.Credentials != (provider.Credentials{}) {
				t.Fatalf("resolution credentials = %#v, want empty for conference_room", resolution.Credentials)
			}
			if got := resolution.Metadata["provider"]; got != providerName {
				t.Fatalf("metadata provider = %q, want %q", got, providerName)
			}
			if got := resolution.Metadata["resolution_method"]; got != resolutionMethod {
				t.Fatalf("metadata resolution_method = %q, want %q", got, resolutionMethod)
			}
			if resolution.Artifact == nil {
				t.Fatal("resolution artifact = nil, want conference_room artifact")
			}
			if resolution.Artifact.Provider != providerName {
				t.Fatalf("artifact provider = %q, want %q", resolution.Artifact.Provider, providerName)
			}
			if resolution.Artifact.Outcome.ResultKind != string(provider.ArtifactFamilyConferenceRoom) {
				t.Fatalf("artifact result_kind = %q, want conference_room", resolution.Artifact.Outcome.ResultKind)
			}
			if resolution.Artifact.Outcome.Resolution != nil {
				t.Fatalf("artifact generic TURN resolution = %#v, want nil", resolution.Artifact.Outcome.Resolution)
			}
			if resolution.Artifact.Outcome.ConferenceRoom == nil {
				t.Fatal("artifact conference_room = nil, want room summary")
			}
			if got := resolution.Artifact.Outcome.ConferenceRoom.RoomURL; got != tc.wantRoomURL {
				t.Fatalf("room_url = %q, want %q", got, tc.wantRoomURL)
			}
			if got := resolution.Artifact.Input.LinkRedacted; got != tc.wantRedacted {
				t.Fatalf("input.link_redacted = %q, want %q", got, tc.wantRedacted)
			}
			if len(resolution.Artifact.Stages) != 1 {
				t.Fatalf("artifact stages len = %d, want 1", len(resolution.Artifact.Stages))
			}
			stage := resolution.Artifact.Stages[0]
			if stage.Name != stageRoomLink || stage.EndpointID != stageRoomLink {
				t.Fatalf("stage = %#v, want wb_stream_room_link", stage)
			}
			if stage.Request.Method != methodParse {
				t.Fatalf("stage method = %q, want %q", stage.Request.Method, methodParse)
			}
			if got := stage.Response.Body["path_shape"]; got != tc.wantPathShape {
				t.Fatalf("stage path_shape = %#v, want %q", got, tc.wantPathShape)
			}
			if got := stage.Outcome.Extracted["normalized_room_url"]; got != tc.wantExtractURL {
				t.Fatalf("normalized_room_url = %#v, want %q", got, tc.wantExtractURL)
			}
		})
	}
}

func TestResolveRejectsUnsupportedRoomLinksFailClosed(t *testing.T) {
	adapter := New()
	testCases := []struct {
		name string
		link string
		want string
	}{
		{name: "empty", link: "", want: "empty input"},
		{name: "http", link: "http://stream.wb.ru/rooms/team-sync", want: "https scheme is required"},
		{name: "wrong host", link: "https://example.test/rooms/team-sync", want: "host must be stream.wb.ru"},
		{name: "userinfo", link: "https://user:password-secret@stream.wb.ru/rooms/team-sync", want: "userinfo is not supported"},
		{name: "port", link: "https://stream.wb.ru:443/rooms/team-sync", want: "explicit ports are not supported"},
		{name: "root", link: "https://stream.wb.ru/", want: "room path is required"},
		{name: "unsupported prefix", link: "https://stream.wb.ru/archive/team-sync", want: "unsupported room path prefix"},
		{name: "short slug", link: "https://stream.wb.ru/rooms/ab", want: "unsupported room identifier shape"},
		{name: "extra path", link: "https://stream.wb.ru/rooms/team-sync/extra", want: "expected /rooms/{room} style path"},
		{name: "query", link: "https://stream.wb.ru/rooms/team-sync?token=token-secret", want: "query is not supported"},
		{name: "fragment", link: "https://stream.wb.ru/rooms/team-sync#token-secret", want: "fragment is not supported"},
		{name: "escaped slash", link: "https://stream.wb.ru/rooms/team%2Fsecret", want: "unsupported room identifier shape"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := adapter.Resolve(context.Background(), tc.link)
			if err == nil {
				t.Fatal("Resolve() expected error")
			}
			if !strings.Contains(err.Error(), "invalid wb-stream room link:") {
				t.Fatalf("error = %q, want invalid wb-stream room link", err)
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("error = %q, want reason %q", err, tc.want)
			}

			var artifactErr *provider.ArtifactError
			if !errors.As(err, &artifactErr) {
				t.Fatalf("error = %T, want ArtifactError", err)
			}
			artifact := artifactErr.Artifact()
			if artifact == nil {
				t.Fatal("ArtifactError artifact = nil, want provider error artifact")
			}
			if artifact.Outcome.ProviderError == nil {
				t.Fatal("artifact provider_error = nil, want explicit provider error")
			}
			if artifact.Outcome.ProviderError.Stage != stageRoomLink {
				t.Fatalf("provider_error.stage = %q, want %q", artifact.Outcome.ProviderError.Stage, stageRoomLink)
			}
			if artifact.Outcome.ProviderError.Code != "invalid_room_link" {
				t.Fatalf("provider_error.code = %q, want invalid_room_link", artifact.Outcome.ProviderError.Code)
			}
			data, marshalErr := json.Marshal(artifact)
			if marshalErr != nil {
				t.Fatalf("Marshal(artifact) error = %v", marshalErr)
			}
			text := string(data)
			for _, secret := range []string{"token-secret", "password-secret", "team%2Fsecret"} {
				if strings.Contains(text, secret) {
					t.Fatalf("artifact leaked %q: %s", secret, text)
				}
			}
		})
	}
}
