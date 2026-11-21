import Foundation

/// A calendar day of existing local receipts, not a device health or success score.
struct ReceiptDay: Identifiable, Equatable {
    let date: Date
    var id: Date { date }
    var previews = 0
    var other = 0
    var total: Int { previews + other }
}

enum ReceiptCalendar {
    struct Event { let date: Date; let engine: String; let preview: Bool }
    static func days(_ events: [Event], engine: String, now: Date, calendar: Calendar) -> [ReceiptDay] {
        let today = calendar.startOfDay(for: now)
        let dates = (-27...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }.map { calendar.startOfDay(for: $0) }
        var days = dates.map { ReceiptDay(date: $0) }
        let positions = Dictionary(uniqueKeysWithValues: dates.enumerated().map { ($1, $0) })
        for event in events where event.engine == engine && event.date <= now {
            guard let i = positions[calendar.startOfDay(for: event.date)] else { continue }
            if event.preview { days[i].previews += 1 } else { days[i].other += 1 }
        }
        return days
    }
}
