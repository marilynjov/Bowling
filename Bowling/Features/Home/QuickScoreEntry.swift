/// The Quick score field's text as a score Save can take.
enum QuickScoreEntry {
    /// 1 to 3 ASCII digits worth 0 through 300; anything else (spaces, signs, other
    /// numerals, "0300") is nil, which keeps Save disabled.
    static func score(_ text: String) -> Int? {
        guard (1...3).contains(text.count), text.allSatisfy({ ("0"..."9").contains($0) }),
              let score = Int(text), score <= 300 else { return nil }
        return score
    }
}
