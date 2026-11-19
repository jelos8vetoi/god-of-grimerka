## Проверка «5 НОЧЕЙ С ПАХАНОМ»: `--resolution 1280x720 -- --fivenightscheck=<папка>`.
## Как игрок: выбор режима → терминал → NEW GAME; камеры (все 8 и снимки), двери, свет, заслонки, расход
## энергии по таблице, отключение и ручной генератор, маршруты всех врагов (ходы только по соседним комнатам),
## условия атаки (закрыта — уходит, открыта — входит, монитор оттягивает), все шесть скримеров и скример
## в темноте (снимки в середине), победа и 6 AM, переход к следующей ночи, гибель и «ЕЩЁ РАЗ», Night 6,
## Custom Night и свой набор, сохранение и резервная копия, выход в меню режимов, кампания после.
## Симуляции стратегий: безупречный игрок выживает (смерть только по ошибке), лень и «двери весь вечер» — нет.
## Итог — «FIVENIGHTSCHECK ok».
extends Node

const KEEP := ["user://grimerka_save.json", "user://five_nights_save.json", "user://five_nights_save.json.bak"]
var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	for p in KEEP.slice(1):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	FNSave.loaded = false
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("FIVENIGHTSCHECK ok: " if cond else "FIVENIGHTSCHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func key(k: Key, hold := 0.05) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(hold)

func _press(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)

## ход врага только к соседней комнате (или отход на старт / к двери с рывком) — без телепортов
const EDGES := {
	"balon": {"stage": ["arcade", "power", "hall_l", "hall_r", "away"], "arcade": ["hall_l", "storage", "stage", "away"], "storage": ["arcade"], "power": ["hall_r", "stage", "away"],
		"hall_l": ["door_l"], "hall_r": ["door_r"], "away": ["hall_l", "hall_r"], "door_l": ["stage", "arcade"], "door_r": ["stage", "power"]},
	"madk1d": {"vent": ["duct_l", "duct_t"], "duct_l": ["vent_l", "duct_t"], "duct_t": ["vent_t", "duct_l"], "vent_l": ["vent"], "vent_t": ["vent"]},
	"bot": {"server": ["power"], "power": ["hall_r", "server"], "hall_r": ["door_r", "server", "power"], "door_r": ["server"]},
	"clipper": {"storage": ["arcade"], "arcade": ["hall_l", "door_l"], "hall_l": ["door_l"], "door_l": ["storage"]},
	"mod": {"power": ["hall_r"], "hall_r": ["door_r", "power"], "door_r": ["power"]},
}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	var grim0 = kept[KEEP[0]]
	var quick := OS.get_cmdline_user_args().has("--fn-quick")
	# ================= симуляции: честность и баланс =================
	var sims := {}
	if quick:
		await _ui_part()
		return
	for n in 6:
		for s in ["perfect", "good", "average", "lazy", "turtle", "spam", "starer"]:
			sims["%d_%s" % [n, s]] = FNSim.batch(n, s, 24)
		print("FIVENIGHTSCHECK   ночь %d: безупречный %d%%, хороший %d%%, средний %d%%, лень %d%%, двери весь вечер %d%%, всё включено %d%%, не отводит глаз %d%%" % [n + 1,
			int(sims["%d_perfect" % n]["win"] * 100), int(sims["%d_good" % n]["win"] * 100), int(sims["%d_average" % n]["win"] * 100), int(sims["%d_lazy" % n]["win"] * 100),
			int(sims["%d_turtle" % n]["win"] * 100), int(sims["%d_spam" % n]["win"] * 100), int(sims["%d_starer" % n]["win"] * 100)])
	var fair := true
	for n in 5:
		fair = fair and float(sims["%d_perfect" % n]["win"]) >= 0.95
	ok(fair, "ночи 1–5: безупречный игрок выживает (смерть — только из-за ошибки)")
	ok(float(sims["5_perfect"]["win"]) >= 0.5, "ночь 6 трудная, но честная: безупречный выживает в %d%%" % int(sims["5_perfect"]["win"] * 100))
	ok(float(sims["0_good"]["win"]) >= 0.9 and float(sims["4_good"]["win"]) >= 0.6, "хороший игрок проходит первую ночь и чаще всего пятую")
	ok(float(sims["4_average"]["win"]) < float(sims["0_average"]["win"]), "сложность растёт от ночи к ночи")
	var bad := true
	for n in 5:
		for s in ["lazy", "turtle", "spam", "starer"]:
			if float(sims["%d_%s" % [n, s]]["win"]) > 0.1:
				bad = false
				print("FIVENIGHTSCHECK   слишком легко для «%s» в ночь %d" % [s, n + 1])
	ok(bad, "лень, двери весь вечер, всё включено, «не отводит глаз» — проигрыш")
	# ================= логика: двери, энергия, маршруты, атаки =================
	_logic()
	_incidents_logic()
	await _ui_part()

func _ui_part() -> void:
	var grim0 = kept[KEEP[0]]
	# ================= вход через меню режимов =================
	var mm = main.menu
	var idx := -1
	for k in ModeSelect.MODES.size():
		if String(ModeSelect.MODES[k]["id"]) == "five_nights":
			idx = k
	ok(idx >= 0, "в выборе режима есть 5 НОЧЕЙ С ПАХАНОМ")
	var ids: Array = ModeSelect.MODES.map(func(m): return String(m["id"]))
	ok(ids.has("story") and ids.has("training") and ids.has("race") and ids.has("microloans"), "остальные режимы на месте: %s" % ", ".join(ids))
	mm.open_modes(idx)
	await wait(0.8)
	await shot("f00_mode_card")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null, "карточка открывает экран режима (ЗАСТУПИТЬ НА СМЕНУ / НАЗАД)")
	mm._panel_select(0, false)
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is FiveNightsRoot, 15.0)
	ok(started, "мини-игра запустилась своей сценой (five_nights.tscn)")
	if not started:
		_finish()
		return
	ok(main.game == null and main.race == null, "основная игра не создана")
	var R: FiveNightsRoot = main.minigame
	await wait(1.2)
	ok(R.state == "menu" and R.menu.visible and R.menu.rows.size() == 7, "терминал: %s" % ", ".join(R.menu.rows.map(func(r): return String(r["text"].call()) if r["text"] is Callable else String(r["text"]))))
	await shot("f01_terminal")
	ok(not R.menu.rows[3].get("ok", true), "CUSTOM NIGHT закрыт до прохождения")
	R.menu.open_nights()
	await wait(0.2)
	ok(R.menu.rows.size() == 6 and not R.menu.rows[1].get("ok", true), "выбор ночи: закрытые ночи не запускаются")
	await shot("f02_nights")
	R.menu.open_main()
	R.menu.select(0, false)
	await key(KEY_ENTER)
	var night_on: bool = await until(func(): return R.state == "night" and R.st != null and R.intro_t <= 0.0, 12.0)
	ok(night_on and R.st.night == 0, "NEW GAME — первая ночь")
	await wait(4.0)
	await shot("f03_office")
	var st: FNNight = R.st
	print("FIVENIGHTSCHECK   состояние: %s, заставка %.1f, пауза %s, t %.1f, монитор %s" % [R.state, R.intro_t, str(R.paused), st.t, str(st.monitor)])
	# только Балон и не мешаем проверке случайными ходами
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	# взгляд налево/направо
	_press(KEY_LEFT, true)
	await wait(0.9)
	await shot("f04_look_left")
	ok(R.office.yaw < -0.6, "стрелка влево (держать) — Пахан смотрит на левую дверь (%.2f)" % R.office.yaw)
	_press(KEY_LEFT, false)
	_press(KEY_RIGHT, true)
	await wait(1.2)
	ok(R.office.yaw > 0.6, "стрелка вправо — на правую дверь (%.2f)" % R.office.yaw)
	await shot("f04b_look_right")
	_press(KEY_RIGHT, false)
	await wait(0.8)
	ok(absf(R.office.yaw) < 0.2, "отпустил — взгляд снова на стол (%.2f)" % R.office.yaw)
	# двери и свет
	var p0 := st.power
	await key(KEY_A)
	await key(KEY_D)
	await wait(0.6)
	ok(st.door["l"] and st.door["r"] and R.office.door_y["l"] < 0.1 and R.office.door_y["r"] < 0.1, "A и D закрывают обе двери — ставни опустились")
	ok(st.usage == 3, "нагрузка с двумя дверями: %d" % st.usage)
	await shot("f05_doors_closed")
	await key(KEY_A)
	await key(KEY_D)
	await wait(0.6)
	ok(not st.door["l"] and not st.door["r"] and R.office.door_y["l"] > 0.9, "двери открылись")
	# свет держится, пока держишь
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.pressed = true
	Input.parse_input_event(q)
	await wait(0.4)
	ok(st.light["l"] and (R.office.lights["l"] as SpotLight3D).light_energy > 0.0, "Q (держать) — свет в левом коридоре")
	st.enemies["balon"].spot = "door_l"
	R.actors.place_key.clear()
	R.office.yaw = -1.0
	await wait(0.3)
	await shot("f06_light_balon")
	q.pressed = false
	Input.parse_input_event(q)
	await wait(0.2)
	ok(not st.light["l"], "отпустил — свет погас")
	st.enemies["balon"].spot = "stage"
	R.actors.place_key.clear()
	# заслонки
	await key(KEY_Z)
	await key(KEY_X)
	ok(st.seal["l"] and st.seal["t"], "Z и X закрывают заслонки вентиляции")
	await key(KEY_Z)
	await key(KEY_X)
	# камеры: все восемь
	await key(KEY_SPACE)
	await wait(0.5)
	ok(st.monitor and R.ui.tablet.visible, "ПРОБЕЛ — планшет поднят")
	var seen_cams := 0
	for i in 8:
		await key(KEY_1 + i)
		await wait(0.35)
		if st.cam == String(FNData.CAMS[i]["id"]):
			seen_cams += 1
		await shot("f1%d_cam_%s" % [i, FNData.CAMS[i]["id"]])
	ok(seen_cams == 8, "1–8 — все восемь камер (%d)" % seen_cams)
	await _anomalies(R, st)
	ok(R.cams.vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "рисуется только выбранная камера, пока монитор поднят")
	await key(KEY_SPACE)
	await wait(0.4)
	ok(not st.monitor and R.cams.vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "монитор опущен — камера не рендерится")
	ok(st.power < p0, "энергия тратится (%.1f → %.1f)" % [p0, st.power])
	# ================= Пахан-копия в негативе (секрет, безвредный) =================
	R.double_scare()
	await until(func(): return R.ui.neg, 3.0)
	await wait(0.95)
	await shot("f29_pahan_negative")
	var pr: Rig = R.actors.rigs.get("pahan")
	ok(pr != null and pr.visible and R.ui.neg, "скример Пахана: его копия в упор, кадр в негативе")
	await until(func(): return R.state == "night", 4.0)
	ok(R.state == "night" and not R.ui.neg and st.outcome == "", "после копии ночь идёт дальше (безвредный секрет)")
	# ================= скримеры: все шесть и темнота =================
	for eid in ["balon", "madk1d", "bot", "clipper", "ghost", "mod"]:
		await _scare_case(R, eid)
	# темнота: отключение, генератор, второй раз — скример
	R.start_night(0)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 10.0)
	await wait(0.5)
	st = R.st
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	st.power = 0.2
	await until(func(): return st.power_out, 4.0)
	ok(st.power_out and not st.door["l"] and st.cams_dead(), "энергия кончилась: двери открыты, камеры погасли")
	await wait(3.4)
	ok(R.office.dark_eyes.visible, "в темноте у левого проёма — глаза")
	await shot("f30_dark_eyes")
	for k in 16:
		await key(KEY_A if k % 2 == 0 else KEY_D, 0.02)
	ok(not st.power_out and st.power > 5.0, "ручной генератор: A/D по очереди — свет вернулся (%.1f%%)" % st.power)
	st.power = 0.2
	await until(func(): return R.state == "scare", 20.0)
	ok(R.state == "scare" and st.killer == "balon" and st.kill_at == "dark", "второй раз генератор не спасает — Балон в темноте")
	await wait(0.6)
	await shot("f31_scare_dark")
	await until(func(): return R.state == "dead", 6.0)
	await shot("f32_dead")
	# ЕЩЁ РАЗ
	R.retry()
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 10.0)
	ok(R.state == "night" and R.st.night == 0 and R.st.power == 100.0, "ЕЩЁ РАЗ — ночь заново")
	# ================= победа и 6 AM =================
	st = R.st
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	st.t = 6.0 * FNData.HOUR_SEC - 1.0
	await until(func(): return R.state == "six", 4.0)
	ok(R.state == "six" and (FNSave.v("beaten") as Array).has(0) and int(FNSave.v("unlocked")) >= 2, "6 AM: ночь пройдена, открыта вторая")
	await wait(3.0)
	await shot("f40_six_am")
	var next: bool = await until(func(): return R.state == "night" and R.st.night == 1, 12.0)
	ok(next, "после 6 AM — следующая ночь")
	# Night 6 и Custom Night
	FNSave.data["night6"] = true
	FNSave.data["custom"] = true
	R.to_terminal()
	await wait(0.4)
	R.menu.open_nights()
	ok(R.menu.rows.size() == 7, "NIGHT 6 появилась в выборе ночи")
	R.start_night(5)
	await until(func(): return R.state == "night", 6.0)
	ok(R.st.night == 5 and (R.st.enemies["balon"] as FNEnemy).level >= 10, "NIGHT 6: враги злее (Балон %d)" % (R.st.enemies["balon"] as FNEnemy).level)
	R.to_terminal()
	await wait(0.3)
	R.menu.open_custom()
	await wait(0.2)
	R.menu.select(0, false)
	for k in 5:
		await key(KEY_D)
	var lv0 := int((FNSave.v("levels") as Dictionary)["balon"])
	R.menu.select(7, false)
	await key(KEY_ENTER)
	ok((FNSave.v("presets") as Dictionary).size() >= 1, "CUSTOM NIGHT: свой набор сохранён")
	await shot("f50_custom")
	R.menu.select(8, false)
	await key(KEY_ENTER)
	await until(func(): return R.state == "night", 6.0)
	ok(R.st.night == 6 and (R.st.enemies["balon"] as FNEnemy).level == lv0, "CUSTOM NIGHT запущена с выставленными уровнями (Балон %d)" % lv0)
	# сохранение: файл, резервная копия, повреждение
	ok(FileAccess.file_exists(FNSave.PATH), "сохранение: user://five_nights_save.json")
	FNSave.save()
	var f := FileAccess.open(FNSave.PATH, FileAccess.WRITE)
	f.store_string("{сломано")
	f.close()
	FNSave.loaded = false
	ok(bool(FNSave.v("custom")) and (FNSave.v("beaten") as Array).has(0) and int(FNSave.v("unlocked")) >= 2, "повреждённый файл — загружена резервная копия (ночи открыты: %d)" % int(FNSave.v("unlocked")))
	ok(FileAccess.get_file_as_string(KEEP[0]) == (grim0 if grim0 != null else ""), "сюжетное сохранение не тронуто")
	# выход в меню режимов и кампания
	R.to_terminal()
	await wait(0.3)
	R.quit_to_menu()
	var back: bool = await until(func(): return main.menu != null and main.minigame == null and main.menu.modes.visible, 8.0)
	ok(back, "BACK TO MENU — в меню режимов")
	main.start_game(false, 0)
	var camp: bool = await until(func(): return main.game != null and main.game.player != null, 20.0)
	ok(camp, "кампания после мини-игры запускается")
	main.game._to_menu()
	await wait(1.0)
	_finish()

