extends CharacterBody2D
class_name OfficePlayer

signal started
signal fell
signal stumbled
signal tool_changed
signal motion_sound(kind: String)
signal stunt(id: String, label: String, points: int)
signal flow_action(id: String, kind: String, label: String, points: int)

const WALK_SPEED: float = 300.0
const CHAIR_SPEED: float = 500.0
const BUCKET_DRY_SPEED: float = 280.0
const BUCKET_WET_SPEED: float = 700.0
const DASH_SPEED: float = 550.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.7
const JUMP_BUFFER_TIME: float = 0.12
const COYOTE_TIME: float = 0.12
const BASE_STUMBLE_TIME: float = 0.45
const HIT_PROTECTION_TIME: float = 0.8
const EXTINGUISHER_SECONDS: float = 2.8
const FALL_LIMIT_Y: float = 900.0

var world: Node = null
var controls_enabled: bool = true
var simulation_enabled: bool = true
var assist: bool = false
var badge: int = 0

var facing: int = 1
var held: String = ""
var held_id: int = -1
var fuel: float = 1.0
var stumble_count: int = 0
var chair_seconds: float = 0.0
var spray_seconds: float = 0.0
var pose_override: String = ""
var busy: bool = false
var pushing: bool = false
var playground: bool = false
var rocket_unlocked: bool = false
var spring_unlocked: bool = false
var rocket_attached: bool = false
var rocket_id: int = -1
var drift_charge: float = 0.0
var meeting_ride: bool = false
var _drift_armed: bool = false
var _drift_boost: float = 0.0
var _drift_direction: int = 1
var _air_travel: float = 0.0
var _meeting_board_age: float = 0.0
var _meeting_board_from: Vector2 = Vector2.ZERO

var _visual_clock: float = 0.0
var _started_once: bool = false
var _gravity: float = 980.0
var _jump_buffer_seconds: float = 0.0
var _coyote_seconds: float = 0.0
var _jump_cut_pending: bool = false
var _dash_seconds: float = 0.0
var _dash_cooldown_seconds: float = 0.0
var _dash_direction: int = 1
var _air_dash_available: bool = true
var _stumble_seconds: float = 0.0
var _hit_protection_seconds: float = 0.0
var _recovery_pose_seconds: float = 0.0
var _braking: bool = false
var _was_braking: bool = false
var _spraying: bool = false
var _footstep_cooldown: float = 0.0
var _gait_phase: float = 0.0
var _gait_amount: float = 0.0
var _jump_age: float = -1.0
var _land_age: float = -1.0
var _landing_amount: float = 0.0
var _dash_age: float = -1.0
var _brake_age: float = -1.0
var _stumble_age: float = -1.0
var _has_left_ground: bool = false
var anim_state: Dictionary = {}
var _surface: Dictionary = {}
var _last_position: Vector2 = Vector2.ZERO
var _blocked_seconds: float = 0.0
var _dash_buffer: float = 0.0
var _jump_origin: Vector2 = Vector2.ZERO
var _jump_speed: float = 0.0
var _flow_serial: int = 0
var _chair_lean: float = 0.0
var _jump_active: bool = false
var _landing_from_jump: bool = false


func _flow_enabled() -> bool:
	return is_instance_valid(world) and bool(world.get("tactical"))


func _emit_flow(kind: String, label: String, points: int) -> void:
	_flow_serial += 1
	flow_action.emit("motion_%d" % _flow_serial, kind, label, points)


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_ensure_collision_shape()
	queue_redraw()


func _process(delta: float) -> void:
	if simulation_enabled:
		_visual_clock += delta
	_refresh_animation_state()
	queue_redraw()


func _is_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _is_just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _move_axis() -> float:
	var left_strength: float = 0.0
	var right_strength: float = 0.0
	if InputMap.has_action("move_left"):
		left_strength = Input.get_action_strength("move_left")
	if InputMap.has_action("move_right"):
		right_strength = Input.get_action_strength("move_right")
	return clampf(right_strength - left_strength, -1.0, 1.0)


