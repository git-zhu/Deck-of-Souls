# 阶段十七a：RunFlowController — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段十六（`RunRewardFlow`、流程屏 UI）

---

## 1. 目标

将 `Main.gd` 中的**地图 / 事件 / 战斗入口 / 战后路由**迁至 `RunFlowController`，与已有 `RunRewardFlow`（商人 / 赐福 / 战后选牌）对称。

## 2. 范围

### 迁入 `RunFlowController`

- `show_map` / `choose_map_option`
- `visit_event` / `show_event` / `on_event_choice` / `show_event_result` / `advance_floor_and_show_map`
- `begin_combat`（委托 `Main._begin_combat`）
- `on_combat_ended`

### 保留在 `Main`

- UI 层搭建、`_enter_map_layer`、`_present_reward_layer`、`_render_combat`
- 标题 / 出身 / 结算屏
- 日志、测试钩子（`_choose_map_option` 等薄转发）

## 3. 验收

| # | 标准 |
|---|------|
| R1 | 存在 `scripts/core/RunFlowController.gd`（`class_name`） |
| R2 | `Main` 无内联地图选项 match / 事件 apply 逻辑 |
| R3 | `tools/run_flow_test.gd` 无头通过 |
| R4 | `smoke_test.gd` 仍通过 |

## 4. 非目标

- 第四幕、`ACT_COUNT` 变更
- 默认音效包

---

## 5. Git

- 提交：`feat(game): extract RunFlowController for map event and combat routing`
- **提交后 push**
