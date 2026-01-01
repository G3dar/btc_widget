import Foundation
import SwiftUI
import Combine

/// Represents a simulated fill for debug testing
/// Stores the buy info + sell order ID so we can display it like a real OpenPosition
struct SimulatedFill: Codable, Identifiable, Sendable {
    let id: UUID
    let buyPrice: Double
    let sellPrice: Double
    let quantity: Double
    let amountUSD: Double
    let sellOrderId: Int64
    let createdAt: Date

    init(from pair: PendingPair, sellOrderId: Int64) {
        self.id = UUID()
        self.buyPrice = pair.buyPrice
        self.sellPrice = pair.intendedSellPrice
        self.quantity = pair.quantity
        self.amountUSD = pair.amountUSD
        self.sellOrderId = sellOrderId
        self.createdAt = Date()
    }

    init(buyPrice: Double, sellPrice: Double, quantity: Double, amountUSD: Double, sellOrderId: Int64) {
        self.id = UUID()
        self.buyPrice = buyPrice
        self.sellPrice = sellPrice
        self.quantity = quantity
        self.amountUSD = amountUSD
        self.sellOrderId = sellOrderId
        self.createdAt = Date()
    }
}

/// Manages pending trading pairs - buy orders that are waiting to fill,
/// with intended sell prices stored locally until the buy executes.
/// Storage is separated by environment (testnet vs production).
@MainActor
class PendingPairManager: ObservableObject {
    static let shared = PendingPairManager()

    @Published var pendingPairs: [PendingPair] = []
    @Published var simulatedFills: [SimulatedFill] = []  // Debug: simulated buy fills

    private var cancellables = Set<AnyCancellable>()

    /// Storage key includes environment to separate testnet/production data
    private var storageKey: String {
        let env = TradingSettings.shared.isProduction ? "production" : "testnet"
        return "pending_trading_pairs_\(env)"
    }

    private var simulatedFillsKey: String {
        let env = TradingSettings.shared.isProduction ? "production" : "testnet"
        return "simulated_fills_\(env)"
    }

    private init() {
        loadFromStorage()

        // Reload when environment changes
        TradingSettings.shared.$isProduction
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.loadFromStorage()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Add a new pending pair after placing a buy order
    func add(_ pair: PendingPair) {
        pendingPairs.append(pair)
        saveToStorage()
    }

    /// Remove a pending pair by its buy order ID (called when buy fills and sell is placed)
    func remove(buyOrderId: Int64) {
        pendingPairs.removeAll { $0.buyOrderId == buyOrderId }
        saveToStorage()
    }

    /// Remove a pending pair by its UUID
    func remove(id: UUID) {
        pendingPairs.removeAll { $0.id == id }
        saveToStorage()
    }

    /// Update the intended sell price for a pending pair
    func updateIntendedSellPrice(id: UUID, newPrice: Double) {
        if let index = pendingPairs.firstIndex(where: { $0.id == id }) {
            pendingPairs[index].intendedSellPrice = newPrice
            saveToStorage()
        }
    }

    /// Update buy order ID after modifying (cancel + recreate) the buy order
    func updateBuyOrder(id: UUID, newOrderId: Int64, newPrice: Double, newQuantity: Double) {
        if let index = pendingPairs.firstIndex(where: { $0.id == id }) {
            // Create updated pair with new values
            let oldPair = pendingPairs[index]
            let updatedPair = PendingPair(
                buyOrderId: newOrderId,
                buyPrice: newPrice,
                intendedSellPrice: oldPair.intendedSellPrice,
                quantity: newQuantity,
                amountUSD: oldPair.amountUSD
            )
            pendingPairs[index] = updatedPair
            saveToStorage()
        }
    }

    /// Get a pending pair by its buy order ID
    func getPair(byOrderId orderId: Int64) -> PendingPair? {
        pendingPairs.first { $0.buyOrderId == orderId }
    }

    /// Check if an order ID belongs to a pending pair
    func isPendingPairOrder(_ orderId: Int64) -> Bool {
        pendingPairs.contains { $0.buyOrderId == orderId }
    }

    // MARK: - Simulated Fills (Debug)

    /// Add a simulated fill (debug mode only)
    func addSimulatedFill(_ fill: SimulatedFill) {
        simulatedFills.append(fill)
        saveSimulatedFills()
    }

    /// Remove a simulated fill by sell order ID
    func removeSimulatedFill(sellOrderId: Int64) {
        simulatedFills.removeAll { $0.sellOrderId == sellOrderId }
        saveSimulatedFills()
    }

    /// Clear all simulated fills
    func clearSimulatedFills() {
        simulatedFills.removeAll()
        saveSimulatedFills()
    }

    /// Update sell price for a simulated fill (after modifying order on Binance)
    func updateSimulatedFillSellPrice(sellOrderId: Int64, newSellPrice: Double, newOrderId: Int64) {
        if let index = simulatedFills.firstIndex(where: { $0.sellOrderId == sellOrderId }) {
            let old = simulatedFills[index]
            let updated = SimulatedFill(
                buyPrice: old.buyPrice,
                sellPrice: newSellPrice,
                quantity: old.quantity,
                amountUSD: old.amountUSD,
                sellOrderId: newOrderId
            )
            simulatedFills[index] = updated
            saveSimulatedFills()
        }
    }

    /// Import a simulated fill directly (for importing existing orders)
    func importSimulatedFill(buyPrice: Double, sellPrice: Double, quantity: Double, sellOrderId: Int64) {
        let fill = SimulatedFill(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            quantity: quantity,
            amountUSD: buyPrice * quantity,
            sellOrderId: sellOrderId
        )
        simulatedFills.append(fill)
        saveSimulatedFills()
    }

    // MARK: - Private Methods

    private func saveToStorage() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(pendingPairs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func saveSimulatedFills() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(simulatedFills) {
            UserDefaults.standard.set(data, forKey: simulatedFillsKey)
        }
    }

    private func loadFromStorage() {
        // Load pending pairs
        let key = storageKey
        if let data = UserDefaults.standard.data(forKey: key) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let pairs = try? decoder.decode([PendingPair].self, from: data) {
                pendingPairs = pairs
            } else {
                pendingPairs = []
            }
        } else {
            pendingPairs = []
        }

        // Load simulated fills
        let fillsKey = simulatedFillsKey
        if let data = UserDefaults.standard.data(forKey: fillsKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let fills = try? decoder.decode([SimulatedFill].self, from: data) {
                simulatedFills = fills
            } else {
                simulatedFills = []
            }
        } else {
            simulatedFills = []
        }
    }
}
