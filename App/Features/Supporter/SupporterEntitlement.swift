enum SupporterSKU: String, CaseIterable {
    case yearly = "assay.pro.yearly"
    case lifetime = "assay.pro.lifetime"
}

// Called only after StoreKit verification and the SKU/product-type check.
// Times are seconds since 1970; `now` is explicit so the boundary is testable.
enum SupporterEntitlement: Equatable {
    case current, expired, revoked, upgraded, invalid

    static func evaluate(_ sku: SupporterSKU, revoked: Bool, upgraded: Bool,
                         expiration: Double?, now: Double) -> Self {
        if revoked { return .revoked }
        if upgraded { return .upgraded }
        switch sku {
        case .yearly:
            guard let expiration else { return .invalid }
            return expiration > now ? .current : .expired
        case .lifetime:
            return expiration == nil ? .current : .invalid
        }
    }
}
