extends SceneTree

var game: Node = null
var checks: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save.data = game.save.defaults()
	game._start_level(0, false)
	var player: CharacterBody2D = game.player
	var world: Node2D = game.world
	var prop: Dictionary = {}
	for prop_value in world.get("_props"):
		var candidate: Dictionary = prop_value
		if str(candidate.get("id", "")) == "training_box":
			prop = candidate
			break
	var prop_id: String = str(prop.get("id", ""))
	var prop_size_value: Variant = prop.get("size", Vector2(76.0, 74.0))
	var prop_size: Vector2 = prop_size_value if prop_size_value is Vector2 else Vector2(76.0, 74.0)
	var prop_x: float = float(prop.get("x", 1740.0))
	var prop_y: float = float(prop.get("y", 600.0))
	var test_delta: float = 1.0 / 60.0
	player.velocity = Vector2(800.0, 0.0)
	player.position = Vector2(prop_x - 80.0, prop_y)
	world.call("_check_props", test_delta, player.position)
	_record("远离物件时不计事故", game._accidents.is_empty())
	player.position = Vector2(prop_x, prop_y - prop_size.y - 100.0)
	world.call("_check_props", test_delta, player.position)
	_record("从物件上方经过时不计事故", game._accidents.is_empty())
	player.position = Vector2(prop_x - 19.0 - prop_size.x * 0.38 - 2.0, prop_y)
	world.call("_check_props", test_delta, player.position)
	_record("高速实际接触后登记一次事故", game._accidents.size() == 1 and world.get("_accident_effects").size() == 1)
	world.call("_check_props", test_delta, player.position)
	_record("同一物件不会重复登记", game._accidents.size() == 1 and world.get("_accident_effects").size() == 1)
	world.call("_process", 0.2)
	var effect_list: Array = world.get("_accident_effects")
	var effect_age: float = float(effect_list[0].get("age", 0.0)) if not effect_list.is_empty() else -1.0
	var shake_time: float = float(game.get("_camera_shake_time"))
	var context_value: Variant = game.ui.get("_context")
	var hud_context: Dictionary = context_value if context_value is Dictionary else {}
	var recent_event: String = str(hud_context.get("recent_event", ""))
	_record("HUD显示事故数、损失和最近事故", int(hud_context.get("accidents", 0)) == 1 and int(hud_context.get("damage", 0)) == 30 and recent_event.contains("损失 30 元"))
	_record("HUD提供避险说明", str(hud_context.get("accident_tip", "")).contains("跳跃或减速"))
	game.call("_open_pause")
	game.call("_process", 0.5)
	world.call("_process", 0.5)
	effect_list = world.get("_accident_effects")
	var paused_effect_age: float = float(effect_list[0].get("age", 0.0)) if not effect_list.is_empty() else -2.0
	_record("暂停期间特效与冲击效果冻结", is_equal_approx(effect_age, paused_effect_age) and is_equal_approx(shake_time, float(game.get("_camera_shake_time"))))
	game.call("_restart_current")
	_record("重开后清除事故与特效", game._accidents.is_empty() and int(game.get("_damage_total")) == 0 and world.get("_accident_effects").is_empty())
	var passed: bool = true
	for check in checks:
		passed = passed and bool(check.get("passed", false))
	var report: Dictionary = {"passed": passed, "checks": checks}
	var output: FileAccess = FileAccess.open("res://verification/accident_feedback_report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("ACCIDENT_FEEDBACK " + JSON.stringify(report))
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit(0 if passed else 1)


func _record(name: String, passed: bool) -> void:
	checks.append({"check": name, "passed": passed})
