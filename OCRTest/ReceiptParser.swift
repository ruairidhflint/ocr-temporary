//
//  ReceiptParser.swift
//  OCRTest
//
//  Created on iOS
//

import Foundation
import NaturalLanguage

class ReceiptParser {
    
    func parseReceipt(from text: String) -> ReceiptData {
        var receipt = ReceiptData(rawText: text)
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // Only extract the three required fields: Vendor, Date, Total
        
        // Extract vendor (usually first line or organization entity)
        receipt.vendor = extractVendor(from: lines)
        
        // Extract date - prioritize header area
        let (date, _) = extractDateAndTime(from: text)
        receipt.date = date
        
        // Extract money amounts
        let moneyAmounts = extractMoneyAmounts(from: text)
        
        // Extract total only
        receipt.total = extractTotal(from: lines, moneyAmounts: moneyAmounts)
        
        return receipt
    }
    
    // MARK: - Validation
    
    private func validateTotals(_ receipt: inout ReceiptData) {
        // Validation logic removed - ReceiptData no longer has subtotal field
        // OpenAI handles validation in its response
    }
    
    // MARK: - Vendor Extraction
    
    private func extractVendor(from lines: [String]) -> String? {
        // Receipt structure: Vendor name is typically in the first 1-3 lines
        // Skip lines that are clearly not vendor names
        
        let skipPatterns = [
            #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,  // Dates
            #"^\d{1,2}:\d{2}"#,                    // Times
            #"^\$?\d+\.?\d*$"#,                    // Just numbers
            #"phone|tel|fax"#,                      // Contact info
            #"@.*\.(com|net|org)"#,                // Email addresses
            #"www\."#,                             // Websites
            #"^\d{3}[-.\s]?\d{3}[-.\s]?\d{4}"#,   // Phone numbers
            #"^receipt|^invoice"#,                 // Document type
        ]
        
        // Check first 3 lines for vendor name
        for (index, line) in lines.prefix(3).enumerated() {
            // Skip if matches any skip pattern
            let shouldSkip = skipPatterns.contains { line.matches(pattern: $0) }
            if shouldSkip {
                continue
            }
            
            // Vendor name characteristics:
            // - Usually 2-6 words
            // - Often has capitalized words
            // - Not too long (usually < 50 chars)
            // - Doesn't contain common receipt keywords
            let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let lowercased = line.lowercased()
            
            // Skip if contains receipt keywords
            let receiptKeywords = ["total", "subtotal", "tax", "amount", "date", "time", "item", "qty", "quantity"]
            if receiptKeywords.contains(where: { lowercased.contains($0) }) {
                continue
            }
            
            // Good vendor name candidate
            if words.count >= 1 && words.count <= 6 && line.count < 60 && line.count > 2 {
                // Prefer lines with some capitalization (business names)
                let capitalizedCount = words.filter { $0.first?.isUppercase == true }.count
                if capitalizedCount >= 1 || index == 0 {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Fallback: Try Natural Language for organization names
        let text = lines.prefix(5).joined(separator: " ")
        let entities = extractNamedEntities(from: text, types: [.organizationName])
        if let organization = entities.first, organization.count < 60 {
            return organization
        }
        
        return nil
    }
    
    // MARK: - Date and Time Extraction
    
    private func extractDateAndTime(from text: String) -> (date: String?, time: String?) {
        var date: String? = nil
        var time: String? = nil
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Strategy: Look for dates near "Date:" labels first, then fall back to pattern matching
        // Receipts typically have date/time in the header area (first 5-10 lines)
        
        // First, look for explicit "Date:" or "Time:" labels
        for line in lines.prefix(10) {
            let lowercased = line.lowercased()
            
            // Check for "Date:" label
            if lowercased.contains("date") && lowercased.contains(":") {
                // Extract date after the colon
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !afterColon.isEmpty {
                        // Try to extract just the date part (before time if present)
                        let dateTimeParts = afterColon.components(separatedBy: .whitespaces)
                        for part in dateTimeParts {
                            if part.contains(":") && time == nil {
                                time = part
                            } else if !part.contains(":") && date == nil && part.matches(pattern: #"\d"#) {
                                date = part
                            }
                        }
                        if date == nil && !afterColon.isEmpty {
                            date = afterColon
                        }
                    }
                }
            }
            
            // Check for "Time:" label
            if lowercased.contains("time") && lowercased.contains(":") && time == nil {
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if afterColon.contains(":") {
                        time = afterColon
                    }
                }
            }
        }
        
        // If no explicit date label found, use NSDataDetector on header area
        if date == nil {
            let headerText = lines.prefix(10).joined(separator: " ")
            do {
                let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
                let matches = detector.matches(in: headerText, options: [], range: NSRange(location: 0, length: headerText.utf16.count))
                
                // Prefer dates that look like receipt dates (not expiration dates, etc.)
                for match in matches {
                    if let dateRange = Range(match.range, in: headerText) {
                        let dateString = String(headerText[dateRange])
                        // Skip if it's clearly an expiration date or similar
                        let lowercased = dateString.lowercased()
                        if lowercased.contains("exp") || lowercased.contains("valid") {
                            continue
                        }
                        
                        // Split date and time if both present
                        if dateString.contains(":") {
                            let components = dateString.components(separatedBy: " ")
                            for component in components {
                                if component.contains(":") && time == nil {
                                    time = component
                                } else if !component.contains(":") && date == nil {
                                    date = component
                                }
                            }
                            if date == nil {
                                date = dateString
                            }
                        } else {
                            date = dateString
                        }
                        break
                    }
                }
            } catch {
                // Fall through to pattern matching
            }
        }
        
        // Pattern matching for dates as fallback (MM/DD/YYYY, DD/MM/YYYY, etc.)
        if date == nil {
            let headerText = lines.prefix(10).joined(separator: " ")
            let datePatterns = [
                #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,
                #"\d{4}[/-]\d{1,2}[/-]\d{1,2}"#,
                #"[A-Z][a-z]+\s+\d{1,2},?\s+\d{4}"#
            ]
            
            for pattern in datePatterns {
                if let match = headerText.firstMatch(pattern: pattern) {
                    date = match
                    break
                }
            }
        }
        
        // Pattern matching for time (HH:MM, H:MM AM/PM) as fallback
        if time == nil {
            let headerText = lines.prefix(10).joined(separator: " ")
            let timePatterns = [
                #"\d{1,2}:\d{2}\s*(AM|PM|am|pm)?"#,
                #"\d{1,2}:\d{2}:\d{2}"#
            ]
            
            for pattern in timePatterns {
                if let match = headerText.firstMatch(pattern: pattern) {
                    time = match
                    break
                }
            }
        }
        
        return (date, time)
    }
    
    // MARK: - Money Amount Extraction
    
    private func extractMoneyAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        
        // Pattern matching for money ($XX.XX, XX.XX, etc.)
        // This pattern matches:
        // - Optional dollar sign
        // - Numbers with optional thousands separators (commas)
        // - Optional decimal point with 2 digits
        let moneyPattern = #"\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        let matches = text.allMatches(pattern: moneyPattern)
        
        for match in matches {
            let cleaned = match.replacingOccurrences(of: "$", with: "")
                              .replacingOccurrences(of: ",", with: "")
                              .trimmingCharacters(in: .whitespaces)
            if let amount = Double(cleaned), amount > 0 {
                // Avoid duplicates (within 0.01 tolerance for floating point)
                let isDuplicate = amounts.contains { abs($0 - amount) < 0.01 }
                if !isDuplicate {
                    amounts.append(amount)
                }
            }
        }
        
        return amounts.sorted()
    }
    
