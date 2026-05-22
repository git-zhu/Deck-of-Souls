# 阶段四：商人咖列 — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task.

**Goal:** 地图 `merchant` 节点 + 卢恩商店三商品；`MerchantService` + `MerchantOfferData`；离开后进下一层。

**Architecture:** 镜像阶段三 `GraceService`；`DataRegistry` 加载 `merchant_offers`；`Main` 商店 UI；`build_acts.py` 增加商人节点。

**Tech Stack:** Godot 4.6, GDScript, Resource

**Spec:** `docs/superpowers/specs/2026-05-21-phase4-merchant-colleen-design.md`

**Prerequisite:** 阶段三完成（`docs/superpowers/plans/2026-05-21-phase3-grace-upgrades.md`）

---

## File map

| File | Action |
|------|--------|
| `data/MerchantOfferData.gd` | Create |
| `data/merchant_offers/*.tres` | Create ×6 |
| `tools/build_merchant_offers.py` | Create |
| `scripts/core/MerchantService.gd` | Create |
| `scripts/core/DataRegistry.gd` | Load merchant offers |
| `scripts/Main.gd` | Merchant UI + map routing |
| `tools/build_acts.py` | Add merchant MapNodeData |
| `data/acts/*.tres` | Regenerate |
| `tools/merchant_service_test.gd` | Create |
| `README.md`, `CLAUDE.md` | Docs |

---

### Task 1: MerchantOfferData

**Files:** Create `data/MerchantOfferData.gd`

- [ ] **Step 1:** 按 spec §3.1 定义 Resource 字段

- [ ] **Step 2: Commit**

```bash
git add data/MerchantOfferData.gd
git commit -m "feat(data): MerchantOfferData resource"
```

---

### Task 2: 商品 .tres + 生成脚本

**Files:**
- Create `tools/build_merchant_offers.py`
- Create `data/merchant_offers/*.tres`（6 项，spec §2.2）

- [ ] **Step 1:** Python 脚本 UTF-8 写入（勿用 PowerShell 写中文）

- [ ] **Step 2:** `python tools/build_merchant_offers.py`

- [ ] **Step 3: Commit**

```bash
git add tools/build_merchant_offers.py data/merchant_offers/
git commit -m "feat(data): merchant offer catalog for Colleen"
```

---

### Task 3: MerchantService

**Files:** Create `scripts/core/MerchantService.gd`

- [ ] **Step 1:** `load_from_registry`, `is_eligible`, `can_afford`

- [ ] **Step 2:** `roll_stock(run, registry, rng, count=3)` — filter → shuffle → slice

- [ ] **Step 3:** `purchase(...)` — 实现 §3.2 effect 表；`remove_card` 返回 `{ok=true, pick_card=true}`

- [ ] **Step 4:** `pick_random_card(registry, rng)` — 非 starter 池

- [ ] **Step 5: Commit**

```bash
git add scripts/core/MerchantService.gd
git commit -m "feat(core): MerchantService roll and purchase"
```

---

### Task 4: DataRegistry

**Files:** Modify `scripts/core/DataRegistry.gd`

- [ ] **Step 1:** `merchant_offers` dict + `_load_merchant_offers()`

- [ ] **Step 2:** `get_merchant_offer`, `all_merchant_offer_ids`

- [ ] **Step 3:** `load_all()` 调用

- [ ] **Step 4: Commit**

```bash
git add scripts/core/DataRegistry.gd
git commit -m "feat(core): registry loads merchant offers"
```

---

### Task 5: 地图商人节点

**Files:** Modify `tools/build_acts.py`；重新生成 `data/acts/*.tres`

- [ ] **Step 1:** 每幕增加 `merchant` 元组列表，例如：

```python
"merchant": [
    ("商人咖列", "流浪商人坐在熄灭篝火旁，货箱上贴着褪色者也能看懂的价签。"),
],
```

宁姆格福、史东薇尔各 1 条；利耶尼亚可选 0 或 1。

- [ ] **Step 2:** `write_act` 生成 `kind = "merchant"` 的 `MapNodeData` sub_resource

- [ ] **Step 3:** `python tools/build_acts.py`

- [ ] **Step 4: Commit**

```bash
git add tools/build_acts.py data/acts/
git commit -m "feat(map): Colleen merchant nodes in acts"
```

---

### Task 6: Main 商店 UI

**Files:** Modify `scripts/Main.gd`

- [ ] **Step 1:** `merchant_service` + `_ready` 加载

- [ ] **Step 2:** `_choose_map_option` 增加 `"merchant": _visit_merchant()`

- [ ] **Step 3:** `_visit_merchant` / `_show_merchant` / `_on_merchant_buy`

- [ ] **Step 4:** 槽位售罄状态（`Array` 记录已购 index 或 offer id）

- [ ] **Step 5:** 抽 `_show_remove_card_picker(on_removed: Callable)` — 赐福与商人共用

- [ ] **Step 6:** 「离开」→ `advance_floor()` → `_show_map()`

- [ ] **Step 7:** （可选）`_test_merchant_buy(offer_id)` headless

- [ ] **Step 8: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat(ui): Colleen merchant shop flow"
```

---

### Task 7: 测试

**Files:**
- Create `tools/merchant_service_test.gd`

- [ ] **Step 1:** 加载 registry；`run.souls = 100`；购买 `curio_card`；断言 souls 减少、deck 变长

- [ ] **Step 2:** `can_afford` 在 souls=0 时为 false

- [ ] **Step 3:** 运行 `godot4.6 --headless --path . --script tools/merchant_service_test.gd`

- [ ] **Step 4:** 确认 `smoke_test.gd` 仍通过

- [ ] **Step 5: Commit**

```bash
git add tools/merchant_service_test.gd
git commit -m "test: headless MerchantService purchase checks"
```

---

### Task 8: 文档

**Files:** `README.md`, `CLAUDE.md`, spec 状态

- [ ] **Step 1:** README / CLAUDE 增加 MerchantService、merchant 测试命令

- [ ] **Step 2:** spec 状态 →「阶段四已实现」（实现完成后）

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md docs/superpowers/specs/2026-05-21-phase4-merchant-colleen-design.md
git commit -m "docs: phase 4 merchant Colleen spec shipped"
```

---

## Plan self-review

| Spec § | Task |
|--------|------|
| §2.2 六商品 | Task 2 |
| §3.2 MerchantService | Task 3 |
| §2.3 地图节点 | Task 5 |
| §3.4 UI | Task 6 |
| §3.6 测试 | Task 7 |

**估计：** 5–7 commits，单会话可完成。

---

## 验收清单（实现后）

- [ ] 地图可选商人咖列，进入见 3 商品与卢恩
- [ ] 购买扣卢恩；卢恩不足不可买
- [ ] 可买多项后离开，层数 +1
- [ ] `merchant_service_test` 通过
