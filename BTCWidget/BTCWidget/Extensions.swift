import Foundation

extension Double {
    func formatAsCurrency(maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    func formatAsCompactCurrency() -> String {
        if self >= 1000 {
            return String(format: "$%.1fk", self / 1000)
        }
        return String(format: "$%.0f", self)
    }

    func formatAsPercent() -> String {
        return String(format: "%.2f%%", self)
    }

    func formatAsPercentWithSign() -> String {
        let sign = self >= 0 ? "+" : ""
        return sign + String(format: "%.2f%%", self)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    func formattedForChart(in range: TimeRange) -> String {
        let formatter = DateFormatter()
        switch range {
        case .threeHours, .sixHours, .twelveHours, .twentyFourHours:
            formatter.dateFormat = "HH:mm"
        case .sevenDays:
            formatter.dateFormat = "EEE"
        case .thirtyDays:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: self)
    }
}
