import SwiftUI
import ScreenCaptureKit

@MainActor
class ScreenCaptureService: ObservableObject {
    @Published var isCapturing = false
    @Published var isRecording = false
    @Published var lastCaptureResult: CaptureResult?
    
    private let regionSelector = RegionSelectorService.shared
    
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
    
    func captureRegion(completion: ((CaptureResult?) -> Void)? = nil) {
        isCapturing = true
        
        regionSelector.selectRegion { [weak self] region in
            guard let self = self else { return }
            
            guard let region = region else {
                self.isCapturing = false
                completion?(nil)
                return
            }
            
            self.captureSelectedRegion(region, completion: completion)
        }
    }
    
    private func captureSelectedRegion(_ region: SelectedRegion, completion: ((CaptureResult?) -> Void)? = nil) {
        let image = CGWindowListCreateImage(
            region.screenCaptureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
        
        if let cgImage = image {
            let nsImage = NSImage(cgImage: cgImage, size: region.rect.size)
            let result = CaptureResult(
                image: nsImage,
                videoURL: nil,
                timestamp: Date(),
                region: region.rect
            )
            lastCaptureResult = result
            isCapturing = false
            completion?(result)
        } else {
            isCapturing = false
            completion?(nil)
        }
    }
    
    func selectRegion(completion: @escaping (SelectedRegion?) -> Void) {
        regionSelector.selectRegion(completion: completion)
    }
    
    func ocrCapture(completion: @escaping (NSImage?) -> Void) {
        captureRegion { result in
            completion(result?.image)
        }
    }
}
