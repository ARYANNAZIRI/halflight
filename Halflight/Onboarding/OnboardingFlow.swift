import AVFoundation
import Photos
import SwiftUI

/// Four screens, skip-able after the first. Capture is never blocked behind a tutorial.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @State private var page = 0

    var body: some View {
        ZStack {
            Theme.chrome.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    WelcomePage().tag(0)
                    FoldPage().tag(1)
                    PermissionsPage().tag(2)
                    DefaultModePage().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                HStack {
                    if page > 0 {
                        Button("Skip") { finish() }
                            .foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Button(page == 3 ? "Start" : "Continue") {
                        if page == 3 { finish() } else { withAnimation(Theme.snap) { page += 1 } }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.amber)
                    .foregroundStyle(Theme.chrome)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func finish() {
        app.settings.onboardingDone = true
    }
}

private struct OnboardingPage<Content: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            content
                .frame(height: 220)
            Text(title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage(title: "The other screen is for them.", detail: "You keep the viewfinder. They see a preview, a cue, or a script.") {
            HalflightMark()
        }
    }
}

/// Two leaves sharing one hinge. The outer leaf lights up when the phone opens.
private struct FoldPage: View {
    @State private var open = false

    var body: some View {
        OnboardingPage(title: "Open the phone", detail: "Turn on Facing and the outer display becomes theirs.") {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.chromeRaised)
                    .frame(width: 90, height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.ink.opacity(0.5), lineWidth: 2)
                            .padding(8)
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.navy)
                    .frame(width: 90, height: 180)
                    .overlay(
                        Circle()
                            .fill(Theme.amber)
                            .frame(width: 34, height: 34)
                            .opacity(open ? 1 : 0)
                    )
                    .rotation3DEffect(.degrees(open ? 0 : -150), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.6)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.4)) {
                    open = true
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct PermissionsPage: View {
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var mic = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var photos = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    var body: some View {
        OnboardingPage(title: "Permissions", detail: "Camera for the viewfinder. Microphone for video. Photos, add-only, when you save.") {
            VStack(spacing: 12) {
                PermissionRow(title: "Camera", symbol: "camera", granted: camera == .authorized) {
                    _ = await Permissions.camera()
                    camera = AVCaptureDevice.authorizationStatus(for: .video)
                }
                PermissionRow(title: "Microphone", symbol: "mic", granted: mic == .authorized) {
                    _ = await Permissions.microphone()
                    mic = AVCaptureDevice.authorizationStatus(for: .audio)
                }
                PermissionRow(title: "Photos (add only)", symbol: "photo.badge.plus", granted: photos == .authorized || photos == .limited) {
                    _ = await Permissions.photosAddOnly()
                    photos = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                }
            }
        }
    }
}

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let symbol: String
    let granted: Bool
    let request: @MainActor () async -> Void

    var body: some View {
        Button {
            Task { await request() }
        } label: {
            HStack {
                Image(systemName: symbol).frame(width: 28)
                Text(title)
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? Theme.amber : Theme.inkFaint)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.chromeRaised))
        }
        .buttonStyle(.plain)
        .disabled(granted)
        .accessibilityValue(granted ? Text("Allowed") : Text("Not yet"))
    }
}

private struct DefaultModePage: View {
    @Environment(AppState.self) private var app

    var body: some View {
        OnboardingPage(title: "What should they see?", detail: "You can change this any time in Facing.") {
            VStack(spacing: 10) {
                ForEach(FacingMode.onboardingChoices) { mode in
                    Button {
                        app.settings.defaultFacingMode = mode
                        app.capture.setFacingMode(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.symbol).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                Text(mode.summary).font(.footnote).foregroundStyle(Theme.inkMuted)
                            }
                            Spacer()
                            Image(systemName: app.settings.defaultFacingMode == mode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(app.settings.defaultFacingMode == mode ? Theme.amber : Theme.inkFaint)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.chromeRaised))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(app.settings.defaultFacingMode == mode ? [.isSelected] : [])
                }
            }
        }
    }
}

/// The app mark: two leaves, one hinge, an aperture in the left leaf.
struct HalflightMark: View {
    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.navy)
                .frame(width: 84, height: 150)
                .overlay(
                    Circle().stroke(Theme.amber, lineWidth: 9).frame(width: 40, height: 40)
                )
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.navy)
                .frame(width: 84, height: 150)
        }
        .accessibilityLabel(Text("Halflight"))
    }
}

#Preview {
    OnboardingFlow().environment(AppState())
}
