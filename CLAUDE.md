# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Name:** 老头牌：褪色者的牌局 (Old Man's Cards: Tarnished Card Game)
**Engine:** Godot 4.6 (Forward Plus renderer)
**Genre:** Card-based Roguelike deckbuilder with turn-based combat, inspired by *Slay the Spire* and themed on *Elden Ring*.
**Viewport:** 1280x720, canvas_items stretch (expand aspect)

## How to Run

- Open `project.godot` in Godot 4.6 and run `res://scenes/Main.tscn`.
- Smoke test (headless): `godot4.6 --headless --script tools/smoke_test.gd`

## Architecture

**UI shell + core modules.** Game logic is split; `Main.gd` (~785 lines) builds UI and routes screens.

| Module | Path | Role |
|---|---|---|
| Main | `scripts/Main.gd` | Screens, theme, combat/map UI, logs |
| DataRegistry | `scripts/core/DataRegistry.gd` | Load `data/**/*.tres` |
| RunState | `scripts/core/RunState.gd` | Run HP, deck, piles, floor, statuses |
| CombatController | `scripts/core/CombatController.gd` | Combat, damage, enemy turns |
| CardEffectResolver | `scripts/core/CardEffectResolver.gd` | `CardEffectStep` chain + hooks |
| MapGenerator | `scripts/core/MapGenerator.gd` | Map options (6 floors phase 1) |

### Data (`.tres` under `data/`)

- `data/cards/*.tres` — `CardData` + optional `hook_id` / `effects`
- `data/enemies/*.tres` — `EnemyData` + `MoveData`
- `data/origins/*.tres` — `OriginData` starting decks

### Game State Machine

`enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }` — each transition rebuilds layer children via `_clear()`.

### Combat Mechanics

- **Energy (集中):** 3 per turn; card costs 0–3.
- **Hand size:** 5 per turn; reshuffle when draw pile empty.
- **Stance (姿态):** Enemy stance break with bonus damage window.
- **Status:** 腐败 / 出血 / 易伤 / 力量.
- **Run length:** Map still **6 nodes** in phase 1; constants use `RunState.TOTAL_FLOORS = 12` for UI (phase 2 enables 12-layer acts).

## Recommended Next (see `docs/superpowers/plans/`)

1. **Phase 2:** `ActData`, 12-floor three-act map, `is_act_boss` / `is_run_boss` victory rules.
2. Talismans, grace upgrades, merchant Colleen (later).

## Smoke Test

`tools/smoke_test.gd` extends `SceneTree` and validates all 6 origins by:
1. Starting a run, visiting a grace point (heal check), opening deck view.
2. Starting combat, playing a card, ending turn, rendering combat.
3. Verifying UI panels fit within 1280x720 viewport.
