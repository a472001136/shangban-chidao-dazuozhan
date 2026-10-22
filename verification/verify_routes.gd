extends SceneTree

var reports: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var data_script = load("res://scripts/level_data.gd")
	var world_script = load("res://scripts/world.gd")
	var player_script = load("res://scripts/player.gd")
	for index in range(6):
		var config: Dictionary = data_script.get_level(index)
		var world = world_script.new()
		root.add_child(world)
		world.hide()
		world.setup(index, [])
		var player = player_script.new()
		player.world = world
		world.add_child(player)
		world.set_player(player)
		player.reset_at(world.spawn_position)
		for frame in range(10):
			await physics_frame
		Input.action_press("move_right")
		var reached = false
		var recovered = false
		var tick = 0
		var jump_hold_ticks = 0
		var jump_release_ticks = 0
		var last_position: Vector2 = player.position
		for frame in range(int(config.limit * 60.0)):
			if player.is_on_floor() and jump_hold_ticks == 0 and jump_release_ticks == 0:
				jump_hold_ticks = 32
			if jump_hold_ticks > 0:
				Input.action_press("jump")
				jump_hold_ticks -= 1
				if jump_hold_ticks == 0:
					jump_release_ticks = 3
			else:
				Input.action_release("jump")
				jump_release_ticks = maxi(0, jump_release_ticks - 1)
			await physics_frame
			tick += 1
			if absf(player.position.x - last_position.x) > 80.0:
				recovered = true
				break
			last_position = player.position
			if world.goal_reachable(player.position):
				reached = true
				break
		Input.action_release("move_right")
		Input.action_release("jump")
		var report = {"level": index, "reached": reached, "recovery_used": recovered, "seconds": tick / 60.0, "position": [player.position.x, player.position.y], "goal": [world.goal_position.x, world.goal_position.y]}
		reports.append(report)
		print("ROUTE " + JSON.stringify(report))
		world.queue_free()
		await process_frame
	var all_passed = true
	for report in reports:
		all_passed = all_passed and report.reached and not report.recovery_used
	var file = FileAccess.open("res://verification/route_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": all_passed, "routes": reports, "method": "真实物理，持续向右并跳跃，不使用道具/冲刺/位置传送"}, "\t"))
	quit(0 if all_passed else 1)
