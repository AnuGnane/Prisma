import copy
import json
from pathlib import Path

LEVELS_PATH = Path("/Users/anugnana/Library/Projects/Prisma/Prisma/Prisma/Features/Circuit/Resources/circuit_levels.json")


def pos(row, col):
    return {"row": row, "col": col}


def cell(kind, **kwargs):
    value = {"kind": kind}
    value.update(kwargs)
    return value


def source(color, signal="active"):
    return cell("source", color=color, signal=signal)


def target(color, signal="active"):
    return cell("target", color=color, signal=signal)


def not_gate(direction=None):
    value = cell("notGate")
    if direction is not None:
        value["gateDirection"] = direction
    return value


def bridge():
    return cell("bridge")


def waypoint():
    return cell("waypoint")


def synthesizer(logic="or", output_signal="active"):
    return cell("synthesizer", synthLogic=logic, outputSignal=output_signal)


def make_empty_grid(size):
    return [[cell("empty") for _ in range(size)] for _ in range(size)]


def set_cells(grid, entries):
    for row, col, value in entries:
        grid[row][col] = value


def make_path(
    source_color,
    source_signal,
    segments,
    current_color=None,
    current_signal=None,
    was_transformed=False,
    is_complete=True,
):
    if current_color is None:
        current_color = source_color
    if current_signal is None:
        current_signal = source_signal

    return {
        "sourceColor": source_color,
        "sourceSignal": source_signal,
        "segments": [pos(row, col) for row, col in segments],
        "currentSignal": {
            "color": current_color,
            "signal": current_signal,
            "wasTransformed": was_transformed,
        },
        "isComplete": is_complete,
    }


def state_json(active_paths):
    return json.dumps({"activePaths": active_paths}, separators=(",", ":"))


def build_level(level_id, size, seed, grid, terminal_pairs, active_paths):
    return {
        "id": level_id,
        "size": size,
        "seed": seed,
        "grid": grid,
        "terminalPairs": terminal_pairs,
        "solutionStateJSON": state_json(active_paths),
    }


