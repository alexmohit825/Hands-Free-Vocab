//
//  CarPlaySceneDelegate.swift
//  Hands-Free Vocab
//
//  Apple CarPlay Automotive Template Interface.
//  Zero visual distraction; audio-first with CPVoiceControlTemplate integration.
//

import CarPlay
import UIKit

public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    // MARK: - CPTemplateApplicationSceneDelegate

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        print("[CarPlay] Connected interface controller to vehicle.")
        self.interfaceController = interfaceController

        let rootTemplate = buildTabBarTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)

        // Automatically activate hands-free continuous voice recognition when car connects
        VoiceCommander.shared.startContinuousListening()
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        print("[CarPlay] Disconnected from vehicle.")
        self.interfaceController = nil
        VoiceCommander.shared.stopListening()
    }

    // MARK: - Voice Control Template Modal

    public func presentVoiceConversationOverlay() {
        guard let controller = interfaceController else { return }

        let state = CPVoiceControlState(
            identifier: "Hands-Free VocabListening",
            titleVariants: [
                "Hands-Free Vocab Voice Active",
                "Say: 'Next', 'Repeat', 'Mastered'",
                "Say: 'Explain', 'Example', 'Root'"
            ],
            image: nil,
            repeats: true
        )

        let voiceTemplate = CPVoiceControlTemplate(voiceControlStates: [state])
        voiceTemplate.activateVoiceControlState(withIdentifier: "Hands-Free VocabListening")
        controller.presentTemplate(voiceTemplate, animated: true, completion: nil)
    }

    // MARK: - Template Architecture

    private func buildTabBarTemplate() -> CPTabBarTemplate {
        var templates: [CPTemplate] = []

        // Tab 1: Commute Daily Mix (All Tiers)
        templates.append(buildCommuteSprintTemplate())

        // Tab 2..N: Curated Tiers
        for tier in VocabTier.allCases {
            templates.append(buildTierListTemplate(for: tier))
        }

        return CPTabBarTemplate(templates: templates)
    }

    private func buildCommuteSprintTemplate() -> CPListTemplate {
        // Voice conversation trigger item
        let voiceItem = CPListItem(
            text: "🎙️ Start Voice Conversation",
            detailText: "Hands-free continuous driving vocabulary tutor"
        )
        voiceItem.handler = { [weak self] _, completion in
            VoiceManager.shared.startDeck(CurriculumData.words, startingAt: 0)
            self?.presentVoiceConversationOverlay()
            completion()
        }

        let items: [CPListItem] = CurriculumData.words.prefix(10).enumerated().map { index, word in
            let item = CPListItem(
                text: word.word,
                detailText: "\(word.partOfSpeech) • \(word.shortDefinition)"
            )
            item.handler = { [weak self] _, completion in
                VoiceManager.shared.startDeck(CurriculumData.words, startingAt: index)
                self?.presentVoiceConversationOverlay()
                completion()
            }
            return item
        }

        let mainSection = CPListSection(items: [voiceItem], header: "Voice Command Mode", sectionIndexTitle: nil)
        let wordSection = CPListSection(items: items, header: "Today's High-Yield Words", sectionIndexTitle: nil)
        let list = CPListTemplate(title: "Commute Sprint", sections: [mainSection, wordSection])
        list.tabTitle = "Daily Drive"
        list.tabSystemItem = .mostRecent
        return list
    }

    private func buildTierListTemplate(for tier: VocabTier) -> CPListTemplate {
        let wordsForTier = CurriculumData.words.filter { $0.tier == tier }
        let items: [CPListItem] = wordsForTier.enumerated().map { index, word in
            let item = CPListItem(
                text: word.word,
                detailText: word.shortDefinition
            )
            item.handler = { [weak self] _, completion in
                VoiceManager.shared.startDeck(wordsForTier, startingAt: index)
                self?.presentVoiceConversationOverlay()
                completion()
            }
            return item
        }

        let section = CPListSection(items: items, header: tier.subtitle, sectionIndexTitle: nil)
        let list = CPListTemplate(title: tier.rawValue, sections: [section])
        list.tabTitle = tier.rawValue.components(separatedBy: " ").first ?? "Deck"
        list.tabSystemItem = .bookmarks
        return list
    }
}
