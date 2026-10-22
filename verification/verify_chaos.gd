extends SceneTree

var game: Node2D
var checks: Array[Dictionary] = []
var runs: Array[Dictionary] = []
var capture: bool = false
var save_path: String = ""

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func release_controls() -> void:
	for action in ["move_left","move_right","jump","dash","brake","use_tool"]:
		Input.action_release(action)

func shot(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/chaos_"+label+".png")

func _run() -> void:
	capture = DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	save_path = "res://verification/早会玩法_"+Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","")+".json"
	game.save = load("res://scripts/save_store.gd").new(save_path)
	game.save.data.settings.screen_shake = false
	game._apply_settings()
	check("标题直接进入新周一",game.ui.get_node_or_null("LogicalCanvas") != null or game.ui.current_screen == "title")
	await _chair_run()
	await _rocket_run()
	await _face_run()
	await _bucket_run()
	await _logic_checks()
	var passed: bool = true
	for row in checks:
		passed = passed and bool(row.passed)
	var report: Dictionary = {"passed":passed,"checks":checks,"runs":runs,"method":"真实物理输入完成三局；独立规则检查分别注明。快乐程度需玩家试玩评估。"}
	var file: FileAccess = FileAccess.open("res://verification/chaos_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _chair_run() -> void:
	release_controls()
	game._start_level(1,false)
	await frames(8)
	await shot("opening")
	game._handle_interaction()
	check("起点按 E 即可上椅子",game.player.held=="chair")
	Input.action_press("move_right")
	var recovered: bool = false
	var last_position: Vector2 = game.player.position
	var last_held: String = game.player.held
	var captures: Dictionary = {}
	var tick: int = 0
	for i in range(3600):
		await physics_frame
		tick+=1
		if game.player.held != last_held:
			print("TOOL_CHANGE " + str(game.player.position)+" "+game.player.held)
			last_held=game.player.held
		if absf(game.player.position.x-last_position.x)>100.0 and not game.player.meeting_ride:
			recovered=true
		last_position=game.player.position
		if not game.player.meeting_ride and game.world.meeting_near(game.player.position):
			game._handle_interaction()
		for mark in [1350,2260,4430,6510]:
			if game.player.position.x>mark and not captures.has(mark):
				captures[mark]=true
				await shot("chair_"+str(mark))
		if game.world.goal_reachable(game.player.position):
			game._handle_interaction()
			break
		if game.state=="failure":
			break
	release_controls()
	check("真实骑椅路线成功",game.state=="success",{"seconds":tick/60.0,"position":game.player.position,"recovered":recovered})
	check("路线未借助越界恢复",not recovered)
	check("滚桶触发文件与打印机",game._stunts.has("chain_mon_files") and game._stunts.has("paper_bridge"),game._stunts.keys())
	check("打印纸形成可走上层路线",game._stunts.has("upper_route"))
	check("会议桌抵达打卡区",game._stunts.has("meeting_delivery"))
	check("坐着会议桌打卡",game._arrival_style=="meeting")
	check("事故组合至少三连锁",game._best_combo>=3,game._best_combo)
	check("首胜解锁火箭椅",game.save.data.rocket_unlocked)
	check("三连锁解锁弹簧椅",game.save.data.spring_unlocked)
	await frames(65)
	await shot("first_result")
	runs.append({"route":"办公椅与移动早会","success":game.state=="success","seconds":tick/60.0,"chaos":game._chaos_score,"combo":game._best_combo,"arrival":game._arrival_style,"recoveries":recovered})

func _rocket_run() -> void:
	game._start_level(1,false)
	await frames(8)
	game._handle_interaction()
	Input.action_press("move_right")
	await frames(20)
	Input.action_press("brake")
	await frames(27)
	check("刹车可以蓄甩尾",game.player.drift_charge>=0.3,game.player.drift_charge)
	var frozen_charge: float = game.player.drift_charge
	game._open_pause()
	await frames(15)
	check("暂停冻结甩尾蓄力",is_equal_approx(game.player.drift_charge,frozen_charge))
	game._resume_game()
	Input.action_release("brake")
	await frames(12)
	check("松开刹车触发甩尾",game._stunts.has("chair_drift") and absf(game.player.velocity.x)>500,game.player.velocity.x)
	var attached: bool = false
	var jump_hold: int = 0
	var gaps: Dictionary = {}
	var tick: int = 0
	for i in range(3500):
		await physics_frame
		tick+=1
		for gap in [3050,3490]:
			if game.player.position.x>gap and game.player.position.x<gap+90 and game.player.is_on_floor() and not gaps.has(gap):
				gaps[gap]=true
				jump_hold=32
		if jump_hold>0:
			Input.action_press("jump")
			jump_hold-=1
		else:
			Input.action_release("jump")
		if not attached and game.world.attachment_near(game.player.position):
			game._handle_interaction()
			attached=game.player.rocket_attached
			if attached:
				Input.action_press("use_tool")
				await frames(18)
				await shot("rocket")
		if game.world.goal_reachable(game.player.position):
			game._handle_interaction()
			break
		if game.state=="failure":
			break
	release_controls()
	check("上层按 E 组装火箭椅",attached)
	check("F 推进形成独立名场面",game._stunts.has("rocket_chair"))
	check("火箭椅燃料有限",game.player.spray_seconds>0.2 and game.player.spray_seconds<3.4,game.player.spray_seconds)
	check("第二局真实路线成功",game.state=="success",game.player.position)
	check("上层路线跳过会议桌",not game._stunts.has("moving_meeting") and game._arrival_style=="chair",{"gaps":gaps,"style":game._arrival_style})
	await frames(65)
	await shot("replay_result")
	runs.append({"route":"甩尾与火箭椅","success":game.state=="success","seconds":tick/60.0,"chaos":game._chaos_score,"combo":game._best_combo,"arrival":game._arrival_style})

func _face_run() -> void:
	game._start_level(1,false)
	await frames(8)
	Input.action_press("move_right")
	var jump_hold: int = 0
	var jump_release: int = 0
	var dash_hold: int = 0
	var tick: int = 0
	for i in range(3500):
		if game.player.is_on_floor() and game.player.position.x<6200 and jump_hold==0 and jump_release==0:
			jump_hold=30
		if jump_hold>0:
			Input.action_press("jump")
			jump_hold-=1
			if jump_hold==0:
				jump_release=3
		else:
			Input.action_release("jump")
			jump_release=maxi(0,jump_release-1)
		if game.player.position.x>6400 and game.player.is_on_floor() and dash_hold==0:
			Input.action_press("dash")
			dash_hold=5
		elif dash_hold>0:
			dash_hold-=1
			if dash_hold==0:
				Input.action_release("dash")
		await physics_frame
		tick+=1
		if game.world.goal_reachable(game.player.position) and absf(game.player.velocity.x)>=550:
			game._handle_interaction()
			await shot("face_clock")
			break
		if game.player.position.x>game.world.goal_position.x+100 or game.state=="failure":
			break
	release_controls()
	check("普通步行路线也可到达终点",game.player.position.x>6500,game.player.position)
	check("真实冲刺触发脸部打卡",game.state=="success" and game._arrival_style=="face",{"state":game.state,"style":game._arrival_style})
	await frames(65)
	runs.append({"route":"跑跳与脸部打卡","success":game.state=="success","seconds":tick/60.0,"arrival":game._arrival_style})

func _bucket_run() -> void:
	game._start_level(1,false)
	await frames(8)
	Input.action_press("move_right")
	var dash_pressed: bool = false
	var taken: bool = false
	var jump_hold: int = 0
	var tick: int = 0
	for i in range(3500):
		if not dash_pressed and game.player.position.x>880.0:
			Input.action_press("dash")
			dash_pressed=true
		if dash_pressed and game.player.position.x>1090.0:
			Input.action_release("dash")
		if not taken and game.player.position.x>1100.0 and game.player.position.x<1230.0:
			game._handle_interaction()
			taken=game.player.held=="bucket"
		if taken and not game._stunts.has("bucket_launch") and game.player.is_on_floor() and bool(game.world.surface_at(game.player.position).get("wet",false)):
			jump_hold=28
		if jump_hold>0:
			Input.action_press("jump")
			jump_hold-=1
		else:
			Input.action_release("jump")
		await physics_frame
		tick+=1
		if game.world.goal_reachable(game.player.position):
			game._handle_interaction()
			break
		if game.state=="failure":
			break
	release_controls()
	check("真实路线取得拖把桶",taken)
	check("水面起跳触发保洁航空",game._stunts.has("bucket_launch"))
	check("拖把桶路线可完成打卡",game.state=="success",game.player.position)
	await frames(65)
	runs.append({"route":"拖把桶水面弹射","success":game.state=="success","seconds":tick/60.0,"chaos":game._chaos_score})

func _logic_checks() -> void:
	game._start_level(1,false)
	await frames(5)
	var initial_tools: int = game.world._tool_available.size()
	check("重开恢复事故与移动机关",game.world._damaged.is_empty() and game.world._meeting.is_empty() and game.world._rollers.is_empty())
	check("重开恢复所有道具",initial_tools==4)
	check("解锁在重开后保留",game.player.rocket_unlocked and game.player.spring_unlocked)
	game._on_stunt("chair_drift","办公椅甩尾，禁止模仿",160)
	var first_score: int = game._chaos_score
	game._on_stunt("chair_drift","办公椅甩尾，禁止模仿",160)
	check("重复动作不刷分",game._chaos_score==first_score)
	game.remaining=0.0
	game._finish_failure()
	var loaded = load("res://scripts/save_store.gd").new(save_path)
	check("失败后发现的名场面仍保存",loaded.level_record(1).discoveries.has("chair_drift"))
	check("混乱纪录可读回",loaded.level_record(1).normal_chaos>0)
	var normal: int = loaded.level_record(1).normal_chaos
	loaded.record_success(1,30.0,[true,false,false],[],true,9000)
	check("宽松混乱纪录独立保存",loaded.level_record(1).normal_chaos==normal and loaded.level_record(1).assist_chaos==9000)
	game._start_level(1,false)
	await frames(5)
	game._on_stunt("water_slide","饮用水改为交通用水",120)
	game._finish_success()
	game._restart_current()
	await frames(65)
	check("打卡演出期间重开不会被旧结算覆盖",game.state=="playing" and game.ui.current_screen=="hud")
	game._on_ui_action_requested("album",null)
	check("名场面图鉴可打开",game.state=="album" and game.ui.current_screen=="album")
	await shot("album")
	game._on_ui_action_requested("calendar",null)
	check("图鉴可以返回周历",game.state=="calendar" and game.ui.current_screen=="calendar")
	var legacy_data: Dictionary = game.save.defaults()
	legacy_data.erase("monday_revision")
	legacy_data["unlocked"]=3
	legacy_data["levels"]={"1":{"medals":[true,true,true],"coupons":[0,1],"normal_best":14.0,"assist_best":17.0}}
	var legacy_path: String = save_path.replace("早会玩法_","旧考勤迁移_")
	var legacy_file: FileAccess = FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_data))
	legacy_file.close()
	var migrated = load("res://scripts/save_store.gd").new(legacy_path)
	check("旧周一纪录迁移且保留整周进度",migrated.level_record(1).normal_best==0.0 and migrated.level_record(1).medals==[true,false,false] and migrated.data.unlocked==3 and migrated.level_record(1).coupons==[0,1])
