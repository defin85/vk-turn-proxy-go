package com.defin85.mobile_gui_shell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal class AndroidPlatformTunnelService : VpnService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val policy = intent.getStringExtra(EXTRA_POLICY).orEmpty()
                val allowedPackages =
                    intent.getStringArrayExtra(EXTRA_ALLOWED_PACKAGES)?.toList().orEmpty()
                val disallowedPackages =
                    intent.getStringArrayExtra(EXTRA_DISALLOWED_PACKAGES)?.toList().orEmpty()
                val error = synchronized(lock) {
                    activeService = this
                    startForeground(NOTIFICATION_ID, buildNotification())
                    establishTunnelLocked(
                        policy = policy,
                        allowedPackages = allowedPackages,
                        disallowedPackages = disallowedPackages,
                    )
                }
                signalStartResult(error)
                if (error != null) {
                    synchronized(lock) {
                        cleanupTunnelLocked()
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

    private fun establishTunnelLocked(
        policy: String,
        allowedPackages: List<String>,
        disallowedPackages: List<String>,
    ): String? {
        cleanupTunnelLocked()

        val builder = Builder()
            .setSession("VK TURN Proxy")
            .setMtu(1280)
            .addAddress("198.18.0.1", 32)
            .addRoute("0.0.0.0", 0)

        val policyError = applyAppRoutingPolicy(
            context = this,
            builder = builder,
            policy = policy,
            allowedPackages = allowedPackages,
            disallowedPackages = disallowedPackages,
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
        private const val EXTRA_POLICY = "policy"
        private const val EXTRA_ALLOWED_PACKAGES = "allowed_packages"
        private const val EXTRA_DISALLOWED_PACKAGES = "disallowed_packages"
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
            allowedPackages: List<String>,
            disallowedPackages: List<String>,
        ): String? {
            val normalizedPolicy = policy.trim()
            val packageManager = context.packageManager
            when (normalizedPolicy) {
                "all_apps" -> return null
                "allowed_packages" -> {
                    for (pkg in allowedPackages) {
                        if (pkg == context.packageName) {
                            return "The host app package cannot be routed through allowed_packages."
                        }
                        if (!packageExists(packageManager, pkg)) {
                            return "Allowed package $pkg is not installed on this device."
                        }
                    }
                    return null
                }
                "disallowed_packages" -> {
                    for (pkg in disallowedPackages) {
                        if (!packageExists(packageManager, pkg)) {
                            return "Disallowed package $pkg is not installed on this device."
                        }
                    }
                    return null
                }
                else -> return "Android VPN route policy $normalizedPolicy is not supported."
            }
        }

        fun bringup(
            context: Context,
            policy: String,
            allowedPackages: List<String>,
            disallowedPackages: List<String>,
        ): String? {
            if (VpnService.prepare(context) != null) {
                return "Android VPN permission is still not granted."
            }
            val validationError =
                validateRoutePolicy(context, policy, allowedPackages, disallowedPackages)
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
                putExtra(EXTRA_POLICY, policy)
                putExtra(EXTRA_ALLOWED_PACKAGES, allowedPackages.toTypedArray())
                putExtra(EXTRA_DISALLOWED_PACKAGES, disallowedPackages.toTypedArray())
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
            activeService = null
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
    }
}
