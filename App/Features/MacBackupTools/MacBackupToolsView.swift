import SwiftUI

/// Same helper as the one distributed with this build. Share only when the owner taps.
struct MacBackupToolsView: View {
    var body: some View {
        List {
            Section {
                if let zip=Bundle.main.url(forResource:"Assay-USB-Backup-Mac",withExtension:"zip") {
                    ShareLink(item:zip){Label("Send Mac helper…",systemImage:"square.and.arrow.up")}
                } else { Text("The helper is missing from this build.") }
            } header: { Text("1. Send to your Mac") } footer: { Text("AirDrop the ZIP to your own Mac or choose Save to Files. This contains only the launcher, two scripts and instructions. Sending it does not start a backup.") }.rowCard()
            Section("2. Prepare the Mac") { Text("Unzip it. The helper requires Python 3 and libimobiledevice on the Mac. The README lists prerequisites. Connect your iPhone by USB and approve Trust if prompted.") }.rowCard()
            Section("3. Make the request") { NavigationLink { USBBackupHandoffView() } label: { Label("Open USB backup handoff",systemImage:"externaldrive") };Text("On the Mac, open Assay USB Backup.command from the extracted folder. Choose the request and confirm the backup there. The backup stays on the Mac; send only the result JSON back to Assay.") }.rowCard()
        }.themedList().navigationTitle("Mac helper").navigationBarTitleDisplayMode(.inline)
    }
}
