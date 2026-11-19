import AppIntents
import Foundation

struct OpenWorkbenchIntent:AppIntent {
    static var title: LocalizedStringResource = "Open Assay"
    static var description = IntentDescription("Open the workbench. No device settings are changed.")
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}
