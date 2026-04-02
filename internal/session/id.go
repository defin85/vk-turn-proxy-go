package session

import (
	"crypto/rand"
	"encoding/hex"
)

type ID string

func NewID() ID {
	var data [16]byte
	if _, err := rand.Read(data[:]); err != nil {
		panic(err)
	}

	return ID(hex.EncodeToString(data[:]))
}
