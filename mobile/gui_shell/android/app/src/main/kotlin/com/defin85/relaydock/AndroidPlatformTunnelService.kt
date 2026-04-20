package com.defin85.relaydock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.Network
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import org.json.JSONObject
import java.net.Inet4Address
import java.net.InetAddress
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal data class AndroidPlatformTunnelHostConfig(
    val policy: String,
    val underlayRoutePolicy: String,
    val allowedPackages: List<String>,
    val disallowedPackages: List<String>,
    val clientAddresses: List<String>,
    val dnsServers: List<String>,
    val includedRoutes: List<String>,
    val mtu: Int,
)

internal class AndroidPlatformTunnelService : VpnService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val hostConfig =
                    try {
                        parseHostConfig(intent.getStringExtra(EXTRA_HOST_CONFIG).orEmpty())
                    } catch (error: Exception) {
                        signalStartResult(
                            error.message ?: "Android VpnService host config could not be parsed.",
                        )
                        stopSelf()
                        return Service.START_NOT_STICKY
                    }
                val error = synchronized(lock) {
                    activeService = this
                    startForeground(NOTIFICATION_ID, buildNotification())
                    establishTunnelLocked(hostConfig)
                }
                signalStartResult(error)
                if (error != null) {
                    synchronized(lock) {
                        cleanupTunnelLocked()
                        if (activeService === this) {
                            activeService = null
                        }
                    }
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                synchronized(lock) {
                    cleanupTunnelLocked()
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return Service.START_NOT_STICKY
    }

    override fun onDestroy() {
        synchronized(lock) {
            if (activeService === this) {
                cleanupTunnelLocked()
                activeService = null
            }
        }
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VK TURN Proxy VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }
        return builder
            .setContentTitle("VK TURN Proxy")
            .setContentText("Android VPN tunnel startup is in progress.")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setOngoing(true)
            .build()
    }

    private fun establishTunnelLocked(config: AndroidPlatformTunnelHostConfig): String? {
        cleanupTunnelLocked()

        val builder =
            Builder()
                .setSession("VK TURN Proxy")
                .setMtu(config.mtu)

        for (address in config.clientAddresses) {
            val (host, prefixLength) = parseCIDR(address)
            builder.addAddress(host, prefixLength)
        }
        for (dnsServer in config.dnsServers) {
            builder.addDnsServer(dnsServer)
        }
        val includedRoutes =
            prepareIncludedRoutes(
                context = this,
                underlayRoutePolicy = config.underlayRoutePolicy,
                builder = builder,
                includedRoutes = config.includedRoutes,
            )
                ?: return "Android VpnService could not preserve the active local network safely."
        for (route in includedRoutes) {
            val (host, prefixLength) = parseCIDR(route)
            builder.addRoute(host, prefixLength)
        }

        val policyError = applyAppRoutingPolicy(
            context = this,
            builder = builder,
            policy = config.policy,
            allowedPackages = config.allowedPackages,
            disallowedPackages = config.disallowedPackages,
        )
        if (policyError != null) {
            return policyError
        }

        val descriptor = builder.establish()
            ?: return "Android VpnService.Builder.establish() returned null."
        activeTun = descriptor
        return null
    }

    companion object {
        private const val ACTION_START =
            "com.defin85.vk_turn_proxy_go.android_vpn_service.START"
        private const val ACTION_STOP =
            "com.defin85.vk_turn_proxy_go.android_vpn_service.STOP"
        private const val EXTRA_HOST_CONFIG = "host_config"
        private const val NOTIFICATION_CHANNEL_ID = "vktp_android_vpn_service"
        private const val NOTIFICATION_ID = 7341

        private val lock = Any()
        private var activeService: AndroidPlatformTunnelService? = null
        private var activeTun: ParcelFileDescriptor? = null
        private var pendingStartLatch: CountDownLatch? = null
        private var pendingStartError: String? = null

        fun validateRoutePolicy(
            context: Context,
            policy: String,
            underlayRoutePolicy: String,
            allowedPackages: List<String>,
            disallowedPackages: List<String>,
        ): String? {
            val normalizedPolicy = policy.trim()
            val packageManager = context.packageManager
            val appRoutingError =
                when (normalizedPolicy) {
                    "all_apps" -> null
                "allowed_packages" -> {
                    for (pkg in allowedPackages) {
                        if (pkg == context.packageName) {
                            return "The host app package cannot be routed through allowed_packages."
                        }
                        if (!packageExists(packageManager, pkg)) {
                            return "Allowed package $pkg is not installed on this device."
                        }
                    }
                    null
                }
                "disallowed_packages" -> {
                    for (pkg in disallowedPackages) {
                        if (!packageExists(packageManager, pkg)) {
                            return "Disallowed package $pkg is not installed on this device."
                        }
                    }
                    null
                }
                    else -> "Android VPN route policy $normalizedPolicy is not supported."
                }
            if (appRoutingError != null) {
                return appRoutingError
            }
            return when (underlayRoutePolicy.trim()) {
                "", "standard" -> null
                "preserve_active_local_network" -> {
                    if (activeUnderlayIPv4Routes(context).isEmpty()) {
                        "The active local network route exclusion could not be prepared safely."
                    } else {
                        null
                    }
                }
                else -> "Android VPN underlay route policy ${underlayRoutePolicy.trim()} is not supported."
            }
        }

        fun bringup(context: Context, configJson: String): String? {
            if (VpnService.prepare(context) != null) {
                return "Android VPN permission is still not granted."
            }
            val config =
                try {
                    parseHostConfig(configJson)
                } catch (error: Exception) {
                    return error.message ?: "Android VpnService host config could not be parsed."
                }
            val validationError =
                validateRoutePolicy(
                    context,
                    config.policy,
                    config.underlayRoutePolicy,
                    config.allowedPackages,
                    config.disallowedPackages,
                )
            if (validationError != null) {
                return validationError
            }

            val latch = CountDownLatch(1)
            synchronized(lock) {
                pendingStartLatch = latch
                pendingStartError = "Android VpnService startup did not report a result."
            }

            val intent = Intent(context, AndroidPlatformTunnelService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_HOST_CONFIG, configJson)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            if (!latch.await(5, TimeUnit.SECONDS)) {
                synchronized(lock) {
                    pendingStartLatch = null
                    pendingStartError = null
                }
                return "Android VpnService startup timed out."
            }

            return synchronized(lock) {
                val error = pendingStartError
                pendingStartLatch = null
                pendingStartError = null
                error
            }
        }

        fun duplicateTunFd(): Int {
            synchronized(lock) {
                val descriptor = activeTun ?: return -1
                return try {
                    ParcelFileDescriptor.dup(descriptor.fileDescriptor).detachFd()
                } catch (_: Exception) {
                    -1
                }
            }
        }

        fun protectSocket(fd: Int): String? {
            if (fd <= 0) {
                return "Android VpnService received invalid socket fd."
            }
            synchronized(lock) {
                val service =
                    activeService
                        ?: return "Android VpnService is not active."
                return if (service.protect(fd)) {
                    null
                } else {
                    "Android VpnService could not protect the TURN socket."
                }
            }
        }

        fun cleanup(): String? {
            synchronized(lock) {
                cleanupTunnelLocked()
                activeService?.let { service ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        service.stopForeground(STOP_FOREGROUND_REMOVE)
                    } else {
                        @Suppress("DEPRECATION")
                        service.stopForeground(true)
                    }
                }
                activeService?.stopSelf()
                activeService = null
            }
            return null
        }

        private fun signalStartResult(error: String?) {
            synchronized(lock) {
                pendingStartError = error
                pendingStartLatch?.countDown()
            }
        }

        private fun cleanupTunnelLocked() {
            try {
                activeTun?.close()
            } catch (_: Exception) {
            }
            activeTun = null
        }

        private fun applyAppRoutingPolicy(
            context: Context,
            builder: Builder,
            policy: String,
            allowedPackages: List<String>,
            disallowedPackages: List<String>,
        ): String? {
            return try {
                when (policy.trim()) {
                    "all_apps" -> {
                        builder.addDisallowedApplication(context.packageName)
                        null
                    }
                    "allowed_packages" -> {
                        for (pkg in allowedPackages) {
                            builder.addAllowedApplication(pkg)
                        }
                        null
                    }
                    "disallowed_packages" -> {
                        builder.addDisallowedApplication(context.packageName)
                        for (pkg in disallowedPackages) {
                            if (pkg != context.packageName) {
                                builder.addDisallowedApplication(pkg)
                            }
                        }
                        null
                    }
                    else -> "Android VPN route policy ${policy.trim()} is not supported."
                }
            } catch (error: Exception) {
                error.message ?: "Android VpnService.Builder package policy application failed."
            }
        }

        private fun prepareIncludedRoutes(
            context: Context,
            underlayRoutePolicy: String,
            builder: Builder,
            includedRoutes: List<String>,
        ): List<String>? {
            val normalizedUnderlayPolicy = underlayRoutePolicy.trim()
            if (normalizedUnderlayPolicy != "preserve_active_local_network") {
                return includedRoutes
            }
            val (activeNetwork, exclusions) = activeUnderlayIPv4Snapshot(context) ?: return null
            if (exclusions.isEmpty()) {
                return null
            }
            trySetUnderlyingNetwork(builder, activeNetwork)
            if (tryExcludeRoutes(builder, exclusions)) {
                return includedRoutes
            }

            val expandedRoutes = mutableListOf<String>()
            for (route in includedRoutes) {
                val ipv4Route = parseIPv4Route(route)
                if (ipv4Route == null) {
                    expandedRoutes += route
                    continue
                }
                var remaining = listOf(ipv4Route)
                for (excluded in exclusions) {
                    remaining =
                        remaining.flatMap { candidate ->
                            subtractIPv4Route(candidate, excluded)
                        }
                    if (remaining.isEmpty()) {
                        break
                    }
                }
                expandedRoutes += remaining.map { it.toCIDR() }
            }
            return expandedRoutes
        }

        private fun activeUnderlayIPv4Snapshot(context: Context): Pair<Network, List<IPv4Route>>? {
            val connectivityManager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    ?: return null
            val activeNetwork = connectivityManager.activeNetwork ?: return null
            val linkProperties = connectivityManager.getLinkProperties(activeNetwork) ?: return null
            val routes =
                linkProperties.linkAddresses
                    .mapNotNull { linkAddress ->
                        val address = linkAddress.address
                        if (address !is Inet4Address) {
                            return@mapNotNull null
                        }
                        IPv4Route.from(address.hostAddress.orEmpty(), linkAddress.prefixLength)
                    }
                    .distinct()
            return activeNetwork to routes
        }

        private fun activeUnderlayIPv4Routes(context: Context): List<IPv4Route> {
            return activeUnderlayIPv4Snapshot(context)?.second ?: emptyList()
        }

        private fun trySetUnderlyingNetwork(builder: Builder, activeNetwork: Network) {
            try {
                val method =
                    Builder::class.java.getMethod(
                        "setUnderlyingNetworks",
                        Array<Network>::class.java,
                    )
                method.invoke(builder, arrayOf(activeNetwork))
            } catch (_: Throwable) {
            }
        }

        private fun tryExcludeRoutes(builder: Builder, exclusions: List<IPv4Route>): Boolean {
            return try {
                val method = Builder::class.java.getMethod("excludeRoute", IpPrefix::class.java)
                for (route in exclusions) {
                    val prefix = IpPrefix(InetAddress.getByName(route.hostAddress), route.prefixLength)
                    method.invoke(builder, prefix)
                }
                true
            } catch (_: Throwable) {
                false
            }
        }

        private fun subtractIPv4Route(route: IPv4Route, excluded: IPv4Route): List<IPv4Route> {
            if (!route.overlaps(excluded)) {
                return listOf(route)
            }
            if (excluded.covers(route)) {
                return emptyList()
            }
            if (route.prefixLength >= 32) {
                return emptyList()
            }
            val (left, right) = route.split()
            return subtractIPv4Route(left, excluded) + subtractIPv4Route(right, excluded)
        }

        private fun parseHostConfig(configJson: String): AndroidPlatformTunnelHostConfig {
            val json = JSONObject(configJson)
            val policy = json.optString("policy").trim()
            if (policy.isEmpty()) {
                throw IllegalArgumentException("Android VpnService host config is missing policy.")
            }
            val clientAddresses = readStringArray(json, "client_addresses")
            if (clientAddresses.isEmpty()) {
                throw IllegalArgumentException(
                    "Android VpnService host config is missing client_addresses.",
                )
            }
            val includedRoutes = readStringArray(json, "included_routes")
            if (includedRoutes.isEmpty()) {
                throw IllegalArgumentException(
                    "Android VpnService host config is missing included_routes.",
                )
            }
            val mtu = json.optInt("mtu", 1280).coerceAtLeast(1280)
            return AndroidPlatformTunnelHostConfig(
                policy = policy,
                underlayRoutePolicy =
                    json.optString("underlay_route_policy").trim().ifEmpty { "standard" },
                allowedPackages = readStringArray(json, "allowed_packages"),
                disallowedPackages = readStringArray(json, "disallowed_packages"),
                clientAddresses = clientAddresses,
                dnsServers = readStringArray(json, "dns_servers"),
                includedRoutes = includedRoutes,
                mtu = mtu,
            )
        }

        private fun readStringArray(json: JSONObject, key: String): List<String> {
            val array = json.optJSONArray(key) ?: return emptyList()
            return (0 until array.length())
                .map { index -> array.optString(index).trim() }
                .filter { it.isNotEmpty() }
        }

        private fun parseCIDR(value: String): Pair<String, Int> {
            val separator = value.lastIndexOf('/')
            if (separator <= 0 || separator >= value.lastIndex) {
                throw IllegalArgumentException("Android VpnService received invalid CIDR $value.")
            }
            val host = value.substring(0, separator).trim()
            val prefixLength = value.substring(separator + 1).trim().toInt()
            if (host.isEmpty()) {
                throw IllegalArgumentException("Android VpnService received invalid CIDR $value.")
            }
            return host to prefixLength
        }

        private data class IPv4Route(
            val network: Long,
            val prefixLength: Int,
        ) {
            val hostAddress: String
                get() = toIPv4String(network)

            val size: Long
                get() = 1L shl (32 - prefixLength)

            val lastAddress: Long
                get() = network + size - 1

            fun overlaps(other: IPv4Route): Boolean =
                network <= other.lastAddress && other.network <= lastAddress

            fun covers(other: IPv4Route): Boolean =
                network <= other.network && lastAddress >= other.lastAddress

            fun split(): Pair<IPv4Route, IPv4Route> {
                val childPrefix = prefixLength + 1
                val childSize = 1L shl (32 - childPrefix)
                return IPv4Route(network, childPrefix) to
                    IPv4Route(network + childSize, childPrefix)
            }

            fun toCIDR(): String = "${toIPv4String(network)}/$prefixLength"

            companion object {
                fun from(host: String, prefixLength: Int): IPv4Route? {
                    if (prefixLength !in 0..32) {
                        return null
                    }
                    val address = parseIPv4Host(host) ?: return null
                    val mask =
                        if (prefixLength == 0) {
                            0L
                        } else {
                            (0xFFFF_FFFFL shl (32 - prefixLength)) and 0xFFFF_FFFFL
                        }
                    return IPv4Route(address and mask, prefixLength)
                }
            }
        }

        private fun parseIPv4Route(value: String): IPv4Route? {
            val separator = value.lastIndexOf('/')
            if (separator <= 0 || separator >= value.lastIndex) {
                return null
            }
            val host = value.substring(0, separator).trim()
            val prefixLength = value.substring(separator + 1).trim().toIntOrNull() ?: return null
            return IPv4Route.from(host, prefixLength)
        }

        private fun parseIPv4Host(host: String): Long? {
            val parts = host.split('.')
            if (parts.size != 4) {
                return null
            }
            var value = 0L
            for (part in parts) {
                val octet = part.toIntOrNull() ?: return null
                if (octet !in 0..255) {
                    return null
                }
                value = (value shl 8) or octet.toLong()
            }
            return value
        }

        private fun toIPv4String(value: Long): String {
            val normalized = value and 0xFFFF_FFFFL
            return listOf(
                (normalized shr 24) and 0xFF,
                (normalized shr 16) and 0xFF,
                (normalized shr 8) and 0xFF,
                normalized and 0xFF,
            ).joinToString(".")
        }
    }
}
