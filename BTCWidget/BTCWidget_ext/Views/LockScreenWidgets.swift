import SwiftUI
import WidgetKit

// MARK: - Rectangular Lock Screen Widget (Main)
struct LockScreenRectangularView: View {
    let entry: PriceEntry

    var body: some View {
        let data = entry.bitcoinData

        VStack(alignment: .leading, spacing: 2) {
            // Top row: Bitcoin icon + price
            HStack(spacing: 4) {
                Text("\u{20BF}")
                    .font(.system(size: 14, weight: .bold))
                Text(formatPrice(data.currentPrice))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            // Bottom row: Chart + High/Low
            HStack(spacing: 6) {
                MonochromeMiniChartView(prices: data.priceHistory, lineWidth: 1.2)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8))
                        Text(formatCompactPrice(data.high6h))
                            .font(.system(size: 9))
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8))
                        Text(formatCompactPrice(data.low6h))
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }

    private func formatCompactPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.1fk", price / 1000)
        }
        return String(format: "%.0f", price)
    }
}

// MARK: - Circular Lock Screen Widget
struct LockScreenCircularView: View {
    let entry: PriceEntry

    var body: some View {
        let data = entry.bitcoinData

        VStack(spacing: 1) {
            Text("\u{20BF}")
                .font(.system(size: 12, weight: .bold))

            Text(formatCompactPrice(data.currentPrice))
                .font(.system(size: 12, weight: .semibold))
                .minimumScaleFactor(0.8)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatCompactPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.1fk", price / 1000)
        }
        return String(format: "%.0f", price)
    }
}

// MARK: - Inline Lock Screen Widget
struct LockScreenInlineView: View {
    let entry: PriceEntry

    var body: some View {
        let data = entry.bitcoinData

        HStack(spacing: 4) {
            Text("\u{20BF}")
            Text(formatPrice(data.currentPrice))
        }
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
}

// MARK: - Lock Screen Widget Definition
struct BTCLockScreenWidget: Widget {
    let kind: String = "BTCLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BTCTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("View Bitcoin price on your Lock Screen")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PriceEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            LockScreenRectangularView(entry: entry)
        }
    }
}

// MARK: - Previews
#Preview("Rectangular", as: .accessoryRectangular) {
    BTCLockScreenWidget()
} timeline: {
    PriceEntry.placeholder
}

#Preview("Circular", as: .accessoryCircular) {
    BTCLockScreenWidget()
} timeline: {
    PriceEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    BTCLockScreenWidget()
} timeline: {
    PriceEntry.placeholder
}
