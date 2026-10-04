//
//  VoiceCommander.swift
//  Hands-Free Vocab
//
//  Hands-Free Continuous Automotive Speech Recognition & Command Engine.
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
        guard !isListening else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }

        stopListening()

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            print("[VoiceCommander] 🎙️ Speech recognition active and listening.")

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

    private func evaluateSpokenUtterance(_ utterance: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTimestamp) > debounceInterval else { return }

        let normalized = utterance.lowercased()
        var detected: VocabCommand? = nil

        if normalized.contains("next") || normalized.contains("skip") || normalized.contains("forward") {
            detected = .next
        } else if normalized.contains("repeat") || normalized.contains("again") || normalized.contains("say again") {
            detected = .repeatWord
        } else if normalized.contains("master") || normalized.contains("got it") || normalized.contains("i know this") {
            detected = .mastered
        } else if normalized.contains("explain") || normalized.contains("detail") || normalized.contains("elaborate") {
            detected = .explain
        } else if normalized.contains("example") || normalized.contains("sentence") {
            detected = .example
        } else if normalized.contains("root") || normalized.contains("origin") {
            detected = .root
        } else if normalized.contains("pause") || normalized.contains("stop") {
            detected = .pause
        } else if normalized.contains("resume") || normalized.contains("play") || normalized.contains("continue") {
            detected = .resume
        }

        if let command = detected {
            lastCommandTimestamp = now
            lastDetectedCommand = command
            print("[VoiceCommander] Detected command: \(command.rawValue)")
            delegate?.didRecognizeCommand(command)

            recognitionRequest?.endAudio()
            restartListening()
        }
    }
}
