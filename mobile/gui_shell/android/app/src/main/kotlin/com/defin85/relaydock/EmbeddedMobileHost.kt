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
    external fun setTransportProfileStorePath(path: String?)
}

internal object EmbeddedMobileHost {
    private const val APP_WIREGUARD_PROFILE_PATH = "wireguard/android-vpn-service.conf"
    private const val TRANSPORT_PROFILE_STORE_PATH = "vpn-transport-profiles/store.json"

    fun ensureStarted(context: Context): String {
        configureTransportProfileStore(context)
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

    private fun restoreConfiguredWireGuardProfile(context: Context) {
        val profile = wireGuardProfileFile(context)
        EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(
            if (profile.isFile) profile.absolutePath else null,
        )
    }

    private fun configureTransportProfileStore(context: Context) {
        val store = transportProfileStoreFile(context)
        store.parentFile?.mkdirs()
        EmbeddedMobileHostNative.setTransportProfileStorePath(store.absolutePath)
    }

    private fun transportProfileStoreFile(context: Context): File {
        return File(context.noBackupFilesDir, TRANSPORT_PROFILE_STORE_PATH)
    }

    private fun wireGuardProfileFile(context: Context): File {
        return File(context.filesDir, APP_WIREGUARD_PROFILE_PATH)
    }
}
