class_name OfficeSave
extends RefCounted

const PATH: String = "user://progress.json"
var save_path: String = PATH
var data: Dictionary = {}

func _init(save_path: String = PATH) -> void:
	self.save_path = PATH if save_path.is_empty() else save_path
	data = defaults()
	load_progress()

func defaults() -> Dictionary:
	return {"version": 2, "unlocked": 1, "tutorial_done": false, "badge": 0,
		"rocket_unlocked": false, "spring_unlocked": false,
		"monday_revision": 4,
		"week_complete": false, "last_completed": -1, "levels": {},
		"settings": {"music_volume": 0.55, "sound_volume": 0.8, "screen_shake": true,
			"assist": false, "fullscreen": false}}

func load_progress() -> void:
	var loaded: Variant = null
	if FileAccess.file_exists(save_path):
		loaded = _read_json(save_path)
		if not loaded is Dictionary:
			_preserve_broken_file(save_path)
			loaded = _read_json(save_path + ".bak")
	else:
		loaded = _read_json(save_path + ".bak")
	if not loaded is Dictionary:
		return
	var default_data: Dictionary = defaults()
	for key in default_data.keys():
		var loaded_value: Variant = loaded.get(key, default_data[key])
		var default_value: Variant = default_data[key]
		if typeof(default_value) == TYPE_INT:
			data[key] = _safe_integer(loaded_value, int(default_value))
		elif typeof(default_value) == TYPE_FLOAT:
			data[key] = _safe_float(loaded_value, float(default_value))
		elif typeof(loaded_value) == typeof(default_value):
			data[key] = loaded_value
	data["unlocked"] = clampi(int(data["unlocked"]), 1, 5)
	data["last_completed"] = clampi(int(data["last_completed"]), -1, 5)
	_sanitize_settings()
	_sanitize_levels()
	if _safe_integer(loaded.get("monday_revision",0),0) < 4 and data.levels.has("1"):
		var monday: Dictionary = data.levels["1"]
		monday["normal_best"] = 0.0
		monday["assist_best"] = 0.0
		monday["medals"] = [bool(monday.medals[0]),false,false]
		monday["normal_chaos"] = 0
		monday["assist_chaos"] = 0
		for obsolete in ["paper_bridge","chair_drift","rocket_chair","bucket_launch","meeting_board","meeting_clock","meeting_delivery","drawer_steps"]:
			monday.discoveries.erase(obsolete)
	data["monday_revision"] = 4
	data["badge"] = clampi(int(data["badge"]), 0, unlocked_badges())
	if bool(data["week_complete"]) or int(data["last_completed"]) == 5:
		data["week_complete"] = true
		data["unlocked"] = 5
		data["last_completed"] = 5


func _preserve_broken_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var broken_uri: String = path + ".broken"
	if FileAccess.file_exists(broken_uri):
		var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		broken_uri += "-" + stamp
	var source_path: String = ProjectSettings.globalize_path(path)
	var destination_path: String = ProjectSettings.globalize_path(broken_uri)
	DirAccess.copy_absolute(source_path, destination_path)


func _sanitize_settings() -> void:
	var base_settings: Dictionary = defaults()["settings"]
	var loaded_settings: Variant = data.get("settings", {})
	var settings: Dictionary = base_settings.duplicate(true)
	var legacy_keys: Dictionary = {"music_volume": "music", "sound_volume": "sound", "screen_shake": "shake"}
	if loaded_settings is Dictionary:
		for key in base_settings.keys():
			var source_key: String = str(key)
			if not loaded_settings.has(source_key) and legacy_keys.has(source_key):
				source_key = str(legacy_keys[source_key])
			var value: Variant = loaded_settings.get(source_key, base_settings[key])
			if typeof(base_settings[key]) == TYPE_FLOAT:
				settings[key] = _safe_float(value, float(base_settings[key]))
			elif typeof(value) == typeof(base_settings[key]):
				settings[key] = value
	settings["music_volume"] = clampf(float(settings["music_volume"]), 0.0, 1.0)
	settings["sound_volume"] = clampf(float(settings["sound_volume"]), 0.0, 1.0)
	data["settings"] = settings


func _sanitize_levels() -> void:
	var loaded_levels: Variant = data.get("levels", {})
	var levels: Dictionary = {}
	if loaded_levels is Dictionary:
		for level_index in range(1, 6):
			var key: String = str(level_index)
			if loaded_levels.has(key):
				levels[key] = _sanitize_record(loaded_levels[key])
	data["levels"] = levels


func _default_level_record() -> Dictionary:
	return {"medals": [false, false, false], "coupons": [], "normal_best": 0.0, "assist_best": 0.0,
		"normal_chaos": 0, "assist_chaos": 0, "discoveries": {}}


