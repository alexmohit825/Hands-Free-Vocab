//
//  AudioCache.swift
//  Orator: Executive Lexicon
//
//  100% On-Device Speech Cache & Audio Pipeline:
//  - Fast-Path App Bundle: Instant 0ms playback for bundled studio audio files.
//  - Local Disk Cache: Pre-renders and caches speech to Documents/AudioCache/ on device.
//  - Premium Voice Selection: Automatically prioritizes Apple Premium, Enhanced, and Alex breathing voices.
//  - Zero External Servers: 100% offline, zero network traffic, zero ongoing costs.
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
        rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.88, // Deliberate executive pace
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

    private let renderQueue = DispatchQueue(label: "com.Alex.HandsFreeVocab.AudioCache.render",
                                            qos: .userInitiated)

    private var inFlight: [String: [((Result<URL, Error>) -> Void)]] = [:]
    private let inFlightLock = NSLock()

    private init() {
        _ = try? Self.ensureCacheRoot()
    }

    // MARK: - Voice Discovery & Ranking

    public static var availableEnglishVoices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        return all.filter { $0.language == "en-US" || $0.language.hasPrefix("en") }
            .sorted { v1, v2 in
                if v1.quality.rawValue != v2.quality.rawValue {
                    return v1.quality.rawValue > v2.quality.rawValue
                }
                return v1.name < v2.name
            }
    }

    public static func pickBestVoice(preferredIdentifier: String? = nil, preferredGender: AVSpeechSynthesisVoiceGender? = nil) -> AVSpeechSynthesisVoice {
        // 1. Explicit user preference
        if let id = preferredIdentifier, !id.isEmpty, let matched = AVSpeechSynthesisVoice(identifier: id) {
            return matched
        }
        if let savedID = UserDefaults.standard.string(forKey: "orator_selected_voice_id"),
           let savedVoice = AVSpeechSynthesisVoice(identifier: savedID) {
            return savedVoice
        }

        let candidates = availableEnglishVoices.filter { v in
            if let gender = preferredGender {
                return v.gender == gender
            }
            return true
        }

        // 2. Prioritize Premium quality voices
        if let premium = candidates.first(where: { $0.quality == .premium }) {
            return premium
        }

        // 3. Prioritize Enhanced quality voices
        if let enhanced = candidates.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        // 4. Prioritize Alex (Apple's legendary breathing voice with recorded acoustic lung dynamics)
        if let alex = candidates.first(where: { $0.identifier.contains("Alex") || $0.name.lowercased() == "alex" }) {
            return alex
        }

        // 5. Prioritize natural sounding names, avoiding compact Samantha
        if let naturalNamed = candidates.first(where: {
            ($0.name.contains("Ava") || $0.name.contains("Evan") || $0.name.contains("Zoe") || $0.name.contains("Allison") || $0.name.contains("Nicky")) &&
            !$0.identifier.contains("compact")
        }) {
            return naturalNamed
        }

        // 6. Filter out compact Samantha if any other voice exists
        if let nonSamantha = candidates.first(where: { !$0.name.contains("Samantha") }) {
            return nonSamantha
        }

        return candidates.first ?? AVSpeechSynthesisVoice(language: "en-US")!
    }

    // MARK: - Audio Resolver

    public func url(
        forWordId wordId: String? = nil,
        kind: String? = nil,
        text: String,
        voicePersona: String = "",
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let gender: AVSpeechSynthesisVoiceGender? = voicePersona.contains("Male") ? .male : (voicePersona.contains("Female") ? .female : nil)
        let chosenVoice = Self.pickBestVoice(preferredIdentifier: voicePersona, preferredGender: gender)

        // 1. Fast-Path: Check Bundled Studio Audio in App Bundle (Set 1)
        if let wid = wordId, let k = kind {
            let baseFilename = "\(wid.lowercased())_\(k)"
            if let bundleURL = Bundle.main.url(forResource: baseFilename, withExtension: "wav") ??
                               Bundle.main.url(forResource: baseFilename, withExtension: "wav", subdirectory: "BundledAudio") ??
                               Bundle.main.url(forResource: baseFilename, withExtension: "caf") {
                DispatchQueue.main.async { completion(.success(bundleURL)) }
                return
            }
        }

        // Also check bundled set transitions
        if let wid = wordId, (wid.hasPrefix("set1_") || wid.contains("transition")) {
            if let bundleURL = Bundle.main.url(forResource: wid, withExtension: "wav") ??
                               Bundle.main.url(forResource: wid, withExtension: "wav", subdirectory: "BundledAudio") {
                DispatchQueue.main.async { completion(.success(bundleURL)) }
                return
            }
        }

        // 2. Build Render Request for on-device synthesis
        let req = RenderRequest(
            text: text,
            localeCode: chosenVoice.language,
            voiceID: chosenVoice.identifier,
            rate: AVSpeechUtteranceDefaultSpeechRate * 0.88,
            pitch: 1.02
        )

        let path: URL
        do {
            path = try Self.cacheURL(for: req)
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        // 3. Local Disk Cache Check
        if FileManager.default.fileExists(atPath: path.path) {
            DispatchQueue.main.async { completion(.success(path)) }
            return
        }

        // 4. In-Flight Request Deduplication
        let key = path.path
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

        // 5. Synthesize on-device to file
        renderQueue.async { [weak self] in
            guard let self = self else { return }
            let result: Result<URL, Error>
            do {
                try self.renderToFile(req: req, dest: path)
                result = .success(path)
            } catch {
                result = .failure(error)
            }

            self.inFlightLock.lock()
            let waiters = self.inFlight[key] ?? []
            self.inFlight[key] = nil
            self.inFlightLock.unlock()

            DispatchQueue.main.async {
                for cb in waiters { cb(result) }
            }
        }
    }

    public func prefetchWord(_ word: VocabWord, voicePersona: String = "") {
        renderQueue.async {
            self.url(forWordId: word.id, kind: "hook", text: word.spokenAcousticHook, voicePersona: voicePersona) { _ in }
            self.url(forWordId: word.id, kind: "example", text: word.spokenExampleScript, voicePersona: voicePersona) { _ in }
        }
    }

    public func url(for req: RenderRequest, completion: @escaping (Result<URL, Error>) -> Void) {
        url(forWordId: nil, kind: nil, text: req.text, voicePersona: req.voiceID, completion: completion)
    }

    // MARK: - On-Device Core Render Implementation

    private func renderToFile(req: RenderRequest, dest: URL) throws {
        let voice: AVSpeechSynthesisVoice
        if !req.voiceID.isEmpty, let matched = AVSpeechSynthesisVoice(identifier: req.voiceID) {
            voice = matched
        } else {
            voice = Self.pickBestVoice()
        }

        let utterance = AVSpeechUtterance(string: req.text)
        utterance.voice = voice
        utterance.rate = req.rate
        utterance.pitchMultiplier = req.pitch
        utterance.volume = req.volume
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.15

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

    private static func cacheURL(for req: RenderRequest) throws -> URL {
        let root = try ensureCacheRoot()
        let langDir = root.appendingPathComponent(req.localeCode, isDirectory: true)
        try FileManager.default.createDirectory(at: langDir,
                                                withIntermediateDirectories: true)
        return langDir.appendingPathComponent(Self.key(for: req) + ".caf")
    }

    private static func key(for req: RenderRequest) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data(req.text.utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(req.voiceID.utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(String(format: "%.3f", req.rate).utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(String(format: "%.3f", req.pitch).utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(String(format: "%.3f", req.volume).utf8))
        hasher.update(data: Data("|".utf8))
        hasher.update(data: Data(String(format: "%.3f", req.postGain).utf8))
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
