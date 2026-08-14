# AOE 卡牌 + 群怪精英化 — 实施记录

> 日期：2026-05-23
> 目标：多敌人战斗扩展——AOE 卡牌（群体伤害/状态）+ 群怪精英战（护符奖励）。

## 1. AOE 卡牌系统

### CardEffectStep 新增 4 个 Kind
| Kind | 效果 |
|------|------|
| `DAMAGE_ALL` | 对全体存活敌人造成伤害（含力量加成） |
| `APPLY_ALL_VULN` | 全体敌人施加易伤 |
| `APPLY_ALL_ROT` | 全体敌人施加腐败 |
| `APPLY_ALL_BLEED` | 全体敌人施加出血（逐目标结算爆发） |

### 改为 AOE 的卡牌（法环风）
| 卡牌 | 原效果 | 新效果 |
|------|--------|--------|
| 腐败吐息 | 单体 6 腐败 | **全体 5 腐败** |
| 岩石球 | 单体 6 伤 | **全体 5 伤 + 1 姿态** |
| 辉石流星 | 单体 4 伤×2 | **全体 3 伤×2** |
| 冰雾踏地 | 单体 5 伤 | **全体 5 伤 + 3 姿态** |
| 火山壶 | 单体 6 伤+2 易伤 | **全体 5 伤 + 1 易伤** |

### 结算
`CardEffectResolver._apply_step` 对 `combat.enemies` 逐目标调用 `deal_enemy_damage(…, i)` / 状态施加，跳过已死敌人。

## 2. 群怪精英化

### 精英群模板
- `DataRegistry.resolve_group(group_id, as_elite=true)` → 模板带 `elite=true`。
- `CombatController.start_combat` 将模板级 `elite/boss/is_act_boss/is_run_boss` 标记传播到每个成员敌人。
- 全灭后 `check_combat_end` 读取成员 `elite` → `elite_reward`（护符奖励路径，与单精英一致）。

### 地图精英群遭遇（MapGenerator）
| 幕 | 精英群 |
|----|--------|
| 宁姆格福 | 亚人掠夺者、葛瑞克精锐小队 |
| 史东薇尔 | 城门哨卫、守墓斗士与矿工、腐败突袭 |
| 利耶尼亚 | 腐败突袭、葛瑞克精锐小队 |

地图选项显示为"精英 · 群组名"，权重 1 混入精英池。

## 3. 验证
- `aoe_elite_test`：AOE 对 3 野狼全体命中（18 伤害）、精英标记传播、全灭 → elite_reward。
- 全量 34 项 headless 测试通过。
