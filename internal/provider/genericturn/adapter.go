package genericturn

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	providerName      = "generic-turn"
	stageStaticLink   = "generic_turn_static_link"
	methodStaticParse = "PARSE"

	placeholderUsername = "<redacted:turn-username>"
	placeholderPassword = "<redacted:turn-password>"
)

type Adapter struct{}

func New() *Adapter {
	return &Adapter{}
}

func (a *Adapter) Name() string {
	return providerName
}

func (a *Adapter) Resolve(_ context.Context, link string) (provider.Resolution, error) {
	username, password, address, artifact, err := parseLink(link)
	if err != nil {
		return provider.Resolution{}, err
	}

	return provider.Resolution{
		Credentials: provider.Credentials{
			Username: username,
			Password: password,
			Address:  address,
		},
		Metadata: map[string]string{
			"provider":          providerName,
			"resolution_method": "static_link",
		},
		Artifact: artifact,
	}, nil
}

func parseLink(raw string) (string, string, string, *provider.ProbeArtifact, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", "", "", nil, invalidLink("empty input")
	}

	parsed, err := url.Parse(trimmed)
	if err != nil {
		return "", "", "", nil, invalidLink(err.Error())
	}
	if parsed.Scheme != providerName {
		return "", "", "", nil, invalidLink(fmt.Sprintf("expected scheme %q", providerName))
	}
	if parsed.Path != "" {
		return "", "", "", nil, invalidLink("path is not supported")
	}
	if parsed.RawQuery != "" {
		return "", "", "", nil, invalidLink("query is not supported")
	}
	if parsed.Fragment != "" {
		return "", "", "", nil, invalidLink("fragment is not supported")
	}
	if parsed.User == nil {
		return "", "", "", nil, invalidLink("missing username")
	}

	username := strings.TrimSpace(parsed.User.Username())
	if username == "" {
		return "", "", "", nil, invalidLink("missing username")
	}
	password, ok := parsed.User.Password()
	if !ok || strings.TrimSpace(password) == "" {
		return "", "", "", nil, invalidLink("missing password")
	}

	host := strings.TrimSpace(parsed.Hostname())
	if host == "" {
		return "", "", "", nil, invalidLink("missing host")
	}
	port := strings.TrimSpace(parsed.Port())
	if port == "" {
		return "", "", "", nil, invalidLink("missing port")
	}
	portNumber, err := strconv.Atoi(port)
	if err != nil || portNumber <= 0 || portNumber > 65535 {
		return "", "", "", nil, invalidLink("invalid port")
	}

	address := net.JoinHostPort(host, port)

	return username, password, address, buildArtifact(host, port, address), nil
}

func buildArtifact(host string, port string, address string) *provider.ProbeArtifact {
	return &provider.ProbeArtifact{
		Provider:         providerName,
		ResolutionMethod: "static_link",
		Input: provider.ProbeArtifactInput{
			LinkRedacted: fmt.Sprintf("%s://%s:%s@%s", providerName, placeholderUsername, placeholderPassword, net.JoinHostPort(host, port)),
		},
		Stages: []provider.ProbeArtifactStage{
			{
				Name:       stageStaticLink,
				EndpointID: stageStaticLink,
				Request: provider.ProbeArtifactStageRequest{
					Method:         methodStaticParse,
					FormKeys:       []string{"username", "password", "host", "port"},
					RedactedFields: []string{"username", "password"},
				},
				Response: provider.ProbeArtifactStageResponse{
					StatusCode: 0,
					Body: map[string]any{
						"host": host,
						"port": port,
					},
				},
				Outcome: provider.ProbeArtifactStageOutcome{
					Kind: "resolution",
					Extracted: map[string]any{
						"username":           placeholderUsername,
						"password":           placeholderPassword,
						"normalized_address": address,
					},
				},
			},
		},
		Outcome: provider.ProbeArtifactOutcome{
			ResultKind: "resolution",
			Resolution: &provider.ProbeArtifactResolution{
				UsernameRedacted: placeholderUsername,
				PasswordRedacted: placeholderPassword,
				Address:          address,
			},
		},
	}
}

func invalidLink(reason string) error {
	return fmt.Errorf("invalid generic-turn link: %s", reason)
}
