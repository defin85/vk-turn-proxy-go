cmake_minimum_required(VERSION 3.22.1)

project(android_mobile_host_jni LANGUAGES CXX)

set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../..")
set(ANDROID_EMBEDDED_HOST_ROOT "${REPO_ROOT}/dist/mobile/android-embedded-host")
set(ANDROID_EMBEDDED_HOST_INCLUDE "${ANDROID_EMBEDDED_HOST_ROOT}/jniLibs/${ANDROID_ABI}")
set(ANDROID_EMBEDDED_HOST_LIB "${ANDROID_EMBEDDED_HOST_ROOT}/jniLibs/${ANDROID_ABI}/libvk_turn_mobile_host.so")

if(NOT EXISTS "${ANDROID_EMBEDDED_HOST_INCLUDE}/libvk_turn_mobile_host.h")
    message(FATAL_ERROR "missing generated Android embedded host header for ${ANDROID_ABI}; run scripts/build-android-embedded-host.sh first")
endif()

if(NOT EXISTS "${ANDROID_EMBEDDED_HOST_LIB}")
    message(FATAL_ERROR "missing generated Android embedded host library for ${ANDROID_ABI}; run scripts/build-android-embedded-host.sh first")
endif()

add_library(android_mobile_host_jni SHARED mobile_host_bridge_jni.cpp)
target_include_directories(android_mobile_host_jni PRIVATE "${ANDROID_EMBEDDED_HOST_INCLUDE}")
target_link_libraries(android_mobile_host_jni log dl)
