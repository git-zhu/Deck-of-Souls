# 阶段一：L2 架构与卡牌效果 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `Main.gd` 中的数据加载、跑团状态、战斗逻辑与卡牌效果拆到 `scripts/core/`，用 EffectStep + hook 替代 `_play_card` 的 `match`，冒烟测试保持通过。

**Architecture:** `DataRegistry` 加载 `.tres`；`RunState` 持有跑团字段；`CombatController` 处理战斗与信号；`CardEffectResolver` 执行效果链；`Main.gd` 仅 UI 与路由。`MapGenerator` 阶段一仅转发现有 `_map_options` 逻辑。

**Tech Stack:** Godot 4.6, GDScript, Resource (.tres), headless smoke test

**Spec:** `docs/superpowers/specs/2026-05-21-architecture-three-act-design.md` §2

---

## File map (phase 1)

| File | Responsibility |
|------|----------------|
| `data/CardEffectStep.gd` | 单步效果资源定义 |
| `data/CardData.gd` | 增加 effects / hook_id / exhaust_after_play |
| `scripts/core/DataRegistry.gd` | 扫描加载 cards/origins/enemies |
| `scripts/core/RunState.gd` | 跑团状态与牌堆 |
| `scripts/core/CombatController.gd` | 战斗状态机、伤害、敌人回合 |
| `scripts/core/CardEffectResolver.gd` | 效果链 + hooks |
| `scripts/core/MapGenerator.gd` | 阶段一：6 层地图选项（从 Main 迁入） |
| `scripts/Main.gd` | UI + 绑定 Controller 信号 |
| `data/cards/*.tres` | 每张卡填写 effects 或 hook_id |
| `tools/smoke_test.gd` | 回归（必要时改访问路径） |

---

### Task 1: CardEffectStep 资源类型

**Files:**
- Create: `data/CardEffectStep.gd`
- Modify: `project.godot`（若需 `global_script_class` — Godot 4 用 `class_name` 自动注册）

- [ ] **Step 1: 创建 `CardEffectStep.gd`**

```gdscript
class_name CardEffectStep
extends Resource

enum Kind {
	DAMAGE,
	GAIN_BLOCK,
	HEAL,
	DRAW,
	APPLY_BLEED,
	APPLY_VULN_PLAYER_SIDE,  # 未使用可删
	APPLY_ROT_ON_ENEMY,
	APPLY_VULN_ON_ENEMY,
}

@export var kind: Kind = Kind.DAMAGE
@export var value: int = 0
@export var stance: int = 0
@export var hits: int = 1
```

- [ ] **Step 2: 在 Godot 编辑器打开项目**，确认脚本无解析错误（或运行 `godot4.6 --headless --quit-after 1`）。

- [ ] **Step 3: Commit**

```bash
git add data/CardEffectStep.gd
git commit -m "feat(data): add CardEffectStep resource for card effects"
```

---

### Task 2: 扩展 CardData

**Files:**
- Modify: `data/CardData.gd`

- [ ] **Step 1: 在 `CardData.gd` 末尾增加**

```gdscript
@export_group("Effects")
@export var effects: Array[CardEffectStep] = []
@export var hook_id: String = ""
@export var exhaust_after_play: bool = false
```

- [ ] **Step 2: Commit**

```bash
git add data/CardData.gd
git commit -m "feat(data): extend CardData with effect chain and hooks"
```

---

### Task 3: DataRegistry

**Files:**
- Create: `scripts/core/DataRegistry.gd`
- Modify: `project.godot` — 添加 autoload（可选，推荐）

- [ ] **Step 1: 创建 `scripts/core/DataRegistry.gd`**

从 `Main.gd` 复制并整理 `_load_cards`, `_load_origins`, `_load_enemies`, `_enemy_to_dict`，暴露：

