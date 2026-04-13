//
//  GameCardGraphic.swift
//  Prisma
//
//  Miniature game illustration used in home and detail cards.
//

import SwiftUI

struct GameCardGraphic: View {
    let game: GameType

    var body: some View {
        switch game {
        case .signals:  SignalsGraphic()
        case .archive:  ArchiveGraphic()
        case .cargo:    CargoGraphic()
        case .shift:    ShiftGraphic()
        }
    }
}

// MARK: - Signals: Mastermind code-guess board

struct SignalsGraphic: View {
    // 5 rows of guesses: each row has 4 circle dots
    let rows: [[Color?]] = [
        [nil, nil, nil, nil],
        [.green, nil, nil, nil],
        [.green, .yellow, nil, nil],
        [.green, .green, .yellow, nil],
        [.green, .green, .green, .green],
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { c in
                        let color = rows[r][c]
                        Circle()
                            .fill(color ?? Color.white.opacity(0.2))
                            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }
}

// MARK: - Archive: Calendar grid with a circled date

struct ArchiveGraphic: View {
    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                let days = ["S","M","T","W","T","F","S"]
                ForEach(days.indices, id: \.self) { i in
                    Text(days[i])
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Date grid — 5 rows, 7 cols
            let dates: [[Int?]] = [
                [1,2,3,4,5,6,7],
                [8,9,10,11,12,13,14],
                [15,16,17,18,19,20,21],
                [22,23,24,25,26,27,28],
                [29,30,31,nil,nil,nil,nil]
            ]
            let highlighted = 16

            VStack(spacing: 2) {
                ForEach(dates.indices, id: \.self) { r in
                    HStack(spacing: 2) {
                        ForEach(dates[r].indices, id: \.self) { c in
                            if let d = dates[r][c] {
                                ZStack {
                                    if d == highlighted {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 1)
                                    }
                                    Text("\(d)")
                                        .font(.system(size: 6, weight: d == highlighted ? .bold : .regular))
                                        .foregroundStyle(.white.opacity(d == highlighted ? 1.0 : 0.55))
                                }
                                .frame(width: 8, height: 8)
                            } else {
                                Color.clear.frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Cargo: Tetromino grid

struct CargoGraphic: View {
    // 4x4 grid, each cell has a colour index (0 = empty, 1-4 = piece)
    let grid: [[Int]] = [
        [1, 1, 2, 2],
        [1, 3, 3, 2],
        [4, 3, 4, 4],
        [4, 3, 4, 0],
    ]
    let colours: [Color] = [
        .clear,
        .white.opacity(0.9),
        .white.opacity(0.6),
        .white.opacity(0.75),
        .white.opacity(0.45),
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(grid.indices, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(grid[r].indices, id: \.self) { c in
                        let idx = grid[r][c]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colours[idx])
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
    }
}

// MARK: - Shift: Sliding letter-tile grid (3x4, one tile shifted)

struct ShiftGraphic: View {
    let letters: [[String]] = [
        ["S","H","I","F"],
        ["T","E","R","M"],
        ["W","O","R","D"],
    ]
    let highlightRow = 0

    var body: some View {
        VStack(spacing: 3) {
            ForEach(letters.indices, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(letters[r].indices, id: \.self) { c in
                        let letter = letters[r][c]
                        let isHighlighted = (r == highlightRow)
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(isHighlighted ? 0.3 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.white.opacity(isHighlighted ? 0.6 : 0.25), lineWidth: 1)
                                )
                            Text(letter)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 15, height: 15)
                    }
                    // Arrow on the right of highlighted row
                    if r == highlightRow {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}
