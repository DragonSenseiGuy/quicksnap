import SwiftUI
import AppKit

@main
struct QuickSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var captureService = ScreenCaptureService()
    @StateObject private var recordingService = ScreenRecordingService()
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some Scene {
        MenuBarExtra("QuickSnap", systemImage: "camera.viewfinder") {
            MainMenuBarView(
                captureService: captureService,
                recordingService: recordingService
            )
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            PreferencesView()
        }
    }
}

struct MainMenuBarView: View {
    @ObservedObject var captureService: ScreenCaptureService
    @ObservedObject var recordingService: ScreenRecordingService
    
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        Group {
            Button("Capture Full Screen") {
                Task { await performFullScreenCapture() }
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            
            Button("Capture Region...") {
                captureService.captureRegion()
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])
            
            Divider()
            
            if recordingService.isRecording {
                Button("Stop Recording (\(formatDuration(recordingService.recordingDuration)))") {
                    Task { await stopRecording() }
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
            } else {
                Button("Record Full Screen") {
                    Task { await startFullScreenRecording() }
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
                
                Button("Record Region...") {
                    Task { await startRegionRecording() }
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
            }
            
            Divider()
            
            Button("OCR Capture...") {
                captureService.ocrCapture()
            }
            .keyboardShortcut("9", modifiers: [.command, .shift])
            .disabled(!settings.enableOCR)
            
            Divider()
            
            Button("Open Screenshots Folder") {
                NSWorkspace.shared.open(settings.defaultSaveLocation)
            }
            
            Button("Preferences...") {
                openPreferences()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit QuickSnap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
    
    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @MainActor
    private func performFullScreenCapture() async {
        captureService.captureFullScreen()
        
        if let result = captureService.lastCaptureResult, let image = result.image {
            if settings.showQuickActions {
                QuickActionWindowController.show(for: result) { action in
                    handleQuickAction(action, for: result)
                }
            } else {
                DestinationManager.shared.copyImageToClipboard(image)
                NotificationManager.shared.showCaptureSuccess(message: "Screenshot copied to clipboard")
            }
            
            if settings.playCaptureSound {
                NotificationManager.shared.playCaptureSound()
            }
        }
    }
    
    private func startFullScreenRecording() async {
        do {
            try await recordingService.startRecordingFullScreen()
        } catch {
            NotificationManager.shared.showError(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func startRegionRecording() async {
        do {
            try await recordingService.startRecordingRegion(CGRect(x: 0, y: 0, width: 800, height: 600))
        } catch {
            NotificationManager.shared.showError(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() async {
        do {
            let url = try await recordingService.stopRecording()
            NotificationManager.shared.showCaptureSuccess(message: "Recording saved to \(url.lastPathComponent)")
        } catch {
            NotificationManager.shared.showError(message: "Failed to save recording: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func handleQuickAction(_ action: QuickAction, for result: CaptureResult) {
        guard let image = result.image else { return }
        
        switch action {
        case .copyToClipboard:
            DestinationManager.shared.copyImageToClipboard(image)
            NotificationManager.shared.showCaptureSuccess(message: "Copied to clipboard")
            
        case .saveToDefault:
            let filename = DestinationManager.shared.generateFileName(
                pattern: settings.fileNamingPattern,
                format: settings.imageFormat
            )
            let url = settings.defaultSaveLocation.appendingPathComponent(filename)
            do {
                try DestinationManager.shared.saveImage(image, format: settings.imageFormat, to: url)
                NotificationManager.shared.showCaptureSuccess(message: "Saved to \(url.lastPathComponent)")
            } catch {
                NotificationManager.shared.showError(message: "Failed to save: \(error.localizedDescription)")
            }
            
        case .saveAs:
            if let url = DestinationManager.shared.promptSaveLocation(for: image, suggestedName: "Screenshot") {
                do {
                    try DestinationManager.shared.saveImage(image, format: settings.imageFormat, to: url)
                    NotificationManager.shared.showCaptureSuccess(message: "Saved to \(url.lastPathComponent)")
                } catch {
                    NotificationManager.shared.showError(message: "Failed to save: \(error.localizedDescription)")
                }
            }
            
        case .edit:
            EditorWindowController.show(for: image) { editedImage in
                DestinationManager.shared.copyImageToClipboard(editedImage)
                NotificationManager.shared.showCaptureSuccess(message: "Edited image copied to clipboard")
            }
            
        case .ocr:
            Task {
                await performOCR(on: image)
            }
        }
    }
    
    @MainActor
    private func performOCR(on image: NSImage) async {
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var shortcutManager: ShortcutManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()
        setupShortcuts()
    }
    
    private func checkPermissions() {
        let hasPermission = CGPreflightScreenCaptureAccess()
        if !hasPermission {
            CGRequestScreenCaptureAccess()
        }
    }
    
    private func setupShortcuts() {
        shortcutManager = ShortcutManager.shared
        shortcutManager?.registerAllShortcuts()
        shortcutManager?.onShortcutTriggered = { [weak self] action in
            self?.handleShortcut(action)
        }
    }
    
    private func handleShortcut(_ action: ShortcutManager.ShortcutAction) {
        switch action {
        case .captureFullScreen:
            NotificationCenter.default.post(name: .triggerFullScreenCapture, object: nil)
        case .captureRegion:
            NotificationCenter.default.post(name: .triggerRegionCapture, object: nil)
        case .recordFullScreen:
            NotificationCenter.default.post(name: .triggerFullScreenRecording, object: nil)
        case .recordRegion:
            NotificationCenter.default.post(name: .triggerRegionRecording, object: nil)
        case .ocrCapture:
            NotificationCenter.default.post(name: .triggerOCRCapture, object: nil)
        case .stopRecording:
            NotificationCenter.default.post(name: .triggerStopRecording, object: nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregisterAllShortcuts()
    }
}

extension Notification.Name {
    static let triggerFullScreenCapture = Notification.Name("triggerFullScreenCapture")
    static let triggerRegionCapture = Notification.Name("triggerRegionCapture")
    static let triggerFullScreenRecording = Notification.Name("triggerFullScreenRecording")
    static let triggerRegionRecording = Notification.Name("triggerRegionRecording")
    static let triggerOCRCapture = Notification.Name("triggerOCRCapture")
    static let triggerStopRecording = Notification.Name("triggerStopRecording")
}
