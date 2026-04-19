//go:build android

package androidplatformbridge

/*
#include <jni.h>
#include <stdlib.h>
#include <string.h>

static JavaVM *vktp_bridge_vm = NULL;
static jobject vktp_bridge_object = NULL;
static jclass vktp_bridge_class = NULL;
static jmethodID vktp_mid_is_permission_granted = NULL;
static jmethodID vktp_mid_validate_route_policy = NULL;
static jmethodID vktp_mid_bringup_host = NULL;
static jmethodID vktp_mid_protect_socket = NULL;
static jmethodID vktp_mid_duplicate_tun_fd = NULL;
static jmethodID vktp_mid_cleanup_host = NULL;

static char* vktp_strdup_or_null(const char* value) {
	if (value == NULL) {
		return NULL;
	}
	size_t length = strlen(value);
	char* out = (char*)malloc(length + 1);
	if (out == NULL) {
		return NULL;
	}
	memcpy(out, value, length);
	out[length] = '\0';
	return out;
}

static void vktp_clear_exception(JNIEnv* env) {
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
	}
}

static void vktp_clear_registered_bridge(JNIEnv* env) {
	if (env == NULL) {
		return;
	}
	if (vktp_bridge_object != NULL) {
		(*env)->DeleteGlobalRef(env, vktp_bridge_object);
		vktp_bridge_object = NULL;
	}
	if (vktp_bridge_class != NULL) {
		(*env)->DeleteGlobalRef(env, vktp_bridge_class);
		vktp_bridge_class = NULL;
	}
	vktp_mid_is_permission_granted = NULL;
	vktp_mid_validate_route_policy = NULL;
	vktp_mid_bringup_host = NULL;
	vktp_mid_protect_socket = NULL;
	vktp_mid_duplicate_tun_fd = NULL;
	vktp_mid_cleanup_host = NULL;
}

static JNIEnv* vktp_attach_env(int *attached) {
	if (attached != NULL) {
		*attached = 0;
	}
	if (vktp_bridge_vm == NULL) {
		return NULL;
	}
	JNIEnv *env = NULL;
	jint status = (*vktp_bridge_vm)->GetEnv(vktp_bridge_vm, (void**)&env, JNI_VERSION_1_6);
	if (status == JNI_OK) {
		return env;
	}
	if (status != JNI_EDETACHED) {
		return NULL;
	}
	if ((*vktp_bridge_vm)->AttachCurrentThread(vktp_bridge_vm, &env, NULL) != JNI_OK) {
		return NULL;
	}
	if (attached != NULL) {
		*attached = 1;
	}
	return env;
}

static void vktp_detach_env(int attached) {
	if (attached && vktp_bridge_vm != NULL) {
		(*vktp_bridge_vm)->DetachCurrentThread(vktp_bridge_vm);
	}
}

static char* vktp_jstring_to_error(JNIEnv* env, jstring value) {
	if (env == NULL || value == NULL) {
		return NULL;
	}
	const char *utf = (*env)->GetStringUTFChars(env, value, NULL);
	if (utf == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge returned an unreadable error");
	}
	char *out = vktp_strdup_or_null(utf);
	(*env)->ReleaseStringUTFChars(env, value, utf);
	return out;
}

void vktp_register_platform_tunnel_bridge(void *env_ptr, void *bridge_ptr) {
	JNIEnv *env = (JNIEnv*)env_ptr;
	jobject bridge = (jobject)bridge_ptr;
	if (env == NULL || bridge == NULL) {
		return;
	}

	vktp_clear_registered_bridge(env);
	if ((*env)->GetJavaVM(env, &vktp_bridge_vm) != JNI_OK) {
		vktp_bridge_vm = NULL;
		return;
	}

	jclass local_class = (*env)->GetObjectClass(env, bridge);
	if (local_class == NULL) {
		vktp_clear_exception(env);
		return;
	}

	vktp_bridge_object = (*env)->NewGlobalRef(env, bridge);
	vktp_bridge_class = (*env)->NewGlobalRef(env, local_class);
	(*env)->DeleteLocalRef(env, local_class);
	if (vktp_bridge_object == NULL || vktp_bridge_class == NULL) {
		vktp_clear_registered_bridge(env);
		return;
	}

	vktp_mid_is_permission_granted = (*env)->GetMethodID(env, vktp_bridge_class, "isAndroidVpnPermissionGranted", "()Z");
	vktp_mid_validate_route_policy = (*env)->GetMethodID(env, vktp_bridge_class, "validateAndroidVpnRoutePolicy", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;");
	vktp_mid_bringup_host = (*env)->GetMethodID(env, vktp_bridge_class, "bringupAndroidVpnHost", "(Ljava/lang/String;)Ljava/lang/String;");
	vktp_mid_protect_socket = (*env)->GetMethodID(env, vktp_bridge_class, "protectAndroidVpnSocket", "(I)Ljava/lang/String;");
	vktp_mid_duplicate_tun_fd = (*env)->GetMethodID(env, vktp_bridge_class, "duplicateAndroidVpnTunFd", "()I");
	vktp_mid_cleanup_host = (*env)->GetMethodID(env, vktp_bridge_class, "cleanupAndroidVpnHost", "()Ljava/lang/String;");
	if (vktp_mid_is_permission_granted == NULL || vktp_mid_validate_route_policy == NULL ||
		vktp_mid_bringup_host == NULL || vktp_mid_protect_socket == NULL ||
		vktp_mid_duplicate_tun_fd == NULL || vktp_mid_cleanup_host == NULL) {
		vktp_clear_exception(env);
		vktp_clear_registered_bridge(env);
	}
}

void vktp_clear_platform_tunnel_bridge(void *env_ptr) {
	JNIEnv *env = (JNIEnv*)env_ptr;
	if (env != NULL) {
		vktp_clear_registered_bridge(env);
		return;
	}
	int attached = 0;
	env = vktp_attach_env(&attached);
	if (env != NULL) {
		vktp_clear_registered_bridge(env);
	}
	vktp_detach_env(attached);
}

int vktp_android_vpn_permission_state() {
	if (vktp_bridge_object == NULL || vktp_mid_is_permission_granted == NULL) {
		return -1;
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return -1;
	}
	jboolean granted = (*env)->CallBooleanMethod(env, vktp_bridge_object, vktp_mid_is_permission_granted);
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		vktp_detach_env(attached);
		return -1;
	}
	vktp_detach_env(attached);
	return granted ? 1 : 0;
}

static char* vktp_call_string3(
	jmethodID method,
	const char* value1,
	const char* value2,
	const char* value3
) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge is not registered");
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge could not attach to the JVM");
	}

	jstring arg1 = (*env)->NewStringUTF(env, value1 == NULL ? "" : value1);
	jstring arg2 = (*env)->NewStringUTF(env, value2 == NULL ? "" : value2);
	jstring arg3 = (*env)->NewStringUTF(env, value3 == NULL ? "" : value3);
	jstring result = (jstring)(*env)->CallObjectMethod(env, vktp_bridge_object, method, arg1, arg2, arg3);
	char* out = NULL;
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		out = vktp_strdup_or_null("android platform tunnel bridge method threw an exception");
	} else {
		out = vktp_jstring_to_error(env, result);
	}
	if (result != NULL) {
		(*env)->DeleteLocalRef(env, result);
	}
	(*env)->DeleteLocalRef(env, arg1);
	(*env)->DeleteLocalRef(env, arg2);
	(*env)->DeleteLocalRef(env, arg3);
	vktp_detach_env(attached);
	return out;
}

static char* vktp_call_string4(
	jmethodID method,
	const char* value1,
	const char* value2,
	const char* value3,
	const char* value4
) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge is not registered");
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge could not attach to the JVM");
	}

	jstring arg1 = (*env)->NewStringUTF(env, value1 == NULL ? "" : value1);
	jstring arg2 = (*env)->NewStringUTF(env, value2 == NULL ? "" : value2);
	jstring arg3 = (*env)->NewStringUTF(env, value3 == NULL ? "" : value3);
	jstring arg4 = (*env)->NewStringUTF(env, value4 == NULL ? "" : value4);
	jstring result = (jstring)(*env)->CallObjectMethod(env, vktp_bridge_object, method, arg1, arg2, arg3, arg4);
	char* out = NULL;
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		out = vktp_strdup_or_null("android platform tunnel bridge method threw an exception");
	} else {
		out = vktp_jstring_to_error(env, result);
	}
	if (result != NULL) {
		(*env)->DeleteLocalRef(env, result);
	}
	(*env)->DeleteLocalRef(env, arg1);
	(*env)->DeleteLocalRef(env, arg2);
	(*env)->DeleteLocalRef(env, arg3);
	(*env)->DeleteLocalRef(env, arg4);
	vktp_detach_env(attached);
	return out;
}

static char* vktp_call_string1(jmethodID method, const char* value1) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge is not registered");
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge could not attach to the JVM");
	}

	jstring arg1 = (*env)->NewStringUTF(env, value1 == NULL ? "" : value1);
	jstring result = (jstring)(*env)->CallObjectMethod(env, vktp_bridge_object, method, arg1);
	char* out = NULL;
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		out = vktp_strdup_or_null("android platform tunnel bridge method threw an exception");
	} else {
		out = vktp_jstring_to_error(env, result);
	}
	if (result != NULL) {
		(*env)->DeleteLocalRef(env, result);
	}
	(*env)->DeleteLocalRef(env, arg1);
	vktp_detach_env(attached);
	return out;
}

static char* vktp_call_string0(jmethodID method) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge is not registered");
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge could not attach to the JVM");
	}
	jstring result = (jstring)(*env)->CallObjectMethod(env, vktp_bridge_object, method);
	char* out = NULL;
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		out = vktp_strdup_or_null("android platform tunnel bridge method threw an exception");
	} else {
		out = vktp_jstring_to_error(env, result);
	}
	if (result != NULL) {
		(*env)->DeleteLocalRef(env, result);
	}
	vktp_detach_env(attached);
	return out;
}

static int vktp_call_int0(jmethodID method) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return -1;
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return -1;
	}
	jint result = (*env)->CallIntMethod(env, vktp_bridge_object, method);
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		vktp_detach_env(attached);
		return -1;
	}
	vktp_detach_env(attached);
	return (int)result;
}

static char* vktp_call_string_int1(jmethodID method, int value1) {
	if (vktp_bridge_object == NULL || method == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge is not registered");
	}
	int attached = 0;
	JNIEnv *env = vktp_attach_env(&attached);
	if (env == NULL) {
		return vktp_strdup_or_null("android platform tunnel bridge could not attach to the JVM");
	}
	jstring result = (jstring)(*env)->CallObjectMethod(env, vktp_bridge_object, method, (jint)value1);
	char* out = NULL;
	if ((*env)->ExceptionCheck(env)) {
		vktp_clear_exception(env);
		out = vktp_strdup_or_null("android platform tunnel bridge method threw an exception");
	} else {
		out = vktp_jstring_to_error(env, result);
	}
	if (result != NULL) {
		(*env)->DeleteLocalRef(env, result);
	}
	vktp_detach_env(attached);
	return out;
}

char* vktp_android_vpn_validate_route_policy(const char* policy, const char* underlay_policy, const char* allowed, const char* disallowed) {
	return vktp_call_string4(vktp_mid_validate_route_policy, policy, underlay_policy, allowed, disallowed);
}

char* vktp_android_vpn_bringup_host(const char* config_json) {
	return vktp_call_string1(vktp_mid_bringup_host, config_json);
}

char* vktp_android_vpn_protect_socket(int fd) {
	return vktp_call_string_int1(vktp_mid_protect_socket, fd);
}

char* vktp_android_vpn_cleanup() {
	return vktp_call_string0(vktp_mid_cleanup_host);
}

int vktp_android_vpn_duplicate_tun_fd() {
	return vktp_call_int0(vktp_mid_duplicate_tun_fd);
}
*/
import "C"

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"unsafe"

	"github.com/defin85/vk-turn-proxy-go/internal/androidembeddedhost"
	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type androidVPNHostConfig struct {
	Policy              string   `json:"policy"`
	UnderlayRoutePolicy string   `json:"underlay_route_policy,omitempty"`
	AllowedPackages     []string `json:"allowed_packages,omitempty"`
	DisallowedPackages  []string `json:"disallowed_packages,omitempty"`
	ClientAddresses     []string `json:"client_addresses"`
	DNSServers          []string `json:"dns_servers,omitempty"`
	IncludedRoutes      []string `json:"included_routes"`
	MTU                 int      `json:"mtu,omitempty"`
}

