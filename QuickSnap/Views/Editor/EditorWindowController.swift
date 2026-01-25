import AppKit
import SwiftUI

class EditorWindowController: NSWindowController {
    private var onSave: ((NSImage) -> Void)?
    private var isPresentedBinding: Binding<Bool>?
    
    convenience init(image: NSImage, onSave: @escaping (NSImage) -> Void) {
        let isPresented = Binding<Bool>(
            get: { true },
            set: { _ in }
        )
        
        let editorView = EditorView(
            originalImage: image,
            isPresented: isPresented,
            onSave: onSave
        )
        
        let hostingController = NSHostingController(rootView: editorView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "QuickSnap Editor"
        window.center()
        window.setFrameAutosaveName("EditorWindow")
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        
        let toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        
        self.init(window: window)
        self.onSave = onSave
        
        window.delegate = self
    }
    
    static func show(for image: NSImage, onSave: @escaping (NSImage) -> Void) {
        let controller = EditorWindowController(image: image, onSave: onSave)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        editorWindowControllers.append(controller)
    }
}

private var editorWindowControllers: [EditorWindowController] = []

extension EditorWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let index = editorWindowControllers.firstIndex(where: { $0 === self }) {
            editorWindowControllers.remove(at: index)
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
