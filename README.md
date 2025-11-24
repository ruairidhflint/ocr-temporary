# Receipt OCR Scanner

An iPhone app built with Xcode that uses on-device OCR (Optical Character Recognition) to scan and extract text from receipts using the camera.

## Features

- 📷 Real-time camera capture
- 🔍 On-device OCR using Apple's Vision framework
- 📄 Text extraction from receipts
- 💾 Display extracted text in a clean interface
- 🎯 Visual scanning guide to help position receipts

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Physical iPhone device (camera functionality requires a real device)
- Camera permission (will be requested on first launch)

## Setup Instructions

1. **Open the Project**
   - Open `OCRTest.xcodeproj` in Xcode

2. **Configure Signing** (Required Step!)
   
   **Step-by-step:**
   - In Xcode's left sidebar (Project Navigator), click on the blue "OCRTest" project icon at the very top
   - In the main editor area, you'll see "PROJECT" and "TARGETS" sections
   - Under "TARGETS", click on "OCRTest" (the app target, not the project)
   - Click on the "Signing & Capabilities" tab at the top
   - Check the box that says **"Automatically manage signing"**
   - In the "Team" dropdown, select your Apple ID
     - If you don't see your Apple ID, click "Add Account..." and sign in with your Apple ID
     - A free Apple ID works for personal development/testing
   - Xcode will automatically create a provisioning profile
   - You should see a green checkmark ✅ when signing is configured correctly
   
   **Note:** If you don't have a paid Apple Developer account, that's fine! A free Apple ID allows you to:
   - Test on your own devices
   - Install apps via Xcode
   - Use all development features (just not App Store distribution)

3. **Connect Your iPhone**
   - Connect your iPhone to your Mac via USB cable
   - Unlock your iPhone
   - If prompted, tap "Trust This Computer" on your iPhone
   - Wait for Xcode to recognize your device

4. **Build and Run**
   - In Xcode, select your iPhone from the device menu (next to the Play button at the top)
   - Click the Run button (⌘R) or press the Play button
   - Xcode will build the app and install it on your device
   - The app will launch automatically on your iPhone

5. **Grant Permissions**
   - On first launch, the app will request camera permission
   - Tap "Allow" to enable camera access
   - If you accidentally denied permission, go to iPhone Settings > Privacy & Security > Camera > OCRTest and enable it

## How to Use

1. Launch the app on your iPhone
2. Tap "Scan Receipt" button
3. Point your camera at a receipt
4. Position the receipt within the blue scanning frame
5. The app will automatically detect and extract text
6. View the extracted text on the main screen
7. Tap "Scan Again" to scan another receipt

## Technical Details

### Architecture
- **SwiftUI** for the user interface
- **AVFoundation** for camera capture
- **Vision Framework** for on-device OCR processing
- **UIKit** integration for camera view controller

### Key Components

- `OCRTestApp.swift`: Main app entry point
- `ContentView.swift`: Main UI with text display
- `CameraView.swift`: SwiftUI wrapper for camera functionality
- `CameraViewController.swift`: UIKit view controller handling camera capture
- `OCRProcessor.swift`: Vision framework integration for text recognition

### OCR Configuration
- Uses `VNRecognizeTextRequest` with accurate recognition level
- Language correction enabled for better results
- Custom word dictionary for common receipt terms
- Processes frames at 0.5-second intervals to balance performance and accuracy

## Notes

- OCR processing happens entirely on-device (no internet required)
- The app processes video frames in real-time to detect text
- Text extraction is automatic when sufficient text is detected
- Works best with clear, well-lit receipts

## Testing

### ⚠️ Important: Physical Device Required

**You CANNOT test this app on the iOS Simulator** because:
- The iOS Simulator does not have a camera
- Camera functionality requires a real iPhone device
- The app will crash or fail to open the camera on simulator

### Testing Steps

1. **Connect your iPhone** to your Mac via USB
2. **Select your device** in Xcode's device menu
3. **Build and run** (⌘R)
4. **Test the camera**:
   - Tap "Scan Receipt"
   - Point at a receipt or any text document
   - Hold steady and wait for text detection
   - The app automatically extracts text when detected

### Testing Tips

- **Good lighting**: Test in a well-lit area for best OCR results
- **Steady hands**: Hold the phone steady while scanning
- **Clear text**: Use receipts or documents with clear, printed text
- **Distance**: Hold the phone about 6-12 inches from the document
- **Focus**: Wait for the camera to autofocus before expecting results

## Troubleshooting

- **Camera not working**: 
  - Ensure you're testing on a physical device (simulator doesn't support camera)
  - Check that camera permission was granted in Settings
  - Try disconnecting and reconnecting your device
  
- **No text detected**: 
  - Try improving lighting conditions
  - Hold the camera steady for a few seconds
  - Ensure the receipt is in focus (wait for autofocus)
  - Try moving closer or further from the document
  - Make sure the text is clear and not blurry
  
- **"Signing requires a development team" error**: 
  - Follow the detailed signing instructions in step 2 above
  - Make sure you've selected the "OCRTest" **target** (not just the project)
  - Ensure "Automatically manage signing" is checked
  - Select your Apple ID from the Team dropdown (add it if needed)
  - Wait a few seconds for Xcode to configure signing
  - If you see errors, try: Product > Clean Build Folder, then try again
  
- **Build errors**: 
  - Make sure you have selected a valid development team in Signing & Capabilities
  - Ensure your iPhone is unlocked and trusted
  - Check that your device is running iOS 17.0 or later
  - Try Product > Clean Build Folder if you see persistent errors
  
- **App won't install**: 
  - Verify your Apple ID has developer capabilities (free account works for personal testing)
  - Check that your device is registered in your Apple Developer account
  - Try cleaning the build folder (Product > Clean Build Folder)

## License

This project is provided as-is for demonstration purposes.

