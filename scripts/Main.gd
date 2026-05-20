extends Control

enum GameScreen { TITLE, ORIGIN, MAP, COMBAT, REWARD, GAME_OVER, VICTORY }

const CARD_W := 132.0
const CARD_H := 178.0
const STARTER_DECK := [
	"longsword", "longsword", "longsword",
	"heater_shield", "heater_shield", "heater_shield",
	"halberd", "crimson_flask"
]

var rng := RandomNumberGenerator.new()
var screen := GameScreen.TITLE
var run_seed := 0

var max_hp := 72
var hp := 72
var flasks := 2
var max_flasks := 2
var souls := 0
var floor_index := 0
var ember := 3
var max_ember := 3
var block := 0
var player_rot := 0
var player_bleed := 0
var player_vulnerable := 0
var player_strength := 0

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var deck: Array[String] = []

var enemy := {}
var enemy_intent := {}
var combat_over := false
var rewards: Array[String] = []
var selected_origin_id := "vagabond"

var root: MarginContainer
var title_layer: Control
var map_layer: Control
var combat_layer: Control
var reward_layer: Control
var end_layer: Control
var header: HBoxContainer
var log_box: RichTextLabel
var hand_row: HBoxContainer
var enemy_panel: PanelContainer
var player_panel: PanelContainer
var draw_label: Label
var discard_label: Label
var exhaust_label: Label
var end_turn_button: Button
var flask_button: Button
var deck_button: Button

var cards := {
	"longsword": {
		"name": "长剑", "cost": 1, "rarity": "starter", "type": "武器",
		"text": "造成 7 点伤害，削减 3 姿态。流浪骑士的可靠起手。",
		"tone": Color("#b9a37b")
	},
	"heater_shield": {
		"name": "熨斗形盾", "cost": 1, "rarity": "starter", "type": "盾牌",
		"text": "获得 8 护甲。若敌人意图攻击，返还 1 点集中。",
		"tone": Color("#7d9ca3")
	},
	"halberd": {
		"name": "戟", "cost": 2, "rarity": "starter", "type": "武器",
		"text": "造成 13 点伤害，削减 5 姿态。长柄武器让距离成为护甲。",
		"tone": Color("#c0a06c")
	},
	"uchigatana": {
		"name": "打刀", "cost": 1, "rarity": "starter", "type": "武器",
		"text": "造成 6 点伤害，积累 5 出血。芦苇之地武士的弯刃。",
		"tone": Color("#b94b50")
	},
	"longbow": {
		"name": "长弓", "cost": 1, "rarity": "starter", "type": "武器",
		"text": "造成 5 点伤害。若敌人没有护甲，抽 1 张牌。",
		"tone": Color("#9c8458")
	},
	"scimitar": {
		"name": "弯刀", "cost": 1, "rarity": "starter", "type": "武器",
		"text": "造成 4 点伤害两次。战士以双刀寻找破绽。",
		"tone": Color("#b7a071")
	},
	"battle_axe": {
		"name": "战斧", "cost": 2, "rarity": "starter", "type": "武器",
		"text": "造成 15 点伤害。若破姿态，获得 1 点集中。",
		"tone": Color("#c9834b")
	},
	"great_knife": {
		"name": "大刀", "cost": 0, "rarity": "starter", "type": "武器",
		"text": "造成 3 点伤害，积累 3 出血。盗贼从阴影里开局。",
		"tone": Color("#9d6d70")
	},
	"buckler": {
		"name": "小圆盾", "cost": 1, "rarity": "starter", "type": "盾牌",
		"text": "获得 5 护甲。若敌人意图攻击，削减 4 姿态。",
		"tone": Color("#879b9a")
	},
	"glintstone_pebble": {
		"name": "辉石魔砾", "cost": 1, "rarity": "starter", "type": "魔法",
		"text": "造成 4 点伤害两次。观星者将学院辉石化作投射物。",
		"tone": Color("#70a8d8")
	},
	"glintstone_arc": {
		"name": "辉石弯弧", "cost": 2, "rarity": "starter", "type": "魔法",
		"text": "造成 10 点伤害，削减 4 姿态。弧光适合扫开成群敌人。",
		"tone": Color("#6aaed0")
	},
	"magic_glintblade": {
		"name": "魔法辉剑", "cost": 1, "rarity": "starter", "type": "魔法",
		"text": "造成 8 点伤害。若本回合还剩集中，追加 3 点伤害。",
		"tone": Color("#7ba0e0")
	},
	"catch_flame": {
		"name": "火焰啊", "cost": 1, "rarity": "starter", "type": "祷告",
		"text": "造成 9 点伤害。先知以近身火焰迫使敌人退缩。",
		"tone": Color("#d38a45")
	},
	"heal": {
		"name": "恢复", "cost": 2, "rarity": "starter", "type": "祷告",
		"text": "回复 8 生命，获得 3 护甲。双指信仰留下喘息。",
		"tone": Color("#d9c16d")
	},
	"urgent_heal": {
		"name": "紧急恢复", "cost": 1, "rarity": "starter", "type": "祷告",
		"text": "回复 5 生命。若生命低于一半，抽 1 张牌。",
		"tone": Color("#decf82")
	},
	"assassins_approach": {
		"name": "刺客步法", "cost": 0, "rarity": "starter", "type": "祷告",
		"text": "获得 4 护甲，抽 1 张牌。忏悔者习惯无声接近。",
		"tone": Color("#8f8bb8")
	},
	"club": {
		"name": "棍棒", "cost": 1, "rarity": "starter", "type": "武器",
		"text": "造成 6 点伤害。若这是手牌最后一张，伤害 +5。",
		"tone": Color("#9b7a55")
	},
	"lions_claw": {
		"name": "狮子斩", "cost": 2, "rarity": "common", "type": "战灰",
		"text": "造成 14 点伤害，削减 5 姿态。源自红狮子军的翻身重击。",
		"tone": Color("#d3a141")
	},
	"volcano_pot": {
		"name": "火山壶", "cost": 1, "rarity": "common", "type": "壶",
		"text": "造成 6 点伤害，并施加 2 易伤。格密尔火山的热意仍在。",
		"tone": Color("#b85f43")
	},
	"rotten_breath": {
		"name": "腐败吐息", "cost": 2, "rarity": "uncommon", "type": "祷告",
		"text": "施加 6 腐败。龙飨祭坛的猩红吐息会拉长战斗的痛苦。",
		"tone": Color("#b94f73")
	},
	"black_flame": {
		"name": "黑焰", "cost": 2, "rarity": "uncommon", "type": "祷告",
		"text": "造成 12 点伤害，并施加 3 易伤。神皮使徒的火会继续灼烧。",
		"tone": Color("#5d5a65")
	},
	"bloodhounds_step": {
		"name": "猎犬步法", "cost": 0, "rarity": "uncommon", "type": "战灰",
		"text": "获得 4 护甲，抽 1 张牌。高速闪身，像黑夜骑兵掉落的传闻。",
		"tone": Color("#8f8bb8")
	},
	"crimson_flask": {
		"name": "红露滴圣杯瓶", "cost": 0, "rarity": "rare", "type": "圣杯瓶",
		"text": "回复 12 生命。消耗。赐福分配给褪色者的红色瓶子。",
		"tone": Color("#d85b4f")
	},
	"destined_death": {
		"name": "命定之死", "cost": 3, "rarity": "rare", "type": "传说",
		"text": "造成 25 点伤害。若击杀敌人，永久获得 4 最大生命。",
		"tone": Color("#9b7bd0")
	}
}

