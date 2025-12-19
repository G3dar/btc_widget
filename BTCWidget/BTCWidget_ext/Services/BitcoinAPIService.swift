import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
}

actor BitcoinAPIService {
    static let shared = BitcoinAPIService()

    private let baseURL = "https://api.coingecko.com/api/v3"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func fetchBitcoinData() async throws -> BitcoinData {
        async let priceData = fetchCurrentPrice()
        async let chartData = fetchMarketChart()

        let (price, chart) = try await (priceData, chartData)

        let prices = chart.prices.map { dataPoint -> PricePoint in
            let timestamp = Date(timeIntervalSince1970: dataPoint[0] / 1000)
            let price = dataPoint[1]
            return PricePoint(timestamp: timestamp, price: price)
        }

        let priceValues = prices.map { $0.price }
        let high6h = priceValues.max() ?? price.usd
        let low6h = priceValues.min() ?? price.usd

        let percentChange: Double
        if let firstPrice = prices.first?.price, firstPrice > 0 {
            percentChange = ((price.usd - firstPrice) / firstPrice) * 100
        } else {
            percentChange = 0
        }

        return BitcoinData(
            currentPrice: price.usd,
            priceHistory: prices,
            high6h: high6h,
            low6h: low6h,
            percentChange6h: percentChange,
            lastUpdated: Date()
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

    private func fetchMarketChart() async throws -> CoinGeckoMarketChartResponse {
        // 0.25 days = 6 hours
        guard let url = URL(string: "\(baseURL)/coins/bitcoin/market_chart?vs_currency=usd&days=0.25") else {
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