def build_base_levels():
    levels = []

    # Level 1: 4x4 dual-pair intro, full-board partition.
    grid = make_empty_grid(4)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (3, 0, target("blue", "active")),
            (0, 2, source("red", "active")),
            (3, 2, target("red", "active")),
        ],
    )
    levels.append(
        build_level(
            1,
            4,
            10,
            grid,
            [
                {"source": pos(0, 0), "target": pos(3, 0), "color": "blue", "signal": "active"},
                {"source": pos(0, 2), "target": pos(3, 2), "color": "red", "signal": "active"},
            ],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [(0, 0), (0, 1), (1, 1), (1, 0), (2, 0), (2, 1), (3, 1), (3, 0)],
                ),
                "red": make_path(
                    "red",
                    "active",
                    [(0, 2), (0, 3), (1, 3), (1, 2), (2, 2), (2, 3), (3, 3), (3, 2)],
                ),
            },
        )
    )

    # Level 2: 4x4 NOT gate pathing, full-board serpentine.
    grid = make_empty_grid(4)
    set_cells(
        grid,
        [
            (0, 0, source("yellow", "active")),
            (3, 0, target("yellow", "inactive")),
            (2, 1, not_gate()),
        ],
    )
    levels.append(
        build_level(
            2,
            4,
            20,
            grid,
            [{"source": pos(0, 0), "target": pos(3, 0), "color": "yellow", "signal": "inactive"}],
            {
                "yellow": make_path(
                    "yellow",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (0, 3),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (1, 0),
                        (2, 0),
                        (2, 1),
                        (2, 2),
                        (2, 3),
                        (3, 3),
                        (3, 2),
                        (3, 1),
                        (3, 0),
                    ],
                    current_signal="inactive",
                    was_transformed=True,
                )
            },
        )
    )

    # Level 3: 5x5 dual NOT lanes, both paths transform once.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (2, 4, target("blue", "inactive")),
            (4, 0, source("yellow", "active")),
            (4, 1, target("yellow", "inactive")),
            (1, 1, not_gate()),
            (3, 3, not_gate()),
        ],
    )
    levels.append(
        build_level(
            3,
            5,
            30,
            grid,
            [
                {"source": pos(0, 0), "target": pos(2, 4), "color": "blue", "signal": "inactive"},
                {"source": pos(4, 0), "target": pos(4, 1), "color": "yellow", "signal": "inactive"},
            ],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (0, 3),
                        (0, 4),
                        (1, 4),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (1, 0),
                        (2, 0),
                        (2, 1),
                        (2, 2),
                        (2, 3),
                        (2, 4),
                    ],
                    current_signal="inactive",
                    was_transformed=True,
                ),
                "yellow": make_path(
                    "yellow",
                    "active",
                    [(4, 0), (3, 0), (3, 1), (3, 2), (3, 3), (3, 4), (4, 4), (4, 3), (4, 2), (4, 1)],
                    current_signal="inactive",
                    was_transformed=True,
                ),
            },
        )
    )

    # Level 4: 4x4 bridge crossover with explicit axis crossing.
    grid = make_empty_grid(4)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (0, 3, target("blue", "active")),
            (0, 1, source("yellow", "active")),
            (2, 1, target("yellow", "active")),
            (1, 2, bridge()),
        ],
    )
    levels.append(
        build_level(
            4,
            4,
            40,
            grid,
            [
                {"source": pos(0, 0), "target": pos(0, 3), "color": "blue", "signal": "active"},
                {"source": pos(0, 1), "target": pos(2, 1), "color": "yellow", "signal": "active"},
            ],
            {
                "blue": make_path("blue", "active", [(0, 0), (1, 0), (1, 1), (1, 2), (1, 3), (0, 3)]),
                "yellow": make_path(
                    "yellow",
                    "active",
                    [(0, 1), (0, 2), (1, 2), (2, 2), (2, 3), (3, 3), (3, 2), (3, 1), (3, 0), (2, 0), (2, 1)],
                ),
            },
        )
    )

    # Level 5: 5x5 waypoint marathon, full snake.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("red", "active")),
            (4, 4, target("red", "active")),
            (1, 2, waypoint()),
            (2, 1, waypoint()),
            (3, 3, waypoint()),
        ],
    )
    levels.append(
        build_level(
            5,
            5,
            50,
            grid,
            [{"source": pos(0, 0), "target": pos(4, 4), "color": "red", "signal": "active"}],
            {
                "red": make_path(
                    "red",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (0, 3),
                        (0, 4),
                        (1, 4),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (1, 0),
                        (2, 0),
                        (2, 1),
                        (2, 2),
                        (2, 3),
                        (2, 4),
                        (3, 4),
                        (3, 3),
                        (3, 2),
                        (3, 1),
                        (3, 0),
                        (4, 0),
                        (4, 1),
                        (4, 2),
                        (4, 3),
                        (4, 4),
                    ],
                )
            },
        )
    )

    # Level 6: 5x5 synthesizer intro with feeder + transformed output path.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (0, 4, target("purple", "active")),
            (4, 0, source("red", "active")),
            (2, 2, synthesizer()),
        ],
    )
    levels.append(
        build_level(
            6,
            5,
            60,
            grid,
            [{"source": pos(0, 0), "target": pos(0, 4), "color": "blue", "signal": "active"}],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (1, 2),
                        (2, 2),
                        (2, 3),
                        (3, 3),
                        (4, 3),
                        (4, 4),
                        (3, 4),
                        (2, 4),
                        (1, 4),
                        (1, 3),
                        (0, 3),
                        (0, 4),
                    ],
                    current_color="purple",
                    current_signal="active",
                    was_transformed=True,
                ),
                "red": make_path(
                    "red",
                    "active",
                    [(4, 0), (3, 0), (2, 0), (1, 0), (1, 1), (2, 1), (3, 1), (4, 1), (4, 2), (3, 2), (2, 2)],
                ),
            },
        )
    )

    # Level 7: 5x5 NOT + waypoint full board.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (4, 4, target("blue", "inactive")),
            (1, 3, waypoint()),
            (2, 2, not_gate()),
        ],
    )
    levels.append(
        build_level(
            7,
            5,
            70,
            grid,
            [{"source": pos(0, 0), "target": pos(4, 4), "color": "blue", "signal": "inactive"}],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (0, 3),
                        (0, 4),
                        (1, 4),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (1, 0),
                        (2, 0),
                        (2, 1),
                        (2, 2),
                        (2, 3),
                        (2, 4),
                        (3, 4),
                        (3, 3),
                        (3, 2),
                        (3, 1),
                        (3, 0),
                        (4, 0),
                        (4, 1),
                        (4, 2),
                        (4, 3),
                        (4, 4),
                    ],
                    current_signal="inactive",
                    was_transformed=True,
                )
            },
        )
    )

    # Level 8: 5x5 bridge + waypoint crossover, full coverage.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (0, 4, target("blue", "active")),
            (0, 2, source("red", "active")),
            (4, 0, target("red", "active")),
            (0, 3, waypoint()),
            (2, 2, bridge()),
        ],
    )
    levels.append(
        build_level(
            8,
            5,
            80,
            grid,
            [
                {"source": pos(0, 0), "target": pos(0, 4), "color": "blue", "signal": "active"},
                {"source": pos(0, 2), "target": pos(4, 0), "color": "red", "signal": "active"},
            ],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [(0, 0), (0, 1), (1, 1), (1, 0), (2, 0), (3, 0), (3, 1), (2, 1), (2, 2), (2, 3), (2, 4), (1, 4), (0, 4)],
                ),
                "red": make_path(
                    "red",
                    "active",
                    [(0, 2), (0, 3), (1, 3), (1, 2), (2, 2), (3, 2), (3, 3), (3, 4), (4, 4), (4, 3), (4, 2), (4, 1), (4, 0)],
                ),
            },
        )
    )

    # Level 9: 5x5 NOT gate full snake.
    grid = make_empty_grid(5)
    set_cells(
        grid,
        [
            (0, 0, source("yellow", "active")),
            (4, 4, target("yellow", "inactive")),
            (2, 2, not_gate()),
        ],
    )
    levels.append(
        build_level(
            9,
            5,
            90,
            grid,
            [{"source": pos(0, 0), "target": pos(4, 4), "color": "yellow", "signal": "inactive"}],
            {
                "yellow": make_path(
                    "yellow",
                    "active",
                    [
                        (0, 0),
                        (0, 1),
                        (0, 2),
                        (0, 3),
                        (0, 4),
                        (1, 4),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (1, 0),
                        (2, 0),
                        (2, 1),
                        (2, 2),
                        (2, 3),
                        (2, 4),
                        (3, 4),
                        (3, 3),
                        (3, 2),
                        (3, 1),
                        (3, 0),
                        (4, 0),
                        (4, 1),
                        (4, 2),
                        (4, 3),
                        (4, 4),
                    ],
                    current_signal="inactive",
                    was_transformed=True,
                )
            },
        )
    )

    # Level 10: 6x6 synth + bridge advanced full-board puzzle.
    grid = make_empty_grid(6)
    set_cells(
        grid,
        [
            (0, 0, source("blue", "active")),
            (0, 1, target("purple", "active")),
            (0, 2, source("red", "active")),
            (3, 2, bridge()),
            (2, 4, synthesizer()),
        ],
    )
    levels.append(
        build_level(
            10,
            6,
            100,
            grid,
            [{"source": pos(0, 0), "target": pos(0, 1), "color": "blue", "signal": "active"}],
            {
                "blue": make_path(
                    "blue",
                    "active",
                    [
                        (0, 0),
                        (1, 0),
                        (2, 0),
                        (3, 0),
                        (4, 0),
                        (5, 0),
                        (5, 1),
                        (4, 1),
                        (3, 1),
                        (2, 1),
                        (2, 2),
                        (3, 2),
                        (4, 2),
                        (5, 2),
                        (5, 3),
                        (4, 3),
                        (3, 3),
                        (2, 3),
                        (2, 4),
                        (1, 4),
                        (1, 3),
                        (1, 2),
                        (1, 1),
                        (0, 1),
                    ],
                    current_color="purple",
                    current_signal="active",
                    was_transformed=True,
                ),
                "red": make_path(
                    "red",
                    "active",
                    [(0, 2), (0, 3), (0, 4), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5), (5, 4), (4, 4), (3, 4), (2, 4)],
                ),
            },
        )
    )

    return levels


