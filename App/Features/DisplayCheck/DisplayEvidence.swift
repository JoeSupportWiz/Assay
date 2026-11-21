import Foundation

/// Counts complete preset-import records, not individual key mentions, planned resets or restore verdicts.
struct DisplayImportEvidence: Equatable {
    var records = 0
    var recordingRecords = 0
    var authLineRecords = 0
    var lastRecording = false
    var lastAuthLine = false
    static func parse(_ text: String) -> Self {
        var result = Self()
        text.enumerateLines { raw, _ in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("applied "), let boundary = line.range(of: " tweak(s): "),
                  let n = Int(line.dropFirst(8).prefix(while: { $0.isNumber })), (1...5000).contains(n),
                  String(line[..<boundary.lowerBound]) == "applied \(n)" else { return }
            let keys = line[boundary.upperBound...].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard keys.count == n, Set(keys).count == n else { return }
            result.records += 1
            result.lastRecording = keys.contains("SBShowStatusBarOverridesForRecording")
            result.lastAuthLine = keys.contains("SBShowAuthenticationEngineeringUI")
            if result.lastRecording { result.recordingRecords += 1 }
            if result.lastAuthLine { result.authLineRecords += 1 }
        }
        return result
    }
}

enum DisplayClockComparison: Equatable {
    case matches, differs, indeterminate
    /// Comparison is local, not an internet time check. Accept 12h (no AM/PM) or 24h. A minute boundary is ambiguous.
    static func evaluate(_ visible: String, at date: Date, calendar: Calendar = .current) -> Self? {
        guard let minute = DisplayMinute(visible) else { return nil }
        return minute.compare(at: date, calendar: calendar, allow12Hour: true)
    }
}

struct DisplayMinute: Equatable {
    let hour: Int, minute: Int
    var text: String { String(format: "%02d:%02d", hour, minute) }

    init?(_ input: String, strict24Hour: Bool = false) {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = s.replacingOccurrences(of: ".", with: ":").split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 2, (1...2).contains(fields[0].count), fields[1].count == 2,
              fields.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let h = Int(fields[0]), h < 24, let m = Int(fields[1]), m < 60,
              !strict24Hour || (fields[0].count == 2 && s.contains(":")) else { return nil }
        hour = h; minute = m
    }

    func compare(at date: Date, calendar: Calendar, allow12Hour: Bool) -> DisplayClockComparison {
        func same(_ d: Date) -> Bool {
            let h = calendar.component(.hour, from: d)
            return minute == calendar.component(.minute, from: d) && (hour == h || (allow12Hour && hour == (h+11)%12+1))
        }
        if same(date) { return .matches }
        if same(date.addingTimeInterval(-60)) || same(date.addingTimeInterval(60)) { return .indeterminate }
        return .differs
    }
}
