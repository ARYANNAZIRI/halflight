import SwiftUI

/// Tab shell. Compact width (outer display, closed Duo, other iPhones) uses the system tab bar.
/// Regular width (inner display, open Duo) uses a vertical rail on the leading edge so the
/// content pane keeps its full height for the viewfinder.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        Group {
            if hSize == .regular {
                RegularShell(tab: $app.tab)
            } else {
                CompactShell(tab: $app.tab)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.amber)
        .fullScreenCover(isPresented: Binding(
            get: { !app.settings.onboardingDone },
            set: { if !$0 { app.settings.onboardingDone = true } }
        )) {
            OnboardingFlow()
        }
        .fullScreenCover(isPresented: Binding(
            get: { app.capture.cueOverlayShown },
            set: { app.capture.showCueOverlay($0) }
        )) {
            MotionCueOverlay(model: app.capture)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                Task { await app.capture.enterBackground() }
            case .active:
                if app.tab == .capture, app.settings.onboardingDone {
                    Task { await app.capture.start() }
                }
            default:
                break
            }
        }
        .onChange(of: app.hinge.facingAvailable) { _, available in
            // Accessory went away (phone closed, session ended): flip the toggle off, never crash.
            if !available { app.capture.facingEnabled = false }
        }
        .onChange(of: app.hinge.posture) { _, posture in
            app.capture.postureChanged(posture)
        }
    }
}

private struct CompactShell: View {
    @Binding var tab: AppState.Tab

    var body: some View {
        TabView(selection: $tab) {
            ForEach(AppState.Tab.allCases) { item in
                Tab(item.title, systemImage: item.symbol, value: item) {
                    TabContent(tab: item)
                }
            }
        }
        .toolbarBackground(Theme.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct RegularShell: View {
    @Binding var tab: AppState.Tab

    var body: some View {
        HStack(spacing: 0) {
            RailView(tab: $tab)
            Divider().background(Theme.chromeLine)
            TabContent(tab: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .chromeBackground()
    }
}

/// Vertical rail: 72pt, pictograms, amber only for the selected item.
private struct RailView: View {
    @Binding var tab: AppState.Tab

    var body: some View {
        VStack(spacing: 6) {
            ForEach(AppState.Tab.allCases) { item in
                Button {
                    withAnimation(Theme.quick) { tab = item }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .regular))
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? Theme.amber : Theme.inkMuted)
                    .frame(width: 64, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(tab == item ? Theme.chromeRaised : .clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
            Spacer()
        }
        .padding(.top, 12)
        .frame(width: 72)
        .frame(maxHeight: .infinity)
        .background(Theme.chrome)
    }
}

private struct TabContent: View {
    let tab: AppState.Tab

    var body: some View {
        switch tab {
        case .capture: CaptureView()
        case .facing: FacingStudioView()
        case .roll: RollView()
        case .edit: EditTabView()
        case .settings: SettingsView()
        }
    }
}

#Preview("Compact") {
    RootView()
        .environment(AppState())
}

#Preview("Regular", traits: .fixedLayout(width: 1000, height: 740)) {
    RootView()
        .environment(AppState())
        .environment(\.horizontalSizeClass, .regular)
}
