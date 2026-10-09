//
//  VoiceAuditionSheet.swift
//  Orator: Executive Lexicon
//
//  100% On-Device Voice Audition & Selection Studio:
//  - Discovers all high-fidelity Apple speech voices installed on the iPhone.
//  - Badges Premium, Enhanced, and Alex breathing models.
//  - Interactive 1-tap sample preview.
//  - Persists preference locally with zero cloud dependencies.
//

import SwiftUI
import AVFoundation

public struct VoiceAuditionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var voiceManager = VoiceManager.shared

    @State private var previewSynthesizer = AVSpeechSynthesizer()
    @State private var previewingVoiceID: String? = nil
    @State private var isSpeakingPreview: Bool = false

    private var voices: [AVSpeechSynthesisVoice] {
        AudioCache.availableEnglishVoices
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Guidance Card
                        guidanceCard

                        // Tip for Apple Enhanced Studio Voices
                        enhancedVoiceTipCard

                        // Voice List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Installed English Voices (\(voices.count))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.gray)
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                }
            }
            .onDisappear {
                previewSynthesizer.stopSpeaking(at: .immediate)
            }
        }
    }

    // MARK: - Guidance Cards

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                Text("100% On-Device Synthesis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Orator uses Apple's native neural speech engine. It works completely offline in your vehicle with zero cloud delay, zero data usage, and zero recurring server costs.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }

    private var enhancedVoiceTipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("Pro-Tip: Get Studio Quality Free")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
            }

            Text("For the most natural human inflection and breathing dynamics, open iPhone **Settings > Accessibility > Spoken Content > Voices > English** and tap the download icon next to **Ava (Enhanced)**, **Zoe (Enhanced)**, or **Alex**. They will appear here automatically.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color.yellow.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Voice Row

    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        let isSelected = voiceManager.selectedVoiceIdentifier == voice.identifier
        let isPreviewing = previewingVoiceID == voice.identifier && isSpeakingPreview

        return Button {
            voiceManager.selectVoice(identifier: voice.identifier)
        } label: {
            HStack(spacing: 14) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .orange : .gray.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                            .foregroundColor(.white)

                        qualityBadge(for: voice)
                    }

                    HStack(spacing: 8) {
                        Text(voice.language)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        Text(voice.gender == .male ? "Male" : (voice.gender == .female ? "Female" : "Neutral"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Audition Play Button
                Button {
                    previewVoice(voice)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPreviewing ? "stop.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 12))
                        Text(isPreviewing ? "Stop" : "Sample")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(isPreviewing ? .yellow : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isPreviewing ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(isSelected ? Color.orange.opacity(0.12) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func qualityBadge(for voice: AVSpeechSynthesisVoice) -> some View {
        if voice.identifier.contains("Alex") || voice.name.lowercased() == "alex" {
            Text("Apple Breath Model")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(6)
        } else if voice.quality == .premium {
            Text("Premium")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
        } else if voice.quality == .enhanced {
            Text("Enhanced")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(6)
        } else {
            Text("Standard")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        if previewingVoiceID == voice.identifier && isSpeakingPreview {
            previewSynthesizer.stopSpeaking(at: .immediate)
            isSpeakingPreview = false
            previewingVoiceID = nil
            return
        }

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
