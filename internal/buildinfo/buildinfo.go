package buildinfo

import (
	"runtime"
	"runtime/debug"
	"strings"
)

const defaultProduct = "vk-turn-proxy-go"

var (
	ProductName    = defaultProduct
	ProductVersion = ""
	BuildNumber    = ""
	Revision       = ""
	Dirty          = ""
	BuiltAt        = ""
	ArtifactRole   = ""
	ArtifactTarget = ""
)

type Identity struct {
	Product     string `json:"product"`
	Version     string `json:"version"`
	BuildNumber string `json:"build_number"`
	Revision    string `json:"revision,omitempty"`
	Dirty       bool   `json:"dirty,omitempty"`
	BuiltAt     string `json:"built_at,omitempty"`
	Role        string `json:"role,omitempty"`
	Target      string `json:"target,omitempty"`
}

type Options struct {
	Role   string
	Target string
}

func Current(opts Options) Identity {
	info := Identity{
		Product:     firstNonEmpty(strings.TrimSpace(ProductName), defaultProduct),
		Version:     strings.TrimSpace(ProductVersion),
		BuildNumber: strings.TrimSpace(BuildNumber),
		Revision:    strings.TrimSpace(Revision),
		Dirty:       parseBool(Dirty),
		BuiltAt:     strings.TrimSpace(BuiltAt),
		Role:        firstNonEmpty(strings.TrimSpace(ArtifactRole), strings.TrimSpace(opts.Role)),
		Target:      firstNonEmpty(strings.TrimSpace(ArtifactTarget), strings.TrimSpace(opts.Target)),
	}

	if build, ok := debug.ReadBuildInfo(); ok {
		for _, setting := range build.Settings {
			switch setting.Key {
			case "vcs.revision":
				if info.Revision == "" {
					info.Revision = strings.TrimSpace(setting.Value)
				}
			case "vcs.modified":
				if strings.TrimSpace(Dirty) == "" {
					info.Dirty = parseBool(setting.Value)
				}
			case "vcs.time":
				if info.BuiltAt == "" {
					info.BuiltAt = strings.TrimSpace(setting.Value)
				}
			}
		}
	}

	if info.Version == "" {
		info.Version = "dev"
	}
	if info.BuildNumber == "" {
		info.BuildNumber = "0"
	}
	if info.Revision == "" {
		info.Revision = "dev"
	}
	if info.Target == "" {
		info.Target = runtime.GOOS + "/" + runtime.GOARCH
	}

	return info
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func parseBool(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "t", "true", "yes", "y":
		return true
	default:
		return false
	}
}
