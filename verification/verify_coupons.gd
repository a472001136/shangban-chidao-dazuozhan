extends SceneTree

var _collected_ids: Array[int] = []
var _collected_positions: Array[Dictionary] = []
var _active_player: CharacterBody2D = null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var data_script = load("res://scripts/level_data.gd")
	var world_script = load("res://scripts/world.gd")
	var player_script = load("res://scripts/player.gd")
	var level_reports: Array[Dictionary] = []
	for index in range(1, 6):
		Input.action_release("move_right")
		Input.action_release("jump")
		Input.action_release("use_tool")
		_collected_ids.clear()
		_collected_positions.clear()
		var config: Dictionary = data_script.get_level(index)
		var coupons: Array = config.get("coupons", [])
		var world = world_script.new()
		root.add_child(world)
		world.hide()
		world.setup(index, [])
		world.collected.connect(_on_coupon_collected)
		var player = player_script.new()
		_active_player = player
		player.world = world
		world.add_child(player)
		world.set_player(player)
		player.reset_at(world.spawn_position)
		for frame in range(10):
			await physics_frame
		Input.action_press("move_right")
		var jump_hold_ticks: int = 0
		var jump_release_ticks: int = 0
		var recovery_used: bool = false
		var reached_goal: bool = false
		var frame_count: int = 0
		var last_position: Vector2 = player.position
		var closest: Dictionary = {}
		var route_stage: int = 0
		var landing_evidence: Array[Dictionary] = []
		for frame in range(int(float(config.get("limit", 60.0)) * 60.0)):
			Input.action_press("move_right")
			if index == 2:
				if route_stage == 0 and player.position.x >= 5800.0:
					route_stage = 1
					jump_hold_ticks = 0
					jump_release_ticks = 0
				if route_stage == 1:
					if player.position.x >= 5810.0:
						Input.action_release("move_right")
					if player.is_on_floor() and player.position.x >= 5800.0 and player.position.x < 6000.0:
						route_stage = 2
						jump_hold_ticks = 32
				if route_stage == 2 and jump_hold_ticks == 0 and jump_release_ticks == 0:
					route_stage = 3
				if route_stage == 3 and player.is_on_floor() and player.position.y <= 500.0 and player.position.x >= 6010.0:
					landing_evidence.append({"platform_x": 6030.0, "top_y": 480.0, "position": [player.position.x, player.position.y], "on_floor": true})
					route_stage = 4
					jump_hold_ticks = 0
					jump_release_ticks = 0
			elif index == 4:
				if route_stage == 0 and player.position.x >= 6650.0:
					route_stage = 1
					jump_hold_ticks = 0
					jump_release_ticks = 0
				if route_stage == 1:
					if player.position.x >= 6670.0:
						Input.action_release("move_right")
					if player.is_on_floor() and player.position.x >= 6650.0 and player.position.x < 6860.0:
						route_stage = 2
						jump_hold_ticks = 32
				if route_stage == 2 and jump_hold_ticks == 0 and jump_release_ticks == 0:
					route_stage = 3
				if route_stage == 3 and player.is_on_floor() and player.position.y <= 500.0 and player.position.x >= 6860.0:
					landing_evidence.append({"platform_x": 6880.0, "top_y": 480.0, "position": [player.position.x, player.position.y], "on_floor": true})
					route_stage = 4
					jump_hold_ticks = 0
					jump_release_ticks = 0
			elif index == 5:
				if route_stage == 0 and player.position.x >= 7500.0:
					route_stage = 1
					jump_hold_ticks = 0
					jump_release_ticks = 0
				if route_stage == 1:
					if player.position.x >= 7560.0:
						Input.action_release("move_right")
					if player.is_on_floor() and player.position.x >= 7560.0 and player.position.x < 7720.0:
						route_stage = 2
						jump_hold_ticks = 32
				if route_stage == 2 and jump_hold_ticks == 0 and jump_release_ticks == 0:
					route_stage = 3
				if route_stage == 3 and player.is_on_floor() and player.position.y <= 490.0 and player.position.x >= 7720.0 and player.position.x < 8020.0:
					landing_evidence.append({"platform_x": 7740.0, "top_y": 480.0, "position": [player.position.x, player.position.y], "on_floor": true})
					route_stage = 4
					jump_hold_ticks = 0
					jump_release_ticks = 0
				if route_stage == 4:
					if player.position.x >= 7880.0:
						Input.action_release("move_right")
					if player.is_on_floor() and player.position.x >= 7860.0:
						route_stage = 5
						jump_hold_ticks = 32
				if route_stage == 5 and jump_hold_ticks == 0 and jump_release_ticks == 0:
					route_stage = 6
				if route_stage == 6 and player.is_on_floor() and player.position.y <= 430.0 and player.position.x >= 8110.0:
					landing_evidence.append({"platform_x": 8130.0, "top_y": 414.0, "position": [player.position.x, player.position.y], "on_floor": true})
					route_stage = 7
					jump_hold_ticks = 0
					jump_release_ticks = 0
			if index == 5 and route_stage == 7 and _collected_ids.has(2):
				route_stage = 8
			var controlled_jump: bool = (index == 2 and route_stage == 2) or (index == 4 and route_stage == 2) or (index == 5 and (route_stage == 2 or route_stage == 5))
			var waiting_for_landing: bool = (index == 2 and route_stage in [1, 3]) or (index == 4 and route_stage in [1, 3]) or (index == 5 and route_stage in [1, 3, 4, 6, 7])
			if controlled_jump or not waiting_for_landing:
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
			else:
				Input.action_release("jump")
				jump_hold_ticks = 0
				jump_release_ticks = 0
			await physics_frame
			frame_count += 1
			for coupon in coupons:
				var coupon_id: int = int(coupon.get("id", -1))
				var coupon_position: Vector2 = coupon.get("pos", Vector2.ZERO)
				var dx: float = absf(player.position.x - coupon_position.x)
				var dy: float = absf(player.position.y - coupon_position.y)
				var score: float = dx / 54.0 + dy / 68.0
				var previous: Dictionary = closest.get(coupon_id, {})
				if previous.is_empty() or score < float(previous.get("score", INF)):
					closest[coupon_id] = {"score": score, "position": [player.position.x, player.position.y], "dx": dx, "dy": dy}
			if absf(player.position.x - last_position.x) > 80.0:
				recovery_used = true
				break
			last_position = player.position
			if world.goal_reachable(player.position):
				reached_goal = true
				break
		Input.action_release("move_right")
		Input.action_release("jump")
		var coupon_reports: Array[Dictionary] = []
		for coupon in coupons:
			var coupon_id: int = int(coupon.get("id", -1))
			coupon_reports.append({
				"id": coupon_id,
				"target": [coupon.get("pos", Vector2.ZERO).x, coupon.get("pos", Vector2.ZERO).y],
				"collected": _collected_ids.has(coupon_id),
				"collected_at": _position_for_coupon(coupon_id),
			"nearest": closest.get(coupon_id, {})
			})
		var route_method: String = "从出生点持续向右，连续物理跳跃；无道具、冲刺或恢复传送"
		if index in [2, 4, 5]:
			route_method = "从出生点持续跑跳，在券台前定点满跳并确认落台；无道具、冲刺或恢复传送"
		var level_report: Dictionary = {
			"level": index,
			"day": str(config.get("day", "")),
			"method": route_method,
			"seconds": frame_count / 60.0,
			"target_stage": route_stage,
			"goal_reached": reached_goal,
			"recovery_used": recovery_used,
			"coupons": coupon_reports,
			"platform_landings": landing_evidence
		}
		level_reports.append(level_report)
		print("COUPON_ROUTE " + JSON.stringify(level_report))
		world.queue_free()
		await process_frame
	var all_collected: bool = true
	for level_report in level_reports:
		for coupon_report in level_report.get("coupons", []):
			all_collected = all_collected and bool(coupon_report.get("collected", false))
	var output: FileAccess = FileAccess.open("res://verification/coupon_report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"passed": all_collected, "levels": level_reports}, "\t"))
	quit(0 if all_collected else 1)

func _on_coupon_collected(coupon_id: int, _at: Vector2) -> void:
	if not _collected_ids.has(coupon_id):
		_collected_ids.append(coupon_id)
		if is_instance_valid(_active_player):
			_collected_positions.append({"id": coupon_id, "position": [_active_player.position.x, _active_player.position.y]})

func _position_for_coupon(coupon_id: int) -> Dictionary:
	for entry in _collected_positions:
		if int(entry.get("id", -1)) == coupon_id:
			return entry
	return {}
