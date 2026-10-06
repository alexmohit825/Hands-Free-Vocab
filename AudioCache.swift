//
//  AudioCache.swift
//  Hands-Free Vocab
//
//  Pre-renders AVSpeechSynthesizer output to .caf files in the app's
//  Documents directory, then plays them back via AVAudioPlayer.
//  Matching Hands-Free Lingo proven architecture.
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
        rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.95,
        pitch: Float = 1.0,
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

    // MARK: - Public API

    public func url(for req: RenderRequest,
                    completion: @escaping (Result<URL, Error>) -> Void) {
        let path: URL
        do {
            path = try Self.cacheURL(for: req)
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        if FileManager.default.fileExists(atPath: path.path) {
            DispatchQueue.main.async { completion(.success(path)) }
            return
        }

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

    // MARK: - Core Render Implementation

    public static func pickBestVoice(for localeCode: String = "en-US", preferredGender: AVSpeechSynthesisVoiceGender? = nil) -> AVSpeechSynthesisVoice {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let matchingLocale = allVoices.filter { $0.language == localeCode || $0.language.hasPrefix("en") }

        // 1. Check for user-selected or premium / enhanced quality voices
        let candidates = matchingLocale.filter { v in
            if let gender = preferredGender {
                return v.gender == gender
            }
            return true
        }

        // Prioritize: Premium > Enhanced > Default
        // Also prioritize expressive natural voice names like Samantha, Ava, Zoe, Evan, Tom, Allison
        if let premium = candidates.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = candidates.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        if let naturalNamed = candidates.first(where: {
            $0.name.contains("Ava") || $0.name.contains("Samantha") || $0.name.contains("Zoe") || $0.name.contains("Allison") || $0.name.contains("Tom")
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

        // Semaphore waits for buffer drainage until EOF empty buffer
        let sem = DispatchSemaphore(value: 0)
        var didFinish = false

        synth.write(utterance) { (buffer: AVAudioBuffer) in
            guard let pcm = buffer as? AVAudioPCMBuffer else {
                writeError = AudioCacheError.renderFailed("non-PCM buffer")
                if !didFinish { didFinish = true; sem.signal() }
                return
            }

            if pcm.frameLength == 0 {
                // EOF marker from AVSpeechSynthesizer
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
