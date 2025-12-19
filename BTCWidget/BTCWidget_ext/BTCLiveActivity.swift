import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

struct BTCActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPrice: Double
        var percentChange: Double
        var lastUpdated: Date

        var isPositive: Bool {
            percentChange >= 0
        }

        var formattedPrice: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: currentPrice)) ?? "$\(Int(currentPrice))"
        }

        var formattedChange: String {
            let sign = percentChange >= 0 ? "+" : ""
            return sign + String(format: "%.2f%%", percentChange)
        }
    }

    // Fixed properties (don't change during activity)
    var activityName: String
}

// MARK: - Live Activity Widget

struct BTCLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BTCActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                        Text("BTC")
                            .font(.headline)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedChange)
                        .font(.headline.bold())
                        .foregroundStyle(context.state.isPositive ? .green : .red)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.formattedPrice)
                        .font(.title.bold())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Updated \(context.state.lastUpdated, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.formattedPrice)
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    func lockScreenView(context: ActivityViewContext<BTCActivityAttributes>) -> some View {
        HStack {
            // Bitcoin icon and label
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bitcoin")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(context.state.formattedPrice)
                        .font(.title2.bold())
                }
            }

            Spacer()

            // Change indicator
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: context.state.isPositive ? "arrow.up.right" : "arrow.down.right")
                    Text(context.state.formattedChange)
                }
                .font(.headline.bold())
                .foregroundStyle(context.state.isPositive ? .green : .red)

                Text(context.state.lastUpdated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Preview

#Preview("Live Activity", as: .content, using: BTCActivityAttributes(activityName: "BTC Price")) {
    BTCLiveActivity()
} contentStates: {
    BTCActivityAttributes.ContentState(
        currentPrice: 97432.00,
        percentChange: 2.34,
        lastUpdated: Date()
    )
    BTCActivityAttributes.ContentState(
        currentPrice: 95100.00,
        percentChange: -1.23,
        lastUpdated: Date().addingTimeInterval(-120)
    )
}
