extends SceneTree
## host 级端到端：RunFlowController.show_map 的死亡回响注入 + 地图碎片购买全流程

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const RunFlowController = preload("res://scripts/core/RunFlowController.gd")
const ProfileService = preload("res://scripts/core/ProfileService.gd")


class TestHost extends Node:
	var registry
	var run_state
	var rng
	var map_gen
	var entered_map: Control = null

	func _enter_map_layer(content: Control) -> void:
		entered_map = content


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	var registry := DataRegistry.new()
	registry.load_all()

	# 上一局死在第 0 层（100 卢恩 → 50 回响）
	ProfileService.record_death(100, 0, "vagabond")

	var host := TestHost.new()
	root.add_child(host)
	host.registry = registry
	host.run_state = RunState.new()
	host.run_state.reset_for_origin(registry.get_origin("vagabond"), 4242)
	host.rng = RandomNumberGenerator.new()
	host.rng.seed = 4242
	host.map_gen = MapGenerator.new()
	host.run_state.souls = 80
	var flow := RunFlowController.new(host)

	# ── 死亡回响事件应注入到死亡层的地图 ──
	flow.show_map()
	if host.entered_map == null:
		_fail("show_map 应渲染地图层")
		return
	if not _label_contains(host.entered_map, "上一局的痕迹"):
		_fail("死亡层地图应注入「上一局的痕迹」事件卡")
		return
	print("E2E echo injection OK")

	# ── 地图碎片：预览生成 + 购买 + 刷新展示 ──
	if host.run_state.next_floor_preview.is_empty():
		_fail("show_map 应生成下一层预览")
		return
	if host.run_state.map_fragment_revealed:
		_fail("进入地图时碎片应为未揭示状态")
		return
	var frag_btn := _find_button_with(host.entered_map, "购买地图碎片")
	if frag_btn == null or frag_btn.disabled:
		_fail("卢恩足够时应出现可购买的地图碎片按钮")
		return
	frag_btn.pressed.emit()
	if host.run_state.souls != 30 or not host.run_state.map_fragment_revealed:
		_fail("购买碎片应扣 50 卢恩并标记揭示")
		return
	# on_fragment 回调 = show_map：地图应重建并展示预览文本
	if not _label_contains(host.entered_map, "地图碎片（下一层）"):
		_fail("购买后地图应展示下一层预览")
		return
	print("E2E map fragment flow OK")

	# ── 非死亡层：无回响卡 ──
	ProfileService.record_death(100, 7, "vagabond")  # 回响记在第 7 层
	flow.show_map()  # 当前仍在第 0 层
	if _label_contains(host.entered_map, "上一局的痕迹"):
		_fail("非死亡层不应出现回响事件")
		return
	print("E2E echo floor gate OK")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileService.PROFILE_PATH))
	print("run_flow_host_test: OK")
	quit()


func _label_contains(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	if node is Button and (node as Button).text.contains(needle):
		return true
	for child in node.get_children():
		if _label_contains(child, needle):
			return true
	return false


func _find_button_with(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.contains(needle):
		return node
	for child in node.get_children():
		var found := _find_button_with(child, needle)
		if found != null:
			return found
	return null


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
