#if os(Linux)
import Foundation
// Linux lacks Files-provider security scopes. Used only by the in-memory test.
extension URL {
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() { }
}
#endif
import Foundation
@main enum Check {
    static func main() throws {
        let lines = """
        ⏱ protective backup: 10s elapsed — streamed=2 kept=2 dropped=0 progress=1% — host callbacks idle 7s, 11 DL message(s) this run
        ⏱ protective backup: 40s elapsed — streamed=3 kept=3 dropped=0 progress=9% — host callbacks idle 30s, 12 DL message(s) this run
        protective backup attempt 1/3 dropped the channel (ConnectionReset)
        Restore confirmed complete: device verdict 0, last progress 100%, 3 files served
        fake device name=PRIVATE; api_key=DO-NOT-EXPORT
        ⏱ unrelated: progress=80% — host callbacks idle 9999s
        """
        let r = MinisTransport.summarise(lines)
        precondition(r.heartbeatSamples == 2 && r.maxHostIdleSeconds == 30 && r.lastReportedPercent == 9)
        precondition(r.explicitResetLines == 1 && r.completionLines == 1)
        let j=JSONEncoder(); j.keyEncodingStrategy = .convertToSnakeCase
        let data=try j.encode(r); let text=String(decoding:data,as:UTF8.self)
        precondition(!text.contains("PRIVATE") && !text.contains("DO-NOT-EXPORT"))
        let none = MinisTransport.summarise("Ordinary text")
        precondition(none.heartbeatSamples == 0 && none.maxHostIdleSeconds == nil && none.lastReportedPercent == nil)
        print("Swift transport checks passed: two sampled heartbeats, reset/completion counters, noisy line exclusion, absent values unknown; no source text exported.")
    }
}
