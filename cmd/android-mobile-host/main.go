package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"sync"
	"unsafe"

	"github.com/defin85/vk-turn-proxy-go/internal/androidembeddedhost"
)

var (
	hostManager = androidembeddedhost.New()
	stateMu     sync.Mutex
	lastError   string
)

func main() {}

//export AndroidEmbeddedHostEnsureStarted
func AndroidEmbeddedHostEnsureStarted() *C.char {
	baseURL, err := hostManager.EnsureStarted()
	if err != nil {
		setLastError(err.Error())
		return nil
	}
	setLastError("")
	return C.CString(baseURL)
}

//export AndroidEmbeddedHostLastError
func AndroidEmbeddedHostLastError() *C.char {
	stateMu.Lock()
	value := lastError
	stateMu.Unlock()
	return C.CString(value)
}

//export AndroidEmbeddedHostStop
func AndroidEmbeddedHostStop() {
	if err := hostManager.Stop(); err != nil {
		setLastError(err.Error())
		return
	}
	setLastError("")
}

//export AndroidEmbeddedHostFreeString
func AndroidEmbeddedHostFreeString(value *C.char) {
	C.free(unsafe.Pointer(value))
}

func setLastError(value string) {
	stateMu.Lock()
	lastError = value
	stateMu.Unlock()
}
