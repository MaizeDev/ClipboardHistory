//
//  ClipboardHistoryApp.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//

import SwiftData
import SwiftUI

@main
struct ClipboardHistoryApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    /// 数据库容器由 `ModelContainerFactory` 创建。
    /// 数据库打不开时，它会先备份再恢复，而不是让 App 直接崩溃。
    static let modelContainer: ModelContainer =
        ModelContainerFactory.outcome.container

    var body: some Scene {
        // 应用没有主窗口，偏好设置由 AppDelegate 里的
        // `SettingsWindowController` 以普通 AppKit 窗口打开。
        // 之前使用 SwiftUI `Settings` 场景时，菜单栏应用（LSUIElement）
        // 通过 `showSettingsWindow:` 打开窗口并不可靠，而且容易和手工窗口
        // 同时出现两个设置窗口。这里只保留一个不自动显示的窗口来满足
        // SwiftUI App 必须有 Scene 的要求。
        Window("ClipboardHistory", id: "background") {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
        .commandsRemoved()
        .modelContainer(Self.modelContainer)
    }
}
