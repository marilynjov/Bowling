import Foundation
import SwiftData

/// Kept off `Game` so syncing a game never moves image bytes.
@Model
final class GamePhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    /// Downscaled before save.
    @Attribute(.externalStorage)
    var imageData: Data = Data()
    var game: Game?

    init(imageData: Data) {
        self.imageData = imageData
    }
}

/// Kept off `Ball` so syncing a ball never moves image bytes.
@Model
final class BallPhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    /// Downscaled before save.
    @Attribute(.externalStorage)
    var imageData: Data = Data()
    var ball: Ball?

    init(imageData: Data) {
        self.imageData = imageData
    }
}
