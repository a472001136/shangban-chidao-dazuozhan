extends SceneTree

var game: Node2D
var checks: Array = []
var routes: Array = []
var visual: bool = false
var previous: Vector2
var teleported: bool = false
var ticks: int = 0

func _initialize() -> void:
	visual=DisplayServer.get_name()!="headless"
	_run.call_deferred()

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func release() -> void:
	for action in ["move_left","move_right","jump","dash","brake","busy","use_tool"]:
		Input.action_release(action)

func step() -> void:
	await physics_frame
	ticks+=1
	teleported=teleported or previous.distance_to(game.player.position)>35
	previous=game.player.position

func frames(count: int) -> void:
	for index in range(count):
		await step()

func shot(label: String) -> void:
	if not visual:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/tactical_"+label+".png")

func start() -> void:
	release()
	game._start_level(1,false)
	previous=game.player.position
	teleported=false
	ticks=0
	await frames(8)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)

func travel(target: Vector2, max_frames: int = 480, spray: bool = false) -> bool:
	var jumping: int = 0
	var blocked: int = 0
	var last_x: float = game.player.position.x
	for index in range(max_frames):
		if game.state!="playing":
			break
		var gap: Vector2 = target-game.player.position
		if absf(gap.x)<24 and absf(gap.y)<24 and game.player.is_on_floor():
			release()
			return true
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(gap.x)>12:
			Input.action_press("move_right" if gap.x>0 else "move_left")
		else:
			Input.action_press("brake")
		if absf(gap.x)>12:
			Input.action_release("brake")
		if spray:
			var threatened: bool = false
			for officer in game.world.officers:
				threatened=threatened or (officer.position.distance_to(game.player.position)<350 and officer.state in ["notice","chase","grab","search"] and officer.clear_sight(game.player.position))
			if threatened:
				Input.action_press("use_tool")
			else:
				Input.action_release("use_tool")
		if jumping>0:
			jumping-=1
			if jumping==0:
				Input.action_release("jump")
		elif game.player.is_on_floor() and ((gap.y<-30 and absf(gap.x)<260 and (game.player.velocity.x*signf(gap.x)>260 or absf(gap.x)<100)) or (blocked>6 and absf(gap.x)>30)):
			Input.action_press("jump")
			jumping=35
			blocked=0
		await step()
		blocked=blocked+1 if absf(game.player.position.x-last_x)<0.5 else 0
		last_x=game.player.position.x
	release()
	print("STOP target ",target," at ",game.player.position," state ",game.state)
	return false

func upper_route() -> void:
	await start()
	for point in [Vector2(510,500),Vector2(790,400),Vector2(1040,330),Vector2(1210,330),Vector2(1310,500),Vector2(1530,410),Vector2(1840,330)]:
		if not await travel(point):
			break
	if game.state=="playing":
		game._handle_interaction()
	await shot("upper")
	for point in [Vector2(2020,600),Vector2(2400,488),Vector2(2780,500),Vector2(2990,400),Vector2(3240,300),Vector2(3480,600)]:
		if not await travel(point,480,true):
			break
	await finish_route("上层绕行加消防遮挡",true)

func diversion_route() -> void:
	await start()
	await travel(Vector2(280,600))
	await tap("use_tool")
	await shot("diversion")
	for point in [Vector2(510,500),Vector2(600,600),Vector2(1140,488),Vector2(1310,500),Vector2(1530,410),Vector2(1840,330)]:
		if not await travel(point):
			break
	if game.state=="playing":
		game._handle_interaction()
	await travel(Vector2(2020,600),480,true)
	for point in [Vector2(2400,488),Vector2(2680,600)]:
		if not await travel(point,480,true):
			break
	await tap("use_tool")
	await shot("gate")
	await travel(Vector2(3450,600),480,true)
	await finish_route("复印诱饵加门禁放行",true)

func chaos_route() -> void:
	await start()
	game._handle_interaction()
	await tap("use_tool")
	for point in [Vector2(510,500),Vector2(790,400),Vector2(1040,330),Vector2(1210,330),Vector2(1310,500),Vector2(1460,600)]:
		if not await travel(point):
			break
	game._handle_interaction()
	print("CHAIR ",game.player.held," at ",game.player.position)
	Input.action_press("move_right")
	for index in range(160):
		if game.state!="playing" or game.player.position.x>1750:
			break
		await step()
	release()
	Input.action_press("jump")
	Input.action_press("move_right")
	await frames(35)
	release()
	await shot("chain")
	await travel(Vector2(2020,600))
	game._handle_interaction()
	for point in [Vector2(2400,488),Vector2(2680,600)]:
		if not await travel(point,480,true):
			break
	await tap("use_tool")
	await travel(Vector2(3450,600),480,true)
	await finish_route("骑椅连锁开路",false)

func finish_route(label: String, zero_damage: bool) -> void:
	if game.state=="playing" and game.world.goal_reachable(game.player.position):
		game._handle_interaction()
	var row: Dictionary = {"route":label,"state":game.state,"seconds":ticks/60.0,"teleport":teleported,"damage":game._damage_total,"accidents":game._accidents.duplicate(),"strategies":game.world.tactical_actions.duplicate(),"position":[game.player.position.x,game.player.position.y],"coupons":game._run_coupon_ids.size()}
	routes.append(row)
	check(label+"实际输入通关",game.state=="success" and not teleported,row)
	if zero_damage:
		check(label+"没有损坏物件",game._damage_total==0)
	else:
		check("连锁路线由滚桶撞散文件",game.world._announced.has("chain_mon_files") and game.world._damaged.has("mon_files") and game._stunts.get("chain_mon_files","")=="连锁事故：水桶开路")
	if game.world.tactical_actions.size()>=2:
		check(label+"组合奖章存档",game.state=="success" and game.save.level_record(1).medals[2])
	await frames(55)
	await shot("result_"+str(routes.size()))

