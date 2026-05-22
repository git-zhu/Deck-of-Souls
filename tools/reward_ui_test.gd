extends SceneTree

const RewardLayerViews = preload("res://scripts/ui/RewardLayerViews.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const RunState = preload("res://scripts/core/RunState.gd")
const MerchantService = preload("res://scripts/core/MerchantService.gd")
const RelicService = preload("res://scripts/core/RelicService.gd")
const GraceOptionData = preload("res://data/GraceOptionData.gd")


func _initialize() -> void:
	var continue_root := RewardLayerViews.build_centered_continue(
		"测试结果",
		"正文",
		"继续",
		func(): pass
	)
	if not _tree_has_button_text(continue_root, "继续"):
		_fail("build_centered_continue missing continue button")
		return
	continue_root.queue_free()

	var registry := DataRegistry.new()
	registry.load_all()
	var run_state := RunState.new()
	var merchant_service := MerchantService.new()
	merchant_service.load_from_registry(registry)

	var merchant_root := RewardLayerViews.build_merchant_screen(
		[],
		[],
		0,
		"",
		100,
		merchant_service,
		run_state,
		func(_o, _i): pass,
		func(): pass
	)
	if not _tree_has_label_text(merchant_root, "商人咖列"):
		_fail("build_merchant_screen missing title")
		return
	if not _tree_has_button_text(merchant_root, "离开商店"):
		_fail("build_merchant_screen missing leave button")
		return
	merchant_root.queue_free()

	var option := GraceOptionData.new()
	option.title = "测试赐福"
	option.body = "说明"
	var grace_card := RewardLayerViews.grace_choice_card(option, func(_o): pass)
	if not _tree_has_button_text(grace_card, "选择"):
		_fail("grace_choice_card missing pick button")
		return
	grace_card.queue_free()

	print("reward_ui_test: OK")
	quit()


func _tree_has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _tree_has_label_text(child, text):
			return true
	return false


func _tree_has_button_text(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text:
		return true
	for child in node.get_children():
		if _tree_has_button_text(child, text):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
