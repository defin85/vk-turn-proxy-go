package com.defin85.mobile_gui_shell

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val MOBILE_HOST_BRIDGE_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private const val MOBILE_HOST_BRIDGE_BROWSER_RETURN_SIGNAL_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals"
private const val MOBILE_HOST_URL_META_DATA =
    "com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL"

class MainActivity : FlutterActivity() {
    private var mobileHostBridgeChannel: MethodChannel? = null
    private var browserReturnSignalChannel: EventChannel? = null
    private var browserReturnSignalSink: EventChannel.EventSink? = null
    private val pendingBrowserReturnSignals = mutableListOf<Map<String, Any>>()
    private var pendingPlatformTunnelPermissionResult: MethodChannel.Result? = null
    private val platformTunnelBridge by lazy {
        AndroidPlatformTunnelBridge(applicationContext)
    }
    private val platformTunnelPermissionLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            finishPlatformTunnelPermissionRequest(result.resultCode == Activity.RESULT_OK)
        }

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
                    "requestPlatformTunnelPermission" ->
                        requestPlatformTunnelPermission(call, result)
                    else -> result.notImplemented()
                }
            }
        }
        browserReturnSignalChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MOBILE_HOST_BRIDGE_BROWSER_RETURN_SIGNAL_CHANNEL,
        ).apply {
            setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(
                        arguments: Any?,
                        events: EventChannel.EventSink,
                    ) {
                        browserReturnSignalSink = events
                        flushPendingBrowserReturnSignals()
                    }

                    override fun onCancel(arguments: Any?) {
                        browserReturnSignalSink = null
                    }
                },
            )
        }
        EmbeddedMobileHost.registerPlatformTunnelBridge(platformTunnelBridge)
        emitBrowserReturnSignalFromIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        finishPlatformTunnelPermissionRequest(null)
        EmbeddedMobileHost.clearPlatformTunnelBridge()
        EmbeddedMobileHost.stop()
        mobileHostBridgeChannel?.setMethodCallHandler(null)
        mobileHostBridgeChannel = null
        browserReturnSignalChannel?.setStreamHandler(null)
        browserReturnSignalChannel = null
        browserReturnSignalSink = null
        pendingBrowserReturnSignals.clear()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        emitBrowserReturnSignalFromIntent(intent)
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

    private fun emitBrowserReturnSignalFromIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) {
            return
        }
        emitBrowserReturnSignal(
            kind = "app_link",
            uri = intent.dataString?.trim()?.takeIf { value -> value.isNotEmpty() },
        )
    }

    private fun emitBrowserReturnSignal(kind: String, uri: String?) {
        val payload = mutableMapOf<String, Any>("kind" to kind)
        if (!uri.isNullOrEmpty()) {
            payload["uri"] = uri
        }
        val sink = browserReturnSignalSink
        if (sink == null) {
            pendingBrowserReturnSignals.add(payload)
            return
        }
        sink.success(payload)
    }

    private fun flushPendingBrowserReturnSignals() {
        val sink = browserReturnSignalSink ?: return
        for (payload in pendingBrowserReturnSignals) {
            sink.success(payload)
        }
        pendingBrowserReturnSignals.clear()
    }

    private fun requestPlatformTunnelPermission(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val mode = call.argument<String>("mode")?.trim().orEmpty()
        if (mode != "android_vpn_service") {
            result.error(
                "unsupported_platform_tunnel_mode",
                "Native Android permission flow supports only android_vpn_service.",
                null,
            )
            return
        }
        if (pendingPlatformTunnelPermissionResult != null) {
            result.error(
                "platform_tunnel_permission_in_progress",
                "An Android VPN permission request is already in progress.",
                null,
            )
            return
        }

        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent == null) {
            result.success(true)
            return
        }

        pendingPlatformTunnelPermissionResult = result
        platformTunnelPermissionLauncher.launch(prepareIntent)
    }

    private fun finishPlatformTunnelPermissionRequest(granted: Boolean?) {
        val pending = pendingPlatformTunnelPermissionResult ?: return
        pendingPlatformTunnelPermissionResult = null
        when (granted) {
            null ->
                pending.error(
                    "platform_tunnel_permission_cancelled",
                    "The Android VPN permission request was cancelled before completion.",
                    null,
                )
            else -> pending.success(granted)
        }
    }
}
