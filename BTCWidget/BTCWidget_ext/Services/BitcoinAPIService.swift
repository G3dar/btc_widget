import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
}

// Binance API response models
struct BinancePrice: Codable {
    let symbol: String
    let price: String
}

struct BinanceKline {
    let openTime: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    init(from data: [Any]) {
        openTime = (data[0] as? Int64) ?? 0
        open = Double((data[1] as? String) ?? "0") ?? 0
        high = Double((data[2] as? String) ?? "0") ?? 0
        low = Double((data[3] as? String) ?? "0") ?? 0
        close = Double((data[4] as? String) ?? "0") ?? 0
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

    func fetchBitcoinData() async throws -> BitcoinData {
        async let priceData = fetchCurrentPrice()
        async let chartData = fetchKlines()

        let (currentPrice, klines) = try await (priceData, chartData)

        let prices = klines.map { kline -> PricePoint in
            let timestamp = Date(timeIntervalSince1970: Double(kline.openTime) / 1000)
            return PricePoint(timestamp: timestamp, price: kline.close)
        }

        let high6h = klines.map { $0.high }.max() ?? currentPrice
        let low6h = klines.map { $0.low }.min() ?? currentPrice

        let percentChange: Double
        if let firstPrice = prices.first?.price, firstPrice > 0 {
            percentChange = ((currentPrice - firstPrice) / firstPrice) * 100
        } else {
            percentChange = 0
        }

        return BitcoinData(
            currentPrice: currentPrice,
            priceHistory: prices,
            high6h: high6h,
            low6h: low6h,
            percentChange6h: percentChange,
            lastUpdated: Date()
        )
    }

    private func fetchCurrentPrice() async throws -> Double {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(BinancePrice.self, from: data)
            return Double(decoded.price) ?? 0
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func fetchKlines() async throws -> [BinanceKline] {
        // 6 hours of 5-minute candles
        guard let url = URL(string: "https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=5m&limit=72") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let rawKlines = try JSONSerialization.jsonObject(with: data) as? [[Any]] ?? []
            return rawKlines.map { BinanceKline(from: $0) }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
