import StoreKit
import SwiftUI

@MainActor struct SupporterView: View {
    @ObservedObject private var store = AssaySupporterStore.shared
    @State private var manage = false
    var body: some View {
        List {
            Section { Label(store.isSupporter ? "Assay supporter" : "Support Assay", systemImage:store.isSupporter ? "star.circle.fill" : "star")
                if store.hasLifetime { Text("Lifetime support · verified") }
                else if let end = store.annualUntil { Text("Annual support through \(end.formatted(date:.abbreviated,time:.omitted))") }
                if store.verificationIssue { Text("One or more transactions could not be verified and did not grant status.") }
            } footer: { Text("Optional support. All device, signing and creative features are available without a purchase.") }.rowCard()
            Section { ForEach(store.products,id:\.id) { p in
                Button { Task { await store.purchase(p) } } label: { VStack(alignment:.leading,spacing:3){Text(p.displayName);Text(p.id == SupporterSKU.yearly.rawValue ? "\(p.displayPrice) per year · auto-renewing" : "\(p.displayPrice) · one-time purchase").font(.footnote).foregroundStyle(.secondary)} }.disabled(store.busy || store.hasLifetime || (p.id == SupporterSKU.yearly.rawValue && store.hasAnnual))
            }; if store.loadingProducts { ProgressView("Loading products…") }; if let note = store.catalogueNotice { Text(note); Button("Reload options") { Task { await store.loadProducts() } }.disabled(store.busy || store.loadingProducts) }
            } header:{Text("App Store options")} footer:{Text("Apple shows the final price before purchase. An annual subscription renews until cancelled in your App Store account. Lifetime support does not cancel an existing subscription.")}.rowCard()
            Section { Button("Restore purchases"){Task{await store.restore()}}.disabled(store.busy); Button("Manage subscriptions"){manage = true}; if let n=store.notice {Text(n)} }.rowCard()
        }.themedList().navigationTitle("Support Assay").navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented:$manage)
        .task { await store.start(); await store.loadProducts() }
    }
}
