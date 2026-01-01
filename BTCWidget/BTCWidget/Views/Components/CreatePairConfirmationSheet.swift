import SwiftUI

/// Confirmation sheet for creating a trading pair with optional trailing orders
struct CreatePairConfirmationSheet: View {
    let buyPrice: Double
    let sellPrice: Double
    let amount: Double
    let currentPrice: Double
    let isSafeMode: Bool

    @Binding var buyTrailingPercent: Double
    @Binding var sellTrailingPercent: Double

    let onCreate: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var profit: ProfitCalculation {
        ProfitCalculation(buyPrice: buyPrice, sellPrice: sellPrice, amount: amount)
    }

    private var quantity: Double {
        amount / buyPrice
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Order Summary
                    orderSummarySection

                    Divider()

                    // Trailing Options
                    trailingOptionsSection

                    // Profit Preview
                    profitPreviewSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Create Trading Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Order Summary Section

    private var orderSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ORDER SUMMARY")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                // Buy
                VStack(spacing: 4) {
                    Text("BUY")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.title3.bold())
                        .foregroundColor(.green)
                    Text("(-\(String(format: "%.1f", (1 - buyPrice/currentPrice) * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                // Sell
                VStack(spacing: 4) {
                    Text("SELL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sellPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.title3.bold())
                        .foregroundColor(.red)
                    Text("(+\(String(format: "%.1f", (sellPrice/currentPrice - 1) * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )

            // Amount and quantity
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AMOUNT")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(amount.formatAsCurrency(maximumFractionDigits: 2))
                            .font(.subheadline.bold())
                        if isSafeMode {
                            Text("(SAFE)")
                                .font(.caption2.bold())
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("QUANTITY")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.6f", quantity)) BTC")
                        .font(.subheadline.bold())
                }
            }
        }
    }

    // MARK: - Trailing Options Section

    private var trailingOptionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("TRAILING OPTIONS")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if buyTrailingPercent > 0 || sellTrailingPercent > 0 {
                    Text("ENABLED")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                }
            }

            // Info banner
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Trailing orders automatically adjust prices as the market moves in your favor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )

            // Buy Trailing
            TrailingSlider(
                trailingPercent: $buyTrailingPercent,
                title: "Buy Trailing",
                subtitle: "Order follows price down as BTC drops",
                color: .green
            )

            // Sell Trailing
            TrailingSlider(
                trailingPercent: $sellTrailingPercent,
                title: "Sell Trailing",
                subtitle: "Order follows price up as BTC rises",
                color: .red
            )
        }
    }

    // MARK: - Profit Preview Section

    private var profitPreviewSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PROFIT PREVIEW")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Profit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(profit.formattedProfit)
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("(\(profit.formattedPercentage))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("After Fees")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(profit.formattedCommission)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )

            // Trailing note if enabled
            if buyTrailingPercent > 0 || sellTrailingPercent > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        if buyTrailingPercent > 0 {
                            Text("Buy trails \(String(format: "%.1f", buyTrailingPercent))% above lowest price")
                                .font(.caption2)
                        }
                        if sellTrailingPercent > 0 {
                            Text("Sell trails \(String(format: "%.1f", sellTrailingPercent))% below highest price")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
}

#Preview {
    CreatePairConfirmationSheet(
        buyPrice: 95000,
        sellPrice: 100000,
        amount: 2000,
        currentPrice: 97000,
        isSafeMode: false,
        buyTrailingPercent: .constant(0),
        sellTrailingPercent: .constant(1.0),
        onCreate: {},
        onCancel: {}
    )
}
