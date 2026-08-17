# 破碎法环：褪色者牌局

Godot 4.6 卡牌 Roguelike 原型。背景与素材名词以《艾尔登法环》本体真实存在的职业、地点、敌人、武器、战灰、魔法、祷告和道具为基础，玩法节奏参考《杀戮尖塔》。

## 打开方式

1. 启动 Godot 4.6。
2. 导入本目录的 `project.godot`。
3. 运行主场景 `res://scenes/Main.tscn`。

## 已实现

- 初始出身选择：流浪骑士、武士、观星者、预言家、战士、一贫如洗者。
- 不同出身拥有不同生命、圣杯瓶数量、开局装备和初始牌组。
- 每回合 3 点集中（每 3 点集中属性 +1 上限，最多 +2），抽 5 张牌，手牌可点击打出。
- 抽牌堆、弃牌堆、消耗牌堆循环。
- 敌方意图（含权重、蓄力、出血意图）、护甲、生命条和战斗日志。
- 姿态崩解决策点：破防后选「处决」（大伤害）或「防反」（护甲 +1 能量）；蓄力重击可被姿态削减打断。
- 敌人个性：野狼群扑（权重连击）、大树守卫/法师蓄力重击、玛尔基特 50% 血二阶段狂暴、出血积累。
- 腐败、出血（血君主之乐可 5 层触发）、易伤（上限 3）、力量等状态。
- 先手压制：普通战第 1 回合打出 ≥3 张攻击卡 → 敌人姿态减半（节奏压缩）。
- 赐福点、普通战、精英战、Boss 战和战后选牌（流派化：2 张倾向 + 1 张异端）。
- 赐福营火式三选一（休憩、添火、删牌、净化、锻造刻印卡牌升级等，数据见 `data/grace_options/`）。
- 卡牌升级：锻造刻印消耗 1 级锻造石 + 30 卢恩，单卡数值 +30%。
- 商人咖列节点：花卢恩购买货箱卡牌、删牌、回血等（`data/merchant_offers/`）。
- 护符（Relic）：14 种，跑团持久加成与规则改造（出血阈值/法术抽牌/姿态+50%/处决+50%/卢恩翻倍等，`data/relics/`）。
- 按幕敌人 HP 缩放（幕 1/2/3：100% / 110% / 125%）；敌人卢恩与 HP 由 `tools/build_enemies.py` 维护。
- 圣杯瓶回复随最大生命缩放（25%，至少 18）；锻造石掉落保底（精英必掉、Boss 必掉高级）。
- 战后奖励池仅非 starter 卡；新增 4 张通用卡 + 2 张姿态协同卡（格挡反击、重击蓄力）。
- 记忆石（最多 3 颗）：每场战斗每回合多抽 1 张牌。
- 三幕 12 层跑团（宁姆格福 → 史东薇尔 → 利耶尼亚），地图与敌池由 `data/acts/*.tres` 驱动。
- 地图碎片：花 50 卢恩预览下一层的路（法环式探图）。
- 死亡回响：死亡时一半卢恩凝为回响，下一局死点出现「上一局的痕迹」事件（夺回 / 凝成记忆）；记忆 ≥100 解锁开局护符三选一。
- 地图事件节点：21 个非战斗抉择（含事件链与风险赌博：押卢恩、诅咒交易、开箱赌卡），数据见 `data/events/`。
- 敌人 18 种（含大树守卫、狮子混种、坠星兽），由 `data/enemies/` 与 `tools/build_enemies.py` 维护。
- 按幕商人货池与价格（幕 1 基础货 → 幕 3 含记忆石/护符，利耶尼亚价 ×0.95）。
- NG+（通关解锁，敌人 HP +25%/级、伤害 +15%、卢恩 +30%）与誓约 Ⅰ–Ⅲ（破损的瓶/无恩之地/鲜血契约）；誓言挑战（无瓶/强敌）自选修饰。
- 地图节点显示类型徽章（战斗/精英/事件等）；战斗意图着色、不可打出牌灰化。
- UI：`GameTheme`、`UiBuilders`、`RewardLayerViews`、`CombatHudView`、`RunHeaderView`、流程屏 View 等；`RunFlowController`（地图/事件/战斗路由）+ `RunRewardFlow`（商人/赐福/战后奖励）；`ProfileService`（跨局档案 `user://profile.json`）；可选音效 `GameAudio`（`audio/*.ogg`）。
- 核心逻辑在 `scripts/core/`（`DataRegistry`、`RunState`、`CombatController`、`MapGenerator` 等）。

## 当前素材方向

- 出身参考本体初始职业与装备。
- 卡牌使用长剑、熨斗形盾、戟、打刀、长弓、辉石魔砾、辉石弯弧、魔法辉剑、火焰啊、恢复、紧急恢复、刺客步法、狮子斩、猎犬步法、腐败吐息、黑焰、红露滴圣杯瓶、命定之死等真实存在内容。
- 敌人使用葛瑞克士兵、野狼、亚人、葛瑞克骑士、凯丹佣兵、挖石矿工、学院辉石法师、腐败眷属、大树守卫、狮子混种、坠星兽、法姆亚兹拉的兽人、亚人首领、守墓斗士、挖石山妖、熔炉骑士、接肢贵族、恶兆妖鬼玛尔基特等真实存在内容。
- 地图事件按前期进度扩展到艾雷教堂、关卡前废墟、亚基尔湖北岸、宁姆格福坑道、驿站街遗迹、近林洞窟、海岸洞窟、风暴山丘封牢、通城隧道等节点。
- 战斗 UI 将手牌放入横向滚动区域，并收紧双方状态面板，避免 1280x720 下右侧敌人与底部卡牌被裁切。

## 无头测试

```bash
godot4.6 --headless --path . --script tools/smoke_test.gd
godot4.6 --headless --path . --script tools/map_generator_test.gd
godot4.6 --headless --path . --script tools/grace_service_test.gd
godot4.6 --headless --path . --script tools/merchant_service_test.gd
godot4.6 --headless --path . --script tools/relic_service_test.gd
godot4.6 --headless --path . --script tools/memory_stone_test.gd
godot4.6 --headless --path . --script tools/balance_content_test.gd
godot4.6 --headless --path . --script tools/act_economy_test.gd
godot4.6 --headless --path . --script tools/ui_layout_test.gd
godot4.6 --headless --path . --script tools/reward_ui_test.gd
godot4.6 --headless --path . --script tools/combat_hud_test.gd
godot4.6 --headless --path . --script tools/flow_screen_test.gd
godot4.6 --headless --path . --script tools/event_chain_test.gd
godot4.6 --headless --path . --script tools/content_pack_test.gd
godot4.6 --headless --path . --script tools/run_flow_test.gd
```

## 推荐下一步

- 普通战难度观察：Monte Carlo 贪心 bot（完美信息 + 满资源）对裸卡组普通战仍接近 100%——先手压制 + 敌人个性已按设计压缩普通战节奏，难度预算集中在精英/Boss（一贫如洗 vs 玛尔基特 74%）。若需进一步收紧，优先考虑敌人首回合防御姿态/格挡，而非堆 HP。
- 第四幕扩展暂缓；可选：在 `audio/` 补充战斗音效。
