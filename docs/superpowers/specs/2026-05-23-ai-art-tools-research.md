# AI 游戏美术素材生成工具调研报告

> 日期：2026-05-23
> 项目：《Deck of Souls》（Godot 4.6，艾尔登法环暗黑奇幻风，暗金/符文/石碑/雾）
> 目的：调研可用于生成**卡牌边框 / 符文背景 / 图标 / 纹理**的 AI 工具，评估本机（Windows、Python 3.13、
> CPU-only PyTorch 2.12、diffusers 0.39.0 / transformers 5.13.1、无法直连 huggingface.co 下载权重）可行性，
> 给出推荐路线。本调研仅产出一份文档，不修改任何代码/资源，不做 git 提交。
>
> 前置背景（见 `docs/superpowers/specs/2026-05-23-art-and-input-design.md`）：项目当前无图片资源，
> UI 全为程序化（`ColorRect`/SVG/`GameTheme` 暗金配色），已落地 `assets/bg_elden.svg` 等自产 SVG +
> 程序化纹理路线。本报告为其"AI 增强"补充调研。

---

## 1. 结论摘要（含本机可行性）

### 1.1 一句话结论

> **本机（无 GPU、CPU-only、huggingface 直连不可达）跑不了 SDXL/SD3/FLUX 全量推理，但有三条真正可行的路线：
> ① 程序化工具 + 传统图像处理做"伪 AI"效果（最稳、零成本、零授权风险，且项目已走这条路）；
> ② 镜像下载小模型（SD1.5 系）+ stable-diffusion.cpp / onnxruntime / OpenVINO 量化后在 CPU 上勉强出图（慢但离线可用）；
> ③ 在线免费平台与免费 API（即梦 / LiblibAI / Bing Image Creator / Pollinations / AI Horde）做主力出图，本机只做后处理。
> 推荐以 ③ 为主、① 为骨架、② 为离线兜底。**

### 1.2 本机可行性速查表

| 方案 | 可行性 | 说明 |
|---|---|---|
| pip 从国内镜像装依赖 | ✅ 可行 | 清华/阿里/豆瓣 PyPI 镜像；Python 3.13 + CPU-only PyTorch 2.12 已装，diffusers 0.39.0 可直接用 |
| 模型权重下载（不直连 HF） | ✅ 可行 | ① `HF_ENDPOINT=https://hf-mirror.com` 环境变量（diffusers/transformers 透明生效）；② ModelScope 魔搭国内直连；③ hf-mirror-cli / 手动下载后本地目录加载 |
| diffusers 本地 CPU 推理 | ⚠️ 可行但慢 | SD1.5 512×512 单张约 **3–10 分钟**（8 核 CPU 估算）；用 SD-Turbo / LCM-LoRA 把步数压到 1–8 步可进 1 分钟内 |
| onnxruntime / OpenVINO | ✅ 可行（推荐） | ONNX 模型 CPU 推理 + int8 量化，可比 PyTorch CPU 快 2–4 倍；OpenVINO 对 Intel CPU 最佳 |
| stable-diffusion.cpp + GGUF 量化 | ✅ 可行（推荐） | 纯 C/C++，Q4/Q5 量化后 4GB 内存可跑（社区实测），是 CPU 上最快的出图路线之一 |
| SDXL / SD3 / FLUX 本地全量 | ❌ 不推荐 | 内存与耗时不可接受（SDXL fp32 约 8–10GB RAM、单张 30 分钟+；FLUX 12B 更甚）；仅 8bit/4bit 量化小模型勉强 |
| TensorRT | ❌ 不适用 | 需 NVIDIA GPU，本机无 GPU |
| 在线免费平台（即梦 / LiblibAI / 通义万相 / Bing / Craiyon / Ideogram） | ✅ 可行 | 零本地算力；注意免费额度与商用条款 |
| 免费 API（Pollinations 免登录、AI Horde 匿名众包） | ✅ 可行 | 适合批量原型；AI Horde 有社区 Godot 插件（AI-Horde-Godot-Addon） |
| Google Colab / Kaggle | ⚠️ 需账号 | 免费 T4（Colab 限时断连、Kaggle 约 30h/周）；需 Google 账号且国内网络不稳 |
| Ollama 图像生成（0.11+ imagegen，支持 FLUX） | ⚠️ 视网络 | 模型从 ollama.com 官方仓库拉取（非 huggingface），网络可达即可本地跑；CPU 上依然偏慢 |
| 程序化 + 传统图像处理"伪 AI" | ✅ 可行（最稳） | Material Maker（基于 Godot）、Godot NoiseTexture/Gradient、SVG 手绘、Pillow/OpenCV 后处理（浮雕/发光/平铺） |

