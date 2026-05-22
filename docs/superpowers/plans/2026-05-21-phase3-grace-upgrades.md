# 阶段三：赐福升级 — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Checkboxes track progress.

**Goal:** 赐福节点改为营火式三选一；选项数据化；移除自动购买《命定之死》。

**Architecture:** `GraceOptionData` + `GraceService`（抽池/资格/应用）；`DataRegistry` 加载选项；`Main` 赐福 UI 与删牌子流程。

**Tech Stack:** Godot 4.6, GDScript, Resource

**Spec:** `docs/superpowers/specs/2026-05-21-phase3-grace-upgrades-design.md`

**Prerequisite:** 阶段二完成（`docs/superpowers/plans/2026-05-21-phase2-three-act-map.md`）

---

## File map

| File | Action |
|------|--------|
| `data/GraceOptionData.gd` | Create |
| `data/grace_options/*.tres` | Create ×6 |
| `scripts/core/GraceService.gd` | Create |
| `scripts/core/DataRegistry.gd` | Load grace options |
| `scripts/Main.gd` | Replace `_visit_grace`, add grace UI |
| `tools/grace_service_test.gd` | Create headless test |
| `tools/smoke_test.gd` | Adjust grace step |
| `README.md`, `CLAUDE.md` | Document phase 3 |

---

### Task 1: GraceOptionData 资源类型

**Files:**
- Create: `data/GraceOptionData.gd`

- [ ] **Step 1: 定义 Resource**

```gdscript
class_name GraceOptionData
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var effect: String = ""
@export var effect_value: int = 0
@export var soul_cost: int = 0
@export var card_id: String = ""
@export var min_deck_size: int = 6
```

- [ ] **Step 2: Commit**

```bash
git add data/GraceOptionData.gd
git commit -m "feat(data): GraceOptionData resource"
```

---

### Task 2: 六张赐福选项 .tres

**Files:**
- Create: `data/grace_options/rest.tres`, `vitality.tres`, `kindling.tres`, `purge.tres`, `clarity.tres`, `destined_death.tres`

- [ ] **Step 1: 按 spec §2.3 填写各文件**（中文 title/body，UTF-8；用编辑器或 Python 脚本生成，避免 PowerShell 破坏编码）

| 文件 | id | effect | effect_value | soul_cost | card_id |
|------|-----|--------|--------------|-----------|---------|
| rest | rest | heal_percent | 35 | 0 | |
| vitality | vitality | max_hp | 8 | 0 | |
| kindling | kindling | max_flasks | 1 | 0 | |
| purge | purge | remove_card | 0 | 0 | |
| clarity | clarity | clear_debuffs | 0 | 0 | |
| destined_death | destined_death | add_card | 0 | 45 | destined_death |

- [ ] **Step 2: Commit**

```bash
git add data/grace_options/
git commit -m "feat(data): six grace upgrade options"
```

---

### Task 3: GraceService

**Files:**
- Create: `scripts/core/GraceService.gd`

- [ ] **Step 1: 实现 `load_from_registry(registry)`** — 缓存 `Array` 全部选项

- [ ] **Step 2: `is_eligible(option, run)`**
  - `purge`: `run.deck.size() > option.min_deck_size`
  - `destined_death`: `run.souls >= option.soul_cost` 且 `not run.deck.has(option.card_id)`
  - `kindling`: `run.max_flasks < 5`
  - 其余：true

- [ ] **Step 3: `roll_options(run, rng, count=3)`**
  - 过滤 eligible → shuffle → slice(0, count)
  - 若结果中无 `heal_percent` 且池内有 eligible `rest`，将最后一个槽替换为 `rest`（保证有恢复手段）

- [ ] **Step 4: `apply(option, run) -> String`**
  - 实现 spec §3.2 各 effect
  - `remove_card` 返回 `""` 并由 Main 处理（或返回 `"__pick_card__"` 约定）

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GraceService.gd
git commit -m "feat(core): GraceService roll and apply"
```

---

### Task 4: DataRegistry 加载

**Files:**
- Modify: `scripts/core/DataRegistry.gd`

- [ ] **Step 1: `var grace_options: Dictionary = {}`**

- [ ] **Step 2: `_load_grace_options()`** — 扫描 `res://data/grace_options/*.tres`

