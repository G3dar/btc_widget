import WidgetKit
import Foundation

struct BTCTimelineProvider: TimelineProvider {
    typealias Entry = PriceEntry

    // Placeholder for widget gallery
    func placeholder(in context: Context) -> PriceEntry {
        .placeholder
    }

    // Snapshot for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        Task {
            do {
                let data = try await BitcoinAPIService.shared.fetchBitcoinData()
                let entry = PriceEntry(date: Date(), bitcoinData: data)
                completion(entry)
            } catch {
                completion(.placeholder)
            }
        }
    }

    // Main timeline generation
    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            do {
                let data = try await BitcoinAPIService.shared.fetchBitcoinData()
                let currentDate = Date()
                let entry = PriceEntry(date: currentDate, bitcoinData: data)

                // Update every 2 minutes
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: currentDate) ?? currentDate.addingTimeInterval(120)

                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                // On error, use placeholder and retry in 2 minutes
                let entry = PriceEntry.placeholder
                let nextUpdate = Date().addingTimeInterval(120)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}
