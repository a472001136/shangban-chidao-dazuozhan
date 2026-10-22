extends SceneTree

var game: Node
var _accidents: Array[Dictionary] = []
var _accident_ids: Dictionary = {}
var _accident_kinds: Dictionary = {}
var _warning_count: int = 0
var _reports: Array[Dictionary] = []
var _dash_motion_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 2.0
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	var save_script: Script = load("res://scripts/save_store.gd") as Script
	var test_save_path: String = "res://verification/真实挑战验收存档_" + stamp + ".json"
	game.save = save_script.new(test_save_path)
	game.save.data = game.save.defaults()
	game._apply_settings()
	game.world.accident.connect(_on_accident)
	game.world.supervisor_warning.connect(_on_supervisor_warning)
	for level_index in [1, 4, 5]:
		var report: Dictionary = await _run_level(int(level_index))
		_reports.append(report)
		print("CHALLENGE " + JSON.stringify(report))
	var all_passed: bool = true
	for report in _reports:
		all_passed = all_passed and bool(report.get("passed", false))
	var report_path: String = "res://verification/other_challenge_report.json"
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify({"passed": all_passed, "routes": _reports, "method": "真实物理移动；周五逐件停稳后冲刺接触物件并长跳通过低平台；跳过高处玻璃柜；不使用位置传送或直接登记事故"}, "\t"))
		report_file.close()
		print("CHALLENGE_REPORT " + report_path)
	else:
		printerr("无法写入挑战验收报告")
	var absolute_save_path: String = ProjectSettings.globalize_path(test_save_path)
	var absolute_backup_path: String = ProjectSettings.globalize_path(test_save_path + ".bak")
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	if FileAccess.file_exists(test_save_path + ".bak"):
		DirAccess.remove_absolute(absolute_backup_path)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit(0 if all_passed and report_file != null else 1)


