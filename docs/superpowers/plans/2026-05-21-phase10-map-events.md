# 阶段十：地图事件节点 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase10-map-events-design.md`  
**状态：** 已实现（2026-05-21）

---

## Tasks

### Task 1: Event resources

- [x] `MapEventChoiceData` / `MapEventData` / `build_events.py` / `DataRegistry`

---

### Task 2: `EventService`

- [x] `EventService` + `PICK_CARD`

**验证：** `tools/event_service_test.gd`

---

### Task 3: `ActData` + `build_acts.py`

- [x] `ActData.event_ids` + `build_acts.py`

---

### Task 4: `MapGenerator` + `Main`

- [x] `MapGenerator` + `Main` 事件 UI

---

### Task 5: 测试与文档

- [x] `event_service_test.gd` + `act_content_test` 更新
- [x] **git commit:** `feat(game): phase 10 map event nodes with EventService`

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 地图出现「?」式事件 | 标题+正文+2～3 按钮 |
| 选「搜刮」类 | 卢恩增加，进下一层 |
| 卢恩不足 | 需付费选项 disabled |
| 赐福/商人/战斗 | 行为不变 |
| 精英战后护符 | 阶段八流程不变 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `data/MapEventData.gd` | 新建 |
| `data/MapEventChoiceData.gd` | 新建 |
| `data/events/*.tres` | 新建 ×6 |
| `data/ActData.gd` | `event_ids` |
| `data/acts/*.tres` | 再生 |
| `tools/build_events.py` | 新建 |
| `tools/build_acts.py` | event_ids |
| `scripts/core/EventService.gd` | 新建 |
| `scripts/core/DataRegistry.gd` | load events |
| `scripts/core/MapGenerator.gd` | event 选项 |
| `scripts/Main.gd` | event UI |
| `tools/event_service_test.gd` | 新建 |
