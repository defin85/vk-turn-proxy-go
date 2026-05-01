package wireguardturnruntime

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"github.com/pion/logging"
	"github.com/pion/transport/v4/stdnet"
	"github.com/pion/turn/v5"
	"golang.zx2c4.com/wireguard/conn"
	"golang.zx2c4.com/wireguard/device"
	"golang.zx2c4.com/wireguard/tun"
)

type SocketProtector func(fd int) error

type Config struct {
	Lease         *clientcontrol.WireGuardTurnExecutionLease
	TUNFD         int
	TUNDevice     tun.Device
	ProtectSocket SocketProtector
}

type Runtime struct {
	mu sync.Mutex

	device     *device.Device
	tunDevice  tun.Device
	turnBind   *turnDatagramBind
	allocation net.PacketConn
	turnClient *turn.Client
	baseConn   net.PacketConn
	closed     bool
}

const defaultTURNClientRTO = 200 * time.Millisecond

func Start(ctx context.Context, cfg Config) (*Runtime, error) {
	_ = ctx
	if cfg.Lease == nil {
		return nil, fmt.Errorf("wireguard TURN runtime requires an execution lease")
	}
	if cfg.TUNFD <= 0 && cfg.TUNDevice == nil {
		return nil, fmt.Errorf("wireguard TURN runtime requires a valid TUN file descriptor or device")
	}
	if strings.TrimSpace(cfg.Lease.PeerEndpointAddress) == "" {
		return nil, fmt.Errorf("wireguard TURN runtime requires peer_endpoint_address")
	}
	if strings.TrimSpace(cfg.Lease.TURNServerAddress) == "" {
		return nil, fmt.Errorf("wireguard TURN runtime requires turn_server_address")
	}

	baseConn, err := listenTURNPacketConn(cfg.Lease.TURNServerAddress)
	if err != nil {
		return nil, fmt.Errorf("listen TURN socket: %w", err)
	}
	cleanupBaseConn := true
	defer func() {
		if cleanupBaseConn {
			_ = baseConn.Close()
		}
	}()

	if cfg.ProtectSocket != nil {
		if err := protectPacketConn(baseConn, cfg.ProtectSocket); err != nil {
			return nil, fmt.Errorf("protect TURN socket: %w", err)
		}
	}

	turnNet, err := stdnet.NewNet()
	if err != nil {
		return nil, fmt.Errorf("create TURN network: %w", err)
	}

	turnClient, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: cfg.Lease.TURNServerAddress,
		TURNServerAddr: cfg.Lease.TURNServerAddress,
		Username:       cfg.Lease.TURNUsername,
		Password:       cfg.Lease.TURNPassword,
		Conn:           baseConn,
		Net:            turnNet,
		RTO:            defaultTURNClientRTO,
		LoggerFactory:  logging.NewDefaultLoggerFactory(),
	})
	if err != nil {
		return nil, fmt.Errorf("create TURN client: %w", err)
	}
	cleanupTurnClient := true
	defer func() {
		if cleanupTurnClient {
			turnClient.Close()
		}
	}()

	if err := turnClient.Listen(); err != nil {
		return nil, fmt.Errorf("listen TURN client: %w", err)
	}

	allocation, err := turnClient.Allocate()
	if err != nil {
		return nil, fmt.Errorf("allocate TURN relay: %w", err)
	}
	cleanupAllocation := true
	defer func() {
		if cleanupAllocation {
			_ = allocation.Close()
		}
	}()

	turnBind, err := newTurnDatagramBind(allocation)
	if err != nil {
		return nil, fmt.Errorf("build TURN datagram bind: %w", err)
	}
	cleanupBind := true
	defer func() {
		if cleanupBind {
			_ = turnBind.Close()
		}
	}()

	tunDevice := cfg.TUNDevice
	cleanupTun := false
	if tunDevice == nil {
		tunDevice, err = tunDeviceFromFD(cfg.TUNFD)
		if err != nil {
			return nil, fmt.Errorf("create userspace TUN device: %w", err)
		}
		cleanupTun = true
	}
	defer func() {
		if cleanupTun {
			_ = tunDevice.Close()
		}
	}()

	wgDevice := device.NewDevice(tunDevice, turnBind, device.NewLogger(device.LogLevelError, "android-wg: "))
	ipcConfig, err := buildIPCConfig(cfg.Lease)
	if err != nil {
		wgDevice.Close()
		return nil, fmt.Errorf("build WireGuard config: %w", err)
	}
	if err := wgDevice.IpcSet(ipcConfig); err != nil {
		wgDevice.Close()
		return nil, fmt.Errorf("configure WireGuard device: %w", err)
	}
	if err := wgDevice.Up(); err != nil {
		wgDevice.Close()
		return nil, fmt.Errorf("bring up WireGuard device: %w", err)
	}

	runtime := &Runtime{
		device:     wgDevice,
		tunDevice:  tunDevice,
		turnBind:   turnBind,
		allocation: allocation,
		turnClient: turnClient,
		baseConn:   baseConn,
	}

	cleanupBaseConn = false
	cleanupTurnClient = false
	cleanupAllocation = false
	cleanupBind = false
	cleanupTun = false

	return runtime, nil
}