### 1.3 关键授权提示（先看这条）

- **SD 1.5 / SDXL / SD3 / SD-Turbo / SDXL-Turbo**：CreativeML **OpenRAIL-M** 许可证 —— 可免费商用，但有约束（不得用于违法/伤害性内容、不得误导他人为原创、保留声明）。
- **FLUX.1 schnell**：**Apache-2.0**（最宽松，商用友好）；FLUX.1 dev / FLUX.2 dev 为非商用。
- **Civitai / 各类 LoRA**：**每个模型独立许可证**，下载前必看 License 标签（有非商用/无再分发限制）。
- **在线平台**：Bing Image Creator / Designer 官方条款允许多数商用场景（微软不主张图片版权，社区有确认问答）；Craiyon、Ideogram、即梦、LiblibAI、通义万相等**免费额度生成图的商用需逐家查 ToS**，商用发布前确认。
- **程序化工具（Material Maker / TextureLab / Leshy / Sprite Fusion）生成的素材**：工具本身开源/免费，生成结果无第三方版权问题，是本项目最稳妥来源。

---

## 2. 工具清单

> 约定：**授权**列中 OpenRAIL = CreativeML OpenRAIL-M（可商用有约束）；AGPL/GPL/MIT/Apache = 开源许可证；
> "免费" 指有免费额度/免费版，商用请查条款。

### 2.1 本地开源：出图引擎与界面（Stable Diffusion 生态）

| 工具 | 类型 | 授权 | 适用素材 | 备注 |
|---|---|---|---|---|
| Stable Diffusion 1.5 | 底模 | OpenRAIL | 通用概念图/图标/纹理 | 512px、生态最大、LoRA 最多，CPU 唯一现实的全量推理候选 |
| SDXL | 底模 | OpenRAIL | 高质量 UI/插画/图标 | 1024px，质量明显更好；本机 CPU 全量不现实，适合在线平台或云 GPU |
| SD3 / SD3.5 | 底模 | OpenRAIL（3.5 有非商用变体） | 新架构出图 | diffusers 支持；量大，本地 CPU 不现实 |
| FLUX.1 schnell | 底模 | **Apache-2.0** | 快速高质量概念图 | 4 步蒸馏、商用最友好；12B 参数量大，本机仅量化版勉强 |
| SD-Turbo / SDXL-Turbo | 蒸馏加速底模 | OpenRAIL | 低步数快速出图 | 1–4 步出图，**CPU 上唯一"能等得起"的 diffusers 路线** |
| ComfyUI | 节点式工作流 | AGPL-3.0 | 批量管线、平铺纹理、ControlNet、抠图合成 | 游戏素材 AI 管线的行业标准；社区有游戏素材专项工作流（含 Unity/Godot 集成案例） |
| AUTOMATIC1111 WebUI | Web 界面 | AGPL-3.0 | 交互式出图/调参 | 生态最大、插件最多；低配需注意显存/内存 |
| Fooocus | 简化开箱即用 | GPL-3.0 | 低配/新手快速出图 | 对低配机最友好（8GB 内存机器实测只有它能无痛出图），有**纯 CPU 环境优化实践**文章 |
| InvokeAI | 专业节点+画布 | AGPL-3.0 | 统一风格/局部重绘工作流 | 面向专业美术管线，模型管理完善 |
| Forge（SD WebUI Forge） | A1111 低配优化分支 | AGPL-3.0 | 低显存/低内存机器 | 内存/显存优化显著，CPU 上比原版略优 |
| stable-diffusion.cpp | 纯 C/C++ 推理 | MIT | **CPU/低内存出图** | GGUF 量化（Q4/Q5），4GB RAM 可跑（社区实测），支持 SD1.5/SDXL/FLUX 系列；**本机首选离线出图引擎** |

### 2.2 编程库 / 部署（在代码里调用的方案）

