//
//  ContentView.swift
//  BTCWidget
//
//  Created by German Heller on 12/18/25.
//

import SwiftUI
import Charts
import ActivityKit
import Combine
import WidgetKit

struct ContentView: View {
    @State private var bitcoinData: BitcoinData?
    @State private var selectedRange: TimeRange = .sixHours
    @State private var isLoading = true
    @State private var isChartLoading = false
    @State private var errorMessage: String?
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @State private var countdown = 10
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    // Auto-refresh timer (every 10 seconds)
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    // Countdown timer (every 1 second)
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        compactPriceHeader(data: nil)
                        loadingView
                    } else if let data = bitcoinData {
                        compactPriceHeader(data: data)
                        chartWithControls(data: data)

                        // Trading Section
                        TradingView(currentPrice: data.currentPrice)
                    } else if let error = errorMessage {
                        compactPriceHeader(data: nil)
                        errorView(message: error)
                    }

                    binanceButton

                    if let data = bitcoinData {
                        lastUpdatedView(date: data.lastUpdated)
                    }

                    if !isLoading {
                        countdownView
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                APIKeySetupView()
            }
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedRange) { _, _ in
            isChartLoading = true
            Task {
                await loadData(showLoading: false)  // Don't show full-page loading for chart refresh
                await MainActor.run { isChartLoading = false }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await loadData(showLoading: false)
                }
            }
        }
        .onReceive(refreshTimer) { _ in
            if scenePhase == .active {
                countdown = 10
                Task {
                    await loadData(showLoading: false)
                }
            }
        }
        .onReceive(countdownTimer) { _ in
            if scenePhase == .active && countdown > 0 {
                countdown -= 1
            }
        }
    }

    // MARK: - Compact Price Header

    private func compactPriceHeader(data: BitcoinData?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Bitcoin icon
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            // Price
            if let data = data {
                Text(data.currentPrice.formatAsCurrency(maximumFractionDigits: 2))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Percent change badge
            if let data = data {
                HStack(spacing: 3) {
                    Image(systemName: data.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.bold())
                    Text(data.percentChange.formatAsPercentWithSign())
                        .font(.subheadline.bold())
                }
                .foregroundStyle(data.isPositive ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(data.isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Chart with Controls (Compact)

    private func chartWithControls(data: BitcoinData) -> some View {
        VStack(spacing: 0) {
            // Time range buttons above chart
            HStack(spacing: 4) {
                ForEach(TimeRange.allCases) { range in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRange = range
                        }
                    } label: {
                        Text(range.displayName)
                            .font(.caption2.bold())
                            .foregroundColor(
                                selectedRange == range ? .white : .secondary
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedRange == range
                                        ? Color.orange
                                        : Color(.systemGray5).opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Chart
            ZStack {
                InteractiveChartView(data: data, selectedRange: selectedRange)
                    .frame(height: 200)
                    .opacity(isChartLoading ? 0.5 : 1.0)

                if isChartLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.orange)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isChartLoading)

            // Inline High/Low stats below chart
            HStack(spacing: 0) {
                // High
                HStack(spacing: 4) {
                    Text("H")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(data.highPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 12)

                Spacer()

                // Low
                HStack(spacing: 4) {
                    Text("L")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(data.lowPrice.formatAsCurrency(maximumFractionDigits: 0))
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Binance Button

    private var binanceButton: some View {
        Button(action: openBinance) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)

                Text("Open Binance")
                    .font(.headline)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
            }
            .foregroundColor(.black)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadData()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Last Updated View

    private func lastUpdatedView(date: Date) -> some View {
        Text("Updated \(date.timeAgoDisplay())")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private var countdownView: some View {
        Text("Updating in \(countdown)...")
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.6))
            .monospacedDigit()
    }

    // MARK: - Data Loading

    private func loadData(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            let data = try await BitcoinAPIService.shared.fetchBitcoinData(for: selectedRange)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.bitcoinData = data
                    self.errorMessage = nil
                    self.isLoading = false
                }

                // Auto-start or update Live Activity
                if liveActivityManager.isActivityActive {
                    liveActivityManager.updateLiveActivity(with: data)
                } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                    liveActivityManager.startLiveActivity(with: data)
                }

                // Refresh widget
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            await MainActor.run {
                if showLoading {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Binance Deep Link

    private func openBinance() {
        // Try to open Binance app to BTC/USDT spot trading
        // Universal link is most reliable
        let urls = [
            "https://app.binance.com/en/trade/BTC_USDT",  // Universal link - opens in app if installed
            "binance://spot?symbol=BTCUSDT",              // Direct to spot trading
            "bnc://app.binance.com/en/trade/BTC_USDT"     // Alternative scheme
        ]

        func tryURL(at index: Int) {
            guard index < urls.count else {
                // All URLs failed, open App Store
                if let appStoreURL = URL(string: "itms-apps://apps.apple.com/app/id1436799971") {
                    UIApplication.shared.open(appStoreURL)
                }
                return
            }

            if let url = URL(string: urls[index]) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        tryURL(at: index + 1)
                    }
                }
            } else {
                tryURL(at: index + 1)
            }
        }

        tryURL(at: 0)
    }
}

#Preview {
    ContentView()
}
