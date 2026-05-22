# 阶段十三：UI 可读性抛光与主题模块提取 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase13-ui-polish-design.md`  
**状态：** 已实现

---

## Tasks

### Task 1: `GameTheme.gd`

- [x] 新建 `scripts/ui/GameTheme.gd`（`class_name GameTheme`）
- [x] 调色板常量 + `apply_theme(root: Control)`
- [x] `map_kind_meta(kind: String) -> Dictionary`
- [x] `intent_color(kind: String) -> Color`
- [x] `card_disabled_modulate() -> Color`

**验证：** `ui_layout_test` 元数据断言

---

### Task 2: `UiBuilders.gd`

- [x] 新建 `scripts/ui/UiBuilders.gd`（`class_name UiBuilders`）
- [x] 迁移：`panel`、`fighter_panel`（含姿态低警告边框）、`small_stat`
- [x] 迁移：`map_choice_card(option, on_press)` — 类型徽章 + accent 边框
- [x] 迁移：`card_button(card, index, combat, on_play)` — disabled + modulate

**验证：** 编译无循环依赖；`Main` 删除原 `_panel` 等重复实现

---

### Task 3: `Main.gd` 接线

- [x] `_build_ui` / `_setup_theme` → `GameTheme.apply_theme`
- [x] `_map_choice_card` → `UiBuilders.map_choice_card`
- [x] `_render_combat`：意图 Label 使用 `GameTheme.intent_color`
- [x] 手牌行改用 `UiBuilders.card_button`
- [x] 战士面板改用 `UiBuilders.fighter_panel`
- [x] 赐福/商人/事件等屏 `_panel` → `UiBuilders.panel`

**验证：** 行数 ≤ 1200（约）；游戏可跑通标题→出身→地图→战斗

---

### Task 4: 战斗日志截断

- [x] `GameTheme.MAX_LOG_LINES`（12）
- [x] `_log` 入队时裁剪

**验证：** 手工快速出牌+结束回合，日志不无限增高

---

### Task 5: 测试与文档

- [x] 新建 `tools/ui_layout_test.gd`
- [x] `CLAUDE.md` / `README.md` 更新
- [x] spec 状态 → 已实现
- [ ] **git commit:** `feat(game): phase 13 UI polish and theme module extraction`

> 注：`Main.gd` 约 1430 行（奖励/赐福屏未迁出）；核心构建器已提取。

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 地图 | 三卡均有「战斗/事件/赐福」等徽章 |
| 0 集中 | 手牌灰化且不可点 |
| 意图 | 攻击意图偏红 |
| smoke | 六出身视口检查仍通过 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `scripts/ui/GameTheme.gd` | 新建 |
| `scripts/ui/UiBuilders.gd` | 新建 |
| `scripts/Main.gd` | 迁出构建器 + 日志截断 + 意图色 |
| `tools/ui_layout_test.gd` | 新建 |
| `CLAUDE.md`, `README.md` | 文档 |

---

## 实现顺序

1. Task 1 → 2（主题 + 构建器，可单测 `map_kind_meta`）  
2. Task 3（Main 接线，先地图+战斗）  
3. Task 4（日志）  
4. Task 5（测试、文档、commit）

预计 **单会话** 可完成（改动集中、无数据管线）。
