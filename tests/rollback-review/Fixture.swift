import Foundation

// Only UI and machine selection types are stand-ins; all receipt/plan/store rules are production.
enum TagStyle { case reversible, caution, experimental, unknown, neutral }
enum EngineMode: String, Codable, Hashable { case demo, iphone, mac }

@main enum RollbackReview {
    static func main() {
        let key = PrefKey(domain: "fixture", key: "sample")
        func item(_ before:Int, _ after:Int, _ outcome: Receipt.Outcome = .verified, _ known:Bool=true) -> Receipt.Item {
            .init(change:.init(label:"fixture",target:key,before:.int(before),after:.int(after),tier:.reversible,beforeKnown:known),outcome:outcome)
        }
        func receipt(_ id:Int, _ engine:EngineMode, _ items:[Receipt.Item], dry:Bool=false, kind:OperationPlan.Kind = .tweak) -> Receipt {
            .init(id:id,date:Date(timeIntervalSince1970:Double(id)),title:"fixture",kind:kind,engine:engine,dryRun:dry,items:items)
        }
        let a=receipt(1,.demo,[item(1,2)]), b=receipt(2,.demo,[item(2,3)]), other=receipt(3,.iphone,[item(5,6)])
        let store=ReceiptStore(persist:false,seed:[other,b,a]);precondition(store.undoPlan(for:a,engine:.iphone)==nil && store.undoPlan(for:a,engine:.demo)==nil)
        guard let plan=store.restoreAllPlan(engine:.demo) else{fatalError("valid chain refused")}
        precondition(plan.undoOf==[2,1] && plan.changes.count==1 && plan.changes.first?.before == .int(3) && plan.changes.first?.after == .int(1));precondition(plan.undoEngine == .demo)
        for r in [receipt(10,.iphone,[item(3,1)],kind:.restoreAll),receipt(10,.demo,[item(3,1,.unverified)],kind:.restoreAll),receipt(10,.demo,[item(3,1)],dry:true,kind:.restoreAll),receipt(10,.demo,[],kind:.restoreAll),receipt(10,.demo,[item(3,0)],kind:.restoreAll)] {
            store.acknowledgeUndo(plan,result:r);precondition(!store.receipts.contains(where:{$0.rolledBack}))
        }
        let ok=receipt(10,.demo,[item(3,1)],kind:.restoreAll);store.acknowledgeUndo(plan,result:ok);precondition(Set(store.receipts.filter(\.rolledBack).map(\.id))==[1,2]);precondition(store.restoreAllPlan(engine:.demo)==nil)
        let partial=receipt(9,.demo,[item(2,3),item(8,9,.unverified)]);let uncertain=ReceiptStore(persist:false,seed:[partial,a]);precondition(!partial.undoable && uncertain.restoreAllPlan(engine:.demo)==nil)
        let broken=ReceiptStore(persist:false,seed:[receipt(9,.demo,[item(99,3)]),a]);precondition(broken.restoreAllPlan(engine:.demo)==nil)
        print("PASS: engine isolation, newer edits, verified changes only, connected rollback chain, scoped acknowledgements and partial/dry/mismatched rejection")
    }
}
