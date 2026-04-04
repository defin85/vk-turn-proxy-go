package observe

import (
	"bytes"
	"io"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
)

type sessionKey struct {
	Runtime  string
	Provider string
	TURNMode string
	PeerMode string
}

type failureKey struct {
	sessionKey
	Stage string
}

type trafficKey struct {
	Runtime   string
	Provider  string
	Direction string
}

type Metrics struct {
	mu sync.Mutex

	sessionStarts        map[sessionKey]uint64
	sessionFailures      map[failureKey]uint64
	startupStageFailures map[failureKey]uint64
	transportStageErrors map[failureKey]uint64
	activeWorkers        map[sessionKey]int64
	forwardedPackets     map[trafficKey]uint64
	forwardedBytes       map[trafficKey]uint64
}

func NewMetrics() *Metrics {
	return &Metrics{
		sessionStarts:        make(map[sessionKey]uint64),
		sessionFailures:      make(map[failureKey]uint64),
		startupStageFailures: make(map[failureKey]uint64),
		transportStageErrors: make(map[failureKey]uint64),
		activeWorkers:        make(map[sessionKey]int64),
		forwardedPackets:     make(map[trafficKey]uint64),
		forwardedBytes:       make(map[trafficKey]uint64),
	}
}

func (m *Metrics) IncSessionStarts(runtime RuntimeKind, provider string, turnMode string, peerMode string) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := sessionKey{
		Runtime:  string(runtime),
		Provider: sanitizeText(provider),
		TURNMode: sanitizeText(turnMode),
		PeerMode: sanitizeText(peerMode),
	}
	m.sessionStarts[key]++
}

func (m *Metrics) IncSessionFailures(runtime RuntimeKind, provider string, turnMode string, peerMode string, stage string) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := failureKey{
		sessionKey: sessionKey{
			Runtime:  string(runtime),
			Provider: sanitizeText(provider),
			TURNMode: sanitizeText(turnMode),
			PeerMode: sanitizeText(peerMode),
		},
		Stage: sanitizeText(stage),
	}
	m.sessionFailures[key]++
}

func (m *Metrics) IncStartupStageFailures(runtime RuntimeKind, provider string, turnMode string, peerMode string, stage string) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := failureKey{
		sessionKey: sessionKey{
			Runtime:  string(runtime),
			Provider: sanitizeText(provider),
			TURNMode: sanitizeText(turnMode),
			PeerMode: sanitizeText(peerMode),
		},
		Stage: sanitizeText(stage),
	}
	m.startupStageFailures[key]++
}

func (m *Metrics) IncTransportStageFailures(runtime RuntimeKind, provider string, turnMode string, peerMode string, stage string) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := failureKey{
		sessionKey: sessionKey{
			Runtime:  string(runtime),
			Provider: sanitizeText(provider),
			TURNMode: sanitizeText(turnMode),
			PeerMode: sanitizeText(peerMode),
		},
		Stage: sanitizeText(stage),
	}
	m.transportStageErrors[key]++
}

func (m *Metrics) SetActiveWorkers(runtime RuntimeKind, provider string, turnMode string, peerMode string, count int) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := sessionKey{
		Runtime:  string(runtime),
		Provider: sanitizeText(provider),
		TURNMode: sanitizeText(turnMode),
		PeerMode: sanitizeText(peerMode),
	}
	m.activeWorkers[key] = int64(count)
}

func (m *Metrics) AddForwardedTraffic(runtime RuntimeKind, provider string, direction string, bytes int) {
	if m == nil || bytes <= 0 {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	key := trafficKey{
		Runtime:   string(runtime),
		Provider:  sanitizeText(provider),
		Direction: sanitizeText(direction),
	}
	m.forwardedPackets[key]++
	m.forwardedBytes[key] += uint64(bytes)
}

func (m *Metrics) Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = io.WriteString(w, m.Prometheus())
	})
}

