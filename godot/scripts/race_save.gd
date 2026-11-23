## Настройки и рекорды гонок — отдельный файл user://grimerka_race.json (сюжетное сохранение не трогается).
## Здесь же гоночные действия InputMap (race_*): создаются при запуске игры со значениями по умолчанию из
## RaceData.ACTIONS, клавиши можно переназначить в меню гонок (УПРАВЛЕНИЕ). Кампанию это не задевает.
class_name RaceSave

const PATH := "user://grimerka_race.json"
static var data := {}
static var loaded := false
static var persist := true        # проверки выключают запись (их гонки — не рекорды игрока)

static func _load() -> void:
	if loaded:
		return
	loaded = true
	data = {"steer": 1.0, "binds": {}, "records": {}, "level": "normal", "track": "tomsk_dust", "name": "ПАХАН", "weather": "random", "happen": true}
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			if typeof(d.get("steer")) in [TYPE_FLOAT, TYPE_INT]:
				data["steer"] = clampf(float(d["steer"]), 0.5, 1.5)
			if d.get("binds") is Dictionary:
				data["binds"] = d["binds"]
			if d.get("records") is Dictionary:
				data["records"] = d["records"]
			if RaceData.BOTS.has(String(d.get("level", ""))):
				data["level"] = String(d["level"])
			if RaceData.TRACKS.has(String(d.get("track", ""))):
				data["track"] = String(d["track"])
			if RaceWeather.WEATHER_ORDER.has(String(d.get("weather", ""))):
				data["weather"] = String(d["weather"])
			if typeof(d.get("happen")) == TYPE_BOOL:
				data["happen"] = bool(d["happen"])
			if d.get("name") is String and String(d["name"]).strip_edges() != "":
				data["name"] = String(d["name"]).substr(0, 16)

static func v(k: String):
	_load()
	return data.get(k)

static func put(k: String, val) -> void:
	_load()
	data[k] = val
	save()

static func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

## рекорд трассы: mode — "single" / "time" / "lap"; меньше — лучше. Возвращает true, если новый.
static func record(track: String, mode: String, t: float) -> bool:
	_load()
	var recs: Dictionary = data["records"]
	var xf: Dictionary = recs.get(track, {})
	var old := float(xf.get(mode, 0.0))
	if old > 0.0 and old <= t:
		return false
	xf[mode] = snappedf(t, 0.01)
	recs[track] = xf
	save()
	return true

static func best(track: String, mode: String) -> float:
	_load()
	return float((data["records"] as Dictionary).get(track, {}).get(mode, 0.0))

## гоночные действия: по умолчанию + переназначенные клавиши
static func setup_actions() -> void:
	_load()
	for a in RaceData.ACTIONS:
		var nm: String = a[0]
		if not InputMap.has_action(nm):
			InputMap.add_action(nm, 0.2)
		InputMap.action_erase_events(nm)
		var keys: Array = a[2]
		var bound = (data["binds"] as Dictionary).get(nm)
		if bound is Array and not (bound as Array).is_empty():
			keys = bound
		for k in keys:
			var e := InputEventKey.new()
			@warning_ignore("int_as_enum_without_cast")
			e.physical_keycode = int(k)
			InputMap.action_add_event(nm, e)
		for mb in a[3]:
			var m := InputEventMouseButton.new()
			m.button_index = mb
			InputMap.action_add_event(nm, m)
		for jb in a[4]:
			var j := InputEventJoypadButton.new()
			j.button_index = jb
			InputMap.action_add_event(nm, j)
	# стик геймпада — руль
	for side in [["race_left", -1.0], ["race_right", 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = side[1]
		InputMap.action_add_event(side[0], jm)

## клавиши действия (для подписей)
static func keys_of(action: String) -> Array:
	var r: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			r.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
		elif e is InputEventMouseButton:
			r.append({MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ"}.get((e as InputEventMouseButton).button_index, "мышь"))
	return r

## переназначить: клавиша key — действию action. Если она была у другого гоночного действия — меняются местами.
static func rebind(action: String, key: int) -> String:
	_load()
	var binds: Dictionary = data["binds"]
	var cur := {}
	for a in RaceData.ACTIONS:
		var nm: String = a[0]
		cur[nm] = binds.get(nm, a[2]).duplicate()
	var swapped := ""
	for nm in cur:
		if nm != action and (cur[nm] as Array).has(key):
			(cur[nm] as Array).erase(key)
			(cur[nm] as Array).append_array((cur[action] as Array).slice(0, 1))
			swapped = nm
	cur[action] = [key]
	data["binds"] = cur
	save()
	setup_actions()
	return swapped

static func reset_binds() -> void:
	_load()
	data["binds"] = {}
	save()
	setup_actions()
