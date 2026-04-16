package com.defin85.mobile_gui_shell

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.net.VpnService
import android.view.WindowInsets
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import androidx.core.content.getSystemService
import androidx.webkit.ScriptHandler
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import io.flutter.plugins.webviewflutter.WebViewProxyApi

private const val MOBILE_HOST_BRIDGE_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private const val MOBILE_HOST_BRIDGE_BROWSER_RETURN_SIGNAL_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals"
private const val MOBILE_HOST_URL_META_DATA =
    "com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL"
private const val PLATFORM_TUNNEL_PERMISSION_REQUEST_CODE = 1001

class MainActivity : FlutterActivity() {
    private var mobileHostBridgeChannel: MethodChannel? = null
    private var browserReturnSignalChannel: EventChannel? = null
    private var browserReturnSignalSink: EventChannel.EventSink? = null
    private var boundFlutterEngine: FlutterEngine? = null
    private val pendingBrowserReturnSignals = mutableListOf<Map<String, Any>>()
    private var pendingPlatformTunnelPermissionResult: MethodChannel.Result? = null
    private val documentStartScriptHandlers = mutableMapOf<Long, ScriptHandler>()
    private val platformTunnelBridge by lazy {
        AndroidPlatformTunnelBridge(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        boundFlutterEngine = flutterEngine

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
                    "hideSoftKeyboard" -> {
                        hideSoftKeyboard()
                        result.success(null)
                    }
                    "setSoftInputMode" ->
                        try {
                            setSoftInputMode(call)
                            result.success(null)
                        } catch (error: IllegalArgumentException) {
                            result.error(
                                "unsupported_soft_input_mode",
                                error.message ?: "Unsupported Android soft input mode.",
                                null,
                            )
                        }
                    "debugInspectWebView" ->
                        try {
                            result.success(debugInspectWebView(call))
                        } catch (error: IllegalArgumentException) {
                            result.error(
                                "invalid_webview_debug_request",
                                error.message ?: "Invalid native WebView debug request.",
                                null,
                            )
                        } catch (error: IllegalStateException) {
                            result.error(
                                "webview_debug_unavailable",
                                error.message ?: "Native WebView debug snapshot is unavailable.",
                                null,
                            )
                        }
                    "installDocumentStartJavaScript" ->
                        try {
                            installDocumentStartJavaScript(call)
                            result.success(null)
                        } catch (error: IllegalArgumentException) {
                            result.error(
                                "invalid_document_start_script_request",
                                error.message ?: "Invalid document-start JavaScript request.",
                                null,
                            )
                        } catch (error: IllegalStateException) {
                            result.error(
                                "document_start_script_unavailable",
                                error.message ?: "Document-start JavaScript is unavailable.",
                                null,
                            )
                        }
                    "listInstalledApps" -> result.success(listInstalledApps())
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
        clearDocumentStartScriptHandlers()
        mobileHostBridgeChannel?.setMethodCallHandler(null)
        mobileHostBridgeChannel = null
        browserReturnSignalChannel?.setStreamHandler(null)
        browserReturnSignalChannel = null
        browserReturnSignalSink = null
        boundFlutterEngine = null
        pendingBrowserReturnSignals.clear()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        emitBrowserReturnSignalFromIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PLATFORM_TUNNEL_PERMISSION_REQUEST_CODE) {
            finishPlatformTunnelPermissionRequest(resultCode == Activity.RESULT_OK)
        }
    }

