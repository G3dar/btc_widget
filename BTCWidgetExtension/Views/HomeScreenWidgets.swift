import SwiftUI
import WidgetKit

// MARK: - Small Home Screen Widget
struct HomeScreenSmallView: View {
    let entry: PriceEntry

    var body: some View {
        let data = entry.bitcoinData
        let isPositive = data.percentChange6h >= 0

        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Spacer()
                PercentBadge(percent: data.percentChange6h, isPositive: isPositive)
            }

            Spacer()

            // Price
            Text(formatPrice(data.currentPrice))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            // Mini chart
            MiniChartView(
                prices: data.priceHistory,
                isPositive: isPositive,
                lineWidth: 2,
                showGradient: false
            )
            .frame(height: 30)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
}

// MARK: - Medium Home Screen Widget
struct HomeScreenMediumView: View {
    let entry: PriceEntry

    var body: some View {
        let data = entry.bitcoinData
        let isPositive = data.percentChange6h >= 0

        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                        Text("Bitcoin")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(formatPrice(data.currentPrice))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                PercentBadge(percent: data.percentChange6h, isPositive: isPositive, size: .large)
            }

            // Chart
            MiniChartView(
                prices: data.priceHistory,
                isPositive: isPositive,
                lineWidth: 2.5,
                showGradient: true
            )
            .frame(maxHeight: .infinity)

            // Footer: High/Low
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                    Text(formatPrice(data.high6h))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)
                    Text(formatPrice(data.low6h))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("6h")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
}

// MARK: - Percent Badge Component
struct PercentBadge: View {
    let percent: Double
    let isPositive: Bool
    var size: BadgeSize = .small

    enum BadgeSize {
        case small, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .large: return 14
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .large: return 6
            }
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: size.fontSize - 2, weight: .bold))
            Text(String(format: "%.1f%%", abs(percent)))
                .font(.system(size: size.fontSize, weight: .semibold))
        }
        .foregroundStyle(isPositive ? .green : .red)
        .padding(.horizontal, size.padding + 2)
        .padding(.vertical, size.padding)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((isPositive ? Color.green : Color.red).opacity(0.15))
        )
    }
}

// MARK: - Home Screen Widget Definition
struct BTCHomeScreenWidget: Widget {
    let kind: String = "BTCHomeScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BTCTimelineProvider()) { entry in
            HomeScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Track Bitcoin price with charts")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

struct HomeScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PriceEntry

    var body: some View {
        switch family {
        case .systemSmall:
            HomeScreenSmallView(entry: entry)
        case .systemMedium:
            HomeScreenMediumView(entry: entry)
        default:
            HomeScreenSmallView(entry: entry)
        }
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    BTCHomeScreenWidget()
} timeline: {
    PriceEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    BTCHomeScreenWidget()
} timeline: {
    PriceEntry.placeholder
}
