# 阶段十一：平衡调优与内容扩充 — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段一至十（完整 12 层管线）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase11-balance-content.md`

---

## 1. 目标与范围

### 1.1 问题

功能管线已齐，但 **可玩性抛光** 仍有三处缺口：

| 痛点 | 现状 |
|------|------|
| 幕间难度曲线 | 敌人 HP/卢恩来自静态 `.tres`，**幕 3 普通战与幕 1 同数值**，后期压力不足 |
| 奖励池噪音 | 宁姆格福 `reward_cards` 含 `heal`、`glintstone_pebble`（**starter**），`roll_rewards` 过滤后有效池偏小 |
| 构筑深度 | 仅 **5** 护符、**~10** 张非 starter 卡可进池，12 层跑团重复感高 |

### 1.2 目标

1. **按幕难度缩放**：幕 2/3 敌人 HP 乘数（数据在 `ActData`）。  
2. **卢恩经济微调**：`tools/build_enemies.py` 统一维护敌人 `max_hp` / `souls`，按 normal / elite / boss 分层校对。  
3. **修正 `reward_cards`**：三幕池仅含 **非 starter** 卡牌 id。  
4. **内容扩充**：新增 **3** 护符、**4** 张卡牌（含 `effects` 或 `hook_id`）。  
5. **可选护符 hook**：`combat_souls_bonus`（战斗结束额外卢恩），供 1 张新护符使用。  
6. 保持机制不变：不增幕、不改层数、不改战斗规则。

### 1.3 验收标准

| # | 标准 |
|---|------|
| B1 | `ActData.enemy_hp_percent`（默认 100/110/125）在 `CombatController.start_combat` 生效 |
| B2 | `build_enemies.py` 再生或更新敌人 `.tres`；精英/Boss `souls` 与 HP 符合 §3.2 表 |
| B3 | 三幕 `reward_cards` 无 starter；每幕有效池 ≥ 4 张 |
| B4 | `data/relics/` +3、`data/cards/` +4；新卡可进至少一幕 `reward_cards` |
| B5 | `RelicService` 支持 `combat_souls_bonus`（若采用该护符） |
| B6 | `tools/balance_content_test.gd` 通过；现有冒烟/单元测试仍通过 |
| B7 | 实现后 **git commit** |

### 1.4 非目标（YAGNI）

- 完整自动化战斗模拟器 / Monte Carlo 平衡
- 按出身差异化难度、动态难度调整
- 改 merchant 全表价格、事件权重
- 新敌人种类（仅调数值，不强制新 `.tres` 敌人）
- 卡牌升级、铁匠、药水系统

---

## 2. 难度缩放

### 2.1 `ActData` 字段

```gdscript
@export var enemy_hp_percent: int = 100   # 幕内敌人 max_hp 乘数，战斗开始时应用
```

| 幕 | id | `enemy_hp_percent` |
|----|-----|-------------------|
| 1 | limgrave | 100 |
| 2 | stormveil | 110 |
| 3 | liurnia | 125 |

### 2.2 `CombatController.start_combat`

在 `enemy = template.duplicate(true)` 之后：

```gdscript
var act := registry.get_act(run.act_index())
if act != null and act.enemy_hp_percent != 100:
    var scaled := int(round(float(enemy.max_hp) * act.enemy_hp_percent / 100.0))
    enemy.max_hp = maxi(1, scaled)
enemy.hp = enemy.max_hp
```

**不缩放：** 玩家 HP、敌人伤害（首版仅拉长跑团时长，避免伤害公式二次调参）。

---

## 3. 卢恩与敌人数值

### 3.1 `tools/build_enemies.py`（新建）

从现有 `data/enemies/*.tres` 迁移为 Python 表 + 生成器（与 `build_relics.py` 同模式），便于一次性校对。

**分层目标（首版参考，实现时可 ±10%）：**

| 层级 | HP 范围 | souls 范围 | 示例 |
|------|---------|------------|------|
| normal | 28–48 | 10–24 | 野狼、葛瑞克士兵 |
| elite | 60–75 | 38–50 | 兽人、守墓斗士 |
| act boss | 95–115 | 90–130 | 玛尔吉特、熔炉骑士（幕末） |
| run boss | 120–140 | 150–200 | 接肢贵族 |

