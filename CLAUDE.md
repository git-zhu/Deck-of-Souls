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
- Save roundtrip: `godot4.6 --headless --script tools/save_roundtrip_test.gd`
- Title menu: `godot4.6 --headless --script tools/title_menu_test.gd`
- Save load (Main): `godot4.6 --headless --script tools/save_load_test.gd`
- Pause menu: `godot4.6 --headless --script tools/pause_menu_test.gd`
- Export data manifest: `python tools/build_data_manifest.py` (after adding `data/**/*.tres`)
- Export data load: `godot4.6 --headless --script tools/export_data_load_test.gd`
- Origin screen UI: `godot4.6 --headless --script tools/origin_screen_test.gd`
- Audio assets: `godot4.6 --headless --script tools/audio_path_test.gd`
- UI screens: `godot4.6 --headless --script tools/ui_screen_test.gd`
- Keyboard shortcuts: `godot4.6 --headless --script tools/input_test.gd`
- Regenerate 2D art assets: `python tools/generate_assets.py`（自产 PNG：卡牌边框/意图图标/背景/图标）

## Architecture

**UI shell + core modules.** Game logic is split; `Main.gd` (~320 lines) owns UI layers and combat HUD; `RunFlowController` / `RunRewardFlow` route run logic; shared UI in `scripts/ui/`。

| Module | Path | Role |
|---|---|---|
| Main | `scripts/Main.gd` | Screen routing, combat/map/event flow |
| RunRewardFlow | `scripts/core/RunRewardFlow.gd` | Merchant, grace, ash, post-combat reward UI flow |
| RunFlowController | `scripts/core/RunFlowController.gd` | Map options, events, combat entry, combat_ended routing |
| RunSaveService | `scripts/core/RunSaveService.gd` | Single-slot `user://run_save.json` autosave / continue |
| RunPauseMenuView | `scripts/ui/RunPauseMenuView.gd` | In-run pause overlay (resume / title / abandon) |
| TitleScreenView / OriginScreenView / MapScreenView / DeckPopupView / EndScreenView | `scripts/ui/*ScreenView.gd` | Title, origin, map, deck popup, end screens |
| DeckUtils | `scripts/ui/DeckUtils.gd` | Deck card counts helper |
| GameTheme | `scripts/ui/GameTheme.gd` | Palette, map kind badges, intent colors |
| UiBuilders | `scripts/ui/UiBuilders.gd` | Panel, fighter, hand card, map option builders |
| RewardLayerViews | `scripts/ui/RewardLayerViews.gd` | Merchant, grace, event, post-combat rewards, pickers |
| CombatHudView | `scripts/ui/CombatHudView.gd` | Reconstructed combat HUD: compact fighter HUDs, intent banner, combat stage, resource chips, game cards, flask/end-turn CTAs |
| RunHeaderView | `scripts/ui/RunHeaderView.gd` | Run stats header + deck button |
| GameAudio | `scripts/ui/GameAudio.gd` | Optional `res://audio/*.ogg` hooks |
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
- `data/relics/*.tres` — `RelicData` talismans (8；含 `combat_souls_bonus`)
- `ActData.enemy_hp_percent` — per-act enemy HP scaling (100 / 110 / 125)
- `ActData` merchant pools / `merchant_cost_percent` / `map_weight_*` — per-act shop and map sampling
- `data/events/*.tres` — 15 map events (`MapEventData`); `MapEventChoiceData.follow_event_id` for multi-step chains
- `data/enemies/*.tres` — 18 enemies (incl. 大树守卫, 狮子混种, 坠星兽)
- `assets/*.png` — 自产 2D 美术（`tools/generate_assets.py` 生成）：卡牌符文边框、敌人意图图标、标题暗角、面板饰条、圣杯瓶/卢恩图标；AI 生成示例 `assets/ai_test_bg.png`（tiny-sd CPU，见 `docs/superpowers/specs/2026-05-23-ai-asset-generation-record.md`）

