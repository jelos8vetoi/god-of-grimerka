extends PanelContainer

const Reports := preload("res://scripts/balance_lab_report.gd")
const Analysis := preload("res://scripts/balance_analysis.gd")
const ROOT := "user://balance_lab"
const SECTIONS := ["Общая статистика", "Боевые стили", "Герои", "Командные механики", "Противники", "Боссы", "Улучшения", "Сравнение тестов", "Рекомендации по балансу"]
var runs: Array = []
var run := {}
var before := {}
var after := {}
var sources := ["", ""]
var picks := OptionButton.new()
var scenario := OptionButton.new()
var tabs := ItemList.new()
var content := RichTextLabel.new()
var status := Label.new()
var sliders := {}
var dialog := FileDialog.new()
var slot := 0
var job := -1
var job_dir := ""
var next_poll := 0
const LABELS := {"active_seconds": "Активное время, с", "created_utc": "Дата (UTC)", "outcome": "Исход", "enemy_hp_scale": "Множитель HP врагов", "unclassified_enemy_hp_lost": "Урон без атрибуции", "survival": "Результат забега", "kills": "Убийства", "events": "События", "bosses": "Боссы", "threat": "Угроза", "upgrades": "Карточки", "damage_taken": "Полученный урон", "damage_dealt": "Нанесённый урон", "style_seconds": "Время со стилем, с", "knockout_causes": "Причины выбывания", "phases": "Фазы", "abilities": "Способности", "fight_seconds": "Время боя, с", "hits": "Попадания", "uses": "Применения"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	var page := VBoxContainer.new()
	margin.add_child(page)
	var title = get_parent().label("BALANCE LAB  //  ИСПЫТАТЕЛЬНЫЙ СТЕНД", 28, Color.WHITE)
	page.add_child(title)
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(picks)
	picks.item_selected.connect(func(i): run = runs[i]; _refresh())
	_button(bar, "Базовый JSON", _browse.bind(0))
	_button(bar, "Новый JSON", _browse.bind(1))
	_button(bar, "Экспорт предложения", _export)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	tabs.custom_minimum_size.x = 260
	split.add_child(tabs)
	for section in SECTIONS:
		tabs.add_item(section)
	tabs.item_selected.connect(func(_i): _refresh())
	tabs.select(0)
	content.selection_enabled = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(content)
	var controls := HBoxContainer.new()
	page.add_child(controls)
	for item in [["damage", "Урон"], ["hp", "HP цели"], ["cooldown", "Интервал атак"]]:
		var label := Label.new()
		label.text = item[1]
		controls.add_child(label)
		var field := SpinBox.new()
		field.min_value = 0.5
		field.max_value = 2.0
		field.step = 0.05
		field.value = 1.0
		controls.add_child(field)
		sliders[item[0]] = field
	for spec in preload("res://scripts/balance_lab.gd").SCENARIOS:
		scenario.add_item(spec[0])
	controls.add_child(scenario)
	_button(controls, "Испытать", _launch)
	page.add_child(status)
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; JSON"])
	add_child(dialog)
	dialog.file_selected.connect(_loaded)
	var names := DirAccess.get_files_at("user://survival_reports") if DirAccess.dir_exists_absolute("user://survival_reports") else PackedStringArray()
	names.sort()
	names.reverse()
	for nm in names:
		if not nm.ends_with(".json") or runs.size() >= 50:
			continue
		var value = JSON.parse_string(FileAccess.get_file_as_string("user://survival_reports".path_join(nm)))
		if value is Dictionary and value.get("heroes") is Dictionary and value.get("attacks") is Dictionary and value.get("bosses") is Dictionary and value.get("survival") is Dictionary:
			picks.add_item(str(value.get("created_utc", nm)))
			runs.append(value)
	if not runs.is_empty():
		run = runs[0]
	else:
		picks.add_item("Нет забегов Survival")
	set_process(false)
	_refresh()

func _button(parent, caption: String, callback: Callable) -> void:
	var b = get_parent().button(caption, callback)
	b.custom_minimum_size = Vector2(0, 36)
	b.remove_theme_font_size_override("font_size")
	parent.add_child(b)

func _browse(index: int) -> void:
	slot = index
	dialog.popup_centered_ratio(0.75)

func _loaded(path: String) -> void:
	var data := Reports.read(path)
	if data.is_empty():
		status.text = "Требуется действительный JSON контролируемого испытания."
		return
	sources[slot] = path
	if slot == 0:
		before = data
	else:
		after = data
	status.text = path
	_refresh()

func _notes() -> Array:
	return Analysis.review(run, before, after) + Analysis.boss_outcomes(runs, run)

func _refresh() -> void:
	var section := tabs.get_selected_items()[0]
	var lines := PackedStringArray([SECTIONS[section].to_upper(), ""])
	var table := {}
	match section:
		0:
			for key in ["created_utc", "outcome", "active_seconds", "enemy_hp_scale", "unclassified_enemy_hp_lost", "survival"]:
				if run.has(key):
					table[key] = run[key]
		1:
			for key in run.get("attacks", {}):
				var a: Dictionary = run.attacks[key]
				lines.append("%s   ·   %d применений   ·   %d попаданий   ·   %.1f HP   ·   %.1f контроля" % [key, a.uses, a.hits, a.get("actual_hp_lost", 0), a.get("stagger_requested", 0)])
		2: table = run.get("heroes", {})
		3:
			for hero in run.get("heroes", {}):
				var h: Dictionary = run.heroes[hero]
				for key in ["switches_in", "duo_attacks", "air_tags", "team_overdrive"]:
					table[hero + " / " + key] = h.get(key, 0)
		4: table = run.get("enemies", {})
		5: table = run.get("bosses", {})
		6: table = run.get("survival", {}).get("upgrades", {})
		7:
			for i in 2:
				lines.append(("База: " if i == 0 else "Тест: ") + sources[i])
				var selected: Dictionary = before if i == 0 else after
				if not selected.is_empty():
					lines.append("Профиль × " + JSON.stringify(selected.get("experimental_profile", {"damage":1, "hp":1, "cooldown":1})))
			if not after.is_empty():
				for row in Reports.compare(before if not before.is_empty() else {"summary": {}}, after):
					if row.current != null:
						lines.append("%s · %s   %.2f   n=%d   Δ %s   %s" % [row.scenario_style, row.metric, row.current.mean, row.current.n, str(row.delta), row.note])
		8:
			for note in _notes():
				lines.append("%s\n%s · Уверенность: %s\n%s · %s · %s\n" % [note.observation, note.evidence, note.confidence, note.verify, note.parameter, note.repeat])
			if lines.size() == 2:
				lines.append("Для выбранных данных пороги проверки не достигнуты.")
	for key in table:
		_append_value(lines, key, table[key], "")
	if lines.size() == 2:
		lines.append("Нет измерений в выбранном забеге.")
	content.text = "\n".join(lines)
	content.scroll_to_line(0)

func _append_value(lines: PackedStringArray, key: String, value: Variant, indent: String) -> void:
	var caption: String = LABELS.get(key, key)
	if value is Dictionary and not value.is_empty():
		lines.append(indent + caption)
		for child in value:
			_append_value(lines, str(child), value[child], indent + "    ")
	else:
		var display := "%.2f" % value if value is float and value != floorf(value) else str(value)
		lines.append("%s%s    %s" % [indent, caption, display])

func _profile() -> Dictionary:
	var values := {}
	for key in sliders:
		sliders[key].apply()
		values[key] = sliders[key].value
	return values

func _save(path: String, data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	return file != null and file.store_string(JSON.stringify(data, "\t"))

func _export() -> void:
	var path := ROOT.path_join("proposal_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	var ok := _save(path, {"schema": 1, "profile": _profile(), "last_tested_profile": after.get("experimental_profile", {}), "controlled_sources": sources, "survival_utc": run.get("created_utc"), "findings": _notes()})
	status.text = ProjectSettings.globalize_path(path) if ok else "Ошибка записи предложения."

func _launch() -> void:
	if job > 0:
		return
	job_dir = ProjectSettings.globalize_path(ROOT.path_join("trial_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]))
	var path := job_dir.path_join("profile.json")
	if not _save(path, _profile()):
		status.text = "Ошибка записи профиля."
		return
	var args := PackedStringArray(["--headless", "--disable-render-loop", "--fixed-fps", "60"])
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--balance-profile=" + path, "--balance-lab-check=" + job_dir, "--balance-lab-scenario=" + scenario.get_item_text(scenario.selected)])
	job = OS.create_process(OS.get_executable_path(), args)
	status.text = "Испытание выполняется…" if job > 0 else "Не удалось запустить стенд."
	set_process(job > 0)

func _process(_dt: float) -> void:
	if Time.get_ticks_msec() < next_poll:
		return
	next_poll = Time.get_ticks_msec() + 250
	if OS.is_process_running(job):
		return
	job = -1
	set_process(false)
	slot = 1
	_loaded(job_dir.path_join("balance_lab.json"))
