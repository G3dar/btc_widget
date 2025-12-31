import ActivityKit
import Foundation
import Combine

// MARK: - Activity Attributes (must match widget extension)

struct BTCActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPrice: Double
        var percentChange: Double
        var lastUpdated: Date

        var isPositive: Bool {
            percentChange >= 0
        }

        var formattedPrice: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: currentPrice)) ?? "$\(Int(currentPrice))"
        }

        var formattedChange: String {
            let sign = percentChange >= 0 ? "+" : ""
            return sign + String(format: "%.2f%%", percentChange)
        }
    }

    var activityName: String
}

// MARK: - Live Activity Manager

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var isActivityActive = false
    @Published var currentActivity: Activity<BTCActivityAttributes>?

    private var updateTimer: Timer?

    private init() {
        checkExistingActivity()
    }

    private func checkExistingActivity() {
        if let activity = Activity<BTCActivityAttributes>.activities.first {
            currentActivity = activity
            isActivityActive = true
        }
    }

    func startLiveActivity(with data: BitcoinData) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        // End any existing activity first
        for activity in Activity<BTCActivityAttributes>.activities {
            Task {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }

        // Small delay to ensure old activities are cleared
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let attributes = BTCActivityAttributes(activityName: "BTC Price")
            let contentState = BTCActivityAttributes.ContentState(
                currentPrice: data.currentPrice,
                percentChange: data.percentChange,
                lastUpdated: data.lastUpdated
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil),
                    pushType: nil
                )

                await MainActor.run {
                    self.currentActivity = activity
                    self.isActivityActive = true
                }

                startAutoUpdate()
                print("Live Activity started: \(activity.id)")
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }
    }

    func updateLiveActivity(with data: BitcoinData) {
        guard let activity = currentActivity else { return }

        let contentState = BTCActivityAttributes.ContentState(
            currentPrice: data.currentPrice,
            percentChange: data.percentChange,
            lastUpdated: data.lastUpdated
        )

        Task {
            await activity.update(
                ActivityContent(state: contentState, staleDate: Date().addingTimeInterval(180))
            )
        }
    }

    func stopLiveActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(activity.content, dismissalPolicy: .immediate)
            await MainActor.run {
                currentActivity = nil
                isActivityActive = false
            }
        }

        stopAutoUpdate()
    }

    // MARK: - Auto Update

    private func startAutoUpdate() {
        stopAutoUpdate()

        // Update every 60 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAndUpdate()
            }
        }
    }

    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func fetchAndUpdate() async {
        do {
            let data = try await BitcoinAPIService.shared.fetchBitcoinData(for: .sixHours)
            updateLiveActivity(with: data)
        } catch {
            print("Failed to fetch data for Live Activity: \(error)")
        }
    }
}
