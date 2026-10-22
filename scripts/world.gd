extends Node2D
class_name OfficeWorld

signal accident(id: String, kind: String, cost: int, at: Vector2)
signal collected(id: int, at: Vector2)
signal challenge_event(kind: String)
signal bubble(message: String, at: Vector2)
signal supervisor_warning
signal stunt(id: String, label: String, points: int)
signal hr_alert
signal hr_caught

const HR_SCRIPT = preload("res://scripts/hr_officer.gd")
const OBJECT_SCRIPT = preload("res://scripts/office_object.gd")

const FLOOR_Y: float = 600.0
const FLOOR_DEPTH: float = 96.0
const VIEW_WIDTH: float = 1280.0
const BACKGROUND_CHUNK_SIZE: float = 512.0
const BACKGROUND_OVERSCAN: float = 256.0
const BACKGROUND_CLOCK_REFRESH: float = 2.0
const FLOOR_COLOR: Color = Color("e9dfcc")
const FLOOR_EDGE_COLOR: Color = Color("28344a")
const PLATFORM_COLOR: Color = Color("a7bbc3")
const WET_COLOR: Color = Color(0.30, 0.67, 0.67, 0.42)
const OFFICE_FONT: Font = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")


class BackgroundPainter:
	extends Node2D

	var region_left: float = 0.0
	var region_right: float = 0.0
	var theme_index: int = 0
	var scene_clock: float = 0.0


	func configure(left: float, right: float, theme: int, clock: float) -> void:
		region_left = left
		region_right = right
		theme_index = theme
		scene_clock = clock
		queue_redraw()


	func _draw() -> void:
		if region_right <= region_left:
			return
		OfficeArt.draw_office(self, region_left, region_right, theme_index, scene_clock)


var level_index: int = 0
var bounds_width: float = 1280.0
var spawn_position: Vector2 = Vector2(96.0, FLOOR_Y)
var goal_position: Vector2 = Vector2(900.0, FLOOR_Y)
var active: bool = true
var player: Node = null
var view_left: float = 0.0
var view_right: float = VIEW_WIDTH
var chaos_playground: bool = false
var _actors_root: Node2D
var officers: Array = []
var objects: Array = []
var table: CharacterBody2D
var _clouds: Array[Dictionary] = []
var _busy_zones: Array[Dictionary] = []
var _rollers: Array[Dictionary] = []
var _meeting: Dictionary = {}
var _scene_generation: int = 0
var _announced: Dictionary = {}
var tactical: bool = false
var tactical_actions: Dictionary = {}
var _controls: Array[Dictionary] = []
var _control_cooldowns: Dictionary = {}
var _gate: Dictionary = {}
var _gate_body: StaticBody2D
var _gate_started: bool = false
var _gate_remaining: float = 0.0
var _gate_closed: bool = false
var _noise_pulses: Array[Dictionary] = []
var _flow_pops: Array[Dictionary] = []

var _level: Dictionary = {}
var _ground: Array[Dictionary] = []
var _ramps: Array[Dictionary] = []
var _platforms: Array[Dictionary] = []
var _furniture: Array[Dictionary] = []
var _props: Array[Dictionary] = []
var _tools: Array[Dictionary] = []
var _coupons: Array[Dictionary] = []
var _wet_zones: Array[Dictionary] = []
var _mechanisms: Array[Dictionary] = []
var _route_signs: Array[Dictionary] = []
var _npcs: Array[Dictionary] = []
var _supervisor: Dictionary = {}

var _collision_root: Node2D = null
var _prop_bodies: Dictionary = {}
var _damaged: Dictionary = {}
var _tool_available: Dictionary = {}
var _tool_fuel: Dictionary = {}
var _coupon_taken: Dictionary = {}
var _challenge_sent: Dictionary = {}
var _water_spills: Array[Dictionary] = []
var _accident_effects: Array[Dictionary] = []

var _clock: float = 0.0
var _supervisor_x: float = 0.0
var _supervisor_direction: int = 1
var _supervisor_alarm: float = 0.0
var _supervisor_cooldown: float = 0.0
var _warning_lock_time: float = 0.0
var _warning_restore_controls: bool = false
var _bubble_cooldown: float = 0.0
var _background_painter: Node2D = null
var _background_cache_left: float = -1.0
var _background_cache_right: float = -1.0
var _background_cache_theme: int = -1
var _background_cache_view_size: Vector2 = Vector2.ZERO
var _background_clock_elapsed: float = 0.0


func _ready() -> void:
	_background_painter = BackgroundPainter.new()
	_background_painter.name = "BackgroundPainter"
	_background_painter.show_behind_parent = true
	add_child(_background_painter)
	_refresh_background_cache(true)
	set_process(active)
	set_physics_process(active)
	queue_redraw()


func setup(index: int, already_collected: Array) -> void:
	level_index = clampi(index, 0, 5)
	_level = LevelData.get_level(level_index)
	chaos_playground = bool(_level.get("chaos_playground", false))
	tactical = bool(_level.get("tactical", false))
	tactical_actions.clear()
	_control_cooldowns.clear()
	_noise_pulses.clear()
	_flow_pops.clear()
	_gate = _level.get("gate", {}).duplicate(true)
	_gate_started = false
	_gate_remaining = 0.0
	_gate_closed = false
	_gate_body = null
	_scene_generation += 1
	_rollers.clear()
	_meeting.clear()
	_announced.clear()
	bounds_width = float(_level.get("width", VIEW_WIDTH))
	spawn_position = _level.get("spawn", Vector2(96.0, FLOOR_Y))
	goal_position = _level.get("goal", Vector2(bounds_width - 500.0, FLOOR_Y))
	view_left = 0.0
	view_right = minf(VIEW_WIDTH, bounds_width)
	_clock = 0.0
	_damaged.clear()
	_prop_bodies.clear()
	_tool_available.clear()
	_tool_fuel.clear()
	_coupon_taken.clear()
	_challenge_sent.clear()
	_water_spills.clear()
	_accident_effects.clear()
	_supervisor_alarm = 0.0
	_supervisor_cooldown = 0.0
	_warning_lock_time = 0.0
	_warning_restore_controls = false
	_bubble_cooldown = 0.0

	_copy_rows("ground", _ground)
	_copy_rows("ramps", _ramps)
	_copy_rows("platforms", _platforms)
	_copy_rows("furniture", _furniture)
	_copy_rows("props", _props)
	_copy_rows("tools", _tools)
	_copy_rows("coupons", _coupons)
	_copy_rows("wet_zones", _wet_zones)
	_copy_rows("mechanisms", _mechanisms)
	_copy_rows("route_signs", _route_signs)
	_copy_rows("npcs", _npcs)
	_copy_rows("busy_zones", _busy_zones)
	_copy_rows("controls", _controls)
	_clouds.clear()
	_supervisor = _level.get("supervisor", {}).duplicate(true)
	_supervisor_x = float(_supervisor.get("x", 0.0))
	_supervisor_direction = 1

	for tool in _tools:
		var tool_key: String = str(int(tool.get("id", -1)))
		_tool_available[tool_key] = true
		_tool_fuel[tool_key] = clampf(float(tool.get("fuel", 1.0)), 0.0, 1.0)
	for coupon in _coupons:
		var coupon_id: int = int(coupon.get("id", -1))
		_coupon_taken[str(coupon_id)] = already_collected.has(coupon_id)

	_rebuild_collision_geometry()
	if not _gate.is_empty():
		_gate_body = _add_rectangle_body(Vector2(float(_gate.x), float(_gate.y)-float(_gate.height)*0.5), Vector2(36,float(_gate.height)))
		_gate_body.get_child(0).disabled = true
	_create_actors()
	_background_cache_left = -1.0
	_background_cache_right = -1.0
	_background_cache_theme = -1
	_background_cache_view_size = Vector2.ZERO
	_background_clock_elapsed = 0.0
	_refresh_background_cache(true)
	set_process(active)
	set_physics_process(active)
	queue_redraw()


