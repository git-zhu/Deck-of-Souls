class_name DragCard
extends Button
## 可拖拽手牌：拖到敌人/战斗区域打出；点击同样可打出（回退）。
## 数据结构：drag payload = {"card_index": int, "target_id": String}
##   target_id 预留多敌人目标：当前单敌人为 ""（自动打到唯一敌人）；未来可传 enemy_0/enemy_1。

var card_index := 0
var on_play: Callable
var on_drag_start: Callable
var _dragging := false
var _drag_btn: Button


func setup(p_index: int, p_on_play: Callable) -> void:
	card_index = p_index
	on_play = p_on_play
	_setup_hover_lift()


# StS 式悬停：拿起牌（放大 + z 提升），离开放下。
# 注意：卡片在 HBoxContainer 内，position 由容器管理——绝不 tween position（会导致下坠/错位），
# 只改 scale + z_index，用 pivot_offset 底部中心锚点实现视觉"上浮"。
# 防抽搐：放大倍率适中（避免覆盖相邻卡触发离开→进入循环）；离开延迟收起；拖拽时复位缩放。
func _setup_hover_lift() -> void:
	mouse_entered.connect(func() -> void:
		if disabled or _dragging:
			return
		_kill_hover()
		z_index = 50
		pivot_offset = Vector2(size.x * 0.5, size.y)
		var tw := create_tween()
		set_meta("_lift_tween", tw)
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	mouse_exited.connect(func() -> void:
		if _dragging:
			return
		# 延迟收起：短暂经过相邻卡边界时不立即恢复，减少抖动
		var tw := create_tween()
		tw.tween_interval(0.08)
		tw.tween_callback(func() -> void:
			_kill_hover()
			z_index = 0
			var st := create_tween()
			set_meta("_lift_tween", st)
			st.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
	)


func _kill_hover() -> void:
	if has_meta("_lift_tween"):
		var t: Tween = get_meta("_lift_tween") as Tween
		if t != null and t.is_valid():
			t.kill()


func _notification(what: int) -> void:
	# 拖拽结束（无论是否投放成功）复位拖拽标记，恢复后续悬停/点击
	if what == NOTIFICATION_DRAG_END:
		_dragging = false


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
	# 拖拽开始：复位悬停缩放（放大卡片会干扰拖拽 hit 判定），标记拖拽中
	_dragging = true
	_kill_hover()
	z_index = 0
	scale = Vector2.ONE
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
