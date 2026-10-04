//
//  HandsFreeVocabApp.swift
//  Hands-Free Vocab
//
//  Main SwiftUI App entry point matching Hands-Free Lingo.
//

import SwiftUI

@main
struct HandsFreeVocabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
