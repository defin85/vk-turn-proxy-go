package com.defin85.relaydock

import android.content.Context
import java.io.File

internal object EmbeddedMobileHostNative {
    init {
        System.loadLibrary("android_mobile_host_jni")
    }

    external fun ensureStarted(): String?
    external fun lastError(): String?
    external fun stopEmbeddedHost()
    external fun registerPlatformTunnelBridge(bridge: Any)
    external fun clearPlatformTunnelBridge()
    external fun setAndroidWireGuardProfilePath(path: String?)
}

internal object EmbeddedMobileHost {
    private const val APP_WIREGUARD_PROFILE_PATH = "wireguard/android-vpn-service.conf"
    private const val MAX_WIREGUARD_PROFILE_BYTES = 256 * 1024

    fun ensureStarted(context: Context): String {
        restoreConfiguredWireGuardProfile(context)
        val baseUrl = EmbeddedMobileHostNative.ensureStarted()?.trim().orEmpty()
        if (baseUrl.isNotEmpty()) {
            return baseUrl
        }
        val message = EmbeddedMobileHostNative.lastError()?.trim().orEmpty()
        if (message.isNotEmpty()) {
            throw IllegalStateException(message)
        }
        throw IllegalStateException("Android embedded mobile host did not return a loopback base URL.")
    }

    fun stop() {
        EmbeddedMobileHostNative.stopEmbeddedHost()
    }

    fun registerPlatformTunnelBridge(bridge: Any) {
        EmbeddedMobileHostNative.registerPlatformTunnelBridge(bridge)
    }

    fun clearPlatformTunnelBridge() {
        EmbeddedMobileHostNative.clearPlatformTunnelBridge()
    }

    fun wireGuardProfileStatus(context: Context): Map<String, Any> {
        val profile = wireGuardProfileFile(context)
        return mapOf(
            "platform_available" to true,
            "configured" to profile.isFile,
            "bytes" to if (profile.isFile) profile.length() else 0L,
        )
    }

    fun configureWireGuardProfile(context: Context, contents: String): Map<String, Any> {
        val normalized = contents.trim()
        if (normalized.isEmpty()) {
            throw IllegalArgumentException("WireGuard configuration is empty.")
        }
        val encoded = normalized.toByteArray(Charsets.UTF_8)
        if (encoded.size > MAX_WIREGUARD_PROFILE_BYTES) {
            throw IllegalArgumentException("WireGuard configuration is too large.")
        }
        val profile = wireGuardProfileFile(context)
        profile.parentFile?.mkdirs()
        profile.writeBytes(encoded + byteArrayOf('\n'.code.toByte()))
        EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(profile.absolutePath)
        return wireGuardProfileStatus(context)
    }

    fun clearWireGuardProfile(context: Context): Map<String, Any> {
        val profile = wireGuardProfileFile(context)
        if (profile.exists() && !profile.delete()) {
            throw IllegalStateException("Failed to delete the app-owned WireGuard configuration.")
        }
        EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(null)
        return wireGuardProfileStatus(context)
    }

    private fun restoreConfiguredWireGuardProfile(context: Context) {
        val profile = wireGuardProfileFile(context)
        EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(
            if (profile.isFile) profile.absolutePath else null,
        )
    }

    private fun wireGuardProfileFile(context: Context): File {
        return File(context.filesDir, APP_WIREGUARD_PROFILE_PATH)
    }
}