func (r *Runtime) Close() error {
	if r == nil {
		return nil
	}
	r.mu.Lock()
	if r.closed {
		r.mu.Unlock()
		return nil
	}
	r.closed = true
	wgDevice := r.device
	tunDevice := r.tunDevice
	turnBind := r.turnBind
	allocation := r.allocation
	turnClient := r.turnClient
	baseConn := r.baseConn
	r.mu.Unlock()

	if wgDevice != nil {
		wgDevice.Close()
	}

	var errs []error
	if turnBind != nil {
		if err := turnBind.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, err)
		}
	}
	if allocation != nil {
		if err := allocation.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, err)
		}
	}
	if turnClient != nil {
		turnClient.Close()
	}
	if baseConn != nil {
		if err := baseConn.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, err)
		}
	}
	if tunDevice != nil {
		if err := tunDevice.Close(); err != nil && !errors.Is(err, os.ErrClosed) {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

type turnDatagramBind struct {
	packetConn net.PacketConn
	mu         sync.Mutex
	closeCh    chan struct{}
}

type turnDatagramEndpoint struct {
	netip.AddrPort
}

func newTurnDatagramBind(packetConn net.PacketConn) (*turnDatagramBind, error) {
	if packetConn == nil {
		return nil, fmt.Errorf("TURN datagram bind requires an allocated PacketConn")
	}
	return &turnDatagramBind{
		packetConn: packetConn,
		closeCh:    make(chan struct{}),
	}, nil
}

func (b *turnDatagramBind) Open(_ uint16) ([]conn.ReceiveFunc, uint16, error) {
	b.mu.Lock()
	b.closeCh = make(chan struct{})
	b.mu.Unlock()
	actualPort := uint16(0)
	if port, err := localAddrPort(b.packetConn.LocalAddr()); err == nil {
		actualPort = port
	}
	return []conn.ReceiveFunc{b.receive}, actualPort, nil
}

func (b *turnDatagramBind) Close() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	select {
	case <-b.closeCh:
	default:
		close(b.closeCh)
	}
	return nil
}

func (b *turnDatagramBind) SetMark(uint32) error { return nil }

func (b *turnDatagramBind) Send(bufs [][]byte, ep conn.Endpoint) error {
	endpoint, ok := ep.(*turnDatagramEndpoint)
	if !ok {
		return conn.ErrWrongEndpointType
	}
	addr := net.UDPAddrFromAddrPort(endpoint.AddrPort)
	for _, packet := range bufs {
		if _, err := b.packetConn.WriteTo(packet, addr); err != nil {
			return err
		}
	}
	return nil
}

func (b *turnDatagramBind) ParseEndpoint(s string) (conn.Endpoint, error) {
	addrPort, err := netip.ParseAddrPort(strings.TrimSpace(s))
	if err != nil {
		return nil, err
	}
	return &turnDatagramEndpoint{AddrPort: addrPort}, nil
}

func (b *turnDatagramBind) BatchSize() int { return 1 }

func (b *turnDatagramBind) receive(
	packets [][]byte,
	sizes []int,
	eps []conn.Endpoint,
) (int, error) {
	closeCh := b.currentCloseCh()
	for {
		select {
		case <-closeCh:
			return 0, net.ErrClosed
		default:
		}

		if err := b.packetConn.SetReadDeadline(time.Now().Add(100 * time.Millisecond)); err != nil {
			return 0, err
		}
		n, addr, err := b.packetConn.ReadFrom(packets[0])
		if err != nil {
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				continue
			}
			return 0, err
		}
		addrPort, err := udpAddrPort(addr)
		if err != nil {
			return 0, err
		}
		sizes[0] = n
		eps[0] = &turnDatagramEndpoint{AddrPort: addrPort}
		return 1, nil
	}
}

func (b *turnDatagramBind) currentCloseCh() <-chan struct{} {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.closeCh
}

