package com.defin85.mobile_gui_shell

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val MOBILE_HOST_BRIDGE_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private const val MOBILE_HOST_URL_META_DATA =
    "com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL"

class MainActivity : FlutterActivity() {
    private var mobileHostBridgeChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mobileHostBridgeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MOBILE_HOST_BRIDGE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "resolveHost" ->
                        try {
                            result.success(resolveHostConfiguration())
                        } catch (error: IllegalStateException) {
                            result.error(
                                "embedded_host_unavailable",
                                error.message ?: "Android embedded mobile host is unavailable.",
                                null,
                            )
                        }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        EmbeddedMobileHost.stop()
        mobileHostBridgeChannel?.setMethodCallHandler(null)
        mobileHostBridgeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun resolveHostConfiguration(): Map<String, String> {
        val configured = resolveConfiguredHostUrl()
        if (!configured.isNullOrBlank()) {
            return mapOf(
                "base_url" to configured,
                "description" to "android manifest $MOBILE_HOST_URL_META_DATA",
            )
        }
        val embeddedBaseUrl = EmbeddedMobileHost.ensureStarted()
        return mapOf(
            "base_url" to embeddedBaseUrl,
            "description" to "android embedded mobile host",
        )
    }

    private fun resolveConfiguredHostUrl(): String? {
        val applicationInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA,
        )
        return applicationInfo.metaData
            ?.getString(MOBILE_HOST_URL_META_DATA)
            ?.trim()
            ?.takeIf { value -> value.isNotEmpty() }
    }
}
