//
//  PracticeQuizView.swift
//  Orator: Executive Lexicon
//
//  Apple Design Award Editorial Practice & Mastery Studio:
//  - Warm Editorial Parchment (#EFECE4) & Coastal Sage-Teal (#739E9B) palette.
//  - Executive Rank Bell Curve Card with floating "You" marker & "Take the free test" tactile pill.
//  - Tactile Neo-Editorial Challenge Cards (Sprint, Rush, Perfection) + Game Shuffle banner.
//  - Matcha-Green (#B5D69C) interactive definition match pills with instant audio & context drawer.
//

import SwiftUI
import AVFoundation

public struct PracticeQuizView: View {
    @ObservedObject var voiceManager = VoiceManager.shared
    @State private var allWords: [VocabWord] = CurriculumData.words
    @State private var currentWord: VocabWord?
    @State private var answerOptions: [VocabWord] = []
    @State private var selectedWordId: String? = nil
    @State private var hasSubmitted: Bool = false
    @State private var isCorrect: Bool = false

    // Challenge & Mastery Stats
    @State private var streakCount: Int = 5
    @State private var correctAnswersCount: Int = 36
    @State private var totalQuestionsCount: Int = 42
    @State private var wordsReadCount: Int = 255
    @State private var activeChallengeMode: ChallengeMode = .sprint
    @State private var isRapidTestActive: Bool = false
    @State private var rapidTestProgress: Int = 0
    @State private var previewSynth = AVSpeechSynthesizer()

    // Editorial Palette Constants
    private let canvasParchment = Color(red: 0.937, green: 0.925, blue: 0.894) // #EFECE4
    private let cardWhite = Color.white
    private let inkCharcoal = Color(red: 0.110, green: 0.133, blue: 0.133)     // #1C2222
    private let slateMuted = Color(red: 0.345, green: 0.400, blue: 0.400)      // #586666
    private let coastalSage = Color(red: 0.451, green: 0.620, blue: 0.608)     // #739E9B
    private let coastalSageLight = Color(red: 0.545, green: 0.690, blue: 0.682)
    private let matchaMint = Color(red: 0.710, green: 0.839, blue: 0.612)      // #B5D69C
    private let coralTerracotta = Color(red: 0.878, green: 0.455, blue: 0.357) // #E0745B

