package overlay

import (
	"encoding/binary"
	"fmt"
	"log/slog"
	"net"
	"strings"
	"sync"
	"time"
)

type AdapterKind string

const (
	AdapterUDP AdapterKind = "udp"
	AdapterTCP AdapterKind = "tcp"
)

const (
	DefaultDatagramBufferSize = 1600
	StreamChunkSize           = 1024
	maxFrameSize              = 64 * 1024
)

func NormalizeAdapter(kind AdapterKind) AdapterKind {
	switch AdapterKind(strings.TrimSpace(string(kind))) {
	case "", AdapterUDP:
		return AdapterUDP
	case AdapterTCP:
		return AdapterTCP
	default:
		return kind
	}
}

func ValidateAdapter(kind AdapterKind, role string) error {
	switch NormalizeAdapter(kind) {
	case AdapterUDP, AdapterTCP:
		return nil
	default:
		return fmt.Errorf("unsupported %s adapter %q", role, kind)
	}
}

func SupportedPair(ingress AdapterKind, egress AdapterKind) bool {
	ingress = NormalizeAdapter(ingress)
	egress = NormalizeAdapter(egress)

	return (ingress == AdapterUDP && egress == AdapterUDP) || (ingress == AdapterTCP && egress == AdapterTCP)
}

type FrameKind uint8

const (
	FrameHello FrameKind = iota + 1
	FrameHelloAck
	FrameHelloReject
	FrameDatagram
	FrameStreamOpen
	FrameStreamData
	FrameStreamClose
)

func (k FrameKind) String() string {
	switch k {
	case FrameHello:
		return "hello"
	case FrameHelloAck:
		return "hello_ack"
	case FrameHelloReject:
		return "hello_reject"
	case FrameDatagram:
		return "datagram"
	case FrameStreamOpen:
		return "stream_open"
	case FrameStreamData:
		return "stream_data"
	case FrameStreamClose:
		return "stream_close"
	default:
		return fmt.Sprintf("frame_kind_%d", uint8(k))
	}
}

type Frame struct {
	Kind     FrameKind
	Adapter  AdapterKind
	RouteID  uint64
	StreamID uint64
	Sequence uint64
	Payload  []byte
	Reason   string
}

func (f Frame) MarshalBinary() ([]byte, error) {
	out := make([]byte, 1, 1+8+len(f.Payload)+len(f.Reason))
	out[0] = byte(f.Kind)

	switch f.Kind {
	case FrameHello, FrameHelloAck:
		code, err := adapterCode(f.Adapter)
		if err != nil {
			return nil, err
		}
		out = append(out, code)
	case FrameHelloReject:
		out = append(out, []byte(f.Reason)...)
	case FrameDatagram:
		out = binary.BigEndian.AppendUint64(out, f.RouteID)
		out = append(out, f.Payload...)
	case FrameStreamOpen, FrameStreamClose:
		out = binary.BigEndian.AppendUint64(out, f.StreamID)
	case FrameStreamData:
		out = binary.BigEndian.AppendUint64(out, f.StreamID)
		out = binary.BigEndian.AppendUint64(out, f.Sequence)
		out = append(out, f.Payload...)
	default:
		return nil, fmt.Errorf("unsupported frame kind %q", f.Kind)
	}

	return out, nil
}

func UnmarshalFrame(data []byte) (Frame, error) {
	if len(data) == 0 {
		return Frame{}, fmt.Errorf("overlay frame is empty")
	}

	frame := Frame{Kind: FrameKind(data[0])}
	payload := data[1:]

	switch frame.Kind {
	case FrameHello, FrameHelloAck:
		if len(payload) != 1 {
			return Frame{}, fmt.Errorf("overlay %s frame is malformed", frame.Kind)
		}
		adapter, err := adapterFromCode(payload[0])
		if err != nil {
			return Frame{}, err
		}
		frame.Adapter = adapter
	case FrameHelloReject:
		frame.Reason = string(payload)
	case FrameDatagram:
		if len(payload) < 8 {
			return Frame{}, fmt.Errorf("overlay datagram frame is malformed")
		}
		frame.RouteID = binary.BigEndian.Uint64(payload[:8])
		frame.Payload = append([]byte(nil), payload[8:]...)
	case FrameStreamOpen, FrameStreamClose:
		if len(payload) != 8 {
			return Frame{}, fmt.Errorf("overlay %s frame is malformed", frame.Kind)
		}
		frame.StreamID = binary.BigEndian.Uint64(payload[:8])
	case FrameStreamData:
		if len(payload) < 16 {
			return Frame{}, fmt.Errorf("overlay stream data frame is malformed")
		}
		frame.StreamID = binary.BigEndian.Uint64(payload[:8])
		frame.Sequence = binary.BigEndian.Uint64(payload[8:16])
		frame.Payload = append([]byte(nil), payload[16:]...)
	default:
		return Frame{}, fmt.Errorf("unsupported frame kind %d", data[0])
	}

	return frame, nil
}

type FrameWriter interface {
	WriteFrame(Frame) error
}

type Endpoint struct {
	conn    net.Conn
	logger  *slog.Logger
	writeMu sync.Mutex
	buf     []byte
}

func NewEndpoint(conn net.Conn, logger *slog.Logger) *Endpoint {
	if logger == nil {
		logger = slog.Default()
	}

	return &Endpoint{
		conn:   conn,
		logger: logger,
		buf:    make([]byte, maxFrameSize),
	}
}

func (e *Endpoint) ReadFrame() (Frame, error) {
	n, err := e.conn.Read(e.buf)
	if err != nil {
		return Frame{}, err
	}
	if n == len(e.buf) {
		return Frame{}, fmt.Errorf("overlay frame exceeded %d bytes", len(e.buf))
	}

	return UnmarshalFrame(e.buf[:n])
}

func (e *Endpoint) WriteFrame(frame Frame) error {
	return e.writeFrame(frame, time.Time{})
}

func (e *Endpoint) WriteFrameWithDeadline(frame Frame, timeout time.Duration) error {
	deadline := time.Time{}
	if timeout > 0 {
		deadline = time.Now().Add(timeout)
	}

	return e.writeFrame(frame, deadline)
}

func (e *Endpoint) writeFrame(frame Frame, deadline time.Time) error {
	payload, err := frame.MarshalBinary()
	if err != nil {
		return err
	}

	e.writeMu.Lock()
	defer e.writeMu.Unlock()
	if !deadline.IsZero() {
		if err := e.conn.SetWriteDeadline(deadline); err != nil {
			return fmt.Errorf("set overlay %s write deadline: %w", frame.Kind, err)
		}
		defer func() {
			_ = e.conn.SetWriteDeadline(time.Time{})
		}()
	}

	if _, err := e.conn.Write(payload); err != nil {
		return fmt.Errorf("write overlay %s frame: %w", frame.Kind, err)
	}

	return nil
}

func adapterCode(kind AdapterKind) (byte, error) {
	switch NormalizeAdapter(kind) {
	case AdapterUDP:
		return 1, nil
	case AdapterTCP:
		return 2, nil
	default:
		return 0, fmt.Errorf("unsupported overlay adapter %q", kind)
	}
}

func adapterFromCode(code byte) (AdapterKind, error) {
	switch code {
	case 1:
		return AdapterUDP, nil
	case 2:
		return AdapterTCP, nil
	default:
		return "", fmt.Errorf("unsupported overlay adapter code %d", code)
	}
}
