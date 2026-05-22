class_name AshService
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")


func roll_ash_cards(registry: DataRegistry, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var ash_pool: Array = []
	var fallback: Array = []
	for card_id in registry.all_card_ids():
		var card := registry.get_card(str(card_id)) as CardData
		if card == null or card.rarity == "starter":
			continue
		fallback.append(card_id)
		if card.type == "战灰":
			ash_pool.append(card_id)
	var pool: Array = ash_pool if ash_pool.size() >= count else fallback
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
