extends SceneTree

const PLAYER_SCRIPT: Script = preload("res://scripts/player.gd")
const WORLD_SCRIPT: Script = preload("res://scripts/world.gd")
const LEVEL_DATA_SCRIPT: Script = preload("res://scripts/level_data.gd")

var reports: Array[Dictionary] = []
var _active_player: CharacterBody2D = null
var _events: Array[String] = []
var _event_data: Dictionary = {}
var _last_position: Vector2 = Vector2.ZERO
var _recovery_used: bool = false
var _jump_hold_ticks: int = 0
var _jump_release_ticks: int = 0
var _highest_position_y: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_actions()
	await _verify_tuesday()
	await _verify_wednesday()
	var passed: bool = true
	for report in reports:
		passed = passed and bool(report.get("passed", false))
	var summary: Dictionary = {
		"passed": passed,
		"method": "真实物理与玩家控制输入，无位置传送",
		"challenges": reports
	}
	var file: FileAccess = FileAccess.open("res://verification/challenge_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
	print("挑战路线验收 " + JSON.stringify(summary))
	quit(0 if passed else 1)


func _add_actions() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _new_level(index: int) -> Dictionary:
	var world: Node2D = WORLD_SCRIPT.new() as Node2D
	world.name = "OfficeWorld"
	root.add_child(world)
	world.hide()
	world.call("setup", index, [])
	var player: CharacterBody2D = PLAYER_SCRIPT.new() as CharacterBody2D
	player.name = "OfficePlayer"
	player.set("world", world)
	world.add_child(player)
	world.call("set_player", player)
	player.call("reset_at", world.get("spawn_position"))
	player.set("controls_enabled", true)
	player.set("simulation_enabled", true)
	_active_player = player
	_last_position = player.position
	_recovery_used = false
	_jump_hold_ticks = 0
	_jump_release_ticks = 0
	_highest_position_y = player.position.y
	_events.clear()
	_event_data.clear()
	world.connect("challenge_event", _on_challenge_event)
	return {"world": world, "player": player}


func _on_challenge_event(kind: String) -> void:
	_events.append(kind)
	if is_instance_valid(_active_player):
		_event_data[kind] = {
			"position": [_active_player.position.x, _active_player.position.y],
			"held": str(_active_player.get("held")),
			"spray_seconds": float(_active_player.get("spray_seconds")),
			"fuel": float(_active_player.get("fuel"))
		}


func _update_jump_input(player: CharacterBody2D, enabled: bool) -> void:
	if not enabled:
		_jump_hold_ticks = 0
		_jump_release_ticks = 0
		Input.action_release("jump")
		return
	if player.is_on_floor() and _jump_hold_ticks == 0 and _jump_release_ticks == 0:
		_jump_hold_ticks = 32
	if _jump_hold_ticks > 0:
		Input.action_press("jump")
		_jump_hold_ticks -= 1
		if _jump_hold_ticks == 0:
			_jump_release_ticks = 3
	else:
		Input.action_release("jump")
		_jump_release_ticks = maxi(0, _jump_release_ticks - 1)


func _observe_position(player: CharacterBody2D) -> void:
	if player.position.distance_to(_last_position) > 80.0:
		_recovery_used = true
	_last_position = player.position
	_highest_position_y = minf(_highest_position_y, player.position.y)


func _spray_short(player: CharacterBody2D, frame_count: int) -> int:
	Input.action_release("move_right")
	Input.action_release("jump")
	_jump_hold_ticks = 0
	_jump_release_ticks = 0
	Input.action_press("brake")
	var sprayed_frames: int = 0
	for frame_index in range(frame_count):
		if float(player.get("fuel")) <= 0.0:
			break
		Input.action_press("use_tool")
		await physics_frame
		_observe_position(player)
		sprayed_frames += 1
		if _recovery_used:
			break
	Input.action_release("use_tool")
	Input.action_release("brake")
	Input.action_press("move_right")
	return sprayed_frames


func _clear_inputs() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		Input.action_release(action)
	_jump_hold_ticks = 0
	_jump_release_ticks = 0


func _move_to_x(player: CharacterBody2D, target_x: float, jump: bool, max_frames: int) -> bool:
	Input.action_press("move_right")
	for frame_index in range(max_frames):
		_update_jump_input(player, jump)
		await physics_frame
		_observe_position(player)
		if player.position.x >= target_x:
			Input.action_release("move_right")
			Input.action_release("jump")
			return true
	Input.action_release("move_right")
	Input.action_release("jump")
	return false


func _wait_until_landed(player: CharacterBody2D, max_frames: int) -> bool:
	Input.action_release("move_right")
	Input.action_release("jump")
	_jump_hold_ticks = 0
	_jump_release_ticks = 0
	for frame_index in range(max_frames):
		await physics_frame
		_observe_position(player)
		if player.is_on_floor():
			return true
	return false


func _verify_tuesday() -> void:
	var level: Dictionary = LEVEL_DATA_SCRIPT.get_level(2)
	var run_data: Dictionary = _new_level(2)
	var world: Node2D = run_data["world"]
	var player: CharacterBody2D = run_data["player"]
	for frame_index in range(10):
		await physics_frame
	var approached: bool = await _move_to_x(player, 1080.0, false, 900)
	var landed: bool = await _wait_until_landed(player, 60)
	player.call("interact")
	var mounted: bool = str(player.get("held")) == "chair"
	var reached_wall: bool = false
	if mounted:
		Input.action_press("move_right")
		for frame_index in range(1200):
			Input.action_release("jump")
			await physics_frame
			_observe_position(player)
			if _recovery_used:
				break
			if _events.has("chair_wall"):
				reached_wall = true
				break
			if player.position.x >= float(level.get("goal", Vector2.ZERO).x):
				break
	Input.action_release("move_right")
	var chair_event: Dictionary = _event_data.get("chair_wall", {})
	var ticket: Dictionary = {
		"level": "周二",
		"challenge": "chair_wall",
		"approached_tool": approached,
		"landed_for_pickup": landed,
		"mounted_chair": mounted,
		"event": chair_event,
		"recovery_used": _recovery_used,
		"passed": mounted and reached_wall and not _recovery_used and str(chair_event.get("held", "")) == "chair"
	}
	reports.append(ticket)
	_clear_inputs()
	world.queue_free()
	await process_frame


func _verify_wednesday() -> void:
	var run_data: Dictionary = _new_level(3)
	var world: Node2D = run_data["world"]
	var player: CharacterBody2D = run_data["player"]
	for frame_index in range(10):
		await physics_frame
	var approached: bool = await _move_to_x(player, 1780.0, true, 1400)
	var landed: bool = await _wait_until_landed(player, 120)
	player.call("interact")
	var picked_up: bool = str(player.get("held")) == "extinguisher"
	var reached_launch: bool = false
	var reached_balcony: bool = false
	var fan_wait_frames: int = 0
	var launch_fan_strength: float = 0.0
	var launch_spray_frames: int = 0
	var balcony_spray_frames: int = 0
	if picked_up:
		reached_launch = await _move_to_x(player, 2950.0, true, 1800)
		var launch_landed: bool = await _wait_until_landed(player, 150)
		landed = landed and launch_landed
		if landed:
			for wait_index in range(240):
				var fan_surface: Dictionary = world.call("surface_at", Vector2(3100.0, 600.0))
				if float(fan_surface.get("fan", 0.0)) > 0.0:
					launch_fan_strength = float(fan_surface.get("fan", 0.0))
					break
				await physics_frame
				_observe_position(player)
				fan_wait_frames += 1
			_last_position = player.position
			Input.action_press("move_right")
			for frame_index in range(900):
				_update_jump_input(player, true)
				if launch_spray_frames < 18 and float(player.get("fuel")) > 0.0:
					Input.action_press("use_tool")
					launch_spray_frames += 1
				else:
					Input.action_release("use_tool")
				await physics_frame
				_observe_position(player)
				if _recovery_used:
					break
				if _events.has("balcony"):
					reached_balcony = true
					if balcony_spray_frames == 0:
						balcony_spray_frames = await _spray_short(player, 18)
					break
				if balcony_spray_frames == 0 and player.position.x >= 5100.0 and player.position.y <= 424.0 and float(player.get("fuel")) > 0.0:
					balcony_spray_frames = await _spray_short(player, 18)
					if _recovery_used:
						break
				if player.position.x >= 6800.0:
					break
	Input.action_release("move_right")
	var balcony_event: Dictionary = _event_data.get("balcony", {})
	var used_extinguisher: bool = float(balcony_event.get("spray_seconds", 0.0)) >= 0.25 and float(balcony_event.get("fuel", 1.0)) < 1.0
	var balcony_position: Array = balcony_event.get("position", [0.0, 0.0])
	var ticket: Dictionary = {
		"level": "周三",
		"challenge": "balcony",
		"approached_tool": approached,
		"landed_for_pickup": landed,
		"picked_up_extinguisher": picked_up,
		"reached_launch": reached_launch,
		"launch_spray_frames": launch_spray_frames,
		"balcony_spray_frames": balcony_spray_frames,
		"final_position": [player.position.x, player.position.y],
		"final_velocity": [player.velocity.x, player.velocity.y],
		"highest_position_y": _highest_position_y,
		"spray_seconds": float(player.get("spray_seconds")),
		"fuel_remaining": float(player.get("fuel")),
		"launch_fan_strength": launch_fan_strength,
		"fan_wait_frames": fan_wait_frames,
		"event": balcony_event,
		"balcony_position": balcony_position,
		"actual_spray_used": used_extinguisher,
		"recovery_used": _recovery_used,
		"passed": picked_up and reached_launch and launch_fan_strength > 0.0 and reached_balcony and used_extinguisher and balcony_spray_frames >= 18 and not _recovery_used and str(balcony_event.get("held", "")) == "extinguisher"
	}
	reports.append(ticket)
	_clear_inputs()
	world.queue_free()
	await process_frame
