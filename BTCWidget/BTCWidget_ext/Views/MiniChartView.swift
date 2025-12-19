import SwiftUI
import WidgetKit

struct MiniChartView: View {
    let prices: [PricePoint]
    let isPositive: Bool
    let lineWidth: CGFloat
    let showGradient: Bool

    init(prices: [PricePoint], isPositive: Bool = true, lineWidth: CGFloat = 1.5, showGradient: Bool = false) {
        self.prices = prices
        self.isPositive = isPositive
        self.lineWidth = lineWidth
        self.showGradient = showGradient
    }

    var body: some View {
        GeometryReader { geometry in
            let data = prices.map { $0.price }
            let minPrice = data.min() ?? 0
            let maxPrice = data.max() ?? 1
            let range = maxPrice - minPrice
            let normalizedRange = range > 0 ? range : 1

            let path = createPath(
                data: data,
                minPrice: minPrice,
                normalizedRange: normalizedRange,
                size: geometry.size
            )

            ZStack {
                if showGradient {
                    let gradientPath = createGradientPath(
                        data: data,
                        minPrice: minPrice,
                        normalizedRange: normalizedRange,
                        size: geometry.size
                    )

                    gradientPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isPositive ? Color.green : Color.red).opacity(0.3),
                                    (isPositive ? Color.green : Color.red).opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                path
                    .stroke(
                        isPositive ? Color.green : Color.red,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private func createPath(data: [Double], minPrice: Double, normalizedRange: Double, size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }

            let stepX = size.width / CGFloat(data.count - 1)

            for (index, price) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = (price - minPrice) / normalizedRange
                let y = size.height - (CGFloat(normalizedY) * size.height)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func createGradientPath(data: [Double], minPrice: Double, normalizedRange: Double, size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }

            let stepX = size.width / CGFloat(data.count - 1)

            // Start at bottom left
            path.move(to: CGPoint(x: 0, y: size.height))

            // Draw line to first data point
            let firstNormalizedY = (data[0] - minPrice) / normalizedRange
            let firstY = size.height - (CGFloat(firstNormalizedY) * size.height)
            path.addLine(to: CGPoint(x: 0, y: firstY))

            // Draw along data points
            for (index, price) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = (price - minPrice) / normalizedRange
                let y = size.height - (CGFloat(normalizedY) * size.height)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            // Close path at bottom right
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}

// Lock Screen version (monochrome)
struct MonochromeMiniChartView: View {
    let prices: [PricePoint]
    let lineWidth: CGFloat

    init(prices: [PricePoint], lineWidth: CGFloat = 1.5) {
        self.prices = prices
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geometry in
            let data = prices.map { $0.price }
            let minPrice = data.min() ?? 0
            let maxPrice = data.max() ?? 1
            let range = maxPrice - minPrice
            let normalizedRange = range > 0 ? range : 1

            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)

                for (index, price) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (price - minPrice) / normalizedRange
                    let y = geometry.size.height - (CGFloat(normalizedY) * geometry.size.height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview("Chart Preview") {
    VStack(spacing: 20) {
        MiniChartView(
            prices: BitcoinData.placeholder.priceHistory,
            isPositive: true,
            showGradient: true
        )
        .frame(height: 50)

        MiniChartView(
            prices: BitcoinData.placeholder.priceHistory,
            isPositive: false,
            showGradient: true
        )
        .frame(height: 50)

        MonochromeMiniChartView(
            prices: BitcoinData.placeholder.priceHistory
        )
        .frame(height: 30)
    }
    .padding()
}
