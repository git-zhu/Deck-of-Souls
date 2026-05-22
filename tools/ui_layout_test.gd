extends SceneTree

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")


func _initialize() -> void:
	var event_meta := GameTheme.map_kind_meta("event")
	if str(event_meta.get("label", "")) != "事件":
		_fail("event map_kind_meta label")
		return

	if GameTheme.intent_color("attack") != Color("#e07a6a"):
		_fail("attack intent color")
		return

	var card := UiBuilders.map_choice_card(
		{"kind": "combat", "title": "测试遭遇", "body": "正文"},
		func(): pass
	)
	if not _tree_has_label_text(card, "战斗"):
		_fail("map_choice_card missing kind badge")
		return
	card.queue_free()

	print("ui_layout_test: OK")
	quit()


func _tree_has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _tree_has_label_text(child, text):
			return true
	return false


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
