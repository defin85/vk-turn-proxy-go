package wbstream

import (
	"context"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	providerName       = "wb-stream"
	roomHost           = "stream.wb.ru"
	stageRoomLink      = "wb_stream_room_link"
	methodParse        = "PARSE"
	resolutionMethod   = "room_link"
	redactedRoomID     = "<redacted:wb-stream-room-link>"
	redactedRoomTarget = "https://stream.wb.ru/rooms/<redacted:wb-stream-room-link>"
)

var roomSlugPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{2,127}$`)

type Adapter struct{}

func New() *Adapter {
	return &Adapter{}
}

func (a *Adapter) Name() string {
	return providerName
}

func (a *Adapter) Descriptor() provider.ProviderDescriptor {
	return provider.ProviderDescriptor{
		ID:            providerName,
		DisplayName:   "WB Stream",
		Description:   "WB Stream room-link handoff that resolves supported stream.wb.ru meeting URLs into an external conference-room open action.",
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureGuestOrAccount,
		BrowserPolicy: provider.ProviderBrowserPolicyExternalRequired,
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyConferenceRoom,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			PotentialActions: []provider.ArtifactAction{
				provider.ArtifactActionOpenRoom,
			},
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

func (a *Adapter) Resolve(_ context.Context, link string) (provider.Resolution, error) {
	normalized, prefix, err := normalizeRoomLink(link)
	if err != nil {
		return provider.Resolution{}, buildInvalidLinkError(err.Error())
	}

	return provider.Resolution{
		Metadata: map[string]string{
			"provider":          providerName,
			"resolution_method": resolutionMethod,
		},
		Artifact: buildRoomArtifact(normalized, prefix),
	}, nil
}

func normalizeRoomLink(raw string) (string, string, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", "", fmt.Errorf("empty input")
	}

	parsed, err := url.Parse(trimmed)
	if err != nil {
		return "", "", fmt.Errorf("malformed URL")
	}
	if parsed.Opaque != "" || !parsed.IsAbs() {
		return "", "", fmt.Errorf("absolute URL is required")
	}
	if !strings.EqualFold(parsed.Scheme, "https") {
		return "", "", fmt.Errorf("https scheme is required")
	}
	if parsed.User != nil {
		return "", "", fmt.Errorf("userinfo is not supported")
	}
	if !strings.EqualFold(parsed.Hostname(), roomHost) {
		return "", "", fmt.Errorf("host must be %s", roomHost)
	}
	if parsed.Port() != "" {
		return "", "", fmt.Errorf("explicit ports are not supported")
	}
	if parsed.RawQuery != "" {
		return "", "", fmt.Errorf("query is not supported")
	}
	if parsed.Fragment != "" {
		return "", "", fmt.Errorf("fragment is not supported")
	}

	escapedPath := parsed.EscapedPath()
	if escapedPath == "" {
		escapedPath = parsed.Path
	}
	if escapedPath == "" || escapedPath == "/" {
		return "", "", fmt.Errorf("room path is required")
	}
	if strings.HasSuffix(escapedPath, "/") {
		return "", "", fmt.Errorf("trailing slash is not supported")
	}
	if strings.Contains(escapedPath, "//") {
		return "", "", fmt.Errorf("empty path segments are not supported")
	}

	segments := strings.Split(strings.TrimPrefix(escapedPath, "/"), "/")
	if len(segments) != 2 {
		return "", "", fmt.Errorf("expected /rooms/{room} style path")
	}
	prefix := strings.ToLower(segments[0])
	if !isSupportedRoomPrefix(prefix) {
		return "", "", fmt.Errorf("unsupported room path prefix")
	}
	slug := segments[1]
	if !roomSlugPattern.MatchString(slug) {
		return "", "", fmt.Errorf("unsupported room identifier shape")
	}

	normalized := (&url.URL{
		Scheme: "https",
		Host:   roomHost,
		Path:   "/" + prefix + "/" + slug,
	}).String()

	return normalized, prefix, nil
}

func isSupportedRoomPrefix(prefix string) bool {
	switch prefix {
	case "room", "rooms", "meeting", "meetings", "join":
		return true
	default:
		return false
	}
}

func buildRoomArtifact(roomURL string, prefix string) *provider.ProbeArtifact {
	redactedLink := redactedRoomLink(prefix)
	return &provider.ProbeArtifact{
		Provider:         providerName,
		ResolutionMethod: resolutionMethod,
		Input: provider.ProbeArtifactInput{
			LinkRedacted: redactedLink,
		},
		Stages: []provider.ProbeArtifactStage{
			{
				Name:       stageRoomLink,
				EndpointID: stageRoomLink,
				Request: provider.ProbeArtifactStageRequest{
					Method:         methodParse,
					FormKeys:       []string{"room_url"},
					RedactedFields: []string{"room_url"},
				},
				Response: provider.ProbeArtifactStageResponse{
					StatusCode: 0,
					Body: map[string]any{
						"host":       roomHost,
						"path_shape": "/" + prefix + "/" + redactedRoomID,
					},
				},
				Outcome: provider.ProbeArtifactStageOutcome{
					Kind: "conference_room",
					Extracted: map[string]any{
						"normalized_room_url": roomURL,
					},
				},
			},
		},
		Outcome: provider.ProbeArtifactOutcome{
			ResultKind: "conference_room",
			ConferenceRoom: &provider.ProbeArtifactConferenceRoom{
				RoomURL: roomURL,
			},
		},
	}
}

func buildInvalidLinkError(reason string) error {
	return &provider.ArtifactError{
		Err:           fmt.Errorf("invalid wb-stream room link: %s", reason),
		ProbeArtifact: buildInvalidLinkArtifact(reason),
	}
}

func buildInvalidLinkArtifact(reason string) *provider.ProbeArtifact {
	return &provider.ProbeArtifact{
		Provider:         providerName,
		ResolutionMethod: resolutionMethod,
		Input: provider.ProbeArtifactInput{
			LinkRedacted: redactedRoomTarget,
		},
		Stages: []provider.ProbeArtifactStage{
			{
				Name:       stageRoomLink,
				EndpointID: stageRoomLink,
				Request: provider.ProbeArtifactStageRequest{
					Method:         methodParse,
					FormKeys:       []string{"room_url"},
					RedactedFields: []string{"room_url"},
				},
				Response: provider.ProbeArtifactStageResponse{
					StatusCode: 0,
					Body: map[string]any{
						"error":  "invalid_room_link",
						"reason": reason,
					},
				},
				Outcome: provider.ProbeArtifactStageOutcome{
					Kind:      "provider_error",
					ErrorCode: "invalid_room_link",
				},
			},
		},
		Outcome: provider.ProbeArtifactOutcome{
			ResultKind: "provider_error",
			ProviderError: &provider.ProbeArtifactProviderError{
				Stage: stageRoomLink,
				Code:  "invalid_room_link",
			},
		},
	}
}

func redactedRoomLink(prefix string) string {
	prefix = strings.TrimSpace(strings.ToLower(prefix))
	if !isSupportedRoomPrefix(prefix) {
		prefix = "rooms"
	}
	return "https://" + roomHost + "/" + prefix + "/" + redactedRoomID
}
