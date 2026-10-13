import SwiftUI
#if DEBUG
import GoogleMobileAds
#endif

/// Ported from CoopHockey's SettingsView. Reached from the menu as a sibling
/// screen (like High Scores), so nothing on the way in or out can trigger an ad.
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("SOUND") {
                    Toggle("Sound Effects & Haptics", isOn: $settings.effectsEnabled)
                }

                Section("ADS") {
                    if settings.hasRemovedAds {
                        Label("Ads removed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button {
                            Task { await purchaseManager.buyRemoveAds() }
                        } label: {
                            HStack {
                                if purchaseManager.isLoading { ProgressView() }
                                else { Text("Remove Ads") }
                            }
                        }
                        .disabled(purchaseManager.isLoading)

                        Button("Restore Purchases") {
                            Task { await purchaseManager.restorePurchases() }
                        }
                        .disabled(purchaseManager.isLoading)

                        if let msg = purchaseManager.errorMessage {
                            Text(msg).font(.footnote).foregroundColor(.red)
                        }
                    }
                }

                #if DEBUG
                Section("DEBUG") {
                    Button("Reset consent (UMP form shows next launch)") {
                        ConsentManager.shared.reset()
                    }

                    Button("Ad Inspector") {
                        guard let top = AdManager.topmostPresenterVC() else { return }
                        MobileAds.shared.presentAdInspector(from: top) { error in
                            if let error { print("[AdInspector] \(error.localizedDescription)") }
                        }
                    }
                }
                #endif

                Section("ABOUT") {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Credits")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .task { await purchaseManager.loadProducts() }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section("GAME") {
                Text("Flashing Numbers")
                    .font(.headline)
                Text("A reaction-time game: tap when the flashing number matches the target.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("DEVELOPMENT") {
                LabeledContent("Developer", value: "Ashutosh Bhardwaj")
            }

            Section("FRAMEWORKS") {
                LabeledContent("Ads",      value: "Google Mobile Ads SDK")
                LabeledContent("Payments", value: "StoreKit")
            }
        }
        .navigationTitle("Credits")
    }
}
