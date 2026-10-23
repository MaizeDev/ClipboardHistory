//
//  LogicTests.swift
//  ClipboardHistory
//
//  轻量逻辑测试，不依赖 Xcode 测试 target，直接由
//  `scripts/run_logic_tests.sh` 编译运行。
//
//  这些测试覆盖数据格式、搜索、历史和撤销恢复等纯逻辑，
//  界面布局、快捷键和系统集成仍需要按人工验收清单检查。
//

import Foundation
import SwiftData

private var passedCount = 0
private var failedCount = 0

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    if condition() {
        passedCount += 1
    } else {
        failedCount += 1
        print("✗ \(message)")
    }
}

private func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) {
    if actual == expected {
        passedCount += 1
    } else {
        failedCount += 1
        print("✗ \(message)（实际：\(actual)，预期：\(expected)）")
    }
}

@main
struct LogicTests {

    static func main() throws {
        testFileURLPayload()
        testStoredFormats()
        try testHistorySearch()
        try testHistoryManager()
        try testRestore()

        print("")

        if failedCount == 0 {
            print("全部通过：\(passedCount) 项")
            exit(EXIT_SUCCESS)
        } else {
            print("失败：\(failedCount) 项，通过：\(passedCount) 项")
            exit(EXIT_FAILURE)
        }
    }

    // MARK: - 文件路径存储

    private static func testFileURLPayload() {
        expect(FileURLPayload.encode([]) == nil, "空文件列表不应生成数据")

        let single = URL(fileURLWithPath: "/tmp/一个 文件.txt")
        guard let singleData = FileURLPayload.encode([single]) else {
            expect(false, "单个文件应能编码")
            return
        }

        expectEqual(
            String(data: singleData, encoding: .utf8),
            single.path,
            "单个文件仍按旧格式保存纯路径"
        )
        expectEqual(
            FileURLPayload.decode(singleData),
            [single],
            "单个文件解码往返一致"
        )

        let multiple = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.png")
        ]
        guard let multipleData = FileURLPayload.encode(multiple) else {
            expect(false, "多个文件应能编码")
            return
        }

        expectEqual(
            FileURLPayload.decode(multipleData),
            multiple,
            "多个文件解码往返一致"
        )

