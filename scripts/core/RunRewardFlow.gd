class_name RunRewardFlow
extends RefCounted

const CardData = preload("res://data/CardData.gd")
const ActData = preload("res://data/ActData.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")
const MerchantOfferData = preload("res://data/MerchantOfferData.gd")
const MapEventData = preload("res://data/MapEventData.gd")
const GraceService = preload("res://scripts/core/GraceService.gd")
const LevelingService = preload("res://scripts/core/LevelingService.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const DeckUtils = preload("res://scripts/ui/DeckUtils.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")

# I5 追忆：BOSS 名 -> 二选一独占卡
const REMEMBRANCE := {
	"恶兆妖鬼玛尔基特": ["omen_judgment", "omen_chain"],
	"熔炉骑士": ["crucible_wings", "crucible_horn"],
	"接肢贵族": ["grafted_dragon", "royal_rot"],
}

# I4 大卢恩：rune_id -> 两种激活形态（护符二选一）
const RUNE_ACTIVATIONS := {
	"rune_margit": ["rune_margit_might", "rune_margit_blood"],
	"rune_crucible": ["rune_crucible_stance", "rune_crucible_armor"],
}

var host: Node
var merchant_stock: Array = []
var merchant_sold: Array[bool] = []
var merchant_status: String = ""
var merchant_cost_percent: int = 100
var reward_export: Dictionary = {}
var _rune_act_pending: Dictionary = {}      # I4：激活二选一的待决上下文
var _remembrance_pending: Dictionary = {}   # I5：追忆拾取的待决上下文


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
			var event: MapEventData = registry.get_event(str(d.get("event_id", ""))) as MapEventData
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
			leave_merchant,
			_on_merchant_kill  # I9 黑暗抉择
		)
	)


# I9 杀死商人：免费抄没全部未售库存 + 铃珠护符，代价是本局再无商人
func _on_merchant_kill() -> void:
	var registry = host.get("registry")
	var run_state = host.get("run_state")
	var rng = host.get("rng")
	var merchant_service = host.get("merchant_service")
	var seized := 0
	for slot_index in range(merchant_stock.size()):
		if slot_index < merchant_sold.size() and merchant_sold[slot_index]:
			continue
		var offer := merchant_stock[slot_index] as MerchantOfferData
		if offer == null or not merchant_service.is_eligible(offer, run_state):
			continue
		var result: Dictionary = merchant_service.purchase(offer, run_state, registry, rng, 0)
		if bool(result.get("ok", false)) \
			and not bool(result.get("pick_card", false)) \
			and not bool(result.get("pick_ash_replace", false)):
			if slot_index < merchant_sold.size():
				merchant_sold[slot_index] = true
			seized += 1
	host.get("relic_service").add_relic(run_state, registry, "kale_bellbearing")
	run_state.merchant_killed = true
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_centered_continue(
			"铃珠",
			"咖列倒下了。你抄没了他全部 %d 件货物，又从他的颈间取走一枚铃珠。剩下的路上，不会再有商人应你而来了。（某些需要他亲手操持的服务，随他一起走了。）" % seized,
			"继续",
			_on_merchant_kill_leave
		)
	)


func _on_merchant_kill_leave() -> void:
	host.get("run_state").advance_floor()
	host.get("run_flow").show_map()


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
	if summary == GraceService.PICK_UPGRADE:
		push_error("Grace pick %s requires upgrade card selection UI" % option_id)
		return
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
	if summary == "__level_up__":
		show_attr_upgrade()
		return
	if summary == "__weapon_upgrade__":
		show_weapon_upgrade()
		return
	if summary == GraceService.PICK_CARD:
		show_remove_card_picker(
			"遗忘仪式",
			"选择要从牌组中移除的一张牌。",
			func(card_id: String):
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				show_grace_result("遗忘仪式", "已从牌组移除《%s》。" % card_name)
		)
	elif summary == GraceService.PICK_UPGRADE:
		show_upgrade_card_picker()
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


func show_upgrade_card_picker() -> void:
	# 锻造刻印：选一张非 hook 卡升级（数值 +30%）
	var run_state = host.get("run_state")
	var registry = host.get("registry")
	var counts: Dictionary = DeckUtils.card_counts(run_state.deck)
	var upgradable := {}
	for cid in counts.keys():
		var c: CardData = registry.get_card(str(cid))
		if c != null and c.hook_id == "" and not run_state.upgraded_cards.has(str(cid)):
			upgradable[cid] = counts[cid]
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_deck_picker(
			"锻造刻印",
			"选择一张牌刻上强化铭文（数值 +30%）。",
			upgradable,
			registry,
			run_state,
			func(card_id: String):
				run_state.upgraded_cards.append(card_id)
				var c: CardData = registry.get_card(card_id)
				var card_name := c.name if c != null else card_id
				show_grace_result("锻造刻印", "《%s》被刻上铭文，变得更锋利了。" % card_name),
			false
		)
	)


func show_attr_upgrade() -> void:
	# 属性升级界面：可反复升级，点"继续上路"进入结果
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_attr_upgrade_screen(
			host.get("run_state"),
			_on_attr_upgrade_pressed,
			func() -> void: show_grace_result("属性升级", "潜能已被唤醒。")
		)
	)


func show_weapon_upgrade() -> void:
	# 武器强化界面
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_weapon_upgrade_screen(
			host.get("run_state"),
			_weapon_upgrade_infos(),
			_on_weapon_upgrade_pressed,
			func() -> void: show_grace_result("武器强化", "武器在铁砧上微微发亮。")
		)
	)


