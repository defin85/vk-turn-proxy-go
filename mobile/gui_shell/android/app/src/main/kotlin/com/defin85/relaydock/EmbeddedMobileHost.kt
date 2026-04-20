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
    private const val DEV_WIREGUARD_ASSET_PATH = "wireguard/phone1.conf"

    fun ensureStarted(context: Context): String {
        stageEmbeddedWireGuardProfile(context)
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

    private fun stageEmbeddedWireGuardProfile(context: Context) {
        val assetManager = context.assets
        val targetFile = File(context.filesDir, DEV_WIREGUARD_ASSET_PATH)
        try {
            assetManager.open(DEV_WIREGUARD_ASSET_PATH).use { input ->
                targetFile.parentFile?.mkdirs()
                targetFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(targetFile.absolutePath)
        } catch (_: Exception) {
            // The packaged profile is optional. When it is absent, the host stays fail-closed.
            EmbeddedMobileHostNative.setAndroidWireGuardProfilePath(null)
        }
    }
}
