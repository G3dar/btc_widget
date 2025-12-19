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

actor BitcoinAPIService {
    static let shared = BitcoinAPIService()

    private let baseURL = "https://api.coingecko.com/api/v3"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func fetchBitcoinData(for range: TimeRange = .twentyFourHours) async throws -> BitcoinData {
        async let priceData = fetchCurrentPrice()
        async let chartData = fetchMarketChart(days: range.days)

        let (price, chart) = try await (priceData, chartData)

        let prices = chart.prices.map { dataPoint -> PricePoint in
            let timestamp = Date(timeIntervalSince1970: dataPoint[0] / 1000)
            let price = dataPoint[1]
            return PricePoint(timestamp: timestamp, price: price)
        }

        let priceValues = prices.map { $0.price }
        let highPrice = priceValues.max() ?? price.usd
        let lowPrice = priceValues.min() ?? price.usd

        let percentChange: Double
        if let firstPrice = prices.first?.price, firstPrice > 0 {
            percentChange = ((price.usd - firstPrice) / firstPrice) * 100
        } else {
            percentChange = 0
        }

        return BitcoinData(
            currentPrice: price.usd,
            priceHistory: prices,
            highPrice: highPrice,
            lowPrice: lowPrice,
            percentChange: percentChange,
            lastUpdated: Date(),
            timeRange: range.rawValue
        )
    }

    private func fetchCurrentPrice() async throws -> BitcoinPriceData {
        guard let url = URL(string: "\(baseURL)/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(CoinGeckoSimplePriceResponse.self, from: data)
            return decoded.bitcoin
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func fetchMarketChart(days: Double) async throws -> CoinGeckoMarketChartResponse {
        guard let url = URL(string: "\(baseURL)/coins/bitcoin/market_chart?vs_currency=usd&days=\(days)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            return try JSONDecoder().decode(CoinGeckoMarketChartResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
