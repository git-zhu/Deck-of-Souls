class_name FloatingText
extends Label

# 战斗飘字：上浮 + 淡出（伤害/回复/护甲提示），艾尔登法环风金白配色。

const GameTheme = preload("res://scripts/ui/GameTheme.gd")


static func spawn(parent: Control, text: String, at_global: Vector2, color: Color = GameTheme.GOLD) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 100
	parent.add_child(label)
	label.global_position = at_global - label.size * 0.5
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", at_global + Vector2(0, -46), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)
