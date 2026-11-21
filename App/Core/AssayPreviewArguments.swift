import Foundation

/// Simulator captures may set a route or seed sample data. Production launches never read these switches.
enum AssayPreviewArguments {
    static var values: [String] {
        #if DEBUG
        return ProcessInfo.processInfo.arguments
        #else
        return []
        #endif
    }
}
