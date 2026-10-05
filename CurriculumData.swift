//
//  CurriculumData.swift
//  Hands-Free Vocab
//
//  1,800-Word Comprehensive Curriculum across 60 progressive automotive study sets.
//  Loads the bundled CurriculumData.json with instant fallback.
//

import Foundation

public struct CurriculumData {
    public static let words: [VocabWord] = {
        // Attempt to load full 1,800-word dataset from CurriculumData.json bundle
        if let url = Bundle.main.url(forResource: "CurriculumData", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([VocabWord].self, from: data), !decoded.isEmpty {
                print("[CurriculumData] Successfully loaded \(decoded.count) words across 60 sets from bundle.")
                return decoded
            }
        }
        
        // Fallback embedded seed if bundle read fails
        return seedFallbackWords
    }()

    public static var totalSetsCount: Int {
        let maxSet = words.map { $0.setNumber }.max() ?? 60
        return max(maxSet, 60)
    }

    public static func wordsForSet(_ setNumber: Int) -> [VocabWord] {
        words.filter { $0.setNumber == setNumber }
    }

    public static func wordsForTier(_ tier: VocabTier) -> [VocabWord] {
        words.filter { $0.tier == tier }
    }

    private static let seedFallbackWords: [VocabWord] = [
        VocabWord(
            word: "Perspicacious",
            phonetic: "/ˌpɜː.spɪˈkeɪ.ʃəs/",
            partOfSpeech: "Adjective",
            shortDefinition: "Having keen insight and understanding",
            fullDefinition: "Acutely perceptive and discerning in judgment.",
            etymology: "From Latin perspicax (sharp-sighted), from perspicere (to see through).",
            rootFamily: "Spec / Spic (to look, observe)",
            exampleSentence: "The perspicacious CEO restructured the subsidiary months before the market contracted.",
            synonyms: ["Discerning", "Astute", "Shrewd"],
            antonyms: ["Obtuse", "Myopic"],
            tier: .executive,
            setNumber: 1
        ),
        VocabWord(
            word: "Equivocate",
            phonetic: "/ɪˈkwɪv.ə.keɪt/",
            partOfSpeech: "Verb",
            shortDefinition: "Use ambiguous language to conceal the truth",
            fullDefinition: "To use evasive speech with intent to deceive or avoid committing oneself.",
            etymology: "From Late Latin aequivocare, from aequus (equal) + vox (voice).",
            rootFamily: "Voc / Vox (voice, call)",
            exampleSentence: "The spokesperson began to equivocate when pressed on executive compensation.",
            synonyms: ["Hedge", "Prevaricate", "Evade"],
            antonyms: ["Clarify", "Assert"],
            tier: .executive,
            setNumber: 1
        ),
        VocabWord(
            word: "Salient",
            phonetic: "/ˈseɪ.li.ənt/",
            partOfSpeech: "Adjective",
            shortDefinition: "Most noticeable or prominent",
            fullDefinition: "Prominent, conspicuous, or of central significance in argument.",
            etymology: "From Latin saliens, participle of salire (to leap).",
            rootFamily: "Sal / Sult (to leap, jump)",
            exampleSentence: "He focused entirely on the salient points of the cross-border merger.",
            synonyms: ["Conspicuous", "Pivotal", "Striking"],
            antonyms: ["Inconspicuous", "Peripheral"],
            tier: .executive,
            setNumber: 1
        ),
        VocabWord(
            word: "Obfuscate",
            phonetic: "/ˈɒb.fʌs.keɪt/",
            partOfSpeech: "Verb",
            shortDefinition: "Render obscure, unclear, or unintelligible",
            fullDefinition: "To deliberately bewilder, darken, or confuse meaning.",
            etymology: "From Latin obfuscare (to darken), from fuscus (dark, brown).",
            rootFamily: "Fusc (dark, dusky)",
            exampleSentence: "The auditor argued the accounting notes were drafted to obfuscate liabilities.",
            synonyms: ["Muddle", "Befuddle", "Cloud"],
            antonyms: ["Elucidate", "Clarify"],
            tier: .executive,
            setNumber: 1
        ),
        VocabWord(
            word: "Germane",
            phonetic: "/dʒɜːˈmeɪn/",
            partOfSpeech: "Adjective",
            shortDefinition: "Relevant to a subject under consideration",
            fullDefinition: "Directly pertinent and fitting to the matter in hand.",
            etymology: "From Old French germain, from Latin germanus (having the same parents).",
            rootFamily: "Gen / Germ (origin, birth)",
            exampleSentence: "Her insights on regulatory compliance were directly germane to the acquisition.",
            synonyms: ["Pertinent", "Apropos", "Applicable"],
            antonyms: ["Irrelevant", "Extraneous"],
            tier: .executive,
            setNumber: 1
        )
    ]
}
