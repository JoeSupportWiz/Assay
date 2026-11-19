import Foundation
@main enum DisplaySmoke {
    static func main() throws {
        var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(secondsFromGMT:0)!
        func test(_ s:String,_ t:String,_ expected:DisplayClockComparison?) {let d=ISO8601DateFormatter().date(from:t)!;precondition(DisplayClockComparison.evaluate(s,at:d,calendar:calendar)==expected,s)}
        test("09:41","2026-11-19T10:21:41Z",.differs);test("9.41","2026-11-19T21:41:41Z",.matches);test("00:00","2026-11-20T00:00:05Z",.matches);test("23:59","2026-11-20T00:00:05Z",.indeterminate);test("14:26","2026-11-19T14:27:01Z",.indeterminate);test("24:60","2026-11-19T10:21:41Z",nil);test("09:1","2026-11-19T10:21:41Z",nil)
        let input="""
           applied 2 tweak(s): SBShowAuthenticationEngineeringUI, SBShowStatusBarOverridesForRecording
           applied 1 tweak(s): SBShowAuthenticationEngineeringUI
           applied 2 tweak(s): SBShowStatusBarOverridesForRecording
           switched off — not compatible: SBShowStatusBarOverridesForRecording
           applied 1 tweak(s): OtherSBShowStatusBarOverridesForRecordingExtra
        """
        let e=DisplayImportEvidence.parse(input);precondition(e.records==3 && e.authLineRecords==2 && e.recordingRecords==1 && !e.lastAuthLine && !e.lastRecording)
        print("7 clock cases and preset counting/exclusions passed")
        if let path=CommandLine.arguments.dropFirst().first {let actual=DisplayImportEvidence.parse(try String(contentsOfFile:path,encoding:.utf8));print("complete lists: \(actual.records), recording: \(actual.recordingRecords), authentication: \(actual.authLineRecords)")}
    }
}
