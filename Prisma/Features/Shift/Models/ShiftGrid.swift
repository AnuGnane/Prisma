//
//  ShiftGrid.swift
//  Prisma
//
//  8×8 letter grid with row/column slide operations and full-board word scanning.
//

import Foundation

/// Direction a word can be oriented in the grid.
enum WordDirection: String, Codable, CaseIterable {
    case horizontal    // left → right
    case vertical      // top → bottom
    case diagonalDown  // top-left → bottom-right
    case diagonalUp    // bottom-left → top-right

    var icon: String {
        switch self {
        case .horizontal:   return "arrow.right"
        case .vertical:     return "arrow.down"
        case .diagonalDown: return "arrow.down.right"
        case .diagonalUp:   return "arrow.up.right"
        }
    }

    var delta: (dRow: Int, dCol: Int) {
        switch self {
        case .horizontal:   return (0, 1)
        case .vertical:     return (1, 0)
        case .diagonalDown: return (1, 1)
        case .diagonalUp:   return (-1, 1)
        }
    }
}

/// A found word location on the board — used to highlight cells.
struct FoundWordLocation: Equatable {
    let word: String
    let row: Int
    let col: Int
    let direction: WordDirection

    var cells: [(row: Int, col: Int)] {
        let (dR, dC) = direction.delta
        return (0..<word.count).map { i in (row + dR * i, col + dC * i) }
    }
}

/// Core 8×8 letter grid with slide operations and full-board word scanning.
struct ShiftGrid: Equatable, Hashable {
    static let size = 8

    private(set) var letters: [[Character]]

    init(letters: [[Character]]) {
        precondition(
            letters.count == Self.size &&
            letters.allSatisfy { $0.count == Self.size },
            "ShiftGrid must be \(Self.size)×\(Self.size)"
        )
        self.letters = letters
    }

    // MARK: - Access

    subscript(row: Int, col: Int) -> Character {
        letters[row][col]
    }

    func row(at index: Int) -> [Character] { letters[index] }

    func column(at index: Int) -> [Character] { letters.map { $0[index] } }

    // MARK: - Row Slide (wraparound)

    func slideRowLeft(_ rowIndex: Int) -> ShiftGrid {
        var n = letters
        let r = n[rowIndex]
        n[rowIndex] = Array(r.dropFirst()) + [r.first!]
        return ShiftGrid(letters: n)
    }

    func slideRowRight(_ rowIndex: Int) -> ShiftGrid {
        var n = letters
        let r = n[rowIndex]
        n[rowIndex] = [r.last!] + Array(r.dropLast())
        return ShiftGrid(letters: n)
    }

    // MARK: - Column Slide (wraparound)

    func slideColumnUp(_ colIndex: Int) -> ShiftGrid {
        var n = letters
        let col = column(at: colIndex)
        let rotated = Array(col.dropFirst()) + [col.first!]
        for r in 0..<Self.size { n[r][colIndex] = rotated[r] }
        return ShiftGrid(letters: n)
    }

    func slideColumnDown(_ colIndex: Int) -> ShiftGrid {
        var n = letters
        let col = column(at: colIndex)
        let rotated = [col.last!] + Array(col.dropLast())
        for r in 0..<Self.size { n[r][colIndex] = rotated[r] }
        return ShiftGrid(letters: n)
    }

    // MARK: - Full Board Word Scanning

    /// Scans the entire grid for a word in all directions.
    /// Returns the first location found, or nil if not found.
    func findWord(_ word: String) -> FoundWordLocation? {
        let chars = Array(word.uppercased())
        guard !chars.isEmpty else { return nil }

        for dir in WordDirection.allCases {
            let (dR, dC) = dir.delta
            for r in 0..<Self.size {
                for c in 0..<Self.size {
                    if matchesAt(chars: chars, row: r, col: c, dRow: dR, dCol: dC) {
                        return FoundWordLocation(word: word, row: r, col: c, direction: dir)
                    }
                }
            }
        }
        return nil
    }

    /// Checks if characters match starting from (row, col) in the given direction.
    private func matchesAt(chars: [Character], row: Int, col: Int, dRow: Int, dCol: Int) -> Bool {
        var r = row, c = col
        for ch in chars {
            guard r >= 0, r < Self.size, c >= 0, c < Self.size else { return false }
            guard letters[r][c] == ch else { return false }
            r += dRow; c += dCol
        }
        return true
    }

    /// Legacy: checks a word at a specific position (for serialization compatibility).
    func containsWord(_ word: String, at position: WordPosition) -> Bool {
        let chars = Array(word.uppercased())
        let (dR, dC) = position.direction.delta
        var r = position.row, c = position.startCol
        for ch in chars {
            guard r >= 0, r < Self.size, c >= 0, c < Self.size else { return false }
            guard letters[r][c] == ch else { return false }
            r += dR; c += dC
        }
        return true
    }
}
