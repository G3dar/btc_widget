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

struct ContentView: View {
    @State private var bitcoinData: BitcoinData?
    @State private var selectedRange: TimeRange = .twentyFourHours
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @State private var countdown = 10
    @Environment(\.scenePhase) private var scenePhase

    // Auto-refresh timer (every 10 seconds to avoid API rate limits)
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    // Countdown timer (every 1 second)
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    priceHeader

                    if isLoading {
                        loadingView
                    } else if let data = bitcoinData {
                        chartSection(data: data)
                        timeRangeSelector
                        statsSection(data: data)
                    } else if let error = errorMessage {
                        errorView(message: error)
                    }

                    xapoButton

                    if let data = bitcoinData {
                        lastUpdatedView(date: data.lastUpdated)
                        countdownView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedRange) { _, _ in
            Task {
                await loadData()
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

    // MARK: - Price Header

    private var priceHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Bitcoin")
                    .font(.title2.bold())
            }

            if let data = bitcoinData {
                Text(data.currentPrice.formatAsCurrency(maximumFractionDigits: 2))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                HStack(spacing: 4) {
                    Image(systemName: data.isPositive ? "arrow.up.right" : "arrow.down.right")
                    Text(data.percentChange.formatAsPercentWithSign())
                }
                .font(.headline)
                .foregroundStyle(data.isPositive ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(data.isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                )
            } else {
                Text("--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Chart Section

    private func chartSection(data: BitcoinData) -> some View {
        VStack {
            InteractiveChartView(data: data, selectedRange: selectedRange)
                .frame(height: 280)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.displayName)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedRange == range
                                ? Color.orange
                                : Color.clear
                        )
                        .foregroundColor(
                            selectedRange == range
                                ? .white
                                : .primary
                        )
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Stats Section

    private func statsSection(data: BitcoinData) -> some View {
        HStack(spacing: 16) {
            statCard(
                title: "High",
                value: data.highPrice.formatAsCurrency(maximumFractionDigits: 0),
                color: .green
            )

            statCard(
                title: "Low",
                value: data.lowPrice.formatAsCurrency(maximumFractionDigits: 0),
                color: .red
            )
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - XAPO Button

    private var xapoButton: some View {
        Button(action: openXAPO) {
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.title2)

                Text("Open XAPO Bank")
                    .font(.headline)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
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
                    self.isLoading = false
                }

                // Auto-start or update Live Activity
                if liveActivityManager.isActivityActive {
                    liveActivityManager.updateLiveActivity(with: data)
                } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                    liveActivityManager.startLiveActivity(with: data)
                }
            }
        } catch {
            await MainActor.run {
                // Only show error if we were showing loading indicator
                if showLoading {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - XAPO Deep Link

    private func openXAPO() {
        // Try to open XAPO app directly
        let schemes = ["xapo://", "xapobank://", "xapo-bank://"]

        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback to App Store
        if let appStoreURL = URL(string: "https://apps.apple.com/app/id1560681080") {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

#Preview {
    ContentView()
}
