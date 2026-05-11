//go:build linux

package main

import (
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/internal/linuxdesktophost"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func newClientHost(logger *slog.Logger) *clientcontrol.Host {
	return linuxdesktophost.NewClientControlHost(logger)
}
