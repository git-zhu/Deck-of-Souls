class_name MapGenerator
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapNodeData = preload("res://data/MapNodeData.gd")

const COMBAT_NODES := {
	"葛瑞克士兵": {"title": "关卡前废墟", "body": "葛瑞克士兵巡逻。胜利后获得一张牌与少量卢恩。"},
	"野狼": {"title": "艾雷教堂北侧", "body": "野狼在林间徘徊，商人咖列的篝火还在身后。"},
	"凯丹佣兵": {"title": "亚基尔湖北岸", "body": "凯丹佣兵沿湖道游荡，远处能听见飞龙亚基尔的风声。"},
	"挖石矿工": {"title": "宁姆格福坑道", "body": "挖石矿工守着锻造石，矿镐比看上去更硬。"},
	"学院辉石法师": {"title": "驿站街遗迹", "body": "学院辉石法师藏在废墟地下，辉石光芒从石缝里透出。"},
	"葛瑞克骑士": {"title": "史东薇尔城墙", "body": "葛瑞克骑士巡逻于城墙之上，铠甲上还带着宁姆格福的泥。"},
	"腐败眷属": {"title": "腐败湖畔", "body": "腐败眷属在湖畔蠕动，金色的菌丝缠住脚踝。"},
	"挖石山妖": {"title": "坑道深处", "body": "挖石山妖在矿道底层抬起巨臂，碎石从顶上落下。"},
}

const ELITE_NODES := {
	"法姆亚兹拉的兽人": {"title": "近林洞窟", "body": "法姆亚兹拉的兽人盘踞洞底，这是许多褪色者的第一个洞窟首领。"},
	"亚人首领": {"title": "海岸洞窟", "body": "亚人首领在黑暗中聚众嚎叫，洞外通向龙飨教堂。"},
	"熔炉骑士": {"title": "封牢深处", "body": "熔炉骑士的古老武艺仍在回响。"},
	"守墓斗士": {"title": "英雄墓地", "body": "守墓斗士守在墓碑之间，巨斧扬起时风声如哭。"},
}


func options_for_floor(run: RunState, registry: DataRegistry, rng: RandomNumberGenerator) -> Array:
	if run.is_act_boss_floor():
		var act := registry.get_act(run.act_index())
		if act == null:
			return []
		return [{
			"kind": "boss",
			"enemy": act.act_boss_name,
			"title": act.act_boss_title,
			"body": act.act_boss_body,
		}]
	var act := registry.get_act(run.act_index())
	if act == null:
		return []
	var pool: Array = []
	for node in act.fixed_nodes:
		pool.append(_node_to_dict(node))
	for enemy_name in act.combat_enemies:
		pool.append(_combat_option(str(enemy_name)))
	for enemy_name in act.elite_enemies:
		pool.append(_elite_option(str(enemy_name)))
	pool.shuffle()
	return pool.slice(0, 3)


func _node_to_dict(node: MapNodeData) -> Dictionary:
	return {
		"kind": node.kind,
		"title": node.title,
		"body": node.body,
		"enemy": node.enemy_name,
	}


func _combat_option(enemy_name: String) -> Dictionary:
	var meta: Dictionary = COMBAT_NODES.get(enemy_name, {"title": enemy_name, "body": "一场遭遇战。"})
	return {
		"kind": "combat",
		"enemy": enemy_name,
		"title": meta.title,
		"body": meta.body,
	}


func _elite_option(enemy_name: String) -> Dictionary:
	var meta: Dictionary = ELITE_NODES.get(enemy_name, {"title": enemy_name, "body": "精英敌人挡在路前。"})
	return {
		"kind": "elite",
		"enemy": enemy_name,
		"title": meta.title,
		"body": meta.body,
	}