def remap_color(color):
    mapping = {
        "blue": "green",
        "red": "orange",
        "yellow": "purple",
        "green": "blue",
        "orange": "yellow",
        "purple": "red",
    }
    return mapping.get(color, color)


def transform_pos(position, size, style):
    row = position["row"]
    col = position["col"]

    if row < 0 or col < 0:
        return {"row": row, "col": col}

    if style == 1:  # horizontal flip
        return {"row": row, "col": size - 1 - col}
    if style == 2:  # vertical flip
        return {"row": size - 1 - row, "col": col}
    if style == 3:  # transpose
        return {"row": col, "col": row}

    return {"row": row, "col": col}


def transform_grid(grid, size, style):
    recolored = []
    for row in grid:
        next_row = []
        for item in row:
            next_item = copy.deepcopy(item)
            if isinstance(next_item.get("color"), str):
                next_item["color"] = remap_color(next_item["color"])
            if isinstance(next_item.get("outputColor"), str):
                next_item["outputColor"] = remap_color(next_item["outputColor"])
            next_row.append(next_item)
        recolored.append(next_row)

    transformed = [[cell("empty") for _ in range(size)] for _ in range(size)]
    for row in range(size):
        for col in range(size):
            destination = transform_pos({"row": row, "col": col}, size, style)
            transformed[destination["row"]][destination["col"]] = recolored[row][col]

    return transformed


