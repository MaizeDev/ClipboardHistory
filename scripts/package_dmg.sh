#!/bin/zsh

set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd)"
project_directory="$(cd "$script_directory/.." && pwd)"

# 不传版本号时，直接使用 Xcode 工程里的 MARKETING_VERSION，
# 避免 DMG 文件名、应用版本和 CHANGELOG 对不上。
project_marketing_version="$(
    awk -F'= ' '/MARKETING_VERSION = / { gsub(/;/, "", $2); print $2; exit }' \
        "$project_directory/ClipboardHistory.xcodeproj/project.pbxproj"
)"
release_version="${1:-$project_marketing_version}"

if [[ -z "$release_version" ]]; then
    print "错误：无法从 Xcode 工程读取 MARKETING_VERSION，请显式传入版本号。" >&2
    exit 1
fi

build_directory="$project_directory/build"
derived_data_directory="$build_directory/ReleaseDerivedData"
distribution_directory="$project_directory/dist"
application_path="$derived_data_directory/Build/Products/Release/ClipboardHistory.app"
disk_image_path="$distribution_directory/ClipboardHistory-v${release_version}.dmg"
volume_name="ClipboardHistory"

mkdir -p "$build_directory" "$distribution_directory"

working_directory="$(mktemp -d "$build_directory/dmg-work.XXXXXX")"
staging_directory="$working_directory/staging"
mounted_volume_path="$working_directory/mounted-volume"
writable_disk_image_path="$working_directory/ClipboardHistory-rw.dmg"
is_volume_mounted=false

mkdir -p \
    "$staging_directory/.background" \
    "$mounted_volume_path"

cleanup() {
    if [[ "$is_volume_mounted" == true ]]; then
        if ! hdiutil detach "$mounted_volume_path" >/dev/null 2>&1; then
            print "警告：临时 DMG 仍在使用，已保留工作目录：$working_directory" >&2
            return
        fi
    fi

    rm -rf "$working_directory"
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

xcrun swift \
    "$script_directory/make_dmg_background.swift" \
    "$staging_directory/.background/background.png"

if [[ -f "$application_path/Contents/Resources/AppIcon.icns" ]]; then
    ditto \
        "$application_path/Contents/Resources/AppIcon.icns" \
        "$staging_directory/.VolumeIcon.icns"
fi

codesign --verify --deep --strict --verbose=2 \
    "$staging_directory/ClipboardHistory.app"

hdiutil create \
    -quiet \
    -volname "$volume_name" \
    -srcfolder "$staging_directory" \
    -ov \
    -format UDRW \
    "$writable_disk_image_path"

hdiutil attach \
    -quiet \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$mounted_volume_path" \
    "$writable_disk_image_path"
is_volume_mounted=true

if xcrun --find SetFile >/dev/null 2>&1; then
    xcrun SetFile -a C "$mounted_volume_path"
fi

osascript \
    "$script_directory/layout_dmg.applescript" \
    "$volume_name" \
    "$mounted_volume_path"
sync

hdiutil detach -quiet "$mounted_volume_path"
is_volume_mounted=false

hdiutil convert \
    -quiet \
    "$writable_disk_image_path" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$disk_image_path"

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

hdiutil verify "$disk_image_path"

print "DMG 已生成：$disk_image_path"
