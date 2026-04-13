#!/bin/bash
# 版本号管理脚本
# 用法:
#   ./scripts/version.sh show           # 显示当前版本
#   ./scripts/version.sh bump patch     # 1.0.0 → 1.0.1
#   ./scripts/version.sh bump minor     # 1.0.0 → 1.1.0
#   ./scripts/version.sh bump major     # 1.0.0 → 2.0.0

set -e

ACTION="${1:-show}"
LEVEL="${2:-patch}"
BUILD_GRADLE="android/app/build.gradle.kts"

get_version() {
    local version_name=$(grep 'versionName' "$BUILD_GRADLE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    local version_code=$(grep 'versionCode' "$BUILD_GRADLE" | head -1 | sed 's/[^0-9]//g')
    echo "$version_name:$version_code"
}

bump_version() {
    local current=$(get_version)
    local version_name=$(echo "$current" | cut -d: -f1)
    local version_code=$(echo "$current" | cut -d: -f2)

    IFS='.' read -ra PARTS <<< "$version_name"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}

    case "$LEVEL" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    local new_version="$major.$minor.$patch"
    local new_code=$((version_code + 1))

    # 更新 build.gradle.kts
    sed -i '' "s/versionCode = $version_code/versionCode = $new_code/" "$BUILD_GRADLE"
    sed -i '' "s/versionName = \"$version_name\"/versionName = \"$new_version\"/" "$BUILD_GRADLE"

    echo "✅ 版本已更新: $version_name ($version_code) → $new_version ($new_code)"
}

case "$ACTION" in
    show)
        current=$(get_version)
        version_name=$(echo "$current" | cut -d: -f1)
        version_code=$(echo "$current" | cut -d: -f2)
        echo "📱 当前版本: $version_name (code: $version_code)"
        ;;
    bump)
        bump_version
        ;;
    *)
        echo "用法: $0 [show|bump] [patch|minor|major]"
        exit 1
        ;;
esac
