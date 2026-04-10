package turnrest

import (
	"strconv"
	"strings"
	"time"
)

const (
	FormatTimestampOnly     = "timestamp_only"
	FormatTimestampUsername = "timestamp_username"
	minUnixSeconds          = 946684800  // 2000-01-01T00:00:00Z
	maxUnixSeconds          = 4102444800 // 2100-01-01T00:00:00Z
)

type ExpiryCandidate struct {
	Expiry    time.Time
	Format    string
	Timestamp int64
	Suffix    string
}

// ParseExpiryCandidate extracts a TURN REST style expiry candidate from a TURN username.
// It only recognizes usernames that begin with a plausible UNIX timestamp in seconds.
func ParseExpiryCandidate(username string) (ExpiryCandidate, bool) {
	trimmed := strings.TrimSpace(username)
	if trimmed == "" {
		return ExpiryCandidate{}, false
	}

	prefix := trimmed
	suffix := ""
	format := FormatTimestampOnly
	if idx := strings.Index(prefix, ":"); idx >= 0 {
		suffix = prefix[idx+1:]
		prefix = prefix[:idx]
		format = FormatTimestampUsername
	}

	timestamp, err := strconv.ParseInt(prefix, 10, 64)
	if err != nil || timestamp < minUnixSeconds || timestamp > maxUnixSeconds {
		return ExpiryCandidate{}, false
	}

	return ExpiryCandidate{
		Expiry:    time.Unix(timestamp, 0).UTC(),
		Format:    format,
		Timestamp: timestamp,
		Suffix:    suffix,
	}, true
}
