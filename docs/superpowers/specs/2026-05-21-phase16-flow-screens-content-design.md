# 阶段十六：流程屏 UI 提取与内容扩展 — 设计规格

**日期：** 2026-05-21  
**状态：** 待实现  
**前置：** 阶段一至十五（`Main` ~723 行，战斗/奖励 UI 已模块化）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase16-flow-screens-content.md`

---

## 1. 目标与范围

### 1.1 问题

`Main.gd` 仍承担 **标题 / 出身 / 地图 / 牌组弹窗 / 结算** 的 UI 搭建（合计约 **260 行**），与路由、商人/赐福/事件业务缠在一起。内容侧已有 15 种敌人、12 个地图事件，但缺少 **多步事件链** 与若干幕间敌人变体。

### 1.2 目标

1. **流程屏 UI 模块**（`scripts/ui/`）  
   - `TitleScreenView` — 标题屏  
   - `OriginScreenView` — 出身网格 + `origin_card`  
   - `MapScreenView` — 幕标题 + 三选一地图卡  
   - `DeckPopupView` — 牌组 `AcceptDialog`  
   - `EndScreenView` — 死亡 / 胜利结算  

2. **`Main.gd` 瘦身**  
   - 上述屏改为 `_present_*` 薄封装；行数目标 **≤ 500**（净迁出 ≥220 行）。  
   - `_card_counts` 迁至 `DeckUtils.gd`（`scripts/ui/` 或 `scripts/core/`），供 `Main` / `DeckPopupView` / `RewardLayerViews` 复用（可选本阶段只迁 Main 调用）。

3. **内容：+3 敌人**  
   - 大树守卫、狮子混种、坠星兽（中文名与本体一致）  
   - 完整 `data/enemies/*.tres` + `MoveData`；`tools/build_enemies.py` 表补 HP/卢恩  
   - 写入 `build_acts.py` 遭遇池（幕 1 普通/精英、幕 2/3 各至少 1 处引用）

4. **内容：事件链**  
   - `MapEventChoiceData.follow_event_id: String`  
   - `EventService` / `Main._on_event_choice`：应用效果后若 `follow_event_id` 非空则 **不推进层数**，直接 `_show_event(next)`  
   - `build_events.py` 新增 **3 条链**（每链 2 屏：选择 → 后续事件 → 继续回地图）  
   - 各幕 `event_ids` 加入链入口 id（`build_acts.py`）

5. 不改战斗数值管线、不拆 `.tscn`、不改 `smoke_test` 视口断言。

### 1.3 验收标准

| # | 标准 |
|---|------|
| F1 | 存在 `TitleScreenView`、`OriginScreenView`、`MapScreenView`、`DeckPopupView`、`EndScreenView` |
| F2 | `Main` 无内联标题/出身/地图/牌组弹窗/结算 UI 搭建 |
| F3 | `Main.gd` ≤ **500** 行 |
| F4 | 3 个新敌人 `.tres` 可被 `DataRegistry` 加载；`balance_content_test` 或新 `content_pack_test` 断言敌人总数 **18** |
| F5 | 3 条事件链可玩通：选链入口选项 → 进入第二屏事件 → 点继续回地图且 **仅 advance 一次**（在链末） |
| F6 | `tools/flow_screen_test.gd`、`tools/event_chain_test.gd` 无头通过 |
| F7 | `smoke_test.gd` 仍通过 |
| F8 | **git commit** + **git push** |

### 1.4 非目标

- CC0 默认音效包（仍可选 `audio/*.ogg`）  
- Monte Carlo 平衡  
- 新卡牌 / 新护符 / 第四幕  
- `CombatHudView` 二次拆分  

---

## 2. UI 模块设计

### 2.1 通用约定

- 全部 `extends RefCounted`，`class_name` 导出，静态 `build(...) -> Control`（或 `AcceptDialog`）。  
- 颜色用 `GameTheme.TITLE_GOLD` / `BODY_MUTED` / `GOLD`，禁止新增魔法 hex（结算红/金可保留 `EndScreenView` 内常量）。  
- `Main` 保留 `_hide_layers`、`_build_header`、`screen` 切换；各 `_show_*` 只负责选层 + 挂子树。

### 2.2 `TitleScreenView.build(on_start: Callable) -> Control`

等价现 `_show_title`：大标题、副标题、「选择出身」按钮、`on_start` → `_show_origin`。

### 2.3 `OriginScreenView.build(registry, on_pick_origin: Callable) -> Control`

- 标题 + 说明 + `GridContainer` 3 列  
- `origin_card(origin, on_pick)` 从 `Main._origin_card` 迁出  

### 2.4 `MapScreenView.build(act, run_state, options, on_option: Callable) -> Control`

- 幕 `title` / `subtitle_template` 文案  
- 对 `options` 每项调用 `UiBuilders.map_choice_card(option, on_option.bind(option))`  

`Main._show_map` 形态：

```gdscript
func _show_map() -> void:
    screen = GameScreen.MAP
    _hide_layers()
    map_layer.visible = true
    _clear(map_layer)
    _build_header()
    var act := registry.get_act(run_state.act_index())
    var options := map_gen.options_for_floor(run_state, registry, rng)
    map_layer.add_child(MapScreenView.build(act, run_state, options, _choose_map_option))
```

### 2.5 `DeckPopupView.show(parent, deck, registry) -> void`

- 迁出 `_show_deck_view` 全部节点树  
- `parent: Node` 用于 `add_child(popup)`（`Main` 为 `self`）  
- 排序逻辑保留（按卡名）  

### 2.6 `EndScreenView.build_game_over(on_retry)` / `build_victory(souls, deck_size, on_retry)`

- 迁出 `_show_game_over` / `_show_victory` 的 `VBox` 布局  
- `Main` 仍在显示前调用 `GameAudio.play`  

### 2.7 `DeckUtils.card_counts(card_ids: Array) -> Dictionary`

- 从 `Main._card_counts` 迁出，供 `DeckPopupView` 与 `Main`（删牌 picker 计数）使用。

---

## 3. 事件链设计

### 3.1 数据

`data/MapEventChoiceData.gd` 增加：

```gdscript
@export var follow_event_id: String = ""
```

`tools/build_events.py` 的 `write_event` 输出 `follow_event_id = "..."`（默认空字符串）。

### 3.2 运行时

```text
玩家选选项
  → EventService.apply（扣卢恩、改 HP/牌组等）
  → 若 effect == PICK_CARD → 删牌 picker（不变）
  → 若 choice.follow_event_id 非空且 registry.get_event 有效
        → _show_event(next)   # 不 advance_floor
  → 否则 _show_event_result(title, summary)
        → 继续按钮 → advance_floor + _show_map
```

链末事件的选项 **不得** 再带 `follow_event_id`（或为空），走结果页 + 推进层数。

### 3.3 三条链（示例，实现时可微调文案）

| 链 | 入口 id | 第二屏 id | 幕 |
|----|---------|-----------|-----|
| A | `limgrave_corpse` | `limgrave_corpse_cache` | 1 — 搜刮 → 隐藏补给 |
| B | `stormveil_armory` | `stormveil_armory_inner` | 2 — 拿斧 → 机关室 |
| C | `liurnia_scholar_ghost` | `liurnia_scholar_reward` | 3 — 对话 → 遗物卢恩 |

入口选项在 `build_events.py` 中为对应 choice 设置 `follow_event_id`；第二屏为新建 event 资源。`build_acts.py` 将入口 id 保留在 `event_ids`（第二屏 **不** 进地图池，仅链内可达）。

### 3.4 测试 `event_chain_test.gd`

- 加载 `limgrave_corpse`，断言某 choice 的 `follow_event_id` 非空  
- 模拟 `apply` + 检查 `registry.get_event(follow)` 存在  

---

## 4. 敌人内容设计

### 4.1 新敌人（建议数值）

| 文件 id | 中文名 | max_hp | stance | souls | 分类 | 入池 |
|---------|--------|--------|--------|-------|------|------|
| `tree_sentinel` | 大树守卫 | 58 | 14 | 28 | 幕 1 精英 | limgrave elite |
| `misbegotten` | 狮子混种 | 50 | 12 | 24 | 幕 2 普通 | stormveil combat |
| `fallingstar_beast` | 坠星兽 | 78 | 16 | 50 | 幕 3 精英 | liurnia elite |

每敌 3 个 `MoveData`（攻击/护甲/增益或腐败），与现有 `.tres` 格式一致。

### 4.2 工具链

- `tools/build_enemies.py`：`ENEMY_STATS` 增加三名  
- 新建 `tools/build_new_enemies.py`（可选）或手写 3 个 `.tres`  
- `build_acts.py`：`combat` / `elite` 列表追加名称；`COMBAT_META` / `ELITE_META` 补地图文案  

### 4.3 测试

- `content_pack_test.gd`：`registry.all_enemy_templates().size() >= 18`（原 15 + 3）  
- `act_content_test`：新敌人名出现在至少一个 `ActData` 遭遇列表（grep 或 registry 遍历）

---

## 5. `Main.gd` 目标结构（示意）

保留：状态机、`_choose_map_option`、商人/赐福/事件/战斗/奖励路由、`log_*`、测试钩子（`_test_grace_pick` 等）。

迁出后单屏典型形态：

```gdscript
func _show_title() -> void:
    screen = GameScreen.TITLE
    _hide_layers()
    title_layer.visible = true
    _clear(title_layer)
    title_layer.add_child(TitleScreenView.build(_show_origin))
```

---

## 6. 测试命令

```bash
godot4.6 --headless --path . --script tools/flow_screen_test.gd
godot4.6 --headless --path . --script tools/event_chain_test.gd
godot4.6 --headless --path . --script tools/content_pack_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

---

## 7. 文件清单

| 文件 | 变更 |
|------|------|
| `scripts/ui/TitleScreenView.gd` | 新建 |
| `scripts/ui/OriginScreenView.gd` | 新建 |
| `scripts/ui/MapScreenView.gd` | 新建 |
| `scripts/ui/DeckPopupView.gd` | 新建 |
| `scripts/ui/EndScreenView.gd` | 新建 |
| `scripts/ui/DeckUtils.gd` | 新建 |
| `data/MapEventChoiceData.gd` | `follow_event_id` |
| `data/enemies/tree_sentinel.tres` 等 ×3 | 新建 |
| `tools/build_events.py` | 链 + 字段 |
| `tools/build_acts.py` | 敌人 + event_ids |
| `tools/build_enemies.py` | _stats |
| `scripts/core/EventService.gd` | 无需改 apply；链逻辑在 Main |
| `scripts/Main.gd` | 瘦身 + 链分支 |
| `tools/flow_screen_test.gd` 等 | 新建 |
| `CLAUDE.md`, `README.md` | 文档 |

---

## 8. 决策记录

| 议题 | 决策 |
|------|------|
| 链中间是否显示 apply 摘要 | **不显示**；直接进入下一事件屏（效果已生效） |
| 第二屏是否进地图池 | **否**，仅 `follow_event_id` 可达 |
| 敌人总数 | 15 → **18** |
| Main 行数 | **500** 硬目标；不足则再迁 `_show_game_over` 以外的小函数 |

---

## 9. 后续（阶段十七候选）

- `Main` 路由拆为 `RunFlowController`（RefCounted，持 Main 引用）  
- 第四幕 / 更多事件链 / 默认音效包  
- 牌组编辑 UI 与奖励选牌统一组件  

---

## 10. Git

- 提交：`feat(game): phase 16 flow screen views, event chains, and three enemies`  
- **提交后 push**
