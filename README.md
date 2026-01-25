# QuickSnap

A native macOS screenshot and screen recording application with built-in editing and OCR capabilities.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)

## Features

### 📸 Capture Modes
- **Full Screen Capture** - Capture the entire screen (⌘⇧3)
- **Region Selection** - Click and drag to select a specific area (⌘⇧4)
- **Full Screen Recording** - Record the entire screen as video (⌘⇧5)
- **Region Recording** - Record a specific portion of the screen (⌘⇧6)
- **OCR Capture** - Capture and extract text (⌘⇧9)

### 🎨 Image Editor
- Blur and pixelate tools for censoring sensitive information
- Text annotations and arrows
- Crop and resize
- Undo/redo support

### 🔤 OCR (Optical Character Recognition)
- Extract text from screenshots using Apple's Vision framework
- Multi-language support
- Auto-copy to clipboard option

### ⚙️ Preferences
- Configurable save location
- Multiple image formats (PNG, JPEG, TIFF)
- Video formats (MP4, MOV)
- Custom file naming patterns
- Quick action panel settings

## Building

### Requirements
- macOS 13.0 or later
- Xcode 15.0 or later

### Build from Source
```bash
cd quicksnap
xcodebuild -project QuickSnap.xcodeproj -scheme QuickSnap -configuration Release build
```

Or open `QuickSnap.xcodeproj` in Xcode and build (⌘B).

## Permissions

QuickSnap requires the following permissions:
- **Screen Recording** - To capture screenshots and screen recordings
- **Accessibility** - For global keyboard shortcuts (optional)

## Project Structure

```
QuickSnap/
├── QuickSnapApp.swift          # App entry point and menu bar
├── Models/
│   ├── AppSettings.swift       # User preferences
│   ├── CaptureMode.swift       # Capture mode enum
│   └── CaptureResult.swift     # Capture result model
├── Services/
│   ├── ScreenCaptureService.swift    # Screenshot capture
│   ├── ScreenRecordingService.swift  # Video recording
│   ├── VisionOCRService.swift        # OCR text recognition
│   ├── ShortcutManager.swift         # Global hotkeys
│   ├── DestinationManager.swift      # File saving
│   ├── NotificationManager.swift     # User notifications
│   └── PermissionManager.swift       # System permissions
└── Views/
    ├── MenuBarView.swift             # Menu bar dropdown
    ├── RegionSelectorView.swift      # Region selection overlay
    ├── QuickActionView.swift         # Post-capture actions
    ├── PreferencesView.swift         # Settings window
    ├── OCRResultView.swift           # OCR results display
    └── Editor/
        ├── EditorView.swift          # Main editor
        ├── CanvasView.swift          # Drawing canvas
        ├── ToolPaletteView.swift     # Tool sidebar
        └── EditorWindowController.swift
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
