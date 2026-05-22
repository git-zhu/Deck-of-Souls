# 阶段八：战后护符奖励 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase8-post-combat-relics-design.md`  
**状态：** 已实现（2026-05-21）

---

## 依赖

- `RelicService` / `RunState.relics` / `data/relics/*.tres`（阶段五）
- `CombatController.check_combat_end` / `Main._on_combat_ended`（阶段二幕末）

---

## Tasks

### Task 1: `RelicService.roll_relic_offers`

- [x] 新增 `roll_relic_offers(run, registry, rng, count=3) -> Array`（护符 id 字符串）
- [x] 池 = 未持有且 `registry.get_relic` 非空
- [x] `grant_random_relic` 复用 roll + `add_relic`

**验证：** `tools/relic_reward_test.gd` 第 1–3 条断言

---

### Task 2: `CombatController` 精英结束信号

- [x] `check_combat_end`：`elite == true` 时 `emit("elite_reward")`
- [x] `enemy` 字典键 `elite`（与 `DataRegistry` 一致）

---

### Task 3: 延后 `advance_floor` 的卡牌奖励

- [x] `_reward_card(card_id, on_done: Callable)`
- [x] `_show_card_rewards(on_done)` 替代 `_show_rewards`
- [x] `_show_act_clear(on_done)`

---

### Task 4: 护符奖励 UI

- [x] `_show_relic_rewards` / `_relic_reward_panel` / 放弃 / 池空跳过

---

### Task 5: `Main._on_combat_ended` 串联

- [x] `elite_reward` / `act_clear` 串联护符屏
- [x] `_finish_combat_rewards()` / 普通战不变

```text
elite_reward:
  _show_rewards( func(): _show_relic_rewards(roll..., _finish_combat_rewards) )

act_clear:
  _show_act_clear( func(): _show_relic_rewards(roll..., _finish_combat_rewards) )
```

---

### Task 6: 测试与文档

- [x] `tools/relic_reward_test.gd`
- [x] `CLAUDE.md` / spec 状态
- [x] **git commit:** `feat(game): phase 8 post-combat relic rewards for elite and act boss`

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 普通战斗胜利 | 仅卡牌奖励 → 进下一层 |
| 精英战斗胜利 | 卡牌 → 护符（0–3）→ 进下一层 |
| 幕末 Boss | 回满 + 卡牌 → 护符 → 进下一层 |
| 持有全部护符后精英战 | 仅卡牌，无护符屏 |
| 商人购买护符 | 仍即时 `grant_relic`，与战后池独立 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `scripts/core/RelicService.gd` | `roll_relic_offers` |
| `scripts/core/CombatController.gd` | `elite_reward` emit |
| `scripts/Main.gd` | 延后 advance、护符 UI、combat_ended 分支 |
| `tools/relic_reward_test.gd` | 新建 |
| `CLAUDE.md` | 测试命令 |
| `docs/superpowers/specs/2026-05-21-phase8-post-combat-relics-design.md` | 状态 |

**不改动：** `data/relics/*`（除非验收需要第 6 个护符）、地图生成、商人 offer
