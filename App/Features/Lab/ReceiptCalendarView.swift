import SwiftUI

/// Inspired by SwiftPieces' activity-calendar pattern, drawn with native SwiftUI. No library or third-party artwork.
struct ReceiptCalendarView: View {
    let receipts: [Receipt]
    let engine: EngineMode
    @Environment(\.theme) private var t
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selected: Date?
    private let week = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { time in
            let days = ReceiptCalendar.days(receipts.map { .init(date:$0.date, engine:$0.engine.rawValue, preview:$0.dryRun) }, engine:engine.rawValue, now:time.date, calendar:.current)
            let active = days.first { $0.date == selected } ?? days.last(where: { $0.total > 0 }) ?? days.last
            VStack(alignment:.leading,spacing:9) {
                Text(engine == .demo ? "Demo receipts · last 28 days" : "\(engine.title) · last 28 days").font(.headline)
                if let start=days.first, let end=days.last { Text("\(start.date,format:.dateTime.month(.abbreviated).day()) – \(end.date,format:.dateTime.month(.abbreviated).day())").font(.caption).foregroundStyle(t.ink2) }
                if typeSize.isAccessibilitySize {
                    ForEach(days.filter { $0.total > 0 }) { d in Text(summary(d)).font(.body) }
                } else {
                    LazyVGrid(columns:week,spacing:4) {
                        ForEach(days) { d in
                            let foreground = d.total > 0 ? Palette.ink : t.ink2
                            Button { selected=d.date } label: {
                                VStack(spacing:1){Text(d.date,format:.dateTime.day()).font(.caption.monospacedDigit());Text(d.total == 0 ? "–" : String(d.total)).font(.footnote.monospacedDigit().bold())}
                                    .frame(maxWidth:.infinity,minHeight:44).foregroundStyle(foreground)
                                    .background(d.total == 0 ? t.soft : (d.other > 0 ? Palette.mint : Palette.lilac),in:RoundedRectangle(cornerRadius:7))
                                    .overlay { if active?.id == d.id { RoundedRectangle(cornerRadius:7).strokeBorder(foreground,lineWidth:2) } }
                            }.buttonStyle(.plain).accessibilityLabel(summary(d)).accessibilityAddTraits(active?.id == d.id ? [.isSelected] : [])
                        }
                    }
                    if let active { Text(summary(active)).font(.footnote).foregroundStyle(t.ink) }
                }
                if !days.contains(where:{$0.total>0}) { Text("No receipts saved in this period for this engine.").font(.subheadline) }
                Text("Counts include previews and failed attempts, not just verified changes.").font(.caption).foregroundStyle(t.ink2)
            }.padding(.vertical,4)
        }
    }
    private func summary(_ d:ReceiptDay) -> String { "\(d.date.formatted(date:.abbreviated,time:.omitted)): \(d.previews) preview\(d.previews == 1 ? "" : "s"), \(d.other) other receipt\(d.other == 1 ? "" : "s")." }
}
