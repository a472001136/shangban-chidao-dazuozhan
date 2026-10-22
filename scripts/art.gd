class_name OfficeArt
extends RefCounted

const PAPER: Color = Color("#F5EBD8")
const INK: Color = Color("#28344A")
const WALL: Color = Color("#AFC5CF")
const TEAL: Color = Color("#55AAA4")
const MUSTARD: Color = Color("#E9BD4A")
const TOMATO: Color = Color("#E76A52")
const SKIN: Color = Color("#F0BE95")
const SHADE: Color = Color("#8E8795")
const WHITE: Color = Color("#FFF9EE")
const SOFT_BLUE: Color = Color("#D6E2E1")
const DARK_HAIR: Color = Color("#393746")
const SUIT_BLUE: Color = Color("#526B83")
const OFFICE_FONT: Font = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")


static func draw_player(c: CanvasItem, pos: Vector2, facing: int, pose: String, clock: float, velocity: Vector2, held: String, badge: int = 0, fuel: float = 1.0, anim_state: Dictionary = {}) -> void:
	var slope_angle: float = float(anim_state.get("slope_angle",0))
	if absf(slope_angle)>0.005:
		var seated_state: Dictionary = anim_state.duplicate()
		seated_state["slope_angle"]=0.0
		c.draw_set_transform(pos+Vector2(0,absf(tan(slope_angle))*(32.0 if held=="chair" else 28.0)),slope_angle)
		draw_player(c,Vector2.ZERO,facing,pose,clock,velocity,held,badge,fuel,seated_state)
		c.draw_set_transform(Vector2.ZERO)
		return
	var shirt: Color = anim_state.get("shirt_color",PAPER)
	var direction: float = -1.0 if facing < 0 else 1.0
	var visual_clock: float = float(anim_state.get("visual_clock", clock))
	var gait_phase: float = float(anim_state.get("gait_phase", clock * 8.5))
	var gait_amount: float = clampf(float(anim_state.get("gait_amount", 1.0 if absf(velocity.x) > 48.0 else 0.0)), 0.0, 1.0)
	var airborne: bool = bool(anim_state.get("airborne", pose == "jump" or pose == "fall"))
	var vertical_speed: float = float(anim_state.get("vertical_speed", velocity.y))
	var landing_amount: float = clampf(float(anim_state.get("landing_amount", 0.0)), 0.0, 1.0)
	var dash_age: float = float(anim_state.get("dash_age", -1.0))
	var brake_age: float = float(anim_state.get("brake_age", -1.0))
	var stumble_age: float = float(anim_state.get("stumble_age", -1.0))
	var dash_strength: float = clampf(1.0 - dash_age / 0.42, 0.0, 1.0) if dash_age >= 0.0 else (1.0 if pose == "dash" else 0.0)
	var brake_strength: float = clampf(1.0 - brake_age / 0.40, 0.0, 1.0) if brake_age >= 0.0 else (1.0 if pose == "brake" else 0.0)
	var stumble_strength: float = clampf(1.0 - stumble_age / 0.70, 0.0, 1.0) if stumble_age >= 0.0 else (1.0 if pose == "stumble" else 0.0)
	var running: bool = gait_amount > 0.02 or pose == "run" or (pose == "idle" and absf(velocity.x) > 48.0)
	var comic: bool = bool(anim_state.get("comic", false))
	var speed_amount: float = clampf((absf(velocity.x) - 300.0) / 350.0, 0.0, 1.0)
	var riding_chair: bool = held == "chair" or pose == "chair" or pose == "ride_chair" or pose == "riding_chair" or pose == "clock_chair"
	var riding_bucket: bool = held == "bucket" or pose == "bucket" or pose == "ride_bucket" or pose == "riding_bucket"
	var riding: bool = riding_chair or riding_bucket or pose == "clock_meeting"
	var gait: float = sin(gait_phase)
	var knee_lift: float = maxf(0.0, cos(gait_phase)) * 15.0 * gait_amount
	var bob: float = sin(gait_phase * 2.0) * 4.0 * gait_amount
	if not running and not riding:
		bob += sin(visual_clock * 3.1) * 1.5
	bob += landing_amount * 3.0
	var lean: float = direction * (dash_strength * 0.26 - brake_strength * 0.20 + stumble_strength * 0.52)
	if comic and running:
		lean += direction * (0.08 + speed_amount * 0.12)
	if pose == "fall":
		lean += direction * 0.18
	if riding:
		lean = direction * (0.32 if bool(anim_state.get("spraying",false)) else -0.28 if bool(anim_state.get("braking",false)) else 0.10)
		if comic:
			lean += float(anim_state.get("chair_lean", 0.0)) + direction * speed_amount * 0.09
	var body_scale: float = 1.0 + (0.06 if airborne and vertical_speed < 0.0 else 0.0) - landing_amount * 0.15
	if riding:
		bob = 0
	var anchor: Vector2 = pos + Vector2(0.0, bob)
	if comic and speed_amount > 0.12:
		for streak in range(4):
			var trail_y: float = -22.0 - streak * 18.0
			var trail_start: Vector2 = pos + Vector2(-direction * (43.0 + streak * 9.0), trail_y)
			_line(c, trail_start, trail_start + Vector2(-direction * (22.0 + speed_amount * 34.0), 0.0), _alpha(TEAL if streak % 2 == 0 else INK, speed_amount * 0.45), 2.0)
	if not airborne:
		_ellipse(c, pos + Vector2(0.0, 1.0), 29.0 + landing_amount * 4.0, 6.0 - landing_amount * 1.1, _alpha(INK, 0.17), Color.TRANSPARENT, 0.0)
	var land_age: float = float(anim_state.get("land_age", -1.0))
	if comic and land_age >= 0.0 and land_age < 0.24:
		var dust_fade: float = 1.0 - land_age / 0.24
		for puff in range(4):
			var side: float = -1.0 if puff % 2 == 0 else 1.0
			_ellipse(c, pos + Vector2(side * (16.0 + land_age * (110.0 + puff * 15.0)), -4.0 - puff * 2.0), 7.0 + land_age * 15.0, 4.0, _alpha(WHITE, dust_fade * 0.8), Color.TRANSPARENT, 0.0)
	if comic and brake_strength > 0.1:
		_line(c, pos + Vector2(-direction * 14.0, 1.0), pos + Vector2(-direction * (34.0 + brake_strength * 35.0), 1.0), _alpha(MUSTARD, brake_strength), 3.0)
	if riding_chair:
		_draw_chair(c, pos, Vector2(64.0, 62.0), visual_clock + 0.12, true)
		for streak in range(2):
			_line(c, pos + Vector2(-direction * (38.0 + float(streak) * 7.0), -4.0 - float(streak) * 4.0), pos + Vector2(-direction * (52.0 + float(streak) * 7.0), -3.0 - float(streak) * 4.0), _alpha(INK, 0.54), 1.7)
	elif riding_bucket:
		_draw_bucket(c, pos, Vector2(56.0, 43.0), visual_clock, true)

	var left_hip: Vector2 = Vector2(-10.0, -37.0)
	var right_hip: Vector2 = Vector2(9.0, -37.0)
	var left_knee: Vector2
	var right_knee: Vector2
	var left_ankle: Vector2
	var right_ankle: Vector2
	if riding:
		left_knee = Vector2(-17.0, -22.0)
		right_knee = Vector2(18.0, -24.0)
		left_ankle = Vector2(-29.0, -16.0)
		right_ankle = Vector2(28.0, -17.0)
		if absf(velocity.x) > 10 or bool(anim_state.get("braking",false)):
			left_ankle = Vector2(-22.0 + sin(visual_clock*9.0)*12.0, -5.0)
	elif airborne or pose == "jump" or pose == "fall":
		var tuck: float = clampf(absf(vertical_speed) / 850.0, 0.0, 1.0)
		left_knee = Vector2(-17.0 - 5.0 * tuck, -23.0 - 4.0 * tuck)
		right_knee = Vector2(17.0 + 3.0 * tuck, -25.0)
		left_ankle = Vector2(-25.0 - 4.0 * tuck, -16.0 - 5.0 * tuck)
		right_ankle = Vector2(25.0 + 4.0 * tuck, -20.0 - 3.0 * tuck)
	elif stumble_strength > 0.1:
		left_knee = Vector2(-18.0, -24.0)
		right_knee = Vector2(17.0, -18.0)
		left_ankle = Vector2(-29.0, -10.0)
		right_ankle = Vector2(25.0, -6.0)
	else:
		var lift_left: float = maxf(0.0, cos(gait_phase)) * gait_amount
		var lift_right: float = maxf(0.0, cos(gait_phase + PI)) * gait_amount
		left_knee = Vector2(-10.0 + sin(gait_phase) * 12.0 * gait_amount, -24.0 - lift_left * 10.0)
		right_knee = Vector2(9.0 + sin(gait_phase + PI) * 12.0 * gait_amount, -24.0 - lift_right * 10.0)
		left_ankle = Vector2(-10.0 + sin(gait_phase + 0.55) * 21.0 * gait_amount, -8.0 - lift_left * 13.0)
		right_ankle = Vector2(9.0 + sin(gait_phase + PI + 0.55) * 21.0 * gait_amount, -8.0 - lift_right * 13.0)
	_draw_limb(c, anchor, left_hip, left_knee, 9.0, INK, direction, lean)
	_draw_limb(c, anchor, left_knee, left_ankle, 8.0, INK, direction, lean)
	_draw_limb(c, anchor, right_hip, right_knee, 9.0, INK, direction, lean)
	_draw_limb(c, anchor, right_knee, right_ankle, 8.0, INK, direction, lean)
	var shoe_left: Vector2 = left_ankle + Vector2(direction * 5.0, 1.0)
	var shoe_right: Vector2 = right_ankle + Vector2(direction * 5.0, 1.0)
	_ellipse(c, _xf(anchor, shoe_left, direction, lean), 10.0, 5.0, INK, INK, 1.5, 14)
	_ellipse(c, _xf(anchor, shoe_right, direction, lean), 10.0, 5.0, INK, INK, 1.5, 14)
	_line(c, _xf(anchor, shoe_left + Vector2(-2.0, 1.0), direction, lean), _xf(anchor, shoe_left + Vector2(4.0, 1.0), direction, lean), SHADE, 1.5)
	_line(c, _xf(anchor, shoe_right + Vector2(-2.0, 1.0), direction, lean), _xf(anchor, shoe_right + Vector2(4.0, 1.0), direction, lean), SHADE, 1.5)

	var torso: PackedVector2Array = _scale_y_points(PackedVector2Array([Vector2(-19, -71), Vector2(-25, -66), Vector2(-22, -43), Vector2(-18, -36), Vector2(17, -36), Vector2(22, -44), Vector2(24, -65), Vector2(16, -71)]), body_scale)
	_poly(c, anchor, torso, shirt, INK, 3.4, direction, lean)
	var collar: PackedVector2Array = _scale_y_points(PackedVector2Array([Vector2(-18, -69), Vector2(-11, -73), Vector2(-1, -64), Vector2(8, -73), Vector2(16, -69), Vector2(10, -57), Vector2(0, -61), Vector2(-10, -56)]), body_scale)
	_poly(c, anchor, collar, WHITE, INK, 1.7, direction, lean)
	var tie_sway: float = sin(visual_clock * 8.0) * 2.2 + direction * (dash_strength * 7.0 + brake_strength * 2.0)
	if comic:
		tie_sway = sin(visual_clock * 13.0) * (2.0 + speed_amount * 4.0) - speed_amount * 23.0
	if absf(velocity.x) > 500.0:
		tie_sway += -direction * clampf(absf(velocity.x) / 150.0, 0.0, 6.0)
	var tie_knot: PackedVector2Array = _scale_y_points(PackedVector2Array([Vector2(-4, -64), Vector2(4, -65), Vector2(6, -51), Vector2(3, -42), Vector2(0, -39), Vector2(-4, -43), Vector2(-6, -53)]), body_scale)
	_poly(c, anchor, tie_knot, MUSTARD, INK, 1.8, direction, lean)
	var tie_tail: PackedVector2Array = PackedVector2Array([Vector2(-3, -43), Vector2(3, -43), Vector2(tie_sway + 5, -30), Vector2(tie_sway - 1, -30)])
	_poly(c, anchor, _scale_y_points(tie_tail, body_scale), MUSTARD, INK, 1.5, direction, lean)
	var badge_color: Color = TOMATO
	if badge > 0:
		match badge % 4:
			1:
				badge_color = MUSTARD
			2:
				badge_color = TEAL
			3:
				badge_color = Color("#DB9A69")
	_poly(c, anchor, _scale_y_points(PackedVector2Array([Vector2(7, -57), Vector2(17, -57), Vector2(16, -47), Vector2(7, -46)]), body_scale), badge_color, INK, 1.5, direction, lean)
	_line(c, _xf(anchor, Vector2(9, -54 * body_scale), direction, lean), _xf(anchor, Vector2(15, -54 * body_scale), direction, lean), WHITE, 1.0)
	_line(c, _xf(anchor, Vector2(9, -51 * body_scale), direction, lean), _xf(anchor, Vector2(14, -51 * body_scale), direction, lean), WHITE, 1.0)

	var left_shoulder: Vector2 = Vector2(-18.0, -64.0 * body_scale)
	var right_shoulder: Vector2 = Vector2(17.0, -64.0 * body_scale)
	var left_elbow: Vector2
	var right_elbow: Vector2
	var left_hand: Vector2
	var right_hand: Vector2
	if airborne or pose == "jump" or pose == "fall":
		left_elbow = Vector2(-29.0, -75.0)
		right_elbow = Vector2(29.0, -75.0)
		left_hand = Vector2(-34.0, -87.0)
		right_hand = Vector2(35.0, -86.0)
	elif stumble_strength > 0.1:
		left_elbow = Vector2(-31.0, -75.0 + stumble_strength * 8.0)
		right_elbow = Vector2(31.0, -52.0)
		left_hand = Vector2(-43.0, -82.0 + stumble_strength * 9.0)
		right_hand = Vector2(40.0, -42.0)
	elif held == "extinguisher" or held == "fire_extinguisher":
		left_elbow = Vector2(-24.0, -56.0)
		right_elbow = Vector2(25.0, -56.0)
		left_hand = Vector2(-31.0, -44.0)
		right_hand = Vector2(30.0, -39.0)
	elif dash_strength > 0.1 or running:
		left_elbow = Vector2(-23.0 - gait * 7.0 * gait_amount, -55.0 - maxf(0.0, gait) * 5.0)
		right_elbow = Vector2(23.0 + gait * 7.0 * gait_amount, -62.0 + maxf(0.0, -gait) * 6.0)
		left_hand = left_elbow + Vector2(-7.0, -5.0 + gait * 3.0)
		right_hand = right_elbow + Vector2(7.0, -5.0 - gait * 3.0)
	elif brake_strength > 0.1:
		left_elbow = Vector2(-28.0, -55.0)
		right_elbow = Vector2(29.0, -56.0)
		left_hand = Vector2(-34.0, -50.0)
		right_hand = Vector2(36.0, -49.0)
	else:
		left_elbow = Vector2(-25.0, -54.0)
		right_elbow = Vector2(24.0, -54.0)
		left_hand = Vector2(-29.0, -48.0)
		right_hand = Vector2(29.0, -48.0)
	if pose == "busy":
		left_elbow = Vector2(-17,-51)
		right_elbow = Vector2(23,-60)
		left_hand = Vector2(4,-58)
		right_hand = Vector2(18,-64 + sin(visual_clock*14)*2)
	elif bool(anim_state.get("pushing",false)):
		left_elbow = Vector2(17,-76)
		right_elbow = Vector2(30,-80)
		left_hand = Vector2(39,-89)
		right_hand = Vector2(40,-95)
	if pose == "desk":
		left_elbow = Vector2(-13.0, -49.0)
		right_elbow = Vector2(16.0, -50.0)
		left_hand = Vector2(-8.0, -47.0)
		right_hand = Vector2(11.0, -48.0)
	_draw_limb(c, anchor, left_shoulder, left_elbow, 8.0, shirt, direction, lean)
	_draw_limb(c, anchor, left_elbow, left_hand, 7.0, shirt, direction, lean)
	_draw_limb(c, anchor, right_shoulder, right_elbow, 8.0, shirt, direction, lean)
	_draw_limb(c, anchor, right_elbow, right_hand, 7.0, shirt, direction, lean)
	_ellipse(c, _xf(anchor, left_hand, direction, lean), 5.0, 4.5, SKIN, INK, 1.4, 12)
	_ellipse(c, _xf(anchor, right_hand, direction, lean), 5.0, 4.5, SKIN, INK, 1.4, 12)

	var expression: String = "alert"
	if pose == "late" or pose == "idle":
		expression = "tired"
	elif pose == "desk":
		expression = "smile"
	var blink: float = _blink_amount(visual_clock + 0.42)
	_draw_face(c, anchor, direction, lean, SKIN, anim_state.get("hair_color",DARK_HAIR), expression, int(anim_state.get("hair_style",0)), visual_clock, blink)
	if stumble_strength > 0.15:
		_draw_stars(c, anchor + Vector2(-direction * (28.0 + stumble_strength * 5.0), -108.0), visual_clock)
	if dash_strength > 0.15 and absf(velocity.x) > 250.0:
		for i in range(3):
			var y_line: float = -79.0 + float(i) * 12.0
			_line(c, pos + Vector2(-direction * (34.0 + float(i) * 7.0), y_line), pos + Vector2(-direction * (49.0 + float(i) * 8.0), y_line + 2.0), INK, 2.3)
	if held == "extinguisher" or held == "fire_extinguisher":
		var tool_pos: Vector2 = anchor + Vector2(direction * (29.0 + dash_strength * 4.0), -29.0 + sin(visual_clock * 8.0) * 1.5)
		draw_prop(c, "extinguisher", tool_pos, Vector2(25.0, 48.0), false, visual_clock)
		var fuel_amount: float = clampf(fuel, 0.0, 1.0)
		if fuel_amount > 0.01:
			var bar_w: float = 12.0 * fuel_amount
			_line(c, tool_pos + Vector2(-bar_w * 0.5, -53.0), tool_pos + Vector2(bar_w * 0.5, -53.0), TEAL, 2.0)
		_ellipse(c, tool_pos + Vector2(-direction * 3.0, -16.0), 4.5, 4.0, SKIN, INK, 1.2, 12)
	if pose == "busy":
		c.draw_rect(Rect2(pos+Vector2(-3,-72),Vector2(31,27)),WHITE)
		c.draw_rect(Rect2(pos+Vector2(-3,-72),Vector2(31,27)),INK,false,2)
		_line(c,pos+Vector2(3,-64),pos+Vector2(20,-64),TEAL,2)
		c.draw_string(OFFICE_FONT,pos+Vector2(-42,-140),"正在写日报",HORIZONTAL_ALIGNMENT_CENTER,110,14,INK)


