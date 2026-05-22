# 架构重构与三幕地图 — 设计规格

**日期：** 2026-05-21  
**状态：** 阶段一、阶段二已实现（2026-05-21）；实现计划见 `docs/superpowers/plans/`  
**决策摘要：** 阶段一 L2 模块拆分 + 卡牌效果数据化（方案 γ）；阶段二 S3 三幕 12 层地图（宁姆格福 → 史东薇尔 → 利耶尼亚）。

---

## 1. 目标与范围

### 1.1 总目标

在保持现有可玩原型前提下，使「改一张牌 / 加一层地图」主要通过改资源与小模块完成，而非编辑巨型 `Main.gd`。

### 1.2 阶段划分

| 阶段 | 内容 | 验收 |
|------|------|------|
| **一** | `DataRegistry`、`RunState`、`CombatController`、`CardEffectResolver`；UI 留 `Main.gd` | `godot4.6 --headless --script tools/smoke_test.gd` 全出身通过；战斗行为与重构前一致 |
| **二** | `ActData` ×3、`MapGenerator`、12 层、`is_act_boss` / `is_run_boss` 胜利分级 | 冒烟 + 地图边界单元断言；可打通 12 层至最终胜利 |

### 1.3 明确不做（YAGNI）

- 阶段一：护符、商人、赐福升级、多场景 `.tscn` 拆分（L3）
- 阶段二：不强制新增 12 个全新敌人资源（先复用现有 15 敌分池）
- 本规格不包含：记忆石、战灰替换、咖列商人（后续独立变更）

---

## 2. 阶段一：L2 架构

### 2.1 目录结构

```
scripts/
  Main.gd
  core/
    DataRegistry.gd
    RunState.gd
    CombatController.gd
    MapGenerator.gd          # 阶段一薄封装，转发现有 _map_options
    CardEffectResolver.gd
data/
  CardData.gd                # +effects, +hook_id, +exhaust_after_play
  CardEffectStep.gd          # 新建
```

### 2.2 DataRegistry

- 迁移 `_load_cards`、`_load_origins`、`_load_enemies`、`_enemy_to_dict`
- API：`get_card(id)`, `all_card_ids()`, `get_origin(id)`, `enemy_templates()`, `template_by_name(name)`
- 可作为 Autoload `DataRegistry` 或由 `Main` 在 `_ready` 持有单例

### 2.3 RunState

**字段：** `run_seed`, `origin_id`, `hp`, `max_hp`, `flasks`, `souls`, `floor_index`, `act_index`, `deck`, 四堆牌, `player_rot/bleed/vulnerable/strength`, （可选）`log_lines`

**常量：**

```gdscript
const FLOORS_PER_ACT := 4
const ACT_COUNT := 3
const TOTAL_FLOORS := 12
```

阶段一运行时仍可使用 `TOTAL_FLOORS = 6` 的兼容开关，或常量定为 12 但 `MapGenerator` 仍按 6 层生成直至阶段二启用——**推荐阶段一末尾即改用 `TOTAL_FLOORS` 单点常量**，阶段二只换 `MapGenerator` 实现。

**方法：** `reset_for_origin(origin)`, `advance_floor()`, `is_act_boss_floor() -> bool`（`floor_index % 4 == 3`）

### 2.4 CombatController

- 依赖：`RunState`, `DataRegistry`
- 战斗局部状态：`enemy`, `enemy_intent`, `combat_over`, `ember`, `block`
- 公开方法：`start_combat(template)`, `play_card(index)`, `end_player_turn()`, `use_flask()`, …
- 信号：`combat_changed`, `combat_ended(kind: String)`, `log_message(text: String)`
  - `kind`: `"reward"` | `"act_clear"` | `"run_victory"` | `"none"`

### 2.5 卡牌效果（方案 γ）

**CardEffectStep**（Resource）：

- `kind` 枚举：`DAMAGE`, `MULTI_HIT_DAMAGE`, `GAIN_BLOCK`, `HEAL`, `DRAW`, `APPLY_BLEED`, `APPLY_VULN`, `APPLY_ROT`, `STANCE_DAMAGE`（按实现裁剪）
- `value`, `stance`, `hits` 等数值字段

**CardData 扩展：**

- `effects: Array[CardEffectStep]`
- `hook_id: String` — 非空时执行 `CardEffectHooks` 命名钩子
- `exhaust_after_play: bool`

**钩子表（阶段一必须覆盖现有 match 行为）：**  
`heater_shield`, `buckler`, `longbow`, `club`, `battle_axe`, `lions_claw`, `magic_glintblade`, `destined_death`（其余卡用 `effects` 链）

**打牌流程：** 校验集中 → 扣费 → 移出手牌 → hook 或 effects 链 → exhaust/弃牌 → 检查战斗结束

### 2.6 Main.gd

- 保留：`_build_ui`, 各 `_show_*`, `_render_combat`, 主题与控件工厂
- 按钮事件委托 `CombatController` / `RunState`
- **禁止** 新增 `match card_id` 效果逻辑

