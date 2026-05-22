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
| MapGenerator | `scripts/core/MapGenerator.gd` | 12-floor map options from `ActData` + `MapEncounterData` |
| GraceService | `scripts/core/GraceService.gd` | Grace campfire roll/apply |
| MerchantService | `scripts/core/MerchantService.gd` | Colleen shop roll/purchase |
| RelicService | `scripts/core/RelicService.gd` | Run relics, combat-start hooks |
| AshService | `scripts/core/AshService.gd` | War-ash replace pool (type 战灰) |
| EventService | `scripts/core/EventService.gd` | Map event choice eligibility/apply |

### Data (`.tres` under `data/`)

- `data/cards/*.tres` — `CardData` + optional `hook_id` / `effects`
- `data/enemies/*.tres` — `EnemyData` + `MoveData`
- `data/origins/*.tres` — `OriginData` starting decks
- `data/acts/*.tres` — `ActData` per act (encounters, reward_cards, grace/merchant, boss)
- `data/MapEncounterData.gd` — map combat/elite encounter copy
- `data/grace_options/*.tres` — `GraceOptionData` campfire upgrades
- `data/merchant_offers/*.tres` — `MerchantOfferData` shop stock
- `data/relics/*.tres` — `RelicData` talismans
- `data/events/*.tres` — `MapEventData` narrative choices

### Game State Machine

`enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }` — each transition rebuilds layer children via `_clear()`.

### Combat Mechanics

- **Energy (集中):** 3 per turn; card costs 0–3.
- **Hand size:** Base 5 per turn + memory stones + relic draw bonuses; reshuffle when draw pile empty.
- **Stance (姿态):** Enemy stance break with bonus damage window.
- **Status:** 腐败 / 出血 / 易伤 / 力量.
- **Run length:** **12 floors** (3 acts × 4); act bosses on floors 4/8/12 (indices 3, 7, 11); final boss triggers `run_victory`.

## Recommended Next (see `docs/superpowers/plans/`)

1. Balance pass; more relics/cards/events; fix act `reward_cards` starter ids.
2. Optional: event-specific UI polish, weighted event spawn.

**Workflow:** After each implementation phase, create a focused `git commit` for that phase.

## Smoke Test

```bash
godot4.6 --headless --path . --script tools/smoke_test.gd
godot4.6 --headless --path . --script tools/map_generator_test.gd
godot4.6 --headless --path . --script tools/grace_service_test.gd
godot4.6 --headless --path . --script tools/merchant_service_test.gd
godot4.6 --headless --path . --script tools/relic_service_test.gd
godot4.6 --headless --path . --script tools/memory_stone_test.gd
godot4.6 --headless --path . --script tools/ash_service_test.gd
godot4.6 --headless --path . --script tools/relic_reward_test.gd
godot4.6 --headless --path . --script tools/act_content_test.gd
godot4.6 --headless --path . --script tools/event_service_test.gd
```

Core scripts use `preload()` for cross-module types; data `.tres` files use Godot 4 `gd_resource` format (see `tools/convert_tres.py` if you add legacy `[resource name=...]` assets).

`tools/smoke_test.gd` extends `SceneTree` and validates all 6 origins by:
1. Starting a run, visiting a grace point (heal check), opening deck view.
2. Starting combat, playing a card, ending turn, rendering combat.
3. Verifying UI panels fit within 1280x720 viewport.
