//
//  FileURLPayload.swift
//  ClipboardHistory
//

import Foundation

/// `.fileURL` 类型记录的存储格式。
///
/// - 只有一个文件：直接保存路径字符串（和旧版本完全一致，
///   所以已有的历史记录和内容哈希都不受影响）。
/// - 多个文件：保存路径数组的 JSON。
///
/// 路径一定以 “/” 开头，不可能是合法的 JSON 数组，
/// 所以读取时先尝试按 JSON 解析，失败就当作单个路径。
enum FileURLPayload {

    static func encode(_ urls: [URL]) -> Data? {
        guard let first = urls.first else {
            return nil
        }

        if urls.count == 1 {
            return first.path.data(using: .utf8)
        }

        return try? JSONEncoder().encode(urls.map(\.path))
    }

    static func decode(_ data: Data) -> [URL] {
        if let paths = try? JSONDecoder().decode([String].self, from: data) {
            return paths
                .filter { !$0.isEmpty }
                .map { URL(fileURLWithPath: $0) }
        }

        guard let path = String(data: data, encoding: .utf8),
              !path.isEmpty else {
            return []
        }

        return [URL(fileURLWithPath: path)]
    }
}
