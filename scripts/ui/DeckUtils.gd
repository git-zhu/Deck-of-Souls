class_name DeckUtils
extends RefCounted


static func card_counts(card_ids: Array) -> Dictionary:
	var counts := {}
	for id in card_ids:
		var key := str(id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts
