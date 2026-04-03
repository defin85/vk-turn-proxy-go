package session

import "strings"

func applyTURNOverrides(creds string, hostOverride string, portOverride string) (string, error) {
	host, port, err := netSplitHostPort(creds)
	if err != nil {
		return "", err
	}
	if trimmed := strings.TrimSpace(hostOverride); trimmed != "" {
		host = trimmed
	}
	if trimmed := strings.TrimSpace(portOverride); trimmed != "" {
		port = trimmed
	}

	return netJoinHostPort(host, port)
}
