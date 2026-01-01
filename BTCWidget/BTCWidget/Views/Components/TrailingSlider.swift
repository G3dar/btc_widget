import SwiftUI

/// Reusable slider component for configuring trailing percentage
struct TrailingSlider: View {
    @Binding var trailingPercent: Double
    let title: String
    let subtitle: String
    let color: Color

    private let presets: [Double] = [0, 0.5, 1.0, 2.0]

    private var isEnabled: Bool {
        trailingPercent > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(isEnabled ? color : .primary)

                Spacer()

                if isEnabled {
                    Text("\(String(format: "%.1f", trailingPercent))%")
                        .font(.subheadline.bold())
                        .foregroundColor(color)
                }
            }

            // Subtitle explanation
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            // Preset buttons
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trailingPercent = preset
                        }
                    } label: {
                        Text(preset == 0 ? "OFF" : "\(String(format: "%.1f", preset))%")
                            .font(.caption.bold())
                            .foregroundColor(trailingPercent == preset ? .white : color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(trailingPercent == preset ? color : color.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Fine-tune slider when enabled
            if isEnabled {
                VStack(spacing: 4) {
                    Slider(value: $trailingPercent, in: 0.1...5.0, step: 0.1)
                        .tint(color)

                    HStack {
                        Text("0.1%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("5%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? color.opacity(0.1) : Color(.systemGray6))
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        TrailingSlider(
            trailingPercent: .constant(0),
            title: "Buy Trailing",
            subtitle: "Order follows price down",
            color: .green
        )

        TrailingSlider(
            trailingPercent: .constant(1.0),
            title: "Sell Trailing",
            subtitle: "Order follows price up",
            color: .red
        )
    }
    .padding()
}
