//
//  HermesNativeTranslationService.swift
//  HermesMacOS
//

import Foundation
import Observation
@preconcurrency import Translation

struct HermesChatTranslationSelection: Equatable, Sendable {
    let messageID: UUID
    let originalContent: String
    let selectedRange: NSRange

    var selectedText: String? {
        guard let range = Range(selectedRange, in: originalContent) else { return nil }
        let text = String(originalContent[range])
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}

@MainActor
@Observable
final class HermesNativeTranslationService {
    private(set) var selection: HermesChatTranslationSelection?
    private(set) var isTranslating = false
    private(set) var errorMessage = ""
    private(set) var configuration: TranslationSession.Configuration?

    private let english = Locale.Language(identifier: "en")

    func requestTranslation(messageID: UUID, content: String, selectedRange: NSRange, isMessageComplete: Bool) {
        guard !isTranslating else { return }
        errorMessage = ""
        guard isMessageComplete else {
            errorMessage = "Select text in a completed message before translating."
            return
        }

        let selection = HermesChatTranslationSelection(
            messageID: messageID,
            originalContent: content,
            selectedRange: selectedRange
        )
        guard selection.selectedText != nil else {
            errorMessage = "Select text in a completed message before translating."
            return
        }

        self.selection = selection
        isTranslating = true
        // SwiftUI owns the TranslationSession lifecycle so macOS can prepare
        // its on-device language resources before the translation begins.
        configuration = TranslationSession.Configuration(source: nil, target: english)
    }

    nonisolated func performTranslation(with session: sending TranslationSession, apply: @escaping @MainActor (HermesChatTranslationSelection, String) -> Bool) async {
        guard let selection = await currentSelection(), let selectedText = selection.selectedText else {
            await finish()
            return
        }

        do {
            let availability = try await LanguageAvailability().status(for: selectedText, to: english)
            guard availability != .unsupported else { throw HermesNativeTranslationError.unavailable }
            try await session.prepareTranslation()
            let response = try await session.translate(selectedText)
            let translatedText = Self.translatedTextPreservingEdgeWhitespace(
                from: selectedText,
                translated: response.targetText
            )
            guard !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HermesNativeTranslationError.emptyResult
            }
            guard await apply(selection, translatedText) else { throw HermesNativeTranslationError.messageChanged }
            await finish()
        } catch {
            await recordFailure(Self.userFacingMessage(for: error))
        }
    }

    func dismissError() { errorMessage = "" }

    private func currentSelection() -> HermesChatTranslationSelection? {
        selection
    }

    private func recordFailure(_ message: String) {
        errorMessage = message
        finish(keepingError: true)
    }

    private func finish(keepingError: Bool = false) {
        selection = nil
        isTranslating = false
        configuration = nil
        if !keepingError { errorMessage = "" }
    }

    nonisolated private static func translatedTextPreservingEdgeWhitespace(from source: String, translated: String) -> String {
        var leadingWhitespace = ""
        for character in source {
            guard character.isWhitespace else { break }
            leadingWhitespace.append(character)
        }

        var trailingWhitespaceReversed = ""
        for character in source.reversed() {
            guard character.isWhitespace else { break }
            trailingWhitespaceReversed.append(character)
        }

        let core = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        return leadingWhitespace + core + String(trailingWhitespaceReversed.reversed())
    }

    nonisolated private static func userFacingMessage(for error: Error) -> String {
        if error is CancellationError { return "Translation was cancelled. Try again." }
        if let translationError = error as? TranslationError {
            switch translationError {
            case .unableToIdentifyLanguage:
                return "macOS could not identify the selected language. The message was not changed."
            case .nothingToTranslate:
                return "Select text to translate. The message was not changed."
            case .unsupportedSourceLanguage, .unsupportedTargetLanguage, .unsupportedLanguagePairing, .notInstalled:
                return "Translation to English is unavailable for this selection. The message was not changed."
            default:
                return "Translation failed. The message was not changed. Try again."
            }
        }
        return "Translation failed. The message was not changed. Try again."
    }
}

private enum HermesNativeTranslationError: Error {
    case unavailable
    case emptyResult
    case messageChanged
}
