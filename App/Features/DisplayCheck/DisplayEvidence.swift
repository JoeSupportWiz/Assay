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
        let s = visible.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: ":")
        let a=s.split(separator: ":", omittingEmptySubsequences: false)
        guard a.count==2, (1...2).contains(a[0].count), a[1].count==2,
              s.utf8.allSatisfy({ (48...57).contains($0) || $0==58 }),
              let h=Int(a[0]), (0...23).contains(h), let m=Int(a[1]), (0...59).contains(m) else { return nil }
        func same(_ d: Date) -> Bool { let hour=calendar.component(.hour, from:d); return calendar.component(.minute,from:d)==m && (h==hour || h == (hour+11)%12+1) }
        if same(date) { return .matches }
        if same(date.addingTimeInterval(-60)) || same(date.addingTimeInterval(60)) { return .indeterminate }
        return .differs
    }
}
