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
        case .circuit:  CircuitGraphic()
        }
    }
}

// MARK: - Circuit: miniature neon path grid

struct CircuitGraphic: View {
    // 4×4 grid showing two intersecting neon traces
    var body: some View {
        Canvas { context, size in
            let cell = size.width / 4
            let half = cell / 2

            func center(row: Int, col: Int) -> CGPoint {
                CGPoint(x: CGFloat(col) * cell + half, y: CGFloat(row) * cell + half)
            }

            // Cyan path: (0,0) → (1,0) → (2,0) → (2,1) → (2,2) → (3,2)
            let cyanPoints: [(Int,Int)] = [(0,0),(1,0),(2,0),(2,1),(2,2),(3,2)]
            drawNeonPath(from: cyanPoints, color: Color(red: 0, green: 0.78, blue: 1), cellFn: center, in: context, lineWidth: cell * 0.25)

            // Magenta path: (0,3) → (0,2) → (1,2) → (1,1) → (1,0) — crosses cyan via bridge
            let magentaPoints: [(Int,Int)] = [(0,3),(0,2),(1,2),(1,1),(3,1)]
            drawNeonPath(from: magentaPoints, color: Color(red: 0.88, green: 0.25, blue: 0.98), cellFn: center, in: context, lineWidth: cell * 0.25)

            // Draw small terminal circles
            for (r, c) in [(0,0),(3,2)] {
                let pt = center(row: r, col: c)
                let rect = CGRect(x: pt.x - cell*0.22, y: pt.y - cell*0.22, width: cell*0.44, height: cell*0.44)
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0, green: 0.78, blue: 1)))
            }
            for (r, c) in [(0,3),(3,1)] {
                let pt = center(row: r, col: c)
                let rect = CGRect(x: pt.x - cell*0.22, y: pt.y - cell*0.22, width: cell*0.44, height: cell*0.44)
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.88, green: 0.25, blue: 0.98)))
            }
        }
    }

    private func drawNeonPath(
        from points: [(Int, Int)],
        color: Color,
        cellFn: (Int, Int) -> CGPoint,
        in context: GraphicsContext,
        lineWidth: CGFloat
    ) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: cellFn(points[0].0, points[0].1))
        for p in points.dropFirst() { path.addLine(to: cellFn(p.0, p.1)) }

        // Glow pass
        var glow = context
        glow.opacity = 0.3
        glow.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth * 1.8, lineCap: .round, lineJoin: .round))
        // Core pass
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

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
