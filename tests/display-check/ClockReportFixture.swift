import Foundation

@main enum ClockReportFixture {
    static func main() throws {
        typealias Report = DisplayClockReport
        let tick = ContinuousClock.now
        let utc = TimeZone(secondsFromGMT: 0)!
        let plus = TimeZone(secondsFromGMT: 3600)!
        let midnight = ISO8601DateFormatter().date(from: "2026-11-19T23:59:20Z")!
        func pair(_ s1: String = "9.41", _ s2: String = "09:41", _ r1: String = "23:59", _ r2: String = "00:00",
                  start: Date? = nil, elapsed: Int = 60, wall: Double = 60, zone1: TimeZone? = nil, zone2: TimeZone? = nil) throws -> Report {
            var pair = Report()
            let start = start ?? midnight
            try pair.record(status: s1, reference: r1, date: start, zone: zone1 ?? utc, instant: tick)
            try pair.record(status: s2, reference: r2, date: start.addingTimeInterval(wall), zone: zone2 ?? zone1 ?? utc,
                            instant: tick.advanced(by: .seconds(elapsed)))
            return pair
        }
        func expect(_ finding: Report.Finding, _ report: Report, line: UInt = #line) {
            precondition(report.finding == finding, "line \(line): \(report.summary)")
            if finding != .supported { precondition(report.text.contains("not ruled out")) }
        }
        func rejects(_ reason: Report.InputError, _ operation: () throws -> Void, line: UInt = #line) throws {
            do { try operation(); preconditionFailure("Accepted invalid reading at \(line)") }
            catch let error as Report.InputError { precondition(error == reason, "line \(line)") }
        }

        var empty = Report()
        expect(.empty, empty)
        try rejects(.status) { try empty.record(status: "", reference: "") }
        try rejects(.reference) { try empty.record(status: "9:41", reference: "9:41") }
        try rejects(.reference) { try empty.record(status: "9:41", reference: "24:00") }
        expect(.empty, empty)
        try empty.record(status: "9:41", reference: "", date: midnight, zone: utc, instant: tick)
        expect(.incomplete, empty)
        try rejects(.tooSoon) {
            try empty.record(status: "9:41", reference: "", date: midnight.addingTimeInterval(3600), zone: utc,
                             instant: tick.advanced(by: .milliseconds(59_999)))
        }
        expect(.incomplete, empty)
        var supported = try pair()
        expect(.supported, supported)
        try rejects(.complete) { try supported.record(status: "9:41", reference: "") }
        for fragment in ["Reading 1", "Reading 2", "2026-11-20", "00:00", "Status bar (reported): 09:41", "60 seconds", "does not prove"] {
            precondition(supported.text.contains(fragment), fragment)
        }
        expect(.other, try pair("10:03", "10:03"))
        expect(.other, try pair("9:41", "9:42"))
        expect(.other, try pair("21:41", "21:41"))
        expect(.unconfirmed, try pair("9:41", "9:41", "", "   "))
        expect(.unconfirmed, try pair("9:41", "9:41", "", "00:00"))
        expect(.unconfirmed, try pair("9:41", "9:41", "23:59", "23:59")) // Rollover, not an exact reference match.
        expect(.conflicting, try pair("9:41", "9:41", "11:59", "00:00")) // Do not fold strict 24h reference to 12h.
        let pm = ISO8601DateFormatter().date(from: "2026-11-19T21:41:30Z")!
        expect(.ambiguous, try pair(start: pm)) // 9:41 without meridiem can be 21:41.
        expect(.ambiguous, try pair(start: pm.addingTimeInterval(60))) // Adjacent minutes.
        expect(.timing, try pair(wall: 0))
        expect(.timing, try pair(wall: -60))
        expect(.timing, try pair(wall: 3600))
        expect(.timing, try pair(elapsed: 601, wall: 601))
        expect(.timing, try pair(zone2: plus))
        let dst = ISO8601DateFormatter().date(from: "2026-03-08T06:59:30Z")!
        expect(.timing, try pair(start: dst, zone1: TimeZone(identifier: "America/New_York")!))
        let local = try pair("9:41", "9:41", "00:59", "01:00", zone1: plus)
        expect(.supported, local)
        precondition(local.text.contains("2026-11-20T00:59") && local.text.contains(plus.identifier))
        print("Two-reading report: input, timing, midnight, zones, references, findings and shared evidence passed")
    }
}
