import ActivityKit
import Foundation

@MainActor final class VaultStatusActivity {
    static let shared=VaultStatusActivity()
    private var activity: Activity<AssayVaultActivity>?
    private var owner:UUID?
    private var sequence=0
    func start(id:UUID,restoring:Bool,enabled:Bool){
        guard enabled,ActivityAuthorizationInfo().areActivitiesEnabled else{return};owner=id;sequence=0
        // Do not resurrect stale activities or report fake transfer progress.
        let state=AssayVaultActivity.ContentState(phase:restoring ? "Checking saved file":"Preparing checkpoint",reported:Date(),finished:false)
        activity=try? Activity.request(attributes:AssayVaultActivity(restoring:restoring),content:.init(state:state,staleDate:Date().addingTimeInterval(45)),pushType:nil)
    }
    func update(id:UUID,stage:String){
        guard id==owner,let a=activity else{return};sequence+=1;let n=sequence
        // Publish only known progress categories, never names or paths.
        let labels=[("Reading file", "Reading selected files"),("Verifying source", "Checking source"),("Verifying stored", "Verifying stored copy"),("Saving checkpoint", "Saving checkpoint"),("Checking saved", "Checking saved file"),("Writing restored", "Writing a separate copy"),("Checking restored", "Verifying exported bytes")]
        guard let label=labels.first(where:{stage.hasPrefix($0.0)})?.1 else{return}
        Task{guard owner==id,sequence==n else{return};let now=Date();await a.update(.init(state:.init(phase:label,reported:now,finished:false),staleDate:now.addingTimeInterval(45)))}
    }
    func end(id:UUID,verified:Bool){guard owner==id,let a=activity else{return};activity=nil;owner=nil;let now=Date();Task{await a.end(.init(state:.init(phase:verified ? "Verified and finished":"Stopped — open Assay for details",reported:now,finished:true),staleDate:nil),dismissalPolicy:.after(now.addingTimeInterval(15)))}}
}