## скример врага: поставить у двери (или где он входит), открыть, дождаться — снимок в середине
func _scare_case(R: FiveNightsRoot, eid: String) -> void:
	R.start_night(4)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 10.0)
	await wait(0.3)
	var st: FNNight = R.st
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	var e: FNEnemy = st.enemies[eid]
	e.level = 10
	st.attack(eid, {"balon": "door_l", "madk1d": "vent_t", "bot": "door_r", "clipper": "door_l", "ghost": "stage", "mod": "door_r"}[eid])
	var t0 := Time.get_ticks_msec()
	await until(func(): return R.state == "scare", 2.0)
	# середина скримера: враг в кадре вплотную
	await until(func(): return R.office.shake > 0.8, 3.0)
	await wait(0.12)
	await shot("f2_scare_" + eid)
	var r: Rig = R.actors.rigs[eid]
	var close := r.visible and r.global_position.distance_to(R.office.cam.global_position) < 2.2
	var head: Vector3 = r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["head"]).origin
	var in_view := not R.office.cam.is_position_behind(head) and Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(60).has_point(R.office.cam.unproject_position(head))
	print("FIVENIGHTSCHECK   %s: голова %s, камера %s, голова в кадре %s" % [eid, str(head.snapped(Vector3.ONE * 0.01)), str(R.office.cam.global_position.snapped(Vector3.ONE * 0.01)), str(in_view)])
	close = close and in_view
	await until(func(): return R.state == "dead", 6.0)
	var dur := (Time.get_ticks_msec() - t0) / 1000.0
	ok(close and R.state == "dead", "скример %s: в 3D вплотную, затем экран гибели (%.1f с)" % [FNData.ENEMIES[eid]["name"], dur])

