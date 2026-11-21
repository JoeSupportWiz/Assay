import Foundation
import CryptoKit

/// A team API key authenticates to Apple. It is not an app-signing key. Nothing here persists it.
extension Data { fileprivate var teamB64: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") } }
struct TeamCredential {
    let issuer: UUID, kid: String, key: P256.Signing.PrivateKey
    init(issuer: String, keyID: String, pem: String) throws {
        guard let id=UUID(uuidString:issuer),keyID.range(of:"^[A-Z0-9]{10}$",options:.regularExpression) != nil else {throw TeamError.invalidKey}
        guard let p=try? P256.Signing.PrivateKey(pemRepresentation:pem) else {throw TeamError.invalidKey}
        self.issuer=id; kid=keyID;key=p
    }
    func token(at now: Date = Date()) throws -> String {
        let ts=Int(now.timeIntervalSince1970)
        let head=try JSONSerialization.data(withJSONObject:["alg":"ES256","kid":kid,"typ":"JWT"],options:.sortedKeys).teamB64
        let body=try JSONSerialization.data(withJSONObject:["iss":issuer.uuidString.lowercased(),"iat":ts,"exp":ts+300,"aud":"appstoreconnect-v1"],options:.sortedKeys).teamB64
        let msg=head+"."+body;return msg+"."+(try key.signature(for:Data(msg.utf8))).rawRepresentation.teamB64
    }
    static func load(url: URL, issuer: String, keyID: String) throws -> Self {
        guard url.isFileURL,url.pathExtension.lowercased()=="p8" else {throw TeamError.invalidKey}
        let scoped=url.startAccessingSecurityScopedResource(); defer {if scoped {url.stopAccessingSecurityScopedResource()}}
        let file=try FileHandle(forReadingFrom:url); defer {try? file.close()};guard let d=try file.read(upToCount:16_385),!d.isEmpty,d.count<=16_384,let pem=String(data:d,encoding:.utf8) else {throw TeamError.invalidKey}
        return try Self(issuer:issuer,keyID:keyID,pem:pem)
    }
}
enum TeamError: Error, LocalizedError {
    case invalidKey, response(Int), tooLarge, invalidSelection, noFile, unavailable
    var errorDescription: String? { switch self {
    case .invalidKey: return "Use a team issuer UUID, a 10-character Key ID and its matching .p8 App Store Connect key. Never choose a signing .p12 here."
    case .response(401):return "Apple rejected the key. Check the issuer, Key ID and device time."
    case .response(403):return "Apple did not authorise this operation. Check the team key’s role and access to Certificates, Identifiers & Profiles."
    case .response(409):return "Apple rejected this combination or the profile name is already in use. Review it in the developer portal."
    case .response(429):return "Apple rate-limited this request. Wait before trying again."
    case .response(let n):return "Apple returned HTTP \(n). No success was verified."
    case .tooLarge:return "The response exceeds Assay’s local size limit."
    case .invalidSelection:return "Choose a registered iOS app ID, an unexpired development certificate and an enabled iOS device from this team."
    case .noFile:return "Apple processed the request but Assay could not verify a downloadable profile. Check the portal before creating another."
    case .unavailable:return "Could not complete the request. Check your connection. If this was a creation request, check Apple’s portal before retrying."
    } }
}
struct TeamItem: Identifiable, Hashable {
    let id: String, title: String
    var expires: Date? = nil
}
struct TeamInventory { let bundles, certs, devices: [TeamItem]; let limited: Bool }
struct TeamGrant {
    let name: String, bundle: TeamItem, cert: TeamItem, device: TeamItem
    func body(in inventory: TeamInventory, now:Date = Date()) throws -> Data {
        let trimmed=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard (1...80).contains(trimmed.count),!trimmed.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains),inventory.bundles.contains(bundle),inventory.certs.contains(cert),inventory.devices.contains(device),let exp=cert.expires,exp>now else {throw TeamError.invalidSelection}
        func ref(_ t:String,_ v:TeamItem)->[String:String]{["type":t,"id":v.id]}
        let rel:[String:Any]=["bundleId":["data":ref("bundleIds",bundle)],"certificates":["data":[ref("certificates",cert)]],"devices":["data":[ref("devices",device)]]]
        return try JSONSerialization.data(withJSONObject:["data":["type":"profiles","attributes":["name":trimmed,"profileType":"IOS_APP_DEVELOPMENT"],"relationships":rel]],options:.sortedKeys)
    }
}
private final class NoAppleRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void){ completionHandler(nil) }
}
struct TeamPortal {
    let cred: TeamCredential
    private func fetch(_ route:String,query:[URLQueryItem]=[],body:Data?=nil) async throws -> [String:Any] {
        guard ["bundleIds","devices","certificates","profiles"].contains(route) else {throw TeamError.invalidSelection}
        var c=URLComponents();c.scheme="https";c.host="api.appstoreconnect.apple.com";c.path="/v1/"+route;c.queryItems=query.isEmpty ? nil:query
        guard let url=c.url else {throw TeamError.unavailable}; var req=URLRequest(url:url);req.httpMethod=body == nil ? "GET":"POST";req.httpBody=body;req.setValue("Bearer "+(try cred.token()),forHTTPHeaderField:"Authorization");req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let cfg=URLSessionConfiguration.ephemeral;cfg.urlCache=nil;cfg.httpCookieStorage=nil;cfg.urlCredentialStorage=nil;cfg.timeoutIntervalForRequest=15;cfg.timeoutIntervalForResource=30
        let session=URLSession(configuration:cfg,delegate:NoAppleRedirect(),delegateQueue:nil);defer {session.invalidateAndCancel()}
        do { let (stream,resp)=try await session.bytes(for:req);guard let http=resp as? HTTPURLResponse,(200...299).contains(http.statusCode) else {throw TeamError.response((resp as? HTTPURLResponse)?.statusCode ?? 0)}
            var data=Data();for try await b in stream { guard data.count < 2_100_000 else {throw TeamError.tooLarge};data.append(b) }
            guard let obj=try JSONSerialization.jsonObject(with:data) as? [String:Any] else {throw TeamError.unavailable};return obj
        } catch let e as TeamError {throw e} catch {throw TeamError.unavailable}
    }
    private func list(_ type:String,_ fields:String) async throws -> ([[String:Any]],Bool) {
        let obj=try await fetch(type,query:[.init(name:"limit",value:"200"),.init(name:"fields[\(type)]",value:fields)])
        guard let rows=obj["data"] as? [[String:Any]] else {throw TeamError.unavailable};return (rows,(obj["links"] as? [String:Any])?["next"] as? String != nil)
    }
    static func validUntil(_ s:String?) -> Date? {guard let s else {return nil};let f=ISO8601DateFormatter();if let d=f.date(from:s){return d};f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f.date(from:s)}
    func inventory() async throws -> TeamInventory {
        let (bs,mb)=try await list("bundleIds","identifier,name,platform"), (cs,mc)=try await list("certificates","name,certificateType,expirationDate"), (ds,md)=try await list("devices","name,platform,status")
        let bundles:[TeamItem]=bs.compactMap{ row in guard let id=row["id"] as? String, let a=row["attributes"] as? [String:Any], let identifier=a["identifier"] as? String, !identifier.contains("*"),["IOS","UNIVERSAL"].contains(a["platform"] as? String ?? "") else{return nil};return TeamItem(id:id,title:identifier)}
        let certs:[TeamItem]=cs.compactMap{ row in guard let id=row["id"] as? String,let a=row["attributes"] as? [String:Any], ["DEVELOPMENT","IOS_DEVELOPMENT"].contains(a["certificateType"] as? String ?? ""), let d=Self.validUntil(a["expirationDate"] as? String),d>Date() else{return nil};return TeamItem(id:id,title:a["name"] as? String ?? "Development certificate",expires:d)}
        let devices:[TeamItem]=ds.compactMap{ row in guard let id=row["id"] as? String,let a=row["attributes"] as? [String:Any],a["platform"] as? String=="IOS",a["status"] as? String=="ENABLED" else{return nil};return TeamItem(id:id,title:a["name"] as? String ?? "Registered iPhone")}
        return TeamInventory(bundles:bundles.sorted{$0.title<$1.title},certs:certs,devices:devices.sorted{$0.title<$1.title},limited:mb||mc||md)
    }
    func create(_ grant:TeamGrant, in inventory:TeamInventory) async throws -> Data {
        let obj=try await fetch("profiles",body:grant.body(in:inventory))
        guard let row=obj["data"] as? [String:Any],row["type"] as? String=="profiles",let a=row["attributes"] as? [String:Any],a["profileType"] as? String=="IOS_APP_DEVELOPMENT",let string=a["profileContent"] as? String,let d=Data(base64Encoded:string),!d.isEmpty,d.count<=1_500_000 else{throw TeamError.noFile}
        return d
    }
}