static func draw_rolling_barrel(c: CanvasItem, pos: Vector2, angle: float, moving: bool = true) -> void:
	c.draw_circle(pos+Vector2(0,-34),34,INK)
	c.draw_circle(pos+Vector2(0,-34),30,SOFT_BLUE)
	c.draw_circle(pos+Vector2(0,-34),22,TEAL)
	for i in range(4):
		var offset: Vector2 = Vector2.from_angle(angle+float(i)*PI/2.0)*25.0
		_line(c,pos+Vector2(0,-34)+offset*0.5,pos+Vector2(0,-34)+offset,WHITE,3.0)
	if moving:
		_line(c,pos+Vector2(-48,-5),pos+Vector2(-77,-5),TEAL,3)


static func draw_meeting(c: CanvasItem, pos: Vector2, _clock: float, _moving: bool) -> void:
	for leg_x in [-150.0,150.0]:
		_line(c,pos+Vector2(leg_x,-104),pos+Vector2(leg_x,-18),INK,8)
		c.draw_circle(pos+Vector2(leg_x,-11),11,INK)
		c.draw_circle(pos+Vector2(leg_x,-11),5,SHADE)
	c.draw_rect(Rect2(pos+Vector2(-190,-112),Vector2(380,22)),INK)
	c.draw_rect(Rect2(pos+Vector2(-186,-110),Vector2(372,13)),MUSTARD)
	_line(c,pos+Vector2(-150,-42),pos+Vector2(150,-42),INK,5)
	c.draw_rect(Rect2(pos+Vector2(-86,-80),Vector2(172,34)),PAPER)
	c.draw_rect(Rect2(pos+Vector2(-86,-80),Vector2(172,34)),INK,false,2)
	c.draw_string(OFFICE_FONT,pos+Vector2(-78,-57),"会议地点禁止移动",HORIZONTAL_ALIGNMENT_CENTER,156,16,INK)


static func draw_hr(c: CanvasItem, pos: Vector2, facing: int, state: String, clock: float, velocity: Vector2, grab: float, notice: float, slip: float = 0.0, compact: bool = false) -> void:
	draw_player(c,pos,facing,"stumble" if slip > 0.0 else "run" if absf(velocity.x)>30 else "idle",clock,velocity,"",3,1,{"airborne":absf(velocity.y)>20,"gait_phase":clock*11,"gait_amount":minf(1,absf(velocity.x)/300),"visual_clock":clock,"shirt_color":Color("DA7350"),"hair_color":Color("76514D"),"hair_style":1})
	c.draw_rect(Rect2(pos+Vector2(-26,-70),Vector2(13,19)),TOMATO)
	c.draw_string(OFFICE_FONT,pos+Vector2(-24,-56),"HR",HORIZONTAL_ALIGNMENT_LEFT,14,9,WHITE)
	var reach: float = 50.0 if state == "grab" else 29.0
	_line(c,pos+Vector2(17*facing,-63),pos+Vector2(reach*facing,-55),TOMATO,7)
	c.draw_circle(pos+Vector2(reach*facing,-55),5,SKIN)
	var clipboard: Vector2 = pos + Vector2(-facing * 36.0, -47.0)
	var board_angle: float = sin(clock * 22.0) * 0.45 if slip > 0.0 else 0.0
	_poly(c, clipboard, PackedVector2Array([Vector2(-10,-15),Vector2(10,-15),Vector2(10,15),Vector2(-10,15)]), MUSTARD, INK, 2.0, 1.0, board_angle)
	if slip > 0.0:
		for sheet in range(3):
			var flutter: Vector2 = pos + Vector2(-facing * (48.0 + sheet * 20.0), -84.0 + sin(clock * 10.0 + sheet) * 12.0)
			_poly(c, flutter, PackedVector2Array([Vector2(-8,-5),Vector2(8,-5),Vector2(8,5),Vector2(-8,5)]), WHITE, SHADE, 1.0, 1.0, clock * 2.0 + sheet)
	var text: String = {"patrol":"人事 · 查考勤","notice":"等一下！","chase":"工牌拿出来！","search":"人呢？","noise":"什么动静？","inspect":"日报我看看","grab":"抓住你了…","caught":"迟到登记完成"}.get(state,"人事")
	if not compact or state != "patrol":
		text = "哎哎哎——！" if slip > 0.0 else text
		c.draw_rect(Rect2(pos+Vector2(-70,-149),Vector2(140,25)),WHITE)
		c.draw_string(OFFICE_FONT,pos+Vector2(-68,-131),text,HORIZONTAL_ALIGNMENT_CENTER,136,14,TOMATO if state in ["chase","grab","caught"] or slip > 0.0 else INK)
	elif compact:
		c.draw_circle(pos + Vector2(0,-133), 12.0, TOMATO)
		c.draw_string(OFFICE_FONT,pos+Vector2(-9,-129),"HR",HORIZONTAL_ALIGNMENT_CENTER,18,10,WHITE)
	if state in ["notice","grab"]:
		c.draw_rect(Rect2(pos+Vector2(-38,-124),Vector2(76,5)),SHADE)
		c.draw_rect(Rect2(pos+Vector2(-38,-124),Vector2(76*clampf(grab if state=="grab" else notice,0,1),5)),TOMATO)


