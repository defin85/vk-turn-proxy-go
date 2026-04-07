package com.defin85.mobile_gui_shell

internal object EmbeddedMobileHostNative {
    init {
        System.loadLibrary("android_mobile_host_jni")
    }

    external fun ensureStarted(): String?
    external fun lastError(): String?
    external fun stopEmbeddedHost()
}

internal object EmbeddedMobileHost {
    fun ensureStarted(): String {
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
}
