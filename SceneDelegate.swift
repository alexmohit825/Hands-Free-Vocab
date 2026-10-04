//
//  SceneDelegate.swift
//  VocabRoady
//
//  iPhone Companion Window Scene Delegate.
//

import UIKit
import SwiftUI

public final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let contentView = ContentView()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }
}
