import SwiftUI
import Charts

struct InteractiveChartView: View {
    let data: BitcoinData
    let selectedRange: TimeRange

    @State private var selectedPoint: PricePoint?
    @State private var plotWidth: CGFloat = 0

    private var lineColor: Color {
        data.isPositive ? Color.green : Color.red
    }

    private var gradientColors: [Color] {
        [lineColor.opacity(0.3), lineColor.opacity(0.0)]
    }

    // Minimum 4% range for Y-axis to avoid exaggerating small fluctuations
    private var yAxisRange: (min: Double, max: Double) {
        let prices = data.priceHistory.map { $0.price }
        let dataMin = prices.min() ?? data.currentPrice
        let dataMax = prices.max() ?? data.currentPrice
        let midPrice = (dataMin + dataMax) / 2

        // Minimum range is 4% of the mid price (2% above and below)
        let minRange = midPrice * 0.04
        let actualRange = dataMax - dataMin

        if actualRange >= minRange {
            // Data range is already >= 4%, use actual data with small margin
            return (dataMin * 0.999, dataMax * 1.001)
        } else {
            // Expand to minimum 4% range, centered on midpoint
            let halfMinRange = minRange / 2
            return (midPrice - halfMinRange, midPrice + halfMinRange)
        }
    }

    private var yAxisMin: Double {
        yAxisRange.min
    }

    private var yAxisMax: Double {
        yAxisRange.max
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selected = selectedPoint {
                selectedPriceOverlay(point: selected)
            } else {
                Spacer().frame(height: 50)
            }

            chartView
        }
    }

    private func selectedPriceOverlay(point: PricePoint) -> some View {
        VStack(spacing: 4) {
            Text(point.price.formatAsCurrency(maximumFractionDigits: 2))
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text(point.timestamp.formattedForChart(in: selectedRange))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 50)
        .animation(.easeInOut(duration: 0.1), value: selectedPoint?.id)
    }

    private var chartView: some View {
        Chart {
            ForEach(data.priceHistory) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Min", yAxisMin),
                    yEnd: .value("Price", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.timestamp))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                PointMark(
                    x: .value("Time", selected.timestamp),
                    y: .value("Price", selected.price)
                )
                .foregroundStyle(lineColor)
                .symbolSize(100)
            }
        }
        .chartYScale(domain: yAxisMin...yAxisMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formattedForChart(in: selectedRange))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price.formatAsCompactCurrency())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectPoint(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                selectedPoint = nil
                            }
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private func selectPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x

        guard xPosition >= 0,
              let date: Date = proxy.value(atX: xPosition) else {
            return
        }

        // Find the closest data point
        let closest = data.priceHistory.min { a, b in
            abs(a.timestamp.timeIntervalSince(date)) < abs(b.timestamp.timeIntervalSince(date))
        }

        if let closest = closest {
            selectedPoint = closest
        }
    }
}

#Preview {
    InteractiveChartView(
        data: BitcoinData.placeholder(for: .twentyFourHours),
        selectedRange: .twentyFourHours
    )
    .frame(height: 300)
    .padding()
}
