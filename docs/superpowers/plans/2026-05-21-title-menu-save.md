# 标题主菜单与 StS 式存档 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 标题屏底栏「开始/新游戏、继续、退出」+ 单槽 `user://run_save.json` 高频自动存档，继续游戏恢复到上次界面（含战斗）。

**Architecture:** 新建 `RunSaveService` 负责 JSON 序列化/恢复；`Main` 在地图/战斗/奖励/回合结束/退出前调用 `save_snapshot`；`TitleScreenView` 按 `has_save()` 切换文案与禁用态；恢复时按 `screen` 分支调用 `run_flow` / `_render_combat` / `RunRewardFlow` 恢复方法。

**Tech Stack:** Godot 4.6 GDScript，`FileAccess` + `JSON`，现有 `RunState` / `CombatController` / `RunRewardFlow`。

**设计规格：** `docs/superpowers/specs/2026-05-21-title-menu-save-design.md`

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `scripts/core/RunSaveService.gd` | 读写 `user://run_save.json`，run/combat/reward 序列化 |
| `scripts/ui/TitleScreenView.gd` | 布局 C，三键 + 继续禁用 |
| `scripts/Main.gd` | 标题回调、确认框、autosave、`_end_player_turn`、继续读档 |
| `scripts/ui/CombatHudView.gd` | 结束回合改为 `Callable` 参数（已有，改传入） |
| `scripts/core/RunRewardFlow.gd` | `export_merchant_state` / `restore_merchant_from_dict`；事件结果恢复辅助 |
| `tools/save_roundtrip_test.gd` | 序列化往返 |
| `tools/title_menu_test.gd` | 标题按钮状态 |
| `tools/smoke_test.gd` | 经标题「开始游戏」进出身 |
| `project.godot` | 注册 `RunSaveService` class（若用 class_name） |

---

### Task 1: RunSaveService 骨架与 run 序列化

**Files:**
- Create: `scripts/core/RunSaveService.gd`
- Test: `tools/save_roundtrip_test.gd`

- [ ] **Step 1: 新建 `RunSaveService.gd`**

```gdscript
class_name RunSaveService
extends RefCounted

const SAVE_PATH := "user://run_save.json"
const SAVE_VERSION := 1

static func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data := _read_json()
	return data != null and int(data.get("save_version", 0)) == SAVE_VERSION

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

static func _read_json() -> Variant:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	return JSON.parse_string(text)

static func _write_json(obj: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(obj))
	return true
```

- [ ] **Step 2: 实现 `_run_to_dict` / `_run_from_dict`**

映射 `RunState` 全部持久字段（见 spec §3.2）。`deck` 等为 `Array[String]`，JSON 中为字符串数组。

- [ ] **Step 3: 实现 `_combat_to_dict` / `_combat_from_dict`**

从 `CombatController` 读取：`enemy`, `enemy_intent`, `ember`, `max_ember`, `block`, `combat_over`。

- [ ] **Step 4: 写 `save_roundtrip_test.gd`（仅 run + combat）**

```gdscript
extends SceneTree

func _initialize() -> void:
	var run := RunState.new()
	run.reset_for_origin(/* vagabond from registry */, 42)
	run.floor_index = 2
	var combat := CombatController.new(run, DataRegistry.new(), RandomNumberGenerator.new())
	combat.enemy = {"id": "test", "name": "Test", "hp": 5, "max_hp": 10, "stance": 0, "stance_max": 0, "stance_now": 0, "block": 0, "rot": 0, "bleed": 0, "vulnerable": 0, "strength": 0}
	var snap := {
		"save_version": 1,
		"screen": 3, # COMBAT
		"run": RunSaveService._run_to_dict(run),
		"combat": RunSaveService._combat_to_dict(combat),
		"log_lines": ["line1"],
	}
	# write temp, read back, assert floor_index and enemy.hp
	print("save roundtrip ok")
	quit()
```

将 `_run_to_dict` 设为可被测试调用（`static` 或测试同文件 duplicate 最小逻辑）。

- [ ] **Step 5: 运行测试**

```bash
godot4.6 --headless --script tools/save_roundtrip_test.gd
```

Expected: `save roundtrip ok`，exit 0。

- [ ] **Step 6: Commit**

```bash
git add scripts/core/RunSaveService.gd tools/save_roundtrip_test.gd project.godot
git commit -m "feat(save): add RunSaveService run/combat serialization"
```

---

### Task 2: save_snapshot / load_snapshot 与 Main 挂钩

**Files:**
- Modify: `scripts/core/RunSaveService.gd`
- Modify: `scripts/Main.gd`