| 工具 | 类型 | 授权 | 适用素材 | 备注 |
|---|---|---|---|---|
| diffusers | Python 库 | Apache-2.0 | 代码内 txt2img/img2img/批量 | **本机已装 0.39.0**；CPU 推理见 §3.2 |
| transformers | Python 库 | Apache-2.0 | 文本编码/提示词增强 | 本机已装 5.13.1，随 diffusers 使用 |
| onnxruntime | 推理引擎 | MIT | ONNX 模型 CPU 部署 | diffusers 有 ONNX 管线；配合 int8 量化 CPU 提速 |
| OpenVINO | 推理引擎 | Apache-2.0（Intel） | **Intel CPU 加速** | 转换后 CPU 推理可比 PyTorch 快数倍，Intel 平台首选 |
| TensorRT | 推理引擎 | NVIDIA | GPU 加速 | **需 NVIDIA GPU，本机不适用**；列此供将来升级参考 |
| huggingface_hub / hf-mirror | 模型下载 | Apache-2.0 | 权重获取 | `HF_ENDPOINT=https://hf-mirror.com` 后 diffusers 透明走镜像；另有 hf-mirror-cli |
| ModelScope（魔搭） | 模型托管/下载 | 平台条款 | 权重获取 | 阿里，国内直连快；大量 SD/SDXL 模型可直接 `modelscope` 拉取 |

### 2.3 在线免费 / 低价（零本地算力主力）

| 工具 | 类型 | 授权 | 适用素材 | 备注 |
|---|---|---|---|---|
| Leonardo.ai | 在线生成 | 免费每日积分 | 概念图/图标/纹理 | 积分制，SD 系模型丰富，出图质量稳定 |
| Playground（playground.com） | 在线生成 | 免费额度 | 通用出图 | 界面友好，每日免费额度 |
| Krea | 在线生成/实时 | 免费额度 | 概念探索/实时涂抹 | 实时生成与放大有特色 |
| Bing Image Creator / Microsoft Designer | 在线生成 | **免费** | 通用概念图 | 基于 DALL·E；微软不主张版权，多数商用场景允许（发布前查最新条款） |
| Craiyon | 在线生成 | 免费（广告） | 快速概念草图 | 免登录可用，分辨率低、质量一般 |
| Ideogram | 在线生成 | 免费额度 | **带文字素材**（卡名/标题图案） | 文字渲染业界最强，适合卡牌标题艺术字 |
| Pollinations.ai | 免费 API | 免费（限流） | **批量原型**（脚本一键出 100 张） | 无需登录、URL/API 直接出图，适合批量试 prompt |
| AI Horde（Stable Horde） | 免费众包 API | 免费（匿名） | 批量原型/社区协作 | 众包 GPU，匿名队列可能慢；有 Godot 插件 |
| LiblibAI（哩布哩布） | 国内模型库+在线生成 | 免费每日积分 | **国内最全 SD 模型/LoRA + 在线生成** | 中文生态最大；可直接在线用 SDXL/FLUX 与卡面 LoRA |
| 即梦AI（字节） | 在线生成 | 免费额度 | 中文提示出图/视频 | 中文友好、免费额度较足 |
| 通义万相（阿里） | 在线生成+API | 免费额度 | 通用出图 | 有开放 API，免费额度可接入脚本 |
| 文心一格（百度） | 在线生成 | 免费额度 | 通用出图 | 中文生态，额度一般 |
| 腾讯混元 / 代号 Craft | 在线生成平台 | 免费/内测 | 游戏世界素材（场景/概念） | 腾讯 AIGC 游戏素材平台，自然语言生成游戏素材 |

### 2.4 专用游戏素材（程序化为主，"伪 AI"与管线工具）