- [ ] **Step 3: `get_grace_option(id) -> GraceOptionData`**

- [ ] **Step 4: `all_grace_option_ids() -> Array`**

- [ ] **Step 5: `load_all()` 调用 `_load_grace_options()`**

- [ ] **Step 6: Commit**

```bash
git add scripts/core/DataRegistry.gd
git commit -m "feat(core): registry loads grace options"
```

---

### Task 5: Main 赐福 UI 与流程

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: 成员 `var grace_service: GraceService`；`_ready` 中 `grace_service.load_from_registry(registry)`**

- [ ] **Step 2: 替换 `_visit_grace()`**

```gdscript
func _visit_grace() -> void:
	var options := grace_service.roll_options(run_state, rng, 3)
	_show_grace_rest(options)
```

- [ ] **Step 3: `_show_grace_rest(options)`** — 三列选项卡，类似 `_map_choice_card` 布局

- [ ] **Step 4: `_on_grace_option_picked(option)`**
  - `remove_card` → `_show_grace_remove_card()`
  - 否则 `summary = grace_service.apply(...)` → `_show_grace_result(option.title, summary)`

- [ ] **Step 5: `_show_grace_result` / 继续按钮** — `run_state.advance_floor()` 后 `_show_map()`

- [ ] **Step 6: `_show_grace_remove_card()`** — 牌组列表删 1 张 → 结果 → advance_floor

- [ ] **Step 7: 删除旧自动 `heal_player(18)` 与自动买命定之死逻辑**

- [ ] **Step 8: （可选）`func _test_grace_pick(option_id: String)`** 供 smoke 调用

- [ ] **Step 9: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat(ui): grace rest three-choice flow"
```

---

### Task 6: Headless 测试

**Files:**
- Create: `tools/grace_service_test.gd`
- Modify: `tools/smoke_test.gd`

- [ ] **Step 1: `grace_service_test.gd`**

```gdscript
extends SceneTree
# load registry + GraceService
# apply vitality → assert max_hp increased by 8
# roll_options with deck size 5 → no purge in results
# print passed + quit()
```

- [ ] **Step 2: 更新 `smoke_test.gd`**

将 `main.call("_visit_grace")` 改为 `main.call("_test_grace_pick", "rest")` 或模拟选第一项；仍断言 HP 上升。

- [ ] **Step 3: 运行**

```bash
godot4.6 --headless --path . --script tools/grace_service_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

- [ ] **Step 4: Commit**

```bash
git add tools/grace_service_test.gd tools/smoke_test.gd
git commit -m "test: grace service and smoke grace pick"
```

---

### Task 7: 文档

**Files:**
- Modify: `README.md`, `CLAUDE.md`

- [ ] **Step 1: README「已实现」加入赐福三选一**

- [ ] **Step 2: CLAUDE.md 增加 `GraceService` 行与 grace 测试命令**

- [ ] **Step 3: spec 状态改为「阶段三已实现」**（实现完成后）

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md docs/superpowers/specs/2026-05-21-phase3-grace-upgrades-design.md
git commit -m "docs: phase 3 grace upgrades spec shipped"
```

---

## Plan self-review

| Spec § | Task |
|--------|------|
| §2.3 六选项 | Task 2 |
| §3.1 GraceService | Task 3 |
| §3.3 UI 三选一 | Task 5 |
| §3.6 测试 | Task 6 |
| 非目标（商人/护符） | 无任务 |

**估计工作量：** 约 4–6 个 focused commit；单会话可完成。

---

## 实现后验收清单

- [ ] 进赐福见 3 选项，选 1 后进下一层地图
- [ ] 卢恩 &lt; 45 时不会出现「窥见命定之死」
- [ ] 牌组 ≤5 时不出现「遗忘仪式」
- [ ] 圣杯瓶最多 5 个
- [ ] `grace_service_test` + `smoke_test` 通过
