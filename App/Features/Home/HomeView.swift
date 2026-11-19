import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        let snap = model.snapshot
        ZStack {
            ThemedBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Wordmark()
                        Spacer()
                        IconCircle(systemName: "bell", badge: true) {
                            model.show(Toast(kind: .info, title: "No new alerts", subtitle: "Expiry and backup reminders appear here.", symbol: "bell"))
                        }
                    }.padding(.top, 6).rise(0)

                    TwoToneTitle(line1: greeting, line2: "what are we making?").padding(.top, 22).rise(1)

                    DeviceChip(snapshot: snap).padding(.top, 14).rise(2)

                    SearchPill { model.showSearch = true }.padding(.top, 16).rise(3)

                    HStack(spacing: 12) {
                        HealthCard(snapshot: snap) { model.selectedTab = .lab }
                        BackupCard(snapshot: snap)
                    }
                    .frame(height: 176).padding(.top, 18).rise(4)

                    SectionHeader(title: "Studio", trailing: "See all") { model.selectedTab = .studio }.rise(5)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(StudioModule.allCases.enumerated()), id: \.element) { i, m in
                                NavigationLink(value: m) { ModuleTile(module: m, index: i) }.buttonStyle(PressStyle())
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 10)
                    }
                    .padding(.horizontal, -20).padding(.top, -10).rise(6)

                    SectionHeader(title: "Needs you").rise(7)
                    NeedsYouList().rise(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 128)
            }
            .refreshable { await model.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: StudioModule.self) { $0.destination }
    }

    private var greeting: String {
        let name = model.userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Hey there," : "Hey \(name),"
    }
}

// MARK: - Pieces

struct DeviceChip: View {
    @Environment(\.theme) private var t
    let snapshot: DeviceSnapshot?
    var body: some View {
        HStack(spacing: 8) {
            if let s = snapshot {
                if s.connected { LiveDot() } else { Circle().fill(t.ink3).frame(width: 8, height: 8) }
                Text("\(s.name) · iOS \(s.osVersion)").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(t.ink)
                if s.isDemo { Tag(style: .demo) }
                else if !s.connected { Text("Not connected").font(.system(size: 12.5, weight: .medium)).foregroundStyle(t.ink2) }
            } else {
                ProgressView().controlSize(.mini)
                Text("Reading device…").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(t.ink2)
            }
        }
        .padding(.horizontal, 14).frame(height: 36)
        .card(radius: 18)
    }
}

struct SearchPill: View {
    @Environment(\.theme) private var t
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .medium))
                Text("Search tweaks, profiles, assets…").font(.system(size: 15)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                    .frame(width: 38, height: 38).background(t.soft, in: Circle())
            }
            .foregroundStyle(t.ink2)
            .padding(.leading, 18).padding(.trailing, 7).frame(height: 52)
            .card(radius: 26)
        }.buttonStyle(PressStyle()).accessibilityLabel("Search Assay")
    }
}

struct HealthCard: View {
    @Environment(\.theme) private var t
    let snapshot: DeviceSnapshot?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Device\nhealth").font(Typo.display(19, .semibold, t)).foregroundStyle(t.heroInk).multilineTextAlignment(.leading)
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot?.healthScore.map(String.init) ?? "—").font(Typo.display(44, .bold, t)).monospacedDigit().foregroundStyle(t.heroInk)
                        Text(snapshot?.healthScore == nil ? "Run a check" : "All passed").font(.system(size: 12)).lineLimit(1).foregroundStyle(t.heroInk.opacity(0.65))
                    }
                    Spacer()
                    Ring(progress: Double(snapshot?.healthScore ?? 0) / 100, lineWidth: 7, tint: Palette.mint).frame(width: 52, height: 52)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    Rectangle().fill(t.hero)
                    Circle().fill(Palette.mint.opacity(0.28)).frame(width: 140).blur(radius: 30).offset(x: 40, y: -40)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: t.cardRadius, style: .continuous))
        }.buttonStyle(PressStyle())
    }
}

struct BackupCard: View {
    @Environment(\.theme) private var t
    let snapshot: DeviceSnapshot?
    var body: some View {
        let phase = snapshot?.backup?.phase
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Full\nbackup").font(Typo.display(19, .semibold, t))
                Spacer()
                if case .running = phase { Tag(style: .live) }
            }
            Spacer()
            switch phase {
            case .running(let p):
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(p * 100))").font(Typo.display(44, .bold, t)).monospacedDigit()
                    Text("%").font(Typo.display(22, .bold, t))
                }
                ProgressBar(progress: p, tint: t.accentInk, track: t.accentInk.opacity(0.12)).padding(.top, 8)
            default:
                Text("No backup yet").font(Typo.display(19, .bold, t))
                Text("Vault keeps a baseline before any change").font(.system(size: 12)).opacity(0.7).padding(.top, 2)
            }
        }
        .foregroundStyle(t.accentInk)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(t.accent)
        .shimmer()
        .clipShape(RoundedRectangle(cornerRadius: t.cardRadius, style: .continuous))
    }
}

