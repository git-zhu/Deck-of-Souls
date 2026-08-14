# 人物属性加点 + 法环式伤害 + 武器升级（锻造石）— 可行性分析

> 日期：2026-05-23
> 状态：**可行性分析**（设计论证，未实现）
> 目标：评估为《老头牌》引入 ①人物属性加点 ②法环式属性+武器伤害 ③锻造石武器升级 的可行性。

---

## 1. 结论摘要

| 系统 | 可行性 | 核心依据 |
|------|--------|---------|
| 人物属性加点（篝火卢恩升级） | ✅ **可行** | RunState 已有 souls；GraceService 已有"花费卢恩"先例；法环升级曲线可用公式拟合 |
| 法环式伤害（属性+武器等级） | ✅ **可行，需重构伤害链路** | CardEffectResolver 伤害集中在 `deal_enemy_damage` + `step.value`，可插拔公式；武器系统已开建（WeaponData） |
| 武器升级（1/2/3 级锻造石） | ✅ **可行** | 商人系统已有 `add_random_card`/offer 机制可扩展"锻造石"商品；WeaponData 可加 `level`/锻造石字段 |
| 与现有平衡 | ⚠️ **需全局数值重平衡** | 属性加成会放大伤害，需重调敌人 HP/卢恩/卡牌数值 |

**总评**：技术上**完全可行**，改动集中（伤害公式 + RunState + 篝火/商人选项 + UI）。主要成本在**数值平衡**而非代码结构。

---

## 2. 现有系统盘点（改造基础）

| 系统 | 现状 | 可复用点 |
|------|------|---------|
| 属性 | RunState：hp/max_hp/flasks/souls/relics/memory_stones；出身 stats 文本（力量/灵巧/集中/信仰） | `origin.stats` 已有属性描述，可结构化 |
| 卢恩经济 | 敌人掉落 12-180；篝火 `add_card` 花 50-150；商人商品 `soul_cost` | souls 已全程贯通 |
| 伤害计算 | `CardEffectResolver` → `deal_enemy_damage(step.value + strength, step.stance)`；武器 attack_bonus 尚未接入 | 单点公式，易替换 |
| 篝火 | `GraceService`：3 选项 + `apply`（heal/max_hp/删牌/记忆石/战灰） | 可加"属性升级""武器升级"选项 |
| 商人 | `MerchantService`：offer 商品 + `soul_cost` + 按幕货池 | 可加"锻造石"商品（分等级） |
| 武器 | `WeaponData`（attack_bonus/stance_bonus/block_bonus/draw_bonus/effect_hook）；RunState.weapons；11 个武器数据 | 已建基座，需加 `level` + 锻造石 |

---

## 3. 人物属性加点设计

### 3.1 属性定义（源自出身 stats）
出身 stats 已是文本（如"力量 14 / 灵巧 13 / 集中 15"），结构化为：
- `vigor 生命`：+1 → +2 最大生命
- `strength 力量`：+1 → 物理卡伤害 +1
- `dexterity 灵巧`：+1 → 姿态伤害 +1（或抽牌）
- `mind 集中`：+1 → 每回合集中 +1（上限）
- `faith 信仰`：+1 → 祷告卡伤害/治疗 +1

**RunState 新增**：`attrs: Dictionary`（vigor/strength/dexterity/mind/faith）+ `attr_levels`（当前升级次数）。

### 3.2 升级成本曲线（法环拟合）
法环升级卢恩成本为分段线性增长（约 673→892→1166→1530→...，越级越贵）。
本项目卢恩量级小（单战 12-180），设计**压缩曲线**：

```
cost(level) = base + level * slope
  level 0-4:   base=20, slope=10   → 20,30,40,50,60
  level 5-9:   base=60, slope=20   → 80,100,120,140,160
  level 10+:   base=160, slope=40  → 200,240,...
```

- 一局 12 层约赚 800-1200 卢恩 → 可升级 **6-9 次**（每属性 1-2 点），符合 roguelike 单局成长。
- 公式实现为 `LevelingService.upgrade_cost(attr, current_level)`，与法环同构（分段线性、加速增长）。

### 3.3 篝火交互
- 篝火选项新增"升级属性"（进入属性选择子界面，展示各属性当前值/升级效果/所需卢恩）。
- 与现有"恢复/删牌/记忆石"并列，玩家二选一或三选一。

---

## 4. 法环式伤害公式

### 4.1 当前公式（简化）
```
伤害 = step.value + 力量buff
```

### 4.2 目标公式（法环：属性补正 × 武器等级）
```
攻击力 = (卡牌基础值 + 力量/灵巧/信仰补正) × (1 + 武器等级系数)
武器等级系数 = 0 + 0.1 × weapon_level   # +10 级 → +100% 基础伤害
```

- **物理卡**（武器/战技）：补正 = 力量(×1.0) + 灵巧(×0.5)
- **法术卡**（魔法）：补正 = 集中(×1.0)
- **祷告卡**：补正 = 信仰(×1.0)
- **武器升级**：同类型武器等级直接放大该系伤害