static func draw_prop(c: CanvasItem, kind: String, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	if damaged and kind in ["box","files","bin","plant","glass","cooler","monitor","printer"]:
		draw_debris(c,pos,size,kind)
		return
	match kind.to_lower():
		"meeting":
			if not damaged:
				draw_meeting(c,pos,clock,false)
		"chair", "office_chair":
			_draw_chair(c, pos, size, clock, false)
		"extinguisher", "fire_extinguisher":
			_draw_extinguisher(c, pos, size, damaged, clock)
		"bucket", "mop_bucket":
			_draw_bucket(c, pos, size, clock, false)
		"box":
			_draw_box(c, pos, size, damaged)
		"files", "file_stack":
			_draw_files(c, pos, size, damaged, clock)
		"bin", "waste_bin":
			_draw_bin(c, pos, size, damaged, clock)
		"plant", "potted_plant":
			_draw_plant(c, pos, size, damaged, clock)
		"glass", "glass_door":
			_draw_glass(c, pos, size, damaged)
		"cooler", "water_cooler":
			_draw_cooler(c, pos, size, damaged, clock)
		"monitor":
			_draw_monitor(c, pos, size, damaged, clock)
		"printer":
			_draw_printer(c, pos, size, damaged, clock)
		"fan":
			_draw_fan(c, pos, size, clock)
		"belt", "conveyor":
			_draw_belt(c, pos, size, clock)
		"paper_machine":
			_draw_paper_machine(c, pos, size, damaged, clock)
		"reception", "front_desk", "frontdesk":
			_draw_reception(c, pos, size)
		"gate", "turnstile":
			_draw_gate(c, pos, size, clock)
		"desk", "workstation":
			_draw_desk(c, pos, size)
		"shelf", "cabinet", "file_cabinet":
			_draw_storage(c, pos, size, kind.to_lower() != "shelf")
		"sofa", "couch":
			_draw_sofa(c, pos, size)
		_:
			_draw_box(c, pos, size, damaged)


static func accident_effect_lifetime(kind: String) -> float:
	var normalized: String = kind.to_lower()
	if normalized.contains("glass"):
		return 3.0
	if normalized.contains("cooler") or normalized.contains("water") or normalized.contains("spray"):
		return 2.55
	return 2.8


static func draw_accident_effect(c: CanvasItem, kind: String, pos: Vector2, age: float, seed: int = 0) -> void:
	var normalized: String = kind.to_lower()
	var lifetime: float = accident_effect_lifetime(normalized)
	if age < 0.0 or age > lifetime:
		return
	var family: String = "paper"
	if normalized.contains("glass"):
		family = "glass"
	elif normalized.contains("cooler") or normalized.contains("water") or normalized.contains("spray"):
		family = "water"
	elif normalized.contains("plant") or normalized.contains("leaf"):
		family = "leaf"
	elif normalized.contains("monitor") or normalized.contains("fan") or normalized.contains("spark"):
		family = "spark"
	elif normalized.contains("box") or normalized.contains("carton"):
		family = "cardboard"
	elif normalized.contains("bin"):
		family = "scrap"
	var colors: Array[Color] = [PAPER, WHITE, MUSTARD, Color("#D9A67D")]
	match family:
		"glass":
			colors = [Color("#B7E1DC"), Color("#8CC8C7"), WHITE, Color("#D7E9E0")]
		"water":
			colors = [Color("#A5D7E3"), Color("#D5F1E9"), WHITE, Color("#78BFCB")]
		"leaf":
			colors = [TEAL, Color("#84B79C"), MUSTARD, Color("#6A9B73")]
		"spark":
			colors = [MUSTARD, TOMATO, WHITE, Color("#A5D7E3")]
		"cardboard":
			colors = [Color("#C79B6E"), Color("#D7B18A"), MUSTARD, PAPER]
		"scrap":
			colors = [Color("#718BA0"), PAPER, Color("#9DB4BA"), MUSTARD]
	if age < 0.26:
		var burst_t: float = clampf(1.0 - age / 0.26, 0.0, 1.0)
		var burst_radius: float = 18.0 + (1.0 - burst_t) * 48.0
		c.draw_arc(pos, burst_radius, 0.0, TAU, 32, _alpha(WHITE, burst_t * 0.75), 3.0, true)
		for ray in range(8):
			var ray_angle: float = TAU * float(ray) / 8.0 + float(seed % 7) * 0.07
			var ray_dir: Vector2 = Vector2(cos(ray_angle), sin(ray_angle))
			_line(c, pos + ray_dir * (burst_radius * 0.48), pos + ray_dir * burst_radius, _alpha(MUSTARD if ray % 2 == 0 else INK, burst_t * 0.9), 2.4 if ray % 2 == 0 else 1.8)
		var star: PackedVector2Array = PackedVector2Array([Vector2(0.0, -9.0), Vector2(3.0, -3.0), Vector2(9.0, 0.0), Vector2(3.0, 3.0), Vector2(0.0, 9.0), Vector2(-3.0, 3.0), Vector2(-9.0, 0.0), Vector2(-3.0, -3.0)])
		_poly(c, pos, star, _alpha(WHITE, burst_t), _alpha(INK, burst_t), 1.7, 1.0, float(seed % 9) * 0.12)
	var particle_count: int = 14 if family == "glass" or family == "paper" else 10
	for particle in range(particle_count):
		var angle: float = -PI * 0.88 + _effect_unit(seed, particle, 1) * PI * 0.78
		var speed: float = 65.0 + _effect_unit(seed, particle, 2) * 180.0
		if family == "water":
			angle = -PI * 0.90 + _effect_unit(seed, particle, 1) * PI * 0.8
			speed = 32.0 + _effect_unit(seed, particle, 2) * 112.0
		var drift: Vector2 = Vector2(cos(angle) * speed * age, sin(angle) * speed * age + 105.0 * age * age)
		var jitter_x: float = (_effect_unit(seed, particle, 3) - 0.5) * 12.0
		var particle_pos: Vector2 = pos + drift + Vector2(jitter_x, 0.0)
		var fade: float = clampf(1.0 - maxf(0.0, age - 0.28) / maxf(lifetime - 0.28, 0.01), 0.0, 1.0)
		var color_index: int = posmod(particle + seed, colors.size())
		var particle_color: Color = _alpha(colors[color_index], fade)
		var size: float = 3.5 + _effect_unit(seed, particle, 4) * 4.5
		if family == "glass":
			var shard: PackedVector2Array = PackedVector2Array([Vector2(-size, size * 0.65), Vector2(size * 0.85, size * 0.2), Vector2(size * 0.15, -size)])
			_poly(c, particle_pos, shard, particle_color, _alpha(INK, fade * 0.7), 1.0, 1.0, angle + age * 2.0)
		elif family == "water":
			_ellipse(c, particle_pos, size * 0.6, size, particle_color, _alpha(WHITE, fade * 0.7), 0.8, 10)
		elif family == "spark":
			_line(c, particle_pos, particle_pos + Vector2(cos(angle + 0.4), sin(angle + 0.4)) * size * 1.8, particle_color, 1.8)
		else:
			var scrap: PackedVector2Array = PackedVector2Array([Vector2(-size, -size * 0.5), Vector2(size * 0.9, -size * 0.75), Vector2(size * 0.65, size * 0.8), Vector2(-size * 0.8, size * 0.6)])
			_poly(c, particle_pos, scrap, particle_color, _alpha(INK, fade * 0.65), 0.9, 1.0, angle + age * 2.2)
	if age > 0.55:
		var settle_fade: float = clampf((lifetime - age) / (lifetime * 0.68), 0.0, 1.0) * 0.58
		for shard_index in range(3):
			var settle_x: float = (_effect_unit(seed, shard_index, 5) - 0.5) * 42.0
			var settle_y: float = 7.0 + _effect_unit(seed, shard_index, 6) * 6.0
			var settle_color: Color = _alpha(colors[posmod(shard_index + seed, colors.size())], settle_fade)
			if family == "water":
				c.draw_arc(pos + Vector2(settle_x, settle_y), 3.0 + float(shard_index), PI, TAU, 10, settle_color, 1.3, true)
			else:
				_line(c, pos + Vector2(settle_x - 4.0, settle_y), pos + Vector2(settle_x + 4.0, settle_y - 2.0), settle_color, 1.5)


static func draw_npc(c: CanvasItem, pos: Vector2, kind: String, facing: int, clock: float, alarm: float = 0.0) -> void:
	var direction: float = -1.0 if facing < 0 else 1.0
	var role: String = kind.to_lower()
	var shirt_color: Color = SOFT_BLUE
	var hair_color: Color = DARK_HAIR
	var accent: Color = TEAL
	var skin_color: Color = SKIN
	var hair_style: int = 1
	var expression: String = "neutral"
	match role:
		"frontdesk", "reception", "receptionist", "xiaolin":
			shirt_color = Color("#76AFA8")
			hair_color = Color("#5A4745")
			accent = MUSTARD
			hair_style = 2
		"coworker", "laowang", "colleague":
			shirt_color = Color("#7996B0")
			hair_color = Color("#373849")
			accent = TOMATO
			hair_style = 0
		"cleaner", "janitor":
			shirt_color = Color("#74A9A2")
			hair_color = Color("#5B5149")
			accent = MUSTARD
			hair_style = 2
		"supervisor", "manager", "he":
			shirt_color = SUIT_BLUE
			hair_color = Color("#4A4546")
			accent = TOMATO
			hair_style = 1
			expression = "stern" if alarm < 0.35 else "alert"
		"hr", "personnel", "xiaoxu":
			shirt_color = Color("#D7A690")
			hair_color = Color("#76514D")
			accent = TEAL
			hair_style = 2
		_:
			shirt_color = SOFT_BLUE
	var bob: float = sin(clock * 4.0) * 1.0
	var origin: Vector2 = pos + Vector2(0.0, bob)
	_ellipse(c, pos + Vector2(0.0, 1.0), 25.0, 5.0, _alpha(INK, 0.13), Color.TRANSPARENT, 0.0)
	var leg_sway: float = sin(clock * 3.3) * 2.0 if role == "cleaner" else 0.0
	_poly(c, origin, PackedVector2Array([Vector2(-11, -37), Vector2(-3, -36), Vector2(-7 + leg_sway, -8), Vector2(-16 + leg_sway, -7), Vector2(-18, -15)]), INK, INK, 1.5, direction)
	_poly(c, origin, PackedVector2Array([Vector2(5, -37), Vector2(14, -36), Vector2(17 - leg_sway, -9), Vector2(9 - leg_sway, -7), Vector2(3, -16)]), INK, INK, 1.5, direction)
	_ellipse(c, _xf(origin, Vector2(-13 + leg_sway, -7), direction), 8.0, 4.0, INK, INK, 1.0, 12)
	_ellipse(c, _xf(origin, Vector2(13 - leg_sway, -7), direction), 8.0, 4.0, INK, INK, 1.0, 12)
	_poly(c, origin, PackedVector2Array([Vector2(-19, -70), Vector2(-24, -64), Vector2(-21, -43), Vector2(-15, -37), Vector2(16, -37), Vector2(22, -44), Vector2(23, -64), Vector2(15, -70)]), shirt_color, INK, 3.0, direction)
	_poly(c, origin, PackedVector2Array([Vector2(-13, -68), Vector2(-5, -72), Vector2(0, -64), Vector2(7, -72), Vector2(14, -68), Vector2(9, -57), Vector2(0, -60), Vector2(-8, -56)]), WHITE, INK, 1.5, direction)
	_poly(c, origin, PackedVector2Array([Vector2(-2, -64), Vector2(4, -64), Vector2(5, -51), Vector2(1, -44), Vector2(-3, -51)]), accent, INK, 1.4, direction)
	_poly(c, origin, PackedVector2Array([Vector2(-18, -64), Vector2(-23, -60), Vector2(-31, -49), Vector2(-26, -45), Vector2(-16, -53)]), shirt_color, INK, 2.2, direction)
	_poly(c, origin, PackedVector2Array([Vector2(17, -64), Vector2(22, -60), Vector2(29, -49), Vector2(25, -45), Vector2(16, -53)]), shirt_color, INK, 2.2, direction)
	_ellipse(c, _xf(origin, Vector2(-27, -45), direction), 4.5, 4.0, skin_color, INK, 1.2, 12)
	_ellipse(c, _xf(origin, Vector2(26, -45), direction), 4.5, 4.0, skin_color, INK, 1.2, 12)
	_draw_face(c, origin, direction, 0.0, skin_color, hair_color, expression, hair_style, clock)
	if role == "frontdesk" or role == "reception" or role == "receptionist" or role == "xiaolin":
		_ellipse(c, _xf(origin, Vector2(direction * 20.0, -87.0), direction), 4.0, 4.0, accent, INK, 1.3, 12)
		_line(c, _xf(origin, Vector2(direction * 18.0, -85.0), direction), _xf(origin, Vector2(direction * 11.0, -82.0), direction), INK, 1.4)
	elif role == "coworker" or role == "laowang" or role == "colleague":
		_poly(c, origin, PackedVector2Array([Vector2(14, -53), Vector2(29, -51), Vector2(29, -35), Vector2(13, -37)]), PAPER, INK, 1.7, direction)
		_line(c, _xf(origin, Vector2(17, -48), direction), _xf(origin, Vector2(27, -47), direction), WALL, 1.2)
	elif role == "cleaner" or role == "janitor":
		var sway: float = sin(clock * 5.0) * 5.0
		_line(c, _xf(origin, Vector2(-32, -20), direction), _xf(origin, Vector2(-42 + sway, -2), direction), INK, 3.0)
		_line(c, _xf(origin, Vector2(-42 + sway, -2), direction), _xf(origin, Vector2(-52 + sway, 1), direction), TEAL, 3.0)
		_line(c, _xf(origin, Vector2(-46 + sway, -1), direction), _xf(origin, Vector2(-49 + sway, 4), direction), TEAL, 1.5)
	elif role == "supervisor" or role == "manager" or role == "he":
		_poly(c, origin, PackedVector2Array([Vector2(16, -54), Vector2(31, -51), Vector2(29, -34), Vector2(15, -37)]), MUSTARD, INK, 1.8, direction)
		_line(c, _xf(origin, Vector2(18, -48), direction), _xf(origin, Vector2(27, -47), direction), INK, 1.0)
		if alarm > 0.25:
			_draw_alert_mark(c, _xf(origin, Vector2(-direction * 30.0, -111.0), direction), clock)
	elif role == "hr" or role == "personnel" or role == "xiaoxu":
		_poly(c, origin, PackedVector2Array([Vector2(-21, -45), Vector2(20, -45), Vector2(15, -34), Vector2(-17, -34)]), accent, INK, 1.8, direction)
		_line(c, _xf(origin, Vector2(17, -49), direction), _xf(origin, Vector2(20, -40), direction), INK, 1.4)
		_ellipse(c, _xf(origin, Vector2(21, -40), direction), 2.5, 2.5, TOMATO, INK, 1.0, 10)


static func draw_office(c: CanvasItem, left: float, right: float, theme: int, clock: float) -> void:
	if right <= left:
		return
	var wall_color: Color = Color("#DCE5E0")
	var floor_color: Color = Color("#E6D8C2")
	var trim_color: Color = Color("#95AFBA")
	match posmod(theme, 5):
		1:
			wall_color = Color("#DCE5E1")
			floor_color = Color("#DCC8AD")
			trim_color = Color("#A2B9BC")
		2:
			wall_color = Color("#D5E0E4")
			floor_color = Color("#E5D8C7")
			trim_color = Color("#88A8B7")
		3:
			wall_color = Color("#E4DCD7")
			floor_color = Color("#DBD3CB")
			trim_color = Color("#A9989F")
		4:
			wall_color = Color("#D8E4DC")
			floor_color = Color("#E5D6BE")
			trim_color = Color("#8AAEA6")
	var span: float = right - left
	c.draw_rect(Rect2(left, 0.0, span, 600.0), wall_color)
	c.draw_rect(Rect2(left, 0.0, span, 172.0), Color("#D9E8EA"))
	_draw_city(c, left, right, clock)
	c.draw_rect(Rect2(left, 152.0, span, 432.0), wall_color)
	_draw_wall_texture(c, left, right)
	var lamp_step: float = 344.0
	var lamp_x: float = floor((left - 100.0) / lamp_step) * lamp_step
	while lamp_x <= right + 100.0:
		var lamp_index: int = floori(lamp_x / lamp_step)
		if lamp_x + 94.0 >= left and lamp_x - 94.0 <= right:
			_draw_ceiling_lamp(c, Vector2(lamp_x, 26.0), trim_color, clock, lamp_index)
		lamp_x += lamp_step
	var window_step: float = 590.0
	var window_x: float = floor((left - 253.0) / window_step) * window_step
	while window_x <= right:
		var window_center_x: float = window_x + 150.0
		if window_center_x + 103.0 >= left and window_center_x - 103.0 <= right:
			_draw_office_window(c, Vector2(window_center_x, 184.0), trim_color, clock)
		window_x += window_step
	var sign_step: float = 930.0
	var sign_x: float = floor((left - 485.0) / sign_step) * sign_step
	while sign_x <= right:
		var sign_center_x: float = sign_x + 430.0
		if sign_center_x + 78.0 >= left and sign_center_x - 78.0 <= right:
			_draw_wall_sign(c, Vector2(sign_center_x, 293.0), theme + floori(sign_x / sign_step))
		sign_x += sign_step
	var feature_step: float = 1580.0
	var feature_x: float = floor((left - 920.0) / feature_step) * feature_step
	while feature_x <= right:
		var feature_center_x: float = feature_x + 700.0
		if feature_center_x + 180.0 >= left and feature_center_x - 180.0 <= right:
			_draw_wall_feature(c, Vector2(feature_center_x, 367.0), floori(feature_x / feature_step), theme, clock)
		feature_x += feature_step
	c.draw_rect(Rect2(left,545.0,span,55.0),Color("D6D5CF"))
	c.draw_line(Vector2(left,545),Vector2(right,545),_alpha(INK,0.25),2)
	var furniture_step: float = 1080.0
	var furniture_x: float = floor((left - 1030.0) / furniture_step) * furniture_step
	while furniture_x <= right:
		var cluster_index: int = floori(furniture_x / furniture_step)
		var first_desk_x: float = furniture_x + 225.0
		if first_desk_x + 152.0 >= left and first_desk_x - 152.0 <= right:
			var first_desk_y: float = 507.0
			_draw_background_desk(c, Vector2(first_desk_x, first_desk_y), trim_color, cluster_index, clock)
		var second_desk_x: float = furniture_x + 606.0
		if second_desk_x + 152.0 >= left and second_desk_x - 152.0 <= right:
			var second_desk_y: float = 507.0
			_draw_background_desk(c, Vector2(second_desk_x, second_desk_y), trim_color, cluster_index + 1, clock)
		var shelf_center_x: float = furniture_x + 943.0
		if shelf_center_x + 61.0 >= left and shelf_center_x - 61.0 <= right:
			_draw_shelf(c, Vector2(shelf_center_x, 485.0), trim_color)
		furniture_x += furniture_step
	var plant_step: float = 1090.0
	var plant_x: float = floor((left - 500.0) / plant_step) * plant_step
	while plant_x <= right:
		var plant_center_x: float = plant_x + 475.0
		if plant_center_x + 25.0 >= left and plant_center_x - 25.0 <= right:
			_draw_plant(c, Vector2(plant_center_x, 545.0), Vector2(50.0, 72.0), false, clock)
		plant_x += plant_step
	c.draw_rect(Rect2(left, 152.0, span, 426.0), Color(0.93, 0.94, 0.89, 0.32))
	var panel_x: float = floor(left / 720.0) * 720.0
	while panel_x < right:
		c.draw_line(Vector2(panel_x, 172.0), Vector2(panel_x, 545.0), _alpha(trim_color, 0.3), 2.0)
		panel_x += 720.0
	c.draw_rect(Rect2(left, 578.0, span, 22.0), Color("#D0D6D1"))
	c.draw_rect(Rect2(left, 578.0, span, 17.0), _alpha(WHITE, 0.18))
	c.draw_rect(Rect2(left, 578.0, span, 3.0), trim_color)
	c.draw_line(Vector2(left, 595.0), Vector2(right, 595.0), _alpha(INK, 0.14), 1.0, true)
	c.draw_rect(Rect2(left, 600.0, span, 120.0), floor_color)
	c.draw_rect(Rect2(left, 600.0, span, 3.0), INK)
	c.draw_rect(Rect2(left, 603.0, span, 7.0), Color("#C6B69D"))
	c.draw_line(Vector2(left, 603.0), Vector2(right, 603.0), _alpha(WHITE, 0.56), 1.0, true)
	var tile_x: float = floor(left / 92.0) * 92.0
	while tile_x <= right:
		c.draw_line(Vector2(tile_x, 610.0), Vector2(tile_x, 720.0), _alpha(SHADE, 0.22), 1.0)
		tile_x += 92.0
	c.draw_line(Vector2(left, 664.0), Vector2(right, 664.0), _alpha(WHITE, 0.22), 1.0, true)
	c.draw_line(Vector2(left, 600.0), Vector2(right, 600.0), INK, 3.0, true)
	c.draw_line(Vector2(left, 608.0), Vector2(right, 608.0), _alpha(WHITE, 0.8), 2.0, true)


static func draw_title(c: CanvasItem, screen: Vector2, clock: float) -> void:
	var width: float = screen.x
	var height: float = screen.y
	var floor_y: float = height * 0.845
	c.draw_rect(Rect2(Vector2.ZERO, screen), PAPER)
	c.draw_rect(Rect2(0.0, 0.0, width, floor_y), Color("#D9E7E5"))
	for i in range(5):
		var building_x: float = float(i) * 255.0 - 20.0
		var building_h: float = 80.0 + float((i * 37) % 65)
		c.draw_rect(Rect2(building_x, 115.0 - building_h, 170.0, building_h), _alpha(WALL, 0.62))
		for j in range(3):
			c.draw_rect(Rect2(building_x + 21.0 + float(j) * 46.0, 82.0 - building_h * 0.43, 19.0, 27.0), _alpha(WHITE, 0.62))
		c.draw_rect(Rect2(building_x + 21.0, 112.0 - building_h * 0.2, 19.0, 22.0), _alpha(WHITE, 0.5))
	c.draw_rect(Rect2(0.0, 175.0, width, floor_y - 175.0), Color("#E4E9DF"))
	c.draw_rect(Rect2(0.0, floor_y, width, height - floor_y), Color("#DDCFB9"))
	c.draw_line(Vector2(0.0, floor_y), Vector2(width, floor_y), INK, 4.0, true)
	for tile in range(0, int(width) + 90, 90):
		c.draw_line(Vector2(float(tile), floor_y), Vector2(float(tile), height), _alpha(SHADE, 0.2), 1.0)
	for wx in [710.0, 1015.0]:
		_draw_office_window(c, Vector2(wx, 275.0), Color("#95AFBA"))
	# The title sheet stays open for the game's title text.
	var sheet: PackedVector2Array = PackedVector2Array([Vector2(56, 58), Vector2(666, 46), Vector2(682, 354), Vector2(69, 371)])
	_poly(c, Vector2.ZERO, sheet, PAPER, INK, 5.0)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(76, 75), Vector2(645, 64), Vector2(656, 337), Vector2(86, 351)]), _alpha(WHITE, 0.42), Color.TRANSPARENT, 0.0)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(274, 43), Vector2(353, 41), Vector2(361, 67), Vector2(282, 70)]), _alpha(MUSTARD, 0.75), _alpha(INK, 0.35), 1.0)
	# Keep the lower-left button lane clear and fast to read.
	c.draw_rect(Rect2(44.0, 400.0, 466.0, height - 420.0), _alpha(PAPER, 0.72))
	# A little desk and the seated personnel clerk anchor the far side of the poster.
	draw_npc(c, Vector2(width - 92.0, floor_y - 70.0), "hr", -1, clock + 0.3)
	var desk_x: float = width - 204.0
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(width - 266.0, floor_y - 81.0), Vector2(width - 39.0, floor_y - 81.0), Vector2(width - 21.0, floor_y - 12.0), Vector2(width - 276.0, floor_y - 12.0)]), Color("#AFC5CF"), INK, 4.0)
	c.draw_rect(Rect2(width - 252.0, floor_y - 13.0, 16.0, 28.0), INK)
	c.draw_rect(Rect2(width - 79.0, floor_y - 13.0, 16.0, 28.0), INK)
	c.draw_line(Vector2(desk_x + 21.0, floor_y - 72.0), Vector2(width - 66.0, floor_y - 72.0), _alpha(WHITE, 0.8), 3.0)
	c.draw_rect(Rect2(width - 193.0, floor_y - 107.0, 61.0, 26.0), Color("#707D8A"), true)
	# The chair skids toward the clerk; loose papers trail into the empty center.
	var slide: float = sin(clock * 2.4) * 8.0
	var rider_pos: Vector2 = Vector2(width * 0.67 + slide, floor_y)
	c.draw_set_transform(rider_pos, 0.0, Vector2(2.0, 2.0))
	draw_player(c, Vector2.ZERO, 1, "dash", clock, Vector2(690.0, 0.0), "chair", 0, 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(4):
		var page_x: float = rider_pos.x - 92.0 - float(i) * 31.0 + sin(clock * 4.0 + float(i)) * 5.0
		var page_y: float = floor_y - 124.0 - float((i * 29) % 74)
		var page_rot: float = sin(clock * 3.0 + float(i) * 1.5) * 0.18
		_poly(c, Vector2(page_x, page_y), PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(16, 18), Vector2(-16, 16)]), WHITE, INK, 2.0, 1.0, page_rot)
		_line(c, Vector2(page_x - 8.0, page_y - 7.0), Vector2(page_x + 8.0, page_y - 7.0), WALL, 1.4)
		_line(c, Vector2(page_x - 8.0, page_y), Vector2(page_x + 9.0, page_y), WALL, 1.4)
	# The open title and button spaces stay free of decorative marks.


