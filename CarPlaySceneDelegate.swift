//
//  CarPlaySceneDelegate.swift
//  VocabRoady
//
//  Apple CarPlay Automotive Template Interface.
//  Zero visual distraction; audio-first with voice command hints and glanceable metadata.
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
        let items: [CPListItem] = CurriculumData.words.prefix(8).enumerated().map { index, word in
            let item = CPListItem(
                text: word.word,
                detailText: "\(word.partOfSpeech) • \(word.shortDefinition)"
            )
            item.handler = { [weak self] _, completion in
                VoiceManager.shared.startDeck(CurriculumData.words, startingAt: index)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items, header: "🎙️ Hands-Free Commute (Say 'Next', 'Repeat', 'Mastered')", sectionIndexTitle: nil)
        let list = CPListTemplate(title: "Commute Sprint", sections: [section])
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
