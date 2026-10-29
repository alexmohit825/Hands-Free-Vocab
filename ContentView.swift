//
//  ContentView.swift
//  Orator: Executive Lexicon
//
//  Apple Design Award Editorial Lexicon Architecture:
//  - Warm Editorial Parchment (#EFECE4), Crisp Paper White (#FFFFFF), Coastal Sage-Teal (#739E9B),
//    Matcha Mint (#B5D69C), Terracotta Coral (#E0745B), and Deep Ink Charcoal (#1C2222) borders.
//  - Tab 0 ("Words"): Top progress bar & streak pill, Hero Editorial Book-Plate Word Card,
//    Atmospheric Botanical "Word of the Day" card, 2-column Bento discovery grid, and Review Banner.
//  - Tab 1 ("Practice"): PracticeQuizView (Bell curve rank, Matcha Mint recall quiz, Sprint/Rush/Perfection).
//  - Tab 2 ("Journey"): Interactive Stepping-Stone Set Map + 4 Collegiate Curriculum Tracks.
//  - Tab 3 ("Drive"): 100% Hands-Free CarPlay & Spoken Knowledge Check Cockpit + Review Banner.
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
    @State private var selectedSetInJourney: Int = 1

    // Editorial Palette Constants (Matching Benchmark Archetypes)
    private let canvasParchment = Color(red: 0.937, green: 0.925, blue: 0.894) // #EFECE4
    private let cardWhite = Color.white
    private let warmLinen = Color(red: 0.969, green: 0.961, blue: 0.941)       // #F7F5F0
    private let inkCharcoal = Color(red: 0.110, green: 0.133, blue: 0.133)     // #1C2222
    private let slateMuted = Color(red: 0.345, green: 0.400, blue: 0.400)      // #586666
    private let coastalSage = Color(red: 0.451, green: 0.620, blue: 0.608)     // #739E9B
    private let matchaMint = Color(red: 0.710, green: 0.839, blue: 0.612)      // #B5D69C
    private let coralTerracotta = Color(red: 0.878, green: 0.455, blue: 0.357) // #E0745B
    private let botanicalEmerald = Color(red: 0.133, green: 0.255, blue: 0.239)// #22413D
    private let warmGold = Color(red: 0.949, green: 0.788, blue: 0.298)        // #F2C94C

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Tab 0: Words (Daily Editorial Card & Bento Grid)
                wordsTab
                    .tabItem {
                        Label("Words", systemImage: "text.book.closed.fill")
                    }
                    .tag(0)

                // Tab 1: Practice (Bell Curve & Interactive Recall)
                PracticeQuizView()
                    .tabItem {
                        Label("Practice", systemImage: "brain.head.profile")
                    }
                    .tag(1)

                // Tab 2: Journey (Stepping-Stone Set Map & Tracks)
                tracksTab
                    .tabItem {
                        Label("Journey", systemImage: "map.fill")
                    }
                    .tag(2)

                // Tab 3: Drive (CarPlay & Voice Radar Cockpit)
                driveTab
                    .tabItem {
                        Label("Drive", systemImage: "car.fill")
                    }
                    .tag(3)
            }
            .tint(inkCharcoal)
            .navigationTitle(navTitleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(canvasParchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingVoiceAuditionSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(voiceManager.selectedVoiceName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(inkCharcoal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(cardWhite)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inkCharcoal, lineWidth: 1.3)
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if !storeManager.isUnlocked {
                            Button {
                                showingPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Pro")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(inkCharcoal)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(warmGold)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(inkCharcoal, lineWidth: 1.3)
                                )
                            }
                        }

                        Button {
                            showingVoiceCommandCheatSheet.toggle()
                        } label: {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(coastalSage)
                                .overlay(
                                    Circle()
                                        .stroke(inkCharcoal, lineWidth: 1.2)
                                )
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
                requestReview()
            }
            .onAppear {
                if !hasRequestedPermissions {
                    hasRequestedPermissions = true
                    voiceCommander.requestPermissionsAndStart { _ in }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func navTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Orator Lexicon"
        case 1: return "Practice Studio"
        case 2: return "Lexicon Journey"
        case 3: return "CarPlay Cockpit"
        default: return "Orator"
        }
    }

    // MARK: - Tab 0: Words (Daily Editorial Card & Bento Grid)

    private var wordsTab: some View {
        ZStack {
            canvasParchment.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Top Progress Capsule & Streak Pill (Matching Screenshot 2)
                    topEditorialProgressRow

                    // Hands-Free Spoken Quiz Banner if active
                    if voiceManager.isQuizMode {
                        handsFreeQuizCard
                    }

                    // Primary Editorial Word Plate
                    if let currentWord = voiceManager.currentWord {
                        activeWordCard(currentWord)
                    } else if let firstWord = CurriculumData.words.first {
                        activeWordCard(firstWord)
                    }

                    // Mini Hands-Free Voice Radar Bar
                    miniVoiceControlBar

                    // Daily Curated Bento Section (Matching Screenshot 3)
                    curatedEditorialBentoSection

                    // Persistent App Store Rating Banner Card (Guideline 5.6.1)
                    appRatingBannerCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var topEditorialProgressRow: some View {
        let total = max(1, voiceManager.activeDeck.isEmpty ? 30 : min(30, voiceManager.activeDeck.count))
        let currentPos = (voiceManager.activeIndex % 30) + 1
        let progressFraction = CGFloat(currentPos) / CGFloat(total)

        return HStack(spacing: 10) {
            // Left Set Progress Capsule
            HStack(spacing: 10) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(coastalSage)

                Text("\(currentPos)/\(total)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(inkCharcoal.opacity(0.10))
                            .frame(height: 8)

                        Capsule()
                            .fill(coastalSage)
                            .frame(width: max(12, geo.size.width * progressFraction), height: 8)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 14)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(cardWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(inkCharcoal, lineWidth: 1.5)
            )

            // Right Daily Streak Pill
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(coralTerracotta)
                Text("5d")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(inkCharcoal, lineWidth: 1.5)
            )
        }
    }

    private func activeWordCard(_ word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top Tier & Set Metadata Row
            HStack {
                Text(word.tier.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(inkCharcoal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(coastalSage.opacity(0.24))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.1)
                    )

                Text("SET \(word.setNumber)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(slateMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(warmLinen)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal.opacity(0.25), lineWidth: 1)
                    )

                Spacer()

                Text(word.partOfSpeech.lowercased())
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(slateMuted)
            }

            // Centerpiece Word & Outlined Phonetic Audio Pill (Screenshot 2 Archetype)
            VStack(alignment: .center, spacing: 12) {
                Text(word.word.lowercased())
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    } else {
                        voiceManager.speakWordTrack(wordId: word.id, kind: "hook", text: word.spokenAcousticHook) {}
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(word.phonetic)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(inkCharcoal)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(coastalSage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(warmLinen)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.3)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)

            // Crisp Editorial Definition
            Text("(\(word.partOfSpeech.lowercased().prefix(1)).) \(word.shortDefinition)")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(inkCharcoal)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Warm Linen "In Context & Root" Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("IN CONTEXT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(slateMuted)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(coastalSage)
                }

                Text("\"\(word.exampleSentence)\"")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(inkCharcoal.opacity(0.9))
                    .lineSpacing(3)

                Divider()
                    .background(inkCharcoal.opacity(0.15))
                    .padding(.vertical, 2)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(coralTerracotta)
                        .padding(.top, 2)
                    Text(word.etymology)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(slateMuted)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warmLinen)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(inkCharcoal.opacity(0.25), lineWidth: 1.2)
            )

            // Circular Outlined Action Icons Row (Matching Screenshot 2 Bottom Row)
            HStack {
                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    }
                    voiceManager.deliverFullExplanation()
                } label: {
                    editorialActionCircle(systemName: "info", label: "Explain")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    }
                    voiceManager.deliverContextualExample()
                } label: {
                    editorialActionCircle(systemName: "quote.bubble", label: "Example")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    }
                    voiceManager.markCurrentWordMastered()
                } label: {
                    editorialActionCircle(
                        systemName: word.isMastered ? "heart.fill" : "heart",
                        label: "Save",
                        fillColor: word.isMastered ? coralTerracotta.opacity(0.22) : cardWhite,
                        iconColor: word.isMastered ? coralTerracotta : inkCharcoal
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    }
                    voiceManager.deliverEtymology()
                } label: {
                    editorialActionCircle(systemName: "books.vertical", label: "Root")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)

            // Tactile Previous / Next Word Pill Controls
            HStack(spacing: 12) {
                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    } else {
                        voiceManager.advanceWord(by: -1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Previous")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(inkCharcoal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(warmLinen)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if voiceManager.currentWord == nil {
                        voiceManager.startDeck(CurriculumData.words, startingAt: 0)
                    } else {
                        voiceManager.advanceWord(by: 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(voiceManager.currentWord == nil ? "Start Audio Deck" : "Next word")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(inkCharcoal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(coastalSage)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.5)
                    )
                    .shadow(color: inkCharcoal.opacity(0.18), radius: 0, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.6)
        )
        .shadow(color: inkCharcoal.opacity(0.08), radius: 0, x: 0, y: 3)
    }

    private func editorialActionCircle(
        systemName: String,
        label: String,
        fillColor: Color = .white,
        iconColor: Color = Color(red: 0.110, green: 0.133, blue: 0.133)
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(inkCharcoal, lineWidth: 1.4)
                    )
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(slateMuted)
        }
        .frame(minWidth: 56)
    }

    private var miniVoiceControlBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(voiceCommander.isListening ? matchaMint : warmLinen)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(inkCharcoal, lineWidth: 1.3)
                    )
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(inkCharcoal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("HANDS-FREE VOICE RADAR")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(slateMuted)
                    .tracking(0.5)

                Text(voiceCommander.recognizedTranscription.isEmpty
                     ? "Say \"Next\", \"Repeat\", \"Explain\", or \"Quiz\""
                     : "\"\(voiceCommander.recognizedTranscription)\"")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(inkCharcoal)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                selectedTab = 3
            } label: {
                Text("Cockpit")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(coastalSage.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.3)
                    )
            }
        }
        .padding(14)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    // MARK: - Curated Editorial Bento Section (Matching Screenshot 3)

    private var curatedEditorialBentoSection: some View {
        let spotlightWords = Array(CurriculumData.words.dropFirst().prefix(5))
        let featuredWord = spotlightWords.first ?? CurriculumData.words[0]
        let bentoGridWords = Array(spotlightWords.dropFirst().prefix(4))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Editorial Spotlight")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
                Spacer()
                Text("Tap any card to listen")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(slateMuted)
            }

            // Atmospheric Botanical Emerald "Word of the Day" Hero Card (Matching Screenshot 3)
            Button {
                if let idx = CurriculumData.words.firstIndex(where: { $0.id == featuredWord.id }) {
                    voiceManager.startDeck(CurriculumData.words, startingAt: idx)
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [
                            botanicalEmerald,
                            Color(red: 0.09, green: 0.19, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Subtle botanical leaf watermark
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 110))
                        .foregroundColor(Color.white.opacity(0.06))
                        .rotationEffect(.degrees(-18))
                        .offset(x: 20, y: 15)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Word of the day")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(matchaMint)
                            Spacer()
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }

                        Text(featuredWord.word.lowercased())
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundColor(.white)

                        Text(featuredWord.phonetic)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(Color.white.opacity(0.8))

                        Text("(\(featuredWord.partOfSpeech.lowercased().prefix(3)).) \(featuredWord.shortDefinition)")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(Color.white.opacity(0.92))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(inkCharcoal, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            // 2-Column Editorial Bento Grid (Matching Screenshot 3)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(bentoGridWords, id: \.id) { item in
                    Button {
                        if let idx = CurriculumData.words.firstIndex(where: { $0.id == item.id }) {
                            voiceManager.startDeck(CurriculumData.words, startingAt: idx)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.word.lowercased())
                                    .font(.system(size: 19, weight: .bold, design: .serif))
                                    .foregroundColor(inkCharcoal)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(coastalSage)
                            }

                            Text(item.phonetic)
                                .font(.system(size: 11, weight: .regular, design: .serif))
                                .foregroundColor(slateMuted)
                                .lineLimit(1)

                            Text("(\(item.partOfSpeech.lowercased().prefix(3)).) \(item.shortDefinition)")
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundColor(inkCharcoal.opacity(0.88))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                        .background(cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(inkCharcoal, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tab 2: Journey (Stepping-Stone Set Map & Collegiate Tracks)

    private var tracksTab: some View {
        ZStack {
            canvasParchment.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Interactive Stepping-Stone Set Map Card (Matching Screenshot 3)
                    steppingStoneJourneyCard

                    Text("Collegiate & Executive Curricula")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(inkCharcoal)
                        .padding(.top, 4)

                    ForEach(VocabTier.allCases) { tier in
                        Button {
                            let words = CurriculumData.words.filter { $0.tier == tier }
                            voiceCommander.requestPermissionsAndStart { _ in
                                voiceManager.startDeck(words, startingAt: 0)
                                selectedTab = 0
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(coastalSage.opacity(0.25))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(inkCharcoal, lineWidth: 1.4)
                                        )
                                    Image(systemName: tier.iconName)
                                        .font(.system(size: 21, weight: .bold))
                                        .foregroundColor(inkCharcoal)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tier.rawValue)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundColor(inkCharcoal)

                                    Text(storeManager.isUnlocked
                                         ? "\(CurriculumData.wordsForTier(tier).count) words • 15 Sets (Lifetime Unlocked)"
                                         : "Set 1 Free • 15 Sets Total (30 words/set)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(storeManager.isUnlocked ? coastalSage : coralTerracotta)

                                    Text(tier.subtitle)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(slateMuted)
                                        .lineLimit(1)
                                }

                                Spacer()

                                ZStack {
                                    Circle()
                                        .fill(coastalSage)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(inkCharcoal, lineWidth: 1.4)
                                        )
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(inkCharcoal)
                                }
                            }
                            .padding(16)
                            .background(cardWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(inkCharcoal, lineWidth: 1.5)
                            )
                            .shadow(color: inkCharcoal.opacity(0.07), radius: 0, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var steppingStoneJourneyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Progression Path")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(inkCharcoal)
                    Text("Each stone unlocks 30 high-precision words + a spoken knowledge check")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(slateMuted)
                }
                Spacer()
                Text("60 SETS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(matchaMint)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.2)
                    )
            }

            // Winding Stepping-Stone Nodes (Matching Screenshot 3 Bottom Card)
            HStack(spacing: 0) {
                steppingStoneNode(setNum: 1, title: "Set 1", icon: "star.fill", fill: matchaMint, isUnlocked: true)
                steppingPathConnector
                steppingStoneNode(setNum: 2, title: "Set 2", icon: "puzzlepiece.fill", fill: coastalSage, isUnlocked: true)
                steppingPathConnector
                steppingStoneNode(setNum: 3, title: "Set 3", icon: "sparkles", fill: warmGold, isUnlocked: storeManager.isUnlocked)
                steppingPathConnector
                steppingStoneNode(setNum: 4, title: "Set 4", icon: "trophy.fill", fill: coralTerracotta.opacity(0.85), isUnlocked: storeManager.isUnlocked)
            }
            .padding(.vertical, 8)

            Button {
                let targetSetWords = CurriculumData.words.filter { $0.setNumber == selectedSetInJourney }
                let deck = targetSetWords.isEmpty ? CurriculumData.words : targetSetWords
                voiceCommander.requestPermissionsAndStart { _ in
                    voiceManager.startDeck(deck, startingAt: 0)
                    selectedTab = 0
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .font(.system(size: 14, weight: .bold))
                    Text("Launch Set \(selectedSetInJourney) Audio Session (30 Words)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(inkCharcoal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(coastalSage)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(inkCharcoal, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private var steppingPathConnector: some View {
        Rectangle()
            .fill(inkCharcoal.opacity(0.25))
            .frame(height: 2.5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    private func steppingStoneNode(setNum: Int, title: String, icon: String, fill: Color, isUnlocked: Bool) -> some View {
        let isSelected = selectedSetInJourney == setNum
        return Button {
            if isUnlocked || setNum == 1 {
                selectedSetInJourney = setNum
            } else {
                showingPaywall = true
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // 3D pedestal shadow base
                    Circle()
                        .fill(inkCharcoal)
                        .frame(width: 52, height: 52)
                        .offset(y: 3)

                    Circle()
                        .fill(isUnlocked ? fill : warmLinen)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(inkCharcoal, lineWidth: isSelected ? 2.2 : 1.5)
                        )

                    Image(systemName: isUnlocked ? icon : "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(inkCharcoal)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(inkCharcoal)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 3: Drive Mode (CarPlay & Hands-Free Cockpit)

    private var driveTab: some View {
        ZStack {
            canvasParchment.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    carPlayStatusCard
                    handsFreeQuizCard
                    knowledgeCheckSettingsCard
                    voiceRecognitionStatusCard
                    appRatingBannerCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private var handsFreeQuizCard: some View {
        if voiceManager.isQuizMode, let word = voiceManager.quizExpectedWord {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(inkCharcoal)
                    Text("HANDS-FREE KNOWLEDGE CHECK")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(inkCharcoal)
                        .tracking(0.5)

                    Spacer()

                    Text("Q\(voiceManager.quizQuestionIndex + 1)/\(voiceManager.quizTotalCount) • Score: \(voiceManager.quizScore)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(inkCharcoal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(matchaMint)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inkCharcoal, lineWidth: 1.2)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Identify the vocabulary word for:")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(slateMuted)
                    Text("\"\(word.shortDefinition)\"")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(inkCharcoal)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(warmLinen)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(inkCharcoal.opacity(0.3), lineWidth: 1.1)
                )

                Text(voiceManager.quizStatusMessage.isEmpty ? "Speak the word aloud, or say \"Tell me\"" : voiceManager.quizStatusMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(coralTerracotta)

                HStack(spacing: 8) {
                    Button {
                        voiceManager.handleQuizAnswer(isUserCorrect: true, userGaveUp: false)
                    } label: {
                        Text("Simulate: \"\(word.word)\"")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(matchaMint)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(inkCharcoal, lineWidth: 1.3)
                            )
                    }

                    Button {
                        voiceManager.handleQuizAnswer(isUserCorrect: false, userGaveUp: true)
                    } label: {
                        Text("Say \"Tell Me\"")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(warmLinen)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(inkCharcoal, lineWidth: 1.3)
                            )
                    }

                    Spacer()

                    Button {
                        voiceManager.skipHandsFreeKnowledgeCheck()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(slateMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(18)
            .background(cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(inkCharcoal, lineWidth: 1.6)
            )
        }
    }

    private var knowledgeCheckSettingsCard: some View {
        VStack(spacing: 14) {
            Toggle(isOn: $voiceManager.enableHandsFreeKnowledgeCheck) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(matchaMint)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(inkCharcoal, lineWidth: 1.3)
                            )
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(inkCharcoal)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hands-Free Set Knowledge Check")
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundColor(inkCharcoal)
                        Text("Spoken 3-question recall quiz after every 30-word set")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(slateMuted)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: coastalSage))

            if !voiceManager.isQuizMode {
                Button {
                    voiceManager.triggerManualKnowledgeCheck()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Spoken Knowledge Check Now (3 Words)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(inkCharcoal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(coastalSage)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(inkCharcoal, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private var carPlayStatusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(coastalSage.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(inkCharcoal, lineWidth: 1.4)
                    )
                Image(systemName: "car.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(inkCharcoal)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("CarPlay & Steering-Wheel Ready")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
                Text("Use CarPlay templates or physical >> / << buttons")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(slateMuted)
            }

            Spacer()

            Circle()
                .fill(matchaMint)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(inkCharcoal, lineWidth: 1.3)
                )
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private var voiceRecognitionStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(coastalSage)
                Text("ON-DEVICE VOICE RADAR")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(slateMuted)
                    .tracking(0.6)

                Spacer()

                if let cmd = voiceCommander.lastDetectedCommand {
                    Text("Last: \(cmd.rawValue)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(inkCharcoal)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(matchaMint)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inkCharcoal, lineWidth: 1.1)
                        )
                }
            }

            if voiceCommander.recognizedTranscription.isEmpty {
                Text(voiceCommander.isListening
                     ? "Listening in cabin for \"Next\", \"Repeat\", \"Mastered\", \"Quiz\"..."
                     : "Tap any simulator pill below or speak a command aloud.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(slateMuted)
            } else {
                Text("\"\(voiceCommander.recognizedTranscription)\"")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
            }

            Text("Instant Command Simulator:")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(slateMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    voiceTestPill("Next", cmd: .next)
                    voiceTestPill("Repeat", cmd: .repeatWord)
                    voiceTestPill("Mastered", cmd: .mastered)
                    voiceTestPill("Quiz", cmd: .quiz)
                    voiceTestPill("Explain", cmd: .explain)
                    voiceTestPill("Root", cmd: .root)
                }
            }
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private func voiceTestPill(_ title: String, cmd: VocabCommand) -> some View {
        Button {
            voiceManager.didRecognizeCommand(cmd)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(inkCharcoal)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(warmLinen)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(inkCharcoal, lineWidth: 1.3)
                )
        }
        .buttonStyle(.plain)
    }

    private var voiceCommandSheet: some View {
        NavigationStack {
            ZStack {
                canvasParchment.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Drive safely. Orator responds to spoken commands and steering-wheel track controls with zero screen touches required.")
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .foregroundColor(slateMuted)
                            .padding(.bottom, 4)

                        commandGuideRow("Next / Skip / Forward", description: "Advances immediately to the next vocabulary word.")
                        commandGuideRow("Repeat / Again / Say Again", description: "Re-plays the acoustic phonetic hook of the current word.")
                        commandGuideRow("Mastered / Got It / Easy", description: "Flags word as mastered, increments SRS interval, and advances.")
                        commandGuideRow("Quiz / Test / Knowledge Check", description: "Triggers a 3-question spoken recall test on recent words.")
                        commandGuideRow("Tell Me / Answer / Pass", description: "Hands-free reveal: speaks the answer and example sentence.")
                        commandGuideRow("Skip Quiz / Exit Quiz", description: "Exits the knowledge check and resumes normal word flow.")
                        commandGuideRow("Explain / Detail / Elaborate", description: "Spoken narration of the full comprehensive definition.")
                        commandGuideRow("Example / Sentence / Context", description: "Speaks the real-world usage and contextual sentence.")
                        commandGuideRow("Root / Origin / Etymology", description: "Narrates Latin/Greek roots and morphological word family.")
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Spoken Commands")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.light)
    }

    private func commandGuideRow(_ phrase: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("🎙️ \"\(phrase)\"")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(inkCharcoal)
            Text(description)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(slateMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.4)
        )
    }

    // MARK: - App Store Rating & Review Banner (Guideline 5.6.1 Compliant)

    private var appRatingBannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(warmGold)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                Text("ENJOYING ORATOR?")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(inkCharcoal)
                    .tracking(0.5)
                Spacer()
            }

            Text("Your 5-star review helps fellow drivers and lifelong learners discover hands-free collegiate vocabulary.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundColor(slateMuted)
                .lineSpacing(2)

            Button {
                requestReview()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Rate Orator on the App Store")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(inkCharcoal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(warmGold)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(inkCharcoal, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }
}
