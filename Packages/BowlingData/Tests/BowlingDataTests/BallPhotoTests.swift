import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallPhotoTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }
    let ballID: BallID

    init() throws {
        store = try BowlingStore(inMemory: true)
        ballID = try store.balls.addBall(BallFields(name: "Phaze II", weightPounds: 15)).id
    }

    var photoCount: Int {
        (try? store.context.fetchCount(FetchDescriptor<BallPhoto>())) ?? -1
    }

    @Test func aNewBallHasNoPhoto() throws {
        #expect(try balls.photo(for: ballID) == nil)
        #expect(try !balls.detail(for: ballID).hasPhoto)
    }

    @Test func setPhotoStoresTheBytes() throws {
        try balls.setPhoto(Data([1, 2, 3]), for: ballID)
        #expect(try balls.photo(for: ballID) == Data([1, 2, 3]))
        #expect(try balls.detail(for: ballID).hasPhoto)
        #expect(photoCount == 1)
    }

    @Test func setPhotoAgainReplacesItInPlace() throws {
        try balls.setPhoto(Data([1]), for: ballID)
        let firstID = try store.context.ball(ballID).photo?.id
        try balls.setPhoto(Data([2, 2]), for: ballID)
        #expect(try balls.photo(for: ballID) == Data([2, 2]))
        #expect(try store.context.ball(ballID).photo?.id == firstID)
        #expect(photoCount == 1)
    }

    @Test func removePhotoDeletesTheBallPhoto() throws {
        try balls.setPhoto(Data([1]), for: ballID)
        try balls.removePhoto(for: ballID)
        #expect(try balls.photo(for: ballID) == nil)
        #expect(photoCount == 0)
        try balls.removePhoto(for: ballID)
        #expect(photoCount == 0)
    }

    @Test func emptyDataRemovesThePhoto() throws {
        try balls.setPhoto(Data([1]), for: ballID)
        try balls.setPhoto(Data(), for: ballID)
        #expect(try balls.photo(for: ballID) == nil)
        #expect(photoCount == 0)
    }

    @Test func eachBallKeepsItsOwnPhoto() throws {
        let otherID = try balls.addBall(BallFields(name: "Spare", weightPounds: 14)).id
        try balls.setPhoto(Data([1]), for: ballID)
        try balls.setPhoto(Data([9]), for: otherID)
        try balls.removePhoto(for: otherID)
        #expect(try balls.photo(for: ballID) == Data([1]))
        #expect(photoCount == 1)
    }

    @Test func aPhotoAtTheLimitIsStored() throws {
        let data = Data(count: BallRepository.maxPhotoBytes)
        try balls.setPhoto(data, for: ballID)
        #expect(try balls.photo(for: ballID)?.count == BallRepository.maxPhotoBytes)
    }

    @Test func aPhotoOverTheLimitIsRefusedAndKeepsTheOldOne() throws {
        try balls.setPhoto(Data([1]), for: ballID)
        #expect(throws: RepositoryError.invalidBall(.photoTooLarge)) {
            try balls.setPhoto(Data(count: BallRepository.maxPhotoBytes + 1), for: ballID)
        }
        #expect(try balls.photo(for: ballID) == Data([1]))
        #expect(photoCount == 1)
    }

    @Test func unknownBallIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try balls.photo(for: BallID()) }
        #expect(throws: RepositoryError.notFound) { try balls.setPhoto(Data([1]), for: BallID()) }
        #expect(throws: RepositoryError.notFound) { try balls.removePhoto(for: BallID()) }
        #expect(photoCount == 0)
    }
}
