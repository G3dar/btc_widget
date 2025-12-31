import SwiftUI

struct GridPairRow: View {
    let buyOrder: BinanceOrder
    let sellOrder: BinanceOrder
    let currentPrice: Double
    let onCancelBuy: () -> Void
    let onCancelSell: () -> Void
    let onModifyBuy: (Double) -> Void
    let onModifySell: (Double) -> Void

    @State private var isEditingBuy = false
    @State private var isEditingSell = false
    @State private var editBuyPrice: Double = 0
    @State private var editSellPrice: Double = 0

    // Net profit after Binance commissions (0.1% per trade)
    private var profitUSD: Double {
        let qty = buyOrder.quantityDouble
        let buyP = isEditingBuy ? editBuyPrice : buyOrder.priceDouble
        let sellP = isEditingSell ? editSellPrice : sellOrder.priceDouble
        let grossProfit = (sellP - buyP) * qty
        // Commission: 0.1% on buy (in BTC value) + 0.1% on sell (in USDT)
        let buyCommission = (buyP * qty) * ProfitCalculation.commissionRate
        let sellCommission = (sellP * qty) * ProfitCalculation.commissionRate
        return grossProfit - buyCommission - sellCommission
    }

    private var profitPercentage: Double {
        let qty = buyOrder.quantityDouble
        let buyP = isEditingBuy ? editBuyPrice : buyOrder.priceDouble
        let amount = buyP * qty
        guard amount > 0 else { return 0 }
        return (profitUSD / amount) * 100
    }

    var body: some View {
        VStack(spacing: 6) {
            // Visual slider - now interactive
            EditableGridPairSlider(
                buyPrice: isEditingBuy ? $editBuyPrice : .constant(buyOrder.priceDouble),
                sellPrice: isEditingSell ? $editSellPrice : .constant(sellOrder.priceDouble),
                currentPrice: currentPrice,
                isEditingBuy: $isEditingBuy,
                isEditingSell: $isEditingSell,
                originalBuyPrice: buyOrder.priceDouble,
                originalSellPrice: sellOrder.priceDouble
            )

            // Price labels with cancel buttons
            HStack(spacing: 0) {
                // Buy side - tap to edit
                HStack(spacing: 4) {
                    Button(action: onCancelBuy) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    if isEditingBuy {
                        Text(editBuyPrice.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    } else {
                        Text(buyOrder.priceDouble.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .onTapGesture {
                                editBuyPrice = buyOrder.priceDouble
                                isEditingBuy = true
                            }
                    }
                }

                Spacer()

                // Profit badge or confirm buttons
                if isEditingBuy || isEditingSell {
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
                            if isEditingBuy {
                                onModifyBuy(editBuyPrice)
                            }
                            if isEditingSell {
                                onModifySell(editSellPrice)
                            }
                            isEditingBuy = false
                            isEditingSell = false
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
                    Text("+\(profitUSD.formatAsCurrency(maximumFractionDigits: 0))")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                }

                Spacer()

                // Sell side - tap to edit
                HStack(spacing: 4) {
                    if isEditingSell {
                        Text(editSellPrice.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    } else {
                        Text(sellOrder.priceDouble.formatAsCurrency(maximumFractionDigits: 0))
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .onTapGesture {
                                editSellPrice = sellOrder.priceDouble
                                isEditingSell = true
                            }
                    }

                    Button(action: onCancelSell) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEditingBuy || isEditingSell ? Color.orange.opacity(0.1) : Color(.systemGray6))
        )
        .animation(.easeInOut(duration: 0.2), value: isEditingBuy)
        .animation(.easeInOut(duration: 0.2), value: isEditingSell)
    }
}

// MARK: - Editable Grid Pair Slider

struct EditableGridPairSlider: View {
    @Binding var buyPrice: Double
    @Binding var sellPrice: Double
    let currentPrice: Double
    @Binding var isEditingBuy: Bool
    @Binding var isEditingSell: Bool
    let originalBuyPrice: Double
    let originalSellPrice: Double

    private let trackHeight: CGFloat = 6
    private let dotSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = geometry.size.width
                // Range must include: original buy, current price, and original sell
                // So buy can slide up to current price, and sell can slide down to current price
                let minPrice = min(originalBuyPrice, currentPrice * 0.90)
                let maxPrice = max(originalSellPrice, currentPrice * 1.10)
                let range = maxPrice - minPrice
                let currentPos = max(0, min(1, (currentPrice - minPrice) / range))

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color(.systemGray5))
                        .frame(height: trackHeight)

                    // Filled area between buy and sell
                    let buyPos = max(0, min(1, (buyPrice - minPrice) / range))
                    let sellPos = max(0, min(1, (sellPrice - minPrice) / range))
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.5), .red.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, width * (sellPos - buyPos)), height: trackHeight)
                        .offset(x: width * buyPos)

