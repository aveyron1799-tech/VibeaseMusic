import CoreImage.CIFilterBuiltins
import SwiftUI

struct LoginSheet: View {
    private enum Phase: Equatable {
        case loading
        case waiting          // 801
        case scanned(String)  // 802, nickname
        case expired          // 800
        case success
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var qrImage: NSImage?
    @State private var pollTask: Task<Void, Never>?

    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("登录网易云音乐")
                    .font(.serif(22, .bold))
                    .foregroundStyle(Theme.ink)
                Text("使用网易云音乐 App 扫码登录")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            .padding(.top, 30)

            qrMount

            Group {
                switch phase {
                case .loading:
                    Text("正在获取二维码…")
                case .waiting:
                    Text("打开网易云音乐 App，扫一扫登录")
                case .scanned:
                    Text("等待手机确认…")
                case .expired:
                    Text("二维码已失效，请刷新")
                case .success:
                    Text("登录成功！")
                case .failed(let message):
                    Text(message).foregroundStyle(Theme.accent)
                }
            }
            .font(.system(size: 12))
            .tracking(1)
            .foregroundStyle(Theme.ink.opacity(0.55))
            .animation(AppAnimation.quick, value: phase)

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.inkOutline)
            .padding(.bottom, 24)
        }
        .frame(width: 340)
        .background { PaperBackground() }
        .onAppear { startLogin() }
        .onDisappear { pollTask?.cancel() }
    }

    /// The QR code mounted like a print: white mat on a paper sheet, signed
    /// with a small vermilion seal.
    private var qrMount: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Color.white)
                .frame(width: 196, height: 196)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.75)
                )

            if let qrImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 180, height: 180)
                    .blur(radius: overlayVisible || phase == .success ? 3 : 0)
                    .opacity(phase == .success ? 0.35 : 1)
                    .transition(.opacity)
            } else {
                InkLoader(size: 30, color: Color(red: 0.165, green: 0.153, blue: 0.133))
            }

            if overlayVisible {
                VStack(spacing: 10) {
                    switch phase {
                    case .expired:
                        Enso(progress: 0.72, lineWidth: 3.5, color: Theme.ink.opacity(0.6))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.ink.opacity(0.7))
                            )
                        Text("二维码已失效")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Button("刷新") {
                            startLogin()
                        }
                        .buttonStyle(.ink)
                    case .scanned(let nickname):
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.onInk)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.ink))
                        Text("已扫码")
                            .font(.serif(14, .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(nickname)，请在手机上确认")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    default:
                        EmptyView()
                    }
                }
                .padding(14)
                .paperSheet(cornerRadius: Theme.Radius.large, lifted: true)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            if phase == .success {
                LoginSuccessEnso()
                    .frame(width: 96, height: 96)
                    .transition(.opacity)
            }
        }
        .frame(width: 228, height: 228)
        .paperSheet(cornerRadius: Theme.Radius.standard, lifted: true)
        .overlay(alignment: .bottomTrailing) {
            SealStamp(text: "扫", size: 24)
                .rotationEffect(.degrees(-6))
                .offset(x: 8, y: 8)
                .accessibilityHidden(true)
        }
        .animation(AppAnimation.spring, value: phase)
        .animation(AppAnimation.standard, value: qrImage == nil)
    }

    private var overlayVisible: Bool {
        switch phase {
        case .expired, .scanned: return true
        default: return false
        }
    }

    private func startLogin() {
        pollTask?.cancel()
        phase = .loading
        qrImage = nil
        pollTask = Task {
            do {
                let unikey = try await NeteaseAPI.qrKey()
                let url = NeteaseAPI.qrLoginURL(unikey: unikey)
                qrImage = Self.generateQR(from: url)
                phase = .waiting

                var consecutiveErrors = 0
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1.2))
                    let check: NeteaseAPI.QRCheckResponse
                    do {
                        check = try await NeteaseAPI.qrCheck(unikey: unikey)
                        consecutiveErrors = 0
                    } catch {
                        // Ride out transient network blips; the QR code stays valid meanwhile.
                        consecutiveErrors += 1
                        if Task.isCancelled || consecutiveErrors >= 5 { throw error }
                        continue
                    }
                    switch check.code {
                    case 800:
                        phase = .expired
                        return
                    case 801:
                        if case .waiting = phase {} else { phase = .waiting }
                    case 802:
                        phase = .scanned(check.nickname ?? "")
                    case 803:
                        phase = .success
                        await account.bootstrap()
                        ToastCenter.shared.show(String(localized: "欢迎回来，\(account.profile?.nickname ?? "")"))
                        dismiss()
                        return
                    default:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    private static func generateQR(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 180, height: 180))
    }
}

/// An ensō brushed in once when the login completes.
private struct LoginSuccessEnso: View {
    @State private var progress: Double = 0
    @State private var showCheck = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DrawnEnso(progress: progress)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .opacity(showCheck ? 1 : 0)
                    .scaleEffect(showCheck ? 1 : 0.7)
            )
            .onAppear {
                if reduceMotion {
                    progress = 1
                    showCheck = true
                } else {
                    withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
                    withAnimation(AppAnimation.spring.delay(0.5)) { showCheck = true }
                }
            }
    }
}

private struct DrawnEnso: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Enso(progress: progress, lineWidth: 6, color: Color(red: 0.165, green: 0.153, blue: 0.133))
    }
}
