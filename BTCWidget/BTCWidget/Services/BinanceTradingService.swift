import Foundation
import Combine

enum TradingError: Error, LocalizedError {
    case noCredentials
    case invalidURL
    case networkError(String)
    case apiError(String)
    case decodingError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Not authenticated"
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error)"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - Trading Settings

@MainActor
class TradingSettings: ObservableObject {
    static let shared = TradingSettings()

    private let safeModeKey = "trading_safe_mode"
    private let productionKey = "trading_production_mode"
    private let debugModeKey = "trading_debug_mode"

    /// Safe mode: uses 1/1000 of amounts for orders (for testing with real money)
    @Published var safeMode: Bool {
        didSet {
            UserDefaults.standard.set(safeMode, forKey: safeModeKey)
        }
    }

    /// Production mode: uses real Binance API (not testnet)
    @Published var isProduction: Bool {
        didSet {
            UserDefaults.standard.set(isProduction, forKey: productionKey)
        }
    }

    /// Debug mode: shows simulate fill buttons and other debug features
    @Published var debugMode: Bool {
        didSet {
            UserDefaults.standard.set(debugMode, forKey: debugModeKey)
        }
    }

    /// For backward compatibility
    var useTestnet: Bool { !isProduction }

    /// Scale factor for amounts (1/100 in production safe mode to stay above NOTIONAL minimum)
    /// On testnet, always use full amounts regardless of safe mode setting
    var amountScale: Double {
        (isProduction && safeMode) ? 0.01 : 1.0
    }

    /// Scale an amount according to safe mode setting
    func scaleAmount(_ amount: Double) -> Double {
        amount * amountScale
    }

    var environmentName: String {
        if !isProduction {
            return "Testnet"
        } else if safeMode {
            return "Safe Mode"
        } else {
            return "LIVE"
        }
    }

    var environmentColor: String {
        if !isProduction {
            return "green"  // Testnet = safe, green
        } else if safeMode {
            return "orange"  // Production but safe mode
        } else {
            return "red"  // Full production = danger, red
        }
    }

    private init() {
        self.safeMode = UserDefaults.standard.bool(forKey: safeModeKey)
        // Default to testnet (not production) for safety
        self.isProduction = UserDefaults.standard.object(forKey: productionKey) as? Bool ?? false
        self.debugMode = UserDefaults.standard.bool(forKey: debugModeKey)
    }
}

// MARK: - Trading Service (Backend Proxy)