func (m *Metrics) Prometheus() string {
	if m == nil {
		return ""
	}

	var out bytes.Buffer

	m.mu.Lock()
	defer m.mu.Unlock()

	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_session_starts_total",
		"counter",
		"Total runtime sessions that reached ready state.",
		sortedSessionMetrics(m.sessionStarts),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_session_failures_total",
		"counter",
		"Total runtime session failures.",
		sortedFailureMetrics(m.sessionFailures),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_startup_stage_failures_total",
		"counter",
		"Total startup-stage failures before the runtime reached ready state.",
		sortedFailureMetrics(m.startupStageFailures),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_transport_stage_failures_total",
		"counter",
		"Total transport-stage failures observed by the runtime, including recoverable worker or connection failures.",
		sortedFailureMetrics(m.transportStageErrors),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_active_workers",
		"gauge",
		"Current number of ready client workers for the runtime session.",
		sortedSessionGauges(m.activeWorkers),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_forwarded_packets_total",
		"counter",
		"Total forwarded packets.",
		sortedTrafficMetrics(m.forwardedPackets),
	)
	writeMetricFamily(&out,
		"vk_turn_proxy_runtime_forwarded_bytes_total",
		"counter",
		"Total forwarded bytes.",
		sortedTrafficMetrics(m.forwardedBytes),
	)

	return out.String()
}

type metricLine struct {
	labels map[string]string
	value  string
}

func writeMetricFamily(out *bytes.Buffer, name string, typ string, help string, lines []metricLine) {
	out.WriteString("# HELP ")
	out.WriteString(name)
	out.WriteByte(' ')
	out.WriteString(help)
	out.WriteByte('\n')
	out.WriteString("# TYPE ")
	out.WriteString(name)
	out.WriteByte(' ')
	out.WriteString(typ)
	out.WriteByte('\n')
	for _, line := range lines {
		out.WriteString(name)
		out.WriteString(renderLabels(line.labels))
		out.WriteByte(' ')
		out.WriteString(line.value)
		out.WriteByte('\n')
	}
}

func sortedSessionMetrics[V ~uint64](metrics map[sessionKey]V) []metricLine {
	lines := make([]metricLine, 0, len(metrics))
	for key, value := range metrics {
		lines = append(lines, metricLine{
			labels: map[string]string{
				"runtime":   key.Runtime,
				"provider":  key.Provider,
				"turn_mode": key.TURNMode,
				"peer_mode": key.PeerMode,
			},
			value: strconv.FormatUint(uint64(value), 10),
		})
	}

	sortMetricLines(lines)
	return lines
}

func sortedSessionGauges(metrics map[sessionKey]int64) []metricLine {
	lines := make([]metricLine, 0, len(metrics))
	for key, value := range metrics {
		lines = append(lines, metricLine{
			labels: map[string]string{
				"runtime":   key.Runtime,
				"provider":  key.Provider,
				"turn_mode": key.TURNMode,
				"peer_mode": key.PeerMode,
			},
			value: strconv.FormatInt(value, 10),
		})
	}

	sortMetricLines(lines)
	return lines
}

func sortedFailureMetrics[V ~uint64](metrics map[failureKey]V) []metricLine {
	lines := make([]metricLine, 0, len(metrics))
	for key, value := range metrics {
		lines = append(lines, metricLine{
			labels: map[string]string{
				"runtime":   key.Runtime,
				"provider":  key.Provider,
				"turn_mode": key.TURNMode,
				"peer_mode": key.PeerMode,
				"stage":     key.Stage,
			},
			value: strconv.FormatUint(uint64(value), 10),
		})
	}

	sortMetricLines(lines)
	return lines
}

func sortedTrafficMetrics[V ~uint64](metrics map[trafficKey]V) []metricLine {
	lines := make([]metricLine, 0, len(metrics))
	for key, value := range metrics {
		lines = append(lines, metricLine{
			labels: map[string]string{
				"runtime":   key.Runtime,
				"provider":  key.Provider,
				"direction": key.Direction,
			},
			value: strconv.FormatUint(uint64(value), 10),
		})
	}

	sortMetricLines(lines)
	return lines
}

func sortMetricLines(lines []metricLine) {
	sort.Slice(lines, func(i int, j int) bool {
		return renderLabels(lines[i].labels) < renderLabels(lines[j].labels)
	})
}

func renderLabels(labels map[string]string) string {
	keys := make([]string, 0, len(labels))
	for key, value := range labels {
		if strings.TrimSpace(value) == "" {
			continue
		}
		keys = append(keys, key)
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return ""
	}

	var b strings.Builder
	b.WriteByte('{')
	for index, key := range keys {
		if index > 0 {
			b.WriteByte(',')
		}
		b.WriteString(key)
		b.WriteString(`="`)
		b.WriteString(escapeLabelValue(labels[key]))
		b.WriteByte('"')
	}
	b.WriteByte('}')
	return b.String()
}

func escapeLabelValue(value string) string {
	replacer := strings.NewReplacer(`\`, `\\`, "\n", `\n`, `"`, `\"`)
	return replacer.Replace(value)
}
