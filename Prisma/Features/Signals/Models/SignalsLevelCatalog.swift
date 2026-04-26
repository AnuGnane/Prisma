//
//  SignalsLevelCatalog.swift
//  Prisma
//
//  Loads the curated Signals progression catalog from signals_levels.json
//  and caches it for O(1) lookup by level id.
//
//  Until this catalog existed, SignalsGameViewModel.init(level: Int) ignored
//  signals_levels.json entirely and used a fixed 4-digit, 5-guess config for
//  every progression level. With 150 curated levels, we now look up each
//  level's config (digit range + max guesses) so difficulty actually scales.
//

import Foundation

enum SignalsLevelCatalog {

    /// Filename (without extension) in the app bundle.
    private static let resourceName = "signals_levels"

    /// Lazy-loaded, in-memory catalog. Accessed via `level(id:)`.
    ///
    /// If the JSON is missing or malformed we return an empty dictionary and
    /// the caller is expected to fall back to a sensible default config.
    private static let catalog: [Int: SignalsLevel] = {
        do {
            let levels: [SignalsLevel] = try LevelLoader.load(resourceName)
            var byId: [Int: SignalsLevel] = [:]
            byId.reserveCapacity(levels.count)
            for level in levels {
                byId[level.id] = level
            }
            return byId
        } catch {
            print("❌ SignalsLevelCatalog: failed to load \(resourceName).json — \(error.localizedDescription)")
            return [:]
        }
    }()

    /// Number of curated levels available.
    static var count: Int { catalog.count }

    /// Returns the config for the given level id, or `nil` if unknown.
    static func level(id: Int) -> SignalsLevel? {
        catalog[id]
    }

    /// Returns the config for the given level id, falling back to a safe
    /// default (5 guesses, 4 digits 0–9) if the id isn't in the catalog.
    ///
    /// The fallback keeps legacy progression playable even if the JSON file
    /// is ever missing a level id.
    static func levelOrDefault(id: Int) -> SignalsLevel {
        if let lvl = catalog[id] {
            return lvl
        }
        return SignalsLevel(id: id, maxGuesses: 5, codeLength: 4, digitMin: 0, digitMax: 9)
    }
}
