//go:build linux || android

package wireguardturnruntime

import "golang.zx2c4.com/wireguard/tun"

func tunDeviceFromFD(fd int) (tun.Device, error) {
	tunDevice, _, err := tun.CreateUnmonitoredTUNFromFD(fd)
	return tunDevice, err
}
