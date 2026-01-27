import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var captureService: ScreenCaptureService
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuBarButton(title: "Capture Full Screen", shortcut: "⌘⇧3") {
                captureService.captureFullScreen()
            }
            
            MenuBarButton(title: "Capture Region", shortcut: "⌘⇧4") {
                captureService.captureRegion(completion: nil)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            MenuBarButton(title: "Record Full Screen", shortcut: "⌘⇧5") {
                NotificationCenter.default.post(name: .triggerFullScreenRecording, object: nil)
            }
            
            MenuBarButton(title: "Record Region", shortcut: "⌘⇧6") {
                NotificationCenter.default.post(name: .triggerRegionRecording, object: nil)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            MenuBarButton(title: "OCR Capture", shortcut: "⌘⇧O") {
                captureService.ocrCapture { image in
                    guard let image = image else { return }
                    Task { @MainActor in
                        let ocrService = VisionOCRService()
                        do {
                            let result = try await ocrService.recognizeText(in: image, languages: [settings.ocrLanguage])
                            OCRResultWindowController.show(result: result)
                            if settings.ocrAutoClipboard {
                                ocrService.copyToClipboard(result.text)
                            }
                        } catch {
                            NotificationManager.shared.showError(message: "OCR failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            MenuBarButton(title: "Open Screenshots Folder", shortcut: nil) {
                openScreenshotsFolder()
            }
            
            MenuBarButton(title: "Preferences...", shortcut: "⌘,") {
                openPreferences()
            }
            
            Divider()
                .padding(.vertical, 4)
            
            MenuBarButton(title: "Quit QuickSnap", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
    }
    
    private func openScreenshotsFolder() {
        let folderURL = settings.defaultSaveLocation
        NSWorkspace.shared.open(folderURL)
    }
    
    private func openPreferences() {
        NotificationCenter.default.post(name: .openPreferences, object: nil)
    }
}

struct MenuBarButton: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundColor(isHovered ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(.horizontal, 4)
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}

#Preview {
    MenuBarView()
        .environmentObject(ScreenCaptureService())
        .environmentObject(AppSettings())
}
