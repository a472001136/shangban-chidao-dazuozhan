class_name OfficeUI
extends CanvasLayer

signal action_requested(action: String, value: Variant)

const LOGICAL_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PAPER: Color = Color("#F5EBD8")
const INK: Color = Color("#28344A")
const WALL: Color = Color("#AFC5CF")
const TEAL: Color = Color("#55AAA4")
const MUSTARD: Color = Color("#E9BD4A")
const TOMATO: Color = Color("#E76A52")
const SHADE: Color = Color("#8E8795")
const WHITE: Color = Color("#FFF9EE")
const FONT_PATH: String = "res://assets/fonts/SourceHanSansSC-Regular.otf"

class _ScenePainter extends Control:
	var paint_handler: Callable

	func _draw() -> void:
		if paint_handler.is_valid():
			paint_handler.call(self)


var current_screen: String = "title"
var _clock: float = 0.0
var _result_anim_started: float = 0.0
var _context: Dictionary = {}
var _result: Dictionary = {}
var _font: Font
var _viewport_root: Control
var _content: Control
var _painter: _ScenePainter
var _overlay_painter: _ScenePainter
var _elements: Control
var _buttons: Array[Button] = []
var _focus_targets: Array[Control] = []
var _hud_labels: Dictionary = {}
var _setting_value_labels: Dictionary = {}
var _setting_checks: Dictionary = {}


func _ready() -> void:
	layer = 20
	_font = load(FONT_PATH) as Font
	_viewport_root = Control.new()
	_viewport_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_viewport_root)
	_content = Control.new()
	_content.position = Vector2.ZERO
	_content.size = LOGICAL_SIZE
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport_root.add_child(_content)
	_painter = _ScenePainter.new()
	_painter.position = Vector2.ZERO
	_painter.size = LOGICAL_SIZE
	_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painter.paint_handler = Callable(self, "_paint_scene")
	_content.add_child(_painter)
	_elements = Control.new()
	_elements.position = Vector2.ZERO
	_elements.size = LOGICAL_SIZE
	_elements.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_elements)
	_overlay_painter = _ScenePainter.new()
	_overlay_painter.position = Vector2.ZERO
	_overlay_painter.size = LOGICAL_SIZE
	_overlay_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_painter.paint_handler = Callable(self, "_paint_hud_overlay")
	_content.add_child(_overlay_painter)
	_content.move_child(_overlay_painter, 1)
	get_viewport().size_changed.connect(_fit_logical_canvas)
	_fit_logical_canvas()
	show_screen("title", {})


func _process(delta: float) -> void:
	_clock += delta
	if current_screen == "title" or current_screen == "calendar" or current_screen == "briefing" or current_screen == "hud" or current_screen == "success" or current_screen == "failure":
		if is_instance_valid(_painter):
			_painter.queue_redraw()
	if current_screen == "hud" and is_instance_valid(_overlay_painter):
		_overlay_painter.queue_redraw()


func show_screen(screen: String, context: Dictionary) -> void:
	var previous_screen: String = current_screen
	current_screen = screen
	_context = context.duplicate(true)
	if current_screen == "settings" and not _context.has("return_state") and not _context.has("world_visible"):
		_context["return_state"] = previous_screen
	_result = _to_dictionary(_context.get("result", {}))
	if current_screen == "success" or current_screen == "failure":
		_result_anim_started = _clock
	_clear_elements()
	if is_instance_valid(_painter):
		_painter.queue_redraw()
	if is_instance_valid(_overlay_painter):
		_overlay_painter.queue_redraw()
	match current_screen:
		"title":
			_build_title()
		"calendar":
			_build_calendar()
		"album":
			_build_album()
		"briefing":
			_build_briefing()
		"hud":
			_build_hud()
		"pause":
			_build_pause()
		"settings":
			_build_settings()
		"success":
			_build_result(true)
		"failure":
			_build_result(false)
		_:
			_build_title()
	call_deferred("_focus_first")


func update_hud(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_result = _to_dictionary(_context.get("result", {}))
	if current_screen != "hud":
		return
	_refresh_hud()
	if is_instance_valid(_painter):
		_painter.queue_redraw()
	if is_instance_valid(_overlay_painter):
		_overlay_painter.queue_redraw()


func _fit_logical_canvas() -> void:
	if not is_instance_valid(_content):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_factor: float = minf(viewport_size.x / LOGICAL_SIZE.x, viewport_size.y / LOGICAL_SIZE.y)
	_content.scale = Vector2(scale_factor, scale_factor)
	_content.position = (viewport_size - LOGICAL_SIZE * scale_factor) * 0.5
	_content.size = LOGICAL_SIZE
	_painter.size = LOGICAL_SIZE
	_overlay_painter.size = LOGICAL_SIZE
	_elements.size = LOGICAL_SIZE


func _clear_elements() -> void:
	_buttons.clear()
	_focus_targets.clear()
	_hud_labels.clear()
	_setting_value_labels.clear()
	_setting_checks.clear()
	for child in _elements.get_children():
		_elements.remove_child(child)
		child.queue_free()


func _paint_scene(canvas: CanvasItem) -> void:
	var theme: int = _current_theme()
	match current_screen:
		"title":
			OfficeArt.draw_title(canvas, LOGICAL_SIZE, _clock)
		"hud":
			pass
		"pause":
			canvas.draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(INK.r, INK.g, INK.b, 0.43))
		"settings":
			if _settings_has_live_world():
				canvas.draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(INK.r, INK.g, INK.b, 0.43))
			elif str(_context.get("return_state", "title")) == "title":
				OfficeArt.draw_title(canvas, LOGICAL_SIZE, _clock)
			else:
				OfficeArt.draw_office(canvas, 0.0, LOGICAL_SIZE.x, theme, _clock)
		"calendar", "briefing", "success", "failure", "album":
			OfficeArt.draw_office(canvas, 0.0, LOGICAL_SIZE.x, theme, _clock)
			if current_screen == "success" or current_screen == "failure":
				_draw_result_illustration(canvas)
		_:
			OfficeArt.draw_title(canvas, LOGICAL_SIZE, _clock)


func _settings_has_live_world() -> bool:
	if _context.has("world_visible"):
		return bool(_context.get("world_visible", false))
	var return_state: String = str(_context.get("return_state", ""))
	return return_state == "pause" or return_state == "hud" or return_state == "playing"


