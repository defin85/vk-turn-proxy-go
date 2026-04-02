package provider

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"
)

var ErrNotImplemented = errors.New("provider adapter is not implemented")

type Credentials struct {
	Username string
	Password string
	Address  string
	TTL      time.Duration
}

type Resolution struct {
	Credentials Credentials
	Metadata    map[string]string
	Artifact    *ProbeArtifact
}

type Adapter interface {
	Name() string
	Resolve(context.Context, string) (Resolution, error)
}

type Registry struct {
	adapters map[string]Adapter
}

func NewRegistry(adapters ...Adapter) *Registry {
	registry := &Registry{adapters: make(map[string]Adapter, len(adapters))}
	for _, adapter := range adapters {
		registry.Register(adapter)
	}

	return registry
}

func (r *Registry) Register(adapter Adapter) {
	if adapter == nil {
		return
	}

	r.adapters[strings.ToLower(adapter.Name())] = adapter
}

func (r *Registry) Get(name string) (Adapter, error) {
	adapter, ok := r.adapters[strings.ToLower(strings.TrimSpace(name))]
	if !ok {
		return nil, fmt.Errorf("provider %q is not registered", name)
	}

	return adapter, nil
}

func (r *Registry) Names() []string {
	names := make([]string, 0, len(r.adapters))
	for name := range r.adapters {
		names = append(names, name)
	}
	sort.Strings(names)

	return names
}
