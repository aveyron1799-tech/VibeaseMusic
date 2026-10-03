import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AccountStore.self) private var account
    @State private var cacheSize: String = String(localized: "计算中…")

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection("播放") {
                    SettingsRow("音质", note: "无损与 Hi-Res 需要黑胶 VIP，未开通时自动回落到可用音质") {
                        Picker("音质", selection: $settings.audioQuality) {
                            ForEach(AudioQuality.allCases) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    SettingsDivider()
                    SettingsRow("灰色歌曲解锁", note: "无版权 / 下架歌曲自动从第三方音源（酷我、酷狗等）匹配播放") {
                        SettingsToggle("灰色歌曲解锁", isOn: $settings.enableUnblock)
                    }
                }

                SettingsSection("外观") {
                    SettingsRow("主题") {
                        Picker("主题", selection: $settings.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.displayName).tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    SettingsDivider()
                    SettingsRow("显示歌词翻译") {
                        SettingsToggle("显示歌词翻译", isOn: $settings.showLyricsTranslation)
                    }
                    SettingsDivider()
                    SettingsRow("桌面歌词", note: "在屏幕上悬浮显示当前歌词，可拖动调整位置") {
                        SettingsToggle("桌面歌词", isOn: $settings.showDesktopLyrics)
                    }
                }

                SettingsSection("存储") {
                    SettingsRow("图片缓存") {
                        HStack(spacing: 12) {
                            Text(cacheSize)
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(Theme.ink.opacity(0.55))
                            Button("清除缓存") {
                                clearCache()
                            }
                            .buttonStyle(.inkOutline)
                        }
                    }
                }

                SettingsSection("账号") {
                    if let profile = account.profile {
                        SettingsRow("当前账号") {
                            HStack(spacing: 12) {
                                Text(profile.nickname)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.ink.opacity(0.55))
                                    .lineLimit(1)
                                Button("退出登录", role: .destructive) {
                                    Task { await AccountStore.shared.logout() }
                                }
                                .buttonStyle(.inkOutline)
                            }
                        }
                    } else {
                        SettingsRow("未登录") { EmptyView() }
                    }
                }

                SettingsSection("关于") {
                    SettingsRow("VibeaseMusic", note: "网易云音乐第三方客户端 · 数据来自网易云音乐") {
                        Text(appVersion)
                            .font(.serif(13))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .hoverScrollIndicators()
        .background { PaperBackground().ignoresSafeArea() }
        .frame(width: 440, height: 480)
        .task { updateCacheSize() }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.vibease.music/images", isDirectory: true)
    }

    private func updateCacheSize() {
        let dir = cacheDirectory
        DispatchQueue.global(qos: .utility).async {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []
            let bytes = files.reduce(0) { sum, url in
                sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            DispatchQueue.main.async {
                cacheSize = formatted
            }
        }
    }

    private func clearCache() {
        let dir = cacheDirectory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                cacheSize = String(localized: "0 字节")
                ToastCenter.shared.show(String(localized: "缓存已清除"))
            }
        }
    }
}

// MARK: - Settings layout

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(title)
                    .font(.serif(16, .bold))
                    .foregroundStyle(Theme.ink)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 4)
                    .accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .paperSheet(cornerRadius: Theme.Radius.large)
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: LocalizedStringKey
    var note: LocalizedStringKey?
    @ViewBuilder var control: () -> Control

    init(_ title: LocalizedStringKey, note: LocalizedStringKey? = nil,
         @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.note = note
        self.control = control
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct SettingsToggle: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
            .labelsHidden()
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.75)
            .padding(.leading, 14)
    }
}
