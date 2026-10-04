//
//  CurriculumData.swift
//  VocabRoady
//
//  Curated high-yield vocabulary data bank with morpheme roots and phonetic breakdowns.
//

import Foundation

public struct CurriculumData {
    public static let words: [VocabWord] = [
        // MARK: - Executive & Orator
        VocabWord(
            word: "Perspicacious",
            phonetic: "/ˌpɜː.spɪˈkeɪ.ʃəs/",
            partOfSpeech: "Adjective",
            shortDefinition: "Having a ready insight into and understanding of things",
            fullDefinition: "Having keen mental perception and discernment; acutely perceptive and discerning in judgment.",
            etymology: "From Latin perspicax (sharp-sighted), from perspicere (to look closely through).",
            rootFamily: "Spec / Spic (to look, observe)",
            exampleSentence: "The perspicacious CEO recognized that the merger was fundamentally flawed months before the market reacted.",
            synonyms: ["Discerning", "Astute", "Shrewd", "Perceptive"],
            antonyms: ["Obtuse", "Dense", "Myopic"],
            tier: .executive
        ),
        VocabWord(
            word: "Equivocate",
            phonetic: "/ɪˈkwɪv.ə.keɪt/",
            partOfSpeech: "Verb",
            shortDefinition: "Use ambiguous language to conceal the truth or avoid committing",
            fullDefinition: "To use unclear or evasive speech, especially with intent to deceive or to avoid committing oneself to a position.",
            etymology: "From Late Latin aequivocare, from aequus (equal) + vox (voice).",
            rootFamily: "Voc / Vox (voice, call)",
            exampleSentence: "When asked about impending hospital budget cuts, the administrator chose to equivocate rather than address the question directly.",
            synonyms: ["Hedge", "Prevaricate", "Vacillate", "Evade"],
            antonyms: ["Confront", "Clarify", "Assert"],
            tier: .executive
        ),
        VocabWord(
            word: "Salient",
            phonetic: "/ˈseɪ.li.ənt/",
            partOfSpeech: "Adjective",
            shortDefinition: "Most noticeable or important",
            fullDefinition: "Prominent, conspicuous, or standing out beyond adjacent parts; of central significance.",
            etymology: "From Latin saliens, present participle of salire (to leap).",
            rootFamily: "Sal / Sult (to leap, jump)",
            exampleSentence: "During his brief opening address, he highlighted only the three most salient aspects of the surgical trial.",
            synonyms: ["Conspicuous", "Prominent", "Pivotal", "Striking"],
            antonyms: ["Inconspicuous", "Peripheral", "Trivial"],
            tier: .executive
        ),
        VocabWord(
            word: "Obfuscate",
            phonetic: "/ˈɒb.fʌs.keɪt/",
            partOfSpeech: "Verb",
            shortDefinition: "Render obscure, unclear, or unintelligible",
            fullDefinition: "To deliberately bewilder, darken, or confuse; to make complicated or difficult to perceive.",
            etymology: "From Latin obfuscare (to darken), from fuscus (dark, brown).",
            rootFamily: "Fusc (dark, dusky)",
            exampleSentence: "Legal counsel attempted to obfuscate the core contract dispute by submitting two thousand pages of peripheral email logs.",
            synonyms: ["Confuse", "Muddle", "Cloud", "Befuddle"],
            antonyms: ["Elucidate", "Clarify", "Illuminate"],
            tier: .executive
        ),
        VocabWord(
            word: "Germane",
            phonetic: "/dʒɜːˈmeɪn/",
            partOfSpeech: "Adjective",
            shortDefinition: "Relevant to a subject under consideration",
            fullDefinition: "Directly pertinent and fitting to the matter in hand; having a tight, meaningful connection.",
            etymology: "From Old French germain (closely related), from Latin germanus (having the same parents).",
            rootFamily: "Gen / Germ (birth, origin, produce)",
            exampleSentence: "Her comments on supply chain bottlenecks were entirely germane to the quarterly board deliberations.",
            synonyms: ["Pertinent", "Applicable", "Apropos", "Cognate"],
            antonyms: ["Irrelevant", "Extraneous", "Inapplicable"],
            tier: .executive
        ),

        // MARK: - GRE & Polymath
        VocabWord(
            word: "Laconic",
            phonetic: "/ləˈkɒn.ɪk/",
            partOfSpeech: "Adjective",
            shortDefinition: "Using very few words; concise to the point of seeming blunt",
            fullDefinition: "Expressing much in few words; pithy and succinct without superfluous ornament.",
            etymology: "From Greek Lakōnikos, referring to the famously terse residents of Laconia (ancient Sparta).",
            rootFamily: "Toponymic (Spartan speech)",
            exampleSentence: "The lead surgeon gave a laconic nod before making the initial incision, needing no further instructions.",
            synonyms: ["Terse", "Succinct", "Pithy", "Compact"],
            antonyms: ["Verbose", "Loquacious", "Prolix", "Garrulous"],
            tier: .grePolymath
        ),
        VocabWord(
            word: "Ephemeral",
            phonetic: "/ɪˈfem.ər.əl/",
            partOfSpeech: "Adjective",
            shortDefinition: "Lasting for a very short time; transitory",
            fullDefinition: "Fleeting and transient; existing or lasting for merely a day or a momentary duration.",
            etymology: "From Greek ephēmeros (lasting only a day), from epi (on) + hēmera (day).",
            rootFamily: "Hemer (day, diurnal)",
            exampleSentence: "Fame on algorithmic feeds is notoriously ephemeral, fading before the end of the news cycle.",
            synonyms: ["Evanescent", "Transient", "Fugacious", "Fleeting"],
            antonyms: ["Perennial", "Permanent", "Enduring", "Eternal"],
            tier: .grePolymath
        ),
        VocabWord(
            word: "Esoteric",
            phonetic: "/ˌes.əˈter.ɪk/",
            partOfSpeech: "Adjective",
            shortDefinition: "Understood by only a small number of people with specialized knowledge",
            fullDefinition: "Confined to and understandable only by an inner circle of initiates or experts; highly specialized and obscure.",
            etymology: "From Greek esōterikos (inner), from esō (within).",
            rootFamily: "Eso / Endo (inner, within)",
            exampleSentence: "The mathematical physics paper discussed esoteric symmetries that only a dozen researchers worldwide could evaluate.",
            synonyms: ["Arcane", "Recondite", "Abstruse", "Hermetic"],
            antonyms: ["Exoteric", "Commonplace", "Accessible", "Universal"],
            tier: .grePolymath
        ),
        VocabWord(
            word: "Ubiquitous",
            phonetic: "/juːˈbɪk.wɪ.təs/",
            partOfSpeech: "Adjective",
            shortDefinition: "Present, appearing, or found everywhere",
            fullDefinition: "Existing or being encountered everywhere simultaneously; omnipresent.",
            etymology: "From Latin ubique (everywhere), from ubi (where).",
            rootFamily: "Ubi (where, location)",
            exampleSentence: "Smartphones have become so ubiquitous that life without instant cellular data is almost unimaginable.",
            synonyms: ["Omnipresent", "Pervasive", "Universal"],
            antonyms: ["Rare", "Scarce", "Infrequent"],
            tier: .grePolymath
        ),

        // MARK: - Classic Literary
        VocabWord(
            word: "Evanescent",
            phonetic: "/ˌev.əˈnes.ənt/",
            partOfSpeech: "Adjective",
            shortDefinition: "Soon passing out of sight, memory, or existence; quickly fading",
            fullDefinition: "Tending to vanish like vapor; barely perceptible and quickly fading from consciousness or view.",
            etymology: "From Latin evanescere (to disappear), from ex (out) + vanus (empty, void).",
            rootFamily: "Van / Vain (empty, void)",
            exampleSentence: "The golden hue of twilight cast an evanescent glow over the mountain ridge before dissolving into night.",
            synonyms: ["Vanishing", "Fugitive", "Ephemeral", "Fleeting"],
            antonyms: ["Indelible", "Persistent", "Abiding"],
            tier: .classicLit
        ),
        VocabWord(
            word: "Verisimilitude",
            phonetic: "/ˌver.ɪ.sɪˈmɪl.ɪ.tjuːd/",
            partOfSpeech: "Noun",
            shortDefinition: "The appearance of being true or real",
            fullDefinition: "The state of possessing the appearance or illusion of truth; genuine plausibility or lifelike realism.",
            etymology: "From Latin verisimilitudo, from verus (true) + similis (like, similar).",
            rootFamily: "Ver (true) + Simil (like)",
            exampleSentence: "The historical novelist achieved breathtaking verisimilitude by studying centuries-old maritime logbooks.",
            synonyms: ["Authenticity", "Plausibility", "Credibility", "Realism"],
            antonyms: ["Falsity", "Implausibility", "Artificiality"],
            tier: .classicLit
        ),
        VocabWord(
            word: "Ineffable",
            phonetic: "/ɪnˈef.ə.bəl/",
            partOfSpeech: "Adjective",
            shortDefinition: "Too great or extreme to be expressed or described in words",
            fullDefinition: "Incapable of being uttered or described in speech; unspeakable due to grandeur, majesty, or sanctity.",
            etymology: "From Latin ineffabilis, from in- (not) + effabilis (speakable), from effari (to utter).",
            rootFamily: "Fa / Fess (to speak, declare)",
            exampleSentence: "Looking out from the alpine summit, an ineffable sense of wonder silenced the entire climbing party.",
            synonyms: ["Indescribable", "Inexpressible", "Transcendent"],
            antonyms: ["Utterable", "Describable", "Mundane"],
            tier: .classicLit
        ),

        // MARK: - Medicolegal & Nuance
        VocabWord(
            word: "Iatrogenic",
            phonetic: "/aɪˌæt.rəˈdʒen.ɪk/",
            partOfSpeech: "Adjective",
            shortDefinition: "Induced unintentionally in a patient by medical examination or treatment",
            fullDefinition: "Relating to illness or complications caused by medical examination, medication, surgical procedure, or therapeutic intervention.",
            etymology: "From Greek iatros (physician, healer) + -genic (producing, caused by).",
            rootFamily: "Iatr (physician, medicine) + Gen (origin)",
            exampleSentence: "The postoperative hematoma was an unfortunate iatrogenic complication following the robotic vascular procedure.",
            synonyms: ["Treatment-induced", "Physician-caused"],
            antonyms: ["Idiopathic", "Spontaneous", "Congenital"],
            tier: .medicalLegal
        ),
        VocabWord(
            word: "Exculpate",
            phonetic: "/ˈek.skʌl.peɪt/",
            partOfSpeech: "Verb",
            shortDefinition: "Show or declare that someone is not guilty of wrongdoing",
            fullDefinition: "To clear from alleged fault or guilt; to free from blame or incrimination through definitive evidence.",
            etymology: "From Medieval Latin exculpare, from Latin ex- (out of, away from) + culpa (fault, blame).",
            rootFamily: "Culp (guilt, blame, fault)",
            exampleSentence: "The telemetry logs and electronic medical records fully exculpated the attending physician from the malpractice allegation.",
            synonyms: ["Absolve", "Exonerate", "Vindicate", "Acquit"],
            antonyms: ["Inculpate", "Incriminate", "Indict", "Blame"],
            tier: .medicalLegal
        )
    ]
}
