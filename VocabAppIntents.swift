//
//  VocabAppIntents.swift
//  Hands-Free Vocab
//
//  iOS 17+ App Intents & Siri Shortcuts Provider.
//  Enables hands-free voice invocation: "Hey Siri, start Hands-Free Vocab"
//

import AppIntents
import SwiftUI

@available(iOS 17.0, *)
public struct StartHandsFreeVocabIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Hands-Free Vocab"
    public static var description = IntentDescription("Launches Hands-Free Vocab and automatically begins your automotive vocabulary study session.")

    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        print("[AppIntent] Siri triggered StartHandsFreeVocabIntent.")
        
        // Start study session immediately
        VoiceManager.shared.startDeck(CurriculumData.words, startingAt: 0)
        VoiceCommander.shared.startContinuousListening()
        
        return .result()
    }
}

@available(iOS 17.0, *)
public struct VocabAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartHandsFreeVocabIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Open \(.applicationName)",
                "Start studying with \(.applicationName)",
                "Begin drive with \(.applicationName)",
                "Start commute with \(.applicationName)"
            ],
            shortTitle: "Start Drive",
            systemImageName: "car.fill"
        )
    }
}