var enemy_templates := [
	{
		"name": "葛瑞克士兵", "max_hp": 38, "stance": 12, "souls": 16,
		"moves": [
			{"kind": "attack", "value": 7, "text": "君主军直剑"},
			{"kind": "attack_block", "value": 5, "block": 5, "text": "黄铜盾防线"},
			{"kind": "debuff", "vulnerable": 2, "text": "风暴关卡号令"}
		]
	},
	{
		"name": "野狼", "max_hp": 30, "stance": 9, "souls": 10,
		"moves": [
			{"kind": "attack", "value": 5, "hits": 2, "text": "狼群撕咬"},
			{"kind": "attack", "value": 9, "text": "扑击"},
			{"kind": "debuff", "vulnerable": 1, "text": "包围低吼"}
		]
	},
	{
		"name": "亚人", "max_hp": 34, "stance": 10, "souls": 14,
		"moves": [
			{"kind": "attack", "value": 6, "hits": 2, "text": "短刀乱抓"},
			{"kind": "buff", "strength": 1, "text": "夜色躁动"},
			{"kind": "attack_block", "value": 5, "block": 4, "text": "兽骨护身"}
		]
	},
	{
		"name": "葛瑞克骑士", "max_hp": 54, "stance": 15, "souls": 28,
		"moves": [
			{"kind": "attack", "value": 10, "text": "君主军大剑"},
			{"kind": "attack_block", "value": 7, "block": 8, "text": "风暴面盾"},
			{"kind": "buff", "strength": 2, "text": "骑士战技"}
		]
	},
	{
		"name": "凯丹佣兵", "max_hp": 48, "stance": 14, "souls": 24,
		"moves": [
			{"kind": "attack", "value": 9, "text": "凯丹弯刀"},
			{"kind": "attack", "value": 6, "hits": 2, "text": "骑马斩击"},
			{"kind": "buff", "strength": 2, "text": "佣兵怒吼"}
		]
	},
	{
		"name": "挖石矿工", "max_hp": 40, "stance": 16, "souls": 18,
		"moves": [
			{"kind": "attack_block", "value": 6, "block": 7, "text": "矿镐与石皮"},
			{"kind": "attack", "value": 10, "text": "结晶矿镐"},
			{"kind": "debuff", "vulnerable": 1, "text": "狭窄矿道"}
		]
	},
	{
		"name": "学院辉石法师", "max_hp": 42, "stance": 10, "souls": 22,
		"moves": [
			{"kind": "attack", "value": 5, "hits": 2, "text": "辉石魔砾连射"},
			{"kind": "buff", "strength": 2, "text": "卢瑟特辉石杖"},
			{"kind": "attack", "value": 11, "text": "卡利亚迅剑"}
		]
	},
	{
		"name": "腐败眷属", "max_hp": 46, "stance": 14, "souls": 24,
		"moves": [
			{"kind": "attack", "value": 8, "text": "虫丝刃"},
			{"kind": "rot", "value": 4, "text": "猩红腐败孢子"},
			{"kind": "attack_rot", "value": 6, "rot": 2, "text": "艾奥尼亚病灶"}
		]
	},
	{
		"name": "熔炉骑士", "max_hp": 72, "stance": 18, "souls": 48, "elite": true,
		"moves": [
			{"kind": "attack", "value": 13, "text": "熔炉百相之尾"},
			{"kind": "attack_block", "value": 8, "block": 8, "text": "熔炉角盾"},
			{"kind": "buff", "strength": 3, "text": "古老黄金树之力"},
			{"kind": "attack", "value": 18, "text": "熔炉百相之翼"}
		]
	},
	{
		"name": "法姆亚兹拉的兽人", "max_hp": 66, "stance": 17, "souls": 42, "elite": true,
		"moves": [
			{"kind": "attack", "value": 8, "hits": 2, "text": "兽骨弯刀"},
			{"kind": "buff", "strength": 2, "text": "古龙时代的野性"},
			{"kind": "attack", "value": 16, "text": "咆哮重劈"}
		]
	},
	{
		"name": "亚人首领", "max_hp": 68, "stance": 16, "souls": 44, "elite": true,
		"moves": [
			{"kind": "attack", "value": 7, "hits": 3, "text": "海岸洞窟围攻"},
			{"kind": "buff", "strength": 2, "text": "首领嚎叫"},
			{"kind": "attack_block", "value": 12, "block": 6, "text": "骨棒横扫"}
		]
	},
	{
		"name": "守墓斗士", "max_hp": 70, "stance": 18, "souls": 46, "elite": true,
		"moves": [
			{"kind": "attack", "value": 12, "text": "连枷旋舞"},
			{"kind": "debuff", "vulnerable": 2, "text": "墓地压迫"},
			{"kind": "attack", "value": 18, "text": "链锤处刑"}
		]
	},
	{
		"name": "挖石山妖", "max_hp": 82, "stance": 20, "souls": 54, "elite": true,
		"moves": [
			{"kind": "attack", "value": 15, "text": "山妖踩踏"},
			{"kind": "attack_block", "value": 10, "block": 10, "text": "岩肤硬直"},
			{"kind": "debuff", "vulnerable": 2, "text": "矿道震落"}
		]
	},
	{
		"name": "接肢贵族", "max_hp": 95, "stance": 22, "souls": 90, "boss": true,
		"moves": [
			{"kind": "attack", "value": 12, "hits": 2, "text": "接肢剑舞"},
			{"kind": "debuff", "vulnerable": 3, "text": "王族凝视"},
			{"kind": "attack_block", "value": 16, "block": 10, "text": "兽纹黄金盾"},
			{"kind": "rot", "value": 6, "text": "蜘蛛般的近身压迫"}
		]
	},
	{
		"name": "恶兆妖鬼玛尔基特", "max_hp": 110, "stance": 24, "souls": 120, "boss": true,
		"moves": [
			{"kind": "attack", "value": 13, "hits": 2, "text": "手杖连击"},
			{"kind": "attack_block", "value": 14, "block": 10, "text": "黄金短剑"},
			{"kind": "debuff", "vulnerable": 3, "text": "野心之火该灭"},
			{"kind": "attack", "value": 22, "text": "黄金锤跃击"}
		]
	}
]

