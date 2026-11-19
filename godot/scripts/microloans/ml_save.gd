## Сохранение «ПАХАН НАБРАЛ МИКРОЗАЙМОВ»: user://microloans_save.json — своя валюта и свой прогресс
## (сюжетное grimerka_save.json не трогается). Версия схемы SCHEMA; перед записью прошлый файл копируется
## в .bak; файл повреждён — берётся .bak, нет и его — новая игра. Пишется атомарно: .tmp → замена.
## Сверху — «зал славы»: открытые концовки и лучшие итоги переживают новую игру.
class_name MLSave

const PATH := "user://microloans_save.json"
const SCHEMA := 1
static var persist := true

static func has_run() -> bool:
	var d := _read(PATH)
	if d.is_empty():
		d = _read(PATH + ".bak")
	return d.has("run") and String((d["run"] as Dictionary).get("ending", "")) == ""

static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary) or int((d as Dictionary).get("schema", 0)) != SCHEMA:
		return {}
	return d

## всё сохранение (с откатом на резервную копию)
static func load_all() -> Dictionary:
	var d := _read(PATH)
	if d.is_empty() and FileAccess.file_exists(PATH):
		push_warning("microloans: сохранение повреждено — беру резервную копию")
		d = _read(PATH + ".bak")
	if d.is_empty():
		d = {"schema": SCHEMA, "endings": {}, "best": {}}
	return d

static func save_run(econ: MLEconomy) -> void:
	var d := load_all()
	d["run"] = econ.to_dict()
	_write(d)

static func record_ending(econ: MLEconomy) -> void:
	var d := load_all()
	var e: Dictionary = d.get("endings", {})
	e[econ.ending] = int(e.get(econ.ending, 0)) + 1
	d["endings"] = e
	var best: Dictionary = d.get("best", {})
	if econ.ending != "pit":
		best["fastest_day"] = mini(int(best.get("fastest_day", 99)), econ.day)
	best["max_money"] = maxi(int(best.get("max_money", 0)), econ.money)
	d["best"] = best
	d["run"] = econ.to_dict()
	_write(d)

static func load_run(econ: MLEconomy) -> bool:
	var d := load_all()
	if not d.has("run"):
		return false
	econ.from_dict(d["run"])
	return true

static func _write(d: Dictionary) -> void:
	if not persist:
		return
	d["schema"] = SCHEMA
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bak"))
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH))
