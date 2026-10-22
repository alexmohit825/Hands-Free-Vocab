//
//  VoiceManager.swift
//  Orator: Executive Lexicon
//
//  Automotive Audio Director & Spaced Repetition Playback Orchestrator.
//  Hybrid Neural Architecture: Bundled Studio Audio -> Cached Neural Audio -> Cloudflare Edge Streaming -> Synthesizer Fallback.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

public final class VoiceManager: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate, ObservableObject, VoiceCommandDelegate {
    public static let shared = VoiceManager()

    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var didSetAudioCategory: Bool = false

    @Published public var currentWord: VocabWord?
    @Published public var isPlaying: Bool = false
    @Published public var playbackModeDescription: String = "Idle"
    @Published public var activeDeck: [VocabWord] = []
    @Published public var activeIndex: Int = 0
    @Published public var shouldShowPaywall: Bool = false

    @Published public var selectedVoiceIdentifier: String = ""
    @Published public var selectedVoiceName: String = "Natural Orator"

    public var selectedVoicePersona: String {
        get { selectedVoiceIdentifier }
        set { selectedVoiceIdentifier = newValue }
    }

    // Timing gaps calibrated for driver cognitive retrieval
    public var recallWindowSeconds: Double = 3.5
    private var recallTimer: Timer?

    // MARK: - Hands-Free Knowledge Check State
    @Published public var isQuizMode: Bool = false
    @Published public var quizExpectedWord: VocabWord?
    @Published public var quizQuestionIndex: Int = 0
    @Published public var quizTotalCount: Int = 3
    @Published public var quizScore: Int = 0
    @Published public var quizStatusMessage: String = ""
    @Published public var enableHandsFreeKnowledgeCheck: Bool = {
        if UserDefaults.standard.object(forKey: "enable_hands_free_quiz") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enable_hands_free_quiz")
    }() {
        didSet {
            UserDefaults.standard.set(enableHandsFreeKnowledgeCheck, forKey: "enable_hands_free_quiz")
        }
    }

    private var quizQuestions: [VocabWord] = []
    private var pendingPostQuizAction: (() -> Void)?
    private var quizTimer: Timer?
    private var isEvaluatingAnswer: Bool = false

    @Published public var isCarPlayConnected: Bool = false
    private var didWireRemoteCommands: Bool = false

    private override init() {
        super.init()
        let best = AudioCache.pickBestVoice()
        if let savedID = UserDefaults.standard.string(forKey: "orator_selected_voice_id"),
           let savedVoice = AVSpeechSynthesisVoice(identifier: savedID) {
            self.selectedVoiceIdentifier = savedVoice.identifier
            self.selectedVoiceName = savedVoice.name
        } else {
            self.selectedVoiceIdentifier = best.identifier
            self.selectedVoiceName = best.name
        }
        self.activeDeck = CurriculumData.words
        VoiceCommander.shared.delegate = self
        wireRemoteCommandCenter()
        observeInterruptions()
        observeAppLifecycle()
    }