var origins := {
	"vagabond": {
		"name": "流浪骑士", "level": 9, "max_hp": 78, "flasks": 2,
		"stats": "生命 15 / 力量 14 / 灵巧 13",
		"equipment": "长剑、戟、熨斗形盾",
		"deck": ["longsword", "longsword", "longsword", "heater_shield", "heater_shield", "heater_shield", "halberd", "crimson_flask"],
		"note": "高生命与稳定盾牌，适合第一次穿过宁姆格福。"
	},
	"samurai": {
		"name": "武士", "level": 9, "max_hp": 70, "flasks": 2,
		"stats": "生命 12 / 耐力 13 / 灵巧 15",
		"equipment": "打刀、长弓、红棘圆盾",
		"deck": ["uchigatana", "uchigatana", "uchigatana", "longbow", "longbow", "heater_shield", "bloodhounds_step", "crimson_flask"],
		"note": "出血与远程兼备，来自芦苇之地的均衡开局。"
	},
	"astrologer": {
		"name": "观星者", "level": 6, "max_hp": 62, "flasks": 2,
		"stats": "集中 15 / 智力 16 / 灵巧 12",
		"equipment": "辉石魔砾、辉石弯弧、短剑、观星杖",
		"deck": ["glintstone_pebble", "glintstone_pebble", "glintstone_pebble", "glintstone_arc", "longsword", "heater_shield", "magic_glintblade", "crimson_flask"],
		"note": "依靠雷亚卢卡利亚的辉石魔法，用脆弱生命换取稳定输出。"
	},
	"prophet": {
		"name": "预言家", "level": 7, "max_hp": 66, "flasks": 2,
		"stats": "集中 14 / 信仰 16 / 力量 11",
		"equipment": "恢复、火焰啊、短矛、指头圣印记",
		"deck": ["catch_flame", "catch_flame", "heal", "heal", "heater_shield", "longsword", "rotten_breath", "crimson_flask"],
		"note": "以祷告管理血线，火焰逼近，恢复拖长战斗。"
	},
	"warrior": {
		"name": "战士", "level": 8, "max_hp": 68, "flasks": 2,
		"stats": "集中 12 / 耐力 11 / 灵巧 16",
		"equipment": "双弯刀、铆钉木盾",
		"deck": ["scimitar", "scimitar", "scimitar", "scimitar", "buckler", "buckler", "bloodhounds_step", "crimson_flask"],
		"note": "双刀连击最容易触发低费循环，但防线薄。"
	},
	"wretch": {
		"name": "一贫如洗者", "level": 1, "max_hp": 60, "flasks": 3,
		"stats": "全属性 10",
		"equipment": "棍棒",
		"deck": ["club", "club", "club", "club", "club", "crimson_flask", "crimson_flask"],
		"note": "几乎没有装备，只有均等属性和更多圣杯瓶。"
	}
}