func _mark_started() -> void:
	if _started_once:
		return
	_started_once = true
	started.emit()


func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		return

	var rectangle: RectangleShape2D = $CollisionShape2D.shape
	rectangle.size.x = 64.0 if held=="chair" else 56.0 if held=="bucket" else 44.0
	var was_on_floor: bool = is_on_floor()
	_update_timers(delta)
	_update_visual_timers(delta)
	if meeting_ride and _update_meeting_ride(delta):
		return
	if is_on_floor():
		_coyote_seconds = COYOTE_TIME
		_air_dash_available = true
	else:
		_coyote_seconds = maxf(0.0, _coyote_seconds - delta)

	_surface.clear()
	if world != null and world.has_method("surface_at"):
		_surface = world.call("surface_at", position)

	var can_control: bool = controls_enabled and _stumble_seconds <= 0.0
	var axis: float = _move_axis() if can_control else 0.0
	_braking = can_control and _is_pressed("brake")
	if _braking and not _was_braking and absf(velocity.x) >= 120.0:
		_brake_age = 0.0
		motion_sound.emit("brake")
	_was_braking = _braking
	var busy_requested: bool = can_control and held.is_empty() and is_on_floor() and _is_pressed("busy") and world.busy_near(position)
	busy = busy_requested and absf(velocity.x)<45
	if busy_requested:
		axis = 0
		_mark_started()
	pushing = world.push_table(position, axis) if can_control and held.is_empty() and is_on_floor() else false
	if absf(axis) > 0.01:
		facing = 1 if axis > 0.0 else -1
		_mark_started()

	if can_control and _is_just_pressed("jump"):
		_jump_buffer_seconds = JUMP_BUFFER_TIME
		_mark_started()
	if can_control and _is_just_pressed("dash"):
		_mark_started()
		_dash_buffer = 0.14 if _flow_enabled() else 0.0
		_try_start_dash()
	elif can_control and _dash_buffer > 0.0 and is_on_floor():
		_try_start_dash()

	var control_used: bool = false
	if can_control and _is_just_pressed("use_tool"):
		control_used = world.use_control(position)
		if control_used:
			_mark_started()
		elif held in ["chair","bucket"] and is_on_floor():
			var launched_id: int = held_id
			_release_held_prop()
			world.launch_tool(launched_id,facing)
			_mark_started()
			motion_sound.emit("dash")
	var spray_requested: bool = can_control and not control_used and (held == "extinguisher" or rocket_attached) and fuel > 0.0 and _is_pressed("use_tool")
	_apply_jump_buffer()
	_apply_horizontal(axis, delta, spray_requested)
	_apply_extinguisher(delta, can_control and not control_used)
	_apply_gravity(delta)
	_cut_short_jump()

	if held == "chair":
		chair_seconds += delta
	var incoming_velocity: Vector2 = velocity
	_chair_lean = lerpf(_chair_lean, clampf((incoming_velocity.x - float(anim_state.get("speed", 0.0))) / 100.0, -0.24, 0.24), minf(1.0, delta * 12.0)) if held == "chair" else 0.0
	move_and_slide()
	var did_land: bool = not was_on_floor and is_on_floor() and _has_left_ground
	if not is_on_floor():
		_air_travel += absf(position.x - _last_position.x)
	elif did_land:
		if playground and _air_travel >= 250.0:
			stunt.emit("long_flight", "人先到，鞋随后", 180)
		_air_travel = 0.0
	_update_floor_state()
	_update_animation_motion(delta, axis, did_land, incoming_velocity)
	for index in range(get_slide_collision_count()):
		var contact: KinematicCollision2D = get_slide_collision(index)
		if absf(contact.get_normal().x)>0.8:
			world.object_impact(contact.get_collider(),incoming_velocity.x,"player")
	_handle_wall_impact(incoming_velocity)
	_check_stuck(delta, axis)
	_check_fall_recovery()
	_last_position = position