## чистая логика ночи: энергия, двери, маршруты, условия атаки
## аномалии камер в настоящей сцене: силуэт, свет, головы, поворот врага, «за спиной»; снимки a_*
func _anomalies(R: FiveNightsRoot, st: FNNight) -> void:
	var A: FNAnomaly = R.anomaly
	var f: FNFacility = R.fac
	ok(f.figures.size() >= 8 and f.lights.size() >= 7 and f.heads.has("storage") and f.movable.size() >= 2, "у комнат есть точки для аномалий: силуэтов %d, комнат со светом %d, тележка и автомат могут «переехать»" % [f.figures.size(), f.lights.size()])
	var meshes := f.find_children("*", "MeshInstance3D", true, false).size()
	ok(meshes > 1200, "комнаты обставлены моделями (деталей %d)" % meshes)
	st.set_cam("stage")
	await wait(0.4)
	A._start("figure", "stage", st)
	await wait(0.25)
	ok((f.figures["stage"] as Node3D).visible, "аномалия «силуэт»: в углу главного зала стоит фигура")
	await shot("a1_figure_stage")
	st.set_cam("arcade")
	await wait(0.3)
	ok(not (f.figures["stage"] as Node3D).visible, "переключил камеру — силуэта больше нет")
	A._start("light", "arcade", st)
	await wait(0.5)
	var red: bool = (f.lights["arcade"] as Array).any(func(l): return (l as Light3D).light_color.r > 0.9 and (l as Light3D).light_color.g < 0.2)
	ok(red, "аномалия «свет»: игровая зона краснеет и мигает")
	await shot("a2_light_arcade")
	st.set_cam("storage")
	await wait(0.4)
	A._start("heads", "storage", st)
	await wait(0.2)
	await shot("a3_heads_storage")
	var cp: Vector3 = f.cams["storage"]["pos"]
	var faced := 0
	for h in f.heads["storage"]:
		var hn := h as Node3D
		var to := cp - hn.global_position
		if absf(wrapf(hn.global_rotation.y - atan2(to.x, to.z), -PI, PI)) < 0.2:
			faced += 1
	ok(faced == (f.heads["storage"] as Array).size(), "аномалия «головы»: все %d голов маскотов смотрят в камеру" % faced)
	st.set_cam("hall_r")
	await wait(0.3)
	A._start("self", "hall_r", st)
	await wait(0.15)
	ok((f.figures["office"] as Node3D).visible, "аномалия «за спиной»: камера на миг показывает будку, за стулом кто-то стоит")
	await shot("a4_self")
	await wait(0.6)
	ok(not (f.figures["office"] as Node3D).visible, "«за спиной» — меньше секунды, потом снова коридор")
	A._moved("hall_r")
	await wait(0.3)
	await shot("a5_moved_hall_r")
	ok(A.events_log.size() >= 5, "журнал аномалий: %s" % ", ".join(A.events_log))
	A.reset(int(st.rng.seed))
	ok(not (f.figures["office"] as Node3D).visible and A.count == 0, "новая ночь — аномалии сброшены")

