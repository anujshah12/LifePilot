import SwiftUI

struct ColorPickerGrid: View {
    @Binding var selectedColorHex: String

    static let presetColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#30B0C7", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93",
        "#FF6482", "#FFD60A", "#64D2FF", "#BF5AF2"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Self.presetColors, id: \.self) { hex in
                colorCircle(hex: hex)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func colorCircle(hex: String) -> some View {
        let isSelected = selectedColorHex.uppercased() == hex.uppercased()

        ZStack {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 44, height: 44)

            if isSelected {
                Circle()
                    .strokeBorder(Color(hex: hex), lineWidth: 3)
                    .frame(width: 54, height: 54)

                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .frame(width: 54, height: 54)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedColorHex = hex
            }
        }
        .accessibilityLabel("Color \(hex)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selected = "#007AFF"
        var body: some View {
            VStack {
                ColorPickerGrid(selectedColorHex: $selected)
                Text("Selected: \(selected)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
