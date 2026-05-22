class_name RunRewardFlow
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const ActData = preload("res://data/ActData.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")
const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const DeckUtils = preload("res://scripts/ui/DeckUtils.gd")

var host: Node
var merchant_stock: Array = []
var merchant_sold: Array[bool] = []
var merchant_status: String = ""
var merchant_cost_percent: int = 100
var reward_export: Dictionary = {}


func _init(main_host: Node) -> void:
	host = main_host


func export_reward_state() -> Dictionary:
	return reward_export.duplicate(true)


func set_event_export(event_id: String) -> void:
	reward_export = {"kind": "event", "event_id": event_id}


func set_grace_result_export(title_text: String, body_text: String) -> void:
	reward_export = {
		"kind": "grace_result",
		"title": title_text,
		"body": body_text,
	}


func _set_merchant_export() -> void:
	var offer_ids: Array[String] = []
	for offer in merchant_stock:
		if offer is MerchantOfferData:
			offer_ids.append(offer.id)
	reward_export = {
		"kind": "merchant",
		"merchant_offer_ids": offer_ids,
		"merchant_sold": merchant_sold.duplicate(),
		"merchant_status": merchant_status,
		"merchant_cost_percent": merchant_cost_percent,
	}


func restore_reward_state(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		host.get("run_flow").show_map()
		return
	var d: Dictionary = data
	match str(d.get("kind", "")):
		"merchant":
			_restore_merchant(d)
			show_merchant()
		"event":
			var registry = host.get("registry")
			var event := registry.get_event(str(d.get("event_id", "")))
			if event != null:
				host.get("run_flow").show_event(event)
			else:
				host.get("run_flow").show_map()
		"grace_result":
			set_grace_result_export(str(d.get("title", "")), str(d.get("body", "")))
			host.call(
				"_present_reward_layer",
				RewardLayerViews.build_centered_continue(
					str(d.get("title", "")),
					str(d.get("body", "")),
					"继续",
					host.get("run_flow").advance_floor_and_show_map
				)
			)
		_:
			host.get("run_flow").show_map()


func _restore_merchant(data: Dictionary) -> void:
	var registry = host.get("registry")
	merchant_stock.clear()
	for offer_id in data.get("merchant_offer_ids", []):
		var offer: MerchantOfferData = registry.get_merchant_offer(str(offer_id)) as MerchantOfferData
		if offer != null:
			merchant_stock.append(offer)
	merchant_sold.clear()
	for sold in data.get("merchant_sold", []):
		merchant_sold.append(bool(sold))
	merchant_status = str(data.get("merchant_status", ""))
	merchant_cost_percent = int(data.get("merchant_cost_percent", 100))


func visit_merchant() -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var merchant_service = host.get("merchant_service")
	var act = registry.get_act(run_state.act_index())
	var offer_ids: Array = []
	merchant_cost_percent = 100
	if act != null:
		offer_ids = act.merchant_offer_ids
		merchant_cost_percent = act.merchant_cost_percent
	merchant_stock = merchant_service.roll_stock(run_state, registry, rng, 3, offer_ids)
	merchant_sold.clear()
	for _i in merchant_stock.size():
		merchant_sold.append(false)
	merchant_status = ""
	show_merchant()


func test_merchant_buy(offer_id: String) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var merchant_service = host.get("merchant_service")
	var offer: MerchantOfferData = registry.get_merchant_offer(offer_id) as MerchantOfferData
	if offer == null:
		push_error("Unknown merchant offer: %s" % offer_id)
		return
	var result: Dictionary = merchant_service.purchase(
		offer, run_state, registry, rng, merchant_cost_percent
	)
	if not bool(result.get("ok", false)):
		push_error("Merchant purchase failed: %s" % str(result.get("message", "")))
		return
	if bool(result.get("pick_card", false)):
		push_error("Merchant offer %s requires card picker" % offer_id)


func show_merchant() -> void:
	_set_merchant_export()
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_merchant_screen(
			merchant_stock,
			merchant_sold,
			host.get("run_state").souls,
			merchant_status,
			merchant_cost_percent,
			host.get("merchant_service"),
			host.get("run_state"),
			on_merchant_buy,
			leave_merchant
		)
	)


func on_merchant_buy(offer: MerchantOfferData, slot_index: int) -> void:
	if slot_index < merchant_sold.size() and merchant_sold[slot_index]:
		return
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var merchant_service = host.get("merchant_service")
	var result: Dictionary = merchant_service.purchase(
		offer, run_state, registry, rng, merchant_cost_percent
	)
	if not bool(result.get("ok", false)):
		merchant_status = str(result.get("message", ""))
		show_merchant()
		return
	var paid: int = int(result.get("paid_cost", offer.soul_cost))
	merchant_sold[slot_index] = true
	if bool(result.get("pick_ash_replace", false)):
		start_ash_replace_flow(
			func(removed_id: String, new_id: String):
				var old_c: CardData = registry.get_card(removed_id)
				var new_c: CardData = registry.get_card(new_id)
				var old_name := old_c.name if old_c != null else removed_id
				var new_name := new_c.name if new_c != null else new_id
				merchant_status = "花费 %d 卢恩，《%s》已被战灰《%s》覆盖。" % [
					paid, old_name, new_name
				]
				show_merchant()
		)
	elif bool(result.get("pick_card", false)):
		show_remove_card_picker(
			"整理行囊",
			"选择要从牌组中移除的一张牌。",
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				merchant_status = "花费 %d 卢恩，已从牌组移除《%s》。" % [paid, card_name]
				show_merchant()
		)
	else:
		merchant_status = str(result.get("message", ""))
		show_merchant()


