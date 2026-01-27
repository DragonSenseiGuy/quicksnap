import SwiftUI
import AppKit

struct SelectedRegion {
    let rect: CGRect
    let screen: NSScreen
    
    var screenCaptureRect: CGRect {
        CGRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )
    }
    
    var screenRecordingSourceRect: CGRect {
        let flippedY = screen.frame.height - rect.origin.y - rect.height
        return CGRect(
            x: rect.origin.x,
            y: flippedY,
            width: rect.width,
            height: rect.height
        )
    }
}

@MainActor
class RegionSelectorService: ObservableObject {
    static let shared = RegionSelectorService()
    
    private var windows: [RegionSelectorWindow] = []
    private var eventMonitor: Any?
    private var completion: ((SelectedRegion?) -> Void)?
    
    func selectRegion(completion: @escaping (SelectedRegion?) -> Void) {
        self.completion = completion
        
        windows = RegionSelectorWindow.createForAllScreens()
        
        for (index, window) in windows.enumerated() {
            let screen = NSScreen.screens[index]
            let isPresented = Binding<Bool>(
                get: { true },
                set: { [weak self] newValue in
                    if !newValue {
                        self?.dismissAll(selected: nil)
                    }
                }
            )
            
            let view = RegionSelectorView(isPresented: isPresented) { [weak self] rect in
                let region = SelectedRegion(rect: rect, screen: screen)
                self?.dismissAll(selected: region)
            }
            
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
        }
        
        NSCursor.crosshair.push()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismissAll(selected: nil)
                return nil
            }
            return event
        }
    }
    
    private func dismissAll(selected: SelectedRegion?) {
        NSCursor.pop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.completion?(selected)
            self?.completion = nil
        }
    }
}

class RegionSelectorWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    static func createForAllScreens() -> [RegionSelectorWindow] {
        NSScreen.screens.map { screen in
            let window = RegionSelectorWindow(contentRect: screen.frame)
            window.setFrame(screen.frame, display: true)
            return window
        }
    }
}
