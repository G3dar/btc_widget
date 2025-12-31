import Foundation

/// Represents a trading pair where the buy order has been placed but the sell order
/// is waiting until the buy fills. The intended sell price is stored locally.
struct PendingPair: Codable, Identifiable, Sendable {
    let id: UUID
    let buyOrderId: Int64           // Binance order ID for the buy order
    var intendedSellPrice: Double   // NOT an order yet - just stored locally
    let buyPrice: Double            // The price at which we're trying to buy
    let quantity: Double            // BTC quantity
    let amountUSD: Double           // USD amount invested
    let createdAt: Date

    init(buyOrderId: Int64, buyPrice: Double, intendedSellPrice: Double, quantity: Double, amountUSD: Double) {
        self.id = UUID()
        self.buyOrderId = buyOrderId
        self.buyPrice = buyPrice
        self.intendedSellPrice = intendedSellPrice
        self.quantity = quantity
        self.amountUSD = amountUSD
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    /// Estimated gross profit if buy fills and sell executes at intended price
    var estimatedGrossProfit: Double {
        (intendedSellPrice - buyPrice) * quantity
    }

    /// Estimated commission (0.1% per trade, both buy and sell)
    var estimatedCommission: Double {
        let buyCommission = amountUSD * 0.001
        let sellValue = intendedSellPrice * quantity
        let sellCommission = sellValue * 0.001
        return buyCommission + sellCommission
    }

    /// Estimated net profit after commissions
    var estimatedNetProfit: Double {
        estimatedGrossProfit - estimatedCommission
    }

    /// Estimated profit percentage
    var estimatedProfitPercentage: Double {
        guard amountUSD > 0 else { return 0 }
        return (estimatedNetProfit / amountUSD) * 100
    }

    /// Formatted estimated profit string
    var formattedEstimatedProfit: String {
        let sign = estimatedNetProfit >= 0 ? "+" : ""
        return "\(sign)\(estimatedNetProfit.formatAsCurrency(maximumFractionDigits: 2))"
    }

    /// Formatted profit percentage string
    var formattedProfitPercentage: String {
        let sign = estimatedProfitPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", estimatedProfitPercentage))%"
    }

    /// Time ago string for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
