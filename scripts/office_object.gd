extends CharacterBody2D

var office: Node2D
var kind: String = "meeting"
var spin: float = 0.0
var shove: float = 0.0
var travelled: float = 0.0
var previous_x: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 14
	var collision := CollisionShape2D.new()
	if kind == "barrel":
		var circle := CircleShape2D.new()
		circle.radius = 34
		collision.shape = circle
		collision.position.y = -34
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(380, 112)
		collision.shape = rectangle
		collision.position.y = -56
	add_child(collision)
	previous_x = position.x

func _physics_process(delta: float) -> void:
	if not office.active:
		return
	var slope: float = float(office.surface_at(position).get("slope",0))
	if is_on_floor():
		velocity.x += slope * 700 * delta
		velocity.x = move_toward(velocity.x, 0, (38.0 if kind == "barrel" else 100.0) * delta)
		if shove != 0:
			velocity.x = move_toward(velocity.x, shove * 125, 500 * delta)
	shove = 0
	velocity.y += 980 * delta
	var incoming: float = velocity.x
	move_and_slide()
	var distance: float = position.x - previous_x
	travelled += absf(distance)
	spin += distance / 34
	previous_x = position.x
	if absf(incoming) > 200:
		for i in range(get_slide_collision_count()):
			var hit := get_slide_collision(i)
			if absf(hit.get_normal().x) > 0.8:
				office.object_impact(hit.get_collider(), incoming, kind)
	if kind == "meeting" and travelled > 100:
		office._comedy_event("moving_meeting", "会议地点调整，请自行跟上", 220)
	queue_redraw()

func _draw() -> void:
	if kind == "barrel":
		OfficeArt.draw_rolling_barrel(self, Vector2.ZERO, spin, absf(velocity.x)>20)
	else:
		OfficeArt.draw_meeting(self, Vector2.ZERO, office._clock, absf(velocity.x)>20)
