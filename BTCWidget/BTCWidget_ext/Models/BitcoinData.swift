import Foundation

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
    let high6h: Double
    let low6h: Double
    let percentChange6h: Double
    let lastUpdated: Date

    static var placeholder: BitcoinData {
        let now = Date()
        let points = (0..<72).map { i in
            PricePoint(
                timestamp: now.addingTimeInterval(Double(-i * 300)),
                price: 97000 + Double.random(in: -1000...1000)
            )
        }.reversed()

        return BitcoinData(
            currentPrice: 97245.00,
            priceHistory: Array(points),
            high6h: 98120.00,
            low6h: 96230.00,
            percentChange6h: 2.4,
            lastUpdated: now
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
