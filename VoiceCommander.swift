//
//  VoiceCommander.swift
//  Hands-Free Vocab
//
//  Hands-Free Continuous Automotive Speech Recognition & Command Engine.
//  Engineered for driver safety, zero acoustic feedback loops, and seamless cabin voice control.
//

import Foundation
import Speech
import AVFoundation
import Combine

public enum VocabCommand: String {
    case next = "NEXT"
    case repeatWord = "REPEAT"
    case explain = "EXPLAIN"
    case example = "EXAMPLE"
    case root = "ROOT"
    case pause = "PAUSE"
    case resume = "RESUME"
    case mastered = "MASTERED"
    case quiz = "QUIZ"
}

public protocol VoiceCommandDelegate: AnyObject {
    func didRecognizeCommand(_ command: VocabCommand)
}

public final class VoiceCommander: NSObject, ObservableObject {
    public static let shared = VoiceCommander()

    @Published public var isListening: Bool = false
    @Published public var recognizedTranscription: String = ""
    @Published public var lastDetectedCommand: VocabCommand? = nil
    @Published public var hasPermission: Bool = false

    public weak var delegate: VoiceCommandDelegate?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hasInstalledTap: Bool = false
    private var restartWorkItem: DispatchWorkItem? = nil

    private var lastCommandTimestamp: Date = .distantPast
    private let debounceInterval: TimeInterval = 1.0

    private override init() {
        super.init()
    }

    public func requestPermissionsAndStart(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard authStatus == .authorized else {
                    print("[VoiceCommander] Speech permission denied: \(authStatus.rawValue)")
                    self?.hasPermission = false
                    completion(false)
                    return
                }

                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            self?.hasPermission = granted
                            if granted {
                                self?.startContinuousListening()
                            }
                            completion(granted)
                        }
                    }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            self?.hasPermission = granted
                            if granted {
                                self?.startContinuousListening()
                            }
                            completion(granted)
                        }
                    }
                }
            }
        }
    }

    public func startContinuousListening() {
        restartWorkItem?.cancel()
        restartWorkItem = nil

        guard !isListening else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }

        // Never start listening while audio is actively playing or in CarPlay
        guard !VoiceManager.shared.isPlaying else {
            print("[VoiceCommander] Audio is actively playing, deferring microphone listening.")
            return
        }
        guard !VoiceManager.shared.isCarPlayConnected else {
            print("[VoiceCommander] CarPlay connected: cabin mic bus closed by CarPlay architecture.")
            return
        }

        // Configure audio session for simultaneous recording and playback on iPhone
        VoiceManager.shared.configureAudioSessionIfNeeded()

        stopListening()

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                print("[VoiceCommander] Invalid recording format: \(recordingFormat)")
                return
            }

            if hasInstalledTap {
                inputNode.removeTap(onBus: 0)
                hasInstalledTap = false
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            hasInstalledTap = true

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            print("[VoiceCommander] 🎙️ Speech recognition active and listening on bus 0 (sampleRate=\(recordingFormat.sampleRate)).")

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.recognizedTranscription = text
                        self.evaluateSpokenUtterance(text)
                    }
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.restartListening()
                }
            }
        } catch {
            print("[VoiceCommander] Error starting listening: \(error)")
            isListening = false
        }
    }

    public func stopListening() {
        restartWorkItem?.cancel()
        restartWorkItem = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    private func restartListening() {
        stopListening()
        // Do not restart if audio is actively playing or CarPlay is connected
        guard !VoiceManager.shared.isPlaying && !VoiceManager.shared.isCarPlayConnected else { return }

        restartWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !VoiceManager.shared.isPlaying && !VoiceManager.shared.isCarPlayConnected else { return }
            self.startContinuousListening()
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func evaluateSpokenUtterance(_ utterance: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTimestamp) > debounceInterval else { return }

        let normalized = utterance.lowercased()

        // 1. Hands-Free Knowledge Check Intercept (when active)
        if VoiceManager.shared.isQuizMode {
            if VoiceManager.shared.evaluateQuizUtterance(normalized) {
                lastCommandTimestamp = now
                // Stop listening immediately so speech output is not interrupted by self-feedback
                stopListening()
                return
            }
        }

        var detected: VocabCommand? = nil

        if normalized.contains("next") || normalized.contains("skip") || normalized.contains("forward") {
            detected = .next
        } else if normalized.contains("repeat") || normalized.contains("again") || normalized.contains("say again") {
            detected = .repeatWord
        } else if normalized.contains("master") || normalized.contains("got it") || normalized.contains("i know this") || normalized.contains("easy") {
            detected = .mastered
        } else if normalized.contains("explain") || normalized.contains("detail") || normalized.contains("elaborate") {
            detected = .explain
        } else if normalized.contains("example") || normalized.contains("sentence") || normalized.contains("context") {
            detected = .example
        } else if normalized.contains("root") || normalized.contains("origin") || normalized.contains("etymology") {
            detected = .root
        } else if normalized.contains("pause") || normalized.contains("stop") || normalized.contains("wait") {
            detected = .pause
        } else if normalized.contains("resume") || normalized.contains("play") || normalized.contains("continue") || normalized.contains("start") || normalized.contains("begin") || normalized.contains("go") {
            detected = .resume
        } else if normalized.contains("quiz") || normalized.contains("test me") || normalized.contains("knowledge check") {
            detected = .quiz
        }

        if let command = detected {
            lastCommandTimestamp = now
            lastDetectedCommand = command
            print("[VoiceCommander] 🎯 Detected voice command: \(command.rawValue)")

            // Crucial: Stop listening immediately to prevent hearing the app's own spoken playback
            stopListening()

            delegate?.didRecognizeCommand(command)
        }
    }
}
