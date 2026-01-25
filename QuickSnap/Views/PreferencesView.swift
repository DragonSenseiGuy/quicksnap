import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ShortcutsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            EditorTab()
                .tabItem {
                    Label("Editor", systemImage: "pencil.and.outline")
                }
            
            OCRTab()
                .tabItem {
                    Label("OCR", systemImage: "text.viewfinder")
                }
        }
        .frame(width: 500, height: 400)
        .environmentObject(settings)
    }
}

struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Save Location:")
                    Spacer()
                    Text(settings.defaultSaveLocation.path)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose...") {
                        selectFolder()
                    }
                }
                
                Picker("Image Format:", selection: Binding(
                    get: { settings.imageFormat },
                    set: { settings.imageFormat = $0 }
                )) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                
                Picker("Video Format:", selection: Binding(
                    get: { settings.videoFormat },
                    set: { settings.videoFormat = $0 }
                )) {
                    ForEach(VideoFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            } header: {
                Text("Save Settings")
            }
            
            Section {
                TextField("File Name Pattern:", text: $settings.fileNamingPattern)
                
                Text("Available tokens: {date}, {time}")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Preview:")
                    Text(previewFileName)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Naming")
            }
            
            Section {
                Toggle("Play Sound on Capture", isOn: $settings.playCaptureSound)
                Toggle("Show Quick Actions", isOn: $settings.showQuickActions)
                
                if settings.showQuickActions {
                    HStack {
                        Text("Quick Action Duration:")
                        Slider(value: $settings.quickActionDuration, in: 1...10, step: 1)
                        Text("\(Int(settings.quickActionDuration))s")
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                }
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var previewFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        formatter.dateFormat = "HH-mm-ss"
        let timeStr = formatter.string(from: Date())
        
        return settings.fileNamingPattern
            .replacingOccurrences(of: "{date}", with: dateStr)
            .replacingOccurrences(of: "{time}", with: timeStr)
        + ".\(settings.imageFormat.rawValue)"
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder to save screenshots"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultSaveLocation = url
        }
    }
}

struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section {
                Text("Keyboard shortcuts can be configured in System Settings > Keyboard > Keyboard Shortcuts")
                    .foregroundColor(.secondary)
            } header: {
                Text("Keyboard Shortcuts")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct EditorTab: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-open Editor After Capture", isOn: $settings.autoOpenEditor)
            } header: {
                Text("Editor Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct OCRTab: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable OCR", isOn: $settings.enableOCR)
                
                TextField("Recognition Language:", text: $settings.ocrLanguage)
                    .disabled(!settings.enableOCR)
                
                Text("e.g., en-US, fr-FR, de-DE")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("OCR Settings")
            }
            
            Section {
                Toggle("Auto-copy Text to Clipboard", isOn: $settings.ocrAutoClipboard)
                    .disabled(!settings.enableOCR)
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

class PreferencesWindowController: NSWindowController {
    convenience init(settings: AppSettings) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "QuickSnap Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
        let view = PreferencesView().environmentObject(settings)
        window.contentView = NSHostingView(rootView: view)
        
        self.init(window: window)
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview("Preferences") {
    PreferencesView()
        .environmentObject(AppSettings())
}

#Preview("General Tab") {
    GeneralTab()
        .environmentObject(AppSettings())
        .frame(width: 500, height: 400)
}

#Preview("OCR Tab") {
    OCRTab()
        .environmentObject(AppSettings())
        .frame(width: 500, height: 400)
}
