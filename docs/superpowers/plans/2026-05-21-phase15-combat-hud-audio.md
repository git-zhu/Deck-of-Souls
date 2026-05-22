# 阶段十五：战斗 HUD 提取与音效钩子 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase15-combat-hud-audio-design.md`  
**状态：** 待实现

---

## Tasks

### Task 1: `CombatHudRefs` + `CombatHudView` 骨架

- [ ] 新建 `scripts/ui/CombatHudRefs.gd`（`class_name CombatHudRefs`）
- [ ] 新建 `scripts/ui/CombatHudView.gd`（`class_name CombatHudView`）
- [ ] 从 `Main._render_combat` 逐段迁移布局（field / piles / actions / hand_scroll）
- [ ] `build(...)` 返回填充好的 `CombatHudRefs`

**验证：** `combat_hud_test` 能构建并找到意图 Label

---

### Task 2: `Main` 战斗接线

- [ ] `Main` 增加 `preload` `CombatHudView` / `CombatHudRefs`
- [ ] `_render_combat()` 改为委托（≤15 行有效逻辑）
- [ ] 成员 `enemy_panel`、`hand_row`、`log_box`、`player_panel`、`flask_button`、`end_turn_button` 从 `refs` 赋值
- [ ] 删除 `Main` 内原战斗 UI 搭建代码

**验证：** `smoke_test.gd` 不改断言仍通过

---

### Task 3: `RunHeaderView`

- [ ] 新建 `scripts/ui/RunHeaderView.gd`
- [ ] 迁移 `_build_header` 全部 Label/Button 逻辑
- [ ] `Main._build_header()` → 单行委托

**验证：** 地图/战斗顶栏文案与改前一致

---

### Task 4: `GameAudio`

- [ ] 新建 `scripts/ui/GameAudio.gd`（`play(parent, id)`，缺失资源静默）
- [ ] 新建 `audio/README.md` 列出可选 `ui_click.ogg` 等
- [ ] 接线：` _choose_map_option`、`_play_card`、`_show_victory`、`_show_game_over`

**验证：** 无 `audio/*.ogg` 时 headless 测试不报错

---

### Task 5: 测试与文档

- [ ] 新建 `tools/combat_hud_test.gd`
- [ ] `CLAUDE.md` / `README.md` 更新（模块表、测试命令、Main 行数）
- [ ] spec / plan 状态 → 已实现
- [ ] 确认 `Main.gd` ≤ **750** 行
- [ ] **git commit:** `feat(game): phase 15 combat HUD extraction and audio hooks`
- [ ] **git push**

---

## 手工检查清单

| 场景 | 预期 |
|------|------|
| 六出身 smoke | 敌人不裁切、手牌高度 ≤210 |
| 战斗 | 意图着色、灰牌、圣杯瓶/结束回合可用 |
| 日志 | 出牌后日志更新且最多 12 条 |
| 音效（可选） | 放入 ogg 后地图点击有反馈 |

---

## 预估改动文件

| 文件 | 变更 |
|------|------|
| `scripts/ui/CombatHudRefs.gd` | 新建 |
| `scripts/ui/CombatHudView.gd` | 新建 |
| `scripts/ui/RunHeaderView.gd` | 新建 |
| `scripts/ui/GameAudio.gd` | 新建 |
| `audio/README.md` | 新建 |
| `scripts/Main.gd` | 瘦身 + 音效 |
| `tools/combat_hud_test.gd` | 新建 |
| `CLAUDE.md`, `README.md` | 文档 |

---

## Git 工作流

每次阶段 commit 后执行 **`git push origin main`**（`.githooks/post-commit` 或代理手动）。