func _ready() -> void:
	rng.randomize()
	_build_ui()
	_show_title()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#16130f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 22)
	root.add_theme_constant_override("margin_right", 22)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	root.add_child(stack)

	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	title_layer = _new_layer(stack)
	map_layer = _new_layer(stack)
	combat_layer = _new_layer(stack)
	reward_layer = _new_layer(stack)
	end_layer = _new_layer(stack)

	_setup_theme()


func _setup_theme() -> void:
	var theme := Theme.new()
	var font_size := 18
	theme.set_font_size("font_size", "Label", font_size)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_font_size("font_size", "RichTextLabel", 16)
	theme.set_color("font_color", "Label", Color("#e8ddc7"))
	theme.set_color("font_color", "Button", Color("#f0e5cd"))
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("#d8b15d"))
	self.theme = theme


func _new_layer(parent: Control) -> Control:
	var layer := Control.new()
	layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(layer)
	return layer


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _hide_layers() -> void:
	for layer in [title_layer, map_layer, combat_layer, reward_layer, end_layer]:
		layer.visible = false
	_clear(header)


func _show_title() -> void:
	screen = GameScreen.TITLE
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	title_layer.add_child(box)

	var title := Label.new()
	title.text = "破碎法环：褪色者牌局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#e6c56d"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "从候王礼拜堂醒来，在宁姆格福的赐福之间改写牌组。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)

	var start := Button.new()
	start.text = "选择出身"
	start.custom_minimum_size = Vector2(240, 54)
	start.pressed.connect(_show_origin)
	box.add_child(start)

	var hint := Label.new()
	hint.text = "参考本体初始职业、武器、战灰、魔法、祷告与敌人设计。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#b9ac94"))
	box.add_child(hint)


func _show_origin() -> void:
	screen = GameScreen.ORIGIN
	_hide_layers()
	title_layer.visible = true
	_clear(title_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)
	title_layer.add_child(wrap)

	var title := Label.new()
	title.text = "选择出身"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "出身只决定开局属性与装备。就像本体一样，之后的牌组会在交界地中改变。"
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(grid)

	for id in origins.keys():
		grid.add_child(_origin_card(str(id)))


func _origin_card(origin_id: String) -> PanelContainer:
	var origin: Dictionary = origins[origin_id]
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var name := Label.new()
	name.text = "%s  Lv.%d" % [origin.name, origin.level]
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var stats := Label.new()
	stats.text = origin.stats
	stats.add_theme_color_override("font_color", Color("#d8ccb4"))
	v.add_child(stats)

	var gear := Label.new()
	gear.text = origin.equipment
	gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gear)

	var note := Label.new()
	note.text = origin.note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("font_color", Color("#b9ac94"))
	v.add_child(note)

	var pick := Button.new()
	pick.text = "以此出身开始"
	pick.custom_minimum_size = Vector2(0, 42)
	pick.pressed.connect(func(): _start_run(origin_id))
	v.add_child(pick)
	return panel


func _start_run(origin_id: String = "vagabond") -> void:
	run_seed = randi()
	rng.seed = run_seed
	selected_origin_id = origin_id
	var origin: Dictionary = origins.get(origin_id, origins.vagabond)
	max_hp = int(origin.max_hp)
	hp = max_hp
	max_flasks = int(origin.flasks)
	flasks = max_flasks
	souls = 0
	floor_index = 0
	deck.assign(origin.deck)
	_log_reset()
	_log("出身：%s。装备：%s。" % [origin.name, origin.equipment])
	_show_map()


func _show_map() -> void:
	screen = GameScreen.MAP
	_hide_layers()
	map_layer.visible = true
	_clear(map_layer)
	_build_header()

	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 16)
	map_layer.add_child(wrap)

	var title := Label.new()
	title.text = "宁姆格福路标"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e2bd65"))
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "第 %d 段 / 6。沿赐福指引穿过风暴山丘，接近候王礼拜堂的阴影。" % [floor_index + 1]
	desc.add_theme_color_override("font_color", Color("#c8bca5"))
	wrap.add_child(desc)

	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	wrap.add_child(choices)

	var options := _map_options()
	for option in options:
		var card := _map_choice_card(option)
		choices.add_child(card)


func _map_options() -> Array:
	if floor_index >= 5:
		return [{"kind": "boss", "enemy": "恶兆妖鬼玛尔基特", "title": "通城隧道", "body": "恶兆妖鬼玛尔基特守在史东薇尔城前。穿过这道雾门，宁姆格福的开局才算结束。"}]
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
		{"kind": "grace", "title": "艾雷教堂", "body": "短暂停歇。锻造台旁的金光提醒你整理牌组。"}
	]
	options.shuffle()
	return options.slice(0, 3)


