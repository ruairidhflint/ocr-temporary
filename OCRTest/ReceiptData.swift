//
//  ReceiptData.swift
//  OCRTest
//
//  Created on iOS
//

import Foundation

struct ReceiptData: Codable {
    var vendor: String?
    var date: String?
    var tax: Double?
    var total: Double?
    var currency: String?
    var rawText: String
    
    init(rawText: String) {
        self.rawText = rawText
    }
    
    init(from openAIResponse: OpenAIResponse, rawText: String) {
        self.vendor = openAIResponse.vendor
        self.date = openAIResponse.date
        self.tax = openAIResponse.tax
        self.total = openAIResponse.total
        self.currency = openAIResponse.currency
        self.rawText = rawText
    }
}