    private fun resolveHostConfiguration(): Map<String, String> {
        val configured = resolveConfiguredHostUrl()
        if (!configured.isNullOrBlank()) {
            return mapOf(
                "base_url" to configured,
                "description" to "android manifest $MOBILE_HOST_URL_META_DATA",
            )
        }
        val embeddedBaseUrl = EmbeddedMobileHost.ensureStarted(applicationContext)
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
        @Suppress("DEPRECATION")
        startActivityForResult(prepareIntent, PLATFORM_TUNNEL_PERMISSION_REQUEST_CODE)
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

    private fun hideSoftKeyboard() {
        currentFocus?.windowToken?.let { windowToken ->
            getSystemService<InputMethodManager>()?.hideSoftInputFromWindow(windowToken, 0)
        }
        window?.decorView?.windowToken?.let { windowToken ->
            getSystemService<InputMethodManager>()?.hideSoftInputFromWindow(windowToken, 0)
        }
    }

    private fun setSoftInputMode(call: MethodCall) {
        val mode = call.argument<String>("mode")?.trim().orEmpty()
        val adjustFlag =
            when (mode) {
                "adjustResize" -> WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
                "adjustNothing" -> WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
                else -> throw IllegalArgumentException("Unsupported Android soft input mode: $mode")
            }
        val currentMode = window.attributes.softInputMode
        val preservedState = currentMode and WindowManager.LayoutParams.SOFT_INPUT_MASK_STATE
        window.setSoftInputMode(preservedState or adjustFlag)
    }

    private fun installDocumentStartJavaScript(call: MethodCall) {
        val webViewIdentifier =
            call.argument<Number>("webViewIdentifier")?.toLong()
                ?: throw IllegalArgumentException("webViewIdentifier is required.")
        val javaScript =
            call.argument<String>("javaScript")
                ?.trim()
                ?.takeIf { value -> value.isNotEmpty() }
                ?: throw IllegalArgumentException("javaScript is required.")
        val allowedOriginRules =
            (call.argument<List<String>>("allowedOriginRules") ?: emptyList())
                .map { value -> value.trim() }
                .filter { value -> value.isNotEmpty() }
                .toSet()
        if (allowedOriginRules.isEmpty()) {
            throw IllegalArgumentException("allowedOriginRules must not be empty.")
        }
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            throw IllegalStateException("Android WebView document-start JavaScript is unsupported.")
        }
        val flutterEngine =
            boundFlutterEngine
                ?: throw IllegalStateException("Flutter engine is not currently attached.")
        val webView =
            WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, webViewIdentifier)
                ?: throw IllegalStateException(
                    "No Android WebView is registered for identifier $webViewIdentifier.",
                )
        documentStartScriptHandlers.remove(webViewIdentifier)?.remove()
        documentStartScriptHandlers[webViewIdentifier] =
            WebViewCompat.addDocumentStartJavaScript(
                webView,
                javaScript,
                allowedOriginRules,
            )
    }

    private fun debugInspectWebView(call: MethodCall): Map<String, Any> {
        val rawIdentifier = call.argument<Number>("webViewIdentifier")
            ?: throw IllegalArgumentException(
                "webViewIdentifier is required for native WebView inspection.",
            )
        val identifier = rawIdentifier.toLong()
        val flutterEngine = boundFlutterEngine
            ?: throw IllegalStateException("Flutter engine is not currently attached.")
        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, identifier)
            ?: throw IllegalStateException(
                "No native Android WebView is registered for identifier $identifier.",
            )

        val snapshot = linkedMapOf<String, Any>(
            "web_view_identifier" to identifier,
            "web_view_class" to webView.javaClass.name,
            "web_view_has_focus" to webView.hasFocus(),
            "web_view_is_focused" to webView.isFocused,
            "web_view_has_window_focus" to webView.hasWindowFocus(),
            "web_view_visibility" to webView.visibility,
            "web_view_width" to webView.width,
            "web_view_height" to webView.height,
            "web_view_content_height" to webView.contentHeight,
            "web_view_scroll_x" to webView.scrollX,
            "web_view_scroll_y" to webView.scrollY,
            "window_soft_input_mode" to window.attributes.softInputMode,
            "window_soft_input_mode_hex" to "0x${window.attributes.softInputMode.toString(16)}",
        )

        val location = IntArray(2)
        webView.getLocationOnScreen(location)
        snapshot["web_view_screen_x"] = location[0]
        snapshot["web_view_screen_y"] = location[1]

        webView.findFocus()?.javaClass?.name?.let { snapshot["web_view_find_focus_class"] = it }
        webView.rootView?.findFocus()?.javaClass?.name?.let {
            snapshot["root_find_focus_class"] = it
        }
        currentFocus?.javaClass?.name?.let { snapshot["activity_focus_class"] = it }
        window.decorView.findFocus()?.javaClass?.name?.let {
            snapshot["decor_focus_class"] = it
        }

        val imm = getSystemService<InputMethodManager>()
        if (imm != null) {
            snapshot["ime_accepting_text"] = imm.isAcceptingText
            snapshot["ime_active_for_web_view"] = imm.isActive(webView)
            snapshot["ime_active_for_activity_focus"] = currentFocus?.let { imm.isActive(it) } ?: false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val rootInsets = window.decorView.rootWindowInsets
            if (rootInsets != null) {
                val imeInsets = rootInsets.getInsets(WindowInsets.Type.ime())
                val systemInsets = rootInsets.getInsets(WindowInsets.Type.systemBars())
                snapshot["ime_visible"] = rootInsets.isVisible(WindowInsets.Type.ime())
                snapshot["ime_inset_bottom"] = imeInsets.bottom
                snapshot["system_inset_bottom"] = systemInsets.bottom
            }
        }

        if (webView is WebViewProxyApi.WebViewPlatformView) {
            snapshot.putAll(webView.debugSnapshot())
        }

        return snapshot
    }

    private fun listInstalledApps(): List<Map<String, Any>> {
        @Suppress("DEPRECATION")
        val installed = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        return installed
            .asSequence()
            .filter { appInfo -> appInfo.packageName != packageName }
            .map { appInfo ->
                val label =
                    packageManager.getApplicationLabel(appInfo)?.toString()?.trim().orEmpty()
                mapOf(
                    "package_name" to appInfo.packageName,
                    "label" to if (label.isEmpty()) appInfo.packageName else label,
                    "system_app" to isSystemApplication(appInfo),
                )
            }
            .sortedWith(
                compareBy<Map<String, Any>> { entry ->
                    (entry["label"] as String).lowercase()
                }.thenBy { entry -> entry["package_name"] as String },
            )
            .toList()
    }

    private fun isSystemApplication(appInfo: ApplicationInfo): Boolean {
        val flags = appInfo.flags
        return flags and ApplicationInfo.FLAG_SYSTEM != 0 ||
            flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0
    }

    private fun clearDocumentStartScriptHandlers() {
        for (handler in documentStartScriptHandlers.values) {
            handler.remove()
        }
        documentStartScriptHandlers.clear()
    }
}