func _copy_rows(field: String, destination: Array[Dictionary]) -> void:
	destination.clear()
	var rows: Variant = _level.get(field, [])
	if not (rows is Array):
		return
	for row_value in rows:
		if row_value is Dictionary:
			var row: Dictionary = row_value.duplicate(true)
			destination.append(row)


func set_player(value: Node) -> void:
	player = value


func _player_position() -> Vector2:
	if not is_instance_valid(player):
		return spawn_position
	var value: Variant = player.get("position")
	if value is Vector2:
		return value
	return spawn_position


func _player_velocity() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var value: Variant = player.get("velocity")
	if value is Vector2:
		return value
	return Vector2.ZERO


func set_active(value: bool) -> void:
	active = value
	set_process(active)
	set_physics_process(active)
	if active:
		_refresh_background_cache()
	queue_redraw()


func surface_at(pos: Vector2) -> Dictionary:
	var result: Dictionary = {"wet": false, "belt": 0.0, "fan": 0.0, "slope": 0.0}
	for zone in _wet_zones:
		var zone_y: float = float(zone.get("y", FLOOR_Y))
		if pos.x >= float(zone.get("x1", 0.0)) and pos.x <= float(zone.get("x2", 0.0)) and absf(pos.y - zone_y) <= 78.0:
			result["wet"] = true
			break
	for spill in _water_spills:
		if pos.x >= float(spill.get("x1", 0.0)) and pos.x <= float(spill.get("x2", 0.0)) and absf(pos.y - float(spill.get("y", FLOOR_Y))) <= 78.0:
			result["wet"] = true
			break
	for mechanism in _mechanisms:
		var mechanism_y: float = float(mechanism.get("y", FLOOR_Y))
		if pos.x < float(mechanism.get("x1", 0.0)) or pos.x > float(mechanism.get("x2", 0.0)) or absf(pos.y - mechanism_y) > 110.0:
			continue
		var period: float = float(mechanism.get("period", 0.0))
		var phase: float = float(mechanism.get("phase", 0.0))
		var active_time: float = float(mechanism.get("active_time", period))
		var mechanism_kind: String = str(mechanism.get("kind", ""))
		var cycle_active: bool = period <= 0.0 or fposmod(_clock + phase, period) <= active_time
		if not cycle_active:
			continue
		if mechanism_kind == "belt":
			result["belt"] = clampf(float(mechanism.get("direction", 1.0)), -1.0, 1.0) * 180.0
		elif mechanism_kind == "fan":
			var fan_reach: float = 320.0
			var height_factor: float = clampf((mechanism_y - pos.y + 60.0) / fan_reach, 0.2, 1.0)
			result["fan"] = maxf(float(result.get("fan", 0.0)), clampf(float(mechanism.get("strength", 1.0)) * height_factor, 0.0, 1.0))
	for ramp in _ramps:
		var ramp_x1: float = float(ramp.get("x1", 0.0))
		var ramp_x2: float = float(ramp.get("x2", 0.0))
		if ramp_x2 <= ramp_x1 or pos.x < ramp_x1 or pos.x > ramp_x2:
			continue
		var ramp_y1: float = float(ramp.get("y1", FLOOR_Y))
		var ramp_y2: float = float(ramp.get("y2", FLOOR_Y))
		var local_ratio: float = (pos.x - ramp_x1) / (ramp_x2 - ramp_x1)
		var surface_y: float = lerpf(ramp_y1, ramp_y2, local_ratio)
		if absf(pos.y - surface_y) <= 72.0:
			result["slope"] = clampf((ramp_y2 - ramp_y1) / (ramp_x2 - ramp_x1), -1.0, 1.0)
			break
	return result


func safe_at(pos: Vector2) -> Vector2:
	var safe_points: Variant = _level.get("safe_points", [spawn_position])
	if not (safe_points is Array) or safe_points.is_empty():
		return spawn_position
	var nearest: Vector2 = spawn_position
	var nearest_distance: float = INF
	for point_value in safe_points:
		if not (point_value is Vector2):
			continue
		var point: Vector2 = point_value
		var distance: float = absf(point.x - pos.x) + absf(point.y - pos.y) * 0.35
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = point
	return nearest


func take_prop(pos: Vector2, required_kind: String = "") -> Dictionary:
	var best_index: int = -1
	var best_distance: float = 60.0
	for index in range(_tools.size()):
		var tool: Dictionary = _tools[index]
		if not required_kind.is_empty() and str(tool.get("kind", "")) != required_kind:
			continue
		var tool_key: String = str(int(tool.get("id", -1)))
		if not bool(_tool_available.get(tool_key, false)):
			continue
		var tool_pos: Vector2 = tool.get("pos", Vector2.ZERO)
		var distance: float = pos.distance_to(tool_pos)
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0:
		return {}
	var selected: Dictionary = _tools[best_index]
	var selected_id: int = int(selected.get("id", -1))
	var selected_key: String = str(selected_id)
	_tool_available[selected_key] = false
	queue_redraw()
	return {"id": selected_id, "kind": str(selected.get("kind", "")), "fuel": float(_tool_fuel.get(selected_key, 1.0))}


func take_attachment(_pos: Vector2, _unlocked: bool) -> Dictionary:
	return {}


func attachment_near(pos: Vector2) -> bool:
	for tool in _tools:
		if str(tool.get("kind", "")) == "extinguisher" and bool(_tool_available.get(str(int(tool.get("id", -1))), false)) and pos.distance_to(tool.get("pos", Vector2.ZERO)) <= 112.0:
			return true
	return false


func meeting_near(pos: Vector2) -> bool:
	return is_instance_valid(table) and absf(pos.x-table.position.x)<235 and absf(pos.y-table.position.y)<35


func board_near_meeting(_pos: Vector2) -> bool:
	return false


func release_prop(id: int, pos: Vector2, kind: String, fuel: float) -> void:
	var tool_index: int = -1
	for index in range(_tools.size()):
		if int(_tools[index].get("id", -1)) == id:
			tool_index = index
			break
	if tool_index < 0:
		return
	var drop_x: float = clampf(pos.x, 48.0, maxf(48.0, bounds_width - 48.0))
	var drop_y: float = pos.y
	_tools[tool_index]["pos"] = Vector2(drop_x, drop_y)
	_tools[tool_index]["kind"] = kind
	_tools[tool_index]["drop_velocity"] = _player_velocity()
	_tools[tool_index]["fall_speed"] = 0.0
	_tools[tool_index]["falling"] = true
	_tool_fuel[str(id)] = clampf(fuel, 0.0, 1.0)
	_tool_available[str(id)] = true
	queue_redraw()


