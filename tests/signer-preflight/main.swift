import Foundation

// No keys, profiles, device identifiers, clock dependencies or network access.
typealias Rules = SignerPreflightRules
var count = 0
func check(_ value: Bool, _ line: UInt = #line) {
    precondition(value, "Failed at line \(line)"); count += 1
}
let selected = Data(repeating: 7, count: 32), other = Data(repeating: 9, count: 32)
check(Rules.membership(selected, in: [other, selected]) == .yes)
check(Rules.membership(selected, in: [nil, selected]) == .yes)
check(Rules.membership(selected, in: [other]) == .no)
check(Rules.membership(selected, in: []) == .no)
check(Rules.membership(selected, in: [nil, other]) == .unknown)
check(Rules.membership(nil, in: [selected]) == .unknown)
check(Rules.membership(selected, in: nil) == .unknown)
let now = Date(timeIntervalSince1970: 500)
check(Rules.expiry(nil, asOf: now) == .unknown)
check(Rules.expiry(now, asOf: now) == .no)
check(Rules.expiry(now.addingTimeInterval(-1), asOf: now) == .no)
check(Rules.expiry(now.addingTimeInterval(1), asOf: now) == .yes)
func pattern(_ id: String) -> String? { Rules.pattern(id, prefixes: ["OTHER", "OLDPREFIX"]) }
check(pattern("OLDPREFIX.com.a") == "com.a")
check(pattern("TEAM.com.a") == nil)
check(pattern("OLDPREFIX.com.example.*") == "com.example.*")
check(pattern("OLDPREFIX.*") == "*")
for value in ["*.bad", "com..app", "com*", "com.*.app", "com.**", ""] {
    check(pattern("OLDPREFIX." + value) == nil)
}
check(Rules.target("com.a", allowedBy: "com.a") == .yes)
check(Rules.target("com.A", allowedBy: "com.a") == .no)
check(Rules.target("com.a.beta", allowedBy: "com.a") == .no)
check(Rules.target("com.a.beta.ext", allowedBy: "com.a.*") == .yes)
check(Rules.target("com.ab.beta", allowedBy: "com.a.*") == .no)
check(Rules.target("com.a", allowedBy: "com.a.*") == .no)
check(Rules.target("com.a", allowedBy: "*") == .yes)
check(Rules.target("com.a", allowedBy: nil) == .unknown)
check(Rules.target(nil, allowedBy: "*") == .unknown)
for id in ["com.a*", ".bad", "bad.", "a..b", "a/b", "a b", "café", "", String(repeating: "a", count: 256)] {
    check(Rules.target(id, allowedBy: "*") == .unknown)
}

// Tiny, intentionally unauthenticated BER-shaped fixtures exercise payload extraction.
func tlv(_ tag: UInt8, _ bytes: [UInt8]) -> [UInt8] { [tag, UInt8(bytes.count)] + bytes }
func indefinite(_ tag: UInt8, _ bytes: [UInt8]) -> [UInt8] { [tag, 128] + bytes + [0, 0] }
func cms(_ octets: [UInt8]) -> Data {
    let oid: [UInt8] = [42,134,72,134,247,13,1,7]
    let encap = tlv(48, tlv(6, oid + [1]) + tlv(160, octets))
    let fields = tlv(2, [1]) + tlv(49, []) + encap + tlv(49, [])
    return Data(indefinite(48, tlv(6, oid + [2]) + indefinite(160, tlv(48, fields))))
}
let payload = Data("plist here".utf8)
check(try SignerPreflightEnvelope.payload(cms(tlv(4, Array(payload)))) == payload)
let chunks = indefinite(36, tlv(4, Array(payload.prefix(3))) + tlv(4, Array(payload.dropFirst(3))))
check(try SignerPreflightEnvelope.payload(cms(chunks)) == payload)
check((try? SignerPreflightEnvelope.payload(payload)) == nil)
check((try? SignerPreflightEnvelope.payload(Data(cms(chunks).dropLast()))) == nil)
check((try? SignerPreflightEnvelope.payload(cms(chunks) + Data([0]))) == nil)
let dates = tlv(23, Array("500101000000Z".utf8)) + tlv(24, Array("20510101000000Z".utf8))
let metadata = tlv(2, [1]) + tlv(48, []) + tlv(48, []) + tlv(48, dates)
let period = try SignerPreflightEnvelope.certificateDates(Data(tlv(48, tlv(48, metadata))))
check(period.0 == Date(timeIntervalSince1970: -631152000))
check(period.1 == Date(timeIntervalSince1970: 2556144000))
print("\(count) preflight checks passed")