func _map_choice_card(option: Dictionary) -> PanelContainer:
	var panel := _panel(Color("#242018"))
	panel.custom_minimum_size = Vector2(0, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name := Label.new()
	name.text = option.title
	name.add_theme_font_size_override("font_size", 28)
	name.add_theme_color_override("font_color", Color("#e0c06c"))
	v.add_child(name)

	var body := Label.new()
	body.text = option.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var btn := Button.new()
	btn.text = "踏入"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func(): _choose_map_option(option))
	v.add_child(btn)
	return panel


func _choose_map_option(option: Dictionary) -> void:
	match str(option.get("kind", "")):
		"combat":
			_start_combat(_pick_named_enemy(str(option.get("enemy", "")), false, false))
		"elite":
			_start_combat(_pick_named_enemy(str(option.get("enemy", "")), true, false))
		"boss":
			_start_combat(_pick_named_enemy(str(option.get("enemy", "")), false, true))
		"grace":
			_visit_grace()


func _visit_grace() -> void:
	var before_hp: int = hp
	_heal_player(18)
	var recovered: int = hp - before_hp
	flasks = max_flasks
	if souls >= 45 and not deck.has("destined_death"):
		souls -= 45
		deck.append("destined_death")
		_show_message_end("赐福点", "你回复 %d 生命，补满圣杯瓶，并以 45 卢恩窥见《命定之死》。" % recovered)
	else:
		_show_message_end("赐福点", "你回复 %d 生命，补满圣杯瓶。金色引导仍指向雾门。" % recovered)
	floor_index += 1


func _show_message_end(title_text: String, body_text: String) -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(720, 0)
	box.add_child(body)
	var next := Button.new()
	next.text = "继续"
	next.custom_minimum_size = Vector2(220, 48)
	next.pressed.connect(_show_map)
	box.add_child(next)


func _pick_enemy(elite: bool, boss: bool) -> Dictionary:
	var pool: Array = enemy_templates.filter(func(e: Dictionary) -> bool: return bool(e.get("boss", false)) == boss and bool(e.get("elite", false)) == elite)
	if pool.is_empty():
		pool = enemy_templates.filter(func(e): return not bool(e.get("boss", false)) and not bool(e.get("elite", false)))
	return pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)


func _pick_named_enemy(enemy_name: String, elite: bool, boss: bool) -> Dictionary:
	for template: Dictionary in enemy_templates:
		if str(template.get("name", "")) == enemy_name:
			return template.duplicate(true)
	return _pick_enemy(elite, boss)


func _start_combat(template: Dictionary) -> void:
	screen = GameScreen.COMBAT
	combat_over = false
	block = 0
	player_rot = 0
	player_bleed = 0
	player_vulnerable = 0
	player_strength = 0
	enemy = template.duplicate(true)
	enemy.hp = enemy.max_hp
	enemy.block = 0
	enemy.rot = 0
	enemy.bleed = 0
	enemy.vulnerable = 0
	enemy.strength = 0
	enemy.stance_max = enemy.stance
	enemy.stance_now = enemy.stance
	draw_pile.assign(deck)
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_log_reset()
	_log("你踏入雾中。%s 举起武器。" % enemy.name)
	_choose_enemy_intent()
	_start_player_turn()


func _start_player_turn() -> void:
	ember = max_ember
	block = 0
	_apply_player_start_status()
	_draw_cards(5)
	_render_combat()


func _apply_player_start_status() -> void:
	if player_rot > 0:
		_take_player_damage(player_rot, true)
		_log("腐败在血管中开花：你受到 %d 点伤害。" % player_rot)
		player_rot = max(0, player_rot - 1)
	if player_vulnerable > 0:
		player_vulnerable -= 1


func _render_combat() -> void:
	_hide_layers()
	combat_layer.visible = true
	_clear(combat_layer)
	_build_header()

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	combat_layer.add_child(main)

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	main.add_child(field)

	player_panel = _fighter_panel("褪色者", hp, max_hp, block, "腐败 %d  出血 %d  易伤 %d" % [player_rot, player_bleed, player_vulnerable], Color("#2a241b"))
	player_panel.custom_minimum_size = Vector2(250, 0)
	field.add_child(player_panel)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(270, 0)
	center.add_theme_constant_override("separation", 8)
	field.add_child(center)
	var intent := Label.new()
	intent.text = "敌方意图：%s" % _intent_text()
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent.add_theme_font_size_override("font_size", 23)
	intent.add_theme_color_override("font_color", Color("#e6c56d"))
	center.add_child(intent)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.fit_content = false
	log_box.scroll_following = true
	log_box.custom_minimum_size = Vector2(270, 170)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.text = _log_text()
	center.add_child(log_box)

	enemy_panel = _fighter_panel(enemy.name, enemy.hp, enemy.max_hp, int(enemy.block), "姿态 %d/%d  腐败 %d  出血 %d  易伤 %d  力量 %d" % [enemy.stance_now, enemy.stance_max, enemy.rot, enemy.bleed, enemy.vulnerable, enemy.strength], Color("#2b1d1b"))
	enemy_panel.custom_minimum_size = Vector2(280, 0)
	field.add_child(enemy_panel)

	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation", 18)
	main.add_child(piles)
	draw_label = _small_stat("抽牌 %d" % draw_pile.size())
	discard_label = _small_stat("弃牌 %d" % discard_pile.size())
	exhaust_label = _small_stat("消耗 %d" % exhaust_pile.size())
	piles.add_child(draw_label)
	piles.add_child(discard_label)
	piles.add_child(exhaust_label)
	piles.add_child(_small_stat("集中 %d/%d" % [ember, max_ember]))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	main.add_child(actions)
	flask_button = Button.new()
	flask_button.text = "圣杯瓶 (%d)" % flasks
	flask_button.disabled = flasks <= 0 or hp >= max_hp
	flask_button.pressed.connect(_use_flask)
	actions.add_child(flask_button)
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.pressed.connect(_end_player_turn)
	actions.add_child(end_turn_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, CARD_H + 18)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(hand_scroll)

	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_scroll.add_child(hand_row)
	for i in range(hand.size()):
		hand_row.add_child(_card_button(hand[i], i))


