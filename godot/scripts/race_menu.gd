## Меню гонок VACUUM RACING — экраны главного меню (тот же вид и та же навигация, что у остальных: menu._open):
##   SINGLE RACE — гонка против пяти ботов (уровень — СОПЕРНИКИ), TIME TRIAL — заезд на время без соперников и
##   предметов, ONLINE RACE — сетевая гонка (menu.open_online, race_lobby.gd), РЕКОРДЫ, УПРАВЛЕНИЕ (переназначение
##   гоночных клавиш и чувствительность руля), НАЗАД. Выбор трассы и уровня запоминается в user://grimerka_race.json.
## Меню только собирает настройки заезда и передаёт их main.cinematic_race — гонку ведёт race.gd.
class_name RaceMenu

static func open(menu, start := 2) -> void:
	var tid := String(RaceSave.v("track"))
	var T := RaceData.track(tid)
	var lines: Array = [String(T["desc"])]
	var rec := _records_line(tid)
	if rec != "":
		lines.append(rec)
	menu._open("VACUUM RACING", lines, [
		[func(): return "ТРАССА: " + String(RaceData.track(String(RaceSave.v("track")))["name"]), null, func(d: int): _track_step(d)],
		[func(): return "СОПЕРНИКИ: " + String(RaceData.BOTS[String(RaceSave.v("level"))]["name"]), null, func(d: int): _level_step(d)],
		["SINGLE RACE", func(): _start(menu, "single")],
		["TIME TRIAL", func(): _start(menu, "time")],
		["ONLINE RACE", func(): menu.open_online()],
		["РЕКОРДЫ", func(): _records(menu)],
		["УПРАВЛЕНИЕ", func(): controls(menu)],
		["НАЗАД", func(): menu._close()]], start)

static func _track_step(d: int) -> void:
	var list: Array = RaceData.TRACK_ORDER
	var i := list.find(String(RaceSave.v("track")))
	RaceSave.put("track", String(list[posmod(i + d, list.size())]))

static func _level_step(d: int) -> void:
	var list: Array = RaceData.BOT_ORDER
	var i := list.find(String(RaceSave.v("level")))
	RaceSave.put("level", String(list[posmod(i + d, list.size())]))

## настройки заезда → переход в гонку
static func config(mode: String) -> Dictionary:
	var tid := String(RaceSave.v("track"))
	return {"mode": mode, "track": tid, "laps": int(RaceData.track(tid)["laps"]), "level": String(RaceSave.v("level")),
		"rider": "pahan", "name": "ПАХАН", "seed": int(Time.get_ticks_usec() % 2147483647)}

static func _start(menu, mode: String) -> void:
	menu.launch_race(config(mode))

static func _records_line(tid: String) -> String:
	var a := RaceSave.best(tid, "single")
	var b := RaceSave.best(tid, "time")
	var c := RaceSave.best(tid, "lap")
	var parts: Array = []
	if a > 0.0:
		parts.append("гонка " + RaceHud.fmt(a))
	if b > 0.0:
		parts.append("на время " + RaceHud.fmt(b))
	if c > 0.0:
		parts.append("лучший круг " + RaceHud.fmt(c))
	return ("Рекорды: " + " · ".join(parts)) if not parts.is_empty() else ""

static func _records(menu) -> void:
	var lines: Array = []
	for tid in RaceData.TRACK_ORDER:
		var r := _records_line(tid)
		lines.append(String(RaceData.track(tid)["name"]) + " — " + (r.substr(9) if r != "" else "рекордов пока нет"))
	lines.append("Рекорды хранятся на этом компьютере (user://grimerka_race.json): лучшее время одиночной гонки, заезда на время и лучший круг.")
	menu._open("РЕКОРДЫ", lines, [["НАЗАД", func(): open(menu, 5)]])
	menu.panel_back = func(): open(menu, 5)

## УПРАВЛЕНИЕ: Enter на действии — «нажми клавишу» (Esc — отмена); занятая другим гоночным действием клавиша
## меняется с ним местами. Мышь и геймпад остаются как были.
static func controls(menu, start := 0) -> void:
	var acts: Array = []
	for a in RaceData.ACTIONS:
		var nm: String = a[0]
		var title: String = a[1]
		acts.append([func(): return "%s: %s" % [title, " / ".join(RaceSave.keys_of(nm))], func(): _capture(menu, nm, title)])
	acts.append([func(): return "ЧУВСТВИТЕЛЬНОСТЬ РУЛЯ: %d%%" % roundi(float(RaceSave.v("steer")) * 100.0), null,
		func(d: int): RaceSave.put("steer", clampf(snappedf(float(RaceSave.v("steer")) + 0.1 * d, 0.1), 0.5, 1.5))])
	acts.append(["СБРОСИТЬ КЛАВИШИ", func():
		RaceSave.reset_binds()
		controls(menu, RaceData.ACTIONS.size() + 1)])
	acts.append(["НАЗАД", func(): open(menu, 6)])
	menu._open("УПРАВЛЕНИЕ", ["Гоночные клавиши — свои, управление кампании не меняется. Геймпад: левый стик — руль, RT — газ, LT — тормоз, A — газ, B — тормоз, RB — занос, LB — прыжок, Y — турбо, X — предмет."], acts, start)
	menu.panel_back = func(): open(menu, 6)

static func _capture(menu, action: String, title: String) -> void:
	menu.info.text = "Нажми клавишу для «%s» · Esc — отмена" % title
	var row: int = menu.panel_sel
	for r in menu.panel_rows:
		if r["act"] != null and menu.panel_rows.find(r) == row:
			(r["label"] as Label).text = "▶ %s: …нажми клавишу…" % title
	menu.capture = func(e: InputEvent):
		if e is InputEventKey and (e as InputEventKey).physical_keycode != KEY_ESCAPE:
			var swapped := RaceSave.rebind(action, int((e as InputEventKey).physical_keycode))
			controls(menu, row)
			if swapped != "":
				menu.info.text = "Клавиша была у другого действия — они поменялись местами."
		else:
			controls(menu, row)
