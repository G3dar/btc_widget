import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// Binance API response models
struct BinancePrice: Codable, Sendable {
    let symbol: String
    let price: String
}

struct BinanceKline: Sendable {
    let openTime: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// MARK: - JSON Helpers (nonisolated global functions for Swift 6 compatibility)

private nonisolated func decodeBinancePrice(from data: Data) throws -> BinancePrice {
    try JSONDecoder().decode(BinancePrice.self, from: data)
}

private nonisolated func parseBinanceKlines(from data: Data) throws -> [BinanceKline] {
    let rawKlines = try JSONSerialization.jsonObject(with: data) as? [[Any]] ?? []
    return rawKlines.map { klineData in
        BinanceKline(
            openTime: (klineData[0] as? Int64) ?? 0,
            open: Double((klineData[1] as? String) ?? "0") ?? 0,
            high: Double((klineData[2] as? String) ?? "0") ?? 0,
            low: Double((klineData[3] as? String) ?? "0") ?? 0,
            close: Double((klineData[4] as? String) ?? "0") ?? 0
        )
    }
}

actor BitcoinAPIService {
    static let shared = BitcoinAPIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func fetchBitcoinData(for range: TimeRange = .twentyFourHours) async throws -> BitcoinData {
        async let priceData = fetchCurrentPrice()
        async let chartData = fetchKlines(for: range)

        let (currentPrice, klines) = try await (priceData, chartData)

        let prices = klines.map { kline -> PricePoint in
            let timestamp = Date(timeIntervalSince1970: Double(kline.openTime) / 1000)
            return PricePoint(timestamp: timestamp, price: kline.close)
        }

        let highPrice = klines.map { $0.high }.max() ?? currentPrice
        let lowPrice = klines.map { $0.low }.min() ?? currentPrice

        let percentChange: Double
        if let firstPrice = prices.first?.price, firstPrice > 0 {
            percentChange = ((currentPrice - firstPrice) / firstPrice) * 100
        } else {
            percentChange = 0
        }

        return BitcoinData(
            currentPrice: currentPrice,
            priceHistory: prices,
            highPrice: highPrice,
            lowPrice: lowPrice,
            percentChange: percentChange,
            lastUpdated: Date(),
            timeRange: range.rawValue
        )
    }

    private func fetchCurrentPrice() async throws -> Double {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")
        request.addValue("0", forHTTPHeaderField: "Expires")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Check for error status codes and extract error message
            if httpResponse.statusCode >= 400 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorJson["msg"] as? String {
                    throw APIError.networkError(NSError(domain: "Binance", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                }
                throw APIError.networkError(NSError(domain: "Binance", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
            }

            let decoded = try decodeBinancePrice(from: data)
            return Double(decoded.price) ?? 0
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func fetchKlines(for range: TimeRange) async throws -> [BinanceKline] {
        let interval: String
        let limit: Int

        switch range {
        case .threeHours:
            interval = "1m"
            limit = 180 // 3 hours of 1-min candles
        case .sixHours:
            interval = "5m"
            limit = 72  // 6 hours of 5-min candles
        case .twelveHours:
            interval = "5m"
            limit = 144 // 12 hours of 5-min candles
        case .twentyFourHours:
            interval = "15m"
            limit = 96  // 24 hours of 15-min candles
        case .sevenDays:
            interval = "1h"
            limit = 168 // 7 days of hourly candles
        case .thirtyDays:
            interval = "4h"
            limit = 180 // 30 days of 4-hour candles
        }

        guard let url = URL(string: "https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=\(interval)&limit=\(limit)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")
        request.addValue("0", forHTTPHeaderField: "Expires")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Check for error status codes and extract error message
            if httpResponse.statusCode >= 400 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorJson["msg"] as? String {
                    throw APIError.networkError(NSError(domain: "Binance", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                }
                throw APIError.networkError(NSError(domain: "Binance", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
            }

            return try parseBinanceKlines(from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