    public func selectVoice(identifier: String) {
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            self.selectedVoiceIdentifier = voice.identifier
            self.selectedVoiceName = voice.name
            UserDefaults.standard.set(voice.identifier, forKey: "orator_selected_voice_id")
        }
    }

    private var directSynthesizer: AVSpeechSynthesizer?
    private var isUsingDirectSpeech: Bool = false

    // MARK: - Audio Session Priority & Remote Controls

    public func configureAudioSessionIfNeeded(forcePlaybackCategory: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        do {
            // Using .playback with .allowBluetoothA2DP / .allowAirPlay guarantees crystal clear
            // CarPlay and vehicle audio delivery matching Apple Music and Podcasts (Zero mic route collision).
            try session.setCategory(.playback,
                                    mode: .spokenAudio,
                                    options: [.allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true, options: [])
            print("[VoiceManager] Audio session active with .playback / .spokenAudio")
        } catch {
            print("[VoiceManager] Audio session setCategory error: \(error)")
        }
    }

    private func wireRemoteCommandCenter() {
        guard !didWireRemoteCommands else { return }
        didWireRemoteCommands = true

        UIApplication.shared.beginReceivingRemoteControlEvents()

        let rcc = MPRemoteCommandCenter.shared()
        rcc.playCommand.isEnabled = true
        rcc.pauseCommand.isEnabled = true
        rcc.nextTrackCommand.isEnabled = true
        rcc.previousTrackCommand.isEnabled = true

        rcc.playCommand.addTarget { [weak self] _ in
            self?.resumeStudySession()
            return .success
        }
        rcc.pauseCommand.addTarget { [weak self] _ in
            self?.pauseStudySession()
            return .success
        }
        rcc.nextTrackCommand.addTarget { [weak self] _ in
            self?.advanceWord(by: 1)
            return .success
        }
        rcc.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isQuizMode {
                if let word = self.quizExpectedWord {
                    self.speakText("What word means: \(word.shortDefinition)?") {}
                }
            } else if self.activeIndex > 0 {
                self.advanceWord(by: -1)
            } else if let word = self.currentWord {
                self.presentWord(word)
            }
            return .success
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let userInfo = note.userInfo,
                  let typeVal = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }

            if type == .began {
                self?.player?.pause()
                self?.isPlaying = false
                self?.republishNowPlayingRate()
            } else if type == .ended {
                try? AVAudioSession.sharedInstance().setActive(true, options: [])
                self?.player?.play()
                self?.isPlaying = (self?.player?.isPlaying == true)
                self?.republishNowPlayingRate()
            }
        }
    }

    private func observeAppLifecycle() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.player?.isPlaying != true && self?.directSynthesizer?.isSpeaking != true {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                self?.didSetAudioCategory = false
            }
        }
    }

    // MARK: - Study Session Engine

    public func startDeck(_ deck: [VocabWord], startingAt index: Int = 0) {
        guard !deck.isEmpty else { return }
        self.activeDeck = deck
        self.activeIndex = max(0, min(index, deck.count - 1))
        self.presentWord(self.activeDeck[self.activeIndex])
    }

    public func presentWord(_ word: VocabWord) {
        self.currentWord = word
        self.playbackModeDescription = "Presenting Word"
        updateNowPlaying(with: word, status: "Acoustic Hook")

        speakWordTrack(wordId: word.id, kind: "hook", text: word.spokenAcousticHook) { [weak self] in
            guard let self = self else { return }
            self.playbackModeDescription = "Listening for voice ('Next', 'Repeat', 'Mastered')..."

            self.recallTimer?.invalidate()
            self.recallTimer = Timer.scheduledTimer(withTimeInterval: self.recallWindowSeconds, repeats: false) { [weak self] _ in
                self?.deliverContextualExample()
            }
        }

        // Background Pre-fetch next word for 0ms transition
        let nextIdx = activeIndex + 1
        if nextIdx < activeDeck.count {
            AudioCache.shared.prefetchWord(activeDeck[nextIdx], voicePersona: selectedVoiceIdentifier)
        }
    }

    public func deliverContextualExample() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Contextual Sentence"
        updateNowPlaying(with: word, status: "Contextual Usage")

        speakWordTrack(wordId: word.id, kind: "example", text: word.spokenExampleScript) { [weak self] in
            guard let self = self else { return }
            self.playbackModeDescription = "Awaiting Command ('Next' to proceed)"

            // Auto-advance after 5 seconds if driver stays silent
            self.recallTimer?.invalidate()
            self.recallTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.advanceWord(by: 1)
            }
        }
    }

    public func deliverEtymology() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Etymology & Roots"
        updateNowPlaying(with: word, status: "Root Analysis")

        speakWordTrack(wordId: word.id, kind: "etymology", text: word.spokenEtymologyScript) { [weak self] in
            self?.playbackModeDescription = "Awaiting Command ('Next' to proceed)"
        }
    }

    public func deliverFullExplanation() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Detailed Elaboration"
        updateNowPlaying(with: word, status: "Deep Definition")

        speakWordTrack(wordId: word.id, kind: "deep", text: word.spokenDetailedScript) { [weak self] in
            self?.playbackModeDescription = "Awaiting Command ('Next' to proceed)"
        }
    }

    // MARK: - VoiceCommandDelegate

    public func didRecognizeCommand(_ command: VocabCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[VoiceManager] 🎯 Executing Voice Command: \(command.rawValue)")

            switch command {
            case .next:
                if self.isQuizMode {
                    self.skipHandsFreeKnowledgeCheck()
                } else {
                    self.advanceWord(by: 1)
                }
            case .repeatWord:
                if self.isQuizMode {
                    if let word = self.quizExpectedWord {
                        let prompt = "What word means: \(word.shortDefinition)?"
                        self.speakText(prompt) {}
                    }
                } else if let word = self.currentWord {
                    self.presentWord(word)
                }
            case .mastered:
                self.markCurrentWordMastered()
                self.advanceWord(by: 1)
            case .explain:
                self.deliverFullExplanation()
            case .example:
                self.deliverContextualExample()
            case .root:
                self.deliverEtymology()
            case .pause:
                self.pauseStudySession()
            case .resume:
                self.resumeStudySession()
            case .quiz:
                self.triggerManualKnowledgeCheck()
            }
        }
    }

    public func advanceWord(by offset: Int) {
        recallTimer?.invalidate()
        quizTimer?.invalidate()
        player?.stop()
        directSynthesizer?.stopSpeaking(at: .immediate)

        guard !activeDeck.isEmpty else { return }
        let nextIndex = activeIndex + offset
        if nextIndex >= 0 && nextIndex < activeDeck.count {
            let previousSet = activeDeck[activeIndex].setNumber
            let nextSet = activeDeck[nextIndex].setNumber

            if previousSet != nextSet {
                activeIndex = nextIndex
                triggerSetCompletionKnowledgeCheck(completedSet: previousSet, nextSet: nextSet, isFullDeckProgression: false)
            } else {
                activeIndex = nextIndex
                presentWord(activeDeck[activeIndex])
            }
        } else if nextIndex >= activeDeck.count {
            let currentSet = activeDeck[activeIndex].setNumber
            let totalSets = CurriculumData.totalSetsCount
            let nextSet = (currentSet >= totalSets) ? 1 : currentSet + 1

            triggerSetCompletionKnowledgeCheck(completedSet: currentSet, nextSet: nextSet, isFullDeckProgression: true)
        }
    }

    // MARK: - Hands-Free Knowledge Check (Automotive Spoken Recall Engine)

    public func triggerSetCompletionKnowledgeCheck(completedSet: Int, nextSet: Int, isFullDeckProgression: Bool = false) {
        guard enableHandsFreeKnowledgeCheck else {
            announceSetTransition(completedSet: completedSet, nextSet: nextSet, isFullDeckProgression: isFullDeckProgression)
            return
        }

        let wordsInSet = CurriculumData.wordsForSet(completedSet)
        let candidates = wordsInSet.isEmpty ? Array(activeDeck.prefix(3)) : wordsInSet
        let selected = Array(candidates.shuffled().prefix(3))

        let intro = "Set \(completedSet) complete! Time for a quick hands-free knowledge check. I will read \(selected.count) definitions. Say the word aloud, or say 'Tell me' if you need the answer."

        startHandsFreeKnowledgeCheck(questions: selected, introAnnouncement: intro) { [weak self] in
            self?.announceSetTransition(completedSet: completedSet, nextSet: nextSet, isFullDeckProgression: isFullDeckProgression)
        }
    }

    public func triggerManualKnowledgeCheck() {
        let candidates = activeDeck.isEmpty ? CurriculumData.wordsForSet(1) : activeDeck
        let selected = Array(candidates.shuffled().prefix(3))
        let intro = "Starting a quick hands-free knowledge check. I will read \(selected.count) definitions. Say the word aloud, or say 'Tell me' if you need the answer."

        startHandsFreeKnowledgeCheck(questions: selected, introAnnouncement: intro) { [weak self] in
            guard let self = self else { return }
            if let word = self.currentWord {
                self.presentWord(word)
            }
        }
    }

    public func startHandsFreeKnowledgeCheck(questions: [VocabWord], introAnnouncement: String, onComplete: @escaping () -> Void) {
        guard !questions.isEmpty else {
            onComplete()
            return
        }

        recallTimer?.invalidate()
        quizTimer?.invalidate()
        player?.stop()
        directSynthesizer?.stopSpeaking(at: .immediate)

        self.quizQuestions = questions
        self.quizTotalCount = questions.count
        self.quizQuestionIndex = 0
        self.quizScore = 0
        self.isQuizMode = true
        self.isEvaluatingAnswer = false
        self.pendingPostQuizAction = onComplete
        self.quizStatusMessage = "Knowledge Check Active"
        self.playbackModeDescription = "Hands-Free Knowledge Check"

        updateNowPlayingForQuiz(title: "Hands-Free Knowledge Check", detail: "Listen for definition...")

        speakText(introAnnouncement) { [weak self] in
            guard let self = self, self.isQuizMode else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.presentNextQuizQuestion()
            }
        }
    }

    private func presentNextQuizQuestion() {
        guard isQuizMode else { return }
        quizTimer?.invalidate()

        if quizQuestionIndex >= quizQuestions.count {
            finishHandsFreeKnowledgeCheck()
            return
        }

        let word = quizQuestions[quizQuestionIndex]
        self.quizExpectedWord = word
        self.isEvaluatingAnswer = false
        let qNum = quizQuestionIndex + 1

        let prompt = "Question \(qNum) of \(quizTotalCount): What word means: \(word.shortDefinition)?"
        self.playbackModeDescription = "Quiz \(qNum)/\(quizTotalCount): \"\(word.shortDefinition)\""
        self.quizStatusMessage = "Q\(qNum)/\(quizTotalCount): What word means: \(word.shortDefinition)?"
        updateNowPlayingForQuiz(title: "Question \(qNum) of \(quizTotalCount)", detail: "What means: \(word.shortDefinition)?")

        speakText(prompt) { [weak self] in
            guard let self = self, self.isQuizMode else { return }
            print("[VoiceManager] 🎯 Quiz question spoken. Starting 8.5s listening window for driver response...")
            self.playbackModeDescription = "Listening for: \"\(word.word)\" or \"Tell me\"..."
            self.quizTimer?.invalidate()
            self.quizTimer = Timer.scheduledTimer(withTimeInterval: 8.5, repeats: false) { [weak self] _ in
                self?.handleQuizAnswer(isUserCorrect: false, userGaveUp: false, isTimeout: true)
            }
        }
    }

    public func evaluateQuizUtterance(_ utterance: String) -> Bool {
        guard isQuizMode, let word = quizExpectedWord, !isEvaluatingAnswer else { return false }
        let target = word.word.lowercased()

        if utterance.contains("skip quiz") || utterance.contains("skip test") || utterance.contains("stop quiz") || utterance.contains("exit quiz") || utterance.contains("cancel quiz") {
            isEvaluatingAnswer = true
            quizTimer?.invalidate()
            skipHandsFreeKnowledgeCheck()
            return true
        }

        if utterance.contains("tell me") || utterance.contains("answer") || utterance.contains("don't know") || utterance.contains("dont know") || utterance.contains("pass") || utterance.contains("give up") {
            isEvaluatingAnswer = true
            quizTimer?.invalidate()
            handleQuizAnswer(isUserCorrect: false, userGaveUp: true)
            return true
        }

        if utterance.contains(target) {
            isEvaluatingAnswer = true
            quizTimer?.invalidate()
            handleQuizAnswer(isUserCorrect: true, userGaveUp: false)
            return true
        }

        return false
    }

    public func handleQuizAnswer(isUserCorrect: Bool, userGaveUp: Bool, isTimeout: Bool = false) {
        guard isQuizMode, let word = quizExpectedWord else { return }
        quizTimer?.invalidate()
        quizTimer = nil
        isEvaluatingAnswer = true

        let feedbackText: String
        let nowPlayingStatus: String

        if isUserCorrect {
            quizScore += 1
            feedbackText = "Correct! \(word.word). \(word.exampleSentence)"
            nowPlayingStatus = "Correct: \(word.word)"
            self.quizStatusMessage = "✅ Correct! \(word.word)"
        } else if userGaveUp {
            feedbackText = "The answer is \(word.word). \(word.shortDefinition). Here is an example: \(word.exampleSentence)"
            nowPlayingStatus = "Answer: \(word.word)"
            self.quizStatusMessage = "💡 The answer is \(word.word)"
        } else {
            feedbackText = "Time's up. The word is \(word.word). \(word.shortDefinition)."
            nowPlayingStatus = "Time's up: \(word.word)"
            self.quizStatusMessage = "⏱️ Time's up: \(word.word)"
        }

        self.playbackModeDescription = feedbackText
        updateNowPlayingForQuiz(title: nowPlayingStatus, detail: word.shortDefinition)

        speakText(feedbackText) { [weak self] in
            guard let self = self, self.isQuizMode else { return }
            self.quizQuestionIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.presentNextQuizQuestion()
            }
        }
    }

    public func finishHandsFreeKnowledgeCheck() {
        quizTimer?.invalidate()
        quizTimer = nil
        let finalScore = quizScore
        let total = quizTotalCount
        isQuizMode = false
        quizExpectedWord = nil
        isEvaluatingAnswer = false

        let summary = "Knowledge check complete! You scored \(finalScore) out of \(total)."
        self.playbackModeDescription = summary
        self.quizStatusMessage = summary
        updateNowPlayingForQuiz(title: "Knowledge Check Complete", detail: "Score: \(finalScore)/\(total)")

        NotificationCenter.default.post(name: .oratorMilestoneReached, object: nil)

        speakText(summary) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                let transition = self?.pendingPostQuizAction
                self?.pendingPostQuizAction = nil
                transition?()
            }
        }
    }

    public func skipHandsFreeKnowledgeCheck() {
        quizTimer?.invalidate()
        quizTimer = nil
        isQuizMode = false
        quizExpectedWord = nil
        isEvaluatingAnswer = false
        self.playbackModeDescription = "Knowledge check skipped."
        self.quizStatusMessage = "Quiz Skipped"

        speakText("Skipping knowledge check.") { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                let transition = self?.pendingPostQuizAction
                self?.pendingPostQuizAction = nil
                transition?()
            }
        }
    }

    private func updateNowPlayingForQuiz(title: String, detail: String) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title.uppercased(),
            MPMediaItemPropertyArtist: detail,
            MPMediaItemPropertyAlbumTitle: "Orator [Knowledge Check]",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPMediaItemPropertyPlaybackDuration: 15.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
        ]

        if let img = UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func announceSetTransition(completedSet: Int, nextSet: Int, isFullDeckProgression: Bool = false) {
        if nextSet > 1 && !StoreKitManager.isUnlockedLocally {
            let announcement = "Set \(completedSet) complete. To continue to Set 2 and unlock all 60 sets, please unlock Orator Lifetime Full Access."
            self.playbackModeDescription = "Unlock Lifetime Access"
            let trackId = (completedSet == 1) ? "set1_complete_unlock" : nil
            speakWordTrack(wordId: trackId, kind: nil, text: announcement) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.shouldShowPaywall = true
                    self.isPlaying = false
                }
            }
            return
        }

        let announcement = "Set \(completedSet) complete. Moving to Set \(nextSet)."
        self.playbackModeDescription = "Transitioning to Set \(nextSet)..."
        let trackId = (completedSet == 1 && nextSet == 2) ? "set1_complete_next" : nil

        NotificationCenter.default.post(name: .oratorMilestoneReached, object: nil)

        speakWordTrack(wordId: trackId, kind: nil, text: announcement) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if isFullDeckProgression {
                    let nextSetWords = CurriculumData.wordsForSet(nextSet)
                    if !nextSetWords.isEmpty {
                        self.startDeck(nextSetWords, startingAt: 0)
                        return
                    } else if !CurriculumData.words.isEmpty {
                        self.startDeck(CurriculumData.words, startingAt: 0)
                        return
                    }
                }
                if self.activeIndex < self.activeDeck.count {
                    self.presentWord(self.activeDeck[self.activeIndex])
                }
            }
        }
    }

    public func markCurrentWordMastered() {
        guard var word = currentWord else { return }
        word.isMastered = true
        word.repetitions += 1
        word.lastReviewedAt = Date()
        currentWord = word
    }

    public func pauseStudySession() {
        recallTimer?.invalidate()
        quizTimer?.invalidate()
        player?.pause()
        directSynthesizer?.pauseSpeaking(at: .immediate)
        isPlaying = false
        playbackModeDescription = "Paused"
        republishNowPlayingRate()
        VoiceCommander.shared.stopListening()
    }

    public func resumeStudySession() {
        if let player = player, !player.isPlaying {
            player.play()
            isPlaying = true
            republishNowPlayingRate()
        } else if let synth = directSynthesizer, synth.isPaused {
            synth.continueSpeaking()
            isPlaying = true
            republishNowPlayingRate()
        } else if isQuizMode {
            presentNextQuizQuestion()
        } else if let word = currentWord {
            presentWord(word)
        }
    }

    // MARK: - Speech Audio Playback Pipeline

    public func speakWordTrack(wordId: String? = nil, kind: String? = nil, text: String, completion: @escaping () -> Void) {
        configureAudioSessionIfNeeded()

        // Temporarily pause speech recognition while speaking to prevent feedback/audio conflicts
        VoiceCommander.shared.stopListening()

        player?.stop()
        player = nil
        directSynthesizer?.stopSpeaking(at: .immediate)

        self.completionHandler = { [weak self] in
            guard let self = self else { return }
            if !self.isCarPlayConnected {
                VoiceCommander.shared.startContinuousListening()
            }
            completion()
        }

        AudioCache.shared.url(forWordId: wordId, kind: kind, text: text, voicePersona: selectedVoiceIdentifier) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let url):
                do {
                    self.player = try AVAudioPlayer(contentsOf: url)
                    self.player?.delegate = self
                    self.player?.prepareToPlay()
                    let started = self.player?.play() ?? false
                    if started {
                        self.isPlaying = true
                        self.republishNowPlayingRate()
                    } else {
                        print("[VoiceManager] AVAudioPlayer.play() returned false, falling back to direct synthesizer")
                        self.speakDirectly(text: text)
                    }
                } catch {
                    print("[VoiceManager] AVAudioPlayer error: \(error), falling back to direct synthesizer")
                    self.speakDirectly(text: text)
                }
            case .failure(let error):
                print("[VoiceManager] AudioCache error: \(error), falling back to direct synthesizer")
                self.speakDirectly(text: text)
            }
        }
    }

    public func speakText(_ text: String, completion: @escaping () -> Void) {
        speakWordTrack(wordId: nil, kind: nil, text: text, completion: completion)
    }

    private func speakDirectly(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let synth = AVSpeechSynthesizer()
            synth.delegate = self
            self.directSynthesizer = synth

            let utterance = AVSpeechUtterance(string: text)
            let chosenVoice = AudioCache.pickBestVoice(preferredIdentifier: self.selectedVoiceIdentifier)
            utterance.voice = chosenVoice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
            utterance.pitchMultiplier = 1.02
            utterance.volume = 1.0

            self.isPlaying = true
            self.republishNowPlayingRate()
            synth.speak(utterance)
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        republishNowPlayingRate()
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.isPlaying = false
        republishNowPlayingRate()
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        self.isPlaying = false
        republishNowPlayingRate()
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }

    // MARK: - Now Playing Info Center (CarPlay Dashboard Sync)

    public func updateNowPlaying(with word: VocabWord, status: String) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: word.word.uppercased(),
            MPMediaItemPropertyArtist: "\(word.partOfSpeech) • \(word.phonetic)",
            MPMediaItemPropertyAlbumTitle: "Orator [\(status)]",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPMediaItemPropertyPlaybackDuration: player?.duration ?? 30.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0.0
        ]

        if let img = UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func republishNowPlayingRate() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime ?? 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension Notification.Name {
    public static let oratorMilestoneReached = Notification.Name("oratorMilestoneReached")
}
