import StoreKit
import SwiftUI

/// One screen, one price, one button. No timers, no fake discounts.
struct ProPaywallView: View {
    @Environment(PawState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var buying = false

    var body: some View {
        let pro = app.pro
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.treat)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("Pawlight Pro")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity)

                    Text("Every lure and every sound, and a burst of shots each time your pet looks up. Pay once, keep it.")
                        .font(.body)
                        .foregroundStyle(Theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        Benefit(symbol: "rectangle.on.rectangle.angled", text: "All six lures on the outer screen: Feather, Mouse, Bubbles, Peek Paw and more")
                        Benefit(symbol: "speaker.wave.2.fill", text: "All six sounds: Whistle, Chirp, Crinkle and Bell")
                        Benefit(symbol: "square.stack.3d.up.fill", text: "Up to 5 shots per catch, so you get the one with the ears up")
                        Benefit(symbol: "lock.shield", text: "Still no account, no ads, no tracking")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.chromeRaised))

                    if pro.isPro {
                        Label("You have Pawlight Pro", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.ready)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            Task { await buy() }
                        } label: {
                            Group {
                                if buying || pro.isLoading {
                                    ProgressView().tint(.black)
                                } else if let product = pro.product {
                                    Text("Unlock for \(product.displayPrice)")
                                } else {
                                    Text("Unavailable right now")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.treat))
                        }
                        .buttonStyle(.plain)
                        .disabled(pro.product == nil || buying)

                        Button("Restore Purchases") {
                            Task { await pro.restore() }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Theme.inkMuted)
                    }

                    if let message = pro.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(Theme.chrome)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await pro.load() }
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private func buy() async {
        guard let product = app.pro.product else { return }
        buying = true
        defer { buying = false }
        do {
            let result = try await purchase(product)
            await app.pro.handle(result)
        } catch {
            app.pro.errorMessage = error.localizedDescription
        }
    }
}

private struct Benefit: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.treat)
                .frame(width: 24)
            Text(text)
                .foregroundStyle(Theme.ink)
        }
    }
}