func rules() -> void:
	await start()
	game.player.position=Vector2(280,600)
	previous=game.player.position
	await frames(8)
	await tap("use_tool")
	var officer=game.world.officers[0]
	check("定点：复印诱饵使人事转向声音",officer.state=="noise" and officer.noise_target.x==1140 and officer.noise_focus>0)
	var focus: float = officer.noise_focus
	game._open_pause()
	await frames(40)
	check("暂停冻结诱饵和门禁计时",is_equal_approx(officer.noise_focus,focus))
	game._resume_game()
	await start()
	game._handle_interaction()
	await tap("use_tool")
	check("F 踢出椅子后空手",game.player.held.is_empty() and bool(game.world._tools[0].get("launched",false)))
	await frames(50)
	check("椅子通过真实碰撞撞散纸箱",game.world._damaged.has("mon_box") and game.world._announced.has("chain_reaction"))
	await start()
	game.player.position=Vector2(2680,600)
	previous=game.player.position
	for officer_node in game.world.officers:
		officer_node.set_physics_process(false)
	await frames(190)
	check("定点：门禁预警后实体关闭",game.world._gate_closed)
	game.player.reset_at(Vector2(2990,600))
	previous=game.player.position
	Input.action_press("move_right")
	await frames(30)
	release()
	check("定点：关闭的门禁阻挡实际移动",game.player.position.x<3012)
	game.player.reset_at(Vector2(2680,600))
	previous=game.player.position
	await frames(8)
	await tap("use_tool")
	check("定点：按钮打开实体门禁",not game.world._gate_closed and game.world._gate_remaining>3.8)
	game.player.reset_at(Vector2(2990,600))
	previous=game.player.position
	Input.action_press("move_right")
	await frames(40)
	release()
	check("定点：开放的门禁允许实际移动",game.player.position.x>3070)
	game.player.reset_at(Vector2(3050,600))
	previous=game.player.position
	await frames(260)
	check("定点：占用门口时延迟关闭",not game.world._gate_closed and absf(game.player.position.x-3050)<2)
	game.player.reset_at(Vector2(2680,600))
	previous=game.player.position
	await frames(8)
	check("定点：放行结束重新关闭",game.world._gate_closed)
	game._restart_current()
	check("重开清空门禁诱饵和组合",not game.world._gate_started and game.world.tactical_actions.is_empty() and game.world._noise_pulses.is_empty())
	await table_and_water()
	game._open_album()
	await shot("album")
	check("图鉴可以打开",game.ui.current_screen=="album")

func table_and_water() -> void:
	await start()
	for officer_node in game.world.officers:
		officer_node.set_physics_process(false)
	game.player.reset_at(Vector2(2210,600))
	previous=game.player.position
	await frames(8)
	var original_x: float = game.world.table.position.x
	Input.action_press("move_right")
	await frames(70)
	release()
	await frames(80)
	check("定点：新布局可以用实际输入推桌",game.world.table.position.x-original_x>40 and game.world.table.position.x<2561)
	await shot("table")
	game.player.reset_at(Vector2(2890,600))
	previous=game.player.position
	var officer=game.world.officers[1]
	officer.position=game.world.table.position-Vector2(240,0)
	officer.velocity=Vector2.ZERO
	officer.state="chase"
	officer.last_seen=game.player.position
	officer.memory=4.5
	officer.set_physics_process(true)
	await frames(25)
	check("定点：推桌实际挡住追赶并计入组合",game.world.tactical_actions.has("table_block"))
	await start()
	for officer_node in game.world.officers:
		officer_node.set_physics_process(false)
	game.player.reset_at(Vector2(1460,600))
	previous=game.player.position
	await frames(8)
	game._handle_interaction()
	Input.action_press("move_right")
	await frames(80)
	release()
	check("定点：实际骑椅碰撞生成漏水",not game.world._water_spills.is_empty())
	game.player.reset_at(Vector2(1840,600))
	previous=game.player.position
	officer=game.world.officers[0]
	officer.position=Vector2(1740,600)
	officer.velocity=Vector2(390,0)
	officer.state="noise"
	officer.noise_target=Vector2(1730,600)
	officer.noise_time=3.0
	officer.memory=0
	officer.set_physics_process(true)
	await frames(10)
	check("定点：人事在实际漏水区转向打滑",officer.slip_remaining>0 and absf(officer.velocity.x)>250 and game._stunts.has("hr_skid"))
	await shot("water")

func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","")
	game.save=load("res://scripts/save_store.gd").new("res://verification/办公室临时改道_"+stamp+".json")
	game.save.data.settings.screen_shake=false
	game._apply_settings()
	if "--ui-only" in OS.get_cmdline_user_args():
		game._open_title()
		await shot("title")
		game._start_level(1,true)
		await shot("briefing")
		await start()
		await shot("opening")
		game.player.position=Vector2(2680,600)
		previous=game.player.position
		game.camera.reset_smoothing()
		await frames(8)
		await tap("use_tool")
		await frames(8)
		game._update_hud()
		await shot("gate")
		game._open_album()
		await shot("album")
		print("UI_PREVIEW_COMPLETE")
		game.queue_free()
		await process_frame
		quit()
		return
	await start()
	await shot("opening")
	await upper_route()
	await diversion_route()
	await chaos_route()
	await rules()
	var passed: bool = true
	for row in checks:
		passed=passed and bool(row.passed)
	var file:=FileAccess.open("res://verification/tactical_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"routes":routes,"method":"整局路线使用实际移动输入，保留人事和碰撞；定点规则检查单独标注。"},"\t"))
	file.close()
	release()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