func _build_header() -> void:
	_clear(header)
	header.add_child(_small_stat("生命 %d/%d" % [hp, max_hp]))
	header.add_child(_small_stat("圣杯瓶 %d/%d" % [flasks, max_flasks]))
	header.add_child(_small_stat("卢恩 %d" % souls))
	header.add_child(_small_stat("牌组 %d" % deck.size()))
	if screen == GameScreen.COMBAT:
		header.add_child(_small_stat("抽牌 %d  弃牌 %d" % [draw_pile.size(), discard_pile.size()]))
	header.add_child(_small_stat("层数 %d/6" % [floor_index + 1]))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	deck_button = Button.new()
	deck_button.text = "查看牌组"
	deck_button.custom_minimum_size = Vector2(118, 34)
	deck_button.pressed.connect(_show_deck_view)
	header.add_child(deck_button)


func _small_stat(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#d8ccb4"))
	label.add_theme_font_size_override("font_size", 18)
	return label


func _show_deck_view() -> void:
	var popup := AcceptDialog.new()
	popup.title = "牌组"
	popup.min_size = Vector2i(620, 520)
	add_child(popup)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	popup.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var counts := _card_counts(deck)
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(cards[a].name) < str(cards[b].name)
	)
	for id in ids:
		var card: Dictionary = cards[id]
		var row := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#242018")
		style.border_color = card.tone.darkened(0.1)
		style.set_border_width_all(1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", style)
		list.add_child(row)

		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = "x%d  %s  [%s / 集中:%d]\n%s" % [counts[id], card.name, card.type, card.cost, card.text]
		row.add_child(text)

	popup.popup_centered()
	popup.close_requested.connect(func(): popup.queue_free())


func _card_counts(card_ids: Array[String]) -> Dictionary:
	var counts := {}
	for id in card_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#4f4535")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _fighter_panel(n: String, cur_hp: int, full_hp: int, cur_block: int, status: String, color: Color) -> PanelContainer:
	var panel := _panel(color)
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var name := Label.new()
	name.text = n
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("#e4c06d"))
	v.add_child(name)
	var hp_label := Label.new()
	hp_label.text = "生命 %d / %d" % [cur_hp, full_hp]
	hp_label.add_theme_font_size_override("font_size", 22)
	v.add_child(hp_label)
	var bar := ProgressBar.new()
	bar.max_value = full_hp
	bar.value = cur_hp
	bar.custom_minimum_size = Vector2(0, 22)
	v.add_child(bar)
	var block_label := Label.new()
	block_label.text = "护甲 %d" % cur_block
	v.add_child(block_label)
	var status_label := Label.new()
	status_label.text = status
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#c8bca5"))
	v.add_child(status_label)
	return panel


