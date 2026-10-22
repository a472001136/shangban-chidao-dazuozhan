extends CharacterBody2D

signal caught

var office: Node2D
var patrol_left: float
var patrol_right: float
var facing: int = -1
var state: String = "patrol"
var notice: float = 0.0
var grab: float = 0.0
var inspection: float = 0.0
var memory: float = 0.0
var last_seen: Vector2
var noise_target: Vector2
var noise_time: float = 0.0
var clock: float = 0.0
var jump_cooldown: float = 0.0
var obstacle_wait: float = 0.0
var escaped_busy: bool = false
var had_chase: bool = false
var detour: Array = []
var detour_age: float = 0.0
var blocked_seconds: float = 0.0
var avoid_seconds: float = 0.0
var avoid_facing: int = 1
var noise_focus: float = 0.0
var slip_remaining: float = 0.0
var slip_cooldown: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 12.0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(38, 110)
	shape.shape = rectangle
	shape.position.y = -55
	add_child(shape)

func hear(at: Vector2, diversion: bool = false) -> bool:
	if position.distance_to(at) < 800.0 and state != "caught":
		noise_target = at
		noise_time = 5.0
		if diversion and state not in ["chase","grab"]:
			noise_focus = 4.0
			memory = 0
			notice = 0
			state = "noise"
			return true
	return false

