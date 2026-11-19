import CryptoKit
import Foundation

enum BuildFetchError: String, LocalizedError {
    case auth = "Access denied. Use a fine-grained GitHub token with Actions: Read for JoeSupportWiz/Assay only. Do not use an Apple key."
    case unavailable = "GitHub could not supply this build. It may be expired or unavailable."
    case provenance = "The workflow, repository, revision, or SHA-256 did not match. No IPA was accepted."
    case limit = "This build is outside the supported archive size limit."
    case package = "Expected one Assay iPhone IPA with the known bundle ID. No file was exported."
    var errorDescription: String? { rawValue }
}
private final class BuildNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct SignetVerifiedPayload { let bytes: Data, digest:String, version:String, build:String, parts:Int }
actor SignetBuildClient {
    private let root=URL(string:"https://api.github.com/repos/JoeSupportWiz/Assay/actions/")!
    private func read(_ url:URL, key:String?, max:Int, allowStorageRedirect:Bool=false) async throws -> Data {
        var request=URLRequest(url:url); request.httpMethod="GET"
        if let key { guard url.scheme=="https",url.host=="api.github.com",url.path.hasPrefix(root.path),url.user==nil,url.port==nil else {throw BuildFetchError.provenance}
            request.setValue("Bearer "+key,forHTTPHeaderField:"Authorization");request.setValue("2022-11-28",forHTTPHeaderField:"X-GitHub-Api-Version");request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept")
        } else if !SignetBuildRef.downloadHost(url) {throw BuildFetchError.provenance}
        let cfg=URLSessionConfiguration.ephemeral;cfg.urlCache=nil;cfg.urlCredentialStorage=nil;cfg.httpCookieStorage=nil;cfg.httpShouldSetCookies=false;cfg.timeoutIntervalForRequest=18;cfg.timeoutIntervalForResource=75
        let session=URLSession(configuration:cfg,delegate:BuildNoRedirect(),delegateQueue:nil);defer{session.invalidateAndCancel()}
        do {
            let (stream,response)=try await session.bytes(for:request);guard let http=response as? HTTPURLResponse else{throw BuildFetchError.unavailable}
            if http.statusCode==302,allowStorageRedirect,key != nil,let s=http.value(forHTTPHeaderField:"Location"),let dest=URL(string:s),SignetBuildRef.downloadHost(dest) { return try await read(dest,key:nil,max:max) }
            guard http.statusCode==200 else {throw [401,403,404].contains(http.statusCode) && key != nil ? BuildFetchError.auth : BuildFetchError.unavailable}
            guard response.expectedContentLength <= Int64(max) else {throw BuildFetchError.limit}
            var bytes=Data();if response.expectedContentLength>0{bytes.reserveCapacity(Int(response.expectedContentLength))};for try await b in stream{guard bytes.count<max else{throw BuildFetchError.limit};bytes.append(b)};try Task.checkCancellation();return bytes
        }catch let e as BuildFetchError {throw e} catch {throw BuildFetchError.unavailable}
    }
    func list(_ key:String) async throws->[SignetBuildRef] {
        let u=URL(string:"artifacts?name=Assay-unsigned-ipa&per_page=30",relativeTo:root)!.absoluteURL
        let b=try await read(u,key:key,max:524288);guard let j=(try? JSONSerialization.jsonObject(with:b)) as? [String:Any],let a=j["artifacts"] as? [[String:Any]] else {throw BuildFetchError.unavailable};return a.compactMap(SignetBuildRef.parse).sorted{$0.run>$1.run}
    }
    func fetch(_ build:SignetBuildRef,key:String) async throws->SignetVerifiedPayload {
        let meta=try await read(root.appendingPathComponent("runs/\(build.run)"),key:key,max:524288);guard let body=(try? JSONSerialization.jsonObject(with:meta)) as? [String:Any],build.accepts(run:body) else {throw BuildFetchError.provenance}
        let archive=try await read(root.appendingPathComponent("artifacts/\(build.id)/zip"),key:key,max:12_582_912,allowStorageRedirect:true)
        return try Self.verifyArchive(archive,build:build)
    }
    static func verifyArchive(_ archive:Data,build:SignetBuildRef) throws->SignetVerifiedPayload {
        guard archive.count==build.size, Self.sha(archive)==build.digest else {throw BuildFetchError.provenance}
        let tmp=FileManager.default.temporaryDirectory.appendingPathComponent("assay-artifact-"+UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:tmp,withIntermediateDirectories:false);defer{try? FileManager.default.removeItem(at:tmp)}
        let outer=tmp.appendingPathComponent("artifact.zip"),inner=tmp.appendingPathComponent("output.ipa");try archive.write(to:outer,options:[.atomic,.completeFileProtection]);let z=try SignetZipReader(url:outer),files=z.entries.filter{!$0.isDirectory};guard files.count==1,let entry=files.first,entry.name=="Assay-unsigned.ipa" else{throw BuildFetchError.package};let ipa=try z.extract(entry);try ipa.write(to:inner,options:[.atomic,.completeFileProtection]);let app=try SignetZipReader(url:inner),infos=app.entries.filter{$0.name.hasPrefix("Payload/") && $0.name.hasSuffix(".app/Info.plist") && $0.name.split(separator:"/").count==3};guard infos.count==1,let info=infos.first,let p=(try? PropertyListSerialization.propertyList(from:app.extract(info), options:[],format:nil)) as? [String:Any], p["CFBundleIdentifier"] as? String=="com.joesupportwiz.assay",(p["CFBundleSupportedPlatforms"] as? [String])?.contains("iPhoneOS")==true,let v=p["CFBundleShortVersionString"] as? String,let n=p["CFBundleVersion"] as? String else{throw BuildFetchError.package}
        return SignetVerifiedPayload(bytes:ipa,digest:Self.sha(ipa),version:v,build:n,parts:app.entries.filter{$0.name.hasPrefix("Payload/") && $0.name.hasSuffix(".appex/Info.plist")}.count)
    }
    private static func sha(_ d:Data)->String{SHA256.hash(data:d).map{String(format:"%02x",$0)}.joined()}
}