```gdscript
class_name DataRegistry
extends RefCounted

var cards: Dictionary = {}       # id -> CardData
var origins: Dictionary = {}       # id -> OriginData
var _enemy_templates: Array = [] # dict templates

func load_all() -> void:
	cards = _load_dir_cards()
	origins = _load_dir_origins()
	_enemy_templates = _load_dir_enemies()

func get_card(id: String) -> CardData:
	return cards.get(id)

func all_card_ids() -> Array:
	return cards.keys()

func get_origin(id: String) -> OriginData:
	return origins.get(id)

func enemy_templates() -> Array:
	return _enemy_templates

func template_by_name(enemy_name: String) -> Dictionary:
	for t in _enemy_templates:
		if str(t.get("name", "")) == enemy_name:
			return t.duplicate(true)
	return {}
```

- [ ] **Step 2: （推荐）在 `project.godot` 添加**

```ini
[autoload]
DataRegistry="*res://scripts/core/DataRegistry.gd"
```

若用 Autoload，将 `class_name DataRegistry` 改为 `extends Node`，`load_all()` 在 `_ready()` 调用；否则 `Main._ready()` 里 `var registry := DataRegistry.new(); registry.load_all()`。

- [ ] **Step 3: 临时在 `Main._ready` 顶部验证**

```gdscript
var _registry: DataRegistry
# _ready:
_registry = DataRegistry.new() # 或 get_node if autoload
_registry.load_all()
assert(_registry.cards.size() >= 24)
```

运行：`godot4.6 --headless --script tools/smoke_test.gd`（可能仍用旧加载，Task 9 统一）

- [ ] **Step 4: Commit**

```bash
git add scripts/core/DataRegistry.gd project.godot
git commit -m "feat(core): add DataRegistry for tres loading"
```

---

### Task 4: RunState

**Files:**
- Create: `scripts/core/RunState.gd`

- [ ] **Step 1: 创建 `RunState.gd`**

```gdscript
class_name RunState
extends RefCounted

const FLOORS_PER_ACT := 4
const ACT_COUNT := 3
const TOTAL_FLOORS := 12

var run_seed: int = 0
var origin_id: String = "vagabond"
var hp: int = 72
var max_hp: int = 72
var flasks: int = 2
var max_flasks: int = 2
var souls: int = 0
var floor_index: int = 0
var deck: Array[String] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var player_rot: int = 0
var player_bleed: int = 0
var player_vulnerable: int = 0
var player_strength: int = 0

func act_index() -> int:
	return floor_index / FLOORS_PER_ACT

func is_act_boss_floor() -> bool:
	return floor_index % FLOORS_PER_ACT == FLOORS_PER_ACT - 1

func advance_floor() -> void:
	floor_index += 1

func reset_for_origin(origin: OriginData, seed: int, rng: RandomNumberGenerator) -> void:
	run_seed = seed
	origin_id = origin.id
	max_hp = origin.max_hp
	hp = max_hp
	max_flasks = origin.flasks
	flasks = max_flasks
	souls = 0
	floor_index = 0
	player_rot = 0
	player_bleed = 0
	player_vulnerable = 0
	player_strength = 0
	deck.assign(origin.deck)
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/RunState.gd
git commit -m "feat(core): add RunState for run progression"
```

---

### Task 5: CombatController（迁移战斗，暂保留效果调用）

**Files:**
- Create: `scripts/core/CombatController.gd`
- Modify: `scripts/Main.gd` — 逐步改为委托

- [ ] **Step 1: 创建 `CombatController.gd` 骨架**

```gdscript
class_name CombatController
extends RefCounted

signal combat_changed
signal combat_ended(kind: String)
signal log_message(text: String)

var run: RunState
var registry: DataRegistry
var rng: RandomNumberGenerator

var enemy: Dictionary = {}
var enemy_intent: Dictionary = {}
var combat_over: bool = false
var ember: int = 3
var max_ember: int = 3
var block: int = 0

func _init(p_run: RunState, p_registry: DataRegistry, p_rng: RandomNumberGenerator) -> void:
	run = p_run
	registry = p_registry
	rng = p_rng
```

- [ ] **Step 2: 从 `Main.gd` 剪切到 `CombatController`（保持逻辑不变）**

