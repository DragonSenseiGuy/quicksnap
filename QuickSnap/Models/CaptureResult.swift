import AppKit

/// Represents the result of a capture operation.
/// Contains the captured content (image or video) along with metadata.
struct CaptureResult {
    /// The captured image, nil for video captures.
    let image: NSImage?
    
    /// The URL to the recorded video file, nil for image captures.
    let videoURL: URL?
    
    /// The date and time when the capture was taken.
    let timestamp: Date
    
    /// The screen region that was captured, nil for full screen captures.
    let region: CGRect?
    
    /// Returns true if this result contains a video capture.
    var isVideo: Bool {
        videoURL != nil
    }
    
    /// Returns true if this result contains an image capture.
    var isImage: Bool {
        image != nil
    }
    
    /// Convenience initializer for screenshot results
    init(image: NSImage?, videoURL: URL? = nil, timestamp: Date = Date(), region: CGRect? = nil) {
        self.image = image
        self.videoURL = videoURL
        self.timestamp = timestamp
        self.region = region
    }
}
