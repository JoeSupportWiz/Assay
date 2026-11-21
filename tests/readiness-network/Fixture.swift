import Foundation

// The fixture builds the real request without a Keychain implementation or a live session.
enum AIKeychain {
    static func read(for kind: AIProviderKind, endpoint: String) -> String? {
        fatalError("Fixture should never read credentials")
    }
}

@main
struct ReadinessNetworkFixture {
    static func main() throws {
        let local = ["10.0.0.1", "172.16.0.1", "172.31.255.255", "192.168.0.1", "169.254.1.2",
                     "fe80::1", "febf::2", "fe80::a%en0", "fe80::a%12", "fc00::1", "FDFF::2", "Printer.Local."]
        let loopback = ["localhost", "LOCALHOST.", "127.0.0.1", "::1", "0:0:0:0:0:0:0:1"]
        let external = ["100.63.255.255", "100.64.0.0", "100.100.1.1", "100.127.255.255", "100.128.0.0",
                        "172.15.255.255", "172.32.0.1", "010.0.0.1", "127.1", "10.0.0.256", "fe7f::1", "fec0::1",
                        "2001:db8::1", "::", "ff02::1", "::ffff:127.0.0.1", "::ffff:c0a8:101", "fdxx::1", "fe80:::1",
                        "fe80::1%", "fe80::1%en0%en1", "fe80::1%0", "fd00::1%en0", "2001:db8::1%host.local",
                        "::1%lo0", "server:80", "example.invalid", "host.localhost", ".localhost", "local", "printer..local",
                        "printer.local.invalid", "-printer.local", "printer.local..", "fe80::1\u{0}abc"]
        for (hosts, label) in [(local, AIPrivacyLabel.staysOnLAN), (loopback, .staysOnPhone), (external, .leavesPhone)] {
            for host in hosts {
                precondition(AIHost.classify(host: host) == label, "AI host: \(host)")
                for verdict in [NetAddressPolicy.check(host), NetAddressPolicy.checkDiscovered(host)] {
                    precondition(verdict.host == (label == .staysOnLAN ? host : nil), "Network host: \(host)")
                }
            }
        }
        precondition(NetAddressPolicy.check(" [fe80::1%en0] ").host == "fe80::1%en0")

        for (authority, expected) in [("localhost", AIPrivacyLabel.staysOnPhone), ("[::1]", .staysOnPhone),
                                      ("[fe80::1%25en0]", .staysOnLAN), ("[fd00::1]", .staysOnLAN),
                                      ("printer.local.", .staysOnLAN), ("100.64.0.1", .leavesPhone),
                                      ("[2001:db8::1%25host.local]", .leavesPhone), ("[::ffff:127.0.0.1]", .leavesPhone),
                                      ("[localhost]", .leavesPhone), ("[fe80::xyz]", .leavesPhone),
                                      ("test.localhost", .leavesPhone), ("test..local", .leavesPhone), ("test%2Elocal", .leavesPhone)] {
            let base = "http://\(authority):8080/v1/"
            precondition(AIPrivacyLabel.forProvider(.custom, baseURL: base) == expected, "Privacy label: \(base)")
            let endpoint = try? AIHost.endpoint(provider: .custom, base: base)
            if expected == .leavesPhone {
                precondition(endpoint == nil, "External HTTP: \(base)")
            } else {
                let request = try AIClient.buildRequest(provider: .custom, baseURL: endpoint!.url, model: "sample", messages: [],
                                                        system: nil, maxTokens: 1, key: nil, timeout: 1)
                precondition(request.url?.absoluteString == base + "chat/completions", "Changed destination: \(base)")
            }
        }
        let externalBase = "https://100.64.0.1/v1"
        let externalEndpoint = try AIHost.endpoint(provider: .custom, base: externalBase)
        precondition(externalEndpoint.label.needsConsent)
        precondition((try? AIHost.endpoint(provider: .minis, base: externalBase)) == nil)
        var settings = AIStoredSettings()
        settings.baseURLs[AIProviderKind.custom.rawValue] = externalBase
        settings.consented = [settings.consentKey(.custom)]
        precondition(settings.hasConsent(.custom, withContext: false) && !settings.hasConsent(.custom, withContext: true))
        settings.baseURLs[AIProviderKind.custom.rawValue] = "https://100.64.0.2/v1"
        precondition(!settings.hasConsent(.custom, withContext: false))
        print("PASS: AI-02 and NET-01 offline address, request and consent-scope fixtures")
    }
}
