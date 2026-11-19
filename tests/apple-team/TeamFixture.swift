import Foundation
import CryptoKit
@main enum PortalFixture {
    static func main() throws {
        // Ephemeral synthetic key; never read a user's account or contact Apple.
        let key=P256.Signing.PrivateKey(), d=Date(timeIntervalSince1970:1800000000)
        let c=try TeamCredential(issuer:"3198D457-699C-4C30-B630-9786F46F8219",keyID:"ABCDE12345",pem:key.pemRepresentation)
        let b64:(Substring)->Data = {part in var s=String(part).replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/");s+=String(repeating:"=",count:(4-s.count%4)%4);return Data(base64Encoded:s)!}
        let parts=try c.token(at:d).split(separator:".");precondition(parts.count==3)
        let sig=try P256.Signing.ECDSASignature(rawRepresentation:b64(parts[2]));precondition(key.publicKey.isValidSignature(sig,for:Data((parts[0]+"."+parts[1]).utf8)))
        let h=(try JSONSerialization.jsonObject(with:b64(parts[0]))) as! [String:Any]; let claims=(try JSONSerialization.jsonObject(with:b64(parts[1]))) as! [String:Any]
        precondition(h["alg"] as? String=="ES256" && h["kid"] as? String=="ABCDE12345");precondition(claims["aud"] as? String=="appstoreconnect-v1" && claims["exp"] as? Int==1800000300)
        let bundle=TeamItem(id:"B",title:"com.example.fixture"),cert=TeamItem(id:"C",title:"Synthetic certificate",expires:d.addingTimeInterval(300)),device=TeamItem(id:"D",title:"Synthetic device")
        let inv=TeamInventory(bundles:[bundle],certs:[cert],devices:[device],limited:false), g=TeamGrant(name:" Test ",bundle:bundle,cert:cert,device:device)
        let obj=try JSONSerialization.jsonObject(with:g.body(in:inv,now:d)) as! [String:Any];let row=obj["data"] as! [String:Any], attrs=row["attributes"] as! [String:String], rel=row["relationships"] as! [String:Any]
        precondition(row["type"] as? String=="profiles" && attrs==["name":"Test","profileType":"IOS_APP_DEVELOPMENT"] && Set(rel.keys)==["certificates","devices","bundleId"])
        precondition((try? g.body(in:inv,now:d.addingTimeInterval(301)))==nil);precondition((try? g.body(in:.init(bundles:[],certs:[cert],devices:[device],limited:false),now:d))==nil)
        precondition((try? TeamCredential(issuer:"invalid",keyID:"ABCDE12345",pem:key.pemRepresentation))==nil)
        print("PASS: verified JWT signature, algorithm, key ID, audience, TTL, official relationship structure, team membership and expired-certificate rejection. Zero requests to Apple.")
    }
}
