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
    @StateObject private var gameCenter      = GameCenterManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(AdPresenter().frame(width: 0, height: 0))
                .environmentObject(settings)
                .environmentObject(purchaseManager)
                .environmentObject(gameCenter)
                .task {
                    // Game Center may present its own sign-in sheet, so this
                    // runs from .task rather than the AppDelegate.
                    gameCenter.authenticate()
                    await purchaseManager.loadProducts()
                    await purchaseManager.restorePurchases()
                }
        }
    }
}
