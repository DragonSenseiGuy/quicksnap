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



#Preview {
    RegionSelectorView(isPresented: .constant(true)) { rect in
        print("Selected: \(rect)")
    }
    .frame(width: 800, height: 600)
}