func nearest_interaction(pos: Vector2) -> String:
	var best_text: String = ""
	var best_distance: float = 60.0
	for tool in _tools:
		var tool_key: String = str(int(tool.get("id", -1)))
		if not bool(_tool_available.get(tool_key, false)):
			continue
		var tool_pos: Vector2 = tool.get("pos", Vector2.ZERO)
		var distance: float = pos.distance_to(tool_pos)
		if distance > best_distance:
			continue
		best_distance = distance
		var kind: String = str(tool.get("kind", ""))
		if kind == "chair":
			best_text = "乘坐办公椅"
		elif kind == "extinguisher":
			best_text = "拿起灭火器"
		elif kind == "bucket":
			best_text = "乘坐拖把桶"
	return best_text


func goal_reachable(pos: Vector2) -> bool:
	return absf(pos.x-goal_position.x)<110 and absf(pos.y-goal_position.y)<35 and is_instance_valid(player) and player.is_on_floor()


func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	for index in range(_flow_pops.size() - 1, -1, -1):
		_flow_pops[index]["age"] = float(_flow_pops[index].age) + delta
		if float(_flow_pops[index].age) >= 0.8:
			_flow_pops.remove_at(index)
	_background_clock_elapsed += delta
	var refresh_background_clock: bool = _background_clock_elapsed >= BACKGROUND_CLOCK_REFRESH
	if refresh_background_clock:
		_background_clock_elapsed = fposmod(_background_clock_elapsed, BACKGROUND_CLOCK_REFRESH)
	_refresh_background_cache(false, refresh_background_clock)
	for index in range(_accident_effects.size() - 1, -1, -1):
		var effect: Dictionary = _accident_effects[index]
		var age: float = float(effect.get("age", 0.0)) + delta
		var kind: String = str(effect.get("kind", ""))
		if age > OfficeArt.accident_effect_lifetime(kind):
			_accident_effects.remove_at(index)
		else:
			effect["age"] = age
			_accident_effects[index] = effect
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return
	if is_instance_valid(player):
		var player_position: Vector2 = _player_position()
		_check_props(delta, player_position)
		_check_coupons(player_position)
		_check_challenge(player_position)
		_update_supervisor(delta, player_position)
	_update_comedy_objects(delta)
	_update_warning_lock(delta)
	_update_temporary_surfaces(delta)
	_update_tactics(delta)
	_bubble_cooldown = maxf(0.0, _bubble_cooldown - delta)
	queue_redraw()


