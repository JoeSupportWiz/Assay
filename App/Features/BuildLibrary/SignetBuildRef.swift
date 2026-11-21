import Foundation

/// Fail closed when the hosted artifact has no digest or does not belong to Assay.
struct SignetBuildRef: Identifiable, Equatable {
    static let repo = "JoeSupportWiz/Assay", repoID = 1463612021
    static let allowedBranches = ["main", "integration/studio-lab-review"]
    let id: Int, run: Int, sha: String, branch: String, digest: String, size: Int
    static func parse(_ j: [String: Any]) -> Self? {
        guard j["name"] as? String == "Assay-unsigned-ipa", j["expired"] as? Bool == false,
              let id = j["id"] as? Int, id > 0, let size = j["size_in_bytes"] as? Int, (1...12_582_912).contains(size),
              let d = j["digest"] as? String, d.hasPrefix("sha256:"), hex(String(d.dropFirst(7)), 64),
              let r = j["workflow_run"] as? [String:Any], r["repository_id"] as? Int == repoID, r["head_repository_id"] as? Int == repoID,
              let run = r["id"] as? Int, run > 0, let sha = r["head_sha"] as? String, hex(sha, 40),
              let branch = r["head_branch"] as? String, allowedBranches.contains(branch) else { return nil }
        return .init(id:id,run:run,sha:sha,branch:branch,digest:String(d.dropFirst(7)),size:size)
    }
    func accepts(run r:[String:Any]) -> Bool {
        (r["repository"] as? [String:Any])?["id"] as? Int == Self.repoID && (r["head_repository"] as? [String:Any])?["id"] as? Int == Self.repoID && r["id"] as? Int == run && r["event"] as? String == "workflow_dispatch" && r["status"] as? String == "completed" && r["conclusion"] as? String == "success" && r["path"] as? String == ".github/workflows/ios.yml" && r["head_sha"] as? String == sha && r["head_branch"] as? String == branch
    }
    private static func hex(_ text:String,_ n:Int)->Bool { text.utf8.count == n && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    static func downloadHost(_ url:URL) -> Bool {
        guard let c=URLComponents(url:url,resolvingAgainstBaseURL:false), c.scheme == "https", c.user == nil, c.password == nil, c.port == nil || c.port == 443, let h = c.host?.lowercased() else { return false }
        return h == "objects.githubusercontent.com" || h == "release-assets.githubusercontent.com" || h.hasSuffix(".blob.core.windows.net") || h.hasSuffix(".actions.githubusercontent.com")
    }
}
