//
//  Config.swift
//  OCRTest
//
//  Created on iOS
//

import Foundation

struct Config {
    // TODO: Replace with your OpenAI API key
    // You can also set this via environment variable or secure storage
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY_HERE"
    
    // Check if API key is configured
    static var isAPIKeyConfigured: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY_HERE"
    }
}

