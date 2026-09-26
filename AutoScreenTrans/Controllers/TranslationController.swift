//
//  TranslationController.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/25/26.
//

// This class is not used because we decided to use Qwen 2.5(MLX) for translation.
// However, the code is retained for future extensions.

import Foundation
import Translation

enum TranslationError: Error {
    case translationFailed(Error)
}

final class TranslationController {
    @available(macOS 15.0, *)
    func translateText(text: String,
                       from sourceLanguage: Locale.Language = Locale.Language(identifier: "ja"),
                       to targetLanguage: Locale.Language = Locale.Language(identifier: "ko")) async throws -> String {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        
        let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
        
        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            throw TranslationError.translationFailed(error)
        }
    }
}

