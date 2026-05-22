# 阶段九：按幕内容扩充与 UI 抛光 — 设计规格

**日期：** 2026-05-21  
**状态：** 阶段九已实现（2026-05-21）  
**前置：** 阶段二 `ActData` 三幕地图、阶段八战后护符  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase9-act-content.md`

---

## 1. 目标与范围

### 1.1 问题

当前三幕结构已可打通 12 层，但**内容层**仍偏「全局池 + 硬编码文案」：

| 痛点 | 现状 |
|------|------|
| 地图遭遇文案 | `MapGenerator` 内 `COMBAT_NODES` / `ELITE_NODES` 字典与 `ActData.combat_enemies` **双处维护**，易漂移 |
| 战后卡牌 | `CombatController.roll_rewards()` 从**全库非 starter** 抽 3 张，后期幕与前期幕奖励无差异 |
| 敌人利用 | 15 个敌人 `.tres` 中 **「亚人」** 未进任何幕池；幕间敌种重复率高（如「法姆亚兹拉的兽人」出现在幕 1、2） |
| Header | 仅显示 `层数 n/12`，**不显示当前幕名**（阶段二 Task 7 遗留） |
| 第三幕 | `liurnia` **无商人节点**，与 README「咖列」叙事不一致 |

### 1.2 目标

1. **数据驱动遭遇**：遭遇标题/描述随 `ActData` 配置，删除 `MapGenerator` 硬编码字典。  
2. **按幕奖励池**：战后卡牌三选一优先从当前幕 `reward_cards` 抽取。  
3. **扩充可玩内容**：每幕至少 **+1 普通敌人进池**、**+2 张战后可抽卡牌**（新建或从全库划入）；利耶尼亚补 **1 个商人节点**。  
4. **Header 抛光**：顶栏显示 **幕名 + 幕内段数 + 总层数**。  
5. 保持 12 层 / 三幕 / 现有战斗逻辑不变。

### 1.3 验收标准

| # | 标准 |
|---|------|
| C1 | `ActData` 含 `combat_encounters` / `elite_encounters`（或等价结构），`MapGenerator` 不再含 `COMBAT_NODES` / `ELITE_NODES` 常量表 |
| C2 | `roll_rewards(act_index)`（或 `CombatController` 接收 `ActData`）仅从当前幕 `reward_cards` 抽牌；池不足 3 张时回退全库非 starter |
| C3 | 三幕 `build_acts.py` 更新：敌池差异化、利耶尼亚有商人；冒烟 + `map_generator_test` 仍通过 |
| C4 | 新增 `tools/act_content_test.gd`：断言每幕 reward 池非空、遭遇字典可由 act 生成 |
| C5 | Header 显示形如 `宁姆格福路标 · 2/4 · 层 3/12`（幕名取自 `ActData.title`） |
| C6 | 实现后 **git commit** |

### 1.4 非目标（YAGNI）

- 第四幕、层数改为 18+、新 GameScreen
- 敌人全新招式 / Boss 二阶段
- 卡牌 `act_tags` 全库自动标注（首版用 `ActData.reward_cards` 显式列表即可）
- 按幕商人不同商品表
- 地图分支图、事件节点

---

## 2. 数据模型

### 2.1 `MapEncounterData`（新建 Resource）

```gdscript
# res://data/MapEncounterData.gd
@export var enemy_name: String = ""   # 对应 EnemyData.name（与 template_by_name 一致）
@export var title: String = ""
@export var body: String = ""
```

### 2.2 `ActData` 扩展

| 字段 | 类型 | 说明 |
|------|------|------|
| `combat_encounters` | `Array[MapEncounterData]` | 替代 `combat_enemies: Array[String]` |
| `elite_encounters` | `Array[MapEncounterData]` | 替代 `elite_enemies: Array[String]` |
| `reward_cards` | `Array[String]` | 卡牌 **id**（如 `glintstone_arc`），战后奖励池 |

**迁移策略（推荐）：**

- `build_acts.py` 一次生成新字段；**删除** `combat_enemies` / `elite_enemies` 字符串数组，避免双源。
- `MapGenerator._combat_option` / `_elite_option` 改为接收 `MapEncounterData`。

**幕内奖励池（首版建议 id）：**

| 幕 | `reward_cards`（示例，实现时以现有 `.tres` 为准） |
|----|--------------------------------------------------|
| 宁姆格福 | `great_knife`, `bloodhounds_step`, `assassins_approach`, `glintstone_pebble`, `heal` |
| 史东薇尔 | `lions_claw`, `black_flame`, `rotten_breath`, `battle_axe`, `longbow` |
| 利耶尼亚 | `glintstone_arc`, `volcano_pot`, `catch_flame`, `destined_death`, `magic_glintblade` |

> `destined_death` 仍可出现在利耶尼亚池（与赐福购买叠加为构筑选择）；全库回退保证池永远 ≥1。

### 2.3 敌人池调整（首版）

| 幕 | 普通遭遇（新增/调整） | 精英 |
|----|----------------------|------|
| 宁姆格福 | 保留现有 5 种 + **亚人** | 保持 3 精英；**移除**幕 2 对「法姆亚兹拉的兽人」的重复（仅留幕 1） |
| 史东薇尔 | 以城墙/腐败主题为主；**不**再抽幕 1 兽人 | 熔炉骑士、守墓斗士 + **挖石山妖**（已在池） |
| 利耶尼亚 | 学院/腐败/骑士；可保留 **亚人首领** 作精英 | 熔炉骑士、守墓斗士、挖石山妖 |

**Boss 不变：** 玛尔吉特 / 熔炉骑士（幕末）/ 接肢贵族（最终 run boss）。

### 2.4 利耶尼亚商人

在 `build_acts.py` 的 `liurnia` 增加：

- `("湖畔咖列", "咖列把船系在教堂遗迹旁，高价收购卢恩，低价卖出麻烦。")`

---

## 3. 运行时行为

### 3.1 地图生成

```text
options_for_floor(run, registry, rng):
  if act_boss_floor → boss 节点（不变）
  pool = fixed_nodes + combat_encounters + elite_encounters
  shuffle → slice(0, 3)
