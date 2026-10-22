extends SceneTree

var game: Node
var failures: Array[String] = []
var checks: Array[String] = []
var capture_enabled = false

func _initialize() -> void:
	capture_enabled = OS.get_cmdline_user_args().has("--screenshots")
	_run.call_deferred()

func _check(label: String, condition: bool) -> void:
	checks.append(label)
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _capture(name: String) -> void:
	if not capture_enabled:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	captured.save_png("res://verification/" + name + ".png")

func _action(action: String, value: Variant = null) -> void:
	game.ui.action_requested.emit(action, value)

func _run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var stamp = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	var store = load("res://scripts/save_store.gd")
	game.save = store.new("res://verification/整周到岗记录_" + stamp + ".json")
	game.save.data = game.save.defaults()
	game._apply_settings()
	game._show_screen("title")
	_check("真实启动到标题", game.state == "title" and game.ui.current_screen == "title")
	await _capture("title")
	_action("calendar")
	_check("标题进入周历", game.state == "calendar" and game.ui.current_screen == "calendar")
	await _capture("calendar")
	_action("level", 1)
	_check("周一通知页", game.state == "briefing" and game.level_index == 1)
	await _capture("briefing")
	_action("start")
	_check("通知进入实际关卡", game.state == "playing" and game.player.controls_enabled and game.world.active)
	var untouched_time: float = game.remaining
	await _frames(30)
	_check("首次移动前不消耗时间", is_equal_approx(game.remaining, untouched_time))
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	_check("真实移动启动倒计时", game.timer_started and game.remaining < untouched_time and game.player.position.x > 200.0)
	await _capture("gameplay")
	game._open_pause()
	var paused_time: float = game.remaining
	var paused_position: Vector2 = game.player.position
	await _frames(80)
	_check("暂停冻结计时与角色", game.state == "pause" and is_equal_approx(game.remaining, paused_time) and game.player.position.is_equal_approx(paused_position))
	await _capture("pause")
	_action("settings")
	_check("暂停进入设置", game.state == "settings")
	_action("setting", {"key": "assist", "value": true})
	_check("局中设置不立刻改变模式", not game.assist_for_run and game.save.data.settings.assist)
	await _capture("settings")
	_action("back")
	_check("关闭设置返回暂停", game.state == "pause" and not game.player.simulation_enabled)
	_action("resume")
	_check("暂停恢复", game.state == "playing" and game.player.simulation_enabled)
	game._restart_current()
	_check("重开重置计时与模式", game.state == "playing" and not game.timer_started and is_equal_approx(game.level_limit, float(game._level.limit)*1.25) and game.assist_for_run)
	_check("重开恢复起点和道具", game.player.position.is_equal_approx(game.world.spawn_position) and game.player.held == "" and game._damage_total == 0)
	game.save.data.settings.assist = false
	for index in range(6):
		game._start_level(index, true)
		game._begin_play()
		await _frames(2)
		game.timer_started = true
		game.remaining = game.level_limit - 12.0
		game.player.position = game.world.goal_position - Vector2(0, 230)
		game._handle_interaction()
		_check("关卡%d不能从远处高层打卡" % index, game.state == "playing")
		game.player.position = game.world.goal_position
		game._handle_interaction()
		_check("关卡%d工位互动成功与计时锁定" % index, game.state == "success" and game.result_locked and not game.world.active)
		var locked_time: float = game.remaining
		await _frames(8)
		_check("关卡%d结算不继续扣时间" % index, is_equal_approx(game.remaining, locked_time))
		if index == 5:
			await _frames(90)
			await _capture("result")
		game._restart_current()
		_check("关卡%d成功后可以重开" % index, game.state == "playing" and not game.result_locked and not game.timer_started)
		game.timer_started = true
		game.remaining = 0.001
		await _frames(3)
		_check("关卡%d超时失败" % index, game.state == "failure" and game.result_locked)
		if index == 5:
			await _capture("failure")
		game._restart_current()
		_check("关卡%d失败后可以重开" % index, game.state == "playing" and game.remaining > 0.0)
	game._open_calendar()
	_check("整周进度已解锁", game.save.data.week_complete and game.save.data.unlocked == 5)
	await _capture("calendar_unlocked")
	var report = {"checks": checks.size(), "failures": failures, "passed": failures.is_empty(), "scope": "菜单导航、实际移动、暂停、模式、六关胜负重开与存档；通关测试使用终点定位，不证明路线可达"}
	var report_file = FileAccess.open("res://verification/game_report.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("GAME_REPORT " + JSON.stringify(report))
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
