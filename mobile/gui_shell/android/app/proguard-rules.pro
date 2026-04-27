# AndroidPlatformTunnelBridge is called from libvk_turn_mobile_host.so through
# JNI GetMethodID by string name. Keep the class and method names stable in
# release AABs so Play-delivered APK splits retain the callback surface.
-keep class com.defin85.relaydock.AndroidPlatformTunnelBridge {
    *;
}
