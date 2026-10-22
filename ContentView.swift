//
//  ContentView.swift
//  Orator: Executive Lexicon
//
//  Premier App Store Architecture:
//  - Tab 1: Words (Daily Executive Card matching premier archetype with classic Serif typography)
//  - Tab 2: Practice (Executive Rank bell curve, Sprint/Rush challenges, interactive recall quiz)
//  - Tab 3: Tracks (The 4 specialized collegiate curricula)
//  - Tab 4: Drive (100% hands-free automotive cockpit with CarPlay voice radar)
//

import SwiftUI
import Speech
import AVFoundation
import StoreKit

public struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var voiceManager = VoiceManager.shared
    @ObservedObject var voiceCommander = VoiceCommander.shared
    @ObservedObject var storeManager = StoreKitManager.shared

    @State private var selectedTab: Int = 0
    @State private var showingVoiceCommandCheatSheet: Bool = false
    @State private var showingVoiceAuditionSheet: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var hasRequestedPermissions: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Tab 0: Words (Daily Card)
                wordsTab
                    .tabItem {
                        Label("Words", systemImage: "text.book.closed.fill")
                    }
                    .tag(0)

                // Tab 1: Practice (Quiz & Bell Curve)
                PracticeQuizView()
                    .tabItem {
                        Label("Practice", systemImage: "brain.head.profile")
                    }
                    .tag(1)

                // Tab 2: Tracks (Curricula)
                tracksTab
                    .tabItem {
                        Label("Tracks", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(2)

                // Tab 3: Drive (CarPlay & Voice Radar)
                driveTab
                    .tabItem {
                        Label("Drive Mode", systemImage: "car.fill")
                    }
                    .tag(3)
            }
            .tint(.orange)
            .navigationTitle(navTitleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingVoiceAuditionSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13))
                            Text(voiceManager.selectedVoiceName)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
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
            .sheet(isPresented: $showingVoiceAuditionSheet) {
                VoiceAuditionSheet()
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
            .onReceive(NotificationCenter.default.publisher(for: .oratorMilestoneReached)) { _ in
                // Milestone rating hook: triggers un-gated review when completing study sets or quizzes
                requestReview()
            }
            .onAppear {
                if !hasRequestedPermissions {
                    hasRequestedPermissions = true
                    voiceCommander.requestPermissionsAndStart { _ in }
                }
            }
        }
    }

    private func navTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Orator"
        case 1: return "Practice Studio"
        case 2: return "Curriculum Tracks"
        case 3: return "CarPlay Cockpit"
        default: return "Orator"
        }
    }

    // MARK: - Tab 0: Words (Daily Card)

    private var wordsTab: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if voiceManager.isQuizMode {
                        handsFreeQuizCard
                    }
                    if let currentWord = voiceManager.currentWord {
                        activeWordCard(currentWord)
                    } else {
                        startSessionPromptCard
                    }

                    // Mini Hands-Free Bar
                    miniVoiceControlBar

                    // Persistent App Store Rating Banner Card (Guideline 5.6.1)
                    appRatingBannerCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private func activeWordCard(_ word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Progress & Tier Pills
            HStack {
                Text(word.tier.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)

                Text("SET \(word.setNumber) • WORD \(voiceManager.activeIndex + 1) OF \(voiceManager.activeDeck.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(8)

                Spacer()

                Text(word.partOfSpeech.lowercased())
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(.gray)
            }

            // Word Title & Phonetic Audio Tap Pill (Screenshot 2 Archetype)
            VStack(alignment: .center, spacing: 10) {
                Text(word.word.lowercased())
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    voiceManager.speakWordTrack(wordId: word.id, kind: "hook", text: word.spokenAcousticHook) {}
                } label: {
                    HStack(spacing: 6) {
                        Text(word.phonetic)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)

            // Definition
            VStack(alignment: .leading, spacing: 4) {
                Text("(\(word.partOfSpeech.lowercased().prefix(1)).) \(word.shortDefinition)")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundColor(Color(white: 0.95))
                    .lineSpacing(4)
            }

            // In Context Box
            VStack(alignment: .leading, spacing: 6) {
                Text("IN CONTEXT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                Text("\"\(word.exampleSentence)\"")
                    .font(.system(size: 14, weight: .regular))
                    .italic()
                    .foregroundColor(Color(white: 0.85))
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            // Latin / Greek Origin
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text(word.etymology)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange.opacity(0.9))
                    .lineLimit(2)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Action Icons Row (Matching Screenshot 2)
            HStack {
                Button {
                    voiceManager.deliverFullExplanation()
                } label: {
                    actionIcon(systemName: "info.circle", label: "Explain")
                }

                Spacer()

                Button {
                    voiceManager.deliverContextualExample()
                } label: {
                    actionIcon(systemName: "quote.bubble", label: "Example")
                }

                Spacer()

                Button {
                    voiceManager.markCurrentWordMastered()
                } label: {
                    actionIcon(systemName: (word.isMastered ? "heart.fill" : "heart"), label: "Mastered", color: word.isMastered ? .red : .white)
                }

                Spacer()

                Button {
                    voiceManager.deliverEtymology()
                } label: {
                    actionIcon(systemName: "sparkles", label: "Root")
                }
            }
            .padding(.top, 2)

            // Next / Previous Navigation Controls
            HStack(spacing: 12) {
                Button {
                    voiceManager.advanceWord(by: -1)
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }

                Button {
                    voiceManager.advanceWord(by: 1)
                } label: {
                    HStack {
                        Text("Next Word")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
        }
        .padding(22)
        .background(Color(white: 0.12))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func actionIcon(systemName: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(minWidth: 48)
    }

    private var startSessionPromptCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange)

            Text("Begin Today's Commute Deck")
                .font(.system(size: 20, weight: .bold, design: .serif))
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

    private var miniVoiceControlBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(voiceCommander.isListening ? .green : .gray)

            Text(voiceCommander.recognizedTranscription.isEmpty ? "Voice radar active: say 'Next', 'Repeat', or 'Explain'" : "\"\(voiceCommander.recognizedTranscription)\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()

            Button {
                selectedTab = 3
            } label: {
                Text("Drive Cockpit")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .cornerRadius(14)
    }

    // MARK: - Tab 2: Tracks (Curricula)

    private var tracksTab: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Select a specialized collegiate curriculum to begin hands-free spoken study:")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    ForEach(VocabTier.allCases) { tier in
                        Button {
                            let words = CurriculumData.words.filter { $0.tier == tier }
                            voiceCommander.requestPermissionsAndStart { _ in
                                voiceManager.startDeck(words, startingAt: 0)
                                selectedTab = 0
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

                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                            }
                            .padding(16)
                            .background(Color(white: 0.12))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Tab 3: Drive Mode (CarPlay & Cockpit)

    private var driveTab: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    carPlayStatusCard
                    handsFreeQuizCard
                    knowledgeCheckSettingsCard
                    voiceRecognitionStatusCard
                    appRatingBannerCard
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var handsFreeQuizCard: some View {
        if voiceManager.isQuizMode, let word = voiceManager.quizExpectedWord {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.orange)
                    Text("HANDS-FREE KNOWLEDGE CHECK")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)

                    Spacer()

                    Text("Q\(voiceManager.quizQuestionIndex + 1)/\(voiceManager.quizTotalCount) • Score: \(voiceManager.quizScore)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Definition:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Text("\"\(word.shortDefinition)\"")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(voiceManager.quizStatusMessage.isEmpty ? "Say the word aloud, or say \"Tell me\"" : voiceManager.quizStatusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.yellow)

                HStack(spacing: 8) {
                    Button {
                        voiceManager.handleQuizAnswer(isUserCorrect: true, userGaveUp: false)
                    } label: {
                        Text("Simulate: \"\(word.word)\"")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }

                    Button {
                        voiceManager.handleQuizAnswer(isUserCorrect: false, userGaveUp: true)
                    } label: {
                        Text("Simulate: \"Tell Me\"")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }

                    Spacer()

                    Button {
                        voiceManager.skipHandsFreeKnowledgeCheck()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(18)
            .background(Color(red: 0.12, green: 0.10, blue: 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
            )
            .cornerRadius(16)
        }
    }

    private var knowledgeCheckSettingsCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $voiceManager.enableHandsFreeKnowledgeCheck) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hands-Free Set Knowledge Check")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Spoken 3-question recall quiz after completing every 30 words")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))

            if !voiceManager.isQuizMode {
                Button {
                    voiceManager.triggerManualKnowledgeCheck()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Start Knowledge Check Now (3 Words)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(16)
    }

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
    }

    private var voiceRecognitionStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Quick Voice Simulator:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                voiceTestPill("Next", cmd: .next)
                voiceTestPill("Repeat", cmd: .repeatWord)
                voiceTestPill("Mastered", cmd: .mastered)
                voiceTestPill("Quiz", cmd: .quiz)
                voiceTestPill("Explain", cmd: .explain)
                voiceTestPill("Root", cmd: .root)
            }
        }
        .padding(18)
        .background(Color(white: 0.11))
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
                        commandGuideRow("Quiz / Test / Knowledge Check", description: "Triggers a quick 3-question spoken recall test on recent words.")
                        commandGuideRow("Tell Me / Answer / Pass", description: "Hands-free reveal: Orator speaks the answer and example sentence if you cannot recall the word.")
                        commandGuideRow("Skip Quiz / Exit Quiz", description: "Bypasses the current knowledge check and returns immediately to normal drive mode.")
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

    // MARK: - App Store Rating & Review Banner (Guideline 5.6.1 Compliant)

    private var appRatingBannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 3) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 11))
                    }
                }
                Text("ENJOYING ORATOR?")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
            }

            Text("Your 5-star rating supports continuous automotive vocabulary expansion and offline voice features.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)
                .lineSpacing(2)

            Button(action: {
                requestReview()
            }) {
                HStack {
                    Image(systemName: "star.leadinghalf.filled")
                    Text("Rate Orator on the App Store")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.yellow)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
        )
    }
}
