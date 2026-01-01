import Foundation
import Combine

// MARK: - Order Models

struct BinanceOrder: Identifiable, Codable, Sendable {
    let orderId: Int64
    let symbol: String
    let side: String
    let type: String
    let price: String
    let origQty: String
    let executedQty: String
    let status: String
    let time: Int64

    var id: Int64 { orderId }

    var orderSide: OrderSide {
        OrderSide(rawValue: side) ?? .buy
    }

    var orderStatus: OrderStatus {
        OrderStatus(rawValue: status) ?? .new
    }

    var priceDouble: Double {
        Double(price) ?? 0
    }

    var quantityDouble: Double {
        Double(origQty) ?? 0
    }

    var executedQuantityDouble: Double {
        Double(executedQty) ?? 0
    }

    var usdValue: Double {
        priceDouble * quantityDouble
    }

    var timeDate: Date {
        Date(timeIntervalSince1970: Double(time) / 1000)
    }
}

enum OrderSide: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }
}

enum OrderType: String, Codable {
    case limit = "LIMIT"
    case market = "MARKET"
    case stopLoss = "STOP_LOSS"
    case stopLossLimit = "STOP_LOSS_LIMIT"
    case takeProfit = "TAKE_PROFIT"
    case takeProfitLimit = "TAKE_PROFIT_LIMIT"
}

enum OrderStatus: String, Codable {
    case new = "NEW"
    case partiallyFilled = "PARTIALLY_FILLED"
    case filled = "FILLED"
    case canceled = "CANCELED"
    case pendingCancel = "PENDING_CANCEL"
    case rejected = "REJECTED"
    case expired = "EXPIRED"

    var isActive: Bool {
        switch self {
        case .new, .partiallyFilled:
            return true
        default:
            return false
        }
    }
}

enum TimeInForce: String, Codable {
    case gtc = "GTC"  // Good Till Cancel
    case ioc = "IOC"  // Immediate or Cancel
    case fok = "FOK"  // Fill or Kill
}

// MARK: - Account Balance

struct AccountBalance: Codable, Sendable {
    let balances: [AssetBalance]

    func balance(for asset: String) -> AssetBalance? {
        balances.first { $0.asset == asset }
    }

    var usdtBalance: Double {
        balance(for: "USDT")?.totalDouble ?? 0
    }

    var btcBalance: Double {
        balance(for: "BTC")?.totalDouble ?? 0
    }
}

struct AssetBalance: Codable, Identifiable, Sendable {
    let asset: String
    let free: String
    let locked: String

    var id: String { asset }

    var freeDouble: Double {
        Double(free) ?? 0
    }

    var lockedDouble: Double {
        Double(locked) ?? 0
    }

    var totalDouble: Double {
        freeDouble + lockedDouble
    }
}

// MARK: - API Response Models

struct BinanceAccountInfo: Codable, Sendable {
    let balances: [AssetBalance]
    let canTrade: Bool
    let canWithdraw: Bool
    let canDeposit: Bool
}

struct NewOrderResponse: Codable, Sendable {
    let symbol: String
    let orderId: Int64
    let clientOrderId: String
    let transactTime: Int64
    let price: String
    let origQty: String
    let executedQty: String
    let status: String
    let type: String
    let side: String
}

struct CancelOrderResponse: Codable, Sendable {
    let symbol: String
    let orderId: Int64
    let status: String
}

// MARK: - Trading State

@MainActor
class TradingState: ObservableObject {
    @Published var openOrders: [BinanceOrder] = []
    @Published var accountBalance: AccountBalance?
    @Published var isLoading = false
    @Published var error: String?

    var usdtAvailable: Double {
        accountBalance?.usdtBalance ?? 0
    }

    var btcAvailable: Double {
        accountBalance?.btcBalance ?? 0
    }
}

// MARK: - Profit Calculation

struct ProfitCalculation {
    let buyPrice: Double
    let sellPrice: Double
    let amount: Double  // in USD

    // Binance standard spot trading fee: 0.1% per trade (maker/taker)
    // Total for buy + sell = 0.2%
    static let commissionRate: Double = 0.001  // 0.1% per trade

