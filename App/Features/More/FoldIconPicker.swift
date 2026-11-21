import SwiftUI

/// Launchable alternate app icons, not third-party Home Screen icon packs.
struct FoldIconPicker: View {
    @State private var active: String? = UIApplication.shared.alternateIconName
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Section {
            if UIApplication.shared.supportsAlternateIcons {
                ForEach(["Default", "Millennium", "Pinstripe"], id: \.self) { label in
                    let target: String? = label == "Default" ? nil : "Fold" + label
                    Button { set(target) } label: {
                        HStack { Text(label); Spacer(); if active == target { Image(systemName: "checkmark").accessibilityLabel("Selected") } }
                    }.disabled(busy || active == target)
                }
            } else { Text("Alternate icons aren’t available in this installation.").foregroundStyle(.secondary) }
            if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
        } header: { Text("Assay app icon") } footer: { Text("Changes only Assay’s icon. Default follows your Home Screen appearance.") }.rowCard()
        .onAppear { active = UIApplication.shared.alternateIconName }
    }
    private func set(_ name: String?) {
        guard !busy, UIApplication.shared.supportsAlternateIcons else { return }; busy = true; message = nil
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async { busy = false; active = UIApplication.shared.alternateIconName; if error != nil { message = "iOS didn’t change the icon. Your previous choice is still in use if shown above." } }
        }
    }
}
