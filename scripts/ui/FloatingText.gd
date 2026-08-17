class_name FloatingText
extends Label

# 战斗飘字：上浮 + 淡出（伤害/回复/护甲提示），艾尔登法环风金白配色。

const GameTheme = preload("res://scripts/ui/GameTheme.gd")


static func spawn(parent: Control, text: String, at_global: Vector2, color: Color = GameTheme.GOLD, font_size: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	# 入树后再取实际尺寸 → pivot/中心对齐准确（入树前 size 为 0）
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.6, 0.6)
	label.global_position = at_global - label.size * 0.5
	var tw := label.create_tween()
	tw.set_parallel(true)
	# 弹入（overshoot 缩放）+ 上浮 + 淡出
	tw.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "global_position", at_global + Vector2(0, -46), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


# 回合横幅：屏幕中央大号文字，弹入 → 停留 → 淡出（回合推进提示）
static func spawn_banner(parent: Control, text: String, color: Color = GameTheme.GOLD) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color(1, 1, 1, 0)
	parent.add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	# 居中于父层（战斗层为全屏 Control）；略偏上避开手牌区
	var host_size: Vector2 = parent.size if parent.size.x > 0 else Vector2(1280, 720)
	var center := host_size * 0.5 + Vector2(0, -40)
	label.position = center - label.size * 0.5
	label.scale = Vector2(1.5, 1.5)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, 0.12)
	tw.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.75)
	tw.chain().tween_callback(label.queue_free)
