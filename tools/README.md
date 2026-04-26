# Prisma — Dev Tooling

Scripts that don't ship with the app but help build, configure, or maintain it.

## `gen_achievement_icons.swift`

Renders the ten 512×512 PNG icons needed for the Phase 4 App Store Connect achievement entries (5 first-win + 5 perfect-win, one of each per game). Each icon is a per-game gradient backdrop with a centered SF Symbol in white.

### Run

From the Xcode project root (`Prisma/Prisma/`, where `Prisma.xcodeproj` lives):

```sh
swift tools/gen_achievement_icons.swift
```

Output lands in `tools/achievement_images/`:

| File                          | ASC Achievement ID         |
|-------------------------------|----------------------------|
| `prisma.first_signal.png`     | `prisma.first_signal`      |
| `prisma.first_archive.png`    | `prisma.first_archive`     |
| `prisma.first_cargo.png`      | `prisma.first_cargo`       |
| `prisma.first_shift.png`      | `prisma.first_shift`       |
| `prisma.first_circuit.png`    | `prisma.first_circuit`     |
| `prisma.perfect_signal.png`   | `prisma.perfect_signal`    |
| `prisma.perfect_archive.png`  | `prisma.perfect_archive`   |
| `prisma.perfect_cargo.png`    | `prisma.perfect_cargo`     |
| `prisma.perfect_shift.png`    | `prisma.perfect_shift`     |
| `prisma.perfect_circuit.png`  | `prisma.perfect_circuit`   |

### Requirements

- macOS 12 or later (the script uses `NSImage.SymbolConfiguration(paletteColors:)`).
- No third-party dependencies; AppKit is built into Swift on macOS.

### Editing

The gradients in the script mirror `AppTheme.cargoGradient` etc. in `AppTheme.swift`. If you change the in-app palette, update the script, re-run, and commit the new PNGs.

### App Store Connect upload

1. App Store Connect → Your App → Features → Game Center → Achievements.
2. For each of the seven entries listed in `GAME_CENTER_STATUS.md` marked ⚠️, create the achievement, paste the ID exactly, upload the matching PNG, fill localisation (see `LEADERBOARD_RESTRUCTURE_TASKS.md` § Phase 4), set point value, save.
3. ASC needs a few minutes to propagate before the achievements are testable in the GC sandbox.
