import SwiftUI

/// Represents a Binance order that can be imported
struct ImportableOrder: Identifiable {
    let id: Int64
    let orderId: Int64
    let side: String // "BUY" or "SELL"
    let price: Double
    let quantity: Double
    var intendedPrice: Double // For BUY: intended sell price, For SELL: original buy price

    var isBuy: Bool { side == "BUY" }
}

struct DebugView: View {
    @StateObject private var tradingSettings = TradingSettings.shared
    @StateObject private var pendingPairManager = PendingPairManager.shared
    @State private var testResults: [BackendService.TestResult] = []
    @State private var isRunning = false
    @State private var hasRun = false
    @State private var showManualImport = false

    // Auto-import
    @State private var showAutoImport = false
    @State private var isLoadingOrders = false
    @State private var importableOrders: [ImportableOrder] = []
    @State private var importError: String?

    // Manual import fields
    @State private var importSellOrderId: String = ""
    @State private var importSellPrice: String = ""
    @State private var importQuantity: String = ""
    @State private var importBuyPrice: String = ""

    var body: some View {
        NavigationView {
            List {
                Section("Debug Settings") {
                    Toggle(isOn: $tradingSettings.debugMode) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Debug Mode")
                                Text("Shows simulate fill buttons on pending pairs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Import from Binance") {
                    Button {
                        loadOrdersForImport()
                        showAutoImport = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Auto-Import Orders")
                                Text("Fetch open orders from Binance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button {
                        showManualImport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Manual Import")
                                Text("Enter order details manually")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !pendingPairManager.simulatedFills.isEmpty || !pendingPairManager.pendingPairs.isEmpty {
                    Section("Imported Positions") {
                        // Imported sell orders
                        ForEach(pendingPairManager.simulatedFills) { fill in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text("SELL @ \(fill.sellPrice.formatAsCurrency(maximumFractionDigits: 0))")
                                            .font(.subheadline.bold())
                                    }
                                    Text("Qty: \(String(format: "%.5f", fill.quantity)) • Bought: \(fill.buyPrice.formatAsCurrency(maximumFractionDigits: 0))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    pendingPairManager.removeSimulatedFill(sellOrderId: fill.sellOrderId)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Imported pending buy orders
                        ForEach(pendingPairManager.pendingPairs) { pair in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("BUY @ \(pair.buyPrice.formatAsCurrency(maximumFractionDigits: 0))")
                                            .font(.subheadline.bold())
                                    }
                                    Text("Qty: \(String(format: "%.5f", pair.quantity)) • Sell target: \(pair.intendedSellPrice.formatAsCurrency(maximumFractionDigits: 0))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    pendingPairManager.remove(id: pair.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button(role: .destructive) {
                            pendingPairManager.clearSimulatedFills()
                            for pair in pendingPairManager.pendingPairs {
                                pendingPairManager.remove(id: pair.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Clear All")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        runTests()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                            Text("Run All Tests")
                            Spacer()
                            if isRunning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRunning)
                }

                if hasRun {
                    Section("Results") {
                        ForEach(testResults, id: \.endpoint) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.endpoint)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(String(format: "%.0fms", result.duration * 1000))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(result.success ? .secondary : .red)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Summary") {
                        let passed = testResults.filter { $0.success }.count
                        let failed = testResults.filter { !$0.success }.count

                        HStack {
                            Label("\(passed) Passed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Label("\(failed) Failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(failed > 0 ? .red : .secondary)
                        }
                        .font(.subheadline)
                    }
                }

                Section("Backend Info") {
                    LabeledContent("URL", value: "btc-trading-backend.fly.dev")
                    LabeledContent("Environment", value: "Testnet")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showManualImport) {
                manualImportSheet
            }
            .sheet(isPresented: $showAutoImport) {
                autoImportSheet
            }
        }
    }

    // MARK: - Auto Import Sheet

    private var autoImportSheet: some View {
        NavigationView {
            Group {
                if isLoadingOrders {
                    VStack {
                        ProgressView()
                        Text("Loading orders from Binance...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else if let error = importError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error loading orders")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadOrdersForImport()
                        }
                    }
                    .padding()
                } else if importableOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No orders to import")
                            .font(.headline)
                        Text("All open orders are already imported or there are no open orders.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            Text("Set the missing price for each order, then tap Import.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ForEach($importableOrders) { $order in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: order.isBuy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundColor(order.isBuy ? .green : .red)
                                    Text("\(order.side) @ \(order.price.formatAsCurrency(maximumFractionDigits: 0))")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(String(format: "%.5f", order.quantity)) BTC")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(order.isBuy ? "Sell target:" : "Bought at:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextField(order.isBuy ? "Sell price" : "Buy price", value: $order.intendedPrice, format: .currency(code: "USD"))
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)

                                    Spacer()

                                    let profit = order.isBuy
                                        ? (order.intendedPrice - order.price) * order.quantity
                                        : (order.price - order.intendedPrice) * order.quantity
                                    Text("Goal: +\(profit.formatAsCurrency(maximumFractionDigits: 2))")
                                        .font(.caption)
                                        .foregroundColor(profit > 0 ? .green : .red)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Section {
                            Button {
                                performAutoImport()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Import \(importableOrders.count) Order(s)")
                                        .bold()
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAutoImport = false
                    }
                }
            }
        }
    }

    private func loadOrdersForImport() {
        isLoadingOrders = true
        importError = nil
        importableOrders = []

        Task {
            do {
                let orders = try await BinanceTradingService.shared.getOpenOrders()

                await MainActor.run {
                    var importable: [ImportableOrder] = []

                    for order in orders {
                        let orderId = order.orderId
                        let price = order.priceDouble
                        let quantity = order.quantityDouble
                        let side = order.side

                        // Check if already imported
                        let alreadyImported = pendingPairManager.pendingPairs.contains { $0.buyOrderId == orderId }
                            || pendingPairManager.simulatedFills.contains { $0.sellOrderId == orderId }

                        if !alreadyImported {
                            // Default intended price: +5% for buys, -5% for sells
                            let defaultIntended = side == "BUY" ? price * 1.05 : price * 0.95

                            importable.append(ImportableOrder(
                                id: orderId,
                                orderId: orderId,
                                side: side,
                                price: price,
                                quantity: quantity,
                                intendedPrice: defaultIntended
                            ))
                        }
                    }

                    importableOrders = importable
                    isLoadingOrders = false
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isLoadingOrders = false
                }
            }
        }
    }

    private func performAutoImport() {
        for order in importableOrders {
            if order.isBuy {
                // Import as pending pair (buy order waiting to fill)
                let pair = PendingPair(
                    buyOrderId: order.orderId,
                    buyPrice: order.price,
                    intendedSellPrice: order.intendedPrice,
                    quantity: order.quantity,
                    amountUSD: order.price * order.quantity
                )
                pendingPairManager.add(pair)
            } else {
                // Import as simulated fill (sell order with estimated buy price)
                pendingPairManager.importSimulatedFill(
                    buyPrice: order.intendedPrice,
                    sellPrice: order.price,
                    quantity: order.quantity,
                    sellOrderId: order.orderId
                )
            }
        }

        showAutoImport = false
        importableOrders = []
    }

    private var manualImportSheet: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter the details of an existing Binance sell order to track it with its original buy price.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Sell Order Details") {
                    TextField("Sell Order ID (from Binance)", text: $importSellOrderId)
                        .keyboardType(.numberPad)
                    TextField("Sell Price ($)", text: $importSellPrice)
                        .keyboardType(.decimalPad)
                    TextField("Quantity (BTC)", text: $importQuantity)
                        .keyboardType(.decimalPad)
                }

                Section("Original Buy Price") {
                    TextField("Buy Price ($)", text: $importBuyPrice)
                        .keyboardType(.decimalPad)
                    Text("Enter the price you originally bought this BTC at")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        performManualImport()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Import Order")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(!isImportValid)
                }
            }
            .navigationTitle("Import Sell Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showManualImport = false
                        clearImportFields()
                    }
                }
            }
        }
    }

    private var isImportValid: Bool {
        guard let orderId = Int64(importSellOrderId), orderId > 0,
              let sellPrice = Double(importSellPrice), sellPrice > 0,
              let quantity = Double(importQuantity), quantity > 0,
              let buyPrice = Double(importBuyPrice), buyPrice > 0 else {
            return false
        }
        return true
    }

    private func performManualImport() {
        guard let orderId = Int64(importSellOrderId),
              let sellPrice = Double(importSellPrice),
              let quantity = Double(importQuantity),
              let buyPrice = Double(importBuyPrice) else {
            return
        }

        // Check if already imported
        let alreadyExists = pendingPairManager.simulatedFills.contains { $0.sellOrderId == orderId }
        if !alreadyExists {
            pendingPairManager.importSimulatedFill(
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                quantity: quantity,
                sellOrderId: orderId
            )
        }

        showManualImport = false
        clearImportFields()
    }

    private func clearImportFields() {
        importSellOrderId = ""
        importSellPrice = ""
        importQuantity = ""
        importBuyPrice = ""
    }

    private func runTests() {
        isRunning = true
        testResults = []

        Task {
            let results = await BackendService.shared.runDiagnostics()

            await MainActor.run {
                testResults = results
                isRunning = false
                hasRun = true
            }
        }
    }
}

#Preview {
    DebugView()
}
