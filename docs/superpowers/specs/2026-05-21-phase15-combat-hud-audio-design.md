# 阶段十五：战斗 HUD 提取与音效钩子 — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段一至十四（`RewardLayerViews`、`Main` ~880 行）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase15-combat-hud-audio.md`

---

## 1. 目标与范围

### 1.1 问题

`scripts/Main.gd` 在阶段十四后约 **880 行**，仍是「路由 + 非战斗屏 UI + 战斗 HUD」的混合体。战斗相关 UI 集中在 `_render_combat()`（约 **118 行**）与 `_build_header()`（约 **35 行**），且 `smoke_test.gd` 通过 `Main` 成员引用 `enemy_panel`、`hand_row` 做视口断言。

| 痛点 | 现状 |
|------|------|
| 战斗布局难维护 | 意图色、日志区、双方 `fighter_panel`、牌堆统计、手牌滚动全在 `Main` |
| 日志与 HUD 耦合 | `_log_text()` 在 `Main`，`RichTextLabel` 在 `_render_combat` 内创建 |
| 无音效反馈 | 全程静音；按钮/胜利无统一入口 |
| 标题/地图/出身屏仍内联 | 本阶段**不迁**（YAGNI），仅战斗 + 顶栏 |

### 1.2 目标

1. **`CombatHudView.gd`**：静态构建战斗层整棵 UI，返回 **节点引用结构** 供 `Main` 与冒烟测试使用。  
2. **`RunHeaderView.gd`**（小模块）：从 `Main._build_header()` 迁出顶栏统计与「查看牌组」按钮。  
3. **`GameAudio.gd`**：无资源时静默；有 `res://audio/*.ogg` 时播放 UI 点击、胜利、失败短音。在关键交互点调用（不强制导入素材）。  
4. `Main._render_combat()` 改为 **≤15 行** 委托；`Main.gd` 行数目标 **≤ 750**（净迁出 ≥130 行）。  
5. **不改** `CombatController` 数值、不新增 `.tscn`、不改变 `smoke_test` 视口阈值（敌人右缘、手牌高 ≤210）。

### 1.3 验收标准

| # | 标准 |
|---|------|
| C1 | 存在 `CombatHudView.gd`、`RunHeaderView.gd`、`GameAudio.gd` |
| C2 | `Main` 无 `_render_combat` 内联手牌/意图/日志搭建逻辑 |
| C3 | `smoke_test.gd` **无需改断言逻辑**（仍从 `Main` 读取 `enemy_panel`、`hand_row`） |
| C4 | `tools/combat_hud_test.gd` 无头构建 HUD，断言意图 Label、手牌行、日志区存在 |
| C5 | `GameAudio.play("ui_click")` 在文件缺失时不报错；提供 `res://audio/README.md` 说明可选素材 |
| C6 | 胜利屏/地图选项/打出牌至少 **3 处** 调用音效 API |
| C7 | `Main.gd` ≤ **750** 行；`tools/smoke_test.gd`、`ui_layout_test.gd`、`reward_ui_test.gd` 仍通过 |
| C8 | **git commit** + **git push** |

### 1.4 非目标（YAGNI）

- 迁出标题/出身/地图/牌组弹窗（阶段十六候选）  
- BGM、循环环境音、音量设置 UI  
- 战斗动画、卡牌拖拽、伤害飘字  
- 新敌人、事件链、`next_event_id`（阶段十六内容包）  
- Monte Carlo 平衡工具  

---

## 2. 模块设计

### 2.1 `CombatHudRefs`（内嵌于 `CombatHudView.gd` 或独立 `class_name`）

保存 `Main` / 测试需引用的节点：

```gdscript
class_name CombatHudRefs
extends RefCounted

var root: Control              # 挂到 combat_layer 的子树根
var player_panel: PanelContainer
var enemy_panel: PanelContainer
var log_box: RichTextLabel
var hand_row: HBoxContainer
var flask_button: Button
var end_turn_button: Button
```

`draw_label` / `discard_label` / `exhaust_label` **不必** 暴露给 `Main`（仅展示，无外部引用）。

### 2.2 `CombatHudView.build(...) -> CombatHudRefs`

**参数（建议）：**

| 参数 | 用途 |
|------|------|
| `run_state: RunState` | HP、手牌、牌堆数量 |
| `combat: CombatController` | 敌人、意图、集中、block |
| `registry: DataRegistry` | 手牌 `CardData` |
| `log_bbcode: String` | 由 `Main._log_text()` 传入 |
| `card_w`, `card_h: float` | 与 `Main.CARD_W/H` 一致 |
| `on_play_card: Callable` | `(index: int) -> void` |
| `on_flask`, `on_end_turn: Callable` | 按钮回调 |

**布局：** 与现 `_render_combat` 逐段等价迁移：

- `VBox` → `HBox` field（玩家 | 意图+日志 | 敌人）  
- 牌堆 `HBox` + 行动 `HBox` + 手牌 `ScrollContainer`  
- 意图 `GameTheme.intent_color(kind)`  
- 手牌 `UiBuilders.card_button` + `combat.can_play` 灰化  

