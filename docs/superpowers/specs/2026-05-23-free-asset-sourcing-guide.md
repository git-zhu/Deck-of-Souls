# Godot 免费素材渠道调研 — 替换现有素材指南

> 日期：2026-05-23
> 目标：为《老头牌：褪色者的牌局》（Godot 4.6 卡牌 roguelike，艾尔登法环暗黑奇幻风）
> 找到可替换当前自产素材的免费渠道与具体资源，含授权、适用性与接入建议。

---

## 1. 核心结论（速览）

| 素材需求 | 首选渠道 | 具体资源 | 授权 |
|---------|---------|---------|------|
| 卡牌边框/牌面 | Godot Asset Library + itch.io | Mechanized Magic 2D Vector Cards、Simple Cards、Card Framework | CC0 / 免费 |
| 暗黑奇幻 UI 面板 | Godot Forum + ArtStation 免费区 | Relics of the Abyss（Godot 论坛展示） | 免费（自查） |
| UI 边框/按钮 | SummerEngine / Kenney | Fantasy UI Borders Pack、UI Pack Adventure | CC0 |
| 意图/状态图标 | Kenney | Board Game Icons、UI Pack | CC0 |
| 字体 | Google Fonts | Cinzel / IM Fell English / Metamorphous | OFL |
| 音效 | Godot Asset Library | Kenney UI Audio（Calinou 打包） | CC0 |
| 背景 | itch.io / SummerEngine | Dark Fantasy Arena/Background、Background Ruins | 每包自查 |

---

## 2. Godot 专属渠道（最贴合引擎，可编辑器内直接导入）

### 2.1 Godot Asset Library（引擎内置，推荐首选）
- **入口**：Godot 编辑器 → AssetLib 标签页；或网页 https://godotengine.org/asset-library/
- **实测**：API 可访问，Godot 4.6 版本共 3327 个资源。
- **直接相关资源**：

| 资源 | 类型 | 链接 | 说明 |
|------|------|------|------|
| Simple Cards | 卡牌 | https://godotengine.org/asset-library/asset/4019 | 极简卡牌模板（拖入即用） |
| Mechanized Magic: 2D Vector Cards | 卡牌套件 | https://store.godotengine.org/asset/dumivid/mechanized-magic-2d-vector-cards-pack/ | 2D 矢量卡牌全套（含边框/图标） |
| Kenney UI Audio | 音效 | https://www.godotengine.org/asset-library/asset/796 | CC0 UI 音效包（Calinou 打包） |
| Kenney Interface Sounds | 音效 | https://www.godotengine.org/asset-library/asset/793 | 界面音效 |
| Card Framework（社区） | 卡牌框架 | https://godotassetlibrary.com/asset/S40pFX/ | 卡牌拖拽/堆叠框架（参考用） |
| Card3D | 3D 卡牌 | https://godotengine.org/asset-library/asset/3031 | 3D 卡牌（可作牌背参考） |

### 2.2 Godot Forum / 社区资源
- **Relics of the Abyss**：暗黑奇幻 RPG UI 素材集 + 交互展示（Godot 论坛发布，更新中）
  - https://forum.godotengine.org/t/relics-of-the-abyss-dark-fantasy-rpg-ui-assets-interactive-showcase/142384
  - 含 Cathedral Frames Pack（哥特式边框）、Treasures of the Damned（122 暗黑图标）——**与法环风格高度契合**
  - 注意：ArtStation 上有付费版，论坛发布版需自行确认免费范围

### 2.3 Godot Asset Store（store.godotengine.org）
- 官方新商店，部分免费资源：搜索 `#vector`、`#userinterface`、`#card` 标签。

---

## 3. 综合免费素材站（非 Godot 专属，但通用）

### 3.1 Kenney.nl（CC0 公共领域，商业无忧，强烈推荐）
| 素材 | 链接 | 用途 |
|------|------|------|
| UI Pack | https://kenney.nl/assets/ui-pack | 通用 UI 面板/按钮/图标 |
| UI Pack Adventure | https://kenney.nl/assets/ui-pack-adventure | 奇幻风 UI（边框/按钮） |
| Board Game Icons | https://kenney.nl/assets/board-game-icons | 状态/行动图标（意图/护甲/增益） |
| UI Audio | https://kenney.nl/assets/ui-audio | UI 音效（点击/悬停/确认） |
| Pixel UI Pack | https://kenney.nl/assets/pixel-ui-pack | 像素风 UI（若走像素路线） |

### 3.2 OpenGameArt.org（CC0/CC-BY 混合，需逐项确认）
- **Dark ARPG UI**：https://opengameart.org/content/dark-arpg-ui —— 暗黑 ARPG 风格面板/按钮，最接近法环风
- 搜索建议：`dark fantasy UI`、`card frame`、`souls`、`gothic`
- 注意：OGA 有 CC-BY 需要署名，下载页会标注，务必核对每个文件

