import SwiftUI
import AppKit

struct RegionSelectorView: View {
    @Binding var isPresented: Bool
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var mouseLocation: CGPoint = .zero
    
    var onRegionSelected: (CGRect) -> Void
    
    private var selectedRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                if let rect = selectedRect {
                    Rectangle()
                        .path(in: rect)
                        .fill(Color.clear)
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0)
                        )
                    
                    Path { path in
                        path.addRect(geometry.frame(in: .local))
                        path.addRect(rect)
                    }
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    dimensionsLabel(for: rect)
                }
                
                CrosshairView(position: mouseLocation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.startLocation
                        }
                        currentPoint = value.location
                        mouseLocation = value.location
                    }
                    .onEnded { value in
                        if let rect = selectedRect, rect.width > 5, rect.height > 5 {
                            onRegionSelected(rect)
                        }
                        dismiss()
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if startPoint == nil {
                        mouseLocation = location
                    }
                case .ended:
                    break
                }
            }
        }
        .onExitCommand {
            dismiss()
        }
    }
    
    private func dimensionsLabel(for rect: CGRect) -> some View {
        let width = Int(rect.width)
        let height = Int(rect.height)
        
        return Text("\(width) × \(height)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.75))
            .cornerRadius(4)
            .position(
                x: rect.midX,
                y: rect.maxY + 20
            )
    }
    
    private func dismiss() {
        startPoint = nil
        currentPoint = nil
        isPresented = false
    }
}

struct CrosshairView: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 1, height: .infinity)
                .position(x: position.x, y: UIScreen.main?.frame.midY ?? 0)
            
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: .infinity, height: 1)
                .position(x: UIScreen.main?.frame.midX ?? 0, y: position.y)
        }
    }
}

private enum UIScreen {
    static var main: NSScreen? { NSScreen.main }
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

class RegionSelectorWindowController: NSWindowController {
    private var windows: [RegionSelectorWindow] = []
    var onRegionSelected: ((CGRect, NSScreen) -> Void)?
    var onCancelled: (() -> Void)?
    
    func showSelector() {
        windows = RegionSelectorWindow.createForAllScreens()
        
        for (index, window) in windows.enumerated() {
            let screen = NSScreen.screens[index]
            let isPresented = Binding<Bool>(
                get: { true },
                set: { [weak self] newValue in
                    if !newValue {
                        self?.dismissAll()
                    }
                }
            )
            
            let view = RegionSelectorView(isPresented: isPresented) { [weak self] rect in
                self?.onRegionSelected?(rect, screen)
                self?.dismissAll()
            }
            
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
        }
        
        NSCursor.crosshair.push()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onCancelled?()
                self?.dismissAll()
                return nil
            }
            return event
        }
    }
    
    func dismissAll() {
        NSCursor.pop()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}

#Preview {
    RegionSelectorView(isPresented: .constant(true)) { rect in
        print("Selected: \(rect)")
    }
    .frame(width: 800, height: 600)
}
