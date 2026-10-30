//
//  VoiceAuditionSheet.swift
//  Orator: Executive Lexicon
//
//  Apple Design Award Editorial Voice Audition Studio:
//  - Warm Editorial Parchment (#EFECE4), Crisp White cards, and Coastal Sage-Teal (#739E9B) accents.
//  - Discovers all high-fidelity Apple speech voices installed on the iPhone.
//  - Badges Premium, Enhanced, and Alex breathing models.
//

import SwiftUI
import AVFoundation

public struct VoiceAuditionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var voiceManager = VoiceManager.shared

    @State private var previewSynthesizer = AVSpeechSynthesizer()
    @State private var previewingVoiceID: String? = nil
    @State private var isSpeakingPreview: Bool = false

    private let canvasParchment = Color(red: 0.937, green: 0.925, blue: 0.894) // #EFECE4
    private let cardWhite = Color.white
    private let warmLinen = Color(red: 0.969, green: 0.961, blue: 0.941)
    private let inkCharcoal = Color(red: 0.110, green: 0.133, blue: 0.133)     // #1C2222
    private let slateMuted = Color(red: 0.345, green: 0.400, blue: 0.400)
    private let coastalSage = Color(red: 0.451, green: 0.620, blue: 0.608)     // #739E9B
    private let matchaMint = Color(red: 0.710, green: 0.839, blue: 0.612)      // #B5D69C
    private let warmGold = Color(red: 0.949, green: 0.788, blue: 0.298)

    private var voices: [AVSpeechSynthesisVoice] {
        AudioCache.availableEnglishVoices
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                canvasParchment.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        guidanceCard
                        enhancedVoiceTipCard

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Installed English Voices (\(voices.count))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(slateMuted)
                                .textCase(.uppercase)

                            ForEach(voices, id: \.identifier) { voice in
                                voiceRow(voice)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Voice Audition Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        previewSynthesizer.stopSpeaking(at: .immediate)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)
                }
            }
            .onDisappear {
                previewSynthesizer.stopSpeaking(at: .immediate)
            }
        }
        .preferredColorScheme(.light)
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundColor(coastalSage)
                    .font(.system(size: 18, weight: .bold))
                Text("100% On-Device Neural Synthesis")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
            }

            Text("Orator uses Apple's native neural speech engine. It works completely offline in your vehicle with zero cloud delay and zero cellular data usage.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(slateMuted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private var enhancedVoiceTipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(inkCharcoal)
                    .font(.system(size: 15, weight: .bold))
                Text("Pro-Tip: Unlock Studio Voices Free")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
            }

            Text("For the most natural human inflection, open iPhone Settings > Accessibility > Spoken Content > Voices > English and download Ava (Enhanced), Zoe (Enhanced), or Alex.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(inkCharcoal.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(14)
        .background(warmGold.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.4)
        )
    }

    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        let isSelected = voiceManager.selectedVoiceIdentifier == voice.identifier
        let isPreviewing = previewingVoiceID == voice.identifier && isSpeakingPreview

        return Button {
            voiceManager.selectVoice(identifier: voice.identifier)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? coastalSage : slateMuted.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(inkCharcoal)

                        qualityBadge(for: voice)
                    }

                    HStack(spacing: 8) {
                        Text(voice.language)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(slateMuted)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(slateMuted)

                        Text(voice.gender == .male ? "Male" : (voice.gender == .female ? "Female" : "Neutral"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(slateMuted)
                    }
                }

                Spacer()

                Button {
                    previewVoice(voice)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPreviewing ? "stop.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(isPreviewing ? "Stop" : "Sample")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(inkCharcoal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isPreviewing ? warmGold : warmLinen)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(isSelected ? matchaMint.opacity(0.35) : cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(inkCharcoal, lineWidth: isSelected ? 1.8 : 1.3)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func qualityBadge(for voice: AVSpeechSynthesisVoice) -> some View {
        if voice.identifier.contains("Alex") || voice.name.lowercased() == "alex" {
            Text("Breath Model")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(inkCharcoal)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(warmGold)
                .clipShape(Capsule())
        } else if voice.quality == .premium {
            Text("Premium")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(inkCharcoal)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(matchaMint)
                .clipShape(Capsule())
        } else if voice.quality == .enhanced {
            Text("Enhanced")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(inkCharcoal)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(coastalSage.opacity(0.4))
                .clipShape(Capsule())
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        if previewingVoiceID == voice.identifier && isSpeakingPreview {
            previewSynthesizer.stopSpeaking(at: .immediate)
            isSpeakingPreview = false
            previewingVoiceID = nil
            if !voiceManager.isCarPlayConnected && !voiceManager.isPlaying {
                VoiceCommander.shared.startContinuousListening()
            }
            return
        }

        VoiceCommander.shared.stopListening()
        voiceManager.configureAudioSessionIfNeeded()

        previewSynthesizer.stopSpeaking(at: .immediate)
        previewingVoiceID = voice.identifier
        isSpeakingPreview = true

        let utterance = AVSpeechUtterance(string: "Welcome to Orator. Master precision vocabulary for executive leadership.")
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.15

        previewSynthesizer.speak(utterance)
    }
}