type VPNServiceLifecycle struct {
	mu      sync.Mutex
	runtime *wireguardturnruntime.Runtime
}

func NewVPNServiceLifecycle() *VPNServiceLifecycle {
	return &VPNServiceLifecycle{}
}

func Register(env, bridge unsafe.Pointer) {
	C.vktp_register_platform_tunnel_bridge(env, bridge)
}

func Clear(env unsafe.Pointer) {
	C.vktp_clear_platform_tunnel_bridge(env)
}

func (l *VPNServiceLifecycle) AcquirePermission(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	switch int(C.vktp_android_vpn_permission_state()) {
	case 1:
		return nil
	case 0:
		return androidembeddedhost.NewAndroidPermissionPendingError(
			"Android VPN permission is required before startup can continue.",
		)
	default:
		return fmt.Errorf("android platform tunnel bridge is not registered")
	}
}

func (l *VPNServiceLifecycle) ResumeAfterPermission(_ context.Context, _ string, _ clientcontrol.PlatformTunnelStartRequest) error {
	if int(C.vktp_android_vpn_permission_state()) != 1 {
		return fmt.Errorf("Android VPN permission is still not granted")
	}
	return nil
}

func (l *VPNServiceLifecycle) ValidateRoutePolicy(
	_ context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
) error {
	if err := callBridgeString4Value(
		func(cValue1, cValue2, cValue3, cValue4 *C.char) *C.char {
			return C.vktp_android_vpn_validate_route_policy(cValue1, cValue2, cValue3, cValue4)
		},
		string(req.ApplicationRoutingPolicy),
		string(req.UnderlayRoutePolicy),
		joinPackages(req.AllowedPackages),
		joinPackages(req.DisallowedPackages),
	); err != nil {
		if req.UnderlayRoutePolicy == clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
			return androidembeddedhost.NewAndroidRouteExclusionError(err.Error())
		}
		return androidembeddedhost.NewAndroidAppRoutingPolicyError(err.Error())
	}
	return nil
}

