extends "res://verification/verify_tactical.gd"

var observed: Array[Dictionary] = []

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	game.save = load("res://scripts/save_store.gd").new("res://verification/精彩通勤_" + stamp + ".json")
	game.player.flow_action.connect(func(id: String, kind: String, label: String, points: int): observed.append({"kind": kind, "position": game.player.position, "speed": game.player.velocity.x}))
	await start()
	await shot("flow_opening")
	var routes_only: bool = "--routes-only" in OS.get_cmdline_user_args()
	if not routes_only:
		await motion_checks()
		await score_checks()
		await near_checks()
	await chaos_route()
	check("整局连锁路线产生连续评分", game._chaos_score > 600 and game._best_combo >= 2 and game._flow_all_types.size() >= 2, {"score": game._chaos_score, "combo": game._best_combo, "types": game._flow_all_types})
	if visual:
		check("名场面截取来自实际游玩", game._moment_texture != null)
	await shot("flow_result")
	await skill_route()
	var passed: bool = true
	for row in checks:
		passed = passed and bool(row.passed)
	var report := FileAccess.open("res://verification/flow_visual_report.json" if routes_only else "res://verification/flow_report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "checks": checks, "routes": routes, "motion": observed, "method": "整局保留人事和碰撞，定点检查用于隔离运动与评分边界。"}, "\t"))
	report.close()
	release()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)

func skill_route() -> void:
	await start()
	game._handle_interaction()
	await tap("use_tool")
	Input.action_press("move_right")
	await tap("dash")
	Input.action_press("jump")
	await frames(16)
	Input.action_release("jump")
	var airborne: bool = true
	for index in range(70):
		if not game.player.is_on_floor() and game.player.velocity.y > 0.0 and game.player.position.y > 479.0 and game.player.position.x > 450.0 and game.player.position.x < 548.0:
			Input.action_press("dash")
		if airborne and game.player.is_on_floor():
			await frames(2)
			break
		await step()
	release()
	for point in [Vector2(510,500),Vector2(790,400),Vector2(1040,330),Vector2(1210,330),Vector2(1310,500),Vector2(1460,600)]:
		if not await travel(point):
			break
	if game.state == "playing":
		game._handle_interaction()
		Input.action_press("move_right")
		for index in range(160):
			if game.state != "playing" or game.player.position.x > 1750:
				break
			await step()
		release()
		Input.action_press("jump")
		Input.action_press("move_right")
		await frames(35)
		release()
		await travel(Vector2(2020,600))
		game._handle_interaction()
		for point in [Vector2(2400,488),Vector2(2680,600)]:
			if not await travel(point,480,true):
				break
		await tap("use_tool")
		await travel(Vector2(3450,600),480,true)
	await finish_route("高速翻越落地冲刺连锁路线",false)
	check("实际整局操作可以达到 S 级", game.state == "success" and game._flow_rank(true) == "S" and game._flow_all_types.has("landing_dash") and not teleported, {"score": game._chaos_score, "combo": game._best_combo, "types": game._flow_all_types, "position": game.player.position})
	await shot("flow_skill_result")

func motion_checks() -> void:
	await start()
	for officer in game.world.officers:
		officer.set_physics_process(false)
	Input.action_press("move_right")
	await tap("dash")
	Input.action_press("jump")
	var buffered: bool = false
	var airborne: bool = false
	var air_speed: float = 0.0
	var landed_speed: float = 0.0
	for index in range(80):
		if index == 16:
			Input.action_release("jump")
		if not game.player.is_on_floor():
			airborne = true
			if index == 20:
				air_speed = game.player.velocity.x
			if game.player.velocity.y > 0.0 and game.player.position.y > 479.0 and game.player.position.x > 450.0 and game.player.position.x < 548.0 and not buffered:
				Input.action_press("dash")
				buffered = true
		elif airborne:
			landed_speed = game.player.velocity.x
			await frames(8)
			break
		await step()
	release()
	check("定点运动：地面冲刺起跳保持实际惯性", airborne and air_speed > 400.0, air_speed)
	check("定点运动：落地前冲刺输入被缓冲", buffered and game._flow_all_types.has("landing_dash"), observed)
	check("定点运动：高速翻越由真实起落产生", game._flow_all_types.has("vault"), {"land_speed": landed_speed, "actions": observed})
	await shot("flow_motion")
	game._open_pause()
	var paused: Dictionary = {"time": game._combo_remaining, "position": game.player.position, "score": game._chaos_score}
	await frames(30)
	check("暂停冻结连击与运动", game._combo_remaining == paused.time and game.player.position == paused.position and game._chaos_score == paused.score)
	game._resume_game()
	await start()
	Input.action_press("jump")
	await frames(15)
	var before: float = game.player.velocity.x
	await tap("dash")
	check("空中冲刺不凭空提供推进力", absf(game.player.velocity.x - before) < 5.0)
	release()

