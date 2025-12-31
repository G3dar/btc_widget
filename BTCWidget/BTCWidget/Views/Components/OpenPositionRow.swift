import SwiftUI

struct OpenPositionRow: View {
    let position: OpenPosition
    let currentPrice: Double
    let onClose: () -> Void
    let onModifySellPrice: (Double) -> Void

    @State private var editSellPrice: Double
    @State private var isEditingSell = false

    init(position: OpenPosition, currentPrice: Double, onClose: @escaping () -> Void, onModifySellPrice: @escaping (Double) -> Void) {
        self.position = position
        self.currentPrice = currentPrice
        self.onClose = onClose
        self.onModifySellPrice = onModifySellPrice
        self._editSellPrice = State(initialValue: position.targetSellPrice)
    }

    // Net P&L calculation with editable sell price
    private var projectedPnL: Double {
        let grossProfit = (editSellPrice - position.buyPrice) * position.quantity
        let buyCommission = position.investedAmount * ProfitCalculation.commissionRate
        let sellCommission = (editSellPrice * position.quantity) * ProfitCalculation.commissionRate
        return grossProfit - buyCommission - sellCommission
    }

    private var projectedPnLPercentage: Double {
        guard position.investedAmount > 0 else { return 0 }
        return (projectedPnL / position.investedAmount) * 100
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header row: Bought price, target, invested
            HStack {
                // Bought at (fixed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BOUGHT")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(position.buyPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                // Current price
                VStack(spacing: 2) {
                    Text("NOW")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(currentPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.subheadline.bold())
                }

                Spacer()

                // Target sell (editable)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SELL TARGET")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text((isEditingSell ? editSellPrice : position.targetSellPrice).formatAsCurrency(maximumFractionDigits: 0))
                        .font(.subheadline.bold())
                        .foregroundColor(isEditingSell ? .orange : .red)
                }
            }

            // Slider for sell price
            OpenPositionSlider(
                sellPrice: $editSellPrice,
                buyPrice: position.buyPrice,
                currentPrice: currentPrice,
                originalSellPrice: position.targetSellPrice,
                isEditing: $isEditingSell
            )

            // Projected profit and actions
            HStack {
                // Projected P&L
                VStack(alignment: .leading, spacing: 2) {
                    Text("EST. PROFIT")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(projectedPnL >= 0 ? "+\(projectedPnL.formatAsCurrency(maximumFractionDigits: 2))" : projectedPnL.formatAsCurrency(maximumFractionDigits: 2))
                            .font(.caption.bold())
                        Text("(\(projectedPnL >= 0 ? "+" : "")\(String(format: "%.2f", projectedPnLPercentage))%)")
                            .font(.caption2)
                    }
                    .foregroundColor(projectedPnL >= 0 ? .green : .red)
                }

                Spacer()

                // Action buttons
                if isEditingSell {
                    // Cancel and Save buttons when editing
                    HStack(spacing: 8) {
                        Button {
                            editSellPrice = position.targetSellPrice
                            isEditingSell = false
                        } label: {
                            Text("Cancel")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(.systemGray5)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onModifySellPrice(editSellPrice)
                            isEditingSell = false
                        } label: {
                            Text("Update")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Close button - always visible, styled prominently
                    Button {
                        onClose()
                    } label: {
                        if position.isInProfit {
                            // In profit - prominent green button with clear call to action
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption)
                                    Text("CLOSE NOW")
                                        .font(.caption.bold())
                                }
                                Text("FOR \(position.formattedPnL)")
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green)
                                    .shadow(color: .green.opacity(0.4), radius: 4, y: 2)
                            )
                        } else {
                            // Not in profit - show loss, still closeable but less prominent
                            VStack(spacing: 2) {
                                Text("CLOSE NOW")
                                    .font(.caption.bold())
                                Text(position.formattedPnL)
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 1.5)
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isEditingSell ? Color.orange.opacity(0.5) : Color(.systemGray4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Open Position Slider

struct OpenPositionSlider: View {
    @Binding var sellPrice: Double
    let buyPrice: Double
    let currentPrice: Double
    let originalSellPrice: Double
    @Binding var isEditing: Bool

    private let trackHeight: CGFloat = 6
    private let dotSize: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Range: from buy price to 15% above current price
            let minPrice = buyPrice
            let maxPrice = max(originalSellPrice, currentPrice * 1.15)
            let range = maxPrice - minPrice
            let currentPos = max(0, min(1, (currentPrice - minPrice) / range))

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(.systemGray5))
                    .frame(height: trackHeight)

                // Filled area from buy to sell
                let sellPos = max(0, min(1, (sellPrice - minPrice) / range))
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.5), .red.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, width * sellPos), height: trackHeight)

                // Current price marker (orange line)
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: trackHeight + 14)
                    .offset(x: width * currentPos - 1)

                // Buy dot (green, fixed at left)
                Circle()
                    .fill(Color.green)
                    .frame(width: dotSize - 4, height: dotSize - 4)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: -((dotSize - 4) / 2))

                // Sell dot (red) - draggable
                Circle()
                    .fill(isEditing ? Color.orange : Color.red)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: isEditing ? .orange.opacity(0.5) : .clear, radius: 4)
                    .offset(x: width * sellPos - dotSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isEditing = true
                                let newPos = gesture.location.x / width
                                let newPrice = minPrice + (newPos * range)
                                // Clamp: must be above current price + 50
                                sellPrice = max(min(newPrice, maxPrice), currentPrice + 50)
                                sellPrice = (sellPrice / 10).rounded() * 10
                            }
                    )

                // Current price label below the line
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: dotSize + 6)
                    VStack(spacing: 0) {
                        Text("CURRENT")
                            .font(.system(size: 7, weight: .medium))
                        Text(currentPrice.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .offset(x: width * currentPos - 25)
                }
            }
        }
        .frame(height: dotSize + 24)
    }
}

#Preview {
    VStack(spacing: 12) {
        let mockBuyTrade = BinanceTrade(
            id: 1,
            orderId: 100,
            symbol: "BTCUSDT",
            price: "95000.00",
            qty: "0.02105",
            quoteQty: "2000.00",
            commission: "0.00002105",
            commissionAsset: "BTC",
            time: Int64(Date().timeIntervalSince1970 * 1000),
            isBuyer: true,
            isMaker: true
        )

        let mockSellOrder = BinanceOrder(
            orderId: 101,
            symbol: "BTCUSDT",
            side: "SELL",
            type: "LIMIT",
            price: "100000.00",
            origQty: "0.02105",
            executedQty: "0",
            status: "NEW",
            time: Int64(Date().timeIntervalSince1970 * 1000)
        )

        OpenPositionRow(
            position: OpenPosition(
                buyTrade: mockBuyTrade,
                pendingSellOrder: mockSellOrder,
                currentPrice: 98000
            ),
            currentPrice: 98000,
            onClose: {},
            onModifySellPrice: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
