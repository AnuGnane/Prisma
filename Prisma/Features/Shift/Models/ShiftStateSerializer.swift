//
//  ShiftStateSerializer.swift
//  Prisma
//
//  JSON serialization for Shift v3 game state.
//

import Foundation

enum ShiftStateSerializer {

    static func serialize(
        grid: ShiftGrid,
        targetWords: [TargetWord],
        moveHistory: [ShiftMove]
    ) -> String? {
        let state = SerializableShiftState(
            grid: grid.letters.map { $0.map { String($0) } },
            targetWords: targetWords.map {
                SerializableTargetWord(
                    word: $0.word,
                    row: $0.position.row,
                    startCol: $0.position.startCol,
                    direction: $0.position.direction.rawValue
                )
            },
            moveHistory: moveHistory
        )

        do {
            let enc = JSONEncoder()
            enc.outputFormatting = .prettyPrinted
            return String(data: try enc.encode(state), encoding: .utf8)
        } catch {
            print("❌ ShiftStateSerializer: \(error.localizedDescription)")
            return nil
        }
    }

    static func deserialize(_ json: String) -> SerializableShiftState? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SerializableShiftState.self, from: data)
    }
}

struct SerializableShiftState: Codable, Equatable {
    let grid: [[String]]
    let targetWords: [SerializableTargetWord]
    let moveHistory: [ShiftMove]

    func toShiftGrid() -> ShiftGrid? {
        let size = ShiftGrid.size
        guard grid.count == size,
              grid.allSatisfy({ $0.count == size }),
              grid.allSatisfy({ r in r.allSatisfy { $0.count == 1 } }) else { return nil }
        return ShiftGrid(letters: grid.map { $0.compactMap { $0.first } })
    }
}

struct SerializableTargetWord: Codable, Equatable {
    let word: String
    let row: Int
    let startCol: Int
    let direction: String
}
