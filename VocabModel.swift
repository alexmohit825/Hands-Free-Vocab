//
//  VocabModel.swift
//  VocabRoady
//
//  Core Lexical Domain Model & Spaced Repetition (SRS) State.
//

import Foundation

public enum VocabTier: String, CaseIterable, Codable, Identifiable {
    case executive = "Executive & Orator"
    case grePolymath = "GRE & Polymath"
    case classicLit = "Classic Literary"
    case medicalLegal = "Medicolegal & Nuance"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .executive:
            return "Persuasive leadership, negotiation, and high-stakes discourse"
        case .grePolymath:
            return "Advanced academic, analytic, and competitive examination lexicon"
        case .classicLit:
            return "Prose, aesthetic nuance, and evocative literary expression"
        case .medicalLegal:
            return "Precision terminology, forensic rigor, and scholarly clarity"
        }
    }

    public var iconName: String {
        switch self {
        case .executive: return "briefcase.fill"
        case .grePolymath: return "graduationcap.fill"
        case .classicLit: return "book.closed.fill"
        case .medicalLegal: return "cross.case.fill"
        }
    }
}

public struct VocabWord: Identifiable, Codable, Equatable {
    public let id: String
    public let word: String
    public let phonetic: String
    public let partOfSpeech: String
    public let shortDefinition: String
    public let fullDefinition: String
    public let etymology: String
    public let rootFamily: String
    public let exampleSentence: String
    public let synonyms: [String]
    public let antonyms: [String]
    public let tier: VocabTier

    // Spaced repetition metrics
    public var intervalDays: Int
    public var easeFactor: Double
    public var repetitions: Int
    public var lastReviewedAt: Date?
    public var isMastered: Bool

    public init(
        word: String,
        phonetic: String,
        partOfSpeech: String,
        shortDefinition: String,
        fullDefinition: String,
        etymology: String,
        rootFamily: String,
        exampleSentence: String,
        synonyms: [String],
        antonyms: [String],
        tier: VocabTier
    ) {
        self.id = word.lowercased()
        self.word = word
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.shortDefinition = shortDefinition
        self.fullDefinition = fullDefinition
        self.etymology = etymology
        self.rootFamily = rootFamily
        self.exampleSentence = exampleSentence
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.tier = tier
        self.intervalDays = 1
        self.easeFactor = 2.5
        self.repetitions = 0
        self.lastReviewedAt = nil
        self.isMastered = false
    }

    /// Spoken script formatted for crisp, high-retention acoustic delivery in vehicle
    public var spokenAcousticHook: String {
        "\(word). \(partOfSpeech). \(shortDefinition)."
    }

    public var spokenExampleScript: String {
        "In context: \(exampleSentence)"
    }

    public var spokenEtymologyScript: String {
        "Origin: \(etymology). Root family: \(rootFamily)."
    }

    public var spokenDetailedScript: String {
        "\(word). \(partOfSpeech). \(fullDefinition). In context: \(exampleSentence). Root: \(etymology)."
    }
}
