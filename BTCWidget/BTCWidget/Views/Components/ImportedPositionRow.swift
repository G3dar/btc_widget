import SwiftUI

/// Row component for imported positions (sell orders with estimated buy prices)
struct ImportedPositionRow: View {
    let fill: SimulatedFill
    let currentPrice: Double

    var onClose: () -> Void
    var onModifySellPrice: (Double) -> Void

    @State private var isEditing = false
    @State private var editSellPrice: Double = 0
    @State private var dragOffset: CGFloat = 0

    init(fill: SimulatedFill, currentPrice: Double, onClose: @escaping () -> Void, onModifySellPrice: @escaping (Double) -> Void) {
        self.fill = fill
        self.currentPrice = currentPrice
        self.onClose = onClose
        self.onModifySellPrice = onModifySellPrice
        self._editSellPrice = State(initialValue: fill.sellPrice)
    }

    private var displaySellPrice: Double {
        isEditing ? editSellPrice : fill.sellPrice
    }

    private var pnl: Double {
        (currentPrice - fill.buyPrice) * fill.quantity
    }

    private var goalProfit: Double {
        (displaySellPrice - fill.buyPrice) * fill.quantity
    }

    private var originalGoalProfit: Double {
        (fill.sellPrice - fill.buyPrice) * fill.quantity
    }

    private var profitChange: Double {
        goalProfit - originalGoalProfit
    }

    /// The USDT value when the sell order fills (quantity * sell price)
    private var saleValue: Double {
        displaySellPrice * fill.quantity
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

    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 8) {
                // Header
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isEditing ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text("SELL PENDING")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatCompactAmount(saleValue))
                            .font(.caption2)
                            .foregroundColor(isEditing ? .orange : .secondary)
                    }
                    Spacer()
                    Text("bought @ \(fill.buyPrice.formatAsCurrency(maximumFractionDigits: 0))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }

                // Prices
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BOUGHT")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(fill.buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }

                    Spacer()

                    // Goal profit and close button
                    VStack(spacing: 4) {
                        if isEditing {
                            // Show profit comparison when editing
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Was:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("+\(originalGoalProfit.formatAsCurrency(maximumFractionDigits: 2))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .strikethrough()
                                }
                                HStack(spacing: 4) {
                                    Text("New:")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("+\(goalProfit.formatAsCurrency(maximumFractionDigits: 2))")
                                        .font(.caption2.bold())
                                        .foregroundColor(.orange)
                                    Text("(\(profitChange >= 0 ? "+" : "")\(profitChange.formatAsCurrency(maximumFractionDigits: 2)))")
                                        .font(.caption2)
                                        .foregroundColor(profitChange >= 0 ? .green : .red)
                                }
                            }

                            // Confirm/Cancel buttons when editing
                            HStack(spacing: 8) {
                                Button {
                                    isEditing = false
                                    editSellPrice = fill.sellPrice
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Circle().fill(Color.gray))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    onModifySellPrice(editSellPrice)
                                    isEditing = false
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
                            Text("Goal: +\(goalProfit.formatAsCurrency(maximumFractionDigits: 2))")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        if !isEditing {
                            if pnl > 0 {
                                Button {
                                    onClose()
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green)
                                            .shadow(color: .green.opacity(0.3), radius: 3, y: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                    Text("CLOSE")
                                    Text(pnl.formatAsCurrency(maximumFractionDigits: 2))
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
                    }

                    Spacer()

                    // Sell target with price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SELL TARGET")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(displaySellPrice.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(isEditing ? .orange : .red)
                    }
                }
            }
            .padding(10)

            // Vertical slider on the right
            verticalSlider
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditing ? Color.orange.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEditing ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    private var verticalSlider: some View {
        // Vertical drag area to adjust sell price
        Rectangle()
            .fill(Color.red.opacity(0.3))
            .frame(width: 24)
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                    Text("$")
                        .font(.system(size: 10, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.red.opacity(0.8))
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 12
                )
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !isEditing {
                            isEditing = true
                            editSellPrice = fill.sellPrice
                        }
                        // Dragging up increases price, down decreases
                        // Scale: 100 points of drag = $1000 price change
                        let priceChange = -gesture.translation.height * 10
                        let newPrice = fill.sellPrice + priceChange
                        // Clamp to reasonable range (above current price)
                        editSellPrice = max(currentPrice + 100, newPrice)
                        // Round to nearest $10
                        editSellPrice = (editSellPrice / 10).rounded() * 10
                    }
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        ImportedPositionRow(
            fill: SimulatedFill(
                buyPrice: 85500,
                sellPrice: 89000,
                quantity: 0.02262,
                amountUSD: 1934,
                sellOrderId: 12345
            ),
            currentPrice: 88000,
            onClose: {},
            onModifySellPrice: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
