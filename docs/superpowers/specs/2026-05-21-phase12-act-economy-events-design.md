# 阶段十二：按幕经济与事件深化 — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段一至十一（含 `enemy_hp_percent`、8 护符、地图事件管线）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase12-act-economy-events.md`

---

## 1. 目标与范围

### 1.1 问题

阶段十/十一完成后，**12 层跑团**在系统上可通关，但地图与商人仍偏「单池、等权重」：

| 痛点 | 现状 |
|------|------|
| 地图节奏 | `MapGenerator` 将战斗/精英/事件/赐福/商人条目 **同等 shuffle**，事件仅 2 个 id，出现率低于大量遭遇战 |
| 商人同质化 | `MerchantService.roll_stock` 从 **全局 8 个** offer 抽 3 个；三幕咖列货架相同，幕 3 卢恩盈余难转化为构筑 |
| 事件体量 | 仅 **6** 个 `MapEventData`；阶段十规格明确延后了 **事件权重** |

### 1.2 目标

1. **按幕商人货池**：`ActData.merchant_offer_ids` 限定每幕可刷出的 offer；幕 2/3 引入更高价/高价值货。  
2. **按幕商人价格**：`ActData.merchant_cost_percent` 在结算时缩放 `soul_cost`（显示与扣款一致）。  
3. **地图加权抽样**：`MapGenerator` 按条目 `kind` 与 `ActData` 权重 **无放回** 抽 3 个路径选项，提高事件相对频率。  
4. **事件扩充**：再增 **6** 个事件（每幕 +2），仍用现有 `EventService` effect 表。  
5. 不改层数、战斗规则、UI 场景结构。

### 1.3 验收标准

| # | 标准 |
|---|------|
| E1 | 三幕 `ActData` 含 `merchant_offer_ids`、`merchant_cost_percent`（建议 100 / 105 / 95） |
| E2 | `_visit_merchant` → `roll_stock` 仅从当前幕 offer 池抽取；池为空时 **回退** 全局池并 `push_warning` |
| E3 | 购买时实际扣款 = `round(offer.soul_cost * merchant_cost_percent / 100)`，UI 按钮文案显示折后价 |
| E4 | `MapGenerator` 加权抽 3 项；固定 seed 下 **事件+赐福+商人** 合计占比高于改前（见 §3.3 默认权重） |
| E5 | `data/events/` 共 **12** 个 `.tres`；每幕 `event_ids` ≥ 4 |
| E6 | `tools/act_economy_test.gd` 通过；`map_generator_test`、`event_service_test`、`merchant_service_test`、`smoke_test` 仍通过 |
| E7 | 实现后 **git commit** |

### 1.4 非目标（YAGNI）

- Monte Carlo / 自动平衡模拟器  
- 新敌人种类、新 `GameScreen`、事件插图/配音  
- 事件链（多屏）、咖列专属叙事事件（与商人节点合并）  
- 改全局 offer 的 `effect` 类型；仅调 **货池归属** 与 **价格倍率**  
- UI/音效抛光（留给阶段十三候选）  
- `Main.gd` 场景拆分  

---

## 2. 按幕商人

### 2.1 `ActData` 字段

```gdscript
@export var merchant_offer_ids: Array[String] = []
@export var merchant_cost_percent: int = 100
```

| 幕 | id | `merchant_cost_percent` | 说明 |
|----|-----|-------------------------|------|
| 1 | limgrave | 100 | 基准价 |
| 2 | stormveil | 105 | 城塞物价略涨 |
| 3 | liurnia | 95 | 湖畔咖列略降价，消化幕 3 卢恩 |

`merchant_offer_ids` 为空时视为「未配置」，实现时 **回退** `MerchantService` 全库（兼容旧档/测试）。

### 2.2 建议货池（`build_acts.py`）

| 幕 | offer id | 设计意图 |
|----|----------|----------|
| limgrave | `curio_card`, `blood_vial`, `refill_flasks`, `remove_card` | 得牌、回血、灌瓶、删牌入门 |
| stormveil | 幕 1 四项 + `kindling_sale`, `ash_replace` | 添火、战灰替换 |
| liurnia | 幕 2 六项 + `memory_stone`, `scrap_paper` | 记忆石、随机护符（`grant_relic`） |

不在早期幕投放 `memory_stone` / `scrap_paper`，避免护符过早堆叠。

### 2.3 `MerchantService` API

```gdscript
func roll_stock(
    run: RunState,
    registry: DataRegistry,
    rng: RandomNumberGenerator,
    count: int = 3,
    offer_ids: Array = []
) -> Array

func effective_cost(offer: MerchantOfferData, cost_percent: int) -> int

func purchase(..., cost_percent: int = 100) -> Dictionary
```

- `roll_stock`：`offer_ids` 非空时只从对应 id 构建 pool，再 `is_eligible` + shuffle + slice。  
- `can_afford` / `purchase` / `Main` 按钮文案统一走 `effective_cost`。  
- 购买成功日志中的卢恩数字使用 **实际扣款**。

`Main._visit_merchant` 传入 `registry.get_act(run_state.act_index())` 的字段。

---

## 3. 地图加权抽样

### 3.1 `ActData` 权重字段

相对权重（整数 ≥ 0；**0 = 该 kind 不参与随机池**）：

