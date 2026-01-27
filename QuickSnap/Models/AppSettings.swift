import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Supported image formats for screenshot exports.
enum ImageFormat: String, CaseIterable {
    case png = "png"
    case jpg = "jpg"
    case tiff = "tiff"
    
    /// The file extension for this format.
    var fileExtension: String {
        rawValue
    }
    
    /// The UTType identifier for this format.
    var utType: UTType {
        switch self {
        case .png:
            return .png
        case .jpg:
            return .jpeg
        case .tiff:
            return .tiff
        }
    }
    
    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .png:
            return "PNG"
        case .jpg:
            return "JPEG"
        case .tiff:
            return "TIFF"
        }
    }
    
    /// The NSBitmapImageRep file type for this format.
    var bitmapType: NSBitmapImageRep.FileType {
        switch self {
        case .png:
            return .png
        case .jpg:
            return .jpeg
        case .tiff:
            return .tiff
        }
    }
}

/// Supported video formats for screen recording exports.
enum VideoFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"
    
    /// The file extension for this format.
    var fileExtension: String {
        rawValue
    }
    
    /// The UTType identifier for this format.
    var utType: UTType {
        switch self {
        case .mp4:
            return .mpeg4Movie
        case .mov:
            return .quickTimeMovie
        }
    }
    
    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .mp4:
            return "MP4"
        case .mov:
            return "QuickTime (MOV)"
        }
    }
}

/// Observable settings class that persists user preferences using @AppStorage.
/// Manages all configurable options for the QuickSnap application.
@MainActor
class AppSettings: ObservableObject {
    /// Shared singleton instance for app-wide access.
    static let shared = AppSettings()
    
    // MARK: - File Settings
    
    /// The default directory where captures are saved.
    @AppStorage("defaultSaveLocation") private var defaultSaveLocationPath: String = {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return picturesURL.appendingPathComponent("QuickSnap").path
    }()
    
    /// Computed property to access the save location as a URL.
    var defaultSaveLocation: URL {
        get {
            URL(fileURLWithPath: defaultSaveLocationPath)
        }
        set {
            defaultSaveLocationPath = newValue.path
        }
    }
    
    /// The format to use when saving screenshots.
    @AppStorage("imageFormat") var imageFormatRaw: String = ImageFormat.png.rawValue
    
    /// Computed property to access the image format as an enum.
    var imageFormat: ImageFormat {
        get {
            ImageFormat(rawValue: imageFormatRaw) ?? .png
        }
        set {
            imageFormatRaw = newValue.rawValue
        }
    }
    
    /// The format to use when saving screen recordings.
    @AppStorage("videoFormat") var videoFormatRaw: String = VideoFormat.mov.rawValue
    
    /// Computed property to access the video format as an enum.
    var videoFormat: VideoFormat {
        get {
            VideoFormat(rawValue: videoFormatRaw) ?? .mp4
        }
        set {
            videoFormatRaw = newValue.rawValue
        }
    }
    
    /// Pattern for naming captured files. Supports {date} and {time} placeholders.
    @AppStorage("fileNamingPattern") var fileNamingPattern: String = "Screenshot {date} at {time}"
    
    // MARK: - Editor Settings
    
    /// Whether to automatically open the editor after capturing.
    @AppStorage("autoOpenEditor") var autoOpenEditor: Bool = true
    
    // MARK: - OCR Settings
    
    /// Whether OCR functionality is enabled.
    @AppStorage("enableOCR") var enableOCR: Bool = true
    
    /// Whether to automatically copy recognized text to clipboard.
    @AppStorage("ocrAutoClipboard") var ocrAutoClipboard: Bool = true
    
    /// The language code for OCR recognition (e.g., "en-US").
    @AppStorage("ocrLanguage") var ocrLanguage: String = "en-US"
    
    // MARK: - Quick Actions Settings
    
    /// Whether to show the quick actions panel after capture.
    @AppStorage("showQuickActions") var showQuickActions: Bool = true
    
    /// How long the quick actions panel remains visible (in seconds).
    @AppStorage("quickActionDuration") var quickActionDuration: Double = 5.0
    
    // MARK: - Sound Settings
    
    /// Whether to play a sound when capturing.
    @AppStorage("playCaptureSound") var playCaptureSound: Bool = true
    
    // MARK: - Initialization
    
    init() {
        ensureSaveDirectoryExists()
    }
    
    /// Ensures the default save directory exists, creating it if necessary.
    private func ensureSaveDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: defaultSaveLocationPath) {
            try? fileManager.createDirectory(
                at: defaultSaveLocation,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
