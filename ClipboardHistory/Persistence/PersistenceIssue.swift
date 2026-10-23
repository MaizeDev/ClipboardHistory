//
//  PersistenceIssue.swift
//  ClipboardHistory
//

import Foundation

/// 启动时数据库出现的问题，需要告诉用户。
enum PersistenceIssue {

    /// 原来的数据库打不开，已经整体备份并换成了新的空数据库。
    case recoveredWithNewStore(backupURL: URL?, errorDescription: String)

    /// 连新的数据库也建不了。本次运行的历史只保存在内存里，退出后会消失。
    case temporaryStore(errorDescription: String)

    var title: String {
        switch self {
        case .recoveredWithNewStore:
            "无法读取原来的历史记录"
        case .temporaryStore:
            "无法保存历史记录"
        }
    }

    var message: String {
        switch self {
        case .recoveredWithNewStore(let backupURL, let errorDescription):
            if let backupURL {
                """
                原来的历史数据库打不开，已经把它完整备份到：
                \(backupURL.path)

                现在使用的是一个新的空数据库。你可以稍后再尝试从备份里恢复。

                原因：\(errorDescription)
                """
            } else {
                """
                原来的历史数据库打不开，而且备份也没有成功，所以现在使用的是一个新的空数据库。

                原因：\(errorDescription)
                """
            }

        case .temporaryStore(let errorDescription):
            """
            无法创建历史数据库。本次运行期间复制的内容只保存在内存里，退出 App 后会消失。

            原因：\(errorDescription)
            """
        }
    }

    /// 可以在 Finder 里显示的位置（备份所在的文件夹）。
    var revealURL: URL? {
        switch self {
        case .recoveredWithNewStore(let backupURL, _):
            backupURL ?? StoreBackup.backupsDirectory
        case .temporaryStore:
            nil
        }
    }
}
