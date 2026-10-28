import BowlingCore

/// A screen pushed on the History tab's stack.
enum HistoryRoute: Hashable {
    case session(SessionID)
    case game(GameID)
}