| 工具 | 类型 | 授权 | 适用素材 | 备注 |
|---|---|---|---|---|
| **Material Maker** | 程序化纹理编辑器 | MIT（开源，**基于 Godot 构建**） | 石头/金属/织物/藤蔓/符文纹理 | **与本项目引擎同源**；节点式生成可平铺 PBR 纹理，导出 PNG；本机首选纹理方案 |
| TextureLab | 程序化纹理编辑器 | 免费（itch.io） | 木/石/金属/UI 纹理 | 大量预设生成器，Windows 可用 |
| Leshy SpriteSheet Tool | 网页工具 | 免费 | 精灵图/图集打包、网格切图 | 卡牌图集整理利器 |
| Leshy MagicUI | 网页工具 | 免费 | 程序化 UI 面板/边框纹理 | 一键生成 UI 框/面板纹理，风格可调 |
| Sprite Fusion | 网页工具 | 免费 | tilemap 瓦片 + 像素画生成 | 适合像素风地图；本项目偏写实暗黑，作备选 |
| Retro Diffusion | 像素画 SD 模型 | 开源权重（模型特定许可） | 像素风角色/道具 | 若未来走像素风可用 |
| TileTile | 在线生成 | 免费（社区） | 像素瓦片批量生成 | Pollinations 社区项目，一键瓦片 |
| Meshy | 3D 资产生成 | 免费额度 | 3D 模型/贴图 | 若将来做 3D 或用 PBR 贴图烘焙 |
| 腾讯混元3D | 3D 重建/生成 | 每日 20 次免费 + API | 3D 模型 | 8 视图重建 |
| ComfyTextures | ComfyUI 工作流 | 开源 | 3D 模型 AI 贴图（Unity） | 3D 贴图管线参考 |

### 2.5 其他（云 GPU / API / 本地 LLM）

| 工具 | 类型 | 授权 | 适用素材 | 备注 |
|---|---|---|---|---|
| Google Colab | 云免费 GPU | 免费（需 Google 账号） | 云端跑 SDXL/FLUX 出图 | 免费 T4 限时断连；国内访问不稳，注册门槛是主要障碍 |
| Kaggle Notebooks | 云免费 GPU | 免费（需账号） | 云端出图 | 约 30h/周 GPU 配额，比 Colab 稳定 |
| Replicate API | 按量付费 API | 付费（约 $0.002–0.05/张，视模型） | 批量生产级出图 | 免运维、可接入脚本；有免费试用额度 |
| Ollama | 本地模型运行时 | MIT | 本地 LLM/视觉理解；0.11+ 支持 FLUX 图像生成（imagegen） | 模型从 ollama.com 拉取（非 HF）；CPU 出图偏慢，更擅长提示词/素材命名辅助 |

---

## 3. 本机可行方案详述

> 环境：Windows / Python 3.13 / CPU-only PyTorch 2.12 / diffusers 0.39.0 / transformers 5.13.1 /
> huggingface.co 无法直连下载权重。以下方案按推荐度排序。

### 3.1 网络与依赖：装包、下模型都走国内通道

1. **pip 用镜像**（清华为例）：
   ```powershell
   pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <包名>
   # 阿里: https://mirrors.aliyun.com/pypi/simple  豆瓣: https://pypi.douban.com/simple
   ```
2. **huggingface 模型走镜像**（diffusers/transformers 透明生效，无需改代码）：
   ```powershell
   $env:HF_ENDPOINT = "https://hf-mirror.com"
   # 可选加速: $env:HF_HUB_ENABLE_HF_TRANSFER = "1"
   ```
   之后 `StableDiffusionPipeline.from_pretrained("runwayml/stable-diffusion-v1-5")` 会自动从镜像下载并缓存。
3. **ModelScope 兜底**（部分模型镜像站没有时）：
   ```bash
   pip install modelscope
   modelscope download --model <模型ID> --local_dir ./models/xxx
   ```
   下载到本地目录后，diffusers 用 `from_pretrained("./models/xxx")` 加载，完全不碰 huggingface。
4. **手动下载 + 本地目录加载**：任何渠道拿到权重（含 LiblibAI 等国内站提供的模型文件）→ 按 diffusers 目录结构放好 → `local_files_only=True` 离线加载。**这是绕开直连问题最稳的兜底。**

### 3.2 diffusers 在 CPU 上出图（可行但慢，需"减步数"）

- 唯一现实选择：**SD1.5 系 + 低步数**。512×512，20 步约 3–10 分钟/张；**换成 SD-Turbo（1–4 步）或加 LCM-LoRA（4–8 步）可压到 1 分钟内**，质量略降但可用。
- 代码要点：
  ```python
  from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
  import torch
  pipe = StableDiffusionPipeline.from_pretrained("runwayml/stable-diffusion-v1-5", torch_dtype=torch.float32)
  pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
  pipe.enable_attention_slicing()          # CPU 显存换内存的关键
  img = pipe("dark fantasy golden ornate card frame, elden ring style, seamless, 512x512",
             num_inference_steps=4, guidance_scale=0.0).images[0]   # SD-Turbo 参数
  ```
