//
//  StoreBackup.swift
//  ClipboardHistory
//

import Foundation
import OSLog

private let backupLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
    category: "StoreBackup"
)

/// 数据库文件的备份和恢复保护。
///
/// 备份都放在 `~/Library/Application Support/ClipboardHistory/Backups/` 下，
/// 每次一个带时间的文件夹，只保留最近几份。
/// 注意：只能在数据库还没有被打开的时候做（App 启动、创建 ModelContainer 之前）。
enum StoreBackup {

    static let maximumBackupCount = 5

    static var backupsDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardHistory", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    static func storeExists(at storeURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// 当前保留的备份数量。备份文件夹下的隐藏文件不算。
    static func backupCount() -> Int {
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: backupsDirectory.path
        ) else {
            return 0
        }

        return names.filter { !$0.hasPrefix(".") }.count
    }

    /// 删除全部数据库备份。
    ///
    /// 备份里可能包含用户早已在应用内清空的剪贴板内容，因此
    /// “清空全部历史”时应当允许一并删除。返回删除的备份数量。
    @discardableResult
    static func deleteAllBackups() throws -> Int {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: backupsDirectory.path) else {
            return 0
        }

        let names = try fileManager.contentsOfDirectory(
            atPath: backupsDirectory.path
        )
        .filter { !$0.hasPrefix(".") }

        try fileManager.removeItem(at: backupsDirectory)

        backupLogger.info("已删除全部数据库备份，共 \(names.count) 份")

        return names.count
    }

    /// 复制一份数据库的完整备份（数据库文件、-wal、-shm，以及外部存储的大文件目录）。
    @discardableResult
    static func backup(
        storeURL: URL,
        label: String
    ) throws -> URL {
        let destination = try makeBackupDirectory(label: label)

        for item in relatedItems(of: storeURL) {
            try FileManager.default.copyItem(
                at: item,
                to: destination.appendingPathComponent(item.lastPathComponent)
            )
        }

        pruneOldBackups()

        backupLogger.info(
            "已备份数据库到：\(destination.path, privacy: .public)"
        )

        return destination
    }

    /// 把打不开的数据库整体移走（不删除），让 App 可以新建一个空的数据库。
    @discardableResult
    static func moveAside(
        storeURL: URL,
        label: String
    ) throws -> URL {
        let destination = try makeBackupDirectory(label: label)

        for item in relatedItems(of: storeURL) {
            try FileManager.default.moveItem(
                at: item,
                to: destination.appendingPathComponent(item.lastPathComponent)
            )
        }

        pruneOldBackups()

        backupLogger.info(
            "已把打不开的数据库移到：\(destination.path, privacy: .public)"
        )

        return destination
    }

    // MARK: - Private

    /// 和数据库相关的所有文件：
    /// `default.store`、`default.store-wal`、`default.store-shm`，
    /// 以及外部存储目录 `.default_SUPPORT`（如果存在）。
    private static func relatedItems(of storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent
        let supportName = "."
            + storeURL.deletingPathExtension().lastPathComponent
            + "_SUPPORT"

        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ) else {
            return []
        }

        return names
            .filter { name in
                name == storeName
                    || name.hasPrefix(storeName + "-")
                    || name == supportName
            }
            .map { directory.appendingPathComponent($0) }
    }

    private static func makeBackupDirectory(label: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let name = "\(formatter.string(from: Date()))-\(label)"
        let directory = backupsDirectory.appendingPathComponent(
            name,
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    /// 只保留最近 `maximumBackupCount` 份备份。
    /// 文件夹名以时间开头，按名字排序就是按时间排序。
    private static func pruneOldBackups() {
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: backupsDirectory.path
        ) else {
            return
        }

        let sortedNames = names
            .filter { !$0.hasPrefix(".") }
            .sorted(by: >)

        for name in sortedNames.dropFirst(maximumBackupCount) {
            let url = backupsDirectory.appendingPathComponent(name)

            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                backupLogger.error(
                    "删除旧备份失败：\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
