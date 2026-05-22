class_name MerchantService
extends RefCounted

const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const RelicData = preload("res://data/RelicData.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")

const MAX_FLASKS := 5

var _offers: Array = []


func load_from_registry(registry: DataRegistry) -> void:
	_offers.clear()
	for offer_id in registry.all_merchant_offer_ids():
		var offer := registry.get_merchant_offer(str(offer_id)) as MerchantOfferData
		if offer != null:
			_offers.append(offer)


func effective_cost(offer: MerchantOfferData, cost_percent: int = 100) -> int:
	if cost_percent == 100:
		return offer.soul_cost
	return maxi(1, int(round(float(offer.soul_cost) * float(cost_percent) / 100.0)))


func is_eligible(offer: MerchantOfferData, run: RunState) -> bool:
	match offer.effect:
		"remove_card":
			return run.deck.size() > 5
		"max_flasks":
			return run.max_flasks < MAX_FLASKS
		"memory_stone":
			return run.can_gain_memory_stone()
		"ash_replace":
			return run.deck.size() > 5
		_:
			return true


func can_afford(offer: MerchantOfferData, run: RunState, cost_percent: int = 100) -> bool:
	return run.souls >= effective_cost(offer, cost_percent)


func roll_stock(
	run: RunState,
	registry: DataRegistry,
	rng: RandomNumberGenerator,
	count: int = 3,
	offer_ids: Array = []
) -> Array:
	var source: Array = _offers_for_ids(registry, offer_ids)
	var pool: Array = []
	for offer in source:
		if is_eligible(offer as MerchantOfferData, run):
			pool.append(offer)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func purchase(
	offer: MerchantOfferData,
	run: RunState,
	registry: DataRegistry,
	rng: RandomNumberGenerator,
	cost_percent: int = 100
) -> Dictionary:
	var paid: int = effective_cost(offer, cost_percent)
	if not can_afford(offer, run, cost_percent):
		return {"ok": false, "message": "卢恩不足。", "pick_card": false, "paid_cost": paid}
	if not is_eligible(offer, run):
		return {"ok": false, "message": "当前无法购买此物。", "pick_card": false, "paid_cost": paid}

	run.souls -= paid

	match offer.effect:
		"add_random_card":
			var card_id := _pick_random_card(registry, rng, offer.card_rarity_filter)
			if card_id.is_empty():
				run.souls += paid
				return {"ok": false, "message": "货箱是空的。", "pick_card": false, "paid_cost": paid}
			run.deck.append(card_id)
			var card := registry.get_card(card_id)
			var card_name := card.name if card != null else card_id
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得《%s》。" % [paid, card_name],
				"pick_card": false,
				"paid_cost": paid,
			}
		"remove_card":
			return {"ok": true, "message": "", "pick_card": true, "pick_ash_replace": false, "paid_cost": paid}
		"ash_replace":
			return {"ok": true, "message": "", "pick_card": false, "pick_ash_replace": true, "paid_cost": paid}
		"heal_percent":
			var heal: int = int(ceil(float(run.max_hp) * float(offer.effect_value) / 100.0))
			run.hp = mini(run.max_hp, run.hp + heal)
			return {
				"ok": true,
				"message": "花费 %d 卢恩，回复 %d 生命。" % [paid, heal],
				"pick_card": false,
				"paid_cost": paid,
			}
		"refill_flasks":
			run.flasks = run.max_flasks
			return {
				"ok": true,
				"message": "花费 %d 卢恩，圣杯瓶已灌满。" % paid,
				"pick_card": false,
				"paid_cost": paid,
			}
		"max_flasks":
			run.max_flasks = mini(MAX_FLASKS, run.max_flasks + offer.effect_value)
			run.flasks = run.max_flasks
			return {
				"ok": true,
				"message": "花费 %d 卢恩，圣杯瓶上限现为 %d。" % [paid, run.max_flasks],
				"pick_card": false,
				"paid_cost": paid,
			}
		"memory_stone":
			run.memory_stones += 1
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得记忆石。（%d/%d）" % [
					paid,
					run.memory_stones,
					RunState.MAX_MEMORY_STONES,
				],
				"pick_card": false,
				"paid_cost": paid,
			}
		"grant_relic":
			var relic_service := RelicService.new()
			var relic: RelicData = relic_service.grant_random_relic(run, registry, rng)
			if relic == null:
				run.souls += paid
				return {"ok": false, "message": "咖列的护符已售罄。", "pick_card": false, "paid_cost": paid}
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得护符《%s》。" % [paid, relic.name],
				"pick_card": false,
				"paid_cost": paid,
			}
		_:
			run.souls += paid
			return {"ok": false, "message": "咖列耸耸肩，交易失败。", "pick_card": false, "paid_cost": paid}


func _offers_for_ids(registry: DataRegistry, offer_ids: Array) -> Array:
	if offer_ids.is_empty():
		return _offers.duplicate()
	var pool: Array = []
	for raw_id in offer_ids:
		var offer := registry.get_merchant_offer(str(raw_id)) as MerchantOfferData
		if offer != null:
			pool.append(offer)
	if pool.is_empty():
		push_warning("MerchantService: act offer pool empty, falling back to all offers.")
		return _offers.duplicate()
	return pool


func _pick_random_card(registry: DataRegistry, rng: RandomNumberGenerator, rarity_filter: String) -> String:
	var pool: Array[String] = []
	for id in registry.all_card_ids():
		var card := registry.get_card(str(id))
		if card == null:
			continue
		if rarity_filter.is_empty():
			if card.rarity == "starter":
				continue
		elif card.rarity != rarity_filter:
			continue
		pool.append(str(id))
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