static func draw_coupon(c: CanvasItem, pos: Vector2, taken: bool, clock: float) -> void:
	var bob: float = sin(clock * 3.2 + pos.x * 0.02) * 3.0
	var origin: Vector2 = pos + Vector2(0.0, bob)
	_ellipse(c, pos + Vector2(0.0, 2.0), 19.0, 4.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	var fill: Color = _alpha(PAPER, 0.18) if taken else MUSTARD
	var outline: Color = _alpha(INK, 0.42) if taken else INK
	_poly(c, origin, PackedVector2Array([Vector2(-19, -14), Vector2(-13, -21), Vector2(14, -21), Vector2(20, -14), Vector2(18, -2), Vector2(12, 1), Vector2(-13, 1), Vector2(-19, -5)]), fill, outline, 2.5)
	if not taken:
		_line(c, origin + Vector2(-10.0, -14.0), origin + Vector2(9.0, -14.0), _alpha(WHITE, 0.8), 1.5)
		_ellipse(c, origin + Vector2(-4.0, -8.0), 4.0, 4.0, WHITE, INK, 1.1, 10)
		_line(c, origin + Vector2(3.0, -8.0), origin + Vector2(12.0, -8.0), INK, 1.2)
	else:
		c.draw_arc(origin + Vector2(0.0, -10.0), 7.0, 0.0, TAU, 18, outline, 2.0, true)


static func _draw_chair(c: CanvasItem, pos: Vector2, size: Vector2, clock: float, occupied: bool) -> void:
	var w: float = maxf(size.x, 42.0)
	var h: float = maxf(size.y, 48.0)
	var wobble: float = sin(clock * 12.0) * 0.035 if occupied else sin(clock * 2.0) * 0.012
	var back_fill: Color = TEAL
	var seat_fill: Color = Color("#65B5AF")
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.38, -h * 0.42), Vector2(-w * 0.34, -h * 0.88), Vector2(-w * 0.17, -h), Vector2(w * 0.26, -h * 0.98), Vector2(w * 0.39, -h * 0.82), Vector2(w * 0.33, -h * 0.40)]), back_fill, INK, 3.0, 1.0, wobble)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.47, -h * 0.48), Vector2(w * 0.37, -h * 0.52), Vector2(w * 0.49, -h * 0.36), Vector2(w * 0.34, -h * 0.26), Vector2(-w * 0.41, -h * 0.27), Vector2(-w * 0.52, -h * 0.37)]), seat_fill, INK, 3.0, 1.0, wobble)
	_line(c, pos + Vector2(-w * 0.27, -h * 0.77), pos + Vector2(w * 0.23, -h * 0.79), _alpha(WHITE, 0.65), 2.0)
	_line(c, pos + Vector2(0.0, -h * 0.27), pos + Vector2(0.0, -h * 0.13), INK, 4.0)
	_line(c, pos + Vector2(0.0, -h * 0.14), pos + Vector2(-w * 0.27, -h * 0.06), INK, 3.0)
	_line(c, pos + Vector2(0.0, -h * 0.14), pos + Vector2(w * 0.29, -h * 0.06), INK, 3.0)
	_line(c, pos + Vector2(-w * 0.27, -h * 0.06), pos + Vector2(-w * 0.42, -h * 0.03), INK, 2.5)
	_line(c, pos + Vector2(w * 0.29, -h * 0.06), pos + Vector2(w * 0.43, -h * 0.03), INK, 2.5)
	for wheel_index in range(4):
		var wheel_x: float = (float(wheel_index) - 1.5) * w * 0.24
		var wheel_y: float = -4.0
		_ellipse(c, pos + Vector2(wheel_x, wheel_y), 4.5, 4.0, INK, INK, 1.0, 12)
	if occupied:
		_line(c, pos + Vector2(-w * 0.31, -h * 0.20), pos + Vector2(-w * 0.37, -h * 0.10), SHADE, 2.0)


static func _draw_extinguisher(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 22.0)
	var h: float = maxf(size.y, 38.0)
	_ellipse(c, pos + Vector2(1.0, 0.0), w * 0.48, 4.0, _alpha(INK, 0.13), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.34, -h * 0.72), Vector2(-w * 0.29, -h * 0.91), Vector2(-w * 0.17, -h), Vector2(w * 0.18, -h), Vector2(w * 0.31, -h * 0.88), Vector2(w * 0.35, -h * 0.18), Vector2(w * 0.22, -h * 0.07), Vector2(-w * 0.24, -h * 0.08), Vector2(-w * 0.36, -h * 0.21)]), TOMATO, INK, 3.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.17, -h * 0.92), Vector2(-w * 0.14, -h * 1.05), Vector2(w * 0.10, -h * 1.05), Vector2(w * 0.16, -h * 0.91)]), INK, INK, 1.5)
	_line(c, pos + Vector2(w * 0.02, -h * 1.03), pos + Vector2(w * 0.33, -h * 1.08), INK, 3.0)
	_line(c, pos + Vector2(w * 0.31, -h * 1.08), pos + Vector2(w * 0.42, -h * 0.91), INK, 2.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.21, -h * 0.64), Vector2(w * 0.20, -h * 0.64), Vector2(w * 0.22, -h * 0.40), Vector2(-w * 0.21, -h * 0.40)]), PAPER, INK, 1.2)
	_line(c, pos + Vector2(-w * 0.12, -h * 0.58), pos + Vector2(w * 0.12, -h * 0.58), INK, 1.2)
	_line(c, pos + Vector2(-w * 0.12, -h * 0.50), pos + Vector2(w * 0.07, -h * 0.50), INK, 1.0)
	if damaged:
		_line(c, pos + Vector2(-w * 0.22, -h * 0.82), pos + Vector2(w * 0.27, -h * 0.25), SHADE, 2.2)
		_line(c, pos + Vector2(-w * 0.24, -h * 0.27), pos + Vector2(w * 0.29, -h * 0.81), SHADE, 2.2)
	else:
		_line(c, pos + Vector2(-w * 0.20, -h * 0.79), pos + Vector2(-w * 0.15, -h * 0.30), _alpha(WHITE, 0.68), 2.0)


static func _draw_bucket(c: CanvasItem, pos: Vector2, size: Vector2, clock: float, occupied: bool) -> void:
	var w: float = maxf(size.x, 38.0)
	var h: float = maxf(size.y, 30.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.49, 4.5, _alpha(INK, 0.14), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.78), Vector2(w * 0.47, -h * 0.78), Vector2(w * 0.35, -h * 0.08), Vector2(-w * 0.34, -h * 0.08)]), MUSTARD, INK, 3.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.50, -h * 0.83), Vector2(-w * 0.42, -h * 0.94), Vector2(w * 0.42, -h * 0.94), Vector2(w * 0.51, -h * 0.83), Vector2(w * 0.46, -h * 0.75), Vector2(-w * 0.46, -h * 0.75)]), Color("#F2CD69"), INK, 2.2)
	_line(c, pos + Vector2(-w * 0.28, -h * 0.66), pos + Vector2(w * 0.27, -h * 0.66), _alpha(WHITE, 0.75), 2.0)
	var mop_sway: float = sin(clock * 5.0) * 4.0
	_line(c, pos + Vector2(w * 0.19, -h * 0.83), pos + Vector2(w * 0.62 + mop_sway, -h * 1.48), INK, 3.0)
	_poly(c, pos, PackedVector2Array([Vector2(w * 0.48 + mop_sway, -h * 1.40), Vector2(w * 0.78 + mop_sway, -h * 1.51), Vector2(w * 0.82 + mop_sway, -h * 1.41), Vector2(w * 0.62 + mop_sway, -h * 1.31)]), TEAL, INK, 1.7)
	if occupied:
		_line(c, pos + Vector2(-w * 0.23, -h * 0.91), pos + Vector2(w * 0.22, -h * 0.91), INK, 2.0)


static func _draw_box(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool) -> void:
	var w: float = maxf(size.x, 30.0)
	var h: float = maxf(size.y, 25.0)
	_ellipse(c, pos + Vector2(2.0, 2.0), w * 0.49, 5.5, _alpha(INK, 0.18), Color.TRANSPARENT, 0.0)
	if damaged:
		var crushed: PackedVector2Array = PackedVector2Array([Vector2(-w * 0.48, -h * 0.10), Vector2(-w * 0.47, -h * 0.52), Vector2(-w * 0.34, -h * 0.69), Vector2(-w * 0.17, -h * 0.51), Vector2(-w * 0.04, -h * 0.68), Vector2(w * 0.10, -h * 0.48), Vector2(w * 0.27, -h * 0.63), Vector2(w * 0.47, -h * 0.50), Vector2(w * 0.43, -h * 0.08)])
		_poly(c, pos, crushed, Color("#B0835F"), INK, 3.0)
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.47, -h * 0.52), Vector2(-w * 0.34, -h * 0.69), Vector2(-w * 0.20, -h * 0.53), Vector2(-w * 0.16, -h * 0.39)]), Color("#D6AE87"), INK, 2.0)
		_poly(c, pos, PackedVector2Array([Vector2(w * 0.47, -h * 0.50), Vector2(w * 0.28, -h * 0.63), Vector2(w * 0.12, -h * 0.49), Vector2(w * 0.16, -h * 0.36)]), Color("#D6AE87"), INK, 2.0)
		_line(c, pos + Vector2(-w * 0.27, -h * 0.37), pos + Vector2(w * 0.24, -h * 0.36), _alpha(INK, 0.54), 1.4)
		_line(c, pos + Vector2(-w * 0.05, -h * 0.48), pos + Vector2(w * 0.02, -h * 0.08), _alpha(INK, 0.62), 1.6)
		for scrap in range(3):
			var scrap_x: float = (float(scrap) - 1.0) * w * 0.56
			var scrap_y: float = -4.0 - float((scrap + 1) % 2) * 4.0
			_poly(c, pos + Vector2(scrap_x, scrap_y), PackedVector2Array([Vector2(-8.0, -3.0), Vector2(6.0, -4.0), Vector2(10.0, 2.0), Vector2(-5.0, 3.0)]), Color("#D1A77F"), INK, 1.0, 1.0, float(scrap - 1) * 0.1)
	else:
		var body: PackedVector2Array = PackedVector2Array([Vector2(-w * 0.48, -h * 0.83), Vector2(-w * 0.35, -h), Vector2(w * 0.37, -h * 0.98), Vector2(w * 0.49, -h * 0.82), Vector2(w * 0.43, -h * 0.06), Vector2(-w * 0.43, -h * 0.06)])
		_poly(c, pos, body, Color("#C79B6E"), INK, 3.0)
		_poly(c, pos, PackedVector2Array([Vector2(w * 0.28, -h * 0.95), Vector2(w * 0.46, -h * 0.83), Vector2(w * 0.41, -h * 0.12), Vector2(w * 0.23, -h * 0.13)]), Color("#B78963"), _alpha(INK, 0.54), 1.0)
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.08, -h * 0.97), Vector2(w * 0.09, -h * 0.97), Vector2(w * 0.08, -h * 0.08), Vector2(-w * 0.08, -h * 0.08)]), Color("#E2BD8C"), INK, 1.5)
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.32, -h * 0.64), Vector2(-w * 0.09, -h * 0.64), Vector2(-w * 0.09, -h * 0.40), Vector2(-w * 0.32, -h * 0.40)]), PAPER, _alpha(INK, 0.48), 1.0)
		_line(c, pos + Vector2(-w * 0.28, -h * 0.56), pos + Vector2(-w * 0.13, -h * 0.56), TOMATO, 1.2)
		_line(c, pos + Vector2(-w * 0.29, -h * 0.49), pos + Vector2(-w * 0.16, -h * 0.49), _alpha(INK, 0.42), 1.0)
		_line(c, pos + Vector2(-w * 0.44, -h * 0.77), pos + Vector2(w * 0.43, -h * 0.77), _alpha(INK, 0.42), 1.0)
	_line(c, pos + Vector2(-w * 0.29, -h * 0.10), pos + Vector2(-w * 0.22, -h * 0.10), INK, 1.5)


static func _draw_files(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 34.0)
	var h: float = maxf(size.y, 28.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.49, 3.5, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.47, -h * 0.34), Vector2(-w * 0.38, -h * 0.82), Vector2(w * 0.39, -h * 0.82), Vector2(w * 0.47, -h * 0.34)]), Color("#718BA0"), INK, 2.5)
	for i in range(3):
		var offset: float = float(i) * 3.0
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.39 + offset, -h * (0.72 - float(i) * 0.12)), Vector2(-w * 0.18 + offset, -h * (0.72 - float(i) * 0.12)), Vector2(-w * 0.14 + offset, -h * 0.86), Vector2(-w * 0.36 + offset, -h * 0.86)]), MUSTARD if i == 0 else PAPER, INK, 1.4)
	_line(c, pos + Vector2(-w * 0.37, -h * 0.43), pos + Vector2(w * 0.37, -h * 0.43), INK, 1.5)
	if damaged:
		for i in range(7):
			var spread: float = float(i) - 3.0
			var dx: float = spread * w * 0.36 + sin(float(i) * 2.13) * w * 0.08
			var dy: float = -h * (0.26 + float(posmod(i, 3)) * 0.13) + sin(clock * 1.7 + float(i)) * 1.2
			var paper_width: float = 12.0 + float(posmod(i, 2)) * 3.0
			var paper_height: float = 17.0 + float(posmod(i, 3)) * 3.0
			var sheet: PackedVector2Array = PackedVector2Array([Vector2(-paper_width, -paper_height), Vector2(paper_width, -paper_height + 1.0), Vector2(paper_width + 1.0, paper_height), Vector2(-paper_width + 1.0, paper_height - 1.0)])
			var sheet_angle: float = float(i - 3) * 0.12 + sin(clock * 1.4 + float(i)) * 0.025
			_poly(c, pos + Vector2(dx, dy), sheet, WHITE if i % 2 == 0 else Color("#EADCBF"), INK, 1.1, 1.0, sheet_angle)
			_line(c, pos + Vector2(dx - paper_width * 0.5, dy - 2.0), pos + Vector2(dx + paper_width * 0.45, dy - 2.0), _alpha(WALL, 0.9), 1.0)


