import Foundation
#if canImport(UIKit)
@preconcurrency import UIKit
#endif

// MARK: - Backend Error Types

enum BackendError: Error, LocalizedError, Sendable {
    case noToken
    case invalidURL
    case networkError(String)
    case apiError(String, Int)
    case decodingError(String)
    case invalidResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Not authenticated with backend"
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error)"
        case .apiError(let message, let code):
            return "API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Session expired, please restart the app"
        }
    }
}

// MARK: - Backend Response Models (nonisolated for Swift 6)

struct LoginResponse: Codable, Sendable {
    let token: String
    let expires_in: Int
}

struct BackendAssetBalance: Codable, Sendable {
    let free: Double
    let locked: Double
    let total: Double
}

struct BackendBalanceResponse: Codable, Sendable {
    let usdt: BackendAssetBalance
    let btc: BackendAssetBalance
    let btc_value_usd: Double
    let total_usd: Double
}

struct BackendOrderItem: Codable, Sendable {
    let orderId: Int64
    let symbol: String
    let side: String
    let type: String
    let price: String
    let origQty: String
    let executedQty: String
    let status: String
    let time: Int64
}

struct BackendGridPair: Codable, Sendable {
    let buy_order: BackendOrderItem
    let sell_order: BackendOrderItem
    let profit_usd: Double
    let profit_percent: Double
}

struct BackendOrdersResponse: Codable, Sendable {
    let grid_pairs: [BackendGridPair]
    let unpaired_orders: [BackendOrderItem]
    let total_orders: Int
}

struct BackendNewOrderResponse: Codable, Sendable {
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

struct BackendGridCreateResponse: Codable, Sendable {
    let buy_order: BackendNewOrderResponse
    let sell_order: BackendNewOrderResponse
}

struct BackendTradeItem: Codable, Sendable {
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
}

struct BackendCompletedPair: Codable, Sendable {
    let buy_trade: BackendTradeItem
    let sell_trade: BackendTradeItem
    let quantity: Double
    let buy_price: Double
    let sell_price: Double
    let gross_profit_usd: Double
    let commission_usd: Double
    let net_profit_usd: Double
    let profit_percent: Double
    let completed_at: Int64
}

struct BackendTradesResponse: Codable, Sendable {
    let completed_pairs: [BackendCompletedPair]
    let total_net_profit: Double
}

struct BackendErrorResponse: Codable, Sendable {
    let error: String
}


// MARK: - JSON Helpers (nonisolated global functions for Swift 6 compatibility)

private nonisolated func jsonEncode(_ dict: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: dict)
}

private nonisolated func jsonDecode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try JSONDecoder().decode(type, from: data)
}

// MARK: - Backend Service