    public enum ChallengeMode: String, CaseIterable, Identifiable {
        case sprint = "Sprint"
        case rush = "Rush"
        case perfection = "Perfection"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .sprint: return "stopwatch.fill"
            case .rush: return "bolt.horizontal.fill"
            case .perfection: return "heart.fill"
            }
        }

        public var accentColor: Color {
            switch self {
            case .sprint: return Color(red: 0.68, green: 0.84, blue: 0.58)
            case .rush: return Color(red: 0.92, green: 0.62, blue: 0.50)
            case .perfection: return Color(red: 0.90, green: 0.56, blue: 0.52)
            }
        }
    }

    public init() {}

    private var masteryScore: Int {
        let base = totalQuestionsCount > 0 ? Int((Double(correctAnswersCount) / Double(totalQuestionsCount)) * 88) : 76
        return min(98, max(62, base))
    }

    private var outrankPercentile: Int {
        min(99, max(72, masteryScore + 12))
    }

    public var body: some View {
        ZStack {
            canvasParchment.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Editorial Title Header
                    HStack(alignment: .firstTextBaseline) {
                        Text("Practice")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundColor(inkCharcoal)

                        Spacer()

                        if isRapidTestActive {
                            HStack(spacing: 6) {
                                Text("Test \(rapidTestProgress)/5")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(inkCharcoal)
                                Button {
                                    isRapidTestActive = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(slateMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(cardWhite)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(inkCharcoal, lineWidth: 1.2))
                        }
                    }
                    .padding(.top, 4)

                    // 1. Executive Rank Bell Curve Card (Benchmark Screenshot 1)
                    executiveRankCard

                    // 2. Interactive Definition Recall Quiz Card (Benchmark Screenshot 2)
                    if let target = currentWord {
                        quizCard(for: target)
                    } else {
                        loadingCard
                    }

                    // 3. Challenges Row (Sprint / Rush / Perfection + Game Shuffle)
                    challengesSection

                    // 4. Bottom Read & Favorited Counter Cards
                    bottomCountersRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            if currentWord == nil {
                loadNewQuestion()
            }
        }
    }

    // MARK: - 1. Executive Rank Bell Curve Card

    private var executiveRankCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(masteryScore)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(inkCharcoal)
                    Text("score")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(slateMuted)
                }

                Text("You outrank \(outrankPercentile)% of learners")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(inkCharcoal)
            }

            // Coastal Sage Bell Curve with "You" Pin
            ZStack(alignment: .bottom) {
                // Soft fill under curve
                BellCurveShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                coastalSageLight.opacity(0.55),
                                coastalSageLight.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 82)

                // Crisp curve stroke
                BellCurveLineShape()
                    .stroke(coastalSage, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(height: 82)

                // Center dashed average line
                Rectangle()
                    .fill(coastalSage.opacity(0.35))
                    .frame(width: 1, height: 68)

                // User "You" Pin on the right upper slope
                GeometryReader { geo in
                    let pinX = geo.size.width * 0.72
                    let pinY = geo.size.height * 0.28

                    ZStack {
                        // Vertical stem line
                        Path { p in
                            p.move(to: CGPoint(x: pinX, y: pinY + 6))
                            p.addLine(to: CGPoint(x: pinX, y: geo.size.height))
                        }
                        .stroke(coastalSage, lineWidth: 1.5)

                        // "You" label + circle node
                        VStack(spacing: 2) {
                            Text("You")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(inkCharcoal)
                            Circle()
                                .fill(cardWhite)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(coastalSage, lineWidth: 2.5))
                        }
                        .position(x: pinX, y: pinY)
                    }
                }
                .frame(height: 82)
            }
            .padding(.top, 4)

            // Axis labels (0 --- Average --- 100)
            HStack {
                Text("0")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(slateMuted)
                Spacer()
                Text("Average")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(slateMuted)
                Spacer()
                Text("100")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(slateMuted)
            }

            // Centered Tactile Pill Button: "Take the free test"
            HStack {
                Spacer()
                Button {
                    isRapidTestActive = true
                    rapidTestProgress = 1
                    loadNewQuestion()
                } label: {
                    Text(isRapidTestActive ? "Restart 5-Word Test" : "Take the free test")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(inkCharcoal)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(coastalSageLight)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inkCharcoal, lineWidth: 1.5)
                        )
                        .shadow(color: inkCharcoal.opacity(0.85), radius: 0, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(cardWhite)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    // MARK: - 2. Interactive Definition Match Card

    private func quizCard(for word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Progress Bar & Audio Button
            HStack(spacing: 12) {
                // Segmented progress bar matching Screenshot 2
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(canvasParchment)
                            .frame(height: 8)
                            .overlay(Capsule().stroke(inkCharcoal, lineWidth: 1))

                        Capsule()
                            .fill(coastalSage)
                            .frame(width: max(24, geo.size.width * CGFloat(isRapidTestActive ? Double(rapidTestProgress) / 5.0 : 0.45)), height: 8)
                    }
                }
                .frame(height: 8)

                Button {
                    speakWord(word.word)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                        Text("Listen")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(inkCharcoal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(canvasParchment)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(inkCharcoal, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Elevated Definition Prompt Box
            VStack(spacing: 8) {
                Text(word.partOfSpeech.lowercased())
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(slateMuted)

                Text(word.shortDefinition)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(inkCharcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 14)
            .background(canvasParchment.opacity(0.55))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(inkCharcoal.opacity(0.15), lineWidth: 1)
            )

            // 3 Tactile Pill Choices
            VStack(spacing: 10) {
                ForEach(answerOptions) { option in
                    optionPillButton(option: option, targetWord: word)
                }
            }

            // Feedback & Contextual Sentence Drawer (Matching Screenshot 2 bottom sheet)
            if hasSubmitted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isCorrect ? Color(red: 0.35, green: 0.62, blue: 0.25) : coralTerracotta)

                        Text(isCorrect ? "That's correct!" : "Correct word: \(word.word.lowercased())")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
                    }

                    HStack(spacing: 6) {
                        Text(word.word.lowercased())
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(inkCharcoal)
                        Text(word.phonetic)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(slateMuted)
                        Button {
                            speakWord(word.word)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(coastalSage)
                        }
                    }

                    Text("Used in a sentence: \(word.exampleSentence)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(inkCharcoal.opacity(0.88))
                        .lineSpacing(2)

                    Button {
                        if isRapidTestActive {
                            if rapidTestProgress < 5 {
                                rapidTestProgress += 1
                            } else {
                                isRapidTestActive = false
                            }
                        }
                        loadNewQuestion()
                    } label: {
                        Text("Next word")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(coastalSageLight)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(inkCharcoal, lineWidth: 1.5)
                            )
                            .shadow(color: inkCharcoal.opacity(0.85), radius: 0, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(16)
                .background(canvasParchment.opacity(0.6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(inkCharcoal.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(cardWhite)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(inkCharcoal, lineWidth: 1.5)
        )
    }

    private func optionPillButton(option: VocabWord, targetWord: VocabWord) -> some View {
        let isSelected = selectedWordId == option.id
        let isTarget = option.id == targetWord.id

        var bgColor = cardWhite
        var strokeWidth: CGFloat = 1.5

        if hasSubmitted {
            if isTarget {
                bgColor = matchaMint
                strokeWidth = 2.0
            } else if isSelected && !isTarget {
                bgColor = coralTerracotta.opacity(0.28)
            }
        }

        return Button {
            guard !hasSubmitted else { return }
            selectedWordId = option.id
            hasSubmitted = true
            isCorrect = (option.id == targetWord.id)
            totalQuestionsCount += 1
            wordsReadCount += 1
            if isCorrect {
                correctAnswersCount += 1
                streakCount += 1
            } else {
                streakCount = 0
            }
            speakWord(targetWord.word)
        } label: {
            ZStack {
                HStack {
                    if hasSubmitted && isTarget {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(inkCharcoal)
                    } else if hasSubmitted && isSelected && !isTarget {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(inkCharcoal)
                    }
                    Spacer()
                }
                .padding(.leading, 18)

                Text(option.word.lowercased())
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(inkCharcoal, lineWidth: strokeWidth)
            )
            .shadow(color: inkCharcoal.opacity(0.75), radius: 0, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(coastalSage)
            Text("Preparing lexical challenge...")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(slateMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(cardWhite)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(inkCharcoal, lineWidth: 1.5))
    }

    // MARK: - 3. Challenges Section (Sprint, Rush, Perfection + Game Shuffle)

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenges")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(inkCharcoal)

            HStack(spacing: 12) {
                ForEach(ChallengeMode.allCases) { mode in
                    Button {
                        activeChallengeMode = mode
                        loadNewQuestion()
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            // Stylized stacked-pill emblem matching Screenshot 1
                            ZStack {
                                Capsule()
                                    .fill(mode.accentColor.opacity(0.45))
                                    .frame(width: 38, height: 12)
                                    .rotationEffect(.degrees(-28))
                                    .offset(x: 4, y: 6)
                                    .overlay(
                                        Capsule()
                                            .stroke(inkCharcoal, lineWidth: 1.2)
                                            .rotationEffect(.degrees(-28))
                                            .offset(x: 4, y: 6)
                                    )

                                Capsule()
                                    .fill(mode.accentColor)
                                    .frame(width: 38, height: 12)
                                    .rotationEffect(.degrees(-28))
                                    .offset(x: -2, y: -2)
                                    .overlay(
                                        Capsule()
                                            .stroke(inkCharcoal, lineWidth: 1.2)
                                            .rotationEffect(.degrees(-28))
                                            .offset(x: -2, y: -2)
                                    )

                                Image(systemName: mode.icon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(inkCharcoal)
                                    .offset(x: -8, y: -10)
                            }
                            .frame(height: 36)
                            .frame(maxWidth: .infinity, alignment: .center)

                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(inkCharcoal)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(activeChallengeMode == mode ? mode.accentColor.opacity(0.22) : cardWhite)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(inkCharcoal, lineWidth: activeChallengeMode == mode ? 2.0 : 1.5)
                        )
                        .shadow(color: inkCharcoal.opacity(0.75), radius: 0, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Full-width "Game shuffle" card (Matching Screenshot 1)
            Button {
                activeChallengeMode = ChallengeMode.allCases.randomElement() ?? .sprint
                loadNewQuestion()
                voiceManager.triggerManualKnowledgeCheck()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game shuffle")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
                        Text("A mix of all games & spoken recall")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(slateMuted)
                    }

                    Spacer()

                    ZStack {
                        Capsule()
                            .fill(matchaMint)
                            .frame(width: 36, height: 12)
                            .rotationEffect(.degrees(25))
                            .overlay(Capsule().stroke(inkCharcoal, lineWidth: 1.2).rotationEffect(.degrees(25)))
                        Capsule()
                            .fill(coastalSageLight)
                            .frame(width: 36, height: 12)
                            .rotationEffect(.degrees(-35))
                            .overlay(Capsule().stroke(inkCharcoal, lineWidth: 1.2).rotationEffect(.degrees(-35)))
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(inkCharcoal)
                    }
                    .frame(width: 48, height: 40)
                }
                .padding(16)
                .background(cardWhite)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(inkCharcoal, lineWidth: 1.5)
                )
                .shadow(color: inkCharcoal.opacity(0.75), radius: 0, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. Bottom Counters Row (Read & Favorited)

    private var bottomCountersRow: some View {
        HStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(wordsReadCount)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(inkCharcoal)
                    Text("Read")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(slateMuted)
                }
                Spacer()
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 22))
                    .foregroundColor(coastalSage)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(cardWhite)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(inkCharcoal, lineWidth: 1.5))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(correctAnswersCount)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(inkCharcoal)
                    Text("Favorited")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(slateMuted)
                }
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(coastalSage)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(cardWhite)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(inkCharcoal, lineWidth: 1.5))
        }
    }

    // MARK: - Logic

    private func loadNewQuestion() {
        guard !allWords.isEmpty else { return }
        let target = allWords.randomElement() ?? allWords[0]
        currentWord = target

        var distractors = allWords.filter { $0.id != target.id }.shuffled()
        let d1 = distractors.popLast() ?? target
        let d2 = distractors.popLast() ?? target

        var options = [target, d1, d2]
        options.shuffle()

        answerOptions = options
        selectedWordId = nil
        hasSubmitted = false
        isCorrect = false
    }

    private func speakWord(_ text: String) {
        previewSynth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AudioCache.pickBestVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.02
        previewSynth.speak(utterance)
    }
}

// MARK: - Bell Curve Shapes

private struct BellCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))

        let pointsCount = 60
        for i in 0...pointsCount {
            let x = CGFloat(i) / CGFloat(pointsCount) * width
            let normalizedX = (Double(i) / Double(pointsCount) - 0.5) * 5.2
            let yNorm = exp(-0.5 * normalizedX * normalizedX)
            let y = height - (CGFloat(yNorm) * height * 0.88)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

private struct BellCurveLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let pointsCount = 60
        for i in 0...pointsCount {
            let x = CGFloat(i) / CGFloat(pointsCount) * width
            let normalizedX = (Double(i) / Double(pointsCount) - 0.5) * 5.2
            let yNorm = exp(-0.5 * normalizedX * normalizedX)
            let y = height - (CGFloat(yNorm) * height * 0.88)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