    private func parseMoneyAmount(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "")
                         .replacingOccurrences(of: ",", with: "")
                         .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
    
    // MARK: - Total, Subtotal, Tax Extraction
    
    private func extractTotal(from lines: [String], moneyAmounts: [Double]) -> Double? {
        // Strategy: Look for "Total" keyword, but be smart about it
        // Total is usually:
        // 1. On a line with "Total" keyword (not "Subtotal")
        // 2. Usually near the bottom of the receipt
        // 3. Usually the largest amount (but not always)
        // 4. Should be >= subtotal + tax
        
        var totalAmount: Double? = nil
        var totalLineIndex: Int? = nil
        
        // Search from bottom to top (totals are usually at bottom)
        for (index, line) in lines.enumerated().reversed() {
            let lowercased = line.lowercased()
            
            // Look for "Total" but not "Subtotal"
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                if let amount = extractAmountFromLine(line) {
                    totalAmount = amount
                    totalLineIndex = index
                    break
                }
            }
        }
        
        // If found explicit total, return it
        if let total = totalAmount {
            return total
        }
        
        // Fallback: Use the largest amount, but only if it's reasonable
        // (not a phone number, not too small, etc.)
        if let largest = moneyAmounts.last, largest >= 0.01 && largest < 100000 {
            // Make sure it's not likely a phone number or other number
            // (receipt totals are usually > $1.00)
            if largest >= 1.0 {
                return largest
            }
        }
        
        return nil
    }
    
    private func extractSubtotal(from lines: [String], moneyAmounts: [Double]) -> Double? {
        // Look for "Subtotal" keyword
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("subtotal") {
                if let amount = extractAmountFromLine(line) {
                    // Validate: subtotal should be less than total
                    return amount
                }
            }
        }
        return nil
    }
    
    private func extractTax(from lines: [String], moneyAmounts: [Double]) -> Double? {
        // Look for tax-related keywords
        let taxKeywords = ["tax", "vat", "gst", "hst", "sales tax"]
        
        for line in lines {
            let lowercased = line.lowercased()
            for keyword in taxKeywords {
                if lowercased.contains(keyword) {
                    if let amount = extractAmountFromLine(line) {
                        // Tax is usually a small amount relative to total
                        // Validate it's reasonable (not a huge number)
                        if amount >= 0 && amount < 10000 {
                            return amount
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func extractAmountFromLine(_ line: String) -> Double? {
        let moneyPattern = #"\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        if let match = line.firstMatch(pattern: moneyPattern) {
            return parseMoneyAmount(match)
        }
        return nil
    }
    
    // MARK: - Payment Method Extraction
    
    private func extractPaymentMethod(from text: String) -> String? {
        let lowercased = text.lowercased()
        let paymentMethods = ["cash", "credit", "debit", "card", "visa", "mastercard", "amex", "apple pay", "paypal"]
        
        for method in paymentMethods {
            if lowercased.contains(method) {
                return method.capitalized
            }
        }
        return nil
    }
    
    // MARK: - Items Extraction
    
    // Items extraction removed - ReceiptData no longer has items field
    // OpenAI handles item extraction if needed in the future
    
    // MARK: - Natural Language Framework Helpers
    
    private func extractNamedEntities(from text: String, types: [NLTag]) -> [String] {
        var entities: [String] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, types.contains(tag) {
                entities.append(String(text[tokenRange]))
            }
            return true
        }
        
        return entities
    }
}

// MARK: - String Extensions for Pattern Matching

extension String {
    func matches(pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    func firstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: self.utf16.count)),
              let range = Range(match.range, in: self) else {
            return nil
        }
        return String(self[range])
    }
    
    func allMatches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: self.utf16.count))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }
}

