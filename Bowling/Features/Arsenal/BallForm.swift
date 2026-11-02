import BowlingCore
import BowlingData
import Foundation

/// The add and edit form's values (spec §7, Arsenal 1b). Only name and weight are required.
/// Numbers are kept as typed and parsed in `locale`, so a bad one shows under its field.
struct BallForm: Hashable {
    enum PhotoChange: Hashable {
        case unchanged, set(Data), removed
    }

    enum NumberField: CaseIterable {
        case rg, differential, intermediateDifferential, resurfaceInterval
    }

    /// `save` was called with a number field that doesn't parse.
    struct InvalidNumber: Error {}

    /// Nil on add.
    var editing: BallID?
    var isRetired = false

    var name = ""
    var brand = ""
    /// Nil until the user picks one; the picker reads "Choose".
    var weightPounds: Int?
    var colorDescription = ""
    var serialNumber = ""
    var coverstock: Coverstock = .unknown
    var coverstockName = ""
    var coreType: CoreType = .unknown
    var coreName = ""
    var rg = ""
    var differential = ""
    /// Saved only for an asymmetric core.
    var intermediateDifferential = ""
    var factoryFinish = ""
    var releaseDate: Date?
    /// `.unknown` keeps the stored role.
    var intendedRole: BallRole = .strike
    var purchaseDate: Date?
    /// On add, blank starts from `factoryFinish`.
    var surfaceGrit = ""
    var resurfaceInterval = ""
    var notes = ""
    var photo: PhotoChange = .unchanged
    var locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    init(editing id: BallID, detail: BallDetail, locale: Locale = .current) {
        self.locale = locale
        let fields = detail.fields
        editing = id
        isRetired = detail.isRetired
        name = fields.name
        brand = fields.brand
        weightPounds = fields.weightPounds
        colorDescription = fields.colorDescription
        serialNumber = fields.serialNumber
        coverstock = fields.coverstock
        coverstockName = fields.coverstockName
        coreType = fields.coreType
        coreName = fields.coreName
        rg = text(fields.rg)
        differential = text(fields.differential)
        intermediateDifferential = text(fields.intermediateDifferential)
        factoryFinish = fields.factoryFinish
        releaseDate = fields.releaseDate
        intendedRole = fields.intendedRole
        purchaseDate = fields.purchaseDate
        surfaceGrit = fields.surfaceGrit
        resurfaceInterval = fields.resurfaceIntervalGames.map { $0.formatted(.number.locale(locale).grouping(.never)) } ?? ""
        notes = fields.notes
    }

    /// A name that isn't blank, a picked weight, and every number field valid.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fields() != nil
    }

    /// The message under a number field, or nil when it's blank or valid.
    func fieldError(_ field: NumberField) -> String? {
        // The field is hidden for other cores, so it never blocks Save there.
        if field == .intermediateDifferential, coreType != .asymmetric { return nil }
        // `try?` would read a blank field's nil as a failure, so catch instead.
        do {
            switch field {
            case .rg, .differential, .intermediateDifferential: _ = try decimal(self[field])
            case .resurfaceInterval: _ = try interval()
            }
            return nil
        } catch {
            return field == .resurfaceInterval
                ? String(localized: "Enter a whole number of at least 1")
                : String(localized: "Enter a number")
        }
    }

    /// Nil with no weight or a bad number field.
    func fields() -> BallFields? {
        guard let weightPounds else { return nil }
        let rg, differential, intermediate: Double?
        let interval: Int?
        do {
            rg = try decimal(self.rg)
            differential = try decimal(self.differential)
            intermediate = coreType == .asymmetric ? try decimal(intermediateDifferential) : nil
            interval = try self.interval()
        } catch {
            return nil
        }
        return BallFields(
            name: name, brand: brand, weightPounds: weightPounds, coverstock: coverstock,
            coverstockName: coverstockName, coreType: coreType, coreName: coreName,
            rg: rg, differential: differential,
            intermediateDifferential: intermediate,
            intendedRole: intendedRole, serialNumber: serialNumber, colorDescription: colorDescription,
            releaseDate: releaseDate, purchaseDate: purchaseDate, factoryFinish: factoryFinish,
            surfaceGrit: surfaceGrit, resurfaceIntervalGames: interval, notes: notes
        )
    }

    /// Adds or updates the ball, then applies `photo`. A photo error propagates after the ball
    /// is saved, so the ball stays.
    /// - Throws: `.invalidBall(.weightOutOfRange)` with no weight, `InvalidNumber` for a bad
    ///   number field, else what the repository throws.
    func save(to store: BowlingStore) throws -> BallID {
        guard weightPounds != nil else { throw RepositoryError.invalidBall(.weightOutOfRange) }
        guard let fields = fields() else { throw InvalidNumber() }
        let id = if let editing {
            try store.balls.updateBall(editing, with: fields).id
        } else {
            try store.balls.addBall(fields).id
        }
        switch photo {
        case .unchanged: break
        case .set(let data): try store.balls.setPhoto(data, for: id)
        case .removed: try store.balls.removePhoto(for: id)
        }
        return id
    }

    private subscript(field: NumberField) -> String {
        switch field {
        case .rg: rg
        case .differential: differential
        case .intermediateDifferential: intermediateDifferential
        case .resurfaceInterval: resurfaceInterval
        }
    }

    private struct ParseFailure: Error {}

    /// Nil for blank text; throws for text that isn't a number in `locale`.
    private func decimal(_ text: String) throws -> Double? {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return try Double(text, format: .number.locale(locale))
    }

    /// Nil for blank text; throws unless it's a whole number of at least 1.
    private func interval() throws -> Int? {
        guard let value = try decimal(resurfaceInterval) else { return nil }
        guard value >= 1, value.rounded() == value, value <= Double(Int.max) else { throw ParseFailure() }
        return Int(value)
    }

    private func text(_ value: Double?) -> String {
        value.map { $0.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...6))) } ?? ""
    }
}
