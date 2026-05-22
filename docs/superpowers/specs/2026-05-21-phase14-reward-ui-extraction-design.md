# 阶段十四：奖励层 UI 提取与 Main 瘦身 — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段一至十三（含 `GameTheme` / `UiBuilders`）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase14-reward-ui-extraction.md`

---

## 1. 目标与范围

### 1.1 问题

阶段十三已将地图卡、战斗 HUD 迁入 `scripts/ui/`，但 `scripts/Main.gd` 仍约 **1430 行**。大量 **奖励层**（`reward_layer`）界面仍内联在 `Main`：

| 区域 | 约行数 | 重复模式 |
|------|--------|----------|
| 商人 `_show_merchant` / `_merchant_offer_card` | ~120 | 标题 + 三列选项卡 + 底部按钮 |
| 赐福 `_show_grace_rest` / `_grace_choice_card` | ~90 | 同上 |
| 事件 `_show_event` / `_show_event_result` | ~90 | 选项列表 / 居中结果页 |
| 战后奖励 `_show_card_rewards` / `_show_relic_rewards` / `_show_act_clear` | ~180 | 横排奖励卡 + skip |
| 通用 `_show_remove_card_picker` / `_show_ash_replace_picker` / `_show_message_end` / `_show_grace_result` | ~200 | 滚动列表 / 战灰三选一 / 继续按钮 |

业务回调（`grace_service.apply`、`merchant_service.purchase`、`event_service.apply`）必须留在 `Main`；**仅迁 UI 构建**。

### 1.2 目标

1. 新增 `scripts/ui/RewardLayerViews.gd`（`class_name RewardLayerViews`），集中奖励层布局。  
2. 抽取共享组件：`choice_offer_card`（商人/赐福三列卡）、`centered_message`（事件结果/赐福结果/通用消息）、`card_reward_row`、`relic_reward_row`、`deck_card_picker`、`ash_replace_row`。  
3. `Main.gd` 只调用静态构建器并连接 `Callable`；行数目标 **≤ 1050**（净迁出 ≥ 350 行）。  
4. 颜色/字号沿用 `GameTheme`；不新增硬编码色值（除 `GameTheme` 已有常量）。  
5. 行为与阶段十三一致：无新玩法、无 `.tscn`、无音效。

### 1.3 验收标准

| # | 标准 |
|---|------|
| R1 | 存在 `RewardLayerViews.gd`；`Main` 无 `_merchant_offer_card`、`_grace_choice_card`、`_relic_reward_panel`、`_reward_card` 内联实现 |
| R2 | 商人/赐福/事件/战后卡牌/护符/幕末/删牌/战灰/消息结束屏均由 `RewardLayerViews` 构建 |
| R3 | `Main.gd` 行数 ≤ 1050 |
| R4 | `tools/smoke_test.gd`、`tools/ui_layout_test.gd` 仍通过 |
| R5 | 新建 `tools/reward_ui_test.gd`：无头构建商人屏根节点、赐福选项卡、护符面板，断言子节点数与标题文案 |
| R6 | 实现后 **git commit** 并 **git push**（见仓库 Git 工作流） |

### 1.4 非目标（YAGNI）

- 音效 / BGM（阶段十五候选）  
- 拆分 `Main.tscn` 或多场景  
- 新敌人、新事件、新护符数据  
- 重写 `_render_combat`（留在 `Main` 或后续阶段）  
- 标题/出身/地图/Deck 查看屏（本阶段仅 `reward_layer` 族）  

---

## 2. 模块设计

### 2.1 `RewardLayerViews.gd`

`extends RefCounted`，`preload` `GameTheme`、`UiBuilders`、`CardData`、`RelicData`、`MerchantOfferData`、`GraceOptionData`、`RelicService`（仅 `hook_summary` 文案）。

**上下文对象**（减少参数列表）：

```gdscript
class RewardUiContext:
    var registry: DataRegistry
    var run_state: RunState
    var relic_service: RelicService  # 仅护符 hook 摘要
```

**静态 API（建议）**

| 方法 | 返回 | 说明 |
|------|------|------|
| `build_merchant_screen(ctx, stock, sold, cost_percent, status, on_buy, on_leave)` | `Control` | 根 `VBox`；`on_buy(offer, slot_index)` |
| `merchant_offer_card(offer, slot_index, sold, cost_percent, merchant_service, run_state, on_buy)` | `PanelContainer` | 从 `Main._merchant_offer_card` 迁出 |
| `build_grace_rest(ctx, options, on_pick)` | `Control` | 三列赐福卡 |
| `grace_choice_card(option, on_pick)` | `PanelContainer` | |
| `build_event_screen(event, ctx, event_service, on_choice)` | `Control` | 禁用态由 `event_service.is_choice_eligible` |
| `build_card_rewards(card_ids, registry, on_pick, on_skip)` | `Control` | 战后/幕末选牌 |
| `build_relic_rewards(relic_ids, ctx, on_pick, on_skip)` | `Control` | |
| `build_deck_picker(title, hint, deck_counts, registry, on_removed)` | `Control` | 滚动删牌列表 |
| `build_ash_picker(title, hint, card_ids, registry, on_picked)` | `Control` | 三战灰按钮 |
| `build_centered_continue(title, body, button_text, on_continue)` | `Control` | 事件结果/赐福结果/消息结束 |