struct ModuleTile: View {
    @Environment(\.theme) private var t
    let module: StudioModule
    let index: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlyphTile(symbol: module.symbol, hue: module.hue).floating(index)
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(module.title).font(.system(size: 18, weight: .bold)).foregroundStyle(t.ink)
                    Text(module.subtitle).font(.system(size: 13)).foregroundStyle(t.ink2)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(t.onPrimary)
                    .frame(width: 36, height: 36).background(t.primary, in: Circle())
            }
        }
        .padding(16)
        .frame(width: 156, height: 178)
        .card(radius: t.cardRadius - 4, fill: AnyShapeStyle(t.tile(module.hue)))
    }
}

struct NeedsYouList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    var body: some View {
        VStack(spacing: 0) {
            if model.snapshot?.isDemo == true {
                Row(icon: "seal", hue: .peach, title: "Dev certificate", subtitle: "Expires in 4 days") {
                    PillButton(title: "Renew", kind: .compact) { model.selectedTab = .studio }
                }
                Divider().padding(.leading, 68)
                Row(icon: "clock.badge.exclamationmark", hue: .butter, title: "Clock stuck at 09:41", subtitle: "Likely a status-bar override") {
                    PillButton(title: "Review", kind: .compact) { model.selectedTab = .lab }
                }
            } else {
                Row(icon: "stethoscope", hue: .mint, title: "Run your first device check", subtitle: "Takes a few seconds and changes nothing") {
                    PillButton(title: "Start", kind: .compact) { model.selectedTab = .lab }
                }
                Divider().padding(.leading, 68)
                Row(icon: model.engineMode?.symbol ?? "bolt", hue: .sky, title: "Finish engine setup", subtitle: "Needed before Assay can change anything") {
                    PillButton(title: "Set up", kind: .compact) { model.selectedTab = .more }
                }
            }
        }
        .card()
    }
}

// MARK: - Search

struct SearchSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [SearchItem] { SearchItem.index.filter { query.isEmpty || $0.matches(query) } }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(t.ink2)
                            TextField("Tweaks, findings, targets, actions…", text: $query).focused($focused).submitLabel(.search)
                        }
                        .padding(.horizontal, 18).frame(height: 52).card(radius: 26)
                        VStack(spacing: 0) {
                            ForEach(results) { item in
                                Button {
                                    dismiss()
                                    model.selectedTab = item.tab
                                } label: {
                                    Row(icon: item.symbol, hue: item.hue, title: item.title, subtitle: item.subtitle) {
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink3)
                                    }
                                }.buttonStyle(.plain)
                            }
                            if results.isEmpty {
                                Text("Nothing matches “\(query)”. Try describing the problem in Lab › Diagnose.")
                                    .font(.system(size: 14)).foregroundStyle(t.ink2).padding(20)
                            }
                        }.card()
                    }.padding(20)
                }
            }
            .navigationTitle("Search").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(40)
    }
}

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String, subtitle: String, symbol: String, hue: ModuleHue, tab: AppTab, keywords: String
    func matches(_ q: String) -> Bool { (title + " " + subtitle + " " + keywords).localizedCaseInsensitiveContains(q) }
    static let index: [SearchItem] = [
        .init(title: "Device check", subtitle: "Lab · diagnose and fix", symbol: "stethoscope", hue: .mint, tab: .lab, keywords: "health diagnose clock status bar green"),
        .init(title: "Scenes", subtitle: "Wallpaper, layout and widgets", symbol: "square.2.layers.3d", hue: .lilac, tab: .scenes, keywords: "home screen layout focus"),
        .init(title: "Gild", subtitle: "Studio · tweak catalogue", symbol: "slider.horizontal.3", hue: .lilac, tab: .studio, keywords: "tweaks customise"),
        .init(title: "Canvas", subtitle: "Studio · wallpapers and .tendies", symbol: "photo.artframe", hue: .sky, tab: .studio, keywords: "poster wallpaper tendies"),
        .init(title: "Signet", subtitle: "Studio · signing", symbol: "seal", hue: .butter, tab: .studio, keywords: "certificate profile ipa"),
        .init(title: "Vault", subtitle: "Lab · backups and history", symbol: "tray.full", hue: .butter, tab: .lab, keywords: "backup restore undo"),
        .init(title: "Bluetooth scanner", subtitle: "Lab · tools", symbol: "dot.radiowaves.left.and.right", hue: .sky, tab: .lab, keywords: "ble gatt"),
        .init(title: "Appearance", subtitle: "More · themes", symbol: "paintpalette", hue: .peach, tab: .more, keywords: "theme dark light millennium pinstripe"),
        .init(title: "Engine", subtitle: "More · Mac or iPhone", symbol: "cpu", hue: .sky, tab: .more, keywords: "mac usb tunnel loopback"),
    ]
}
