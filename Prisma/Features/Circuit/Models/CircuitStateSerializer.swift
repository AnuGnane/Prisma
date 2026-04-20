//
//  CircuitStateSerializer.swift
//  Prisma
//
//  Serialises the active paths of a Circuit board for history replay.
//
//  Schema note:
//  ────────────
//  `activePaths` is a color-keyed dictionary for O(1) lookup during gameplay.
//  Dictionaries do NOT preserve insertion order, so `pathOrder` records the
//  order in which the player drew each color. This is essential for faithful
//  replay of boards containing Synthesizer gates, because the first path to
//  arrive at a synth dictates the mixed-color output seen by the second.
//  Older saves (pre-2026-04) omit `pathOrder` — decoding is backward
//  compatible and the view model falls back to permutation search in that
//  case.
//

import Foundation

struct CircuitState: Codable {
    let activePaths: [NeonColor: ActivePath]
    /// The order in which colors were drawn. `nil` for legacy saves.
    let pathOrder: [NeonColor]?

    enum CodingKeys: String, CodingKey {
        case activePaths
        case pathOrder
    }

    init(activePaths: [NeonColor: ActivePath], pathOrder: [NeonColor]? = nil) {
        self.activePaths = activePaths
        self.pathOrder = pathOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dict = try container.decode([String: ActivePath].self, forKey: .activePaths)
        var paths: [NeonColor: ActivePath] = [:]
        for (k, v) in dict {
            if let color = NeonColor(rawValue: k) {
                paths[color] = v
            }
        }
        self.activePaths = paths

        // Optional field with legacy-friendly decoding. String values are mapped
        // through NeonColor(from:) so legacy palette keys (cyan/magenta/etc.)
        // are upgraded automatically.
        if let rawOrder = try container.decodeIfPresent([String].self, forKey: .pathOrder) {
            var resolved: [NeonColor] = []
            for raw in rawOrder {
                if let color = NeonColor(legacyRawValue: raw) {
                    resolved.append(color)
                }
            }
            // Filter to colors we actually have paths for so a corrupt order
            // field can't produce a ghost entry.
            self.pathOrder = resolved.filter { paths.keys.contains($0) }
        } else {
            self.pathOrder = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var dict: [String: ActivePath] = [:]
        for (k, v) in activePaths {
            dict[k.rawValue] = v
        }
        try container.encode(dict, forKey: .activePaths)
        if let order = pathOrder {
            try container.encode(order.map { $0.rawValue }, forKey: .pathOrder)
        }
    }
}

struct CircuitStateSerializer {
    /// Serialise the current active paths. Callers should pass the draw order
    /// so Synthesizer-bearing boards replay identically to the original game.
    static func serialize(activePaths: [NeonColor: ActivePath], pathOrder: [NeonColor]? = nil) -> String? {
        let state = CircuitState(activePaths: activePaths, pathOrder: pathOrder)
        guard let data = try? JSONEncoder().encode(state) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deserialize(_ jsonString: String) -> CircuitState? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(CircuitState.self, from: data)
        } catch {
            print("[Circuit] Deserialize error: \(error)")
            return nil
        }
    }
}