- [ ] **Step 1: `save_snapshot(main: Node) -> bool`**

收集：

- `screen` → `main.screen`（int 枚举值）
- `run` → `_run_to_dict(main.run_state)`
- `combat` → 若 `screen == COMBAT` 则 `_combat_to_dict(main.combat)` else `{}`
- `reward` → 若 `screen == REWARD` 调用 `RunRewardFlow.export_reward_state()`（Task 3 实现，此处先 `{}`）
- `log_lines` → `main.log_lines.duplicate()`

无效屏（TITLE/ORIGIN/GAME_OVER/VICTORY）返回 `false` 不写盘。

- [ ] **Step 2: `load_snapshot(main: Node) -> bool`**

读 JSON → 校验 → `_run_from_dict` → `main.rng.seed = run.run_seed` → `match screen`：

- `MAP` → `main.run_flow.show_map()`
- `COMBAT` → `_combat_from_dict` + `main._render_combat()`
- `REWARD` → `main.reward_flow.restore_reward_state(reward_dict)`（Task 3）

恢复 `log_lines`。

- [ ] **Step 3: Main 增加 `_maybe_autosave()`**

```gdscript
func _maybe_autosave() -> void:
	if screen in [GameScreen.MAP, GameScreen.COMBAT, GameScreen.REWARD]:
		RunSaveService.save_snapshot(self)
```

在以下末尾调用：`_enter_map_layer`、`_present_reward_layer`、`_begin_combat`（`start_combat` 后）、`_advance_floor_and_show_map`（经 `run_flow` 回调后，或在 `RunFlowController.advance_floor_and_show_map` 末尾由 host 调用 — 优先在 Main 的 `_enter_map_layer` 与 `_present_reward_layer` 末尾统一调用，战斗开始已在 `_begin_combat`）。

- [ ] **Step 4: `_end_player_turn()`**

```gdscript
func _end_player_turn() -> void:
	combat.end_player_turn()
	_maybe_autosave()
```

`_render_combat` 传入 `_end_player_turn` 替代 `combat.end_player_turn`。

- [ ] **Step 5: 手动验证**

Godot 运行 → 出身 → 地图 → 关编辑器 → 再开 → 暂不测继续（Task 4）。

- [ ] **Step 6: Commit**

```bash
git add scripts/core/RunSaveService.gd scripts/Main.gd
git commit -m "feat(save): wire autosave hooks and load routing in Main"
```

---

### Task 3: REWARD 层恢复（商人 + 事件结果）

**Files:**
- Modify: `scripts/core/RunRewardFlow.gd`
- Modify: `scripts/core/RunSaveService.gd`

- [ ] **Step 1: `export_reward_state() -> Dictionary`**

根据当前 reward UI 类型设置 `kind`：

- 商人：`merchant_stock` 存 **offer id 字符串数组**（非 Resource 引用），`merchant_sold`, `merchant_status`, `merchant_cost_percent`
- 事件结果屏：由 `RunFlowController` 在 `show_event_result` 时设置 `host` 上临时变量 `_pending_reward_kind = "grace_result"` + title/body（或在 `show_event_result` 内写 host meta）

最小实现：**先只保证 `merchant` 与 `event`（`event_id`）**；`grace_result` 存 `title`/`body` 文本。

- [ ] **Step 2: `restore_reward_state(data: Dictionary) -> void`**

```gdscript
match data.get("kind", ""):
	"merchant":
		restore_merchant_from_dict(data)
		show_merchant()
	"event":
		var ev := host.get("registry").get_event(data["event_id"])
		if ev: host.get("run_flow").show_event(ev)
	"grace_result":
		host.call("_present_reward_layer", RewardLayerViews.build_centered_continue(...))
```

- [ ] **Step 3: `save_snapshot` 填入 `reward`**

- [ ] **Step 4: 扩展 `save_roundtrip_test` 或新用例：商人 offer ids 往返**

- [ ] **Step 5: Commit**

```bash
git add scripts/core/RunRewardFlow.gd scripts/core/RunSaveService.gd tools/save_roundtrip_test.gd
git commit -m "feat(save): reward layer merchant and event restore"
```

---

### Task 4: TitleScreenView 与标题流程

**Files:**
- Modify: `scripts/ui/TitleScreenView.gd`
- Modify: `scripts/Main.gd`
- Test: `tools/title_menu_test.gd`

- [ ] **Step 1: 重写 `TitleScreenView.build`**

签名：

```gdscript
static func build(
	has_save: bool,
	on_new_game: Callable,
	on_continue: Callable,
	on_quit: Callable
) -> Control
```

