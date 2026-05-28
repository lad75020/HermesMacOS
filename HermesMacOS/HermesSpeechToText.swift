//
//  HermesSpeechToText.swift
//  HermesMacOS
//

@preconcurrency import AVFoundation
import Foundation
import Observation
import Speech

enum HermesSpeechToTextEngine: String, CaseIterable, Identifiable {
    case appleLocal
    case whisperWebSocket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleLocal: "Apple local"
        case .whisperWebSocket: "Whisper WebSocket"
        }
    }

    var description: String {
        switch self {
        case .appleLocal:
            "Uses Apple’s on-device Speech framework."
        case .whisperWebSocket:
            "Records audio locally, then sends it to wss://whisper.dubertrand.fr for Whisper transcription."
        }
    }
}

let hermesSpeechToTextEngineStorageKey = "hermes.macOS.speechToTextEngine"

@MainActor
@Observable
final class HermesSpeechToTextSession {
    var isRecording = false
    var isProcessing = false
    var statusMessage = ""
    var lastErrorMessage = ""

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var whisperTask: Task<Void, Never>?
    private var webSocketTask: URLSessionWebSocketTask?
    private var activeEngine: HermesSpeechToTextEngine?
    private var recordedAudioFile: AVAudioFile?
    private var recordedAudioURL: URL?
    private var requestID = ""
    @ObservationIgnored private var updatePromptHandler: (@MainActor (String) -> Void)?
    private var basePrompt = ""
    private var finalizedTranscript = ""
    private var volatileTranscript = ""

    var buttonTitle: String {
        if isRecording { return String(localized: "Stop dictation") }
        if isProcessing { return String(localized: "Transcribing audio") }
        return String(localized: "Dictate prompt")
    }

    var buttonSystemImage: String { isRecording || isProcessing ? "mic.fill" : "mic" }

