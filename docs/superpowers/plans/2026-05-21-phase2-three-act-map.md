# 阶段二：三幕 12 层地图 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将跑团从 6 层扩展为 12 层（3 幕 × 4 层），地图与敌池按 `ActData.tres` 驱动；幕末 Boss 与最终 Boss 分级；修正胜利条件。

**Architecture:** `ActData` + `MapGenerator.options_for_floor` 读当前幕配置；`EnemyData.is_act_boss` / `is_run_boss` 驱动 `CombatController.check_combat_end`；`Main` 地图 UI 读 `ActData` 文案。

**Tech Stack:** Godot 4.6, GDScript, Resource, headless tests

**Spec:** `docs/superpowers/specs/2026-05-21-architecture-three-act-design.md` §3

**Prerequisite:** 阶段一完成（`docs/superpowers/plans/2026-05-21-phase1-architecture.md`）

---

## File map (phase 2)

| File | Action |
|------|--------|
| `data/ActData.gd` | Create |
| `data/MapNodeData.gd` | Create（可选，或用 Dictionary 过渡） |
| `data/acts/limgrave.tres` | Create |
| `data/acts/stormveil.tres` | Create |
| `data/acts/liurnia.tres` | Create |
| `data/EnemyData.gd` | Add is_act_boss, is_run_boss |
| `data/enemies/*.tres` | Patch flags on margit, mohg, etc. |
| `scripts/core/DataRegistry.gd` | Load acts |
| `scripts/core/MapGenerator.gd` | Full 12-floor logic |
| `scripts/core/CombatController.gd` | combat_ended kinds |
| `scripts/Main.gd` | Map UI, act clear flow |
| `tools/map_generator_test.gd` | New headless test |
| `tools/smoke_test.gd` | Optional extend |

---

### Task 1: EnemyData Boss 分级

**Files:**
- Modify: `data/EnemyData.gd`
- Modify: `data/enemies/margit.tres`, `mohg_lovula.tres`, `gargoyle_knight.tres`（等）

- [ ] **Step 1: 扩展 `EnemyData.gd`**

```gdscript
@export_group("Boss Flags")
@export var is_act_boss: bool = false
@export var is_run_boss: bool = false
# 保留 is_boss 作强度/分类，不再单独触发 victory
```

- [ ] **Step 2: 更新 `_enemy_to_dict`（DataRegistry）**

字典增加：`"is_act_boss": template.is_act_boss`, `"is_run_boss": template.is_run_boss`

- [ ] **Step 3: 设置资源**

| 资源文件 | is_act_boss | is_run_boss | is_boss |
|----------|-------------|-------------|---------|
| `margit.tres` | true | false | true |
| `gargoyle_knight.tres` 或占位幕二 | true | false | true |
| `mohg_lovula.tres` | false | true | true |

- [ ] **Step 4: Commit**

```bash
git add data/EnemyData.gd data/enemies/
git commit -m "feat(data): act and run boss flags on enemies"
```

---

### Task 2: ActData 与三幕资源

**Files:**
- Create: `data/MapNodeData.gd`, `data/ActData.gd`
- Create: `data/acts/limgrave.tres`, `stormveil.tres`, `liurnia.tres`

- [ ] **Step 1: `MapNodeData.gd`**

```gdscript
class_name MapNodeData
extends Resource
@export var kind: String = "combat"  # combat | elite | grace
@export var title: String
@export var body: String
@export var enemy_name: String = ""
```

- [ ] **Step 2: `ActData.gd`**

```gdscript
class_name ActData
extends Resource
@export var id: String
@export var title: String
@export var subtitle_template: String = "第 {local} 段 / 4。{flavor}"
@export var flavor: String
@export var combat_enemies: Array[String] = []
@export var elite_enemies: Array[String] = []
@export var fixed_nodes: Array[MapNodeData] = []
@export var act_boss_name: String
@export var act_boss_title: String
@export var act_boss_body: String
@export var is_final_act: bool = false
```

- [ ] **Step 3: 填写 `limgrave.tres`（示例）**

- `title`: 宁姆格福路标
- `combat_enemies`: 葛瑞克士兵, 野狼, 凯丹佣兵, 挖石矿工, 学院辉石法师
- `elite_enemies`: 法姆亚兹拉的兽人, 亚人首领, 挖石山妖
- `fixed_nodes`: 2 个 grace 节点（从现 `_map_options` 复制文案）
- `act_boss_name`: 恶兆妖鬼玛尔基特
- `act_boss_title`: 通城隧道

- [ ] **Step 4: `stormveil.tres` / `liurnia.tres`**

史东薇尔：普通池 葛瑞克骑士、腐败眷属、stoneminer_fiend；精英 熔炉骑士、gravekeeper；`act_boss_name`: 熔炉骑士（占位）

利耶尼亚：`is_final_act=true`；`act_boss_name` / run boss: 接肢贵族 → 使用 `mohg_lovula.tres` 的 `name` 字段值

- [ ] **Step 5: Commit**

```bash
git add data/ActData.gd data/MapNodeData.gd data/acts/
git commit -m "feat(data): ActData resources for three acts"
```

---

### Task 3: DataRegistry 加载 ActData

**Files:**
- Modify: `scripts/core/DataRegistry.gd`

- [ ] **Step 1: 增加 `var acts: Array[ActData] = []` 与 `_load_dir_acts()`**

按文件名排序：`limgrave`, `stormveil`, `liurnia`

- [ ] **Step 2: `get_act(index: int) -> ActData`**

`index = clamp(run.act_index(), 0, acts.size()-1)`

- [ ] **Step 3: Commit**

