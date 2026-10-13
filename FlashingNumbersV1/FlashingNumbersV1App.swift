//
//  FlashingNumbersV1App.swift
//  FlashingNumbersV1
//
//  Created by Ashutosh Bhardwaj on 2025-04-29.
//
import SwiftUI

@main
struct FlashingNumbersV1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var settings        = SettingsStore.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(AdPresenter().frame(width: 0, height: 0))
                .environmentObject(settings)
                .environmentObject(purchaseManager)
                .task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.restorePurchases()
                }
        }
    }
}
