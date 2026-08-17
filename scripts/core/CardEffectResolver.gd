class_name CardEffectResolver
extends RefCounted

const CombatController = preload("res://scripts/core/CombatController.gd")
const CardData = preload("res://data/CardData.gd")
const CardEffectStep = preload("res://data/CardEffectStep.gd")

var combat: CombatController


func _init(p_combat: CombatController) -> void:
	combat = p_combat


func resolve(card: CardData) -> bool:
	if card.hook_id != "":
		_run_hook(card)
		return card.exhaust_after_play
	var steps: Array = card.effects if card.effects.size() > 0 else _catalog_steps(card.id)
	for step in steps:
		if step is CardEffectStep:
			_apply_step(step as CardEffectStep, card)
	return card.exhaust_after_play


func _apply_step(step: CardEffectStep, card: CardData = null) -> void:
	var strength: int = combat.run.player_strength
	# 锻造刻印：升级卡数值 ×1.3（抽牌不放大）
	var upgraded: bool = card != null and combat.run.upgraded_cards.has(card.id)
	var sv: int = step.value
	if upgraded:
		sv = maxi(step.value + 1, int(ceil(float(step.value) * 1.3)))
	match step.kind:
		CardEffectStep.Kind.DAMAGE:
			for _i in range(step.hits):
				var dmg: int = sv + strength
				if card != null:
					dmg = combat.calculate_card_damage(card, sv) + strength
				combat.deal_enemy_damage(dmg, combat.calculate_stance_damage(step.stance))
		CardEffectStep.Kind.DAMAGE_ALL:
			# AOE：对全体存活敌人造成伤害
			for i in range(combat.enemies.size()):
				var e: Dictionary = combat.enemies[i]
				if int(e.get("hp", 0)) > 0:
					var aoe_dmg: int = sv + strength
					if card != null:
						aoe_dmg = combat.calculate_card_damage(card, sv) + strength
					combat.deal_enemy_damage(aoe_dmg, combat.calculate_stance_damage(step.stance), i)
		CardEffectStep.Kind.APPLY_ALL_VULN:
			for i in range(combat.enemies.size()):
				var e: Dictionary = combat.enemies[i]
				if int(e.get("hp", 0)) > 0:
					e.vulnerable = mini(3, int(e.get("vulnerable", 0)) + sv)
					combat.combat_log("%s 获得 %d 易伤。" % [e.name, sv])
		CardEffectStep.Kind.APPLY_ALL_ROT:
			for i in range(combat.enemies.size()):
				var e: Dictionary = combat.enemies[i]
				if int(e.get("hp", 0)) > 0:
					e.rot = int(e.get("rot", 0)) + sv
					combat.combat_log("%s 被腐败侵染。" % e.name)
		CardEffectStep.Kind.APPLY_ALL_BLEED:
			for i in range(combat.enemies.size()):
				var e: Dictionary = combat.enemies[i]
				if int(e.get("hp", 0)) > 0:
					combat.apply_enemy_bleed(sv, i)
		CardEffectStep.Kind.GAIN_BLOCK:
			combat.gain_block(sv)
		CardEffectStep.Kind.HEAL:
			combat.heal_player(sv)
		CardEffectStep.Kind.DRAW:
			combat.draw_cards(step.value)
		CardEffectStep.Kind.APPLY_BLEED:
			combat.apply_enemy_bleed(sv)
		CardEffectStep.Kind.APPLY_ROT_ON_ENEMY:
			combat.enemy.rot += sv
			combat.combat_log("%s 被腐败吐息侵染。" % combat.enemy.name)
		CardEffectStep.Kind.APPLY_VULN_ON_ENEMY:
			combat.enemy.vulnerable = mini(3, combat.enemy.vulnerable + sv)
			combat.combat_log("敌人获得 %d 易伤。" % sv)
		CardEffectStep.Kind.GAIN_STRENGTH:
			combat.run.player_strength += sv
			combat.combat_log("力量 +%d（本场战斗）。" % sv)
		CardEffectStep.Kind.SELF_DAMAGE:
			# 癫火代价：灼烧自身，但不会自毙（最低留 1 HP）
			if combat.run.hp > 1:
				var self_dmg: int = mini(sv, combat.run.hp - 1)
				combat.run.hp -= self_dmg
				combat.combat_log("癫火灼烧了你：%d 伤害。" % self_dmg)


