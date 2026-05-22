# 阶段十四：奖励层 UI 提取与 Main 瘦身 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase14-reward-ui-extraction-design.md`  
**状态：** 待实现

---

## Tasks

### Task 1: `GameTheme` 语义色（小改）

- [ ] 在 `GameTheme.gd` 增加 `TITLE_GOLD`、`BODY_MUTED`（或复用现有常量并导出别名）
- [ ] `RewardLayerViews` / 迁出代码使用常量，替换 `Main` 奖励层中的 `#e2bd65` / `#c8bca5` 魔法值

**验证：** `ui_layout_test` 仍通过

---

### Task 2: `RewardLayerViews.gd` 骨架 + 共享组件

- [ ] 新建 `scripts/ui/RewardLayerViews.gd`（`class_name RewardLayerViews`）
- [ ] `choice_offer_card(title, body, button_text, disabled, on_press) -> PanelContainer`
- [ ] `build_centered_continue(title, body, button_text, on_continue) -> Control`
- [ ] `card_reward_button(card: CardData, on_press) -> Button`（从 `_reward_card` 迁出）

**验证：** `reward_ui_test` 断言 `build_centered_continue`

---

### Task 3: 商人 + 赐福屏

- [ ] `build_merchant_screen(...)` + `merchant_offer_card(...)`
- [ ] `build_grace_rest(...)` + `grace_choice_card(...)`
- [ ] `Main._show_merchant` / `_show_grace_rest` 改为委托；删除 `_merchant_offer_card`、`_grace_choice_card`

**验证：** `merchant_service_test` + 手工进商人

---

### Task 4: 事件 + 结果页

- [ ] `build_event_screen(event, ...)`
- [ ] `build_centered_continue` 用于 `_show_event_result`、`_show_grace_result`、`_show_message_end`
- [ ] 删除三处重复 VBox 搭建

**验证：** `event_service_test` + 手工随机事件

---

### Task 5: 战后奖励 + 护符

- [ ] `build_card_rewards`（含幕末标题参数化）
- [ ] `build_relic_rewards` + `relic_reward_panel` 迁出
- [ ] `Main._show_card_rewards` / `_show_relic_rewards` / `_show_act_clear` 委托

**验证：** `relic_reward_test` + 精英战后流程

---

### Task 6: 选择器（删牌 / 战灰）

- [ ] `build_deck_picker(title, hint, counts, registry, on_removed)`
- [ ] `build_ash_picker(title, hint, card_ids, registry, on_picked)`
- [ ] `Main._show_remove_card_picker` / `_show_ash_replace_picker` 委托

**验证：** 赐福删牌、商人删牌、战灰替换冒烟

---

### Task 7: `Main._present_reward_layer` + 行数

- [ ] 提取 `_present_reward_layer(root: Control)` 统一 `reward_layer` 展示
- [ ] 确认 `Main.gd` ≤ **1050** 行

**验证：** `wc -l scripts/Main.gd` 或编辑器行数

---

### Task 8: 测试与文档

- [ ] 新建 `tools/reward_ui_test.gd`
- [ ] `CLAUDE.md` / `README.md` 更新
- [ ] spec 状态 → 已实现
- [ ] **git commit:** `feat(game): phase 14 extract reward-layer UI from Main`
- [ ] **git push**（钩子或代理手动执行）

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 商人购买 | 卢恩扣除、售罄、战灰/删牌子流程 |
| 赐福 | 三选一后回地图或结果页 |
| 战后 | 卡牌 → 护符（精英）→ 地图 |
| 幕末 | HP/瓶回满 + 选牌/护符 |
| smoke | 六出身视口仍通过 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `scripts/ui/RewardLayerViews.gd` | 新建（主要迁出） |
| `scripts/ui/GameTheme.gd` | 可选语义色常量 |
| `scripts/Main.gd` | 大幅删减，接线 `_present_reward_layer` |
| `tools/reward_ui_test.gd` | 新建 |
| `CLAUDE.md`, `README.md` | 文档 |
| `docs/superpowers/specs/2026-05-21-phase14-reward-ui-extraction-design.md` | 状态 |

---

## Git 工作流（本仓库约定）

每次阶段 **commit 后必须 push** 到 `origin`：

- 本地一次性：`.\scripts\setup-git-hooks.ps1`（设置 `core.hooksPath=.githooks`）
- 或代理在 commit 后显式执行：`git push`
