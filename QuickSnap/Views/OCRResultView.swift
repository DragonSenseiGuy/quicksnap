import SwiftUI

struct OCRResultView: View {
    let result: OCRResult
    @Binding var isPresented: Bool
    @State private var editedText: String = ""
    @State private var hasCopied = false
    
    private var confidenceColor: Color {
        if result.confidence >= 0.9 {
            return .green
        } else if result.confidence >= 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var confidencePercentage: String {
        String(format: "%.0f%%", result.confidence * 100)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            textEditorView
            
            Divider()
            
            footerView
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 700)
        .frame(minHeight: 300, idealHeight: 400, maxHeight: 600)
        .onAppear {
            editedText = result.text
        }
    }
    
    private var headerView: some View {
        HStack {
            Label("Recognized Text", systemImage: "text.viewfinder")
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
                
                Text("Confidence: \(confidencePercentage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var textEditorView: some View {
        TextEditor(text: $editedText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var footerView: some View {
        HStack {
            Text(String(format: "Processed in %.2fs", result.processingTime))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                copyText()
            }) {
                Label(hasCopied ? "Copied!" : "Copy", systemImage: hasCopied ? "checkmark" : "doc.on.clipboard")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button("Close") {
                isPresented = false
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }
    
    private func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(editedText, forType: .string)
        
        hasCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            hasCopied = false
        }
    }
}

class OCRResultWindowController: NSWindowController {
    private static var sharedController: OCRResultWindowController?
    private var hostingView: NSHostingView<AnyView>?
    
    static func show(result: OCRResult) {
        let controller = OCRResultWindowController()
        sharedController = controller
        controller.show(result: result)
    }
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "OCR Result"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(result: OCRResult) {
        let isPresented = Binding<Bool>(
            get: { true },
            set: { [weak self] newValue in
                if !newValue {
                    self?.close()
                }
            }
        )
        
        let view = OCRResultView(result: result, isPresented: isPresented)
        
        hostingView = NSHostingView(rootView: AnyView(view))
        window?.contentView = hostingView
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview {
    OCRResultView(
        result: OCRResult(
            text: "Sample recognized text\nLine 2\nLine 3",
            observations: [],
            confidence: 0.95,
            processingTime: 0.342
        ),
        isPresented: .constant(true)
    )
}
