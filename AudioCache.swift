//
//  AudioCache.swift
//  Orator: Executive Lexicon
//
//  Hybrid Neural Voice Architecture:
//  1. Fast-Path App Bundle: Instant 0ms playback from pre-rendered studio neural .wav files (e.g. Set 1 free tier).
//  2. Local Disk Cache: Instant 0ms playback from Documents/AudioCache/ for previously synthesized neural clips.
//  3. Edge Neural Streaming: Fetches studio-grade 24kHz audio from Cloudflare Worker proxy powered by Gemini 3.8 Flash TTS.
//  4. Offline Synthesizer Fallback: Uses on-device AVSpeechSynthesizer if device is offline and clip is not cached.
//

import Foundation
import AVFoundation
import CryptoKit

public struct RenderRequest {
    public let text: String
    public let localeCode: String
    public let voiceID: String
    public let rate: Float
    public let pitch: Float
    public let volume: Float
    public let postGain: Float

    public init(
        text: String,
        localeCode: String = "en-US",
        voiceID: String = "",
        rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.90,
        pitch: Float = 1.02,
        volume: Float = 1.0,
        postGain: Float = 1.0
    ) {
        self.text = text
        self.localeCode = localeCode
        self.voiceID = voiceID
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.postGain = postGain
    }
}

public enum AudioCacheError: Error {
    case voiceUnavailable
    case renderFailed(String)
    case writeFailed(String)
}

public final class AudioCache: @unchecked Sendable {
    public static let shared = AudioCache()

    // Cloudflare Edge Proxy Endpoint (Rule 11 Compliant, Zero Key Exposure)
    public static let edgeProxyURL = URL(string: "https://orator-tts.mohalex.workers.dev/api/tts")!

    private let renderQueue = DispatchQueue(label: "com.Alex.HandsFreeVocab.AudioCache.render",
                                            qos: .userInitiated)

    private var inFlight: [String: [((Result<URL, Error>) -> Void)]] = [:]
    private let inFlightLock = NSLock()

    private init() {
        _ = try? Self.ensureCacheRoot()
    }

    // MARK: - Primary Neural Audio Resolver

