# 阶段十三：UI 可读性抛光与主题模块提取 — 设计规格

**日期：** 2026-05-21  
**状态：** 已实现  
**前置：** 阶段一至十二（完整 12 层玩法管线）  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase13-ui-polish.md`

---

## 1. 目标与范围

### 1.1 问题

`scripts/Main.gd` 已约 **1500+ 行**，同时承担路由、主题、地图/战斗/奖励 UI 构建。阶段一至十二补全了玩法，但 **1280×720** 下的体验仍有明显缺口：

| 痛点 | 现状 |
|------|------|
| 地图选项难辨 | 三选一卡片仅标题/正文，**无节点类型标识**（战斗/精英/事件等） |
| 战斗信息层级弱 | 敌方意图一行黄字；手牌不可打出时仅 `disabled`，**视觉反馈不足** |
| 样式散落 | `_panel`、`_fighter_panel`、`_card_button`、颜色常量重复写在 `Main` |
| 文档漂移 | `CLAUDE.md` 仍写 Main ~785 行 |

### 1.2 目标

1. **提取 UI 模块**：`scripts/ui/GameTheme.gd`（调色板 + 主题应用）、`scripts/ui/UiBuilders.gd`（面板/战斗者/手牌/地图卡片构建）。  
2. **地图可读性**：路径选项显示 **类型徽章**（中文短标签 + 边框色调）。  
3. **战斗可读性**：意图按 `enemy_intent.kind` **着色**；不可打出牌 **变暗/降饱和**；日志保留最近 **N 条**（防刷屏撑布局）。  
4. **姿态提示**：敌人姿态 ≤25% 时面板边框高亮（崩解临近）。  
5. `Main.gd` 仅保留屏幕路由与业务回调，行数目标 **≤ 1200**（净迁出 ≥250 行）。  
6. 不改 `GameScreen` 枚举、不引入 `.tscn` 子场景、不改战斗数值。

### 1.3 验收标准

| # | 标准 |
|---|------|
| U1 | 存在 `GameTheme.gd`、`UiBuilders.gd`；`Main` 通过二者构建 UI（无重复 `_panel` 实现） |
| U2 | 地图选项含类型标签：战斗/精英/Boss/赐福/商人/事件，颜色可区分 |
| U3 | 战斗意图标签颜色随 `kind` 变化（攻击/护甲/增益/腐败等） |
| U4 | `cost > ember` 的手牌明显灰化；`combat_over` 时全军牌不可点 |
| U5 | 战斗日志最多显示 **12** 条（可配置常量）；旧条目丢弃 |
| U6 | `tools/smoke_test.gd` 仍通过（视口不溢出）；新增 `tools/ui_layout_test.gd` 断言地图徽章存在 |
| U7 | 实现后 **git commit** |

### 1.4 非目标（YAGNI）

- 音效 / BGM / `AudioStreamPlayer`  
- 将 `Main.tscn` 拆为多场景（`CombatScreen.tscn` 等）  
- 卡牌拖拽、动画补间、粒子  
- 完整 Design System 文档 / 外部字体资源  
- 重写 origin/merchant/event 布局（仅触达地图卡与战斗 HUD）  
- 新玩法、新数据 `.tres`  

---

## 2. 模块设计

### 2.1 `GameTheme.gd`

```gdscript
class_name GameTheme
extends RefCounted

const BG := Color("#16130f")
const PANEL := Color("#242018")
const GOLD := Color("#e0c06c")
# ...

static func apply_theme(root: Control) -> void
static func map_kind_meta(kind: String) -> Dictionary  # { "label": "战斗", "accent": Color }
static func intent_color(kind: String) -> Color
static func card_disabled_modulate() -> Color
```

**地图类型元数据：**

| kind | 标签 | accent（边框/徽章） |
|------|------|---------------------|
| combat | 战斗 | `#8b5a3c` |
| elite | 精英 | `#9b4dca` |
| boss | Boss | `#c0392b` |
| grace | 赐福 | `#3d8b5a` |
| merchant | 商人 | `#c9a227` |
| event | 事件 | `#4a7eb0` |

**意图颜色（`enemy_intent.kind`）：**

| kind | 颜色倾向 |
|------|----------|
| attack / attack_block / attack_rot | 偏红 `#e07a6a` |
| block | 偏金 `#e6c56d` |
| buff / strength | 偏紫 `#b08ce0` |
| debuff / rot | 偏绿 `#7ab87a` |
| 默认 | `#e6c56d` |