### 3.3 itch.io 免费区（每包单独授权）
- 卡牌/奇幻合集：https://itch.io/game-assets/free/tag-card-game/tag-fantasy
- 暗黑奇幻标签：https://itch.io/game-assets/free/tag-dark-fantasy
- 具体推荐：
  - **Ink Style RPG UI Kit（FREE）**：https://itch.io/games-like/4416004/ink-style-rpg-ui-kit
  - **Fantasy UI Pack – Hand-Drawn UI & Card Assets**：https://itch.io/games-like/4098195/fui

### 3.4 SummerEngine 素材站（免费包 + 单图）
- **Fantasy UI Borders Asset Pack（Free CC0）**：https://www.summerengine.com/asset-store/pack/fantasy-ui-borders
- **Dark Fantasy Win Panel / Decorations / Background**：该站 "dark fantasy" 分类下大量免费单图

---

## 4. 字体（法环风衬线/哥特体，OFL 免费商用）

| 字体 | 风格 | 链接 |
|------|------|------|
| Cinzel | 罗马衬线大写（标题） | https://fonts.google.com/specimen/Cinzel |
| Cinzel Decorative | 装饰性罗马 | https://fonts.google.com/specimen/Cinzel+Decorative |
| IM Fell English | 古旧衬线（正文/描述） | https://fonts.google.com/specimen/IM+Fell+English |
| Metamorphous | 奇幻/哥特衬线 | https://www.commercialusefont.com/font/metamorphous |

---

## 5. 音效（替换/补充自产合成音）

| 资源 | 授权 | 链接 |
|------|------|------|
| Kenney UI Audio（Godot 打包） | CC0 | https://www.godotengine.org/asset-library/asset/796 |
| Kenney UI Audio（GitHub 直链） | CC0 | https://github.com/Calinou/kenney-ui-audio |
| OGA `ui click` / `sword` / `fire` 搜索 | 每文件标注 | https://opengameart.org |

---

## 6. 背景/场景素材

| 资源 | 风格 | 链接 |
|------|------|------|
| Dark Fantasy Arena Background | 竞技场暗黑 | https://www.summerengine.com/asset-store/dark-fantasy-arena-background-3b661a26 |
| Dark Fantasy Background | 通用暗黑 | https://www.summerengine.com/asset-store/dark-fantasy-background-ef854d66 |
| Background Ruins | 废墟 | https://www.summerengine.com/es/asset-store/background-ruins-e91cd557 |

---

## 7. 接入建议（针对本项目）

### 7.1 替换优先级（按性价比）
1. **卡牌边框**：用 Godot AssetLib 的 Mechanized Magic Cards 或 Fantasy UI Borders 替换自产 card_frame（九宫格缩放更专业）
2. **意图/状态图标**：Kenney Board Game Icons（矢量、CC0、语义清晰）替换自绘几何图标
3. **UI 面板**：Relics of the Abyss 或 Ink Style RPG UI Kit 替换纯色 StyleBoxFlat 面板
4. **字体**：标题用 Cinzel，正文用 IM Fell English（OFL，可打包进游戏）
5. **音效**：Kenney UI Audio 替换自产合成音（更丰富）

### 7.2 接入方式
- **AssetLib 资源**：Godot 编辑器 → AssetLib → 搜索 → Download → 直接出现在 res:// 下
- **Kenney/itch.io**：下载 zip → 解压到 `assets/external/` → Godot 自动导入
- **字体**：下载 TTF/OTF → `assets/fonts/` → `theme.add_font(``)` 应用到 GameTheme
- 导入后需跑 `godot4.6 --headless --path . --import` 更新 .import 缓存

### 7.3 授权清单（接入前必查）
- Kenney：CC0，无需署名，可商用 ✅
- Godot AssetLib：每资源页标注（多数免费/CC0，个别 MIT/CC-BY）
- OpenGameArt：CC-BY 需署名（加入 credits 文件）
- itch.io：每个包页面标注（多数 free 可商用，个别仅免费非商用）

---

## 8. 验证与 QA

- 素材替换后运行 `ui_screen_test` / `smoke_test` / `combat_hud_test` 确认布局不越界。
- 新增字体需验证中文渲染（部分西文字体不含 CJK，需保留现有中文标签字体，仅对英文/数字/标题启用）。
- 每接入一批 commit + push。

---

## 9. 参考来源

- Godot Asset Library: https://godotengine.org/asset-library/
- Relics of the Abyss (Godot Forum): https://forum.godotengine.org/t/relics-of-the-abyss-dark-fantasy-rpg-ui-assets-interactive-showcase/142384
- Kenney: https://kenney.nl/assets
- OpenGameArt: https://opengameart.org
- Simple Cards: https://godotengine.org/asset-library/asset/4019
- Mechanized Magic Cards: https://store.godotengine.org/asset/dumivid/mechanized-magic-2d-vector-cards-pack/
- SummerEngine Fantasy UI Borders: https://www.summerengine.com/asset-store/pack/fantasy-ui-borders
