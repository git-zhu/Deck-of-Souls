extends SceneTree

const DataRegistry = preload("res://scripts/core/DataRegistry.gd")


func _initialize() -> void:
	var registry := DataRegistry.new()
	registry.load_all()
	var origin_count := registry.all_origin_ids().size()
	if origin_count < 6:
		push_error("Expected >= 6 origins, got %d (export manifest may be stale)" % origin_count)
		quit(1)
		return
	if registry.all_card_ids().is_empty():
		push_error("No cards loaded")
		quit(1)
		return
	if registry.enemy_templates().is_empty():
		push_error("No enemies loaded")
		quit(1)
		return
	if registry.acts.is_empty():
		push_error("No acts loaded")
		quit(1)
		return
	print("export_data_load_test passed (%d origins)" % origin_count)
	quit()
