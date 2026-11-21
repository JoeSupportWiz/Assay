import SwiftUI
import LocalAuthentication

/// Controls access to the UI only. Never stores a passcode, and never overrides iOS authentication.
@MainActor final class AssayPrivacyLock: ObservableObject {
    static let shared = AssayPrivacyLock()
    static let key = "assay.privacyLock.enabled.v1"
    @Published private(set) var enabled: Bool
    @Published private(set) var unlocked: Bool
    @Published private(set) var busy = false
    @Published private(set) var note = ""
    private var generation = UUID()
    private var context: LAContext?
    private init() { let v=UserDefaults.standard.bool(forKey:Self.key); enabled=v; unlocked = !v }
    func background() { generation=UUID(); context?.invalidate(); context=nil; busy=false; unlocked = !enabled; note="" }
    enum Operation {case enable, disable, unlock}
    func authenticate(_ op:Operation) async {
        guard !busy else{return}
        let ctx=LAContext(); var err:NSError?; ctx.localizedCancelTitle="Cancel"
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication,error:&err) else {note="Device authentication is unavailable. Set up a device passcode in Settings and try again.";return}
        let ticket=UUID();generation=ticket;context=ctx;busy=true;note=""
        defer { if generation==ticket {busy=false;context=nil} }
        do { let reason:String = switch op {case .enable:"Turn on Assay’s privacy lock";case .disable:"Turn off Assay’s privacy lock";case .unlock:"Unlock Assay"}
            let ok=try await ctx.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:reason)
            guard ok,generation==ticket else{return}
            switch op {case .enable: enabled=true; unlocked=true; case .disable: enabled=false;unlocked=true; case .unlock: unlocked=true}
            UserDefaults.standard.set(enabled,forKey:Self.key)
        } catch {if generation==ticket {note="Not authenticated. No lock setting changed."} }
    }
}

struct AssayPrivacyGate<Content:View>:View {
    @ObservedObject private var lock = AssayPrivacyLock.shared
    @Environment(\.scenePhase) private var phase
    @ViewBuilder let content: ()->Content
    var body:some View {
        Group {
            if !lock.enabled || (lock.unlocked && phase == .active) { content() }
            else { VStack(spacing:18){Image(systemName:"lock.fill").font(.largeTitle);Text("Assay is locked").font(.title2.bold());if phase == .active {Button("Unlock Assay"){Task {await lock.authenticate(.unlock)}}.buttonStyle(.borderedProminent).disabled(lock.busy);if !lock.note.isEmpty {Text(lock.note).font(.footnote)}}}.padding().frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(uiColor:.systemBackground)).accessibilityElement(children:.contain) }
        }.onChange(of:phase){_,v in if v == .background {lock.background()} }
    }
}
struct AssayPrivacyLockSettings:View {
    @ObservedObject private var lock=AssayPrivacyLock.shared
    var body:some View {List {Section {LabeledContent("Assay lock",value:lock.enabled ? "On":"Off");Button(lock.enabled ? "Turn off lock":"Turn on lock"){Task {await lock.authenticate(lock.enabled ? .disable:.enable)}}.disabled(lock.busy);if !lock.note.isEmpty {Text(lock.note)}} footer:{Text("Uses Face ID, Touch ID or your device passcode. Assay locks when backgrounded or relaunched. This protects this app’s interface, not other apps, exported files, widget data or stored-file encryption. You will need working device authentication to turn this off.")}.rowCard()}.themedList().navigationTitle("Privacy lock").navigationBarTitleDisplayMode(.inline)}
}
