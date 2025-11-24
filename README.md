# Receipt OCR Scanner

An iPhone app that uses on-device OCR and OpenAI to extract structured data from receipts.

## Features

- 📷 Camera capture with manual trigger
- 🔍 On-device OCR using Apple's Vision framework
- 🤖 AI-powered parsing via OpenAI (extracts Vendor, Date, Tax, Total, Currency)
- ✨ Animated loading UI during processing
- 🌍 Automatic date format detection (US vs European)
- 💰 Multi-currency support

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Physical iPhone device (camera required)
- OpenAI API key

## Quick Setup

1. **Open Project**: Open `OCRTest.xcodeproj` in Xcode

2. **Add OpenAI API Key**: 
   - Open `OCRTest/Config.swift`
   - Replace `YOUR_OPENAI_API_KEY_HERE` with your OpenAI API key

3. **Configure Signing**:
   - Select project → Target "OCRTest" → Signing & Capabilities
   - Enable "Automatically manage signing"
   - Select your Apple ID/Team

4. **Build & Run**:
   - Connect iPhone via USB
   - Select device in Xcode
   - Press ⌘R to build and run
   - Grant camera permission when prompted

## Usage

1. Tap "Scan Receipt"
2. Position receipt in view
3. Tap "Capture" button when ready
4. Wait for AI processing (animated loading screen)
5. View extracted data: Vendor, Date, Tax, Total

## Technical Stack

- **SwiftUI** - User interface
- **AVFoundation** - Camera capture
- **Vision Framework** - On-device OCR
- **OpenAI API** - Receipt parsing (gpt-4o-mini)
- **UIKit** - Camera view controller

## Key Files

- `ContentView.swift` - Main UI and loading animation
- `CameraView.swift` - Camera capture interface
- `OpenAIService.swift` - OpenAI API integration
- `Config.swift` - API key configuration
- `ReceiptData.swift` - Data model

## Notes

- OCR happens on-device; parsing uses OpenAI API
- Date format auto-detected based on currency/language
- Works with receipts in multiple currencies (USD, EUR, GBP, etc.)
- Requires internet connection for OpenAI processing

## Troubleshooting

- **No animation**: Ensure camera view dismisses before processing starts
- **API errors**: Verify API key in `Config.swift` is correct
- **No text detected**: Improve lighting, hold steady, ensure receipt is in focus
- **Build errors**: Clean build folder (Product > Clean Build Folder)
