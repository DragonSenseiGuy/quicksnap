# QuickSnap Agent Guidelines

## Project Overview

QuickSnap is a native macOS menu bar application for screenshots and screen recording, built with Swift and SwiftUI. It targets macOS 13.0+ and uses ScreenCaptureKit for capture and Vision framework for OCR.

## Build Commands

```bash
# Build (Debug)
xcodebuild -project QuickSnap.xcodeproj -scheme QuickSnap -destination 'platform=macOS' build

# Build (Release)
xcodebuild -project QuickSnap.xcodeproj -scheme QuickSnap -configuration Release build

# Clean build
xcodebuild -project QuickSnap.xcodeproj -scheme QuickSnap clean build
```

There are no tests, linting, or type-checking commands configured yet.

## Architecture

```
QuickSnap/
├── QuickSnapApp.swift       # @main entry, MenuBarExtra, AppDelegate
├── Models/                  # Data models and enums
├── Services/                # Business logic (capture, recording, OCR)
└── Views/                   # SwiftUI views and NSWindowControllers
```

### Key Patterns

- **Singleton services**: `AppSettings.shared`, `DestinationManager.shared`, `ShortcutManager.shared`, `NotificationManager.shared`
- **ObservableObject**: Services like `ScreenCaptureService`, `ScreenRecordingService`, `PermissionManager` use `@Published` properties
- **WindowControllers**: `EditorWindowController`, `QuickActionWindowController`, `OCRResultWindowController` wrap SwiftUI views in NSWindow for floating panels

## Code Conventions

### Swift Style
- Use Swift 5 with async/await for asynchronous operations
- Prefer `@MainActor` annotations for UI-related classes
- Use `@AppStorage` for persisted user preferences
- Error handling: Define custom error enums conforming to `LocalizedError`

### Naming
- Services: `*Service` (e.g., `ScreenCaptureService`)
- Window controllers: `*WindowController`
- Settings/preferences: Store in `AppSettings` using `@AppStorage`

### File Organization
- One primary type per file
- Group related enums with their primary consumer
- Shared enums (like `ImageFormat`, `VideoFormat`) go in `Models/AppSettings.swift`

## Important Types

| Type | Location | Purpose |
|------|----------|---------|
| `AppSettings` | Models/AppSettings.swift | All user preferences via @AppStorage |
| `CaptureResult` | Models/CaptureResult.swift | Screenshot/recording output |
| `ImageFormat` | Models/AppSettings.swift | PNG, JPG, TIFF export formats |
| `VideoFormat` | Models/AppSettings.swift | MP4, MOV export formats |
| `EditorTool` | Views/Editor/EditorView.swift | Editor tool types |
| `QuickAction` | Views/QuickActionView.swift | Post-capture action types |

## Common Tasks

### Adding a new preference
1. Add `@AppStorage` property to `AppSettings` in Models/AppSettings.swift
2. Add UI control in appropriate tab in Views/PreferencesView.swift

### Adding a new capture mode
1. Add case to `CaptureMode` enum in Models/CaptureMode.swift
2. Add handler in `ScreenCaptureService` or `ScreenRecordingService`
3. Add menu item in `MainMenuBarView` in QuickSnapApp.swift

### Adding a new editor tool
1. Add case to `EditorTool` enum in Views/Editor/EditorView.swift
2. Implement tool logic in `EditorState` class
3. Add tool preview in `CanvasView`

## Frameworks Used

- **SwiftUI** - UI framework
- **AppKit** - NSWindow, NSMenu, NSStatusItem integration
- **ScreenCaptureKit** - Modern screen capture API (macOS 12.3+)
- **Vision** - OCR text recognition
- **AVFoundation** - Video encoding
- **Carbon** - Global hotkey registration (EventHotKey API)

## Known Limitations

- Global shortcuts use Carbon API (legacy but stable)
- No test coverage yet
- Region recording currently uses hardcoded region (needs region selector integration)
- Editor undo/redo is basic
