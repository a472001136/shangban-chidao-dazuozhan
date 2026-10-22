extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save.data = game.save.defaults()
	game.save.data.settings.screen_shake = false
	game._apply_settings()
	game._start_level(5, false)
	for warmup in range(60):
		await RenderingServer.frame_post_draw
	var start: int = Time.get_ticks_usec()
	var process_times: Array[float] = []
	var draw_counts: Array[int] = []
	var jump_hold: int = 0
	var jump_release: int = 0
	Input.action_press("move_right")
	for frame in range(360):
		if game.player.is_on_floor() and jump_hold == 0 and jump_release == 0:
			jump_hold = 32
		if jump_hold > 0:
			Input.action_press("jump")
			jump_hold -= 1
			if jump_hold == 0:
				jump_release = 3
		else:
			Input.action_release("jump")
			jump_release = maxi(0, jump_release - 1)
		await RenderingServer.frame_post_draw
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_counts.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	Input.action_release("move_right")
	Input.action_release("jump")
	var wall_seconds: float = float(Time.get_ticks_usec() - start) / 1000000.0
	process_times.sort()
	draw_counts.sort()
	var report: Dictionary = {"frames": 360, "wall_seconds": wall_seconds, "observed_render_fps": 360.0 / wall_seconds, "process_ms_p95": process_times[342], "draw_calls_p95": draw_counts[342], "position": [game.player.position.x, game.player.position.y], "method": "周五场景真实跑跳，图形渲染，无逐帧截图回读；固定60Hz模拟，帧率只描述本机测试"}
	var output: FileAccess = FileAccess.open("res://verification/render_performance_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("RENDER_PERFORMANCE " + JSON.stringify(report))
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit()
