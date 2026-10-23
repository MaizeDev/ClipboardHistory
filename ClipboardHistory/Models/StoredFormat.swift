//
//  StoredFormat.swift
//  ClipboardHistory
//

import Foundation

/// 一条记录除“主要内容”之外，额外保存的一种剪贴板格式（比如 HTML、富文本、图片）。
/// 复制回剪贴板时把它们原样写回，这样粘贴到不同应用里的效果，和直接复制时一致。
struct StoredFormat: Codable, Equatable, Sendable {

    /// 剪贴板类型标识，例如 `public.html`。
    let type: String

    let data: Data
}

/// 把多种格式打包成一份数据存进数据库，以及再还原出来。
enum StoredFormats {

    static func encode(_ formats: [StoredFormat]) -> Data? {
        guard !formats.isEmpty else {
            return nil
        }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        return try? encoder.encode(formats)
    }

    static func decode(_ data: Data?) -> [StoredFormat] {
        guard let data else {
            return []
        }

        return (
            try? PropertyListDecoder().decode(
                [StoredFormat].self,
                from: data
            )
        ) ?? []
    }
}
