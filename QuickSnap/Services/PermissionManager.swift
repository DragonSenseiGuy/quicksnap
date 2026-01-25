import AppKit
import ScreenCaptureKit

enum PermissionType {
    case screenRecording
    case accessibility
    
    var systemPreferencesURL: URL? {
        switch self {
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }
}

class PermissionManager: ObservableObject {
    @Published var hasScreenRecordingPermission = false
    @Published var hasAccessibilityPermission = false
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }
    
    private func checkScreenRecordingPermission() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }
    
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    func requestScreenRecordingPermission() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.hasScreenRecordingPermission = true
                }
            } catch {
                await MainActor.run {
                    self.hasScreenRecordingPermission = false
                }
            }
        }
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }
    
    func openSystemPreferences(for permission: PermissionType) {
        guard let url = permission.systemPreferencesURL else { return }
        NSWorkspace.shared.open(url)
    }
}
