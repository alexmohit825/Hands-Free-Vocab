//
//  ContentView.swift
//  Hands-Free Vocab
//
//  iPhone Companion Studio & In-Car Mirroring Dashboard.
//

import SwiftUI
import Speech
import AVFoundation

public struct ContentView: View {
    @ObservedObject var voiceManager = VoiceManager.shared
    @ObservedObject var voiceCommander = VoiceCommander.shared
    @ObservedObject var storeManager = StoreKitManager.shared
    @State private var showingVoiceCommandCheatSheet: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var hasRequestedPermissions: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Automotive Live Header Card
                        carPlayStatusCard

                        // Active Driving / Audio Player Mirror
                        if let currentWord = voiceManager.currentWord {
                            activeWordCard(currentWord)
                        } else {
                            startSessionPromptCard
                        }

                        // Hands-Free Voice Control Radar
                        voiceRecognitionStatusCard

                        // Curated Curriculum Tiers
                        curriculumTiersSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Orator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            voiceManager.selectedVoicePersona = "Natural Female (Ava / Samantha)"
                        } label: {
                            Label("Natural Female (Ava / Samantha)", systemImage: voiceManager.selectedVoicePersona.contains("Female") ? "checkmark" : "")
                        }
                        Button {
                            voiceManager.selectedVoicePersona = "Natural Male (Evan / Tom)"
                        } label: {
                            Label("Natural Male (Evan / Tom)", systemImage: voiceManager.selectedVoicePersona.contains("Male") ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 15))
                            Text(voiceManager.selectedVoicePersona.contains("Male") ? "Male" : "Female")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        if !storeManager.isUnlocked {
                            Button {
                                showingPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                    Text("Unlock")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.yellow)
                                .cornerRadius(12)
                            }
                        }

                        Button {
                            showingVoiceCommandCheatSheet.toggle()
                        } label: {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingVoiceCommandCheatSheet) {
                voiceCommandSheet
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .onReceive(voiceManager.$shouldShowPaywall) { show in
                if show {
                    showingPaywall = true
                    voiceManager.shouldShowPaywall = false
                }
            }
            .onAppear {
                // Warm up audio session and pre-request speech permissions
                if !hasRequestedPermissions {
                    hasRequestedPermissions = true
                    voiceCommander.requestPermissionsAndStart { granted in
                        print("[ContentView] Microphone & Speech permissions: \(granted)")
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var carPlayStatusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("CarPlay Audio Engine Ready")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("100% Hands-Free • Voice-Controlled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            Circle()
                .fill(voiceCommander.isListening ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var startSessionPromptCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange)

            Text("Begin Today's Commute Deck")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Tap to start listening, or connect to your car's CarPlay screen. Control everything hands-free with your voice.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button {
                voiceCommander.requestPermissionsAndStart { _ in
                    voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                }
            } label: {
                Text("Start Hands-Free Drive")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.12))
        .cornerRadius(20)
    }

    private func activeWordCard(_ word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(word.tier.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)

                Text("SET \(word.setNumber) OF 60")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)

                Spacer()

                Text(word.partOfSpeech)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(word.word)
                    .font(.system(size: 34, weight: .heavy, design: .serif))
                    .foregroundColor(.white)

                Text(word.phonetic)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.9))
            }

            Text(word.shortDefinition)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(white: 0.9))
                .lineSpacing(4)

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 6) {
                Text("EXAMPLE IN CONTEXT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Text("\"\(word.exampleSentence)\"")
                    .font(.system(size: 14, weight: .regular))
                    .italic()
                    .foregroundColor(Color(white: 0.8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ROOT FAMILY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Text(word.rootFamily)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
            }

            // Driver Status Mode Banner & Manual Audio Tap
            Button {
                voiceManager.speakText(word.spokenAcousticHook) {}
            } label: {
                HStack {
                    Image(systemName: voiceManager.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.orange)
                    Text(voiceManager.playbackModeDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Tap to Speak")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var voiceRecognitionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                Text("VOICE RADAR (ON-DEVICE)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)

                Spacer()

                if let cmd = voiceCommander.lastDetectedCommand {
                    Text("Last: \(cmd.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(6)
                }
            }

            if voiceCommander.recognizedTranscription.isEmpty {
                Text(voiceCommander.isListening ? "Listening in vehicle for \"Next\", \"Repeat\", \"Mastered\"..." : "Microphone initializing...")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .italic()
            } else {
                Text("\"\(voiceCommander.recognizedTranscription)\"")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            // Quick Voice Action Triggers
            HStack(spacing: 8) {
                voiceTestPill("Next", cmd: .next)
                voiceTestPill("Repeat", cmd: .repeatWord)
                voiceTestPill("Mastered", cmd: .mastered)
                voiceTestPill("Explain", cmd: .explain)
                voiceTestPill("Root", cmd: .root)
            }
        }
        .padding(16)
        .background(Color(white: 0.10))
        .cornerRadius(16)
    }

    private func voiceTestPill(_ title: String, cmd: VocabCommand) -> some View {
        Button {
            voiceManager.didRecognizeCommand(cmd)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
        }
    }

    private var curriculumTiersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VOCABULARY TRACKS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)

            ForEach(VocabTier.allCases) { tier in
                Button {
                    let words = CurriculumData.words.filter { $0.tier == tier }
                    voiceCommander.requestPermissionsAndStart { _ in
                        voiceManager.startDeck(words, startingAt: 0)
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: tier.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(.orange)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tier.rawValue)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text(storeManager.isUnlocked ? "\(CurriculumData.wordsForTier(tier).count) words • 15 Sets (Unlocked)" : "Set 1 Free • 15 Sets Total")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(storeManager.isUnlocked ? .green.opacity(0.85) : .yellow.opacity(0.85))
                            Text(tier.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer()

                        if !storeManager.isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow.opacity(0.8))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color(white: 0.12))
                    .cornerRadius(14)
                }
            }
        }
    }

    private var voiceCommandSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Drive safely. Orator requires zero touches or button pressing while you are behind the wheel.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)

                        commandGuideRow("Next / Skip / Forward", description: "Advances immediately to the next vocabulary word.")
                        commandGuideRow("Repeat / Again / Say Again", description: "Re-plays the acoustic phonetic hook of the current word.")
                        commandGuideRow("Mastered / Got It / Easy", description: "Flags word as mastered, increments SRS interval, and advances.")
                        commandGuideRow("Explain / Detail / Elaborate", description: "Spoken narration of the full comprehensive definition.")
                        commandGuideRow("Example / Sentence / Context", description: "Speaks the real-world usage and contextual sentence.")
                        commandGuideRow("Root / Origin / Etymology", description: "Narrates Latin/Greek roots and morphological word family.")
                        commandGuideRow("Pause / Stop / Wait", description: "Temporarily pauses the audio session.")
                        commandGuideRow("Resume / Play / Continue", description: "Resumes audio playback exactly where you left off.")
                        commandGuideRow("Hey Siri, start Orator", description: "Launches the app and immediately starts automotive audio playback.")
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Spoken Commands")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func commandGuideRow(_ phrase: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎙️ \"\(phrase)\"")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}
