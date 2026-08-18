# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Name:** Deck of Souls
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
- Drag-to-play hand cards: `godot4.6 --headless --script tools/drag_test.gd`
- StS-style features (hover lift / energy orb / status icons): `godot4.6 --headless --script tools/sts_features_test.gd`
- Multi-enemy combat (core): `godot4.6 --headless --script tools/multi_enemy_test.gd`
- Multi-enemy combat (UI + targeting): `godot4.6 --headless --script tools/multi_enemy_ui_test.gd`
- AOE cards + elite groups: `godot4.6 --headless --script tools/aoe_elite_test.gd`
- Hand card hitbox (mouse_filter consistency): `godot4.6 --headless --script tools/hitbox_test.gd`
- Drag targeting line (StS-style aim): `godot4.6 --headless --script tools/targeting_line_test.gd`
- Attribute leveling (ER rune curve): `godot4.6 --headless --script tools/leveling_service_test.gd`
- ER-style damage formula: `godot4.6 --headless --script tools/damage_formula_test.gd`
- Smithing stone weapon upgrade: `godot4.6 --headless --script tools/smithing_test.gd`
- Enemy behavior patterns (weight/charge/phase2/bleed): `godot4.6 --headless --script tools/enemy_pattern_test.gd`
- Stance break choices (exec/parry): `godot4.6 --headless --script tools/stance_break_test.gd`
- NG+ and vows (profile/scaling): `godot4.6 --headless --script tools/ngplus_test.gd`
- Build depth (affinity rewards/rule relics/card upgrade/numbers): `godot4.6 --headless --script tools/build_depth_test.gd`
- Souls features (map fragment/death echo/events/ambush/challenges): `godot4.6 --headless --script tools/souls_features_test.gd`
- Round-2 fixes (charge interrupt/parry sustain/souls_earned/NG+ pools/vows): `godot4.6 --headless --script tools/round2_fixes_test.gd`
- Round-3 fixes (weapon-level pipeline/hook scaling/scion difficulty/interrupt reroll/ambush/relic values/fragment cost/buckler/elite phase2): `godot4.6 --headless --script tools/round3_fixes_test.gd`
- Host-level e2e (RunFlowController echo injection + fragment flow): `godot4.6 --headless --script tools/run_flow_host_test.gd`
- Balance gate (greedy bot winrate): `godot4.6 --headless --script tools/monte_carlo_balance.gd`
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
| ProfileService | `scripts/core/ProfileService.gd` | Cross-run profile (`user://profile.json`): NG/vow unlocks, memory currency, death echo |
| AshService | `scripts/core/AshService.gd` | War-ash replace pool (type 战灰) |
| EventService | `scripts/core/EventService.gd` | Map event choice eligibility/apply |

### Data (`.tres` under `data/`)

- `data/cards/*.tres` — `CardData` + optional `hook_id` / `effects`（含幕专属卡：`twinblade` 宁姆格福 / `storm_blade` `bloody_slash` 史东薇尔 / `comet` `shard_spiral` 利耶尼亚；三幕奖励池零重叠）
- `data/enemies/*.tres` — `EnemyData` + `MoveData`
- `data/origins/*.tres` — `OriginData` starting decks
- `data/acts/*.tres` — `ActData` per act (encounters, reward_cards, grace/merchant, boss)
- `data/MapEncounterData.gd` — map combat/elite encounter copy
- `data/grace_options/*.tres` — `GraceOptionData` campfire upgrades（含 `forge_etch` 锻造刻印卡牌升级）
- `data/merchant_offers/*.tres` — `MerchantOfferData` shop stock
- `data/relics/*.tres` — `RelicData` talismans (14；含规则型：`bleed_threshold_5` / `draw_on_magic` / `stance_up_block_down` / `souls_double_chance` / `exec_bonus` / `ember_and_rot`)
- `ActData.enemy_hp_percent` — per-act enemy HP scaling (100 / 110 / 125)
- `ActData` merchant pools / `merchant_cost_percent` / `map_weight_*` — per-act shop and map sampling
- `data/events/*.tres` — 21 map events (`MapEventData`; 含赌博/诅咒/死亡回响；效果词汇见 `EventService`); `MapEventChoiceData.follow_event_id` for multi-step chains
- `data/enemies/*.tres` — 18 enemies (incl. 大树守卫, 狮子混种, 坠星兽)
- `assets/*.png` — 自产 2D 美术（`tools/generate_assets.py` 生成）：卡牌符文边框、敌人意图图标、标题暗角、面板饰条、圣杯瓶/卢恩图标；AI 生成示例 `assets/ai_test_bg.png`（tiny-sd CPU，见 `docs/superpowers/specs/2026-05-23-ai-asset-generation-record.md`）

### Game State Machine

`enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }` — each transition rebuilds layer children via `_clear()`.

### Combat Mechanics

- **Energy (集中):** 3 per turn (+1 per 3 集中属性, cap +2); card costs 0–3.
- **Hand size:** Base 5 per turn + memory stones + relic draw bonuses; reshuffle when draw pile empty.
- **Stance (姿态):** Enemy stance break opens a decision point — 处决 (big damage, ×1.5 with `starscourge_prosthesis`) or 防反 (block + 1 ember, and the enemy stays break_open for one more hit). Charge moves telegraph heavy hits and CAN be interrupted by a stance break; phase-2 enemies swap move sets below an HP threshold (玛尔基特 / 接肢贵族); NG+ mixes phase-2 moves into normal turns.
- **先手压制:** Normal fights, ≥3 attack cards on turn 1 → enemy stance halved (tempo compression).
- **Status:** 腐败 / 出血 (burst at 10, or 5 with 血君主之乐) / 易伤 (cap 3) / 力量.
- **Flask:** heals max(18, max_hp × 25%).
- **Meta-progression:** `ProfileService` — NG+ (enemy HP +25%/level, dmg +15%, souls +30%, phase-2 move mixing), vows Ⅰ–Ⅴ (破瓶/无恩之地/鲜血契约/苦行者 −1 抽牌/死荫 −20% HP), 誓言挑战 (无瓶/强敌), death echo (reclaim souls_earned/2 or convert to memory; memory ≥50 → starting card choice for 50 memory; memory ≥100 → starting relic choice).
- **Run length:** **12 floors** (3 acts × 4); act bosses on floors 4/8/12 (indices 3, 7, 11); final boss triggers `run_victory`.

## Recommended Next (see `docs/superpowers/plans/`)

1. ~~默认音效包~~（P0 已完成：`audio/*.ogg` + `audio_path_test.gd`）；第四幕（16 层）**暂缓**，不在近期计划内。
2. ~~Monte Carlo 平衡工具~~（P2 已完成：`tools/monte_carlo_balance.gd`）。
3. ~~预言家 Boss 平衡~~（P3 已完成：`black_flame` 入初始牌组，Boss 胜率 20%→76%）。
4. ~~普通战难度上调~~（已重定向：S11 先手压制 + S2 敌人个性压缩普通战节奏，难度预算集中在精英/Boss 与外循环修饰 [NG+/誓约/挑战]；贪心 bot 满资源单挑仍 ≈100% 属预期，一贫如洗 vs 玛尔基特 74%。详见 `docs/superpowers/specs/2026-08-17-design-review-soulslike-direction.md` 复测补记。）
5. ~~第三轮评审~~（M1–M12 全部实施：武器等级入 RunState+持久化、钩子卡吃武器倍率/攻击加成〈不吃属性补正，防 0 级 3 倍膨胀〉、接肢贵族 attack_rot+65% 二阶段、打断不重选蓄力、先手按实际伤害、属性描述/护符数值/誓约文案/祝福链重读、碎片 30+10×层、小圆盾统一结算、熔炉骑士/守墓斗士二阶段池。详见 `docs/superpowers/specs/2026-08-17-design-review-round3-structure-and-pipes.md` 第五节回执）。
6. 第四轮评审（创新提案）：B/C 簇已实施——I5 追忆二选一、I6 少女的引火、I4 大卢恩朝圣、I7 壶哥任务线、I8 癫火圣约、I9 杀死商人。剩余 P0：I1 死亡回响·死因解析、I2 血迹地图、I3 追忆决斗。详见 `docs/superpowers/specs/2026-08-17-design-review-round4-elden-content-and-learning-loops.md` 第七节回执。
7. 第五轮评审（持久成就、构筑共鸣与跨局传承）：J1 褪色者铭牌（留存引擎）、J2 构筑共鸣（跨局成长）、J3 祷告连锁（操作深度）、J4 武器技艺、J5 腐败灾厄、J6 半死状态、J7 前世遗物。待实施。详见 `docs/superpowers/specs/2026-08-17-design-review-round5-persistence-build-and-risk.md`。

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
godot4.6 --headless --path . --script tools/drag_test.gd
godot4.6 --headless --path . --script tools/sts_features_test.gd
godot4.6 --headless --path . --script tools/hitbox_test.gd
godot4.6 --headless --path . --script tools/multi_enemy_test.gd
godot4.6 --headless --path . --script tools/multi_enemy_ui_test.gd
godot4.6 --headless --path . --script tools/aoe_elite_test.gd
godot4.6 --headless --path . --script tools/targeting_line_test.gd
godot4.6 --headless --path . --script tools/leveling_service_test.gd
godot4.6 --headless --path . --script tools/damage_formula_test.gd
godot4.6 --headless --path . --script tools/smithing_test.gd
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