static func _draw_bin(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 30.0)
	var h: float = maxf(size.y, 35.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.46, 4.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.39, -h * 0.78), Vector2(w * 0.38, -h * 0.78), Vector2(w * 0.28, -h * 0.06), Vector2(-w * 0.29, -h * 0.06)]), Color("#738899"), INK, 2.8)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.82), Vector2(-w * 0.40, -h * 0.94), Vector2(w * 0.42, -h * 0.94), Vector2(w * 0.48, -h * 0.82), Vector2(w * 0.44, -h * 0.75), Vector2(-w * 0.44, -h * 0.75)]), Color("#96A8B0"), INK, 2.2)
	for i in range(3):
		var rib_x: float = (float(i) - 1.0) * w * 0.21
		_line(c, pos + Vector2(rib_x, -h * 0.67), pos + Vector2(rib_x * 0.82, -h * 0.14), _alpha(INK, 0.45), 1.4)
	if damaged:
		_poly(c, pos, PackedVector2Array([Vector2(w * 0.10, -h * 0.92), Vector2(w * 0.50, -h * 1.02), Vector2(w * 0.62, -h * 0.90), Vector2(w * 0.49, -h * 0.80)]), Color("#96A8B0"), INK, 2.0, 1.0, sin(clock * 8.0) * 0.04)


static func _draw_plant(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 34.0)
	var h: float = maxf(size.y, 46.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.48, 4.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	var leaf_wobble: float = sin(clock * 2.8) * 2.5
	_line(c, pos + Vector2(0.0, -h * 0.31), pos + Vector2(-w * 0.08, -h * 0.82), INK, 2.0)
	_line(c, pos + Vector2(0.0, -h * 0.42), pos + Vector2(w * 0.28 + leaf_wobble, -h * 0.76), INK, 2.0)
	_line(c, pos + Vector2(-w * 0.02, -h * 0.49), pos + Vector2(-w * 0.31 - leaf_wobble, -h * 0.72), INK, 2.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.12, -h * 0.64), Vector2(-w * 0.35, -h * 0.78), Vector2(-w * 0.42, -h * 0.64), Vector2(-w * 0.26, -h * 0.52)]), TEAL, INK, 1.7)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.09, -h * 0.71), Vector2(-w * 0.04, -h), Vector2(w * 0.12, -h * 0.98), Vector2(w * 0.18, -h * 0.69)]), Color("#68A998"), INK, 1.7)
	_poly(c, pos, PackedVector2Array([Vector2(0, -h * 0.61), Vector2(w * 0.26, -h * 0.82), Vector2(w * 0.39, -h * 0.70), Vector2(w * 0.16, -h * 0.50)]), Color("#84B79C"), INK, 1.7)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.36, -h * 0.39), Vector2(w * 0.36, -h * 0.39), Vector2(w * 0.27, -h * 0.05), Vector2(-w * 0.26, -h * 0.05)]), Color("#C57C65"), INK, 2.6)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.40, -h * 0.43), Vector2(-w * 0.35, -h * 0.51), Vector2(w * 0.35, -h * 0.51), Vector2(w * 0.42, -h * 0.43), Vector2(w * 0.38, -h * 0.36), Vector2(-w * 0.37, -h * 0.36)]), Color("#D89073"), INK, 2.0)
	if damaged:
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.22, -h * 0.52), Vector2(w * 0.23, -h * 0.49), Vector2(w * 0.13, -h * 0.40), Vector2(-w * 0.15, -h * 0.40)]), Color("#795F50"), INK, 1.2)
		_line(c, pos + Vector2(w * 0.24, -h * 0.76), pos + Vector2(w * 0.45, -h * 0.92), TEAL, 2.0)


static func _draw_glass(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool) -> void:
	var w: float = maxf(size.x, 54.0)
	var h: float = maxf(size.y, 100.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.46, 5.0, _alpha(INK, 0.10), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.47, -h), Vector2(-w * 0.37, -h), Vector2(-w * 0.37, -h * 0.04), Vector2(-w * 0.47, 0)]), SHADE, INK, 2.6)
	_poly(c, pos, PackedVector2Array([Vector2(w * 0.37, -h), Vector2(w * 0.47, -h), Vector2(w * 0.47, 0), Vector2(w * 0.37, -h * 0.04)]), SHADE, INK, 2.6)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.36, -h * 0.96), Vector2(w * 0.36, -h * 0.96), Vector2(w * 0.36, -h * 0.05), Vector2(-w * 0.36, -h * 0.05)]), Color("#BAD9D9"), INK, 2.2)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.25, -h * 0.82), Vector2(-w * 0.15, -h * 0.90), Vector2(-w * 0.15, -h * 0.20), Vector2(-w * 0.25, -h * 0.14)]), _alpha(WHITE, 0.52), Color.TRANSPARENT, 0.0)
	_ellipse(c, pos + Vector2(w * 0.23, -h * 0.48), 2.8, 2.8, MUSTARD, INK, 1.1, 12)
	if damaged:
		_line(c, pos + Vector2(-w * 0.13, -h * 0.72), pos + Vector2(0.0, -h * 0.56), INK, 2.0)
		_line(c, pos + Vector2(0.0, -h * 0.56), pos + Vector2(-w * 0.08, -h * 0.39), INK, 2.0)
		_line(c, pos + Vector2(0.0, -h * 0.56), pos + Vector2(w * 0.18, -h * 0.51), INK, 2.0)
		_line(c, pos + Vector2(-w * 0.12, -h * 0.72), pos + Vector2(-w * 0.23, -h * 0.75), INK, 1.7)
		_line(c, pos + Vector2(-w * 0.08, -h * 0.39), pos + Vector2(-w * 0.16, -h * 0.30), INK, 1.7)


static func _draw_cooler(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 42.0)
	var h: float = maxf(size.y, 76.0)
	_ellipse(c, pos + Vector2(2.0, 2.0), w * 0.54, 6.0, _alpha(INK, 0.19), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.38, -h * 0.48), Vector2(w * 0.38, -h * 0.48), Vector2(w * 0.34, -h * 0.07), Vector2(-w * 0.34, -h * 0.07)]), Color("#E6E4DA"), INK, 2.8)
	_poly(c, pos, PackedVector2Array([Vector2(w * 0.25, -h * 0.46), Vector2(w * 0.38, -h * 0.48), Vector2(w * 0.34, -h * 0.07), Vector2(w * 0.21, -h * 0.08)]), Color("#C4C8C1"), _alpha(INK, 0.64), 1.1)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.30, -h * 0.46), Vector2(-w * 0.21, -h * 0.46), Vector2(-w * 0.21, -h * 0.10), Vector2(-w * 0.29, -h * 0.10)]), _alpha(WHITE, 0.68), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.30, -h * 0.50), Vector2(-w * 0.24, -h * 0.76), Vector2(w * 0.25, -h * 0.76), Vector2(w * 0.32, -h * 0.50)]), Color("#B5D4D8"), INK, 2.0)
	_ellipse(c, pos + Vector2(0.0, -h * 0.78), w * 0.27, h * 0.05, Color("#BAD9D9"), INK, 2.0, 16)
	_ellipse(c, pos + Vector2(0.0, -h * 0.88), w * 0.20, h * 0.018, _alpha(WHITE, 0.62), Color.TRANSPARENT, 0.0, 16)
	_line(c, pos + Vector2(-w * 0.20, -h * 0.68), pos + Vector2(-w * 0.17, -h * 0.54), _alpha(WHITE, 0.55), 1.2)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.16, -h * 0.76), Vector2(-w * 0.19, -h * 0.96), Vector2(-w * 0.10, -h), Vector2(w * 0.11, -h), Vector2(w * 0.18, -h * 0.95), Vector2(w * 0.15, -h * 0.76)]), TOMATO, INK, 2.4)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.10, -h * 0.88), Vector2(w * 0.10, -h * 0.88), Vector2(w * 0.10, -h * 0.78), Vector2(-w * 0.10, -h * 0.78)]), Color("#8DC7D1"), INK, 1.4)
	c.draw_rect(Rect2(pos + Vector2(-w * 0.18, -h * 0.43), Vector2(w * 0.36, h * 0.11)), INK, true)
	c.draw_rect(Rect2(pos + Vector2(-w * 0.16, -h * 0.42), Vector2(w * 0.11, h * 0.07)), TOMATO, true)
	c.draw_rect(Rect2(pos + Vector2(w * 0.04, -h * 0.42), Vector2(w * 0.10, h * 0.07)), Color("#6BAFC1"), true)
	_line(c, pos + Vector2(-w * 0.18, -h * 0.30), pos + Vector2(w * 0.18, -h * 0.30), _alpha(INK, 0.42), 1.0)
	for vent in range(4):
		var vent_x: float = -w * 0.18 + float(vent) * w * 0.12
		_line(c, pos + Vector2(vent_x, -h * 0.18), pos + Vector2(vent_x, -h * 0.11), _alpha(INK, 0.38), 1.0)
	if damaged:
		_ellipse(c, pos + Vector2(w * 0.18, 1.0), w * 0.34, 4.4, _alpha(Color("#76C7D0"), 0.42), Color.TRANSPARENT, 0.0, 20)
		_line(c, pos + Vector2(w * 0.02, -h * 0.10), pos + Vector2(w * 0.14, -h * 0.20), Color("#6BAFC1"), 3.0)
		_line(c, pos + Vector2(w * 0.14, -h * 0.20), pos + Vector2(w * 0.20, -h * 0.10), Color("#6BAFC1"), 2.2)
		for drop in range(3):
			var dx: float = w * (0.20 + float(drop) * 0.13)
			var dy: float = -h * 0.06 + sin(clock * 5.0 + float(drop)) * 3.0
			_ellipse(c, pos + Vector2(dx, dy), 2.8, 4.5, Color("#79C9D0"), Color("#397C8B"), 0.9, 10)


static func _draw_monitor(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 52.0)
	var h: float = maxf(size.y, 42.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.45, 3.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h), Vector2(w * 0.48, -h), Vector2(w * 0.45, -h * 0.34), Vector2(-w * 0.45, -h * 0.34)]), INK, INK, 2.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.40, -h * 0.92), Vector2(w * 0.40, -h * 0.92), Vector2(w * 0.37, -h * 0.42), Vector2(-w * 0.37, -h * 0.42)]), Color("#8AB8BF"), _alpha(WHITE, 0.45), 1.2)
	if damaged:
		_line(c, pos + Vector2(-w * 0.31, -h * 0.78), pos + Vector2(w * 0.30, -h * 0.72), TOMATO, 3.0)
		_line(c, pos + Vector2(-w * 0.23, -h * 0.62), pos + Vector2(w * 0.25, -h * 0.65), MUSTARD, 2.0)
		_line(c, pos + Vector2(-w * 0.36, -h * 0.53), pos + Vector2(w * 0.34, -h * 0.56), INK, 1.8)
	else:
		_line(c, pos + Vector2(-w * 0.25, -h * 0.73), pos + Vector2(w * 0.20, -h * 0.73), _alpha(WHITE, 0.8), 2.0)
		_line(c, pos + Vector2(-w * 0.25, -h * 0.62), pos + Vector2(w * 0.02, -h * 0.62), _alpha(WHITE, 0.6), 1.4)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.08, -h * 0.35), Vector2(w * 0.08, -h * 0.35), Vector2(w * 0.10, -h * 0.12), Vector2(-w * 0.10, -h * 0.12)]), SHADE, INK, 1.6)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.24, -h * 0.12), Vector2(w * 0.24, -h * 0.12), Vector2(w * 0.38, -h * 0.04), Vector2(-w * 0.38, -h * 0.04)]), SHADE, INK, 1.8)


static func _draw_printer(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 50.0)
	var h: float = maxf(size.y, 40.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.46, 3.5, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.45, -h * 0.62), Vector2(-w * 0.35, -h * 0.92), Vector2(w * 0.32, -h * 0.92), Vector2(w * 0.45, -h * 0.63), Vector2(w * 0.42, -h * 0.08), Vector2(-w * 0.42, -h * 0.08)]), Color("#E7E3D9"), INK, 2.8)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.38, -h * 0.70), Vector2(w * 0.38, -h * 0.70), Vector2(w * 0.31, -h * 0.50), Vector2(-w * 0.31, -h * 0.50)]), Color("#C9D5D2"), INK, 1.5)
	_line(c, pos + Vector2(-w * 0.27, -h * 0.37), pos + Vector2(w * 0.23, -h * 0.37), INK, 1.5)
	_ellipse(c, pos + Vector2(w * 0.30, -h * 0.58), 2.7, 2.7, TEAL, INK, 1.0, 10)
	if damaged:
		var paper_y: float = -h * 0.89 + sin(clock * 8.0) * 2.0
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.18, paper_y), Vector2(w * 0.15, paper_y), Vector2(w * 0.23, -h * 1.30), Vector2(-w * 0.12, -h * 1.26)]), WHITE, INK, 1.7)
		_line(c, pos + Vector2(-w * 0.06, -h * 1.16), pos + Vector2(w * 0.12, -h * 1.17), WALL, 1.0)
		_line(c, pos + Vector2(-w * 0.08, -h * 1.10), pos + Vector2(w * 0.09, -h * 1.11), WALL, 1.0)
	else:
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.12, -h * 0.94), Vector2(w * 0.12, -h * 0.94), Vector2(w * 0.18, -h * 0.68), Vector2(-w * 0.18, -h * 0.68)]), WHITE, INK, 1.5)


static func _draw_fan(c: CanvasItem, pos: Vector2, size: Vector2, clock: float) -> void:
	var w: float = maxf(size.x, 52.0)
	var h: float = maxf(size.y, 54.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.45, 4.0, _alpha(INK, 0.11), Color.TRANSPARENT, 0.0)
	_line(c, pos + Vector2(0.0, -h * 0.10), pos + Vector2(0.0, -h * 0.78), INK, 4.0)
	_ellipse(c, pos + Vector2(0.0, -h * 0.85), w * 0.43, h * 0.43, Color("#D2E0DF"), INK, 2.4, 18)
	var rotation: float = clock * 5.0
	for blade in range(3):
		var angle: float = rotation + TAU * float(blade) / 3.0
		var tip: Vector2 = Vector2(cos(angle) * w * 0.34, sin(angle) * h * 0.34 - h * 0.85)
		var middle: Vector2 = Vector2(cos(angle + 0.55) * w * 0.15, sin(angle + 0.55) * h * 0.15 - h * 0.85)
		_poly(c, pos, PackedVector2Array([Vector2(0.0, -h * 0.85), middle, tip, Vector2(cos(angle - 0.46) * w * 0.12, sin(angle - 0.46) * h * 0.12 - h * 0.85)]), TEAL, INK, 1.5)
	_ellipse(c, pos + Vector2(0.0, -h * 0.85), 5.0, 5.0, MUSTARD, INK, 1.5, 12)
	for i in range(3):
		var dx: float = (float(i) - 1.0) * 12.0
		_line(c, pos + Vector2(dx, -h * 1.42), pos + Vector2(dx + 3.0, -h * 1.32), _alpha(TEAL, 0.72), 1.5)


static func _draw_belt(c: CanvasItem, pos: Vector2, size: Vector2, clock: float) -> void:
	var w: float = maxf(size.x, 100.0)
	var h: float = maxf(size.y, 32.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.50, -h * 0.52), Vector2(-w * 0.43, -h * 0.95), Vector2(w * 0.42, -h * 0.95), Vector2(w * 0.50, -h * 0.52), Vector2(w * 0.43, -h * 0.10), Vector2(-w * 0.44, -h * 0.10)]), Color("#748696"), INK, 2.8)
	_line(c, pos + Vector2(-w * 0.43, -h * 0.16), pos + Vector2(w * 0.43, -h * 0.16), MUSTARD, 2.0)
	for i in range(5):
		var stripe_x: float = -w * 0.35 + float(i) * w * 0.17 + fposmod(clock * 18.0, w * 0.17)
		while stripe_x > w * 0.42:
			stripe_x -= w * 0.85
		_line(c, pos + Vector2(stripe_x, -h * 0.62), pos + Vector2(stripe_x + 8.0, -h * 0.34), _alpha(PAPER, 0.72), 2.0)
	for i in range(4):
		var arrow_x: float = -w * 0.30 + float(i) * w * 0.20
		_line(c, pos + Vector2(arrow_x, -h * 0.79), pos + Vector2(arrow_x + 8.0, -h * 0.68), MUSTARD, 2.0)
		_line(c, pos + Vector2(arrow_x + 8.0, -h * 0.68), pos + Vector2(arrow_x, -h * 0.57), MUSTARD, 2.0)


