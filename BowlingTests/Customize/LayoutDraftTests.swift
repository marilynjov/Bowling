import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct LayoutDraftTests {
    private func makeOwner() throws -> (BowlingStore, BowlerRecord) {
        let store = try BowlingStore(inMemory: true)
        let owner = try store.bowlers.createOwner(name: "Marilyn", handedness: .right, statsProfile: .league)
        return (store, owner)
    }

    @Test func startsFromTheDisplayedLayout() throws {
        let (_, owner) = try makeOwner()
        let draft = LayoutDraft(destination: .stats, owner: owner)
        #expect(draft.cards == StatsPreset.statsCards(for: .league))
        #expect(!draft.isCustomized)
    }

    @Test func startsFromASavedLayout() throws {
        let (store, _) = try makeOwner()
        try store.bowlers.setStatsLayout([.fouls, .average])
        let owner = try #require(store.bowlers.owner())
        let draft = LayoutDraft(destination: .stats, owner: owner)
        #expect(draft.cards == [.fouls, .average])
        #expect(draft.isCustomized)
    }

    @Test func homeOffersOnlyTileCards() {
        for card in [StatsCardID.trendChart, .leavesTable, .leftMostMadeLeast, .byFrameStrike, .byFrameAverage, .whatIfSinglePins] {
            #expect(!LayoutDraft.offers(card, for: .home), "\(card)")
            #expect(LayoutDraft.offers(card, for: .stats), "\(card)")
        }
    }

    @Test func catalogIsEverythingElseByGroup() throws {
        let (_, owner) = try makeOwner()
        let draft = LayoutDraft(destination: .home, owner: owner)
        let tiles = StatsCardID.allCases.filter { LayoutDraft.offers($0, for: .home) }
        #expect(tiles.count == 13)
        #expect(draft.cards.count == 5)
        let expected = tiles.filter { !draft.cards.contains($0) }
        #expect(draft.catalog.flatMap(\.cards) == expected)
        #expect(draft.catalog.allSatisfy { !$0.cards.isEmpty })
        #expect(draft.catalog.allSatisfy { g in g.cards.allSatisfy { $0.group == g.group } })
    }

    @Test func addAppendsOnce() throws {
        let (_, owner) = try makeOwner()
        var draft = LayoutDraft(destination: .home, owner: owner)
        draft.add(.fouls)
        draft.add(.fouls)
        #expect(draft.cards.filter { $0 == .fouls }.count == 1)
        #expect(draft.cards.last == .fouls)
        #expect(!draft.catalog.flatMap(\.cards).contains(.fouls))
    }

    @Test func addIgnoresANonTileCardOnHome() throws {
        let (_, owner) = try makeOwner()
        var draft = LayoutDraft(destination: .home, owner: owner)
        let before = draft.cards
        draft.add(.trendChart)
        #expect(draft.cards == before)
    }

    @Test func removeAndMove() throws {
        let (store, _) = try makeOwner()
        try store.bowlers.setStatsLayout([.average, .fouls, .trendChart])
        var draft = LayoutDraft(destination: .stats, owner: try #require(store.bowlers.owner()))
        draft.remove(atOffsets: [0])
        #expect(draft.cards == [.fouls, .trendChart])
        draft.add(.average)
        draft.move(fromOffsets: [0], toOffset: 3)
        #expect(draft.cards == [.trendChart, .average, .fouls])
    }

    @Test func anEmptyLayoutCannotBeSaved() throws {
        let (_, owner) = try makeOwner()
        var draft = LayoutDraft(destination: .stats, owner: owner)
        #expect(draft.canSave)
        draft.remove(atOffsets: IndexSet(draft.cards.indices))
        #expect(!draft.canSave)
    }

    @Test func homeDraftDropsANonTileCard() throws {
        let (_, owner) = try makeOwner()
        var record = owner
        record.homeLayout = ["average", "trendChart", "fromTheFuture"]
        let draft = LayoutDraft(destination: .home, owner: record)
        #expect(draft.cards == [.average])
        #expect(StatsPreset.layoutToSave(draft.cards, replacing: record.homeLayout).contains("fromTheFuture"))
    }
}
