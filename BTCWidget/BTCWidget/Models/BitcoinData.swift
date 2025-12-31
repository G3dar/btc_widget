import Foundation

// MARK: - Time Range Selection

enum TimeRange: String, CaseIterable, Identifiable {
    case threeHours = "3H"
    case sixHours = "6H"
    case twelveHours = "12H"
    case twentyFourHours = "24H"
    case sevenDays = "7D"
    case thirtyDays = "30D"

    var id: String { rawValue }

    var days: Double {
        switch self {
        case .threeHours: return 0.125    // 3 hours
        case .sixHours: return 0.25       // 6 hours
        case .twelveHours: return 0.5     // 12 hours
        case .twentyFourHours: return 1
        case .sevenDays: return 7
        case .thirtyDays: return 30
        }
    }

    var displayName: String {
        rawValue
    }
}

// MARK: - Price Data Models

struct PricePoint: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let price: Double

    enum CodingKeys: String, CodingKey {
        case timestamp, price
    }
}

struct BitcoinData: Codable {
    let currentPrice: Double
    let priceHistory: [PricePoint]
    let highPrice: Double
    let lowPrice: Double
    let percentChange: Double
    let lastUpdated: Date
    let timeRange: String

    var isPositive: Bool {
        percentChange >= 0
    }

    static func placeholder(for range: TimeRange = .twentyFourHours) -> BitcoinData {
        let now = Date()
        let pointCount = 72
        let intervalSeconds = (range.days * 24 * 3600) / Double(pointCount)

        let points = (0..<pointCount).map { i in
            PricePoint(
                timestamp: now.addingTimeInterval(Double(-i) * intervalSeconds),
                price: 97000 + Double.random(in: -1000...1000)
            )
        }.reversed()

        return BitcoinData(
            currentPrice: 97245.00,
            priceHistory: Array(points),
            highPrice: 98120.00,
            lowPrice: 96230.00,
            percentChange: 2.4,
            lastUpdated: now,
            timeRange: range.rawValue
        )
    }
}

// MARK: - CoinGecko API Response Models

struct CoinGeckoMarketChartResponse: Codable {
    let prices: [[Double]]
}

struct CoinGeckoSimplePriceResponse: Codable {
    let bitcoin: BitcoinPriceData
}

struct BitcoinPriceData: Codable {
    let usd: Double
    let usd24hChange: Double?

    enum CodingKeys: String, CodingKey {
        case usd
        case usd24hChange = "usd_24h_change"
    }
}