                    // Current price marker (orange line)
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: trackHeight + 14)
                        .offset(x: width * currentPos - 1)

                    // Buy dot (green) - draggable when editing
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
                                    // Clamp: can go up to current price - 50 (to get filled)
                                    buyPrice = min(max(newPrice, minPrice), currentPrice - 50)
                                    buyPrice = (buyPrice / 10).rounded() * 10
                                }
                        )

                    // Sell dot (red) - draggable when editing
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
                                    // Clamp: can go down to current price + 50 (to get filled)
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
}

// MARK: - Single Order Row (for unpaired orders)

struct SingleOrderRow: View {
    let order: BinanceOrder
    let currentPrice: Double
    let onCancel: () -> Void

    private var distancePercent: Double {
        guard currentPrice > 0 else { return 0 }
        return ((order.priceDouble - currentPrice) / currentPrice) * 100
    }

    var body: some View {
        HStack(spacing: 8) {
            // Order indicator
            Circle()
                .fill(order.orderSide == .buy ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Order type
            Text(order.orderSide.displayName.uppercased())
                .font(.caption.bold())
                .foregroundColor(order.orderSide == .buy ? .green : .red)
                .frame(width: 32, alignment: .leading)

            // Price
            Text("@")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(order.priceDouble.formatAsCurrency(maximumFractionDigits: 0))
                .font(.caption.bold())

            // Distance from current price
            Text("(\(distancePercent >= 0 ? "+" : "")\(String(format: "%.1f", distancePercent))%)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            // Amount
            Text(order.usdValue.formatAsCurrency(maximumFractionDigits: 0))
                .font(.caption)
                .foregroundColor(.secondary)

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        // Mock orders for preview
        let mockBuyOrder = BinanceOrder(
            orderId: 1,
            symbol: "BTCUSDT",
            side: "BUY",
            type: "LIMIT",
            price: "88000.00",
            origQty: "0.02273",
            executedQty: "0",
            status: "NEW",
            time: Int64(Date().timeIntervalSince1970 * 1000)
        )

        let mockSellOrder = BinanceOrder(
            orderId: 2,
            symbol: "BTCUSDT",
            side: "SELL",
            type: "LIMIT",
            price: "108000.00",
            origQty: "0.02273",
            executedQty: "0",
            status: "NEW",
            time: Int64(Date().timeIntervalSince1970 * 1000)
        )

        Text("Grid Pair")
            .font(.headline)

        GridPairRow(
            buyOrder: mockBuyOrder,
            sellOrder: mockSellOrder,
            currentPrice: 98000,
            onCancelBuy: {},
            onCancelSell: {},
            onModifyBuy: { _ in },
            onModifySell: { _ in }
        )

        Text("Single Order")
            .font(.headline)

        SingleOrderRow(
            order: mockBuyOrder,
            currentPrice: 98000,
            onCancel: {}
        )
    }
    .padding()
}