    func toggleTranscription(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stopTranscription()
        } else if isProcessing {
            stopTranscription(transcribeRecording: false)
        } else {
            startTranscription(currentPrompt: currentPrompt, updatePrompt: updatePrompt)
        }
    }

    func startTranscription(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        stopTranscription(transcribeRecording: false)
        switch Self.selectedEngine() {
        case .appleLocal:
            startAppleTranscription(currentPrompt: currentPrompt, updatePrompt: updatePrompt)
        case .whisperWebSocket:
            startWhisperWebSocketRecording(currentPrompt: currentPrompt, updatePrompt: updatePrompt)
        }
    }

    func stopTranscription(transcribeRecording: Bool = true) {
        if activeEngine == .whisperWebSocket {
            stopWhisperWebSocketRecording(transcribeRecording: transcribeRecording)
        } else {
            stopAppleTranscription()
        }
    }

    private func startAppleTranscription(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        activeEngine = .appleLocal
        updatePromptHandler = updatePrompt
        basePrompt = currentPrompt
        finalizedTranscript = ""
        volatileTranscript = ""
        lastErrorMessage = ""
        statusMessage = String(localized: "Preparing dictation…")

        recognitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard await Self.requestMicrophoneAccess() else {
                    await MainActor.run {
                        self.statusMessage = String(localized: "Microphone access denied")
                        self.lastErrorMessage = String(localized: "Allow microphone access in System Settings to use dictation.")
                        self.activeEngine = nil
                    }
                    return
                }

                guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                    await MainActor.run {
                        self.statusMessage = String(localized: "Dictation unavailable")
                        self.lastErrorMessage = String(localized: "SpeechTranscriber does not support the current locale.")
                        self.activeEngine = nil
                    }
                    return
                }

                let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
                if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    await MainActor.run { self.statusMessage = String(localized: "Installing speech model…") }
                    try await installationRequest.downloadAndInstall()
                }

                guard let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                    await MainActor.run {
                        self.statusMessage = String(localized: "Dictation unavailable")
                        self.lastErrorMessage = String(localized: "No compatible microphone format is available for speech transcription.")
                        self.activeEngine = nil
                    }
                    return
                }
                let analyzer = SpeechAnalyzer(modules: [transcriber])
                let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

                await MainActor.run {
                    self.analyzer = analyzer
                    self.inputContinuation = inputContinuation
                }

                try await MainActor.run {
                    try self.startAudioCapture(targetFormat: audioFormat, inputContinuation: inputContinuation)
                    self.isRecording = true
                    self.statusMessage = String(localized: "Listening…")
                }

                await MainActor.run {
                    self.analysisTask = Task { [weak self] in
                        guard let self else { return }
                        do {
                            let lastSampleTime = try await analyzer.analyzeSequence(inputSequence)
                            if let lastSampleTime {
                                try await analyzer.finalizeAndFinish(through: lastSampleTime)
                            } else {
                                await analyzer.cancelAndFinishNow()
                            }
                        } catch is CancellationError {
                            await analyzer.cancelAndFinishNow()
                        } catch {
                            await MainActor.run { self.finishWithError(error.localizedDescription) }
                        }
                    }
                }

                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        if result.isFinal {
                            self.appendFinalizedTranscript(text)
                            self.volatileTranscript = ""
                        } else {
                            self.volatileTranscript = text
                        }
                        updatePrompt(self.composedPrompt())
                    }
                }
            } catch is CancellationError {
                await MainActor.run { self.finishCleanly() }
            } catch {
                await MainActor.run { self.finishWithError(error.localizedDescription) }
            }
        }
    }

    private func stopAppleTranscription() {
        inputContinuation?.finish()
        inputContinuation = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        analyzer = nil
        activeEngine = nil
        updatePromptHandler = nil
        if isRecording {
            finishCleanly()
        }
    }

    private func startWhisperWebSocketRecording(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        activeEngine = .whisperWebSocket
        updatePromptHandler = updatePrompt
        basePrompt = currentPrompt
        finalizedTranscript = ""
        volatileTranscript = ""
        requestID = UUID().uuidString
        lastErrorMessage = ""
        statusMessage = String(localized: "Preparing Whisper dictation…")

        whisperTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard await Self.requestMicrophoneAccess() else {
                    await MainActor.run {
                        self.statusMessage = String(localized: "Microphone access denied")
                        self.lastErrorMessage = String(localized: "Allow microphone access in System Settings to use dictation.")
                        self.activeEngine = nil
                    }
                    return
                }

                try await MainActor.run {
                    try self.startWhisperAudioCapture()
                    self.isRecording = true
                    self.statusMessage = String(localized: "Recording for Whisper…")
                }
            } catch is CancellationError {
                await MainActor.run { self.cancelWhisperWebSocketWork() }
            } catch {
                await MainActor.run { self.finishWithError(error.localizedDescription) }
            }
        }
    }

    private func startWhisperAudioCapture() throws {
        let inputNode = audioEngine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-whisper-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let audioFile = try AVAudioFile(forWriting: audioURL, settings: sourceFormat.settings)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: sourceFormat) { buffer, _ in
            try? audioFile.write(from: buffer)
        }
        recordedAudioFile = audioFile
        recordedAudioURL = audioURL
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopWhisperWebSocketRecording(transcribeRecording: Bool) {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recordedAudioFile = nil
        isRecording = false

        guard transcribeRecording, let audioURL = recordedAudioURL else {
            cancelWhisperWebSocketWork()
            return
        }
        recordedAudioURL = nil
        statusMessage = String(localized: "Sending audio to Whisper…")
        isProcessing = true

        whisperTask?.cancel()
        whisperTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dataURL = try await Self.base64AudioDataURL(from: audioURL)
                try await self.transcribeWithWhisper(audioDataURL: dataURL, audioFileURL: audioURL)
            } catch is CancellationError {
                await MainActor.run { self.cancelWhisperWebSocketWork() }
            } catch {
                await MainActor.run { self.finishWithError(error.localizedDescription) }
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
    }

    private func transcribeWithWhisper(audioDataURL: String, audioFileURL: URL) async throws {
        guard let url = URL(string: "wss://whisper.dubertrand.fr") else {
            throw HermesSpeechToTextError.invalidWhisperURL
        }
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        let payload = HermesWhisperTranscriptionRequest(
            type: "transcribe",
            id: requestID.isEmpty ? UUID().uuidString : requestID,
            language: "auto",
            audio: audioDataURL
        )
        let payloadData = try JSONEncoder().encode(payload)
        guard let payloadString = String(data: payloadData, encoding: .utf8) else {
            throw HermesSpeechToTextError.invalidWhisperPayload
        }
        try await task.send(.string(payloadString))

        while !Task.isCancelled {
            let message = try await task.receive()
            let response: HermesWhisperTranscriptionResponse
            switch message {
            case .string(let text):
                response = try JSONDecoder().decode(HermesWhisperTranscriptionResponse.self, from: Data(text.utf8))
            case .data(let data):
                response = try JSONDecoder().decode(HermesWhisperTranscriptionResponse.self, from: data)
            @unknown default:
                continue
            }

            let shouldFinish = handleWhisperResponse(response)
            if shouldFinish { break }
        }

        task.cancel(with: .normalClosure, reason: nil)
        try? FileManager.default.removeItem(at: audioFileURL)
        webSocketTask = nil
        whisperTask = nil
        isProcessing = false
        activeEngine = nil
        updatePromptHandler = nil
    }

    private func handleWhisperResponse(_ response: HermesWhisperTranscriptionResponse) -> Bool {
        switch response.type {
        case "queued":
            if let position = response.position {
                statusMessage = String(localized: "Whisper queued (position \(position))…")
            } else {
                statusMessage = String(localized: "Whisper queued…")
            }
            return false
        case "start":
            statusMessage = String(localized: "Whisper is transcribing…")
            return false
        case "delta":
            volatileTranscript = (response.fullText ?? response.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            updatePromptHandler?(composedPrompt())
            return false
        case "done":
            finalizedTranscript = (response.text ?? response.fullText ?? volatileTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
            volatileTranscript = ""
            updatePromptHandler?(composedPrompt())
            statusMessage = finalizedTranscript.isEmpty ? String(localized: "Whisper finished with no speech") : String(localized: "Whisper transcript added")
            lastErrorMessage = ""
            return true
        case "error":
            finishWithError(response.message ?? String(localized: "Whisper transcription failed."))
            return true
        default:
            return false
        }
    }

    private func cancelWhisperWebSocketWork() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        whisperTask?.cancel()
        whisperTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        recordedAudioFile = nil
        if let recordedAudioURL {
            try? FileManager.default.removeItem(at: recordedAudioURL)
        }
        recordedAudioURL = nil
        activeEngine = nil
        updatePromptHandler = nil
        isRecording = false
        isProcessing = false
        if statusMessage.isEmpty {
            statusMessage = String(localized: "Dictation stopped")
        }
    }

    private func startAudioCapture(targetFormat: AVAudioFormat, inputContinuation: AsyncStream<AnalyzerInput>.Continuation) throws {
        let inputNode = audioEngine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: sourceFormat) { buffer, _ in
            guard let convertedBuffer = Self.convert(buffer, to: targetFormat) else { return }
            inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == targetFormat { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return nil }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(max(1, Double(buffer.frameLength) * ratio).rounded(.up))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }

        var didProvideInput = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            status.pointee = .haveData
            return buffer
        }
        return conversionError == nil ? outputBuffer : nil
    }

    private static func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func selectedEngine() -> HermesSpeechToTextEngine {
        let rawValue = UserDefaults.standard.string(forKey: hermesSpeechToTextEngineStorageKey) ?? HermesSpeechToTextEngine.appleLocal.rawValue
        return HermesSpeechToTextEngine(rawValue: rawValue) ?? .appleLocal
    }

    nonisolated private static func base64AudioDataURL(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return "data:audio/wav;base64," + data.base64EncodedString()
        }.value
    }

    private func appendFinalizedTranscript(_ text: String) {
        guard !text.isEmpty else { return }
        if finalizedTranscript.isEmpty {
            finalizedTranscript = text
        } else {
            finalizedTranscript += " " + text
        }
    }

    private func composedPrompt() -> String {
        let dictatedText = [finalizedTranscript, volatileTranscript]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if basePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dictatedText
        }
        if dictatedText.isEmpty {
            return basePrompt
        }
        return basePrompt + (basePrompt.hasSuffix("\n") || basePrompt.hasSuffix(" ") ? "" : " ") + dictatedText
    }

    private func finishCleanly() {
        isRecording = false
        isProcessing = false
        statusMessage = finalizedTranscript.isEmpty && volatileTranscript.isEmpty ? String(localized: "Dictation stopped") : String(localized: "Dictation added")
    }

    private func finishWithError(_ message: String) {
        inputContinuation?.finish()
        inputContinuation = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        analyzer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        whisperTask?.cancel()
        whisperTask = nil
        recordedAudioFile = nil
        if let recordedAudioURL {
            try? FileManager.default.removeItem(at: recordedAudioURL)
        }
        recordedAudioURL = nil
        activeEngine = nil
        updatePromptHandler = nil
        isRecording = false
        isProcessing = false
        statusMessage = String(localized: "Dictation failed")
        lastErrorMessage = message
    }
}

private struct HermesWhisperTranscriptionRequest: Encodable {
    let type: String
    let id: String
    let language: String
    let audio: String
}

private struct HermesWhisperTranscriptionResponse: Decodable {
    let type: String
    let id: String?
    let position: Int?
    let model: String?
    let language: String?
    let text: String?
    let fullText: String?
    let message: String?
}

private enum HermesSpeechToTextError: LocalizedError {
    case invalidWhisperURL
    case invalidWhisperPayload

    var errorDescription: String? {
        switch self {
        case .invalidWhisperURL:
            "The Whisper WebSocket URL is invalid."
        case .invalidWhisperPayload:
            "Could not encode the Whisper transcription request."
        }
    }
}