func _sanitize_record(raw_record: Variant) -> Dictionary:
	var record: Dictionary = _default_level_record()
	if not raw_record is Dictionary:
		return record
	var medals: Array = [false, false, false]
	var loaded_medals: Variant = raw_record.get("medals", [])
	if loaded_medals is Array:
		for medal_index in range(mini(3, loaded_medals.size())):
			if typeof(loaded_medals[medal_index]) == TYPE_BOOL:
				medals[medal_index] = loaded_medals[medal_index]
	var coupons: Array = []
	var loaded_coupons: Variant = raw_record.get("coupons", [])
	if loaded_coupons is Array:
		for coupon_value in loaded_coupons:
			var coupon_id: int = _safe_integer(coupon_value, -1)
			if coupon_id >= 0 and coupon_id <= 2 and not coupons.has(coupon_id):
				coupons.append(coupon_id)
	var normal_best: float = _safe_best_time(raw_record.get("normal_best", 0.0))
	var assist_best: float = _safe_best_time(raw_record.get("assist_best", 0.0))
	record["medals"] = medals
	record["coupons"] = coupons
	record["normal_best"] = normal_best
	record["assist_best"] = assist_best
	for key in ["normal_chaos", "assist_chaos"]:
		record[key] = clampi(_safe_integer(raw_record.get(key,0),0),0,1000000)
	var discoveries: Variant = raw_record.get("discoveries",{})
	if discoveries is Dictionary:
		for id in discoveries.keys():
			if id is String and discoveries[id] is String and str(id).length()<=80 and str(discoveries[id]).length()<=100 and record["discoveries"].size()<64:
				record["discoveries"][id] = discoveries[id]
	return record


func _safe_best_time(value: Variant) -> float:
	var elapsed: float = _safe_float(value, -1.0)
	if elapsed < 0.0 or elapsed > 3600.0:
		return 0.0
	return elapsed


func _safe_float(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var numeric: float = float(value)
	if numeric != numeric or numeric < -1000000.0 or numeric > 1000000.0:
		return fallback
	return numeric


func _safe_integer(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) != TYPE_FLOAT:
		return fallback
	var numeric: float = float(value)
	if numeric != numeric or numeric < -2147483648.0 or numeric > 2147483647.0 or floorf(numeric) != numeric:
		return fallback
	return int(numeric)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return null
	return parser.data

func save() -> bool:
	if FileAccess.file_exists(save_path):
		var existing: Variant = _read_json(save_path)
		if existing is Dictionary:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
		else:
			_preserve_broken_file(save_path)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("到岗记录暂时无法保存：" + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var save_error: Error = file.get_error()
	file.close()
	if save_error != OK:
		push_warning("到岗记录暂时无法保存：" + error_string(save_error))
		return false
	if not FileAccess.file_exists(save_path + ".bak"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
	return true

func level_record(index: int) -> Dictionary:
	if index < 1 or index > 5:
		return _default_level_record()
	if not data.get("levels", {}) is Dictionary:
		data["levels"] = {}
	var levels: Dictionary = data["levels"]
	var key: String = str(index)
	if not levels.has(key):
		levels[key] = _default_level_record()
	else:
		levels[key] = _sanitize_record(levels[key])
	return levels[key]

func record_success(index: int, elapsed: float, medals: Array, coupons: Array, assist: bool, chaos: int = 0) -> void:
	if index == 0:
		data["tutorial_done"] = true
		data["last_completed"] = 0
		save()
		return
	if index < 1 or index > 5:
		return
	var record: Dictionary = level_record(index)
	var chaos_key: String = "assist_chaos" if assist else "normal_chaos"
	record[chaos_key] = maxi(int(record.get(chaos_key,0)), clampi(chaos,0,1000000))
	var stored_medals: Array = record["medals"]
	for i in range(3):
		var earned: bool = i < medals.size() and bool(medals[i])
		stored_medals[i] = bool(stored_medals[i]) or earned
	var stored_coupons: Array = record["coupons"]
	for coupon_value in coupons:
		var coupon_id: int = _safe_integer(coupon_value, -1)
		if coupon_id >= 0 and coupon_id <= 2 and not stored_coupons.has(coupon_id):
			stored_coupons.append(coupon_id)
	var best_key: String = "assist_best" if assist else "normal_best"
	var current_best: float = float(record[best_key])
	var saved_elapsed: float = _safe_best_time(elapsed)
	if saved_elapsed > 0.0 and (current_best <= 0.0 or saved_elapsed < current_best):
		record[best_key] = saved_elapsed
	data["unlocked"] = mini(5, maxi(int(data["unlocked"]), index + 1))
	if index == 5:
		data["week_complete"] = true
	data["last_completed"] = index
	save()


func record_discovery(index: int, id: String, label: String) -> void:
	if index < 1 or index > 5 or id.is_empty():
		return
	var record: Dictionary = level_record(index)
	var discoveries: Dictionary = record.get("discoveries",{})
	if discoveries.has(id):
		return
	discoveries[id] = label
	record["discoveries"] = discoveries
	save()

func coupon_count() -> int:
	var total: int = 0
	for index in range(1, 6):
		total += level_record(index).coupons.size()
	return total

func unlocked_badges() -> int:
	var count: int = coupon_count()
	return 3 if count >= 15 else (2 if count >= 8 else (1 if count >= 3 else 0))

func next_level() -> int:
	if not bool(data.tutorial_done):
		return 0
	if bool(data.get("week_complete", false)):
		return -1
	return int(data.unlocked)
