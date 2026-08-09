//
//  SettingsView.swift
//  ClipboardHistory
//

import AppKit
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
            Tab("通用", systemImage: "gearshape") {
                generalSettings
            }

            Tab("快捷键", systemImage: "keyboard") {
                ShortcutSettingsView()
            }

            Tab("隐私", systemImage: "hand.raised") {
                privacySettings
            }
        }
        .frame(width: 720, height: 560)
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
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionCard(title: "操作") {
                HStack {
                    Text("按 Enter 时")
                    Spacer()
                    Picker("", selection: $preferences.defaultCopyMode) {
                        ForEach(ClipboardCopyMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                }

                Text("Option + Enter 会临时使用另一种方式。文字卡片上也提供两个按钮。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsSectionCard(title: "历史记录") {
                HStack {
                    Text("最多保留未固定记录")
                    Spacer()
                    Picker("", selection: $preferences.maximumHistoryCount) {
                        ForEach(
                            AppPreferences.historyCountOptions,
                            id: \.self
                        ) { count in
                            Text("\(count) 条").tag(count)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("清空历史记录")
                        Text("固定记录也会一起删除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("清空全部历史…", role: .destructive) {
                        isShowingClearConfirmation = true
                    }
                }
            }

            SettingsSectionCard(title: "启动") {
                Toggle("登录 Mac 时自动启动", isOn: launchAtLoginBinding)

                if launchAtLogin.requiresApproval {
                    Divider()

                    HStack {
                        Text("需要在系统设置中允许")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("打开系统设置") {
                            launchAtLogin.openSystemSettings()
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionCard(title: "自动保护") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("自动忽略密码和临时剪贴板内容")
                            .fontWeight(.medium)
                        Text(
                            "当密码管理器或其他应用把内容标记为机密、自动生成或临时时，ClipboardHistory 不会读取或保存它。"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Label("已开启", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            SettingsSectionCard(title: "忽略的应用") {
                Text("从下列应用复制的任何内容都不会进入历史记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if preferences.ignoredApplications.isEmpty {
                    ContentUnavailableView(
                        "没有忽略的应用",
                        systemImage: "app.dashed",
                        description: Text("需要时可以把密码管理器或其他应用添加到这里。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    List(preferences.ignoredApplications) { application in
                        ignoredApplicationRow(application)
                    }
                    .listStyle(.inset)
                    .frame(height: 190)
                }

                HStack {
                    Button("添加应用…") {
                        chooseApplicationToIgnore()
                    }
                    Spacer()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
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

            Button("不再忽略这个应用", systemImage: "minus.circle") {
                preferences.removeIgnoredApplication(application)
            }
            .labelStyle(.iconOnly)
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
