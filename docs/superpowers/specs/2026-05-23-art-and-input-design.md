# 美术素材调研 + UI/动画/操作优化 — 设计规格

> 日期：2026-05-23
> 目标：让《老头牌：褪色者的牌局》整体美术风格贴近艾尔登法环（暗黑奇幻、暗金、石碑、雾、符文），
> 并为 PC 与手机端操作做人性化便捷优化。

---

## 1. 现状盘点

- 当前项目**无任何图片美术资源**：仅 `icon.svg`（Godot 默认图标）。
- UI 全部为程序化纯色（`ColorRect` / `StyleBoxFlat` / 文本），`GameTheme` 统一定义暗金配色。
- 结论：不是"替换"而是"从零引入"美术。为避免大体积素材与授权风险，
  **优先采用 SVG（Godot 原生导入）+ 程序化纹理**自产暗黑奇幻风格素材，可提交、可离线、无版权问题。

---

## 2. 免费素材调研清单（CC0 / CC-BY，供后续扩展替换）

### 2.1 综合游戏素材站

| 站点 | 授权 | 地址 | 说明 |
|------|------|------|------|
| OpenGameArt | CC0/CC-BY/CC-BY-SA 混合 | https://opengameart.org | 2D GUI、纹理、音效量大；搜索 `dark fantasy GUI`、`souls` |
| Kenney.nl | CC0（公共领域） | https://kenney.nl/assets | UI Pack、UI Pack Adventure、Fantasy 系列，可直接商用 |
| itch.io 免费区 | 每包单独授权 | https://itch.io/game-assets/free/tag-souls-like | `souls-like`、`gothic`、`dark-fantasy` 标签 |
| GDevelop 素材站 | 免费/Fantasy | https://gdevelop.io/pt-pt/asset-store/free/fantasy-ui-borders-fantasy-ui-borders | Fantasy UI Borders 边框包 |
| summerengine.com | 每包单独授权 | https://www.summerengine.com/asset-store | Dark Fantasy UI Panel / Win Panel / Arena Background 等 |

### 2.2 推荐具体素材（符合艾尔登法环风格）

| 素材 | 来源 | 类型 | 用途 |
|------|------|------|------|
| Dark ARPG UI | OpenGameArt（https://opengameart.org/content/dark-arpg-ui） | 面板/按钮 PNG | 替换程序面板，暗黑 ARPG 风 |
| UI Pack Adventure | Kenney（https://kenney.nl/assets/ui-pack-adventure） | 9-patch UI | 边框/按钮/面板，扁平奇幻风 |
| 1-Bit Pack | Kenney（https://kenney-assets.itch.io/1-bit-pack） | 图标/纹理 | 符文、装饰线条 |
| Isometric Dark Souls Gothic（monogon） | itch.io | 概念参考 | 风格基准参考 |
| Dark Fantasy Arena Background | summerengine | 背景图 | 战斗/地图背景 |

### 2.3 字体（艾尔登法环风格衬线/哥特体）

| 字体 | 授权 | 地址 |
|------|------|------|
| Cinzel（衬线大写，罗马风） | OFL | https://fonts.google.com/specimen/Cinzel |
| Cinzel Decorative | OFL | https://fonts.google.com/specimen/Cinzel+Decorative |
| IM Fell English | OFL | https://fonts.google.com/specimen/IM+Fell+English |
| UnifrakturMaguntia（哥特） | OFL | https://fonts.google.com/specimen/UnifrakturMaguntia |

> OFL（SIL Open Font License）允许免费商用与嵌入，适合游戏标题/按钮。

### 2.4 音效（替换/扩展自产合成音）

- 可继续自产合成（ffmpeg）或替换为 CC0 音效站：OpenGameArt 搜索 `ui click`、`sword`、`fire`。

---

## 3. 本阶段落地策略（自产 SVG + 程序化）

由于引入外部大体积 PNG/字体包会使仓库膨胀且需人工下载授权文件，
本阶段**直接生成**以下资源并提交仓库：

### 3.1 美术资源（`assets/`）

- `assets/bg_elden.svg`：全屏背景（暗色渐变 + 雾 + 金色符文微光），用于标题/地图/结算屏。
- `assets/bg_combat.svg`：战斗场景背景（石地 + 雾气 + 篝火微光）。
- `assets/panel_ornament.svg`：面板金色角饰/分隔线（九宫格或角部叠加）。
- `assets/divider_gold.svg`：标题与正文之间的金色符文分隔线。
- `assets/icon_elden.svg`：替换默认 `icon.svg`（法环风格金色圆环图标）。

### 3.2 UI 风格优化（贴近艾尔登法环）

1. **背景层**：`Main` 底部增加 `TextureRect`（拉伸至全屏）替换纯色 `ColorRect`。
2. **面板**：`UiBuilders.panel` 增加金色渐变描边 + 内阴影 + 圆角保持。
3. **标题屏**：大标题用金色 + 微光（自绘 `ShaderMaterial` 或逐帧 alpha 呼吸），下方符文分隔线。
4. **按钮**：hover 时金色描边 + 轻微放大；disabled 半透明灰。
5. **卡片**：按 `tone` 保留底色，增加渐变高光与描边发光。

### 3.3 动画效果

1. **屏幕转场**：`Main._show_*` 时对层做淡入 + 轻微上浮（`Tween`，120–180ms）。
2. **卡片打出**：手牌卡片打出时放大回弹 + 飞向场地动画（可选简单缩放脉冲）。
3. **伤害数字**：战斗日志旁增加飘字（`Label` + `Tween` 上浮淡出）——用现有 log 驱动。
4. **悬停反馈**：按钮/地图卡 hover 缩放 1.03 + 描边变金。
5. **意图提示**：敌人攻击意图时面板描边闪烁（红色脉冲）。

### 3.4 PC 操作优化

1. **快捷键**（`_unhandled_input` 在 `Main`）：
   - `1`–`9`：打出对应手牌；`F`：圣杯瓶；`Space`/`E`：结束回合。
   - `D`：查看牌组；`Esc`：暂停菜单。
   - 方向键/数字：地图选项选择 + 回车确认。
2. **滚轮**：手牌横向滚动支持鼠标滚轮（垂直滚动映射到水平）。
3. **悬停提示**：地图选项/卡片已有 `tooltip_text`，补充快捷键说明。

### 3.5 手机端操作优化

1. **触控目标**：所有按钮 `custom_minimum_size.y >= 48`（现有 48–52 达标），手牌卡 `>= 120px` 高度可点。
2. **手势**：手牌行支持左右滑动（`ScrollContainer` 原生 touch 拖动 + 惯性）。
3. **安全区**：`project.godot` 增加 `display/window/handheld/orientation` 与 `emulate_touch_from_mouse`；
   `Main` 根容器保留边距，适配刘海屏（`DisplayServer.get_display_safe_area`）。
4. **双击缩放**：项目设置禁用 `web/allow_zooming` 类选项（桌面导出默认无此问题）。
5. **输入动作**：`project.godot` 注册 `ui_*` 与自定义动作，统一 `Input.is_action_pressed`。

---

## 4. 验收

- `ui_screen_test`、`smoke_test`、`audio_path_test` 等全量 headless 测试通过。
- 每阶段 `git commit` + `git push`。
- 资源文件均为自产 SVG（可离线、无外部授权依赖）。
- 快捷键在 `run_flow_test` 或新增 `input_test` 中有覆盖（headless 可模拟 `InputEventKey`）。
