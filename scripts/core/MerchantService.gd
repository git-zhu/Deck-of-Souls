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


func is_eligible(offer: MerchantOfferData, run: RunState) -> bool:
	match offer.effect:
		"remove_card":
			return run.deck.size() > 5
		"max_flasks":
			return run.max_flasks < MAX_FLASKS
		"memory_stone":
			return run.can_gain_memory_stone()
		_:
			return true


func can_afford(offer: MerchantOfferData, run: RunState) -> bool:
	return run.souls >= offer.soul_cost


func roll_stock(run: RunState, _registry: DataRegistry, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = []
	for offer in _offers:
		if is_eligible(offer as MerchantOfferData, run):
			pool.append(offer)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func purchase(
	offer: MerchantOfferData,
	run: RunState,
	registry: DataRegistry,
	rng: RandomNumberGenerator
) -> Dictionary:
	if not can_afford(offer, run):
		return {"ok": false, "message": "卢恩不足。", "pick_card": false}
	if not is_eligible(offer, run):
		return {"ok": false, "message": "当前无法购买此物。", "pick_card": false}

	run.souls -= offer.soul_cost

	match offer.effect:
		"add_random_card":
			var card_id := _pick_random_card(registry, rng, offer.card_rarity_filter)
			if card_id.is_empty():
				run.souls += offer.soul_cost
				return {"ok": false, "message": "货箱是空的。", "pick_card": false}
			run.deck.append(card_id)
			var card := registry.get_card(card_id)
			var card_name := card.name if card != null else card_id
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得《%s》。" % [offer.soul_cost, card_name],
				"pick_card": false,
			}
		"remove_card":
			return {"ok": true, "message": "", "pick_card": true}
		"heal_percent":
			var heal: int = int(ceil(float(run.max_hp) * float(offer.effect_value) / 100.0))
			run.hp = mini(run.max_hp, run.hp + heal)
			return {
				"ok": true,
				"message": "花费 %d 卢恩，回复 %d 生命。" % [offer.soul_cost, heal],
				"pick_card": false,
			}
		"refill_flasks":
			run.flasks = run.max_flasks
			return {
				"ok": true,
				"message": "花费 %d 卢恩，圣杯瓶已灌满。" % offer.soul_cost,
				"pick_card": false,
			}
		"max_flasks":
			run.max_flasks = mini(MAX_FLASKS, run.max_flasks + offer.effect_value)
			run.flasks = run.max_flasks
			return {
				"ok": true,
				"message": "花费 %d 卢恩，圣杯瓶上限现为 %d。" % [offer.soul_cost, run.max_flasks],
				"pick_card": false,
			}
		"memory_stone":
			run.memory_stones += 1
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得记忆石。（%d/%d）" % [
					offer.soul_cost,
					run.memory_stones,
					RunState.MAX_MEMORY_STONES,
				],
				"pick_card": false,
			}
		"grant_relic":
			var relic_service := RelicService.new()
			var relic: RelicData = relic_service.grant_random_relic(run, registry, rng)
			if relic == null:
				run.souls += offer.soul_cost
				return {"ok": false, "message": "咖列的护符已售罄。", "pick_card": false}
			return {
				"ok": true,
				"message": "花费 %d 卢恩，获得护符《%s》。" % [offer.soul_cost, relic.name],
				"pick_card": false,
			}
		_:
			run.souls += offer.soul_cost
			return {"ok": false, "message": "咖列耸耸肩，交易失败。", "pick_card": false}


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
