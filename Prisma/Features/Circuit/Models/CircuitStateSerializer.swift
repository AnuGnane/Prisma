//
//  CircuitStateSerializer.swift
//  Prisma
//
//  Serialises the active paths of a Circuit board for history replay.
//

import Foundation

struct CircuitState: Codable {
    let activePaths: [NeonColor: ActivePath]
}

struct CircuitStateSerializer {
    static func serialize(activePaths: [NeonColor: ActivePath]) -> String? {
        let state = CircuitState(activePaths: activePaths)
        guard let data = try? JSONEncoder().encode(state) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func deserialize(_ jsonString: String) -> CircuitState? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CircuitState.self, from: data)
    }
}