static func _draw_paper_machine(c: CanvasItem, pos: Vector2, size: Vector2, damaged: bool, clock: float) -> void:
	var w: float = maxf(size.x, 54.0)
	var h: float = maxf(size.y, 60.0)
	_draw_printer(c, pos, size, damaged, clock)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.46, -h * 0.91), Vector2(w * 0.46, -h * 0.91), Vector2(w * 0.42, -h * 0.78), Vector2(-w * 0.42, -h * 0.78)]), TOMATO, INK, 1.8)
	_ellipse(c, pos + Vector2(w * 0.31, -h * 0.85), 3.5, 3.5, MUSTARD, INK, 1.0, 10)
	if damaged:
		for i in range(3):
			var page_x: float = float(i - 1) * w * 0.27
			_poly(c, pos, PackedVector2Array([Vector2(page_x - 5.0, -h * 1.07), Vector2(page_x + 7.0, -h * 1.07), Vector2(page_x + 12.0, -h * 1.35), Vector2(page_x - 9.0, -h * 1.32)]), WHITE, INK, 1.3)


static func _draw_reception(c: CanvasItem, pos: Vector2, size: Vector2) -> void:
	var w: float = maxf(size.x, 110.0)
	var h: float = maxf(size.y, 54.0)
	_ellipse(c, pos + Vector2(0.0, 1.0), w * 0.48, 4.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.50, -h * 0.84), Vector2(w * 0.47, -h * 0.84), Vector2(w * 0.42, -h * 0.06), Vector2(-w * 0.42, -h * 0.06)]), Color("#78949C"), INK, 3.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.54, -h * 0.92), Vector2(-w * 0.46, -h), Vector2(w * 0.49, -h), Vector2(w * 0.55, -h * 0.91)]), Color("#91AAA9"), INK, 2.5)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.27, -h * 0.75), Vector2(w * 0.14, -h * 0.75), Vector2(w * 0.14, -h * 0.20), Vector2(-w * 0.27, -h * 0.20)]), Color("#DCE6DE"), INK, 1.7)
	_line(c, pos + Vector2(-w * 0.20, -h * 0.59), pos + Vector2(w * 0.08, -h * 0.59), WALL, 1.5)
	_line(c, pos + Vector2(-w * 0.20, -h * 0.48), pos + Vector2(w * 0.08, -h * 0.48), WALL, 1.5)
	_ellipse(c, pos + Vector2(w * 0.33, -h * 0.56), 5.0, 5.0, MUSTARD, INK, 1.3, 12)


static func _draw_gate(c: CanvasItem, pos: Vector2, size: Vector2, clock: float) -> void:
	var w: float = maxf(size.x, 62.0)
	var h: float = maxf(size.y, 46.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.46, -h * 0.58), Vector2(w * 0.46, -h * 0.58), Vector2(w * 0.38, -h * 0.07), Vector2(-w * 0.38, -h * 0.07)]), Color("#9DAEB1"), INK, 2.6)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.63), Vector2(-w * 0.36, -h * 0.84), Vector2(w * 0.36, -h * 0.84), Vector2(w * 0.48, -h * 0.63)]), Color("#D9E3DC"), INK, 2.0)
	_line(c, pos + Vector2(-w * 0.18, -h * 0.38), pos + Vector2(w * 0.18, -h * 0.38), INK, 2.0)
	_ellipse(c, pos + Vector2(0.0, -h * 0.69), 5.0, 5.0, TEAL if int(clock * 2.0) % 4 != 0 else MUSTARD, INK, 1.1, 12)
	_line(c, pos + Vector2(w * 0.28, -h * 0.59), pos + Vector2(w * 0.77, -h * (0.59 + sin(clock * 1.7) * 0.16)), INK, 3.0)
	_ellipse(c, pos + Vector2(-w * 0.34, -h * 0.04), 4.0, 3.0, INK, INK, 1.0, 10)
	_ellipse(c, pos + Vector2(w * 0.34, -h * 0.04), 4.0, 3.0, INK, INK, 1.0, 10)


static func _draw_desk(c: CanvasItem, pos: Vector2, size: Vector2) -> void:
	var w: float = maxf(size.x, 112.0)
	var h: float = maxf(size.y, 66.0)
	_ellipse(c, pos + Vector2(2.0, 2.0), w * 0.57, 7.0, _alpha(INK, 0.19), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.69), Vector2(w * 0.48, -h * 0.69), Vector2(w * 0.50, -h * 0.49), Vector2(-w * 0.50, -h * 0.49)]), Color("#A68168"), INK, 2.8)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.46, -h * 0.68), Vector2(w * 0.45, -h * 0.68), Vector2(w * 0.47, -h * 0.57), Vector2(-w * 0.47, -h * 0.57)]), Color("#C09B7D"), _alpha(INK, 0.45), 1.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.40, -h * 0.49), Vector2(-w * 0.27, -h * 0.49), Vector2(-w * 0.28, -h * 0.06), Vector2(-w * 0.41, -h * 0.06)]), Color("#A68168"), INK, 2.0)
	_poly(c, pos, PackedVector2Array([Vector2(w * 0.27, -h * 0.49), Vector2(w * 0.40, -h * 0.49), Vector2(w * 0.42, -h * 0.06), Vector2(w * 0.29, -h * 0.06)]), Color("#A68168"), INK, 2.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.29, -h * 0.40), Vector2(w * 0.29, -h * 0.40), Vector2(w * 0.27, -h * 0.08), Vector2(-w * 0.27, -h * 0.08)]), Color("#B89174"), INK, 1.6)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.25, -h * 0.34), Vector2(w * 0.25, -h * 0.34), Vector2(w * 0.24, -h * 0.12), Vector2(-w * 0.24, -h * 0.12)]), _alpha(Color("#D2B496"), 0.55), _alpha(INK, 0.36), 1.0)
	_line(c, pos + Vector2(-w * 0.07, -h * 0.30), pos + Vector2(w * 0.07, -h * 0.30), MUSTARD, 2.0)
	_line(c, pos + Vector2(w * 0.19, -h * 0.60), pos + Vector2(w * 0.30, -h * 0.60), MUSTARD, 2.0)
	c.draw_rect(Rect2(pos + Vector2(-w * 0.18, -h * 0.97), Vector2(w * 0.36, h * 0.27)), Color("#677A82"), false, 2.0)
	c.draw_rect(Rect2(pos + Vector2(-w * 0.15, -h * 0.94), Vector2(w * 0.30, h * 0.19)), Color("#B9D2D0"))
	c.draw_rect(Rect2(pos + Vector2(-w * 0.11, -h * 0.90), Vector2(w * 0.18, 2.0)), _alpha(WHITE, 0.72))
	c.draw_rect(Rect2(pos + Vector2(-w * 0.11, -h * 0.85), Vector2(w * 0.23, 1.5)), _alpha(WHITE, 0.48))
	c.draw_line(pos + Vector2(0.0, -h * 0.70), pos + Vector2(0.0, -h * 0.68), INK, 3.0, true)
	c.draw_line(pos + Vector2(-w * 0.12, -h * 0.68), pos + Vector2(w * 0.12, -h * 0.68), INK, 3.0, true)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.38, -h * 0.72), Vector2(-w * 0.17, -h * 0.72), Vector2(-w * 0.16, -h * 0.62), Vector2(-w * 0.40, -h * 0.62)]), PAPER, _alpha(INK, 0.58), 1.0)
	_line(c, pos + Vector2(-w * 0.35, -h * 0.69), pos + Vector2(-w * 0.22, -h * 0.69), TOMATO, 1.2)
	_line(c, pos + Vector2(-w * 0.35, -h * 0.66), pos + Vector2(-w * 0.25, -h * 0.66), _alpha(INK, 0.5), 0.9)
	_ellipse(c, pos + Vector2(w * 0.37, -h * 0.68), w * 0.045, h * 0.035, Color("#D5B59A"), INK, 1.1, 12)
	_line(c, pos + Vector2(w * 0.35, -h * 0.65), pos + Vector2(w * 0.39, -h * 0.65), _alpha(WHITE, 0.8), 1.0)
	_line(c, pos + Vector2(-w * 0.37, -h * 0.05), pos + Vector2(-w * 0.35, 0.0), INK, 2.0, true)
	_line(c, pos + Vector2(w * 0.38, -h * 0.05), pos + Vector2(w * 0.40, 0.0), INK, 2.0, true)


static func _draw_storage(c: CanvasItem, pos: Vector2, size: Vector2, cabinet: bool) -> void:
	var w: float = maxf(size.x, 56.0)
	var h: float = maxf(size.y, 76.0)
	var fill: Color = Color("#8EA5AA") if cabinet else Color("#93ADB0")
	_ellipse(c, pos + Vector2(2.0, 2.0), w * 0.53, 6.0, _alpha(INK, 0.17), Color.TRANSPARENT, 0.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.46, -h), Vector2(w * 0.46, -h), Vector2(w * 0.46, -h * 0.04), Vector2(-w * 0.46, -h * 0.04)]), fill, INK, 2.8)
	_poly(c, pos, PackedVector2Array([Vector2(w * 0.31, -h * 0.98), Vector2(w * 0.46, -h), Vector2(w * 0.46, -h * 0.04), Vector2(w * 0.31, -h * 0.04)]), fill.darkened(0.12), _alpha(INK, 0.6), 1.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.41, -h * 0.93), Vector2(-w * 0.31, -h * 0.95), Vector2(-w * 0.31, -h * 0.08), Vector2(-w * 0.41, -h * 0.08)]), _alpha(WHITE, 0.18), Color.TRANSPARENT, 0.0)
	_line(c, pos + Vector2(-w * 0.43, -h * 0.53), pos + Vector2(w * 0.43, -h * 0.53), INK, 2.0)
	if cabinet:
		_poly(c, pos, PackedVector2Array([Vector2(-w * 0.39, -h * 0.91), Vector2(-w * 0.03, -h * 0.91), Vector2(-w * 0.03, -h * 0.57), Vector2(-w * 0.39, -h * 0.57)]), _alpha(PAPER, 0.11), _alpha(INK, 0.56), 1.0)
		_poly(c, pos, PackedVector2Array([Vector2(w * 0.03, -h * 0.91), Vector2(w * 0.39, -h * 0.91), Vector2(w * 0.39, -h * 0.57), Vector2(w * 0.03, -h * 0.57)]), _alpha(PAPER, 0.08), _alpha(INK, 0.56), 1.0)
		_line(c, pos + Vector2(0.0, -h * 0.96), pos + Vector2(0.0, -h * 0.06), _alpha(INK, 0.76), 1.8)
		for handle_y in [-h * 0.76, -h * 0.25]:
			_ellipse(c, pos + Vector2(-w * 0.09, handle_y), 1.8, 2.7, MUSTARD, INK, 0.8, 10)
			_ellipse(c, pos + Vector2(w * 0.09, handle_y), 1.8, 2.7, MUSTARD, INK, 0.8, 10)
		_line(c, pos + Vector2(-w * 0.27, -h * 0.12), pos + Vector2(w * 0.27, -h * 0.12), _alpha(WHITE, 0.4), 1.0)
	else:
		for shelf_index in range(2):
			var shelf_y: float = -h * (0.78 - float(shelf_index) * 0.32)
			for book_index in range(4):
				var bx: float = -w * 0.34 + float(book_index) * w * 0.20
				var book_h: float = h * (0.13 + float((book_index + shelf_index) % 2) * 0.06)
				var book_color: Color = TEAL if book_index % 2 == 0 else MUSTARD
				_poly(c, pos, PackedVector2Array([Vector2(bx, shelf_y), Vector2(bx + w * 0.13, shelf_y), Vector2(bx + w * 0.13, shelf_y - book_h), Vector2(bx, shelf_y - book_h)]), book_color, INK, 1.0)


static func _draw_sofa(c: CanvasItem, pos: Vector2, size: Vector2) -> void:
	var w: float = maxf(size.x, 110.0)
	var h: float = maxf(size.y, 54.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.26), Vector2(-w * 0.48, -h * 0.82), Vector2(-w * 0.37, -h), Vector2(w * 0.37, -h), Vector2(w * 0.48, -h * 0.82), Vector2(w * 0.48, -h * 0.26)]), Color("#6C9F9B"), INK, 3.0)
	_poly(c, pos, PackedVector2Array([Vector2(-w * 0.48, -h * 0.62), Vector2(w * 0.48, -h * 0.62), Vector2(w * 0.42, -h * 0.12), Vector2(-w * 0.42, -h * 0.12)]), Color("#78AAA4"), INK, 2.0)
	_line(c, pos + Vector2(-w * 0.06, -h * 0.60), pos + Vector2(-w * 0.04, -h * 0.16), _alpha(INK, 0.5), 1.5)
	_line(c, pos + Vector2(-w * 0.37, -h * 0.09), pos + Vector2(-w * 0.34, 0.0), INK, 2.0)
	_line(c, pos + Vector2(w * 0.37, -h * 0.09), pos + Vector2(w * 0.34, 0.0), INK, 2.0)


static func _draw_face(c: CanvasItem, origin: Vector2, direction: float, rotation: float, skin_color: Color, hair_color: Color, expression: String, hair_style: int, clock: float, blink_amount: float = 0.0) -> void:
	var head: PackedVector2Array = PackedVector2Array([Vector2(-22, -78), Vector2(-21, -91), Vector2(-12, -100), Vector2(4, -102), Vector2(18, -95), Vector2(24, -82), Vector2(23, -68), Vector2(15, -58), Vector2(-2, -56), Vector2(-17, -61)])
	_poly(c, origin, head, skin_color, INK, 3.2, direction, rotation)
	if hair_style == 0:
		_poly(c, origin, PackedVector2Array([Vector2(-21, -81), Vector2(-24, -92), Vector2(-15, -100), Vector2(-12, -107), Vector2(-5, -101), Vector2(2, -108), Vector2(8, -101), Vector2(17, -102), Vector2(24, -92), Vector2(21, -80), Vector2(11, -86), Vector2(1, -83), Vector2(-9, -86)]), hair_color, INK, 2.4, direction, rotation)
	elif hair_style == 1:
		_poly(c, origin, PackedVector2Array([Vector2(-22, -80), Vector2(-24, -91), Vector2(-15, -101), Vector2(-2, -104), Vector2(11, -100), Vector2(22, -91), Vector2(22, -82), Vector2(11, -88), Vector2(0, -85), Vector2(-10, -88)]), hair_color, INK, 2.4, direction, rotation)
	else:
		_poly(c, origin, PackedVector2Array([Vector2(-22, -81), Vector2(-22, -92), Vector2(-14, -101), Vector2(-4, -104), Vector2(6, -100), Vector2(20, -101), Vector2(24, -91), Vector2(22, -80), Vector2(11, -85), Vector2(3, -83), Vector2(-5, -88), Vector2(-13, -85)]), hair_color, INK, 2.4, direction, rotation)
		_ellipse(c, _xf(origin, Vector2(20, -94), direction, rotation), 5.0, 6.0, hair_color, INK, 1.8, 12)
	var tired: bool = expression == "tired" or expression == "sleep"
	var eye_open: float = 1.0 - clampf(blink_amount, 0.0, 1.0)
	for eye_side in [-1.0, 1.0]:
		var eye_x: float = eye_side * 8.3
		_ellipse(c, _xf(origin, Vector2(eye_x, -72.0), direction, rotation), 6.2, 3.3, _alpha(SHADE, 0.54), Color.TRANSPARENT, 0.0, 14)
		var eye_h: float = (5.0 if tired else (8.0 if expression == "alert" else 6.4)) * maxf(eye_open, 0.08)
		_ellipse(c, _xf(origin, Vector2(eye_x, -77.0), direction, rotation), 5.2, eye_h, WHITE, INK, 1.4, 14)
		if eye_open > 0.22:
			var pupil_x: float = eye_x + 1.2 if direction > 0.0 else eye_x - 1.2
			var pupil_y: float = -76.0 if not tired else -77.0
			_ellipse(c, _xf(origin, Vector2(pupil_x, pupil_y), direction, rotation), 2.2, 3.0 * eye_open, INK, INK, 0.6, 10)
			_ellipse(c, _xf(origin, Vector2(pupil_x + 0.8, pupil_y - 1.3), direction, rotation), 0.9, 1.0, WHITE, WHITE, 0.2, 8)
		if tired or blink_amount > 0.55:
			_line(c, _xf(origin, Vector2(eye_x - 5.0, -79.0), direction, rotation), _xf(origin, Vector2(eye_x + 5.0, -79.0), direction, rotation), hair_color, 2.0)
	if expression == "stern":
		_line(c, _xf(origin, Vector2(-14.0, -88.0), direction, rotation), _xf(origin, Vector2(-3.0, -86.0), direction, rotation), hair_color, 2.0)
		_line(c, _xf(origin, Vector2(3.0, -86.0), direction, rotation), _xf(origin, Vector2(14.0, -88.0), direction, rotation), hair_color, 2.0)
	elif expression == "alert":
		_line(c, _xf(origin, Vector2(-13.0, -87.0), direction, rotation), _xf(origin, Vector2(-5.0, -89.0), direction, rotation), hair_color, 1.8)
		_line(c, _xf(origin, Vector2(5.0, -89.0), direction, rotation), _xf(origin, Vector2(13.0, -87.0), direction, rotation), hair_color, 1.8)
	else:
		_line(c, _xf(origin, Vector2(-14.0, -87.0), direction, rotation), _xf(origin, Vector2(-4.0, -88.0), direction, rotation), hair_color, 1.6)
		_line(c, _xf(origin, Vector2(4.0, -88.0), direction, rotation), _xf(origin, Vector2(14.0, -87.0), direction, rotation), hair_color, 1.6)
	_ellipse(c, _xf(origin, Vector2(direction * 18.0, -73.0), direction, rotation), 2.0, 2.4, Color("#D99678"), INK, 0.9, 10)
	if expression == "smile" or expression == "desk":
		c.draw_arc(_xf(origin, Vector2(direction * 5.0, -66.0), direction, rotation), 5.0, 0.1, PI - 0.1, 10, INK, 1.8, true)
	elif expression == "alert":
		_ellipse(c, _xf(origin, Vector2(direction * 7.0, -64.0), direction, rotation), 2.2, 3.2, INK, INK, 0.6, 10)
	else:
		_line(c, _xf(origin, Vector2(direction * 2.0, -66.0), direction, rotation), _xf(origin, Vector2(direction * 10.0, -66.0), direction, rotation), INK, 1.7)


