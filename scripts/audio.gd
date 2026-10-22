class_name OfficeAudio
extends Node

const RATE: int = 22050
var music: AudioStreamPlayer = null
var tool: AudioStreamPlayer = null
var effects: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var music_volume: float = 0.55
var sound_volume: float = 0.8
var current_tool: String = ""
var recent: Dictionary = {}
var clock: float = 0.0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.stream = _make_music()
	music.play()
	tool = AudioStreamPlayer.new()
	add_child(tool)
	for i in range(8):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		effects.append(voice)
	for kind in ["menu", "jump", "dash", "brake", "footstep", "land", "hit", "water", "paper", "glass", "coupon", "success", "fail", "warning", "chair", "spray", "bucket", "combo"]:
		sounds[kind] = _make_sound(kind)
	set_volumes(music_volume, sound_volume)

func _process(delta: float) -> void:
	clock += delta


func _exit_tree() -> void:
	for voice in effects:
		voice.stop()
		voice.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(tool):
		tool.stop()
		tool.stream = null
	sounds.clear()

func set_volumes(m: float, s: float) -> void:
	music_volume = clampf(m, 0.0, 1.0)
	sound_volume = clampf(s, 0.0, 1.0)
	if is_instance_valid(music):
		music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.48))
	if is_instance_valid(tool):
		tool.volume_db = linear_to_db(maxf(0.0001, sound_volume * 0.18))
	for voice in effects:
		voice.volume_db = linear_to_db(maxf(0.0001, sound_volume * 0.55))

func play(kind: String) -> void:
	if not sounds.has(kind):
		kind = "hit"
	var interval: float = 0.14 if kind in ["hit", "paper", "footstep", "land"] else (0.09 if kind in ["dash", "brake", "jump"] else 0.05)
	if clock - float(recent.get(kind, -100.0)) < interval:
		return
	recent[kind] = clock
	for voice in effects:
		if not voice.playing:
			voice.stream = sounds[kind]
			voice.pitch_scale = 1.0
			voice.play()
			return

func play_combo(count: int) -> void:
	if clock - float(recent.get("combo", -100.0)) < 0.06:
		return
	recent["combo"] = clock
	for voice in effects:
		if not voice.playing:
			voice.stream = sounds["combo"]
			voice.pitch_scale = 0.9 + mini(8, count) * 0.10
			voice.play()
			return


func set_phase(phase: String, remaining: float = 60.0) -> void:
	if not is_instance_valid(music):
		return
	if phase != "playing":
		stop_tool()
	music.stream_paused = phase == "pause"
	if phase == "playing" and remaining < 5.0:
		music.pitch_scale = 1.24
	elif phase == "playing" and remaining < 15.0:
		music.pitch_scale = 1.12
	elif phase in ["success", "failure"]:
		music.pitch_scale = 0.96
	else:
		music.pitch_scale = 1.0
	if phase in ["success", "failure"]:
		music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.18))
	else:
		music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.48))

func set_tool(kind: String, speed: float, spraying: bool, running: bool) -> void:
	if not is_instance_valid(tool):
		return
	var next = ""
	if running:
		if kind == "extinguisher" and spraying:
			next = "spray"
		elif kind in ["chair", "bucket"] and absf(speed) > 55.0:
			next = kind
	if next != current_tool:
		current_tool = next
		tool.stop()
		if not next.is_empty():
			tool.stream = sounds[next]
			tool.play()
	if not next.is_empty():
		tool.pitch_scale = clampf(0.8 + absf(speed) / 1200.0, 0.8, 1.55)


func stop_tool() -> void:
	current_tool = ""
	if is_instance_valid(tool):
		tool.stop()

func _stream(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -0.95, 0.95) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

