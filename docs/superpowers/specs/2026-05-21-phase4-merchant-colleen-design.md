# 阶段四：商人咖列 — 设计规格

**日期：** 2026-05-21  
**状态：** 阶段四已实现（2026-05-21）  
**前置：** 阶段三赐福升级（`2026-05-21-phase3-grace-upgrades-design.md`）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase4-merchant-colleen.md`

---

## 1. 目标与范围

### 1.1 目标

在地图中加入 **商人咖列** 节点：玩家花 **卢恩** 购买商品，可多次购买，**离开商店** 后进入下一层。商品数据化，逻辑集中在 `MerchantService`，UI 仍在 `Main.gd`。

与赐福形成互补：赐福 = 无卢恩的营火升级；咖列 = 卢恩消费与牌组调整。

### 1.2 验收标准

| # | 标准 |
|---|------|
| M1 | 地图上可出现 `kind: "merchant"` 节点；进入后显示咖列界面与当前卢恩 |
| M2 | 每次访问随机 **3 个** 可购商品（来自 `data/merchant_offers/*.tres`）；卢恩不足时按钮禁用 |
| M3 | 购买成功扣卢恩并生效；同一次访问内同一槽位不可重复购买（售罄灰显） |
| M4 | 「离开」→ `advance_floor()` → 地图；未购买也可离开 |
| M5 | `tools/merchant_service_test.gd` 通过；`tools/smoke_test.gd` 六出身仍通过 |
| M6 | 宁姆格福 `ActData` 至少含 1 个商人地图节点（`build_acts.py` 更新） |

### 1.3 非目标（YAGNI）

- 护符 / `RelicData` 完整系统（「褪色者护符」商品仅占位文案 + 小效果或跳过）
- 按幕不同商品表、补货、涨价
- 咖列专属剧情对话树
- Smith（升级卡牌数值）
- 记忆石、战灰替换
- 多场景 UI 拆分（L3）

---

## 2. 玩家体验

### 2.1 流程

```mermaid
sequenceDiagram
  participant Map
  participant Main
  participant Shop as MerchantService
  participant Run as RunState

  Map->>Main: 选 merchant 节点
  Main->>Shop: roll_stock(run, registry, rng, 3)
  Shop-->>Main: MerchantOfferData[]
  Main->>Main: _show_merchant(stock)
  loop 可选多次购买
    Main->>Shop: purchase(offer, run, registry, rng)
    Shop->>Run: souls -= cost; deck/hp/flasks
  end
  Main->>Main: 离开 → advance_floor → _show_map
```

### 2.2 首版商品池（6 项，每次随机 3 个）

| id | 显示名 | effect | soul_cost | 说明 |
|----|--------|--------|-----------|------|
| `curio_card` | 咖列的货箱 | `add_random_card` | 50 | 非 starter 稀有度随机 1 张入牌组 |
| `remove_card` | 整理行囊 | `remove_card` | 75 | 删 1 张牌；牌组 ≤5 不入池 |
| `blood_vial` | 血污圣杯瓶 | `heal_percent` 25 | 35 | 回复 25% 最大生命 |
| `refill_flasks` | 装满圣杯瓶 | `refill_flasks` | 30 | `flasks = max_flasks` |
| `kindling_sale` | 添火材料 | `max_flasks` +1 | 40 | 瓶上限 +1，cap 5；已满不入池 |
| `scrap_paper` | 褪色者护符（占位） | `gain_strength` 1 | 55 | 本场跑团 `player_strength += 1`（非永久遗物，阶段五再换 Relic） |

**资格过滤**（与 `GraceService` 类似）后再抽 3 个；卢恩不足时 UI 禁用购买按钮，仍显示价格。

### 2.3 地图投放

| 幕 | 商人节点（示例） |
|----|------------------|
| 宁姆格福 | `商人咖列` — 艾雷教堂旁篝火，野狼节点文案已提及 |
| 史东薇尔 | `城墙下的咖列` — 可选，阶段四一并加入 `build_acts.py` |
| 利耶尼亚 | 首版 **不强制**（避免池子过大）；可在实现计划中作为 Task 可选 |

`MapNodeData`：`kind = "merchant"`，`title` / `body` 仅叙事；库存由 `MerchantService` 生成。

---

## 3. 技术设计

### 3.1 新类型与目录

```
data/
  MerchantOfferData.gd
  merchant_offers/
    curio_card.tres
    ...
scripts/core/
  MerchantService.gd
tools/
  build_merchant_offers.py   # UTF-8 生成 .tres
```

**MerchantOfferData** 字段：

```gdscript
@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var effect: String = ""
@export var effect_value: int = 0
@export var soul_cost: int = 0
@export var min_deck_size: int = 6      # remove_card
@export var card_rarity_filter: String = ""  # add_random_card: 空=非 starter
```

### 3.2 MerchantService API

```gdscript
func load_from_registry(registry: DataRegistry) -> void
func is_eligible(offer: MerchantOfferData, run: RunState) -> bool
func roll_stock(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator, count: int = 3) -> Array
func can_afford(offer: MerchantOfferData, run: RunState) -> bool
func purchase(offer: MerchantOfferData, run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> Dictionary
# 返回 { "ok": bool, "message": String, "pick_card": bool }
```

**effect 表：**

| effect | 行为 |
|--------|------|
| `add_random_card` | 从 `registry` 非 starter 卡池 `rng` 抽 1 张 `deck.append` |
| `remove_card` | `pick_card: true`，Main 复用赐福删牌 UI |
| `heal_percent` | 同 GraceService |
| `refill_flasks` | `flasks = max_flasks` |
| `max_flasks` | cap 5，+effect_value |
| `gain_strength` | `run.player_strength += effect_value` |

购买前：`can_afford` → `run.souls >= soul_cost`；成功后 `run.souls -= soul_cost`。

### 3.3 DataRegistry

- `var merchant_offers: Dictionary = {}`
- `_load_merchant_offers()` 扫描 `data/merchant_offers/`
- `get_merchant_offer(id)`, `all_merchant_offer_ids()`
- `load_all()` 中调用

### 3.4 Main.gd

- 成员 `merchant_service: MerchantService`，`_ready` 加载
- `_choose_map_option`：`"merchant"` → `_visit_merchant()`
- `_visit_merchant()`：`roll_stock` → `_show_merchant(stock)`
- `_show_merchant`：标题「商人咖列」、卢恩显示、3 商品卡（价 + 购买）、「离开」
- 槽位状态：`var _merchant_slots_bought: Array[bool]` 或 stock 内记录
- 购买后刷新该槽为售罄；`pick_card` 时走 `_show_merchant_remove_card`（可复用 `_show_grace_remove_card` 逻辑，抽公共 `_show_remove_card_picker(on_done)`）
- `_test_merchant_buy(offer_id)`：headless 直购，供扩展测试（smoke 可不进商人）

### 3.5 MapGenerator / ActData

- `_node_to_dict` 已透传 `kind`；**无需改** MapGenerator 逻辑，只需 `ActData.fixed_nodes` 含 merchant 节点
- 更新 `tools/build_acts.py`：每幕 `merchant` 列表，生成 `MapNodeData` sub_resource

### 3.6 测试

| 脚本 | 断言 |
|------|------|
| `merchant_service_test.gd` | 50 卢恩买 `curio_card` 后 souls 减少、deck 增大；卢恩 0 时 `can_afford` false |
| `smoke_test.gd` | 不强制进商人（避免 flaky）；保持 `_test_grace_pick("rest")` |

---

## 4. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 卢恩通胀/枯竭 | 首版定价 30–75，与战后掉落（敌人 `souls` 10–90）对齐 |
| 与赐福删牌 UI 重复 | 抽 `_show_remove_card_picker(callback)` 共用 |
| 商人节点过少 | 宁姆格福 + 史东薇尔各 1 个 fixed merchant |

---

## 5. 后续（阶段五候选）

- `RelicData` + 永久护符，替换 `scrap_paper` 占位
- 商人库存受 `act_index` 权重影响
- 咖列特殊事件（消耗全部卢恩换稀有牌等）

---

## 6. 规格自检

- [x] 与阶段三 `GraceService` 模式一致，可并行阅读实现
- [x] 无护符 Resource 依赖
- [x] 可拆为单份 implementation plan
