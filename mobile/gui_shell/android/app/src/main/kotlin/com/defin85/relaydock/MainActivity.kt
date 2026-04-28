package com.defin85.relaydock

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.net.VpnService
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewDatabase
import android.webkit.WebStorage
import android.view.WindowInsets
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import androidx.core.content.getSystemService
import androidx.webkit.ScriptHandler
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebStorageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import io.flutter.plugins.webviewflutter.WebViewProxyApi
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.regex.Pattern
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.roundToInt

private const val MOBILE_HOST_BRIDGE_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge"
private const val MOBILE_HOST_BRIDGE_BROWSER_RETURN_SIGNAL_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_host_bridge/browser_return_signals"
private const val MOBILE_PORTABLE_PROFILE_INGRESS_CHANNEL =
    "com.defin85.vk_turn_proxy_go/mobile_portable_profile_transfer/ingress"
private const val MOBILE_HOST_URL_META_DATA =
    "com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL"
private const val PLATFORM_TUNNEL_PERMISSION_REQUEST_CODE = 1001

class MainActivity : FlutterActivity() {
    private var mobileHostBridgeChannel: MethodChannel? = null
    private var browserReturnSignalChannel: EventChannel? = null
    private var browserReturnSignalSink: EventChannel.EventSink? = null
    private var portableProfileIngressChannel: EventChannel? = null
    private var portableProfileIngressSink: EventChannel.EventSink? = null
    private var boundFlutterEngine: FlutterEngine? = null
    private val pendingBrowserReturnSignals = mutableListOf<Map<String, Any>>()
    private val pendingPortableProfileIngressPayloads = mutableListOf<String>()
    private var pendingPlatformTunnelPermissionResult: MethodChannel.Result? = null
    private val documentStartScriptHandlers = mutableMapOf<Long, ScriptHandler>()
    private val defaultUserAgentMetadataByWebView = mutableMapOf<Long, UserAgentMetadata>()
    private val appInventoryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
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
                    "clearOwnedBrowserSessionState" ->
                        clearOwnedBrowserSessionState(result)
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
                    "setWebViewUserAgentMetadata" ->
                        try {
                            setWebViewUserAgentMetadata(call)
                            result.success(null)
                        } catch (error: IllegalArgumentException) {
                            result.error(
                                "invalid_webview_user_agent_metadata_request",
                                error.message ?: "Invalid native WebView user-agent metadata request.",
                                null,
                            )
                        } catch (error: IllegalStateException) {
                            result.error(
                                "webview_user_agent_metadata_unavailable",
                                error.message ?: "Native WebView user-agent metadata is unavailable.",
                                null,
                            )
                        }
                    "listInstalledApps" -> listInstalledApps(result)
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
        portableProfileIngressChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MOBILE_PORTABLE_PROFILE_INGRESS_CHANNEL,
        ).apply {
            setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(
                        arguments: Any?,
                        events: EventChannel.EventSink,
                    ) {
                        portableProfileIngressSink = events
                        flushPendingPortableProfileIngressPayloads()
                    }

                    override fun onCancel(arguments: Any?) {
                        portableProfileIngressSink = null
                    }
                },
            )
        }
        EmbeddedMobileHost.registerPlatformTunnelBridge(platformTunnelBridge)
        emitPortableProfileIngressFromIntent(intent)
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
        portableProfileIngressChannel?.setStreamHandler(null)
        portableProfileIngressChannel = null
        portableProfileIngressSink = null
        boundFlutterEngine = null
        pendingBrowserReturnSignals.clear()
        pendingPortableProfileIngressPayloads.clear()
        appInventoryExecutor.shutdownNow()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        emitPortableProfileIngressFromIntent(intent)
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
        val scheme = intent.data?.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") {
            return
        }
        emitBrowserReturnSignal(
            kind = "app_link",
            uri = intent.dataString?.trim()?.takeIf { value -> value.isNotEmpty() },
        )
    }

    private fun emitPortableProfileIngressFromIntent(intent: Intent?) {
        val payload = extractPortableProfileIngressPayload(intent) ?: return
        emitPortableProfileIngress(payload)
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

    private fun emitPortableProfileIngress(payload: String) {
        val trimmed = payload.trim()
        if (trimmed.isEmpty()) {
            return
        }
        val sink = portableProfileIngressSink
        if (sink == null) {
            pendingPortableProfileIngressPayloads.add(trimmed)
            return
        }
        sink.success(trimmed)
    }

    private fun flushPendingBrowserReturnSignals() {
        val sink = browserReturnSignalSink ?: return
        for (payload in pendingBrowserReturnSignals) {
            sink.success(payload)
        }
        pendingBrowserReturnSignals.clear()
    }

    private fun flushPendingPortableProfileIngressPayloads() {
        val sink = portableProfileIngressSink ?: return
        for (payload in pendingPortableProfileIngressPayloads) {
            sink.success(payload)
        }
        pendingPortableProfileIngressPayloads.clear()
    }

    private fun extractPortableProfileIngressPayload(intent: Intent?): String? {
        if (intent == null) {
            return null
        }
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                extractPortableProfileSharePayload(intent)
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                val scheme = uri.scheme?.lowercase()
                if (scheme == "http" || scheme == "https") {
                    null
                } else {
                    readPortableProfilePayload(uri)
                }
            }
            else -> null
        }
    }

    private fun extractPortableProfileSharePayload(intent: Intent): String? {
        val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
        if (streamUri != null) {
            return readPortableProfilePayload(streamUri)
        }
        return null
    }

    private fun readPortableProfilePayload(uri: Uri): String? {
        return try {
            val raw = when (uri.scheme?.lowercase()) {
                "file" -> uri.path?.let { path -> File(path).readText() }
                else -> contentResolver.openInputStream(uri)?.bufferedReader()?.use { reader ->
                    reader.readText()
                }
            }
            raw?.trim()?.takeIf { value -> value.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
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

    private fun clearOwnedBrowserSessionState(result: MethodChannel.Result) {
        try {
            val webStorage = WebStorage.getInstance()
            val cookieManager = CookieManager.getInstance()
            val finishReset =
                Runnable {
                    clearLegacyOwnedBrowserState(cookieManager, result)
                }
            if (WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)) {
                WebStorageCompat.deleteBrowsingData(webStorage, finishReset)
            } else {
                webStorage.deleteAllData()
                finishReset.run()
            }
        } catch (error: Exception) {
            result.error(
                "owned_browser_session_clear_failed",
                error.message ?: "Unable to clear app-owned browser session state.",
                null,
            )
        }
    }

    private fun clearLegacyOwnedBrowserState(
        cookieManager: CookieManager,
        result: MethodChannel.Result,
    ) {
        try {
            cookieManager.removeAllCookies {
                try {
                    clearAdditionalOwnedBrowserState()
                    cookieManager.flush()
                    WebView.clearClientCertPreferences {
                        result.success(null)
                    }
                } catch (error: Exception) {
                    result.error(
                        "owned_browser_session_clear_failed",
                        error.message ?: "Unable to clear app-owned browser session state.",
                        null,
                    )
                }
            }
        } catch (error: Exception) {
            result.error(
                "owned_browser_session_clear_failed",
                error.message ?: "Unable to clear app-owned browser session state.",
                null,
            )
        }
    }

    private fun clearAdditionalOwnedBrowserState() {
        val webViewDatabase = WebViewDatabase.getInstance(applicationContext)
        try {
            webViewDatabase.clearHttpAuthUsernamePassword()
        } catch (_: RuntimeException) {
        }
        try {
            webViewDatabase.clearFormData()
        } catch (_: RuntimeException) {
        }
        try {
            webViewDatabase.clearUsernamePassword()
        } catch (_: RuntimeException) {
        }

        val clearingWebView = WebView(applicationContext)
        try {
            clearingWebView.clearCache(true)
            clearingWebView.clearHistory()
            clearingWebView.clearSslPreferences()
            clearingWebView.clearFormData()
        } finally {
            clearingWebView.destroy()
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

    private fun setWebViewUserAgentMetadata(call: MethodCall) {
        val webViewIdentifier =
            call.argument<Number>("webViewIdentifier")?.toLong()
                ?: throw IllegalArgumentException("webViewIdentifier is required.")
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)) {
            throw IllegalStateException("Android WebView user-agent metadata is unsupported.")
        }
        val flutterEngine =
            boundFlutterEngine
                ?: throw IllegalStateException("Flutter engine is not currently attached.")
        val webView =
            WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, webViewIdentifier)
                ?: throw IllegalStateException(
                    "No native Android WebView is registered for identifier $webViewIdentifier.",
                )
        val settings = webView.settings
        defaultUserAgentMetadataByWebView.getOrPut(webViewIdentifier) {
            WebSettingsCompat.getUserAgentMetadata(settings)
        }
        val userAgent = call.argument<String>("userAgent")?.trim().orEmpty()
        if (userAgent.isEmpty()) {
            defaultUserAgentMetadataByWebView[webViewIdentifier]?.let { metadata ->
                WebSettingsCompat.setUserAgentMetadata(settings, metadata)
            }
            return
        }
        val baselineMetadata =
            defaultUserAgentMetadataByWebView[webViewIdentifier]
                ?: WebSettingsCompat.getUserAgentMetadata(settings)
        WebSettingsCompat.setUserAgentMetadata(
            settings,
            buildDesktopUserAgentMetadata(baselineMetadata, userAgent),
        )
    }

    private fun buildDesktopUserAgentMetadata(
        baseline: UserAgentMetadata,
        userAgent: String,
    ): UserAgentMetadata {
        val versionMatch = CHROME_VERSION_PATTERN.matcher(userAgent)
        if (!versionMatch.find()) {
            throw IllegalArgumentException("Chrome version is required in userAgent.")
        }
        val fullVersion = versionMatch.group(1)?.trim().orEmpty()
        if (fullVersion.isEmpty()) {
            throw IllegalArgumentException("Chrome version is required in userAgent.")
        }
        val majorVersion = fullVersion.substringBefore('.').ifEmpty { fullVersion }
        val brands =
            listOf(
                UserAgentMetadata.BrandVersion.Builder()
                    .setBrand("Chromium")
                    .setMajorVersion(majorVersion)
                    .setFullVersion(fullVersion)
                    .build(),
                UserAgentMetadata.BrandVersion.Builder()
                    .setBrand("Not-A.Brand")
                    .setMajorVersion("24")
                    .setFullVersion("24.0.0.0")
                    .build(),
                UserAgentMetadata.BrandVersion.Builder()
                    .setBrand("Google Chrome")
                    .setMajorVersion(majorVersion)
                    .setFullVersion(fullVersion)
                    .build(),
            )
        val metadataBuilder =
            UserAgentMetadata.Builder(baseline)
                .setBrandVersionList(brands)
                .setFullVersion(fullVersion)
                .setPlatform("Windows")
                .setPlatformVersion("10.0.0")
                .setArchitecture("x86")
                .setModel("")
                .setMobile(false)
                .setBitness(64)
                .setWow64(false)
        if (WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA_FORM_FACTORS)) {
            metadataBuilder.setFormFactors(listOf(UserAgentMetadata.FORM_FACTOR_DESKTOP))
        }
        return metadataBuilder.build()
    }

    private fun listInstalledApps(result: MethodChannel.Result) {
        appInventoryExecutor.execute {
            try {
                val installedApps = buildInstalledAppsSnapshot()
                runOnUiThread { result.success(installedApps) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "installed_apps_unavailable",
                        error.message ?: "Unable to load installed Android apps.",
                        null,
                    )
                }
            }
        }
    }

    private fun buildInstalledAppsSnapshot(): List<Map<String, Any?>> {
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
                    "icon_bytes" to applicationIconBytes(appInfo),
                )
            }
            .sortedWith(
                compareBy<Map<String, Any?>> { entry ->
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

    private fun applicationIconBytes(appInfo: ApplicationInfo): ByteArray? {
        val drawable = try {
            appInfo.loadIcon(packageManager)
        } catch (_: RuntimeException) {
            return null
        }
        return drawableToPngBytes(drawable)
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray? {
        val iconSizePx = (resources.displayMetrics.density * 24f).roundToInt().coerceAtLeast(1)
        val bitmap =
            if (drawable is BitmapDrawable && drawable.bitmap != null) {
                val source = drawable.bitmap
                if (source.width == iconSizePx && source.height == iconSizePx) {
                    source
                } else {
                    Bitmap.createScaledBitmap(source, iconSizePx, iconSizePx, true)
                }
            } else {
                Bitmap.createBitmap(iconSizePx, iconSizePx, Bitmap.Config.ARGB_8888).also { target ->
                    val canvas = Canvas(target)
                    drawable.setBounds(0, 0, iconSizePx, iconSizePx)
                    drawable.draw(canvas)
                }
            }
        return ByteArrayOutputStream().use { stream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                return null
            }
            stream.toByteArray()
        }
    }

    private fun clearDocumentStartScriptHandlers() {
        for (handler in documentStartScriptHandlers.values) {
            handler.remove()
        }
        documentStartScriptHandlers.clear()
    }
}

private val CHROME_VERSION_PATTERN: Pattern = Pattern.compile("Chrome/([0-9.]+)")
