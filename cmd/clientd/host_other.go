//go:build !windows && !linux

package main

import (
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func newClientHost(logger *slog.Logger) *clientcontrol.Host {
	return clientcontrol.New(clientcontrol.WithLogger(logger))
}
