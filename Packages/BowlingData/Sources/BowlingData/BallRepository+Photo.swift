import BowlingCore
import Foundation
import SwiftData

// §3.2 BallPhoto: one photo per ball, kept off Ball so syncing a ball never moves the bytes.
extension BallRepository {
    /// Nil when the ball has no photo.
    /// - Throws: `.notFound` for an unknown ball.
    public func photo(for ballID: BallID) throws -> Data? {
        try context.ball(ballID).photo?.imageData
    }

    /// The app downscales `imageData` before calling. Replaces an existing photo in place,
    /// so the ball keeps a single BallPhoto. Empty data removes the photo.
    /// - Throws: `.notFound` for an unknown ball.
    public func setPhoto(_ imageData: Data, for ballID: BallID) throws {
        guard !imageData.isEmpty else { return try removePhoto(for: ballID) }
        try context.write {
            let ball = try context.ball(ballID)
            if let photo = ball.photo {
                photo.imageData = imageData
                photo.updatedAt = .now
            } else {
                let photo = BallPhoto(imageData: imageData)
                context.insert(photo)
                photo.ball = ball
            }
            ball.updatedAt = .now
        }
    }

    /// Does nothing when the ball has no photo.
    /// - Throws: `.notFound` for an unknown ball.
    public func removePhoto(for ballID: BallID) throws {
        try context.write {
            let ball = try context.ball(ballID)
            guard let photo = ball.photo else { return }
            context.delete(photo)
            ball.photo = nil
            ball.updatedAt = .now
        }
    }
}
