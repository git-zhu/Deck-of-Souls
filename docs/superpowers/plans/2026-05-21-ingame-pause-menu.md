# 局内暂停菜单与顶栏 UI — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 局内顶栏 `☰` 打开全屏暂停菜单（继续 / 返回标题+存档 / 放弃本局），并调整顶栏与「查看牌组」布局。

**Architecture:** 新建 `RunPauseMenuView`；`RunHeaderView` 增加 `on_pause_menu` 与 `☰` 按钮；`Main` 管理 overlay 生命周期与存档回调。

**Tech Stack:** Godot 4.6 GDScript，现有 `RunSaveService`、`RunHeaderView`、`Main.GameScreen`。

**设计规格：** `docs/superpowers/specs/2026-05-21-ingame-pause-menu-design.md`

---

### Task 1: RunPauseMenuView

**Files:**
- Create: `scripts/ui/RunPauseMenuView.gd`

- [ ] **Step 1: 实现 `build(on_resume, on_return_title, on_abandon_run) -> Control`**

```gdscript
class_name RunPauseMenuView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")

static func build(on_resume: Callable, on_return_title: Callable, on_abandon_run: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	# center panel + VBox: 继续游戏 / 返回标题 / 放弃本局
	# each button.pressed.connect(...)
	return root
```

- [ ] **Step 2: 按钮宽度约 280px，居中**

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/RunPauseMenuView.gd
git commit -m "feat(ui): add RunPauseMenuView"
```

---

### Task 2: RunHeaderView 顶栏

**Files:**
- Modify: `scripts/ui/RunHeaderView.gd`
- Modify: `scripts/Main.gd` (`_build_header`)

- [ ] **Step 1: 扩展 `build` 签名**

```gdscript
static func build(
	header: HBoxContainer,
	run_state: RunState,
	registry: DataRegistry,
	is_combat_screen: bool,
	on_deck_view: Callable,
	on_pause_menu: Callable
) -> Dictionary  # {"deck": Button, "menu": Button}
```

- [ ] **Step 2: 删除战斗屏抽弃牌 `small_stat` 块**（`is_combat_screen` 分支内原 29–34 行）

- [ ] **Step 3: 操作区**

```gdscript
var actions := HBoxContainer.new()
actions.add_theme_constant_override("separation", 8)
# deck_button ...
var menu_button := Button.new()
menu_button.text = "☰"
menu_button.tooltip_text = "选项"
menu_button.custom_minimum_size = Vector2(40, 34)
menu_button.pressed.connect(on_pause_menu)
actions.add_child(deck_button)
actions.add_child(menu_button)
header.add_child(actions)
```

- [ ] **Step 4: Main `_build_header` 传入 `_show_pause_menu`**

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/RunHeaderView.gd scripts/Main.gd
git commit -m "feat(ui): header menu icon and combat stat trim"
```

---

### Task 3: Main 暂停逻辑

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: 成员 `var pause_overlay: Control = null`**

- [ ] **Step 2: `_show_pause_menu()`**

```gdscript
func _show_pause_menu() -> void:
	if pause_overlay != null:
		return
	pause_overlay = RunPauseMenuView.build(
		_hide_pause_menu,
		_on_pause_return_title,
		_on_pause_abandon_run
	)
	add_child(pause_overlay)
```

- [ ] **Step 3: `_hide_pause_menu()`** — free overlay，置 null

- [ ] **Step 4: `_on_pause_return_title()`** — `_maybe_autosave()` → hide → `_show_title()`

- [ ] **Step 5: `_on_pause_abandon_run()`** — `AcceptDialog` 确认 → `delete_save()` → hide → `_show_title()`

- [ ] **Step 6: `_show_title()` / 切屏时** — 若 overlay 存在则 `_hide_pause_menu()`，避免遮罩残留

- [ ] **Step 7: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat(ui): wire pause menu actions and save"
```

---

### Task 4: 测试与文档

**Files:**
- Create: `tools/pause_menu_test.gd`
- Modify: `tools/flow_screen_test.gd`
- Modify: `CLAUDE.md`

- [ ] **Step 1: `pause_menu_test.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	var main := load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("_start_run", "vagabond")
	await process_frame
	main.call("_build_header")
	await process_frame
	# find ☰ or tooltip 选项
	main.call("_show_pause_menu")
	await process_frame
	# assert 继续游戏 / 返回标题 / 放弃本局
	main.call("_hide_pause_menu")
	print("pause_menu_test: OK")
	quit()
```

- [ ] **Step 2: `flow_screen_test` 经 `RunHeaderView.build(..., Callable(), Callable())` 检查 `☰`**

- [ ] **Step 3: CLAUDE.md 增加** `godot4.6 --headless --script tools/pause_menu_test.gd`

- [ ] **Step 4: 运行测试 + smoke**

```bash
godot4.6 --headless --script tools/pause_menu_test.gd
godot4.6 --headless --script tools/flow_screen_test.gd
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 5: Commit**

```bash
git add tools/pause_menu_test.gd tools/flow_screen_test.gd CLAUDE.md
git commit -m "test: pause menu headless coverage"
```

---

## 规格自检

| Spec | Task |
|------|------|
| P1–P2 | Task 2–3 |
| P3–P4 | Task 3 + RunSaveService |
| P5 | Task 2 |
| P6 | Task 2（仅 run 屏调 header） |
| P7 | Task 4 |

无 TBD；ORIGIN 返回标题不写盘在 Task 3 用现有 `_maybe_autosave` 条件自然满足。

---

## 执行方式

计划已保存。确认 spec 后可 Subagent-Driven 或 Inline 实现；提交 `feat(ui): in-game pause menu and header layout`。
