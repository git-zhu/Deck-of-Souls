# Deck of Souls

Godot 4.6 卡牌 Roguelike。题材与素材名词取自《艾尔登法环》真实存在的出身、地点、敌人、武器、战灰与道具，玩法骨架参考《杀戮尖塔》，并在其上叠加魂系决策层：姿态崩解二选一、蓄力打断、死亡回响与誓约挑战。

- **引擎**：Godot 4.6（Forward+ 渲染器）
- **分辨率**：1280×720，canvas_items 拉伸
- **体量**：12 层 × 3 幕；35 张卡牌、18 种敌人、21 个地图事件、14 枚护符、6 种出身

## 打开方式

1. 启动 Godot 4.6。
2. 导入本目录的 `project.godot`。
3. 运行主场景 `res://scenes/Main.tscn`。

命令行冒烟：

```powershell
godot4.6 --headless --path . --script tools/smoke_test.gd
```

## 玩法概要

### 出身与资源

- 6 种出身：流浪骑士、武士、观星者、预言家、战士、一贫如洗者——不同生命、圣杯瓶、开局装备与初始牌组。
- **集中**（能量）：每回合 3 点；每 3 点集中属性 +1 上限（最多 +2）。卡牌消耗 0–3。
- **手牌**：每回合抽 5（记忆石与护符可加）；抽牌堆空时洗回弃牌堆。
- **圣杯瓶**：回复 max(18, 最大生命 × 25%)。

### 战斗

- **姿态**：敌人姿态条打空触发崩解决策点——**处决**（大伤害，碎星将军的义肢 ×1.5）或**防反**（护甲 +1 集中，且破绽延续一回合，可连环压制）。
- **敌人个性**：权重连击（野狼群扑）、蓄力重击（大树守卫/法师，可被姿态削减打断）、相位二（低血切换招式表）、出血意图。
- **状态**：腐败 / 出血（10 层爆发；血君主之乐降为 5）/ 易伤（上限 3）/ 力量。
- **先手压制**：普通战首回合打出 ≥3 张攻击牌 → 敌人姿态减半（节奏压缩）。
- **多敌战斗**：每敌独立意图胶囊与面板，拖拽/点击均可指定目标，StS 式瞄准线。

### 地图与节点

- `MapGenerator` 按幕权重生成 12 层分支地图：战斗 / 精英 / Boss（4/8/12 层）/ 赐福 / 商人 / 事件。
- **赐福**（11 项）：属性升级、记忆石、锻造刻印（卡牌升级）等。
- **商人咖列**（11 项货架）：卢恩购卡、删牌、回血；每幕独立货池与价格系数。
- **事件**（21 个）：多步链（`follow_event_id`）、赌博、诅咒、死亡回响；含地图碎片与伏击节点。

### 构筑深度

- **流派化奖励**：战后选牌按属性倾向保底（智力倾向 → 3 张中至少 1 张魔法卡）；三幕奖励池零重叠，各带幕专属卡（双头剑/风暴刃/血斩/彗星/碎片旋涡）。
- **护符**（14 枚）：跑团持久加成 + 规则改造——出血阈值 5、法术打出抽牌、姿态↑护甲↓、卢恩翻倍概率、处决加成、能量+腐败交换等。
- **战灰**：替换卡牌的战争灰烬池。
- **卡牌升级**：锻造刻印（锻造石 + 卢恩）使单卡数值 +30%，卡名带「＋」金标。
- **锻造石**：精英必掉、Boss 双掉；武器升级走艾尔登法环伤害曲线。

### 外循环（跨局档案）

`ProfileService` 维护 `user://profile.json`：

- **NG+**：通关解锁；敌人 HP +25%/级、伤害 +15%、卢恩 +30%，并混入二阶段招式池（免费新鲜感）。
- **誓约 Ⅰ–Ⅴ**（破瓶/无恩之地/鲜血契约/苦行者 −1 抽牌/死荫 −20% 生命）与**誓言挑战**（无瓶 / 强敌）。
- **死亡回响**：阵亡时本局总卢恩的一半凝为回响，可在死点夺回，或转化为记忆；记忆 ≥50 → 花 50 记忆选起始携带卡；记忆 ≥100 → 开局护符三选一。

## UI 与反馈

