//
//  OpenAIService.swift
//  OCRTest
//
//  Created on iOS
//

import Foundation

struct OpenAIResponse: Codable {
    let vendor: String?
    let total: Double?
    let tax: Double?
    let date: String?
    let currency: String?
}

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func extractReceiptData(from ocrText: String) async throws -> OpenAIResponse {
let prompt = """
You are an expert receipt OCR parser. The following text comes from very noisy mobile OCR (random line breaks, missing spaces, character errors like 0/O, S/5, etc.). Your task is to extract exactly these fields and return ONLY a valid JSON object.

Extract:
1. Vendor/Store name – the business name at the top or most prominent
2. Total amount – the final amount due/paid (look for words like Total, Amount Due, Balance Due, Paid, Cash, Card, TOTAL, AMOUNT, SUBTOTAL + TAX if separate)
3. Tax/VAT amount – look for Tax, VAT, GST, HST, Sales Tax, MWST, IVA, TVA, BTW, etc. (can be separate line or added to subtotal)
4. Date – any recognizable date, prefer the transaction/purchase date
5. Currency – the ISO 4217 currency code (e.g. USD, GBP, EUR, CAD)

Rules:
- Currency Inference:
   → Look for explicit symbols ($, €, £, ¥, etc.) or codes (USD, EUR, GBP, etc.).
   → CRITICAL: If NO symbol/code is found, infer the currency from the address, city, country, or phone number format found in the text.
     • Example: "London", "UK", "Ltd" → GBP
     • Example: "Paris", "France", "GmbH", "S.A." → EUR
     • Example: "NY", "USA", "+1 (555)" → USD
     • Example: "Toronto", "Canada" → CAD
   → If ambiguous, use the most likely currency for the detected language/location.
- Date Format:
   → $ / USD / English US-style → use MM/DD/YYYY
   → € / £ / other languages → use DD/MM/YYYY
   → If ambiguous, prefer the format that makes the date valid (e.g. 13/04/2025 is valid, 04/13/2025 would be invalid if day > 12)
- Clean numbers: remove any letters stuck to numbers (e.g. "T0tal" → Total, "12O.50" → 120.50, "12,50" → 12.50 if € context)
- Comma vs dot: in €/£ contexts, comma is decimal; in $ it's thousands
- If total is not explicitly labeled, use the largest amount near the bottom or the one after "Total", "Amount Due", etc.
- Return numbers as plain decimals (e.g. 42.90, 1099.00), never with currency symbols or thousands separators
- If uncertain or missing → use null

Return ONLY this valid JSON (no trailing commas, no comments, no explanations):

{
  "vendor": "string or null",
  "total": number or null,
  "tax": number or null,
  "date": "MM/DD/YYYY" or "DD/MM/YYYY" or null,
  "currency": "ISO_CODE" or null
}

OCR Text (very messy – tolerate noise):
\(ocrText)
"""
        
let requestBody: [String: Any] = [
    "model": "gpt-4o",  // or better: "gpt-4o" if you can afford it
    "messages": [
        ["role": "system", "content": "You are a precise receipt data extraction expert. Always return clean, valid JSON only."],
        ["role": "user", "content": prompt]
    ],
    "temperature": 0.0,        // ← Critical: 0.0 for consistency
    "max_tokens": 300,         // 200 was sometimes cutting off
    "top_p": 1,
    "frequency_penalty": 0,
    "presence_penalty": 0
]
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        let openAIResponse = try decoder.decode(OpenAIChatResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        // Parse the JSON response from the content
        return try parseJSONResponse(content)
    }
    
    private func parseJSONResponse(_ content: String) throws -> OpenAIResponse {
        // Clean the content - remove markdown code blocks if present
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = String(cleanedContent.dropFirst(7))
        } else if cleanedContent.hasPrefix("```") {
            cleanedContent = String(cleanedContent.dropFirst(3))
        }
        
        if cleanedContent.hasSuffix("```") {
            cleanedContent = String(cleanedContent.dropLast(3))
        }
        
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedContent.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAIResponse.self, from: data)
    }
}

// MARK: - Response Models

struct OpenAIChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error \(statusCode): \(message)"
        case .noContent:
            return "No content in response"
        case .invalidJSON:
            return "Failed to parse JSON response"
        }
    }
}

