//
//  PracticeQuizView.swift
//  Orator: Executive Lexicon
//
//  Interactive Practice & Mastery Studio (Inspired by Premier App Store Vocab Archetype):
//  - Executive Mastery Score with peer percentile bell curve.
//  - Multi-choice contextual definition recall challenges (Sprint, Rush, Perfection).
//  - Instant audio pronunciation and sentence feedback.
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
    @State private var streakCount: Int = 4
    @State private var correctAnswersCount: Int = 18
    @State private var totalQuestionsCount: Int = 22
    @State private var activeChallengeMode: ChallengeMode = .sprint
    @State private var previewSynth = AVSpeechSynthesizer()

    public enum ChallengeMode: String, CaseIterable, Identifiable {
        case sprint = "Sprint"
        case rush = "Rush"
        case perfection = "Perfection"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .sprint: return "stopwatch.fill"
            case .rush: return "bolt.fill"
            case .perfection: return "star.fill"
            }
        }

        public var subtitle: String {
            switch self {
            case .sprint: return "60-sec rapid recall"
            case .rush: return "Speed definition match"
            case .perfection: return "Zero-error streak"
            }
        }
    }

    public init() {}

    private var masteryPercentile: Int {
        let base = totalQuestionsCount > 0 ? Int((Double(correctAnswersCount) / Double(totalQuestionsCount)) * 100) : 75
        return min(98, max(45, base + 12))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Executive Rank Bell Curve Card
                        executiveRankCard

                        // 2. Challenges Row (Sprint / Rush / Perfection)
                        challengesRow

                        // 3. Interactive Practice Quiz Card
                        if let target = currentWord {
                            quizCard(for: target)
                        } else {
                            loadingCard
                        }

                        // 4. Session Quick Stats Pill Bar
                        quickStatsBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Practice & Rank")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if currentWord == nil {
                    loadNewQuestion()
                }
            }
        }
    }

    // MARK: - 1. Executive Rank Bell Curve Card

    private var executiveRankCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXECUTIVE VOCABULARY RANK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(0.5)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(masteryPercentile)")
                            .font(.system(size: 34, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                        Text("score")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Text("You outrank \(masteryPercentile)% of learners")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.55, green: 0.85, blue: 0.75))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 58, height: 58)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(masteryPercentile) / 100.0)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(-90))
                    Text("\(masteryPercentile)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Bell curve distribution graphic
            BellCurveShape()
                .stroke(Color.orange.opacity(0.6), lineWidth: 2)
                .background(
                    BellCurveShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .frame(height: 52)
                .overlay(
                    // User indicator flag
                    HStack {
                        Spacer()
                            .frame(width: max(20, CGFloat(masteryPercentile) / 100.0 * 260))
                        VStack(spacing: 2) {
                            Text("You")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .cornerRadius(4)
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 6, height: 6)
                        }
                        Spacer()
                    }
                    .offset(y: -10)
                )

            HStack {
                Text("0")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("Average (50)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("100")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(18)
        .background(Color(white: 0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 2. Challenges Row

    private var challengesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHALLENGES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.5)

            HStack(spacing: 12) {
                ForEach(ChallengeMode.allCases) { mode in
                    Button {
                        activeChallengeMode = mode
                        loadNewQuestion()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                                .foregroundColor(activeChallengeMode == mode ? .orange : .white.opacity(0.7))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)

                            Text(mode.subtitle)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                        .background(activeChallengeMode == mode ? Color.orange.opacity(0.18) : Color(white: 0.11))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activeChallengeMode == mode ? Color.orange.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3. Interactive Practice Quiz Card

    private func quizCard(for word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(word.partOfSpeech.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                Button {
                    speakWord(word.word)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                        Text("Pronounce")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                }
            }

            // The Definition Prompt
            VStack(alignment: .leading, spacing: 6) {
                Text("Which word matches this meaning?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                Text("\"\(word.shortDefinition)\"")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }

            // Options List
            VStack(spacing: 10) {
                ForEach(answerOptions) { option in
                    optionButton(option: option, targetWord: word)
                }
            }

            // Feedback & Contextual Sentence
            if hasSubmitted {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isCorrect ? .green : .red)
                        Text(isCorrect ? "That's correct!" : "Correct word: \(word.word)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isCorrect ? .green : .red)
                    }

                    Text("Used in context:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)

                    Text("\"\(word.exampleSentence)\"")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundColor(Color(white: 0.85))

                    Button {
                        loadNewQuestion()
                    } label: {
                        HStack {
                            Text("Next Word")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    .padding(.top, 6)
                }
                .padding(14)
                .background(Color(white: 0.16))
                .cornerRadius(14)
            }
        }
        .padding(18)
        .background(Color(white: 0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func optionButton(option: VocabWord, targetWord: VocabWord) -> some View {
        let isSelected = selectedWordId == option.id
        let isTarget = option.id == targetWord.id

        var bgColor = Color(white: 0.16)
        var borderColor = Color.white.opacity(0.08)
        var textColor = Color.white

        if hasSubmitted {
            if isTarget {
                bgColor = Color.green.opacity(0.2)
                borderColor = Color.green
                textColor = .green
            } else if isSelected && !isTarget {
                bgColor = Color.red.opacity(0.2)
                borderColor = Color.red
                textColor = .red
            }
        } else if isSelected {
            bgColor = Color.orange.opacity(0.2)
            borderColor = Color.orange
        }

        return Button {
            guard !hasSubmitted else { return }
            selectedWordId = option.id
            hasSubmitted = true
            isCorrect = (option.id == targetWord.id)
            totalQuestionsCount += 1
            if isCorrect {
                correctAnswersCount += 1
                streakCount += 1
            } else {
                streakCount = 0
            }
            speakWord(targetWord.word)
        } label: {
            HStack {
                Text(option.word)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(textColor)

                Spacer()

                if hasSubmitted && isTarget {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .bold))
                } else if hasSubmitted && isSelected && !isTarget {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(bgColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.orange)
            Text("Preparing lexical challenge...")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(white: 0.12))
        .cornerRadius(18)
    }

    // MARK: - 4. Quick Stats Bar

    private var quickStatsBar: some View {
        HStack(spacing: 12) {
            statPill(icon: "book.closed.fill", value: "\(totalQuestionsCount)", label: "Tested")
            statPill(icon: "checkmark.seal.fill", value: "\(correctAnswersCount)", label: "Mastered")
            statPill(icon: "flame.fill", value: "\(streakCount)", label: "Streak", color: .orange)
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color = .white) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color == .white ? .orange : color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(white: 0.11))
        .cornerRadius(12)
    }

    // MARK: - Logic

    private func loadNewQuestion() {
        guard !allWords.isEmpty else { return }
        let target = allWords.randomElement() ?? allWords[0]
        currentWord = target

        // Pick 2 random distractors
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

// MARK: - Bell Curve Distribution Shape

private struct BellCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))

        let pointsCount = 40
        for i in 0...pointsCount {
            let x = CGFloat(i) / CGFloat(pointsCount) * width
            // Standard normal distribution bell curve centered at x = 0.5 * width
            let normalizedX = (Double(i) / Double(pointsCount) - 0.5) * 5.0
            let yNorm = exp(-0.5 * normalizedX * normalizedX)
            let y = height - (CGFloat(yNorm) * height * 0.92)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