func _update_timers(delta: float) -> void:
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_jump_buffer_seconds = maxf(0.0, _jump_buffer_seconds - delta)
	_dash_seconds = maxf(0.0, _dash_seconds - delta)
	_dash_cooldown_seconds = maxf(0.0, _dash_cooldown_seconds - delta)
	_hit_protection_seconds = maxf(0.0, _hit_protection_seconds - delta)
	_recovery_pose_seconds = maxf(0.0, _recovery_pose_seconds - delta)
	_footstep_cooldown = maxf(0.0, _footstep_cooldown - delta)
	if _stumble_seconds > 0.0:
		_stumble_seconds = maxf(0.0, _stumble_seconds - delta)
		if _stumble_seconds == 0.0 and pose_override == "stumble":
			pose_override = ""
	if _recovery_pose_seconds == 0.0 and pose_override == "fall":
		pose_override = ""


func _update_visual_timers(delta: float) -> void:
	if _jump_age >= 0.0:
		_jump_age = _advance_visual_age(_jump_age, delta, 0.8)
	if _land_age >= 0.0:
		_land_age = _advance_visual_age(_land_age, delta, 0.38)
	if _dash_age >= 0.0:
		_dash_age = _advance_visual_age(_dash_age, delta, 0.42)
	if _brake_age >= 0.0:
		_brake_age = _advance_visual_age(_brake_age, delta, 0.4)
	if _stumble_age >= 0.0:
		_stumble_age = _advance_visual_age(_stumble_age, delta, 0.7)


func _advance_visual_age(age: float, delta: float, lifetime: float) -> float:
	var next_age: float = age + delta
	return -1.0 if next_age > lifetime else next_age


func _update_animation_motion(delta: float, axis: float, did_land: bool, incoming_velocity: Vector2) -> void:
	var ground_travel: float = absf(position.x - _last_position.x)
	var gait_active: bool = is_on_floor() and not did_land and held.is_empty() and not _braking and _dash_seconds <= 0.0 and _stumble_seconds <= 0.0 and absf(axis) > 0.05 and ground_travel > 0.05
	var gait_target: float = clampf(absf(velocity.x) / WALK_SPEED, 0.0, 1.0) if gait_active else 0.0
	_gait_amount = move_toward(_gait_amount, gait_target, delta * 8.0)
	if gait_active:
		var previous_phase: float = _gait_phase
		var phase_advance: float = ground_travel * TAU / 180.0
		var unwrapped_phase: float = previous_phase + phase_advance
		var crossed_steps: int = floori(unwrapped_phase / PI) - floori(previous_phase / PI)
		_gait_phase = fposmod(unwrapped_phase, TAU)
		if crossed_steps > 0 and _footstep_cooldown <= 0.0:
			motion_sound.emit("footstep")
			_footstep_cooldown = 0.22
	if did_land:
		_landing_from_jump = _jump_active
		if _flow_enabled() and _jump_active and _jump_speed >= 380.0 and absf(position.x - _jump_origin.x) >= 140.0:
			_emit_flow("vault" if absf(position.y - _jump_origin.y) >= 60.0 else "running_jump", "高速翻越" if absf(position.y - _jump_origin.y) >= 60.0 else "飞跃落地", 130)
		_jump_active = false
		_land_age = 0.0
		_landing_amount = clampf(incoming_velocity.y / 720.0, 0.0, 1.0)
		motion_sound.emit("land")
		_has_left_ground = false
	elif not is_on_floor():
		_has_left_ground = true
	_refresh_animation_state()


