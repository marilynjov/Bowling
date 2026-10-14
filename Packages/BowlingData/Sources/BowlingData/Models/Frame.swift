import Foundation
import SwiftData

@Model
final class Frame {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var game: Game?
    /// 1 through 10.
    var frameIndex: Int = 1

    /// Unordered; sort by `Roll.rollIndex`.
    @Relationship(deleteRule: .cascade, inverse: \Roll.frame)
    var rolls: [Roll]?

    /// Reserved for Baker.
    var rotationSlot: Int?

    init(frameIndex: Int) {
        self.frameIndex = frameIndex
    }
}
