package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"sync"
	"unsafe"

	"github.com/defin85/vk-turn-proxy-go/internal/androidembeddedhost"
	"github.com/defin85/vk-turn-proxy-go/internal/androidplatformbridge"
)

var (
	hostManager = androidembeddedhost.New(
		androidembeddedhost.WithAndroidVPNServiceLifecycle(
			androidplatformbridge.NewVPNServiceLifecycle(),
		),
	)
	stateMu   sync.Mutex
	lastError string
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

//export AndroidEmbeddedHostRegisterPlatformTunnelBridge
func AndroidEmbeddedHostRegisterPlatformTunnelBridge(env unsafe.Pointer, bridge unsafe.Pointer) {
	androidplatformbridge.Register(env, bridge)
}

//export AndroidEmbeddedHostClearPlatformTunnelBridge
func AndroidEmbeddedHostClearPlatformTunnelBridge(env unsafe.Pointer) {
	androidplatformbridge.Clear(env)
}

//export AndroidEmbeddedHostSetAndroidWireGuardProfilePath
func AndroidEmbeddedHostSetAndroidWireGuardProfilePath(value *C.char) {
	if value == nil {
		androidembeddedhost.SetAndroidWireGuardProfilePath("")
		return
	}
	androidembeddedhost.SetAndroidWireGuardProfilePath(C.GoString(value))
}

//export AndroidEmbeddedHostSetTransportProfileStorePath
func AndroidEmbeddedHostSetTransportProfileStorePath(value *C.char) {
	if value == nil {
		hostManager.SetTransportProfileStorePath("")
		return
	}
	hostManager.SetTransportProfileStorePath(C.GoString(value))
}

func setLastError(value string) {
	stateMu.Lock()
	lastError = value
	stateMu.Unlock()
}