    var btcQuantity: Double {
        amount / buyPrice
    }

    // Gross profit before commissions
    var grossProfitUSD: Double {
        (sellPrice - buyPrice) * btcQuantity
    }

    // Commission on buy trade (charged in BTC, converted to USD at buy price)
    var buyCommissionUSD: Double {
        amount * Self.commissionRate
    }

    // Commission on sell trade (charged in USDT)
    var sellCommissionUSD: Double {
        (btcQuantity * sellPrice) * Self.commissionRate
    }

    // Total commission for the round trip
    var totalCommissionUSD: Double {
        buyCommissionUSD + sellCommissionUSD
    }

    // Net profit after commissions (this is what you actually make)
    var profitUSD: Double {
        grossProfitUSD - totalCommissionUSD
    }

    var profitPercentage: Double {
        guard buyPrice > 0 else { return 0 }
        // Net profit percentage based on invested amount
        return (profitUSD / amount) * 100
    }

    var grossProfitPercentage: Double {
        guard buyPrice > 0 else { return 0 }
        return ((sellPrice - buyPrice) / buyPrice) * 100
    }

    var formattedProfit: String {
        let sign = profitUSD >= 0 ? "+" : ""
        return "\(sign)\(profitUSD.formatAsCurrency(maximumFractionDigits: 2))"
    }

    var formattedPercentage: String {
        let sign = profitPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", profitPercentage))%"
    }

    var formattedCommission: String {
        return "-\(totalCommissionUSD.formatAsCurrency(maximumFractionDigits: 2))"
    }
}

// MARK: - Trade History (Executed Trades)

struct BinanceTrade: Codable, Identifiable, Sendable {
    let id: Int64
    let orderId: Int64
    let symbol: String
    let price: String
    let qty: String
    let quoteQty: String
    let commission: String
    let commissionAsset: String
    let time: Int64
    let isBuyer: Bool
    let isMaker: Bool

    var priceDouble: Double {
        Double(price) ?? 0
    }

    var quantityDouble: Double {
        Double(qty) ?? 0
    }

    var quoteQuantityDouble: Double {
        Double(quoteQty) ?? 0
    }

    var commissionDouble: Double {
        Double(commission) ?? 0
    }

    var timeDate: Date {
        Date(timeIntervalSince1970: Double(time) / 1000)
    }

    var side: OrderSide {
        isBuyer ? .buy : .sell
    }
}

// MARK: - Completed Grid Pair (For Profit History)

struct CompletedGridPair: Identifiable, Sendable {
    let id: UUID
    let buyTrade: BinanceTrade
    let sellTrade: BinanceTrade

    init(buyTrade: BinanceTrade, sellTrade: BinanceTrade) {
        self.id = UUID()
        self.buyTrade = buyTrade
        self.sellTrade = sellTrade
    }

    var quantity: Double {
        min(buyTrade.quantityDouble, sellTrade.quantityDouble)
    }

    var buyPrice: Double {
        buyTrade.priceDouble
    }

    var sellPrice: Double {
        sellTrade.priceDouble
    }

    var profitUSD: Double {
        (sellPrice - buyPrice) * quantity
    }

    var profitPercentage: Double {
        guard buyPrice > 0 else { return 0 }
        return ((sellPrice - buyPrice) / buyPrice) * 100
    }

    var completedAt: Date {
        sellTrade.timeDate
    }

    var totalCommission: Double {
        // Approximate commission in USD
        let buyCommission = buyTrade.commissionAsset == "USDT" ? buyTrade.commissionDouble : buyTrade.commissionDouble * buyPrice
        let sellCommission = sellTrade.commissionAsset == "USDT" ? sellTrade.commissionDouble : sellTrade.commissionDouble * sellPrice
        return buyCommission + sellCommission
    }

    var netProfitUSD: Double {
        profitUSD - totalCommission
    }

    var investedAmount: Double {
        buyPrice * quantity
    }

