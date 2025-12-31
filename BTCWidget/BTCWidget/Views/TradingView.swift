import SwiftUI

struct TradingView: View {
    let currentPrice: Double

    @StateObject private var tradingState = TradingState()
    @StateObject private var tradingSettings = TradingSettings.shared
    @StateObject private var pendingPairManager = PendingPairManager.shared

    @State private var amount: Double = 2000
    @State private var buyPrice: Double = 0
    @State private var sellPrice: Double = 0
    @State private var showCreateConfirmation = false
    @State private var isCreatingPair = false
    @State private var orderError: String?
    @State private var showErrorAlert = false
    @State private var completedPairs: [CompletedGridPair] = []
    @State private var isLoadingHistory = false

    // Open positions (buy filled, sell pending) - matched from Binance
    @State private var openPositions: [OpenPosition] = []

    // Cancellation/Close confirmations
    @State private var showCancelPendingPair = false
    @State private var pendingPairToCancel: PendingPair?
    @State private var showCloseConfirmation = false
    @State private var positionToClose: OpenPosition?

    // Price range: ±10% of current price
    private var minBuyPrice: Double { currentPrice * 0.90 }
    private var maxBuyPrice: Double { currentPrice }
    private var minSellPrice: Double { currentPrice }
    private var maxSellPrice: Double { currentPrice * 1.10 }

    // Backend always has credentials - they're stored on the server
    private var hasCredentials: Bool { true }