func _run_level(level_index: int) -> Dictionary:
	_accidents.clear()
	_accident_ids.clear()
	_accident_kinds.clear()
	_warning_count = 0
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		Input.action_release(action)
	game.call("_start_level", level_index, false)
	await _frames(4)
	var player: CharacterBody2D = game.player as CharacterBody2D
	var world: Node2D = game.world as Node2D
	var dash_sound_callback: Callable = Callable(self, "_on_player_motion_sound")
	if not player.is_connected("motion_sound", dash_sound_callback):
		player.connect("motion_sound", dash_sound_callback)
	_dash_motion_count = 0
	var level_data: Dictionary = game.get("_level")
	var targets: Array[Dictionary] = []
	var jump_platforms: Array[Dictionary] = []
	var jump_platform_started: Array[bool] = []
	if level_index == 5:
		var raw_props: Variant = level_data.get("props", [])
		if raw_props is Array:
			for prop_value in raw_props:
				if prop_value is Dictionary:
					targets.append(prop_value)
		var raw_platforms: Variant = level_data.get("platforms", [])
		if raw_platforms is Array:
			for platform_value in raw_platforms:
				if not platform_value is Dictionary:
					continue
				var platform: Dictionary = platform_value
				var platform_y: float = float(platform.get("y", 0.0))
				if platform_y >= 488.0 and platform_y <= 500.0:
					jump_platforms.append(platform)
					jump_platform_started.append(false)
	var target_index: int = 0
	var jump_hold_ticks: int = 0
	var jump_release_ticks: int = 0
	var dash_hold_ticks: int = 0
	var dash_press_count: int = 0
	var first_target_max_speed: float = 0.0
	var first_target_max_dash_seconds: float = 0.0
	var first_target_dash_motion_count: int = 0
	var frames_elapsed: int = 0
	var max_frames: int = int((float(game.get("level_limit")) + 5.0) * 60.0)
	var teleport_used: bool = false
	var previous_position: Vector2 = player.position
	Input.action_press("move_right")
	for frame in range(max_frames):
		frames_elapsed = frame + 1
		if str(game.get("state")) != "playing":
			break
		var dash_pressed_this_frame: bool = false
		if level_index == 5 and _accident_ids.size() < 8:
			while target_index < targets.size():
				var current_target: Dictionary = targets[target_index]
				var current_id: String = str(current_target.get("id", ""))
				var current_x: float = float(current_target.get("x", 0.0))
				if _accident_ids.has(current_id) or player.position.x > current_x + 130.0:
					target_index += 1
				else:
					break
			if target_index < targets.size():
				var target: Dictionary = targets[target_index]
				var target_id: String = str(target.get("id", ""))
				var target_x: float = float(target.get("x", 0.0))
				var distance_to_target: float = target_x - player.position.x
				var dash_cooldown: float = float(player.get("_dash_cooldown_seconds"))
				var dash_in_progress: bool = float(player.get("_dash_seconds")) > 0.0
				if target_id == "fri_glass_1" or dash_in_progress or dash_hold_ticks > 0:
					Input.action_release("brake")
				elif player.is_on_floor():
					if distance_to_target > 0.0 and distance_to_target <= 255.0 and dash_cooldown > 0.02:
						Input.action_press("brake")
					elif distance_to_target > 0.0 and distance_to_target <= 145.0 and dash_cooldown <= 0.02 and not _accident_ids.has(target_id) and dash_hold_ticks == 0:
						Input.action_release("brake")
						Input.action_press("dash")
						dash_pressed_this_frame = true
						dash_press_count += 1
					else:
						Input.action_release("brake")
				elif distance_to_target > 0.0 and distance_to_target <= 230.0:
					Input.action_press("brake")
				else:
					Input.action_release("brake")
			if player.is_on_floor() and jump_hold_ticks == 0 and jump_release_ticks == 0 and _accident_ids.has("fri_cooler_1"):
				for platform_index in range(jump_platforms.size()):
					if jump_platform_started[platform_index]:
						continue
					var platform: Dictionary = jump_platforms[platform_index]
					var platform_start: float = float(platform.get("x", 0.0))
					var platform_end: float = platform_start + float(platform.get("w", 240.0))
					if player.position.x >= platform_start - 170.0 and player.position.x <= platform_end:
						jump_platform_started[platform_index] = true
						jump_hold_ticks = 32
						jump_release_ticks = 3
						break
		else:
			Input.action_release("brake")
		if level_index != 5 and player.is_on_floor() and jump_hold_ticks == 0 and jump_release_ticks == 0:
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
		if dash_pressed_this_frame:
			dash_hold_ticks = 5
		var frame_displacement: float = player.position.distance_to(previous_position)
		if frame_displacement > 32.0:
			teleport_used = true
		previous_position = player.position
		if level_index == 5 and not _accident_ids.has("fri_box_1"):
			first_target_max_speed = maxf(first_target_max_speed, absf(player.velocity.x))
			first_target_max_dash_seconds = maxf(first_target_max_dash_seconds, float(player.get("_dash_seconds")))
			first_target_dash_motion_count = _dash_motion_count
		if dash_hold_ticks > 0:
			dash_hold_ticks -= 1
			if dash_hold_ticks == 0:
				Input.action_release("dash")
		if str(game.get("state")) == "playing" and bool(world.call("goal_reachable", player.position)):
			await _press_interact()
			if str(game.get("state")) == "success":
				break
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	var unique_kinds: Array = _accident_kinds.keys()
	unique_kinds.sort()
	var accident_rows: Array[Dictionary] = _accidents.duplicate(true)
	var success: bool = str(game.get("state")) == "success"
	var challenge_passed: bool = false
	var challenge_name: String = ""
	match level_index:
		1:
			challenge_name = "周一损坏物件不超过2个"
			challenge_passed = accident_rows.size() <= 2
		4:
			challenge_name = "周四全程不触发训话"
			challenge_passed = _warning_count == 0
		5:
			challenge_name = "周五触发至少8个不同事故物件"
			challenge_passed = accident_rows.size() >= 8
	var medals: Array = []
	var raw_record: Variant = game.save.call("level_record", level_index)
	if raw_record is Dictionary:
		var medal_value: Variant = raw_record.get("medals", [])
		if medal_value is Array:
			medals = medal_value
	var challenge_medal: bool = medals.size() > 2 and bool(medals[2])
	return {
		"level": level_index,
		"day": str(level_data.get("day", "")),
		"success": success,
		"reached_goal": success,
		"challenge": challenge_name,
		"challenge_passed": challenge_passed,
		"challenge_medal": challenge_medal,
		"accident_object_count": accident_rows.size(),
		"accidents": accident_rows,
		"unique_accident_kinds": unique_kinds,
		"dash_press_count": dash_press_count,
		"dash_motion_count": _dash_motion_count,
		"first_target_max_abs_speed": first_target_max_speed,
		"first_target_max_dash_seconds": first_target_max_dash_seconds,
		"first_target_dash_motion_count": first_target_dash_motion_count,
		"damage_total": int(game.get("_damage_total")),
		"warning_count": _warning_count,
		"elapsed_seconds": float(frames_elapsed) / 60.0,
		"finish_state": str(game.get("state")),
		"position": [player.position.x, player.position.y],
		"goal": [world.get("goal_position").x, world.get("goal_position").y],
		"teleport_used": teleport_used,
		"passed": success and challenge_passed and challenge_medal and not teleport_used
	}


func _on_accident(id: String, kind: String, cost: int, at: Vector2) -> void:
	if _accident_ids.has(id):
		return
	_accident_ids[id] = true
	_accident_kinds[kind] = true
	_accidents.append({"id": id, "kind": kind, "cost": cost, "position": [at.x, at.y]})


func _on_supervisor_warning() -> void:
	_warning_count += 1


func _on_player_motion_sound(kind: String) -> void:
	if kind == "dash":
		_dash_motion_count += 1


func _press_interact() -> void:
	Input.parse_input_event(_make_key_event(true))
	await physics_frame
	Input.parse_input_event(_make_key_event(false))
	await physics_frame


func _make_key_event(pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = pressed
	return event


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
