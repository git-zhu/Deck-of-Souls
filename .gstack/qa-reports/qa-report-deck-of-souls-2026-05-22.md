# QA 报告 — Deck-of-Souls

| 字段 | 值 |
|------|-----|
| 日期 | 2026-05-22 |
| 模式 | Godot 4.6 headless（无 Web URL） |
| 分支 | main |
| 引擎 | `E:\Godot\Godot_v4.6.2-stable_win64.exe` |
| 冒烟 + 工具测试 | **18/18 通过** |

## 执行摘要

| 指标 | 值 |
|------|-----|
| 发现问题 | 8 |
| 已修复 | 8 |
| 健康分（估算） | **86 / 100** |

**PR 摘要：** QA 发现 8 项（含 1 项阻断编译），已修复 8 项；18 个 headless 脚本全绿，健康分约 78 → 86。

### Top 3 待手动确认

1. 编辑器运行 `Main.tscn`：赐福删牌、战灰替换、商人购牌 UI 是否可读。
2. 地图事件链（如 `limgrave_corpse` → `limgrave_corpse_cache`）是否按预期跳转。
3. 第三幕 `reward_cards` 是否均为非 starter 稀有度（已由 `balance_content_test` 校验）。

## 验证命令

```text
E:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . --script tools/smoke_test.gd
→ Smoke test passed

# 其余 17 个 tools/*_test.gd 均已在本轮 QA 中通过
```

## 已修复项

### ISSUE-001 — `RunFlowController.gd` 类型推断失败（Critical）

**现象：** `Main.gd` 无法编译，`smoke_test` 加载场景后 `run_flow` 为 Nil，赐福/地图/战斗流程全部失效。

**根因：** Godot 4.6 对 `host.get()` 返回值无法推断 `act` / `options` / `summary` 类型。

**修复：** 为 `ActData`、`Array`、`String` 添加显式类型注解。

**文件：** `scripts/core/RunFlowController.gd`

**状态：** verified

---

### ISSUE-002 — `relic_service_test` 断言逻辑反了（High）

**现象：** 第二次添加重复护符应返回 `false`，测试却在 `false` 时 `push_error`。

**修复：** 将 `if not add_relic(...)` 改为 `if add_relic(...)`。

**文件：** `tools/relic_service_test.gd`

**状态：** verified

---

### ISSUE-003 — `merchant_service_test` 重复声明 `stock`（High）

**现象：** 同函数内两次 `var stock` 导致解析错误。

**修复：** 内层循环变量改名为 `rolled`。

**文件：** `tools/merchant_service_test.gd`

**状态：** verified

---

### ISSUE-004 — `grace_service_test` 循环外使用 `opts`（Medium）

**现象：** `opts` 仅在 `for` 内声明，循环外赋值触发解析/作用域问题。

**修复：** 在循环前声明 `var opts: Array = []`。

**文件：** `tools/grace_service_test.gd`

**状态：** verified

---

### ISSUE-005 — 事件数量与幕间奖励池过时（Medium）

**现象：** `act_economy_test` 仍期望 12 个事件（实际 15）；三幕 `reward_cards` 含 starter 牌（`scimitar`、`catch_flame` 等），`balance_content_test` 失败。

**修复：**

- 事件数期望改为 15。
- `limgrave` / `liurnia` / `stormveil` 的 `reward_cards` 换为非 starter 卡。
- `act_economy_test` 使用 `origin.deck` 而非已废弃的 `starting_deck`。

**文件：** `data/acts/*.tres`, `tools/act_economy_test.gd`

**状态：** verified

---

### ISSUE-006 — `combat_hud_test` 调用不存在 API（Medium）

**现象：** `RelicService.load_from_registry` 不存在。

**修复：** 删除无效调用，使用 `CombatController` 内置 `relic_service`。

**文件：** `tools/combat_hud_test.gd`

**状态：** verified

---

### ISSUE-007 — 空 `moves` 导致 `choose_enemy_intent` 越界（Medium）

**现象：** `balance_content_test` 使用 `moves: []` 模板时控制台报错（测试仍打印 OK）。

**修复：** `CombatController.choose_enemy_intent` 对空 moves 回退默认攻击；测试模板补一条 move。

**文件：** `scripts/core/CombatController.gd`, `tools/balance_content_test.gd`

**状态：** verified

---

### ISSUE-008 — 工作区含未提交修复（Info）

**说明：** 本轮修复尚未提交；`git status` 有已修改的脚本与 `.tres`。提交前请跑一遍完整测试套件。

## 测试矩阵

| 脚本 | 结果 |
|------|------|
| smoke_test | 通过 |
| map_generator_test | 通过 |
| grace_service_test | 通过 |
| merchant_service_test | 通过 |
| relic_service_test | 通过 |
| memory_stone_test | 通过 |
| ash_service_test | 通过 |
| relic_reward_test | 通过 |
| act_content_test | 通过 |
| event_service_test | 通过 |
| balance_content_test | 通过 |
| act_economy_test | 通过 |
| ui_layout_test | 通过 |
| reward_ui_test | 通过 |
| combat_hud_test | 通过 |
| flow_screen_test | 通过 |
| event_chain_test | 通过 |
| content_pack_test | 通过 |

## 健康分（估算）

| 类别 | 分 | 说明 |
|------|-----|------|
| Functional | 85 | 编译与冒烟已恢复；需编辑器目视 |
| Console | 90 | headless 无脚本错误（修复空 moves 后） |
| Content | 88 | 15 事件 + 三幕奖励池与测试对齐 |
| UX | 80 | 未做浏览器/UI 截图（Godot 桌面项目） |

**加权合计 ≈ 86**

## 变更文件（本轮）

- `scripts/core/RunFlowController.gd`
- `scripts/core/CombatController.gd`
- `data/acts/limgrave.tres`, `liurnia.tres`, `stormveil.tres`
- `tools/relic_service_test.gd`, `grace_service_test.gd`, `merchant_service_test.gd`
- `tools/act_economy_test.gd`, `balance_content_test.gd`, `combat_hud_test.gd`

## 备注

- 本项目为 Godot 卡牌 roguelike，QA 以 headless 脚本为准，不使用 gstack browse。
- Godot 可执行文件不在 PATH；本地使用 `E:\Godot\Godot_v4.6.2-stable_win64.exe`。
- 若需提交：建议单条 commit，消息如 `fix(qa): restore compile, align act rewards and headless tests`。
