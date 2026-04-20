import Foundation
import Testing
@testable import Prisma

@Suite("LevelDumper")
struct LevelDumper {
    @Test("Dump levels 11-25")
    func dumpLevels() throws {
        var levels: [CircuitLevel] = []
        for id in 11...25 {
            // we need to generate different sizes based on id
            let size = id < 15 ? 5 : (id < 20 ? 6 : 7)
            // Just use a date that gives us a good level, or use the generator
            // Wait, CircuitLevelGenerator has a `generate(for:)` which takes a Date and deterministically generates based on the date.
            // We can just use generate(for: date). Let's use different days.
            let date = Date(timeIntervalSince1970: TimeInterval(1700000000 + id * 86400))
            let level = CircuitLevelGenerator.generate(for: date)
            // CircuitLevelGenerator.generate returns a level with id = year*1000 + dayOfYear roughly.
            // We need to mutate the ID.
            var mutableLevel = level
            // Wait, CircuitLevel properties are all `let`. Let's check `CircuitLevel`.
        }
    }
}
