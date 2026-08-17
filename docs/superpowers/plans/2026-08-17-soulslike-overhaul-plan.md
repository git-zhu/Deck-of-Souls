# 魂类化全面改造 — 实施计划

> 日期：2026-08-17
> 依据：`docs/superpowers/specs/2026-08-17-design-review-soulslike-direction.md`
> 原则：每阶段独立可玩、可测（headless）、可提交；不改既有测试语义，只增不改。

---

## 阶段 A：立魂（S1 + S2 + S3）

### A1. 敌人行为模式（S2）
- `MoveData`：+`weight: int = 1`、+`bleed: int = 0`（对玩家出血值）。
- `EnemyData`：+`phase2_hp_percent: int = 0`、+`phase2_moves: Array[MoveData]`、+`phase2_text: String`。
- `DataRegistry._enemy_to_dict`：透传 weight/bleed/phase2 字段。
- `CombatController._choose_one_intent`：按 weight 加权选取；`_charge` 蓄力支持（kind="charge"：本回合蓄力，下回合强制打出 `_charge_value` 攻击）。
- `CombatController.enemy_turn`：血量首次跌破 phase2 阈值 → 切换 moves 为 phase2_moves（一次性台词 + 姿态回满 25%）。
- `_execute_enemy_action`：新增 `bleed` 意图 → `run.player_bleed += value`。
- 数据更新：玛尔基特（二阶段连段）、大树守卫（蓄力重击+权重）、学院辉石法师（蓄力辉石弯弧）、凯丹佣兵/守墓斗士（出血意图）、野狼（多段权重）。
- 测试：`tools/enemy_pattern_test.gd`。

### A2. 姿态崩解决策点（S1）
- `deal_enemy_damage` 破防时：置 `e.break_open = true`（不再自动回满姿态，改为破绽状态）。
- 下次对该敌人造成伤害的卡触发 `break_choice`：「处决」（追加伤害 = 触发伤害 ×1.2 + 8，碎星义肢护符再 +50%）或「防反」（护甲 = 触发伤害 ×0.5 + 4，返还 1 集中）。
- 并发破防（AOE）：仅首个进入选择，其余自动结算为小额处决（+6）。
- 选择期间禁止出牌（`play_card` / `end_player_turn` / `use_flask` 检查 `break_choice != null`）。
- UI：`CombatHudView` 破绽图标 + 选择浮层（两按钮），`Main.gd` 接线信号。
- 新卡 2 张：「格挡反击」（敌人意图为攻击时：护甲 8 + 姿态削减 6）、「重击蓄力」（本回合获得 6 护甲，下回合你的姿态伤害 ×2）。
- 测试：`tools/stance_break_test.gd`。

### A3. NG+ 与誓约（S3）
- 新 `scripts/core/ProfileService.gd`：`user://profile.json`（victories / max_ng / vow_level / memory / challenges）。
- `RunState`：+`ng_plus: int`、+`vow_level: int`、+`challenge_flags: Array[String]`（存档透传）。
- 缩放：NG+ 每级敌人 HP +25%、伤害 +15%、卢恩 +30%；在 `start_combat` / `_enemy_attack` / `check_enemy_death` 生效。
- 誓约 1–3 级修饰器（累积）：①破损的瓶（初始瓶 −1）②无恩之地（赐福休憩治疗减半）③鲜血契约（敌人伤害再 +10%、卢恩再 +30%）。
- 胜利时（run_victory）：`ProfileService.record_victory` → 解锁下一级 NG/誓约；标题/出身屏增加周目与誓约选择。
- 测试：`tools/ngplus_test.gd`。

**阶段 A 验收：** 新增 3 个 headless 测试绿 + 全量回归绿；commit + push。

---

## 阶段 B：深化构筑（S4 + S5 + S6 + S7）

### B1. 流派化奖励（S4）
- `CombatController.roll_rewards`：按出身倾向（origin 主属性）+ 当前最高属性确定 affinity；2 张倾向卡 + 1 张异端卡（全池）。
- 卡类型 → 倾向映射：武器/战灰/传说/壶 → 力量；魔法 → 集中；祷告 → 信仰。

