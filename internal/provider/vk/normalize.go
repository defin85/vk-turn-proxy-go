package vk

import (
	"errors"
	"fmt"
	"net/url"
	"strings"
)

type inputFamily string

const (
	inputFamilyInvite            inputFamily = "invite"
	inputFamilyAuthenticatedRoot inputFamily = "authenticated_root"
)

type normalizedInput struct {
	family         inputFamily
	normalizedLink string
	joinToken      string
}

func normalizeInput(link string) (normalizedInput, error) {
	trimmed := strings.TrimSpace(link)
	if trimmed == "" {
		return normalizedInput{}, errors.New("invalid vk link: empty input")
	}

	lower := strings.ToLower(trimmed)
	if strings.HasPrefix(lower, "vk.com/") ||
		strings.HasPrefix(lower, "www.vk.com/") ||
		strings.HasPrefix(lower, "calls.vk.com/") {
		trimmed = "https://" + trimmed
		lower = strings.ToLower(trimmed)
	}

	if strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://") {
		parsed, err := url.Parse(trimmed)
		if err != nil {
			return normalizedInput{}, fmt.Errorf("invalid vk link: %w", err)
		}

		host := strings.ToLower(parsed.Hostname())
		switch host {
		case "vk.com", "www.vk.com":
			parts := strings.Split(strings.Trim(parsed.Path, "/"), "/")
			if len(parts) < 3 || parts[0] != "call" || parts[1] != "join" {
				return normalizedInput{}, fmt.Errorf("invalid vk link: expected path /call/join/<token>, got %q", parsed.Path)
			}

			token := strings.TrimSpace(parts[2])
			if token == "" {
				return normalizedInput{}, errors.New("invalid vk link: missing join token")
			}

			return normalizedInput{
				family:         inputFamilyInvite,
				normalizedLink: "https://vk.com/call/join/" + token,
				joinToken:      token,
			}, nil
		case "calls.vk.com":
			path := strings.TrimSpace(parsed.EscapedPath())
			if path != "" && path != "/" {
				return normalizedInput{}, fmt.Errorf("invalid vk link: unsupported calls.vk.com path %q", parsed.Path)
			}
			if strings.TrimSpace(parsed.RawQuery) != "" || strings.TrimSpace(parsed.Fragment) != "" {
				return normalizedInput{}, fmt.Errorf("invalid vk link: unsupported calls.vk.com root parameters in %q", trimmed)
			}
			return normalizedInput{
				family:         inputFamilyAuthenticatedRoot,
				normalizedLink: authenticatedHostedCallRootURL,
			}, nil
		default:
			return normalizedInput{}, fmt.Errorf("invalid vk link: unsupported host %q", host)
		}
	}

	token := trimmed
	if idx := strings.IndexAny(token, "/?#"); idx != -1 {
		token = token[:idx]
	}
	token = strings.TrimSpace(token)
	if token == "" || strings.ContainsAny(token, " \t\r\n") {
		return normalizedInput{}, fmt.Errorf("invalid vk link: %q", link)
	}

	return normalizedInput{
		family:         inputFamilyInvite,
		normalizedLink: "https://vk.com/call/join/" + token,
		joinToken:      token,
	}, nil
}

func normalizeJoinToken(link string) (string, error) {
	input, err := normalizeInput(link)
	if err != nil {
		return "", err
	}
	if input.family != inputFamilyInvite {
		return "", fmt.Errorf("invalid vk link: expected vk.com invite path, got %q", input.normalizedLink)
	}
	return input.joinToken, nil
}
