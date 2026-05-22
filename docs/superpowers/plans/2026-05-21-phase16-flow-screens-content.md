# 阶段十六：流程屏 UI 提取与内容扩展 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase16-flow-screens-content-design.md`  
**状态：** 已实现

---

## Tasks

### Task 1: `DeckUtils` + 流程屏骨架

- [ ] 新建 `scripts/ui/DeckUtils.gd`（`card_counts`）
- [ ] 新建 `TitleScreenView.gd`、`EndScreenView.gd`
- [ ] `Main._show_title` / `_show_game_over` / `_show_victory` 委托
- [ ] `flow_screen_test`：断言标题屏「选择出身」、结算屏按钮

**验证：** `flow_screen_test` 通过

---

### Task 2: `OriginScreenView` + `MapScreenView`

- [ ] 新建 `OriginScreenView.gd`（含 `origin_card`）
- [ ] 新建 `MapScreenView.gd`
- [ ] `Main` 删除 `_origin_card`、内联 `_show_origin` / `_show_map` UI
- [ ] `smoke_test` 仍通过

**验证：** 六出身冒烟 + 地图三卡徽章仍可见

---

### Task 3: `DeckPopupView`

- [ ] 新建 `DeckPopupView.gd`
- [ ] `Main._show_deck_view` → `DeckPopupView.show(self, ...)`
- [ ] `RewardLayerViews.build_deck_picker` 可选改用 `DeckUtils.card_counts`（若仍重复则改）

**验证：** 冒烟中打开牌组弹窗不报错

---

### Task 4: 行数检查点

- [ ] `Main.gd` 仅路由 + 业务，无流程屏内联 UI
- [ ] 行数 ≤ **500**（UI 迁出后）

---

### Task 5: 事件链数据与逻辑

- [ ] `MapEventChoiceData.follow_event_id`
- [ ] `build_events.py` 输出字段 + 3 条链（6 个 event 资源：3 入口改 choice + 3 新 follow 屏）
- [ ] `Main._on_event_choice`：有 `follow_event_id` → `_show_event(next)`，否则原逻辑
- [ ] `build_acts.py` 确认入口 event id 仍在各幕 `event_ids`

**验证：** `event_chain_test.gd`

---

### Task 6: +3 敌人

- [ ] `data/enemies/tree_sentinel.tres`、`misbegotten.tres`、`fallingstar_beast.tres`
- [ ] `tools/build_enemies.py` 补 `ENEMY_STATS`
- [ ] `tools/build_acts.py` 遭遇池 + `COMBAT_META`/`ELITE_META` 文案
- [ ] `python tools/build_acts.py`（若改 acts）

**验证：** `content_pack_test.gd`（敌人 ≥18）

---

### Task 7: 文档与 Git

- [ ] `CLAUDE.md` / `README.md` 更新
- [ ] spec / plan → 已实现
- [ ] **git commit:** `feat(game): phase 16 flow screen views, event chains, and three enemies`
- [ ] **git push**

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 标题 → 出身 → 地图 | 布局与改前一致 |
| 遗骸链 | 搜刮后进第二屏，继续才进下一层 |
| 新敌人 | 地图池能随到大树守卫/狮子混种/坠星兽 |
| smoke | 视口、赐福、战斗仍 OK |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `scripts/ui/*ScreenView.gd` ×5 | 新建 |
| `scripts/ui/DeckUtils.gd` | 新建 |
| `scripts/Main.gd` | 大幅删减 |
| `data/MapEventChoiceData.gd` | +字段 |
| `data/events/*.tres` | 链相关再生/新增 |
| `data/enemies/*.tres` | +3 |
| `tools/build_*.py` | 敌人/事件/幕 |
| `tools/flow_screen_test.gd` 等 | 新建 |
| 文档 | 更新 |

---

## Git 工作流

commit 后 **`git push origin main`**。