func _catalog_steps(card_id: String) -> Array:
	var steps: Array = []
	var s := CardEffectStep.new()
	match card_id:
		"longsword":
			s.kind = CardEffectStep.Kind.DAMAGE
			s.value = 7
			s.stance = 3
			steps.append(s)
		"halberd":
			var halberd := CardEffectStep.new()
			halberd.kind = CardEffectStep.Kind.DAMAGE
			halberd.value = 13
			halberd.stance = 5
			steps.append(halberd)
		"uchigatana":
			s = CardEffectStep.new()
			s.kind = CardEffectStep.Kind.DAMAGE
			s.value = 6
			s.stance = 2
			steps.append(s)
			var bleed := CardEffectStep.new()
			bleed.kind = CardEffectStep.Kind.APPLY_BLEED
			bleed.value = 5
			steps.append(bleed)
		"scimitar":
			for _i in 2:
				var hit := CardEffectStep.new()
				hit.kind = CardEffectStep.Kind.DAMAGE
				hit.value = 4
				hit.stance = 1
				steps.append(hit)
		"great_knife":
			var knife := CardEffectStep.new()
			knife.kind = CardEffectStep.Kind.DAMAGE
			knife.value = 3
			knife.stance = 1
			steps.append(knife)
			var g_bleed := CardEffectStep.new()
			g_bleed.kind = CardEffectStep.Kind.APPLY_BLEED
			g_bleed.value = 3
			steps.append(g_bleed)
		"glintstone_pebble":
			for _i in 2:
				var pebble := CardEffectStep.new()
				pebble.kind = CardEffectStep.Kind.DAMAGE
				pebble.value = 4
				pebble.stance = 1
				steps.append(pebble)
		"glintstone_arc":
			var arc := CardEffectStep.new()
			arc.kind = CardEffectStep.Kind.DAMAGE
			arc.value = 10
			arc.stance = 4
			steps.append(arc)
		"catch_flame":
			var flame := CardEffectStep.new()
			flame.kind = CardEffectStep.Kind.DAMAGE
			flame.value = 9
			flame.stance = 3
			steps.append(flame)
		"heal":
			var heal := CardEffectStep.new()
			heal.kind = CardEffectStep.Kind.HEAL
			heal.value = 8
			steps.append(heal)
			var shield := CardEffectStep.new()
			shield.kind = CardEffectStep.Kind.GAIN_BLOCK
			shield.value = 3
			steps.append(shield)
		"assassins_approach":
			var block := CardEffectStep.new()
			block.kind = CardEffectStep.Kind.GAIN_BLOCK
			block.value = 4
			steps.append(block)
			var draw := CardEffectStep.new()
			draw.kind = CardEffectStep.Kind.DRAW
			draw.value = 1
			steps.append(draw)
		"volcano_pot":
			var pot := CardEffectStep.new()
			pot.kind = CardEffectStep.Kind.DAMAGE_ALL
			pot.value = 5
			pot.stance = 2
			steps.append(pot)
			var vuln := CardEffectStep.new()
			vuln.kind = CardEffectStep.Kind.APPLY_ALL_VULN
			vuln.value = 1
			steps.append(vuln)
		"rotten_breath":
			var rot := CardEffectStep.new()
			rot.kind = CardEffectStep.Kind.APPLY_ALL_ROT
			rot.value = 5
			steps.append(rot)
		"black_flame":
			var bf := CardEffectStep.new()
			bf.kind = CardEffectStep.Kind.DAMAGE
			bf.value = 12
			bf.stance = 4
			steps.append(bf)
			var bf_vuln := CardEffectStep.new()
			bf_vuln.kind = CardEffectStep.Kind.APPLY_VULN_ON_ENEMY
			bf_vuln.value = 3
			steps.append(bf_vuln)
		"bloodhounds_step":
			var bs_block := CardEffectStep.new()
			bs_block.kind = CardEffectStep.Kind.GAIN_BLOCK
			bs_block.value = 4
			steps.append(bs_block)
			var bs_draw := CardEffectStep.new()
			bs_draw.kind = CardEffectStep.Kind.DRAW
			bs_draw.value = 1
			steps.append(bs_draw)
		"crimson_flask":
			var flask := CardEffectStep.new()
			flask.kind = CardEffectStep.Kind.HEAL
			flask.value = 12
			steps.append(flask)
		"rock_sling":
			s.kind = CardEffectStep.Kind.DAMAGE_ALL
			s.value = 5
			s.stance = 1
			steps.append(s)
		"flame_grant_me_strength":
			var str_step := CardEffectStep.new()
			str_step.kind = CardEffectStep.Kind.GAIN_STRENGTH
			str_step.value = 2
			steps.append(str_step)
		"glintstone_stars":
			for _i in 2:
				var star := CardEffectStep.new()
				star.kind = CardEffectStep.Kind.DAMAGE_ALL
				star.value = 3
				star.stance = 1
				steps.append(star)
		"hoarfrost_stomp":
			var stomp := CardEffectStep.new()
			stomp.kind = CardEffectStep.Kind.DAMAGE_ALL
			stomp.value = 5
			stomp.stance = 3
			steps.append(stomp)
		"twinblade":
			for _i in 2:
				var tb := CardEffectStep.new()
				tb.kind = CardEffectStep.Kind.DAMAGE
				tb.value = 4
				tb.stance = 1
				steps.append(tb)
		"storm_blade":
			var sb := CardEffectStep.new()
			sb.kind = CardEffectStep.Kind.DAMAGE
			sb.value = 8
			sb.stance = 4
			steps.append(sb)
		"bloody_slash":
			var bl := CardEffectStep.new()
			bl.kind = CardEffectStep.Kind.DAMAGE
			bl.value = 6
			bl.stance = 2
			steps.append(bl)
			var bl_bleed := CardEffectStep.new()
			bl_bleed.kind = CardEffectStep.Kind.APPLY_BLEED
			bl_bleed.value = 3
			steps.append(bl_bleed)
		"comet":
			var cm := CardEffectStep.new()
			cm.kind = CardEffectStep.Kind.DAMAGE
			cm.value = 11
			cm.stance = 2
			steps.append(cm)
		"shard_spiral":
			for _i in 2:
				var ss := CardEffectStep.new()
				ss.kind = CardEffectStep.Kind.DAMAGE
				ss.value = 6
				ss.stance = 1
				steps.append(ss)
		# ── 追忆卡（I5）：BOSS 独占，二选一；NG+ 漫步灵庙可两件都拿 ──
		"omen_judgment":
			var oj := CardEffectStep.new()
			oj.kind = CardEffectStep.Kind.DAMAGE
			oj.value = 18
			oj.stance = 6
			steps.append(oj)
			var oj_vuln := CardEffectStep.new()
			oj_vuln.kind = CardEffectStep.Kind.APPLY_VULN_ON_ENEMY
			oj_vuln.value = 1
			steps.append(oj_vuln)
		"omen_chain":
			var oc := CardEffectStep.new()
			oc.kind = CardEffectStep.Kind.DAMAGE
			oc.value = 4
			oc.stance = 1
			oc.hits = 4
			steps.append(oc)
		"crucible_wings":
			var cw := CardEffectStep.new()
			cw.kind = CardEffectStep.Kind.DAMAGE
			cw.value = 16
			cw.stance = 8
			steps.append(cw)
		"crucible_horn":
			var ch_block := CardEffectStep.new()
			ch_block.kind = CardEffectStep.Kind.GAIN_BLOCK
			ch_block.value = 12
			steps.append(ch_block)
			var ch_str := CardEffectStep.new()
			ch_str.kind = CardEffectStep.Kind.GAIN_STRENGTH
			ch_str.value = 1
			steps.append(ch_str)
		"grafted_dragon":
			var gd := CardEffectStep.new()
			gd.kind = CardEffectStep.Kind.DAMAGE_ALL
			gd.value = 12
			gd.stance = 4
			steps.append(gd)
			var gd_rot := CardEffectStep.new()
			gd_rot.kind = CardEffectStep.Kind.APPLY_ALL_ROT
			gd_rot.value = 2
			steps.append(gd_rot)
		"royal_rot":
			var rr := CardEffectStep.new()
			rr.kind = CardEffectStep.Kind.DAMAGE
			rr.value = 8
			rr.stance = 2
			steps.append(rr)
			var rr_rot := CardEffectStep.new()
			rr_rot.kind = CardEffectStep.Kind.APPLY_ROT_ON_ENEMY
			rr_rot.value = 5
			steps.append(rr_rot)
		# ── 献剑（I6 少女的引火：献出武器的回报）──
		"sacrificed_blade":
			var sb2 := CardEffectStep.new()
			sb2.kind = CardEffectStep.Kind.DAMAGE
			sb2.value = 24
			sb2.stance = 6
			steps.append(sb2)
		# ── 癫火卡（I8）：强力但灼烧自身 ──
		"frenzy_flame":
			var ff := CardEffectStep.new()
			ff.kind = CardEffectStep.Kind.DAMAGE_ALL
			ff.value = 14
			steps.append(ff)
			var ff_self := CardEffectStep.new()
			ff_self.kind = CardEffectStep.Kind.SELF_DAMAGE
			ff_self.value = 6
			steps.append(ff_self)
		"three_fingers":
			var tf := CardEffectStep.new()
			tf.kind = CardEffectStep.Kind.DAMAGE
			tf.value = 20
			tf.stance = 4
			steps.append(tf)
			var tf_self := CardEffectStep.new()
			tf_self.kind = CardEffectStep.Kind.SELF_DAMAGE
			tf_self.value = 8
			steps.append(tf_self)
		"frenzied_burst":
			var fb_rot := CardEffectStep.new()
			fb_rot.kind = CardEffectStep.Kind.APPLY_ROT_ON_ENEMY
			fb_rot.value = 6
			steps.append(fb_rot)
			var fb_self := CardEffectStep.new()
			fb_self.kind = CardEffectStep.Kind.SELF_DAMAGE
			fb_self.value = 3
			steps.append(fb_self)
		"lord_of_frenzy":
			var lf_str := CardEffectStep.new()
			lf_str.kind = CardEffectStep.Kind.GAIN_STRENGTH
			lf_str.value = 3
			steps.append(lf_str)
			var lf_dmg := CardEffectStep.new()
			lf_dmg.kind = CardEffectStep.Kind.DAMAGE
			lf_dmg.value = 12
			lf_dmg.stance = 3
			steps.append(lf_dmg)
			var lf_self := CardEffectStep.new()
			lf_self.kind = CardEffectStep.Kind.SELF_DAMAGE
			lf_self.value = 5
			steps.append(lf_self)
		# ── 壶哥赠礼（I7）──
		"giant_jar_fist":
			var jf := CardEffectStep.new()
			jf.kind = CardEffectStep.Kind.DAMAGE
			jf.value = 16
			jf.stance = 6
			steps.append(jf)
			var jf_block := CardEffectStep.new()
			jf_block.kind = CardEffectStep.Kind.GAIN_BLOCK
			jf_block.value = 4
			steps.append(jf_block)
	return steps


