extends RefCounted

const PATH := "user://survival_records.json"
const HISTORY_LIMIT := 10
const Mods := preload("res://scripts/survival_modifiers.gd")

static func _number(value: Variant, limit: float) -> float:
	if not (value is float or value is int):
		return 0.0
	return clampf(float(value), 0.0, limit) if is_finite(float(value)) else 0.0

static func _run(data: Dictionary) -> Dictionary:
	var upgrades := {}
	var raw = data.get("upgrades")
	if raw is Dictionary:
		for id in Mods.CARDS:
			var amount := int(_number(raw.get(id), Mods.CARDS[id][3]))
			if amount > 0:
				upgrades[id] = amount
	return {"time": _number(data.get("time"), 1.0e12),
		"kills": int(_number(data.get("kills"), 1.0e12)),
		"threat": _number(data.get("threat"), 1.0),
		"bosses": int(_number(data.get("bosses"), 1.0e12)),
		"events": int(_number(data.get("events"), 1.0e12)), "upgrades": upgrades}

static func read(path := PATH) -> Dictionary:
	var data := {}
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			data = json.data
	var last = data.get("last_run")
	var history: Array = []
	var saved = data.get("history")
	if saved is Array:
		for i in mini(saved.size(), HISTORY_LIMIT):
			if saved[i] is Dictionary:
				history.append(_run(saved[i]))
	if history.is_empty() and last is Dictionary and not last.is_empty():
		history.append(_run(last))
	return {"best_time": _number(data.get("best_time"), 1.0e12),
		"best_kills": int(_number(data.get("best_kills"), 1.0e12)),
		"completed_runs": int(_number(data.get("completed_runs"), 1.0e12)),
		"last_run": _run(last) if last is Dictionary else {}, "history": history}

static func record(seconds: float, kills: int, threat: float, path := PATH, extra := {}) -> Dictionary:
	var data := read(path)
	var fields := {"time": seconds, "kills": kills, "threat": threat}
	fields.merge(extra)
	var last := _run(fields)
	data["best_time"] = maxf(data["best_time"], last["time"])
	data["best_kills"] = maxi(data["best_kills"], last["kills"])
	data["completed_runs"] += 1
	data["last_run"] = last
	data["history"].push_front(last)
	data["history"].resize(mini(HISTORY_LIMIT, data["history"].size()))
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open Survival records for writing")
	else:
		var written := file.store_string(JSON.stringify(data))
		file.close()
		if not written or DirAccess.rename_absolute(temp, path) != OK:
			push_warning("Could not save Survival records")
	return data

static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]
