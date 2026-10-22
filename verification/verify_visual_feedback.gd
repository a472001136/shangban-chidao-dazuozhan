extends SceneTree

var game: Node
var missing_frames: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var captures: int = 0
var previous_accidents: int = 0
var accident_frame: int = -100
var run_strip: Image = Image.create(800, 210, false, Image.FORMAT_RGBA8)
var run_frames: Array[int] = [20, 26, 32, 38]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save.data = game.save.defaults()
	game.save.data.settings.screen_shake = false
	game._apply_settings()
	game._start_level(1, true)
	game._begin_play()
	for frame in range(20):
		await physics_frame
	Input.action_press("move_right")
	var mounted: bool = false
	for frame in range(660):
		if not mounted and game.player.position.x >= 1135.0:
			Input.action_release("move_right")
			for settle in range(8):
				await physics_frame
			game.player.interact()
			mounted = game.player.held == "chair"
			Input.action_press("move_right")
		await physics_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var screen_origin: Vector2 = game.player.get_global_transform_with_canvas().origin
		if frame in run_frames:
			var source_rect: Rect2i = Rect2i(int(screen_origin.x) - 100, int(screen_origin.y) - 180, 200, 210)
			run_strip.blit_rect(image, source_rect, Vector2i(run_frames.find(frame) * 200, 0))
		var skin_pixels: int = 0
		for sy in range(maxi(0, int(screen_origin.y - 170.0)), mini(image.get_height(), int(screen_origin.y + 10.0)), 3):
			for sx in range(maxi(0, int(screen_origin.x - 85.0)), mini(image.get_width(), int(screen_origin.x + 85.0)), 3):
				var pixel: Color = image.get_pixel(sx, sy)
				if absf(pixel.r - 0.941) < 0.045 and absf(pixel.g - 0.745) < 0.045 and absf(pixel.b - 0.584) < 0.045:
					skin_pixels += 1
		if skin_pixels < 8:
			missing_frames.append({"frame": frame, "position": [game.player.position.x, game.player.position.y], "screen": [screen_origin.x, screen_origin.y], "skin_pixels": skin_pixels})
		var accident_count: int = game._accidents.size()
		if accident_count > previous_accidents:
			accident_frame = frame
			previous_accidents = accident_count
		if frame % 90 == 0 or frame - accident_frame in [0, 8, 24, 65]:
			var file_name: String = "visual_%03d.png" % captures
			image.save_png("res://verification/" + file_name)
			samples.append({"image": file_name, "frame": frame, "held": game.player.held, "skin_pixels": skin_pixels, "accidents": accident_count, "damage": game._damage_total})
			captures += 1
	Input.action_release("move_right")
	run_strip.save_png("res://verification/run_animation.png")
	var report: Dictionary = {"passed": missing_frames.is_empty(), "frames": 660, "missing_frames": missing_frames, "samples": samples, "mounted": mounted, "accidents": game._accidents.size(), "damage": game._damage_total}
	var output: FileAccess = FileAccess.open("res://verification/visual_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("VISUAL_REPORT " + JSON.stringify(report))
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit(0 if bool(report.passed) else 1)
