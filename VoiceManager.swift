//
//  VoiceManager.swift
//  Hands-Free Vocab
//
//  Automotive Audio Director & Spaced Repetition Playback Orchestrator.
//  Matches Hands-Free Lingo audio session priority and route-holding architecture.
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

    @Published public var selectedVoicePersona: String = "Natural Female (Ava / Samantha)"

    // Timing gaps calibrated for driver cognitive retrieval
    public var recallWindowSeconds: Double = 3.5
    private var recallTimer: Timer?

    private override init() {
        super.init()
        self.activeDeck = CurriculumData.words
        VoiceCommander.shared.delegate = self
        observeInterruptions()
        observeAppLifecycle()
    }

    private var directSynthesizer: AVSpeechSynthesizer?
    private var isUsingDirectSpeech: Bool = false

    // MARK: - Audio Session Priority

    public func configureAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord allows both microphone input and full-volume speaker output.
            // .defaultToSpeaker ensures sound routes to the bottom loud speaker / car Bluetooth instead of receiver.
            try session.setCategory(.playAndRecord,
                                    mode: .spokenAudio,
                                    options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true, options: [])
            print("[VoiceManager] Audio session active with .playAndRecord / .spokenAudio")
        } catch {
            print("[VoiceManager] Audio session setCategory error: \(error)")
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

        speakText(word.spokenAcousticHook) { [weak self] in
            guard let self = self else { return }
            self.playbackModeDescription = "Listening for voice ('Next', 'Repeat', 'Mastered')..."

            self.recallTimer?.invalidate()
            self.recallTimer = Timer.scheduledTimer(withTimeInterval: self.recallWindowSeconds, repeats: false) { [weak self] _ in
                self?.deliverContextualExample()
            }
        }
    }

    public func deliverContextualExample() {
        guard let word = currentWord else { return }
        self.playbackModeDescription = "Contextual Sentence"
        updateNowPlaying(with: word, status: "Contextual Usage")

        speakText(word.spokenExampleScript) { [weak self] in
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
            print("[VoiceManager] 🎯 Executing Voice Command: \(command.rawValue)")

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
        directSynthesizer?.stopSpeaking(at: .immediate)

        guard !activeDeck.isEmpty else { return }
        let nextIndex = activeIndex + offset
        if nextIndex >= 0 && nextIndex < activeDeck.count {
            let previousSet = activeDeck[activeIndex].setNumber
            let nextSet = activeDeck[nextIndex].setNumber

            if previousSet != nextSet {
                // Moving into a new set in the active deck
                activeIndex = nextIndex
                announceSetTransition(completedSet: previousSet, nextSet: nextSet)
            } else {
                activeIndex = nextIndex
                presentWord(activeDeck[activeIndex])
            }
        } else if nextIndex >= activeDeck.count {
            // Reached the end of the current active deck!
            // Check if user is studying a single set, a tier, or the master deck
            let currentSet = activeDeck[activeIndex].setNumber
            let totalSets = CurriculumData.totalSetsCount
            let nextSet = (currentSet >= totalSets) ? 1 : currentSet + 1

            announceSetTransition(completedSet: currentSet, nextSet: nextSet, isFullDeckProgression: true)
        }
    }

    private func announceSetTransition(completedSet: Int, nextSet: Int, isFullDeckProgression: Bool = false) {
        if nextSet > 1 && !StoreKitManager.shared.isUnlocked {
            let announcement = "Set \(completedSet) complete. To continue to Set 2 and unlock all 60 sets, please unlock Orator Lifetime Full Access."
            self.playbackModeDescription = "Unlock Lifetime Access"
            speakText(announcement) { [weak self] in
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

        speakText(announcement) { [weak self] in
            guard let self = self else { return }
            // 2-second pause requested by user before starting next set
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
        } else if let word = currentWord {
            presentWord(word)
        }
    }

    // MARK: - Speech Audio Playback Pipeline

    public func speakText(_ text: String, completion: @escaping () -> Void) {
        configureAudioSessionIfNeeded()

        // Temporarily pause speech recognition while speaking to prevent feedback/audio conflicts
        VoiceCommander.shared.stopListening()

        player?.stop()
        player = nil
        directSynthesizer?.stopSpeaking(at: .immediate)

        self.completionHandler = { [weak self] in
            // Re-engage speech recognition once the app finishes speaking
            VoiceCommander.shared.startContinuousListening()
            completion()
        }

        let gender: AVSpeechSynthesisVoiceGender? = selectedVoicePersona.contains("Male") ? .male : .female
        let chosenVoice = AudioCache.pickBestVoice(for: "en-US", preferredGender: gender)
        
        let req = RenderRequest(
            text: text,
            localeCode: "en-US",
            voiceID: chosenVoice.identifier,
            rate: AVSpeechUtteranceDefaultSpeechRate * 0.90, // Calibrated natural pacing (relaxed human speed)
            pitch: 1.02, // Warm, clear, non-monotone acoustic pitch
            volume: 1.0,
            postGain: 1.0
        )
        AudioCache.shared.url(for: req) { [weak self] result in
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

    private func speakDirectly(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let synth = AVSpeechSynthesizer()
            synth.delegate = self
            self.directSynthesizer = synth

            let utterance = AVSpeechUtterance(string: text)
            let gender: AVSpeechSynthesisVoiceGender? = self.selectedVoicePersona.contains("Male") ? .male : .female
            utterance.voice = AudioCache.pickBestVoice(for: "en-US", preferredGender: gender)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.90
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
