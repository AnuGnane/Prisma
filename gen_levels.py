import json

def make_cell(kind, color=None, sig=None, dir=None, outColor=None, outSig=None, logic=None):
    c = {"kind": kind}
    if color: c["color"] = color
    if sig: c["signal"] = sig
    if dir: c["gateDirection"] = dir
    if outColor: c["outputColor"] = outColor
    if outSig: c["outputSignal"] = outSig
    if logic: c["synthLogic"] = logic
    return c

empty = make_cell("empty")
wp = make_cell("waypoint")
bridge = make_cell("bridge")

def make_level(id, size, par, seed, pairs, grid, active_paths):
    return {
        "id": id, "size": size, "parPathLength": par, "seed": seed,
        "terminalPairs": pairs, "grid": grid,
        "solutionStateJSON": json.dumps({"activePaths": active_paths})
    }

def active_path(color, sig, segs):
    return {
        "sourceColor": color, "sourceSignal": sig,
        "segments": segs,
        "currentSignal": {"color": color, "signal": sig, "wasTransformed": False},
        "isComplete": True
    }

l1_grid = [[empty]*4 for _ in range(4)]
l1_grid[0][0] = make_cell("source", "cyan", "active")
l1_grid[0][3] = make_cell("target", "cyan", "active")
l1_grid[3][0] = make_cell("source", "magenta", "inactive")
l1_grid[3][3] = make_cell("target", "magenta", "inactive")
l1_paths = {
    "cyan": active_path("cyan", "active", [{"row":0,"col":c} for c in range(4)]),
    "magenta": active_path("magenta", "inactive", [{"row":3,"col":c} for c in range(4)])
}
l1 = make_level(1, 4, 8, 1, [
    {"source":{"row":0,"col":0}, "target":{"row":0,"col":3}, "color":"cyan", "signal":"active"},
    {"source":{"row":3,"col":0}, "target":{"row":3,"col":3}, "color":"magenta", "signal":"inactive"}
], l1_grid, l1_paths)

# Level 2 NOT Gate
l2_grid = [[empty]*4 for _ in range(4)]
l2_grid[0][1] = make_cell("source", "amber", "active")
l2_grid[3][1] = make_cell("target", "amber", "inactive")  # requires NOT
l2_grid[1][1] = make_cell("notGate")
l2_paths = {
    "amber": active_path("amber", "active", [{"row":r,"col":1} for r in range(4)])
}
l2_paths["amber"]["currentSignal"]["signal"] = "inactive"
l2_paths["amber"]["currentSignal"]["wasTransformed"] = True
l2 = make_level(2, 4, 4, 2, [
    {"source":{"row":0,"col":1}, "target":{"row":3,"col":1}, "color":"amber", "signal":"inactive"}
], l2_grid, l2_paths)

# Level 3 ColorShift (cyan -> magenta)
l3_grid = [[empty]*4 for _ in range(4)]
l3_grid[1][0] = make_cell("source", "cyan", "active")
l3_grid[1][3] = make_cell("target", "magenta", "active")
l3_grid[1][1] = make_cell("colorShiftGate", outColor="magenta")
l3_paths = {
    "cyan": active_path("cyan", "active", [{"row":1,"col":c} for c in range(4)])
}
l3_paths["cyan"]["currentSignal"]["color"] = "magenta"
l3_paths["cyan"]["currentSignal"]["wasTransformed"] = True
l3 = make_level(3, 4, 4, 3, [
    {"source":{"row":1,"col":0}, "target":{"row":1,"col":3}, "color":"magenta", "signal":"active"}
], l3_grid, l3_paths)

# Level 4 Bridge
l4_grid = [[empty]*5 for _ in range(5)]
l4_grid[2][0] = make_cell("source", "cyan", "active")
l4_grid[2][4] = make_cell("target", "cyan", "active")
l4_grid[0][2] = make_cell("source", "amber", "inactive")
l4_grid[4][2] = make_cell("target", "amber", "inactive")
l4_grid[2][2] = bridge
l4_paths = {
    "cyan": active_path("cyan", "active", [{"row":2,"col":c} for c in range(5)]),
    "amber": active_path("amber", "inactive", [{"row":r,"col":2} for r in range(5)])
}
l4 = make_level(4, 5, 10, 4, [
    {"source":{"row":2,"col":0}, "target":{"row":2,"col":4}, "color":"cyan", "signal":"active"},
    {"source":{"row":0,"col":2}, "target":{"row":4,"col":2}, "color":"amber", "signal":"inactive"}
], l4_grid, l4_paths)

# Level 5 Synthesizer (Active + Inactive = Active using OR)
l5_grid = [[empty]*5 for _ in range(5)]
l5_grid[1][0] = make_cell("source", "cyan", "inactive")
l5_grid[3][0] = make_cell("source", "magenta", "active")
l5_grid[2][4] = make_cell("target", "amber", "active")
l5_grid[2][2] = make_cell("synthesizer", outColor="amber", outSig="active", logic="or")

l5_paths = {
    "cyan": active_path("cyan", "inactive", [{"row":1,"col":0}, {"row":1,"col":1}, {"row":1,"col":2}, {"row":2,"col":2}, {"row":2,"col":3}, {"row":2,"col":4}]),
    "magenta": active_path("magenta", "active", [{"row":3,"col":0}, {"row":3,"col":1}, {"row":3,"col":2}, {"row":2,"col":2}])
}
l5_paths["cyan"]["currentSignal"]["color"] = "amber"
l5_paths["cyan"]["currentSignal"]["signal"] = "active"
l5_paths["cyan"]["currentSignal"]["wasTransformed"] = True
l5 = make_level(5, 5, 10, 5, [
    {"source":{"row":1,"col":0}, "target":{"row":2,"col":4}, "color":"amber", "signal":"active"},
    {"source":{"row":3,"col":0}, "target":{"row":2,"col":2}, "color":"magenta", "signal":"active"} # Synth secondary input
], l5_grid, l5_paths)

out = [l1, l2, l3, l4, l5]
with open("Prisma/Features/Circuit/Resources/circuit_levels.json", "w") as f:
    json.dump(out, f, indent=2)

print("SUCCESS")
