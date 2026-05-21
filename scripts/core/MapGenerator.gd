class_name MapGenerator
extends RefCounted


func options_for_floor(floor_index: int, rng: RandomNumberGenerator) -> Array:
	if floor_index >= RunState.MAP_FLOORS_PHASE1 - 1:
		return [{
			"kind": "boss",
			"enemy": "恶兆妖鬼玛尔基特",
			"title": "通城隧道",
			"body": "恶兆妖鬼玛尔基特守在史东薇尔城前。穿过这道雾门，宁姆格福的开局才算结束。",
		}]
	var options := [
		{"kind": "combat", "enemy": "葛瑞克士兵", "title": "关卡前废墟", "body": "葛瑞克士兵巡逻。胜利后获得一张牌与少量卢恩。"},
		{"kind": "combat", "enemy": "野狼", "title": "艾雷教堂北侧", "body": "野狼在林间徘徊，商人咖列的篝火还在身后。"},
		{"kind": "combat", "enemy": "凯丹佣兵", "title": "亚基尔湖北岸", "body": "凯丹佣兵沿湖道游荡，远处能听见飞龙亚基尔的风声。"},
		{"kind": "combat", "enemy": "挖石矿工", "title": "宁姆格福坑道", "body": "挖石矿工守着锻造石，矿镐比看上去更硬。"},
		{"kind": "combat", "enemy": "学院辉石法师", "title": "驿站街遗迹", "body": "学院辉石法师藏在废墟地下，辉石光芒从石缝里透出。"},
		{"kind": "elite", "enemy": "法姆亚兹拉的兽人", "title": "近林洞窟", "body": "法姆亚兹拉的兽人盘踞洞底，这是许多褪色者的第一个洞窟首领。"},
		{"kind": "elite", "enemy": "亚人首领", "title": "海岸洞窟", "body": "亚人首领在黑暗中聚众嚎叫，洞外通向龙飨教堂。"},
		{"kind": "elite", "enemy": "挖石山妖", "title": "宁姆格福坑道深处", "body": "挖石山妖在矿道底层抬起巨臂，碎石从顶上落下。"},
		{"kind": "elite", "enemy": "熔炉骑士", "title": "风暴山丘封牢", "body": "熔炉骑士的古老武艺仍在回响。"},
		{"kind": "grace", "title": "赐福点", "body": "回复生命，补充圣杯瓶，或用卢恩触碰命定之死。"},
		{"kind": "grace", "title": "艾雷教堂", "body": "短暂停歇。锻造台旁的金光提醒你整理牌组。"},
	]
	options.shuffle()
	return options.slice(0, 3)
