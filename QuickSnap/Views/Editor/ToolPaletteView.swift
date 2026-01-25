import SwiftUI

struct ToolPaletteView: View {
    @Binding var selectedTool: EditorTool
    @Binding var toolOptions: ToolOptions
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(EditorTool.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: selectedTool == tool
                ) {
                    selectedTool = tool
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            ColorPicker("", selection: Binding(
                get: { Color(toolOptions.strokeColor) },
                set: { toolOptions.strokeColor = NSColor($0) }
            ))
            .labelsHidden()
            .frame(width: 36, height: 36)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 60)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                    )
                    .foregroundColor(foregroundColor)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tool.displayName)
        .keyboardShortcut(keyboardShortcut, modifiers: [])
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.3)
        }
        return Color.clear
    }
    
    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }
    
    private var keyboardShortcut: KeyEquivalent {
        switch tool {
        case .select: return "v"
        case .crop: return "c"
        case .blur: return "b"
        case .pixelate: return "x"
        case .solidRect: return "r"
        case .text: return "t"
        case .arrow: return "a"
        case .pen: return "p"
        case .highlight: return "h"
        }
    }
}

#Preview {
    ToolPaletteView(
        selectedTool: .constant(.select),
        toolOptions: .constant(ToolOptions())
    )
}