- 根节点 `VBoxContainer`：`size_flags_vertical = EXPAND`，`alignment = BEGIN`（顶对齐）
- 上部 spacer + 标题区（沿用现文案）
- 底部 `HBoxContainer`：`size_flags_vertical = SIZE_EXPAND_FILL` + 底部对齐子容器，或 `MarginContainer` 锚底
- 三按钮等宽 `size_flags_horizontal = SIZE_EXPAND_FILL`，`custom_minimum_size.y = 52`
- 左键文案：`"开始游戏" if not has_save else "新游戏"`
- 中键：`"继续游戏"`，`disabled = not has_save`
- 右键：`"退出游戏"`

- [ ] **Step 2: Main `_show_title`**

```gdscript
func _show_title() -> void:
	screen = GameScreen.TITLE
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	var has := RunSaveService.has_save()
	title_layer.add_child(TitleScreenView.build(
		has,
		_on_title_new_game,
		_on_title_continue,
		_on_title_quit
	))
```

- [ ] **Step 3: 回调**

```gdscript
func _on_title_new_game() -> void:
	if RunSaveService.has_save():
		var dlg := AcceptDialog.new()
		dlg.title = "放弃当前进度？"
		dlg.dialog_text = "开始新游戏将覆盖现有存档。"
		dlg.confirmed.connect(func(): dlg.queue_free(); _show_origin())
		dlg.canceled.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_show_origin()

func _on_title_continue() -> void:
	if not RunSaveService.load_snapshot(self):
		_show_title()

func _on_title_quit() -> void:
	_maybe_autosave()
	get_tree().quit()
```

- [ ] **Step 4: `_start_run` 成功后删档**

在 `run_flow.show_map()` 之前：`RunSaveService.delete_save()` 然后正常 autosave 会写新档。

- [ ] **Step 5: `title_menu_test.gd`**

实例化 `TitleScreenView.build(false, ...)`，遍历子树找「继续游戏」按钮，断言 `disabled == true`；再 `build(true, ...)` 断言 `disabled == false`。

- [ ] **Step 6: 运行**

```bash
godot4.6 --headless --script tools/title_menu_test.gd
```

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/TitleScreenView.gd scripts/Main.gd tools/title_menu_test.gd
git commit -m "feat(ui): title menu with continue and quit"
```

---

### Task 5: 文档与 smoke 回归

**Files:**
- Modify: `tools/smoke_test.gd`
- Modify: `CLAUDE.md`
- Modify: `README.md`（若有运行说明）

- [ ] **Step 1: smoke_test 每个 origin**

在 `main.call("_start_run", origin_id)` 之前：

```gdscript
main.call("_on_title_new_game")  # 或 _show_origin 若测试跳过标题
await process_frame
```

更简单：直接 `main.call("_show_origin")` 保持绕过标题 UI 逻辑，**或** 调用 `_on_title_new_game` 测完整链。推荐：

```gdscript
main.call("_show_origin")
await process_frame
main.call("_start_run", origin_id)
```

（出身屏仍由 `_start_run` 进入 — 与现逻辑一致；标题流由 `title_menu_test` 覆盖。）

在 `CLAUDE.md` 「How to Run」增加：

```text
- Save roundtrip: godot4.6 --headless --script tools/save_roundtrip_test.gd
- Title menu: godot4.6 --headless --script tools/title_menu_test.gd
```

- [ ] **Step 2: 全量 headless**

```bash
godot4.6 --headless --script tools/save_roundtrip_test.gd
godot4.6 --headless --script tools/title_menu_test.gd
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md tools/smoke_test.gd
git commit -m "docs: document run save and title menu tests"
```

---

## 规格自检（plan ↔ spec）

| Spec 要求 | 任务 |
|-----------|------|
| 布局 C 三键 | Task 4 |
| 有档「新游戏」+ 确认 | Task 4 |
| 继续不进出身 | Task 2 `load_snapshot` |
| Sts 高频 autosave | Task 2 |
| 退出前 save | Task 4 |
| 新局成功后删旧档 | Task 4 |
| merchant/event 恢复 | Task 3 |
| 不恢复 GAME_OVER/VICTORY | Task 2 校验 screen |
| 测试三件套 | Task 1/4/5 |

---

## 执行方式

计划已保存。可选：

1. **Subagent-Driven** — 每任务派生子 agent，任务间审查  
2. **Inline Execution** — 本会话按 `executing-plans` 逐步执行  

实现完成后提交：`feat(game): title menu and StS-style run save`，并 **push origin main**。