迁移函数（签名改为使用 `self` 状态）：
- `start_combat(template)`
- `start_player_turn`, `apply_player_start_status`
- `deal_enemy_damage`, `apply_enemy_bleed`, `gain_block`, `heal_player`
- `draw_cards`, `end_player_turn`, `enemy_turn`, `enemy_attack`, `take_player_damage`
- `choose_enemy_intent`, `intent_text`, `check_combat_end`
- `use_flask`
- `_play_card` 暂仍 match（Task 7 删除）

`log` 改为 `log_message.emit(text)`。

`check_combat_end` 中 Boss 胜利暂保留旧逻辑（`enemy.boss` → `"run_victory"`），阶段二改。

- [ ] **Step 3: `Main.gd` 持有 Controller**

```gdscript
var run_state: RunState
var combat: CombatController
var registry: DataRegistry

func _ready() -> void:
	registry = DataRegistry.new()
	registry.load_all()
	run_state = RunState.new()
	combat = CombatController.new(run_state, registry, rng)
	combat.log_message.connect(_log)
	combat.combat_changed.connect(_render_combat)
	combat.combat_ended.connect(_on_combat_ended)
```

- [ ] **Step 4: 运行冒烟测试**

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

Expected: `Smoke test passed`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/CombatController.gd scripts/Main.gd
git commit -m "refactor(core): move combat logic into CombatController"
```

---

### Task 6: CardEffectResolver

**Files:**
- Create: `scripts/core/CardEffectResolver.gd`
- Modify: `scripts/core/CombatController.gd`

- [ ] **Step 1: 创建 resolver**

```gdscript
class_name CardEffectResolver
extends RefCounted

var combat: CombatController

func _init(p_combat: CombatController) -> void:
	combat = p_combat

func resolve(card: CardData) -> bool:
	if card.hook_id != "":
		return _run_hook(card.hook_id)
	for step in card.effects:
		_apply_step(step)
	return card.exhaust_after_play

func _apply_step(step: CardEffectStep) -> void:
	match step.kind:
		CardEffectStep.Kind.DAMAGE:
			for i in step.hits:
				combat.deal_enemy_damage(step.value + combat.run.player_strength, step.stance)
		CardEffectStep.Kind.GAIN_BLOCK:
			combat.gain_block(step.value)
		# ... HEAL, DRAW, APPLY_BLEED, APPLY_ROT_ON_ENEMY, APPLY_VULN_ON_ENEMY
```

- [ ] **Step 2: 实现 `_run_hook` — 从 `Main._play_card` match 逐条迁移**

| hook_id | 行为来源（Main 现 match） |
|---------|---------------------------|
| `heater_shield` | 8 格挡 + 攻击意图返 1 集中 |
| `buckler` | 5 格挡 + 攻击意图 -4 姿态 |
| `longbow` | 5 伤 1 姿态；无护甲抽 1 |
| `club` | 6(+5 空手) 伤 2 姿态 |
| `battle_axe` | 15 伤 4 姿态；崩解返 1 集中 |
| `lions_claw` | 14 伤 5 姿态；崩解抽 1 |
| `magic_glintblade` | 8 伤 2 姿态；有集中再 3 伤 1 姿态 |
| `destined_death` | 25 伤 8 姿态；击杀 +4 最大生命 |

- [ ] **Step 3: `CombatController.play_card` 改为**

```gdscript
func play_card(index: int) -> void:
	# 校验、扣费、移除手牌（同现逻辑）
	var card: CardData = registry.get_card(card_id)
	var resolver := CardEffectResolver.new(self)
	var exhaust := resolver.resolve(card)
	# 弃牌 / 消耗 + check_combat_end + combat_changed.emit()
