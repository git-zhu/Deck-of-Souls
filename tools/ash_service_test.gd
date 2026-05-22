extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const AshService = preload("res://scripts/core/AshService.gd")
const RunState = preload("res://scripts/core/RunState.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var ash := AshService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var opts: Array = ash.roll_ash_cards(registry, rng, 3)
	if opts.is_empty():
		push_error("ash pool empty")
		quit(1)
		return

	for card_id in opts:
		var card := registry.get_card(str(card_id))
		if card == null:
			push_error("unknown card %s" % card_id)
			quit(1)
			return

	var run := RunState.new()
	run.deck = ["longsword", "longsword", "heater_shield", "heater_shield", "halberd", "crimson_flask"]
	run.replace_card_in_deck("halberd", str(opts[0]))
	if not run.deck.has(str(opts[0])):
		push_error("replace did not add new card")
		quit(1)
		return
	if run.deck.has("halberd"):
		push_error("replace did not remove old card")
		quit(1)
		return
	if run.deck.size() != 6:
		push_error("deck size changed after replace")
		quit(1)
		return

	print("Ash service test passed")
	quit()
