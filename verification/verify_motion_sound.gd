extends SceneTree

var _counts: Dictionary = {}
var _active_player: Node = null
var _active_audio: OfficeAudio = null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var audio = OfficeAudio.new()
	_active_audio = audio
	root.add_child(audio)
	var data_script: GDScript = load("res://scripts/level_data.gd")
	var world_script: GDScript = load("res://scripts/world.gd")
	var world = world_script.new()
	root.add_child(world)
	world.setup(1, [])
	var player_script: GDScript = load("res://scripts/player.gd")
	var player = player_script.new()
	_active_player = player
	player.world = world
	player.motion_sound.connect(_on_motion_sound)
	player.stumbled.connect(_on_player_stumbled)
	world.add_child(player)
	world.set_player(player)
	player.reset_at(world.spawn_position)
	for frame in range(10):
		await physics_frame

	player.reset_at(Vector2(5800.0, 600.0))
	var gait_state: Dictionary = {}
	Input.action_press("move_right")
	for frame in range(60):
		await physics_frame
		if frame == 44:
			gait_state = player.anim_state.duplicate(true)
	Input.action_release("move_right")
	var footstep_count: int = int(_counts.get("footstep", 0))
	var footstep_rate_valid: bool = footstep_count >= 2 and footstep_count <= 4
	var run_end_position: Vector2 = player.position

	Input.action_press("jump")
	for frame in range(32):
		await physics_frame
	Input.action_release("jump")
	var jump_state: Dictionary = player.anim_state.duplicate(true)
	for frame in range(90):
		await physics_frame
		if player.is_on_floor():
			break
	var landing_state: Dictionary = player.anim_state.duplicate(true)

	Input.action_press("move_left")
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	var dash_state: Dictionary = player.anim_state.duplicate(true)
	Input.action_release("dash")
	for frame in range(12):
		await physics_frame
	Input.action_release("move_left")
	Input.action_press("brake")
	for frame in range(18):
		await physics_frame
	Input.action_release("brake")
	var brake_state: Dictionary = player.anim_state.duplicate(true)
	for frame in range(5):
		await physics_frame
	player.knock(player.position + Vector2(-80.0, 0.0))
	await physics_frame
	var stumble_state: Dictionary = player.anim_state.duplicate(true)

	var counts_before_pause: Dictionary = _counts.duplicate(true)
	var paused_visual_clock: float = float(player.anim_state.get("visual_clock", 0.0))
	var paused_gait_phase: float = float(player.anim_state.get("gait_phase", 0.0))
	player.simulation_enabled = false
	Input.action_press("move_right")
	Input.action_press("jump")
	Input.action_press("dash")
	Input.action_press("brake")
	for frame in range(20):
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("brake")
	var pause_silent: bool = _counts == counts_before_pause
	var pause_visual_frozen: bool = is_equal_approx(float(player.anim_state.get("visual_clock", -1.0)), paused_visual_clock) and is_equal_approx(float(player.anim_state.get("gait_phase", -1.0)), paused_gait_phase)
	player.simulation_enabled = true

	player.reset_at(Vector2(1140.0, 600.0))
	var reached_tool: bool = player.position.distance_to(Vector2(1220.0, 600.0)) <= 112.0
	player.interact()
	var mounted_chair: bool = str(player.held) == "chair"
	var footsteps_before_tool: int = int(_counts.get("footstep", 0))
	Input.action_press("move_right")
	for frame in range(36):
		await physics_frame
	Input.action_release("move_right")
	var footsteps_during_tool: int = int(_counts.get("footstep", 0)) - footsteps_before_tool
	var sample_keys: Array = audio.sounds.keys()
	sample_keys.sort()
	var report: Dictionary = {
		"passed": footstep_rate_valid and int(_counts.get("jump", 0)) == 1 and int(_counts.get("dash", 0)) == 1 and int(_counts.get("brake", 0)) == 1 and pause_silent and reached_tool and mounted_chair and footsteps_during_tool == 0 and sample_keys.has("footstep") and sample_keys.has("brake") and sample_keys.has("jump") and sample_keys.has("dash"),
		"motion_sound_counts": _counts,
		"footstep_probe_frames": 60,
		"footstep_rate_valid": footstep_rate_valid,
		"pause_silent": pause_silent,
		"tool_in_interaction_range": reached_tool,
		"held_tool": str(player.held),
		"footsteps_during_tool": footsteps_during_tool,
		"pause_visual_frozen": pause_visual_frozen,
		"run_end_position": [run_end_position.x, run_end_position.y],
		"animation_states": {"gait": gait_state, "jump": jump_state, "landing": landing_state, "dash": dash_state, "brake": brake_state, "stumble": stumble_state},
		"audio_sample_keys": sample_keys
	}
	var animation_checks: Dictionary = {
		"running_pose_active": float(gait_state.get("gait_amount", 0.0)) > 0.7 and float(gait_state.get("gait_phase", 0.0)) > 0.0,
		"jump_pose_active": bool(jump_state.get("airborne", false)) and float(jump_state.get("jump_age", -1.0)) >= 0.0,
		"landing_pose_active": float(landing_state.get("land_age", -1.0)) >= 0.0 and float(landing_state.get("landing_amount", 0.0)) > 0.0,
		"dash_pose_active": float(dash_state.get("dash_age", -1.0)) >= 0.0,
		"brake_pose_active": float(brake_state.get("brake_age", -1.0)) >= 0.0,
		"stumble_pose_active": float(stumble_state.get("stumble_age", -1.0)) >= 0.0 and int(_counts.get("stumble", 0)) == 1,
		"pause_visual_frozen": pause_visual_frozen
	}
	report["animation_checks"] = animation_checks
	report["passed"] = bool(report.get("passed", false)) and int(_counts.get("land", 0)) == 1 and bool(animation_checks.get("running_pose_active", false)) and bool(animation_checks.get("jump_pose_active", false)) and bool(animation_checks.get("landing_pose_active", false)) and bool(animation_checks.get("dash_pose_active", false)) and bool(animation_checks.get("brake_pose_active", false)) and bool(animation_checks.get("stumble_pose_active", false)) and bool(animation_checks.get("pause_visual_frozen", false)) and sample_keys.has("land") and sample_keys.has("hit")
	var output: FileAccess = FileAccess.open("res://verification/motion_sound_report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
	print("MOTION_SOUND_REPORT " + JSON.stringify(report))
	world.set_player(null)
	player.world = null
	world.queue_free()
	audio.queue_free()
	player = null
	_active_player = null
	_active_audio = null
	world = null
	audio = null
	await process_frame
	await process_frame
	quit(0 if bool(report.get("passed", false)) else 1)

func _on_motion_sound(kind: String) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1

func _on_player_stumbled() -> void:
	_counts["stumble"] = int(_counts.get("stumble", 0)) + 1
	if is_instance_valid(_active_audio):
		_active_audio.play("hit")