### 2.3 `RunHeaderView.build(header, ctx) -> void`

**`RunHeaderContext`（Dictionary 或小型 RefCounted）：**

- `run_state`, `registry`, `screen: int`（`GameScreen` 值）  
- `on_deck_view: Callable`  

行为与现 `_build_header` 一致：生命/瓶/卢恩/护符/记忆石/牌组数；战斗中额外抽弃统计；幕标题与层数。

`Main` 保留：

```gdscript
func _build_header() -> void:
    RunHeaderView.build(header, _header_context())
```

### 2.4 `GameAudio.gd`

```gdscript
class_name GameAudio
extends RefCounted

const PATHS := {
    "ui_click": "res://audio/ui_click.ogg",
    "victory": "res://audio/victory.ogg",
    "defeat": "res://audio/defeat.ogg",
}

static func play(parent: Node, id: String) -> void:
    # ResourceLoader.exists → 临时 AudioStreamPlayer，play，finished→queue_free
```

- **不** 在 `project.godot` 注册 Autoload（避免全局状态）；由 `Main` 持有一个实例或全静态 `play(main, id)`。  
- 仓库可只提交 `audio/README.md`，无 `.ogg` 时 CI 仍绿。  
- 调用点（最少）：`_choose_map_option`、`_play_card`、` _show_victory`、`_show_game_over`（可选 `_on_merchant_buy` 成功）。

### 2.5 `Main.gd` 接线

```gdscript
var _combat_hud: CombatHudRefs  # 可选，或仍用成员 var enemy_panel 等

func _render_combat() -> void:
    _hide_layers()
    combat_layer.visible = true
    _clear(combat_layer)
    _build_header()
    var refs := CombatHudView.build(
        run_state, combat, registry, _log_text(),
        CARD_W, CARD_H,
        _play_card, combat.use_flask, combat.end_player_turn
    )
    combat_layer.add_child(refs.root)
    enemy_panel = refs.enemy_panel
    hand_row = refs.hand_row
    log_box = refs.log_box
    player_panel = refs.player_panel
    flask_button = refs.flask_button
    end_turn_button = refs.end_turn_button
```

`combat.use_flask` / `end_player_turn` 需 `bind` 或 lambda 包装为无参 `Callable`（与现 `pressed.connect` 一致）。

日志仍由 `Main` 维护 `log_lines` / `_log` / `_log_text`；`combat_changed` 时 `_render_combat` 重建 HUD 并传入最新 BBCode。

---

## 3. 测试

### 3.1 `tools/combat_hud_test.gd`

- 构造最小 `RunState` + `CombatController.start_combat`（或 mock 敌人 template）  
- `CombatHudView.build(...)`  
- 断言子树含「敌方意图」、`hand_row` 子节点数 ≥ 0、 `log_box` 非空  

### 3.2 回归

```bash
godot4.6 --headless --path . --script tools/combat_hud_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

### 3.3 手工（1280×720）

| 场景 | 预期 |
|------|------|
| 进战斗 | 敌人面板不超出右边界；手牌横向滚动 |
| 0 集中 | 手牌灰化 |
| 意图 | 攻击类偏红 |
| 放 optional ogg | 点地图/出牌有短音（若文件存在） |

---

## 4. 文件清单

| 文件 | 变更 |
|------|------|
| `scripts/ui/CombatHudView.gd` | 新建 |
| `scripts/ui/CombatHudRefs.gd` | 新建（或与 View 同文件） |
| `scripts/ui/RunHeaderView.gd` | 新建 |
| `scripts/ui/GameAudio.gd` | 新建 |
| `audio/README.md` | 新建（可选素材说明） |
| `scripts/Main.gd` | 委托 + 音效调用 |
| `tools/combat_hud_test.gd` | 新建 |
| `CLAUDE.md`, `README.md` | 文档 |

---

## 5. 决策记录

| 议题 | 决策 |
|------|------|
| 节点引用存 Main 还是 Refs | **保持 Main 成员变量**，冒烟测试零改动 |
| 日志所有权 | 仍归 `Main`；HUD 只接收字符串 |
| 音效资源 | 可选文件；缺失 = 无操作 |
| 顶栏是否本阶段迁 | **是**（小、与战斗同频 `_build_header`） |
| 行数目标 | **750**（战斗+顶栏迁出后合理值） |

---

## 6. 后续（阶段十六候选）

- `MapScreenView` / `TitleScreenView` / `OriginScreenView` → `Main` **<500 行**  
- `build_enemies.py` +3 敌人；`build_events.py` 事件链 `follow_event_id`  
- 可选 `res://audio/` 默认素材包（CC0）  

---

## 7. 文档与 Git

- 更新 `CLAUDE.md`（ui 模块表、`combat_hud_test`、Main 行数）  
- 更新 `README.md`  
- 提交：`feat(game): phase 15 combat HUD extraction and audio hooks`  
- **提交后 `git push`**
