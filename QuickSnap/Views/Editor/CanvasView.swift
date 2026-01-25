import SwiftUI
import AppKit

struct CanvasView: View {
    @ObservedObject var state: EditorState
    @State private var currentDrag: DragState?
    @State private var penPoints: [CGPoint] = []
    @State private var imageFrame: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                Image(nsImage: state.currentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(GeometryReader { imageGeometry in
                        Color.clear.onAppear {
                            imageFrame = imageGeometry.frame(in: .local)
                        }
                        .onChange(of: geometry.size) { _ in
                            imageFrame = imageGeometry.frame(in: .local)
                        }
                    })
                    .overlay {
                        ZStack {
                            ForEach(state.annotations) { annotation in
                                AnnotationView(
                                    annotation: annotation,
                                    isSelected: state.selectedAnnotationID == annotation.id,
                                    imageSize: state.currentImage.size
                                )
                                .onTapGesture {
                                    if state.currentTool == .select {
                                        state.selectedAnnotationID = annotation.id
                                    }
                                }
                            }
                            
                            if let drag = currentDrag {
                                CurrentToolPreview(
                                    tool: state.currentTool,
                                    drag: drag,
                                    penPoints: penPoints,
                                    options: state.toolOptions
                                )
                            }
                        }
                    }
                    .gesture(dragGesture)
                    .gesture(tapGesture)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                if state.currentTool == .text {
                    showTextInput(at: value.location)
                } else if state.currentTool == .select {
                    state.selectedAnnotationID = nil
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = value.startLocation
                let current = value.location
                
                if state.currentTool == .pen {
                    if penPoints.isEmpty {
                        penPoints.append(start)
                    }
                    penPoints.append(current)
                    currentDrag = DragState(start: start, current: current)
                } else {
                    currentDrag = DragState(start: start, current: current)
                }
            }
            .onEnded { value in
                let start = value.startLocation
                let end = value.location
                
                applyTool(from: start, to: end)
                
                currentDrag = nil
                penPoints = []
            }
    }
    
    private func applyTool(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        guard rect.width > 5 || rect.height > 5 || state.currentTool == .pen else { return }
        
        switch state.currentTool {
        case .select:
            break
        case .crop:
            state.crop(to: rect)
        case .blur:
            state.applyBlur(to: rect, intensity: state.toolOptions.blurIntensity)
        case .pixelate:
            state.applyPixelate(to: rect, blockSize: state.toolOptions.pixelateBlockSize)
        case .solidRect:
            state.addSolidRect(rect, color: state.toolOptions.strokeColor)
        case .text:
            break
        case .arrow:
            state.addArrow(from: start, to: end, color: state.toolOptions.strokeColor, lineWidth: state.toolOptions.lineWidth)
        case .pen:
            if !penPoints.isEmpty {
                state.addPenStroke(penPoints, color: state.toolOptions.strokeColor, lineWidth: state.toolOptions.lineWidth)
            }
        case .highlight:
            state.addHighlight(rect, color: state.toolOptions.strokeColor)
        }
    }
    
    private func showTextInput(at point: CGPoint) {
        let alert = NSAlert()
        alert.messageText = "Enter Text"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Enter text here"
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let text = textField.stringValue
            if !text.isEmpty {
                let font = NSFont(name: state.toolOptions.fontName, size: state.toolOptions.fontSize) ?? NSFont.systemFont(ofSize: state.toolOptions.fontSize)
                state.addText(text, at: point, font: font, color: state.toolOptions.strokeColor)
            }
        }
    }
}

struct DragState {
    let start: CGPoint
    let current: CGPoint
    
    var rect: CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
}

struct AnnotationView: View {
    let annotation: Annotation
    let isSelected: Bool
    let imageSize: NSSize
    
    var body: some View {
        Group {
            switch annotation.type {
            case .blur:
                BlurAnnotationView(annotation: annotation)
            case .pixelate:
                PixelateAnnotationView(annotation: annotation)
            case .solidRect:
                Rectangle()
                    .fill(Color(annotation.color ?? .black))
                    .frame(width: annotation.rect.width, height: annotation.rect.height)
                    .position(x: annotation.rect.midX, y: annotation.rect.midY)
            case .text(let font):
                if let text = annotation.text {
                    Text(text)
                        .font(Font(font))
                        .foregroundColor(Color(annotation.color ?? .white))
                        .position(x: annotation.rect.origin.x + annotation.rect.width / 2,
                                  y: annotation.rect.origin.y + annotation.rect.height / 2)
                }
            case .arrow(let start, let end, let lineWidth):
                ArrowShape(start: start, end: end)
                    .stroke(Color(annotation.color ?? .red), lineWidth: lineWidth)
            case .pen(let points, let lineWidth):
                PenShape(points: points)
                    .stroke(Color(annotation.color ?? .red), lineWidth: lineWidth)
            case .highlight:
                Rectangle()
                    .fill(Color(annotation.color ?? .yellow))
                    .frame(width: annotation.rect.width, height: annotation.rect.height)
                    .position(x: annotation.rect.midX, y: annotation.rect.midY)
            }
        }
        .overlay {
            if isSelected {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: annotation.rect.width + 4, height: annotation.rect.height + 4)
                    .position(x: annotation.rect.midX, y: annotation.rect.midY)
            }
        }
    }
}

struct BlurAnnotationView: View {
    let annotation: Annotation
    
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(width: annotation.rect.width, height: annotation.rect.height)
            .position(x: annotation.rect.midX, y: annotation.rect.midY)
    }
}

struct PixelateAnnotationView: View {
    let annotation: Annotation
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.5))
            .frame(width: annotation.rect.width, height: annotation.rect.height)
            .position(x: annotation.rect.midX, y: annotation.rect.midY)
    }
}

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: start)
        path.addLine(to: end)
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)
        
        return path
    }
}

struct PenShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        return path
    }
}

struct CurrentToolPreview: View {
    let tool: EditorTool
    let drag: DragState
    let penPoints: [CGPoint]
    let options: ToolOptions
    
    var body: some View {
        Group {
            switch tool {
            case .crop:
                CropPreview(rect: drag.rect)
            case .blur, .pixelate:
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .background(Color.accentColor.opacity(0.1))
                    .frame(width: drag.rect.width, height: drag.rect.height)
                    .position(x: drag.rect.midX, y: drag.rect.midY)
            case .solidRect:
                Rectangle()
                    .fill(Color(options.strokeColor))
                    .frame(width: drag.rect.width, height: drag.rect.height)
                    .position(x: drag.rect.midX, y: drag.rect.midY)
            case .arrow:
                ArrowShape(start: drag.start, end: drag.current)
                    .stroke(Color(options.strokeColor), lineWidth: options.lineWidth)
            case .pen:
                PenShape(points: penPoints)
                    .stroke(Color(options.strokeColor), lineWidth: options.lineWidth)
            case .highlight:
                Rectangle()
                    .fill(Color(options.strokeColor).opacity(0.3))
                    .frame(width: drag.rect.width, height: drag.rect.height)
                    .position(x: drag.rect.midX, y: drag.rect.midY)
            default:
                EmptyView()
            }
        }
    }
}

struct CropPreview: View {
    let rect: CGRect
    
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .background(Color.clear)
            
            Rectangle()
                .stroke(Color.black, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            VStack {
                HStack {
                    cropHandle
                    Spacer()
                    cropHandle
                }
                Spacer()
                HStack {
                    cropHandle
                    Spacer()
                    cropHandle
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }
    
    private var cropHandle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
    }
}
