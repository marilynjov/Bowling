import BowlingCore

/// Why a repository refused a read or a write. Nothing is saved when one is thrown.
public enum RepositoryError: Error, Sendable, Hashable {
    case notFound
    /// The game would fail `Scorer.validate`.
    case invalidGame([ScoringError])
    /// The entry mode is fixed once the first roll exists.
    case entryModeLocked
    /// The user can delete the games first.
    case bowlerHasGames(count: Int)
    case cannotDeleteOwner
    /// One owner per user; a second device's owner is merged after sync instead.
    case ownerAlreadyExists
    case invalidBall(BallFieldError)
    case invalidBowler(BowlerFieldError)
    /// Only a finalOnly game has a typed score; the others are scored from their rolls.
    case notFinalOnly
}

public enum BallFieldError: Sendable, Hashable {
    case emptyName
    /// Outside 6 through 16 pounds.
    case weightOutOfRange
}

public enum BowlerFieldError: Sendable, Hashable {
    /// Blank after trimming whitespace and newlines.
    case emptyName
}
