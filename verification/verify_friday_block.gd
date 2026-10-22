extends SceneTree

var game: Node2D
var checks: Array = []

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func release() -> void:
	for action in ["move_left","move_right","jump","dash","brake"]:
		Input.action_release(action)

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/friday_"+label+".png")

func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stamp: String = Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","")
	game.save=load("res://scripts/save_store.gd").new("res://verification/周五饮水机通道_"+stamp+".json")
	game.save.data.settings.screen_shake=false
	game._start_level(5,false)
	for officer in game.world.officers:
		officer.set_physics_process(false)
	game.player.position=Vector2(3116,600)
	await frames(8)
	Input.action_press("move_right")
	Input.action_press("jump")
	var highest: float = 600
	for i in range(65):
		await physics_frame
		highest=minf(highest,game.player.position.y)
	release()
	print("FULL_JUMP "+JSON.stringify({"height":600-highest,"machine_height":178,"x":game.player.position.x}))
	if "--baseline" in OS.get_cmdline_user_args():
		await shot("blocked_before")
		game.player.simulation_enabled=false
		for officer in game.world.officers:
			officer.set_physics_process(true)
		await frames(150)
		for officer in game.world.officers:
			print("PATROL "+str(officer.position)+" "+str(officer.velocity))
		quit()
		return
	check("地面跳跃不能凭空跨越高机器",game.player.position.x<3140 and 600-highest<178)
	Input.action_press("move_left")
	Input.action_press("jump")
	for i in range(80):
		await physics_frame
		if game.player.position.x<3050:
			Input.action_release("move_left")
			Input.action_press("brake")
		if game.player.is_on_floor() and absf(game.player.position.y-520)<3:
			break
	release()
	Input.action_press("brake")
	await frames(8)
	release()
	Input.action_press("move_right")
	var jump_ticks: int = 0
	var last: Vector2 = game.player.position
	var teleported: bool = false
	var crossed: bool = false
	var captured: bool = false
	for i in range(700):
		if jump_ticks>0:
			jump_ticks-=1
			if jump_ticks==0:
				Input.action_release("jump")
				jump_ticks=-3
		elif jump_ticks<0:
			jump_ticks+=1
		elif game.player.is_on_floor():
			Input.action_press("jump")
			jump_ticks=35
		await physics_frame
		teleported=teleported or last.distance_to(game.player.position)>25
		last=game.player.position
		if not captured and game.player.position.x>3160 and game.player.position.y<400:
			await shot("service_walkway")
			captured=true
		if game.player.position.x>3500:
			crossed=true
			break
	release()
	check("从截图堵点跳上踏台后只用走跳绕过饮水机",crossed and not teleported,game.player.position)
	check("绕行不会损坏饮水机",not game.world._damaged.has("fri_cooler_1"))
	game._start_level(5,false)
	await frames(8)
	game.player.simulation_enabled=false
	var patrol=game.world.officers[0]
	check("人事生成时站在支撑面上",absf(patrol.position.y-490)<3,patrol.position)
	patrol.position=Vector2(3120,600)
	patrol.patrol_left=3000
	patrol.patrol_right=3350
	patrol.facing=1
	patrol.avoid_seconds=0
	patrol.detour.clear()
	patrol.velocity=Vector2.ZERO
	var moved_left: bool = false
	for i in range(150):
		await physics_frame
		moved_left=moved_left or patrol.position.x<3080
	check("巡查遇到高机器会转向继续走",moved_left,patrol.position)
	patrol.position=Vector2(3110,600)
	patrol.state="chase"
	patrol.memory=4.5
	patrol.last_seen=Vector2(3700,490)
	patrol.facing=1
	patrol.avoid_seconds=0
	patrol.detour.clear()
	patrol.velocity=Vector2.ZERO
	game.player.position=Vector2(3700,490)
	game.player._started_once=true
	var reached: bool = false
	for i in range(800):
		await physics_frame
		if "--trace" in OS.get_cmdline_user_args() and i%30==0:
			print("HR_TRACE ",i," ",patrol.position," ",patrol.velocity," ",patrol.state," ",patrol.detour," ",patrol.avoid_seconds)
		if patrol.position.x>3400:
			reached=true
			break
	check("追赶遇到饮水机会沿实体踏台绕行",reached and patrol.position.y<=600,patrol.position)
	await shot("hr_detour")
	game._start_level(5,false)
	await frames(8)
	game.player.simulation_enabled=false
	patrol=game.world.officers[0]
	patrol.position=Vector2(3260,600)
	patrol.velocity=Vector2.ZERO
	patrol.state="chase"
	patrol.memory=4.5
	patrol.last_seen=Vector2(2900,600)
	patrol.facing=-1
	game.player.position=Vector2(2900,600)
	game.player._started_once=true
	reached=false
	for i in range(800):
		await physics_frame
		if "--trace" in OS.get_cmdline_user_args() and i%60==0:
			print("HR_REVERSE ",i," ",patrol.position," ",patrol.velocity," ",patrol.detour)
		if patrol.position.x<3030:
			reached=true
			break
	check("饮水机右侧的人事也能反向绕行脱困",reached and patrol.position.y<=600,patrol.position)
	game._start_level(5,false)
	await frames(8)
	game.player.simulation_enabled=false
	patrol=game.world.officers[0]
	var held_x: float = patrol.position.x
	patrol.detour=[Vector2(held_x,200)]
	patrol.detour_age=0
	await frames(300)
	check("定点：不可达绕行点超时后恢复移动",patrol.detour.is_empty() and absf(patrol.position.x-held_x)>20,patrol.position)
	for level_index in range(6):
		game._start_level(level_index,false)
		await frames(8)
		game.player.simulation_enabled=false
		var spans: Array = []
		for officer in game.world.officers:
			spans.append({"min":officer.position.x,"max":officer.position.x,"embedded":false})
		for i in range(300):
			await physics_frame
			for j in range(game.world.officers.size()):
				var officer=game.world.officers[j]
				spans[j].min=minf(spans[j].min,officer.position.x)
				spans[j].max=maxf(spans[j].max,officer.position.x)
				spans[j].embedded=spans[j].embedded or officer.position.y>602
		for j in range(spans.size()):
			var span: Dictionary = spans[j]
			check("关卡%d人事%d持续巡查且未陷进地面"%[level_index,j],span.max-span.min>40 and not span.embedded,span)
	var passed: bool = true
	for row in checks:
		passed=passed and bool(row.passed)
	var file:=FileAccess.open("res://verification/friday_block_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"定点复现截图位置后用真实输入绕行；人事巡查与绕行规则使用独立状态设置。"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