func _card_button(card_id: String, index: int) -> Button:
	var c: Dictionary = cards[card_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(CARD_W, CARD_H)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = "%s\n%s  集中:%d\n\n%s" % [c.name, c.type, c.cost, c.text]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = c.text
	button.disabled = int(c.cost) > ember or combat_over
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = c.tone.darkened(0.45)
	style.border_color = c.tone.lightened(0.2)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(func(): _play_card(index))
	return button


func _play_card(index: int) -> void:
	if index < 0 or index >= hand.size() or combat_over:
		return
	var card_id := hand[index]
	var c: Dictionary = cards[card_id]
	if int(c.cost) > ember:
		_log("集中不足。")
		_render_combat()
		return
	ember -= int(c.cost)
	hand.remove_at(index)
	_log("你打出《%s》。" % c.name)
	var exhaust := false
	match card_id:
		"longsword":
			_deal_enemy_damage(7 + player_strength, 3)
		"heater_shield":
			_gain_block(8)
			if enemy_intent.get("kind", "") in ["attack", "attack_block", "attack_rot"]:
				ember += 1
				_log("盾面稳住冲击，返还 1 集中。")
		"halberd":
			_deal_enemy_damage(13 + player_strength, 5)
		"uchigatana":
			_deal_enemy_damage(6 + player_strength, 2)
			_apply_enemy_bleed(5)
		"longbow":
			_deal_enemy_damage(5 + player_strength, 1)
			if int(enemy.block) <= 0:
				_draw_cards(1)
		"scimitar":
			_deal_enemy_damage(4 + player_strength, 1)
			_deal_enemy_damage(4 + player_strength, 1)
		"battle_axe":
			var axe_broke: bool = _deal_enemy_damage(15 + player_strength, 4)
			if axe_broke:
				ember += 1
		"great_knife":
			_deal_enemy_damage(3 + player_strength, 1)
			_apply_enemy_bleed(3)
		"buckler":
			_gain_block(5)
			if enemy_intent.get("kind", "") in ["attack", "attack_block", "attack_rot"]:
				enemy.stance_now -= 4
				_log("小圆盾架开武器，削减 4 姿态。")
		"glintstone_pebble":
			_deal_enemy_damage(4 + player_strength, 1)
			_deal_enemy_damage(4 + player_strength, 1)
		"glintstone_arc":
			_deal_enemy_damage(10 + player_strength, 4)
		"magic_glintblade":
			_deal_enemy_damage(8 + player_strength, 2)
			if ember > 0:
				_deal_enemy_damage(3, 1)
		"catch_flame":
			_deal_enemy_damage(9 + player_strength, 3)
		"heal":
			_heal_player(8)
			_gain_block(3)
		"urgent_heal":
			_heal_player(5)
			if hp < max_hp / 2:
				_draw_cards(1)
		"assassins_approach":
			_gain_block(4)
			_draw_cards(1)
		"club":
			var club_damage: int = 6 + player_strength
			if hand.is_empty():
				club_damage += 5
			_deal_enemy_damage(club_damage, 2)
		"lions_claw":
			var broke: bool = _deal_enemy_damage(14 + player_strength, 5)
			if broke:
				_draw_cards(1)
		"volcano_pot":
			_deal_enemy_damage(6 + player_strength, 2)
			enemy.vulnerable += 2
			_log("火山壶爆开，敌人获得 2 易伤。")
		"rotten_breath":
			enemy.rot += 6
			_log("%s 被腐败吐息侵染。" % enemy.name)
		"black_flame":
			_deal_enemy_damage(12 + player_strength, 4)
			enemy.vulnerable += 3
			_log("黑焰残留在敌人身上，敌人获得 3 易伤。")
		"bloodhounds_step":
			_gain_block(4)
			_draw_cards(1)
		"crimson_flask":
			_heal_player(12)
			exhaust = true
		"destined_death":
			var was_alive: bool = int(enemy.get("hp", 0)) > 0
			_deal_enemy_damage(25 + player_strength, 8)
			if was_alive and enemy.hp <= 0:
				max_hp += 4
				hp += 4
				_log("命定之死留下空位：最大生命 +4。")
	if exhaust:
		exhaust_pile.append(card_id)
	else:
		discard_pile.append(card_id)
	_check_combat_end()
	if screen == GameScreen.COMBAT:
		_render_combat()


func _deal_enemy_damage(amount: int, stance_damage: int) -> bool:
	var final: int = amount
	if enemy.vulnerable > 0:
		final = int(ceil(final * 1.5))
	if enemy.stance_now <= 0:
		final = int(ceil(final * 1.35))
	var blocked: int = min(int(enemy.block), final)
	enemy.block -= blocked
	final -= blocked
	enemy.hp = max(0, int(enemy.hp) - final)
	enemy.stance_now -= stance_damage
	_log("造成 %d 伤害，削减 %d 姿态。" % [final, stance_damage])
	var broke: bool = false
	if enemy.stance_now <= 0:
		broke = true
		enemy.vulnerable += 1
		enemy.stance_now = enemy.stance_max
		_log("姿态崩解，%s 短暂露出破绽。" % enemy.name)
	return broke


func _apply_enemy_bleed(value: int) -> void:
	enemy.bleed += value
	_log("出血积累 +%d。" % value)
	if enemy.bleed >= 10:
		enemy.bleed -= 10
		var burst: int = max(8, int(enemy.max_hp * 0.16))
		enemy.hp = max(0, int(enemy.hp) - burst)
		_log("出血爆发，追加 %d 点伤害。" % burst)


func _gain_block(value: int) -> void:
	block += value
	_log("获得 %d 护甲。" % value)


func _heal_player(value: int) -> void:
	var recovered: int = min(max_hp - hp, value)
	hp += recovered
	_log("回复 %d 生命。" % recovered)


func _use_flask() -> void:
	if flasks <= 0 or hp >= max_hp:
		return
	flasks -= 1
	_heal_player(18)
	_render_combat()


func _draw_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile.assign(discard_pile)
			discard_pile.clear()
			draw_pile.shuffle()
			_log("弃牌堆化为新的抽牌堆。")
		hand.append(draw_pile.pop_back())


func _end_player_turn() -> void:
	if combat_over:
		return
	discard_pile.append_array(hand)
	hand.clear()
	_enemy_turn()


func _enemy_turn() -> void:
	enemy.block = 0
	if enemy.rot > 0:
		enemy.hp = max(0, int(enemy.hp) - int(enemy.rot))
		_log("腐败啃食 %s：%d 点伤害。" % [enemy.name, enemy.rot])
		enemy.rot = max(0, int(enemy.rot) - 1)
	_check_combat_end()
	if combat_over:
		return
	match enemy_intent.get("kind", ""):
		"attack":
			_enemy_attack(int(enemy_intent.value), int(enemy_intent.get("hits", 1)))
		"attack_block":
			enemy.block += int(enemy_intent.block)
			_log("%s 获得 %d 护甲。" % [enemy.name, enemy_intent.block])
			_enemy_attack(int(enemy_intent.value), 1)
		"debuff":
			player_vulnerable += int(enemy_intent.vulnerable)
			_log("%s 施加 %d 易伤。" % [enemy.name, enemy_intent.vulnerable])
		"buff":
			enemy.strength += int(enemy_intent.strength)
			_log("%s 力量 +%d。" % [enemy.name, enemy_intent.strength])
		"rot":
			player_rot += int(enemy_intent.value)
			_log("你积累 %d 腐败。" % enemy_intent.value)
		"attack_rot":
			_enemy_attack(int(enemy_intent.value), 1)
			player_rot += int(enemy_intent.rot)
			_log("你积累 %d 腐败。" % enemy_intent.rot)
	if hp <= 0:
		_show_game_over()
		return
	_choose_enemy_intent()
	_start_player_turn()


func _enemy_attack(value: int, hits: int) -> void:
	for i in range(hits):
		var amount: int = value + int(enemy.strength)
		if player_vulnerable > 0:
			amount = int(ceil(amount * 1.5))
		var absorbed: int = min(block, amount)
		block -= absorbed
		amount -= absorbed
		_take_player_damage(amount, false)
		_log("%s 造成 %d 点伤害。" % [enemy.name, amount])


func _take_player_damage(amount: int, ignores_block: bool) -> void:
	var final: int = amount
	if not ignores_block:
		var absorbed: int = min(block, final)
		block -= absorbed
		final -= absorbed
	hp = max(0, hp - final)


func _choose_enemy_intent() -> void:
	var moves: Array = enemy.moves
	enemy_intent = moves[rng.randi_range(0, moves.size() - 1)].duplicate(true)


func _intent_text() -> String:
	var label: String = str(enemy_intent.get("text", "凝视"))
	match enemy_intent.get("kind", ""):
		"attack":
			return "%s，攻击 %d x%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.get("hits", 1)]
		"attack_block":
			return "%s，攻击 %d，护甲 %d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.block]
		"debuff":
			return "%s，施加易伤 %d" % [label, enemy_intent.vulnerable]
		"buff":
			return "%s，力量 +%d" % [label, enemy_intent.strength]
		"rot":
			return "%s，腐败 +%d" % [label, enemy_intent.value]
		"attack_rot":
			return "%s，攻击 %d，腐败 +%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.rot]
	return label


func _check_combat_end() -> void:
	if enemy.has("hp") and int(enemy.hp) <= 0 and not combat_over:
		combat_over = true
		souls += int(enemy.souls)
		_log("%s 倒下。你获得 %d 卢恩。" % [enemy.name, enemy.souls])
		if bool(enemy.get("boss", false)):
			_show_victory()
		else:
			_show_rewards()


func _show_rewards() -> void:
	screen = GameScreen.REWARD
	_hide_layers()
	reward_layer.visible = true
	_clear(reward_layer)
	_build_header()
	rewards = _roll_rewards()

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	reward_layer.add_child(box)
	var title := Label.new()
	title.text = "战利品"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#e0c06c"))
	box.add_child(title)
	var desc := Label.new()
	desc.text = "选择一张牌加入牌组，或放弃奖励。"
	box.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for id in rewards:
		row.add_child(_reward_card(id))

	var skip := Button.new()
	skip.text = "放弃，继续前进"
	skip.custom_minimum_size = Vector2(240, 48)
	skip.pressed.connect(func():
		floor_index += 1
		_show_map()
	)
	box.add_child(skip)


func _roll_rewards() -> Array[String]:
	var pool: Array[String] = []
	for id in cards.keys():
		if cards[id].rarity != "starter":
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, 3)


