//
//  FlashingNumbersV1App.swift
//  FlashingNumbersV1
//
//  Created by Ashutosh Bhardwaj on 2025-04-29.
//
import SwiftUI
import GoogleMobileAds

@main
struct FlashingNumbersV1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MobileAds.shared.start(completionHandler: nil)
        return true
    }
}
