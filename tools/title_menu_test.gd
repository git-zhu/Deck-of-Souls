extends SceneTree

const TitleScreenView = preload("res://scripts/ui/TitleScreenView.gd")


func _initialize() -> void:
	var no_save := TitleScreenView.build(false, Callable(), Callable(), Callable())
	var continue_disabled := _find_continue_button(no_save)
	if continue_disabled == null:
		_fail("continue button missing (no save)")
		return
	if not continue_disabled.disabled:
		_fail("continue should be disabled when no save")
		return

	var with_save := TitleScreenView.build(true, Callable(), Callable(), Callable())
	var continue_enabled := _find_continue_button(with_save)
	if continue_enabled == null:
		_fail("continue button missing (has save)")
		return
	if continue_enabled.disabled:
		_fail("continue should be enabled when has save")
		return

	var new_btn := _find_button_by_text(with_save, "新游戏")
	if new_btn == null:
		_fail("expected 新游戏 label when has save")
		return

	var start_btn := _find_button_by_text(no_save, "开始游戏")
	if start_btn == null:
		_fail("expected 开始游戏 label when no save")
		return

	print("title_menu_test: OK")
	quit()


func _find_continue_button(root: Control) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn != null and btn.text == "继续游戏":
			return btn
	return null


func _find_button_by_text(root: Control, label_text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn != null and btn.text == label_text:
			return btn
	return null


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