func _paint_hud_overlay(canvas: CanvasItem) -> void:
	if current_screen != "hud":
		return
	if bool(_context.get("tactical", false)):
		_paint_flow_hud(canvas)
		return
	canvas.draw_rect(Rect2(18.0, 14.0, 405.0, 91.0), Color(PAPER.r, PAPER.g, PAPER.b, 0.78))
	canvas.draw_line(Vector2(25.0, 104.0), Vector2(414.0, 104.0), Color(INK.r, INK.g, INK.b, 0.55), 1.5, true)
	canvas.draw_rect(Rect2(516.0, 18.0, 248.0, 60.0), Color(PAPER.r, PAPER.g, PAPER.b, 0.88))
	canvas.draw_rect(Rect2(516.0, 18.0, 248.0, 60.0), Color(INK.r, INK.g, INK.b, 0.72), false, 1.5, true)
	canvas.draw_rect(Rect2(18.0, 649.0, 500.0, 48.0), Color(PAPER.r, PAPER.g, PAPER.b, 0.76))
	if bool(_context.get("playground",false)):
		canvas.draw_rect(Rect2(985.0,102.0,260.0,36.0),Color(PAPER.r,PAPER.g,PAPER.b,0.90))
	var event_remaining: float = float(_context.get("recent_event_age", 0.0))
	var event_text: String = str(_context.get("recent_event", ""))
	var tip_text: String = str(_context.get("accident_tip", ""))
	var event_active: bool = not event_text.is_empty() and event_remaining > 0.0
	var show_tip: bool = bool(_context.get("started", false)) and int(_context.get("accidents", 0)) == 0 and event_remaining <= 0.0 and not tip_text.is_empty()
	var toast_text: String = event_text if event_active else (tip_text if show_tip else "")
	if not toast_text.is_empty():
		canvas.draw_rect(Rect2(376.0, 103.0, 528.0, 36.0), Color(PAPER.r, PAPER.g, PAPER.b, 0.92))
		canvas.draw_rect(Rect2(376.0, 103.0, 528.0, 36.0), Color(TOMATO.r, TOMATO.g, TOMATO.b, 0.62) if event_active else Color(INK.r, INK.g, INK.b, 0.35), false, 1.5, true)
	var coupons: int = clampi(int(_context.get("coupons", 0)), 0, 3)
	for i in range(3):
		OfficeArt.draw_coupon(canvas, Vector2(1116.0 + float(i) * 38.0, 69.0), i >= coupons, _clock + float(i) * 0.3)
	var held: String = str(_context.get("held", ""))
	if held == "extinguisher" or held == "fire_extinguisher":
		var fuel: float = clampf(float(_context.get("fuel", 1.0)), 0.0, 1.0)
		canvas.draw_rect(Rect2(350.0, 682.0, 150.0, 8.0), INK)
		canvas.draw_rect(Rect2(352.0, 684.0, 146.0 * fuel, 4.0), TEAL if fuel > 0.15 else TOMATO)
		canvas.draw_line(Vector2(350.0, 679.0), Vector2(500.0, 679.0), WHITE, 1.0, true)


func _paint_flow_hud(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(20,18,290,68), Color(PAPER.r,PAPER.g,PAPER.b,0.88))
	canvas.draw_rect(Rect2(540,18,200,64), INK)
	canvas.draw_line(Vector2(548,77),Vector2(732,77),MUSTARD,3.0)
	canvas.draw_rect(Rect2(956,18,304,122), Color(INK.r,INK.g,INK.b,0.94))
	var combo: int = int(_context.get("combo",0))
	var fraction: float = clampf(float(_context.get("combo_remaining",0.0))/4.0,0.0,1.0)
	canvas.draw_rect(Rect2(974,104,268,5),Color("566172"))
	canvas.draw_rect(Rect2(974,104,268*fraction,5),MUSTARD if combo >= 3 else TEAL)
	if float(_context.get("flow_flash",0.0)) > 0.8:
		canvas.draw_rect(Rect2(956,18,304,122),MUSTARD,false,2.0)
	if not str(_context.get("prompt", "")).is_empty():
		canvas.draw_rect(Rect2(382,647,516,45),Color(PAPER.r,PAPER.g,PAPER.b,0.95))
		canvas.draw_line(Vector2(390,687),Vector2(890,687),TEAL,3.0)
	canvas.draw_rect(Rect2(20,655,338,34),Color(PAPER.r,PAPER.g,PAPER.b,0.8))
	var held: String = str(_context.get("held",""))
	if held == "extinguisher":
		canvas.draw_rect(Rect2(23,694,330,4),INK)
		canvas.draw_rect(Rect2(23,694,330*float(_context.get("fuel",1.0)),4),TEAL)
	if float(_context.get("recent_event_age",0.0)) > 0.0:
		canvas.draw_rect(Rect2(400,122,480,28),Color(PAPER.r,PAPER.g,PAPER.b,0.9))


func _draw_result_illustration(canvas: CanvasItem) -> void:
	var success: bool = bool(_result.get("success", current_screen == "success"))
	if success and bool(_result.get("finale", false)):
		_draw_final_receipt(canvas)
		OfficeArt.draw_prop(canvas, "printer", Vector2(990.0, 600.0), Vector2(88.0, 62.0), false, _clock)
		OfficeArt.draw_prop(canvas, "plant", Vector2(1212.0, 600.0), Vector2(48.0, 70.0), false, _clock)
		OfficeArt.draw_player(canvas, Vector2(1123.0, 600.0), -1, "desk", _clock, Vector2.ZERO, "chair", 0, 1.0)
		return
	OfficeArt.draw_prop(canvas, "printer", Vector2(1167.0, 600.0), Vector2(74.0, 57.0), not success, _clock)
	OfficeArt.draw_prop(canvas, "plant", Vector2(905.0, 600.0), Vector2(52.0, 78.0), not success, _clock)
	OfficeArt.draw_prop(canvas, "files", Vector2(1114.0, 600.0), Vector2(54.0, 40.0), not success, _clock)
	OfficeArt.draw_player(canvas, Vector2(1010.0, 600.0), -1, "desk" if success else "stumble", _clock, Vector2.ZERO, "chair" if success else "", 0, 1.0)


