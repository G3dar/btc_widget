import SwiftUI

/// A unified row component that displays a trading pair in either state:
/// - State 1: Buy Pending (from PendingPair) - both sliders editable
/// - State 2: Buy Filled / Sell Pending (from OpenPosition) - only sell editable, has CLOSE button
struct UnifiedPairRow: View {
    enum PairState {
        case buyPending(PendingPair)
        case sellPending(OpenPosition)
    }

    let state: PairState
    let currentPrice: Double
    let debugMode: Bool

    // Callbacks for State 1 (Buy Pending)
    var onCancelPair: (() -> Void)?
    var onModifyBuyPrice: ((Double) -> Void)?
    var onModifyIntendedSellPrice: ((Double) -> Void)?
    var onSimulateFill: (() -> Void)?  // Debug only

    // Callbacks for State 2 (Sell Pending)
    var onModifySellOrder: ((Double) -> Void)?
    var onClose: (() -> Void)?

    // Edit state
    @State private var isEditingBuy = false
    @State private var isEditingSell = false
    @State private var editBuyPrice: Double = 0
    @State private var editSellPrice: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Header showing state
            stateHeader

            // Slider
            sliderView

            // Bottom row: prices and actions
            bottomRow
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditing ? Color.orange.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEditing ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isEditingBuy)
        .animation(.easeInOut(duration: 0.2), value: isEditingSell)
    }

    // MARK: - Computed Properties

    private var isEditing: Bool {
        isEditingBuy || isEditingSell
    }

    private var buyPrice: Double {
        switch state {
        case .buyPending(let pair): return pair.buyPrice
        case .sellPending(let position): return position.buyPrice
        }
    }

    private var sellPrice: Double {
        switch state {
        case .buyPending(let pair): return pair.intendedSellPrice
        case .sellPending(let position): return position.targetSellPrice
        }
    }

    private var quantity: Double {
        switch state {
        case .buyPending(let pair): return pair.quantity
        case .sellPending(let position): return position.quantity
        }
    }

    private var amountUSD: Double {
        switch state {
        case .buyPending(let pair): return pair.amountUSD
        case .sellPending(let position): return position.investedAmount
        }
    }

    /// The USDT value when the sell order fills (quantity * sell price)
    private var saleValue: Double {
        let sellP = isEditingSell ? editSellPrice : sellPrice
        return sellP * quantity
    }

    /// Current P&L if we closed at market price (State 2 only)
    private var pnlAtMarket: Double {
        switch state {
        case .buyPending: return 0
        case .sellPending(let position): return position.unrealizedNetPnL
        }
    }

    /// Estimated profit based on buy/sell prices
    private var estimatedProfit: Double {
        let buyP = isEditingBuy ? editBuyPrice : buyPrice
        let sellP = isEditingSell ? editSellPrice : sellPrice
        let grossProfit = (sellP - buyP) * quantity
        let buyCommission = (buyP * quantity) * 0.001
        let sellCommission = (sellP * quantity) * 0.001
        return grossProfit - buyCommission - sellCommission
    }

    private var estimatedProfitPercentage: Double {
        guard amountUSD > 0 else { return 0 }
        return (estimatedProfit / amountUSD) * 100
    }

    // MARK: - State Header

    private var stateHeader: some View {
        HStack {
            switch state {
            case .buyPending(let pair):
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    Text("BUY PENDING")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatCompactAmount(saleValue))
                        .font(.caption2)
                        .foregroundColor(isEditingSell ? .orange : .secondary)
                }
                Spacer()
                Text(pair.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)

            case .sellPending:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("SELL PENDING")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatCompactAmount(saleValue))
                        .font(.caption2)
                        .foregroundColor(isEditingSell ? .orange : .secondary)
                }
                Spacer()
                Text("bought @ \(buyPrice.formatAsCurrency(maximumFractionDigits: 0))")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
    }

    private func formatCompactAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            let k = amount / 1000
            if k == floor(k) {
                return "$\(Int(k))K"
            } else {
                return String(format: "$%.1fK", k)
            }
        } else {
            return "$\(Int(amount))"
        }
    }

    // MARK: - Slider View

    private var sliderView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let minPrice = min(buyPrice, currentPrice * 0.90)
            let maxPrice = max(sellPrice, currentPrice * 1.10)
            let range = maxPrice - minPrice

            let buyPos = max(0, min(1, ((isEditingBuy ? editBuyPrice : buyPrice) - minPrice) / range))
            let sellPos = max(0, min(1, ((isEditingSell ? editSellPrice : sellPrice) - minPrice) / range))
            let currentPos = max(0, min(1, (currentPrice - minPrice) / range))

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                // Filled area between buy and sell
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.5), .red.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, width * (sellPos - buyPos)), height: 6)
                    .offset(x: width * buyPos)

                // Current price marker
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: 20)
                    .offset(x: width * currentPos - 1)

                // Buy dot
                buyDot(width: width, minPrice: minPrice, range: range, buyPos: buyPos)

                // Sell dot
                sellDot(width: width, minPrice: minPrice, maxPrice: maxPrice, range: range, sellPos: sellPos)
            }
        }
        .frame(height: 40)
    }

    @ViewBuilder
    private func buyDot(width: CGFloat, minPrice: Double, range: Double, buyPos: Double) -> some View {
        let dotSize: CGFloat = 16

        switch state {
        case .buyPending:
            // Draggable buy dot
            Circle()
                .fill(isEditingBuy ? Color.orange : Color.green)
                .frame(width: dotSize, height: dotSize)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: isEditingBuy ? .orange.opacity(0.5) : .clear, radius: 4)
                .offset(x: width * buyPos - dotSize / 2)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            isEditingBuy = true
                            let newPos = gesture.location.x / width
                            let newPrice = minPrice + (newPos * range)
                            editBuyPrice = min(max(newPrice, minPrice), currentPrice - 50)
                            editBuyPrice = (editBuyPrice / 10).rounded() * 10
                        }
                )

        case .sellPending:
            // Fixed buy dot (not draggable)
            Circle()
                .fill(Color.green)
                .frame(width: dotSize - 4, height: dotSize - 4)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .offset(x: width * buyPos - (dotSize - 4.0) / 2.0)
        }
    }

    @ViewBuilder
    private func sellDot(width: CGFloat, minPrice: Double, maxPrice: Double, range: Double, sellPos: Double) -> some View {
        let dotSize: CGFloat = 16

        Circle()
            .fill(isEditingSell ? Color.orange : Color.red)
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: isEditingSell ? .orange.opacity(0.5) : .clear, radius: 4)
            .offset(x: width * sellPos - dotSize / 2)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isEditingSell = true
                        let newPos = gesture.location.x / width
                        let newPrice = minPrice + (newPos * range)
                        editSellPrice = max(min(newPrice, maxPrice), currentPrice + 50)
                        editSellPrice = (editSellPrice / 10).rounded() * 10
                    }
            )
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack {
            // Left: Buy price info
            VStack(alignment: .leading, spacing: 2) {
                Text(state.isBuyPending ? "BUY" : "BOUGHT")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if isEditingBuy {
                    Text(editBuyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                } else {
                    Text(buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Center: Profit or edit controls
            centerContent

            Spacer()

            // Right: Sell price info
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.isBuyPending ? "SELL (intended)" : "SELL TARGET")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if isEditingSell {
                    Text(editSellPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                } else {
                    Text(sellPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        if isEditing {
            // Edit mode: Cancel and Confirm buttons
            HStack(spacing: 8) {
                Button {
                    isEditingBuy = false
                    isEditingSell = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.gray))
                }
                .buttonStyle(.plain)

                Button {
                    confirmEdits()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.green))
                }
                .buttonStyle(.plain)
            }
        } else {
            // Normal mode: Show profit and actions
            switch state {
            case .buyPending:
                buyPendingCenterContent

            case .sellPending(let position):
                sellPendingCenterContent(position: position)
            }
        }
    }

    private var buyPendingCenterContent: some View {
        VStack(spacing: 4) {
            // Estimated profit
            HStack(spacing: 4) {
                Text(estimatedProfit >= 0 ? "+" : "")
                Text(estimatedProfit.formatAsCurrency(maximumFractionDigits: 2))
            }
            .font(.caption.bold())
            .foregroundColor(estimatedProfit >= 0 ? .green : .red)

            HStack(spacing: 8) {
                // Cancel button
                Button {
                    onCancelPair?()
                } label: {
                    Text("CANCEL")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Debug: Simulate Fill button
                if debugMode {
                    Button {
                        onSimulateFill?()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("FILL")
                                .font(.caption2.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func sellPendingCenterContent(position: OpenPosition) -> some View {
        VStack(spacing: 4) {
            // Current P&L at market
            Text("P&L: \(pnlAtMarket >= 0 ? "+" : "")\(pnlAtMarket.formatAsCurrency(maximumFractionDigits: 2))")
                .font(.caption2)
                .foregroundColor(pnlAtMarket >= 0 ? .green : .red)

            // CLOSE NOW button
            Button {
                onClose?()
            } label: {
                if pnlAtMarket > 0 {
                    // Profit - clickable green button
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("CLOSE FOR")
                        Text("+\(pnlAtMarket.formatAsCurrency(maximumFractionDigits: 2))")
                            .bold()
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.3), radius: 3, y: 2)
                    )
                } else {
                    // Loss - disabled red button
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("CLOSE")
                        Text(pnlAtMarket.formatAsCurrency(maximumFractionDigits: 2))
                            .bold()
                    }
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(pnlAtMarket <= 0)
        }
    }

    // MARK: - Actions

    private func confirmEdits() {
        switch state {
        case .buyPending:
            if isEditingBuy {
                onModifyBuyPrice?(editBuyPrice)
            }
            if isEditingSell {
                onModifyIntendedSellPrice?(editSellPrice)
            }

        case .sellPending:
            if isEditingSell {
                onModifySellOrder?(editSellPrice)
            }
        }

        isEditingBuy = false
        isEditingSell = false
    }
}

// MARK: - Helper Extension

extension UnifiedPairRow.PairState {
    var isBuyPending: Bool {
        switch self {
        case .buyPending: return true
        case .sellPending: return false
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        Text("State 1: Buy Pending")
            .font(.headline)

        UnifiedPairRow(
            state: .buyPending(PendingPair(
                buyOrderId: 12345,
                buyPrice: 94000,
                intendedSellPrice: 98000,
                quantity: 0.02128,
                amountUSD: 2000
            )),
            currentPrice: 96000,
            debugMode: true,
            onCancelPair: {},
            onModifyBuyPrice: { _ in },
            onModifyIntendedSellPrice: { _ in },
            onSimulateFill: {}
        )

        Text("State 2: Sell Pending (Profit)")
            .font(.headline)

        // Would need actual OpenPosition object for full preview
        Text("(Requires OpenPosition mock)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
