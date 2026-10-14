import Foundation
import SwiftData

@Model
final class Roll {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var frame: Frame?
    /// 1 through 3.
    var rollIndex: Int = 1
    /// Ten-bit mask, bit n-1 is pin n. 0 for countOnly rolls and fouls.
    var pinsDownMask: Int = 0
    /// Pins credited on this roll. 0 on a foul.
    var pinCount: Int = 0
    /// False for countOnly and scanned games, where only `pinCount` is meaningful.
    var pinsKnown: Bool = false
    var isFoul: Bool = false
    /// Nil means the game's default ball.
    var ball: Ball?

    init(rollIndex: Int, pinsDownMask: Int = 0, pinCount: Int = 0, pinsKnown: Bool = false, isFoul: Bool = false) {
        self.rollIndex = rollIndex
        self.pinsDownMask = pinsDownMask
        self.pinCount = pinCount
        self.pinsKnown = pinsKnown
        self.isFoul = isFoul
    }
}
