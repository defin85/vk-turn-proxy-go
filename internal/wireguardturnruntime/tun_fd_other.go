//go:build !linux && !android

package wireguardturnruntime

import (
	"fmt"

	"golang.zx2c4.com/wireguard/tun"
)

func tunDeviceFromFD(fd int) (tun.Device, error) {
	return nil, fmt.Errorf("wireguard TURN runtime does not support TUN file descriptors on this target")
}