func score_checks() -> void:
	await start()
	game._score_flow("first", "vault", "高速翻越", 130, Vector2(600,500))
	var initial: int = game._chaos_score
	game._score_flow("first", "vault", "高速翻越", 130, Vector2(600,500))
	check("评分边界：同一事件不重复计分", game._chaos_score == initial)
	game._score_flow("same_spot", "vault", "高速翻越", 130, Vector2(610,500))
	check("评分边界：原地重复跳不刷分", game._chaos_score == initial)
	game._score_flow("forward_repeat", "vault", "高速翻越", 130, Vector2(800,500))
	check("评分边界：连续同招降分且不增加连击", game._combo == 1 and game._flow_award == 32)
	game._score_flow("other", "landing_dash", "落地接冲刺", 110, Vector2(850,500))
	game._score_flow("third", "near_miss", "擦身躲过查岗", 220, Vector2(1000,500))
	check("评分边界：不同动作续接提高倍率", game._combo == 3 and game._flow_award == 520)
	game._open_pause()
	var score: int = game._chaos_score
	game._score_flow("paused", "chain", "连锁事故", 100, Vector2(1000,500))
	check("暂停不能接受评分事件", game._chaos_score == score)
	game._resume_game()
	for officer in game.world.officers:
		officer.set_physics_process(false)
	await frames(250)
	check("四秒没有新动作连击归零", game._combo == 0 and game._flow_types.is_empty())
	await start()
	game._on_world_accident("desk_files", "files", 30, Vector2(400,570))
	game._on_stunt("chain_desk_files", "连锁事故：椅子开路", 100)
	check("同一次碰撞的事故与连锁只算一招", game._combo == 1 and game._flow_all_types.has("chain"))
	game._score_flow("after", "noise_lure", "诱饵脱身", 160, Vector2(500,600))
	game.player.knock(game.player.position - Vector2(40,0))
	check("摔倒中断连击", game._combo == 0 and game._combo_remaining == 0.0)
	await start()
	check("重开清空连击与名场面", game._flow_seen.is_empty() and game._flow_all_types.is_empty() and game._combo == 0 and game._moment_texture == null)
	game._chaos_score = 4000
	game._best_combo = 6
	game._flow_all_types = {"vault": true, "near_miss": true, "chain": true}
	check("S 级同时要求分数连击与动作种类", game._flow_rank(true) == "S")
	game._flow_all_types = {"vault": true}
	check("单一动作高分不能得到 S 级", game._flow_rank(true) != "S")
	check("失败不能获得成功评级", game._flow_rank(false) == "未打卡")

func near_checks() -> void:
	await start()
	for actor in game.world.officers:
		actor.set_physics_process(false)
	var officer = game.world.officers[0]
	officer.position = Vector2(630,600)
	officer.state = "chase"
	game.player.reset_at(Vector2(500,500))
	previous = game.player.position
	Input.action_press("move_right")
	await frames(70)
	release()
	check("定点：真实经过追赶人事上方触发擦身", game._flow_seen.has("near_0"), {"position": game.player.position, "passes": game._near_passes})
	await shot("flow_near")
	await start()
	for actor in game.world.officers:
		actor.set_physics_process(false)
	officer = game.world.officers[0]
	officer.position = Vector2(630,600)
	officer.state = "patrol"
	game.player.reset_at(Vector2(500,500))
	previous = game.player.position
	Input.action_press("move_right")
	await frames(70)
	release()
	check("定点：普通经过巡逻人事不算擦身", not game._flow_seen.has("near_0"))
