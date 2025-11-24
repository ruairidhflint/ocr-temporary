//
//  ContentView.swift
//  OCRTest
//
//  Created on iOS
//

import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var ocrText = ""
    @State private var receiptData: ReceiptData?
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    if let receipt = receiptData {
                        // Display structured receipt data
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Vendor
                                if let vendor = receipt.vendor {
                                    ReceiptField(label: "Vendor", value: vendor, icon: "building.2")
                                } else {
                                    ReceiptField(label: "Vendor", value: "Not found", icon: "building.2")
                                }
                                
                                // Date
                                if let date = receipt.date {
                                    ReceiptField(label: "Date", value: date, icon: "calendar")
                                } else {
                                    ReceiptField(label: "Date", value: "Not found", icon: "calendar")
                                }
                                
                                // Tax
                                if let tax = receipt.tax {
                                    ReceiptField(label: "Tax/VAT", value: formatCurrency(tax, currencyCode: receipt.currency), icon: "percent")
                                }
                                
                                // Total
                                if let total = receipt.total {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Total")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(formatCurrency(total, currencyCode: receipt.currency))
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                } else {
                                    ReceiptField(label: "Total", value: "Not found", icon: "dollarsign.circle")
                                }
                                
                                // Raw Text (collapsible)
                                DisclosureGroup("Raw OCR Text") {
                                    Text(receipt.rawText)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                                .padding(.top)
                            }
                            .padding()
                        }
                    } else if !ocrText.isEmpty {
                        // Display raw text if no structured data
                        ScrollView {
                            Text(ocrText)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Receipt OCR Scanner")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Point your camera at a receipt to extract data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(receiptData == nil ? "Scan Receipt" : "Scan Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .disabled(isProcessing)
                }
                
                // Loading overlay - appears on top of everything
                if isProcessing {
                    ProcessingOverlay()
                        .zIndex(1000)
                }
            }
            .navigationTitle("Receipt OCR")
            .sheet(isPresented: $showCamera) {
                CameraView(ocrText: $ocrText, receiptData: $receiptData, isProcessing: $isProcessing)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode ?? "$")\(String(format: "%.2f", amount))"
    }
}

// MARK: - Loading Animation View

struct ProcessingOverlay: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)
                }
                
                Text("Processing with AI...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Extracting receipt data")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .shadow(radius: 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
    }
}

struct ReceiptField: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ReceiptRow: View {
    let label: String
    let value: String
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .fontWeight(isTotal ? .bold : .regular)
                .font(isTotal ? .title3 : .body)
        }
    }
}

#Preview {
    ContentView()
}