static func _draw_stars(c: CanvasItem, center: Vector2, clock: float) -> void:
	for i in range(3):
		var angle: float = clock * 1.7 + float(i) * TAU / 3.0
		var point: Vector2 = center + Vector2(cos(angle) * 8.0, sin(angle) * 4.0)
		var star: PackedVector2Array = PackedVector2Array([Vector2(0, -5), Vector2(1.5, -1.5), Vector2(5, 0), Vector2(1.5, 1.5), Vector2(0, 5), Vector2(-1.5, 1.5), Vector2(-5, 0), Vector2(-1.5, -1.5)])
		_poly(c, point, star, MUSTARD, INK, 1.1, 1.0, angle)


static func _draw_alert_mark(c: CanvasItem, center: Vector2, clock: float) -> void:
	var pulse: float = 1.0 + sin(clock * 8.0) * 0.08
	_poly(c, center, PackedVector2Array([Vector2(0, -10), Vector2(8, -5), Vector2(8, 5), Vector2(0, 10), Vector2(-8, 5), Vector2(-8, -5)]), TOMATO, INK, 1.7, 1.0, 0.0)
	_line(c, center + Vector2(0.0, -4.0 * pulse), center + Vector2(0.0, 2.0 * pulse), WHITE, 2.2)
	_ellipse(c, center + Vector2(0.0, 5.0), 1.3, 1.3, WHITE, WHITE, 0.5, 8)


static func _draw_limb(c: CanvasItem, origin: Vector2, start_point: Vector2, end_point: Vector2, thickness: float, fill: Color, mirror: float, rotation: float) -> void:
	var start: Vector2 = _xf(origin, start_point, mirror, rotation)
	var finish: Vector2 = _xf(origin, end_point, mirror, rotation)
	c.draw_line(start, finish, INK, thickness + 2.2, true)
	c.draw_line(start, finish, fill, thickness, true)
	_ellipse(c, start, thickness * 0.53, thickness * 0.53, fill, INK, 1.2, 12)
	_ellipse(c, finish, thickness * 0.53, thickness * 0.53, fill, INK, 1.2, 12)


static func _scale_y_points(points: PackedVector2Array, scale_y: float) -> PackedVector2Array:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point in points:
		scaled.append(Vector2(point.x, point.y * scale_y))
	return scaled


static func _blink_amount(clock: float) -> float:
	var phase: float = fposmod(clock, 4.0)
	if phase < 0.14:
		return sin(PI * phase / 0.14)
	if phase > 0.20 and phase < 0.30:
		return sin(PI * (phase - 0.20) / 0.10) * 0.68
	return 0.0


static func _effect_unit(seed: int, index: int, salt: int) -> float:
	var value: float = sin(float(seed) * 12.9898 + float(index) * 78.233 + float(salt) * 37.719) * 43758.5453
	return fposmod(value, 1.0)


static func _draw_city(c: CanvasItem, left: float, right: float, clock: float) -> void:
	var far_stride: float = 258.0
	var far_x: float = floor((left - 212.0) / far_stride) * far_stride
	while far_x <= right:
		var far_index: int = floori(far_x / far_stride)
		var far_width: float = 142.0 + float(posmod(far_index * 13, 3)) * 20.0
		var far_height: float = 54.0 + float(posmod(far_index * 19, 38))
		if far_x + far_width >= left and far_x <= right:
			c.draw_rect(Rect2(far_x, 152.0 - far_height, far_width, far_height), _alpha(Color("#C1D2D3"), 0.42))
			for floor_index in range(2):
				var row_y: float = 152.0 - far_height + 18.0 + float(floor_index) * 22.0
				for window_index in range(3):
					var light: float = 0.26 + float(posmod(far_index + window_index + floor_index, 3)) * 0.07
					c.draw_rect(Rect2(far_x + 14.0 + float(window_index) * 40.0, row_y, 16.0, 11.0), _alpha(PAPER, light))
		far_x += far_stride
	var stride: float = 390.0
	var base_x: float = floor((left - 264.0) / stride) * stride
	while base_x <= right:
		var global_index: int = floori(base_x / stride)
		var building_w: float = 190.0 + float(posmod(global_index, 3)) * 37.0
		var building_h: float = 57.0 + float(posmod(global_index * 31, 55))
		if base_x + building_w >= left and base_x <= right:
			var building_color: Color = Color("#AFC5CF") if global_index % 2 == 0 else Color("#A5BCC6")
			c.draw_rect(Rect2(base_x, 152.0 - building_h, building_w, building_h), _alpha(building_color, 0.72))
			c.draw_rect(Rect2(base_x + 7.0, 152.0 - building_h - 5.0, building_w - 14.0, 6.0), _alpha(building_color.darkened(0.08), 0.75))
			for row in range(3):
				for col in range(5):
					var window_x: float = base_x + 16.0 + float(col) * 35.0
					if window_x + 13.0 < base_x + building_w - 5.0:
						var window_y: float = 152.0 - building_h + 14.0 + float(row) * 22.0
						var light_alpha: float = 0.30 + float(posmod(global_index + row * 3 + col * 7, 4)) * 0.08
						c.draw_rect(Rect2(window_x, window_y, 13.0, 10.0), _alpha(PAPER, light_alpha))
						c.draw_rect(Rect2(window_x + 1.0, window_y + 1.0, 2.0, 7.0), _alpha(WHITE, 0.35))
		base_x += stride


static func _draw_office_window(c: CanvasItem, center: Vector2, trim: Color, clock: float = 0.0) -> void:
	var x: float = center.x
	var y: float = center.y
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 75.0, y + 72.0), Vector2(x + 72.0, y + 72.0), Vector2(x + 151.0, y + 288.0), Vector2(x - 167.0, y + 288.0)]), _alpha(Color("#F5E7C8"), 0.075), Color.TRANSPARENT, 0.0)
	c.draw_rect(Rect2(x - 100.0, y - 74.0, 200.0, 148.0), _alpha(INK, 0.12))
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 103, y - 77), Vector2(x + 103, y - 77), Vector2(x + 103, y + 77), Vector2(x - 103, y + 77)]), Color("#BCD5D7"), trim.darkened(0.1), 2.0)
	c.draw_rect(Rect2(x - 93.0, y - 67.0, 186.0, 134.0), Color("#C9DFDF"))
	c.draw_rect(Rect2(x - 89.0, y - 63.0, 63.0, 74.0), _alpha(Color("#F6E7BE"), 0.26))
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 18.0, y - 60.0), Vector2(x + 31.0, y - 60.0), Vector2(x + 1.0, y + 13.0), Vector2(x - 12.0, y + 13.0)]), _alpha(WHITE, 0.23), Color.TRANSPARENT, 0.0)
	_line(c, Vector2(x - 4.0, y - 66.0), Vector2(x - 4.0, y + 66.0), trim, 4.0)
	_line(c, Vector2(x - 92.0, y + 19.0), Vector2(x + 92.0, y + 19.0), trim, 4.0)
	_line(c, Vector2(x - 74.0, y - 48.0), Vector2(x - 38.0, y - 48.0), _alpha(WHITE, 0.7), 3.0)
	_line(c, Vector2(x + 22.0, y - 47.0), Vector2(x + 72.0, y - 47.0), _alpha(WHITE, 0.7), 3.0)
	var glint_x: float = x + 52.0 + sin(clock * 0.4 + x * 0.01) * 9.0
	_line(c, Vector2(glint_x, y - 39.0), Vector2(glint_x + 9.0, y - 22.0), _alpha(WHITE, 0.48), 2.0)


