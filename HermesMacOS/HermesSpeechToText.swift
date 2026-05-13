//
//  HermesSpeechToText.swift
//  HermesMacOS
//

@preconcurrency import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class HermesSpeechToTextSession {
    var isRecording = false
    var statusMessage = ""
    var lastErrorMessage = ""

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var basePrompt = ""
    private var finalizedTranscript = ""
    private var volatileTranscript = ""

    var buttonTitle: String { isRecording ? String(localized: "Stop dictation") : String(localized: "Dictate prompt") }
    var buttonSystemImage: String { isRecording ? "mic.fill" : "mic" }

    func toggleTranscription(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stopTranscription()
        } else {
            startTranscription(currentPrompt: currentPrompt, updatePrompt: updatePrompt)
        }
    }

    func startTranscription(currentPrompt: String, updatePrompt: @escaping @MainActor (String) -> Void) {
        stopTranscription()
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
                    }
                    return
                }

                guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                    await MainActor.run {
                        self.statusMessage = String(localized: "Dictation unavailable")
                        self.lastErrorMessage = String(localized: "SpeechTranscriber does not support the current locale.")
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

    func stopTranscription() {
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
        if isRecording {
            finishCleanly()
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
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
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
        isRecording = false
        statusMessage = String(localized: "Dictation failed")
        lastErrorMessage = message
    }
}
