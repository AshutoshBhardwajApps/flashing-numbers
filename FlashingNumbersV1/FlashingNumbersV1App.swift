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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(AdPresenter().frame(width: 0, height: 0))
        }
    }
}
