import BowlingCore
import Foundation
import SwiftData

// §3.2 BallPhoto: one photo per ball, kept off Ball so syncing a ball never moves the bytes.
extension BallRepository {
    /// 5 MB. A photo downscaled for the Arsenal and ball detail screens is far smaller;
    /// the limit keeps a missed downscale from syncing a full camera image.
    public nonisolated static let maxPhotoBytes = 5_000_000

    /// Nil when the ball has no photo.
    /// - Throws: `.notFound` for an unknown ball.
    public func photo(for ballID: BallID) throws -> Data? {
        try context.ball(ballID).photo?.imageData
    }

    /// The app downscales `imageData` before calling. Replaces an existing photo in place,
    /// so the ball keeps a single BallPhoto. Empty data removes the photo.
    /// - Throws: `.notFound` for an unknown ball, checked first so a deleted ball never
    ///   asks for a smaller photo; then `.invalidBall(.photoTooLarge)` over `maxPhotoBytes`.
    public func setPhoto(_ imageData: Data, for ballID: BallID) throws {
        let ball = try context.ball(ballID)
        guard !imageData.isEmpty else { return try removePhoto(for: ballID) }
        guard imageData.count <= Self.maxPhotoBytes else { throw RepositoryError.invalidBall(.photoTooLarge) }
        try context.write {
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