        let legacy = Data("/tmp/legacy.txt".utf8)
        expectEqual(
            FileURLPayload.decode(legacy),
            [URL(fileURLWithPath: "/tmp/legacy.txt")],
            "旧版本纯路径数据仍能读取"
        )
        expectEqual(FileURLPayload.decode(Data()), [], "空数据返回空列表")
    }

    // MARK: - 附加格式存储

    private static func testStoredFormats() {
        expect(StoredFormats.decode(nil).isEmpty, "没有格式数据时返回空列表")

        let formats = [
            StoredFormat(type: "public.html", data: Data("<b>hi</b>".utf8)),
            StoredFormat(type: "public.rtf", data: Data("{\\rtf1}".utf8))
        ]

        guard let encoded = StoredFormats.encode(formats) else {
            expect(false, "格式列表应能编码")
            return
        }

        expectEqual(
            StoredFormats.decode(encoded),
            formats,
            "附加格式解码往返一致"
        )
    }

    // MARK: - 搜索

    private static func testHistorySearch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let textItem = HistoryItem(
            contentData: Data("Hello World".utf8),
            contentType: .text,
            sourceAppName: "Safari",
            sourceBundleID: "com.apple.Safari"
        )
        let notesItem = HistoryItem(
            contentData: Data("另一段文字".utf8),
            contentType: .text,
            sourceAppName: "Notes",
            sourceBundleID: "com.apple.Notes"
        )
        let fileItem = HistoryItem(
            contentData: FileURLPayload.encode([
                URL(fileURLWithPath: "/tmp/年度报告.pdf")
            ]) ?? Data(),
            contentType: .fileURL,
            sourceAppName: "Finder",
            sourceBundleID: "com.apple.finder"
        )

        context.insert(textItem)
        context.insert(notesItem)
        context.insert(fileItem)
        try context.save()

        let textRow = HistoryRow(item: textItem)
        let notesRow = HistoryRow(item: notesItem)
        let fileRow = HistoryRow(item: fileItem)

        let fullText: (HistoryRow) -> String? = { row in
            row.id == textRow.id ? "Hello World" : nil
        }

        expect(
            HistorySearch.matches(textRow, query: "hello", fullText: fullText),
            "搜索应忽略大小写匹配正文"
        )
        expect(
            HistorySearch.matches(textRow, query: "Safari", fullText: fullText),
            "搜索应匹配来源应用名"
        )
        expect(
            HistorySearch.matches(fileRow, query: "报告", fullText: fullText),
            "搜索应匹配文件名"
        )
        expect(
            !HistorySearch.matches(
                notesRow,
                query: "hello",
                fullText: fullText
            ),
            "不匹配的记录不应命中"
        )

        var fullTextCallCount = 0
        let filteredRows = HistorySearch.filter(
            [textRow, notesRow, fileRow],
            query: "   "
        ) { _ in
            fullTextCallCount += 1
            return nil
        }
        expectEqual(filteredRows.count, 3, "空白搜索词返回原列表")
        expectEqual(fullTextCallCount, 0, "空白搜索词不读取完整内容")
    }

    // MARK: - 历史记录

    private static func testHistoryManager() throws {
        let container = try makeContainer()
        let manager = HistoryManager(
            modelContainer: container,
            maximumUnpinnedItemCount: { 100 },
            retentionDays: { 0 }
        )

        let dataA = Data("A".utf8)
        let captureA = makeCapture(
            data: dataA,
            formatsData: Data("formats-1".utf8)
        )

        guard case .inserted = manager.add(capture: captureA) else {
            expect(false, "第一次添加应插入新记录")
            return
        }
        expectEqual(manager.store.rows.count, 1, "插入后 store 应有 1 条记录")

        let captureA2 = makeCapture(
            data: dataA,
            formatsData: Data("formats-2".utf8)
        )

        guard case .updatedExisting = manager.add(capture: captureA2) else {
            expect(false, "相同内容应更新已有记录")
            return
        }
        expectEqual(manager.store.rows.count, 1, "重复内容不应新增记录")
        expectEqual(
            manager.store.rows.first?.contentHash,
            captureA.contentHash,
            "重复内容应保留原哈希"
        )

        let fetched = try manager.fetchItem(contentHash: captureA.contentHash)
        expectEqual(
            fetched?.formatsData,
            Data("formats-2".utf8),
            "再次复制相同内容时格式快照应更新"
        )

        // 多条文件和固定上限
        let fileCapture = ClipboardCapture(
            contentData: FileURLPayload.encode([
                URL(fileURLWithPath: "/tmp/one.txt"),
                URL(fileURLWithPath: "/tmp/two.txt")
            ]) ?? Data(),
            contentType: .fileURL,
            sourceAppName: "Finder",
            sourceBundleID: "com.apple.finder",
            contentHash: HistoryItem.generateContentHash(
                data: Data(),
                type: .fileURL
            ),
            formatsData: nil,
            capturedAt: .now
        )
        manager.add(capture: fileCapture)
        expectEqual(manager.store.rows.first?.fileURLs.count, 2, "多文件记录应保留全部文件")

        for index in 0..<4 {
            let data = Data("pin-\(index)".utf8)
            manager.add(capture: makeCapture(data: data))
        }

        let idsToPin = manager.store.rows.map(\.id).prefix(4)

        for id in idsToPin {
            manager.togglePinned(id: id)
        }

        let pinnedRows = manager.store.rows.filter(\.isPinned)
        expectEqual(
            pinnedRows.count,
            HistoryManager.maximumPinnedItemCount,
            "固定数量不应超过上限"
        )
        expect(
            !pinnedRows.contains { $0.id == idsToPin.first },
            "固定第 4 条时应自动取消最早固定的记录"
        )

        // 收藏和清理
        if let favoriteID = manager.store.rows.first(where: { !$0.isPinned })?.id {
            manager.toggleFavorite(id: favoriteID)

            let cleanupManager = HistoryManager(
                modelContainer: container,
                maximumUnpinnedItemCount: { 1 },
                retentionDays: { 0 }
            )
            cleanupManager.cleanupIfNeeded()

            expect(
                cleanupManager.store.rows.contains { $0.id == favoriteID },
                "收藏记录不应被数量清理删除"
            )
            expect(
                cleanupManager.store.rows.filter(\.isPinned).count
                    == HistoryManager.maximumPinnedItemCount,
                "固定记录不应被数量清理删除"
            )
        }

        manager.deleteAll()
        expectEqual(manager.store.rows.count, 0, "清空历史后 store 应为空")

        // 过期清理
        let oldCapture = ClipboardCapture(
            contentData: Data("old".utf8),
            contentType: .text,
            sourceAppName: "Test",
            sourceBundleID: "test.app",
            contentHash: HistoryItem.generateContentHash(
                data: Data("old".utf8),
                type: .text
            ),
            formatsData: nil,
            capturedAt: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
        )

        let retentionManager = HistoryManager(
            modelContainer: container,
            maximumUnpinnedItemCount: { 100 },
            retentionDays: { 30 }
        )
        retentionManager.add(capture: oldCapture)

        expect(
            retentionManager.store.rows.isEmpty,
            "超过保留天数的普通记录应在清理时删除"
        )
    }

    // MARK: - 删除与恢复

    private static func testRestore() throws {
        let container = try makeContainer()
        let manager = HistoryManager(
            modelContainer: container,
            maximumUnpinnedItemCount: { 100 },
            retentionDays: { 0 }
        )

        let data = Data("restore-me".utf8)
        manager.add(capture: makeCapture(data: data))
        let id = manager.store.rows[0].id
        manager.togglePinned(id: id)

        guard let snapshot = manager.delete(id: id) else {
            expect(false, "删除应返回可撤销的快照")
            return
        }
        expectEqual(manager.store.rows.count, 0, "删除后记录应消失")
        expect(snapshot.isPinned, "快照应保留固定状态")

        expect(manager.restore(snapshot: snapshot), "恢复应成功")
        expectEqual(manager.store.rows.count, 1, "恢复后记录应回来")
        expectEqual(
            manager.store.rows.first?.isPinned,
            true,
            "恢复后应保留固定状态"
        )

        // 删除后同一内容又被重新复制：恢复时应合并到已有记录。
        guard let snapshot2 = manager.delete(id: manager.store.rows[0].id) else {
            expect(false, "第二次删除应返回快照")
            return
        }
        manager.add(capture: makeCapture(data: data))
        expect(manager.restore(snapshot: snapshot2), "合并恢复应成功")
        expectEqual(manager.store.rows.count, 1, "合并恢复不应产生重复记录")
        expectEqual(
            manager.store.rows.first?.isPinned,
            true,
            "合并恢复后应保留固定状态"
        )
    }

    // MARK: - 辅助

    private static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private static func makeCapture(
        data: Data,
        formatsData: Data? = nil,
        capturedAt: Date = .now
    ) -> ClipboardCapture {
        ClipboardCapture(
            contentData: data,
            contentType: .text,
            sourceAppName: "Test",
            sourceBundleID: "test.app",
            contentHash: HistoryItem.generateContentHash(
                data: data,
                type: .text
            ),
            formatsData: formatsData,
            capturedAt: capturedAt
        )
    }
}
