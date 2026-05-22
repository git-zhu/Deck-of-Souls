# 阶段十一：平衡调优与内容扩充 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase11-balance-content-design.md`  
**状态：** 已实现

---

## Tasks

### Task 1: 按幕 HP 缩放

- [x] `ActData.enemy_hp_percent: int = 100`
- [x] `build_acts.py` 输出三幕 100 / 110 / 125
- [x] `CombatController.start_combat` 应用缩放

**验证：** `balance_content_test` 缩放断言

---

### Task 2: `tools/build_enemies.py`

- [x] 从现有敌人提取/整理 Python 表（name, hp, souls）
- [x] 按 §3.2 调整 normal/elite/boss 的 hp/souls
- [x] patch `data/enemies/*.tres` 的 `max_hp`/`souls`

> 若全量再生 moves 风险高，**最小方案**：脚本仅批量改 `max_hp`/`souls` 行，或 Python 只输出覆盖表 + 手工确认 2 个 Boss。

---

### Task 3: 修正 `reward_cards`

- [x] `build_acts.py` 去掉 starter id，加入新卡 id
- [x] `balance_content_test`：扫描三幕 reward_cards vs registry rarity

---

### Task 4: 护符 +3 与 `combat_souls_bonus`

- [x] `build_relics.py` 追加 3 条
- [x] `RelicService.combat_souls_bonus(run, registry) -> int`
- [x] `CombatController.check_combat_end` 胜利时加卢恩

---

### Task 5: 卡牌 +4

- [x] 新建 `data/cards/{rock_sling,flame_grant_me_strength,glintstone_stars,hoarfrost_stomp}.tres`
- [x] `CardEffectResolver` catalog + `GAIN_STRENGTH` kind
- [x] 写入 `build_acts.py` reward_cards

---

### Task 6: 测试与文档

- [x] `tools/balance_content_test.gd`
- [x] `CLAUDE.md` / `README.md`
- [x] spec 状态 → 已实现
- [ ] **git commit:** `feat(game): phase 11 balance scaling, soul tuning, and content expansion`

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 幕 1 野狼 | HP ×1.0 |
| 幕 3 普通战 | HP ×1.25 |
| 战后选牌 | 无「长剑」类 starter 重复泛滥 |
| 精英战后 | 卢恩 + 护符 + 可购物 |
| 新护符 | 金粪金龟战斗结束 +5 卢恩 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `data/ActData.gd` | `enemy_hp_percent` |
| `data/acts/*.tres` | 再生 |
| `data/enemies/*.tres` | 数值（build 脚本） |
| `data/relics/*.tres` | +3 |
| `data/cards/*.tres` | +4 |
| `scripts/core/CombatController.gd` | HP 缩放 + souls bonus |
| `scripts/core/RelicService.gd` | `combat_souls_bonus` |
| `tools/build_enemies.py` | 新建 |
| `tools/build_relics.py` | 扩展 |
| `tools/build_acts.py` | reward_cards |
| `tools/balance_content_test.gd` | 新建 |
