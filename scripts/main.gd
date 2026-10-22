extends Node2D

const PLAYER_SCRIPT: Script = preload("res://scripts/player.gd")
const WORLD_SCRIPT: Script = preload("res://scripts/world.gd")
const LEVEL_DATA_SCRIPT: Script = preload("res://scripts/level_data.gd")
const AUDIO_SCRIPT: Script = preload("res://scripts/audio.gd")
const SAVE_SCRIPT: Script = preload("res://scripts/save_store.gd")
const UI_SCRIPT: Script = preload("res://scripts/game_ui.gd")

var world: Node2D = null
var player: CharacterBody2D = null
var camera: Camera2D = null
var ui: CanvasLayer = null
var audio: Node = null
var save: RefCounted = null

var state: String = "title"
var level_index: int = 0
var remaining: float = 60.0
var level_limit: float = 60.0
var timer_started: bool = false
var game_started: bool = false
var assist_for_run: bool = false
var result_locked: bool = false

var _level: Dictionary = {}
var _run_coupon_ids: Array[int] = []
var _saved_coupon_ids: Array[int] = []
var _accidents: Dictionary = {}
var _damage_by_kind: Dictionary = {}
var _damage_total: int = 0
var _recent_accident: String = ""
var _recent_accident_time: float = 0.0
var _current_bubble: String = ""
var _bubble_time: float = 0.0
var _hud_refresh_time: float = 0.0
var _settings_return_state: String = "title"
var _camera_shake_time: float = 0.0
var _camera_shake_strength: float = 0.0
var _camera_shake_phase: float = 0.0
var _smoke_requested: bool = false
var _capture_path: String = ""
var _chaos_score: int = 0
var _combo: int = 0
var _best_combo: int = 0
var _combo_remaining: float = 0.0
var _stunts: Dictionary = {}
var _best_moment: String = "今天暂时没有名场面"
var _best_moment_points: int = 0
var _arrival_style: String = "normal"
var _run_generation: int = 0
var _rocket_new: bool = false
var _spring_new: bool = false
var _flow_seen: Dictionary = {}
var _flow_types: Dictionary = {}
var _flow_all_types: Dictionary = {}
var _flow_furthest: Dictionary = {}
var _flow_trace: Array[String] = []
var _flow_last_kind: String = ""
var _flow_label: String = ""
var _flow_award: int = 0
var _flow_flash: float = 0.0
var _near_passes: Dictionary = {}
var _camera_lead: float = 190.0
var _moment_texture: Texture2D = null
var _moment_request: int = 0
var _flow_best_award: int = 0
var _flow_impact_age: float = 10.0


func _ready() -> void:
	_setup_input_map()
	_read_command_line()
	if _smoke_requested:
		save = SAVE_SCRIPT.new("user://验收_上班迟到大作战.json")
	else:
		save = SAVE_SCRIPT.new()
	_create_world_and_player()
	_create_support_nodes()
	_apply_settings()
	_show_screen("title")
	audio.call("set_phase", "menu", 60.0)
	if _smoke_requested:
		call_deferred("_run_smoke_test")
	elif not _capture_path.is_empty():
		call_deferred("_capture_initial_screen")


func _setup_input_map() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("dash", [KEY_SHIFT])
	_add_key_action("brake", [KEY_S, KEY_DOWN])
	_add_key_action("busy", [KEY_Q])
	_add_key_action("interact", [KEY_E])
	_add_key_action("use_tool", [KEY_F])
	_add_key_action("pause", [KEY_ESCAPE])
	_add_key_action("restart", [KEY_R])


