import Foundation
import AppIntents

struct AssayCheckSummaryIntent:AppIntent {
    static var title:LocalizedStringResource="Get Assay device summary"
    static var description=IntentDescription("Return the public local OS version, thermal state and Low Power Mode. No identifiers, account, network, or device writes.")
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let pi=ProcessInfo.processInfo, os=pi.operatingSystemVersion
        let state:String = switch pi.thermalState {case .nominal:"nominal";case .fair:"fair";case .serious:"serious";case .critical:"critical";@unknown default:"unknown"}
        return .result(value:"iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion); thermal: \(state); Low Power Mode: \(pi.isLowPowerModeEnabled ? "on":"off"). Sampled \(Date().ISO8601Format()). No system preferences inspected.")
    }
}
struct AssayShortcutProvider:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:OpenWorkbenchIntent(),phrases:["Open my workbench in \(.applicationName)"],shortTitle:"Open workbench",systemImageName:"square.2.layers.3d")
        AppShortcut(intent:AssayCheckSummaryIntent(),phrases:["Get my device summary with \(.applicationName)"],shortTitle:"Device summary",systemImageName:"stethoscope")
    }
}