func clear_sight(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-78), office.to_global(target + Vector2(0,-65)), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty() and not office.vision_obscured(position, target)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(office) or not office.active:
		return
	var previous_x: float = position.x
	var move_intent: float = 0.0
	clock += delta
	avoid_seconds=maxf(0,avoid_seconds-delta)
	jump_cooldown = maxf(0, jump_cooldown - delta)
	noise_time = maxf(0, noise_time - delta)
	noise_focus = maxf(0,noise_focus-delta)
	slip_cooldown = maxf(0,slip_cooldown-delta)
	slip_remaining = maxf(0,slip_remaining-delta)
	var employee = office.player
	if not is_instance_valid(employee):
		return
	var offset: Vector2 = employee.position - position
	var busy: bool = employee.busy
	var visible: bool = absf(offset.x) < 480 and absf(offset.y) < 180 and clear_sight(employee.position) and avoid_seconds<=0 and (noise_focus<=0 or absf(offset.x)<120)
	var in_front: bool = offset.x * facing >= -25
	var running: bool = employee._started_once
	var destination: float = position.x
	var speed: float = 80
	if state == "caught":
		velocity.x = 0
	elif running and visible and (in_front or memory > 0):
		last_seen = employee.position
		memory = 4.5
		if (busy or state=="inspect") and absf(offset.x) < 360 and state not in ["chase","grab","search"] and inspection<=2.3:
			state = "inspect"
			inspection += delta
			destination = employee.position.x - signf(offset.x) * 115 if busy else position.x
			if inspection > 2.3:
				state = "chase"
				office.bubble.emit("这份日报怎么只有一行？站住！", position - Vector2(0,150))
		else:
			if state != "chase" and state != "grab":
				notice += delta
				state = "notice"
				if notice > 0.55:
					state = "chase"
					office.hr_alert.emit()
					office.bubble.emit("工牌呢？还没打卡的别跑！", position - Vector2(0,150))
			else:
				state = "chase"
			destination = employee.position.x
			speed = (335.0 if employee.assist else 390.0) if state == "chase" else 100.0
			var tactical: bool = office.tactical
			if absf(offset.x) < (60.0 if tactical else 52.0) and absf(offset.y) < (65.0 if tactical else 38.0) and state == "chase":
				state = "grab"
				grab += delta
				speed = 280 if tactical else 90
				if grab > (1.1 if employee.assist else 0.75 if tactical else 0.8):
					state = "caught"
					caught.emit()
			else:
				grab = maxf(0,grab-delta*0.6) if tactical and absf(offset.x)<120 else 0.0
	else:
		grab = 0
		memory = maxf(0, memory - delta)
		if inspection > 0.25 and not escaped_busy:
			escaped_busy = true
			office._comedy_event("busy_escape", "日报就一行，人事看两遍", 180)
		if memory > 0 and state in ["chase", "grab", "notice", "search"]:
			state = "search"
			destination = last_seen.x
			speed = 240
		elif noise_time > 0:
			state = "noise"
			destination = noise_target.x
			speed = 190
			if absf(position.x-noise_target.x)<35:
				speed=0
		else:
			state = "patrol"
			notice = 0
			inspection = 0
			if position.x < patrol_left + 10:
				facing = 1
			elif position.x > patrol_right - 10:
				facing = -1
			destination = position.x + facing * 100
	if not detour.is_empty() and state!="caught":
		detour_age+=delta
		var point: Vector2 = detour.front()
		if is_on_floor() and absf(position.y-point.y)<18 and absf(position.x-point.x)<64:
			detour.pop_front()
			detour_age=0
		if detour_age>4.0:
			detour.clear()
			detour_age=0
			memory=0
			noise_time=0
			avoid_facing=-facing
			avoid_seconds=1.5
		if not detour.is_empty():
			destination=detour.front().x
			speed=260
			state="search"
			memory=maxf(memory,1.0)
	if avoid_seconds>0 and state!="caught":
		state="patrol"
		destination=position.x+avoid_facing*100
		speed=100
	if state in ["chase","grab","caught"]:
		had_chase = true
	if state != "caught":
		var direction: float = signf(destination - position.x) if absf(destination - position.x) > 8 else 0.0
		move_intent=direction
		var wet: bool = office.tactical and is_on_floor() and bool(office.surface_at(position).get("wet",false))
		if wet and slip_cooldown<=0 and absf(velocity.x)>250 and (direction*velocity.x<=0 or absf(destination-position.x)<75):
			slip_remaining=0.8
			slip_cooldown=3.0
			grab=0
			office._comedy_event("hr_skid","人事刹不住，考勤滑过去了",220)
		if slip_remaining>0:
			direction=signf(velocity.x)
			speed=absf(velocity.x)
			state="search"
			grab=0
		if direction != 0:
			facing = int(direction)
		velocity.x = move_toward(velocity.x, direction * speed, (80.0 if slip_remaining>0 else 1300.0) * delta)
		if is_on_floor():
			var probe := KinematicCollision2D.new()
			var obstacle: bool = test_move(global_transform,Vector2(facing*55,0),probe) and absf(probe.get_normal().x)>0.65
			if obstacle and state=="patrol":
				var reverse_probe := KinematicCollision2D.new()
				var boxed: bool = test_move(global_transform,Vector2(-facing*55,0),reverse_probe) and absf(reverse_probe.get_normal().x)>0.65
				avoid_facing=-facing
				avoid_seconds=0.8
				facing=avoid_facing
				velocity.x=avoid_facing*80
				if boxed and jump_cooldown<=0:
					velocity.y=-505
					jump_cooldown=0.9
			elif obstacle and jump_cooldown<=0 and state in ["chase","search","noise"]:
				var routed: bool = false
				if detour.is_empty():
					detour=office.navigation_detour(position,last_seen if memory>0 else noise_target)
					detour_age=0
					routed=not detour.is_empty()
				if is_instance_valid(office.table) and probe.get_collider()==office.table:
					obstacle_wait += delta
					velocity.x = 0
					if office.table.travelled>40:
						office._comedy_event("table_block","会议没挡住工作，挡住了人事",250)
						office._emit_challenge("table_block")
					if obstacle_wait>0.65:
						velocity.y=-505
						jump_cooldown=0.9
				elif not routed:
					velocity.y = -505
					jump_cooldown = 0.9
			else:
				obstacle_wait=0
	velocity.y += 980 * delta
	move_and_slide()
	if absf(move_intent)>0.1 and absf(position.x-previous_x)<0.6 and state not in ["caught","grab"]:
		blocked_seconds+=delta
	else:
		blocked_seconds=0
	if blocked_seconds>1.2:
		if detour.is_empty():
			detour=office.navigation_detour(position,last_seen)
			detour_age=0
		if detour.is_empty():
			state="patrol"
			memory=0
			notice=0
			noise_time=0
			avoid_facing=-facing
			avoid_seconds=1.5
		blocked_seconds=0
	queue_redraw()

func _draw() -> void:
	OfficeArt.draw_hr(self, Vector2.ZERO, facing, state, clock, velocity, grab / (1.1 if is_instance_valid(office.player) and office.player.assist else 0.75 if office.tactical else 0.8), notice / 0.55, slip_remaining, office.tactical)
