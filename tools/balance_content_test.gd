extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CombatController = preload("res://scripts/core/CombatController.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const OriginData = preload("res://data/OriginData.gd")
const CardData = preload("res://data/CardData.gd")

const HP_PERCENTS: Array[int] = [100, 110, 125]
const NEW_CARD_IDS: Array[String] = [
	"rock_sling",
	"flame_grant_me_strength",
	"glintstone_stars",
	"hoarfrost_stomp",
]
const NEW_RELIC_IDS: Array[String] = [
	"erdtree_favor",
	"green_turtle_talisman",
	"gold_scarab",
]


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for act_index in range(RunState.ACT_COUNT):
		var act := registry.get_act(act_index)
		if act == null:
			_fail("missing act %d" % act_index)
			return
		if act.enemy_hp_percent != HP_PERCENTS[act_index]:
			_fail(
				"act %s enemy_hp_percent %d expected %d"
				% [act.id, act.enemy_hp_percent, HP_PERCENTS[act_index]]
			)
			return
		var non_starter := 0
		for card_id in act.reward_cards:
			var card := registry.get_card(str(card_id)) as CardData
			if card == null:
				_fail("unknown reward card %s on %s" % [card_id, act.id])
				return
			if card.rarity == "starter":
				_fail("starter in reward_cards: %s on %s" % [card_id, act.id])
				return
			non_starter += 1
		if non_starter < 4:
			_fail("act %s reward pool < 4 non-starter cards" % act.id)
			return

	for card_id in NEW_CARD_IDS:
		if registry.get_card(card_id) == null:
			_fail("missing card %s" % card_id)
			return

	for relic_id in NEW_RELIC_IDS:
		if registry.get_relic(relic_id) == null:
			_fail("missing relic %s" % relic_id)
			return

	run.floor_index = RunState.FLOORS_PER_ACT * 2
	var combat := CombatController.new(run, registry, rng)
	var template := {
		"name": "测试",
		"max_hp": 100,
		"stance": 5,
		"souls": 10,
		"moves": [{"kind": "attack", "value": 8, "hits": 1, "text": "试探"}],
	}
	combat.start_combat(template)
	if combat.enemy.max_hp != 125:
		_fail("act 3 scaled hp expected 125 got %d" % combat.enemy.max_hp)
		return

	run.relics.append("gold_scarab")
	var bonus := combat.relic_service.combat_souls_bonus(run, registry)
	if bonus != 5:
		_fail("gold_scarab bonus expected 5 got %d" % bonus)
		return

	print("balance_content_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
