extends SceneTree

var failures: Array[String] = []
var checks: Array[String] = []
var accident_count = 0
var coupon_count = 0

func _initialize() -> void:
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

func _run() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "brake", "interact", "use_tool"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var store_script = load("res://scripts/save_store.gd")
	var stamp = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	var record_path = "res://verification/到岗记录_" + stamp + ".json"
	var record = store_script.new(record_path)
	record.data = record.defaults()
	record.record_success(0, 24.0, [false, false, false], [], false)
	record.record_success(1, 33.5, [true, true, false], [0, 1], false)
	record.record_success(1, 48.0, [true, false, true], [1, 2], true)
	record.record_success(5, 70.0, [true, true, true], [0], false)
	record.data.settings.music_volume = 0.21
	record.data.settings.screen_shake = false
	record.save()
	var reloaded = store_script.new(record_path)
	_check("成功进度与整周完成重载", reloaded.data.week_complete and reloaded.data.last_completed == 5 and reloaded.data.unlocked == 5)
	_check("奖章合并且午饭券不重复", reloaded.level_record(1).medals == [true, true, true] and reloaded.level_record(1).coupons.size() == 3)
	_check("普通与宽松成绩分别保存", is_equal_approx(reloaded.level_record(1).normal_best, 33.5) and is_equal_approx(reloaded.level_record(1).assist_best, 48.0))
	_check("音量与震动设置重载", is_equal_approx(reloaded.data.settings.music_volume, 0.21) and reloaded.data.settings.screen_shake == false)
	var corrupt = FileAccess.open(record_path, FileAccess.WRITE)
	corrupt.store_string("到岗记录中断")
	corrupt.close()
	var recovered = store_script.new(record_path)
	_check("损坏存档保留原件并恢复备份", FileAccess.file_exists(record_path + ".broken") and recovered.data.week_complete)
	var audio_script = load("res://scripts/audio.gd")
	var audio = audio_script.new()
	root.add_child(audio)
	await process_frame
	_check("音乐与音效可生成", audio.music.stream != null and audio.sounds.size() >= 12)
	audio.set_tool("chair", 400.0, false, true)
	_check("道具循环启动", audio.current_tool == "chair")
	audio.set_phase("pause")
	_check("暂停停止道具循环", audio.current_tool == "" and not audio.tool.playing)
	audio.queue_free()
	var data_script = load("res://scripts/level_data.gd")
	var world_script = load("res://scripts/world.gd")
	var player_script = load("res://scripts/player.gd")
	for index in range(6):
		var config: Dictionary = data_script.get_level(index)
		var world = world_script.new()
		root.add_child(world)
		world.hide()
		world.setup(index, [])
		var player = player_script.new()
		player.world = world
		world.add_child(player)
		world.set_player(player)
		player.reset_at(world.spawn_position)
		world.set_active(false)
		await _frames(8)
		_check("关卡%d起点落地" % index, player.is_on_floor() and absf(player.position.y - world.spawn_position.y) < 5.0)
		var start_x: float = player.position.x
		Input.action_press("move_right")
		await _frames(35)
		Input.action_release("move_right")
		_check("关卡%d基础移动" % index, player.position.x > start_x + 110.0)
		await _frames(10)
		var start_y: float = player.position.y
		Input.action_press("jump")
		await _frames(16)
		_check("关卡%d实际起跳" % index, player.position.y < start_y - 65.0)
		Input.action_release("jump")
		await _frames(50)
		_check("关卡%d终点高度校验" % index, world.goal_reachable(world.goal_position) and not world.goal_reachable(world.goal_position - Vector2(0, 220)))
		_check("关卡%d午饭券布局" % index, config.get("coupons", []).size() == (0 if index == 0 else 3))
		for tool_config in config.get("tools", []):
			player.position = tool_config.pos
			player.velocity = Vector2.ZERO
			player.interact()
			_check("关卡%d%s拿取" % [index, tool_config.kind], player.held == tool_config.kind)
			if player.held == "extinguisher":
				var before_fuel: float = player.fuel
				Input.action_press("move_right")
				Input.action_press("use_tool")
				await _frames(38)
				Input.action_release("move_right")
				Input.action_release("use_tool")
				_check("关卡%d灭火器有效推进" % index, player.fuel < before_fuel - 0.1 and absf(player.velocity.x) > 500.0)
			player.interact()
			_check("关卡%d%s释放" % [index, tool_config.kind], player.held.is_empty())
			await _frames(2)
		player.simulation_enabled = false
		accident_count = 0
		world.accident.connect(func(_id, _kind, _cost, _at): accident_count += 1)
		var props: Array = config.get("props", [])
		if not props.is_empty():
			var prop_size: Vector2 = props[0].get("size", Vector2(64, 64))
			player.position = Vector2(props[0].x - 150.0, props[0].y)
			player.velocity = Vector2(850, 0)
			world.set_active(true)
			await _frames(3)
			_check("关卡%d未接触不登记事故" % index, accident_count == 0)
			player.position = Vector2(props[0].x - 30.0, props[0].y - prop_size.y - 100.0)
			await _frames(3)
			_check("关卡%d上方经过不登记事故" % index, accident_count == 0)
			player.position = Vector2(props[0].x - prop_size.x * 0.5 - 14.0, props[0].y)
			await _frames(3)
			var first_count = accident_count
			await _frames(5)
			_check("关卡%d事故只登记一次" % index, first_count > 0 and accident_count == first_count)
		coupon_count = 0
		world.collected.connect(func(_id, _at): coupon_count += 1)
		for coupon in config.get("coupons", []):
			player.position = coupon.pos
			player.velocity = Vector2.ZERO
			await _frames(3)
		await _frames(4)
		_check("关卡%d券一次登记" % index, coupon_count == (0 if index == 0 else 3))
		world.set_active(false)
		world.queue_free()
		await process_frame
	var report = {"checks": checks.size(), "failures": failures, "passed": failures.is_empty()}
	var report_file = FileAccess.open("res://verification/module_report.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("MODULE_REPORT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
