import Foundation

/// Represents the different capture modes available in QuickSnap.
/// Each mode defines a specific type of screen capture operation.
enum CaptureMode: String, CaseIterable {
    case fullScreenshot = "fullScreenshot"
    case regionScreenshot = "regionScreenshot"
    case fullRecording = "fullRecording"
    case regionRecording = "regionRecording"
    case ocrCapture = "ocrCapture"
    
    /// Human-readable display name for the capture mode.
    var displayName: String {
        switch self {
        case .fullScreenshot:
            return "Full Screenshot"
        case .regionScreenshot:
            return "Region Screenshot"
        case .fullRecording:
            return "Full Screen Recording"
        case .regionRecording:
            return "Region Recording"
        case .ocrCapture:
            return "OCR Capture"
        }
    }
    
    /// Default keyboard shortcut description for the capture mode.
    var shortcutKey: String {
        switch self {
        case .fullScreenshot:
            return "⌘⇧3"
        case .regionScreenshot:
            return "⌘⇧4"
        case .fullRecording:
            return "⌘⇧5"
        case .regionRecording:
            return "⌘⇧6"
        case .ocrCapture:
            return "⌘⇧7"
        }
    }
}
