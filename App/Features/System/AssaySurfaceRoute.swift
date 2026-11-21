import Foundation
/// The public URL scheme can only navigate, never apply a change or read a file.
enum AssaySurfaceRoute:String, CaseIterable {
    case clock,vault,scenes
    init?(url:URL){
        guard let c=URLComponents(url:url,resolvingAgainstBaseURL:false),c.scheme=="assay",c.host=="open",c.port==nil,c.user==nil,c.password==nil,c.fragment==nil,c.query==nil else {return nil}
        guard let r=Self.allCases.first(where:{"/"+$0.rawValue==c.percentEncodedPath}) else{return nil};self=r
    }
}
