extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/" + name + ".png")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	root.size = Vector2i(960, 540)
	await _capture("title_960")
	game._start_level(5, true)
	game._begin_play()
	for frame in range(30):
		await physics_frame
	print("DISPLAY_PLAYER ", game.player.position, " valid=", is_instance_valid(game.player))
	await _capture("gameplay_960")
	game._open_pause()
	game._open_settings()
	await _capture("settings_960")
	root.size = Vector2i(1100, 800)
	game._open_title()
	await _capture("title_tall")
	print("DISPLAY_CAPTURE_COMPLETE")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