actor BinanceTradingService {
    static let shared = BinanceTradingService()

    private let symbol = "BTCUSDT"

    private init() {}

    // MARK: - Public Trading Methods

    /// Get account balance (USDT and BTC)
    func getAccountBalance() async throws -> AccountBalance {
        do {
            return try await BackendService.shared.getBalance()
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Get open orders for BTCUSDT
    func getOpenOrders() async throws -> [BinanceOrder] {
        do {
            return try await BackendService.shared.getOpenOrders()
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Cancel a specific order
    func cancelOrder(orderId: Int64) async throws -> CancelOrderResponse {
        do {
            return try await BackendService.shared.cancelOrder(orderId: orderId)
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Get trade history for BTCUSDT (executed trades)
    func getTradeHistory(limit: Int = 100) async throws -> [BinanceTrade] {
        do {
            return try await BackendService.shared.getTradeHistory(limit: limit)
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Create a limit order with optional trailing percentage
    func createLimitOrder(side: OrderSide, price: Double, quantity: Double, trailingPercent: Double? = nil) async throws -> NewOrderResponse {
        do {
            return try await BackendService.shared.createLimitOrder(side: side, price: price, quantity: quantity, trailingPercent: trailingPercent)
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Create a market order
    func createMarketOrder(side: OrderSide, quantity: Double) async throws -> NewOrderResponse {
        do {
            return try await BackendService.shared.createMarketOrder(side: side, quantity: quantity)
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapBackendError(_ error: BackendError) -> TradingError {
        switch error {
        case .noToken, .unauthorized:
            return .noCredentials
        case .invalidURL:
            return .invalidURL
        case .networkError(let err):
            return .networkError(err)
        case .apiError(let msg, _):
            return .apiError(msg)
        case .decodingError(let err):
            return .decodingError(err)
        case .invalidResponse:
            return .invalidResponse
        }
    }

    // MARK: - Formatting Helpers

    private func formatPrice(_ price: Double) -> String {
        // BTCUSDT uses 2 decimal places for price
        return String(format: "%.2f", price)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        // BTCUSDT uses 5 decimal places for quantity
        return String(format: "%.5f", quantity)
    }
}

// MARK: - Convenience Extensions

extension BinanceTradingService {
    /// Calculate BTC quantity from USD amount and price
    func calculateQuantity(usdAmount: Double, price: Double) -> Double {
        guard price > 0 else { return 0 }
        return usdAmount / price
    }

    /// Test if backend connection is working
    func testCredentials() async -> Bool {
        do {
            _ = try await getAccountBalance()
            return true
        } catch {
            return false
        }
    }

    /// Create a grid pair (BUY + SELL orders) via backend
    func createGridPair(
        buyPrice: Double,
        sellPrice: Double,
        amount: Double
    ) async throws -> (buyOrder: NewOrderResponse, sellOrder: NewOrderResponse) {
        do {
            return try await BackendService.shared.createGridPair(
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                amountUSD: amount
            )
        } catch let error as BackendError {
            throw mapBackendError(error)
        }
    }

    /// Get open positions: buy trades that have been filled but sell order is still pending
    /// Matches filled buy trades with open sell orders of similar quantity
    func getOpenPositions(openOrders: [BinanceOrder], currentPrice: Double, limit: Int = 100) async throws -> [OpenPosition] {
        let trades = try await getTradeHistory(limit: limit)

        return await MainActor.run {
            // Get buy trades sorted by time (newest first for matching)
            let buyTrades = trades.filter { $0.isBuyer }.sorted { $0.time > $1.time }

            // Get open sell orders
            let openSellOrders = openOrders.filter { $0.orderSide == .sell }

            // Get all completed sell trades to exclude already-closed positions
            let sellTrades = trades.filter { !$0.isBuyer }
            var matchedBuyIdsFromSells: Set<Int64> = []

            // First, mark buy trades that already have matching sells (completed positions)
            for sellTrade in sellTrades {
                for buyTrade in buyTrades {
                    guard !matchedBuyIdsFromSells.contains(buyTrade.id),
                          buyTrade.time < sellTrade.time else { continue }

                    let qtyDiff = abs(buyTrade.quantityDouble - sellTrade.quantityDouble) / buyTrade.quantityDouble
                    if qtyDiff < 0.05 {
                        matchedBuyIdsFromSells.insert(buyTrade.id)
                        break
                    }
                }
            }

            // Now match remaining buy trades with open sell orders
            var openPositions: [OpenPosition] = []
            var matchedSellOrderIds: Set<Int64> = []

            for buyTrade in buyTrades {
                // Skip if this buy already has a completed sell
                guard !matchedBuyIdsFromSells.contains(buyTrade.id) else { continue }

                // Find matching open sell order by quantity
                for sellOrder in openSellOrders {
                    guard !matchedSellOrderIds.contains(sellOrder.orderId) else { continue }

                    let qtyDiff = abs(buyTrade.quantityDouble - sellOrder.quantityDouble) / buyTrade.quantityDouble
                    if qtyDiff < 0.05 {
                        openPositions.append(OpenPosition(
                            buyTrade: buyTrade,
                            pendingSellOrder: sellOrder,
                            currentPrice: currentPrice
                        ))
                        matchedSellOrderIds.insert(sellOrder.orderId)
                        break
                    }
                }
            }

            return openPositions.sorted { $0.buyTrade.time > $1.buyTrade.time }
        }
    }

    /// Get completed grid pairs from trade history
    /// Matches BUY trades with subsequent SELL trades of similar quantity
    func getCompletedGridPairs(limit: Int = 100) async throws -> [CompletedGridPair] {
        let trades = try await getTradeHistory(limit: limit)

        return await MainActor.run {
            // Separate buy and sell trades, sorted by time
            let buyTrades = trades.filter { $0.isBuyer }.sorted { $0.time < $1.time }
            let sellTrades = trades.filter { !$0.isBuyer }.sorted { $0.time < $1.time }

            var completedPairs: [CompletedGridPair] = []
            var matchedBuyIds: Set<Int64> = []
            var matchedSellIds: Set<Int64> = []

            // Match each sell with a preceding buy of similar quantity
            for sellTrade in sellTrades {
                for buyTrade in buyTrades {
                    // Skip if already matched or buy happened after sell
                    guard !matchedBuyIds.contains(buyTrade.id),
                          buyTrade.time < sellTrade.time else {
                        continue
                    }

                    // Match by similar quantity (within 5%)
                    let qtyDiff = abs(buyTrade.quantityDouble - sellTrade.quantityDouble) / buyTrade.quantityDouble
                    if qtyDiff < 0.05 {
                        // Only count as profit if sell > buy (positive trade)
                        if sellTrade.priceDouble > buyTrade.priceDouble {
                            completedPairs.append(CompletedGridPair(buyTrade: buyTrade, sellTrade: sellTrade))
                        }
                        matchedBuyIds.insert(buyTrade.id)
                        matchedSellIds.insert(sellTrade.id)
                        break
                    }
                }
            }

            // Sort by completion time, newest first
            return completedPairs.sorted { $0.completedAt > $1.completedAt }
        }
    }
}
