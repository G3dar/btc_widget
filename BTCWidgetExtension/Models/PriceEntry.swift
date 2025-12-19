import WidgetKit
import Foundation

struct PriceEntry: TimelineEntry {
    let date: Date
    let bitcoinData: BitcoinData
    let isPlaceholder: Bool

    init(date: Date, bitcoinData: BitcoinData, isPlaceholder: Bool = false) {
        self.date = date
        self.bitcoinData = bitcoinData
        self.isPlaceholder = isPlaceholder
    }

    static var placeholder: PriceEntry {
        PriceEntry(
            date: Date(),
            bitcoinData: .placeholder,
            isPlaceholder: true
        )
    }
}
