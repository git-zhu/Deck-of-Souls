class_name CombatController
extends RefCounted

const RunState = preload("res://scripts/core/RunState.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const CardEffectResolver = preload("res://scripts/core/CardEffectResolver.gd")

signal combat_changed
signal combat_ended(kind: String)
signal log_message(text: String)

var run: RunState
var registry: DataRegistry
var rng: RandomNumberGenerator

var enemy: Dictionary = {}
var enemy_intent: Dictionary = {}
var combat_over: bool = false
var ember: int = 3
var max_ember: int = 3
var block: int = 0


func _init(p_run: RunState, p_registry: DataRegistry, p_rng: RandomNumberGenerator) -> void:
	run = p_run
	registry = p_registry
	rng = p_rng


func combat_log(text: String) -> void:
	log_message.emit(text)


func start_combat(template: Dictionary) -> void:
	combat_over = false
	block = 0
	run.player_rot = 0
	run.player_bleed = 0
	run.player_vulnerable = 0
	run.player_strength = 0
	enemy = template.duplicate(true)
	enemy.hp = enemy.max_hp
	enemy.block = 0
	enemy.rot = 0
	enemy.bleed = 0
	enemy.vulnerable = 0
	enemy.strength = 0
	enemy.stance_max = enemy.stance
	enemy.stance_now = enemy.stance
	run.draw_pile.assign(run.deck)
	run.draw_pile.shuffle()
	run.hand.clear()
	run.discard_pile.clear()
	run.exhaust_pile.clear()
	combat_log("你踏入雾中。%s 举起武器。" % enemy.name)
	choose_enemy_intent()
	start_player_turn()


func start_player_turn() -> void:
	ember = max_ember
	block = 0
	apply_player_start_status()
	draw_cards(5)
	combat_changed.emit()


func apply_player_start_status() -> void:
	if run.player_rot > 0:
		take_player_damage(run.player_rot, true)
		combat_log("腐败在血管中开花：你受到 %d 点伤害。" % run.player_rot)
		run.player_rot = max(0, run.player_rot - 1)
	if run.player_bleed >= 10:
		run.player_bleed -= 10
		var burst: int = max(8, int(run.max_hp * 0.16))
		take_player_damage(burst, true)
		combat_log("出血爆发，你受到 %d 点伤害。" % burst)
	if run.player_vulnerable > 0:
		run.player_vulnerable -= 1


func play_card(index: int) -> void:
	if index < 0 or index >= run.hand.size() or combat_over:
		return
	var card_id := run.hand[index]
	var card := registry.get_card(card_id)
	if card == null:
		return
	if card.cost > ember:
		combat_log("集中不足。")
		combat_changed.emit()
		return
	ember -= card.cost
	run.hand.remove_at(index)
	combat_log("你打出《%s》。" % card.name)
	var resolver := CardEffectResolver.new(self)
	var exhaust: bool = resolver.resolve(card)
	if exhaust:
		run.exhaust_pile.append(card_id)
	else:
		run.discard_pile.append(card_id)
	check_combat_end()
	combat_changed.emit()


func deal_enemy_damage(amount: int, stance_damage: int) -> bool:
	var final: int = amount
	if enemy.vulnerable > 0:
		final = int(ceil(final * 1.5))
	if enemy.stance_now <= 0:
		final = int(ceil(final * 1.35))
	var blocked: int = mini(int(enemy.block), final)
	enemy.block -= blocked
	final -= blocked
	enemy.hp = maxi(0, int(enemy.hp) - final)
	enemy.stance_now -= stance_damage
	combat_log("造成 %d 伤害，削减 %d 姿态。" % [final, stance_damage])
	var broke: bool = false
	if enemy.stance_now <= 0:
		broke = true
		enemy.vulnerable += 1
		enemy.stance_now = enemy.stance_max
		combat_log("姿态崩解，%s 短暂露出破绽。" % enemy.name)
	return broke


func apply_enemy_bleed(value: int) -> void:
	enemy.bleed += value
	combat_log("出血积累 +%d。" % value)
	if enemy.bleed >= 10:
		enemy.bleed -= 10
		var burst: int = maxi(8, int(enemy.max_hp * 0.16))
		enemy.hp = maxi(0, int(enemy.hp) - burst)
		combat_log("出血爆发，追加 %d 点伤害。" % burst)


func gain_block(value: int) -> void:
	block += value
	combat_log("获得 %d 护甲。" % value)


func heal_player(value: int) -> void:
	var recovered: int = mini(run.max_hp - run.hp, value)
	run.hp += recovered
	combat_log("回复 %d 生命。" % recovered)


func use_flask() -> void:
	if run.flasks <= 0 or run.hp >= run.max_hp:
		return
	run.flasks -= 1
	heal_player(18)
	combat_changed.emit()


func draw_cards(count: int) -> void:
	for _i in range(count):
		if run.draw_pile.is_empty():
			if run.discard_pile.is_empty():
				return
			run.draw_pile.assign(run.discard_pile)
			run.discard_pile.clear()
			run.draw_pile.shuffle()
			combat_log("弃牌堆化为新的抽牌堆。")
		run.hand.append(run.draw_pile.pop_back())


func end_player_turn() -> void:
	if combat_over:
		return
	run.discard_pile.append_array(run.hand)
	run.hand.clear()
	enemy_turn()


func enemy_turn() -> void:
	enemy.block = 0
	if enemy.rot > 0:
		enemy.hp = maxi(0, int(enemy.hp) - int(enemy.rot))
		combat_log("腐败啃食 %s：%d 点伤害。" % [enemy.name, enemy.rot])
		enemy.rot = maxi(0, int(enemy.rot) - 1)
	if enemy.bleed >= 10:
		enemy.bleed -= 10
		var burst: int = maxi(8, int(enemy.max_hp * 0.16))
		enemy.hp = maxi(0, int(enemy.hp) - burst)
		combat_log("%s 出血爆发，受到 %d 点伤害。" % [enemy.name, burst])
	check_combat_end()
	if combat_over:
		return
	match enemy_intent.get("kind", ""):
		"attack":
			enemy_attack(int(enemy_intent.value), int(enemy_intent.get("hits", 1)))
		"attack_block":
			enemy.block += int(enemy_intent.block)
			combat_log("%s 获得 %d 护甲。" % [enemy.name, enemy_intent.block])
			enemy_attack(int(enemy_intent.value), 1)
		"debuff":
			run.player_vulnerable += int(enemy_intent.vulnerable)
			combat_log("%s 施加 %d 易伤。" % [enemy.name, enemy_intent.vulnerable])
		"buff":
			enemy.strength += int(enemy_intent.strength)
			combat_log("%s 力量 +%d。" % [enemy.name, enemy_intent.strength])
		"rot":
			run.player_rot += int(enemy_intent.value)
			combat_log("你积累 %d 腐败。" % enemy_intent.value)
		"attack_rot":
			enemy_attack(int(enemy_intent.value), 1)
			run.player_rot += int(enemy_intent.rot)
			combat_log("你积累 %d 腐败。" % enemy_intent.rot)
	if run.hp <= 0:
		combat_ended.emit("defeat")
		return
	choose_enemy_intent()
	start_player_turn()


func enemy_attack(value: int, hits: int) -> void:
	for _i in range(hits):
		var amount: int = value + int(enemy.strength)
		if run.player_vulnerable > 0:
			amount = int(ceil(amount * 1.5))
		var absorbed: int = mini(block, amount)
		block -= absorbed
		amount -= absorbed
		take_player_damage(amount, false)
		combat_log("%s 造成 %d 点伤害。" % [enemy.name, amount])


func take_player_damage(amount: int, ignores_block: bool) -> void:
	var final: int = amount
	if not ignores_block:
		var absorbed: int = mini(block, final)
		block -= absorbed
		final -= absorbed
	run.hp = maxi(0, run.hp - final)


func choose_enemy_intent() -> void:
	var moves: Array = enemy.moves
	enemy_intent = moves[rng.randi_range(0, moves.size() - 1)].duplicate(true)


func intent_text() -> String:
	var label: String = str(enemy_intent.get("text", "凝视"))
	match enemy_intent.get("kind", ""):
		"attack":
			return "%s，攻击 %d x%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.get("hits", 1)]
		"attack_block":
			return "%s，攻击 %d，护甲 %d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.block]
		"debuff":
			return "%s，施加易伤 %d" % [label, enemy_intent.vulnerable]
		"buff":
			return "%s，力量 +%d" % [label, enemy_intent.strength]
		"rot":
			return "%s，腐败 +%d" % [label, enemy_intent.value]
		"attack_rot":
			return "%s，攻击 %d，腐败 +%d" % [label, enemy_intent.value + int(enemy.get("strength", 0)), enemy_intent.rot]
	return label


func check_combat_end() -> void:
	if enemy.has("hp") and int(enemy.hp) <= 0 and not combat_over:
		combat_over = true
		run.souls += int(enemy.souls)
		combat_log("%s 倒下。你获得 %d 卢恩。" % [enemy.name, enemy.souls])
		if bool(enemy.get("is_run_boss", false)):
			combat_ended.emit("run_victory")
		elif bool(enemy.get("is_act_boss", false)):
			combat_ended.emit("act_clear")
		else:
			combat_ended.emit("reward")


func roll_rewards() -> Array[String]:
	var pool: Array[String] = []
	for id in registry.all_card_ids():
		var card := registry.get_card(id)
		if card != null and card.rarity != "starter":
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, 3) as Array[String]
