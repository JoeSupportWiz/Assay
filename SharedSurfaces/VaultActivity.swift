import Foundation
import ActivityKit

// No filenames, device identity, bytes or synthetic percentages go to the Lock Screen.
struct AssayVaultActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable { var phase:String; var reported:Date; var finished: Bool }
    var restoring: Bool
}
