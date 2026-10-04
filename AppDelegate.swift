//
//  AppDelegate.swift
//  VocabRoady
//
//  Application entry point and lifecycle delegate.
//

import UIKit

@main
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[VocabRoady] Launched. Preparing speech and audio cache engines.")
        _ = AudioCache.shared
        _ = VoiceCommander.shared
        _ = VoiceManager.shared
        return true
    }

    // MARK: - UISceneSession Lifecycle

    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            return UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