static func _draw_wall_sign(c: CanvasItem, center: Vector2, theme: int) -> void:
	var accent: Color = MUSTARD if theme % 2 == 0 else TEAL
	var x: float = center.x
	var y: float = center.y
	var labels: Array[String] = ["前台接待", "考勤处", "档案室", "复印区", "人事部"]
	var label: String = labels[posmod(theme, labels.size())]
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 75.0, y - 27.0), Vector2(x + 74.0, y - 29.0), Vector2(x + 77.0, y + 27.0), Vector2(x - 73.0, y + 29.0)]), PAPER, _alpha(INK, 0.62), 2.0)
	c.draw_rect(Rect2(x - 70.0, y - 24.0, 7.0, 48.0), accent)
	c.draw_string(OFFICE_FONT, Vector2(x - 53.0, y + 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)
	_ellipse(c, Vector2(x + 57.0, y - 14.0), 3.0, 3.0, TOMATO, INK, 0.8, 10)
	c.draw_line(Vector2(x - 47.0, y + 13.0), Vector2(x + 41.0, y + 13.0), _alpha(SHADE, 0.4), 1.0, true)


static func _draw_wall_feature(c: CanvasItem, center: Vector2, global_index: int, theme: int, clock: float) -> void:
	var x: float = center.x
	var y: float = center.y
	var feature_kind: int = posmod(global_index + theme, 4)
	if feature_kind == 0:
		var board_rect: Rect2 = Rect2(x - 153.0, y - 57.0, 306.0, 114.0)
		c.draw_rect(Rect2(board_rect.position + Vector2(5.0, 7.0), board_rect.size), _alpha(INK, 0.12))
		c.draw_rect(board_rect, Color("#BFA78C"))
		c.draw_rect(Rect2(x - 145.0, y - 49.0, 290.0, 20.0), Color("#8AA5A9"))
		c.draw_string(OFFICE_FONT, Vector2(x - 132.0, y - 34.0), "本周值班表", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, PAPER)
		var note_colors: Array[Color] = [PAPER, Color("#E8D8B7"), Color("#C9DBD2"), Color("#E7C8B9")]
		var note_titles: Array[String] = ["前台", "会议", "设备", "考勤"]
		for note in range(4):
			var nx: float = x - 130.0 + float(note) * 65.0
			var tilt: float = float(posmod(global_index + note, 3) - 1) * 0.025
			_poly(c, Vector2(nx, y + 1.0), PackedVector2Array([Vector2(-27.0, -12.0), Vector2(26.0, -13.0), Vector2(27.0, 27.0), Vector2(-25.0, 26.0)]), note_colors[note], _alpha(INK, 0.48), 1.0, 1.0, tilt)
			c.draw_string(OFFICE_FONT, Vector2(nx - 19.0, y + 5.0), note_titles[note], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, _alpha(INK, 0.78))
			c.draw_line(Vector2(nx - 17.0, y + 13.0), Vector2(nx + 16.0, y + 13.0), _alpha(INK, 0.42), 1.0, true)
		for pin in range(4):
			_ellipse(c, Vector2(x - 130.0 + float(pin) * 65.0, y - 12.0), 2.4, 2.4, TOMATO if pin % 2 == 0 else MUSTARD, INK, 0.8, 8)
	elif feature_kind == 1:
		var clock_center: Vector2 = Vector2(x, y + 3.0)
		_ellipse(c, clock_center + Vector2(4.0, 6.0), 53.0, 53.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0, 28)
		_ellipse(c, clock_center, 52.0, 52.0, PAPER, INK, 2.8, 32)
		_ellipse(c, clock_center, 44.0, 44.0, _alpha(WHITE, 0.75), _alpha(INK, 0.24), 1.0, 32)
		for tick in range(12):
			var tick_angle: float = TAU * float(tick) / 12.0
			var outer_tick: Vector2 = clock_center + Vector2(cos(tick_angle), sin(tick_angle)) * 39.0
			var inner_tick: Vector2 = clock_center + Vector2(cos(tick_angle), sin(tick_angle)) * (31.0 if tick % 3 == 0 else 34.0)
			_line(c, outer_tick, inner_tick, INK, 1.7 if tick % 3 == 0 else 1.0)
		var minute_angle: float = fposmod(clock * 0.32 + float(theme) * 0.8, TAU) - PI * 0.5
		var hour_angle: float = minute_angle * 0.083 - PI * 0.5
		_line(c, clock_center, clock_center + Vector2(cos(hour_angle), sin(hour_angle)) * 18.0, INK, 3.0)
		_line(c, clock_center, clock_center + Vector2(cos(minute_angle), sin(minute_angle)) * 31.0, TOMATO, 2.0)
		_ellipse(c, clock_center, 3.4, 3.4, MUSTARD, INK, 1.0, 10)
		c.draw_string(OFFICE_FONT, Vector2(x - 34.0, y + 72.0), "考勤挂钟", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, _alpha(INK, 0.78))
	elif feature_kind == 2:
		var banner: PackedVector2Array = PackedVector2Array([Vector2(x - 169.0, y - 37.0), Vector2(x + 169.0, y - 37.0), Vector2(x + 160.0, y + 37.0), Vector2(x - 161.0, y + 37.0)])
		_poly(c, Vector2.ZERO, banner, Color("#D7C8A8"), _alpha(INK, 0.58), 1.7)
		c.draw_rect(Rect2(x - 159.0, y - 27.0, 6.0, 54.0), MUSTARD)
		c.draw_string(OFFICE_FONT, Vector2(x - 135.0, y + 7.0), "准时打卡，午饭券不迟到", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)
		c.draw_line(Vector2(x - 133.0, y + 17.0), Vector2(x + 115.0, y + 17.0), _alpha(TEAL, 0.75), 2.0, true)
		for pin_x in [x - 151.0, x + 151.0]:
			_ellipse(c, Vector2(pin_x, y - 28.0), 2.6, 2.6, TOMATO, INK, 0.7, 8)
	else:
		var board: Rect2 = Rect2(x - 143.0, y - 49.0, 286.0, 98.0)
		c.draw_rect(Rect2(board.position + Vector2(5.0, 7.0), board.size), _alpha(INK, 0.11))
		c.draw_rect(board, Color("#CDD7D0"))
		c.draw_rect(Rect2(x - 132.0, y - 39.0, 112.0, 78.0), Color("#E6E4D7"))
		c.draw_line(Vector2(x - 119.0, y - 24.0), Vector2(x - 32.0, y - 24.0), TEAL, 2.0, true)
		c.draw_line(Vector2(x - 119.0, y - 11.0), Vector2(x - 48.0, y - 11.0), _alpha(INK, 0.45), 1.2, true)
		c.draw_line(Vector2(x - 119.0, y + 1.0), Vector2(x - 62.0, y + 1.0), _alpha(INK, 0.45), 1.2, true)
		c.draw_string(OFFICE_FONT, Vector2(x - 10.0, y - 15.0), "安全通道", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, INK)
		c.draw_string(OFFICE_FONT, Vector2(x - 10.0, y + 12.0), "请勿堆放纸箱", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, SHADE)
		c.draw_line(Vector2(x + 119.0, y + 26.0), Vector2(x + 119.0, y - 26.0), TOMATO, 3.0, true)


static func _draw_background_desk(c: CanvasItem, center: Vector2, trim: Color, variant: int = 0, clock: float = 0.0) -> void:
	var x: float = center.x
	var y: float = center.y
	var muted_ink: Color = _alpha(INK, 0.58)
	var wood: Color = Color("#AEB7AC") if variant % 2 == 0 else Color("#A9B7B8")
	if variant % 4 == 0:
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 138.0, y - 138.0), Vector2(x + 135.0, y - 138.0), Vector2(x + 142.0, y - 52.0), Vector2(x - 143.0, y - 52.0)]), _alpha(Color("#B6C5BE"), 0.52), _alpha(INK, 0.32), 1.3)
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 126.0, y - 127.0), Vector2(x - 25.0, y - 127.0), Vector2(x - 25.0, y - 89.0), Vector2(x - 126.0, y - 89.0)]), _alpha(Color("#D7CBAF"), 0.64), _alpha(INK, 0.23), 0.9)
		c.draw_line(Vector2(x - 115.0, y - 116.0), Vector2(x - 38.0, y - 116.0), _alpha(TEAL, 0.6), 1.2, true)
		c.draw_line(Vector2(x - 115.0, y - 106.0), Vector2(x - 57.0, y - 106.0), _alpha(INK, 0.32), 1.0, true)
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 27.0, y - 126.0), Vector2(x + 122.0, y - 126.0), Vector2(x + 121.0, y - 84.0), Vector2(x + 27.0, y - 84.0)]), _alpha(PAPER, 0.42), _alpha(INK, 0.22), 0.8)
		_ellipse(c, Vector2(x + 75.0, y - 106.0), 11.0, 11.0, _alpha(MUSTARD, 0.54), _alpha(INK, 0.34), 0.8, 12)
	_ellipse(c, Vector2(x, y + 54.0), 147.0, 7.0, _alpha(INK, 0.12), Color.TRANSPARENT, 0.0)
	_draw_background_chair(c, Vector2(x + float(posmod(variant, 3) - 1) * 22.0, 545.0), trim)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 145.0, y - 48.0), Vector2(x + 136.0, y - 48.0), Vector2(x + 151.0, y - 29.0), Vector2(x - 151.0, y - 29.0)]), wood, muted_ink, 1.8)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 144.0, y - 48.0), Vector2(x + 136.0, y - 48.0), Vector2(x + 141.0, y - 42.0), Vector2(x - 146.0, y - 42.0)]), _alpha(WHITE, 0.36), Color.TRANSPARENT, 0.0)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 130.0, y - 29.0), Vector2(x - 115.0, y - 29.0), Vector2(x - 117.0, y + 38.0), Vector2(x - 130.0, y + 38.0)]), wood.darkened(0.07), muted_ink, 1.2)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 104.0, y - 29.0), Vector2(x + 119.0, y - 29.0), Vector2(x + 123.0, y + 38.0), Vector2(x + 108.0, y + 38.0)]), wood.darkened(0.07), muted_ink, 1.2)
	var screen_x: float = x - 56.0 if variant % 2 == 0 else x - 18.0
	c.draw_rect(Rect2(screen_x - 44.0, y - 120.0, 88.0, 62.0), _alpha(Color("#607B83"), 0.9), false, 1.7)
	c.draw_rect(Rect2(screen_x - 39.0, y - 115.0, 78.0, 51.0), _alpha(Color("#C4D8D3"), 0.9))
	c.draw_rect(Rect2(screen_x - 34.0, y - 108.0, 28.0, 3.0), _alpha(WHITE, 0.68))
	c.draw_rect(Rect2(screen_x - 34.0, y - 101.0, 57.0, 2.0), _alpha(WHITE, 0.52))
	c.draw_rect(Rect2(screen_x - 34.0, y - 95.0, 43.0, 2.0), _alpha(WHITE, 0.52))
	c.draw_rect(Rect2(screen_x - 33.0, y - 58.0, 66.0, 5.0), muted_ink)
	c.draw_rect(Rect2(screen_x - 4.0, y - 59.0, 8.0, 12.0), muted_ink)
	if variant % 3 == 1:
		var second_x: float = x + 62.0
		c.draw_rect(Rect2(second_x - 29.0, y - 105.0, 58.0, 43.0), muted_ink)
		c.draw_rect(Rect2(second_x - 25.0, y - 101.0, 50.0, 35.0), _alpha(Color("#B9D0CF"), 0.86))
		c.draw_rect(Rect2(second_x - 21.0, y - 95.0, 37.0, 2.0), _alpha(WHITE, 0.65))
		c.draw_rect(Rect2(second_x - 4.0, y - 62.0, 8.0, 9.0), muted_ink)
		c.draw_rect(Rect2(second_x - 21.0, y - 54.0, 42.0, 4.0), muted_ink)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 9.0, y - 43.0), Vector2(x + 55.0, y - 43.0), Vector2(x + 62.0, y - 35.0), Vector2(x - 14.0, y - 35.0)]), Color("#86999B"), muted_ink, 1.0)
	for key in range(9):
		var key_x: float = x - 4.0 + float(key) * 6.0
		c.draw_line(Vector2(key_x, y - 41.0), Vector2(key_x, y - 37.0), _alpha(WHITE, 0.62), 0.7, true)
	_ellipse(c, Vector2(x + 76.0, y - 39.0), 7.0, 4.0, Color("#D4B79A"), muted_ink, 0.9, 12)
	_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x - 100.0, y - 44.0), Vector2(x - 72.0, y - 44.0), Vector2(x - 75.0, y - 31.0), Vector2(x - 98.0, y - 31.0)]), PAPER, muted_ink, 1.0)
	c.draw_line(Vector2(x - 95.0, y - 39.0), Vector2(x - 79.0, y - 39.0), TOMATO, 1.0, true)
	_ellipse(c, Vector2(x - 73.0, y - 37.0), 4.0, 3.0, MUSTARD, muted_ink, 0.8, 10)
	if variant % 2 == 0:
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 95.0, y - 46.0), Vector2(x + 126.0, y - 46.0), Vector2(x + 129.0, y - 30.0), Vector2(x + 98.0, y - 30.0)]), Color("#8EA2A3"), muted_ink, 1.0)
		c.draw_line(Vector2(x + 105.0, y - 42.0), Vector2(x + 122.0, y - 42.0), _alpha(WHITE, 0.55), 1.0, true)
	else:
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 100.0, y - 44.0), Vector2(x + 122.0, y - 44.0), Vector2(x + 126.0, y - 29.0), Vector2(x + 96.0, y - 29.0)]), PAPER, muted_ink, 1.0)
		c.draw_line(Vector2(x + 103.0, y - 39.0), Vector2(x + 120.0, y - 39.0), _alpha(TEAL, 0.72), 1.0, true)
	c.draw_line(Vector2(x + 85.0, y - 28.0), Vector2(x + 95.0, y - 12.0), _alpha(INK, 0.25), 0.9, true)
	if variant % 4 == 2:
		c.draw_arc(Vector2(x - 121.0, y - 57.0), 11.0, PI, TAU, 12, _alpha(MUSTARD, 0.82), 1.3, true)
		c.draw_line(Vector2(x - 132.0, y - 56.0), Vector2(x - 110.0, y - 56.0), muted_ink, 1.0, true)
		_poly(c, Vector2.ZERO, PackedVector2Array([Vector2(x + 94.0, y - 114.0), Vector2(x + 130.0, y - 114.0), Vector2(x + 128.0, y - 67.0), Vector2(x + 92.0, y - 67.0)]), _alpha(Color("#829497"), 0.78), muted_ink, 1.0)
		c.draw_rect(Rect2(x + 98.0, y - 109.0, 28.0, 35.0), _alpha(Color("#BBD0CC"), 0.88))
		c.draw_line(Vector2(x + 101.0, y - 103.0), Vector2(x + 122.0, y - 103.0), _alpha(WHITE, 0.68), 1.0, true)
	if clock > 0.0 and variant % 3 == 2:
		var status_glow: float = 0.56 + sin(clock * 2.0 + float(variant)) * 0.08
		_ellipse(c, Vector2(screen_x + 34.0, y - 112.0), 2.0, 2.0, _alpha(TEAL, status_glow), Color.TRANSPARENT, 0.0, 8)


static func _draw_background_chair(c: CanvasItem, pos: Vector2, trim: Color) -> void:
	var outline: Color = _alpha(INK, 0.46)
	var fill: Color = _alpha(trim, 0.58)
	_ellipse(c, pos + Vector2(0.0, -1.0), 27.0, 3.5, _alpha(INK, 0.10), Color.TRANSPARENT, 0.0, 14)
	_poly(c, pos, PackedVector2Array([Vector2(-21.0, -64.0), Vector2(-17.0, -74.0), Vector2(16.0, -74.0), Vector2(21.0, -65.0), Vector2(18.0, -38.0), Vector2(-18.0, -38.0)]), fill, outline, 1.7)
	_line(c, pos + Vector2(-14.0, -66.0), pos + Vector2(14.0, -66.0), _alpha(WHITE, 0.47), 1.2)
	_poly(c, pos, PackedVector2Array([Vector2(-24.0, -38.0), Vector2(22.0, -38.0), Vector2(27.0, -31.0), Vector2(22.0, -24.0), Vector2(-22.0, -24.0), Vector2(-27.0, -31.0)]), fill, outline, 1.7)
	_line(c, pos + Vector2(0.0, -24.0), pos + Vector2(0.0, -10.0), outline, 2.6)
	_line(c, pos + Vector2(0.0, -11.0), pos + Vector2(-19.0, -3.0), outline, 2.0)
	_line(c, pos + Vector2(0.0, -11.0), pos + Vector2(19.0, -3.0), outline, 2.0)
	for wheel in [-1.0, 1.0]:
		_ellipse(c, pos + Vector2(wheel * 20.0, -1.0), 3.0, 2.7, outline, outline, 0.7, 8)


static func _draw_ceiling_lamp(c: CanvasItem, center: Vector2, trim: Color, clock: float, global_index: int) -> void:
	var brightness: float = 0.87 + sin(clock * 1.15 + float(global_index) * 0.8) * 0.025
	var warm: Color = Color("#F7EBCB").lerp(WHITE, brightness)
	_poly(c, center, PackedVector2Array([Vector2(-76.0, -3.0), Vector2(76.0, -3.0), Vector2(61.0, 17.0), Vector2(-61.0, 17.0)]), _alpha(warm, 0.48), Color.TRANSPARENT, 0.0)
	c.draw_rect(Rect2(center + Vector2(-50.0, -8.0), Vector2(100.0, 13.0)), _alpha(trim.darkened(0.12), 0.94))
	c.draw_rect(Rect2(center + Vector2(-43.0, -7.0), Vector2(86.0, 7.0)), _alpha(warm, 0.96))
	c.draw_line(center + Vector2(-40.0, 5.0), center + Vector2(40.0, 5.0), _alpha(WHITE, 0.95), 1.5, true)


static func _draw_shelf(c: CanvasItem, center: Vector2, trim: Color) -> void:
	var x: float = center.x
	var y: float = center.y
	c.draw_rect(Rect2(x - 41.0, y - 104.0, 82.0, 104.0), _alpha(trim, 0.76), false, 2.0)
	for shelf in range(3):
		var sy: float = y - 75.0 + float(shelf) * 30.0
		c.draw_line(Vector2(x - 38.0, sy), Vector2(x + 38.0, sy), _alpha(INK, 0.58), 2.0)
		for book in range(4):
			var bx: float = x - 30.0 + float(book) * 17.0
			var bh: float = 12.0 + float((book + shelf) % 3) * 4.0
			var book_color: Color = TEAL if (book + shelf) % 2 == 0 else Color("#C68770")
			c.draw_rect(Rect2(bx, sy - bh, 12.0, bh), _alpha(book_color, 0.82))


static func _draw_wall_texture(c: CanvasItem, left: float, right: float) -> void:
	var dot_x: float = floor(left / 71.0) * 71.0 + 18.0
	while dot_x < right:
		var dot_y: float = 346.0 + fposmod(dot_x * 1.73, 151.0)
		_ellipse(c, Vector2(dot_x, dot_y), 1.0, 1.0, _alpha(INK, 0.055), Color.TRANSPARENT, 0.0, 8)
		dot_x += 71.0


static func _poly(c: CanvasItem, origin: Vector2, points: PackedVector2Array, fill: Color, outline: Color = INK, width: float = 2.0, mirror: float = 1.0, rotation: float = 0.0) -> void:
	if points.size() < 3:
		return
	var transformed: PackedVector2Array = PackedVector2Array()
	for point in points:
		transformed.append(_xf(origin, point, mirror, rotation))
	c.draw_colored_polygon(transformed, fill)
	if width > 0.0 and outline.a > 0.0:
		var outline_points: PackedVector2Array = transformed.duplicate()
		outline_points.append(transformed[0])
		c.draw_polyline(outline_points, outline, width, true)


static func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, fill: Color, outline: Color = INK, width: float = 2.0, segments: int = 18, mirror: float = 1.0, rotation: float = 0.0) -> void:
	var safe_segments: int = maxi(segments, 8)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(safe_segments):
		var angle: float = TAU * float(i) / float(safe_segments)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	_poly(c, center, points, fill, outline, width, mirror, rotation)


static func _line(c: CanvasItem, start_point: Vector2, end_point: Vector2, color: Color, width: float = 2.0, mirror: float = 1.0, rotation: float = 0.0, origin: Vector2 = Vector2.ZERO) -> void:
	c.draw_line(_xf(origin, start_point, mirror, rotation), _xf(origin, end_point, mirror, rotation), color, width, true)


static func _xf(origin: Vector2, point: Vector2, mirror: float = 1.0, rotation: float = 0.0) -> Vector2:
	return origin + Vector2(point.x * mirror, point.y).rotated(rotation)


static func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


static func draw_debris(c: CanvasItem, pos: Vector2, size: Vector2, kind: String) -> void:
	var width: float = minf(140,size.x*1.3)
	var color: Color = Color("C79B6E") if kind=="box" else TEAL if kind=="plant" else Color("9DB4BA") if kind in ["cooler","monitor","bin"] else WHITE
	_ellipse(c,pos+Vector2(0,1),width*0.6,3,_alpha(INK,0.12),Color.TRANSPARENT,0)
	for i in range(7):
		var x: float = (float(i)/6.0-0.5)*width
		var y: float = -2.0-float(i%3)
		var shape: PackedVector2Array = PackedVector2Array([Vector2(-9,0),Vector2(7,-3),Vector2(11,1),Vector2(-7,2)])
		_poly(c,pos+Vector2(x,y),shape,color,INK,0.8)
	if kind in ["printer","cooler","monitor"]:
		c.draw_rect(Rect2(pos+Vector2(-size.x*0.35,-7),Vector2(size.x*0.7,6)),SHADE)
		c.draw_rect(Rect2(pos+Vector2(-size.x*0.35,-7),Vector2(size.x*0.7,6)),INK,false,1)
