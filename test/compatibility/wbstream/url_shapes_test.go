package wbstream_test

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/wbstream"
)

type urlShapeFixture struct {
	Version  int    `json:"version"`
	Provider string `json:"provider"`
	Accepted []struct {
		ScenarioID        string `json:"scenario_id"`
		Input             string `json:"input"`
		NormalizedRoomURL string `json:"normalized_room_url"`
		RedactedLink      string `json:"redacted_link"`
	} `json:"accepted"`
	Rejected []struct {
		ScenarioID    string `json:"scenario_id"`
		Input         string `json:"input"`
		ProviderError struct {
			Stage string `json:"stage"`
			Code  string `json:"code"`
		} `json:"provider_error"`
		MustNotContain []string `json:"must_not_contain"`
	} `json:"rejected"`
}

func TestWBStreamURLShapeFixtures(t *testing.T) {
	paths, err := filepath.Glob(filepath.Join("fixtures", "*.json"))
	if err != nil {
		t.Fatalf("glob fixtures: %v", err)
	}
	if len(paths) == 0 {
		t.Fatal("no wbstream URL-shape fixtures found")
	}

	adapter := wbstream.New()
	for _, path := range paths {
		path := path
		t.Run(filepath.Base(path), func(t *testing.T) {
			data, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("read fixture: %v", err)
			}
			var fixture urlShapeFixture
			if err := json.Unmarshal(data, &fixture); err != nil {
				t.Fatalf("decode fixture: %v", err)
			}
			if fixture.Version != 1 {
				t.Fatalf("fixture version = %d, want 1", fixture.Version)
			}
			if fixture.Provider != "wb-stream" {
				t.Fatalf("fixture provider = %q, want wb-stream", fixture.Provider)
			}

			for _, scenario := range fixture.Accepted {
				scenario := scenario
				t.Run(scenario.ScenarioID, func(t *testing.T) {
					resolution, err := adapter.Resolve(context.Background(), scenario.Input)
					if err != nil {
						t.Fatalf("Resolve() error = %v", err)
					}
					if resolution.Artifact == nil {
						t.Fatal("resolution artifact = nil, want conference_room artifact")
					}
					if resolution.Artifact.Outcome.ConferenceRoom == nil {
						t.Fatal("conference_room outcome = nil, want room URL")
					}
					if got := resolution.Artifact.Outcome.ConferenceRoom.RoomURL; got != scenario.NormalizedRoomURL {
						t.Fatalf("room_url = %q, want %q", got, scenario.NormalizedRoomURL)
					}
					if got := resolution.Artifact.Input.LinkRedacted; got != scenario.RedactedLink {
						t.Fatalf("link_redacted = %q, want %q", got, scenario.RedactedLink)
					}
					if resolution.Credentials != (provider.Credentials{}) {
						t.Fatalf("credentials = %#v, want empty", resolution.Credentials)
					}
				})
			}

			for _, scenario := range fixture.Rejected {
				scenario := scenario
				t.Run(scenario.ScenarioID, func(t *testing.T) {
					_, err := adapter.Resolve(context.Background(), scenario.Input)
					if err == nil {
						t.Fatal("Resolve() expected provider error")
					}
					var artifactErr *provider.ArtifactError
					if !errors.As(err, &artifactErr) {
						t.Fatalf("Resolve() error = %T, want ArtifactError", err)
					}
					artifact := artifactErr.Artifact()
					if artifact == nil || artifact.Outcome.ProviderError == nil {
						t.Fatalf("artifact = %#v, want provider_error outcome", artifact)
					}
					if artifact.Outcome.ProviderError.Stage != scenario.ProviderError.Stage {
						t.Fatalf("provider_error.stage = %q, want %q", artifact.Outcome.ProviderError.Stage, scenario.ProviderError.Stage)
					}
					if artifact.Outcome.ProviderError.Code != scenario.ProviderError.Code {
						t.Fatalf("provider_error.code = %q, want %q", artifact.Outcome.ProviderError.Code, scenario.ProviderError.Code)
					}
					payload, err := json.Marshal(artifact)
					if err != nil {
						t.Fatalf("Marshal(artifact) error = %v", err)
					}
					for _, forbidden := range scenario.MustNotContain {
						if strings.Contains(string(payload), forbidden) {
							t.Fatalf("artifact leaked %q: %s", forbidden, payload)
						}
					}
				})
			}
		})
	}
}