    // Badge color based on environment
    private var badgeColor: Color {
        switch tradingSettings.environmentColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .green
        }
    }

    // Effective amount (scaled by safe mode)
    private var effectiveAmount: Double {
        tradingSettings.scaleAmount(amount)
    }

    var body: some View {
        VStack(spacing: 8) {
            if hasCredentials {
                // Sticky Price Header
                stickyPriceHeader

                // Compact Balance Row
                compactBalanceRow

                Divider()
                    .padding(.vertical, 4)

                // New Grid Pair Section
                newGridPairSection

                // Active Positions Section (unified)
                if !pendingPairManager.pendingPairs.isEmpty || !openPositions.isEmpty || !pendingPairManager.simulatedFills.isEmpty {
                    activePositionsSection
                }

                // Profit History at the bottom
                ProfitHistoryView(
                    completedPairs: completedPairs,
                    isLoading: isLoadingHistory
                )
            } else {
                noCredentialsView
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .onAppear {
            initializePrices()
            if hasCredentials {
                loadTradingData()
            }
        }
        .onChange(of: currentPrice) { _, newPrice in
            if buyPrice == 0 {
                buyPrice = newPrice * 0.95  // Default 5% below
            }
            if sellPrice == 0 {
                sellPrice = newPrice * 1.05  // Default 5% above
            }
            // Update open positions with new current price
            openPositions = openPositions.map { position in
                OpenPosition(
                    buyTrade: position.buyTrade,
                    pendingSellOrder: position.pendingSellOrder,
                    currentPrice: newPrice
                )
            }
        }
        .alert("Create Trading Pair", isPresented: $showCreateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                createPendingPair()
            }
        } message: {
            let profit = ProfitCalculation(buyPrice: buyPrice, sellPrice: sellPrice, amount: effectiveAmount)
            let safeModeText = (tradingSettings.isProduction && tradingSettings.safeMode) ? "\n\n⚠️ SAFE MODE: Using \(effectiveAmount.formatAsCurrency(maximumFractionDigits: 2))" : ""
            Text("Place BUY order at \(buyPrice.formatAsCurrency(maximumFractionDigits: 0))\n\nSell will be placed at \(sellPrice.formatAsCurrency(maximumFractionDigits: 0)) when buy fills.\n\nAmount: \(effectiveAmount.formatAsCurrency(maximumFractionDigits: 2))\nPotential profit: \(profit.formattedProfit) (\(profit.formattedPercentage))\(safeModeText)")
        }
        .alert("Cancel Pending Pair", isPresented: $showCancelPendingPair) {
            Button("Keep", role: .cancel) {}
            Button("Cancel Pair", role: .destructive) {
                if let pair = pendingPairToCancel {
                    cancelPendingPair(pair)
                }
            }
        } message: {
            if let pair = pendingPairToCancel {
                Text("Cancel buy order at \(pair.buyPrice.formatAsCurrency(maximumFractionDigits: 0))?\n\nThis will remove the pending pair.")
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(orderError ?? "Unknown error occurred")
        }
        .alert("Close Position", isPresented: $showCloseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Close Now") {
                if let position = positionToClose {
                    closePosition(position)
                }
            }
        } message: {
            if let position = positionToClose {
                Text("Market sell \(String(format: "%.5f", position.quantity)) BTC at current price?\n\nEstimated profit: \(position.formattedPnL) (\(position.formattedPercentage))")
            }
        }
    }

    // MARK: - Sticky Price Header

    private var stickyPriceHeader: some View {
        HStack {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text(currentPrice.formatAsCurrency(maximumFractionDigits: 0))
                .font(.title2.bold())

            // Environment badge
            Text(tradingSettings.environmentName.uppercased())
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(badgeColor)
                )

            Spacer()

            Button {
                loadTradingData()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
            }
            .disabled(tradingState.isLoading)

            if tradingState.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Compact Balance Row

    private var compactBalanceRow: some View {
        HStack(spacing: 16) {
            // USDT
            HStack(spacing: 4) {
                Text("USDT:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(tradingState.usdtAvailable.formatAsCurrency(maximumFractionDigits: 0))
                    .font(.caption.bold())
            }

            Divider()
                .frame(height: 12)

            // BTC
            HStack(spacing: 4) {
                Text("BTC:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatBTC(tradingState.btcAvailable))
                    .font(.caption.bold())
                Text("(~\((tradingState.btcAvailable * currentPrice).formatAsCurrency(maximumFractionDigits: 0)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Connection status
            if let error = tradingState.error {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .onTapGesture {
                        orderError = error
                        showErrorAlert = true
                    }
            } else if tradingState.usdtAvailable > 0 || tradingState.btcAvailable > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - New Grid Pair Section

    private var newGridPairSection: some View {
        VStack(spacing: 8) {
            // Header with amount
            HStack {
                Text("NEW TRADING PAIR")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Spacer()

                // Amount stepper
                HStack(spacing: 8) {
                    Button {
                        if amount > 1000 { amount -= 500 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }

                    Text(amount.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .frame(width: 50)

                    Button {
                        if amount < 4000 { amount += 500 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Dual slider
            DualPriceSlider(
                buyPrice: $buyPrice,
                sellPrice: $sellPrice,
                currentPrice: currentPrice,
                minPrice: minBuyPrice,
                maxPrice: maxSellPrice
            )

            // Price labels
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BUY")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text("(-\(String(format: "%.1f", (1 - buyPrice/currentPrice) * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("CURRENT")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(currentPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("SELL")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(sellPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    Text("(+\(String(format: "%.1f", (sellPrice/currentPrice - 1) * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Profit and Create button
            HStack {
                let profit = ProfitCalculation(buyPrice: buyPrice, sellPrice: sellPrice, amount: effectiveAmount)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("EST. PROFIT")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if tradingSettings.isProduction && tradingSettings.safeMode {
                            Text("(SAFE)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(profit.formattedProfit)
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                        Text("(\(profit.formattedPercentage))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Button {
                    showCreateConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        if isCreatingPair {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text("CREATE PAIR")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isCreatingPair)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Active Positions Section (Unified)

    private var activePositionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTIVE POSITIONS")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            // State 2: Open positions (buy filled, sell pending) - have CLOSE button
            ForEach(openPositions) { position in
                UnifiedPairRow(
                    state: .sellPending(position),
                    currentPrice: currentPrice,
                    debugMode: tradingSettings.debugMode,
                    onModifySellOrder: { newPrice in
                        modifySellOrder(position.pendingSellOrder, newPrice: newPrice)
                    },
                    onClose: {
                        positionToClose = position
                        showCloseConfirmation = true
                    }
                )
            }

            // Debug: Simulated fills (sell orders placed without real buy trades)
            ForEach(pendingPairManager.simulatedFills) { fill in
                simulatedFillRow(fill)
            }

            // State 1: Pending pairs (buy pending, sell not placed yet)
            ForEach(pendingPairManager.pendingPairs) { pair in
                UnifiedPairRow(
                    state: .buyPending(pair),
                    currentPrice: currentPrice,
                    debugMode: tradingSettings.debugMode,
                    onCancelPair: {
                        pendingPairToCancel = pair
                        showCancelPendingPair = true
                    },
                    onModifyBuyPrice: { newPrice in
                        modifyPendingPairBuyPrice(pair, newPrice: newPrice)
                    },
                    onModifyIntendedSellPrice: { newPrice in
                        pendingPairManager.updateIntendedSellPrice(id: pair.id, newPrice: newPrice)
                    },
                    onSimulateFill: {
                        simulateBuyFill(pair)
                    }
                )
            }
        }
    }

    // MARK: - Simulated Fill Row (Debug)

    @ViewBuilder
    private func simulatedFillRow(_ fill: SimulatedFill) -> some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("SIMULATED SELL")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("Debug")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().stroke(Color.orange, lineWidth: 1))
            }

            // Prices
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BOUGHT (simulated)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(fill.buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                // P&L at market
                let pnl = (currentPrice - fill.buyPrice) * fill.quantity
                VStack(spacing: 2) {
                    Text("P&L @ Market")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(pnl >= 0 ? "+" : "")\(pnl.formatAsCurrency(maximumFractionDigits: 2))")
                        .font(.caption.bold())
                        .foregroundColor(pnl >= 0 ? .green : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("SELL TARGET")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(fill.sellPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                // Cancel button
                Button {
                    cancelSimulatedFill(fill)
                } label: {
                    Text("CANCEL")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Close at market button (if profit > 0)
                if pnl > 0 {
                    Button {
                        closeSimulatedFillAtMarket(fill)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("CLOSE FOR")
                            Text("+\(pnl.formatAsCurrency(maximumFractionDigits: 2))")
                                .bold()
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func cancelSimulatedFill(_ fill: SimulatedFill) {
        Task {
            do {
                // Cancel the sell order on Binance
                _ = try await BinanceTradingService.shared.cancelOrder(orderId: fill.sellOrderId)

                await MainActor.run {
                    pendingPairManager.removeSimulatedFill(sellOrderId: fill.sellOrderId)
                    loadTradingData()
                }
            } catch {
                await MainActor.run {
                    // Remove anyway - order might already be filled/cancelled
                    pendingPairManager.removeSimulatedFill(sellOrderId: fill.sellOrderId)
                    loadTradingData()
                }
            }
        }
    }

    private func closeSimulatedFillAtMarket(_ fill: SimulatedFill) {
        Task {
            do {
                // Cancel the existing sell limit order
                do {
                    _ = try await BinanceTradingService.shared.cancelOrder(orderId: fill.sellOrderId)
                    print("[CloseSimulated] Cancelled limit sell order \(fill.sellOrderId)")
                } catch {
                    print("[CloseSimulated] Could not cancel sell order: \(error)")
                }

                // Place a market sell order
                print("[CloseSimulated] Placing market sell for qty=\(fill.quantity)")
                _ = try await BinanceTradingService.shared.createMarketOrder(
                    side: .sell,
                    quantity: fill.quantity
                )
                print("[CloseSimulated] ✅ Market sell executed")

                await MainActor.run {
                    // Remove from simulated fills
                    pendingPairManager.removeSimulatedFill(sellOrderId: fill.sellOrderId)
                    loadTradingData()
                }
            } catch {
                print("[CloseSimulated] ❌ Error: \(error)")
                await MainActor.run {
                    orderError = "Close failed: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - No Credentials View

    private var noCredentialsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.title)
                .foregroundColor(.secondary)

            Text("Backend Connection Error")
                .font(.subheadline.bold())

            Text("Unable to connect to trading backend. Please check your internet connection.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }

    // MARK: - Actions

    private func initializePrices() {
        if currentPrice > 0 {
            buyPrice = currentPrice * 0.95  // Default 5% below
            sellPrice = currentPrice * 1.05  // Default 5% above
        }
    }

    private func loadTradingData() {
        guard hasCredentials else { return }

        tradingState.isLoading = true
        isLoadingHistory = true

        Task {
            do {
                async let balanceTask = BinanceTradingService.shared.getAccountBalance()
                async let ordersTask = BinanceTradingService.shared.getOpenOrders()
                async let historyTask = BinanceTradingService.shared.getCompletedGridPairs()

                let (balance, orders, history) = try await (balanceTask, ordersTask, historyTask)

                // Check for filled buy orders from pending pairs
                await checkForFilledBuyOrders(openOrders: orders)

                // Load open positions (buy filled, sell pending)
                let positions = try await BinanceTradingService.shared.getOpenPositions(
                    openOrders: orders,
                    currentPrice: currentPrice
                )

                await MainActor.run {
                    tradingState.accountBalance = balance
                    tradingState.openOrders = orders
                    completedPairs = history
                    openPositions = positions
                    tradingState.isLoading = false
                    isLoadingHistory = false
                }
            } catch {
                await MainActor.run {
                    tradingState.error = error.localizedDescription
                    tradingState.isLoading = false
                    isLoadingHistory = false
                }
            }
        }
    }

    /// Check if any pending pair's buy order has filled, and if so, place the sell order
    private func checkForFilledBuyOrders(openOrders: [BinanceOrder]) async {
        let pendingPairs = await MainActor.run { pendingPairManager.pendingPairs }

        for pair in pendingPairs {
            // Check if buy order is still in open orders
            let buyOrderStillOpen = openOrders.contains { $0.orderId == pair.buyOrderId }
            print("[FillCheck] Pair buyOrderId=\(pair.buyOrderId), stillOpen=\(buyOrderStillOpen)")

            if !buyOrderStillOpen {
                // Buy order is no longer open - it may have filled!
                // Check trade history to confirm
                do {
                    let trades = try await BinanceTradingService.shared.getTradeHistory()
                    print("[FillCheck] Got \(trades.count) trades from history")

                    // Log the order IDs we're looking for vs what we have
                    let buyerTrades = trades.filter { $0.isBuyer }
                    print("[FillCheck] Looking for orderId=\(pair.buyOrderId), buyer trades: \(buyerTrades.map { $0.orderId })")

                    let buyTrade = trades.first { $0.orderId == pair.buyOrderId && $0.isBuyer }

                    if let trade = buyTrade {
                        // Buy order filled! Place the sell order now
                        print("[FillCheck] ✅ Buy order \(pair.buyOrderId) filled! Placing sell order at \(pair.intendedSellPrice), qty=\(pair.quantity)")

                        let sellOrder = try await BinanceTradingService.shared.createLimitOrder(
                            side: .sell,
                            price: pair.intendedSellPrice,
                            quantity: pair.quantity
                        )
                        print("[FillCheck] ✅ Sell order placed: \(sellOrder.orderId)")

                        // Remove from pending pairs (now tracked by Binance)
                        await MainActor.run {
                            pendingPairManager.remove(buyOrderId: pair.buyOrderId)
                        }
                    } else {
                        // Order not found in trades - DON'T remove yet, might be timing issue
                        print("[FillCheck] ⚠️ Order \(pair.buyOrderId) not in open orders AND not in trade history - keeping for now")
                    }
                } catch {
                    print("[FillCheck] ❌ Error: \(error)")
                }
            }
        }
    }

    /// Create a new pending pair (buy order only, sell will be placed when buy fills)
    private func createPendingPair() {
        isCreatingPair = true

        Task {
            do {
                // Calculate quantity
                let quantity = effectiveAmount / buyPrice

                // Create only the BUY order
                let buyOrder = try await BinanceTradingService.shared.createLimitOrder(
                    side: .buy,
                    price: buyPrice,
                    quantity: quantity
                )

                // Store pending pair locally with intended sell price
                let pendingPair = PendingPair(
                    buyOrderId: buyOrder.orderId,
                    buyPrice: buyPrice,
                    intendedSellPrice: sellPrice,
                    quantity: quantity,
                    amountUSD: effectiveAmount
                )

                await MainActor.run {
                    pendingPairManager.add(pendingPair)
                    isCreatingPair = false
                    loadTradingData()

                    // Reset sliders for next pair
                    self.buyPrice = currentPrice * 0.95
                    self.sellPrice = currentPrice * 1.05
                }
            } catch {
                await MainActor.run {
                    isCreatingPair = false
                    orderError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    /// Cancel a pending pair (cancel buy order + remove from local storage)
    private func cancelPendingPair(_ pair: PendingPair) {
        Task {
            do {
                // Cancel the buy order on Binance
                _ = try await BinanceTradingService.shared.cancelOrder(orderId: pair.buyOrderId)

                await MainActor.run {
                    // Remove from local storage
                    pendingPairManager.remove(id: pair.id)
                    loadTradingData()
                }
            } catch {
                await MainActor.run {
                    // Remove from local storage anyway (order might already be filled/cancelled)
                    pendingPairManager.remove(id: pair.id)
                    loadTradingData()

                    let errorMsg = error.localizedDescription
                    if !errorMsg.contains("Unknown order") {
                        orderError = errorMsg
                        showErrorAlert = true
                    }
                }
            }
        }
    }

    /// DEBUG: Simulate a buy order fill by placing the sell order directly
    /// This bypasses the actual buy order and places the sell order as if the buy had filled
    private func simulateBuyFill(_ pair: PendingPair) {
        Task {
            do {
                print("[SimulateFill] Simulating fill for pair buyOrderId=\(pair.buyOrderId)")

                // Cancel the buy order (since we're simulating it filled)
                do {
                    _ = try await BinanceTradingService.shared.cancelOrder(orderId: pair.buyOrderId)
                    print("[SimulateFill] Cancelled buy order")
                } catch {
                    print("[SimulateFill] Could not cancel buy order (might already be filled): \(error)")
                }

                // Place the sell order at the intended price
                print("[SimulateFill] Placing sell order at \(pair.intendedSellPrice), qty=\(pair.quantity)")
                let sellOrder = try await BinanceTradingService.shared.createLimitOrder(
                    side: .sell,
                    price: pair.intendedSellPrice,
                    quantity: pair.quantity
                )
                print("[SimulateFill] ✅ Sell order placed: \(sellOrder.orderId)")

                await MainActor.run {
                    // Store the simulated fill so we can display it
                    let simulatedFill = SimulatedFill(from: pair, sellOrderId: sellOrder.orderId)
                    pendingPairManager.addSimulatedFill(simulatedFill)

                    // Remove from pending pairs
                    pendingPairManager.remove(id: pair.id)
                    loadTradingData()
                }
            } catch {
                print("[SimulateFill] ❌ Error: \(error)")
                await MainActor.run {
                    orderError = "Simulate fill failed: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    /// Modify a pending pair's buy price (cancel old order, create new, update local storage)
    private func modifyPendingPairBuyPrice(_ pair: PendingPair, newPrice: Double) {
        Task {
            do {
                // Cancel old buy order
                _ = try await BinanceTradingService.shared.cancelOrder(orderId: pair.buyOrderId)

                // Create new buy order at new price (same USD amount)
                let newQuantity = pair.amountUSD / newPrice
                let newOrder = try await BinanceTradingService.shared.createLimitOrder(
                    side: .buy,
                    price: newPrice,
                    quantity: newQuantity
                )

                await MainActor.run {
                    // Update local storage with new order ID
                    pendingPairManager.updateBuyOrder(
                        id: pair.id,
                        newOrderId: newOrder.orderId,
                        newPrice: newPrice,
                        newQuantity: newQuantity
                    )
                    loadTradingData()
                }
            } catch {
                await MainActor.run {
                    loadTradingData()
                    orderError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    /// Modify a sell order price (for open positions - State 2)
    private func modifySellOrder(_ order: BinanceOrder, newPrice: Double) {
        Task {
            do {
                // Cancel existing order
                _ = try await BinanceTradingService.shared.cancelOrder(orderId: order.orderId)

                // Create new order at new price
                _ = try await BinanceTradingService.shared.createLimitOrder(
                    side: .sell,
                    price: newPrice,
                    quantity: order.quantityDouble
                )

                await MainActor.run {
                    loadTradingData()
                }
            } catch {
                await MainActor.run {
                    loadTradingData()
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("Unknown order") {
                        orderError = "Order was already filled or cancelled. Refreshing..."
                    } else {
                        orderError = errorMsg
                    }
                    showErrorAlert = true
                }
            }
        }
    }

    /// Close an open position (cancel sell order + market sell)
    private func closePosition(_ position: OpenPosition) {
        Task {
            do {
                // First cancel the pending sell order
                _ = try await BinanceTradingService.shared.cancelOrder(orderId: position.pendingSellOrder.orderId)

                // Market sell the BTC quantity
                _ = try await BinanceTradingService.shared.createMarketOrder(
                    side: .sell,
                    quantity: position.quantity
                )

                await MainActor.run {
                    loadTradingData()
                }
            } catch {
                await MainActor.run {
                    loadTradingData()

                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("Unknown order") {
                        orderError = "Order was already filled or cancelled. Refreshing..."
                    } else {
                        orderError = errorMsg
                    }
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatBTC(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}

#Preview {
    TradingView(currentPrice: 98000)
        .padding()
        .background(Color(.systemGroupedBackground))
}