func _draw_final_receipt(canvas: CanvasItem) -> void:
	var elapsed: float = maxf(_clock - _result_anim_started, 0.0)
	var progress: float = clampf(elapsed / 1.25, 0.0, 1.0)
	var eased_progress: float = 1.0 - pow(1.0 - progress, 3.0)
	var receipt_x: float = 914.0
	var receipt_y: float = 92.0
	var receipt_width: float = 148.0
	var receipt_height: float = 104.0 + 300.0 * eased_progress
	var receipt_rect: Rect2 = Rect2(receipt_x, receipt_y, receipt_width, receipt_height)
	canvas.draw_rect(receipt_rect, WHITE)
	canvas.draw_rect(receipt_rect, INK, false, 2.0, true)
	if _font != null:
		canvas.draw_string(_font, Vector2(receipt_x + 16.0, receipt_y + 28.0), "五日总账", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, INK)
	canvas.draw_line(Vector2(receipt_x + 12.0, receipt_y + 39.0), Vector2(receipt_x + receipt_width - 12.0, receipt_y + 39.0), TEAL, 2.0, true)
	var visible_rows: int = maxi(0, int(floor((receipt_height - 70.0) / 26.0)))
	for row in range(visible_rows):
		var line_y: float = receipt_y + 60.0 + float(row) * 26.0
		canvas.draw_line(Vector2(receipt_x + 15.0, line_y), Vector2(receipt_x + receipt_width - 15.0, line_y), Color("#AFC5CF"), 1.5, true)
	for notch in range(7):
		var notch_x: float = receipt_x + 10.0 + float(notch) * 21.0
		canvas.draw_circle(Vector2(notch_x, receipt_y + receipt_height), 4.0, Color("#B5B1A7"))
func _build_title() -> void:
	_add_title_shadow("上班迟到\n大作战", 92.0, 88.0, 540.0, 150.0, 58)
	_add_label("人可以狼狈，打卡必须体面", 98.0, 256.0, 535.0, 46.0, 24, INK)
	_add_label("稳稳当当有限公司  ·  每日全勤奖 50 元", 102.0, 302.0, 520.0, 35.0, 18, SHADE)
	_add_button("试玩：办公室临时改道", "level", 1, Rect2(90.0, 425.0, 314.0, 58.0), 23)
	_add_button("选工作日", "calendar", null, Rect2(90.0, 492.0, 314.0, 54.0), 22)
	_add_button("设置", "settings", null, Rect2(90.0, 555.0, 150.0, 50.0), 21)
	_add_button("退出", "quit", null, Rect2(254.0, 555.0, 150.0, 50.0), 21)
	_add_button("名场面图鉴", "album", null, Rect2(90.0,615.0,314.0,43.0),18)


