//
//  AudioCache.swift
//  VocabRoady
//
//  Pre-renders AVSpeechSynthesizer utterances to local .caf files in Documents/AudioCache/
//  and plays back via AVAudioPlayer. This avoids mid-utterance CarPlay route dropouts.
//

import Foundation
import AVFoundation
import CryptoKit

public struct AudioRenderRequest {
    public let text: String
    public let voiceIdentifier: String
    public let rate: Float
    public let pitch: Float
    public let volume: Float

    public init(
        text: String,
        voiceIdentifier: String = "com.apple.ttsbundle.siri_female_en-US_compact",
        rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.92,
        pitch: Float = 1.0,
        volume: Float = 1.0
    ) {
        self.text = text
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
    }
}

public final class AudioCache: @unchecked Sendable {
    public static let shared = AudioCache()

    private let renderQueue = DispatchQueue(label: "com.Alex.VocabRoady.AudioCache.render", qos: .userInitiated)
    private var inFlight: [String: [((Result<URL, Error>) -> Void)]] = [:]
    private let lock = NSLock()

    private init() {
        _ = try? Self.ensureCacheDirectory()
    }

    private static func cacheRoot() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent("AudioCache", isDirectory: true)
    }

    private static func ensureCacheDirectory() throws -> URL {
        let dir = try cacheRoot()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func cacheURL(for req: AudioRenderRequest) throws -> URL {
        let dir = try ensureCacheDirectory()
        let rawKey = "\(req.text)|\(req.voiceIdentifier)|\(req.rate)|\(req.pitch)|\(req.volume)"
        let digest = Insecure.SHA1.hash(data: Data(rawKey.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent("\(hex).caf")
    }

    public func getAudioURL(for req: AudioRenderRequest, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileURL: URL
        do {
            fileURL = try Self.cacheURL(for: req)
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            DispatchQueue.main.async { completion(.success(fileURL)) }
            return
        }

        let key = fileURL.path
        lock.lock()
        if inFlight[key] != nil {
            inFlight[key]?.append(completion)
            lock.unlock()
            return
        }
        inFlight[key] = [completion]
        lock.unlock()

        renderQueue.async { [weak self] in
            guard let self = self else { return }
            self.renderUtteranceToFile(req: req, targetURL: fileURL) { result in
                self.lock.lock()
                let callbacks = self.inFlight.removeValue(forKey: key) ?? []
                self.lock.unlock()

                DispatchQueue.main.async {
                    for cb in callbacks {
                        cb(result)
                    }
                }
            }
        }
    }

    private func renderUtteranceToFile(req: AudioRenderRequest, targetURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: req.text)

        if let voice = AVSpeechSynthesisVoice(identifier: req.voiceIdentifier) ?? AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        utterance.rate = req.rate
        utterance.pitchMultiplier = req.pitch
        utterance.volume = req.volume

        var outputAudioFile: AVAudioFile?
        var renderError: Error?

        synthesizer.write(utterance) { buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
            if pcmBuffer.frameLength == 0 { return }

            do {
                if outputAudioFile == nil {
                    outputAudioFile = try AVAudioFile(
                        forWriting: targetURL,
                        settings: pcmBuffer.format.settings,
                        commonFormat: pcmBuffer.format.commonFormat,
                        interleaved: pcmBuffer.format.isInterleaved
                    )
                }
                try outputAudioFile?.write(from: pcmBuffer)
            } catch {
                renderError = error
            }
        }

        if let error = renderError {
            completion(.failure(error))
        } else {
            completion(.success(targetURL))
        }
    }
}
