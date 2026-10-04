//
//  VoiceManager.swift
//  Hands-Free Vocab
//
//  Automotive Audio Director & Spaced Repetition Playback Orchestrator.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

public final class VoiceManager: NSObject, AVAudioPlayerDelegate, ObservableObject, VoiceCommandDelegate {
    public static let shared = VoiceManager()

    private var player: AVAudioPlayer?
    private var nowPlayingSession: MPNowPlayingInfoCenter = .default()

    @Published public var currentWord: VocabWord?
    @Published public var isPlaying: Bool = false
    @Published public var playbackModeDescription: String = "Idle"
    @Published public var activeDeck: [VocabWord] = []
    @Published public var activeIndex: Int = 0

    // Timing gaps calibrated for driver cognitive retrieval
    public var recallWindowSeconds: Double = 4.0
    private var recallTimer: Timer?

    private override init() {
        super.init()
        self.activeDeck = CurriculumData.words
        VoiceCommander.shared.delegate = self
        configureAudioSession()
        observeNavigationAndAudioInterruptions()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true, options: [])
            print("[VoiceManager] Audio session active with duckOthers & spokenAudio.")
        } catch {
            print("[VoiceManager] Audio session configuration error: \(error)")
        }
    }

    private func observeNavigationAndAudioInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                print("[VoiceManager] Interruption began (navigation / phone call). Pausing.")
                self?.pauseStudySession()
            case .ended:
                print("[VoiceManager] Interruption ended. Resuming.")
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resumeStudySession()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Study Session Engine

    public func startDeck(_ deck: [VocabWord], startingAt index: Int = 0) {
        guard !deck.isEmpty else { return }
        self.activeDeck = deck
        self.activeIndex = max(0, min(index, deck.count - 1))
        self.presentWord(self.activeDeck[self.activeIndex])
        VoiceCommander.shared.startContinuousListening()
    }

    public func presentWord(_ word: VocabWord) {
        self.currentWord = word
        self.playbackModeDescription = "Presenting Word"
        updateNowPlaying(with: word, status: "Acoustic Hook")

        // 1. Deliver the acoustic hook (word + part of speech + short definition)
        speakText(word.spokenAcousticHook) { [weak self] in
            guard let self = self else { return }
            self.playbackModeDescription = "Cognitive Recall Window (Listening for voice...)"

            // 2. Open retrieval window (driver can say "Mastered", "Explain", "Example", or "Next")
            self.recallTimer?.invalidate()
            self.recallTimer = Timer.scheduledTimer(withTimeInterval: self.recallWindowSeconds, repeats: false) { [weak self] _ in
                // After 4s without command, naturally deliver the contextual sentence
                self?.deliverContextualExample()
            }
        }
    }

    public func deliverContextualExample() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Contextual Sentence"
        updateNowPlaying(with: word, status: "Contextual Usage")

        speakText(word.spokenExampleScript) { [weak self] in
            self?.playbackModeDescription = "Awaiting Command (Say: 'Next', 'Repeat', 'Mastered', 'Root')"
        }
    }

    public func deliverEtymology() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Etymology & Roots"
        updateNowPlaying(with: word, status: "Root Analysis")

        speakText(word.spokenEtymologyScript) { [weak self] in
            self?.playbackModeDescription = "Awaiting Command ('Next' to proceed)"
        }
    }

    public func deliverFullExplanation() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Detailed Elaboration"
        updateNowPlaying(with: word, status: "Deep Definition")

        speakText(word.spokenDetailedScript) { [weak self] in
            self?.playbackModeDescription = "Awaiting Command ('Next' to proceed)"
        }
    }

    // MARK: - VoiceCommandDelegate

    public func didRecognizeCommand(_ command: VocabCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[VoiceManager] Executing Spoken Command: \(command.rawValue)")

            switch command {
            case .next:
                self.advanceWord(by: 1)
            case .repeatWord:
                if let word = self.currentWord {
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
            }
        }
    }

    public func advanceWord(by offset: Int) {
        recallTimer?.invalidate()
        player?.stop()

        guard !activeDeck.isEmpty else { return }
        let nextIndex = activeIndex + offset
        if nextIndex >= 0 && nextIndex < activeDeck.count {
            activeIndex = nextIndex
            presentWord(activeDeck[activeIndex])
        } else if nextIndex >= activeDeck.count {
            // Loop deck or complete drive session
            speakText("Commute vocabulary sprint complete. Excellent focus.") { [weak self] in
                self?.activeIndex = 0
                if let first = self?.activeDeck.first {
                    self?.presentWord(first)
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

        // Sound a clean positive chime tone or confirmation
        playAudioConfirmation(isPositive: true)
    }

    public func pauseStudySession() {
        recallTimer?.invalidate()
        player?.pause()
        isPlaying = false
        playbackModeDescription = "Paused"
    }

    public func resumeStudySession() {
        if let player = player, !player.isPlaying {
            player.play()
            isPlaying = true
        } else if let word = currentWord {
            presentWord(word)
        }
    }

    // MARK: - Speech Audio Playback Pipeline

    private func speakText(_ text: String, completion: @escaping () -> Void) {
        let request = AudioRenderRequest(text: text)
        AudioCache.shared.getAudioURL(for: request) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let url):
                do {
                    self.player = try AVAudioPlayer(contentsOf: url)
                    self.player?.delegate = self
                    self.player?.prepareToPlay()
                    self.player?.play()
                    self.isPlaying = true
                    self.onPlaybackCompleted = completion
                } catch {
                    print("[VoiceManager] Playback error: \(error)")
                    completion()
                }
            case .failure(let error):
                print("[VoiceManager] TTS caching error: \(error)")
                completion()
            }
        }
    }

    private var onPlaybackCompleted: (() -> Void)?

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        let handler = onPlaybackCompleted
        onPlaybackCompleted = nil
        handler?()
    }

    private func playAudioConfirmation(isPositive: Bool) {
        // Subtle spoken feedback confirming voice command recognition
        let feedback = isPositive ? "Mastered." : "Noted."
        speakText(feedback) {}
    }

    // MARK: - Now Playing Info Center (CarPlay Dashboard Sync)

    private func updateNowPlaying(with word: VocabWord, status: String) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: word.word.uppercased(),
            MPMediaItemPropertyArtist: "\(word.partOfSpeech) • \(word.phonetic)",
            MPMediaItemPropertyAlbumTitle: "Hands-Free Vocab [\(status)]",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        if let img = renderVocabArtwork(for: word) {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlayingSession.nowPlayingInfo = info
    }

    private func renderVocabArtwork(for word: VocabWord) -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background
            UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Gold accent band
            UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 32, y: 32, width: 8, height: 80))

            // Tier text
            let tierAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1.0)
            ]
            (word.tier.rawValue.uppercased() as NSString).draw(at: CGPoint(x: 52, y: 36), withAttributes: tierAttrs)

            // Voice instruction banner
            let voiceAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.lightGray
            ]
            ("🎙️ Speak: 'Next' • 'Repeat' • 'Mastered'" as NSString).draw(at: CGPoint(x: 52, y: 72), withAttributes: voiceAttrs)

            // Word text
            let wordAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            (word.word as NSString).draw(at: CGPoint(x: 32, y: 160), withAttributes: wordAttrs)

            // Definition snippet
            let defAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor(white: 0.85, alpha: 1.0)
            ]
            let rect = CGRect(x: 32, y: 240, width: 448, height: 220)
            (word.shortDefinition as NSString).draw(in: rect, withAttributes: defAttrs)
        }
    }
}
