package wireguardprofile

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Profile struct {
	PrivateKey    string
	Addresses     []string
	DNSServers    []string
	MTU           int
	PeerPublicKey string
	AllowedIPs    []string
	Endpoint      string
}

func FileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func Load(path string) (*Profile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read WireGuard profile: %w", err)
	}
	return Parse(data, path)
}

func Parse(data []byte, source string) (*Profile, error) {
	source = strings.TrimSpace(source)
	if source == "" {
		source = "WireGuard profile"
	}
	profile := &Profile{MTU: 1280}
	section := ""
	for _, rawLine := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(rawLine)
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.ToLower(strings.TrimSpace(line[1 : len(line)-1]))
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.ToLower(strings.TrimSpace(key))
		value = strings.TrimSpace(value)
		switch section {
		case "interface":
			switch key {
			case "privatekey":
				profile.PrivateKey = value
			case "address":
				profile.Addresses = append(profile.Addresses, splitCSV(value)...)
			case "dns":
				profile.DNSServers = append(profile.DNSServers, splitCSV(value)...)
			case "mtu":
				if mtu, err := strconv.Atoi(value); err == nil && mtu > 0 {
					profile.MTU = mtu
				}
			}
		case "peer":
			switch key {
			case "publickey":
				profile.PeerPublicKey = value
			case "allowedips":
				profile.AllowedIPs = append(profile.AllowedIPs, splitCSV(value)...)
			case "endpoint":
				profile.Endpoint = value
			}
		}
	}
	if strings.TrimSpace(profile.PrivateKey) == "" {
		return nil, fmt.Errorf("WireGuard profile %s is missing Interface.PrivateKey", source)
	}
	if len(profile.Addresses) == 0 {
		return nil, fmt.Errorf("WireGuard profile %s is missing Interface.Address", source)
	}
	if strings.TrimSpace(profile.PeerPublicKey) == "" {
		return nil, fmt.Errorf("WireGuard profile %s is missing Peer.PublicKey", source)
	}
	if len(profile.AllowedIPs) == 0 {
		return nil, fmt.Errorf("WireGuard profile %s is missing Peer.AllowedIPs", source)
	}
	return profile, nil
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}
