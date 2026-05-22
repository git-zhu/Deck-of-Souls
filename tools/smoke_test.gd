extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var origins: Array[String] = ["vagabond", "samurai", "astrologer", "prophet", "warrior", "wretch"]
	for origin_id in origins:
		var scene: PackedScene = load("res://scenes/Main.tscn")
		var main: Control = scene.instantiate() as Control
		root.add_child(main)
		await process_frame

		main.call("_start_run", origin_id)
		await process_frame

		var starting_deck_size: int = (main.get("deck") as Array).size()
		main.set("hp", 10)
		main.call("_visit_grace")
		await process_frame
		if int(main.get("hp")) <= 10:
			push_error("Grace did not heal for origin %s" % origin_id)
			quit(1)
			return
		if (main.get("deck") as Array).size() != starting_deck_size:
			push_error("Grace changed deck size unexpectedly for origin %s" % origin_id)
			quit(1)
			return
		main.call("_show_deck_view")
		await process_frame

		main.call("_choose_map_option", {"kind": "combat", "enemy": "葛瑞克士兵"})
		await process_frame

		main.call("_play_card", 0)
		await process_frame

		(main.get("combat") as Object).call("end_player_turn")
		await process_frame

		main.call("_render_combat")
		await process_frame
		var viewport_width: float = 1280.0
		var enemy_panel: Control = main.get("enemy_panel") as Control
		var hand_row: Control = main.get("hand_row") as Control
		if enemy_panel.global_position.x + enemy_panel.size.x > viewport_width + 1.0:
			push_error("Enemy panel exceeds viewport for origin %s" % origin_id)
			quit(1)
			return
		if hand_row.size.y > 210.0:
			push_error("Hand row is too tall for origin %s" % origin_id)
			quit(1)
			return

		main.queue_free()
		await process_frame

	print("Smoke test passed")
	quit()
