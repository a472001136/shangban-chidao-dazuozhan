extends "res://verification/verify_tactical.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	game.save = load("res://scripts/save_store.gd").new("res://verification/通勤画面_" + stamp + ".json")
	game._start_level(1,true)
	await shot("flow_briefing")
	await start()
	game.timer_started = true
	game.remaining = 0.001
	await frames(4)
	check("超时结算显示未打卡与失败原因", game.state == "failure" and game.ui._result.rank == "未打卡" and not str(game.ui._result.failure_reason).is_empty())
	await shot("flow_failure")
	await start()
	game._on_hr_caught()
	await frames(3)
	check("抓获结算显示登记原因", "被人事" in str(game.ui._result.failure_reason))
	await shot("flow_caught")
	var passed: bool = true
	for row in checks:
		passed = passed and bool(row.passed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