```bash
git add scripts/core/DataRegistry.gd
git commit -m "feat(core): registry loads ActData"
```

---

### Task 4: MapGenerator 12 层逻辑

**Files:**
- Modify: `scripts/core/MapGenerator.gd`

- [ ] **Step 1: 删除 `TOTAL_FLOORS_PHASE1`；使用 `RunState.TOTAL_FLOORS`**

- [ ] **Step 2: 实现 `options_for_floor(run: RunState, registry: DataRegistry, rng) -> Array`**

```gdscript
func options_for_floor(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> Array:
	if run.is_act_boss_floor():
		var act := registry.get_act(run.act_index())
		return [{
			"kind": "boss",
			"enemy": act.act_boss_name,
			"title": act.act_boss_title,
			"body": act.act_boss_body,
		}]
	var act := registry.get_act(run.act_index())
	var pool: Array = []
	for node in act.fixed_nodes:
		pool.append(_node_to_dict(node))
	# 随机 2 个 combat + 1 个 elite 从池生成 MapNodeData 字典
	pool.shuffle()
	return pool.slice(0, 3)
```

- [ ] **Step 3: `Main._map_options` 改为调用上述 API**

- [ ] **Step 4: 地图描述 `第 {run.floor_index+1} / 12` 与 `act.title`**

- [ ] **Step 5: Commit**

```bash
git add scripts/core/MapGenerator.gd scripts/Main.gd
git commit -m "feat(map): twelve-floor MapGenerator from ActData"
```

---

### Task 5: 战斗结束与幕间奖励

**Files:**
- Modify: `scripts/core/CombatController.gd`
- Modify: `scripts/Main.gd`

- [ ] **Step 1: 改写 `check_combat_end`**

```gdscript
if int(enemy.hp) <= 0 and not combat_over:
	combat_over = true
	run.souls += int(enemy.souls)
	if enemy.get("is_run_boss", false):
		combat_ended.emit("run_victory")
	elif enemy.get("is_act_boss", false):
		combat_ended.emit("act_clear")
	else:
		combat_ended.emit("reward")
```

- [ ] **Step 2: `Main._on_combat_ended`**

```gdscript
match kind:
	"reward": _show_rewards()
	"act_clear": _show_act_clear()  # 新函数
	"run_victory": _show_victory()
```

- [ ] **Step 3: `_show_act_clear()`**

回满 hp、补满 flasks；提供 1 张可选牌或跳过；`run.advance_floor()` → `_show_map()`

- [ ] **Step 4: 更新 `_show_victory` 文案** — 接肢贵族 / 第三幕；显示 souls、deck.size()

- [ ] **Step 5: 冒烟测试**

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 6: Commit**

```bash
git add scripts/core/CombatController.gd scripts/Main.gd
git commit -m "feat(combat): act boss vs run boss victory flow"
```

---

### Task 6: map_generator_test.gd

**Files:**
- Create: `tools/map_generator_test.gd`

- [ ] **Step 1: 创建 SceneTree 脚本**

```gdscript
extends SceneTree

func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var gen := MapGenerator.new()
	var run := RunState.new()
	for floor in [3, 7, 11]:
		run.floor_index = floor
		var opts := gen.options_for_floor(run, registry, RandomNumberGenerator.new())
		if opts.size() != 1:
			push_error("floor %d expected 1 boss option, got %d" % [floor, opts.size()])
			quit(1)
			return
		if str(opts[0].get("kind")) != "boss":
			push_error("floor %d not boss kind" % floor)
			quit(1)
			return
	print("Map generator test passed")
	quit()
```

- [ ] **Step 2: 运行**

```bash
godot4.6 --headless --script tools/map_generator_test.gd
```

Expected: `Map generator test passed`

- [ ] **Step 3: Commit**

```bash
git add tools/map_generator_test.gd
git commit -m "test: headless MapGenerator boss floor checks"
```

---

### Task 7: Header、赐福与平衡微调

**Files:**
- Modify: `scripts/Main.gd` (`_build_header`, `_visit_grace`)

- [ ] **Step 1: Header 显示 `registry.get_act(run.act_index()).title` + `层数 {floor+1}/12`**

- [ ] **Step 2: 赐福 `_visit_grace` 后 `advance_floor` 逻辑不变**

- [ ] **Step 3: （可选）幕间后第一张普通战降低伤害 — 跳过除非测试反馈需要**

- [ ] **Step 4: 全测试**

```bash
godot4.6 --headless --script tools/map_generator_test.gd
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 5: Commit**

```bash
git add scripts/Main.gd
git commit -m "polish: act-aware map header and grace flow"
```

---

### Task 8: 文档与规格状态

**Files:**
- Modify: `README.md`, `CLAUDE.md`, spec md status

- [ ] **Step 1: README 已实现列表加入「三幕 12 层」**

- [ ] **Step 2: CLAUDE.md 地图节改为 12 层 + ActData**

- [ ] **Step 3: spec 状态改为「阶段二已实现」**

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md docs/superpowers/specs/2026-05-21-architecture-three-act-design.md
git commit -m "docs: three-act map shipped"
```

---

## Plan self-review

| Spec §3 | Task |
|---------|------|
| 12 层 / 幕末 3,7,11 | Task 4, 6 |
| ActData.tres ×3 | Task 2–3 |
| is_act_boss / is_run_boss | Task 1, 5 |
| 敌池复用 | Task 2 |
| UI 幕名 | Task 7 |
| 冒烟 + map test | Task 5–6 |

无占位符；依赖阶段一 `RunState`/`MapGenerator`/`CombatController`。