**原则：**

- 普通战卢恩略升，保证幕 2–3 能买 1–2 次商人货。  
- 精英 `souls` 明显高于同幕普通战（战后还有护符屏）。  
- Boss 战不变 `is_act_boss` / `is_run_boss` 逻辑，只调资源文件数值。

### 3.2 出身基准（不改）

出身 `max_hp` / 初始牌组保持现状；平衡以 **流浪骑士** 12 层通关为手感参考（可死可赢，幕 3 需依赖构筑）。

---

## 4. 奖励池修正

### 4.1 `build_acts.py` 更新

| 幕 | 移除（starter） | 建议替换为 |
|----|-----------------|------------|
| limgrave | `heal`, `glintstone_pebble` | `scimitar`, `catch_flame`（或 `club` 若改为 common） |
| stormveil | （检查无 starter） | 可保留现有 5 张 |
| liurnia | （检查） | 将新卡 `rock_sling`、`flame_grant_me_strength` 写入池 |

实现时以 `CardData.rarity != "starter"` 为准扫描校验脚本。

---

## 5. 新增内容

### 5.1 护符 +3（`build_relics.py`）

| id | 名 | hook | value | 说明 |
|----|-----|------|-------|------|
| `erdtree_favor` | 黄金树恩惠 | `on_acquire_max_hp` | 12 | 获得时 +12 最大生命 |
| `green_turtle_talisman` | 绿龟护符 | `combat_start_block` | 3 | 战斗开始 +3 护甲 |
| `gold_scarab` | 金色粪金龟 | `combat_souls_bonus` | 5 | 战斗结束 +5 卢恩 |

`combat_souls_bonus`：在 `CombatController.check_combat_end` 胜利分支，`run.souls += relic_service.combat_souls_bonus(run, registry)`。

### 5.2 卡牌 +4（手工或 `tools/build_cards.py` 扩展）

| id | 名 | type | rarity | cost | 效果概要 |
|----|-----|------|--------|------|----------|
| `rock_sling` | 岩石球 | 魔法 | common | 1 | 6 伤害 |
| `flame_grant_me_strength` | 火焰啊，赐予我力量！ | 祷告 | uncommon | 1 | +2 力量本回合 |
| `glintstone_stars` | 辉石流星 | 魔法 | uncommon | 2 | 4×2 伤害 |
| `hoarfrost_stomp` | 冰雾踏地 | 战灰 | common | 1 | 5 伤害 + 3 姿态 |

每张卡需提供 `effects` 链或既有 `hook_id`；颜色 `tone` 与类型一致。

**入池：** 至少写入 limgrave / liurnia 的 `reward_cards` 各 1–2 张。

---

## 6. 测试

### 6.1 `tools/balance_content_test.gd`

1. 幕 0/1/2 `enemy_hp_percent` 为 100/110/125。  
2. `start_combat` 后敌人 `max_hp` 按幕缩放（用 mock template max_hp=100 断言）。  
3. 三幕 `reward_cards` 无 `rarity==starter` 的 id。  
4. `gold_scarab` 战斗结束卢恩 +5（若实现 hook）。  
5. 新护符/新卡 `registry.get_*` 非空。

### 6.2 回归

```bash
godot4.6 --headless --path . --script tools/smoke_test.gd
godot4.6 --headless --path . --script tools/act_content_test.gd
```

### 6.3 手工

- 幕 1→3 体感敌人更肉、卢恩更可买商人货。  
- 战后奖励不出现 starter 牌名。

---

## 7. 风险与决策

| 议题 | 决策 |
|------|------|
| 只缩放 HP 不缩放伤害 | 首版接受；避免双变量难测 |
| 是否重写全部敌人 tres | 用 `build_enemies.py` **覆盖生成**，以 Python 表为源 |
| 新卡效果复杂度 | 优先 `CardEffectStep` 链，避免新 hook |
| `combat_souls_bonus` | 仅 1 个护符需要，值得加 |

---

## 8. 文档与提交

- 更新 `README.md` 已实现列表（护符 8、新卡）  
- `CLAUDE.md` Recommended Next → 音效/UI/更多事件  
- 提交：`feat(game): phase 11 balance scaling, soul tuning, and content expansion`
