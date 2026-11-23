extends RefCounted

const KIND := "controlled_balance_lab"
const SCHEMA := 1
const METRICS := ["damage", "dps", "hits", "targets_hit", "stagger_requested", "damage_taken",
	"team_hp_remaining", "knockouts", "combo_damage", "combo_seconds", "bottles_spent",
	"peak_heat", "peak_rhythm", "peak_flow", "peak_skate_charges", "hype_net_spent"]

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("kind") != KIND or value.get("schema") != SCHEMA or not value.get("valid", true) or not value.get("summary") is Dictionary:
		return {}
	var profile = value.get("experimental_profile", {})
	if not profile is Dictionary:
		return {}
	for key in ["hp", "damage", "cooldown"]:
		if typeof(profile.get(key, 1)) not in [TYPE_INT, TYPE_FLOAT] or not (float(profile.get(key, 1)) >= 0.5 and float(profile.get(key, 1)) <= 2.0):
			return {}
	for group in value.summary.values():
		if not group is Dictionary or not group.get("setups") is Array or not group.get("metrics") is Dictionary:
			return {}
		for setup in group.setups:
			if not setup is Dictionary or not setup.has("player_damage_scale") or not setup.get("targets") is Array:
				return {}
			for target in setup.targets:
				if not target is Dictionary or not target.has("initial_hp"):
					return {}
		for metric in group.metrics.values():
			if not metric is Dictionary or not metric.has("n") or not metric.has("mean"):
				return {}
	return value

static func summarize(samples: Array) -> Dictionary:
	var groups := {}
	for sample in samples:
		var key: String = sample["scenario"] + "/" + sample["setup"]["style"]
		if not groups.has(key):
			groups[key] = {"scenario": sample["scenario"], "setups": [], "metrics": {}}
		groups[key]["setups"].append(sample["setup"])
		for metric in METRICS:
			var value = sample["metrics"].get(metric)
			if value == null:
				continue
			if not groups[key]["metrics"].has(metric):
				groups[key]["metrics"][metric] = []
			groups[key]["metrics"][metric].append(float(value))
	for group in groups.values():
		var values: Dictionary = group["metrics"]
		for metric in values.keys():
			values[metric] = _distribution(values[metric])
		group["sample_count"] = group["setups"].size()
	return groups

static func _distribution(values: Array) -> Dictionary:
	var total := 0.0
	for value in values:
		total += float(value)
	var mean := total / values.size()
	var squared := 0.0
	for value in values:
		squared += (float(value) - mean) ** 2
	return {"n": values.size(), "mean": mean, "min": values.min(), "max": values.max(),
		"sample_sd": sqrt(squared / (values.size() - 1)) if values.size() > 1 else (null as Variant)}

static func _matched_setups(group: Dictionary, profile: Dictionary) -> String:
	var setups: Array = group.get("setups", []).duplicate(true)
	for setup in setups:
		setup.erase("cooldown_scale")
		setup.player_damage_scale = snappedf(float(setup.player_damage_scale) / float(profile.get("damage", 1.0)), 0.000001)
		for target in setup.targets:
			target.initial_hp = snappedf(float(target.initial_hp) / float(profile.get("hp", 1.0)), 0.000001)
	# Loaded JSON numbers are floats; freshly measured ticks and seed are integers.
	return JSON.stringify(JSON.parse_string(JSON.stringify(setups)))

static func compare(previous: Dictionary, current: Dictionary) -> Array:
	var differences: Array = []
	for key in current["summary"]:
		var new: Dictionary = current["summary"][key]
		var old = previous["summary"].get(key)
		var reason := ""
		if old == null:
			reason = "Сценарий отсутствует в базовом отчёте"
		elif _matched_setups(old, previous.get("experimental_profile", {})) != _matched_setups(new, current.get("experimental_profile", {})):
			reason = "Различаются исходные условия или seed"
		for metric in new["metrics"]:
			var cur: Dictionary = new["metrics"][metric]
			var base = old["metrics"].get(metric) if old != null else null
			var delta = null
			var percent = null
			var note := reason
			if reason == "" and base != null:
				delta = float(cur["mean"]) - float(base["mean"])
				if not is_zero_approx(float(base["mean"])):
					percent = 100.0 * delta / absf(float(base["mean"]))
				note = _hint(metric, delta, old["metrics"], new["metrics"])
			elif note == "":
				note = "Метрика отсутствует в базовом отчёте"
			differences.append({"scenario_style": key, "metric": metric, "baseline": base, "current": cur,
				"delta": delta, "percent": percent, "note": note})
	for key in previous["summary"]:
		if not current["summary"].has(key):
			differences.append({"scenario_style": key, "metric": "", "baseline": null, "current": null,
				"delta": null, "percent": null, "note": "Сценарий отсутствует в новом отчёте"})
	return differences

static func _hint(metric: String, delta: float, old: Dictionary, new: Dictionary) -> String:
	if is_zero_approx(delta):
		return "Среднее совпало; проверьте разброс"
	if metric in ["dps", "damage", "combo_damage"] and old.has("hits") and new.has("hits") and old["hits"]["mean"] != new["hits"]["mean"]:
		return "Изменилось число попаданий; проверьте дистанцию, выбор цели и окна атак"
	if metric in ["damage_taken", "knockouts", "team_hp_remaining"]:
		return "Проверьте входящие попадания, блок и длительность боя"
	return "Проверьте журналы приёмов, длительность и расход ресурсов; причинность не установлена"

static func export(out: String, name: String, payload: Dictionary, rows: Array) -> bool:
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		return false
	var json := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
	var csv := FileAccess.open(out.path_join(name + ".csv"), FileAccess.WRITE)
	if json == null or csv == null:
		return false
	var ok := json.store_string(JSON.stringify(payload, "\t"))
	ok = csv.store_csv_line(PackedStringArray(["kind", "scenario_style", "metric", "n", "mean", "min",
		"max", "sample_sd", "baseline_n", "baseline_mean", "delta", "percent", "note"])) and ok
	for row in rows:
		var values: Dictionary = row["current"] if row["current"] != null else {}
		var baseline: Dictionary = row["baseline"] if row["baseline"] != null else {}
		var cells := PackedStringArray([KIND, row["scenario_style"], row["metric"]])
		for v in [values.get("n"), values.get("mean"), values.get("min"), values.get("max"), values.get("sample_sd"),
			baseline.get("n"), baseline.get("mean"), row["delta"], row["percent"], row["note"]]:
			cells.append("" if v == null else str(v))
		ok = csv.store_csv_line(cells) and ok
	json.close()
	csv.close()
	return ok
