import SwiftUI
import AppKit

enum QuickAction: CaseIterable {
    case copyToClipboard
    case saveToDefault
    case saveAs
    case edit
    case ocr
    
    var title: String {
        switch self {
        case .copyToClipboard: return "Copy"
        case .saveToDefault: return "Save"
        case .saveAs: return "Save As"
        case .edit: return "Edit"
        case .ocr: return "OCR"
        }
    }
    
    var systemImage: String {
        switch self {
        case .copyToClipboard: return "doc.on.clipboard"
        case .saveToDefault: return "square.and.arrow.down"
        case .saveAs: return "folder"
        case .edit: return "pencil"
        case .ocr: return "text.viewfinder"
        }
    }
    
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .copyToClipboard: return "c"
        case .saveToDefault: return "s"
        case .saveAs: return "a"
        case .edit: return "e"
        case .ocr: return "o"
        }
    }
}

struct QuickActionView: View {
    let captureResult: CaptureResult
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: AppSettings
    var onAction: (QuickAction) -> Void
    
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var isHovering = false
    
    private var availableActions: [QuickAction] {
        var actions: [QuickAction] = [.copyToClipboard, .saveToDefault, .saveAs, .edit]
        if captureResult.isImage {
            actions.append(.ocr)
        }
        return actions
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(availableActions, id: \.self) { action in
                QuickActionButton(action: action) {
                    onAction(action)
                    dismiss()
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .onAppear {
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                autoDismissTask?.cancel()
            } else {
                startAutoDismissTimer()
            }
        }
        .onExitCommand {
            dismiss()
        }
    }
    
    private func startAutoDismissTimer() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(settings.quickActionDuration * 1_000_000_000))
            if !Task.isCancelled && !isHovering {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                
                Text(action.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isHovered ? .white : .primary)
            .frame(width: 56, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor : Color.clear)
                    .opacity(isPressed ? 0.8 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .help(action.title)
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

class QuickActionWindowController: NSWindowController {
    private static var sharedController: QuickActionWindowController?
    private var hostingView: NSHostingView<AnyView>?
    
    static func show(for result: CaptureResult, onAction: @escaping (QuickAction) -> Void) {
        let controller = QuickActionWindowController()
        sharedController = controller
        
        let mouseLocation = NSEvent.mouseLocation
        controller.show(
            for: result,
            near: mouseLocation,
            settings: AppSettings.shared,
            onAction: onAction
        )
    }
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 70),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(
        for result: CaptureResult,
        near point: CGPoint,
        settings: AppSettings,
        onAction: @escaping (QuickAction) -> Void
    ) {
        let isPresented = Binding<Bool>(
            get: { true },
            set: { [weak self] newValue in
                if !newValue {
                    self?.dismiss()
                }
            }
        )
        
        let view = QuickActionView(
            captureResult: result,
            isPresented: isPresented,
            onAction: onAction
        )
        .environmentObject(settings)
        
        hostingView = NSHostingView(rootView: AnyView(view))
        window?.contentView = hostingView
        
        if let contentSize = hostingView?.fittingSize {
            window?.setContentSize(contentSize)
        }
        
        positionWindow(near: point)
        
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1
        }
    }
    
    private func positionWindow(near point: CGPoint) {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let windowSize = window.frame.size
        var origin = CGPoint(
            x: point.x - windowSize.width / 2,
            y: point.y - windowSize.height - 20
        )
        
        let screenFrame = screen.visibleFrame
        origin.x = max(screenFrame.minX + 10, min(origin.x, screenFrame.maxX - windowSize.width - 10))
        origin.y = max(screenFrame.minY + 10, min(origin.y, screenFrame.maxY - windowSize.height - 10))
        
        window.setFrameOrigin(origin)
    }
    
    func dismiss() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }
}

#Preview {
    QuickActionView(
        captureResult: CaptureResult(
            image: NSImage(),
            videoURL: nil,
            timestamp: Date(),
            region: nil
        ),
        isPresented: .constant(true),
        onAction: { action in
            print("Action: \(action)")
        }
    )
    .environmentObject(AppSettings())
    .padding()
    .background(Color.gray.opacity(0.3))
}
