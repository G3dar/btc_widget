import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var bitcoinData: BitcoinData?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Price Card
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(height: 200)
                    } else if let data = bitcoinData {
                        PriceCard(data: data)
                    } else if let error = errorMessage {
                        ErrorCard(message: error, onRetry: fetchData)
                    }

                    // Widget Instructions
                    WidgetInstructionsCard()
                }
                .padding()
            }
            .navigationTitle("BTC Widget")
            .refreshable {
                await fetchDataAsync()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await fetchDataAsync()
        }
    }

    private func fetchData() {
        Task {
            await fetchDataAsync()
        }
    }

    private func fetchDataAsync() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await BitcoinAPIService.shared.fetchBitcoinData()
            bitcoinData = data
            // Reload widgets
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Unable to load data. Pull to retry."
        }

        isLoading = false
    }
}

// MARK: - Price Card
struct PriceCard: View {
    let data: BitcoinData

    private var isPositive: Bool {
        data.percentChange6h >= 0
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bitcoin")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("BTC/USD")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                        Text(String(format: "%.2f%%", abs(data.percentChange6h)))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(isPositive ? .green : .red)

                    Text("6h")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(formatPrice(data.currentPrice))
                .font(.system(size: 44, weight: .bold, design: .rounded))

            // Chart
            MiniChartView(
                prices: data.priceHistory,
                isPositive: isPositive,
                lineWidth: 3,
                showGradient: true
            )
            .frame(height: 100)

            // High/Low
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("High", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(data.high6h))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label("Low", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(data.low6h))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }

            // Last updated
            Text("Updated: \(data.lastUpdated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
}

// MARK: - Widget Instructions Card
struct WidgetInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Add Widget", systemImage: "plus.square.on.square")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Long press on your Lock Screen or Home Screen")
                InstructionRow(number: 2, text: "Tap \"Customize\" or the + button")
                InstructionRow(number: 3, text: "Search for \"BTC Widget\"")
                InstructionRow(number: 4, text: "Choose your preferred widget size")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.orange))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Error Card
struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    ContentView()
}
