extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	game.save = load("res://scripts/save_store.gd").new("D:/ai/youxitest/verification/便携通勤_" + stamp + ".json")
	game._apply_settings()
	game._start_level(1,false)
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/ai/youxitest/verification/爽感便携开场.png")
	var ready: bool = game.ui._context.tactical and game.ui._hud_labels.has("combo") and game._flow_rank(true) == "C"
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(3)
	Input.action_release("dash")
	Input.action_press("jump")
	await _frames(16)
	Input.action_release("jump")
	await _frames(36)
	Input.action_release("move_right")
	var moved: bool = game._flow_all_types.has("vault") and game._chaos_score > 0 and game.player.position.x > 500.0
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/ai/youxitest/verification/爽感便携动作.png")
	print("PORTABLE_FLOW ", {"ready": ready, "actual_motion": moved, "score": game._chaos_score, "types": game._flow_all_types})
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if ready and moved else 1)