func (l *VPNServiceLifecycle) BringupHost(
	_ context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) error {
	config, err := androidVPNHostConfigFrom(req, lease)
	if err != nil {
		return err
	}
	payload, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("marshal Android VPN host config: %w", err)
	}
	return callBridgeString1Value(
		func(value *C.char) *C.char {
			return C.vktp_android_vpn_bringup_host(value)
		},
		string(payload),
	)
}

func (l *VPNServiceLifecycle) AttachRuntime(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) error {
	if strings.TrimSpace(req.ResolutionID) == "" {
		return fmt.Errorf("android runtime attach requires resolution_id")
	}
	if req.RuntimeDefaults == nil {
		return fmt.Errorf("android runtime attach requires runtime_defaults")
	}
	if lease == nil {
		return fmt.Errorf("android runtime attach requires a strict TURN datagram WireGuard execution lease")
	}
	tunFD, err := duplicateAndroidVPNTUNFD()
	if err != nil {
		return err
	}
	runtime, err := wireguardturnruntime.Start(
		ctx,
		wireguardturnruntime.Config{
			Lease: lease,
			TUNFD: tunFD,
			ProtectSocket: func(fd int) error {
				return bridgeError(C.vktp_android_vpn_protect_socket(C.int(fd)))
			},
		},
	)
	if err != nil {
		return fmt.Errorf("start Android strict WireGuard runtime: %w", err)
	}
	if err := l.replaceRuntime(runtime); err != nil {
		_ = runtime.Close()
		return fmt.Errorf("replace Android strict WireGuard runtime: %w", err)
	}
	return nil
}

