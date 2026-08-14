# AI 素材生成与接入记录 — 2026-05-23

## 1. 目标
为《老头牌：褪色者的牌局》（艾尔登法环暗黑奇幻风）生成并接入一批 2D 美术素材（卡牌边框/意图图标/背景/图标），替换纯程序化 UI 的单调感。

## 2. 本地 AI 环境可行性（实测）
- **硬件**：CPU-only（PyTorch 2.12+cpu，12 核），无 GPU。
- **软件**：Python 3.13 + diffusers 0.39.0 + transformers 5.13.1 + Pillow/opencv/numpy（pip 镜像可装）。
- **网络**：huggingface.co / pypi.org / hf-mirror.com 均可访问（此前 urllib 失败是 PowerShell 引号转义问题，非网络问题）。
- **真实 AI 生图验证**：`segmind/tiny-sd`（精简 SD1.5，~500MB）在 CPU 上生成 384×256 图 **约 29 秒**（8 步），输出 `assets/ai_test_bg.png`。需 `torch_dtype=torch.float32` 避免 FP16/FP32 dtype 报错。

## 3. 素材清单（程序化生成，Pillow，tools/generate_assets.py）

| 文件 | 尺寸 | 用途 | 接入点 |
|------|------|------|--------|
| card_frame.png / card_frame_edge.png | 256×340 | 卡牌金色符文边框 | `UiBuilders.card_button` 叠加 TextureRect |
| bg_title_vignette.png | 1280×720 | 标题/地图暗角微光 | `Main` vignette 叠加层 |
| panel_ornament.png | 256×64 | 面板顶部金色饰条 | `UiBuilders.panel` 顶部装饰 |
| intent_attack/block/buff/debuff.png | 64×64 | 敌人意图图标 | `UiBuilders.intent_banner`（PNG 优先 + IntentIcon 自绘回退） |
| icon_flask.png | 48×48 | 圣杯瓶按钮图标 | `UiBuilders.flask_button` theme icon |
| icon_soul.png | 48×48 | 卢恩图标（备用） | 待接入 |

## 4. 接入实现
- `UiBuilders.flask_button`：`add_theme_icon_override("icon", load(...icon_flask.png))`。
- `UiBuilders.card_button`：`card_frame_edge.png` 以 `EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_COVERED + FULL_RECT` 叠加，跟随卡片尺寸（118×156）。
- `UiBuilders.panel`：顶部居中 `panel_ornament.png`（120×14，半透明）。
- `UiBuilders.intent_banner`：意图 PNG 图标叠加在 `IntentIcon` 自绘图标上（PNG 缺失时自绘兜底）。
- `Main._build_ui`：新增 `vignette_rect` 叠加层。

## 5. 验证
- `ui_screen_test`（9 屏 1280×720 边界）、`combat_hud_test`、`smoke_test` 等 12 项 UI 测试通过。
- 卡牌边框 TextureRect 初始使用 STRETCH_SCALE 导致超出卡片边界 → 改为 EXPAND_IGNORE_SIZE + KEEP_ASPECT_COVERED 修复。

## 6. 后续候选
- 用 `icon_soul.png` 替换顶栏卢恩纯文字。
- 用 AI 生成更高质量大图（本机 CPU 可行，或在线平台如 LiblibAI/即梦 AI）。
- 卡面稀有度背景纹理（common/uncommon/rare 各自纹理）。
