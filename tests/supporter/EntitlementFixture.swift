@main enum EntitlementFixture {
    static func main() {
        typealias Rule = SupporterEntitlement
        func check(_ sku: SupporterSKU, _ expected: Rule, end: Double? = nil,
                   revoked: Bool = false, upgraded: Bool = false) {
            precondition(Rule.evaluate(sku, revoked: revoked, upgraded: upgraded,
                                       expiration: end, now: 100) == expected)
        }
        check(.yearly, .current, end: 101)
        check(.yearly, .expired, end: 100)
        check(.yearly, .expired, end: 99)
        check(.yearly, .invalid)
        check(.yearly, .upgraded, end: 101, upgraded: true)
        check(.yearly, .revoked, end: 101, revoked: true)
        check(.lifetime, .current)
        check(.lifetime, .revoked, revoked: true)
        check(.lifetime, .invalid, end: 101)
        precondition(SupporterSKU(rawValue: "unrelated.product") == nil)
        print("Supporter entitlement rules passed")
    }
}