func _add_key_action(action: String, key_codes: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key_code in key_codes:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key_code
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _read_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		var value: String = str(argument)
		if value == "--smoke-test":
			_smoke_requested = true
		elif value.begins_with("--capture="):
			_capture_path = value.trim_prefix("--capture=")


func _create_world_and_player() -> void:
	world = WORLD_SCRIPT.new()
	world.name = "OfficeWorld"
	world.call("setup", 0, [])
	add_child(world)
	player = PLAYER_SCRIPT.new()
	player.name = "OfficePlayer"
	player.set("world", world)
	world.add_child(player)
	world.call("set_player", player)
	camera = Camera2D.new()
	camera.name = "OfficeCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_bottom = 720
	player.add_child(camera)
	camera.make_current()
	world.visible = false
	world.call("set_active", false)
	player.set("simulation_enabled", false)
	player.set("controls_enabled", false)
	world.connect("accident", _on_world_accident)
	world.connect("collected", _on_world_collected)
	world.connect("challenge_event", _on_challenge_event)
	world.connect("bubble", _on_world_bubble)
	world.connect("supervisor_warning", _on_supervisor_warning)
	world.connect("stunt", _on_stunt)
	world.connect("hr_caught", _on_hr_caught)
	world.connect("hr_alert",func(): audio.call("play","warning"))
	player.connect("started", _on_player_started)
	player.connect("stumbled", _on_player_stumbled)
	player.connect("fell",func(): _finish_failure("跌出通道，本次打卡失败"))
	player.connect("tool_changed", _on_player_tool_changed)
	player.connect("motion_sound", _on_motion_sound)
	player.connect("stunt", _on_stunt)
	player.connect("flow_action", _on_flow_action)


func _create_support_nodes() -> void:
	audio = AUDIO_SCRIPT.new()
	audio.name = "OfficeAudio"
	add_child(audio)
	ui = UI_SCRIPT.new()
	ui.name = "OfficeUI"
	add_child(ui)
	ui.connect("action_requested", _on_ui_action_requested)


func _process(delta: float) -> void:
	if _bubble_time > 0.0:
		_bubble_time = maxf(0.0, _bubble_time - delta)
		if _bubble_time <= 0.0:
			_current_bubble = ""
	if state == "playing" and _recent_accident_time > 0.0:
		_recent_accident_time = maxf(0.0, _recent_accident_time - delta)
		if _recent_accident_time <= 0.0:
			_recent_accident = ""
	_hud_refresh_time -= delta
	if state == "playing" and _hud_refresh_time <= 0.0:
		_hud_refresh_time = 0.08
		_update_hud()
	_update_camera_preview()
	_update_audio_tool()
	if state == "playing" and is_instance_valid(camera):
		if _camera_shake_time > 0.0:
			_camera_shake_time = maxf(0.0, _camera_shake_time - delta)
			_camera_shake_phase += delta
			var fade: float = pow(clampf(_camera_shake_time / 0.12, 0.0, 1.0), 2.0)
			var shake_y: float = sin(_camera_shake_phase * TAU * 20.0) * _camera_shake_strength * fade
			var shake_x: float = sin(_camera_shake_phase * TAU * 29.0) * _camera_shake_strength * 0.5 * fade if bool(_level.get("tactical", false)) else 0.0
			camera.offset = Vector2(shake_x, shake_y)
		else:
			camera.offset = Vector2.ZERO
	elif state not in ["pause", "settings"] and is_instance_valid(camera):
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if state == "playing":
		_flow_impact_age += delta
		_flow_flash = maxf(0.0, _flow_flash - delta)
		if bool(_level.get("tactical", false)):
			_check_near_passes()
		_combo_remaining = maxf(0.0, _combo_remaining - delta)
		if _combo_remaining <= 0.0:
			_combo = 0
			_flow_types.clear()
			_flow_last_kind = ""
	if state == "playing" and timer_started:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			_finish_failure()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("pause"):
		_handle_escape()
		get_viewport().set_input_as_handled()
		return
	if key_event.is_action_pressed("restart"):
		if state in ["playing", "briefing", "success", "failure"]:
			_restart_current()
			get_viewport().set_input_as_handled()
		return
	if key_event.is_action_pressed("interact") and state == "playing":
		_handle_interaction()
		get_viewport().set_input_as_handled()
		return
	if key_event.physical_keycode == KEY_SPACE and state == "briefing":
		_begin_play()
		get_viewport().set_input_as_handled()


func _handle_escape() -> void:
	match state:
		"playing":
			_open_pause()
		"pause":
			_resume_game()
		"settings":
			_return_from_settings()
		"briefing":
			_begin_play()
		"success", "failure":
			_open_calendar()
		"calendar":
			_open_title()
		"album":
			_open_calendar()


func _handle_interaction() -> void:
	if not is_instance_valid(player):
		return
	var player_position: Vector2 = player.position
	if bool(world.call("goal_reachable", player_position)):
		if remaining > 0.0 and not result_locked:
			_finish_success()
		return
	player.call("interact")


func _on_ui_action_requested(action: String, value: Variant) -> void:
	match action:
		"start":
			if state == "title":
				_continue_from_title()
			elif state == "briefing":
				_begin_play()
		"calendar":
			_open_calendar()
		"album":
			_open_album()
		"level":
			_select_level(int(value))
		"resume":
			_resume_game()
		"restart":
			_restart_current()
		"settings":
			_open_settings()
		"back":
			_handle_back()
		"quit":
			get_tree().quit()
		"next":
			_go_to_next_level()
		"setting":
			_update_setting(value)
		"badge":
			_select_badge(int(value))


func _continue_from_title() -> void:
	var next_index: int = int(save.call("next_level"))
	if next_index < 0:
		_open_calendar()
	else:
		_start_level(next_index, true)


func _select_level(index: int) -> void:
	if index < 0 or index > 5:
		return
	var data: Dictionary = _save_data()
	var unlocked: int = int(data.get("unlocked", 1))
	if index > 0 and index > unlocked:
		return
	_start_level(index, true)


func _start_level(index: int, show_briefing: bool) -> void:
	_moment_texture = null
	_moment_request += 1
	_flow_best_award = 0
	_flow_impact_age = 10.0
	_flow_seen.clear()
	_flow_types.clear()
	_flow_all_types.clear()
	_flow_furthest.clear()
	_flow_trace.clear()
	_near_passes.clear()
	_flow_last_kind = ""
	_flow_label = ""
	_flow_award = 0
	_flow_flash = 0.0
	_camera_lead = 190.0
	_run_generation += 1
	_chaos_score = 0
	_combo = 0
	_best_combo = 0
	_combo_remaining = 0.0
	_stunts.clear()
	_best_moment = "今天暂时没有名场面"
	_best_moment_points = 0
	_arrival_style = "normal"
	_rocket_new = false
	_spring_new = false
	level_index = clampi(index, 0, 5)
	_level = LEVEL_DATA_SCRIPT.get_level(level_index)
	assist_for_run = bool(_settings().get("assist", false))
	level_limit = float(_level.get("limit", 60.0)) * (1.25 if assist_for_run else 1.0)
	remaining = level_limit
	timer_started = false
	game_started = false
	result_locked = false
	_run_coupon_ids.clear()
	_accidents.clear()
	_damage_by_kind.clear()
	_damage_total = 0
	_recent_accident = ""
	_recent_accident_time = 0.0
	_camera_shake_time = 0.0
	_camera_shake_strength = 0.0
	_camera_shake_phase = 0.0
	_challenge_sent_for_run = false
	_warned_this_run = false
	_current_bubble = ""
	_bubble_time = 0.0
	var saved_coupon_value: Variant = []
	if level_index > 0:
		var record: Dictionary = save.call("level_record", level_index)
		saved_coupon_value = record.get("coupons", [])
	_saved_coupon_ids.clear()
	if saved_coupon_value is Array:
		for coupon_value in saved_coupon_value:
			var coupon_id: int = int(coupon_value)
			if coupon_id >= 0 and coupon_id <= 2 and not _saved_coupon_ids.has(coupon_id):
				_saved_coupon_ids.append(coupon_id)
	world.visible = true
	world.call("set_active", false)
	world.call("setup", level_index, _saved_coupon_ids)
	world.call("set_player", player)
	player.set("world", world)
	player.call("reset_at", world.get("spawn_position"))
	player.set("playground", bool(_level.get("chaos_playground",false)))
	player.set("rocket_unlocked", bool(_save_data().get("rocket_unlocked", false)) or int(_save_data().get("unlocked",1)) >= 2)
	player.set("spring_unlocked", bool(_save_data().get("spring_unlocked", false)))
	player.set("assist", assist_for_run)
	player.set("badge", int(_save_data().get("badge", 0)))
	player.set("controls_enabled", false)
	player.set("simulation_enabled", false)
	camera.limit_right = int(world.get("bounds_width"))
	camera.position = Vector2(190.0, 0.0)
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	var tutorial_seen: bool = bool(_save_data().get("tutorial_done", false))
	var should_show_briefing: bool = show_briefing and not (level_index == 0 and tutorial_seen)
	if should_show_briefing:
		state = "briefing"
		_show_screen("briefing", {"name": str(_level.get("name", "")), "day": str(_level.get("day", "")), "notice": str(_level.get("notice", "")), "challenge": str(_level.get("challenge", ""))})
		audio.call("set_phase", "menu", level_limit)
	else:
		state = "briefing"
		_begin_play()


func _begin_play() -> void:
	if state != "briefing" and state != "playing":
		return
	state = "playing"
	game_started = true
	player.set("controls_enabled", true)
	player.set("simulation_enabled", true)
	world.call("set_active", true)
	_show_screen("hud")
	_update_hud()
	audio.call("set_phase", "playing", remaining)


func _restart_current() -> void:
	if state in ["title", "calendar", "settings"]:
		return
	_start_level(level_index, false)


func _open_title() -> void:
	state = "title"
	timer_started = false
	game_started = false
	_set_simulation(false)
	world.visible = false
	audio.call("set_phase", "menu", 60.0)
	_show_screen("title")


func _open_calendar() -> void:
	state = "calendar"
	timer_started = false
	game_started = false
	_set_simulation(false)
	world.visible = false
	audio.call("set_phase", "menu", 60.0)
	_show_screen("calendar")


func _open_pause() -> void:
	if state != "playing":
		return
	state = "pause"
	_set_simulation(false)
	audio.call("set_phase", "pause", remaining)
	_show_screen("pause")


func _open_album() -> void:
	state = "album"
	_set_simulation(false)
	world.visible = false
	audio.call("set_phase","menu",60.0)
	_show_screen("album")


func _resume_game() -> void:
	if state != "pause":
		return
	state = "playing"
	_set_simulation(true)
	audio.call("set_phase", "playing", remaining)
	_show_screen("hud")
	_update_hud()


func _open_settings() -> void:
	_settings_return_state = state
	if state == "playing":
		state = "pause"
		_set_simulation(false)
		audio.call("set_phase", "pause", remaining)
	else:
		state = "settings"
	_show_screen("settings", {"return_state": _settings_return_state})


func _return_from_settings() -> void:
	if _settings_return_state == "pause" or _settings_return_state == "playing":
		state = "pause"
		_set_simulation(false)
		_show_screen("pause")
	elif _settings_return_state == "calendar":
		_open_calendar()
	else:
		_open_title()


func _handle_back() -> void:
	if state == "settings":
		_return_from_settings()
	elif state == "pause":
		_open_calendar()
	elif state == "briefing":
		_open_calendar()
	elif state in ["success", "failure", "album"]:
		_open_calendar()
	else:
		_open_title()


func _go_to_next_level() -> void:
	if state != "success":
		return
	if level_index >= 5:
		_open_calendar()
	else:
		_start_level(level_index + 1, true)


func _update_setting(value: Variant) -> void:
	if not (value is Dictionary):
		return
	var setting: Dictionary = value
	var key: String = str(setting.get("key", ""))
	if key not in ["music_volume", "sound_volume", "screen_shake", "assist", "fullscreen"]:
		return
	var data: Dictionary = _save_data()
	var settings: Dictionary = _settings().duplicate(true)
	var next_value: Variant = setting.get("value")
	if key in ["music_volume", "sound_volume"]:
		next_value = clampf(float(next_value), 0.0, 1.0)
	else:
		next_value = bool(next_value)
	settings[key] = next_value
	data["settings"] = settings
	save.set("data", data)
	save.call("save")
	_apply_settings()


func _select_badge(index: int) -> void:
	var badge_count: int = int(save.call("unlocked_badges"))
	if index < 0 or index > badge_count:
		return
	var data: Dictionary = _save_data()
	data["badge"] = index
	save.set("data", data)
	save.call("save")
	if is_instance_valid(player):
		player.set("badge", index)
	_show_screen(state)


func _apply_settings() -> void:
	var settings: Dictionary = _settings()
	if is_instance_valid(audio):
		audio.call("set_volumes", float(settings.get("music_volume", 0.55)), float(settings.get("sound_volume", 0.8)))
	if is_instance_valid(player):
		var selected_assist: bool = bool(settings.get("assist", false))
		if game_started and state in ["playing", "pause", "settings"]:
			selected_assist = assist_for_run
		player.set("assist", selected_assist)
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _set_simulation(enabled: bool) -> void:
	if is_instance_valid(world):
		world.call("set_active", enabled)
	if is_instance_valid(player):
		player.set("controls_enabled", enabled)
		player.set("simulation_enabled", enabled)


func _on_player_started() -> void:
	if state != "playing" or timer_started:
		return
	timer_started = true
	audio.call("set_phase", "playing", remaining)


func _on_player_stumbled() -> void:
	if state == "playing":
		if bool(_level.get("tactical", false)):
			_combo_remaining = 0.0
			_combo = 0
			_flow_types.clear()
			_flow_last_kind = ""
		audio.call("play", "hit")


func _on_player_tool_changed() -> void:
	if state == "playing":
		audio.call("play", "menu")
		_update_hud()


func _on_motion_sound(kind: String) -> void:
	if is_instance_valid(audio):
		audio.call("play", kind)


func _on_world_accident(id: String, kind: String, cost: int, at: Vector2) -> void:
	if state != "playing" or _accidents.has(id):
		return
	_accidents[id] = {"kind": kind, "cost": cost}
	if bool(_level.get("tactical", false)):
		_flow_impact_age = 0.0
		_score_flow("impact_" + id, "accident", _accident_text(kind, cost).get_slice(" · ", 0), 100, at)
	else:
		_combo = _combo + 1 if _combo_remaining > 0.0 else 1
		_combo_remaining = 3.0
		_best_combo = maxi(_best_combo, _combo)
		_chaos_score += 80 + mini(_combo,8) * 25 + (50 if not _damage_by_kind.has(kind) else 0)
	_damage_total += cost
	_damage_by_kind[kind] = int(_damage_by_kind.get(kind, 0)) + cost
	_recent_accident = _accident_text(kind, cost)
	_recent_accident_time = 2.5
	_camera_shake_time = 0.16 if bool(_level.get("tactical", false)) else 0.12
	_camera_shake_phase = 0.0
	_camera_shake_strength = (5.0 if bool(_level.get("tactical", false)) else 1.8) if bool(_settings().get("screen_shake", true)) else 0.0
	if kind == "cooler":
		audio.call("play", "water")
	elif kind == "glass":
		audio.call("play", "glass")
	elif kind in ["box", "files", "printer"]:
		audio.call("play", "paper")
	else:
		audio.call("play", "hit")
	_update_hud()


func _accident_text(kind: String, cost: int) -> String:
	var label: String = "物件损坏"
	match kind:
		"files":
			label = "文件散落"
		"printer":
			label = "打印机出纸"
		"box":
			label = "纸箱散开"
		"glass":
			label = "玻璃碎裂"
		"cooler":
			label = "饮水机漏水"
		"plant":
			label = "盆栽倾倒"
		"monitor":
			label = "显示器损坏"
		"bin":
			label = "垃圾桶翻倒"
		"meeting":
			label = "早会开始巡回演出"
	return label + " · 损失 " + str(cost) + " 元"


func _on_world_collected(id: int, at: Vector2) -> void:
	if state != "playing" or _saved_coupon_ids.has(id) or _run_coupon_ids.has(id):
		return
	_run_coupon_ids.append(id)
	audio.call("play", "coupon")
	_update_hud()


func _on_challenge_event(kind: String) -> void:
	if state != "playing":
		return
	var expected: String = str(_level.get("challenge_kind", ""))
	if kind == expected:
		_challenge_sent_for_run = true


func _on_stunt(id: String, label: String, points: int) -> void:
	if state != "playing" or _stunts.has(id):
		return
	_stunts[id] = label
	if bool(_level.get("tactical", false)):
		var kind: String = "chain" if id.begins_with("chain_") else id
		if id not in ["chain_reaction", "long_flight", "powder_cover"]:
			_score_flow(id, kind, label, points, player.position)
	else:
		_chaos_score += points
	if not bool(_level.get("tactical", false)) and points > _best_moment_points:
		_best_moment_points = points
		_best_moment = label
	_current_bubble = label
	_bubble_time = 2.5
	save.call("record_discovery", maxi(1,level_index), id, label)
	audio.call("play", "coupon")
	_update_hud()


func _on_world_bubble(message: String, at: Vector2) -> void:
	_current_bubble = message
	_bubble_time = 1.35
	_update_hud()


func _on_flow_action(id: String, kind: String, label: String, points: int) -> void:
	_score_flow(id, kind, label, points, player.position)


func _score_flow(id: String, kind: String, label: String, points: int, at: Vector2) -> void:
	if state != "playing" or not bool(_level.get("tactical", false)) or _flow_seen.has(id):
		return
	_flow_seen[id] = true
	if kind in ["running_jump", "vault", "landing_dash"]:
		if at.x < float(_flow_furthest.get(kind, -200.0)) + 160.0:
			return
		_flow_furthest[kind] = at.x
	var repeated: bool = kind == _flow_last_kind and _combo_remaining > 0.0
	var same_impact: bool = _flow_impact_age < 0.12 and kind in ["chain", "chain_reaction", "water_slide", "paper_cloud"]
	if not repeated and not same_impact:
		_combo = _combo + 1 if _combo_remaining > 0.0 else 1
		var varied: bool = not _flow_types.has(kind)
		_flow_types[kind] = true
		_flow_all_types[kind] = true
		_flow_award = (points + (40 if varied else 0)) * mini(4, 1 + floori(_combo / 3.0))
		_combo_remaining = 4.0
		_flow_last_kind = kind
		var short_labels: Dictionary = {"vault":"翻越", "running_jump":"飞跃", "landing_dash":"落地冲刺", "near_miss":"擦身", "noise_lure":"诱敌", "powder_escape":"遮挡", "table_block":"挡路", "upper_route":"上层", "gate_dash":"冲门", "hr_escape":"打卡", "water_surf":"滑水", "accident":"事故", "hr_skid":"打滑"}
		_flow_trace.append(str(short_labels.get(kind, "连锁" if kind == "chain" else label)))
		if _flow_trace.size() > 5:
			_flow_trace.pop_front()
	else:
		_flow_award = maxi(10, floori(points / (2.0 if same_impact else 4.0)))
		if same_impact and kind == "chain":
			_flow_all_types[kind] = true
	_best_combo = maxi(_best_combo, _combo)
	_chaos_score += _flow_award
	_flow_label = label if not repeated or same_impact else label + " · 换个动作"
	_flow_flash = 1.1
	world.show_flow(_flow_award, at)
	if _flow_award > _flow_best_award and not result_locked:
		_flow_best_award = _flow_award
		_best_moment = label
		_moment_request += 1
		_capture_moment(_run_generation, _moment_request)
	audio.call("play_combo", _combo)
	_update_hud()


func _capture_moment(generation: int, request: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	if generation != _run_generation or request != _moment_request or state != "playing":
		return
	var shot: Image = get_viewport().get_texture().get_image()
	if shot.is_empty():
		return
	var crop: Rect2i = Rect2i(0, roundi(shot.get_height()*0.23), shot.get_width(), roundi(shot.get_height()*0.63))
	_moment_texture = ImageTexture.create_from_image(shot.get_region(crop))


func _check_near_passes() -> void:
	for index in range(world.officers.size()):
		var officer = world.officers[index]
		var gap: Vector2 = player.position - officer.position
		var entry: Dictionary = _near_passes.get(index, {})
		if entry.is_empty():
			if absf(gap.x) < 140.0 and officer.state in ["chase", "grab", "notice"] and absf(gap.x) > 20.0:
				entry = {"side": signf(gap.x), "close": false, "stumbles": player.stumble_count}
				_near_passes[index] = entry
			continue
		if absf(gap.x) < 75.0 and absf(gap.y) > 75.0 and absf(gap.y) < 155.0 and absf(player.velocity.x) > 240.0 and officer.clear_sight(player.position):
			entry["close"] = true
		if gap.x * float(entry.side) < -85.0:
			if bool(entry.close) and player.stumble_count == int(entry.stumbles):
				_score_flow("near_%d" % index, "near_miss", "擦身躲过查岗", 220, player.position)
			_near_passes.erase(index)
		elif absf(gap.x) > 300.0:
			_near_passes.erase(index)


func _flow_rank(success: bool) -> String:
	if not success:
		return "未打卡"
	if _chaos_score >= 4000 and _best_combo >= 6 and _flow_all_types.size() >= 3:
		return "S"
	if _chaos_score >= 1400 and _best_combo >= 3 and _flow_all_types.size() >= 2:
		return "A"
	return "B" if _chaos_score >= 600 else "C"


func _flow_target() -> String:
	if _best_combo < 3:
		return "下一局接出三连。\n四秒内换招，冲到 A 级。"
	if _chaos_score < 1400:
		return "距 A 级还差 %d 分。\n换一种动作能加分。" % (1400 - _chaos_score)
	if _flow_rank(true) != "S":
		return "距 S 级还差 %d 分。\n目标：六连动作、三种办法。" % maxi(0,4000 - _chaos_score)
	return "S 级到岗！\n下一局挑战更快的连招路线。"


func _on_supervisor_warning() -> void:
	_warned_this_run = true
	audio.call("play", "warning")


var _challenge_sent_for_run: bool = false
var _warned_this_run: bool = false


func _finish_success() -> void:
	if result_locked or state != "playing":
		return
	result_locked = true
	var generation: int = _run_generation
	for officer in world.get("officers"):
		if officer.had_chase:
			_on_stunt("hr_escape","工牌下次再看，先打卡",200)
			break
	_arrival_style = "meeting" if bool(player.get("meeting_ride")) else "chair" if str(player.get("held")) == "chair" else "face" if absf(player.velocity.x) >= 550.0 else "normal"
	if _arrival_style == "meeting":
		_on_stunt("meeting_clock", "早会连人带桌准时打卡", 400)
	elif _arrival_style == "face":
		_on_stunt("face_clock", "脸部识别通过，脸暂时不通过", 200)
	elif _arrival_style == "chair":
		_on_stunt("chair_clock", "员工坐着抵达，椅子站着加班", 120)
	var elapsed: float = maxf(0.0, level_limit - remaining)
	var medals: Array[bool] = _calculate_medals(elapsed)
	var result: Dictionary = _build_result(true, elapsed, medals)
	world.call("set_active", false)
	player.call("freeze_at_desk", player.position)
	if bool(_level.get("chaos_playground",false)):
		player.set("pose_override", "desk")
		if _arrival_style == "meeting":
			player.position.y = float(world.call("meeting_info").get("y",488.0))
	state = "success"
	audio.call("set_phase", "success", remaining)
	audio.call("play", "success")
	save.call("record_success", level_index, elapsed, medals, _run_coupon_ids, assist_for_run, _chaos_score)
	if bool(_level.get("chaos_playground",false)):
		await get_tree().create_timer(0.8).timeout
		if generation != _run_generation or state != "success":
			return
	_show_screen("success", {"result": result})


func _on_hr_caught() -> void:
	_finish_failure("被人事当场登记迟到")


func _finish_failure(reason: String = "超时，迟到已登记") -> void:
	if result_locked or state != "playing":
		return
	result_locked = true
	var elapsed: float = level_limit-remaining
	remaining = 0.0
	var result: Dictionary = _build_result(false, elapsed, [false, false, false])
	result["title"] = reason
	result["failure_reason"] = reason
	world.call("set_active", false)
	if str(player.get("held")) != "":
		player.call("interact")
	player.set("controls_enabled", false)
	player.set("simulation_enabled", false)
	player.set("pose_override", "late")
	state = "failure"
	audio.call("set_phase", "failure", 0.0)
	audio.call("play", "fail")
	_show_screen("failure", {"result": result})


func _calculate_medals(elapsed: float) -> Array[bool]:
	if level_index == 0:
		return [false, false, false]
	var efficient_limit: float = float(_level.get("efficient", 0.0))
	if assist_for_run:
		efficient_limit *= 1.25
	var efficient_medal: bool = efficient_limit > 0.0 and elapsed <= efficient_limit
	var challenge_medal: bool = false
	var challenge_kind: String = str(_level.get("challenge_kind", ""))
	match challenge_kind:
		"low_damage":
			challenge_medal = _accidents.size() <= 2
		"chair_wall", "balcony", "table_block":
			challenge_medal = _challenge_sent_for_run
		"no_warning":
			challenge_medal = not _warned_this_run
		"chaos":
			challenge_medal = _accidents.size() >= 8
		"meeting_delivery":
			challenge_medal = _arrival_style == "meeting"
		"tactical_combo":
			challenge_medal = world.tactical_actions.size() >= 2
	return [true, efficient_medal, challenge_medal]


func _build_result(success: bool, elapsed: float, medals: Array[bool]) -> Dictionary:
	var accidents_count: int = _accidents.size()
	var stumbles: int = int(player.get("stumble_count")) if is_instance_valid(player) else 0
	var chair_seconds: float = float(player.get("chair_seconds")) if is_instance_valid(player) else 0.0
	var spray_seconds: float = float(player.get("spray_seconds")) if is_instance_valid(player) else 0.0
	var title: String = "明日再战"
	if success:
		if _arrival_style == "meeting":
			title = "移动早会运输部长"
		elif _stunts.has("rocket_chair"):
			title = "消防器材研发总监"
		elif _best_combo >= 4:
			title = "办公室多米诺大师"
		elif medals.size() > 1 and medals[1] and _damage_total >= 5000:
			title = "全勤奖守护者"
		elif accidents_count >= 8:
			title = "公司拆迁办主任"
		elif stumbles >= 4:
			title = "人到了，魂没到"
		elif chair_seconds >= 8.0:
			title = "椅路顺风"
		elif spray_seconds >= 1.5:
			title = "消防演习负责人"
		elif accidents_count == 0:
			title = "体面打工人"
		elif remaining <= 3.0:
			title = "踩点专家"
		else:
			title = "今日正常到岗"
	var bill: Array[Dictionary] = []
	var kinds: Array = _damage_by_kind.keys()
	kinds.sort()
	for kind_value in kinds:
		var kind: String = str(kind_value)
		var count: int = 0
		var cost: int = 0
		for accident_value in _accidents.values():
			var accident_record: Dictionary = accident_value
			if str(accident_record.get("kind", "")) == kind:
				count += 1
				cost += int(accident_record.get("cost", 0))
		bill.append({"kind": kind, "count": count, "cost": cost})
	var player_position: Vector2 = _level.get("spawn", Vector2(96.0, 600.0))
	if is_instance_valid(player):
		player_position = player.position
	var goal_position_value: Variant = world.get("goal_position") if is_instance_valid(world) else player_position
	var result_goal: Vector2 = goal_position_value if goal_position_value is Vector2 else player_position
	var distance: float = player_position.distance_to(result_goal)
	var coupons_count: int = _run_coupon_ids.size()
	return {
		"success": success,
		"name": str(_level.get("name", "")),
		"day": str(_level.get("day", "")),
		"elapsed": elapsed,
		"remaining": remaining,
		"damage": _damage_total,
		"accidents": accidents_count,
		"stumbles": stumbles,
		"title": title,
		"medals": medals,
		"coupons": coupons_count,
		"coupon_ids": _run_coupon_ids.duplicate(),
		"bill": bill,
		"distance": distance,
		"finale": success and level_index == 5,
		"chaos": _chaos_score, "best_combo": _best_combo,
		"moment": _best_moment, "discovered": _stunts.size(),
		"arrival": _arrival_style, "replay_tip": _replay_tip(),
		"tactical": bool(_level.get("tactical",false)), "route": _route_summary(),
		"strategy_count": world.tactical_actions.size(), "challenge_done": medals.size()>2 and medals[2],
		"unlock_note": "已发现的名场面会保留，失败也能继续探索。",
		"playground": bool(_level.get("chaos_playground",false)),
		"rank": _flow_rank(success), "flow_target": _flow_target() if success else "下一局先保住打卡。\n再把精彩动作接起来。", "flow_trace": " → ".join(_flow_trace),
		"moment_texture": _moment_texture,
		"previous_best": float(save.level_record(maxi(1, level_index)).get("assist_best" if assist_for_run else "normal_best", 0.0)),
		"assist": assist_for_run
	}


func _replay_tip() -> String:
	if bool(_level.get("tactical",false)):
		if _damage_total>0:
			return "再试零损通勤：F 复印引开人事，上层绕过饮水机。"
		if not world.tactical_actions.has("chain"):
			return "再试连锁开路：骑椅撞水机，让滚桶撞散后面的文件。"
		return "再试组合脱身：引开、装忙、喷粉或推桌，完成两种办法。"
	if level_index>1:
		return "下一局挑战：" + str(_level.get("challenge","准时打卡"))
	if not _stunts.has("busy_escape"):
		return "下一局：在绿线处按住 Q 写日报，趁人事核查时溜走。"
	if not _stunts.has("upper_route"):
		return "下一局：跳上有支架的员工通道，绕开地面查岗。"
	if not _stunts.has("table_block"):
		return "下一局：用 A/D 推动会议桌，把追赶的人事堵在另一侧。"
	return "新目标：绕路、装忙和遮挡连在一局，保住五十块全勤奖。"


func _route_summary() -> String:
	var labels: Array[String] = []
	if world.tactical_actions.has("noise_lure"):
		labels.append("诱饵")
	if world.tactical_actions.has("chain"):
		labels.append("连锁")
	if world.tactical_actions.has("busy_escape"):
		labels.append("装忙")
	if world.tactical_actions.has("powder_escape"):
		labels.append("遮挡")
	if world.tactical_actions.has("table_block"):
		labels.append("挡路")
	if _stunts.has("upper_route"):
		labels.append("上层")
	return " → ".join(labels) if not labels.is_empty() else "直接通勤"


func _update_hud() -> void:
	if not is_instance_valid(ui) or state != "playing":
		return
	var held: String = str(player.get("held")) if is_instance_valid(player) else ""
	var prompt: String = ""
	if is_instance_valid(player):
		if bool(world.call("goal_reachable", player.position)):
			prompt = "E 打卡"
		elif not world.control_hint(player.position).is_empty():
			prompt = world.control_hint(player.position)
		elif bool(world.call("busy_near",player.position)) and held.is_empty():
			prompt = "按住 Q 装忙"
		elif bool(world.call("meeting_near",player.position)) and held.is_empty():
			prompt = "A/D 推桌 · 空格翻过"
		elif not held.is_empty():
			prompt = "F 踢出诱饵 · E 放下" if held in ["chair","bucket"] else "F 喷粉 · E 放下"
		else:
			var interaction_value: Variant = world.call("nearest_interaction", player.position)
			if interaction_value is String and not str(interaction_value).is_empty():
				prompt = "E " + str(interaction_value)
	var hud: Dictionary = {
		"day": str(_level.get("day", "")),
		"name": str(_level.get("name", "")),
		"remaining": remaining,
		"limit": level_limit,
		"held": held,
		"fuel": float(player.get("fuel")) if is_instance_valid(player) else 1.0,
		"coupons": _run_coupon_ids.size(),
		"accidents": _accidents.size(),
		"damage": _damage_total,
		"recent_event": _recent_accident,
		"recent_event_age": _recent_accident_time,
		"accident_tip": "人事会听到事故；装忙只能争取几秒。" if bool(_level.get("chaos_playground",false)) else "高速碰撞会产生损失；跳跃或减速可以避开。",
		"hr_status": world.call("hr_status"),
		"busy": bool(player.get("busy")),
		"prompt": prompt,
		"bubble": _current_bubble,
		"started": timer_started,
		"chaos": _chaos_score, "combo": _combo, "best_combo": _best_combo,
		"drift_charge": float(player.get("drift_charge")), "rocket": bool(player.get("rocket_attached")),
		"meeting": bool(player.get("meeting_ride")), "playground": bool(_level.get("chaos_playground",false)),
		"tactical": bool(_level.get("tactical",false)), "strategy_count": world.tactical_actions.size(),
		"gate_status": ("门禁已关" if world._gate_closed else "门禁 %.1f 秒" % world._gate_remaining) if world._gate_started else "",
		"flow_label": _flow_label, "flow_award": _flow_award, "flow_flash": _flow_flash,
		"combo_remaining": _combo_remaining, "multiplier": mini(4, 1 + floori(_combo / 3.0)),
		"speed": absf(player.velocity.x), "rank": _flow_rank(true)
	}
	ui.call("update_hud", hud)


func _show_screen(screen: String, extra: Dictionary = {}) -> void:
	if not is_instance_valid(ui):
		return
	var context: Dictionary = _base_context()
	context.merge(extra, true)
	ui.call("show_screen", screen, context)


func _base_context() -> Dictionary:
	var data: Dictionary = _save_data()
	var settings: Dictionary = _ui_settings()
	return {
		"levels": _calendar_levels(),
		"current_level": level_index,
		"unlocked": int(data.get("unlocked", 1)),
		"total_coupons": int(save.call("coupon_count")),
		"badge": int(data.get("badge", 0)),
		"badge_count": int(save.call("unlocked_badges")),
		"settings": settings,
		"assist": bool(settings.get("assist", false)),
		"name": str(_level.get("name", "")),
		"day": str(_level.get("day", "")),
		"notice": str(_level.get("notice", "")),
		"challenge": str(_level.get("challenge", "")),
		"limit": level_limit,
		"result": {},
		"playground": bool(_level.get("chaos_playground",false)),
		"tactical": bool(_level.get("tactical",false)),
		"discoveries": save.call("level_record",1).get("discoveries",{})
	}


func _calendar_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var data: Dictionary = _save_data()
	var unlocked: int = int(data.get("unlocked", 1))
	var record: Dictionary = {}
	for index in range(6):
		var metadata: Dictionary = LEVEL_DATA_SCRIPT.get_level(index)
		var medals: Array = [false, false, false]
		var coupons: Array = []
		var normal_best: float = 0.0
		var assist_best: float = 0.0
		if index > 0:
			record = save.call("level_record", index)
			medals = record.get("medals", medals)
			coupons = record.get("coupons", coupons)
			normal_best = float(record.get("normal_best", 0.0))
			assist_best = float(record.get("assist_best", 0.0))
		metadata["index"] = index
		metadata["unlocked"] = index == 0 or index <= unlocked
		metadata["medals"] = medals.duplicate(true)
		metadata["coupons"] = coupons.duplicate(true)
		metadata["normal_best"] = normal_best
		metadata["assist_best"] = assist_best
		var best_time: float = normal_best
		if bool(_settings().get("assist", false)) and assist_best > 0.0:
			best_time = assist_best
		elif best_time <= 0.0:
			best_time = assist_best
		metadata["best_time"] = best_time
		metadata["chaos_best"] = int(record.get("assist_chaos" if bool(_settings().get("assist",false)) else "normal_chaos",0))
		metadata["discoveries"] = record.get("discoveries",{}).size()
		levels.append(metadata)
	return levels


func _save_data() -> Dictionary:
	if not is_instance_valid(save):
		return {}
	var value: Variant = save.get("data")
	if value is Dictionary:
		return value
	return {}


func _settings() -> Dictionary:
	var data: Dictionary = _save_data()
	var value: Variant = data.get("settings", {})
	if value is Dictionary:
		return value
	return {"music_volume": 0.55, "sound_volume": 0.8, "screen_shake": true, "assist": false, "fullscreen": false}


func _ui_settings() -> Dictionary:
	return _settings().duplicate(true)


func _update_camera_preview() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	if state in ["pause", "settings"]:
		return
	var facing: int = int(player.get("facing"))
	var velocity_value: Variant = player.get("velocity")
	var velocity: Vector2 = velocity_value if velocity_value is Vector2 else Vector2.ZERO
	var preview: float = clampf(velocity.x * 0.16, -145.0, 145.0)
	var target_lead: float = float(facing) * 190.0 + preview
	if state == "playing" and bool(_level.get("tactical", false)):
		_camera_lead = lerpf(_camera_lead, target_lead, 0.08)
		camera.position = Vector2(_camera_lead, 0.0)
	else:
		camera.position = Vector2(target_lead, 0.0)
	var center: Vector2 = camera.get_screen_center_position()
	var half_width: float = get_viewport_rect().size.x * 0.5 / maxf(camera.zoom.x, 0.01)
	var world_left: float = clampf(center.x - half_width, 0.0, float(world.get("bounds_width")))
	var world_right: float = clampf(center.x + half_width, world_left, float(world.get("bounds_width")))
	world.set("view_left", world_left)
	world.set("view_right", world_right)


func _update_audio_tool() -> void:
	if not is_instance_valid(player) or not is_instance_valid(audio):
		return
	var held: String = str(player.get("held"))
	var velocity_value: Variant = player.get("velocity")
	var velocity: Vector2 = velocity_value if velocity_value is Vector2 else Vector2.ZERO
	var fuel: float = float(player.get("fuel"))
	var spraying: bool = state == "playing" and (held == "extinguisher" or bool(player.get("rocket_attached"))) and fuel > 0.0 and Input.is_action_pressed("use_tool")
	if bool(player.get("rocket_attached")):
		held = "extinguisher"
	audio.call("set_tool", held, velocity.x, spraying, state == "playing")


func _run_smoke_test() -> void:
	_start_level(0, true)
	_begin_play()
	timer_started = true
	remaining = level_limit - 1.0
	player.position = world.get("goal_position")
	_finish_success()
	await get_tree().create_timer(1.0).timeout
	if not _capture_path.is_empty():
		_save_capture(_capture_path)
	print("上班迟到大作战：主流程验收通过")
	get_tree().quit(0)


func _capture_initial_screen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture(_capture_path)
	get_tree().quit(0)


func _save_capture(path: String) -> void:
	if path.is_empty():
		return
	var directory: String = path.get_base_dir()
	if not directory.is_empty() and directory != ".":
		var absolute_directory: String = ProjectSettings.globalize_path(directory) if path.begins_with("user://") else directory
		DirAccess.make_dir_recursive_absolute(absolute_directory)
	var image: Image = get_viewport().get_texture().get_image()
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		push_warning("畫面擷取失敗：" + error_string(save_error))
