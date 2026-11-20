import Foundation

/// An in-memory pair. The monotonic instant is never exported or compared across sessions.
struct DisplayClockReport {
    struct Sample {
        let date: Date, zone: TimeZone, instant: ContinuousClock.Instant
        let status: DisplayMinute, reference: DisplayMinute?
        let statusResult: DisplayClockComparison, referenceResult: DisplayClockComparison?

        var displayDetails: String {
            details(local: date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, timeZone: zone)))
        }

        var details: String { details(local: date.formatted(Date.ISO8601FormatStyle(timeZone: zone))) }

        private func details(local: String) -> String {
            let trusted: String
            if let reference, let referenceResult { trusted = "\(reference.text) (\(Self.label(referenceResult)))" }
            else { trusted = "not entered" }
            return "Device: \(local) · \(zone.identifier)\nStatus bar (reported): \(status.text) (\(Self.label(statusResult)))\nTrusted local clock (reported): \(trusted)"
        }

        private static func label(_ result: DisplayClockComparison) -> String {
            switch result {
            case .matches: return "compatible with device minute"
            case .indeterminate: return "one minute apart; possible rollover"
            case .differs: return "differs from device"
            }
        }
    }

    enum InputError: String, LocalizedError {
        case status = "Enter the hours and minutes shown in the status bar, for example 9:41."
        case reference = "Use 24-hour HH:mm for the trusted local clock, for example 21:41, or leave it blank."
        case tooSoon = "Wait at least 60 seconds, then look at the clocks again."
        case complete = "Clear these clock readings before starting another check."
        var errorDescription: String? { rawValue }
    }

    private(set) var samples: [Sample] = []

    mutating func record(status: String, reference: String, date: Date = Date(), zone: TimeZone = .current,
                         instant: ContinuousClock.Instant = .now) throws {
        guard samples.count < 2 else { throw InputError.complete }
        if let first = samples.first, first.instant.duration(to: instant) < .seconds(60) { throw InputError.tooSoon }
        guard let visible = DisplayMinute(status) else { throw InputError.status }
        let trusted = DisplayMinute(reference, strict24Hour: true)
        guard trusted != nil || reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InputError.reference }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        samples.append(Sample(date: date, zone: zone, instant: instant, status: visible, reference: trusted,
                              statusResult: visible.compare(at: date, calendar: calendar, allow12Hour: true),
                              referenceResult: trusted?.compare(at: date, calendar: calendar, allow12Hour: false)))
    }

    enum Finding: String {
        case empty = "No clock readings recorded."
        case incomplete = "One reading cannot show whether the status time is stuck."
        case timing = "The interval, device clock or time zone changed unexpectedly. Start a fresh pair 1–10 minutes apart."
        case other = "These are not two reports of 9:41. They do not establish a stuck 9:41 display."
        case ambiguous = "At least one 9:41 report is compatible with the device time or a minute rollover. Try again later."
        case unconfirmed = "You reported 9:41 twice while the device clock advanced. Two matching independent readings are needed to distinguish a display discrepancy from a device clock problem."
        case conflicting = "You reported 9:41 twice while the device clock advanced, but the trusted local clock disagreed with the device. Check the device time and time zone before drawing a conclusion."
        case supported = "You reported 9:41 twice while the device clock advanced and matched both trusted local readings. This supports a display-only discrepancy. It does not prove a particular preference or cause. Only local time of day was compared, not the calendar date or region."
    }

    var finding: Finding {
        guard let a = samples.first else { return .empty }
        guard samples.count == 2 else { return .incomplete }
        let b = samples[1], gap = a.instant.duration(to: b.instant)
        let wall = b.date.timeIntervalSince(a.date)
        // Allow slight sampling jitter, not a manual clock jump, DST transition or stale pair.
        guard gap >= .seconds(60), gap <= .seconds(600), wall >= 60,
              abs(wall - gap.secondsValue) <= 2, a.zone.identifier == b.zone.identifier,
              a.zone.secondsFromGMT(for: a.date) == b.zone.secondsFromGMT(for: b.date) else { return .timing }
        guard samples.allSatisfy({ $0.status.hour == 9 && $0.status.minute == 41 }) else { return .other }
        guard samples.allSatisfy({ $0.statusResult == .differs }) else { return .ambiguous }
        if samples.contains(where: { $0.referenceResult == .differs }) { return .conflicting }
        return samples.allSatisfy { $0.referenceResult == .matches } ? .supported : .unconfirmed
    }

    var summary: String {
        finding.rawValue + (finding == .supported ? "" : " Incorrect device time or time zone is not ruled out.")
    }

    var elapsedDescription: String? {
        guard samples.count == 2 else { return nil }
        return "Elapsed between readings: \(Int(samples[0].instant.duration(to: samples[1].instant).secondsValue)) seconds."
    }

    var text: String {
        var rows = samples.enumerated().map { "Reading \($0.offset + 1)\n\($0.element.details)" }
        if let elapsedDescription { rows.append(elapsedDescription) }
        rows.append(summary)
        return rows.joined(separator: "\n\n")
    }
}

private extension Duration {
    var secondsValue: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
