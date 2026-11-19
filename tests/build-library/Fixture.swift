import Foundation
import CryptoKit

@main enum BuildFixture {
    static func main() throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1]); let ok=try Data(contentsOf:root.appendingPathComponent("ok.zip"));let sha=String(repeating:"a",count:40)
        func reference(_ b:Data, meta:[String:Any]=[:]) -> SignetBuildRef? {
            var j:[String:Any]=["id":4,"name":"Assay-unsigned-ipa","expired":false,"size_in_bytes":b.count,"digest":"sha256:"+SHA256.hash(data:b).map{String(format:"%02x",$0)}.joined(),"workflow_run":["id":2,"repository_id":SignetBuildRef.repoID,"head_repository_id":SignetBuildRef.repoID,"head_sha":sha,"head_branch":"integration/studio-lab-review"] as [String:Any]];j.merge(meta){_,b in b};return SignetBuildRef.parse(j)
        }
        guard let ref=reference(ok) else{fatalError("fixture rejected")};precondition(reference(ok,meta:["expired":true])==nil && reference(ok,meta:["digest":"sha256:"])==nil && reference(ok,meta:["size_in_bytes":12_582_913])==nil)
        let repo=["id":SignetBuildRef.repoID]; var run:[String:Any]=["id":2,"repository":repo,"head_repository":repo,"head_branch":ref.branch,"head_sha":sha,"event":"workflow_dispatch","status":"completed","conclusion":"success","path":".github/workflows/ios.yml"];precondition(ref.accepts(run:run));for (key,val) in [("head_repository",["id":3] as Any),("head_sha","old"),("path","another.yml"),("conclusion","failure"),("head_branch","release")]{var other=run;other[key]=val;precondition(!ref.accepts(run:other))};run["id"]=3;precondition(!ref.accepts(run:run))
        for (s,good) in [("https://container.blob.core.windows.net/build",true),("https://x.actions.githubusercontent.com/build",true),("http://container.blob.core.windows.net/build",false),("https://objects.githubusercontent.com.spoof.test/a",false),("https://name:key@objects.githubusercontent.com/a",false),("https://objects.githubusercontent.com:8080/a",false)] {precondition(SignetBuildRef.downloadHost(URL(string:s)!)==good)}
        let payload=try SignetBuildClient.verifyArchive(ok,build:ref);precondition(payload.version=="0.3.0" && payload.build=="6" && payload.parts==1 && payload.digest.count==64)
        var altered=ok;altered[0]^=1;precondition((try? SignetBuildClient.verifyArchive(altered,build:ref))==nil)
        for name in ["wrong","sim","extra"] {let b=try Data(contentsOf:root.appendingPathComponent(name+".zip"));let r=reference(b)!;precondition((try? SignetBuildClient.verifyArchive(b,build:r))==nil)}
        print("PASS: workflow commit/repository checks, redirect policy, SHA-256/size, expected device bundle, widget count and three archive rejections")
    }
}
