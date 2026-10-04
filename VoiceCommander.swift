//
//  VoiceCommander.swift
//  VocabRoady
//
//  Hands-Free Continuous Automotive Speech Recognition & Command Engine.
//  Zero steering wheel buttons, zero screen touches.
//

import Foundation
import Speech
import AVFoundation
import Combine

public enum VocabCommand: String {
    case next = "NEXT"           // "Next", "Skip", "Forward", "Got it"
    case repeatWord = "REPEAT"   // "Repeat", "Again", "Say that again", "One more time"
    case explain = "EXPLAIN"     // "Explain", "Detail", "More", "Elaborate"
    case example = "EXAMPLE"     // "Example", "Sentence", "Context"
    case root = "ROOT"           // "Root", "Origin", "Etymology"
    case pause = "PAUSE"         // "Pause", "Wait", "Hold on", "Stop"
    case resume = "RESUME"       // "Resume", "Play", "Continue", "Go"
    case mastered = "MASTERED"   // "Mastered", "Know it", "Easy", "Done"
}

public protocol VoiceCommandDelegate: AnyObject {
    func didRecognizeCommand(_ command: VocabCommand)
}

public final class VoiceCommander: NSObject, ObservableObject {
    public static let shared = VoiceCommander()

    @Published public var isListening: Bool = false
    @Published public var recognizedTranscription: String = ""
    @Published public var lastDetectedCommand: VocabCommand? = nil
    @Published public var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    public weak var delegate: VoiceCommandDelegate?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Command debouncing to avoid double execution on multi-word recognition
    private var lastCommandTimestamp: Date = .distantPast
    private let debounceInterval: TimeInterval = 1.2

    private override init() {
        super.init()
        checkAuthorization()
    }

    public func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                print("[VoiceCommander] Speech authorization status: \(status.rawValue)")
            }
        }
    }

    public func startContinuousListening() {
        guard !isListening else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("[VoiceCommander] Speech recognition not authorized.")
            return
        }

        stopListening()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true // Zero latency, 100% offline in moving car

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            print("[VoiceCommander] Started continuous on-device speech recognition.")

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
            print("[VoiceCommander] Error starting listening: \(error.localizedDescription)")
            isListening = false
        }
    }

    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    private func restartListening() {
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startContinuousListening()
        }
    }

    /// Match driver's voice against intuitive lexical study intents
    private func evaluateSpokenUtterance(_ utterance: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTimestamp) > debounceInterval else { return }

        let normalized = utterance.lowercased()

        var detected: VocabCommand? = nil

        if normalized.contains("next") || normalized.contains("skip") || normalized.contains("forward") || normalized.contains("advance") {
            detected = .next
        } else if normalized.contains("repeat") || normalized.contains("again") || normalized.contains("say again") || normalized.contains("one more") {
            detected = .repeatWord
        } else if normalized.contains("master") || normalized.contains("got it") || normalized.contains("i know this") || normalized.contains("easy") {
            detected = .mastered
        } else if normalized.contains("explain") || normalized.contains("detail") || normalized.contains("elaborate") || normalized.contains("definition") {
            detected = .explain
        } else if normalized.contains("example") || normalized.contains("sentence") || normalized.contains("context") {
            detected = .example
        } else if normalized.contains("root") || normalized.contains("origin") || normalized.contains("etymology") {
            detected = .root
        } else if normalized.contains("pause") || normalized.contains("hold on") || normalized.contains("wait") || normalized.contains("stop") {
            detected = .pause
        } else if normalized.contains("resume") || normalized.contains("play") || normalized.contains("continue") || normalized.contains("go") {
            detected = .resume
        }

        if let command = detected {
            lastCommandTimestamp = now
            lastDetectedCommand = command
            print("[VoiceCommander] 🎙️ DETECTED VOICE COMMAND: \(command.rawValue)")
            delegate?.didRecognizeCommand(command)

            // Clear partial buffer so previous word doesn't re-trigger immediately
            recognitionRequest?.endAudio()
            restartListening()
        }
    }
}
