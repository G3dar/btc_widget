import SwiftUI

struct ProfitHistoryView: View {
    let completedPairs: [CompletedGridPair]
    let isLoading: Bool

    private var totalProfit: Double {
        completedPairs.reduce(0) { $0 + $1.netProfitUSD }
    }

    private var totalTrades: Int {
        completedPairs.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with total profit
            HStack {
                Text("PROFIT HISTORY")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if !completedPairs.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(totalTrades) trades")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(totalProfit >= 0 ? "+\(totalProfit.formatAsCurrency(maximumFractionDigits: 2))" : totalProfit.formatAsCurrency(maximumFractionDigits: 2))
                            .font(.caption.bold())
                            .foregroundColor(totalProfit >= 0 ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 4)

            if completedPairs.isEmpty && !isLoading {
                emptyStateView
            } else {
                // Scrollable list of completed trades
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(completedPairs) { pair in
                            CompletedTradeCard(pair: pair)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.5))
                Text("No completed trades yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            Spacer()
        }
    }
}

// MARK: - Completed Trade Card

struct CompletedTradeCard: View {
    let pair: CompletedGridPair

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: pair.completedAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Net Profit (after commissions)
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                Text("+\(pair.netProfitUSD.formatAsCurrency(maximumFractionDigits: 2))")
                    .font(.caption.bold())
            }
            .foregroundColor(.green)

            // Net percentage and invested amount
            HStack(spacing: 4) {
                Text("+\(String(format: "%.2f", pair.netProfitPercentage))%")
                    .foregroundColor(.green.opacity(0.8))
                Text("•")
                    .foregroundColor(.secondary)
                Text(pair.investedAmount.formatAsCurrency(maximumFractionDigits: 0))
                    .foregroundColor(.secondary)
            }
            .font(.caption2)

            // Buy → Sell prices
            HStack(spacing: 2) {
                Text(pair.buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                    .foregroundColor(.green)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(pair.sellPrice.formatAsCurrency(maximumFractionDigits: 0))
                    .foregroundColor(.red)
            }
            .font(.caption2)

            // Time
            Text(timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // With data
        ProfitHistoryView(
            completedPairs: [
                CompletedGridPair(
                    buyTrade: BinanceTrade(
                        id: 1,
                        orderId: 100,
                        symbol: "BTCUSDT",
                        price: "95000.00",
                        qty: "0.02",
                        quoteQty: "1900.00",
                        commission: "0.00002",
                        commissionAsset: "BTC",
                        time: Int64(Date().timeIntervalSince1970 * 1000) - 3600000,
                        isBuyer: true,
                        isMaker: true
                    ),
                    sellTrade: BinanceTrade(
                        id: 2,
                        orderId: 101,
                        symbol: "BTCUSDT",
                        price: "98000.00",
                        qty: "0.02",
                        quoteQty: "1960.00",
                        commission: "0.00002",
                        commissionAsset: "BTC",
                        time: Int64(Date().timeIntervalSince1970 * 1000),
                        isBuyer: false,
                        isMaker: true
                    )
                ),
                CompletedGridPair(
                    buyTrade: BinanceTrade(
                        id: 3,
                        orderId: 102,
                        symbol: "BTCUSDT",
                        price: "92000.00",
                        qty: "0.025",
                        quoteQty: "2300.00",
                        commission: "0.000025",
                        commissionAsset: "BTC",
                        time: Int64(Date().timeIntervalSince1970 * 1000) - 86400000,
                        isBuyer: true,
                        isMaker: true
                    ),
                    sellTrade: BinanceTrade(
                        id: 4,
                        orderId: 103,
                        symbol: "BTCUSDT",
                        price: "96500.00",
                        qty: "0.025",
                        quoteQty: "2412.50",
                        commission: "0.000025",
                        commissionAsset: "BTC",
                        time: Int64(Date().timeIntervalSince1970 * 1000) - 43200000,
                        isBuyer: false,
                        isMaker: true
                    )
                )
            ],
            isLoading: false
        )

        // Empty state
        ProfitHistoryView(
            completedPairs: [],
            isLoading: false
        )

        // Loading state
        ProfitHistoryView(
            completedPairs: [],
            isLoading: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