func _check_props(delta: float, player_position: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var player_velocity: Vector2 = _player_velocity()
	var player_held: String = str(player.get("held"))
	var speed: float = absf(player_velocity.x)
	var player_center_y: float = player_position.y - 57.0
	for prop in _props:
		var prop_id: String = str(prop.get("id", ""))
		if prop_id.is_empty() or str(prop.get("kind",""))=="meeting" or bool(_damaged.get(prop_id, false)):
			continue
		var prop_position: Vector2 = Vector2(float(prop.get("x", 0.0)), float(prop.get("y", FLOOR_Y)))
		var size_value: Variant = prop.get("size", Vector2(64.0, 64.0))
		var prop_size: Vector2 = size_value if size_value is Vector2 else Vector2(64.0, 64.0)
		var collision_half_width: float = maxf(10.0, prop_size.x * 0.5)
		var collision_half_height: float = maxf(12.0, prop_size.y * 0.5)
		var prop_center_y: float = prop_position.y - prop_size.y * 0.5
		if absf(player_center_y - prop_center_y) > 57.0 + collision_half_height:
			continue
		var offset_x: float = prop_position.x - player_position.x
		if player_velocity.x * offset_x <= 0.0:
			continue
		var contact_gap: float = maxf(0.0, absf(offset_x) - (32.0 if player_held=="chair" else 28.0 if player_held=="bucket" else 22.0) - collision_half_width)
		if contact_gap > speed * delta + 2.0:
			continue
		var threshold: float = float(prop.get("threshold", 450.0))
		if speed < threshold:
			continue
		_break_prop(prop, signf(player_velocity.x), "player")
		if str(prop.get("challenge_kind", "")) == "chair_wall" and player_held == "chair":
			_emit_challenge("chair_wall")


func _break_prop(prop: Dictionary, direction: float, source: String, impact_speed: float = 0.0) -> void:
	var prop_id: String = str(prop.get("id", ""))
	if prop_id.is_empty() or bool(_damaged.get(prop_id, false)):
		return
	_damaged[prop_id] = true
	_disable_prop_collision(prop_id)
	var kind: String = str(prop.get("kind", "box"))
	var pos: Vector2 = Vector2(float(prop.get("x", 0.0)), float(prop.get("y", FLOOR_Y)))
	var size: Vector2 = prop.get("size", Vector2(64,64))
	var impact: Vector2 = pos - Vector2(0, size.y * 0.5)
	_add_accident_effect(kind, impact, prop_id)
	accident.emit(prop_id, kind, int(prop.get("cost", 30)), impact)
	for officer in officers:
		officer.hear(pos)
	if kind == "cooler":
		_water_spills.append({"origin":pos.x,"x1":pos.x-25,"x2":pos.x+25,"y":pos.y,"remaining":30.0,"age":0.0})
		_spawn_barrel.call_deferred(pos + Vector2(direction*65,-105), (impact_speed if absf(impact_speed)>0 else _player_velocity().x) * 0.65, _scene_generation)
		_comedy_event("water_slide", "饮用水改为交通用水", 120)
	if kind == "printer":
		_clouds.append({"pos":pos-Vector2(0,80),"remaining":3.5,"paper":true})
		_comedy_event("paper_cloud", "打印机吐的全是废话", 180)
	if source != "player":
		_comedy_event("chain_reaction", "物件撞物件，办公室连锁开路", 160)
		_comedy_event("chain_" + prop_id, "连锁事故：" + ("水桶开路" if source == "barrel" else "椅子开路" if source=="chair" else "会议桌开路"), 100)
	elif _bubble_cooldown <= 0.0 and not chaos_playground:
		bubble.emit("饮水机开始喷水！" if kind == "cooler" else "又出事故了！", impact)
		_bubble_cooldown = 1.0


func _comedy_event(id: String, label: String, points: int) -> void:
	if _announced.has(id):
		return
	_announced[id] = true
	if id in ["noise_lure","busy_escape","powder_escape","table_block","hr_skid"]:
		tactical_actions[id] = true
	elif id.begins_with("chain_"):
		tactical_actions["chain"] = true
	stunt.emit(id, label, points)
	bubble.emit(label, _player_position() - Vector2(0,140))


func _install_comedy_ramp(ramp: Dictionary, generation: int) -> void:
	if generation == _scene_generation and is_instance_valid(_collision_root):
		_add_ramp_body(ramp)


func _install_comedy_platform(platform: Dictionary, generation: int) -> void:
	if generation == _scene_generation and is_instance_valid(_collision_root):
		_add_rectangle_body(Vector2(float(platform.x) + float(platform.w) * 0.5, float(platform.y) + 12.0), Vector2(float(platform.w),24))


func meeting_info() -> Dictionary:
	return {"x":table.position.x,"y":table.position.y,"speed":table.velocity.x} if is_instance_valid(table) else {}


func _update_comedy_objects(delta: float) -> void:
	for i in range(_clouds.size()-1,-1,-1):
		_clouds[i]["remaining"] -= delta
		if float(_clouds[i].remaining)<=0:
			_clouds.remove_at(i)
	for tool in _tools:
		if not bool(tool.get("falling",false)) or not bool(_tool_available.get(str(int(tool.id)),false)):
			continue
		var pos: Vector2 = tool.pos
		var velocity: Vector2 = tool.get("drop_velocity",Vector2.ZERO)
		velocity.y += 980*delta
		var next: Vector2 = pos+velocity*delta
		var half_width: float = _tool_size(str(tool.kind)).x*0.5
		var direction: float = signf(velocity.x)
		if direction!=0:
			var side_ray := PhysicsRayQueryParameters2D.create(to_global(pos+Vector2(0,-22)),to_global(Vector2(next.x+direction*half_width,pos.y-22)),1)
			var side: Dictionary = get_world_2d().direct_space_state.intersect_ray(side_ray)
			if not side.is_empty() and absf(side.normal.x)>0.65:
				if bool(tool.get("launched",false)) and absf(velocity.x)>200:
					object_impact(side.collider, velocity.x, "chair")
					make_noise(to_local(side.position), true)
					tool["launched"] = false
				next.x=to_local(side.position).x-direction*half_width
				velocity.x=0
		var ray := PhysicsRayQueryParameters2D.create(to_global(Vector2(next.x,pos.y-25)),to_global(next+Vector2(0,3)),1)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			next = to_local(hit.position)
			velocity.y=0
			velocity.x += float(surface_at(next).get("slope",0))*980*delta
			velocity.x=move_toward(velocity.x,0,(130.0 if str(tool.kind)=="chair" else 300.0)*delta)
			if absf(velocity.x)<1:
				tool["falling"]=false
		tool["drop_velocity"]=velocity
		tool["pos"]=next
	if is_instance_valid(table):
		for officer in officers:
			if table.travelled>40 and officer.state in ["chase","search"] and absf(officer.position.x-table.position.x)<270 and officer.is_on_wall():
				_comedy_event("table_block", "会议没挡住工作，挡住了人事", 250)
				_emit_challenge("table_block")


func _check_coupons(player_position: Vector2) -> void:
	for coupon in _coupons:
		var coupon_id: int = int(coupon.get("id", -1))
		var coupon_key: String = str(coupon_id)
		if bool(_coupon_taken.get(coupon_key, false)):
			continue
		var coupon_pos: Vector2 = coupon.get("pos", Vector2.ZERO)
		if absf(player_position.x - coupon_pos.x) <= 54.0 and absf(player_position.y - coupon_pos.y) <= 68.0:
			_coupon_taken[coupon_key] = true
			collected.emit(coupon_id, coupon_pos)
			bubble.emit("午饭券到手！", coupon_pos + Vector2(0.0, -38.0))
			queue_redraw()


func _check_challenge(player_position: Vector2) -> void:
	if chaos_playground:
		if (tactical and player_position.x>790 and player_position.x<1980 and player_position.y<=410) or (not tactical and player_position.x > 2020.0 and player_position.x < 3010.0 and player_position.y <= 480.0):
			_comedy_event("upper_route", "走员工通道，绕开人事查岗", 150)
		if bool(surface_at(player_position).get("wet",false)) and str(player.get("held")) == "chair" and absf(_player_velocity().x)>350.0:
			_comedy_event("water_surf", "办公椅水上乐园正式营业", 150)
	if str(_level.get("challenge_kind", "")) != "balcony" or not is_instance_valid(player):
		return
	var balcony: Dictionary = _level.get("balcony", {})
	if balcony.is_empty():
		return
	var x1: float = float(balcony.get("x1", 0.0))
	var x2: float = float(balcony.get("x2", 0.0))
	var height: float = float(balcony.get("y", 400.0))
	if player_position.x >= x1 and player_position.x <= x2 and player_position.y <= height + 70.0:
		_emit_challenge("balcony")


func _emit_challenge(kind: String) -> void:
	if bool(_challenge_sent.get(kind, false)):
		return
	_challenge_sent[kind] = true
	challenge_event.emit(kind)


func _update_supervisor(delta: float, player_position: Vector2) -> void:
	if _supervisor.is_empty():
		return
	_supervisor_cooldown = maxf(0,_supervisor_cooldown-delta)
	var seen: bool = absf(player_position.x-_supervisor_x)<220 and absf(player_position.y-_ground_y_at(_supervisor_x))<80
	if seen and (player.busy or absf(player.velocity.x)>420):
		_supervisor_alarm += delta
		if _supervisor_alarm>1.5 and _supervisor_cooldown<=0:
			_supervisor_cooldown=4
			_supervisor_alarm=0
			supervisor_warning.emit()
			bubble.emit("日报都没写完，还想提前下班？",Vector2(_supervisor_x,430))
			for officer in officers:
				officer.hear(player_position)
	else:
		_supervisor_alarm=0


func _update_warning_lock(delta: float) -> void:
	if _warning_lock_time <= 0.0:
		return
	_warning_lock_time = maxf(0.0, _warning_lock_time - delta)
	if _warning_lock_time > 0.0 or not _warning_restore_controls:
		return
	if is_instance_valid(player) and bool(player.get("simulation_enabled")):
		player.set("controls_enabled", true)
		if str(player.get("pose_override")) == "late":
			player.set("pose_override", "")
	_warning_restore_controls = false


func _update_temporary_surfaces(delta: float) -> void:
	for index in range(_water_spills.size() - 1, -1, -1):
		var spill: Dictionary = _water_spills[index]
		var remaining: float = float(spill.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			_water_spills.remove_at(index)
		else:
			spill["remaining"] = remaining
			spill["age"] = float(spill.get("age",0))+delta
			var spread: float = minf(300,25+float(spill.age)*70)
			spill["x1"]=float(spill.origin)-spread
			spill["x2"]=float(spill.origin)+spread
			_water_spills[index] = spill


func _ground_y_at(x: float) -> float:
	for ramp in _ramps:
		var x1: float = float(ramp.get("x1", 0.0))
		var x2: float = float(ramp.get("x2", 0.0))
		if x2 > x1 and x >= x1 and x <= x2:
			var ratio: float = (x - x1) / (x2 - x1)
			return lerpf(float(ramp.get("y1", FLOOR_Y)), float(ramp.get("y2", FLOOR_Y)), ratio)
	for segment in _ground:
		if x >= float(segment.get("x1", 0.0)) and x <= float(segment.get("x2", bounds_width)):
			return float(segment.get("y", FLOOR_Y))
	return FLOOR_Y


func _rebuild_collision_geometry() -> void:
	if is_instance_valid(_collision_root):
		remove_child(_collision_root)
		_collision_root.free()
	_collision_root = Node2D.new()
	_collision_root.name = "TerrainCollisions"
	add_child(_collision_root)
	for segment in _ground:
		var x1: float = float(segment.get("x1", 0.0))
		var x2: float = float(segment.get("x2", bounds_width))
		var y: float = float(segment.get("y", FLOOR_Y))
		_add_rectangle_body(Vector2((x1 + x2) * 0.5, y + FLOOR_DEPTH * 0.5), Vector2(maxf(1.0, x2 - x1), FLOOR_DEPTH))
	for platform in _platforms:
		var width: float = float(platform.get("w", 240.0))
		var top: float = float(platform.get("y", FLOOR_Y - 40.0))
		var thickness: float = float(platform.get("thickness",28.0))
		_add_rectangle_body(Vector2(float(platform.get("x", 0.0)) + width * 0.5, top + thickness * 0.5), Vector2(width, thickness))
	for ramp in _ramps:
		_add_ramp_body(ramp)
	_add_rectangle_body(Vector2(-34.0, 280.0), Vector2(68.0, 1200.0))
	_add_rectangle_body(Vector2(bounds_width + 34.0, 280.0), Vector2(68.0, 1200.0))
	for prop in _props:
		if str(prop.get("kind",""))=="meeting":
			continue
		var prop_id: String = str(prop.get("id", ""))
		var size: Vector2 = prop.get("size", Vector2(64.0, 64.0))
		var pos: Vector2 = Vector2(float(prop.get("x", 0.0)), float(prop.get("y", FLOOR_Y)))
		var body: StaticBody2D = _add_rectangle_body(Vector2(pos.x, pos.y - size.y * 0.5), size)
		_prop_bodies[prop_id] = body


func _add_rectangle_body(center: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.position = center
	body.add_child(collision)
	_collision_root.add_child(body)
	return body


func _add_ramp_body(ramp: Dictionary) -> void:
	var x1: float = float(ramp.get("x1", 0.0))
	var x2: float = float(ramp.get("x2", x1 + 1.0))
	var y1: float = float(ramp.get("y1", FLOOR_Y))
	var y2: float = float(ramp.get("y2", FLOOR_Y))
	var width: float = maxf(1.0, x2 - x1)
	var rise: float = y2 - y1
	var depth: float = 190.0
	var body: StaticBody2D = StaticBody2D.new()
	var polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2.ZERO, Vector2(width, rise), Vector2(width, rise + depth), Vector2(0.0, depth)])
	body.position = Vector2(x1, y1)
	body.add_child(polygon)
	_collision_root.add_child(body)


func _disable_prop_collision(prop_id: String) -> void:
	var body_value: Variant = _prop_bodies.get(prop_id)
	if not is_instance_valid(body_value):
		return
	var body: StaticBody2D = body_value
	for child in body.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", true)


func _draw() -> void:
	if Engine.is_editor_hint():
		return
	var left: float = clampf(view_left, 0.0, bounds_width)
	var right: float = clampf(view_right, left, bounds_width)
	_draw_terrain(left, right)
	_draw_environment_objects(left, right)
	_draw_tactics(left, right)
	for pop in _flow_pops:
		var age: float = float(pop.age)
		var at: Vector2 = pop.pos + Vector2(-36.0, -126.0 - age * 38.0)
		draw_string(OFFICE_FONT, at + Vector2(2,2), "+%d" % int(pop.points), HORIZONTAL_ALIGNMENT_LEFT, 120, 22, Color(0.15,0.2,0.29,1.0-age/0.8))
		draw_string(OFFICE_FONT, at, "+%d" % int(pop.points), HORIZONTAL_ALIGNMENT_LEFT, 120, 22, Color(1.0,0.81,0.27,1.0-age/0.8))


func show_flow(points: int, at: Vector2) -> void:
	if not tactical:
		return
	if not _flow_pops.is_empty() and at.distance_to(_flow_pops.back().pos) < 100.0:
		_flow_pops.back()["points"] = int(_flow_pops.back().points) + points
		_flow_pops.back()["age"] = 0.0
	else:
		_flow_pops.append({"points": points, "pos": at, "age": 0.0})
	if _flow_pops.size() > 3:
		_flow_pops.pop_front()


func _refresh_background_cache(force: bool = false, refresh_clock: bool = false) -> void:
	if not is_instance_valid(_background_painter):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var requested_left: float = clampf(view_left - BACKGROUND_OVERSCAN, 0.0, bounds_width)
	var requested_right: float = clampf(view_right + BACKGROUND_OVERSCAN, requested_left, bounds_width)
	var cache_left: float = clampf(floor(requested_left / BACKGROUND_CHUNK_SIZE) * BACKGROUND_CHUNK_SIZE, 0.0, bounds_width)
	var cache_right: float = clampf(ceil(requested_right / BACKGROUND_CHUNK_SIZE) * BACKGROUND_CHUNK_SIZE, cache_left, bounds_width)
	if cache_right <= cache_left and cache_left < bounds_width:
		cache_right = minf(bounds_width, cache_left + BACKGROUND_CHUNK_SIZE)
	var theme: int = int(_level.get("theme", 0))
	var changed: bool = force or cache_left != _background_cache_left or cache_right != _background_cache_right or theme != _background_cache_theme or viewport_size != _background_cache_view_size
	if not changed and not refresh_clock:
		return
	_background_painter.call("configure", cache_left, cache_right, theme, _clock)
	_background_cache_left = cache_left
	_background_cache_right = cache_right
	_background_cache_theme = theme
	_background_cache_view_size = viewport_size


func _draw_terrain(left: float, right: float) -> void:
	for segment in _ground:
		var x1: float = float(segment.get("x1", 0.0))
		var x2: float = float(segment.get("x2", bounds_width))
		if x2 < left or x1 > right:
			continue
		var y: float = float(segment.get("y", FLOOR_Y))
		draw_rect(Rect2(x1, y, x2 - x1, FLOOR_DEPTH), FLOOR_COLOR)
		if tactical:
			draw_rect(Rect2(x1, y + 5.0, x2 - x1, 10.0), Color("c8b99e"))
			var tile_x: float = floorf(x1 / 120.0) * 120.0
			while tile_x < x2:
				draw_line(Vector2(tile_x, y + 16.0), Vector2(tile_x - 28.0, y + FLOOR_DEPTH), Color(0.45,0.39,0.3,0.14), 1.0)
				tile_x += 120.0
		draw_line(Vector2(x1, y), Vector2(x2, y), FLOOR_EDGE_COLOR, 5.0, true)
	for ramp in _ramps:
		var x1: float = float(ramp.get("x1", 0.0))
		var x2: float = float(ramp.get("x2", 0.0))
		if x2 < left or x1 > right:
			continue
		var y1: float = float(ramp.get("y1", FLOOR_Y))
		var y2: float = float(ramp.get("y2", FLOOR_Y))
		var points: PackedVector2Array = PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2), Vector2(x2, y2 + 190.0), Vector2(x1, y1 + 190.0)])
		draw_colored_polygon(points, FLOOR_COLOR)
		draw_line(Vector2(x1, y1), Vector2(x2, y2), FLOOR_EDGE_COLOR, 5.0, true)
		if bool(ramp.get("paper",false)):
			draw_colored_polygon(points,Color("fff9ee"))
			for i in range(12):
				var paper_x: float = lerpf(x1,x2,float(i)/12.0)
				var paper_y: float = lerpf(y1,y2,float(i)/12.0)
				draw_line(Vector2(paper_x,paper_y+3),Vector2(paper_x+13,paper_y+14),Color("afc5cf"),2,true)
			draw_line(Vector2(x1,y1),Vector2(x2,y2),Color("e9bd4a"),5,true)
	for platform in _platforms:
		var x: float = float(platform.get("x", 0.0))
		var width: float = float(platform.get("w", 240.0))
		var y: float = float(platform.get("y", FLOOR_Y - 40.0))
		var thickness: float = float(platform.get("thickness",28.0))
		if x + width < left or x > right:
			continue
		for support in range(0,int(width),160):
			var support_x: float = x+support+15
			draw_line(Vector2(support_x,y+thickness),Vector2(support_x,FLOOR_Y),Color(0.40,0.48,0.52,0.40),6,true)
			draw_line(Vector2(support_x,y+thickness),Vector2(support_x+35,y+thickness+27),Color(0.40,0.48,0.52,0.40),4,true)
		draw_rect(Rect2(x + 5.0, y + thickness, width, 7.0), Color(0.17,0.23,0.29,0.10))
		draw_rect(Rect2(x, y, width, thickness), PLATFORM_COLOR)
		if tactical:
			draw_line(Vector2(x+4.0,y+7.0),Vector2(x+width-4.0,y+7.0),Color("f6ead2"),3.0,true)
		draw_line(Vector2(x, y), Vector2(x + width, y), FLOOR_EDGE_COLOR, 5.0, true)
		if bool(platform.get("drawer",false)):
			draw_string(OFFICE_FONT,Vector2(x+12,y+21),"弹出的抽屉",HORIZONTAL_ALIGNMENT_LEFT,width-24,15,FLOOR_EDGE_COLOR)
	for zone in _wet_zones:
		var x1: float = float(zone.get("x1", 0.0))
		var x2: float = float(zone.get("x2", 0.0))
		var y: float = float(zone.get("y", FLOOR_Y))
		if x2 < left or x1 > right:
			continue
		draw_rect(Rect2(x1, y - 12.0, x2 - x1, 20.0), WET_COLOR)
		draw_line(Vector2(x1, y - 8.0), Vector2(x2, y - 8.0), Color("55aaa4"), 3.0, true)
	for spill in _water_spills:
		var x1: float = float(spill.get("x1", 0.0))
		var x2: float = float(spill.get("x2", 0.0))
		if x2 >= left and x1 <= right:
			draw_rect(Rect2(x1, float(spill.y) - 6.0, x2 - x1, 10.0), WET_COLOR)
			draw_line(Vector2(x1, float(spill.y) - 3.0), Vector2(x2, float(spill.y) - 3.0), Color("55aaa4"), 3.0, true)
			if tactical:
				for ripple in range(4):
					var ripple_x: float = lerpf(x1,x2,(ripple+0.5)/4.0)
					draw_line(Vector2(ripple_x-12.0,float(spill.y)-2.0),Vector2(ripple_x+12.0,float(spill.y)-2.0),Color(0.94,1.0,0.94,0.65),2.0,true)