actor BackendService {
    static let shared = BackendService()

    private let baseURL = "https://btc-trading-backend.fly.dev"
    private let appSecret = "ce9bad6793e53f5974710d2342c55675924f7927c4a23a069cc8f6c4d06e3e2b"

    private var token: String?
    private var tokenExpiry: Date?

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    /// Login and get JWT token
    func login() async throws -> String {
        let deviceId = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }
        let deviceName = await MainActor.run {
            UIDevice.current.name
        }

        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app_secret": appSecret,
            "device_id": deviceId,
            "device_name": deviceName
        ]
        request.httpBody = try jsonEncode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecode(BackendErrorResponse.self, from: data) {
                throw BackendError.apiError(errorResponse.error, httpResponse.statusCode)
            }
            throw BackendError.apiError("HTTP \(httpResponse.statusCode)", httpResponse.statusCode)
        }

        let loginResponse = try jsonDecode(LoginResponse.self, from: data)

        self.token = loginResponse.token
        // Expire 1 minute early to avoid edge cases
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(loginResponse.expires_in - 60))

        print("Backend login successful, token expires in \(loginResponse.expires_in)s")

        return loginResponse.token
    }

    /// Ensure we have a valid token, refreshing if needed
    private func ensureAuthenticated() async throws {
        if token == nil || tokenExpiry == nil || tokenExpiry! < Date() {
            _ = try await login()
        }
    }

    // MARK: - Account Endpoints

    /// Get account balance
    func getBalance() async throws -> AccountBalance {
        let data = try await authenticatedRequest("/account/balance")
        let response = try jsonDecode(BackendBalanceResponse.self, from: data)

        // Convert to the existing AccountBalance format
        let balances = [
            AssetBalance(asset: "USDT", free: String(response.usdt.free), locked: String(response.usdt.locked)),
            AssetBalance(asset: "BTC", free: String(response.btc.free), locked: String(response.btc.locked))
        ]
        return AccountBalance(balances: balances)
    }

    /// Get open orders
    func getOpenOrders() async throws -> [BinanceOrder] {
        let data = try await authenticatedRequest("/account/orders")
        let response = try jsonDecode(BackendOrdersResponse.self, from: data)

        // Convert grid pairs and unpaired orders to flat array
        var orders: [BinanceOrder] = []

        for pair in response.grid_pairs {
            orders.append(BinanceOrder(
                orderId: pair.buy_order.orderId,
                symbol: pair.buy_order.symbol,
                side: pair.buy_order.side,
                type: pair.buy_order.type,
                price: pair.buy_order.price,
                origQty: pair.buy_order.origQty,
                executedQty: pair.buy_order.executedQty,
                status: pair.buy_order.status,
                time: pair.buy_order.time
            ))
            orders.append(BinanceOrder(
                orderId: pair.sell_order.orderId,
                symbol: pair.sell_order.symbol,
                side: pair.sell_order.side,
                type: pair.sell_order.type,
                price: pair.sell_order.price,
                origQty: pair.sell_order.origQty,
                executedQty: pair.sell_order.executedQty,
                status: pair.sell_order.status,
                time: pair.sell_order.time
            ))
        }

        for order in response.unpaired_orders {
            orders.append(BinanceOrder(
                orderId: order.orderId,
                symbol: order.symbol,
                side: order.side,
                type: order.type,
                price: order.price,
                origQty: order.origQty,
                executedQty: order.executedQty,
                status: order.status,
                time: order.time
            ))
        }

        return orders
    }

    // MARK: - Trading Endpoints

    /// Create a grid pair (buy + sell orders)
    func createGridPair(buyPrice: Double, sellPrice: Double, amountUSD: Double) async throws -> (buyOrder: NewOrderResponse, sellOrder: NewOrderResponse) {
        let body: [String: Any] = [
            "buy_price": buyPrice,
            "sell_price": sellPrice,
            "amount_usd": amountUSD
        ]

        let data = try await authenticatedRequest("/grid/create", method: "POST", bodyData: try jsonEncode(body))
        let response = try jsonDecode(BackendGridCreateResponse.self, from: data)

        // Convert to existing NewOrderResponse format
        let buyOrder = NewOrderResponse(
            symbol: response.buy_order.symbol,
            orderId: response.buy_order.orderId,
            clientOrderId: response.buy_order.clientOrderId,
            transactTime: response.buy_order.transactTime,
            price: response.buy_order.price,
            origQty: response.buy_order.origQty,
            executedQty: response.buy_order.executedQty,
            status: response.buy_order.status,
            type: response.buy_order.type,
            side: response.buy_order.side
        )

        let sellOrder = NewOrderResponse(
            symbol: response.sell_order.symbol,
            orderId: response.sell_order.orderId,
            clientOrderId: response.sell_order.clientOrderId,
            transactTime: response.sell_order.transactTime,
            price: response.sell_order.price,
            origQty: response.sell_order.origQty,
            executedQty: response.sell_order.executedQty,
            status: response.sell_order.status,
            type: response.sell_order.type,
            side: response.sell_order.side
        )

        return (buyOrder: buyOrder, sellOrder: sellOrder)
    }

    /// Cancel an order
    func cancelOrder(orderId: Int64) async throws -> CancelOrderResponse {
        let data = try await authenticatedRequest("/grid/\(orderId)", method: "DELETE")

        // The backend returns success/order_id (snake_case from Rust)
        struct CancelResponse: Codable, Sendable {
            let success: Bool
            let order_id: Int64
        }

        let response = try jsonDecode(CancelResponse.self, from: data)
        return CancelOrderResponse(
            symbol: "BTCUSDT",
            orderId: response.order_id,
            status: "CANCELED"
        )
    }

    // MARK: - History Endpoints

    /// Get trade history
    func getTradeHistory(limit: Int = 100) async throws -> [BinanceTrade] {
        let data = try await authenticatedRequest("/history/trades?limit=\(limit)")
        let response = try jsonDecode(BackendTradesResponse.self, from: data)

        // Convert completed pairs to flat array of trades
        var trades: [BinanceTrade] = []

        for pair in response.completed_pairs {
            trades.append(BinanceTrade(
                id: pair.buy_trade.id,
                orderId: pair.buy_trade.orderId,
                symbol: pair.buy_trade.symbol,
                price: pair.buy_trade.price,
                qty: pair.buy_trade.qty,
                quoteQty: pair.buy_trade.quoteQty,
                commission: pair.buy_trade.commission,
                commissionAsset: pair.buy_trade.commissionAsset,
                time: pair.buy_trade.time,
                isBuyer: pair.buy_trade.isBuyer,
                isMaker: pair.buy_trade.isMaker
            ))
            trades.append(BinanceTrade(
                id: pair.sell_trade.id,
                orderId: pair.sell_trade.orderId,
                symbol: pair.sell_trade.symbol,
                price: pair.sell_trade.price,
                qty: pair.sell_trade.qty,
                quoteQty: pair.sell_trade.quoteQty,
                commission: pair.sell_trade.commission,
                commissionAsset: pair.sell_trade.commissionAsset,
                time: pair.sell_trade.time,
                isBuyer: pair.sell_trade.isBuyer,
                isMaker: pair.sell_trade.isMaker
            ))
        }

        return trades
    }

    // MARK: - Individual Order Methods

    /// Create a single limit order
    func createLimitOrder(side: OrderSide, price: Double, quantity: Double) async throws -> NewOrderResponse {
        let body: [String: Any] = [
            "side": side.rawValue,
            "price": price,
            "quantity": quantity
        ]

        let data = try await authenticatedRequest("/order/limit", method: "POST", bodyData: try jsonEncode(body))
        let response = try jsonDecode(BackendNewOrderResponse.self, from: data)

        return NewOrderResponse(
            symbol: response.symbol,
            orderId: response.orderId,
            clientOrderId: response.clientOrderId,
            transactTime: response.transactTime,
            price: response.price,
            origQty: response.origQty,
            executedQty: response.executedQty,
            status: response.status,
            type: response.type,
            side: response.side
        )
    }

    /// Create a market order
    func createMarketOrder(side: OrderSide, quantity: Double) async throws -> NewOrderResponse {
        let body: [String: Any] = [
            "side": side.rawValue,
            "quantity": quantity
        ]

        let data = try await authenticatedRequest("/order/market", method: "POST", bodyData: try jsonEncode(body))
        let response = try jsonDecode(BackendNewOrderResponse.self, from: data)

        return NewOrderResponse(
            symbol: response.symbol,
            orderId: response.orderId,
            clientOrderId: response.clientOrderId,
            transactTime: response.transactTime,
            price: response.price,
            origQty: response.origQty,
            executedQty: response.executedQty,
            status: response.status,
            type: response.type,
            side: response.side
        )
    }

    // MARK: - Push Notifications

    /// Register device token for push notifications
    func registerPushToken(_ deviceToken: String) async throws {
        let body: [String: Any] = ["device_token": deviceToken]
        _ = try await authenticatedRequest("/notifications/register", method: "POST", bodyData: try jsonEncode(body))
        print("Push token registered with backend")
    }

    // MARK: - Network Request Helper

    private func authenticatedRequest(_ path: String, method: String = "GET", bodyData: Data? = nil) async throws -> Data {
        try await ensureAuthenticated()

        guard let token = self.token else {
            throw BackendError.noToken
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL
        }

        // Get production mode setting from MainActor
        let useProduction = await MainActor.run {
            TradingSettings.shared.isProduction
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(useProduction ? "true" : "false", forHTTPHeaderField: "X-Use-Production")

        if let bodyData = bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }

            // Handle unauthorized - try to re-login once
            if httpResponse.statusCode == 401 {
                self.token = nil
                self.tokenExpiry = nil
                _ = try await login()
                return try await authenticatedRequest(path, method: method, bodyData: bodyData)
            }

            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? jsonDecode(BackendErrorResponse.self, from: data) {
                    throw BackendError.apiError(errorResponse.error, httpResponse.statusCode)
                }
                throw BackendError.apiError("HTTP \(httpResponse.statusCode)", httpResponse.statusCode)
            }

            return data
        } catch let error as BackendError {
            throw error
        } catch {
            throw BackendError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Debug Testing

    struct TestResult: Sendable {
        let endpoint: String
        let success: Bool
        let message: String
        let duration: TimeInterval
    }

    /// Test all backend endpoints and return results
    func runDiagnostics() async -> [TestResult] {
        var results: [TestResult] = []

        // Test 1: Login
        let loginStart = Date()
        do {
            _ = try await login()
            results.append(TestResult(
                endpoint: "POST /auth/login",
                success: true,
                message: "OK - Token received",
                duration: Date().timeIntervalSince(loginStart)
            ))
        } catch {
            results.append(TestResult(
                endpoint: "POST /auth/login",
                success: false,
                message: error.localizedDescription,
                duration: Date().timeIntervalSince(loginStart)
            ))
            // If login fails, can't test other endpoints
            return results
        }

        // Test 2: Get Balance
        let balanceStart = Date()
        do {
            let balance = try await getBalance()
            let usdtAsset = balance.balances.first { $0.asset == "USDT" }
            let usdtValue = Double(usdtAsset?.free ?? "0") ?? 0
            results.append(TestResult(
                endpoint: "GET /account/balance",
                success: true,
                message: "OK - USDT: $\(Int(usdtValue))",
                duration: Date().timeIntervalSince(balanceStart)
            ))
        } catch {
            results.append(TestResult(
                endpoint: "GET /account/balance",
                success: false,
                message: error.localizedDescription,
                duration: Date().timeIntervalSince(balanceStart)
            ))
        }

        // Test 3: Get Orders
        let ordersStart = Date()
        do {
            let orders = try await getOpenOrders()
            results.append(TestResult(
                endpoint: "GET /account/orders",
                success: true,
                message: "OK - \(orders.count) open orders",
                duration: Date().timeIntervalSince(ordersStart)
            ))
        } catch {
            results.append(TestResult(
                endpoint: "GET /account/orders",
                success: false,
                message: error.localizedDescription,
                duration: Date().timeIntervalSince(ordersStart)
            ))
        }

        // Test 4: Get Trade History
        let historyStart = Date()
        do {
            let trades = try await getTradeHistory(limit: 10)
            results.append(TestResult(
                endpoint: "GET /history/trades",
                success: true,
                message: "OK - \(trades.count) trades",
                duration: Date().timeIntervalSince(historyStart)
            ))
        } catch {
            results.append(TestResult(
                endpoint: "GET /history/trades",
                success: false,
                message: error.localizedDescription,
                duration: Date().timeIntervalSince(historyStart)
            ))
        }

        // Test 5: Create Grid Pair (dry run - very small amount, immediately cancel)
        // Skip this in diagnostics to avoid creating real orders

        return results
    }
}