### 2.2 `UiBuilders.gd`

RefCounted 工具类，**静态方法**为主，避免与 `Main` 循环依赖：

```gdscript
static func panel(bg: Color, border: Color = GameTheme.BORDER) -> PanelContainer
static func fighter_panel(...) -> PanelContainer
static func map_choice_card(option: Dictionary, on_press: Callable) -> PanelContainer
static func card_button(card: CardData, index: int, combat: CombatController, on_play: Callable) -> Button
static func small_stat(text: String) -> Label
```

- `map_choice_card`：顶部 `kind` 徽章 + 标题 + 正文 + 按钮（「踏入」/「介入」逻辑保留在 `Main._choose_map_option`）。  
- `card_button`：根据 `combat.ember` 设置 `disabled` + `modulate`；样式用 `card.tone`。

`Main` 保留：`_show_*` 编排、`_clear`、层可见性、`registry`/`run_state`/`combat` 引用。

### 2.3 战斗日志截断

`Main._log` 或专用 `CombatLogBuffer`（可内联在 `Main`）：

- `const MAX_LOG_LINES := 12`  
- 新消息 append；超过则 `pop_front`  
- `_log_text()` 拼接为 BBCode 行（保持现有金色高亮规则）

### 2.4 姿态崩解提示

在 `UiBuilders.fighter_panel` 或 `_render_combat` 包装层：

```gdscript
if stance_max > 0 and float(stance_now) / float(stance_max) <= 0.25:
    # 面板 border_color 改为 GameTheme.GOLD 或加粗边框
```

仅视觉提示，不改变 `CombatController` 崩解逻辑。

---

## 3. `Main.gd` 迁移边界

| 保留在 Main | 迁至 UiBuilders / GameTheme |
|-------------|------------------------------|
| `_ready`、信号、`GameScreen` 切换 | `_panel`、`_fighter_panel`、`_card_button` |
| `_choose_map_option`、`_visit_*` | `_map_choice_card` 构建 |
| `_render_combat` 布局骨架 | 手牌按钮、战士面板样式 |
| `_build_header`、`_log` 业务 | `small_stat`、主题 `apply_theme` |
| 赐福/商人/事件/奖励屏 | （本阶段不迁，除非顺带改用 `UiBuilders.panel`） |

赐福/商人/事件屏 **允许** 将 `_panel(Color(...))` 替换为 `UiBuilders.panel(...)`，不强制重写整屏。

---

## 4. 测试

### 4.1 `tools/ui_layout_test.gd`

1. 加载 `Main.tscn`，`_start_run("vagabond")`。  
2. 读取 `map_gen.options_for_floor` 第一个选项，调用 `UiBuilders.map_choice_card`（或进入地图后查找子节点 Label 文本含「战斗」等）。  
3. Headless：实例化 `map_choice_card`，断言子树存在类型徽章 Label。  
4. `GameTheme.map_kind_meta("event").label == "事件"`。

### 4.2 回归

```bash
godot4.6 --headless --path . --script tools/ui_layout_test.gd
godot4.6 --headless --path . --script tools/smoke_test.gd
```

### 4.3 手工（1280×720）

| 场景 | 预期 |
|------|------|
| 地图三选一 | 每张卡左上角/顶部可见类型徽章 |
| 战斗 | 意图行颜色随敌招变化；0 集中时手牌灰化 |
| 精英/ Boss 意图 | 攻击类偏红，易辨认 |
| 日志连打 | 不超过约 12 行，不挤掉手牌区 |

---

## 5. 风险与决策

| 议题 | 决策 |
|------|------|
| 静态 vs 节点脚本 | 首版 **RefCounted 静态构建**，不新增 `.tscn` |
| 迁出比例 | 本阶段只迁「高频 + 重复」构建器，奖励屏下次再拆 |
| 日志 BBCode | 截断行数，不解析 BBCode 结构 |
| smoke 视口 | 手牌高度阈值 210 保持不变；地图卡加徽章后 `custom_minimum_size` 仍 ≤330 |

---

## 6. 后续（阶段十四候选）

- `scripts/ui/RewardScreenView.gd` 等，将 `Main` 压至 **<800 行**  
- 可选音效钩子（按钮点击、胜利）  
- 更多敌人 / 事件链  

---

## 7. 文档与提交

- 更新 `CLAUDE.md`（Main 行数、ui 模块表、测试命令）  
- 更新 `README.md` 已实现列表  
- 提交：`feat(game): phase 13 UI polish and theme module extraction`