## поломка камеры, перебой, приманка — на чистой логике ночи
func _incidents_logic() -> void:
	var st := FNNight.new()
	st.setup(2, 4242)
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	st.break_next = 0.0
	st.step(0.1)
	ok(st.broken != "", "поломка: камера %s перестала отвечать" % st.broken)
	var b := st.broken
	st.set_monitor(true)
	st.set_cam(b)
	ok(not st.sees(b), "сломанная камера ничего не показывает")
	var p0 := st.power
	for k in 35:
		st.fix_cam(0.1)
	ok(st.broken == "" and st.power < p0, "держать C на ней 3 с — камера перезапустилась (−%.1f %% энергии)" % (p0 - st.power))
	st.break_next = 0.0
	st.step(0.1)
	var b2 := st.broken
	st.set_cam("stage" if b2 != "stage" else "arcade")
	for k in 35:
		st.fix_cam(0.1)
	ok(st.broken == b2, "перезапуск работает только на самой сломанной камере")
	for k in 620:
		st.step(0.1)
		if st.broken == "":
			break
	ok(st.broken == "", "не починил — через минуту камера оживает сама")
	st.brown_next = 0.0
	st.light["l"] = true
	st.step(0.05)
	ok(st.brown_warn > 0.0 and not st.cams_dead(), "перебой: сначала предупреждение (лампы гудят), камеры ещё работают")
	for k in 30:
		st.step(0.1)
	ok(st.brown_t > 0.0 and st.cams_dead() and not st.light["l"], "перебой: камеры и фонари погасли")
	st.door["r"] = true
	for k in 45:
		st.step(0.1)
	ok(st.brown_t <= 0.0 and not st.cams_dead() and st.door["r"], "перебой кончился за %.0f с, дверь всё это время держала" % FNNight.BROWN_LEN)
	# приманка
	var L := FNNight.new()
	L.setup(1, 99)
	var bal: FNEnemy = L.enemies["balon"]
	for id in L.enemies:
		(L.enemies[id] as FNEnemy).level = 0
	bal.level = 10
	bal.go(L, "hall_l")
	var pulled := false
	for k in 8:
		L.lure_cd = 0.0
		var m: Array = L.lure("arcade")
		if m.has("balon"):
			pulled = true
			break
	ok(pulled and bal.spot == "arcade", "приманка в игровой зоне увела БАЛОНА из коридора")
	bal.go(L, "door_l")
	L.lure_cd = 0.0
	L.lure("stage")
	ok(bal.spot == "door_l", "у двери приманка уже не работает — закрывай дверь")
	L.lure_cd = 0.0
	ok(L.lure("hall_r").is_empty() and L.lure_cd == 0.0, "в коридор приманку не поставить")
	ok(L.lure_uses >= 2, "каждая приманка слабее прошлой (использовано %d)" % L.lure_uses)