func _reward_card(card_id: String) -> Button:
	var c: Dictionary = cards[card_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 320)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s\n%s  集中:%d\n稀有度:%s\n\n%s" % [c.name, c.type, c.cost, c.rarity, c.text]
	button.pressed.connect(func():
		deck.append(card_id)
		floor_index += 1
		_show_map()
	)
	return button


func _show_game_over() -> void:
	screen = GameScreen.GAME_OVER
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	end_layer.add_child(box)
	var title := Label.new()
	title.text = "你死了"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("#b94b50"))
	box.add_child(title)
	var body := Label.new()
	body.text = "卢恩散落在冷石上。下一次，也许能多走一步。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var retry := Button.new()
	retry.text = "重新开始"
	retry.custom_minimum_size = Vector2(220, 50)
	retry.pressed.connect(_start_run)
	box.add_child(retry)


func _show_victory() -> void:
	screen = GameScreen.VICTORY
	_hide_layers()
	end_layer.visible = true
	_clear(end_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	end_layer.add_child(box)
	var title := Label.new()
	title.text = "传说暂时闭环"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#e6c56d"))
	box.add_child(title)
	var body := Label.new()
	body.text = "接肢贵族倒下。你带着 %d 卢恩和 %d 张牌离开雾门。" % [souls, deck.size()]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var retry := Button.new()
	retry.text = "再开一局"
	retry.custom_minimum_size = Vector2(220, 50)
	retry.pressed.connect(_start_run)
	box.add_child(retry)


var log_lines: Array[String] = []


func _log_reset() -> void:
	log_lines.clear()


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 9:
		log_lines.pop_front()


func _log_text() -> String:
	var out := ""
	for line in log_lines:
		out += "[color=#d9ccb3]%s[/color]\n" % line
	return out