    // Net profit percentage based on invested amount (after commissions)
    var netProfitPercentage: Double {
        guard investedAmount > 0 else { return 0 }
        return (netProfitUSD / investedAmount) * 100
    }
}

// MARK: - Open Position (Buy filled, Sell pending)

struct OpenPosition: Identifiable, Sendable {
    let id: UUID
    let buyTrade: BinanceTrade        // The executed buy trade
    let pendingSellOrder: BinanceOrder // The open sell limit order
    let currentPrice: Double           // Current market price

    init(buyTrade: BinanceTrade, pendingSellOrder: BinanceOrder, currentPrice: Double) {
        self.id = UUID()
        self.buyTrade = buyTrade
        self.pendingSellOrder = pendingSellOrder
        self.currentPrice = currentPrice
    }

    var quantity: Double {
        buyTrade.quantityDouble
    }

    var buyPrice: Double {
        buyTrade.priceDouble
    }

    var targetSellPrice: Double {
        pendingSellOrder.priceDouble
    }

    var investedAmount: Double {
        buyPrice * quantity
    }

    // Unrealized gross P&L at current price
    var unrealizedGrossPnL: Double {
        (currentPrice - buyPrice) * quantity
    }

    // Commission for buy (already paid) + estimated sell commission
    var totalCommissionUSD: Double {
        // Buy commission (already paid, in BTC converted to USD)
        let buyCommission = buyTrade.commissionAsset == "USDT"
            ? buyTrade.commissionDouble
            : buyTrade.commissionDouble * buyPrice
        // Estimated sell commission at current price
        let sellCommission = (currentPrice * quantity) * ProfitCalculation.commissionRate
        return buyCommission + sellCommission
    }

    // Net unrealized P&L after commissions
    var unrealizedNetPnL: Double {
        unrealizedGrossPnL - totalCommissionUSD
    }

    var unrealizedPnLPercentage: Double {
        guard investedAmount > 0 else { return 0 }
        return (unrealizedNetPnL / investedAmount) * 100
    }

    var isInProfit: Bool {
        unrealizedNetPnL > 0
    }

    var formattedPnL: String {
        let sign = unrealizedNetPnL >= 0 ? "+" : ""
        return "\(sign)\(unrealizedNetPnL.formatAsCurrency(maximumFractionDigits: 2))"
    }

    var formattedPercentage: String {
        let sign = unrealizedPnLPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", unrealizedPnLPercentage))%"
    }

    // How far from target sell price
    var distanceToTarget: Double {
        ((targetSellPrice - currentPrice) / currentPrice) * 100
    }
}

// MARK: - Grid Pair

struct GridPair: Identifiable {
    let id: UUID
    let buyOrder: BinanceOrder
    let sellOrder: BinanceOrder
    let createdAt: Date

    init(buyOrder: BinanceOrder, sellOrder: BinanceOrder) {
        self.id = UUID()
        self.buyOrder = buyOrder
        self.sellOrder = sellOrder
        self.createdAt = Date()
    }

    var grossProfitUSD: Double {
        let qty = buyOrder.quantityDouble
        return (sellOrder.priceDouble - buyOrder.priceDouble) * qty
    }

    // Commission on buy and sell trades
    var totalCommissionUSD: Double {
        let qty = buyOrder.quantityDouble
        let buyCommission = (buyOrder.priceDouble * qty) * ProfitCalculation.commissionRate
        let sellCommission = (sellOrder.priceDouble * qty) * ProfitCalculation.commissionRate
        return buyCommission + sellCommission
    }

    // Net profit after commissions
    var profitUSD: Double {
        grossProfitUSD - totalCommissionUSD
    }

    var profitPercentage: Double {
        let amount = buyOrder.priceDouble * buyOrder.quantityDouble
        guard amount > 0 else { return 0 }
        return (profitUSD / amount) * 100
    }

    var formattedProfit: String {
        let sign = profitUSD >= 0 ? "+" : ""
        return "\(sign)\(profitUSD.formatAsCurrency(maximumFractionDigits: 0))"
    }

    var formattedPercentage: String {
        let sign = profitPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", profitPercentage))%"
    }
}
