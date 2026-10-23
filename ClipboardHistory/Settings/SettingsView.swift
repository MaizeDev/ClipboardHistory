//
//  SettingsView.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Bindable var preferences: AppPreferences

    /// 清空全部历史。参数表示是否同时删除数据库备份。
    let onClearHistory: (_ includeBackups: Bool) -> Void

    /// 当前不受保护（既没固定也没收藏）的记录数量。
    /// 用来在调低“最多保留条数”之前，告诉用户会有多少条被删除。
    let unprotectedItemCount: () -> Int

    /// 早于“保留 N 天”分界时间的普通记录数量。
    /// 用来在设置自动删除之前，告诉用户会有多少条被删除。
    let expiredItemCount: (Int) -> Int

    @State
    private var launchAtLogin = LaunchAtLoginManager()

    @State
    private var isShowingClearConfirmation = false

    /// 打开清空确认时记录的数据库备份数量。
    @State
    private var backupCountForClear = 0

    @State
    private var applicationPickerError: String?

    /// 用户选了一个更小的上限，但会导致记录被删除，等待用户确认。
    @State
    private var pendingHistoryLimit: Int?

    @State
    private var pendingDeletionCount = 0

    /// 用户选了一个会立即删除旧记录的保留天数，等待用户确认。
    @State
    private var pendingRetentionDays: Int?

    @State
    private var pendingRetentionDeletionCount = 0

    @State
    private var selectedPage: SettingsPage

    init(
        preferences: AppPreferences,
        onClearHistory: @escaping (_ includeBackups: Bool) -> Void,
        unprotectedItemCount: @escaping () -> Int,
        expiredItemCount: @escaping (Int) -> Int,
        initialPage: SettingsPage = .general
    ) {
        self.preferences = preferences
        self.onClearHistory = onClearHistory
        self.unprotectedItemCount = unprotectedItemCount
        self.expiredItemCount = expiredItemCount
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
            settingsContent
        }
        .frame(width: 720, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            "清空全部剪贴板历史？",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("取消", role: .cancel) {}

            if backupCountForClear > 0 {
                Button("清空历史") {
                    onClearHistory(false)
                }
                Button(
                    "清空并删除 \(backupCountForClear) 份备份",
                    role: .destructive
                ) {
                    onClearHistory(true)
                }
            } else {
                Button("清空", role: .destructive) {
                    onClearHistory(false)
                }
            }
        } message: {
            if backupCountForClear > 0 {
                Text(
                    "这会删除包括固定和收藏记录在内的全部内容，而且无法撤销。另外还有 \(backupCountForClear) 份数据库备份可能保留旧内容，建议一并删除。"
                )
            } else {
                Text("这会删除包括固定和收藏记录在内的全部内容，而且无法撤销。")
            }
        }
        .alert(
            "调低保留条数？",
            isPresented: pendingHistoryLimitBinding
        ) {
            Button("取消", role: .cancel) {
                pendingHistoryLimit = nil
            }
            Button("删除 \(pendingDeletionCount) 条", role: .destructive) {
                if let pendingHistoryLimit {
                    preferences.maximumHistoryCount = pendingHistoryLimit
                }

                pendingHistoryLimit = nil
            }
        } message: {
            Text(
                "调整后会立即删除最旧的 \(pendingDeletionCount) 条记录，而且无法撤销。固定和收藏的记录不受影响。"
            )
        }
        .alert(
            "自动删除旧记录？",
            isPresented: pendingRetentionBinding
        ) {
            Button("取消", role: .cancel) {
                pendingRetentionDays = nil
            }
            Button(
                "删除 \(pendingRetentionDeletionCount) 条",
                role: .destructive
            ) {
                if let pendingRetentionDays {
                    preferences.historyRetentionDays = pendingRetentionDays
                }

                pendingRetentionDays = nil
            }
        } message: {
            Text(
                "现有 \(pendingRetentionDeletionCount) 条普通记录已经超过期限，设置后会立即删除，而且无法撤销。固定和收藏的记录不受影响。"
            )
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

    // MARK: - Navigation

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipboardHistory")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text("版本 \(appVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(spacing: 3) {
                ForEach(SettingsPage.allCases) { page in
                    Button {
                        selectedPage = page
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: page.icon)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 18)

                            Text(page.title)
                                .font(.system(size: 13, weight: .medium))

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(
                            selectedPage == page
                                ? Color.accentColor
                                : Color.primary.opacity(0.82)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            selectedPage == page
                                ? Color.accentColor.opacity(0.14)
                                : Color.clear,
                            in: .rect(cornerRadius: 8)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            Text("所有数据仅保存在这台 Mac 上")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 186)
        .background(Color.primary.opacity(0.035))
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedPage.title)
                    .font(.system(size: 20, weight: .semibold))

                Text(selectedPage.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Group {
                switch selectedPage {
                case .general:
                    generalSettings
                case .shortcuts:
                    ShortcutSettingsView()
                case .privacy:
                    privacySettings
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.2.0"
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionCard(title: "操作", icon: "return") {
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

            SettingsSectionCard(title: "历史记录", icon: "clock.arrow.circlepath") {
                HStack {
                    Text("最多保留普通记录")
                    Spacer()
                    Picker("", selection: historyLimitBinding) {
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

                Text("固定和收藏的记录不计入这个数量，也不会被自动清理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text("自动删除旧记录")
                    Spacer()
                    Picker("", selection: retentionBinding) {
                        ForEach(
                            AppPreferences.retentionDayOptions,
                            id: \.self
                        ) { days in
                            Text(retentionTitle(days)).tag(days)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                Text("超过设定时间的普通记录会被自动删除，固定和收藏的不受影响。历史记录以明文保存在这台 Mac 上。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("清空历史记录")
                        Text("固定和收藏的记录也会一起删除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("清空全部历史…", role: .destructive) {
                        backupCountForClear = StoreBackup.backupCount()
                        isShowingClearConfirmation = true
                    }
                }
            }

            SettingsSectionCard(title: "启动", icon: "power") {
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
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionCard(title: "自动保护", icon: "lock.shield") {
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: .capsule)
                }
            }

            SettingsSectionCard(title: "忽略的应用", icon: "nosign") {
                Text("从下列应用复制的任何内容都不会进入历史记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if preferences.ignoredApplications.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.tertiary)

                        Text("没有忽略的应用")
                            .font(.system(size: 13, weight: .medium))

                        Text("需要时可以把密码管理器或其他应用添加到这里。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
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
    }

    // MARK: - History limit

    /// 选择器的绑定。调低上限会立即删除记录，所以先确认；
    /// 不会删除任何记录的修改（调高，或当前记录没那么多）直接生效。
    private var historyLimitBinding: Binding<Int> {
        Binding(
            get: { preferences.maximumHistoryCount },
            set: { requestHistoryLimitChange(to: $0) }
        )
    }

    private func requestHistoryLimitChange(to newLimit: Int) {
        guard newLimit != preferences.maximumHistoryCount else {
            return
        }

        let deletionCount = max(0, unprotectedItemCount() - newLimit)

        guard deletionCount > 0 else {
            preferences.maximumHistoryCount = newLimit
            return
        }

        pendingDeletionCount = deletionCount
        pendingHistoryLimit = newLimit
    }

    private var pendingHistoryLimitBinding: Binding<Bool> {
        Binding(
            get: { pendingHistoryLimit != nil },
            set: { isPresented in
                if !isPresented {
                    pendingHistoryLimit = nil
                }
            }
        )
    }

    // MARK: - Retention

    private func retentionTitle(_ days: Int) -> String {
        days == 0 ? "永不" : "\(days) 天后"
    }

    private var retentionBinding: Binding<Int> {
        Binding(
            get: { preferences.historyRetentionDays },
            set: { requestRetentionChange(to: $0) }
        )
    }

    /// 选择自动删除天数。如果现有记录里已经有超期的，设置后会立即删除，所以先确认。
    private func requestRetentionChange(to days: Int) {
        guard days != preferences.historyRetentionDays else {
            return
        }

        let deletionCount = expiredItemCount(days)

        guard deletionCount > 0 else {
            preferences.historyRetentionDays = days
            return
        }

        pendingRetentionDeletionCount = deletionCount
        pendingRetentionDays = days
    }

    private var pendingRetentionBinding: Binding<Bool> {
        Binding(
            get: { pendingRetentionDays != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRetentionDays = nil
                }
            }
        )
    }

    // MARK: - Bindings

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

enum SettingsPage: String, CaseIterable, Identifiable {

    case general
    case shortcuts
    case privacy

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .general:
            "通用"
        case .shortcuts:
            "快捷键"
        case .privacy:
            "隐私"
        }
    }

    var icon: String {
        switch self {
        case .general:
            "gearshape"
        case .shortcuts:
            "keyboard"
        case .privacy:
            "hand.raised"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            "复制方式、历史记录和登录启动"
        case .shortcuts:
            "自定义呼出浮窗和卡片操作的快捷键"
        case .privacy:
            "哪些内容不会被记录"
        }
    }
}