func _draw_environment_objects(left: float, right: float) -> void:
	for furniture in _furniture:
		var x: float = float(furniture.get("x", 0.0))
		if x < left - 280.0 or x > right + 280.0:
			continue
		draw_set_transform(Vector2(0,-55))
		OfficeArt.draw_prop(self, str(furniture.get("kind", "desk")), Vector2(x, float(furniture.get("y", FLOOR_Y))), furniture.get("size", Vector2(180.0, 140.0)), false, _clock)
		draw_set_transform(Vector2.ZERO)
	for prop in _props:
		var x: float = float(prop.get("x", 0.0))
		if x < left - 220.0 or x > right + 220.0:
			continue
		var prop_id: String = str(prop.get("id", ""))
		if str(prop.get("kind", "")) == "meeting":
			continue
		OfficeArt.draw_prop(self, str(prop.get("kind", "box")), Vector2(x, float(prop.get("y", FLOOR_Y))), prop.get("size", Vector2(64.0, 64.0)), bool(_damaged.get(prop_id, false)), _clock)
	for tool in _tools:
		var tool_key: String = str(int(tool.get("id", -1)))
		if not bool(_tool_available.get(tool_key, false)):
			continue
		var tool_pos: Vector2 = tool.get("pos", Vector2.ZERO)
		if tool_pos.x < left - 160.0 or tool_pos.x > right + 160.0:
			continue
		var tool_kind: String = str(tool.get("kind", "chair"))
		var fuel_value: float = float(_tool_fuel.get(tool_key, 1.0))
		if tactical and absf(tool_pos.x - _player_position().x) < 110.0 and absf(tool_pos.y - _player_position().y) < 80.0:
			draw_arc(tool_pos + Vector2(0.0,-8.0), 32.0, PI * 0.15, PI * 0.85, 20, Color("e9bd4a"), 3.0, true)
		OfficeArt.draw_prop(self, tool_kind, tool_pos, _tool_size(tool_kind), fuel_value <= 0.0, _clock)
	for coupon in _coupons:
		var coupon_pos: Vector2 = coupon.get("pos", Vector2.ZERO)
		if coupon_pos.x < left - 80.0 or coupon_pos.x > right + 80.0:
			continue
		var coupon_key: String = str(int(coupon.get("id", -1)))
		OfficeArt.draw_coupon(self, coupon_pos, bool(_coupon_taken.get(coupon_key, false)), _clock)
	for mechanism in _mechanisms:
		var x1: float = float(mechanism.get("x1", 0.0))
		var x2: float = float(mechanism.get("x2", x1))
		if x2 < left - 120.0 or x1 > right + 120.0:
			continue
		var kind: String = str(mechanism.get("kind", "fan"))
		var size: Vector2 = Vector2(maxf(120.0, x2 - x1), 100.0)
		OfficeArt.draw_prop(self, kind, Vector2((x1 + x2) * 0.5, float(mechanism.get("y", FLOOR_Y))), size, false, _clock)
	for npc in _npcs:
		var npc_pos: Vector2 = Vector2(float(npc.get("x", 0.0)), float(npc.get("y", FLOOR_Y)))
		if npc_pos.x < left - 140.0 or npc_pos.x > right + 140.0:
			continue
		OfficeArt.draw_npc(self, npc_pos, str(npc.get("kind", "coworker")), int(npc.get("facing", 1)), _clock)
	if not _supervisor.is_empty() and _supervisor_x >= left - 180.0 and _supervisor_x <= right + 180.0:
		OfficeArt.draw_npc(self, Vector2(_supervisor_x, _ground_y_at(_supervisor_x)-55), "supervisor", _supervisor_direction, _clock, clampf(_supervisor_alarm, 0.0, 1.0))
	if goal_position.x >= left - 300.0 and goal_position.x <= right + 300.0:
		OfficeArt.draw_prop(self, "desk", goal_position + Vector2(178.0, 0.0), Vector2(250.0, 158.0), false, _clock)
		draw_line(goal_position + Vector2(0.0, -36.0), goal_position + Vector2(0.0, -90.0), Color("e9bd4a"), 5.0, true)
		draw_circle(goal_position + Vector2(0.0, -100.0), 10.0, Color("e9bd4a"))
		if chaos_playground:
			draw_rect(Rect2(goal_position+Vector2(43,-112),Vector2(46,48)),FLOOR_EDGE_COLOR)
			draw_rect(Rect2(goal_position+Vector2(48,-107),Vector2(36,23)),Color("55aaa4"))
			draw_string(OFFICE_FONT,goal_position+Vector2(46,-90),"打卡",HORIZONTAL_ALIGNMENT_CENTER,40,13,Color("fff9ee"))
	for sign in _route_signs:
		if tactical:
			continue
		var x: float = float(sign.get("x", 0.0))
		if x < left - 120.0 or x > right + 120.0:
			continue
		draw_line(Vector2(x, 534.0), Vector2(x, 492.0), FLOOR_EDGE_COLOR, 3.0, true)
		draw_line(Vector2(x - 9.0, 503.0), Vector2(x, 492.0), FLOOR_EDGE_COLOR, 3.0, true)
		draw_line(Vector2(x + 9.0, 503.0), Vector2(x, 492.0), FLOOR_EDGE_COLOR, 3.0, true)
		var sign_y: float = float(sign.get("y", 482.0))
		if chaos_playground:
			draw_rect(Rect2(x - 112.0, sign_y - 25.0, 224.0, 35.0), Color("f5ebd8"))
		draw_string(OFFICE_FONT, Vector2(x - 112.0, sign_y), str(sign.get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, 224.0, 17, FLOOR_EDGE_COLOR)
	for zone in _busy_zones:
		var x: float = float(zone.x)
		draw_rect(Rect2(x-70,593,140,7),Color("55aaa4"))
		if not tactical:
			draw_string(OFFICE_FONT,Vector2(x-100,416),"Q 装忙 · 人事会核查",HORIZONTAL_ALIGNMENT_CENTER,200,16,FLOOR_EDGE_COLOR)
	for cloud in _clouds:
		var at: Vector2 = cloud.pos
		var opacity: float = minf(0.85,float(cloud.remaining))
		if bool(cloud.get("paper",false)):
			for i in range(14):
				var offset := Vector2(sin(i*3.1+_clock)*90,cos(i*1.7+_clock*2)*65)
				draw_rect(Rect2(at+offset,Vector2(23,14)),Color(1,0.98,0.93,opacity))
		else:
			for i in range(7):
				draw_circle(at+Vector2(sin(i*2.3)*55,cos(i*2.1)*38),35,Color(0.97,0.97,0.9,opacity*0.7))
	for effect in _accident_effects:
		var effect_pos_value: Variant = effect.get("pos", Vector2.ZERO)
		var effect_pos: Vector2 = effect_pos_value if effect_pos_value is Vector2 else Vector2.ZERO
		OfficeArt.draw_accident_effect(self, str(effect.get("kind", "")), effect_pos, float(effect.get("age", 0.0)), int(effect.get("seed", 0)))


func _add_accident_effect(kind: String, pos: Vector2, effect_id: String) -> void:
	_accident_effects.append({"kind": kind, "pos": pos, "age": 0.0, "seed": int(hash(effect_id))})


func _tool_size(kind: String) -> Vector2:
	if kind == "chair":
		return Vector2(82.0, 118.0)
	if kind == "extinguisher":
		return Vector2(54.0, 104.0)
	return Vector2(84.0, 96.0)


func _create_actors() -> void:
	if is_instance_valid(_actors_root):
		remove_child(_actors_root)
		_actors_root.free()
	officers.clear()
	objects.clear()
	table = null
	_actors_root=Node2D.new()
	add_child(_actors_root)
	for row in _level.get("hr",[]):
		var officer = HR_SCRIPT.new()
		officer.office=self
		officer.position=supported_spawn_at(row.pos,110.0)
		officer.patrol_left=float(row.get("left",row.pos.x-150))
		officer.patrol_right=float(row.get("right",row.pos.x+150))
		_actors_root.add_child(officer)
		officers.append(officer)
		officer.caught.connect(func(): hr_caught.emit())
	for prop in _props:
		if str(prop.get("kind",""))=="meeting":
			table=OBJECT_SCRIPT.new()
			table.office=self
			table.position=Vector2(float(prop.x),float(prop.y))
			_actors_root.add_child(table)
			objects.append(table)


func _spawn_barrel(pos: Vector2, speed: float, generation: int) -> void:
	if generation!=_scene_generation:
		return
	var barrel = OBJECT_SCRIPT.new()
	barrel.office=self
	barrel.kind="barrel"
	barrel.position=pos
	barrel.velocity.x=speed
	_actors_root.add_child(barrel)
	objects.append(barrel)


func object_impact(body: Object, speed: float, kind: String) -> void:
	for prop in _props:
		var id: String = str(prop.id)
		var threshold: float = float(prop.get("threshold",450)) if kind=="player" else float(prop.get("chain_threshold",float(prop.get("threshold",450))*0.65))
		if _prop_bodies.get(id)==body and absf(speed)>=threshold:
			_break_prop(prop,signf(speed),kind,speed)
			break


func push_table(pos: Vector2, axis: float) -> bool:
	if not is_instance_valid(table) or absf(pos.y-table.position.y)>30 or absf(axis)<0.01:
		return false
	var offset: float = table.position.x-pos.x
	if absf(offset)<225 and absf(offset)>170 and offset*axis>0:
		table.shove=axis
		return true
	return false


func busy_near(pos: Vector2) -> bool:
	for zone in _busy_zones:
		if absf(pos.x-float(zone.x))<70 and absf(pos.y-float(zone.get("y",600)))<20:
			return true
	return false


func spray_at(pos: Vector2, facing: int, _delta: float) -> void:
	var threatened: Array = []
	for officer in officers:
		if officer.state in ["notice","chase","grab","search"] and officer.position.distance_to(pos)<600 and officer.clear_sight(pos):
			threatened.append(officer)
	var at: Vector2 = pos+Vector2(facing*80,-65)
	if _clouds.is_empty() or at.distance_to(_clouds.back().pos)>45 or bool(_clouds.back().get("paper",false)):
		_clouds.append({"pos":at,"remaining":1.4,"paper":false})
	else:
		_clouds.back()["remaining"]=1.4
	_comedy_event("powder_cover","消防演习，人事暂时看不清",150)
	if not threatened.is_empty():
		for officer in threatened:
			if not officer.clear_sight(pos):
				_comedy_event("powder_escape","粉末挡住查岗，通道留给自己",220)


func vision_obscured(a: Vector2, b: Vector2) -> bool:
	for cloud in _clouds:
		var at: Vector2 = cloud.pos
		if Geometry2D.get_closest_point_to_segment(at,a+Vector2(0,-70),b+Vector2(0,-70)).distance_to(at)<85:
			return true
	return false


func hr_status() -> String:
	var nearest: Node2D
	var distance: float = INF
	for officer in officers:
		var gap: float = officer.position.distance_to(_player_position())
		if gap<distance:
			distance=gap
			nearest=officer
	if nearest==null:
		return "人事还没上班"
	if nearest.state=="grab":
		return "人事正在抓你！快离开！"
	var states: Dictionary = {"patrol":"巡查","notice":"发现你了","inspect":"正在核查日报","chase":"追赶中","search":"寻找你","noise":"查看事故"}
	if nearest.get("slip_remaining")>0:
		return "人事脚下打滑 · 趁现在离开"
	return "人事 "+str(states.get(nearest.state,"登记中"))+" · "+str(int(distance/10))+"步"


func control_hint(pos: Vector2) -> String:
	for control in _controls:
		if pos.distance_to(control.pos)<85:
			return str(control.label)
	return ""


func use_control(pos: Vector2) -> bool:
	if not active:
		return false
	for control in _controls:
		if pos.distance_to(control.pos)>=85:
			continue
		var id: String = str(control.id)
		if float(_control_cooldowns.get(id,0))>0:
			bubble.emit("设备正在复位，稍等一下",pos)
			return true
		_control_cooldowns[id]=3.0 if id=="copy" else 1.0
		if id=="gate":
			_gate_started=true
			_gate_remaining=4.0
			_set_gate_closed(false)
			make_noise(control.target,false)
			_comedy_event("gate_dash","门禁只放行四秒，考勤不等人",120)
		else:
			make_noise(control.target,true)
			_clouds.append({"pos":control.target-Vector2(0,80),"remaining":2.2,"paper":true})
			bubble.emit("复印机出纸了，人事过去查看",control.target)
		return true
	return false


func launch_tool(id: int, direction: int) -> void:
	for tool in _tools:
		if int(tool.id)==id:
			tool["drop_velocity"]=Vector2(direction*700.0,-80)
			tool["falling"]=true
			tool["launched"]=true
			bubble.emit("椅子先去探路，我随后再说",tool.pos)
			break


func make_noise(at: Vector2, diversion: bool) -> void:
	_noise_pulses.append({"pos":at-Vector2(0,60),"age":0.0})
	hr_alert.emit()
	var attracted: bool = false
	for officer in officers:
		attracted=officer.hear(at,diversion) or attracted
	if attracted and diversion:
		_comedy_event("noise_lure","人事去查动静，员工另走一边",180)


func _set_gate_closed(closed: bool) -> void:
	_gate_closed=closed
	if is_instance_valid(_gate_body):
		_gate_body.get_child(0).set_deferred("disabled",not closed)


func _update_tactics(delta: float) -> void:
	for id in _control_cooldowns:
		_control_cooldowns[id]=maxf(0,float(_control_cooldowns[id])-delta)
	for index in range(_noise_pulses.size()-1,-1,-1):
		_noise_pulses[index].age+=delta
		if float(_noise_pulses[index].age)>1.2:
			_noise_pulses.remove_at(index)
	if _gate.is_empty() or not is_instance_valid(player):
		return
	if not _gate_started and player.position.x>float(_gate.trigger):
		_gate_started=true
		_gate_remaining=float(_gate.warning)
		bubble.emit("临时查岗！门禁即将关闭，开门或走上层",player.position)
		hr_alert.emit()
		var officer=officers.back()
		officer.hear(Vector2(float(_gate.x)+95,600),false)
	if _gate_started and not _gate_closed:
		_gate_remaining=maxf(0,_gate_remaining-delta)
		if _gate_remaining<=0:
			var occupied: bool = absf(player.position.x-float(_gate.x))<60 and player.position.y>float(_gate.y)-float(_gate.height)
			for officer in officers:
				occupied=occupied or (absf(officer.position.x-float(_gate.x))<50 and officer.position.y>float(_gate.y)-float(_gate.height))
			if not occupied:
				_set_gate_closed(true)


func _draw_tactics(left: float, right: float) -> void:
	for control in _controls:
		var pos: Vector2 = control.pos
		if pos.x<left-120 or pos.x>right+120:
			continue
		var ready: bool = float(_control_cooldowns.get(str(control.id),0))<=0
		draw_rect(Rect2(pos+Vector2(-21,-88),Vector2(42,50)),FLOOR_EDGE_COLOR)
		draw_circle(pos+Vector2(0,-65),12,Color("55aaa4") if ready else Color("d6a250"))
		if not tactical:
			draw_rect(Rect2(pos+Vector2(-112,-142),Vector2(224,30)),Color("f5ebd8"))
			draw_string(OFFICE_FONT,pos+Vector2(-100,-120),str(control.label),HORIZONTAL_ALIGNMENT_CENTER,200,15,FLOOR_EDGE_COLOR)
		else:
			draw_string(OFFICE_FONT,pos+Vector2(-20,-98),"复印" if str(control.id) == "copy" else "门禁",HORIZONTAL_ALIGNMENT_CENTER,40,12,FLOOR_EDGE_COLOR)
	for pulse in _noise_pulses:
		var age: float = float(pulse.age)
		draw_arc(pulse.pos,30+age*65,0,TAU,32,Color(0.89,0.55,0.18,1-age/1.2),3,true)
	if _gate.is_empty() or float(_gate.x)<left-220 or float(_gate.x)>right+220:
		return
	var x: float = float(_gate.x)
	var y: float = float(_gate.y)
	var top: float = y-float(_gate.height)
	draw_rect(Rect2(x-26,top-18,52,18),FLOOR_EDGE_COLOR)
	draw_line(Vector2(x-24,top),Vector2(x-24,y),Color("8e8795"),4,true)
	draw_line(Vector2(x+24,top),Vector2(x+24,y),Color("8e8795"),4,true)
	if _gate_closed:
		draw_rect(Rect2(x-18,top,36,y-top),Color("d6a250"))
		for stripe in range(12):
			draw_line(Vector2(x-18,top+stripe*20),Vector2(x+18,top+stripe*20+12),FLOOR_EDGE_COLOR,3,true)
	var label: String = "临检门禁" if not _gate_started else "临检中 · 上层绕行" if _gate_closed else "放行 %.1f 秒" % _gate_remaining
	draw_string(OFFICE_FONT,Vector2(x-110,top-38),label,HORIZONTAL_ALIGNMENT_CENTER,220,17,Color("be543d") if _gate_closed else FLOOR_EDGE_COLOR)


func supported_spawn_at(pos: Vector2, height: float) -> Vector2:
	var feet: float = _ground_y_at(pos.x)
	for pass_index in range(4):
		for platform in _platforms:
			var top: float = float(platform.y)
			if pos.x+19>float(platform.x) and pos.x-19<float(platform.x)+float(platform.w) and top<feet and top+float(platform.get("thickness",28))>feet-height:
				feet=top
		for prop in _props:
			var size: Vector2 = prop.get("size",Vector2(64,64))
			var top: float = float(prop.y)-size.y
			if absf(pos.x-float(prop.x))<size.x*0.5+19 and top<feet and float(prop.y)>feet-height:
				feet=top
	return Vector2(pos.x,feet)


func navigation_detour(at: Vector2, target: Vector2) -> Array:
	for route in _level.get("hr_detours",[]):
		if at.x<float(route.x1) and target.x>float(route.x2) and float(route.x1)-at.x<150:
			return route.left.duplicate()
		if at.x>float(route.x2) and target.x<float(route.x1) and at.x-float(route.x2)<160:
			return route.right.duplicate()
	return []
