import SwiftUI

struct DualPriceSlider: View {
    @Binding var buyPrice: Double
    @Binding var sellPrice: Double
    let currentPrice: Double
    let minPrice: Double  // 90% of current
    let maxPrice: Double  // 110% of current

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 28
    private let maxPercent: Double = 10.0
    // Power < 1 gives more space to smaller percentages
    private let scalePower: Double = 0.5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let halfWidth = width / 2

            VStack(spacing: 4) {
                // Percentage tick marks
                tickMarks(width: width, halfWidth: halfWidth)

                ZStack(alignment: .leading) {
                    // Track background with gradient (green left, red right)
                    trackBackground(width: width, halfWidth: halfWidth)

                    // Current price marker
                    currentPriceMarker(halfWidth: halfWidth)

                    // Buy thumb (green, left side)
                    buyThumbView(halfWidth: halfWidth)

                    // Sell thumb (red, right side)
                    sellThumbView(width: width, halfWidth: halfWidth)
                }
                .frame(height: thumbSize)
            }
        }
        .frame(height: thumbSize + 24)
    }

    // MARK: - Non-linear Scale Functions

    // Convert percentage (0-10) to visual position (0-1) with non-linear scale
    private func percentToPosition(_ percent: Double) -> Double {
        pow(percent / maxPercent, scalePower)
    }

    // Convert visual position (0-1) to percentage (0-10) with non-linear scale
    private func positionToPercent(_ position: Double) -> Double {
        pow(position, 1 / scalePower) * maxPercent
    }

    // MARK: - Tick Marks

    private func tickMarks(width: CGFloat, halfWidth: CGFloat) -> some View {
        let percentages = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        return ZStack {
            // Left side ticks (buy side - below current price)
            ForEach(percentages, id: \.self) { percent in
                let pos = percentToPosition(Double(percent))
                let xOffset = halfWidth - (halfWidth * pos)

                VStack(spacing: 1) {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: 1, height: percent % 5 == 0 ? 8 : 4)

                    if percent % 2 == 0 || percent == 1 {
                        Text("\(percent)%")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .offset(x: xOffset - halfWidth)
            }

            // Right side ticks (sell side - above current price)
            ForEach(percentages, id: \.self) { percent in
                let pos = percentToPosition(Double(percent))
                let xOffset = halfWidth + (halfWidth * pos)

                VStack(spacing: 1) {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: 1, height: percent % 5 == 0 ? 8 : 4)

                    if percent % 2 == 0 || percent == 1 {
                        Text("\(percent)%")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .offset(x: xOffset - halfWidth)
            }
        }
        .frame(height: 16)
    }

    // MARK: - Track Background

    private func trackBackground(width: CGFloat, halfWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Full track
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(Color(.systemGray5))
                .frame(height: trackHeight)

            // Green zone (left of current price)
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(Color.green.opacity(0.3))
                .frame(width: halfWidth, height: trackHeight)

            // Red zone (right of current price)
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(Color.red.opacity(0.3))
                .frame(width: halfWidth, height: trackHeight)
                .offset(x: halfWidth)
        }
    }

    // MARK: - Current Price Marker

    private func currentPriceMarker(halfWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundColor(.orange)

            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: thumbSize)
        }
        .offset(x: halfWidth - 4, y: -4)
    }

    // MARK: - Buy Thumb (left side)

    private func buyThumbView(halfWidth: CGFloat) -> some View {
        // Calculate buy percentage below current price
        let buyPercent = ((currentPrice - buyPrice) / currentPrice) * 100
        let clampedPercent = min(max(buyPercent, 0), maxPercent)
        let pos = percentToPosition(clampedPercent)
        let xOffset = halfWidth - (halfWidth * pos) - thumbSize / 2

        return Circle()
            .fill(Color.green)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: Color.green.opacity(0.4), radius: 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .overlay(
                Text(String(format: "%.1f", clampedPercent))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            )
            .offset(x: xOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Convert gesture position to percentage using non-linear scale
                        let relativeX = halfWidth - gesture.location.x
                        let normalizedPos = max(0, min(1, relativeX / halfWidth))
                        let percent = positionToPercent(normalizedPos)
                        let newPrice = currentPrice * (1 - percent / 100)
                        // Snap to nearest $10
                        buyPrice = (newPrice / 10).rounded() * 10
                    }
            )
    }

    // MARK: - Sell Thumb (right side)

    private func sellThumbView(width: CGFloat, halfWidth: CGFloat) -> some View {
        // Calculate sell percentage above current price
        let sellPercent = ((sellPrice - currentPrice) / currentPrice) * 100
        let clampedPercent = min(max(sellPercent, 0), maxPercent)
        let pos = percentToPosition(clampedPercent)
        let xOffset = halfWidth + (halfWidth * pos) - thumbSize / 2

        return Circle()
            .fill(Color.red)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .overlay(
                Text(String(format: "%.1f", clampedPercent))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            )
            .offset(x: xOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Convert gesture position to percentage using non-linear scale
                        let relativeX = gesture.location.x - halfWidth
                        let normalizedPos = max(0, min(1, relativeX / halfWidth))
                        let percent = positionToPercent(normalizedPos)
                        let newPrice = currentPrice * (1 + percent / 100)
                        // Snap to nearest $10
                        sellPrice = (newPrice / 10).rounded() * 10
                    }
            )
    }
}

// MARK: - Compact Version for Grid Pairs

struct GridPairSlider: View {
    let buyPrice: Double
    let sellPrice: Double
    let currentPrice: Double

    private let trackHeight: CGFloat = 6
    private let dotSize: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Calculate range based on actual order prices with some padding
            let minPrice = min(buyPrice, currentPrice * 0.88)
            let maxPrice = max(sellPrice, currentPrice * 1.12)
            let range = maxPrice - minPrice

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(.systemGray5))
                    .frame(height: trackHeight)

                // Filled area between buy and sell
                let buyPos = (buyPrice - minPrice) / range
                let sellPos = (sellPrice - minPrice) / range
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.5), .red.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * (sellPos - buyPos), height: trackHeight)
                    .offset(x: width * buyPos)

                // Current price marker
                let currentPos = (currentPrice - minPrice) / range
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: trackHeight + 8)
                    .offset(x: width * currentPos - 1)

                // Buy dot (green)
                Circle()
                    .fill(Color.green)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: width * buyPos - dotSize / 2)

                // Sell dot (red)
                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: width * sellPos - dotSize / 2)
            }
        }
        .frame(height: trackHeight + 8)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var buyPrice: Double = 95000
        @State private var sellPrice: Double = 101000
        let currentPrice: Double = 98000

        var body: some View {
            VStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Grid Pair")
                        .font(.headline)

                    DualPriceSlider(
                        buyPrice: $buyPrice,
                        sellPrice: $sellPrice,
                        currentPrice: currentPrice,
                        minPrice: currentPrice * 0.9,
                        maxPrice: currentPrice * 1.1
                    )

                    HStack {
                        Text("Buy: $\(Int(buyPrice))")
                            .foregroundColor(.green)
                        Spacer()
                        Text("Current: $\(Int(currentPrice))")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("Sell: $\(Int(sellPrice))")
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Grid Pair")
                        .font(.headline)

                    GridPairSlider(
                        buyPrice: 95000,
                        sellPrice: 101000,
                        currentPrice: 98000
                    )
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