`Main` 保留：

```gdscript
func _show_merchant() -> void:
    screen = GameScreen.REWARD
    _present_reward_layer(RewardLayerViews.build_merchant_screen(...))
```

新增薄封装 `_present_reward_layer(root: Control)`：`reward_layer` 清空 → `_build_header()` → `add_child(root)`，避免每个 `_show_*` 重复 6 行。

### 2.2 与 `UiBuilders` 边界

| 模块 | 职责 |
|------|------|
| `UiBuilders` | 战斗 HUD、地图三选一、通用 `panel` / `fighter_panel` / `card_button` |
| `RewardLayerViews` | 仅 `reward_layer` 全屏流（商人/赐福/事件/战后奖励/选择器） |

共享：`UiBuilders.panel`、`GameTheme` 标题色 `#e2bd65` / `#e0c06c` 改为 `GameTheme.TITLE_GOLD` 常量（若尚未存在则在本阶段补 1～2 个语义常量，避免魔法字符串散落）。

### 2.3 `Main.gd` 瘦身清单

**删除或改为单行委托：**

- `_merchant_offer_card`、`_grace_choice_card`、`_relic_reward_panel`、`_reward_card`
- `_show_merchant` / `_show_grace_rest` / `_show_event` 内联 `VBox` 搭建
- `_show_event_result`、`_show_grace_result`、`_show_message_end` 重复居中布局
- `_show_remove_card_picker`、`_show_ash_replace_picker` 列表搭建
- `_show_card_rewards`、`_show_relic_rewards`、`_show_act_clear` 横排奖励 UI

**保留在 `Main`：**

- `_on_merchant_buy`、`_on_grace_option_picked`、`_on_event_choice`、`_start_ash_replace_flow`、战斗奖励链 `_finish_combat_rewards` 等 **状态变更**  
- `_render_combat`、`_show_map`、`_show_title`、`_show_origin`、`_show_deck_view`  

---

## 3. 测试

### 3.1 `tools/reward_ui_test.gd`

- 构造最小 `RunState` + mock `registry`（或加载真实 `DataRegistry` 单例路径）  
- `build_merchant_screen`：断言子树含「商人咖列」「离开商店」  
- `grace_choice_card`：断言 `PanelContainer` 含「选择」按钮  
- `build_centered_continue`：断言「继续」按钮存在  

### 3.2 回归

```bash
godot4.6 --headless --path . --script tools/reward_ui_test.gd
godot4.6 --headless --path . --script tools/ui_layout_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

---

## 4. 手工检查（1280×720）

| 场景 | 预期 |
|------|------|
| 商人 | 三货卡、卢恩价、售罄灰掉；离开回地图 |
| 赐福 | 三选项；选删牌/战灰子流程正常 |
| 精英战后 | 选牌 → 护符 → 地图 |
| 幕末 | 回满 HP/瓶；选牌或跳过 → 护符流 |
| 事件 | 卢恩不足选项 disabled |

---

## 5. 文档与 Git

- 更新 `CLAUDE.md`：`RewardLayerViews` 表项、`reward_ui_test` 命令、`Main` 行数目标  
- 更新 `README.md` 阶段列表  
- 提交：`feat(game): phase 14 extract reward-layer UI from Main`  
- **提交后执行 `git push`**（本地已配置 `.githooks/post-commit` 时自动推送）

---

## 6. 后续（阶段十五候选）

- `CombatHudView.gd`：迁出 `_render_combat`，`Main` **<800 行**  
- `GameAudio.gd`：按钮/胜利短音效钩子（可选静音）  
- 内容：+3 敌人、事件链 `next_event_id`  

---

## 7. 决策记录

| 议题 | 决策 |
|------|------|
| 单文件 vs 多 View | 首版 **单文件 `RewardLayerViews`**，避免过度拆分 |
| `RewardUiContext` | 护符屏需要 `relic_service`；商人需要 `merchant_service` 作参数传入，不塞进全局单例 |
| `GameScreen.REWARD` 复用 | 商人/赐福/事件仍用 `REWARD` 枚举，不新增屏幕类型 |
| 行数目标 | **1050** 务实值（战斗/地图仍在 Main） |
