import SwiftUI
import AppKit

struct EditorView: View {
    @StateObject private var editorState: EditorState
    @Binding var isPresented: Bool
    var onSave: (NSImage) -> Void
    
    init(originalImage: NSImage, isPresented: Binding<Bool>, onSave: @escaping (NSImage) -> Void) {
        self._editorState = StateObject(wrappedValue: EditorState(image: originalImage))
        self._isPresented = isPresented
        self.onSave = onSave
    }
    
    var body: some View {
        HSplitView {
            ToolPaletteView(selectedTool: $editorState.currentTool, toolOptions: $editorState.toolOptions)
            
            CanvasView(state: editorState)
            
            ToolOptionsView(state: editorState)
        }
        .toolbar {
            EditorToolbar(state: editorState, onSave: {
                onSave(editorState.renderFinalImage())
                isPresented = false
            }, onCancel: {
                isPresented = false
            })
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

@MainActor
class EditorState: ObservableObject {
    @Published var currentTool: EditorTool = .select
    @Published var currentImage: NSImage
    @Published var annotations: [Annotation] = []
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var toolOptions = ToolOptions()
    @Published var selectedAnnotationID: UUID?
    
    private let originalImage: NSImage
    private var history: [[Annotation]] = []
    private var historyIndex = -1
    
    init(image: NSImage) {
        self.originalImage = image
        self.currentImage = image
        saveState()
    }
    
    private func saveState() {
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(annotations)
        historyIndex = history.count - 1
        updateUndoRedoState()
    }
    
    private func updateUndoRedoState() {
        canUndo = historyIndex > 0
        canRedo = historyIndex < history.count - 1
    }
    
    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        annotations = history[historyIndex]
        updateUndoRedoState()
    }
    
    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        annotations = history[historyIndex]
        updateUndoRedoState()
    }
    
    func applyBlur(to rect: CGRect, intensity: Float) {
        let annotation = Annotation(
            type: .blur(intensity: intensity),
            rect: rect,
            color: nil,
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func applyPixelate(to rect: CGRect, blockSize: Int) {
        let annotation = Annotation(
            type: .pixelate(blockSize: blockSize),
            rect: rect,
            color: nil,
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func addSolidRect(_ rect: CGRect, color: NSColor) {
        let annotation = Annotation(
            type: .solidRect,
            rect: rect,
            color: color,
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func addText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
        let annotation = Annotation(
            type: .text(font: font),
            rect: CGRect(origin: point, size: CGSize(width: 200, height: 50)),
            color: color,
            text: text
        )
        annotations.append(annotation)
        saveState()
    }
    
    func addArrow(from: CGPoint, to: CGPoint, color: NSColor, lineWidth: CGFloat) {
        let rect = CGRect(
            x: min(from.x, to.x),
            y: min(from.y, to.y),
            width: abs(to.x - from.x),
            height: abs(to.y - from.y)
        )
        let annotation = Annotation(
            type: .arrow(startPoint: from, endPoint: to, lineWidth: lineWidth),
            rect: rect,
            color: color,
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func addPenStroke(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard !points.isEmpty else { return }
        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let annotation = Annotation(
            type: .pen(points: points, lineWidth: lineWidth),
            rect: rect,
            color: color,
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func addHighlight(_ rect: CGRect, color: NSColor) {
        let annotation = Annotation(
            type: .highlight,
            rect: rect,
            color: color.withAlphaComponent(0.3),
            text: nil
        )
        annotations.append(annotation)
        saveState()
    }
    
    func crop(to rect: CGRect) {
        guard let cgImage = currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let scaleX = CGFloat(cgImage.width) / currentImage.size.width
        let scaleY = CGFloat(cgImage.height) / currentImage.size.height
        
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return }
        
        let newImage = NSImage(cgImage: croppedCGImage, size: rect.size)
        currentImage = newImage
        annotations.removeAll()
        saveState()
    }
    
    func deleteSelectedAnnotation() {
        guard let selectedID = selectedAnnotationID else { return }
        annotations.removeAll { $0.id == selectedID }
        selectedAnnotationID = nil
        saveState()
    }
    
    func renderFinalImage() -> NSImage {
        let size = currentImage.size
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        currentImage.draw(in: CGRect(origin: .zero, size: size))
        
        for annotation in annotations {
            renderAnnotation(annotation, in: size)
        }
        
        image.unlockFocus()
        
        return image
    }
    
    private func renderAnnotation(_ annotation: Annotation, in size: NSSize) {
        switch annotation.type {
        case .blur(let intensity):
            renderBlur(in: annotation.rect, intensity: intensity)
        case .pixelate(let blockSize):
            renderPixelate(in: annotation.rect, blockSize: blockSize)
        case .solidRect:
            if let color = annotation.color {
                color.setFill()
                NSBezierPath(rect: annotation.rect).fill()
            }
        case .text(let font):
            if let text = annotation.text, let color = annotation.color {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                text.draw(at: annotation.rect.origin, withAttributes: attributes)
            }
        case .arrow(let start, let end, let lineWidth):
            if let color = annotation.color {
                drawArrow(from: start, to: end, color: color, lineWidth: lineWidth)
            }
        case .pen(let points, let lineWidth):
            if let color = annotation.color, points.count > 1 {
                color.setStroke()
                let path = NSBezierPath()
                path.lineWidth = lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.line(to: point)
                }
                path.stroke()
            }
        case .highlight:
            if let color = annotation.color {
                color.setFill()
                NSBezierPath(rect: annotation.rect).fill()
            }
        }
    }
    
    private func renderBlur(in rect: CGRect, intensity: Float) {
        guard let cgImage = currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputRadiusKey)
        
        guard let outputImage = filter.outputImage else { return }
        
        let context = CIContext()
        let scaleX = CGFloat(cgImage.width) / currentImage.size.width
        let scaleY = CGFloat(cgImage.height) / currentImage.size.height
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: CGFloat(cgImage.height) - (rect.origin.y + rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        guard let blurredCGImage = context.createCGImage(outputImage, from: scaledRect) else { return }
        
        let blurredNSImage = NSImage(cgImage: blurredCGImage, size: rect.size)
        blurredNSImage.draw(in: rect)
    }
    
    private func renderPixelate(in rect: CGRect, blockSize: Int) {
        guard let cgImage = currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIPixellate")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(blockSize, forKey: kCIInputScaleKey)
        
        guard let outputImage = filter.outputImage else { return }
        
        let context = CIContext()
        let scaleX = CGFloat(cgImage.width) / currentImage.size.width
        let scaleY = CGFloat(cgImage.height) / currentImage.size.height
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: CGFloat(cgImage.height) - (rect.origin.y + rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        guard let pixelatedCGImage = context.createCGImage(outputImage, from: scaledRect) else { return }
        
        let pixelatedNSImage = NSImage(cgImage: pixelatedCGImage, size: rect.size)
        pixelatedNSImage.draw(in: rect)
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        color.setFill()
        
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.move(to: start)
        path.line(to: end)
        path.stroke()
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = NSBezierPath()
        arrowPath.move(to: end)
        arrowPath.line(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        arrowPath.line(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))
        arrowPath.close()
        arrowPath.fill()
    }
}

enum EditorTool: String, CaseIterable {
    case select
    case crop
    case blur
    case pixelate
    case solidRect
    case text
    case arrow
    case pen
    case highlight
    
    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .crop: return "crop"
        case .blur: return "drop.fill"
        case .pixelate: return "square.grid.3x3"
        case .solidRect: return "rectangle.fill"
        case .text: return "textformat"
        case .arrow: return "arrow.right"
        case .pen: return "pencil"
        case .highlight: return "highlighter"
        }
    }
    
    var displayName: String {
        switch self {
        case .select: return "Select"
        case .crop: return "Crop"
        case .blur: return "Blur"
        case .pixelate: return "Pixelate"
        case .solidRect: return "Rectangle"
        case .text: return "Text"
        case .arrow: return "Arrow"
        case .pen: return "Pen"
        case .highlight: return "Highlight"
        }
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var type: AnnotationType
    var rect: CGRect
    var color: NSColor?
    var text: String?
}

enum AnnotationType {
    case blur(intensity: Float)
    case pixelate(blockSize: Int)
    case solidRect
    case text(font: NSFont)
    case arrow(startPoint: CGPoint, endPoint: CGPoint, lineWidth: CGFloat)
    case pen(points: [CGPoint], lineWidth: CGFloat)
    case highlight
}

struct ToolOptions {
    var blurIntensity: Float = 10.0
    var pixelateBlockSize: Int = 10
    var strokeColor: NSColor = .red
    var fillColor: NSColor = .black
    var lineWidth: CGFloat = 3.0
    var fontSize: CGFloat = 16.0
    var fontName: String = "Helvetica"
}

struct ToolOptionsView: View {
    @ObservedObject var state: EditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
            
            switch state.currentTool {
            case .blur:
                VStack(alignment: .leading) {
                    Text("Intensity: \(Int(state.toolOptions.blurIntensity))")
                    Slider(value: $state.toolOptions.blurIntensity, in: 1...50)
                }
            case .pixelate:
                VStack(alignment: .leading) {
                    Text("Block Size: \(state.toolOptions.pixelateBlockSize)")
                    Slider(value: Binding(
                        get: { Double(state.toolOptions.pixelateBlockSize) },
                        set: { state.toolOptions.pixelateBlockSize = Int($0) }
                    ), in: 2...50)
                }
            case .solidRect, .arrow, .pen, .highlight:
                ColorPicker("Color", selection: Binding(
                    get: { Color(state.toolOptions.strokeColor) },
                    set: { state.toolOptions.strokeColor = NSColor($0) }
                ))
                
                if state.currentTool == .arrow || state.currentTool == .pen {
                    VStack(alignment: .leading) {
                        Text("Line Width: \(Int(state.toolOptions.lineWidth))")
                        Slider(value: $state.toolOptions.lineWidth, in: 1...20)
                    }
                }
            case .text:
                ColorPicker("Color", selection: Binding(
                    get: { Color(state.toolOptions.strokeColor) },
                    set: { state.toolOptions.strokeColor = NSColor($0) }
                ))
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(state.toolOptions.fontSize))")
                    Slider(value: $state.toolOptions.fontSize, in: 8...72)
                }
            default:
                Text("No options for this tool")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 180)
    }
}

struct EditorToolbar: ToolbarContent {
    @ObservedObject var state: EditorState
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
        }
        
        ToolbarItem(placement: .principal) {
            HStack(spacing: 16) {
                Button(action: state.undo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!state.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                
                Button(action: state.redo) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!state.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                if state.selectedAnnotationID != nil {
                    Button(action: state.deleteSelectedAnnotation) {
                        Label("Delete", systemImage: "trash")
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                }
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: onSave) {
                Label("Save", systemImage: "checkmark")
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}
