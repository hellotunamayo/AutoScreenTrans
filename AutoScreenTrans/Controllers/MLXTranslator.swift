//
//  MLXTranslator.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/25/26.
//

import Foundation
import Combine

import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers

@MainActor
class MLXTranslator: ObservableObject {
    static let shared = MLXTranslator()
    
    @Published var isModelLoaded = false
    @Published var isTranslating = false
    @Published var loadingProgress: String = ""
    @Published var modelStatus: String = ""
    
    private var modelContainer: ModelContainer?
    private let modelId = "mlx-community/gemma-4-e2b-it-4bit"

    private init() {}
    
    func prepareModel() async {
        guard !isModelLoaded else {
            modelStatus = "Model is already loaded."
            return
        }
        
        let formattedModelFolder =
        "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        let snapshotsURL = homeDir.appendingPathComponent(
            ".cache/huggingface/hub/\(formattedModelFolder)/snapshots"
        )
        
        do {
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: snapshotsURL.path) else {
                modelStatus = "Cannot find model folder in local cache."
                print("Path does not exist: \(snapshotsURL.path)")
                return
            }
            
            let contents = try fileManager.contentsOfDirectory(
                at: snapshotsURL,
                includingPropertiesForKeys: nil
            )
            
            guard let actualModelURL = contents.first(where: {
                $0.hasDirectoryPath
            }) else {
                modelStatus = "Cannot find snapshot directory in local cache."
                return
            }
            
            print("Model route: \(actualModelURL.path)")
            
            let container = try await LLMModelFactory.shared.loadContainer(
                from: actualModelURL,
                using: #huggingFaceTokenizerLoader()
            )
            
            self.modelContainer = container
            self.isModelLoaded = true
            self.modelStatus = "Local model loaded."
            
        } catch {
            self.modelStatus =
            "Failed to load model: \(error.localizedDescription)"
            
            print("MLX Load Error Details: \(error)")
        }
    }
    
    func translate(
        sourceLanguage: String,
        targetLanguage: String,
        givenText: String,
        glossary: [String: String] = [:]
    ) async throws -> String {
        guard let container = modelContainer else {
            throw NSError(domain: "MLXTranslator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model is not ready."])
        }
        
        isTranslating = true
        defer { isTranslating = false }
        
        let glossaryText = glossary.map { "- \($0.key) => \($0.value)" }.joined(separator: "\n")
        

        var cleanedText = givenText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedText = cleanedText.replacingOccurrences(of: "■", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "●", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
        
        let systemPrompt = """
        <start_of_turn>user
        You are a professional video game translator specializing in JRPG localizations. 
        Your sole task is to translate \(targetLanguage) game dialogue into natural, expressive, spoken-style \(sourceLanguage) Hangul.
        
        [CRITICAL RULES]
        1. Your output must be 100% written in \(sourceLanguage) (Hangul) ONLY. NEVER include any English/Latin letters, \(targetLanguage) characters, or numbers in the final output.
        2. Maintain a natural, spoken dialogue style in \(sourceLanguage). Use an informal/casual tone (반말/대사체) unless the original text is explicitly polite.
        3. Automatically ignore or remove OCR noise and broken symbols (e.g., "■", "●").
        4. Strictly apply the term dictionary (glossary) provided below:
        \(glossaryText.isEmpty ? "(None)" : glossaryText)
        """
        
        let fullPrompt = """
        \(systemPrompt)
        [Actual Task]
        Source: \(cleanedText)
        Korean:<end_of_turn>
        <start_of_turn>model
        """
        
        print(fullPrompt)
        
        // Inference Parameters
        let generateParameters = GenerateParameters(
            maxTokens: 100, temperature: 0.1
        )
        
        // MLX GPU Inference
        let stream: AsyncStream = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: fullPrompt))
            
            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParameters,
                context: context
            )
        }
        
        var fullText = ""
        for await generation in stream {
            fullText += generation.chunk ?? ""
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
