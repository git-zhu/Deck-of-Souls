class_name ProfileService
extends RefCounted
## 跨局档案：胜场 / NG+ 解锁 / 誓约解锁 / 记忆货币 / 死亡回响 / 誓言挑战。
## 存储于 user://profile.json（与单局存档 run_save.json 分离）。

const RunState = preload("res://scripts/core/RunState.gd")

const PROFILE_PATH := "user://profile.json"
const MAX_NG := 7
const MAX_VOW := 5


static func default_profile() -> Dictionary:
	return {
		"victories": 0,
		"max_ng_unlocked": 0,
		"max_vow_unlocked": 0,
		"memory": 0,
		"echo": {},
		"challenges": [],
	}


static func load_profile() -> Dictionary:
	var defaults := default_profile()
	if not FileAccess.file_exists(PROFILE_PATH):
		return defaults
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return defaults
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	var d: Dictionary = parsed
	for key in defaults:
		if not d.has(key):
			d[key] = defaults[key]
	return d


static func save_profile(profile: Dictionary) -> bool:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(profile))
	return true


# 胜利结算：解锁下一级 NG+ 与誓约，记录誓言挑战达成
static func record_victory(ng_level: int, vow_level: int, challenge_flags: Array) -> Dictionary:
	var p := load_profile()
	p["victories"] = int(p.get("victories", 0)) + 1
	p["max_ng_unlocked"] = clampi(maxi(int(p.get("max_ng_unlocked", 0)), ng_level + 1), 0, MAX_NG)
	p["max_vow_unlocked"] = clampi(maxi(int(p.get("max_vow_unlocked", 0)), vow_level + 1), 0, MAX_VOW)
	var ch: Array = p.get("challenges", [])
	for flag in challenge_flags:
		if str(flag) != "" and not ch.has(str(flag)):
			ch.append(str(flag))
	p["challenges"] = ch
	save_profile(p)
	return p


# 死亡结算：一半卢恩凝为回响，记录死亡层数（下一局可夺回）
static func record_death(souls: int, floor_index: int, origin_id: String) -> void:
	var p := load_profile()
	p["echo"] = {"souls": maxi(0, souls / 2), "floor": floor_index, "origin": origin_id}
	save_profile(p)


static func claim_echo() -> Dictionary:
	var p := load_profile()
	var echo_var: Variant = p.get("echo", {})
	var echo: Dictionary = echo_var if typeof(echo_var) == TYPE_DICTIONARY else {}
	p["echo"] = {}
	save_profile(p)
	return echo


static func add_memory(amount: int) -> void:
	var p := load_profile()
	p["memory"] = maxi(0, int(p.get("memory", 0)) + amount)
	save_profile(p)


# 开局应用誓约修饰（累积生效）
static func apply_vow_start(run: RunState) -> void:
	if run == null or run.vow_level <= 0:
		return
	if run.vow_level >= 1:
		# 破损的瓶：初始圣杯瓶 −1
		run.max_flasks = maxi(1, run.max_flasks - 1)
		run.flasks = run.max_flasks
	if run.vow_level >= 5:
		# 死荫：最大生命 −20%
		run.max_hp = maxi(20, int(run.max_hp * 0.8))
		run.hp = mini(run.hp, run.max_hp)