```gdscript
@export var map_weight_combat: int = 4
@export var map_weight_elite: int = 2
@export var map_weight_event: int = 3
@export var map_weight_grace: int = 1
@export var map_weight_merchant: int = 1
```

| 幕 | combat | elite | event | grace | merchant |
|----|--------|-------|-------|-------|----------|
| limgrave | 4 | 2 | 2 | 1 | 1 |
| stormveil | 3 | 2 | 3 | 1 | 1 |
| liurnia | 3 | 3 | 4 | 1 | 1 |

相对阶段十「事件与战斗同权」，幕 3 的 `event/combat` 比从 `2/4` 升至 `4/3`，体感上 **? 节点明显增多**。

### 3.2 `MapGenerator` 算法

替换 `pool.shuffle(); return pool.slice(0, 3)`：

1. 构建 `Array[{ "option": Dictionary, "weight": int }]`：  
   - `fixed_nodes` → 按 `node.kind` 映射 `grace` / `merchant`（未知 kind 权重 1）  
   - `combat_encounters` → `map_weight_combat`  
   - `elite_encounters` → `map_weight_elite`  
   - `event_ids` → `map_weight_event`  
2. **无放回** 加权随机选 3 次（`rng.randi_range(0, total_weight-1)` 累加）。  
3. 若池条目数 < 3，返回全部（与现逻辑一致，Boss 层不变）。

抽取辅助函数建议放在 `MapGenerator` 内为 `_pick_weighted(options, count, rng)`，便于单测。

### 3.3 回归期望

`tools/map_generator_test.gd` 仍断言：非 Boss 层 **恰好 3** 项、Boss 层 **1** 项。  
新增 `act_economy_test`：对 limgrave 用 seed=42 抽 30 次，统计 `kind==event` 次数 ≥ 8（阈值可随实现微调，写入测试常量）。

---

## 4. 事件扩充（+6）

由 `tools/build_events.py` UTF-8 生成，**不新增 effect 类型**。

| id | 幕 | 标题 | 选项概要 |
|----|-----|------|----------|
| `limgrave_smithing_table` | 1 | 锻造台余温 | 得 `club` / 花 15 卢恩得 `rock_sling` / 离开 |
| `limgrave_misguided_sheep` | 1 | 迷路的绵羊 | 扣 10% 生命得 35 卢恩 / 敬拜 +4 max_hp / 离开 |
| `stormveil_rusty_lever` | 2 | 生锈拉杆 | 花 25 卢恩灌瓶 / 拉杆受伤 8% 得 `hoarfrost_stomp` / 离开 |
| `stormveil_deserter` | 2 | 逃兵遗言 | 得 20 卢恩 / 删牌（min 6）/ 离开 |
| `liurnia_crystal_crab` | 3 | 结晶蟹 | 得 `glintstone_stars` / 花 30 卢恩 +8 max_hp / 离开 |
| `liurnia_shabriri_grape` | 3 | 夏玻利提的葡萄 | 15% 治疗 vs 失去 20 卢恩得 40 卢恩 / 离开 |

`build_acts.py` 每幕 `event_ids` 追加以上 2 个（保留原有 2 个，共 4 个/幕）。

---

## 5. 测试

### 5.1 `tools/act_economy_test.gd`

1. 三幕 `merchant_offer_ids` 非空且 id 均在 registry。  
2. `effective_cost`：offer 50 × 95% = 48（或项目统一取整规则）。  
3. `roll_stock` 在 limgrave 只出现池内 id。  
4. 三幕 `map_weight_event` 符合 §3.1 表。  
5. 加权抽样 30 次 event 计数阈值。  
6. 12 个 event id 均可 `registry.get_event`。

### 5.2 回归

```bash
godot4.6 --headless --path . --script tools/act_economy_test.gd
godot4.6 --headless --path . --script tools/map_generator_test.gd
godot4.6 --headless --path . --script tools/merchant_service_test.gd
godot4.6 --headless --path . --script tools/event_service_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

### 5.3 手工

| 场景 | 预期 |
|------|------|
| 幕 1 咖列 | 无记忆石/护符货；删牌约 75 卢恩 |
| 幕 3 咖列 | 可出现记忆石、护符货；标价 ×0.95 |
| 幕 3 地图 | 若干层出现 `?` 事件而非三连战 |
| 新事件 | 选项禁用/卢恩不足与阶段十一致 |

---

## 6. 风险与决策

| 议题 | 决策 |
|------|------|
| 价格取整 | `effective_cost = maxi(1, int(round(float(cost) * percent / 100.0)))` |
| 空 offer 池 | 回退全局 + warning，避免商人节点空白 |
| 权重为 0 | 该 kind 不进池；勿让三权重全 0 |
| 事件卡 id | 仅用已存在 `data/cards/` id，避免 registry 失败 |
| 与阶段十一 | 不重复调敌人 HP/卢恩；仅消费「幕 3 卢恩更宽裕」 |

---

## 7. 文档与提交

- 更新 `CLAUDE.md` / `README.md` 已实现列表（按幕商人、地图权重、12 事件）  
- `CLAUDE.md` Recommended Next → UI 抛光 / Main 拆分 / 可选平衡工具  
- 提交：`feat(game): phase 12 per-act merchant pools, map weights, and events`