    /// Resolves human-grade neural audio for a vocabulary track (hook, example, etymology, deep) or announcement.
    public func url(
        forWordId wordId: String? = nil,
        kind: String? = nil,
        text: String,
        voicePersona: String = "Aoede",
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let voiceName = voicePersona.contains("Male") ? "Puck" : "Aoede"
        let baseFilename: String
        if let wid = wordId, let k = kind {
            baseFilename = (voiceName == "Puck") ? "\(wid.lowercased())_\(k)_puck" : "\(wid.lowercased())_\(k)"
        } else {
            baseFilename = Self.hashKey(text: text, voice: voiceName)
        }

        // 1. Fast-Path: Check Bundled Studio Audio in App Bundle (Set 1 & Core Announcements)
        if let bundleURL = Bundle.main.url(forResource: baseFilename, withExtension: "wav") ??
                           Bundle.main.url(forResource: baseFilename, withExtension: "wav", subdirectory: "BundledAudio") ??
                           Bundle.main.url(forResource: baseFilename, withExtension: "caf") {
            DispatchQueue.main.async { completion(.success(bundleURL)) }
            return
        }

        // 2. Check Local Disk Cache in Documents/AudioCache/
        let cacheDest: URL
        do {
            let root = try Self.ensureCacheRoot()
            cacheDest = root.appendingPathComponent("\(baseFilename).wav")
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        if FileManager.default.fileExists(atPath: cacheDest.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: cacheDest.path),
           (attr[.size] as? UInt64 ?? 0) > 2000 {
            DispatchQueue.main.async { completion(.success(cacheDest)) }
            return
        }

        // 3. Deduplicate In-Flight Requests
        let key = cacheDest.path
        inFlightLock.lock()
        if var waiters = inFlight[key] {
            waiters.append(completion)
            inFlight[key] = waiters
            inFlightLock.unlock()
            return
        } else {
            inFlight[key] = [completion]
        }
        inFlightLock.unlock()

        // 4. Download from Neural TTS Proxy
        fetchNeuralTTS(text: text, voiceName: voiceName, dest: cacheDest) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let fileURL):
                self.notifyWaiters(key: key, result: .success(fileURL))
            case .failure(let neuralError):
                print("[AudioCache] Neural TTS fetch failed: \(neuralError). Falling back to on-device synthesizer.")
                // 5. Fallback: Synthesize with local AVSpeechSynthesizer to destination
                let req = RenderRequest(
                    text: text,
                    localeCode: "en-US",
                    voiceID: "",
                    rate: AVSpeechUtteranceDefaultSpeechRate * 0.90,
                    pitch: 1.02
                )
                self.renderQueue.async {
                    let fallbackResult: Result<URL, Error>
                    do {
                        try self.renderToFile(req: req, dest: cacheDest)
                        fallbackResult = .success(cacheDest)
                    } catch {
                        fallbackResult = .failure(error)
                    }
                    self.notifyWaiters(key: key, result: fallbackResult)
                }
            }
        }
    }

    private func notifyWaiters(key: String, result: Result<URL, Error>) {
        inFlightLock.lock()
        let waiters = inFlight[key] ?? []
        inFlight[key] = nil
        inFlightLock.unlock()

        DispatchQueue.main.async {
            for cb in waiters { cb(result) }
        }
    }

    // MARK: - Neural TTS Network Fetch

    private func fetchNeuralTTS(
        text: String,
        voiceName: String,
        dest: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var request = URLRequest(url: Self.edgeProxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Orator/1.0 (iOS; NeuralAudioEngine)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12.0

        let payload: [String: String] = [
            "text": text,
            "voice": voiceName
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(AudioCacheError.renderFailed("Failed to encode JSON payload")))
            return
        }
        request.httpBody = httpBody

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResp = response as? HTTPURLResponse,
                  (200...299).contains(httpResp.statusCode),
                  let data = data,
                  data.count > 1000 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(AudioCacheError.renderFailed("Edge proxy HTTP \(code)")))
                return
            }

            do {
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: dest, options: .atomic)
                completion(.success(dest))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Spaced Repetition Background Pre-Fetching

    public func prefetchWord(_ word: VocabWord, voicePersona: String = "Aoede") {
        renderQueue.async {
            self.url(forWordId: word.id, kind: "hook", text: word.spokenAcousticHook, voicePersona: voicePersona) { _ in }
            self.url(forWordId: word.id, kind: "example", text: word.spokenExampleScript, voicePersona: voicePersona) { _ in }
        }
    }

    // MARK: - Backward-Compatible url(for: RenderRequest)

    public func url(for req: RenderRequest, completion: @escaping (Result<URL, Error>) -> Void) {
        url(forWordId: nil, kind: nil, text: req.text, voicePersona: "Aoede", completion: completion)
    }

    // MARK: - On-Device AVSpeechSynthesizer Fallback Engine

    public static func pickBestVoice(for localeCode: String = "en-US", preferredGender: AVSpeechSynthesisVoiceGender? = nil) -> AVSpeechSynthesisVoice {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let matchingLocale = allVoices.filter { $0.language == localeCode || $0.language.hasPrefix("en") }

        let candidates = matchingLocale.filter { v in
            if let gender = preferredGender {
                return v.gender == gender
            }
            return true
        }

        // Prioritize: Premium > Enhanced > Siri Voices
        if let premium = candidates.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = candidates.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        if let siri = candidates.first(where: { $0.identifier.contains("siri") }) {
            return siri
        }
        if let naturalNamed = candidates.first(where: {
            $0.name.contains("Ava") || $0.name.contains("Zoe") || $0.name.contains("Allison") || $0.name.contains("Evan")
        }) {
            return naturalNamed
        }
        if let firstMatch = candidates.first {
            return firstMatch
        }

        return AVSpeechSynthesisVoice(language: localeCode) ?? AVSpeechSynthesisVoice(language: "en-US")!
    }

    private func renderToFile(req: RenderRequest, dest: URL) throws {
        let voice: AVSpeechSynthesisVoice
        if !req.voiceID.isEmpty, let matched = AVSpeechSynthesisVoice(identifier: req.voiceID) {
            voice = matched
        } else {
            voice = Self.pickBestVoice(for: req.localeCode)
        }

        let utterance = AVSpeechUtterance(string: req.text)
        utterance.voice = voice
        utterance.rate = req.rate
        utterance.pitchMultiplier = req.pitch
        utterance.volume = req.volume
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0

        let synth = AVSpeechSynthesizer()
        var audioFile: AVAudioFile?
        var writeError: Error?

        let tmp = dest.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp.caf")

        let sem = DispatchSemaphore(value: 0)
        var didFinish = false

        synth.write(utterance) { (buffer: AVAudioBuffer) in
            guard let pcm = buffer as? AVAudioPCMBuffer else {
                writeError = AudioCacheError.renderFailed("non-PCM buffer")
                if !didFinish { didFinish = true; sem.signal() }
                return
            }

            if pcm.frameLength == 0 {
                if !didFinish { didFinish = true; sem.signal() }
                return
            }

            do {
                if audioFile == nil {
                    audioFile = try AVAudioFile(forWriting: tmp,
                                                settings: pcm.format.settings,
                                                commonFormat: .pcmFormatFloat32,
                                                interleaved: false)
                }

                if req.postGain != 1.0,
                   let channelData = pcm.floatChannelData {
                    let frames = Int(pcm.frameLength)
                    let channels = Int(pcm.format.channelCount)
                    let gain = req.postGain
                    for ch in 0..<channels {
                        let ptr = channelData[ch]
                        for i in 0..<frames {
                            var v = ptr[i] * gain
                            if v > 1.0 { v = 1.0 } else if v < -1.0 { v = -1.0 }
                            ptr[i] = v
                        }
                    }
                }
                try audioFile?.write(from: pcm)
            } catch {
                writeError = error
                if !didFinish { didFinish = true; sem.signal() }
            }
        }

        let waited = sem.wait(timeout: .now() + 30)
        if waited == .timedOut {
            throw AudioCacheError.renderFailed("render timeout after 30s")
        }
        if let e = writeError { throw e }
        guard audioFile != nil else {
            throw AudioCacheError.renderFailed("no audio produced")
        }

        audioFile = nil

        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tmp, to: dest)
    }

    // MARK: - Paths & Hashing

    private static func ensureCacheRoot() throws -> URL {
        let docs = try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        let root = docs.appendingPathComponent("AudioCache", isDirectory: true)
        try FileManager.default.createDirectory(at: root,
                                                withIntermediateDirectories: true)
        return root
    }

    private static func hashKey(text: String, voice: String) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data(text.utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(voice.utf8))
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
