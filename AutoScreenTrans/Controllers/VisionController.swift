//
//  VisionController.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/24/26.
//

import Foundation
import AppKit
import Vision
import CoreImage

struct OCRResult {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

enum OCRError: Error {
    case invalidImage
    case recognitionFailed(Error)
}

final class VisionController {
    func performOCR(on image: NSImage, languages: [String] = ["ko-KR", "en-US", "ja-JP"]) async throws -> [OCRResult] {
        
        guard let cgImage = preprocessImageForOCR(nsImage: image) else {
            throw OCRError.invalidImage
        }
        
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                
                let results = observations.compactMap { observation -> OCRResult? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                
                continuation.resume(returning: results)
            }
            
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }
    
    private func preprocessImageForOCR(nsImage: NSImage) -> CGImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 1. Upsacle 3x (Lanczos Scale Transform 또는 Nearest Neighbor)
        let scaleTransform = CIFilter(name: "CILanczosScaleTransform")
        scaleTransform?.setValue(ciImage, forKey: kCIInputImageKey)
        scaleTransform?.setValue(3.0, forKey: kCIInputScaleKey) // 3배 확대
        scaleTransform?.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let scaledImage = scaleTransform?.outputImage else { return nil }
        
        // 2. Monotone + Increase contrast
        let controlsFilter = CIFilter(name: "CIColorControls")
        controlsFilter?.setValue(scaledImage, forKey: kCIInputImageKey)
        controlsFilter?.setValue(1.5, forKey: kCIInputContrastKey)
        
        guard let outputImage = controlsFilter?.outputImage else { return nil }
        
        let context = CIContext()
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}
