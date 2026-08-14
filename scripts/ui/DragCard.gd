class_name DragCard
extends Button
## 可拖拽手牌：拖到敌人/战斗区域打出；点击同样可打出（回退）。
## 数据结构：drag payload = {"card_index": int, "target_id": String}
##   target_id 预留多敌人目标：当前单敌人为 ""（自动打到唯一敌人）；未来可传 enemy_0/enemy_1。

var card_index := 0
var on_play: Callable
var on_drag_start: Callable


func setup(p_index: int, p_on_play: Callable) -> void:
	card_index = p_index
	on_play = p_on_play


func is_drag_data_supported() -> bool:
	# 供测试/逻辑判断：当前牌是否可被拖拽（未禁用即支持）
	return not disabled


func make_drag_payload() -> Dictionary:
	# 出牌 payload：卡 index + 目标 id（当前单敌人 ""；未来多敌人传 enemy_id）
	return {"card_index": card_index, "target_id": ""}


func _get_drag_data(at_position: Vector2) -> Variant:
	# 不可打出的牌不响应拖拽
	if disabled:
		return null
	# 拖拽预览（半透明卡样）
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(96, 124)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.2, 0.18, 0.15, 0.85)
	pstyle.border_color = Color(0.9, 0.78, 0.42, 1.0)
	pstyle.set_border_width_all(2)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	preview.add_theme_stylebox_override("panel", pstyle)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	preview.add_child(label)
	set_drag_preview(preview)
	if on_drag_start.is_valid():
		on_drag_start.call(card_index)
	# payload：卡 index + 目标（当前单敌人 ""，未来多敌人传目标 id）
	return {"card_index": card_index, "target_id": ""}
