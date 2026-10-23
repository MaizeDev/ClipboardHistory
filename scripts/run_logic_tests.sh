#!/bin/bash
# 轻量逻辑测试：不依赖 Xcode 测试 target，也不依赖测试框架。
#
# 做法是把被测的纯逻辑源码和 Tests/LogicTests.swift 复制到一个临时 SPM
# 可执行 target 里编译运行。这样在无法运行 xcodebuild test 的环境里
# （例如 CI 或受限沙箱）也能验证数据格式、搜索、历史管理和撤销恢复。
#
# 用法：./scripts/run_logic_tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/logic-tests"
PKG="$OUT/pkg"

rm -rf "$PKG"
mkdir -p "$PKG/Sources" "$OUT/tmp" "$OUT/home" "$OUT/modulecache" \
  "$OUT/swiftbuild" "$OUT/swiftcache"

cat > "$PKG/Package.swift" <<'PACKAGE'
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ClipboardHistoryLogicTests",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "LogicTests",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances")
            ]
        )
    ]
)
PACKAGE

SOURCES=(
  "ClipboardHistory/Models/FileURLPayload.swift"
  "ClipboardHistory/Models/HistoryItem.swift"
  "ClipboardHistory/Models/HistoryItem+Content.swift"
  "ClipboardHistory/Models/HistoryItemSnapshot.swift"
  "ClipboardHistory/Models/HistoryRow.swift"
  "ClipboardHistory/Models/StoredFormat.swift"
  "ClipboardHistory/Services/History/HistoryManager.swift"
  "ClipboardHistory/Services/History/HistoryStore.swift"
  "ClipboardHistory/Services/Clipboard/ClipboardMonitor.swift"
  "ClipboardHistory/Services/Preview/FileThumbnailService.swift"
  "ClipboardHistory/Services/Preview/HistoryPreviewCache.swift"
  "ClipboardHistory/Services/Preview/ImageThumbnailService.swift"
  "ClipboardHistory/UI/HistoryPanel/HistorySearch.swift"
  "Tests/LogicTests.swift"
)

for source in "${SOURCES[@]}"; do
  cp "$ROOT/$source" "$PKG/Sources/"
done

echo "编译逻辑测试…"

TMPDIR="$OUT/tmp" \
HOME="$OUT/home" \
CFFIXED_USER_HOME="$OUT/home" \
CLANG_MODULE_CACHE_PATH="$OUT/modulecache" \
SWIFT_MODULECACHE_PATH="$OUT/modulecache" \
swift build \
  --disable-sandbox \
  --package-path "$PKG" \
  --scratch-path "$OUT/swiftbuild" \
  --cache-path "$OUT/swiftcache" 2>&1 | tail -20

BUILD_STATUS="${PIPESTATUS[0]}"

if [ "$BUILD_STATUS" -ne 0 ]; then
  echo "逻辑测试编译失败。"
  exit "$BUILD_STATUS"
fi

echo ""
"$OUT/swiftbuild/debug/LogicTests"
