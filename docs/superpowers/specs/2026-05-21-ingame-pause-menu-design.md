# 局内暂停菜单与顶栏 UI 调整 — 设计规格

**日期：** 2026-05-21  
**状态：** 待实现  
**图标：** `☰`（汉堡菜单）  
**实现计划：** `docs/superpowers/plans/2026-05-21-ingame-pause-menu.md`  
**依赖：** `RunSaveService`（`docs/superpowers/specs/2026-05-21-title-menu-save-design.md`）

---

## 1. 目标与范围

### 1.1 目标

1. 局内顶栏增加 **`☰` 选项按钮**（右上角图标，不占长文案宽度）。  
2. 点击后弹出 **全屏半透明暂停层** + 居中竖排大按钮。  
3. 与现有 **「查看牌组」** 共存，并 **精简战斗顶栏重复统计**，保证 1280×720 不拥挤。  
4. 菜单仅含三项（无退出程序）：**继续游戏**、**返回标题**、**放弃本局**。

### 1.2 验收标准

| # | 标准 |
|---|------|
| P1 | MAP / COMBAT / REWARD / ORIGIN 顶栏可见 `☰` 与「查看牌组」 |
| P2 | 点 `☰` 出现遮罩 + 三按钮；点「继续游戏」关闭遮罩且可继续操作 |
| P3 | 「返回标题」前自动存档（与 `_maybe_autosave` 相同屏条件），再 `_show_title()` |
| P4 | 「放弃本局」二次确认 → `RunSaveService.delete_save()` → `_show_title()` |
| P5 | 战斗屏顶栏不再显示「抽牌/弃牌」条（战斗 HUD 底部已有） |
| P6 | TITLE / GAME_OVER / VICTORY 无 `☰` |
| P7 | `pause_menu_test.gd` 无头通过（按钮文案与 `☰` 顶栏存在） |

### 1.3 非目标

- 音量、分辨率、键位等 **设置页**  
- 局内 **退出程序**（保留标题屏「退出游戏」）  
- 多槽存档、云存档  
- 暂停时冻结战斗动画/计时（本阶段仅 UI 拦截输入）

---

## 2. 顶栏布局

### 2.1 结构

```text
[生命] [圣杯瓶] [卢恩] [护符?] [记忆石?] [牌组数] [幕·层]  ······  [查看牌组]  [☰]
```

- **操作区**（右端）：`HBox`，间距 8px  
  - 「查看牌组」：`118×34`，文字按钮  
  - `☰`：`40×34`，`tooltip_text = "选项"`  
- **战斗屏**：`RunHeaderView.build(..., is_combat_screen)` 为 `true` 时 **不** 追加「抽牌 / 弃牌」`small_stat`（与 `CombatHudView` 底部重复）。

### 2.2 显示范围

| `GameScreen` | 顶栏 + `☰` |
|--------------|------------|
| ORIGIN | 是 |
| MAP | 是 |
| COMBAT | 是 |
| REWARD | 是 |
| TITLE / GAME_OVER / VICTORY | 否 |

### 2.3 ORIGIN 特殊行为

- 仍可打开暂停菜单。  
- **返回标题**：不写盘（`screen == ORIGIN` 不在 autosave 集合），直接 `_show_title()`。  
- **放弃本局**：若尚未 `_start_run`（仍在选出身），等同返回标题且不删档；若已有进行中场（不应出现在 ORIGIN，防御性处理）则 `delete_save()`。

---

## 3. 暂停菜单 UI

### 3.1 `RunPauseMenuView.build(...)`

参数：

- `on_resume: Callable` — 继续游戏  
- `on_return_title: Callable` — 返回标题  
- `on_abandon_run: Callable` — 放弃本局（由 Main 再弹确认）

返回根 `Control`（全屏锚点）：

1. `ColorRect`：铺满，`Color(0,0,0,0.55)`，`mouse_filter = STOP`  
2. 居中 `PanelContainer` + `VBoxContainer`（`separation = 12`）  
3. 三个 `Button`（`custom_minimum_size.y = 48`）：  
   - 「继续游戏」  
   - 「返回标题」  
   - 「放弃本局」

样式沿用 `GameTheme` / 现有 `Button` 主题（与 `TitleScreenView` 底栏一致即可）。

### 3.2 Main 挂载

- `Main` 增加 `pause_overlay: Control`（或每次 `add_child` 后 `queue_free`）。  
- `_show_pause_menu()`：若已有 overlay 则 return；否则 `add_child(RunPauseMenuView.build(...))`，置于树末（最上层）。  
- `_hide_pause_menu()`：`queue_free` overlay。  
- 打开暂停时 **不** 改 `screen` 枚举（仍为 MAP/COMBAT/REWARD）。

### 3.3 放弃确认

`AcceptDialog`（与标题屏新游戏确认同款文案风格）：

- 标题：「放弃当前进度？」  
- 正文：「放弃后本局存档将删除，无法继续。」  
- 确认 → `RunSaveService.delete_save()` → `_hide_pause_menu()` → `_show_title()`

---

## 4. 逻辑与存档

| 菜单项 | 行为 |
|--------|------|
| 继续游戏 | `_hide_pause_menu()` |
| 返回标题 | `_maybe_autosave()` → `_hide_pause_menu()` → `_show_title()` |
| 放弃本局 | 确认 → `delete_save()` → `_hide_pause_menu()` → `_show_title()` |

与标题屏区分：

- 标题 **退出游戏** → `quit()` + 退出前 autosave  
- 局内 **返回标题** → 仅回标题，不退出进程  

---

## 5. 模块改动

| 文件 | 变更 |
|------|------|
| `scripts/ui/RunPauseMenuView.gd` | 新建 |
| `scripts/ui/RunHeaderView.gd` | `☰` + 操作区；战斗屏去掉抽弃牌 stat |
| `scripts/Main.gd` | `_show_pause_menu` / 回调；`RunHeaderView` 传入 `on_pause` |
| `tools/pause_menu_test.gd` | 新建 |
| `tools/flow_screen_test.gd` | 断言顶栏含 `☰` |
| `CLAUDE.md` | 暂停菜单与测试命令 |

---

## 6. 测试

### `pause_menu_test.gd`

- 实例化 `Main.tscn`，`_start_run` 后进 MAP。  
- `_build_header()` 后查找 `tooltip_text == "选项"` 或 `text == "☰"` 的按钮。  
- 调用 `_show_pause_menu()`，断言子树含「继续游戏」「返回标题」「放弃本局」。  
- `_hide_pause_menu()` 后 overlay 消失。

---

## 7. 决策记录

| 议题 | 决策 |
|------|------|
| 菜单条目 | A：继续 / 返回标题 / 放弃本局 |
| 选项入口 | D：右上图标 `☰` |
| 弹层形式 | A：全屏遮罩 + 居中大按钮 |
| 实现结构 | `RunPauseMenuView` + `Main` 挂载（方案 1） |
| 战斗顶栏 | 去掉重复抽弃牌统计 |

---

## 8. Git

- 实现提交：`feat(ui): in-game pause menu and header layout`
- 实现后 push `origin main`
