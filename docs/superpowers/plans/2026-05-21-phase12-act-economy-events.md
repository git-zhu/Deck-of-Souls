# 阶段十二：按幕经济与事件深化 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase12-act-economy-events-design.md`  
**状态：** 已实现

---

## Tasks

### Task 1: `ActData` 扩展 + `build_acts.py`

- [x] `data/ActData.gd` 增加：
  - `merchant_offer_ids: Array[String]`
  - `merchant_cost_percent: int = 100`
  - `map_weight_combat / elite / event / grace / merchant: int`
- [x] `tools/build_acts.py` 为三幕写入 §2.2 货池、§3.1 权重、§4 `event_ids`（每幕 4 个）
- [x] `python tools/build_acts.py` 再生 `data/acts/*.tres`

**验证：** `act_economy_test` 读取 act 字段

---

### Task 2: `MerchantService` 按幕货池与价格

- [x] `effective_cost(offer, cost_percent) -> int`
- [x] `roll_stock(..., offer_ids: Array = [])` 过滤池
- [x] `can_afford` / `purchase` 使用折后价；日志与退款（失败回滚）用同一价格
- [x] `tools/merchant_service_test.gd` 增补：limgrave 池、95% 扣款

**验证：** merchant 单测 + 手工幕 3 标价

---

### Task 3: `Main` 商人接线

- [x] `_visit_merchant` 从当前 `ActData` 取 `merchant_offer_ids`、`merchant_cost_percent`
- [x] `_merchant_offer_card` 按钮文案显示折后 `soul_cost`
- [x] `_on_merchant_buy` / `_test_merchant_buy` 传入 `cost_percent`

**验证：** 冒烟进商人不报错

---

### Task 4: `MapGenerator` 加权抽样

- [x] `_weight_for_kind(act, kind: String) -> int`
- [x] `_pick_weighted(entries: Array, count: int, rng) -> Array`
- [x] `options_for_floor` 改用加权无放回（Boss 分支不变）

**验证：** `map_generator_test` 仍通过；`act_economy_test` 事件计数

---

### Task 5: 事件 +6

- [x] `tools/build_events.py` 追加 §4 六个事件定义
- [x] `python tools/build_events.py`
- [x] 确认 `event_service_test` 对新 choice effect 仍合法（必要时补 1～2 条用例）

**验证：** registry 加载 12 events

---

### Task 6: `act_economy_test` 与文档

- [x] 新建 `tools/act_economy_test.gd`
- [x] `CLAUDE.md` / `README.md` / spec 状态 → 已实现
- [ ] **git commit:** `feat(game): phase 12 per-act merchant pools, map weights, and events`

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 幕 1 商人 | 4 种基础货，无记忆石/护符 |
| 幕 3 商人 | 含 `memory_stone`、`scrap_paper`，价 ×0.95 |
| 幕 3 地图多局 | `?` 事件明显多于改前 |
| 新事件 | 卢恩/生命不足时选项灰掉 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `data/ActData.gd` | 商人 + 地图权重字段 |
| `data/acts/*.tres` | 再生 |
| `data/events/*.tres` | +6 |
| `scripts/core/MerchantService.gd` | 货池 + 折后价 |
| `scripts/core/MapGenerator.gd` | 加权抽样 |
| `scripts/Main.gd` | 商人参数传递 |
| `tools/build_acts.py` | 三幕数据 |
| `tools/build_events.py` | +6 事件 |
| `tools/act_economy_test.gd` | 新建 |
| `tools/merchant_service_test.gd` | 扩展 |
| `CLAUDE.md`, `README.md` | 文档 |

---

## 实现顺序建议

1. Task 1（数据字段 + build 脚本）  
2. Task 2 → 3（商人端到端）  
3. Task 4（地图权重）  
4. Task 5（事件内容）  
5. Task 6（测试 + 文档 + commit）

预计 **单会话** 可完成（与阶段十一体量相近）。
