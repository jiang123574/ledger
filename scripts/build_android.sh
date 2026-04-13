#!/bin/bash
# Ledger Android 构建脚本
# 用法:
#   ./scripts/build_android.sh debug     # 构建 Debug APK
#   ./scripts/build_android.sh release   # 构建 Release APK
#   ./scripts/build_android.sh bundle    # 构建 Release AAB (Play Store)

set -e

BUILD_TYPE="${1:-debug}"
ANDROID_DIR="$(cd "$(dirname "$0")/../android" && pwd)"
OUTPUT_DIR="$ANDROID_DIR/app/build/outputs"

echo "🔨 Ledger Android 构建工具"
echo "   类型: $BUILD_TYPE"
echo "   目录: $ANDROID_DIR"
echo ""

# 检查 Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "❌ 未设置 ANDROID_HOME 或 ANDROID_SDK_ROOT"
    echo "   请设置 Android SDK 路径，例如:"
    echo "   export ANDROID_HOME=\$HOME/Library/Android/sdk  # macOS"
    echo "   export ANDROID_HOME=D:\\Android\\Sdk             # Windows"
    exit 1
fi

cd "$ANDROID_DIR"

case "$BUILD_TYPE" in
    debug)
        echo "📦 构建 Debug APK..."
        ./gradlew assembleDebug
        APK_PATH="$OUTPUT_DIR/apk/debug/app-debug.apk"
        echo ""
        echo "✅ Debug APK 已生成: $APK_PATH"
        echo "   安装: adb install $APK_PATH"
        ;;
    release)
        if [ ! -f "keystore.properties" ]; then
            echo "❌ 未找到 keystore.properties"
            echo "   请先运行: ./scripts/generate_keystore.sh"
            echo "   或手动创建 keystore.properties（参考 keystore.properties.example）"
            exit 1
        fi
        echo "📦 构建 Release APK..."
        ./gradlew assembleRelease
        APK_PATH="$OUTPUT_DIR/apk/release/app-release.apk"
        echo ""
        echo "✅ Release APK 已生成: $APK_PATH"
        echo "   安装: adb install $APK_PATH"
        ;;
    bundle)
        if [ ! -f "keystore.properties" ]; then
            echo "❌ 未找到 keystore.properties"
            echo "   请先运行: ./scripts/generate_keystore.sh"
            exit 1
        fi
        echo "📦 构建 Release AAB (Play Store)..."
        ./gradlew bundleRelease
        AAB_PATH="$OUTPUT_DIR/bundle/release/app-release.aab"
        echo ""
        echo "✅ Release AAB 已生成: $APK_PATH"
        echo "   上传到: Google Play Console"
        ;;
    *)
        echo "❌ 未知的构建类型: $BUILD_TYPE"
        echo "   用法: $0 [debug|release|bundle]"
        exit 1
        ;;
esac
