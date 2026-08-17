class_name LevelingService
extends RefCounted
## 人物属性/武器升级服务（法环式分段升级曲线）。
## 属性升级：消耗卢恩，分段线性成本（模拟法环升级曲线并压缩到本项目卢恩量级）。
## 武器升级：消耗锻造石 + 卢恩。

const RunState = preload("res://scripts/core/RunState.gd")

# 属性元数据：显示名 / 效果描述（与 CombatController 实际公式一一对应，M6）
const ATTR_INFO := {
	"vigor": {"label": "生命", "desc": "每点 +2 最大生命"},
	"strength": {"label": "力量", "desc": "物理卡伤害 +1/点"},
	"dexterity": {"label": "灵巧", "desc": "物理卡伤害与姿态削减各 +0.5/点"},
	"mind": {"label": "集中", "desc": "魔法伤害 +1/点，每 3 点能量上限 +1（至多 +2）"},
	"faith": {"label": "信仰", "desc": "祷告伤害 +1/点（圣杯瓶治疗为固定值，不吃信仰）"},
}

const ATTR_ORDER: Array[String] = ["vigor", "strength", "dexterity", "mind", "faith"]


# 法环式分段升级成本（压缩曲线）：cost(level) 为从当前级升到下一级所需卢恩
static func attr_upgrade_cost(current_level: int) -> int:
	if current_level < 5:
		return 20 + current_level * 10      # 20,30,40,50,60
	if current_level < 10:
		return 60 + (current_level - 5) * 20  # 80,100,120,140,160
	return 160 + (current_level - 10) * 40   # 200,240,...


static func attr_can_afford(run: RunState, key: String) -> bool:
	var level: int = run.attr_upgrade_level(key)
	return run.souls >= attr_upgrade_cost(level)


static func apply_attr_upgrade(run: RunState, key: String) -> Dictionary:
	if not ATTR_INFO.has(key):
		return {"ok": false, "message": "未知属性。"}
	var level: int = run.attr_upgrade_level(key)
	var cost: int = attr_upgrade_cost(level)
	if run.souls < cost:
		return {"ok": false, "message": "卢恩不足（需要 %d）。" % cost}
	if run.upgrade_attr(key, cost):
		var info: Dictionary = ATTR_INFO[key]
		return {"ok": true, "message": "%s +1 → %d（%s）" % [info.label, run.attr(key), info.desc]}
	return {"ok": false, "message": "升级失败。"}


# 锻造石升级消耗表：0→1 ... 9→10
const WEAPON_LEVEL_COSTS := [
	{"stone": [2, 0, 0], "souls": 30},
	{"stone": [2, 0, 0], "souls": 40},
	{"stone": [3, 0, 0], "souls": 50},
	{"stone": [3, 1, 0], "souls": 60},
	{"stone": [4, 1, 0], "souls": 70},
	{"stone": [0, 2, 0], "souls": 90},
	{"stone": [0, 3, 0], "souls": 110},
	{"stone": [0, 3, 1], "souls": 130},
	{"stone": [0, 0, 2], "souls": 160},
	{"stone": [0, 0, 3], "souls": 200},
]


static func weapon_can_afford(run: RunState, weapon_level: int) -> bool:
	if weapon_level < 0 or weapon_level >= WEAPON_LEVEL_COSTS.size():
		return false
	var cost: Dictionary = WEAPON_LEVEL_COSTS[weapon_level]
	var stones: Array = cost.get("stone", [])
	for i in range(3):
		if run.smithing_stones[i] < int(stones[i]):
			return false
	return run.souls >= int(cost.get("souls", 0))


static func weapon_upgrade_cost_text(weapon_level: int) -> String:
	if weapon_level < 0 or weapon_level >= WEAPON_LEVEL_COSTS.size():
		return "已满级"
	var cost: Dictionary = WEAPON_LEVEL_COSTS[weapon_level]
	var parts: Array = []
	var stones: Array = cost.get("stone", [])
	for i in range(3):
		if int(stones[i]) > 0:
			parts.append("%d级锻造石×%d" % [i + 1, int(stones[i])])
	parts.append("%d 卢恩" % int(cost.get("souls", 0)))
	return "，".join(parts)


static func apply_weapon_upgrade(run: RunState, weapon_level: int) -> Dictionary:
	if weapon_level < 0 or weapon_level >= WEAPON_LEVEL_COSTS.size():
		return {"ok": false, "message": "武器已达最高等级。"}
	var cost: Dictionary = WEAPON_LEVEL_COSTS[weapon_level]
	var stones: Array = cost.get("stone", [])
	for i in range(3):
		if run.smithing_stones[i] < int(stones[i]):
			return {"ok": false, "message": "锻造石不足（需要 %s）。" % weapon_upgrade_cost_text(weapon_level)}
	var souls_cost: int = int(cost.get("souls", 0))
	if run.souls < souls_cost:
		return {"ok": false, "message": "卢恩不足（需要 %d）。" % souls_cost}
	for i in range(3):
		run.smithing_stones[i] -= int(stones[i])
	run.souls -= souls_cost
	return {"ok": true, "message": "武器强化至 +%d。" % (weapon_level + 1)}
