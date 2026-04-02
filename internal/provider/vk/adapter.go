package vk

import (
	"context"
	"net/http"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

type httpDoer interface {
	Do(*http.Request) (*http.Response, error)
}

type Adapter struct {
	doer httpDoer
}

func New() *Adapter {
	return &Adapter{doer: newDefaultHTTPClient()}
}

func NewWithHTTPDoer(doer httpDoer) *Adapter {
	if doer == nil {
		doer = newDefaultHTTPClient()
	}

	return &Adapter{doer: doer}
}

func (a *Adapter) Name() string {
	return "vk"
}

func (a *Adapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	joinToken, err := normalizeJoinToken(link)
	if err != nil {
		return provider.Resolution{}, err
	}

	resolution, err := newResolver(a.doer).resolve(ctx, joinToken)
	if err != nil {
		return provider.Resolution{}, err
	}

	if resolution.Metadata == nil {
		resolution.Metadata = make(map[string]string, 2)
	}
	resolution.Metadata["provider"] = "vk"
	resolution.Metadata["resolution_method"] = "staged_http"

	return resolution, nil
}