```

- [ ] **Step 4: 删除 `Main`/`CombatController` 中 `match card_id` 效果块**

- [ ] **Step 5: Commit**

```bash
git add scripts/core/CardEffectResolver.gd scripts/core/CombatController.gd
git commit -m "feat(core): CardEffectResolver with hooks"
```

---

### Task 7: 配置 24 张卡牌 .tres

**Files:**
- Modify: `data/cards/*.tres`（24 个）
- Reference: `scripts/Main.gd` 旧 match 行 802–887（迁移前备份）

- [ ] **Step 1: 纯 EffectStep 卡（示例 `longsword.tres`）**

在资源中增加子资源：
- `effects[0]`: kind=DAMAGE, value=7, stance=3
- `hook_id=""`
- `exhaust_after_play=false`

对照表（hook_id 非空则只填 hook + exhaust）：

| id | hook_id | exhaust |
|----|---------|---------|
| longsword, halberd, uchigatana, scimitar, glintstone_*, catch_flame, heal, urgent_heal, assassins_approach, volcano_pot, rotten_breath, black_flame, bloodhounds_step | "" | crimson_flask=true |
| heater_shield, buckler, longbow, club, battle_axe, lions_claw, magic_glintblade, destined_death | 同名 | destined_death false |

- [ ] **Step 2: 在编辑器中打开 2～3 张卡验证资源可加载**

- [ ] **Step 3: 冒烟 + 手动进战斗打长剑/盾/命定之死**

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 4: Commit**

```bash
git add data/cards/
git commit -m "feat(data): card effects as tres steps and hooks"
```

---

### Task 8: MapGenerator（阶段一薄封装）

**Files:**
- Create: `scripts/core/MapGenerator.gd`
- Modify: `scripts/Main.gd` — `_map_options` 委托

- [ ] **Step 1: 创建 `MapGenerator.gd`**

```gdscript
class_name MapGenerator
extends RefCounted

const TOTAL_FLOORS_PHASE1 := 6  # 阶段二改为 RunState.TOTAL_FLOORS

func options_for_floor(floor_index: int, rng: RandomNumberGenerator) -> Array:
	if floor_index >= TOTAL_FLOORS_PHASE1 - 1:
		return [{"kind": "boss", "enemy": "恶兆妖鬼玛尔基特", ...}]
	# 从 Main._map_options 复制 options 数组与 shuffle slice(0,3)
```

- [ ] **Step 2: `Main._show_map` 使用 `MapGenerator.new().options_for_floor(run_state.floor_index, rng)`**

- [ ] **Step 3: Header 使用 `RunState.TOTAL_FLOORS` 显示 `层数 x/12`（数值 12，地图仍 6 层直至阶段二）**

- [ ] **Step 4: Commit**

```bash
git add scripts/core/MapGenerator.gd scripts/Main.gd
git commit -m "refactor(core): MapGenerator stub for phase 1"
```

---

### Task 9: Main.gd 收尾与文档

**Files:**
- Modify: `scripts/Main.gd`, `CLAUDE.md`, `README.md`, `docs/superpowers/specs/2026-05-21-architecture-three-act-design.md`（状态→阶段一完成）

- [ ] **Step 1: 删除 Main 中已迁移的重复函数与成员变量**

- [ ] **Step 2: `_start_run` 使用 `run_state.reset_for_origin`**

- [ ] **Step 3: `_on_combat_ended(kind)` 分发 reward / victory / game_over**

- [ ] **Step 4: 确认 `Main.gd` 行数 ≤ 750**

- [ ] **Step 5: 更新 `CLAUDE.md` 架构节**

- [ ] **Step 6: 全量冒烟**

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

- [ ] **Step 7: Commit**

```bash
git add scripts/Main.gd CLAUDE.md README.md
git commit -m "refactor: Main as UI shell; docs update for phase 1"
```

---

## Plan self-review

| Spec §2 要求 | Task |
|--------------|------|
| DataRegistry | Task 3 |
| RunState + constants | Task 4, 8 |
| CombatController + signals | Task 5 |
| CardEffect γ | Task 1–2, 6–7 |
| MapGenerator 薄封装 | Task 8 |
| Main UI only | Task 9 |
| smoke test | 5, 7, 9 |

无 TBD；阶段二 Boss 规则在阶段一保留 `boss` 标志，阶段二计划修正。

---

## 依赖

**前置：** 无  
**后续：** `docs/superpowers/plans/2026-05-21-phase2-three-act-map.md`