func _refresh_animation_state() -> void:
	anim_state = {
		"gait_phase": _gait_phase,
		"gait_amount": _gait_amount,
		"airborne": _meeting_board_age < 0.28 if meeting_ride else not is_on_floor(),
		"vertical_speed": velocity.y,
		"jump_age": _jump_age,
		"land_age": _land_age,
		"landing_amount": _landing_amount * pow(maxf(0.0, 1.0 - _land_age / 0.24), 2.0) if _land_age >= 0.0 else 0.0,
		"speed": velocity.x,
		"comic": _flow_enabled(),
		"chair_lean": _chair_lean,
		"dash_age": _dash_age,
		"brake_age": _brake_age,
		"stumble_age": _stumble_age,
		"visual_clock": _visual_clock,
		"held": held,
		"busy": busy,
		"slope_angle": atan(float(_surface.get("slope",0))) if is_on_floor() and held in ["chair","bucket"] else 0.0,
		"pushing": pushing,
		"braking": _braking,
		"drift_charge": drift_charge,
		"rocket": rocket_attached,
		"spraying": _spraying,
		"meeting": meeting_ride
	}


func _update_floor_state() -> void:
	if is_on_floor():
		_coyote_seconds = COYOTE_TIME
		_air_dash_available = true
		_jump_cut_pending = false
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		_coyote_seconds = maxf(0.0, _coyote_seconds)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, 1100.0)


func _apply_jump_buffer() -> void:
	if _jump_buffer_seconds <= 0.0:
		return
	if _coyote_seconds <= 0.0:
		return
	_jump_buffer_seconds = 0.0
	_coyote_seconds = 0.0
	_jump_cut_pending = true
	_jump_origin = position
	_jump_speed = absf(velocity.x)
	_jump_active = true
	if held in ["chair", "bucket"]:
		_release_held_prop()
	velocity.y = -505.0
	_dash_seconds = 0.0
	_braking = false
	_jump_age = 0.0
	_land_age = -1.0
	_landing_amount = 0.0
	_has_left_ground = true
	motion_sound.emit("jump")


func _cut_short_jump() -> void:
	if not _jump_cut_pending:
		return
	if velocity.y >= 0.0:
		_jump_cut_pending = false
		return
	if not _is_pressed("jump"):
		velocity.y = -180.0
		_jump_cut_pending = false


func _apply_horizontal(axis: float, delta: float, _spray_requested: bool) -> void:
	var wet: bool = bool(_surface.get("wet", false))
	var belt: float = float(_surface.get("belt", 0.0)) if is_on_floor() else 0.0
	if not is_on_floor():
		var carry: bool = _flow_enabled() and axis * velocity.x > 0.0 and absf(velocity.x) > WALK_SPEED
		var air_accel: float = 45.0 if carry else 220.0
		velocity.x = move_toward(velocity.x, axis * WALK_SPEED, air_accel * delta)
		return
	if held in ["chair", "bucket"]:
		var rolling_limit: float = CHAIR_SPEED if held == "chair" else 340.0
		if _braking:
			velocity.x = move_toward(velocity.x, belt, (450.0 if wet else 1100.0) * delta)
		else:
			var slope: float = float(_surface.get("slope",0))
			velocity.x += slope * _gravity * delta
			if absf(axis) > 0.01 and absf(velocity.x - belt) < rolling_limit:
				velocity.x += axis * (850.0 if _flow_enabled() else 650.0) * delta
			velocity.x = move_toward(velocity.x, belt, (35.0 if wet else 130.0) * delta)
			velocity.x = clampf(velocity.x,-760,760)
	else:
		var target: float = axis * (125.0 if pushing else WALK_SPEED) + belt
		if _dash_seconds > 0.0 and not pushing and not busy:
			target = _dash_direction * DASH_SPEED + belt
		if _braking or busy:
			target = belt
		var carry: bool = _flow_enabled() and not pushing and not busy and not _braking and _dash_seconds <= 0.0 and axis * velocity.x > 0.0 and absf(velocity.x) > WALK_SPEED
		velocity.x = move_toward(velocity.x,target,(480.0 if carry else 900.0 if wet else 3200.0 if _flow_enabled() else 2500.0) * delta)