### 4.3 接入点
`CardEffectResolver._apply_step` 的 DAMAGE/DAMAGE_ALL 分支 → 调 `combat.calculate_card_damage(card, step)`：
```
final = int(round((step.value + attr_bonus) * weapon_multiplier)) + strength
```
- `CombatController.calculate_card_damage` 为唯一入口，测试可精确验证。

### 4.4 姿态伤害
`stance_damage = step.stance + 灵巧补正`（可选）。

---

## 5. 武器升级（锻造石）设计

### 5.1 WeaponData 扩展
```
@export var level: int = 0            # 0-10
@export var smithing_stone_cost: Array[int] = [1,2,2,3,3,4,4,5,5,6]  # 每级所需 1 级锻造石
```
（不同武器可用不同等级锻造石：普通武器 1 级石，特殊武器 2 级石，传说武器 3 级石）

### 5.2 锻造石等级与获取
| 锻造石 | 获取途径 | 幕 |
|--------|---------|-----|
| 1 级锻造石（Smithing Stone 1） | 普通战掉落、篝火、商人 | 幕1 大量 |
| 2 级锻造石 | 精英战掉落、商人（几率） | 幕2 大量 |
| 3 级锻造石 | Boss 战掉落、商人（低几率） | 幕3 大量 |

- **RunState 新增**：`smithing_stones: Array[int]`（[1级数, 2级数, 3级数]）。
- **商人商品**：新增 3 个 `MerchantOfferData`（锻造石×N，`soul_cost` 分级），按幕货池配置（幕1 只卖 1 级、幕3 有几率卖全部）。
- **升级**：篝火"武器升级"选项 → 消耗对应锻造石 + 卢恩 → `weapon.level += 1`。

### 5.3 升级消耗（参考法环）
| 武器等级 | 1级石 | 2级石 | 3级石 | 卢恩 |
|---------|-------|-------|-------|------|
| 0→1 | 2 | - | - | 30 |
| 1→2 | 2 | - | - | 40 |
| 2→3 | 3 | - | - | 50 |
| 3→4 | 3 | 1 | - | 60 |
| 4→5 | 4 | 1 | - | 70 |
| 5→6 | - | 2 | - | 90 |
| 6→7 | - | 3 | - | 110 |
| 7→8 | - | 3 | 1 | 130 |
| 8→9 | - | - | 2 | 160 |
| 9→10 | - | - | 3 | 200 |

---

## 6. 影响面与改动清单

| 文件 | 改动 |
|------|------|
| `data/WeaponData.gd` | +level/+smithing_stone_cost |
| `data/weapons/*.tres` | 补字段 |
| `scripts/core/RunState.gd` | +attrs/+attr_levels/+smithing_stones |
| `data/OriginData.gd` | stats 结构化为 attrs 初始值 |
| `scripts/core/CombatController.gd` | +calculate_card_damage() |
| `scripts/core/CardEffectResolver.gd` | DAMAGE 分支接入公式 |
| `scripts/core/LevelingService.gd`（新） | 升级成本/应用 |
| `scripts/core/GraceService.gd` | +属性升级/+武器升级选项 |
| `data/grace_options/*.tres` | +新选项 |
| `scripts/core/MerchantService.gd` | +锻造石商品 |
| `data/merchant_offers/*.tres` | +锻造石×3 |
| `data/acts/*.tres` | 货池/掉落配置 |
| `scripts/ui/*.gd` | 属性/武器 UI |
| 存档 `RunSaveService.gd` | 新字段序列化 |
| **数值平衡** | 敌人 HP/卢恩、卡牌数值需整体重调 |

**工作量估计**：核心逻辑 1-2 天；数值平衡 1-2 天；UI 1 天。

---

## 7. 风险与对策

| 风险 | 对策 |
|------|------|
| 属性加成 → 伤害爆炸 | 公式用乘法系数（×1.0 起步）+ 敌人 HP 同步上调；Monte Carlo 工具验证胜率 |
| 卢恩经济失衡 | 升级曲线压缩（见 3.2）；掉落与消耗联动测试 |
| 锻造石卡进度 | 商人按幕出售保底 + 精英/Boss 掉落保底 |
| 存档破坏 | RunSaveService 向后兼容（旧存档缺失字段给默认值） |
| 单局成长感不足 | 12 层保证 6-9 次升级机会（篝火 3 次 + 可选） |

---

## 8. 实施建议（若批准）

分 3 阶段：
1. **P1 属性加点**：RunState attrs + LevelingService + 篝火选项 + UI → 纯属性增益（生命/集中/抽牌）
2. **P2 法环伤害公式**：calculate_card_damage + 武器等级倍率 + 平衡重调（Monte Carlo）
3. **P3 锻造石升级**：WeaponData.level + 锻造石获取/商人 + 篝火武器升级

每阶段独立可测、可提交。