- 不做：SDXL/SD3/FLUX 全量（内存 8GB+/单张 30 分钟+，不值得）；不用 fp16（CPU 上 fp32 反而简单稳定）。
- 批量建议：进程内串行 + 输出 PNG 到 `art_out/` 目录，由后处理脚本统一抠图/尺寸。

### 3.3 onnxruntime / OpenVINO（CPU 提速 2–4 倍，推荐离线路线）

- **OpenVINO**（Intel CPU 最佳）：把 SD1.5 转 OpenVINO IR（官方 `optimum-intel` 支持 diffusers 管线一键导出），CPU 推理通常比 PyTorch 快数倍，可 int8 量化进一步压缩内存与耗时。
- **onnxruntime**：`diffusers` 支持 `OnnxStableDiffusionPipeline`（需先导出 ONNX）；CPU Execution Provider 可用，配合 `quantize`（int8）适合小模型。
- 适用：需要**离线、可重复、无人值守批量**出图时（如一次性生成 100 张图标候选）。

### 3.4 stable-diffusion.cpp + GGUF 量化（CPU 最快出图路线之一）

- 纯 C/C++（MIT），GGUF 量化权重（Q4_K/Q5 等），**4GB RAM 即可跑 SD1.5（社区实测）**，比 PyTorch CPU 快且内存占用低。
- 用法：GitHub（`leejet/stable-diffusion.cpp`）下载 Windows 可执行文件 → 用脚本把 safetensors 转 GGUF 或直接下载现成 GGUF（HF 镜像站有）→ 命令行/内置 CLI 出图。
- 局限：生态节点不如 ComfyUI，但本项目只需 txt2img 出"素材候选"，足够。

### 3.5 在线免费 API 与平台（本机零负担，主力出图）

- **Pollinations.ai**：免登录、URL/API 直接出图，脚本批量试 prompt 最佳；注意限流与不稳定。
- **AI Horde**：匿名众包 API，支持 SD1.5/SDXL 等，排队慢但免费；社区有 Godot 插件（AI-Horde-Godot-Addon）。
- **即梦 / LiblibAI / 通义万相 / Bing**：人肉出图主力，LiblibAI 还能直接在线用 SDXL/FLUX 与卡面 LoRA，**是本项目"高清成品图"最省事的来源**。
- 配合：出图后本地用 Pillow 做统一后处理（抠白底、统一 512/1024、描边、调色到 `GameTheme` 暗金），即可进 `assets/`。

### 3.6 程序化 + 传统图像处理"伪 AI"（最稳、零成本、零风险）

- **Material Maker**（基于 Godot 构建）：节点式生成石头/金属/织物/藤蔓/符文纹理，导出可平铺 PNG —— **与"卡牌边框/背景纹理"需求完美匹配**，且与项目引擎同源、结果可提交可离线。
- **Godot 原生程序化**：`NoiseTexture2D`（FastNoiseLite：Simplex/FBM/域扭曲）+ `GradientTexture2D` + Shader 发光/浮雕 → 符文背景、雾、暗金渐变。项目已有 `assets/bg_elden.svg` 先例（SVG 手绘符文/雾），继续复用该手法。
- **Pillow / OpenCV 后处理**：给 AI 出图做"加工级"效果 —— 浮雕、内发光、暗角、羽化蒙版、无缝平铺（镜像/混合）、统一调色（对齐 `GameTheme` 暗金）。
- 适合：需要**确定性强、风格统一、无授权风险**的 UI 框架件（边框、底纹、分隔线），AI 只负责"灵感候选"与"复杂纹样"。

### 3.7 Colab / Kaggle / Replicate / Ollama（有条件）

- **Colab/Kaggle**：需要 Google 账号与网络，免费 T4 可跑 SDXL/FLUX 高清出图，但限时断连 —— 适合"一次性批量出高清候选"，不适合持续管线。
- **Replicate**：按量付费（一张约几美分），无需 GPU，适合把"出图"变成稳定 API 接入工具链；预算允许时最省事。
- **Ollama**：0.11+ 新增图像生成（imagegen，支持 FLUX 系），模型从 ollama.com 拉取；CPU 出图慢，**更推荐用它做提示词生成/素材命名/视觉质检（llama3.2-vision 类）**。

---

## 4. 推荐路线（按本项目四类素材）

> 统一原则：**AI 出"候选/复杂纹样"，程序化+后处理出"成品"**；所有进 `assets/` 的素材都要过一遍
> 统一尺寸、调色（暗金 `GameTheme`）、授权核查。

### 4.1 卡牌边框（Card Frame）

| 优先级 | 方案 | 步骤 |
|---|---|---|
| P0（骨架） | 程序化边框 | 在现有 `UiBuilders` / StyleBoxFlat 基础上做"金色渐变描边 + 角饰"，用 Material Maker 或 Godot Shader 生成暗金金属纹理做 NinePatch 边框；确定性强、可提交 |
| P1（AI 候选） | 在线 AI 出边框素材 | LiblibAI / 即梦 / 通义万相，prompt 模板：`dark fantasy ornate card frame, aged gold metal, black stone, glowing runes, symmetrical, Elden Ring style, game UI, isolated on black background, 1024x1024`；挑 3–5 张 → Pillow 抠背景/统一尺寸 → 与 P0 边框叠加 |
| P2（离线兜底） | 本地 CPU 出边框 | SD1.5 + 卡框类 LoRA（Civitai 搜 `card frame`，注意每模型 license），SD-Turbo/LCM 4–8 步，512×512；仅当需要离线批量时用 |

### 4.2 符文背景（Rune Background）

| 优先级 | 方案 | 步骤 |
|---|---|---|
| P0（骨架） | Godot 程序化背景 | `NoiseTexture2D`（FBM/域扭曲）+ 金色符文 SVG 叠加（复用 `assets/bg_elden.svg` 手法）；标题/地图/结算屏通用 |
| P1（AI 候选） | 在线生成符文纹样 | prompt：`dark fantasy glowing golden runes on black stone, ancient magic circle background, Elden Ring style, dark atmospheric, game background, 1024x1024`；再在本地做暗角+暗金调色 |
| P2（离线兜底） | 本地生成 + 无缝化 | SD1.5 出符文纹理 → Pillow 无缝平铺（镜像+混合）→ 叠加暗色渐变 |

### 4.3 图标（卡牌/遗物/战灰/状态图标）

| 优先级 | 方案 | 步骤 |
|---|---|---|
| P0（批量） | 免费 API 批量试稿 | Pollinations / AI Horde：统一 prompt 模板（`dark fantasy relic icon, {物品名}, gold rim, black background, Elden Ring style, centered, simple, high contrast`）批量出 50–100 张候选 |
| P1（精修） | 在线平台精修 | LiblibAI / 即梦逐张精修（或选 Civitai 图标 LoRA 在线用）→ 本地 Pillow 抠图、统一描边与暗金调色 |
| P2（离线兜底） | 本地 CPU 批量 | SD1.5 + 图标 LoRA，4–8 步，批量生成 → 后处理脚本统一尺寸/白底抠除 |

### 4.4 纹理（面板/石头/金属/织物/藤蔓等平铺纹理）

| 优先级 | 方案 | 步骤 |
|---|---|---|
| P0（首选） | 程序化纹理 | **Material Maker**（Godot 同源）生成石头/金属/织物/藤蔓等可平铺 PBR 纹理，导出 PNG；零授权风险 |
| P1（AI 增强） | 在线生成 tileable 纹理 | prompt 加 `seamless tileable texture, dark fantasy stone/metal/cloth`；本地用 Pillow 无缝化 + 调色 |
| P2（离线兜底） | 本地 SD 生成 + 平铺 | stable-diffusion.cpp 出纹理 → 镜像平铺后处理 |

### 4.5 通用建议

1. **prompt 基线**（英文，所有工具通用）：
   ```text
   dark fantasy, Elden Ring inspired, aged gold, black stone, glowing runes, fog,
   cinematic lighting, high detail, game asset, 512x512 / 1024x1024
   ```
2. **授权纪律**：底模只用 OpenRAIL-M 或 Apache-2.0（FLUX.1 schnell）；Civitai/LiblibAI 上的 LoRA 逐个查 license；在线平台商用发布前查该平台最新 ToS；程序化工具输出无顾虑。
3. **管线**：AI 出候选 → 本地 Pillow/OpenCV 统一后处理（尺寸/描边/调色到 `GameTheme` 暗金）→ 人工挑选 → 进 `assets/`。保持仓库轻量（PNG 压缩/WebP）。
4. **不投入**：本机跑 SDXL/SD3/FLUX 全量、TensorRT、长期依赖 Colab —— 收益/成本比太低。