func _build_calendar() -> void:
	_add_panel(Rect2(34.0, 24.0, 1212.0, 676.0), Color(0.96, 0.92, 0.84, 0.88), 3, 20)
	_add_title_shadow("本周考勤表", 64.0, 38.0, 640.0, 56.0, 35)
	_add_label("周一：诱饵引开、机关连锁、上层绕行，门禁临检时临场脱身。", 67.0, 94.0, 900.0, 36.0, 19, SHADE)
	_add_label("累计午饭券  " + str(int(_context.get("total_coupons", 0))) + " / 15", 914.0, 45.0, 292.0, 40.0, 19, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	for level_index in range(1, 6):
		var data: Dictionary = _level_data(level_index)
		var card_rect: Rect2 = Rect2(52.0 + float(level_index - 1) * 236.0, 160.0, 220.0, 360.0)
		var unlocked: bool = _level_unlocked(level_index, data)
		var card_fill: Color = PAPER if unlocked else Color("#D6D8D2")
		_add_panel(card_rect, card_fill, 3, 14)
		var day_name: String = str(data.get("day", "周" + _weekday_name(level_index)))
		var level_name: String = str(data.get("name", _fallback_level_name(level_index)))
		var button_label: String = day_name + "\n" + level_name
		_add_button(button_label, "level", level_index, Rect2(card_rect.position.x + 12.0, 174.0, 196.0, 78.0), 19, not unlocked)
		var limit: float = float(data.get("limit", 90.0))
		_add_label("倒计时  " + str(int(limit)) + " 秒", card_rect.position.x + 16.0, 263.0, 188.0, 30.0, 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
		var challenge: String = "触发8件不同物件事故" if level_index == 5 else str(data.get("challenge", "准时到达自己的工位"))
		_add_label("今日挑战", card_rect.position.x + 15.0, 302.0, 190.0, 26.0, 16, SHADE)
		var challenge_label: Label = _add_label(challenge, card_rect.position.x + 15.0, 328.0, 190.0, 62.0, 16, INK)
		challenge_label.clip_text = true
		_add_label(_medal_text(data, unlocked), card_rect.position.x + 15.0, 414.0, 190.0, 32.0, 17, MUSTARD if unlocked else SHADE, HORIZONTAL_ALIGNMENT_CENTER)
		var best: float = float(data.get("best_time", data.get("fastest", 0.0)))
		var best_text: String = "最快  " + _format_time(best) if best > 0.0 else "尚无到岗记录"
		_add_label(best_text, card_rect.position.x + 15.0, 458.0, 190.0, 30.0, 15, SHADE, HORIZONTAL_ALIGNMENT_CENTER)
		if unlocked:
			_add_label("混乱纪录 " + str(int(data.get("chaos_best",0))) + " · 发现 " + str(int(data.get("discoveries",0))),card_rect.position.x+15.0,486.0,190.0,24.0,13,TEAL,HORIZONTAL_ALIGNMENT_CENTER)
		if not unlocked:
			_add_label("尚未开放", card_rect.position.x + 15.0, 486.0, 190.0, 24.0, 15, SHADE, HORIZONTAL_ALIGNMENT_CENTER)
	_add_button("宽松练习", "level", 0, Rect2(54.0, 568.0, 188.0, 54.0), 20)
	_add_button("返回标题", "back", null, Rect2(255.0, 568.0, 188.0, 54.0), 20)
	_add_button("名场面图鉴", "album", null, Rect2(54.0,636.0,389.0,42.0),18)
	_add_label("胸牌", 486.0, 556.0, 110.0, 32.0, 18, INK)
	var badge_names: Array[String] = ["基础胸牌", "煎饼胸牌", "带薪吃饭", "食堂贵宾"]
	var total_coupons: int = int(_context.get("total_coupons", 0))
	var active_badge: int = int(_context.get("badge", 0))
	for badge_index in range(4):
		var available: bool = badge_index == 0 or (badge_index == 1 and total_coupons >= 3) or (badge_index == 2 and total_coupons >= 8) or (badge_index == 3 and total_coupons >= 15)
		var badge_text: String = badge_names[badge_index]
		if active_badge == badge_index:
			badge_text = "已佩戴\n" + badge_text
		_add_button(badge_text, "badge", badge_index, Rect2(588.0 + float(badge_index) * 155.0, 568.0, 143.0, 54.0), 15, not available)


func _build_album() -> void:
	_add_panel(Rect2(34,24,1212,676),PAPER,3,16)
	_add_title_shadow("五十元全勤奖的离谱拿法",64,42,970,54,32)
	var found: Dictionary = _to_dictionary(_context.get("discoveries",{}))
	var entries: Array = [
		["water_slide","饮用水改交通用水","高速撞翻饮水机，水会逐渐铺开。"],
		["water_surf","水滑道临时营业","椅子滑入漏水区，留意刹车距离。"],
		["paper_cloud","打印机吐的全是废话","撞开打印机，散纸会遮住人事视线。"],
		["upper_route","员工专用逃生通道","跳上有支架的通道，绕开地面查岗。"],
		["busy_escape","日报就一行，人事看两遍","装忙被核查时离开，躲出人事视野。"],
		["powder_cover","临时消防演习","拿灭火器按 F 喷粉，遮住人事视线。"],
		["table_block","会议挡住了人事","推动会议桌，让追赶的人事被挡住。"],
		["moving_meeting","会议地点随时调整","用 A/D 将会议桌推动一段距离。"],
		["hr_escape","工牌下次再看","摆脱追赶的人事，先赶到工位打卡。"],
		["face_clock","脸部识别通过","在地面冲刺到终点，按 E 打卡。"],
		["chair_clock","椅子站着加班","用椅子滑行抵达工位打卡。"],
		["long_flight","人先到，鞋随后","蹬地起跳，保留惯性跨过 250 距离。"],
		["noise_lure","人事查动静，员工走另一边","F 启动复印机，或踢出椅子制造动静。"],
		["chain_reaction","水桶替员工开路","撞翻水机，让滚桶撞散后面的文件。"],
		["gate_dash","四秒通勤窗口","门禁临检后，在按钮旁按 F 放行。"]
	]

	var count: int = 0
	for entry in entries:
		if found.has(str(entry[0])):
			count+=1
	_add_label("已发现 " + str(count) + " / " + str(entries.size()) + " · 失败也保留发现 · 按提示试出下一种",67,102,1100,32,18,SHADE)
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var discovered: bool = found.has(str(entry[0]))
		var x: float = 58.0+float(index%3)*396.0
		var y: float = 150.0+float(index/3)*88.0
		_add_panel(Rect2(x,y,374,80),Color("d6e2e1") if discovered else Color("ece4d6"),1,7)
		_add_label(("✓ " if discovered else "○ ")+str(entry[1]),x+16,y+8,340,30,18,INK if discovered else SHADE)
		_add_label(str(entry[2]),x+16,y+43,340,28,14,TEAL if discovered else SHADE)
	_add_button("再闯一次办公室", "level",1,Rect2(354,616,256,54),21)
	_add_button("返回周历", "calendar",null,Rect2(636,616,256,54),19)


func _build_briefing() -> void:
	_add_panel(Rect2(128.0, 72.0, 1024.0, 576.0), PAPER, 4, 20)
	_add_title_shadow("早上好，今天请准时到岗", 182.0, 102.0, 916.0, 52.0, 31)
	var day_text: String = str(_context.get("day", "今天"))
	var name_text: String = str(_context.get("name", "入职第一跑"))
	_add_label(day_text + "  ·  " + name_text, 190.0, 164.0, 900.0, 56.0, 29, TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	_add_panel(Rect2(196.0, 244.0, 888.0, 106.0), Color("#E5DED0"), 2, 12)
	_add_label(str(_context.get("notice", "请走指定通道，准时到达自己的工位。")), 223.0, 259.0, 834.0, 76.0, 23, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("今日挑战", 218.0, 384.0, 130.0, 32.0, 19, SHADE)
	_add_label(str(_context.get("challenge", "准时到达自己的工位")), 351.0, 376.0, 707.0, 48.0, 21, INK)
	var playground: bool = bool(_context.get("playground",false))
	var tactical: bool = bool(_context.get("tactical",false))
	_add_label("F 复印引开 / 踢出椅子 · Q 装忙 · F 喷粉 · A/D 推桌" if tactical else "E 坐椅子 · S 刹车 · 绿线处按住 Q 装忙 · A/D 推桌" if playground else "Shift 冲刺高速撞上办公物件可能造成损失；普通跑过不一定损坏。", 220.0, 434.0, 840.0, 31.0, 18, SHADE, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("上层可零损绕行；撞水机能制造连锁。末段门禁关闭前有预警。" if tactical else "人事先发现再追赶，伸手登记需要时间。装忙几秒后会被识破。" if playground else "跳跃或减速可以避开。第一次行动时，倒计时开始。", 220.0, 466.0, 840.0, 28.0, 17, TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	_add_button("开始上班", "start", null, Rect2(354.0, 526.0, 256.0, 62.0), 25)
	_add_button("返回选关", "back", null, Rect2(636.0, 526.0, 256.0, 62.0), 21)


func _build_hud() -> void:
	if bool(_context.get("tactical", false)):
		_build_flow_hud()
		return
	_hud_labels["day"] = _add_label("", 30.0, 22.0, 365.0, 26.0, 16, SHADE)
	_hud_labels["name"] = _add_label("", 30.0, 48.0, 365.0, 32.0, 21, INK)
	_hud_labels["accident_total"] = _add_label("", 30.0, 79.0, 365.0, 25.0, 17, TOMATO)
	_hud_labels["clock"] = _add_label("", 526.0, 23.0, 228.0, 49.0, 34, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["coupon_label"] = _add_label("", 1012.0, 16.0, 220.0, 27.0, 16, SHADE, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["start_hint"] = _add_label("", 427.0, 79.0, 426.0, 22.0, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["recent_event"] = _add_label("", 388.0, 104.0, 504.0, 34.0, 17, TOMATO, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["accident_tip"] = _add_label("", 388.0, 104.0, 504.0, 34.0, 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["tool"] = _add_label("", 30.0, 655.0, 465.0, 34.0, 15, INK)
	_hud_labels["prompt"] = _add_label("", 540.0, 654.0, 230.0, 34.0, 18, TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["bubble"] = _add_label("", 782.0, 654.0, 470.0, 34.0, 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["chaos"] = _add_label("", 995.0,104.0,245.0,30.0,18,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_refresh_hud()


func _build_flow_hud() -> void:
	_hud_labels["name"] = _add_label("",34,24,265,26,19,INK)
	_hud_labels["detail"] = _add_label("",34,54,265,23,14,SHADE)
	_hud_labels["clock"] = _add_label("",548,22,184,51,32,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["status"] = _add_label("",392,85,496,24,15,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["score"] = _add_label("",974,23,266,43,30,WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_labels["combo"] = _add_label("",974,68,266,29,20,MUSTARD)
	_hud_labels["flow"] = _add_label("",974,113,270,23,14,WHITE)
	_hud_labels["tool"] = _add_label("",30,658,325,27,14,INK)
	_hud_labels["prompt"] = _add_label("",390,651,500,32,17,TEAL,HORIZONTAL_ALIGNMENT_CENTER)
	_hud_labels["event"] = _add_label("",405,124,470,24,14,TOMATO,HORIZONTAL_ALIGNMENT_CENTER)
	_refresh_flow_hud()


func _refresh_flow_hud() -> void:
	_set_label("name",str(_context.get("day","周一"))+" · "+str(_context.get("name","")))
	_set_label("detail","午饭券 %d/3   账单 ¥%d" % [int(_context.get("coupons",0)),int(_context.get("damage",0))])
	var remaining: float = float(_context.get("remaining",55.0))
	_set_label("clock",_format_time(remaining))
	var clock_label: Label = _hud_labels.get("clock") as Label
	clock_label.add_theme_color_override("font_color",TOMATO if remaining <= 5.0 else MUSTARD if remaining <= 15.0 else WHITE)
	var started: bool = bool(_context.get("started",false))
	var status: String = str(_context.get("hr_status",""))
	var gate: String = str(_context.get("gate_status",""))
	_set_label("status",(status+" · "+gate if not gate.is_empty() else status) if started else "行动开始计时 · R 快速重来")
	_set_label("score","%s  %04d" % [str(_context.get("rank","C")),int(_context.get("chaos",0))])
	var combo: int = int(_context.get("combo",0))
	_set_label("combo","%d 连击    ×%d" % [combo,int(_context.get("multiplier",1))] if combo > 0 else "接动作，冲高评级")
	_set_label("flow",str(_context.get("flow_label","")).left(18) if float(_context.get("flow_flash",0.0)) > 0.0 else "四秒内续上 · 换动作加分")
	var held: String = str(_context.get("held",""))
	_set_label("tool","办公椅 · A/D 蹬地 · S 刹车" if held == "chair" else "灭火器 · F 喷粉遮挡" if held == "extinguisher" else "A/D 移动 · 空格跳跃 · Shift 冲刺")
	_set_label("prompt",str(_context.get("prompt","")))
	_set_label("event",str(_context.get("recent_event","")) if float(_context.get("recent_event_age",0.0)) > 0.0 else "")


func _build_pause() -> void:
	_add_panel(Rect2(382.0, 91.0, 516.0, 548.0), PAPER, 4, 22)
	_add_title_shadow("暂停一下", 442.0, 124.0, 398.0, 55.0, 34)
	_add_label("工位还在那里，慢慢来。", 443.0, 181.0, 394.0, 40.0, 19, SHADE, HORIZONTAL_ALIGNMENT_CENTER)
	_add_button("继续上班", "resume", null, Rect2(466.0, 250.0, 348.0, 58.0), 23)
	_add_button("重新开始本关", "restart", null, Rect2(466.0, 320.0, 348.0, 54.0), 20)
	_add_button("设置", "settings", null, Rect2(466.0, 386.0, 348.0, 54.0), 20)
	_add_button("返回选关", "calendar", null, Rect2(466.0, 452.0, 348.0, 54.0), 20)


func _build_settings() -> void:
	_add_panel(Rect2(305.0, 51.0, 670.0, 620.0), PAPER, 4, 22)
	_add_title_shadow("办公室设置", 361.0, 78.0, 558.0, 54.0, 33)
	_add_label("音乐音量", 368.0, 166.0, 180.0, 34.0, 20, INK)
	_add_slider("music_volume", 560.0, 165.0, 290.0)
	_add_label("音效音量", 368.0, 224.0, 180.0, 34.0, 20, INK)
	_add_slider("sound_volume", 560.0, 223.0, 290.0)
	_add_label("全屏显示", 368.0, 295.0, 210.0, 34.0, 20, INK)
	_add_check("fullscreen", 782.0, 289.0)
	_add_label("宽松模式", 368.0, 354.0, 210.0, 34.0, 20, INK)
	_add_check("assist", 782.0, 348.0)
	_add_label("屏幕震动", 368.0, 413.0, 210.0, 34.0, 20, INK)
	_add_check("screen_shake", 782.0, 407.0)
	_add_label("宽松模式增加时间，降低追赶速度，延长抓人反应时间。", 368.0, 474.0, 520.0, 36.0, 17, SHADE)
	_add_label("宽松模式在下次进入关卡时生效。", 368.0, 509.0, 520.0, 30.0, 16, SHADE)
	_add_button("返回", "back", null, Rect2(486.0, 574.0, 308.0, 58.0), 22)


func _build_result(success: bool) -> void:
	if bool(_result.get("tactical", false)):
		_build_flow_result(success)
		return
	_add_panel(Rect2(55.0, 53.0, 827.0, 615.0), PAPER, 4, 13)
	_add_panel(Rect2(77.0, 76.0, 783.0, 69.0), Color("#E8DDC9"), 2, 8)
	var heading: String = "稳稳当当有限公司  ·  到岗记录" if success else "稳稳当当有限公司  ·  今日考勤"
	_add_title_shadow(heading, 96.0, 87.0, 747.0, 48.0, 25)
	var day_text: String = str(_result.get("day", _context.get("day", "今天")))
	var name_text: String = str(_result.get("name", _context.get("name", "入职第一跑")))
	_add_label(day_text + "  ·  " + name_text, 96.0, 158.0, 730.0, 42.0, 23, TEAL)
	var elapsed: float = float(_result.get("elapsed", 0.0))
	var remaining: float = float(_result.get("remaining", 0.0))
	var damage: int = int(_result.get("damage", 0))
	var accidents: int = int(_result.get("accidents", 0))
	var stumbles: int = int(_result.get("stumbles", 0))
	var distance: float = float(_result.get("distance", 0.0))
	_add_label("到岗状态", 101.0, 219.0, 148.0, 28.0, 17, SHADE)
	_add_label("准时打卡" if success else "被人事抓到" if str(_result.get("failure_reason","")).begins_with("被人事") else "跌出通道" if str(_result.get("failure_reason","")).begins_with("跌出") else "超时未打卡", 101.0, 248.0, 265.0, 40.0, 26, INK if success else TOMATO)
	if not success:
		_add_label(str(_result.get("failure_reason","人事已经记住你了")), 101.0, 278.0, 330.0, 24.0, 15, SHADE)
	_add_label("用时", 101.0, 307.0, 120.0, 25.0, 16, SHADE)
	_add_label(_format_time(elapsed), 101.0, 333.0, 205.0, 38.0, 23, INK)
	_add_label("剩余" if success else "距工位", 311.0, 307.0, 120.0, 25.0, 16, SHADE)
	var secondary_value: String = _format_time(remaining) if success else str(int(distance)) + " 像素"
	_add_label(secondary_value, 311.0, 333.0, 205.0, 38.0, 20 if not success else 23, INK)
	_add_label("全勤奖", 101.0, 386.0, 120.0, 25.0, 16, SHADE)
	_add_label("+50 元" if success else "未获得", 101.0, 412.0, 205.0, 34.0, 21, MUSTARD if success else SHADE)
	_add_label("财产损失", 311.0, 386.0, 150.0, 25.0, 16, SHADE)
	_add_label(str(damage) + " 元", 311.0, 412.0, 205.0, 34.0, 21, TOMATO if damage > 0 else TEAL)
	_add_panel(Rect2(538.0, 213.0, 294.0, 247.0), Color("#E9E1D3"), 2, 10)
	_add_label("事故清单", 556.0, 225.0, 255.0, 30.0, 19, INK)
	_add_label("事故物件  " + str(accidents) + " 件", 556.0, 260.0, 255.0, 27.0, 16, SHADE)
	var playground: bool = bool(_result.get("playground",false))
	_add_label("混乱 " + str(int(_result.get("chaos",0))) + " · 最长 " + str(int(_result.get("best_combo",0))) + " 连锁" if playground else "摔倒次数  " + str(stumbles), 556.0, 289.0, 255.0, 27.0, 16, TEAL if playground else SHADE)
	_add_bill_lines(556.0, 326.0, _result.get("bill", []))
	var finale: bool = success and bool(_result.get("finale", false))
	var title_text: String = "下周一，记得早点出门。" if finale else str(_result.get("title", "今日正常到岗" if success else "明日再战"))
	_add_label("本局名场面" if playground else "下周一寄语" if finale else "今日称号", 101.0, 467.0, 150.0, 25.0, 16, SHADE)
	_add_label(str(_result.get("moment",title_text)) if playground else title_text, 101.0, 492.0, 710.0, 42.0, 23 if playground else 26, INK)
	if playground:
		_add_label(str(_result.get("replay_tip","")),101.0,542.0,730.0,26.0,17,TEAL)
		var route_text: String = "路线：" + str(_result.get("route","")) + " · " + ("组合挑战完成" if bool(_result.get("challenge_done",false)) else "组合办法 %d / 2" % int(_result.get("strategy_count",0))) if bool(_result.get("tactical",false)) else str(_result.get("unlock_note",""))
		_add_label(route_text,101.0,574.0,730.0,22.0,14,SHADE)
	else:
		_add_medal_row(101.0, 547.0, success)
		_add_label("午饭券  " + str(int(_result.get("coupons", 0))) + " / 3", 545.0, 550.0, 255.0, 30.0, 17, TEAL)
	if success:
		if finale:
			_add_button("本关再来", "restart", null, Rect2(195.0, 603.0, 230.0, 49.0), 19)
			_add_button("返回周历", "calendar", null, Rect2(463.0, 603.0, 230.0, 49.0), 19)
		else:
			_add_button("本关再来", "restart", null, Rect2(99.0, 603.0, 202.0, 49.0), 19)
			_add_button("下一天", "next", null, Rect2(318.0, 603.0, 202.0, 49.0), 19)
			_add_button("返回选关", "calendar", null, Rect2(537.0, 603.0, 202.0, 49.0), 19)
	else:
		_add_button("再来一次", "restart", null, Rect2(195.0, 603.0, 230.0, 49.0), 21)
		_add_button("返回选关", "calendar", null, Rect2(463.0, 603.0, 230.0, 49.0), 20)
	if playground:
		_add_button("名场面图鉴", "album",null,Rect2(937,619,270,45),18)


func _build_flow_result(success: bool) -> void:
	_add_panel(Rect2(54,45,1172,625), PAPER, 4, 14)
	_add_label("准时到岗 · 今日名场面" if success else "通勤中断 · 再接一段",86,69,940,45,30,INK)
	_add_label(str(_result.get("day","周一"))+" · "+str(_result.get("name",""))+(" · "+str(_result.get("failure_reason","")) if not success else ""),88,119,860,29,18,SHADE)
	_add_panel(Rect2(88,169,744,341),Color("d6e2e1"),2,8)
	var moment_texture: Texture2D = _result.get("moment_texture") as Texture2D
	if moment_texture != null:
		var shot := TextureRect.new()
		shot.position = Vector2(93,174)
		shot.size = Vector2(734,331)
		shot.texture = moment_texture
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shot.clip_contents = true
		shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_elements.add_child(shot)
	else:
		_add_label("下一次，连成一段漂亮的逃脱。",110,275,696,80,26,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(str(_result.get("moment","")),104,518,716,35,21,INK)
	_add_label(str(_result.get("flow_trace","")),104,557,716,28,14,SHADE)
	_add_panel(Rect2(1018,64,165,92),MUSTARD if success else TOMATO,3,5)
	_add_label(str(_result.get("rank","C")),1024,66,153,68,52 if success else 32,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("宽松模式" if bool(_result.get("assist",false)) else "精彩评级",1040,129,121,23,13,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("精彩分数",873,184,286,25,17,SHADE)
	_add_label(str(int(_result.get("chaos",0))),871,215,310,55,38,INK)
	_add_label("最长 %d 连击" % int(_result.get("best_combo",0)),875,277,290,30,20,TEAL)
	var elapsed: float = float(_result.get("elapsed",0.0))
	_add_label("用时  "+_format_time(elapsed),875,326,290,31,21,INK)
	var best: float = float(_result.get("previous_best",0.0))
	var comparison: String = "首次到岗纪录" if best <= 0.0 else "刷新纪录 %.2f 秒" % (best-elapsed) if success and elapsed < best else "距个人纪录 %.2f 秒" % maxf(0.0,elapsed-best)
	_add_label(comparison if success else "R 即刻重来，再接一段",875,360,290,26,15,SHADE)
	_add_label("账单 ¥%d · 午饭券 %d/3" % [int(_result.get("damage",0)),int(_result.get("coupons",0))],875,406,298,28,16,SHADE)
	var target := _add_label(str(_result.get("flow_target","")),874,447,290,95,17,TEAL)
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_button("再跑一局", "restart", null, Rect2(88,604,220,44),20)
	_add_button("下一天" if success else "返回选关", "next" if success else "calendar", null, Rect2(325,604,220,44),19)
	_add_button("名场面图鉴", "album", null, Rect2(562,604,220,44),19)
	if success:
		_add_button("返回选关", "calendar", null, Rect2(869,604,310,44),18)


func _refresh_hud() -> void:
	if _hud_labels.is_empty():
		return
	if bool(_context.get("tactical", false)):
		_refresh_flow_hud()
		return
	var day_text: String = str(_context.get("day", "今天"))
	var name_text: String = str(_context.get("name", "准时到岗"))
	var remaining: float = float(_context.get("remaining", _context.get("limit", 0.0)))
	var started: bool = bool(_context.get("started", true))
	var coupons: int = clampi(int(_context.get("coupons", 0)), 0, 3)
	var accidents: int = maxi(0, int(_context.get("accidents", 0)))
	var damage: int = maxi(0, int(_context.get("damage", 0)))
	var recent_event: String = str(_context.get("recent_event", ""))
	var recent_event_age: float = float(_context.get("recent_event_age", 0.0))
	var held: String = str(_context.get("held", ""))
	_set_label("day", day_text)
	_set_label("name", name_text)
	_set_label("accident_total", "事故 " + str(accidents) + " 件   损失 ¥" + str(damage))
	_set_label("clock", _format_time(remaining))
	_set_label("coupon_label", "午饭券  " + str(coupons) + " / 3")
	_set_label("start_hint", "第一次行动时开始计时" if not started else "Esc  暂停")
	_set_label("tool", _tool_text(held, float(_context.get("fuel", 1.0))))
	if bool(_context.get("playground",false)):
		_set_label("chaos","混乱 " + str(int(_context.get("chaos",0))) + "  ·  " + str(int(_context.get("combo",0))) + " 连锁")
		if held == "chair":
			_set_label("tool","办公椅 · A/D 蹬地 · S 刹车 · F 踢出 · 空格离椅")
		if bool(_context.get("tactical",false)):
			_set_label("chaos","组合 %d / 2 · 混乱 %d" % [int(_context.get("strategy_count",0)),int(_context.get("chaos",0))])

	else:
		_set_label("chaos","")
	_set_label("start_hint", str(_context.get("hr_status","")) if started else "第一次行动时开始计时")
	var gate_text: String = str(_context.get("gate_status",""))
	if started and not gate_text.is_empty():
		_set_label("start_hint",str(_context.get("hr_status",""))+" · "+gate_text)
	var hr_label: Label = _hud_labels.get("start_hint") as Label
	if is_instance_valid(hr_label):
		var status: String = str(_context.get("hr_status",""))
		hr_label.add_theme_color_override("font_color",TOMATO if "追赶" in status or "抓你" in status else INK)
	_set_label("prompt", str(_context.get("prompt", "")))
	_set_label("bubble", str(_context.get("bubble", "")))
	_set_label("recent_event", recent_event if recent_event_age > 0.0 else "")
	var accident_tip: String = str(_context.get("accident_tip", ""))
	_set_label("accident_tip", accident_tip if started and accidents == 0 and recent_event_age <= 0.0 else "")
	var accident_label: Label = _hud_labels.get("accident_total") as Label
	if is_instance_valid(accident_label):
		accident_label.add_theme_color_override("font_color", TOMATO if damage > 0 else TEAL)
	var clock_label: Label = _hud_labels.get("clock") as Label
	if is_instance_valid(clock_label):
		clock_label.add_theme_color_override("font_color", TOMATO if remaining <= 5.0 else (MUSTARD if remaining <= 15.0 else INK))


func _add_button(text_value: String, action: String, value: Variant, rect: Rect2, font_size: int = 20, disabled: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.disabled = disabled
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#777D80"))
	button.add_theme_stylebox_override("normal", _button_style(PAPER if not disabled else Color("#D2D6D1"), INK, 2, 10))
	button.add_theme_stylebox_override("hover", _button_style(Color("#F8F0DD"), TEAL, 3, 10))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#E7D5B5"), INK, 3, 10))
	button.add_theme_stylebox_override("focus", _button_style(MUSTARD, INK, 4, 11))
	button.pressed.connect(_emit_action.bind(action, value))
	_elements.add_child(button)
	_buttons.append(button)
	_focus_targets.append(button)
	return button


func _add_label(text_value: String, x: float, y: float, width: float, height: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = Vector2(x, y)
	label.size = Vector2(width, height)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_elements.add_child(label)
	return label


func _add_title_shadow(text_value: String, x: float, y: float, width: float, height: float, font_size: int) -> void:
	_add_label(text_value, x + 3.0, y + 4.0, width, height, font_size, Color("#8E8795"))
	_add_label(text_value, x, y, width, height, font_size, INK)


func _add_panel(rect: Rect2, fill: Color, border_width: int = 3, radius: int = 12) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(fill, border_width, radius))
	_elements.add_child(panel)
	return panel


func _panel_style(fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(INK.r, INK.g, INK.b, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2.0, 3.0)
	return style


func _button_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(INK.r, INK.g, INK.b, 0.12)
	style.shadow_size = 2
	style.shadow_offset = Vector2(1.0, 2.0)
	return style


func _add_slider(key: String, x: float, y: float, width: float) -> void:
	var slider: HSlider = HSlider.new()
	slider.position = Vector2(x, y)
	slider.size = Vector2(width, 36.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _setting_float(key, 0.75)
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_elements.add_child(slider)
	_focus_targets.append(slider)
	var value_label: Label = _add_label(str(int(slider.value * 100.0)) + "%", x + width + 12.0, y, 62.0, 36.0, 17, TEAL)
	_setting_value_labels[key] = value_label
	slider.value_changed.connect(_on_slider_changed.bind(key))


func _add_check(key: String, x: float, y: float) -> void:
	var check: CheckButton = CheckButton.new()
	check.position = Vector2(x, y)
	check.size = Vector2(124.0, 42.0)
	check.button_pressed = _setting_bool(key, true)
	check.text = "开启" if check.button_pressed else "关闭"
	check.focus_mode = Control.FOCUS_ALL
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	if _font != null:
		check.add_theme_font_override("font", _font)
	check.add_theme_font_size_override("font_size", 17)
	check.add_theme_color_override("font_color", INK)
	check.add_theme_color_override("font_hover_color", INK)
	check.add_theme_color_override("font_pressed_color", INK)
	check.add_theme_color_override("font_hover_pressed_color", INK)
	check.add_theme_color_override("font_focus_color", INK)
	check.toggled.connect(_on_check_changed.bind(key))
	_elements.add_child(check)
	_focus_targets.append(check)
	_setting_checks[key] = check


func _add_bill_lines(x: float, y: float, raw_bill: Variant) -> void:
	var lines: Array = []
	if raw_bill is Array:
		lines = raw_bill
	if lines.is_empty():
		_add_label("没有事故登记", x, y, 250.0, 31.0, 16, TEAL)
		return
	var row: int = 0
	var other_cost: int = 0
	var other_count: int = 0
	for raw_item in lines:
		var item: Dictionary = _to_dictionary(raw_item)
		var kind: String = str(item.get("kind", "物件"))
		var count: int = int(item.get("count", 0))
		var cost: int = int(item.get("cost", 0))
		if row>=4 and lines.size()>5:
			other_cost+=cost
			other_count+=count
			continue
		_add_label(_kind_name(kind) + "  ×" + str(count), x, y + float(row) * 24.0, 166.0, 24.0, 15, INK)
		_add_label(str(cost) + " 元", x + 169.0, y + float(row) * 24.0, 85.0, 24.0, 15, TOMATO, HORIZONTAL_ALIGNMENT_RIGHT)
		row += 1
	if other_count>0:
		_add_label("其余物件  ×"+str(other_count),x,y+float(row)*24.0,166,24,15,INK)
		_add_label(str(other_cost)+" 元",x+169,y+float(row)*24.0,85,24,15,TOMATO,HORIZONTAL_ALIGNMENT_RIGHT)


func _add_medal_row(x: float, y: float, success: bool) -> void:
	var medals: Array = []
	var raw_medals: Variant = _result.get("medals", [])
	if raw_medals is Array:
		medals = raw_medals
	var names: Array[String] = ["准时章", "效率章", "挑战章"]
	for i in range(3):
		var earned: bool = success and (i == 0 or (i < medals.size() and bool(medals[i])))
		var chip_x: float = x + float(i) * 139.0
		var label_color: Color = INK if earned else SHADE
		_add_panel(Rect2(chip_x, y, 126.0, 36.0), Color("#F1E5CC") if earned else Color("#D8D7D0"), 0, 17)
		_add_label("●" if earned else "○", chip_x + 8.0, y, 23.0, 36.0, 15, MUSTARD if earned else SHADE, HORIZONTAL_ALIGNMENT_CENTER)
		_add_label(names[i], chip_x + 30.0, y, 89.0, 36.0, 15, label_color, HORIZONTAL_ALIGNMENT_CENTER)


func _refresh_hud_label(key: String, value: String) -> void:
	if not _hud_labels.has(key):
		return
	var label: Label = _hud_labels[key] as Label
	if is_instance_valid(label):
		label.text = value


func _set_label(key: String, value: String) -> void:
	_refresh_hud_label(key, value)


func _level_data(level_index: int) -> Dictionary:
	var raw_levels: Variant = _context.get("levels", [])
	if not raw_levels is Array:
		return {}
	var levels: Array = raw_levels
	for array_index in range(levels.size()):
		var data: Dictionary = _to_dictionary(levels[array_index])
		var index_value: Variant = data.get("index", data.get("level_index", -999))
		if int(index_value) == level_index:
			return data
		if int(index_value) == -999:
			var fallback_index: int = array_index
			if levels.size() == 5:
				fallback_index += 1
			if fallback_index == level_index:
				return data
	return {}


func _level_unlocked(level_index: int, data: Dictionary) -> bool:
	if data.has("unlocked"):
		return bool(data.get("unlocked", false))
	var global_value: Variant = _context.get("unlocked", 1)
	var max_unlocked: int = 1
	if global_value is int or global_value is float:
		max_unlocked = int(global_value)
	return level_index <= max_unlocked


func _medal_text(data: Dictionary, unlocked: bool) -> String:
	if not unlocked:
		return "奖章  ·  ·  ·"
	var raw: Variant = data.get("medals", data.get("record_medals", []))
	var medals: Array = []
	if raw is Array:
		medals = raw
	var count: int = 0
	for value in medals:
		if bool(value):
			count += 1
	return "奖章  " + str(count) + " / 3"


func _weekday_name(index: int) -> String:
	var names: Array[String] = ["", "一", "二", "三", "四", "五"]
	return names[index] if index >= 0 and index < names.size() else "一"


func _fallback_level_name(index: int) -> String:
	var names: Array[String] = ["入职第一跑", "全勤从今天开始", "公司今天搬家", "空调坏了怎么办", "领导正在视察", "五十块不能丢"]
	return names[index] if index >= 0 and index < names.size() else "准时到岗"


func _current_theme() -> int:
	var level_value: Variant = _context.get("current_level", 0)
	if level_value is int or level_value is float:
		return int(level_value)
	return 0


func _tool_text(held: String, fuel: float) -> String:
	if held == "chair":
		return "办公椅  ·  E 下车  ·  S 刹车"
	if held == "bucket" or held == "mop_bucket":
		return "拖把桶  ·  E 下车  ·  S 刹车"
	if held == "extinguisher" or held == "fire_extinguisher":
		return "灭火器 " + str(int(clampf(fuel, 0.0, 1.0) * 100.0)) + "%  ·  按住 F 喷粉"
	return "A/D 移动 · 空格跳跃 · Shift 地面冲刺 · Q 装忙"


func _kind_name(kind: String) -> String:
	match kind:
		"box":
			return "纸箱"
		"files":
			return "文件堆"
		"bin":
			return "垃圾桶"
		"plant":
			return "盆栽"
		"glass":
			return "玻璃门"
		"cooler":
			return "饮水机"
		"monitor":
			return "显示器"
		"printer":
			return "打印机"
		"meeting":
			return "会议桌运输"
		_:
			return kind


func _format_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var minutes: int = int(floor(safe_seconds / 60.0))
	var remainder: float = fposmod(safe_seconds, 60.0)
	return "%02d:%05.2f" % [minutes, remainder]


func _setting_float(key: String, fallback: float) -> float:
	var settings: Dictionary = _to_dictionary(_context.get("settings", {}))
	var raw_value: Variant = settings.get(key, fallback)
	return clampf(float(raw_value), 0.0, 1.0)


func _setting_bool(key: String, fallback: bool) -> bool:
	var settings: Dictionary = _to_dictionary(_context.get("settings", {}))
	return bool(settings.get(key, fallback))


func _to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _emit_action(action: String, value: Variant) -> void:
	action_requested.emit(action, value)


func _on_slider_changed(value: float, key: String) -> void:
	if _setting_value_labels.has(key):
		var label: Label = _setting_value_labels[key] as Label
		if is_instance_valid(label):
			label.text = str(int(value * 100.0)) + "%"
	action_requested.emit("setting", {"key": key, "value": value})


func _on_check_changed(value: bool, key: String) -> void:
	if _setting_checks.has(key):
		var check: CheckButton = _setting_checks[key] as CheckButton
		if is_instance_valid(check):
			check.text = "开启" if value else "关闭"
	action_requested.emit("setting", {"key": key, "value": value})


func _focus_first() -> void:
	for target in _focus_targets:
		if is_instance_valid(target) and target.focus_mode != Control.FOCUS_NONE:
			if target is Button and (target as Button).disabled:
				continue
			target.grab_focus()
			return