### B2. 规则型护符 ×6（S5）
| id | 效果 | 接入点 |
|---|---|---|
| blood_lord_joy 血君主之乐 | 出血 5 层触发 | `apply_enemy_bleed` / 玩家出血阈值 |
| glintstone_staff 辉石杖 | 法术卡打出后抽 1 | `play_card` |
| twohanded_sword_badge 双手剑徽章 | 姿态伤害 +50%，护甲获得 −2 | `calculate_stance_damage` / `gain_block` |
| erdtree_gift 黄金树的馈赠 | 卢恩 10% 翻倍 | `check_enemy_death` |
| starscourge_prosthesis 碎星将军的义肢 | 处决伤害 +50% | A2 处决分支 |
| marikas_brand 玛莉卡的烙印 | 能量上限 +1，每回合 +2 腐败 | `RelicService` + `apply_player_start_status` |

### B3. 卡牌升级 · 锻造刻印（S6）
- `RunState.upgraded_cards: Array[String]`（存档透传）；展示与结算时卡名 +「+」。
- `CardEffectResolver._apply_step`：升级卡数值 ×1.3（ceil），作用于伤害/护甲/治疗/出血/腐败/易伤（抽牌不加）。
- 赐福新选项 `forge_etch`（锻造刻印）：消耗 1×1级锻造石 + 30 卢恩 → 选一张牌升级（复用选牌流）。

### B4. 数值修正（S7 + 附录）
1. `flame_grant_me_strength` 文案 →「本场战斗」。
2. 集中属性：每 3 点集中 +1 能量上限（上限 +2），`start_combat` 生效。
3. 圣杯瓶：`max(18, max_hp × 25%)`。
4. 易伤 cap = 3（敌我双方）。
5. 锻造石保底：精英必掉 1 颗（概率定等级），幕 Boss 必掉高阶石。
6. 武器倍率文案修正（全局生效，文案如实描述）。

**阶段 B 验收：** `tools/relic_rule_test.gd`、`tools/card_upgrade_test.gd`、`tools/build_rewards_test.gd` 绿 + 全量回归；commit + push。

---

## 阶段 C：拓宽世界（S8–S12）

### C1. 地图碎片（S8）
- `MapGenerator` 生成当层选项时，同时用独立 rng 分支生成下一层选项快照存 `run.next_floor_preview`。
- 地图屏新增「购买地图碎片（50 卢恩）」按钮 → 展示下一层 3 选项预览（仅预览，不可进入）。

### C2. 死亡回响（S9）
- 失败时 `ProfileService.record_death`：`echo_souls = souls/2`、`echo_floor`、`echo_act`。
- 新局到达对应层：地图注入事件「上一局的痕迹」：夺回回响（+卢恩）或献给赐福（转为 `memory` 永久货币 = 回响/20）。
- memory 用途：出身屏解锁「起始护符选择」（memory ≥ 100 后可用，开局三选一护符）。

### C3. 事件强化（S10）
- `EventService` 新效果：`gamble_card`（50% 得稀有卡 / 50% 失去 10% 最大生命）、`curse_card`（获得指定强卡 + 瓶位 −1）、`gamble_souls`（押 50 卢恩翻倍或归零）。
- 新事件 5 个（宁姆格福赌徒、史东薇尔诅咒祭坛、利耶尼亚湖中宝箱、逃兵的赌局、癫火涂鸦）。

### C4. 普通战先手压制（S11）
- 普通战（非精英/Boss）：第 1 回合打出 ≥3 张攻击卡 → 回合结束时全体敌人姿态 −50%（一次性）。

### C5. 誓言挑战（S12）
- 出身屏可选挑战修饰：「无瓶挑战」（flasks=0）、「强敌挑战」（敌人 HP +50%）。
- 胜利后 profile 记录 `challenges`，结算屏展示"誓约达成"。

**阶段 C 验收：** `tools/map_fragment_test.gd`、`tools/death_echo_test.gd`、`tools/event_gamble_test.gd`、`tools/ambush_test.gd` 绿 + 全量回归；commit + push。

---

## 收尾

- 更新 `CLAUDE.md`（新测试清单、Recommended Next、机制说明）与 `README.md`。
- 全量 headless 回归 + Monte Carlo 复测（胜率目标区间 30–80%）。
- 最终 commit + push。

## 风险

| 风险 | 对策 |
|---|---|
| 姿态决策与存档交互（战斗中 pending 选择） | break_choice 不落存档（加载后视为已防反结算，安全侧） |
| NG+ 缩放出伤 | Monte Carlo 门禁；缩放只乘 HP/伤害两个变量 |
| 升级卡与 hook 卡语义 | hook 卡升级仅作用于其 hook 内显式数值（首版：hook 卡不可升级，选牌流过滤） |
| UI 改动回归 | 每阶段跑 ui_screen_test / combat_hud_test |
