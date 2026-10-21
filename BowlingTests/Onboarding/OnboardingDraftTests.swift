import BowlingCore
import BowlingData
import Testing
@testable import Bowling

@Suite struct OnboardingDraftTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test func profileNeedsANameAndAHand() {
        var d = OnboardingDraft()
        #expect(!d.canLeaveProfile)
        d.handedness = .left
        for blank in ["", "   ", "\n\t"] {
            d.name = blank
            #expect(!d.canLeaveProfile)
        }
        d.name = " Ana "
        #expect(d.canLeaveProfile)
        d.handedness = nil
        #expect(!d.canLeaveProfile)
    }

    @Test func finishNeedsAStyle() {
        var d = OnboardingDraft(name: "Ana", handedness: .right)
        #expect(!d.canFinish)
        d.style = .league
        #expect(d.canFinish)
    }

    @Test func createsTheOwnerWithTheAnswers() throws {
        let d = OnboardingDraft(name: " Ana ", handedness: .left, style: .competitive)
        let owner = try #require(try d.createOwner(in: store.bowlers))
        #expect(owner.name == "Ana")
        #expect(owner.isOwner)
        #expect(owner.handedness == .left)
        #expect(owner.statsProfile == .competitive)
        #expect(owner.statsScope == nil)   // follows the bowling style
        #expect(store.bowlers.owner()?.id == owner.id)
    }

    @Test func incompleteDraftSavesNothing() throws {
        #expect(try OnboardingDraft(name: "Ana", handedness: .right).createOwner(in: store.bowlers) == nil)
        #expect(try OnboardingDraft(name: "Ana", style: .casual).createOwner(in: store.bowlers) == nil)
        #expect(store.bowlers.owner() == nil)
    }

    @Test func secondCreateAfterSuccessThrowsOwnerExists() throws {
        let d = OnboardingDraft(name: "Ana", handedness: .right, style: .casual)
        _ = try d.createOwner(in: store.bowlers)
        #expect(throws: RepositoryError.ownerAlreadyExists) { try d.createOwner(in: store.bowlers) }
        #expect(store.bowlers.bowlers().count == 1)
    }

    @Test func keepsInnerSpacesAndAnyScript() throws {
        let owner = try OnboardingDraft(name: "  Ana María ", handedness: .right, style: .casual)
            .createOwner(in: store.bowlers)
        #expect(owner?.name == "Ana María")
        #expect(OnboardingDraft(name: "李", handedness: .left).canLeaveProfile)
    }
}
