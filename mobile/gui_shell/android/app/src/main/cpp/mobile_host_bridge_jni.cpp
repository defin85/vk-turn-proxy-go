#include <jni.h>
#include <dlfcn.h>

#include <string>

#include "libvk_turn_mobile_host.h"

namespace {

using ensure_started_fn = char *(*)();
using last_error_fn = char *(*)();
using stop_fn = void (*)();
using free_string_fn = void (*)(char *);
using register_platform_tunnel_bridge_fn = void (*)(void *, void *);
using clear_platform_tunnel_bridge_fn = void (*)(void *);

struct HostLibrary {
    void *handle = nullptr;
    ensure_started_fn ensure_started = nullptr;
    last_error_fn last_error = nullptr;
    stop_fn stop = nullptr;
    free_string_fn free_string = nullptr;
    register_platform_tunnel_bridge_fn register_platform_tunnel_bridge = nullptr;
    clear_platform_tunnel_bridge_fn clear_platform_tunnel_bridge = nullptr;
    std::string load_error;
};

HostLibrary loadHostLibrary() {
    HostLibrary library;
    // Resolve the packaged soname at runtime instead of linking a build-tree path into the JNI shim.
    library.handle = dlopen("libvk_turn_mobile_host.so", RTLD_NOW | RTLD_LOCAL);
    if (library.handle == nullptr) {
        const char *error = dlerror();
        library.load_error = error == nullptr ? "failed to dlopen libvk_turn_mobile_host.so" : error;
        return library;
    }

    library.ensure_started = reinterpret_cast<ensure_started_fn>(
        dlsym(library.handle, "AndroidEmbeddedHostEnsureStarted"));
    library.last_error = reinterpret_cast<last_error_fn>(
        dlsym(library.handle, "AndroidEmbeddedHostLastError"));
    library.stop = reinterpret_cast<stop_fn>(
        dlsym(library.handle, "AndroidEmbeddedHostStop"));
    library.free_string = reinterpret_cast<free_string_fn>(
        dlsym(library.handle, "AndroidEmbeddedHostFreeString"));
    library.register_platform_tunnel_bridge =
        reinterpret_cast<register_platform_tunnel_bridge_fn>(
            dlsym(library.handle, "AndroidEmbeddedHostRegisterPlatformTunnelBridge"));
    library.clear_platform_tunnel_bridge =
        reinterpret_cast<clear_platform_tunnel_bridge_fn>(
            dlsym(library.handle, "AndroidEmbeddedHostClearPlatformTunnelBridge"));

    if (library.ensure_started == nullptr || library.last_error == nullptr ||
        library.stop == nullptr || library.free_string == nullptr) {
        const char *error = dlerror();
        library.load_error = error == nullptr
            ? "failed to resolve Android embedded host symbols from libvk_turn_mobile_host.so"
            : error;
        dlclose(library.handle);
        library.handle = nullptr;
        library.ensure_started = nullptr;
        library.last_error = nullptr;
        library.stop = nullptr;
        library.free_string = nullptr;
    }

    return library;
}

HostLibrary &hostLibrary() {
    static HostLibrary library = loadHostLibrary();
    return library;
}

jstring toJString(JNIEnv *env, const char *value) {
    if (value == nullptr) {
        return nullptr;
    }
    jstring result = env->NewStringUTF(value);
    hostLibrary().free_string(const_cast<char *>(value));
    return result;
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_defin85_mobile_1gui_1shell_EmbeddedMobileHostNative_ensureStarted(JNIEnv *env, jclass /*clazz*/) {
    HostLibrary &library = hostLibrary();
    if (library.ensure_started == nullptr) {
        return nullptr;
    }
    return toJString(env, library.ensure_started());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_defin85_mobile_1gui_1shell_EmbeddedMobileHostNative_lastError(JNIEnv *env, jclass /*clazz*/) {
    HostLibrary &library = hostLibrary();
    if (library.last_error == nullptr) {
        if (library.load_error.empty()) {
            return nullptr;
        }
        return env->NewStringUTF(library.load_error.c_str());
    }
    return toJString(env, library.last_error());
}

extern "C" JNIEXPORT void JNICALL
Java_com_defin85_mobile_1gui_1shell_EmbeddedMobileHostNative_stopEmbeddedHost(JNIEnv * /*env*/, jclass /*clazz*/) {
    HostLibrary &library = hostLibrary();
    if (library.stop != nullptr) {
        library.stop();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_defin85_mobile_1gui_1shell_EmbeddedMobileHostNative_registerPlatformTunnelBridge(
    JNIEnv *env,
    jclass /*clazz*/,
    jobject bridge
) {
    HostLibrary &library = hostLibrary();
    if (library.register_platform_tunnel_bridge != nullptr && bridge != nullptr) {
        library.register_platform_tunnel_bridge(env, bridge);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_defin85_mobile_1gui_1shell_EmbeddedMobileHostNative_clearPlatformTunnelBridge(
    JNIEnv *env,
    jclass /*clazz*/
) {
    HostLibrary &library = hostLibrary();
    if (library.clear_platform_tunnel_bridge != nullptr) {
        library.clear_platform_tunnel_bridge(env);
    }
}