func (e *turnDatagramEndpoint) ClearSrc() {}

func (e *turnDatagramEndpoint) SrcToString() string { return "" }

func (e *turnDatagramEndpoint) DstToString() string { return e.AddrPort.String() }

func (e *turnDatagramEndpoint) DstToBytes() []byte {
	data, _ := e.AddrPort.MarshalBinary()
	return data
}

func (e *turnDatagramEndpoint) DstIP() netip.Addr { return e.AddrPort.Addr() }

func (e *turnDatagramEndpoint) SrcIP() netip.Addr { return netip.Addr{} }

func buildIPCConfig(lease *clientcontrol.WireGuardTurnExecutionLease) (string, error) {
	privateKeyHex, err := decodeKeyHex(lease.ClientPrivateKey)
	if err != nil {
		return "", fmt.Errorf("decode client private key: %w", err)
	}
	publicKeyHex, err := decodeKeyHex(lease.PeerPublicKey)
	if err != nil {
		return "", fmt.Errorf("decode peer public key: %w", err)
	}
	presharedKeyHex := ""
	if strings.TrimSpace(lease.PresharedKey) != "" {
		presharedKeyHex, err = decodeKeyHex(lease.PresharedKey)
		if err != nil {
			return "", fmt.Errorf("decode peer preshared key: %w", err)
		}
	}
	var builder strings.Builder
	builder.WriteString("private_key=")
	builder.WriteString(privateKeyHex)
	builder.WriteByte('\n')
	builder.WriteString("public_key=")
	builder.WriteString(publicKeyHex)
	builder.WriteByte('\n')
	if presharedKeyHex != "" {
		builder.WriteString("preshared_key=")
		builder.WriteString(presharedKeyHex)
		builder.WriteByte('\n')
	}
	builder.WriteString("endpoint=")
	builder.WriteString(lease.PeerEndpointAddress)
	builder.WriteByte('\n')
	for _, allowedIP := range lease.AllowedIPs {
		builder.WriteString("allowed_ip=")
		builder.WriteString(strings.TrimSpace(allowedIP))
		builder.WriteByte('\n')
	}
	keepalive := lease.PersistentKeepaliveSeconds
	if keepalive <= 0 {
		keepalive = 25
	}
	builder.WriteString(fmt.Sprintf("persistent_keepalive_interval=%d\n", keepalive))
	return builder.String(), nil
}

func decodeKeyHex(base64Value string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(base64Value))
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(raw), nil
}

func effectiveMTU(value int) int {
	if value > 0 {
		return value
	}
	return 1280
}

func protectPacketConn(packetConn net.PacketConn, protector SocketProtector) error {
	udpConn, ok := packetConn.(*net.UDPConn)
	if !ok {
		return fmt.Errorf("TURN runtime expected *net.UDPConn, got %T", packetConn)
	}
	rawConn, err := udpConn.SyscallConn()
	if err != nil {
		return err
	}
	var protectErr error
	if err := rawConn.Control(func(fd uintptr) {
		protectErr = protector(int(fd))
	}); err != nil {
		return err
	}
	return protectErr
}

func listenTURNPacketConn(turnAddr string) (net.PacketConn, error) {
	remoteAddr, err := net.ResolveUDPAddr("udp", turnAddr)
	if err != nil {
		return nil, fmt.Errorf("resolve turn udp address %q: %w", turnAddr, err)
	}

	network := "udp4"
	localAddr := "0.0.0.0:0"
	if remoteAddr.IP != nil && remoteAddr.IP.To4() == nil {
		network = "udp6"
		localAddr = "[::]:0"
	}

	conn, err := net.ListenPacket(network, localAddr)
	if err != nil {
		return nil, fmt.Errorf("bind turn client socket: %w", err)
	}
	return conn, nil
}

func udpAddrPort(addr net.Addr) (netip.AddrPort, error) {
	switch value := addr.(type) {
	case *net.UDPAddr:
		return value.AddrPort(), nil
	default:
		return netip.ParseAddrPort(addr.String())
	}
}

func localAddrPort(addr net.Addr) (uint16, error) {
	switch value := addr.(type) {
	case *net.UDPAddr:
		if value.Port < 0 || value.Port > 65535 {
			return 0, fmt.Errorf("invalid UDP port %d", value.Port)
		}
		return uint16(value.Port), nil
	default:
		addrPort, err := netip.ParseAddrPort(addr.String())
		if err != nil {
			return 0, err
		}
		return addrPort.Port(), nil
	}
}