func _weapon_upgrade_infos() -> Array:
	var run_state = host.get("run_state")
	var registry = host.get("registry")
	var weapon_service = host.get("combat").weapon_service
	var infos: Array = []
	for wid in run_state.weapons:
		var weapon = registry.get_weapon(str(wid))
		if weapon == null:
			continue
		var level: int = weapon_service.weapon_level(run_state, str(wid))
		infos.append({
			"id": weapon.id,
			"name": weapon.name,
			"kind": weapon.kind,
			"level": level,
			"affordable": LevelingService.weapon_can_afford(run_state, level),
			"cost_text": LevelingService.weapon_upgrade_cost_text(level),
		})
	return infos


func _on_weapon_upgrade_pressed(weapon_id: String) -> void:
	var run_state = host.get("run_state")
	var registry = host.get("registry")
	var weapon_service = host.get("combat").weapon_service
	var weapon = registry.get_weapon(weapon_id)
	if weapon == null:
		return
	var level: int = weapon_service.weapon_level(run_state, weapon_id)
	var result: Dictionary = LevelingService.apply_weapon_upgrade(run_state, level)
	if bool(result.get("ok", false)):
		# 等级写入 RunState（随局存档），不再改共享 Resource
		run_state.weapon_levels[weapon_id] = level + 1
		show_weapon_upgrade()


func _on_attr_upgrade_pressed(key: String) -> void:
	# 实际执行升级（扣卢恩 + 加属性），然后重绘界面
	var run_state = host.get("run_state")
	var result: Dictionary = LevelingService.apply_attr_upgrade(run_state, key)
	if bool(result.get("ok", false)):
		host.call(
			"_present_reward_layer",
			RewardLayerViews.build_attr_upgrade_screen(
				run_state,
				_on_attr_upgrade_pressed,
				func() -> void: show_grace_result("属性升级", "潜能已被唤醒。")
			)
		)


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


func show_message_continue(title_text: String, body_text: String, on_done: Callable) -> void:
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_centered_continue(title_text, body_text, "继续", on_done)
	)


func show_rune_activation(rune_id: String, on_done: Callable) -> void:
	var run_state = host.get("run_state")
	var registry = host.get("registry")
	var relic_service = host.get("relic_service")
	var pair: Array = RUNE_ACTIVATIONS.get(rune_id, [])
	if pair.is_empty():
		on_done.call()
		return
	_rune_act_pending = {"rune_id": rune_id, "pair": pair, "on_done": on_done}
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_relic_rewards(
			pair, registry, relic_service, run_state, _on_rune_activation_done
		)
	)


func _on_rune_activation_done() -> void:
	var pending: Dictionary = _rune_act_pending.duplicate()
	_rune_act_pending = {}
	var run_state = host.get("run_state")
	var relic_service = host.get("relic_service")
	var rune_id := str(pending.get("rune_id", ""))
	var pair: Array = pending.get("pair", [])
	# 记录激活结果（选其一 / 放弃）
	var chosen := ""
	for rid in pair:
		if relic_service.has_relic(run_state, str(rid)):
			chosen = str(rid)
			break
	if rune_id != "":
		if chosen == "":
			run_state.great_runes[rune_id] = "refused"
		else:
			run_state.great_runes[rune_id] = chosen
	var cb: Callable = pending.get("on_done", Callable())
	if cb.is_valid():
		cb.call()


func show_remembrance(boss_name: String, on_done: Callable) -> void:
	var run_state = host.get("run_state")
	var registry = host.get("registry")
	var pair: Array = REMEMBRANCE.get(boss_name, [])
	if pair.is_empty():
		on_done.call()
		return
	if run_state.ng_plus > 0:
		# NG+ 漫步灵庙：两件追忆都拿
		var names: Array = []
		for cid in pair:
			run_state.deck.append(str(cid))
			var c: CardData = registry.get_card(str(cid))
			names.append(c.name if c != null else str(cid))
		show_message_continue(
			"追忆 · 漫步灵庙",
			"灵庙为你鸣钟：《%s》与《%s》都加入了牌组。" % [names[0], names[1]],
			on_done
		)
		return
	_remembrance_pending = {"on_done": on_done}
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_card_rewards(
			"追忆",
			"%s 的灵魂凝成了追忆。两件之中，选一件带走。" % boss_name,
			pair,
			registry,
			_on_remembrance_pick,
			on_done,
			"不取追忆"
		)
	)


func _on_remembrance_pick(card_id: String) -> void:
	var pending: Dictionary = _remembrance_pending.duplicate()
	_remembrance_pending = {}
	host.get("run_state").deck.append(card_id)
	var cb: Callable = pending.get("on_done", Callable())
	if cb.is_valid():
		cb.call()


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


func show_memory_card_choice(card_ids: Array, on_done: Callable) -> void:
	# 记忆的刻印：花 50 记忆选一张起始携带卡
	host.call(
		"_present_reward_layer",
		RewardLayerViews.build_card_rewards(
			"记忆的刻印",
			"消耗 50 记忆，选择一张牌随身携带。",
			card_ids,
			host.get("registry"),
			func(card_id: String):
				ProfileService.add_memory(-50)
				host.get("run_state").deck.append(card_id)
				on_done.call(),
			on_done
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
