extends SceneTree

var game: Node2D
var checks: Array = []
var runs: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func release() -> void:
	for action in ["move_left","move_right","jump","dash","brake","busy","use_tool"]:
		Input.action_release(action)

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/hr_"+label+".png")

func start() -> void:
	release()
	game._start_level(0,false)
	await frames(8)

func isolate() -> void:
	for officer in game.world.officers:
		officer.set_physics_process(false)

func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","")
	game.save=load("res://scripts/save_store.gd").new("res://verification/考勤追赶_"+stamp+".json")
	game.save.data.settings.screen_shake=false
	game._apply_settings()
	await start()
	check("三名人事预先出现在巡查区",game.world.officers.size()==3)
	check("菜单和简报正常",game.ui.current_screen=="hud")
	await shot("opening")
	if not "--week-only" in OS.get_cmdline_user_args():
		await route(true)
		await route(false)
		await rules()
		await boundaries()
	if not "--visual-only" in OS.get_cmdline_user_args():
		await week_routes()
	var passed: bool = true
	for row in checks:
		passed=passed and bool(row.passed)
	var file:=FileAccess.open("res://verification/hr_visual_report.json" if "--visual-only" in OS.get_cmdline_user_args() else "res://verification/hr_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":runs,"method":"两条路线使用真实输入；定点规则检查明确标注，测试存档位于 verification。"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func route(chair: bool) -> void:
	await start()
	if chair:
		game._handle_interaction()
		check("起点可坐办公椅",game.player.held=="chair")
	Input.action_press("move_right")
	var previous: Vector2 = game.player.position
	var teleport: bool = false
	var jumping: int = 0
	var ticks: int = 0
	var photographed: bool = false
	for i in range(3600):
		if game.state!="playing":
			break
		var wants_jump: bool = (not chair and (game.player.position.x<1100 or game.player.position.x>1510)) or (chair and game.player.position.x>1530)
		if game.player.position.x>game.world.goal_position.x-90:
			wants_jump=false
			Input.action_release("move_right")
			Input.action_press("brake")
		if not wants_jump:
			Input.action_release("jump")
			jumping=0
		elif jumping>0:
			jumping-=1
			if jumping==0:
				Input.action_release("jump")
				jumping=-3
		elif jumping<0:
			jumping+=1
		elif game.player.is_on_floor():
			Input.action_press("jump")
			jumping=30
		if not chair and (i%43==0 or (game.player.position.x>1250 and game.player.position.x<1500 and game.player.is_on_floor())):
			Input.action_press("dash")
		elif i%43==1:
			Input.action_release("dash")
		await physics_frame
		ticks+=1
		teleport=teleport or previous.distance_to(game.player.position)>35
		previous=game.player.position
		if not photographed and game.player.position.x>2400:
			await shot("upper_route" if chair else "pursuit")
			photographed=true
		if game.world.goal_reachable(game.player.position):
			game._handle_interaction()
			break
	release()
	var label: String = "椅子开路后走上层" if chair else "步行跳跃加地面冲刺"
	runs.append({"route":label,"state":game.state,"seconds":ticks/60.0,"teleport":teleport,"position":[game.player.position.x,game.player.position.y]})
	check(label+"躲过人事并打卡",game.state=="success",runs.back())
	check(label+"没有传送",not teleport)
	await frames(55)
	await shot("result_chair" if chair else "result_foot")

func rules() -> void:
	await start()
	isolate()
	game.player.position=Vector2(970,600)
	game.player._started_once=true
	game.player.velocity=Vector2.ZERO
	var officer=game.world.officers[0]
	officer.position=Vector2(1130,600)
	officer.facing=-1
	officer.set_physics_process(true)
	Input.action_press("busy")
	await frames(55)
	check("定点：绿线处可装忙",game.player.busy,[game.player.position,game.player.is_on_floor(),game.world.busy_near(game.player.position)])
	check("定点：人事先核查日报",officer.state=="inspect",officer.state)
	await shot("inspection")
	game._open_pause()
	var old_pos: Vector2 = officer.position
	var old_inspection: float = officer.inspection
	await frames(30)
	check("暂停冻结追赶和核查",officer.position==old_pos and officer.inspection==old_inspection)
	game._resume_game()
	await frames(125)
	check("装忙持续太久会被识破",officer.state in ["chase","grab","caught"],officer.state)
	await frames(100)
	check("近距离伸手后登记迟到",game.state=="failure",game.state)
	await shot("caught")
	await start()
	isolate()
	game.player.position=Vector2(3190,600)
	game.player.velocity=Vector2.ZERO
	await frames(10)
	var table=game.world.table
	var old_x: float = table.position.x
	Input.action_press("move_right")
	await frames(95)
	check("定点：贴近会议桌可推动",table.position.x>old_x+40,table.position.x-old_x)
	check("推动时玩家留在桌边",game.player.position.x<table.position.x-185)
	await shot("pushing_active")
	release()
	var speed: float = absf(table.velocity.x)
	await frames(100)
	check("停止推桌后摩擦减速",absf(table.velocity.x)<speed and absf(table.velocity.x)<5)
	game.player.position=table.position+Vector2(240,0)
	game.player.velocity=Vector2.ZERO
	officer=game.world.officers[0]
	officer.position=table.position-Vector2(240,0)
	officer.state="chase"
	officer.last_seen=game.player.position
	officer.memory=4.5
	officer.set_physics_process(true)
	await frames(25)
	check("推过的会议桌能挡住追赶并触发事件",game._stunts.has("table_block") and game.world._challenge_sent.has("table_block"))
	officer.set_physics_process(false)
	await shot("pushing")
	await start()
	isolate()
	game._handle_interaction()
	Input.action_press("move_right")
	await frames(36)
	release()
	Input.action_press("brake")
	await frames(20)
	var braking_speed: float = absf(game.player.velocity.x)
	Input.action_release("brake")
	await frames(5)
	check("松开刹车不会凭空加速",absf(game.player.velocity.x)<=braking_speed+0.1)
	Input.action_press("move_right")
	await frames(25)
	release()
	var chair_x: float = game.player.position.x
	game.player._jump_buffer_seconds=0.12
	Input.action_press("jump")
	await frames(2)
	check("从椅子起跳会离椅",game.player.held.is_empty() and game.player.velocity.y<0)
	await frames(10)
	check("离椅后椅子仍保留惯性",float(game.world._tools[0].pos.x)>chair_x+5)
	release()
	var air_speed: float = game.player.velocity.x
	Input.action_press("dash")
	await frames(2)
	check("空中不能冲刺增速",absf(game.player.velocity.x)<=absf(air_speed)+0.1)
	release()
	await start()
	isolate()
	game.player.position=Vector2(2170,405)
	game.player.velocity=Vector2.ZERO
	await frames(8)
	game.player.interact()
	check("上层可拿灭火器",game.player.held=="extinguisher")
	Input.action_press("use_tool")
	await frames(15)
	check("喷粉生成遮挡",game.world.vision_obscured(Vector2(2100,405),Vector2(2350,405)))
	check("喷粉不托举角色",game.player.is_on_floor() and absf(game.player.position.y-405)<2)
	await shot("powder")
	release()
	game.player.interact()
	await frames(8)
	var dropped: Vector2 = game.world._tools[1].pos
	check("道具放下后留在上层支撑面",absf(dropped.y-405)<3,dropped)
	game._restart_current()
	check("重开重置人事和家具",game.world.officers[0].state=="patrol" and absf(game.world.table.position.x-3410)<1)
	game._open_album()
	await shot("album")
	check("图鉴可以打开",game.state=="album")

func boundaries() -> void:
	await start()
	isolate()
	game.player.position=Vector2(970,600)
	game.player.velocity=Vector2.ZERO
	game._on_player_started()
	game.player._started_once=true
	await frames(4)
	var officer=game.world.officers[0]
	officer.position=Vector2(1010,600)
	officer.state="chase"
	officer.memory=4
	officer.set_physics_process(true)
	await frames(15)
	check("定点：伸手有反应窗口",game.state=="playing" and officer.grab>0 and officer.grab<0.8,officer.grab)
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(16)
	release()
	check("离开伸手范围会取消登记",game.state=="playing" and officer.grab==0,[officer.grab,game.player.position])
	await start()
	isolate()
	game.player.position=Vector2(970,600)
	game.player.velocity=Vector2.ZERO
	await frames(4)
	game._on_player_started()
	game.player._started_once=true
	officer=game.world.officers[0]
	officer.position=Vector2(1130,600)
	officer.facing=-1
	officer.set_physics_process(true)
	Input.action_press("busy")
	await frames(50)
	Input.action_release("busy")
	Input.action_press("move_left")
	await frames(40)
	check("离开装忙点时人事仍在看日报",officer.state=="inspect" and game.state=="playing",officer.state)
	await frames(50)
	check("装忙可以争取离开的时间",game.state=="playing")
	release()
	await start()
	isolate()
	var table=game.world.table
	table.position=Vector2(4550,600)
	table.velocity=Vector2(350,0)
	await frames(90)
	check("定点：会议桌不能穿过边界墙",table.position.x<=4610.1 and absf(table.velocity.x)<1,table.position)
	await start()
	isolate()
	game.player.position=Vector2(1380,600)
	await frames(4)
	officer=game.world.officers[0]
	officer.position=Vector2(1570,600)
	await frames(4)
	check("定点：实体饮水机遮挡人事视线",not officer.clear_sight(game.player.position))
	game.world._break_prop(game.world._props[1],1,"player")
	await frames(15)
	check("饮水机滚桶会受重力下落",game.world.objects.size()>1 and game.world.objects.back().position.y>500)
	var early: float = float(game.world._water_spills[0].x2)-float(game.world._water_spills[0].x1)
	await frames(70)
	var later: float = float(game.world._water_spills[0].x2)-float(game.world._water_spills[0].x1)
	check("漏水逐渐扩散",later>early and later<601,[early,later])
	var stamp: String = Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","")
	var path: String = "res://verification/考勤存档迁移_"+stamp+".json"
	var old: Dictionary = game.save.defaults()
	old.monday_revision=2
	old.unlocked=4
	old.levels={"1":{"normal_best":12.0,"medals":[true,true,true],"discoveries":{"rocket_chair":"消防器材新用途","chair_clock":"椅子站着加班"},"coupons":[1]}}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated=load("res://scripts/save_store.gd").new(path)
	check("迁移保留关卡与午饭券",migrated.data.unlocked==4 and migrated.level_record(1).coupons==[1])
	check("迁移移除失效火箭发现和旧路线纪录",migrated.data.monday_revision==4 and not migrated.level_record(1).discoveries.has("rocket_chair") and migrated.level_record(1).normal_best==0)

func week_routes() -> void:
	for index in range(2,6):
		release()
		game._start_level(index,false)
		await frames(8)
		Input.action_press("move_right")
		var previous: Vector2 = game.player.position
		var teleport: bool = false
		var jumping: int = 0
		var ticks: int = 0
		var approaching: bool = false
		for i in range(7200):
			if game.state!="playing":
				break
			var near_tall: bool = false
			for prop in game.world._props:
				if game.player.is_on_floor() and not game.world._damaged.has(str(prop.id)) and float(prop.size.y)>125 and float(prop.x)>game.player.position.x and float(prop.x)-game.player.position.x<230 and absf(game.player.position.y-float(prop.y))<30:
					near_tall=true
			approaching = approaching or game.player.position.x>game.world.goal_position.x-90
			if approaching:
				Input.action_release("move_right")
				Input.action_release("jump")
				Input.action_release("dash")
				Input.action_press("brake")
			elif near_tall:
				Input.action_release("jump")
				jumping=0
				if game.player.is_on_floor() and i%2==0:
					Input.action_press("dash")
				else:
					Input.action_release("dash")
			elif jumping>0:
				jumping-=1
				if jumping==0:
					Input.action_release("jump")
					jumping=-3
			elif jumping<0:
				jumping+=1
			elif game.player.is_on_floor():
				Input.action_press("dash")
				Input.action_press("jump")
				jumping=35
			if not game.player.is_on_floor():
				Input.action_release("dash")
			if approaching:
				Input.action_release("move_right")
				Input.action_release("move_left")
				Input.action_release("jump")
				Input.action_release("dash")
				if absf(game.player.position.x-game.world.goal_position.x)>80:
					Input.action_release("brake")
					Input.action_press("move_left" if game.player.position.x>game.world.goal_position.x else "move_right")
				else:
					Input.action_press("brake")
			await physics_frame
			ticks+=1
			teleport=teleport or previous.distance_to(game.player.position)>35
			previous=game.player.position
			if game.world.goal_reachable(game.player.position):
				game._handle_interaction()
				break
		release()
		runs.append({"level":index,"state":game.state,"seconds":ticks/60.0,"teleport":teleport,"position":[game.player.position.x,game.player.position.y]})
		check("工作日"+str(index)+"实际输入可通关",game.state=="success" and not teleport,runs.back())
		await frames(55)
