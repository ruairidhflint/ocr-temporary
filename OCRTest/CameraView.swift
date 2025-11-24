//
//  CameraView.swift
//  OCRTest
//
//  Created on iOS
//

import SwiftUI
import AVFoundation
import Vision

struct CameraView: UIViewControllerRepresentable {
    @Binding var ocrText: String
    @Binding var receiptData: ReceiptData?
    @Binding var isProcessing: Bool
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didExtractText(_ text: String) {
            // Store raw text
            DispatchQueue.main.async {
                self.parent.ocrText = text
            }
            
            // Process with OpenAI
            Task {
                await processWithOpenAI(text: text)
            }
        }
        
        @MainActor
        private func processWithOpenAI(text: String) async {
            guard Config.isAPIKeyConfigured else {
                // If no API key, just show raw text
                parent.isProcessing = false
                parent.dismiss()
                return
            }
            
            // Dismiss camera view first so animation is visible
            parent.dismiss()
            
            // Small delay to ensure sheet is dismissed
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Show loading state on main screen
            parent.isProcessing = true
            
            do {
                let service = OpenAIService(apiKey: Config.openAIAPIKey)
                let response = try await service.extractReceiptData(from: text)
                
                // Convert OpenAI response to ReceiptData
                let receiptData = ReceiptData(from: response, rawText: text)
                
                // Small delay for smooth transition
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                self.parent.receiptData = receiptData
                self.parent.isProcessing = false
            } catch {
                print("OpenAI Error: \(error.localizedDescription)")
                // On error, just show raw text
                self.parent.isProcessing = false
            }
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didExtractText(_ text: String)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    
    private var isProcessing = false
    private var captureButton: UIButton!
    private var processingIndicator: UIActivityIndicatorView!
    private var scanningFrame: UIView!
    
    // Scanning frame dimensions (relative to preview layer) - made bigger
    private let scanningFrameWidthRatio: CGFloat = 0.95
    private let scanningFrameHeightRatio: CGFloat = 0.7
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showError("Camera not available")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                showError("Could not add video input")
                return
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                showError("Could not add photo output")
                return
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Add overlay with scanning guide
            addScanningOverlay()
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
            
        } catch {
            showError("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    private func addScanningOverlay() {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add scanning frame
        scanningFrame = UIView()
        scanningFrame.layer.borderColor = UIColor.systemBlue.cgColor
        scanningFrame.layer.borderWidth = 2
        scanningFrame.backgroundColor = UIColor.clear
        scanningFrame.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(scanningFrame)
        
        NSLayoutConstraint.activate([
            scanningFrame.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            scanningFrame.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            scanningFrame.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: scanningFrameWidthRatio),
            scanningFrame.heightAnchor.constraint(equalTo: overlayView.heightAnchor, multiplier: scanningFrameHeightRatio)
        ])
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position text in view, then tap Capture"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: scanningFrame.bottomAnchor, constant: 20),
            instructionLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            instructionLabel.widthAnchor.constraint(equalToConstant: 280),
            instructionLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add capture button
        captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor.systemBlue
        captureButton.layer.cornerRadius = 35
        captureButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        overlayView.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 120),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Add processing indicator
        processingIndicator = UIActivityIndicatorView(style: .large)
        processingIndicator.color = .white
        processingIndicator.hidesWhenStopped = true
        processingIndicator.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(processingIndicator)
        
        NSLayoutConstraint.activate([
            processingIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 8
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        overlayView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func captureButtonTapped() {
        guard !isProcessing else { return }
        
        isProcessing = true
        captureButton.isEnabled = false
        captureButton.alpha = 0.6
        processingIndicator.startAnimating()
        
        let settings = AVCapturePhotoSettings()
        // Use the best available format (photoOutput will handle format selection)
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func processCapturedImage(_ image: UIImage) {
        // Process the entire image (no cropping)
        guard let cgImage = image.cgImage else {
            handleProcessingComplete(success: false)
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("OCR Error: \(error.localizedDescription)")
                self.handleProcessingComplete(success: false)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self.handleProcessingComplete(success: false)
                return
            }
            
            var extractedText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                extractedText += topCandidate.string + "\n"
            }
            
            let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.count >= 10 {
                DispatchQueue.main.async {
                    self.delegate?.didExtractText(trimmedText)
                    // Don't dismiss here - wait for OpenAI processing
                    // The delegate will handle dismissal after processing
                }
            } else {
                self.handleProcessingComplete(success: false)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error.localizedDescription)")
            handleProcessingComplete(success: false)
        }
    }
    
    private func handleProcessingComplete(success: Bool) {
        DispatchQueue.main.async {
            self.isProcessing = false
            self.captureButton.isEnabled = true
            self.captureButton.alpha = 1.0
            self.processingIndicator.stopAnimating()
            
            if !success {
                let alert = UIAlertController(
                    title: "No Text Detected",
                    message: "Could not detect text in the image. Please try again with better lighting and ensure the receipt is clearly visible.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })
            self.present(alert, animated: true)
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            handleProcessingComplete(success: false)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            handleProcessingComplete(success: false)
            return
        }
        
        // Process the captured image
        DispatchQueue.global(qos: .userInitiated).async {
            self.processCapturedImage(image)
        }
    }
}


