import AppKit
import UniformTypeIdentifiers

enum DestinationError: Error, LocalizedError {
    case invalidImageData
    case saveFailed(underlying: Error)
    case noTiffRepresentation
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .saveFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        case .noTiffRepresentation:
            return "Could not create image representation"
        }
    }
}

class DestinationManager {
    static let shared = DestinationManager()
    
    private init() {}
    
    func saveImage(_ image: NSImage, format: ImageFormat, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw DestinationError.noTiffRepresentation
        }
        
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpg {
            properties[.compressionFactor] = 0.9
        }
        
        guard let imageData = bitmapRep.representation(using: format.bitmapType, properties: properties) else {
            throw DestinationError.invalidImageData
        }
        
        do {
            try imageData.write(to: url)
        } catch {
            throw DestinationError.saveFailed(underlying: error)
        }
    }
    
    func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    func generateFileName(pattern: String, format: ImageFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH.mm.ss"
        let timeString = timeFormatter.string(from: Date())
        
        var fileName = pattern
            .replacingOccurrences(of: "{date}", with: dateString)
            .replacingOccurrences(of: "{time}", with: timeString)
            .replacingOccurrences(of: "{timestamp}", with: "\(Int(Date().timeIntervalSince1970))")
        
        if !fileName.hasSuffix(".\(format.fileExtension)") {
            fileName += ".\(format.fileExtension)"
        }
        
        return fileName
    }
    
    func defaultSaveDirectory() -> URL {
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktopURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    func promptSaveLocation(for image: NSImage, suggestedName: String) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = ImageFormat.allCases.map { $0.utType }
        savePanel.nameFieldStringValue = suggestedName
        savePanel.directoryURL = defaultSaveDirectory()
        savePanel.canCreateDirectories = true
        
        let response = savePanel.runModal()
        
        if response == .OK {
            return savePanel.url
        }
        
        return nil
    }
}