func leave_merchant() -> void:
	host.get("run_state").advance_floor()
	host.get("run_flow").show_map()


func visit_grace() -> void:
	var options: Array = host.get("grace_service").roll_options(host.get("run_state"), host.get("rng"), 3)
	show_grace_rest(options)


func test_grace_pick(option_id: String) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var grace_service = host.get("grace_service")
	var option: GraceOptionData = registry.get_grace_option(option_id) as GraceOptionData
	if option == null:
		push_error("Unknown grace option: %s" % option_id)
		return
	var summary: String = grace_service.apply(option, run_state)
	if summary == GraceService.PICK_CARD:
		push_error("Grace pick %s requires card selection UI" % option_id)
		return
	run_state.advance_floor()


func show_grace_rest(options: Array) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_grace_rest(options, on_grace_option_picked)
	)


func on_grace_option_picked(option: GraceOptionData) -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var grace_service = host.get("grace_service")
	var summary: String = grace_service.apply(option, run_state)
	if summary == GraceService.PICK_CARD:
		show_remove_card_picker(
			"遗忘仪式",
			"选择要从牌组中移除的一张牌。",
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				show_grace_result("遗忘仪式", "已从牌组移除《%s》。" % card_name)
		)
	elif summary == GraceService.PICK_ASH_REPLACE:
		start_ash_replace_flow(
			func(removed_id: String, new_id: String):
				var old_c: CardData = registry.get_card(removed_id)
				var new_c: CardData = registry.get_card(new_id)
				var old_name := old_c.name if old_c != null else removed_id
				var new_name := new_c.name if new_c != null else new_id
				show_grace_result(
					"战灰传授",
					"《%s》已被战灰《%s》覆盖。" % [old_name, new_name]
				)
		)
	else:
		show_grace_result(option.title, summary)


func show_grace_result(title_text: String, body_text: String) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_centered_continue(
			title_text,
			body_text,
			"继续",
			func(): host.call("_advance_floor_and_show_map")
		)
	)


func start_ash_replace_flow(on_done: Callable) -> void:
	show_remove_card_picker(
		"战灰替换",
		"选择要被战灰覆盖的牌。",
		on_ash_card_picked_for_replace.bind(on_done),
		false
	)


func on_ash_card_picked_for_replace(removed_id: String, on_done: Callable) -> void:
	var options: Array = host.get("ash_service").roll_ash_cards(host.get("registry"), host.get("rng"), 3)
	show_ash_replace_picker(removed_id, options, on_done)


func show_ash_replace_picker(removed_id: String, card_ids: Array, on_done: Callable) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_ash_picker(
			"战灰传授",
			"从下列战灰中选择一张，覆盖你选定的牌。",
			card_ids,
			host.get("registry"),
			removed_id,
			host.get("run_state"),
			on_done
		)
	)


func show_remove_card_picker(
	title_text: String,
	hint_text: String,
	on_removed: Callable,
	remove_immediately: bool = true
) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_deck_picker(
			title_text,
			hint_text,
			DeckUtils.card_counts(host.get("run_state").deck),
			host.get("registry"),
			host.get("run_state"),
			on_removed,
			remove_immediately
		)
	)


func show_message_end(title_text: String, body_text: String) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_centered_continue(
			title_text, body_text, "继续", func(): host.get("run_flow").show_map()
		)
	)


func finish_combat_rewards() -> void:
	host.get("run_flow").advance_floor_and_show_map()


func show_post_combat_relic_rewards() -> void:
	var offers: Array = host.get("relic_service").roll_relic_offers(
		host.get("run_state"), host.get("registry"), host.get("rng"), 3
	)
	if offers.is_empty():
		finish_combat_rewards()
	else:
		show_relic_rewards(offers, finish_combat_rewards)


func show_act_clear(on_done: Callable) -> void:
	var run_state = host.get("run_state")
	run_state.hp = run_state.max_hp
	run_state.flasks = run_state.max_flasks
	var act: ActData = host.get("registry").get_act(run_state.act_index()) as ActData
	host.set("rewards", host.get("combat").roll_rewards(act))
	var act_title: String = act.title if act != null else "幕间休整"
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_card_rewards(
			"%s · 幕末" % act_title,
			"雾门后的金光回满生命与圣杯瓶。选一张牌带走，然后挑选护符。",
			host.get("rewards"),
			host.get("registry"),
			func(card_id: String):
				run_state.deck.append(card_id)
				on_done.call(),
			on_done,
			"不取牌，继续"
		)
	)


func show_card_rewards(on_done: Callable) -> void:
	var act: ActData = host.get("registry").get_act(host.get("run_state").act_index()) as ActData
	host.set("rewards", host.get("combat").roll_rewards(act))
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_card_rewards(
			"战利品",
			"选择一张牌加入牌组，或放弃卡牌奖励。",
			host.get("rewards"),
			host.get("registry"),
			func(card_id: String):
				host.get("run_state").deck.append(card_id)
				on_done.call(),
			on_done
		)
	)


func show_relic_rewards(relic_ids: Array, on_done: Callable) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_relic_rewards(
			relic_ids,
			host.get("registry"),
			host.get("relic_service"),
			host.get("run_state"),
			on_done
		)
	)