---

## 5. 参考来源（主要检索链接）

- ComfyUI 游戏素材管线与节点化工作流：https://comfyui.org/en/ai-game-character-design-workflow 、https://www.scilit.com/publications/5cab57daba2b27a54b6a6e3d99aa8db0 、https://git-stars.org/blog/summaries/AlexanderDzhoganov/ComfyTextures
- 国内 ComfyUI/Stable Diffusion 素材管线：https://adg.csdn.net/6973105d437a6b40336b7b0c.html
- Fooocus 纯 CPU 环境优化实践：https://blog.gitcode.com/d5970e4b3a8fd5385ce663393060a79e.html ；低配机选择实测：https://post.smzdm.com/p/a6zme75n/
- Diffusers ONNX 优化（官方文档）：https://huggingface.co/docs/diffusers/v0.7.0/en/optimization/onnx
- huggingface 国内镜像 / HF_ENDPOINT：https://baike.baidu.com/item/Huggingface%20%E9%95%9C%E5%83%8F%E7%AB%99/67373341 、https://github.com/wangshuai67/hf-mirror-cli ；ModelScope 替代：https://blog.csdn.net/qq_73553710/article/details/153537772
- stable-diffusion.cpp（CPU/GGUF）：https://github.com/leejet/stable-diffusion.cpp 、https://github.com/luboslenco/stable-diffusion.cpp/blob/master/docs/quantization_and_gguf.md ；4GB 显存/内存讨论：https://github.com/leejet/stable-diffusion.cpp/discussions/595
- FLUX.1 schnell 许可（Apache-2.0）：https://huggingface.co/black-forest-labs/FLUX.1-schnell 、https://replicate.com/black-forest-labs/flux-schnell/readme
- SD/SDXL 商用讨论（Fooocus/OpenRAIL）：https://github.com/lllyasviel/Fooocus/discussions/3991
- Civitai 模型许可：https://civitai.com/articles/25923/buyinglicensing-models-and-loras 、https://github.com/orgs/civitai/discussions/267
- Bing Image Creator / Designer 商用：https://learn.microsoft.com/en-us/answers/questions/2348353/is-image-creator-from-microsoft-designer-now-avail 、https://learn.microsoft.com/en-us/answers/questions/2346822/commercial-use-of-images-generated-using-copilot-b
- Pollinations.ai：https://github.com/Igor-Vitin/pollinations-free-API ；AI Horde：https://explore.market.dev/ecosystems/godot/projects/ai-horde-godot-addon
- Material Maker（基于 Godot）：https://github.com/RodZill4/material-maker ；TextureLab 备选：https://alternativeto.net/software/texturelab/
- Leshy SpriteSheet Tool：https://www.leshylabs.com/apps/sstool/
- Sprite Fusion：https://www.spritefusion.com/
- 国内平台：LiblibAI 评测/收费：https://www.php.cn/faq/2751417.html ；即梦/通义/文心对比：https://flowpixai.com/ai-tools/domestic-ai-art-platform.html ；腾讯"代号 Craft"：https://www.ithome.com/0/956/225.htm ；腾讯混元3D（20 次/日免费+API）：https://www.aitop100.cn/infomation/details/33213.html
- Replicate 定价：https://llmtokencounter.online/replicate-api-pricing.html
- Ollama 图像生成（imagegen / FLUX）：https://github.com/ollama/ollama/issues/13880 、https://deepwiki.com/ollama/ollama/5.8-image-generation
- 免费云 GPU 对比：https://aimultiple.com/es/free-cloud-gpu
- Godot 程序化纹理（NoiseTexture）：https://docs.godotengine.org/zh-cn/3.5/classes/class_noisetexture.html 、https://godotengine.org/asset-library/asset/2749

---

*调研方式：多轮 web_search（中英文共 25+ 组关键词），结合本机环境（Windows / Python 3.13 / CPU-only / diffusers 0.39.0 / 无法直连 huggingface.co）做可行性推断；未在本机实测出图，文内耗时/内存为社区实测与估算值，落地前先小样验证。*
