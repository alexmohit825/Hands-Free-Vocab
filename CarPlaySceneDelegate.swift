//
//  CarPlaySceneDelegate.swift
//  Hands-Free Vocab
//
//  Apple CarPlay Automotive Template Interface.
//  Matching Hands-Free Lingo proven architecture: CPTabBarTemplate -> CPListTemplate -> CPNowPlayingTemplate.
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

        let tabTemplate = buildTabBarTemplate()
        interfaceController.setRootTemplate(tabTemplate, animated: false, completion: nil)
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

        // Tab 1: Commute Daily Sprint
        templates.append(buildCommuteSprintTemplate())

        // Tab 2..N: Curated Tiers
        for tier in VocabTier.allCases {
            templates.append(buildTierListTemplate(for: tier))
        }

        let tabBar = CPTabBarTemplate(templates: templates)
        return tabBar
    }

    private func buildCommuteSprintTemplate() -> CPListTemplate {
        let items: [CPListItem] = CurriculumData.words.prefix(12).enumerated().map { index, word in
            let item = CPListItem(
                text: word.word,
                detailText: "\(word.partOfSpeech) • \(word.shortDefinition)"
            )
            item.handler = { [weak self] _, completion in
                self?.startDriveSession(deck: CurriculumData.words, index: index)
                completion()
            }
            return item
        }

        let mainSection = CPListSection(items: items, header: "DAILY SPRINT • 100% HANDS-FREE", sectionIndexTitle: nil)
        let list = CPListTemplate(title: "Daily Drive", sections: [mainSection])
        list.tabTitle = "Daily Drive"
        list.tabImage = UIImage(systemName: "car.fill")
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
                self?.startDriveSession(deck: wordsForTier, index: index)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items, header: tier.subtitle.uppercased(), sectionIndexTitle: nil)
        let list = CPListTemplate(title: tier.rawValue, sections: [section])
        list.tabTitle = tier.rawValue.components(separatedBy: " ").first ?? "Track"
        list.tabImage = UIImage(systemName: tier.iconName)
        return list
    }

    private func startDriveSession(deck: [VocabWord], index: Int) {
        VoiceManager.shared.startDeck(deck, startingAt: index)

        // Push Now Playing Template so the vehicle head unit shows the word, track info, and playback progress
        let nowPlaying = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(nowPlaying, animated: true, completion: nil)
    }
}