- **五区战斗 HUD**：顶栏（跑团信息）/ 战斗特效区 / 行动区（敌人阵列）/ 回合资源条 / 手牌区。
- **StS 式手牌**：扇形叠放（边缘牌渐旋 ±8° + 曲线下沉）、悬停抬升 1.25×、悬停检视大卡（190×250，效果文本 16px 可读）、拖拽出牌 + 数字键 1–9。
- **反馈层**：伤害/格挡/治疗飘字、血条过渡 + 受伤红闪、回合横幅；敌方意图图标化（攻击/防御/增益/腐蚀）。
- **底角牌堆徽标**：抽牌/弃牌/消耗堆可点击弹窗查看。
- **展示字体**：马善政毛笔楷书（SIL OFL，`assets/fonts/`）用于名字、横幅、CTA 与进度标题。
- 存档自动保存（`user://run_save.json`）、标题菜单、局内暂停、可选音效（`audio/*.ogg`）。

## 测试

47 个无头测试 + 贪心 bot 平衡门，全部 `godot4.6 --headless --path . --script tools/<name>` 运行：

```text
smoke_test / run_flow_test / save_load_test / save_roundtrip_test
title_menu_test / pause_menu_test / origin_screen_test / export_data_load_test
map_generator_test / event_service_test / event_chain_test / souls_features_test
combat_hud_test / multi_enemy_test / multi_enemy_ui_test / aoe_elite_test
enemy_pattern_test / stance_break_test / drag_test / targeting_line_test
hitbox_test / sts_features_test / hand_card_style_test / input_test
card_type_test / damage_formula_test / leveling_service_test / smithing_test
grace_service_test / merchant_service_test / relic_service_test / relic_reward_test
ash_service_test / memory_stone_test / ngplus_test / build_depth_test
act_content_test / act_economy_test / balance_content_test / content_pack_test
reward_ui_test / flow_screen_test / ui_layout_test / ui_screen_test / audio_path_test
round2_fixes_test / run_flow_host_test
monte_carlo_balance   # 贪心 bot 胜率门（非冒烟，耗时较长）
```

## 架构速览

| 模块 | 路径 | 职责 |
|---|---|---|
| Main | `scripts/Main.gd` | 屏幕路由、战斗/地图/事件流转、FX 消费 |
| RunFlowController / RunRewardFlow | `scripts/core/` | 地图选项与事件路由 / 商人、赐福、战后奖励流 |
| CombatController | `scripts/core/CombatController.gd` | 战斗结算、敌人回合、FX 事件队列 |
| CardEffectResolver | `scripts/core/CardEffectResolver.gd` | `CardEffectStep` 链 + 钩子 |
| DataRegistry / RunState | `scripts/core/` | 加载 `data/**/*.tres` / 跑团状态与牌堆 |
| ProfileService | `scripts/core/ProfileService.gd` | 跨局档案：NG+、誓约、记忆、死亡回响 |
| GameTheme / UiBuilders | `scripts/ui/` | 调色板与通用构件 / 面板、卡牌、战斗员 HUD 等 |
| CombatHudView / RunHeaderView | `scripts/ui/` | 战斗 HUD 五区布局 / 顶栏 |
| RewardLayerViews | `scripts/ui/RewardLayerViews.gd` | 商人、赐福、事件、战后奖励界面 |
| GameAudio | `scripts/ui/GameAudio.gd` | 可选 `audio/*.ogg` 挂点 |

数据以 `.tres` 存放于 `data/`（卡牌/敌人/出身/幕/事件/赐福/货架/护符）；批量生成脚本见 `tools/build_acts.py`、`build_enemies.py`、`build_events.py`、`build_relics.py`。

## 推荐下一步

- **出牌飞行 / 抽牌滑入动画**：需将战斗 HUD 从整体重构建改为增量更新，属较大架构调整。
- 可选：在 `audio/` 补充战斗音效；第四幕（16 层）暂缓。
- 平衡基调：贪心 bot 满资源单挑普通战接近 100% 属预期（难度预算集中在精英/Boss 与外循环修饰）；一贫如洗 vs 玛尔基特 ≈85%（防反连环后）。详见 `docs/superpowers/specs/2026-08-17-design-review-round2-post-implementation.md`。
