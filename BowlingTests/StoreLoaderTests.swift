import BowlingData
import Testing
@testable import Bowling

@Suite struct StoreLoaderTests {
    struct OpenFailed: Error {}

    @Test func loadOpensTheStore() {
        let loader = StoreLoader(open: { try BowlingStore(inMemory: true) })
        loader.load()
        #expect(loader.app != nil)
        #expect(loader.failure == nil)
    }

    @Test func failureIsKept() {
        let loader = StoreLoader(open: { throw OpenFailed() })
        loader.load()
        #expect(loader.app == nil)
        #expect(loader.failure is OpenFailed)
    }

    @Test func retryAfterFailureOpens() {
        var attempts = 0
        let loader = StoreLoader(open: {
            attempts += 1
            if attempts == 1 { throw OpenFailed() }
            return try BowlingStore(inMemory: true)
        })
        loader.load()
        #expect(loader.failure != nil)
        loader.load()
        #expect(loader.app != nil)
        #expect(loader.failure == nil)
        #expect(attempts == 2)
    }
}
