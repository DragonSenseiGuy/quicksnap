import Vision
import AppKit

struct OCRResult {
    let text: String
    let observations: [VNRecognizedTextObservation]
    let confidence: Float
    let processingTime: TimeInterval
}

enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case requestFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for text recognition"
        case .noTextFound:
            return "No text was found in the image"
        case .requestFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
class VisionOCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var recognizedText: String = ""
    @Published var confidence: Float = 0.0
    
    static var supportedLanguages: [String] {
        if #available(macOS 13.0, *) {
            let revision = VNRecognizeTextRequest.currentRevision
            do {
                return try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: revision)
            } catch {
                return ["en-US"]
            }
        } else {
            return (try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision2)) ?? ["en-US"]
        }
    }
    
    func recognizeText(
        in image: NSImage,
        languages: [String] = ["en-US"],
        level: VNRequestTextRecognitionLevel = .accurate
    ) async throws -> OCRResult {
        isProcessing = true
        defer { isProcessing = false }
        
        let startTime = Date()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.requestFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                
                let text = recognizedStrings.joined(separator: "\n")
                
                let totalConfidence = observations.reduce(Float(0)) { sum, observation in
                    sum + (observation.topCandidates(1).first?.confidence ?? 0)
                }
                let averageConfidence = totalConfidence / Float(observations.count)
                
                let processingTime = Date().timeIntervalSince(startTime)
                
                let result = OCRResult(
                    text: text,
                    observations: observations,
                    confidence: averageConfidence,
                    processingTime: processingTime
                )
                
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = level
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.requestFailed(error))
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