```

遭遇 `enemy_name` 必须能在 `DataRegistry.template_by_name` 解析。

### 3.2 战后卡牌

```gdscript
func roll_rewards(act: ActData) -> Array[String]:
    var pool := act.reward_cards.duplicate() if act else []
    # 过滤 starter、可选过滤已在牌组（首版不过滤，与现行为一致）
    if pool.size() < 3:
        pool = _global_non_starter_pool()
    pool.shuffle()
    return pool.slice(0, 3)
```

`Main` / `CombatController` 在 `_show_card_rewards` 前传入 `registry.get_act(run.act_index())`。

### 3.3 Header

```gdscript
# _build_header 追加或替换层数 stat：
var act := registry.get_act(run_state.act_index())
var local := (run_state.floor_index % RunState.FLOORS_PER_ACT) + 1
if act != null:
    stat = "%s · %d/%d · 层 %d/%d" % [act.title, local, RunState.FLOORS_PER_ACT, run_state.floor_index + 1, RunState.TOTAL_FLOORS]
```

地图页标题区保持 `act.title` + `subtitle_template`（已实现），与 Header 信息一致即可。

---

## 4. 工具与生成

| 工具 | 变更 |
|------|------|
| `tools/build_acts.py` | 输出 `MapEncounterData` sub_resource；`reward_cards`；利耶尼亚 merchant |
| `tools/build_encounters.py` | **可选**；若 encounters 条目多，可从 Python 表生成 |
| `tools/act_content_test.gd` | 新建：三幕 act 加载、reward_cards 非空、encounter enemy 可解析 |

**禁止** 用 PowerShell 写含中文的 `.tres`；沿用 Python UTF-8 生成。

---

## 5. 测试

### 5.1 自动化

- `tools/act_content_test.gd`（新建）
- 更新 `tools/map_generator_test.gd`：断言幕 0 选项含 `kind: combat` 且 `enemy` 来自该幕 encounters
- `tools/smoke_test.gd` 无需改流程（仍走普通战 + 赐福）

### 5.2 手工

- 幕 1/2/3 各打一局，战后卡牌名称应符合该幕主题池
- Header 在三幕切换时幕名变化
- 利耶尼亚地图可出现商人节点

---

## 6. 风险与决策

| 议题 | 决策 |
|------|------|
| 是否保留 `combat_enemies: Array[String]` | **删除**，一次迁移到 `MapEncounterData` |
| reward 池是否要「已拥有则权重降低」 | 首版 **否**，与现全局 roll 一致 |
| 是否新增卡牌 `.tres` | **可选 +2/幕**；若时间紧，仅重划 `reward_cards` 也算完成 C2 |
| 熔炉骑士既在幕 2 精英又在幕 2 Boss | 保留（精英遭遇 vs 幕末 Boss 战不同节点） |

---

## 7. 文档与提交

- 实现后更新本文件状态为「已实现」
- `CLAUDE.md`：Recommended Next 改为「平衡性 / 更多护符 / 事件节点」等
- 提交信息：`feat(game): phase 9 per-act encounters, reward pools, and header polish`
