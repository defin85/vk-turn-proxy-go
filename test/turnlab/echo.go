package turnlab

import (
	"errors"
	"fmt"
	"net"
)

func runUDPEcho(conn net.PacketConn) error {
	buf := make([]byte, 1600)

	for {
		n, addr, err := conn.ReadFrom(buf)
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}

			return fmt.Errorf("read packet: %w", err)
		}

		if _, err := conn.WriteTo(buf[:n], addr); err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}

			return fmt.Errorf("write packet: %w", err)
		}
	}
}