**目标行数：** 500–700 行（UI 为主）

### 2.7 阶段一迁移顺序

1. DataRegistry + 加载无误  
2. RunState + `_start_run`  
3. CombatController（伤害、意图、敌人回合）  
4. CardEffectResolver + 24 卡资源配置 + 删除 `_play_card` match  
5. 冒烟测试  

---

## 3. 阶段二：三幕地图（S3）

### 3.1 楼层表

| floor_index | act_index | 类型 |
|-------------|-----------|------|
| 0–2 | 0 | 宁姆格福普通节点 ×3 选 1 |
| 3 | 0 | 幕末 Boss：恶兆妖鬼玛尔基特 |
| 4–6 | 1 | 史东薇尔普通节点 |
| 7 | 1 | 幕末 Boss（首版可用熔炉骑士占位，标 `is_act_boss`） |
| 8–10 | 2 | 利耶尼亚普通节点 |
| 11 | 2 | 跑团最终 Boss（接肢贵族 / `mohg_lovula`，`is_run_boss`） |

`act_index = floor_index / FLOORS_PER_ACT`

### 3.2 ActData.tres

字段：`id`, `title`, `subtitle_template`, `flavor`, `combat_enemies[]`, `elite_enemies[]`, `map_nodes[]`, `act_boss`, `act_boss_title`, `act_boss_body`, `is_final_act`, `run_boss`（仅最终幕）

文件：`data/acts/limgrave.tres`, `stormveil.tres`, `liurnia.tres`

### 3.3 MapGenerator

- `options_for_floor(state, registry) -> Array[Dictionary]`
- 幕末层：返回单 Boss 选项
- 普通层：合并 `map_nodes` 与随机战斗/精英节点，shuffle 取 3；赐福类节点保证入池

### 3.4 EnemyData 扩展

```gdscript
@export var is_act_boss: bool = false
@export var is_run_boss: bool = false
```

**战斗结束规则：**

| 条件 | 结果 |
|------|------|
| 普通/精英 | 战后三选一 → `floor_index++` → 地图 |
| `is_act_boss` 且非最终幕 | 幕间奖励（回满/补瓶 + 可选一张牌）→ 下一幕 |
| `is_run_boss` | `_show_victory()` |

**修正：** 移除「任意 `is_boss` 即胜利」；胜利文案与最终 Boss 一致。

### 3.5 敌池（首版）

| 幕 | 普通（示例） | 精英（示例） | Boss |
|----|--------------|--------------|------|
| 宁姆格福 | 葛瑞克士兵、野狼、凯丹佣兵、挖石矿工、学院辉石法师 | 兽人、亚人首领、挖石山妖 | 玛尔基特 |
| 史东薇尔 | 葛瑞克骑士、腐败眷属、石矿工异种 | 熔炉骑士、守墓斗士 | 幕 Boss 占位 |
| 利耶尼亚 | 池内现有骑士/法师类 | 石像鬼骑士等 | 接肢贵族 |

敌名与 `EnemyData.name` 一致，通过 `DataRegistry.template_by_name` 解析。

### 3.6 UI

- 地图标题/描述来自当前 `ActData`
- Header：`{幕名} · {层+1}/12` 或 `总进度 {floor+1}/12`

---

## 4. 测试与文档

### 4.1 测试

| 项 | 阶段 |
|----|------|
| `tools/smoke_test.gd` 六出身 | 一、二回归 |
| 固定 seed 战斗快照（可选） | 一 |
| `MapGenerator` 楼层 3/7/11 仅 Boss | 二 headless |
| _viewport 1280×720 面板不溢出 | 一、二 |

### 4.2 文档更新（阶段一完成后）

- `CLAUDE.md`：架构表改为 modules + `.tres`，删除「字典在 Main」描述
- `README.md`：推荐下一步勾选「数据外置」，改为三幕与模块说明

### 4.3 风险与缓解

| 风险 | 缓解 |
|------|------|
| 效果迁移数值偏差 | 逐卡对照旧 `match`；冒烟 + 手动打一张牌 |
| `Main` 与 Controller 双写状态 | 战斗数值只存在于 Controller；Run 只持跑团字段 |
| 12 层节奏过长 | 幕末奖励加强；普通战卢恩/选牌可调 |
| Boss 标记混乱 | 仅 `is_run_boss` 触发 VICTORY |

---

## 5. 方案选型记录

- **路线：** γ 混合（EffectStep + 少量 hook）
- **顺序：** A1 架构优先
- **粒度：** L2
- **阶段二：** P3 三幕，S3 共 12 层

---

## 6. 规格自检（已完成）

- [x] 无 TBD / TODO 占位
- [x] 阶段一/二边界一致；胜利规则与 §3.4 一致
- [x] 范围可拆为两份 implementation plan（阶段一、阶段二）
- [x] `TOTAL_FLOORS` 单点常量策略已写明（阶段一末尾统一）
