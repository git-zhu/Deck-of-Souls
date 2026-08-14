class_name OriginScreenView
extends RefCounted

const GameTheme = preload("res://scripts/ui/GameTheme.gd")
const UiBuilders = preload("res://scripts/ui/UiBuilders.gd")
const DataRegistry = preload("res://scripts/core/DataRegistry.gd")
const OriginData = preload("res://data/OriginData.gd")

const NOTE_MUTED := Color("#b9ac94")


static func build(registry: DataRegistry, on_pick_origin: Callable) -> Control:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "选择出身"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GameTheme.TITLE_GOLD)
	wrap.add_child(title)

	var desc := Label.new()
	desc.text = "出身只决定开局属性与装备。就像本体一样，之后的牌组会在交界地中改变。"
	desc.add_theme_color_override("font_color", GameTheme.BODY_MUTED)
	wrap.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(grid)

	for id in registry.all_origin_ids():
		grid.add_child(origin_card(registry.get_origin(str(id)), str(id), on_pick_origin))

	return wrap


static func origin_card(origin: OriginData, origin_id: String, on_pick: Callable) -> PanelContainer:
	var panel := UiBuilders.panel(GameTheme.PANEL)
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var name := Label.new()
	name.text = "%s  Lv.%d" % [origin.name, origin.level]
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name)

	var stats := Label.new()
	stats.text = origin.stats
	stats.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(stats)

	var gear := Label.new()
	gear.text = origin.equipment
	gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gear)

	var note := Label.new()
	note.text = origin.note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("font_color", NOTE_MUTED)
	v.add_child(note)

	var pick := Button.new()
	pick.text = "以此出身开始"
	pick.custom_minimum_size = Vector2(0, 42)
	pick.pressed.connect(on_pick.bind(origin_id))
	v.add_child(pick)
	UiBuilders.attach_hover_anim(panel, 1.02)
	return panel
