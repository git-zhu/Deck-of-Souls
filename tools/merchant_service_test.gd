extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const OriginData = preload("res://data/OriginData.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var merchant := MerchantService.new()
	merchant.load_from_registry(registry)

	var run := RunState.new()
	var origin := registry.get_origin("vagabond") as OriginData
	run.reset_for_origin(origin, 42)
	run.souls = 100
	var deck_before: int = run.deck.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var curio := registry.get_merchant_offer("curio_card")
	if curio == null:
		push_error("curio_card offer missing")
		quit(1)
		return
	var result: Dictionary = merchant.purchase(curio, run, registry, rng)
	if not bool(result.get("ok", false)):
		push_error("curio purchase failed: %s" % str(result.get("message", "")))
		quit(1)
		return
	if run.souls != 50:
		push_error("expected 50 souls after 100-50 purchase, got %d" % run.souls)
		quit(1)
		return

	if merchant.effective_cost(curio, 95) != 48:
		push_error("effective_cost 50 @ 95%% expected 48")
		quit(1)
		return
	run.souls = 100
	var limgrave_pool: Array[String] = ["curio_card", "blood_vial", "refill_flasks", "remove_card"]
	var stock := merchant.roll_stock(run, registry, rng, 3, limgrave_pool)
	for offer in stock:
		var oid: String = str((offer as Object).get("id"))
		if not limgrave_pool.has(oid):
			push_error("roll_stock leaked offer %s" % oid)
			quit(1)
			return
	if run.deck.size() != deck_before + 1:
		push_error("expected deck +1 after curio, got %d" % run.deck.size())
		quit(1)
		return

	run.souls = 0
	if merchant.can_afford(curio, run):
		push_error("can_afford should be false at 0 souls")
		quit(1)
		return

	run.deck = ["a", "b", "c", "d", "e"]
	for _i in range(20):
		var stock := merchant.roll_stock(run, registry, rng, 3)
		for offer in stock:
			if str((offer as Object).get("id")) == "remove_card":
				push_error("remove_card should not appear when deck size is 5")
				quit(1)
				return

	print("Merchant service test passed")
	quit()
