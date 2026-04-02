package config

import "testing"

func TestServerConfigValidate(t *testing.T) {
	cfg := DefaultServerConfig()
	cfg.UpstreamAddr = "127.0.0.1:51820"

	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected valid server config, got %v", err)
	}
}

func TestClientConfigValidateRejectsInvalidMode(t *testing.T) {
	cfg := DefaultClientConfig()
	cfg.Provider = "vk"
	cfg.Link = "https://vk.com/call/join/example"
	cfg.PeerAddr = "127.0.0.1:56000"
	cfg.Mode = TransportMode("sctp")

	if err := cfg.Validate(); err == nil {
		t.Fatal("expected invalid mode error")
	}
}

func TestProbeConfigValidateAllowsProviderListing(t *testing.T) {
	cfg := DefaultProbeConfig()
	cfg.ListProviders = true

	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected list-providers config to be valid, got %v", err)
	}
}
