import SwiftUI
import ScreenCaptureKit

class ScreenCaptureService: ObservableObject {
    @Published var isCapturing = false
    @Published var isRecording = false
    @Published var lastCaptureResult: CaptureResult?
    
    private var regionSelectorController: RegionSelectorWindowController?
    
    func captureFullScreen() {
        isCapturing = true
        
        Task { @MainActor in
            defer { isCapturing = false }
            
            guard let screen = NSScreen.main else { return }
            
            let image = CGWindowListCreateImage(
                screen.frame,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            )
            
            if let cgImage = image {
                let nsImage = NSImage(cgImage: cgImage, size: screen.frame.size)
                lastCaptureResult = CaptureResult(
                    image: nsImage,
                    videoURL: nil,
                    timestamp: Date(),
                    region: nil
                )
            }
        }
    }
    
    func captureRegion() {
        isCapturing = true
        
        regionSelectorController = RegionSelectorWindowController()
        regionSelectorController?.onRegionSelected = { [weak self] rect, screen in
            self?.captureRect(rect, on: screen)
        }
        regionSelectorController?.onCancelled = { [weak self] in
            self?.isCapturing = false
        }
        regionSelectorController?.showSelector()
    }
    
    private func captureRect(_ rect: CGRect, on screen: NSScreen) {
        let screenRect = CGRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        let image = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
        
        if let cgImage = image {
            let nsImage = NSImage(cgImage: cgImage, size: rect.size)
            lastCaptureResult = CaptureResult(
                image: nsImage,
                videoURL: nil,
                timestamp: Date(),
                region: rect
            )
        }
        
        isCapturing = false
    }
    
    func recordFullScreen() {
        isRecording = true
        // TODO: Implement full screen recording using ScreenCaptureKit
    }
    
    func recordRegion() {
        isRecording = true
        // TODO: Implement region recording using ScreenCaptureKit
    }
    
    func stopRecording() {
        isRecording = false
        // TODO: Stop the recording and save the file
    }
    
    func ocrCapture() {
        captureRegion()
        // TODO: After capture, perform OCR on the captured image
    }
}