# 钩子卡伤害接入成长：武器等级倍率 + 武器攻击加成（M2）。
# 刻意不吃属性补正——钩子卡是"特殊动作"，若与步骤卡全额同级会在 0 级就把
# 力量系出身抬到 3 倍伤害，抹平 Boss 难度锚点（见 round3 评审 M2/M3 取舍）。
func _hook_damage(_card: CardData, base: int) -> int:
	var raw := base + combat.weapon_service.total_attack_bonus(combat.run)
	var scaled: int = maxi(0, int(round(float(raw) * combat.weapon_service.weapon_multiplier(combat.run))))
	return scaled + combat.run.player_strength


func _run_hook(card: CardData) -> void:
	var hook_id := card.hook_id
	match hook_id:
		"heater_shield":
			combat.gain_block(8)
			if _enemy_attacking():
				combat.ember += 1
				combat.combat_log("盾面稳住冲击，返还 1 集中。")
		"buckler":
			combat.gain_block(5)
			if _enemy_attacking():
				# M11：统一走姿态结算（可正常触发崩解，不再产生负姿态黑箱）
				combat.deal_enemy_damage(0, 4)
				combat.combat_log("小圆盾架开武器。")
		"longbow":
			combat.deal_enemy_damage(_hook_damage(card, 5), 1)
			if int(combat.enemy.block) <= 0:
				combat.draw_cards(1)
		"club":
			var club_base: int = 6
			if combat.run.hand.is_empty():
				club_base += 5
			combat.deal_enemy_damage(_hook_damage(card, club_base), 2)
		"battle_axe":
			var axe_broke: bool = combat.deal_enemy_damage(_hook_damage(card, 15), 4)
			if axe_broke:
				combat.ember += 1
		"lions_claw":
			var broke: bool = combat.deal_enemy_damage(_hook_damage(card, 14), 5)
			if broke:
				combat.draw_cards(1)
		"magic_glintblade":
			combat.deal_enemy_damage(_hook_damage(card, 8), 2)
			if combat.ember > 0:
				combat.deal_enemy_damage(_hook_damage(card, 3), 1)
		"destined_death":
			var was_alive: bool = int(combat.enemy.get("hp", 0)) > 0
			combat.deal_enemy_damage(_hook_damage(card, 25), 8)
			if was_alive and int(combat.enemy.hp) <= 0:
				combat.run.max_hp += 4
				combat.run.hp += 4
				combat.combat_log("命定之死留下空位：最大生命 +4。")
		"urgent_heal":
			combat.heal_player(5)
			if combat.run.hp < combat.run.max_hp / 2:
				combat.draw_cards(1)
		"guard_counter":
			combat.gain_block(8)
			combat.deal_enemy_damage(0, 6)
			combat.combat_log("你架开攻势，顺势压向对方架势。")
		"heavy_charge":
			combat.gain_block(6)
			combat.stance_mult_next_turn = true
			combat.combat_log("你沉腰蓄力：下回合姿态削减翻倍。")
		_:
			push_warning("Unknown card hook: %s" % hook_id)


func _enemy_attacking() -> bool:
	return combat.enemy_intent.get("kind", "") in ["attack", "attack_block", "attack_rot"]
