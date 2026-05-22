# 阶段五：护符（Relic）— 设计规格

**日期：** 2026-05-21  
**状态：** 阶段五已实现（2026-05-21）  
**前置：** 阶段四商人咖列  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase5-relics.md`

---

## 1. 目标

跑团内持久持有 **护符**（`RunState.relics: Array[String]`），在战斗开始/获得时触发效果；替换商人「褪色者护符」的临时 `player_strength` 占位。

## 2. 验收

- `RelicData` + `data/relics/*.tres`（≥5）
- `RelicService`：`add_relic`、`apply_combat_start`、`on_acquire` 效果
- `CombatController` 战斗开始应用护符（力量/集中/额外抽牌）
- 商人 `scrap_paper` 改为 `grant_relic`（随机未持有护符）
- Header 或牌组旁显示护符数量；`tools/relic_service_test.gd` 通过

## 3. 非目标

记忆石、战灰、战斗后三选一送护符、重复护符叠加

## 4. 首版护符

| id | 名 | hook | value |
|----|-----|------|-------|
| serpentbone_talisman | 蛇骨护符 | combat_strength | 1 |
| crimson_amulet | 深红护符 | on_acquire_max_hp | 10 |
| cerulean_medallion | 蔚蓝勋章 | combat_extra_ember | 1 |
| ancestral_spirit | 祖灵骨灰瓶 | combat_extra_draw | 1 |
| greatshield_talisman | 大盾护符 | combat_start_block | 4 |

## 5. 模块

`RelicService` + `DataRegistry._load_relics()`；`RunState.relics` 在 `reset_for_origin` 清空。
