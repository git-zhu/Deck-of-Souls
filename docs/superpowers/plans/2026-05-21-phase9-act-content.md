# 阶段九：按幕内容扩充 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase9-act-content-design.md`  
**状态：** 已实现（2026-05-21）

---

## Tasks

### Task 1: `MapEncounterData` + `ActData` 字段

- [x] 新建 `data/MapEncounterData.gd`
- [x] `ActData`：`combat_encounters`, `elite_encounters`, `reward_cards`
- [x] 移除 `combat_enemies` / `elite_enemies`

**验证：** Godot 可加载 `data/acts/*.tres`

---

### Task 2: `tools/build_acts.py` 重写输出

- [x] `build_acts.py` 遭遇 + reward + 利耶尼亚商人 + 亚人

---

### Task 3: `MapGenerator` 去硬编码

- [x] `MapGenerator` 使用 `MapEncounterData`

**验证：** 更新 `tools/map_generator_test.gd`

---

### Task 4: 按幕 `roll_rewards`

- [x] `roll_rewards(act)` + Main 传 act

---

### Task 5: Header 抛光

- [x] Header 幕名 · 段/4 · 层 n/12

---

### Task 6: 测试与文档

- [x] `tools/act_content_test.gd` + `map_generator_test` 更新
- [x] **git commit:** `feat(game): phase 9 per-act encounters, reward pools, and header polish`

---

## 可选 stretch（不阻塞验收）

- [ ] 新增 2–3 张 `data/cards/*.tres`（利耶尼亚魔法 / 史东薇尔战灰主题）
- [ ] 新增 1 个普通敌人 `.tres`（如「湖岸幽灵」占位）并写入幕 3 encounters

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 宁姆格福战后奖励 | 多为剑/步战灰/基础魔法，少见 `destined_death` 除非在幕 3 |
| 利耶尼亚地图 | 可出现商人；Header 显示「湖之利耶尼亚」 |
| 精英/幕末 | 战后护符流程不受影响（阶段八） |
| 敌人名匹配 | 地图选项 `enemy` 与 `template_by_name` 中文名一致 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `data/MapEncounterData.gd` | 新建 |
| `data/ActData.gd` | 字段 |
| `data/acts/*.tres` | 再生 |
| `tools/build_acts.py` | 遭遇 + reward + merchant |
| `scripts/core/MapGenerator.gd` | 去字典 |
| `scripts/core/CombatController.gd` | `roll_rewards(act)` |
| `scripts/Main.gd` | header + 传 act |
| `tools/act_content_test.gd` | 新建 |
| `tools/map_generator_test.gd` | 更新 |
| `CLAUDE.md` | 文档 |