func _try_start_dash() -> void:
	if _dash_cooldown_seconds > 0.0 or held == "chair" or held == "bucket":
		return
	var on_ground: bool = is_on_floor()
	if not on_ground or busy or pushing:
		return
	var axis: float = _move_axis()
	if absf(axis) > 0.01:
		_dash_direction = 1 if axis > 0.0 else -1
	else:
		_dash_direction = facing
	facing = _dash_direction
	_dash_seconds = DASH_DURATION
	_dash_cooldown_seconds = DASH_COOLDOWN
	_dash_age = 0.0
	velocity.x = float(_dash_direction) * DASH_SPEED
	_dash_buffer = 0.0
	if _flow_enabled() and _landing_from_jump and _land_age >= 0.0 and _land_age < 0.18 and _jump_speed >= 280.0 and absf(position.x - _jump_origin.x) >= 110.0:
		_emit_flow("landing_dash", "落地接冲刺", 110)
	motion_sound.emit("dash")
	if not on_ground:
		_air_dash_available = false


func _apply_extinguisher(delta: float, can_control: bool) -> void:
	_spraying = can_control and held == "extinguisher" and fuel > 0 and _is_pressed("use_tool")
	if not _spraying:
		return
	_mark_started()
	fuel = maxf(0,fuel - delta / EXTINGUISHER_SECONDS)
	spray_seconds += delta
	world.spray_at(position, facing, delta)


func _handle_wall_impact(incoming_velocity: Vector2) -> void:
	if absf(incoming_velocity.x) < 600.0:
		return
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if absf(collision.get_normal().x) > 0.5 and absf(collision.get_normal().y) < 0.35:
			knock(collision.get_position())
			return


func interact() -> void:
	if not controls_enabled or _stumble_seconds > 0.0:
		return
	_mark_started()
	if held != "":
		_release_held_prop()
		return
	if world == null or not world.has_method("take_prop"):
		return
	var prop: Dictionary = world.call("take_prop", position)
	var prop_kind: String = str(prop.get("kind", ""))
	if prop_kind != "chair" and prop_kind != "extinguisher" and prop_kind != "bucket":
		return
	held = prop_kind
	held_id = int(prop.get("id", -1))
	fuel = clampf(float(prop.get("fuel", 1.0)), 0.0, 1.0)
	tool_changed.emit()


func _release_held_prop() -> void:
	if held == "":
		return
	if world != null and world.has_method("release_prop"):
		world.call("release_prop", held_id, position, held, fuel)
		if rocket_attached:
			world.call("release_prop", rocket_id, position + Vector2(60.0, 0.0), "extinguisher", fuel)
	held = ""
	held_id = -1
	fuel = 1.0
	_spraying = false
	rocket_attached = false
	rocket_id = -1
	drift_charge = 0.0
	_drift_armed = false
	_drift_boost = 0.0
	tool_changed.emit()


func knock(source: Vector2) -> void:
	if not simulation_enabled or _hit_protection_seconds > 0.0 or _stumble_seconds > 0.0:
		return
	_jump_active = false
	_landing_from_jump = false
	var knock_direction: int = 1 if position.x >= source.x else -1
	if absf(position.x - source.x) < 1.0:
		knock_direction = facing
	_release_held_prop()
	facing = knock_direction
	velocity.x = float(knock_direction) * 260.0
	velocity.y = -180.0
	_dash_seconds = 0.0
	_stumble_seconds = 0.25 if assist else BASE_STUMBLE_TIME
	_stumble_age = 0.0
	_has_left_ground = true
	_hit_protection_seconds = HIT_PROTECTION_TIME
	pose_override = "stumble"
	stumble_count += 1
	stumbled.emit()


