package main

import "testing"

func TestNewRegistryIncludesGenericTurn(t *testing.T) {
	registry := newRegistry()

	for _, name := range []string{"generic-turn", "vk"} {
		adapter, err := registry.Get(name)
		if err != nil {
			t.Fatalf("registry.Get(%q) error = %v", name, err)
		}
		if adapter.Name() != name {
			t.Fatalf("unexpected adapter name %q for %q", adapter.Name(), name)
		}
	}
}