func (l *VPNServiceLifecycle) Cleanup(_ context.Context) error {
	return errors.Join(l.closeRuntime(), bridgeError(C.vktp_android_vpn_cleanup()))
}

func joinPackages(packages []string) string {
	if len(packages) == 0 {
		return ""
	}
	out := make([]string, 0, len(packages))
	for _, pkg := range packages {
		if trimmed := strings.TrimSpace(pkg); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return strings.Join(out, "\n")
}

func callBridgeString3Value(
	fn func(*C.char, *C.char, *C.char) *C.char,
	value1 string,
	value2 string,
	value3 string,
) error {
	cValue1 := C.CString(value1)
	cValue2 := C.CString(value2)
	cValue3 := C.CString(value3)
	defer C.free(unsafe.Pointer(cValue1))
	defer C.free(unsafe.Pointer(cValue2))
	defer C.free(unsafe.Pointer(cValue3))

	errValue := fn(cValue1, cValue2, cValue3)
	return bridgeError(errValue)
}

func callBridgeString4Value(
	fn func(*C.char, *C.char, *C.char, *C.char) *C.char,
	value1 string,
	value2 string,
	value3 string,
	value4 string,
) error {
	cValue1 := C.CString(value1)
	cValue2 := C.CString(value2)
	cValue3 := C.CString(value3)
	cValue4 := C.CString(value4)
	defer C.free(unsafe.Pointer(cValue1))
	defer C.free(unsafe.Pointer(cValue2))
	defer C.free(unsafe.Pointer(cValue3))
	defer C.free(unsafe.Pointer(cValue4))

	errValue := fn(cValue1, cValue2, cValue3, cValue4)
	return bridgeError(errValue)
}

func callBridgeString1Value(fn func(*C.char) *C.char, value string) error {
	cValue := C.CString(value)
	defer C.free(unsafe.Pointer(cValue))

	errValue := fn(cValue)
	return bridgeError(errValue)
}

func duplicateAndroidVPNTUNFD() (int, error) {
	fd := int(C.vktp_android_vpn_duplicate_tun_fd())
	if fd <= 0 {
		return 0, fmt.Errorf("android platform tunnel bridge could not duplicate the active VpnService TUN file descriptor")
	}
	return fd, nil
}

func androidVPNHostConfigFrom(
	req clientcontrol.PlatformTunnelStartRequest,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) (*androidVPNHostConfig, error) {
	if lease == nil {
		return nil, fmt.Errorf("android vpn host bring-up requires a strict TURN datagram WireGuard execution lease")
	}
	config := &androidVPNHostConfig{
		Policy:              string(req.ApplicationRoutingPolicy),
		UnderlayRoutePolicy: string(req.UnderlayRoutePolicy),
		AllowedPackages:     append([]string(nil), req.AllowedPackages...),
		DisallowedPackages:  append([]string(nil), req.DisallowedPackages...),
		ClientAddresses:     append([]string(nil), lease.ClientAddresses...),
		DNSServers:          append([]string(nil), lease.DNSServers...),
		IncludedRoutes:      append([]string(nil), lease.AllowedIPs...),
		MTU:                 lease.MTU,
	}
	if len(config.ClientAddresses) == 0 {
		return nil, fmt.Errorf("android vpn host bring-up requires at least one client address")
	}
	if len(config.IncludedRoutes) == 0 {
		return nil, fmt.Errorf("android vpn host bring-up requires at least one included route")
	}
	if strings.TrimSpace(config.Policy) == "" {
		config.Policy = string(clientcontrol.PlatformTunnelApplicationRoutingPolicyAllApps)
	}
	if strings.TrimSpace(config.UnderlayRoutePolicy) == "" {
		config.UnderlayRoutePolicy = string(clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard)
	}
	return config, nil
}

func (l *VPNServiceLifecycle) replaceRuntime(runtime *wireguardturnruntime.Runtime) error {
	l.mu.Lock()
	previous := l.runtime
	l.runtime = runtime
	l.mu.Unlock()
	if previous == nil {
		return nil
	}
	return previous.Close()
}

func (l *VPNServiceLifecycle) closeRuntime() error {
	l.mu.Lock()
	runtime := l.runtime
	l.runtime = nil
	l.mu.Unlock()
	if runtime == nil {
		return nil
	}
	return runtime.Close()
}

func bridgeError(value *C.char) error {
	if value == nil {
		return nil
	}
	defer C.free(unsafe.Pointer(value))
	message := strings.TrimSpace(C.GoString(value))
	if message == "" {
		return nil
	}
	return fmt.Errorf("%s", message)
}
