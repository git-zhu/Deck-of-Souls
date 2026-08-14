class_name WeaponService
extends RefCounted
## 武器服务：加载武器数据、查询武器等级与加成。

const WeaponData = preload("res://data/WeaponData.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")

var _weapons: Dictionary = {}  # id -> WeaponData


func load_from_registry(registry: DataRegistry) -> void:
	_weapons.clear()
	for wid in registry.weapon_ids():
		var w := registry.get_weapon(str(wid)) as WeaponData
		if w != null:
			_weapons[w.id] = w


func get_weapon(id: String) -> WeaponData:
	return _weapons.get(id) as WeaponData


func equipped_weapons(run: RunState) -> Array:
	# 返回当前装备的武器数据列表
	var out: Array = []
	for wid in run.weapons:
		var w := get_weapon(str(wid))
		if w != null:
			out.append(w)
	return out


# 最高等级武器：作为伤害倍率来源（法环式：武器等级放大该系伤害）
func max_weapon_level(run: RunState) -> int:
	var max_lv := 0
	for w in equipped_weapons(run):
		var wd := w as WeaponData
		if wd != null and wd.level > max_lv:
			max_lv = wd.level
	return max_lv


# 法环式武器倍率：1 + 0.1 × 最高武器等级（+10 级 → +100% 基础伤害）
func weapon_multiplier(run: RunState) -> float:
	return 1.0 + 0.1 * float(max_weapon_level(run))


func total_attack_bonus(run: RunState) -> int:
	var total := 0
	for w in equipped_weapons(run):
		var wd := w as WeaponData
		if wd != null:
			total += wd.attack_bonus
	return total


func total_stance_bonus(run: RunState) -> int:
	var total := 0
	for w in equipped_weapons(run):
		var wd := w as WeaponData
		if wd != null:
			total += wd.stance_bonus
	return total