def transform_terminal_pairs(pairs, size, style):
    output = []
    for pair in pairs:
        next_pair = copy.deepcopy(pair)
        if isinstance(next_pair.get("color"), str):
            next_pair["color"] = remap_color(next_pair["color"])
        next_pair["source"] = transform_pos(next_pair["source"], size, style)
        next_pair["target"] = transform_pos(next_pair["target"], size, style)
        output.append(next_pair)
    return output


def transform_solution(solution_json, size, style):
    top = json.loads(solution_json)
    active_paths = top.get("activePaths", {})

    transformed_paths = {}
    for color, path_data in active_paths.items():
        next_path = copy.deepcopy(path_data)
        transformed_color = remap_color(color)

        if isinstance(next_path.get("sourceColor"), str):
            next_path["sourceColor"] = remap_color(next_path["sourceColor"])

        if isinstance(next_path.get("segments"), list):
            next_path["segments"] = [transform_pos(segment, size, style) for segment in next_path["segments"]]

        current_signal = next_path.get("currentSignal")
        if isinstance(current_signal, dict) and isinstance(current_signal.get("color"), str):
            current_signal["color"] = remap_color(current_signal["color"])
            next_path["currentSignal"] = current_signal

        transformed_paths[transformed_color] = next_path

    return json.dumps({"activePaths": transformed_paths}, separators=(",", ":"))


def clone_and_transform(base_level, new_id, style):
    size = base_level["size"]
    transformed = copy.deepcopy(base_level)
    transformed["id"] = new_id
    transformed["seed"] = new_id * 10
    transformed["grid"] = transform_grid(base_level["grid"], size, style)
    transformed["terminalPairs"] = transform_terminal_pairs(base_level["terminalPairs"], size, style)
    transformed["solutionStateJSON"] = transform_solution(base_level["solutionStateJSON"], size, style)
    return transformed


def main():
    base_levels = build_base_levels()

    rebuilt_levels = [copy.deepcopy(level) for level in base_levels]

    # 11-15: transforms of base 1-5 (horizontal flip)
    for index, base in enumerate(base_levels[:5], start=11):
        rebuilt_levels.append(clone_and_transform(base, index, 1))

    # 16-20: transforms of base 6-10 (vertical flip)
    for index, base in enumerate(base_levels[5:], start=16):
        rebuilt_levels.append(clone_and_transform(base, index, 2))

    # 21-25: transforms of base 6-10 (transpose)
    for index, base in enumerate(base_levels[5:], start=21):
        rebuilt_levels.append(clone_and_transform(base, index, 3))

    rebuilt_levels.sort(key=lambda level: level["id"])

    LEVELS_PATH.write_text(json.dumps(rebuilt_levels, indent=2) + "\n")
    print(f"Rebuilt circuit levels: {len(rebuilt_levels)}")


if __name__ == "__main__":
    main()