func _logic() -> void:
	var P := FNData.POWER
	var st := FNNight.new()
	st.setup(0, 3)
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	var p0 := st.power
	for k in 100:
		st.step(0.1)
	ok(absf((p0 - st.power) - float(P["base"]) * 10.0) < 0.05, "энергия: без ничего — %.3f%% в секунду" % ((p0 - st.power) / 10.0))
	st.set_door("l", true)
	st.set_light("r", true)
	st.set_monitor(true)
	p0 = st.power
	for k in 100:
		st.step(0.1)
	var want: float = (float(P["base"]) + float(P["door"]) + float(P["light"]) + float(P["monitor"])) * 10.0
	ok(absf((p0 - st.power) - want) < 0.05, "энергия: дверь + свет + монитор — %.3f%% в секунду (по таблице %.3f)" % [(p0 - st.power) / 10.0, want / 10.0])
	ok(st.usage == 4, "нагрузка 4 полосы")
	# атака: закрыто — стучит и уходит; открыто — входит
	var st2 := FNNight.new()
	st2.setup(0, 5)
	for id in st2.enemies:
		(st2.enemies[id] as FNEnemy).level = 0
	var b: FNEnemy = st2.enemies["balon"]
	b.level = 20
	b.go(st2, "door_l")
	st2.set_door("l", true)
	var banged := false
	for k in 150:
		st2.step(0.1)
		banged = banged or st2.take_events().any(func(ev): return ev[0] == "bang")
		if banged:
			break
	ok(st2.outcome == "" and banged and b.spot != "door_l", "БАЛОН у закрытой двери постучал и ушёл (%s)" % b.spot)
	b.go(st2, "door_l")
	st2.set_door("l", false)
	var at := -1.0
	for k in 200:
		st2.step(0.1)
		if st2.outcome != "":
			at = st2.t
			break
	ok(st2.outcome == "dead" and st2.killer == "balon", "открыта — входит (через %.1f с после прихода, не мгновенно)" % (b.door_t))
	ok(b.door_t >= float(FNData.ENEMIES["balon"]["linger"][1]) * 0.85, "до входа есть время среагировать (%.1f с)" % b.door_t)
	# монитор оттягивает вход
	var st3 := FNNight.new()
	st3.setup(0, 9)
	for id in st3.enemies:
		(st3.enemies[id] as FNEnemy).level = 0
	var c: FNEnemy = st3.enemies["clipper"]
	c.level = 20
	c.go(st3, "door_l")
	st3.set_light("l", true)
	for k in 10:
		st3.step(0.1)
	ok(c.spot == "storage", "свет сгоняет CLIPPER на склад")
	# заслонка: правильная держит, неправильная — нет
	var st4 := FNNight.new()
	st4.setup(1, 11)
	for id in st4.enemies:
		(st4.enemies[id] as FNEnemy).level = 0
	var m: FNEnemy = st4.enemies["madk1d"]
	m.level = 20
	m.go(st4, "vent_t")
	st4.set_seal("l", true)
	for k in 120:
		st4.step(0.1)
		if st4.outcome != "":
			break
	ok(st4.outcome == "dead" and st4.killer == "madk1d", "MADK1D: закрыта не та заслонка — пролез")
	var st5 := FNNight.new()
	st5.setup(1, 12)
	for id in st5.enemies:
		(st5.enemies[id] as FNEnemy).level = 0
	var m2: FNEnemy = st5.enemies["madk1d"]
	m2.level = 20
	m2.go(st5, "vent_t")
	st5.set_seal("t", true)
	for k in 120:
		st5.step(0.1)
	ok(st5.outcome == "" and m2.moves >= 2, "MADK1D: закрыт люк — постучал и уполз назад")
	# BOT: принятый пинг — не выходит; пропущенный — идёт
	var st6 := FNNight.new()
	st6.setup(2, 13)
	for id in st6.enemies:
		(st6.enemies[id] as FNEnemy).level = 0
	var bt: FNBot = st6.enemies["bot"]
	bt.level = 20
	bt.move_t = 0.0
	st6.step(0.1)
	ok(bt.ping_left > 0.0, "BOT подал пинг")
	st6.set_monitor(true)
	st6.set_cam("server")
	for k in 15:
		st6.step(0.1)
	ok(bt.ping_left <= 0.0 and not bt.awake, "пинг принят (CAM 6) — BOT спит")
	st6.set_monitor(false)
	bt.calm_t = 0.0
	bt.move_t = 0.0
	st6.step(0.1)
	for k in 250:
		st6.step(0.1)
	ok(bt.awake and bt.spot != "server", "пинг пропущен — BOT проснулся и пошёл (%s)" % bt.spot)
	# GHOST: смотреть долго — опасно, отвести взгляд — спадает
	var st7 := FNNight.new()
	st7.setup(2, 14)
	for id in st7.enemies:
		(st7.enemies[id] as FNEnemy).level = 0
	var g: FNGhost = st7.enemies["ghost"]
	g.level = 20
	g.go(st7, "storage")
	g.show_t = 30.0
	st7.set_monitor(true)
	st7.set_cam("storage")
	var stare := 0.0
	while st7.outcome == "" and stare < 10.0:
		st7.step(0.05)
		stare += 0.05
	ok(st7.killer == "ghost" and stare >= FNGhost.STARE_MIN, "GHOST: смотрел %.1f с — он здесь (не раньше %.1f с)" % [stare, FNGhost.STARE_MIN])
	# MOD: сбои копятся, СБРОС их снимает
	var st8 := FNNight.new()
	st8.setup(3, 15)
	for id in st8.enemies:
		(st8.enemies[id] as FNEnemy).level = 0
	var md: FNMod = st8.enemies["mod"]
	md.level = 20
	for k in 400:
		st8.step(0.1)
		if st8.glitches.size() >= 3:
			break
	ok(st8.glitches.size() >= 3, "MOD набрал сбоев: %s" % ", ".join(st8.glitches.keys()))
	var lbl := st8.cam_label(0)
	st8.reset_system()
	ok(st8.glitches.is_empty() and st8.cams_dead() and md.spot == "power", "СБРОС СИСТЕМЫ: сбоев нет, камеры моргнули, MOD в щитовой")
	ok(lbl != "" and st8.cam_label(0) == FNData.CAMS[0]["name"], "подписи камер снова верные")
	# маршруты: ходы только к соседям (без телепортов), высокие уровни, вся ночь
	var bad_moves: Array = []
	for seed_v in 6:
		var s9 := FNNight.new()
		s9.setup(4, 100 + seed_v)
		for id in s9.enemies:
			(s9.enemies[id] as FNEnemy).level = 16
		var guard := {"l": false, "r": false}
		while s9.outcome == "" and s9.t < 300.0:
			# игрок закрывает двери, когда кто-то пришёл, и открывает, когда ушёл; заслонки — по месту MADK1D
			for sd in ["l", "r"]:
				var any := false
				for id in s9.enemies:
					any = any or (s9.enemies[id] as FNEnemy).spot == "door_" + sd
				s9.set_door(sd, any)
			var mm2: FNEnemy = s9.enemies["madk1d"]
			s9.set_seal("l", mm2.spot == "vent_l")
			s9.set_seal("t", mm2.spot == "vent_t")
			s9.power = 100.0
			s9.step(0.1)
			for ev in s9.take_events():
				if ev[0] != "move":
					continue
				var d: Dictionary = ev[1]
				var eid: String = d["e"]
				if not EDGES.has(eid) or String(d.get("why", "")) in ["retreat", "reset"]:
					continue
				var allowed: Array = EDGES[eid].get(String(d["from"]), [])
				if not allowed.has(String(d["to"])):
					bad_moves.append("%s %s→%s" % [eid, d["from"], d["to"]])
	ok(bad_moves.is_empty(), "враги ходят только по соседним комнатам (нарушений %d%s)" % [bad_moves.size(), (": " + ", ".join(bad_moves.slice(0, 4))) if not bad_moves.is_empty() else ""])
	# никакой случайной смерти: все уровни 0 — ночь проходит сама
	var s10 := FNNight.new()
	s10.setup(6, 77, {"balon": 0, "madk1d": 0, "bot": 0, "clipper": 0, "ghost": 0, "mod": 0})
	s10.power = 100.0
	while s10.outcome == "" and s10.t < 400.0:
		s10.power = 100.0
		s10.step(0.25)
	ok(s10.outcome == "win", "без врагов скримеров нет — 6 AM")

func _finish() -> void:
	FNSave.persist = true
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	FNSave.loaded = false
	AudioServer.set_bus_mute(0, false)
	print("FIVENIGHTSCHECK ok" if fails == 0 else "FIVENIGHTSCHECK ОШИБКА: %d" % fails)
	get_tree().quit()
