/// A model enum persisted as its raw string.
///
/// Decoding never fails: a raw value this app version does not know, such as a case added
/// by a newer version and delivered through sync, reads as `fallback`. The stored string is
/// left untouched, so the newer value survives until something writes the property.
protocol StoredEnum: RawRepresentable, CaseIterable where RawValue == String {
    static var fallback: Self { get }
}

extension StoredEnum {
    init(stored rawValue: String) {
        self = Self(rawValue: rawValue) ?? .fallback
    }
}