func reset_at(pos: Vector2) -> void:
	_dash_buffer = 0.0
	_jump_origin = pos
	_jump_speed = 0.0
	_flow_serial = 0
	_chair_lean = 0.0
	_jump_active = false
	_landing_from_jump = false
	busy = false
	pushing = false
	position = pos
	_last_position = pos
	velocity = Vector2.ZERO
	_visual_clock = 0.0
	_gait_phase = 0.0
	_gait_amount = 0.0
	_jump_age = -1.0
	_land_age = -1.0
	_landing_amount = 0.0
	_dash_age = -1.0
	_brake_age = -1.0
	_stumble_age = -1.0
	_has_left_ground = false
	facing = 1
	held = ""
	held_id = -1
	fuel = 1.0
	stumble_count = 0
	chair_seconds = 0.0
	spray_seconds = 0.0
	pose_override = ""
	rocket_attached = false
	rocket_id = -1
	meeting_ride = false
	drift_charge = 0.0
	_drift_armed = false
	_drift_boost = 0.0
	_air_travel = 0.0
	_started_once = false
	_jump_buffer_seconds = 0.0
	_coyote_seconds = COYOTE_TIME
	_jump_cut_pending = false
	_dash_seconds = 0.0
	_dash_cooldown_seconds = 0.0
	_air_dash_available = true
	_braking = false
	_was_braking = false
	_footstep_cooldown = 0.0
	_stumble_seconds = 0.0
	_hit_protection_seconds = 0.0
	_recovery_pose_seconds = 0.0
	_blocked_seconds = 0.0
	controls_enabled = true
	simulation_enabled = true
	_refresh_animation_state()
	queue_redraw()


func freeze_at_desk(pos: Vector2) -> void:
	_dash_buffer = 0.0
	meeting_ride = false
	_release_held_prop()
	busy = false
	pushing = false
	position = pos
	_last_position = pos
	velocity = Vector2.ZERO
	_gait_amount = 0.0
	_jump_age = -1.0
	_land_age = -1.0
	_landing_amount = 0.0
	_dash_age = -1.0
	_brake_age = -1.0
	_stumble_age = -1.0
	_braking = false
	controls_enabled = false
	simulation_enabled = false
	pose_override = "desk"
	_refresh_animation_state()
	queue_redraw()


func _update_drift(_delta: float) -> void:
	drift_charge = 0.0


func board_meeting() -> void:
	meeting_ride = false


func _update_meeting_ride(_delta: float) -> bool:
	meeting_ride = false
	return false


func _check_fall_recovery() -> void:
	var out_of_bounds: bool = position.y > FALL_LIMIT_Y
	if world != null:
		var bounds_value: Variant = world.get("bounds_width")
		if bounds_value != null:
			var bounds_width: float = float(bounds_value)
			out_of_bounds = out_of_bounds or position.x < -128.0 or position.x > bounds_width + 128.0
	if out_of_bounds:
		_recover_to_safe_point()


func _recover_to_safe_point() -> void:
	controls_enabled = false
	simulation_enabled = false
	fell.emit()


func _check_stuck(delta: float, axis: float) -> void:
	if absf(axis) > 0.1 and is_on_floor() and absf(position.x - _last_position.x) < 0.5:
		_blocked_seconds += delta
	else:
		_blocked_seconds = 0
	if _blocked_seconds > 2.5:
		_release_held_prop()
		_blocked_seconds = 0


func _ensure_collision_shape() -> void:
	var existing_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if existing_shape != null:
		return
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(44.0, 114.0)
	shape_node.shape = rectangle
	shape_node.position = Vector2(0.0, -57.0)
	shape_node.name = "CollisionShape2D"
	add_child(shape_node)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 12


func _resolve_pose() -> String:
	if busy:
		return "busy"
	if pose_override != "":
		return pose_override
	if _stumble_seconds > 0.0:
		return "stumble"
	if _dash_seconds > 0.0:
		return "dash"
	if _braking:
		return "brake"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if absf(velocity.x) > 20.0:
		return "run"
	return "idle"


func _draw() -> void:
	if Engine.is_editor_hint():
		return
	OfficeArt.draw_player(self, Vector2.ZERO, facing, _resolve_pose(), _visual_clock, velocity, held, badge, fuel, anim_state)
