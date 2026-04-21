//go:build windows

package main

import (
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/internal/windowsdesktophost"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func newClientHost(logger *slog.Logger) *clientcontrol.Host {
	return windowsdesktophost.NewClientControlHost(logger)
}
