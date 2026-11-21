import SwiftUI

// MARK: - Entitlement matrix

struct SignetMatrixView: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection

    private let keyWidth: CGFloat = 220
    private let colWidth: CGFloat = 84

    var body: some View {
        let keys = inspection.matrixKeys
        List {
            Section {
                if keys.isEmpty {
                    Text("No entitlements to compare. None of the profiles list non-standard entitlements.").foregroundStyle(t.ink2)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Text("Entitlement").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink2)
                                    .frame(width: keyWidth, alignment: .leading)
                                ForEach(inspection.targets) { tg in
                                    Text(tg.shortName).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink2)
                                        .lineLimit(1).frame(width: colWidth)
                                }
                            }
                            .padding(.vertical, 6)
                            ForEach(keys, id: \.self) { k in
                                Divider()
                                HStack(spacing: 0) {
                                    Text(k).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(t.ink)
                                        .frame(width: keyWidth, alignment: .leading)
                                    ForEach(inspection.targets) { tg in
                                        let c = inspection.cell(key: k, target: tg)
                                        VStack(spacing: 1) {
                                            Text(c.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                                            Text(c == .present ? "yes" : (c == .missing ? "missing" : "no"))
                                                .font(.system(size: 10)).foregroundStyle(t.ink2)
                                        }
                                        .frame(width: colWidth)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(tg.shortName), \(k): \(c.spoken)")
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } header: {
                HStack(spacing: 8) { Text("Profiles side by side"); if inspection.isDemo { SignetDemoTag() } }
            } footer: {
                Text("✓ in the profile.  – not in the profile and not expected.  ✗ expected for this target but missing from its profile (from the executable XML slot if available; inferred from bundle metadata otherwise). This is a key-presence comparison, not a signing verdict.")
            }
            .rowCard()

            Section("Columns") {
                ForEach(inspection.targets) { tg in
                    HStack {
                        Text(tg.shortName).font(.system(size: 14, weight: .semibold)).foregroundStyle(t.ink)
                        Spacer()
                        Text(tg.bundleID).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Entitlement matrix")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Diff

struct SignetDiffView: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection

    var body: some View {
        List {
            Section {
                Text("− expected for the target but missing from its profile.  + allowed by the profile but not expected.  A blank sign means the key is present on both sides; values may still differ. Each target labels its source.")
                    .font(.system(size: 13)).foregroundStyle(t.ink2)
            }.rowCard()
            ForEach(inspection.targets) { tg in
                let lines = inspection.diff(for: tg)
                Section {
                    if tg.profile == nil {
                        Text("No profile to compare. The allowed set is unknown.").foregroundStyle(t.ink2)
                    }
                    if lines.isEmpty {
                        Text("Nothing to compare.").foregroundStyle(t.ink2)
                    }
                    ForEach(lines) { l in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(l.sign).font(.system(size: 14, weight: .bold, design: .monospaced)).frame(width: 14)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(l.key).font(.system(size: 12.5, design: .monospaced))
                                if !l.note.isEmpty { Text(l.note).font(.system(size: 11.5, design: .monospaced)).opacity(0.8) }
                            }
                            Spacer(minLength: 0)
                            Text(l.kind == .missing ? "missing" : (l.kind == .extra ? "extra" : "key present")).font(.system(size: 11)).opacity(0.8)
                        }
                        .foregroundStyle(colour(l.kind))
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    HStack(spacing: 8) { Text(tg.shortName); Tag(style: tg.binary.state == .xml ? .observed : .inferred(nil)); Text(tg.bundleID).font(.system(size: 11, design: .monospaced)); if tg.isDemo { SignetDemoTag() } }
                }
                .rowCard()
            }
        }
        .themedList()
        .navigationTitle("Requested vs allowed")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colour(_ k: SignetDiffLine.Kind) -> Color {
        let dark = t.isDark
        switch k {
        case .missing: return dark ? Color(hex: 0xFF8A80) : Color(hex: 0xA3261C)
        case .extra: return dark ? Color(hex: 0x7BE8B5) : Color(hex: 0x0D5C37)
        case .same: return t.ink2
        }
    }
}

// MARK: - Expiry

struct SignetExpiryView: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection
    let icsURL: URL?

    var body: some View {
        let usage = inspection.profileUsage.sorted {
            ($0.profile.expirationDate ?? .distantFuture) < ($1.profile.expirationDate ?? .distantFuture)
        }
        List {
            Section {
                if usage.isEmpty {
                    Text("No provisioning profiles found. An unsigned build has none to expire.").foregroundStyle(t.ink2)
                }
                ForEach(Array(usage.enumerated()), id: \.offset) { _, u in
                    let days = u.profile.daysLeft()
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(u.profile.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                            if u.profile.isDemo { SignetDemoTag() }
                        }
                        HStack(spacing: 8) {
                            SignetExpiryTag(days: days)
                            Text(signetDaysText(days)).font(.system(size: 14)).foregroundStyle(t.ink)
                            Spacer(minLength: 0)
                            Text(u.profile.expirationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not available")
                                .font(.system(size: 13)).foregroundStyle(t.ink2)
                        }
                        Text(u.targets.map { $0.bundleID }.joined(separator: "\n"))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                    }
                    .padding(.vertical, 3)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Profiles by expiry")
            } footer: {
                Text("Days are counted from now to the profile's ExpirationDate.")
            }.rowCard()

            Section {
                if let url = icsURL, !usage.isEmpty {
                    ShareLink(item: url) { Label("Share expiry calendar (.ics)", systemImage: "square.and.arrow.up") }
                } else {
                    Text(usage.isEmpty ? "Nothing to export." : "Calendar file not available.").foregroundStyle(t.ink2)
                }
            } footer: {
                Text("One event per profile at its expiry time, with reminders 14 days, 3 days and at expiry. Import it into any calendar app. Nothing is added automatically.")
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Profile expiry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Receipt

struct SignetReceiptView: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection

    var body: some View {
        let text = SignetReceipt.text(for: inspection)
        List {
            Section {
                Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink).textSelection(.enabled)
            } header: {
                HStack(spacing: 8) { Text("Preview"); if inspection.isDemo { SignetDemoTag() } }
            } footer: {
                Text("Contains the app ID, version, targets, profile names, expiry and the SHA-256 of the file. Device lists show a count only. No certificates, UDIDs or keys are included.")
            }.rowCard()
            Section {
                ShareLink(item: text, subject: Text("Signet build receipt")) {
                    Label("Share receipt", systemImage: "square.and.arrow.up")
                }
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Build receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
}