### Game State Machine

`enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }` — each transition rebuilds layer children via `_clear()`.

### Combat Mechanics

- **Energy (集中):** 3 per turn; card costs 0–3.
- **Hand size:** Base 5 per turn + memory stones + relic draw bonuses; reshuffle when draw pile empty.
- **Stance (姿态):** Enemy stance break with bonus damage window.
- **Status:** 腐败 / 出血 / 易伤 / 力量.
- **Run length:** **12 floors** (3 acts × 4); act bosses on floors 4/8/12 (indices 3, 7, 11); final boss triggers `run_victory`.

## Recommended Next (see `docs/superpowers/plans/`)

1. ~~默认音效包~~（P0 已完成：`audio/*.ogg` + `audio_path_test.gd`）；第四幕（16 层）**暂缓**，不在近期计划内。
2. ~~Monte Carlo 平衡工具~~（P2 已完成：`tools/monte_carlo_balance.gd`）。
3. ~~预言家 Boss 平衡~~（P3 已完成：`black_flame` 入初始牌组，Boss 胜率 20%→76%）。
4. 普通战难度上调（P4 候选：Monte Carlo 显示裸卡组普通/精英战 100% 胜率，偏易）。

**Git workflow:** After each implementation phase, `git commit` with a focused message, then **`git push`** to `origin`.

- One-time per clone (auto-push on every commit): `.\scripts\setup-git-hooks.ps1` — sets `core.hooksPath` to `.githooks/post-commit`.
- Agents: always run `git push` after committing a phase, even if hooks are not installed.

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
godot4.6 --headless --path . --script tools/balance_content_test.gd
godot4.6 --headless --path . --script tools/act_economy_test.gd
godot4.6 --headless --path . --script tools/ui_layout_test.gd
godot4.6 --headless --path . --script tools/reward_ui_test.gd
godot4.6 --headless --path . --script tools/combat_hud_test.gd
godot4.6 --headless --path . --script tools/flow_screen_test.gd
godot4.6 --headless --path . --script tools/event_chain_test.gd
godot4.6 --headless --path . --script tools/content_pack_test.gd
godot4.6 --headless --path . --script tools/run_flow_test.gd
godot4.6 --headless --path . --script tools/save_load_test.gd
godot4.6 --headless --path . --script tools/save_roundtrip_test.gd
godot4.6 --headless --path . --script tools/title_menu_test.gd
godot4.6 --headless --path . --script tools/pause_menu_test.gd
godot4.6 --headless --path . --script tools/export_data_load_test.gd
godot4.6 --headless --path . --script tools/origin_screen_test.gd
godot4.6 --headless --path . --script tools/audio_path_test.gd
godot4.6 --headless --path . --script tools/ui_screen_test.gd
godot4.6 --headless --path . --script tools/input_test.gd
```

Data builders (UTF-8): `python tools/build_acts.py`, `build_relics.py`, `build_enemies.py`, `build_events.py`.

Core scripts use `preload()` for cross-module types; data `.tres` files use Godot 4 `gd_resource` format (see `tools/convert_tres.py` if you add legacy `[resource name=...]` assets).

## QA finish (commit + push)

After `/gstack-qa` or a full headless test run passes, from repo root:

```powershell
.\scripts\post-qa-commit.ps1
```

This stages `scripts/`, `data/`, `tools/`, and `.gstack/qa-reports/`, commits, then pushes (`post-commit` hook if `.\scripts\setup-git-hooks.ps1` was run once per clone).

Optional: `.\scripts\post-qa-commit.ps1 -Message "fix(qa): …"` or `-SkipPush`.

`tools/smoke_test.gd` extends `SceneTree` and validates all 6 origins by:
1. Starting a run, visiting a grace point (heal check), opening deck view.
2. Starting combat, playing a card, ending turn, rendering combat.
3. Verifying UI panels fit within 1280x720 viewport.