func _make_music() -> AudioStreamWAV:
	var step = 0.24
	var melody = [72, 76, 79, 76, 74, 77, 81, 77, 72, 76, 79, 83, 81, 79, 76, 74,
		72, 72, 76, 79, 74, 74, 77, 81, 79, 76, 74, 71, 72, 76, 79, 72]
	var bass = [48, 53, 48, 55, 48, 53, 55, 48]
	var length = step * melody.size()
	var samples = PackedFloat32Array()
	samples.resize(int(RATE * length))
	for i in samples.size():
		var t = float(i) / RATE
		var beat = int(t / step)
		var age = fmod(t, step)
		var f = 440.0 * pow(2.0, (melody[beat % melody.size()] - 69.0) / 12.0)
		var envelope = exp(-age * 16.0) * minf(age * 170.0, 1.0)
		var tone = (sin(TAU * f * age) + 0.32 * sin(TAU * f * 2.0 * age)) * envelope * 0.22
		var bass_age = fmod(t, step * 4.0)
		var bass_index: int = int(beat / 4) % bass.size()
		var bf = 440.0 * pow(2.0, (bass[bass_index] - 69.0) / 12.0)
		tone += sin(TAU * bf * bass_age) * exp(-bass_age * 6.0) * minf(bass_age * 80.0, 1.0) * 0.15
		var tick = sin(TAU * 1600.0 * age) * exp(-age * 100.0) * 0.035
		samples[i] = tone + tick
	return _stream(samples, true)

func _make_sound(kind: String) -> AudioStreamWAV:
	var looped = kind in ["chair", "spray", "bucket"]
	var duration: float = 0.5 if looped else (0.75 if kind in ["success", "fail"] else (0.12 if kind == "footstep" else (0.15 if kind == "land" else (0.18 if kind == "brake" else 0.22))))
	var samples = PackedFloat32Array()
	samples.resize(int(RATE * duration))
	var rng = RandomNumberGenerator.new()
	rng.seed = 72024
	for i in samples.size():
		var t = float(i) / RATE
		var u = t / duration
		var envelope = 0.45 if looped else sin(PI * u) * exp(-u * 1.4)
		var f = 440.0
		var wave = 0.0
		match kind:
			"menu": f = 660.0; wave = sin(TAU * f * t)
			"jump": f = 240.0 + 580.0 * u; wave = sin(TAU * (240.0 * t + 290.0 * t * u))
			"dash": wave = sin(TAU * (165.0 - 35.0 * u) * t) * 0.38 + rng.randf_range(-0.18, 0.18)
			"hit": wave = sin(TAU * (150.0 - 70.0 * u) * t) * 0.5 + rng.randf_range(-0.16, 0.16)
			"water", "paper": wave = rng.randf_range(-0.65, 0.65) * (0.5 + 0.5 * sin(TAU * 20.0 * t))
			"spray": wave = sin(TAU * 920.0 * t) * 0.1 + sin(TAU * 1380.0 * t) * 0.08 + sin(TAU * 2140.0 * t) * 0.04
			"glass": wave = sin(TAU * 1900.0 * t) * 0.35 + sin(TAU * 2700.0 * t) * 0.25
			"coupon": wave = sin(TAU * (880.0 if u < 0.45 else 1320.0) * t)
			"combo": wave = sin(TAU * (523.25 if u < 0.35 else 783.99) * t) * 0.65 + sin(TAU * 1046.5 * t) * 0.22
			"success":
				var notes = [523.25, 659.25, 783.99, 1046.50]
				wave = sin(TAU * notes[mini(3, int(u * 4.0))] * t)
				envelope = 0.4 * (1.0 - u)
			"fail": wave = sin(TAU * (360.0 - 180.0 * u) * t)
			"warning": wave = sin(TAU * 280.0 * t) * (1.0 if fmod(t, 0.1) < 0.06 else 0.0)
			"footstep": wave = sin(TAU * (118.0 - 38.0 * u) * t) * 0.7 + rng.randf_range(-0.12, 0.12)
			"brake": wave = sin(TAU * (210.0 - 95.0 * u) * t) * 0.55 + rng.randf_range(-0.16, 0.16)
			"land": wave = sin(TAU * (65.0 - 16.0 * u) * t) * 0.45 + rng.randf_range(-0.05, 0.05)
			"chair": wave = sin(TAU * 84.0 * t) * 0.4 + sin(TAU * 168.0 * t) * 0.18
			"bucket": wave = sin(TAU * 56.0 * t) * 0.3 + sin(TAU * 168.0 * t) * 0.18 + sin(TAU * 8.0 * t) * 0.04
		var sample_gain: float = 0.16 if kind == "footstep" else (0.18 if kind == "land" else (0.22 if kind == "brake" else (0.28 if kind in ["dash", "hit"] else 0.4)))
		samples[i] = wave * envelope * sample_gain
	return _stream(samples, looped)
