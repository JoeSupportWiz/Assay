import Foundation

/// Only these projections cross the export boundary; never encode an app model, fact or receipt directly.
struct MinisReport: Encodable, Sendable {
    struct FactSummary: Encodable, Sendable {
        let name, value, evidence: String
    }
    struct FindingSummary: Encodable, Sendable {
        let id, severity, evidence: String
    }
    struct ReceiptSummary: Encodable, Sendable {
        let number: Int
        let kind, outcome: String
        let when: Date
        let itemCount: Int
        let engine: String
    }

    private let schema = "assay.minis.report.v1"
    let capturedAt: Date
    let engine, source: String
    let checkAt: Date?
    let facts: [FactSummary]
    let findings: [FindingSummary]
    let receipts: [ReceiptSummary]
    let limits: [String]
    var importedLogSummary: MinisTransport? = nil

    private enum CaptureError: LocalizedError {
        case sourceChanged
        var errorDescription: String? { "The diagnostic source changed. Capture a new report." }
    }

    @MainActor static func capture(from model: AppModel, includeReceipts: Bool) async throws -> MinisReport {
        let engine = model.engine
        let mode = engine.mode
        let snapshot = await engine.snapshot()
        guard model.engine.mode == mode, snapshot.isDemo == (mode == .demo) else { throw CaptureError.sourceChanged }
        let checked = await engine.standardCheck(snapshot: snapshot)
        try Task.checkCancellation()
        guard model.engine.mode == mode else { throw CaptureError.sourceChanged }

        // ReceiptStore inserts newest first. Filter *before* limiting; don't read history unless requested.
        let receipts: [ReceiptSummary] = includeReceipts
            ? model.receipts.receipts.lazy.filter { $0.engine == mode }.prefix(20).map(summarizeReceipt) : []
        var limits = ["Only allowlisted diagnostic fields are included."]
        if mode == .demo { limits.append("Demo data is simulated, not measured on a device.") }
        if mode == .mac { limits.append("This engine samples the local iPhone, not a connected Mac.") }
        limits.append(includeReceipts ? "At most 20 receipt summaries from this engine are included." : "Receipt history was not included.")
        return MinisReport(capturedAt: Date(), engine: mode.rawValue, source: snapshot.isDemo ? "demo" : "device",
                           checkAt: snapshot.takenAt, facts: snapshot.facts.compactMap(summarizeFact).sorted { $0.name < $1.name },
                           findings: checked.compactMap(summarizeFinding).sorted { $0.id < $1.id }, receipts: receipts, limits: limits)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    private static func evidenceLabel(_ evidence: Evidence) -> String {
        switch evidence { case .observed: "observed"; case .inferred: "inferred"; case .unknown: "unknown" }
    }

    private static func summarizeFact(_ fact: Fact) -> FactSummary? {
        let value = fact.value
        switch fact.label {
        case "Battery", "Battery health":
            if value != "Not reported" {
                guard (2...4).contains(value.utf8.count), value.last == "%", let n = Int(value.dropLast()),
                      (0...100).contains(n), value == "\(n)%" else { return nil }
            }
        case "Low Power Mode": guard ["On", "Off"].contains(value) else { return nil }
        case "Thermal state": guard ["Nominal", "Fair", "Serious", "Critical", "Unknown"].contains(value) else { return nil }
        case "Status bar override": guard ["Present", "None"].contains(value) else { return nil }
        case "iOS":
            // Numeric release only: no build suffix, beta label, locale text or identifier.
            guard value.utf8.count <= 8 else { return nil }
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            guard (1...3).contains(parts.count), parts.allSatisfy({ part in
                guard let n = Int(part) else { return false }; return (0...99).contains(n) && part == String(n)
            }), parts.first != "0" else { return nil }
        default: return nil
        }
        return FactSummary(name: fact.label, value: value, evidence: evidenceLabel(fact.evidence))
    }

    private static func summarizeFinding(_ finding: Finding) -> FindingSummary? {
        switch finding.id {
        case "thermal", "lowpower", "prefs-unreadable", "clock-941", "green-line", "touch-dots",
             "no-logo", "never-locks", "paste-noise", "clock-glass": break
        default: return nil
        }
        let severity: String = switch finding.severity { case .info: "info"; case .attention: "attention"; case .problem: "problem" }
        let labels = finding.evidence.map { evidenceLabel($0.evidence) }
        let evidence: String
        if labels.isEmpty || labels.contains("unknown") { evidence = "unknown" }
        else if finding.confidence != nil || labels.contains("inferred") { evidence = "inferred" }
        else { evidence = "observed" }
        return FindingSummary(id: finding.id, severity: severity, evidence: evidence)
    }

    private static func summarizeReceipt(_ receipt: Receipt) -> ReceiptSummary {
        let outcome: String = switch receipt.status {
        case .complete: "complete"; case .partial: "partial"; case .failed: "failed"
        case .simulated: "simulated"; case .rolledBack: "rolled_back"
        }
        return ReceiptSummary(number: receipt.id, kind: receipt.kind.rawValue, outcome: outcome, when: receipt.date,
                              itemCount: receipt.items.count, engine: receipt.engine.rawValue)
    }
}
