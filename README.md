# 破碎法环：褪色者牌局

Godot 4.6 卡牌 Roguelike 原型。背景与素材名词以《艾尔登法环》本体真实存在的职业、地点、敌人、武器、战灰、魔法、祷告和道具为基础，玩法节奏参考《杀戮尖塔》。

## 打开方式

1. 启动 Godot 4.6。
2. 导入本目录的 `project.godot`。
3. 运行主场景 `res://scenes/Main.tscn`。

## 已实现

- 初始出身选择：流浪骑士、武士、观星者、预言家、战士、一贫如洗者。
- 不同出身拥有不同生命、圣杯瓶数量、开局装备和初始牌组。
- 每回合 3 点集中，抽 5 张牌，手牌可点击打出。
- 抽牌堆、弃牌堆、消耗牌堆循环。
- 敌方意图、护甲、生命条和战斗日志。
- 姿态崩解、腐败、出血、易伤、力量等状态。
- 赐福点、普通战、精英战、Boss 战和战后选牌。
- 赐福营火式三选一（休憩、添火、删牌、净化等，数据见 `data/grace_options/`）。
- 商人咖列节点：花卢恩购买货箱卡牌、删牌、回血等（`data/merchant_offers/`）。
- 护符（Relic）：8 种，跑团持久加成（战斗开始/获得时/胜利卢恩，`data/relics/`）。
- 按幕敌人 HP 缩放（幕 1/2/3：100% / 110% / 125%）；敌人卢恩与 HP 由 `tools/build_enemies.py` 维护。
- 战后奖励池仅非 starter 卡；新增 4 张通用卡（岩石球、火焰赐予力量、辉石流星、冰雾踏地）。
- 记忆石（最多 3 颗）：每场战斗每回合多抽 1 张牌。
- 三幕 12 层跑团（宁姆格福 → 史东薇尔 → 利耶尼亚），地图与敌池由 `data/acts/*.tres` 驱动。
- 地图事件节点：12 个非战斗抉择（卢恩/生命/得牌等），按幕加权更易出现，数据见 `data/events/`。
- 按幕商人货池与价格（幕 1 基础货 → 幕 3 含记忆石/护符，利耶尼亚价 ×0.95）。
- 核心逻辑在 `scripts/core/`（`DataRegistry`、`RunState`、`CombatController`、`MapGenerator` 等）；`Main.gd` 负责 UI。

## 当前素材方向

- 出身参考本体初始职业与装备。
- 卡牌使用长剑、熨斗形盾、戟、打刀、长弓、辉石魔砾、辉石弯弧、魔法辉剑、火焰啊、恢复、紧急恢复、刺客步法、狮子斩、猎犬步法、腐败吐息、黑焰、红露滴圣杯瓶、命定之死等真实存在内容。
- 敌人使用葛瑞克士兵、野狼、亚人、葛瑞克骑士、凯丹佣兵、挖石矿工、学院辉石法师、腐败眷属、法姆亚兹拉的兽人、亚人首领、守墓斗士、挖石山妖、熔炉骑士、接肢贵族、恶兆妖鬼玛尔基特等真实存在内容。
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
```

## 推荐下一步

- UI/音效抛光；`Main.gd` 场景拆分；更多敌人种类。
