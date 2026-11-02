import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct BallFormTests {
    let store: BowlingStore
    let us = Locale(identifier: "en_US")

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    /// A ball with every `BallFields` value set.
    private func fullDetail() throws -> BallDetail {
        let day = Calendar.current.startOfDay(for: .now).addingTimeInterval(-86_400 * 30)
        return try store.balls.addBall(BallFields(
            name: "Phaze II", brand: "Storm", weightPounds: 15, coverstock: .reactiveSolid,
            coverstockName: "TX-16", coreType: .asymmetric, coreName: "Velocity",
            rg: 2.48, differential: 0.051, intermediateDifferential: 0.015, intendedRole: .strike,
            serialNumber: "SN123", colorDescription: "Pine/Silver", releaseDate: day, purchaseDate: day,
            factoryFinish: "1500 Polished", surfaceGrit: "2000 Abralon", resurfaceIntervalGames: 60,
            notes: "Benchmark"
        ))
    }

    private func form(_ name: String = "Phaze", weight: Int? = 15) -> BallForm {
        var form = BallForm(locale: us)
        form.name = name
        form.weightPounds = weight
        return form
    }

    @Test func cantSaveWithoutANameOrWeight() {
        var draft = BallForm(locale: us)
        #expect(!draft.canSave)
        draft.name = "Phaze"
        #expect(!draft.canSave)
        draft = form("", weight: 15)
        #expect(!draft.canSave)
        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "Phaze"
        #expect(draft.canSave)
        draft.rg = "abc"
        #expect(!draft.canSave)
    }

    @Test func editRoundTripsEveryField() throws {
        let detail = try fullDetail()
        let form = BallForm(editing: detail.id, detail: detail, locale: us)
        #expect(form.editing == detail.id)
        #expect(form.fields() == detail.fields)
    }

    @Test func blankNumbersAreNil() throws {
        var draft = form()
        draft.rg = ""
        draft.resurfaceInterval = " "
        let fields = try #require(draft.fields())
        #expect(fields.rg == nil)
        #expect(fields.resurfaceIntervalGames == nil)
    }

    @Test func badNumbersHaveMessages() {
        var draft = form()
        draft.rg = "abc"
        #expect(draft.fieldError(.rg) == "Enter a number")
        draft.resurfaceInterval = "0"
        #expect(draft.fieldError(.resurfaceInterval) == "Enter a whole number of at least 1")
        draft.resurfaceInterval = "2.5"
        #expect(draft.fieldError(.resurfaceInterval) == "Enter a whole number of at least 1")
        draft.resurfaceInterval = "60"
        #expect(draft.fieldError(.resurfaceInterval) == nil)
        #expect(draft.fieldError(.differential) == nil)
        #expect(draft.fields() == nil)
    }

    @Test func parsesTheLocaleDecimalSeparator() throws {
        let spain = Locale(identifier: "es_ES")
        var draft = BallForm(locale: spain)
        draft.name = "Phaze"
        draft.weightPounds = 15
        draft.rg = "2,52"
        #expect(draft.fields()?.rg == 2.52)
        let detail = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, rg: 2.52))
        #expect(BallForm(editing: detail.id, detail: detail, locale: spain).rg == "2,52")
    }

    @Test func intermediateDifferentialNeedsAsymmetric() {
        var draft = form()
        draft.intermediateDifferential = "0.015"
        draft.coreType = .symmetric
        #expect(draft.fields()?.intermediateDifferential == nil)
        draft.coreType = .asymmetric
        #expect(draft.fields()?.intermediateDifferential == 0.015)
    }

    @Test func hiddenIntermediateDifferentialDoesntBlockSave() {
        var draft = form()
        draft.coreType = .asymmetric
        draft.intermediateDifferential = "abc"
        #expect(!draft.canSave)
        draft.coreType = .symmetric
        #expect(draft.canSave)
        #expect(draft.fieldError(.intermediateDifferential) == nil)
    }

    @Test func factoryFinishSeedsTheSurfaceOnAdd() throws {
        var draft = form()
        draft.factoryFinish = "1500 Abralon"
        let id = try draft.save(to: store)
        #expect(try store.balls.detail(for: id).fields.surfaceGrit == "1500 Abralon")
    }

    @Test func editChangesOnlyThatField() throws {
        let before = try fullDetail()
        var draft = BallForm(editing: before.id, detail: before, locale: us)
        draft.name = "Phaze III"
        _ = try draft.save(to: store)
        var expected = before.fields
        expected.name = "Phaze III"
        #expect(try store.balls.detail(for: before.id).fields == expected)
    }

    @Test func blankedNumberClearsOnEdit() throws {
        let before = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, rg: 2.5))
        var draft = BallForm(editing: before.id, detail: before, locale: us)
        draft.rg = ""
        _ = try draft.save(to: store)
        #expect(try store.balls.detail(for: before.id).fields.rg == nil)
    }

    @Test func unknownRoleIsKept() throws {
        let before = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, intendedRole: .spare))
        var draft = BallForm(editing: before.id, detail: before, locale: us)
        draft.intendedRole = .unknown
        _ = try draft.save(to: store)
        #expect(try store.balls.detail(for: before.id).fields.intendedRole == .spare)
    }

    @Test func editKeepsRetired() throws {
        let ball = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15))
        try store.balls.setRetired(true, for: ball.id)
        let detail = try store.balls.detail(for: ball.id)
        var draft = BallForm(editing: ball.id, detail: detail, locale: us)
        #expect(draft.isRetired)
        draft.brand = "Storm"
        _ = try draft.save(to: store)
        #expect(try store.balls.detail(for: ball.id).isRetired)
    }

    @Test func photoChangesApply() throws {
        let photo = Data([0xFF, 0xD8, 0xFF, 0x01])
        var draft = form()
        draft.photo = .set(photo)
        let id = try draft.save(to: store)
        #expect(try store.balls.photo(for: id) == photo)

        var edit = BallForm(editing: id, detail: try store.balls.detail(for: id), locale: us)
        #expect(edit.photo == .unchanged)
        _ = try edit.save(to: store)
        #expect(try store.balls.photo(for: id) == photo)

        edit.photo = .removed
        _ = try edit.save(to: store)
        #expect(try store.balls.photo(for: id) == nil)
    }

    @Test func photoFailureKeepsTheBall() {
        var draft = form()
        draft.photo = .set(Data(count: BallRepository.maxPhotoBytes + 1))
        #expect(throws: RepositoryError.invalidBall(.photoTooLarge)) { try draft.save(to: store) }
        #expect(store.balls.activeBalls().map(\.name) == ["Phaze"])
    }

    @Test func noWeightRefusesToSave() {
        #expect(throws: RepositoryError.invalidBall(.weightOutOfRange)) { try form(weight: nil).save(to: store) }
    }

    @Test func savedBallIsInNewSessionsBalls() throws {
        let id = try form().save(to: store)
        #expect(Available.current(in: store).balls.contains(id))
    }
}
