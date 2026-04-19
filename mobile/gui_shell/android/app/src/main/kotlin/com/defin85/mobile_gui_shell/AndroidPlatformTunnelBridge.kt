package com.defin85.mobile_gui_shell

import android.content.Context
import android.content.pm.PackageManager
import android.net.VpnService

internal class AndroidPlatformTunnelBridge(
    private val appContext: Context,
) {
    fun isAndroidVpnPermissionGranted(): Boolean = VpnService.prepare(appContext) == null

    fun validateAndroidVpnRoutePolicy(
        policy: String,
        underlayRoutePolicy: String,
        allowedPackages: String,
        disallowedPackages: String,
    ): String? {
        val allowed = splitPackageList(allowedPackages)
        val disallowed = splitPackageList(disallowedPackages)
        return AndroidPlatformTunnelService.validateRoutePolicy(
            appContext,
            policy = policy,
            underlayRoutePolicy = underlayRoutePolicy,
            allowedPackages = allowed,
            disallowedPackages = disallowed,
        )
    }

    fun bringupAndroidVpnHost(configJson: String): String? =
        AndroidPlatformTunnelService.bringup(appContext, configJson)

    fun protectAndroidVpnSocket(fd: Int): String? =
        AndroidPlatformTunnelService.protectSocket(fd)

    fun duplicateAndroidVpnTunFd(): Int = AndroidPlatformTunnelService.duplicateTunFd()

    fun cleanupAndroidVpnHost(): String? = AndroidPlatformTunnelService.cleanup()

    private fun splitPackageList(value: String): List<String> =
        value
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toList()
}

internal fun packageExists(
    packageManager: PackageManager,
    packageName: String,
): Boolean {
    return try {
        @Suppress("DEPRECATION")
        packageManager.getApplicationInfo(packageName, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
