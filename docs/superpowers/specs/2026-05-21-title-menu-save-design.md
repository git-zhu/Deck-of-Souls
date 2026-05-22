# 标题主菜单与 StS 式单槽存档 — 设计规格

**日期：** 2026-05-21  
**状态：** 待实现  
**参考：** 杀戮尖塔（Slay the Spire）单局高频快照模型  
**实现计划：** `docs/superpowers/plans/2026-05-21-title-menu-save.md`

---

## 1. 目标与范围

### 1.1 目标

1. 标题屏底栏三键：**开始游戏 / 新游戏**、**继续游戏**、**退出游戏**（布局 C）。  
2. **单槽**本地存档 `user://run_save.json`，保存整局进度，支持从**上次界面**恢复（含战斗中）。  
3. **高频自动存档**（对齐 StS）：地图、战斗、回合结束、奖励层、退出前。  
4. 有存档时首键文案为「**新游戏**」，继续独立；新游戏前 **Sts 式放弃确认**。

### 1.2 验收标准

| # | 标准 |
|---|------|
| T1 | 无存档：底栏为「开始游戏 \| 继续(禁用) \| 退出」 |
| T2 | 有存档：底栏为「新游戏 \| 继续 \| 退出」；继续直达读档界面 |
| T3 | 新游戏：确认放弃 → 出身 → 开局成功后旧档删除 |
| T4 | 退出游戏前写盘；再开可继续 |
| T5 | 地图 / 战斗中 / 商人或事件奖励层 关闭游戏后可恢复 |
| T6 | `save_roundtrip_test.gd`、`title_menu_test.gd` 无头通过；`smoke_test.gd` 适配新标题流 |

### 1.3 非目标

- 多存档槽、云存档  
- 设置页、手柄导航  
- 第四幕、`ACT_COUNT` 变更  
- 从 `GAME_OVER` / `VICTORY` 屏恢复（无效档视为无存档）

---

## 2. UI 设计（布局 C）

### 2.1 `TitleScreenView.build(...)`

参数：

- `has_save: bool`
- `on_new_game: Callable` — 无存档时「开始游戏」，有档时「新游戏」
- `on_continue: Callable`
- `on_quit: Callable`

结构：

- 上部：标题 + 副标题（沿用现文案）
- 底部 `HBoxContainer`：三等分按钮，最小高度 48–54px
- 「继续游戏」：`disabled = not has_save`，禁用时 `modulate` 灰化

### 2.2 新游戏确认

有存档且用户点「新游戏」时，`AcceptDialog`：

- 标题：「放弃当前进度？」
- 正文：「开始新游戏将覆盖现有存档。」
- 确认 → `_show_origin()`；取消 → 留标题屏

无存档点「开始游戏」→ 直接 `_show_origin()`。

### 2.3 退出游戏

- 导出/桌面：`get_tree().quit()`
- 退出前调用 `RunSaveService.save_snapshot(main)`（有进行中局时）

---

## 3. 存档模型（StS 式 RunSnapshot）

### 3.1 文件

- 路径：`user://run_save.json`
- 编码：UTF-8 JSON
- 顶层字段：`save_version`（当前 `1`）、`screen`、`run`、`combat`、`reward`、`log_lines`

### 3.2 `run` 对象

序列化 `RunState` 持久字段：

`run_seed`, `origin_id`, `hp`, `max_hp`, `flasks`, `max_flasks`, `souls`, `floor_index`, `deck`, `draw_pile`, `hand`, `discard_pile`, `exhaust_pile`, `player_rot`, `player_bleed`, `player_vulnerable`, `player_strength`, `relics`, `memory_stones`

### 3.3 `combat` 对象（`screen == COMBAT` 时必填）

`enemy`, `enemy_intent`, `ember`, `max_ember`, `block`, `combat_over`

### 3.4 `reward` 对象（`screen == REWARD` 时必填）

| `kind` | 恢复行为 | 额外字段 |
|--------|----------|----------|
| `merchant` | `RunRewardFlow` 恢复库存后 `show_merchant` | `merchant_stock`, `merchant_sold`, `merchant_status`, `merchant_cost_percent` |
| `event` | `RunFlowController.show_event` | `event_id` |
| `grace_result` | `build_centered_continue` + advance | `title`, `body` |
| `card_rewards` | `show_card_rewards` | `reward_card_ids`, `on_done_kind` |
| `relic_rewards` | `show_relic_rewards` | `relic_ids` |
| `act_clear` | `show_act_clear` | 同 card 奖励字段 |

