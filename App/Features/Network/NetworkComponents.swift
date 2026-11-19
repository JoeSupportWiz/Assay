import SwiftUI
import UIKit

// MARK: - Shared pieces

/// Line through the successful samples, drawn with Path. Lost samples are marked with a short tick at the baseline.
struct NetSparkline: View {
    @Environment(\.theme) private var t
    let samples: [Double?]
    var expectedCount: Int = 5

    var body: some View {
        Canvas { ctx, size in
            let ok = samples.compactMap { $0 }
            guard !samples.isEmpty else { return }
            let hi = max(ok.max() ?? 1, 1)
            let lo = min(ok.min() ?? 0, hi)
            let span = max(hi - lo, hi * 0.2, 0.5)
            let n = max(expectedCount, samples.count)
            let pad: CGFloat = 6
            func x(_ i: Int) -> CGFloat {
                n <= 1 ? size.width / 2 : pad + (size.width - 2 * pad) * CGFloat(i) / CGFloat(n - 1)
            }
            func y(_ v: Double) -> CGFloat {
                let f = (v - lo) / span
                return size.height - pad - (size.height - 2 * pad - 4) * CGFloat(f) - 2
            }
            var line = Path()
            var started = false
            var dots = Path()
            var ticks = Path()
            for (i, s) in samples.enumerated() {
                if let v = s {
                    let p = CGPoint(x: x(i), y: y(v))
                    if started { line.addLine(to: p) } else { line.move(to: p); started = true }
                    dots.addEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                } else {
                    ticks.move(to: CGPoint(x: x(i), y: size.height - pad))
                    ticks.addLine(to: CGPoint(x: x(i), y: size.height - pad - 10))
                    started = false
                }
            }
            ctx.stroke(line, with: .color(t.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ctx.fill(dots, with: .color(t.accentColor))
            ctx.stroke(ticks, with: .color(Palette.peachDeep), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(height: 56)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let parts = samples.enumerated().map { i, s in
            s.map { "Attempt \(i + 1): \(String(format: "%.1f", $0)) milliseconds" } ?? "Attempt \(i + 1): no reply"
        }
        return parts.joined(separator: ". ")
    }
}

private func netFmt(_ v: Double?) -> String {
    guard let v else { return "Not available" }
    return String(format: "%.1f ms", v)
}

/// Rows for the latency section of one host:port key.
struct NetLatencyRows: View {
    @Environment(\.theme) private var t
    let probes: NetProbeStore
    let key: String

    var body: some View {
        if probes.isRunning(latencyFor: key) {
            HStack(spacing: 10) {
                ProgressView()
                Text("Testing, attempt \(min(probes.live.count + 1, 5)) of 5").foregroundStyle(t.ink2)
            }
            if !probes.live.isEmpty { NetSparkline(samples: probes.live) }
        } else if let r = probes.latency[key] {
            HStack {
                Text("Result").foregroundStyle(t.ink)
                Spacer()
                if r.isDemo { Tag(style: .neutral, text: "Demo") } else { Tag(style: .observed) }
            }
            LabeledContent("Minimum", value: netFmt(r.minMs))
            LabeledContent("Average", value: netFmt(r.avgMs))
            LabeledContent("Maximum", value: netFmt(r.maxMs))
            LabeledContent("Loss") {
                HStack(spacing: 8) {
                    Text("\(r.lost) of \(r.samples.count) · \(r.lossPercent)%")
                    if r.lost > 0 { Tag(style: .caution, text: "Loss") } else { Tag(style: .reversible, text: "None") }
                }
            }
            NetSparkline(samples: r.samples)
            Text("TCP connect time only. It is not an ICMP ping, and a refused connection counts as a loss.")
                .font(.system(size: 12.5)).foregroundStyle(t.ink3)
        } else if let n = probes.notices[key] {
            Label(n, systemImage: "hand.raised").foregroundStyle(t.ink2)
        } else {
            Text("Not tested yet.").foregroundStyle(t.ink3)
        }
    }
}

/// Rows for the certificate section of one host:port key.
struct NetCertRows: View {
    @Environment(\.theme) private var t
    let probes: NetProbeStore
    let key: String

    private static let dateFormat: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    var body: some View {
        if probes.isRunning(certFor: key) {
            HStack(spacing: 10) {
                ProgressView()
                Text("Reading certificate").foregroundStyle(t.ink2)
            }
        } else if let r = probes.cert[key] {
            if let i = r.info { details(i) }
            else { Label(r.error ?? "No certificate was received.", systemImage: "exclamationmark.triangle").foregroundStyle(t.ink2) }
        } else if let n = probes.notices[key] {
            Label(n, systemImage: "hand.raised").foregroundStyle(t.ink2)
        } else {
            Text("Not checked yet.").foregroundStyle(t.ink3)
        }
    }

    @ViewBuilder private func details(_ i: NetCertInfo) -> some View {
        HStack {
            Text("Result").foregroundStyle(t.ink)
            Spacer()
            if i.isDemo { Tag(style: .neutral, text: "Demo") } else { Tag(style: .observed) }
        }
        LabeledContent("Subject", value: i.subject)
        LabeledContent("Issuer", value: i.issuer)
        LabeledContent("Valid from") { Text(i.notBefore.map { $0.formatted(Self.dateFormat) } ?? "Not available") }
        LabeledContent("Valid until") { Text(i.notAfter.map { $0.formatted(Self.dateFormat) } ?? "Not available") }
        LabeledContent("Days left") {
            HStack(spacing: 8) {
                if let d = i.daysLeft() { Text(d >= 0 ? "\(d)" : "Expired \(-d) days ago") } else { Text("Not available") }
                if i.isExpired() { Tag(style: .experimental, text: "Expired") }
                else if i.notYetValid() { Tag(style: .caution, text: "Not yet valid") }
                else { Tag(style: .reversible, text: "In date") }
            }
        }
        LabeledContent("Key") {
            HStack(spacing: 8) {
                Text("\(i.keyType)\(i.keyBits.map { " \($0)-bit" } ?? "")")
                if i.isWeak { Tag(style: .caution, text: "Weak") }
                else if i.isRSA, i.keyBits != nil { Tag(style: .reversible, text: "OK") }
            }
        }
        LabeledContent("Self-signed") { Text(i.selfSigned ? "Yes" : "No") }
        LabeledContent("Trusted by this iPhone") {
            Text(i.trustedByDevice.map { $0 ? "Yes" : "No" } ?? "Not evaluated")
        }
        Text("Assay read the certificate and then cancelled the connection. No page content was fetched and nothing was sent but one HEAD request line.")
            .font(.system(size: 12.5)).foregroundStyle(t.ink3)
    }
}

// MARK: - Scope guard sheet

struct NetScopeSheet: View {
    @Environment(\.theme) private var t
    let scope: NetScope
    @Binding var isPresented: Bool
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Assay only looks at networks you own or are allowed to test.")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(t.ink)
                    bullet("No port scanning.")
                    bullet("No password or credential guessing.")
                    bullet("No exploit attempts.")
                    bullet("It browses Bonjour adverts, times a TCP connect to a device you pick, and reads a TLS certificate. Nothing more.")
                }.rowCard()
                Section {
                    Toggle("I’m allowed to inspect this network", isOn: $confirmed)
                } footer: {
                    Text("iOS does not let apps read the Wi-Fi name, so this choice is remembered once for the app, not per network. You can reset it from the Local network screen.")
                }.rowCard()
            }
            .themedList()
            .navigationTitle("Before you start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { isPresented = false } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    scope.accept()
                    isPresented = false
                } label: { Text("Continue") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!confirmed)
                .padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
            }
        }
        .interactiveDismissDisabled(true)
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "minus").foregroundStyle(t.ink3).padding(.top, 3)
            Text(s).foregroundStyle(t.ink2)
        }
    }
}
