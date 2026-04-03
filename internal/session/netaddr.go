package session

import (
	"fmt"
	"net"
)

func netSplitHostPort(address string) (string, string, error) {
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return "", "", fmt.Errorf("parse turn address %q: %w", address, err)
	}

	return host, port, nil
}

func netJoinHostPort(host string, port string) (string, error) {
	if host == "" {
		return "", fmt.Errorf("override turn address is missing host")
	}
	if port == "" {
		return "", fmt.Errorf("override turn address is missing port")
	}

	return net.JoinHostPort(host, port), nil
}