实现时以**当前实际 reward 屏**为准，先覆盖 `merchant`、`event`、地图返回型 `grace_result`；其余 kind 在首次需要时补齐。

### 3.5 `log_lines`

`Array[String]`，最多 `GameTheme.MAX_LOG_LINES` 条。

### 3.6 校验

- `save_version` 不匹配或 JSON 损坏 → `has_save() == false`，可选删除坏档  
- `screen` 为 `ORIGIN`、`GAME_OVER`、`VICTORY` → 不恢复，清档

---

## 4. `RunSaveService`

`class_name RunSaveService` `extends RefCounted`

| API | 说明 |
|-----|------|
| `static func has_save() -> bool` | 文件存在且可解析且 `save_version` 合法 |
| `static func save_snapshot(main: Node) -> bool` | 从 Main 收集状态写盘 |
| `static func load_snapshot(main: Node) -> bool` | 读盘填充 Main/run/combat/reward_flow 并切屏 |
| `static func delete_save() -> void` | 删文件 |

`main` 为 `Main` 根节点；通过 `get()` 读取 `run_state`, `combat`, `screen`, `reward_flow`, `run_flow`, `log_lines` 等。

### 4.1 恢复路由

```
load_snapshot 成功
  → rng.seed = run.run_seed
  → match screen:
      MAP    → run_flow.show_map()
      COMBAT → combat 灌入 combat 字典 → Main._render_combat()
      REWARD → 按 reward.kind 分支恢复
```

---

## 5. 自动存档触发点（StS 粒度）

在下列操作**完成后**调用 `RunSaveService.save_snapshot(self)`：

1. `_enter_map_layer`（进入地图）
2. `_present_reward_layer`（进入奖励/事件/商人/赐福 UI）
3. `_begin_combat` 内 `combat.start_combat` 之后
4. 玩家结束回合：`CombatHudView` 改为调用 `Main._end_player_turn`（内部 `end_player_turn` + save）
5. 战斗胜利流程中进入下一屏前（`RunRewardFlow` 的 `show_card_rewards` / `show_merchant` 入口可选再存一次，与 2 重复可省略）
6. `_advance_floor_and_show_map` 之后（地图推进）
7. 退出游戏按钮：先 save 再 quit

**不存档：** 标题屏、出身屏、游戏结束/胜利屏。

**新局删档：** `_start_run` 在 `reset_for_origin` 成功后 `delete_save()`，不在确认弹窗瞬间删除。

---

## 6. 模块改动摘要

| 文件 | 变更 |
|------|------|
| `scripts/core/RunSaveService.gd` | 新建 |
| `scripts/ui/TitleScreenView.gd` | 底栏三键 + 禁用态 |
| `scripts/Main.gd` | 标题回调、继续、确认、autosave 挂钩、`_end_player_turn` |
| `scripts/ui/CombatHudView.gd` | 结束回合 Callable 来自 Main |
| `scripts/core/RunRewardFlow.gd` | 商人状态导出/恢复；`leave_merchant` 仍 advance+地图 |
| `tools/save_roundtrip_test.gd` | 新建 |
| `tools/title_menu_test.gd` | 新建 |
| `tools/smoke_test.gd` | 标题流改为「开始游戏」 |
| `CLAUDE.md` / `README.md` | 存档与标题说明 |

---

## 7. 测试

### 7.1 `save_roundtrip_test.gd`

- 构造 `RunState` + 伪 `combat` 字典 → `save` 到临时路径或 `user://` → 读回 → 断言 `floor_index`, `deck`, `enemy.hp`

### 7.2 `title_menu_test.gd`

- 实例化 `TitleScreenView`：`has_save=false` 时继续按钮 disabled；`has_save=true` 时 enabled

### 7.3 回归

- `smoke_test.gd`：标题后点「开始游戏」等价原「选择出身」

---

## 8. 决策记录

| 议题 | 决策 |
|------|------|
| 参考 StS | 单槽高频快照，继续=整局恢复 |
| 布局 | C 底栏三键 |
| 有档首键 | 「新游戏」非「开始游戏」 |
| 新游戏 | 确认放弃 → 出身 → 成功后删档 |
| 存档格式 | JSON `user://run_save.json` |
| 坏档 / 终局屏 | 视为无存档 |

---

## 9. Git

- 实现提交：`feat(game): title menu and StS-style run save`
- 实现后 **push** `origin main`
