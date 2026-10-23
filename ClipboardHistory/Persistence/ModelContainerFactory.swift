//
//  ModelContainerFactory.swift
//  ClipboardHistory
//

import Foundation
import OSLog
import SwiftData

private let factoryLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
    category: "ModelContainer"
)

/// 创建数据库容器，并在出问题时尽量保住用户的数据。
///
/// 1. 数据库结构的版本发生变化时，先备份再打开；
/// 2. 原来的数据库打不开时，把它整体移到备份文件夹（不删除），再新建一个空的；
/// 3. 连新数据库也建不了时，退回到只存在内存里的数据库，App 仍然可以运行；
/// 4. 出现 2、3 时，把问题记录下来，由 App 在启动后告诉用户。
enum ModelContainerFactory {

    struct Outcome {
        let container: ModelContainer
        let issue: PersistenceIssue?
    }

    /// 数据库结构的版本号。
    /// 每次修改 `@Model` 的结构（增加、删除、修改属性或模型）时，把它加一。
    /// 版本变化后的第一次启动，会在打开数据库之前先做一次完整备份。
    ///
    /// 版本 2：`HistoryItem` 新增 `formatsData`（附加保存的剪贴板格式）。
    static let currentSchemaVersion = 2

    private static let schemaVersionKey = "storeSchemaVersion"

    /// 整个 App 只创建一次。
    static let outcome: Outcome = make()

    // MARK: - Creation

    private static func make() -> Outcome {
        let schema = Schema([HistoryItem.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let storeURL = configuration.url

        backupBeforeSchemaChangeIfNeeded(storeURL: storeURL)

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            UserDefaults.standard.set(
                currentSchemaVersion,
                forKey: schemaVersionKey
            )

            return Outcome(container: container, issue: nil)
        } catch {
            factoryLogger.error(
                "无法打开历史数据库：\(error.localizedDescription, privacy: .public)"
            )

            return recover(
                schema: schema,
                storeURL: storeURL,
                originalError: error
            )
        }
    }

    // MARK: - Backup

    private static func backupBeforeSchemaChangeIfNeeded(storeURL: URL) {
        // 没有记录过版本号的旧安装，数据库结构就是第 1 版。
        let previousVersion = UserDefaults.standard.object(
            forKey: schemaVersionKey
        ) as? Int ?? 1

        guard previousVersion != currentSchemaVersion,
              StoreBackup.storeExists(at: storeURL) else {
            return
        }

        do {
            try StoreBackup.backup(
                storeURL: storeURL,
                label: "schema-v\(previousVersion)-to-v\(currentSchemaVersion)"
            )
        } catch {
            // 备份失败不阻止启动，只记录下来。
            factoryLogger.error(
                "升级数据库前备份失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Recovery

    private static func recover(
        schema: Schema,
        storeURL: URL,
        originalError: Error
    ) -> Outcome {
        let errorDescription = originalError.localizedDescription

        var backupURL: URL?

        do {
            backupURL = try StoreBackup.moveAside(
                storeURL: storeURL,
                label: "unreadable"
            )
        } catch {
            factoryLogger.error(
                "移走打不开的数据库失败：\(error.localizedDescription, privacy: .public)"
            )
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false
                    )
                ]
            )

            UserDefaults.standard.set(
                currentSchemaVersion,
                forKey: schemaVersionKey
            )

            return Outcome(
                container: container,
                issue: .recoveredWithNewStore(
                    backupURL: backupURL,
                    errorDescription: errorDescription
                )
            )
        } catch {
            factoryLogger.error(
                "无法新建历史数据库：\(error.localizedDescription, privacy: .public)"
            )
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                ]
            )

            return Outcome(
                container: container,
                issue: .temporaryStore(errorDescription: errorDescription)
            )
        } catch {
            // 连内存数据库都建不了，App 无法继续运行。
            fatalError("无法创建任何 SwiftData ModelContainer：\(error)")
        }
    }
}
