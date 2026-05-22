extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")

const MERCHANT_COST_PERCENTS: Array[int] = [100, 105, 95]
const EVENT_WEIGHTS: Array[int] = [2, 3, 4]
const LIMGRAVE_MERCHANT: Array[String] = [
	"curio_card", "blood_vial", "refill_flasks", "remove_card",
]
const EVENT_COUNT_MIN := 8
const EVENT_ROLLS := 30


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var merchant := MerchantService.new()
	merchant.load_from_registry(registry)
	var gen := MapGenerator.new()
	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	if registry.events.size() != 12:
		_fail("expected 12 events, got %d" % registry.events.size())
		return

	for act_index in range(RunState.ACT_COUNT):
		var act := registry.get_act(act_index)
		if act == null:
			_fail("missing act %d" % act_index)
			return
		if act.merchant_cost_percent != MERCHANT_COST_PERCENTS[act_index]:
			_fail(
				"act %s merchant_cost_percent %d expected %d"
				% [act.id, act.merchant_cost_percent, MERCHANT_COST_PERCENTS[act_index]]
			)
			return
		if act.map_weight_event != EVENT_WEIGHTS[act_index]:
			_fail(
				"act %s map_weight_event %d expected %d"
				% [act.id, act.map_weight_event, EVENT_WEIGHTS[act_index]]
			)
			return
		if act.merchant_offer_ids.is_empty():
			_fail("act %s merchant_offer_ids empty" % act.id)
			return
		if act.event_ids.size() < 4:
			_fail("act %s expected >= 4 event_ids" % act.id)
			return
		for offer_id in act.merchant_offer_ids:
			if registry.get_merchant_offer(str(offer_id)) == null:
				_fail("unknown merchant offer %s on %s" % [offer_id, act.id])
				return
		for event_id in act.event_ids:
			if registry.get_event(str(event_id)) == null:
				_fail("unknown event %s on %s" % [event_id, act.id])
				return

	var curio := registry.get_merchant_offer("curio_card")
	if curio == null:
		_fail("curio_card missing")
		return
	if merchant.effective_cost(curio, 95) != 48:
		_fail("effective_cost 50 @ 95%% expected 48, got %d" % merchant.effective_cost(curio, 95))
		return

	run.souls = 200
	run.deck = origin.starting_deck.duplicate()
	var limgrave_stock := merchant.roll_stock(run, registry, rng, 3, LIMGRAVE_MERCHANT)
	for offer in limgrave_stock:
		var oid: String = str((offer as Object).get("id"))
		if not LIMGRAVE_MERCHANT.has(oid):
			_fail("limgrave stock has out-of-pool offer %s" % oid)
			return

	run.floor_index = 0
	var event_hits := 0
	for _i in range(EVENT_ROLLS):
		var opts := gen.options_for_floor(run, registry, rng)
		for opt in opts:
			if str(opt.get("kind", "")) == "event":
				event_hits += 1
	if event_hits < EVENT_COUNT_MIN:
		_fail("limgrave weighted rolls: expected >= %d events, got %d" % [EVENT_COUNT_MIN, event_hits])
		return

	print("act_economy_test: OK")
	quit()


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
