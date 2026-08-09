#!/bin/zsh

set -euo pipefail

release_version="${1:-1.0.0}"
script_directory="$(cd "$(dirname "$0")" && pwd)"
project_directory="$(cd "$script_directory/.." && pwd)"
build_directory="$project_directory/build"
derived_data_directory="$build_directory/ReleaseDerivedData"
distribution_directory="$project_directory/dist"
application_path="$derived_data_directory/Build/Products/Release/ClipboardHistory.app"
disk_image_path="$distribution_directory/ClipboardHistory-v${release_version}.dmg"

mkdir -p "$build_directory" "$distribution_directory"

staging_directory="$(mktemp -d "$build_directory/dmg-staging.XXXXXX")"

cleanup() {
    rm -rf "$staging_directory"
}

trap cleanup EXIT

xcodebuild \
    -quiet \
    -project "$project_directory/ClipboardHistory.xcodeproj" \
    -scheme ClipboardHistory \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data_directory" \
    MARKETING_VERSION="$release_version" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

ditto "$application_path" "$staging_directory/ClipboardHistory.app"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$DEVELOPER_ID_APPLICATION" \
        "$staging_directory/ClipboardHistory.app"
else
    codesign \
        --force \
        --deep \
        --options runtime \
        --sign - \
        "$staging_directory/ClipboardHistory.app"
    print "提示：未提供 Developer ID，已创建仅供测试的临时签名版本。"
fi

ln -s /Applications "$staging_directory/Applications"

hdiutil create \
    -volname ClipboardHistory \
    -srcfolder "$staging_directory" \
    -ov \
    -format UDZO \
    "$disk_image_path"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        print "错误：提交公证前必须提供 DEVELOPER_ID_APPLICATION。" >&2
        exit 1
    fi

    xcrun notarytool submit \
        "$disk_image_path" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$disk_image_path"
    xcrun stapler validate "$disk_image_path"
fi

codesign --verify --deep --strict --verbose=2 \
    "$staging_directory/ClipboardHistory.app"

print "DMG 已生成：$disk_image_path"
