package provider

import (
	"context"
	"testing"
)

type fakeAdapter struct {
	name string
}

func (f fakeAdapter) Name() string { return f.name }

func (f fakeAdapter) Resolve(context.Context, string) (Resolution, error) {
	return Resolution{}, nil
}

func TestRegistryReturnsRegisteredAdapter(t *testing.T) {
	registry := NewRegistry(fakeAdapter{name: "vk"})

	adapter, err := registry.Get("vk")
	if err != nil {
		t.Fatalf("expected adapter, got %v", err)
	}
	if adapter.Name() != "vk" {
		t.Fatalf("unexpected adapter %q", adapter.Name())
	}
}

func TestRegistryNamesAreSorted(t *testing.T) {
	registry := NewRegistry(fakeAdapter{name: "zeta"}, fakeAdapter{name: "alpha"})

	names := registry.Names()
	if len(names) != 2 {
		t.Fatalf("expected 2 names, got %d", len(names))
	}
	if names[0] != "alpha" || names[1] != "zeta" {
		t.Fatalf("unexpected names order %v", names)
	}
}
