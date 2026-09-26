//
//  MLXTranslator.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/25/26.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Combine

@MainActor
class MLXTranslator: ObservableObject {
    static let shared = MLXTranslator()
    
    @Published var isModelLoaded = false
    @Published var isTranslating = false
    @Published var loadingProgress: String = ""
    @Published var modelStatus: String = ""
    
    private var modelContainer: ModelContainer?
    
    // 1.5B: mlx-community/Qwen2.5-1.5B-Instruct-4bit (약 1.0GB)
    // 3B:   mlx-community/Qwen2.5-3B-Instruct-4bit (약 1.9GB)
    private let modelId = "mlx-community/Qwen2.5-3B-Instruct-4bit"
    
    private init() {}
    
    func prepareModel() async {
        guard !isModelLoaded else {
            modelStatus = "Please download the 'mlx-community/Qwen2.5-3B-Instruct-4bit' model from Hugging Face."
            return
        }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let snapshotsURL = homeDir.appendingPathComponent(".cache/huggingface/hub/models--mlx-community--Qwen2.5-3B-Instruct-4bit/snapshots")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil)
            
            // Finding model snapshots
            guard let actualModelURL = contents.first(where: { $0.hasDirectoryPath }) else {
                modelStatus = "Cannot find model in local cache."
                print("Cannot find model in local cache.")
                return
            }
            
            print("Model route: \(actualModelURL.path)")
            
            // Loading MLX
            let config = ModelConfiguration(directory: actualModelURL)
            self.modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
            
            self.isModelLoaded = true
            modelStatus = "Local model loaded."
        } catch {
            modelStatus = "Failed to load model: \(error.localizedDescription)"
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
        
        // Qwen2.5 Prompt Format (<|im_start|>)
        let systemPrompt = """
            You are a professional video game translator specializing in JRPG localizations.
            Translate the \(sourceLanguage) game dialogue into natural, expressive, spoken-style \(targetLanguage).

            Rules:
            1. Maintain a natural, spoken dialogue style in \(targetLanguage). Use informal/casual tone (반말/대사체) unless the original text is explicitly polite.
            2. Accurately convey emotional interjections, character energy, and punctuation.
            3. Strictly apply the term dictionary (glossary) provided below:
            \(glossaryText.isEmpty ? "(None)" : glossaryText)
            4. Output ONLY the translated \(targetLanguage) text without any explanation, markdown, or extra commentary.
        """
        
        let fullPrompt = """
        <|im_start|>system
        \(systemPrompt)
        <|im_end|>
        <|im_start|>user
        \(givenText)
        <|im_end|>
        <|im_start|>assistant
        """
        
        // Inference Parameters
        let generateParameters = GenerateParameters(
            maxTokens: 200, temperature: 0.1
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
