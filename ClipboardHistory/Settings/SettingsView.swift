//
//  SettingsView.swift
//  ClipboardHistory
//

import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Bindable var preferences: AppPreferences
    let onClearHistory: () -> Void

    @State
    private var launchAtLogin = LaunchAtLoginManager()

    @State
    private var isShowingClearConfirmation = false

    @State
    private var applicationPickerError: String?

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            ignoreSettings
                .tabItem {
                    Label("忽略规则", systemImage: "eye.slash")
                }
        }
        .frame(width: 520, height: 410)
        .scenePadding()
        .alert(
            "清空全部剪贴板历史？",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                onClearHistory()
            }
        } message: {
            Text("这会删除包括固定记录在内的全部内容，而且无法撤销。")
        }
        .alert(
            "无法添加应用",
            isPresented: applicationPickerErrorBinding
        ) {
            Button("好") {
                applicationPickerError = nil
            }
        } message: {
            Text(applicationPickerError ?? "请选择一个有效的 macOS 应用。")
        }
        .alert(
            "无法修改登录启动",
            isPresented: launchAtLoginErrorBinding
        ) {
            Button("好") {
                launchAtLogin.clearError()
            }
        } message: {
            Text(launchAtLogin.errorMessage ?? "请稍后再试。")
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            launchAtLogin.refresh()
        }
    }

    private var generalSettings: some View {
        Form {
            Section("快捷键") {
                KeyboardShortcuts.Recorder(
                    "打开剪贴板历史：",
                    name: .toggleHistoryPanel
                )

                Text("在任何应用中按这个组合键，都可以显示或隐藏历史浮窗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("历史记录") {
                Picker(
                    "最多保留未固定记录：",
                    selection: $preferences.maximumHistoryCount
                ) {
                    ForEach(AppPreferences.historyCountOptions, id: \.self) {
                        count in
                        Text("\(count) 条").tag(count)
                    }
                }

                Text("固定的记录不会被自动清理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("清空全部历史…", role: .destructive) {
                    isShowingClearConfirmation = true
                }
            }

            Section("启动") {
                Toggle("登录 Mac 时自动启动", isOn: launchAtLoginBinding)

                if launchAtLogin.requiresApproval {
                    LabeledContent {
                        Button("打开系统设置") {
                            launchAtLogin.openSystemSettings()
                        }
                    } label: {
                        Text("需要在系统设置中允许")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var ignoreSettings: some View {
        Form {
            Section("忽略的应用") {
                if preferences.ignoredApplications.isEmpty {
                    ContentUnavailableView(
                        "没有忽略的应用",
                        systemImage: "app.dashed",
                        description: Text("从这些应用复制的内容仍会正常记录。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    List(preferences.ignoredApplications) { application in
                        ignoredApplicationRow(application)
                    }
                    .frame(minHeight: 150)
                }

                Button("添加应用…") {
                    chooseApplicationToIgnore()
                }
            }

            Section("忽略的内容类型") {
                ForEach(supportedContentTypes, id: \.self) { type in
                    Toggle(type.settingsName, isOn: ignoreBinding(for: type))
                }

                Text("被忽略的内容不会进入历史记录，也不会占用本地存储空间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var supportedContentTypes: [ClipboardContentType] {
        [.text, .rtf, .image, .fileURL]
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isRequested },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var applicationPickerErrorBinding: Binding<Bool> {
        Binding(
            get: { applicationPickerError != nil },
            set: { isPresented in
                if !isPresented {
                    applicationPickerError = nil
                }
            }
        )
    }

    private var launchAtLoginErrorBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    launchAtLogin.clearError()
                }
            }
        )
    }

    private func ignoreBinding(
        for type: ClipboardContentType
    ) -> Binding<Bool> {
        Binding(
            get: { preferences.isIgnoring(type) },
            set: { preferences.setIgnoring($0, type: type) }
        )
    }

    private func ignoredApplicationRow(
        _ application: IgnoredApplication
    ) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(application.name)
                Text(application.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                preferences.removeIgnoredApplication(application)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("不再忽略这个应用")
        }
    }

    private func chooseApplicationToIgnore() {
        let panel = NSOpenPanel()
        panel.title = "选择要忽略的应用"
        panel.prompt = "忽略"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let applicationURL = panel.url else {
            return
        }

        guard let bundle = Bundle(url: applicationURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            applicationPickerError = "无法读取这个应用的识别信息。"
            return
        }

        let name = bundle.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent

        preferences.addIgnoredApplication(
            IgnoredApplication(
                name: name,
                bundleIdentifier: bundleIdentifier,
                path: applicationURL.path
            )
        )
    }
}

private extension ClipboardContentType {

    var settingsName: String {
        switch self {
        case .text:
            "纯文字"
        case .rtf:
            "富文本（带格式文字）"
        case .image:
            "图片"
        case .fileURL:
            "文件"
        case .unknown:
            "未知类型"
        }
    }
}
