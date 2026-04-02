package vk

import (
	"errors"
	"fmt"
	"net/url"
	"strings"
)

func normalizeJoinToken(link string) (string, error) {
	trimmed := strings.TrimSpace(link)
	if trimmed == "" {
		return "", errors.New("invalid vk link: empty input")
	}

	lower := strings.ToLower(trimmed)
	if strings.HasPrefix(lower, "vk.com/") || strings.HasPrefix(lower, "www.vk.com/") {
		trimmed = "https://" + trimmed
		lower = strings.ToLower(trimmed)
	}

	if strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://") {
		parsed, err := url.Parse(trimmed)
		if err != nil {
			return "", fmt.Errorf("invalid vk link: %w", err)
		}

		host := strings.ToLower(parsed.Hostname())
		if host != "vk.com" && host != "www.vk.com" {
			return "", fmt.Errorf("invalid vk link: unsupported host %q", host)
		}

		parts := strings.Split(strings.Trim(parsed.Path, "/"), "/")
		if len(parts) < 3 || parts[0] != "call" || parts[1] != "join" {
			return "", fmt.Errorf("invalid vk link: expected path /call/join/<token>, got %q", parsed.Path)
		}

		token := strings.TrimSpace(parts[2])
		if token == "" {
			return "", errors.New("invalid vk link: missing join token")
		}

		return token, nil
	}

	token := trimmed
	if idx := strings.IndexAny(token, "/?#"); idx != -1 {
		token = token[:idx]
	}
	token = strings.TrimSpace(token)
	if token == "" || strings.ContainsAny(token, " \t\r\n") {
		return "", fmt.Errorf("invalid vk link: %q", link)
	}

	return token, nil
}
