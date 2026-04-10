package genericturn

import (
	"fmt"
	"net/url"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func FormatLink(credentials provider.Credentials) string {
	if credentials.Username == "" || credentials.Password == "" || credentials.Address == "" {
		return ""
	}
	return (&url.URL{
		Scheme: providerName,
		User:   url.UserPassword(credentials.Username, credentials.Password),
		Host:   credentials.Address,
	}).String()
}

func RedactedLink(address string) string {
	if address == "" {
		return ""
	}
	return fmt.Sprintf("%s://%s:%s@%s", providerName, placeholderUsername, placeholderPassword, address)
}

func RedactLink(raw string) string {
	_, _, _, artifact, err := parseLink(raw)
	if err != nil || artifact == nil {
		return ""
	}
	return artifact.Input.LinkRedacted
}
