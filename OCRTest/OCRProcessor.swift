//
//  OCRProcessor.swift
//  OCRTest
//
//  Created on iOS
//

import Vision
import CoreImage

class OCRProcessor {
    private let textRecognitionRequest: VNRecognizeTextRequest
    
    init() {
        textRecognitionRequest = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR Error: \(error.localizedDescription)")
                return
            }
        }
        
        // Configure for better accuracy on receipts
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.customWords = [
            "Total", "Subtotal", "Tax", "Amount", "Date", "Time",
            "Receipt", "Invoice", "Cash", "Credit", "Debit", "Change"
        ]
    }
    
    func processImage(pixelBuffer: CVPixelBuffer, completion: @escaping (String) -> Void) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        // Create a completion handler that extracts text
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }
            
            var extractedText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                extractedText += topCandidate.string + "\n"
            }
            
            // Only return text if we found a reasonable amount (at least 10 characters)
            if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 {
                completion(extractedText.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion("")
            }
        }
        
        // Configure request
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error.localizedDescription)")
            completion("")
        }
    }
}

