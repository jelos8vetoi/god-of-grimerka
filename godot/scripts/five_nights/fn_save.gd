## Сохранение «5 НОЧЕЙ С ПАХАНОМ»: user://five_nights_save.json — своё, сюжетное grimerka_save.json не трогается.
## Пройденные и открытые ночи, Night 6 и Custom Night, свои наборы Custom Night, найденные секреты и записки,
## открытые концовки, статистика (смерти по врагам, ночи, лучшие остатки энергии), настройки (сила эффектов).
## Версия схемы, резервная копия .bak, атомарная запись (.tmp → замена). Проверки пишут, только если persist.
class_name FNSave

const PATH := "user://five_nights_save.json"
const SCHEMA := 1
static var persist := true
static var data := {}
static var loaded := false

static func defaults() -> Dictionary:
	return {"schema": SCHEMA, "unlocked": 1, "beaten": [], "night6": false, "custom": false, "current": 0,
		"levels": {"balon": 5, "madk1d": 5, "bot": 5, "clipper": 5, "ghost": 5, "mod": 5}, "presets": {},
		"secrets": [], "endings": [], "notes": ["rules"],
		"stats": {"deaths": {}, "wins": 0, "played": 0, "best_power": {}, "custom_best": 0},
		"settings": {"fx": 1.0}}

static func load_all() -> Dictionary:
	if loaded:
		return data
	loaded = true
	data = defaults()
	for p in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var jp := JSON.new()      # повреждённый файл — не ошибка в журнале, берём резервную копию
		var d = jp.data if jp.parse(FileAccess.get_file_as_string(p)) == OK else null
		if d is Dictionary and int(d.get("schema", 0)) >= 1:
			_merge(d)
			return data
	return data

static func _merge(d: Dictionary) -> void:
	var def := defaults()
	for k in def:
		if not d.has(k):
			continue
		# числа из JSON — дробные: целое поле принимает и их (иначе открытые ночи терялись бы)
		if typeof(d[k]) == typeof(def[k]) or (typeof(def[k]) == TYPE_INT and typeof(d[k]) == TYPE_FLOAT):
			data[k] = d[k]
	data["unlocked"] = clampi(int(data["unlocked"]), 1, 5)
	data["current"] = clampi(int(data["current"]), 0, 4)
	# JSON отдаёт числа дробными: [0.0].has(0) — ложь, поэтому пройденные ночи — снова целые
	data["beaten"] = (data["beaten"] as Array).map(func(x): return int(x))
	for k in def["levels"]:
		data["levels"][k] = clampi(int(data["levels"].get(k, 5)), 0, 20)
	for k in def["stats"]:
		if not (data["stats"] as Dictionary).has(k):
			data["stats"][k] = def["stats"][k]

static func save() -> void:
	if not persist:
		return
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bak"))
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))

static func v(k: String):
	return load_all()[k]

static func put(k: String, val) -> void:
	load_all()[k] = val
	save()

## ночь пройдена: открыть следующую, Night 6 после пятой, Custom Night после шестой
static func beat(n: int, power: float) -> void:
	var d := load_all()
	if not (d["beaten"] as Array).has(n):
		(d["beaten"] as Array).append(n)
	if n < 4:
		d["unlocked"] = maxi(int(d["unlocked"]), n + 2)
		d["current"] = n + 1
	if n == 4:
		d["night6"] = true
		_ending("night5")
	if n == 5:
		d["custom"] = true
		_ending("night6")
	d["stats"]["wins"] = int(d["stats"]["wins"]) + 1
	var bp: Dictionary = d["stats"]["best_power"]
	bp[str(n)] = maxf(float(bp.get(str(n), 0.0)), power)
	save()

static func died(killer: String) -> void:
	var dd: Dictionary = load_all()["stats"]["deaths"]
	dd[killer] = int(dd.get(killer, 0)) + 1
	save()

static func played() -> void:
	load_all()["stats"]["played"] = int(data["stats"]["played"]) + 1
	save()

static func _ending(id: String) -> void:
	if not (data["endings"] as Array).has(id):
		(data["endings"] as Array).append(id)

static func ending(id: String) -> void:
	load_all()
	_ending(id)
	save()

static func secret(id: String) -> bool:
	var s: Array = load_all()["secrets"]
	if s.has(id):
		return false
	s.append(id)
	if FNData.NOTES.has(id) and not (data["notes"] as Array).has(id):
		(data["notes"] as Array).append(id)
	save()
	return true

static func note(id: String) -> void:
	var n: Array = load_all()["notes"]
	if not n.has(id):
		n.append(id)
		save()
