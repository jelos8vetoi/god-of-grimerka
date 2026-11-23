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
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else (null as Variant)
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
	var t0 := GameClock.ms()      # по игровым часам: в ускоренной проверке кадр = 1/N с
	while GameClock.ms() - t0 < int(t * 1000.0):
		await get_tree().process_frame

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm + ".png"))

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
	var quick := OS.get_cmdline_user_args().has("--fn-quick")
	# ================= симуляции: честность и баланс =================
	var sims := {}
	if quick:
		await _ui_part()
		return
	for n in 6:
		for s in ["perfect", "good", "average", "lazy", "turtle", "spam", "starer"]:
			# «безупречному» — выборка больше: порог 95 % на 24 прогонах — это «не больше одной смерти», и итог решал случай
			sims["%d_%s" % [n, s]] = FNSim.batch(n, s, 72 if s == "perfect" else 24)
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
	# ночь 2: первая минута спокойна — никто не встаёт к двери и решётке раньше своего порога, бездействие не бессмертно
	var early_post := 0
	var early_death := 0
	var idle_win := 0
	var deaths := 0
	var att_spots := ["door_l", "door_r", "vent_l", "vent_t"]
	for k in 200:
		var cst := FNNight.new()
		cst.setup(1, 500 + k * 13, {})
		while cst.outcome == "" and cst.t < 7.0 * FNData.HOUR_SEC:
			cst.step(0.1)
			cst.take_events()
			for id in cst.enemies:
				var en: FNEnemy = cst.enemies[id]
				if en.spot in att_spots and cst.t < float(cst.calm(id)[1]):
					early_post += 1
		if cst.outcome == "dead":
			deaths += 1
			if cst.t < 60.0:
				early_death += 1
		elif cst.outcome == "win":
			idle_win += 1
	ok(early_post == 0 and early_death == 0 and idle_win == 0 and deaths > 150, "ночь 2, 200 зёрен, бездействие: у двери и решётки раньше порога — %d раз, гибелей раньше 60 с — %d, побед — %d, гибелей всего %d" % [early_post, early_death, idle_win, deaths])
	var calm_zero := true
	for n in [0, 2, 3, 4, 5]:
		for id in FNData.ORDER:
			calm_zero = calm_zero and FNData.calm(n, id) == [0.0, 0.0]
	ok(calm_zero and FNData.calm(1, "madk1d") == [20.0, 60.0] and FNData.calm(1, "balon") == [0.0, 52.0] and FNData.calm(1, "bot") == [0.0, 0.0], "спокойное начало задано только ночи 2, у остальных ночей — нули")
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
	ok(not R.menu.rows[3].get("ok", true), "СВОЯ НОЧЬ закрыта до прохождения")
	R.menu.open_nights()
	await wait(0.2)
	ok(R.menu.rows.size() == 6 and not R.menu.rows[1].get("ok", true), "выбор ночи: закрытые ночи не запускаются")
	await shot("f02_nights")
	R.menu.open_main()
	R.menu.select(0, false)
	await key(KEY_ENTER)
	var night_on: bool = await until(func(): return R.state == "night" and R.st != null and R.intro_t <= 0.0, 12.0)
	ok(night_on and R.st.night == 0, "НОВАЯ ИГРА — первая ночь")
	# озвучка звонка: у каждой реплики начальника есть файл голоса, первая реплика звучит из трубки, F обрывает
	var need := 0
	var have := 0
	var rx_note := RegEx.create_from_string("\\[[^\\]]*\\]")
	var rx_word := RegEx.create_from_string("[A-Za-zА-Яа-яЁё]")
	for night_calls in FNData.CALLS:
		for ln in night_calls:
			if rx_word.search(rx_note.sub(String(ln), "", true)) == null:
				continue                                  # «[помехи]» — ремарка, её не читают
			need += 1
			if R.call_stream(String(ln)) != null:
				have += 1
	ok(need >= 20 and have == need, "звонки начальника озвучены: %d из %d реплик" % [have, need])
	var p_need := 0
	var p_have := 0
	for sec_id in FNData.PAHAN:
		for ln in FNData.PAHAN[sec_id]:
			if rx_word.search(String(ln)) == null:
				continue                                  # «…» не читают
			p_need += 1
			if ResourceLoader.exists(FiveNightsRoot.pahan_path(String(ln))):
				p_have += 1
	ok(p_need >= 15 and p_have == p_need, "мысли Пахана на смене озвучены его голосом: %d из %d" % [p_have, p_need])
	# говорит кто-то один: сначала Пахан, телефон звонит после него; реплика Пахана посреди звонка ждёт конца реплики
	# начальника, а начальник не продолжает, пока Пахан не договорит; подсказки не затирают его строку
	var said: bool = await until(func(): return R.pahan_voice.playing, 3.0)
	ok(said and not R.call_voice.playing and R.ring_t > 0.0, "первым говорит Пахан — голосом; телефон ещё не звонил")
	var overlap := 0
	var spoke_boss := false
	var t_end := GameClock.ms() + 16000
	while GameClock.ms() < t_end and not spoke_boss:
		if R.pahan_voice.playing and R.call_voice.playing:
			overlap += 1
		spoke_boss = R.call_voice.playing
		await get_tree().process_frame
	ok(spoke_boss and overlap == 0, "начальник заговорил после Пахана, голоса не наложились")
	R.pahan_say(String(FNData.PAHAN["door"][1]), 2.0)
	R.say("Проверочная подсказка.", 1.5)
	await get_tree().process_frame
	ok(R.call_voice.playing and not R.pahan_voice.playing and R.say_q.size() == 2, "реплика Пахана посреди звонка ждёт: начальник договаривает")
	var line1 := R.call_voice.stream
	var pahan_after: bool = await until(func(): return R.pahan_voice.playing, 9.0)
	ok(pahan_after and not R.call_voice.playing, "начальник договорил реплику — говорит Пахан")
	var held := true
	while R.pahan_voice.playing:
		if R.call_voice.playing:
			held = false
		await get_tree().process_frame
	ok(held, "пока Пахан говорит, начальник молчит")
	ok(R.ui.msg_l.text == String(FNData.PAHAN["door"][1]), "подсказка не затёрла строку Пахана, пока он говорил")
	var hint_shown: bool = await until(func(): return R.ui.msg_l.text == "Проверочная подсказка.", 4.0)
	ok(hint_shown, "подсказка показана следом, в свою очередь")
	var resumed: bool = await until(func(): return R.call_voice.playing and R.call_voice.stream != line1, 8.0)
	ok(resumed, "звонок продолжился со следующей реплики")
	var spoke: bool = await until(func(): return R.call_voice.playing, 9.0)
	ok(spoke and R.call_voice.bus == "PhoneVoice" and R.ui.sub_box.visible, "реплика звонка звучит голосом из трубки (шина %s), субтитр на экране" % R.call_voice.bus)
	var held_t := R.call_t
	ok(R.call_voice.stream != null and held_t >= R.call_voice.stream.get_length() - R.call_voice.get_playback_position() - 0.1, "субтитр держится, пока реплику договаривают (ещё %.1f с)" % held_t)
	await key(KEY_F)
	ok(not R.call_voice.playing and not R.ui.sub_box.visible, "F сбрасывает звонок: голос замолчал, субтитр убран")
	await wait(1.0)
	await shot("f03_office")
	await no_ipod_here("«5 ночей»")
	await hints_here(R.ui.tips, "5 ночей", "start", R.ui)
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
	# ---- ПУЛЬТ: у каждого устройства видно клавишу, название и состояние ----
	var UI: FNUI = R.ui
	var learn_on: bool = UI.deck_learn_left > 0.0
	ok(learn_on and UI.deck.visible, "первая ночь нового сохранения: пульт виден из-за учёбы (осталось %.0f с)" % UI.deck_learn_left)
	var pin_was := UI.deck_pin
	if not learn_on:
		UI.deck_pin = true
		await wait(0.2)
	var deck_names_ok := true
	var deck_txt: Array = []
	var deck_screen := Rect2(Vector2.ZERO, UI._vs())
	var deck_prev := Rect2()
	var deck_overlap := false
	var deck_off := false
	for D in FNUI.DEVICES:
		var row: Dictionary = UI.deck_rows[D["id"]]
		var nm: Label = row["name"]
		var stl: Label = row["state"]
		var pr_rect: Rect2 = (row["panel"] as Control).get_global_rect()
		if nm.text != String(D["name"]) or stl.text == "" or not (row["panel"] as Control).is_visible_in_tree() or nm.get_minimum_size().x > nm.size.x + 1.0 or stl.get_minimum_size().x > stl.size.x + 1.0:
			deck_names_ok = false
		if deck_prev.size.x > 0.0 and pr_rect.intersects(deck_prev):
			deck_overlap = true
		if not deck_screen.encloses(pr_rect):
			deck_off = true
		deck_prev = pr_rect
		deck_txt.append("[%s] %s — %s" % [D["key"], nm.text, stl.text])
	ok(UI.deck.visible and UI.deck_rows.size() == 8 and deck_names_ok, "пульт: 8 устройств, у каждого клавиша, название и состояние — %s" % "; ".join(deck_txt))
	ok(not deck_overlap and not deck_off, "пульт: плашки не перекрываются и целиком на экране")
	var deck_keys := {}
	for D in FNUI.DEVICES:
		deck_keys[D["key"]] = true
	ok(deck_keys.size() == FNUI.DEVICES.size(), "пульт: у каждого устройства своя клавиша (%d разных)" % deck_keys.size())
	# состояние и подсказка меняются вместе с устройством: «ЛЕВАЯ ДВЕРЬ — ЗАКРЫТЬ» → закрыта → «…— ОТКРЫТЬ»
	var tip_a := UI.dev_tip(st, "door_l")
	R.deck_press("door_l", true)
	await wait(0.3)
	var st_closed: String = (UI.deck_rows["door_l"]["state"] as Label).text
	var tip_b := UI.dev_tip(st, "door_l")
	ok(st.door["l"] and st_closed == "ЗАКРЫТА" and tip_a.begins_with("ЛЕВАЯ ДВЕРЬ — ЗАКРЫТЬ") and tip_b.begins_with("ЛЕВАЯ ДВЕРЬ — ОТКРЫТЬ"), "плашка мышью закрывает дверь; подсказка «%s» → «%s»" % [tip_a.get_slice("\n", 0), tip_b.get_slice("\n", 0)])
	UI.tip_id = "door_l"
	await wait(0.3)
	ok(UI.tip_box.visible and UI.tip_l.text.contains("тратит энергию"), "наведение на плашку показывает, что делает устройство и чего стоит")
	await shot("f05b_deck_tip")
	UI.tip_id = ""
	R.deck_press("door_l", true)
	await wait(0.3)
	# свет — пока держишь плашку
	R.deck_press("light_l", true)
	await wait(0.3)
	var lit: bool = st.light["l"]
	var lit_txt: String = (UI.deck_rows["light_l"]["state"] as Label).text
	R.deck_press("light_l", false)
	await wait(0.3)
	ok(lit and lit_txt == "ГОРИТ" and not st.light["l"], "свет горит, пока держишь плашку («%s»), отпустил — погас" % lit_txt)
	# заслонки и сброс — на пульте, со своими клавишами
	await key(KEY_Z)
	await key(KEY_X)
	await wait(0.3)
	ok(st.seal["l"] and st.seal["t"] and (UI.deck_rows["seal_l"]["state"] as Label).text == "ЗАКРЫТА" and (UI.deck_rows["seal_t"]["state"] as Label).text == "ЗАКРЫТА", "Z и X закрывают заслонки — пульт показывает «ЗАКРЫТА»")
	await key(KEY_Z)
	await key(KEY_X)
	await wait(0.2)
	# недоступное состояние: мало энергии — сброс серый; сбой MOD — индикатор двери честно пишет «НЕТ ДАННЫХ»
	var pw: float = st.power
	st.power = 2.0
	await wait(0.2)
	var rs := UI.dev_state(st, "reset")
	st.power = pw
	st.add_glitch("leds_off")
	await wait(0.2)
	var led_txt: String = (UI.deck_rows["door_l"]["state"] as Label).text
	st.glitches.erase("leds_off")
	ok(String(rs[0]) == "МАЛО ЭНЕРГИИ" and bool(rs[3]) and led_txt == "НЕТ ДАННЫХ", "недоступное видно: сброс «%s», при сбое индикаторов дверь «%s»" % [rs[0], led_txt])
	await _deck_hidden(R, st)
	UI.deck_pin = pin_was
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
	await _hall_left(R, st)
	await _ambience(R, st)
	await _tension(R, st)
	await _vents_check(R)
	await _lock_lamps(R)
	await _fan_check(R)
	_voice_buses(R)
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
	_scream_catalog()
	_habits_check()
	await _dress_check(R)
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
	ok((FNSave.v("presets") as Dictionary).size() >= 1, "СВОЯ НОЧЬ: свой набор сохранён")
	await shot("f50_custom")
	R.menu.select(8, false)
	await key(KEY_ENTER)
	await until(func(): return R.state == "night", 6.0)
	ok(R.st.night == 6 and (R.st.enemies["balon"] as FNEnemy).level == lv0, "СВОЯ НОЧЬ запущена с выставленными уровнями (Балон %d)" % lv0)
	# сохранение: файл, резервная копия, повреждение
	ok(FileAccess.file_exists(FNSave.PATH), "сохранение: user://five_nights_save.json")
	FNSave.save()
	var f := FileAccess.open(FNSave.PATH, FileAccess.WRITE)
	f.store_string("{сломано")
	f.close()
	FNSave.loaded = false
	ok(bool(FNSave.v("custom")) and (FNSave.v("beaten") as Array).has(0) and int(FNSave.v("unlocked")) >= 2, "повреждённый файл — загружена резервная копия (ночи открыты: %d)" % int(FNSave.v("unlocked")))
	ok(FileAccess.get_file_as_string(KEEP[0]) == (grim0 if grim0 != null else ""), "сюжетное сохранение не тронуто")
	await _after_death(R)
	# выход в меню режимов и кампания
	R.to_terminal()
	await wait(0.3)
	R.quit_to_menu()
	var back: bool = await until(func(): return main.menu != null and main.minigame == null and main.menu.modes.visible, 8.0)
	ok(back, "В МЕНЮ РЕЖИМОВ — выход в выбор режима")
	main.start_game(false, 0)
	var camp: bool = await until(func(): return main.game != null and main.game.player != null, 20.0)
	ok(camp, "кампания после мини-игры запускается")
	main.game._to_menu()
	await wait(1.0)
	_finish()

## механизмы вентиляции: картинка следует за st.seal, логика мгновенная
func _vents_check(R: FiveNightsRoot) -> void:
	var st: FNNight = R.st
	var O: FNOffice = R.office
	var keep := [st.seal["l"], st.seal["t"]]
	st.set_seal("l", false)
	st.set_seal("t", false)
	await wait(1.0)
	var stops := [0]
	var cn := func(_s: String, _c: bool): stops[0] += 1
	O.seal_stop.connect(cn)
	var nodes_ok: bool = O.get_node_or_null("Ventilation/WallGrate/DamperPivot") != null and O.get_node_or_null("Ventilation/CeilingHatch/LeafPivotL") != null and O.get_node_or_null("Ventilation/CeilingHatch/LeafPivotR") != null and O.get_node_or_null("Ventilation/CeilingHatch/Damper") == null
	ok(nodes_ok, "механизмы вентиляции: DamperPivot, LeafPivotL, LeafPivotR есть, старой пластины Damper на люке нет")
	var rep_ok := true
	for side in ["l", "t"]:
		var ang := func() -> float: return O.wall_pivot.rotation.x if side == "l" else O.leaf_l.rotation.z
		var open0: bool = O.seal_k[side] == 0.0 and absf(float(ang.call()) - FNOffice.SEAL_OPEN_ANGLE) < 0.06
		st.set_seal(side, true)
		await wait(0.12)
		var mid: bool = O.seal_k[side] > 0.05 and O.seal_k[side] < 0.95 and float(ang.call()) > 0.05 and float(ang.call()) < FNOffice.SEAL_OPEN_ANGLE - 0.05
		await wait(0.9)
		var shut: bool = O.seal_k[side] == 1.0 and absf(float(ang.call())) <= 0.02
		st.set_seal(side, false)
		await wait(0.9)
		var open1: bool = O.seal_k[side] == 0.0 and absf(float(ang.call()) - FNOffice.SEAL_OPEN_ANGLE) < 0.06
		rep_ok = rep_ok and open0 and mid and shut and open1
		ok(open0 and mid and shut and open1, "заслонка «%s»: открыта → через 0,12 с на полпути → через 0,9 с закрыта (угол %.3f) → снова открыта" % [side, float(ang.call())])
	ok(stops[0] == 4, "сигнал упора: ровно один на каждый завершённый ход (%d из 4)" % stops[0])
	var before_n: int = stops[0]
	for i in 6:
		st.set_seal("l", i % 2 == 0)
		await get_tree().process_frame
	await wait(1.2)
	ok(O.seal_k["l"] == (1.0 if st.seal["l"] else 0.0) and stops[0] - before_n == 1, "шесть переключений по одному на кадр: картинка равна состоянию, упор один (%d)" % (stops[0] - before_n))
	O.seal_stop.disconnect(cn)
	var sd := FNSound.get_stream("damper_close")
	var so := FNSound.get_stream("damper_open")
	var sp := FNSound.get_stream("damper_stop")
	var snd_ok := true
	for w in [sd, so, sp]:
		snd_ok = snd_ok and w.loop_mode == AudioStreamWAV.LOOP_DISABLED and w.get_length() <= 0.6
	ok(snd_ok, "звуки заслонок одноразовые и короткие (%.2f, %.2f, %.2f с)" % [sd.get_length(), so.get_length(), sp.get_length()])
	st.set_seal("l", keep[0])
	st.set_seal("t", keep[1])
	await wait(1.0)

## настольный вентилятор: картинка идёт за ambience.fan_spin (звук и вращение совпадают)
func _fan_check(R: FiveNightsRoot) -> void:
	var O: FNOffice = R.office
	var A: FNAmbience = R.ambience
	var rotor: Node3D = O.desk_fan.rotor
	ok(rotor != null and rotor.name == "RotorPivot", "вентилятор: RotorPivot найден")
	ok(O.desk_tris_after < O.desk_tris_before, "старый вентилятор вырезан из стола: треугольников %d → %d (убрано %d, %.1f мс)" % [O.desk_tris_before, O.desk_tris_after, O.fan_cut_tris, O.fan_cut_ms])
	var fan_pt: Node3D = O.get_node("Console/AudioPoints/Fan")
	ok(fan_pt.global_position.distance_to(rotor.global_position) <= 0.2, "маркер звука вентилятора у двигателя (%.2f м от ротора)" % fan_pt.global_position.distance_to(rotor.global_position))
	A.fan_spin = 1.0
	await wait(0.3)
	var q0: Quaternion = rotor.basis.get_rotation_quaternion()
	await wait(1.0)
	var turned: float = q0.angle_to(rotor.basis.get_rotation_quaternion())
	ok(turned > 0.1 and A.fan_spin > 0.95, "обычная ночь: за 1 с ротор повернулся (шаг %.2f рад), fan_spin %.2f" % [turned, A.fan_spin])
	R.set_paused(true)
	await wait(0.2)
	var qp: Quaternion = rotor.basis.get_rotation_quaternion()
	await wait(0.5)
	var held: float = qp.angle_to(rotor.basis.get_rotation_quaternion())
	R.set_paused(false)
	ok(held < 0.001, "на паузе ротор не вращается (%.4f рад)" % held)

## лампы блокировки на механизмах вентиляции
func _lock_lamps(R: FiveNightsRoot) -> void:
	var st: FNNight = R.st
	var O: FNOffice = R.office
	var keep := [st.seal["l"], st.seal["t"]]
	st.set_seal("l", false)
	st.set_seal("t", false)
	await wait(2.0)
	var present: bool = true
	for p in ["Ventilation/WallGrate/LockLamp", "Ventilation/CeilingHatch/LockLamp"]:
		present = present and O.get_node_or_null(p) != null and O.get_node_or_null(p + "/Glow") != null
	ok(present, "лампы блокировки LockLamp и Glow есть у решётки и у люка")
	for side in ["l", "t"]:
		var lamp: MeshInstance3D = O.lock_lamp[side]
		var glow: OmniLight3D = O.lock_glow[side]
		st.set_seal(side, true)
		var amber := false
		for i in 12:
			await get_tree().process_frame
			amber = amber or lamp.material_override == O.mats["amber_led"]
		await wait(1.0)
		var red: bool = lamp.material_override == O.mats["red_led"] and glow.light_energy > 0.1
		st.set_seal(side, false)
		await wait(2.0)      # ход 0,52 с + догорание 0,8 с + запас
		var dark: bool = lamp.material_override == O.mats["off_led"] and glow.light_energy < 0.02
		ok(amber and red and dark, "лампа «%s»: в ходу янтарная (%s), закрыта — красная со светом %.2f, открыта, после хода и догорания — погашена (%.3f)" % [side, str(amber), glow.light_energy if red else -1.0, glow.light_energy])
	st.set_seal("l", true)
	await wait(1.0)
	O.power_on = false
	O._vents(st, 0.0)
	var off_ok: bool = (O.lock_lamp["l"] as MeshInstance3D).material_override == O.mats["off_led"] and (O.lock_glow["l"] as OmniLight3D).light_energy == 0.0
	O.power_on = true
	ok(off_ok, "без питания лампа блокировки погашена, света нет")
	st.set_seal("l", keep[0])
	st.set_seal("t", keep[1])
	await wait(1.0)

## эффекты шины: имена классов по порядку
func _fx_names(bus: String) -> Array:
	var out_a: Array = []
	var i := AudioServer.get_bus_index(bus)
	for k in AudioServer.get_bus_effect_count(i):
		out_a.append(AudioServer.get_bus_effect(i, k).get_class())
	return out_a

func _fx_sig() -> Array:
	return [AudioServer.bus_count, _fx_names("Phone"), _fx_names("RoomVoice"), _fx_names("PhoneVoice"), _fx_names("Voice")]

## голоса в будке: Пахан — в комнате, начальник — из трубки на столе; Voice и Phone остались прежними
func _voice_buses(R: FiveNightsRoot) -> void:
	var _vi := AudioServer.get_bus_index("Voice")
	var all_there := true
	for b in ["Phone", "RoomVoice", "PhoneVoice"]:
		var i := AudioServer.get_bus_index(b)
		all_there = all_there and i >= 0 and AudioServer.get_bus_send(i) == "Voice"
	var voice_clean := true
	for n in _fx_names("Voice"):
		voice_clean = voice_clean and n != "AudioEffectReverb" and n != "AudioEffectDelay"
	ok(all_there and voice_clean, "шины RoomVoice и PhoneVoice есть и посылают в Voice; на Voice нет ревербератора и задержки")
	var want_phone := ["AudioEffectHighPassFilter", "AudioEffectLowPassFilter", "AudioEffectDistortion", "AudioEffectHardLimiter"]
	ok(_fx_names("Phone") == want_phone, "шина Phone прежняя: HP, LP, Distortion, HardLimiter")
	var ri := AudioServer.get_bus_index("RoomVoice")
	var rv: AudioEffectReverb = AudioServer.get_bus_effect(ri, 1) as AudioEffectReverb
	ok(_fx_names("RoomVoice") == ["AudioEffectDelay", "AudioEffectReverb"] and rv != null and rv.wet <= 0.2 and rv.room_size <= 0.5, "RoomVoice: Delay + Reverb (wet %.2f, room_size %.2f)" % [rv.wet if rv != null else -1.0, rv.room_size if rv != null else -1.0])
	var pi := AudioServer.get_bus_index("PhoneVoice")
	var prv: AudioEffectReverb = AudioServer.get_bus_effect(pi, 4) as AudioEffectReverb
	ok(_fx_names("PhoneVoice") == ["AudioEffectHighPassFilter", "AudioEffectLowPassFilter", "AudioEffectDistortion", "AudioEffectEQ6", "AudioEffectReverb", "AudioEffectHardLimiter"] and prv != null and prv.wet <= 0.12, "PhoneVoice: HP, LP, Distortion, EQ6, Reverb (wet %.2f), HardLimiter последним" % (prv.wet if prv != null else -1.0))
	ok(R.pahan_voice.bus == "RoomVoice" and R.call_voice.bus == "PhoneVoice" and R.call_voice is AudioStreamPlayer3D, "pahan_voice → RoomVoice, call_voice → PhoneVoice (AudioStreamPlayer3D)")

## после смерти: пять гибелей подряд со звуком и «ЕЩЁ РАЗ» — ничего не тянется в новую ночь
func _after_death(R: FiveNightsRoot) -> void:
	var quiet_keep := R.quiet
	R.quiet = false
	var vol_keep: Dictionary = main.audio.vol.duplicate()
	var causes := [["balon", "door_l"], ["madk1d", "vent_t"], ["bot", "door_r"], ["clipper", "door_l"], ["dark", "dark"]]
	var stuck := 0
	var looped := 0
	var alive := true
	var fx_before := _fx_sig()
	var reached := 0
	# заслонки закрыты → новая ночь: картинка сразу открыта, сигнал упора не приходит
	var O: FNOffice = R.office
	var stops_n := [0]
	var on_stop := func(_s: String, _c: bool): stops_n[0] += 1
	O.seal_stop.connect(on_stop)
	R.st.set_seal("l", true)
	R.st.set_seal("t", true)
	await wait(0.8)
	var closed_before: bool = O.seal_k["l"] == 1.0 and O.seal_k["t"] == 1.0
	stops_n[0] = 0
	R.start_night(1)
	var open_now: bool = O.seal_k["l"] == 0.0 and O.seal_k["t"] == 0.0 and absf(O.wall_pivot.rotation.x - FNOffice.SEAL_OPEN_ANGLE) < 0.06 and absf(O.leaf_l.rotation.z - FNOffice.SEAL_OPEN_ANGLE) < 0.06
	await wait(0.3)
	O.seal_stop.disconnect(on_stop)
	ok(closed_before and open_now and stops_n[0] == 0, "заслонки закрыты → новая ночь: в первом же кадре обе открыты (seal_k 0, углы открытые), сигналов упора %d" % stops_n[0])
	for c in causes:
		R.start_night(1)
		await until(func(): return R.state == "night" and R.intro_t <= 0.0, 10.0)
		await wait(1.5)
		if c[0] == "dark":
			R.st.power = 0.0
			R.st.dark_need = 2.0
		else:
			R.st.attack(String(c[0]), String(c[1]))
		var dead: bool = await until(func(): return R.state == "dead", 40.0)
		await wait(1.0)
		if dead:
			reached += 1
		var restart_ms := Time.get_ticks_msec()
		R.start_night(R.night, R.levels)
		await until(func(): return R.state == "night" and R.intro_t <= 0.0, 10.0)
		await wait(3.0)
		var since := float(Time.get_ticks_msec() - restart_ms) / 1000.0      # звук идёт в настоящем времени, часы проверки могут быть быстрее
		for p in R.pool2:
			var pl := p as AudioStreamPlayer
			if pl.playing:
				if pl.get_playback_position() > since + 0.25:
					stuck += 1
				if pl.stream is AudioStreamWAV and (pl.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
					looped += 1
		for p in R.pool3:
			var p3 := p as AudioStreamPlayer3D
			if p3.playing:
				if p3.get_playback_position() > since + 0.25:
					stuck += 1
				if p3.stream is AudioStreamWAV and (p3.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
					looped += 1
		var layers := 0
		for k in R.ambience.layers:
			if (R.ambience.layers[k]["p"] as Node).get("playing"):
				layers += 1
		alive = alive and layers == 11
	var st_stream: AudioStreamWAV = FNSound.get_stream("static")
	ok(reached == 5 and stuck == 0 and looped == 0, "после смерти (звук включён): пять гибелей и «ЕЩЁ РАЗ» — дошли до экрана гибели %d раз, тянущихся звуков %d, зацикленных в пулах %d" % [reached, stuck, looped])
	ok(st_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and st_stream.get_length() <= 1.5, "помехи «static» — вспышка без цикла (%.2f с)" % st_stream.get_length())
	ok(alive, "фон живёт в каждой новой ночи (11 слоёв)")
	R.to_terminal()
	await wait(0.6)
	var silent := true
	for p in R.pool2:
		silent = silent and not (p as AudioStreamPlayer).playing
	for p in R.pool3:
		silent = silent and not (p as AudioStreamPlayer3D).playing
	ok(silent and not main.audio.hush_hold and R.hush_mode == "", "терминал: пулы молчат, мёртвая тишина снята")
	ok(main.audio.vol == vol_keep, "громкости игрока те же, что до раздела")
	FNActors.ensure_ir()
	ok(FNActors._ir_added, "глобальная fn_ir добавлена один раз, повторный вызов пустой")
	ok(R.ambience.fan_spin > 0.99, "перезапуск ночи после отключения питания: вентилятор снова на полной скорости (%.2f)" % R.ambience.fan_spin)
	ok(_fx_sig() == fx_before, "после смертей и отключения питания шины голосов и их эффекты те же: %s" % str(_fx_sig()))
	R.quiet = quiet_keep

## привычки игрока: обитатели подстраиваются под прошлое поведение (чистая логика)
func _habits_check() -> void:
	var hn := FNNight.new()
	hn.setup(4, 99)
	for id in hn.enemies:
		(hn.enemies[id] as FNEnemy).level = 0
	hn.door["l"] = true
	hn.seal["t"] = true
	for k in 600:
		hn._habits(0.1)
	var b: FNBalon = hn.enemies["balon"]
	b.level = 10
	var left := 0
	var right := 0
	for k in 300:
		b.spot = "stage"
		b.transit_to = ""
		b._move(hn)
		if b.spot in ["power", "hall_r"] or b.transit_to == "hall_r":
			right += 1
		elif b.spot in ["arcade", "hall_l"] or b.transit_to == "hall_l":
			left += 1
	ok(float(hn.habit("door_l")) > 0.6 and float(hn.habit("door_r")) < 0.05 and right > left * 2, "привычка «держу левую дверь» (%.0f %% времени): Балон из зала идёт направо %d раз против %d налево" % [float(hn.habit("door_l")) * 100.0, right, left])
	var m: FNMadk1d = hn.enemies["madk1d"]
	m.level = 10
	var dl := 0
	for k in 300:
		m.spot = "vent"
		m._move(hn)
		if m.spot == "duct_l":
			dl += 1
	ok(dl > 200, "привычка «держу верхний люк»: MADK1D лезет левой шахтой %d раз из 300" % dl)
	var c: FNClipper = hn.enemies["clipper"]
	c.level = 8
	c.spot = "hall_l"
	hn.monitor = true
	hn.cam = "hall_l"
	hn.cam_hold = 2.0
	c.move_t = 0.1
	c.tick(hn, 0.05)
	var held: bool = c.spot == "hall_l"
	hn.cam_hold = FNClipper.CAMP_SEC + 0.5
	c.tick(hn, 0.05)
	var left_cam: bool = c.spot == "arcade" and c.rush
	c._move(hn)
	ok(held and left_cam and c.spot in ["hall_l", "door_l"], "CLIPPER: камера держит его в коридоре, но не дольше %.0f с — уходит в игровую и возвращается обычным путём" % FNClipper.CAMP_SEC)
	var g: FNGhost = hn.enemies["ghost"]
	g.level = 5
	hn.hab["mon"] = 20.0
	hn.hab_cam = {"stage": 20.0}
	var corner := 0
	for k in 300:
		g.spot = "away"
		g._move(hn)
		if g.spot == "corner":
			corner += 1
	hn.hab_cam = {"storage": 15.0, "arcade": 8.0}
	var corner2 := 0
	for k in 300:
		g.spot = "away"
		g._move(hn)
		if g.spot == "corner":
			corner2 += 1
	ok(corner > 60 and corner2 == 0, "GHOST: его камеры обходят — приходит в угол будки (%d из 300); смотрят — не приходит (%d)" % [corner, corner2])

## следы прошлых смен: будка от ночи к ночи меняется; событие часа не оставляет тишину висеть
func _dress_check(R: FiveNightsRoot) -> void:
	var o: FNOffice = R.office
	o.dress(0)
	await get_tree().process_frame
	var n0 := o.dress_root.get_child_count()
	var lamp0 := o.lamp_base
	o.dress(2)
	await get_tree().process_frame
	var n2 := o.dress_root.get_child_count()
	o.dress(5)
	await get_tree().process_frame
	var n5 := o.dress_root.get_child_count()
	ok(n0 >= 1 and n2 > n0 + 4 and n5 > n2 + 4 and o.alarm_lamp != null and o.lamp_base < lamp0, "будка меняется по ночам: деталей «следов смен» %d → %d → %d, с четвёртой ночи аварийная лампа, свет тусклее (%.2f → %.2f)" % [n0, n2, n5, lamp0, o.lamp_base])
	await shot("f06b_office_night6")
	R._hour_event(3)
	await wait(0.3)
	var hushed: bool = R.hush_mode == "amb"
	await wait(2.4)
	ok(hushed and R.hush_mode == "", "три часа ночи: гул пропадает на две секунды и возвращается сам")
	o.dress(R.night)

## записи криков: у каждого свои, не меньше трёх, подряд один и тот же не выпадает
func _scream_catalog() -> void:
	var line: Array = []
	var good := true
	for kind in ["balon", "madk1d", "bot", "clipper", "ghost", "mod", "pahan", "dark"]:
		var n := FNSound.scream_count(kind)
		var a := int(FNSound.scream_pick(kind)[1])
		var same := 0
		for k in 12:
			var b := int(FNSound.scream_pick(kind)[1])
			if b == a:
				same += 1
			a = b
		if n < 3 or same > 0:
			good = false
		line.append("%s %d" % [kind, n])
	ok(good, "записи криков: у каждого из восьми свои варианты (%s), подряд один и тот же не играет" % ", ".join(line))
	var lens := {}
	for kind in ["balon", "clipper", "ghost"]:
		lens[kind] = (FNSound.scream_pick(kind)[0] as AudioStream).get_length()
	ok(float(lens["clipper"]) < float(lens["balon"]) and float(lens["balon"]) < float(lens["ghost"]), "длина криков разная: CLIPPER %.1f с < БАЛОН %.1f с < GHOST %.1f с" % [float(lens["clipper"]), float(lens["balon"]), float(lens["ghost"])])

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
	# звук скримера: крик играет и в тихой проверке (мастер-шина заглушена, меряем пик шины Horror); тишина — у
	# каждого своя: проверяем все варианты по очереди
	var hush_want: String = {"balon": "dead", "madk1d": "sfx", "bot": "amb", "clipper": "none", "ghost": "dead", "mod": "dead"}[eid]
	R.scream_force = true
	R.scare.force_hush = hush_want
	R.scare.hush_t0 = 0
	R.scream_at = 0
	var amb_bus := AudioServer.get_bus_index("Ambient")
	var hor_bus := AudioServer.get_bus_index("Horror")
	var amb_before := AudioServer.get_bus_volume_db(amb_bus)
	st.attack(eid, {"balon": "door_l", "madk1d": "vent_t", "bot": "door_r", "clipper": "door_l", "ghost": "stage", "mod": "door_r"}[eid])
	var t0 := GameClock.ms()
	await until(func(): return R.state == "scare", 2.0)
	# момент тишины: фон пропал сразу (если тишина — «мёртвая» или «гул»)
	var amb_silent := 0.0
	if hush_want != "none":
		await until(func(): return R.scare.hush_t0 > 0, 3.0)
		await get_tree().process_frame
		amb_silent = AudioServer.get_bus_volume_db(amb_bus)
	# середина скримера: враг в кадре вплотную
	await until(func(): return R.office.shake > 0.8, 3.0)
	var hit_ms := GameClock.ms()
	var gap_ms: int = R.scream_at - R.scare.hush_t0 if hush_want != "none" else 0
	var sync_ms: int = absi(hit_ms - R.scream_at)
	var peak := -200.0
	for k in 14:
		await get_tree().process_frame
		peak = maxf(peak, maxf(AudioServer.get_bus_peak_volume_left_db(hor_bus, 0), AudioServer.get_bus_peak_volume_right_db(hor_bus, 0)))
	var others := 0
	for q in R.pool2:
		if (q as AudioStreamPlayer).playing and (q as AudioStreamPlayer).stream != null and String((q as AudioStreamPlayer).stream.resource_path).contains("scream_"):
			others += 1
	ok(R.scream_p != null and R.scream_p.playing and R.scream_kind == eid and R.scream_var >= 1 and R.scream_p.bus == "Horror" and others == 0,
		"крик %s: своя запись (вариант %d из %d), один проигрыватель на шине Horror" % [FNData.ENEMIES[eid]["name"], R.scream_var, FNSound.scream_count(eid)])
	ok(sync_ms <= 60, "крик %s начинается в кадр удара (расхождение %d мс)" % [FNData.ENEMIES[eid]["name"], sync_ms])
	ok(peak > -30.0 and peak <= 0.0, "крик %s слышен и не клиппит: пик шины Horror %.1f дБ" % [FNData.ENEMIES[eid]["name"], peak])
	if hush_want == "none":
		ok(R.scare.hush_t0 == 0, "%s: вариант «без тишины» — фон не трогали" % FNData.ENEMIES[eid]["name"])
	else:
		var need_amb: bool = hush_want in ["dead", "amb"]
		ok(gap_ms >= 120 and gap_ms <= 460 and (amb_silent <= -70.0 if need_amb else amb_silent > -60.0),
			"%s: тишина «%s» за %d мс до крика; шина фона в этот миг %.0f дБ (до — %.0f)" % [FNData.ENEMIES[eid]["name"], hush_want, gap_ms, amb_silent, amb_before])
	await wait(0.12)
	await shot("f2_scare_" + eid)
	var r: Rig = R.actors.rigs[eid]
	var close := r.visible and r.global_position.distance_to(R.office.cam.global_position) < 2.2
	var head: Vector3 = R.actors.face_pos(eid)        # лицо (между глаз): у своих моделей кость головы — не лицо
	var in_view := not R.office.cam.is_position_behind(head) and Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(60).has_point(R.office.cam.unproject_position(head))
	print("FIVENIGHTSCHECK   %s: голова %s, камера %s, голова в кадре %s" % [eid, str(head.snapped(Vector3.ONE * 0.01)), str(R.office.cam.global_position.snapped(Vector3.ONE * 0.01)), str(in_view)])
	close = close and in_view
	await until(func(): return R.state == "dead", 6.0)
	var dur := (GameClock.ms() - t0) / 1000.0
	ok(close and R.state == "dead", "скример %s: в 3D вплотную, затем экран гибели (%.1f с)" % [FNData.ENEMIES[eid]["name"], dur])
	# после скримера фон возвращается сам и плавно: тишина не «зависает»
	await wait(2.6)
	var amb_after := AudioServer.get_bus_volume_db(amb_bus)
	ok(R.hush_mode == "" and not main.audio.hush_hold and amb_after > amb_before - 3.0, "%s: после скримера фон вернулся (%.0f дБ, до — %.0f)" % [FNData.ENEMIES[eid]["name"], amb_after, amb_before])
	R.scream_force = false
	R.scare.force_hush = ""
	if R.scream_p != null:
		R.scream_p.stop()

## чистая логика ночи: энергия, двери, маршруты, условия атаки
## левый коридор CAM 4 — сцена: одна, звук совпадает с местом врага, свет не достаёт до двери ниши, враг виден в коридоре
## и не виден из-за угла ниши (сырая картинка камеры без шейдера); снимки c4_*
## пульт скрыт (учёба кончилась): энергия и часы на месте, F1 возвращает пульт и запоминает выбор, действия подписывает toast
func _deck_hidden(R: FiveNightsRoot, _st: FNNight) -> void:
	var UI: FNUI = R.ui
	var pin_was := UI.deck_pin
	var learn_was := UI.deck_learn_left
	var cfg: Dictionary = FNSave.v("settings")
	var cfg_was = cfg.get("deck", null)
	UI.deck_learn_left = 0.0
	UI.deck_pin = false
	await wait(0.3)
	ok(not UI.deck.visible and UI.power_box.visible and UI.clock_box.visible, "учёба кончилась — пульта нет, энергия и часы на месте")
	await key(KEY_F1)
	await wait(0.3)
	var pinned_on: bool = UI.deck.visible and bool(cfg.get("deck", false))
	await key(KEY_F1)
	await wait(0.3)
	ok(pinned_on and not UI.deck.visible and not bool(cfg.get("deck", false)), "F1 показывает пульт и запоминает это в настройках, второй F1 убирает")
	await key(KEY_A)
	await wait(0.25)
	var toast_txt: String = UI.toast_l.text
	var toast_vis: bool = UI.toast_l.visible
	await key(KEY_A)
	await wait(0.4)
	ok(toast_vis and toast_txt == "ЛЕВАЯ ДВЕРЬ — ЗАКРЫТА", "пульта нет — дверь по клавише A подписана на экране: «%s»" % toast_txt)
	UI.deck_pin = true
	UI.toast_t = 0.0
	await wait(0.3)
	await key(KEY_A)
	await wait(0.25)
	var no_toast: bool = not UI.toast_l.visible
	await key(KEY_A)
	await wait(0.4)
	ok(no_toast, "пока пульт на экране, подпись действия не нужна")
	UI.deck_pin = pin_was
	UI.deck_learn_left = learn_was
	if cfg_was == null:
		cfg.erase("deck")
	else:
		cfg["deck"] = cfg_was

func _hall_left(R: FiveNightsRoot, st: FNNight) -> void:
	var F := R.fac
	var hl := F.hall_l
	var found := R.find_children("*", "Node3D", true, false).filter(func(n): return n is FNCorridor)
	var stray := F.get_children().filter(func(n): return n is Node3D and absf((n as Node3D).global_position.x + 3.8) < 0.9 and (n as Node3D).global_position.z > -10.0 and (n as Node3D).global_position.z < -1.0)
	ok(found.size() == 1 and found[0] == hl and F.cams["hall_l"]["pos"] == hl.view["pos"] and stray.is_empty(), "левый коридор — одна сцена Cam4Corridor, камера CAM 4 берётся из неё, кодом в этом объёме ничего не строится (лишних узлов %d)" % stray.size())
	ok((hl.spot_xf[0] as Transform3D).origin.distance_to(FNOffice.point("hall_l")) < 0.75, "шаги в коридоре слышны оттуда же, где враг стоит на камере")
	var door := FNOffice.point("door_l") + Vector3(0, 1, 0)
	var reach := 99.0
	for l in hl.find_children("*", "Light3D", true, false):
		reach = minf(reach, (l as Node3D).global_position.distance_to(door) - ((l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range))
	ok(reach > 0.0, "свет коридора не достаёт до двери ниши (запас %.2f м): у двери враг виден только в луче фонаря" % reach)
	hl.freeze(true)
	st.set_cam("hall_l")
	R.cams.set_cam("hall_l")
	R.cams.sway = 0.0
	var ids := ["balon", "clipper"]
	var saved := {}
	for id in ids:
		var e: FNEnemy = st.enemies[id]
		saved[id] = [e.level, e.spot, e.prev, e.pose, e.look, e.move_t, e.linger]
	var empty := await _hall_frame(R, st, ids, "", "away", 0)
	for id in ids:
		var hall := 100.0
		for p in 3:
			hall = minf(hall, _hall_diff(empty, await _hall_frame(R, st, ids, id, "hall_l", p)))
		var at_door := _hall_diff(empty, await _hall_frame(R, st, ids, id, "door_l", 0))
		ok(hall >= 0.6 and at_door <= 0.02, "%s: в коридоре на CAM 4 виден (мин. %.2f %% кадра; дальняя поза мельче всех), за углом ниши камере не виден (%.3f %%)" % [id, hall, at_door])
		var rig := R.actors.rigs[id] as Node3D
		ok(rig.global_basis.z.dot((R.office.cam.global_position - rig.global_position).normalized()) > 0.5, "%s у левой двери повёрнут лицом к охраннику" % id)
	await _hall_frame(R, st, ids, "balon", "hall_l", 0)
	hl.freeze(false)
	await shot("c4_hall")
	await _hall_frame(R, st, ids, "balon", "hall_l", 2)
	R.actors.creep["balon"] = 1.1
	await wait(0.2)
	await shot("c4_turn")
	for id in ids:
		var e: FNEnemy = st.enemies[id]
		var s: Array = saved[id]
		e.level = s[0]
		e.spot = s[1]
		e.prev = s[2]
		e.pose = s[3]
		e.look = s[4]
		e.move_t = s[5]
		e.linger = s[6]
	R.actors.place_key.clear()

## фон будки (FNAmbience): слои из записей, монитор глушит комнату, угроза запрещает случайные звуки, отключение питания
## останавливает электрику и раскручивает вентиляторы вниз, возвращение — обратно, случайные звуки и пауза
## напряжение ночи: фаза и уровень по состоянию игры, задержанное дыхание, характер камер
func _tension(R: FiveNightsRoot, st_in: FNNight) -> void:
	var st: FNNight = R.st if R.st != null else st_in
	var T := R.tension
	var A := R.ambience
	var C := R.cams
	var cam_keep := [C.cur, C.cam.global_transform, C.cam.fov, C.base_basis, C.sway, C.switch_t, C.mat.get_shader_parameter("noise_k"), C.mat.get_shader_parameter("gain"), C.mat.get_shader_parameter("tint"), C.mat.get_shader_parameter("wobble")]
	var seal_keep := [st.seal["l"], st.seal["t"]]
	var night_keep := [st.t, st.hour, st.broken, st.broken_t, st.break_next, st.fix_t, st.glitches.duplicate(true), st.cam_off_t, st.dark_t, st.stats.duplicate(true), st.usage]
	T.reset()
	var saved := {}
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		saved[id] = [e.level, e.spot, e.prev, e.move_t, e.linger, e.moves, e.door_t, e.pose, e.look]
		e.level = 0
		e.spot = "away"
		e.move_t = 1.0e6
		e.linger = 1.0e6
	var keep := [st.power, st.power_out, st.door["l"], st.door["r"], st.monitor, R.night, A.event_t, A.gust_t]
	st.monitor = false
	st.power = 80.0
	st.power_out = false
	st.door["l"] = false
	st.door["r"] = false
	R.night = 0
	T.rec_t = 0.0
	await wait(1.5)
	ok(T.state == "CALM" and T.level < 0.05, "напряжение: все дома — спокойно (%s, %.2f)" % [T.state, T.level])
	var b: FNEnemy = st.enemies["balon"]
	b.level = 5
	b.moves = 1
	b.spot = "hall_l"
	var up: bool = await until(func(): return T.level > 0.5, 3.0)
	ok(T.state == "NEARBY" and up, "враг в левом коридоре: рядом (%s, %.2f за 3 с)" % [T.state, T.level])
	st.power = 8.0
	await wait(0.8)
	ok(T.state == "CRITICAL", "энергии меньше 12 %%: критично (%s)" % T.state)
	st.power = 80.0
	st.door["l"] = true
	b.spot = "door_l"
	b.door_t = 0.0
	await wait(0.4)
	b.spot = "away"
	await wait(0.5)
	var rec: bool = T.state == "RECOVERY"
	T.rec_t = minf(T.rec_t, 0.5)
	var back: bool = await until(func(): return T.state in ["CALM", "UNEASY"], 20.0)
	ok(rec and back, "дверь закрыта, враг ушёл: передышка, потом спокойнее (%s → %s)" % ["RECOVERY" if rec else "нет", T.state])
	b.level = 0
	st.door["l"] = false
	# отключение проверяем прямым вызовом в один кадр: настоящее отключение запускает игровую логику (темнота, скример)
	st.power_out = true
	T.tick(st, 0.1, 0)
	var blk: bool = T.state == "BLACKOUT"
	st.power_out = false
	T.tick(st, 0.1, 0)
	ok(blk, "питание отключено: фаза BLACKOUT")
	await wait(0.3)
	T.rec_t = 0.0
	await wait(0.3)
	T.rec_t = 0.0
	A.vent_dead = false
	A.vent_spin = 1.0
	A.fan_dead = false
	A.fan_spin = 1.0
	A.duck_k = 0.0
	A.hold_t = 0.0
	var _vent_ok: bool = await until(func(): return A.level("vent") > -40.0, 8.0)
	print("FIVENIGHTSCHECK   дыхание: вентиляция %.1f дБ, питание %s, hush «%s», состояние %s" % [A.level("vent"), str(st.power_out), R.hush_mode, R.state])
	T.reset()
	await wait(1.5)
	A.since_event = 30.0
	A.event_t = 1.0e6
	var v0 := A.level("vent")
	A.start_breath()
	A.breath_len = 5.0
	A.event_t = 0.05
	await wait(3.2)
	var v1 := A.level("vent")
	var quiet: bool = A.since_event > 3.0 or A.breath_done
	ok(v1 <= v0 - 6.0 and A.breath_phase == "hold", "задержанное дыхание: вентиляция упала на %.1f дБ (было %.1f, стало %.1f)" % [v0 - v1, v0, v1])
	await until(func(): return A.breath_phase == "idle", 16.0)
	await wait(1.5)
	var v2 := A.level("vent")
	ok(A.breath_phase == "idle" and absf(v2 - v0) <= 1.0 and A.breath_done and quiet, "после дыхания вентиляция вернулась (%.1f против %.1f дБ), один далёкий звук, случайные не вмешивались" % [v2, v0])
	var all_looks := true
	var applied := true
	var ids: Array = []
	for c in FNData.CAMS:
		ids.append(String(c["id"]))
	ids.append("room9")
	for id in ids:
		if not FNCams.LOOKS.has(id):
			all_looks = false
			continue
		if R.fac.cams.has(id):
			R.cams.set_cam(id)
			if absf(float(R.cams.mat.get_shader_parameter("gain")) - float(FNCams.LOOKS[id]["gain"])) > 0.001:
				applied = false
	ok(all_looks and applied, "у всех камер свой характер (%d записей), set_cam применяет яркость" % ids.size())
	for id in saved:
		var e: FNEnemy = st.enemies[id]
		var sv: Array = saved[id]
		e.level = sv[0]
		e.spot = sv[1]
		e.prev = sv[2]
		e.move_t = sv[3]
		e.linger = sv[4]
		e.moves = sv[5]
		e.door_t = sv[6]
		e.pose = sv[7]
		e.look = sv[8]
	st.power = keep[0]
	st.power_out = keep[1]
	st.door["l"] = keep[2]
	st.door["r"] = keep[3]
	st.monitor = keep[4]
	R.night = keep[5]
	A.event_t = keep[6]
	A.gust_t = keep[7]
	st.seal["l"] = seal_keep[0]
	st.seal["t"] = seal_keep[1]
	C.cur = cam_keep[0]
	C.cam.global_transform = cam_keep[1]
	C.cam.fov = cam_keep[2]
	C.base_basis = cam_keep[3]
	C.sway = cam_keep[4]
	C.switch_t = cam_keep[5]
	C.mat.set_shader_parameter("noise_k", cam_keep[6])
	C.mat.set_shader_parameter("gain", cam_keep[7])
	C.mat.set_shader_parameter("tint", cam_keep[8])
	C.mat.set_shader_parameter("wobble", cam_keep[9])
	C._ir()
	A.breath_phase = "idle"
	A.breath_k = 0.0
	A.breath_t = 0.0
	A.breath_next = randf_range(100.0, 140.0)
	A.breath_done = false
	R.actors.place_key.clear()
	st.t = night_keep[0]
	st.hour = night_keep[1]
	st.broken = night_keep[2]
	st.broken_t = night_keep[3]
	st.break_next = night_keep[4]
	st.fix_t = night_keep[5]
	st.glitches = night_keep[6]
	st.cam_off_t = night_keep[7]
	st.dark_t = night_keep[8]
	st.stats = night_keep[9]
	st.usage = night_keep[10]
	T.reset()

func _ambience(R: FiveNightsRoot, st: FNNight) -> void:
	var A := R.ambience
	var loops := 0
	for k in A.layers:
		var s = (A.layers[k]["p"] as Node).get("stream")
		if s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop and String((s as AudioStreamOggVorbis).resource_path).begins_with(FNAmbience.AMB_DIR):
			loops += 1
	ok(A != null and loops >= 10 and loops == A.layers.size() and FNSound.is_file("knock") and FNSound.is_file("door_down") and not FNSound.is_file("step"), "фон: %d слоёв-петель из assets/audio/fn/amb, стук и ставни — записи, шаги — синтез" % loops)
	var saved := {}
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		saved[id] = [e.level, e.spot, e.prev, e.move_t, e.linger]
		e.spot = "away"
		e.move_t = 1.0e6
		e.linger = 1.0e6
	var keep := [st.monitor, st.power, st.crank_p, st.dark_need, st.emergency_used]
	st.monitor = false
	A.hold_t = 0.0
	A.gust_phase = "idle"
	A.gust_t = 1.0e6
	A.gust = 0.25
	await wait(1.0)
	ok(A.level("vent") > -40.0 and A.room_cutoff > 15000.0, "фон в обычном режиме слышен (вентиляция %.1f дБ), комната открыта (%.0f Гц)" % [A.level("vent"), A.room_cutoff])
	st.monitor = true
	await wait(1.0)
	var open_ok: bool = A.room_cutoff < 2500.0 and A.level("tablet_noise") > -40.0
	st.monitor = false
	await wait(1.2)
	ok(open_ok and A.room_cutoff > 15000.0 and A.level("tablet_noise") <= -55.0, "монитор глушит комнату (срез < 2,5 кГц, шум планшета слышен), закрыли — всё вернулось")
	var b: FNEnemy = st.enemies["balon"]
	b.level = maxi(b.level, 1)
	b.spot = "door_l"
	var near: bool = A.events_blocked(st)
	b.spot = "away"
	A.hold_t = 0.0
	ok(near and not A.events_blocked(st), "враг у двери — случайных звуков нет; ушёл и отсчёт угрозы кончился — разрешены")
	var draft0 := A.level("draft")
	st.power = 0.001
	var went: bool = await until(func(): return st.power_out, 6.0)
	st.dark_need = 60.0
	await wait(1.5)
	var cut_ok: bool = A.level("lamp_hum") <= -55.0 and A.level("crt_whine") <= -55.0 and A.level("panel_hum") <= -55.0 and A.pitch("deskfan") < 0.9
	await wait(5.5)
	var fan_s0 := A.fan_spin
	var fan_stopped: bool = await until(func(): return A.fan_spin < 0.02, 8.0)
	var rotor: Node3D = R.office.desk_fan.rotor
	var fq: Quaternion = rotor.basis.get_rotation_quaternion()
	await wait(0.5)
	var fan_still: float = fq.angle_to(rotor.basis.get_rotation_quaternion())
	ok(fan_stopped and fan_still < 0.001, "отключение питания: вентилятор на столе встал вместе с fan_spin (%.2f → %.3f), за 0,5 с угол не изменился (%.4f рад)" % [fan_s0, A.fan_spin, fan_still])
	var ev_ok := true
	for i in 200:
		var pe := A.pick_event(2, true)
		if pe == "zap" or pe == "relay":
			ev_ok = false
	ok(went and cut_ok and A.level("deskfan") <= -55.0 and A.level("rumble_a") > -30.0 and A.level("draft") >= draft0 and ev_ok, "отключение: электрика молчит, вентилятор остановился (%.0f дБ), гул здания и сквозняк на месте, при тьме нет реле и искр" % A.level("deskfan"))
	st.emergency_used = false
	st.crank_p = 5.99
	st.crank()
	await until(func(): return not st.power_out, 6.0)
	await wait(0.2)
	var fan_early: float = A.fan_spin
	var fq2: Quaternion = rotor.basis.get_rotation_quaternion()
	await wait(1.0)
	var fan_turn: float = fq2.angle_to(rotor.basis.get_rotation_quaternion())
	ok(fan_early < 0.9 and fan_turn > 0.02, "питание вернулось: fan_spin растёт плавно (через 0,2 с %.2f), ротор снова крутится (%.2f рад)" % [fan_early, fan_turn])
	await wait(3.3)
	ok(not st.power_out and A.level("lamp_hum") > -40.0 and A.pitch("deskfan") > 0.95, "питание вернулось: лампа гудит (%.1f дБ), вентилятор раскрутился (%.2f)" % [A.level("lamp_hum"), A.pitch("deskfan")])
	var bad := false
	var prev := ""
	var gaps: Array = []
	for i in 300:
		var pe := A.pick_event(0, false)
		bad = bad or pe == prev or pe in ["knock", "thud", "grind", "groan", "drag"]
		prev = pe
		gaps.append(A.next_gap(0))
	ok(not bad and gaps.min() >= 27.5 and gaps.max() <= 85.0 and gaps.max() / gaps.min() >= 2.0, "случайные звуки: ночью 1 только скрипы, лязг, дребезг, реле и искры, подряд не повторяются, паузы %.0f–%.0f с" % [gaps.min(), gaps.max()])
	var played := A.play_event("clang")
	var far := (A.ev_players[(A.ev_i + A.ev_players.size() - 1) % A.ev_players.size()] as AudioStreamPlayer3D).global_position.distance_to(R.office.cam.global_position)
	ok(played and far >= 8.0, "далёкий лязг звучит издалека (%.0f м)" % far)
	R.set_paused(true)
	var all_paused := A.layers.values().all(func(d): return (d["p"] as Node).get("stream_paused"))
	R.set_paused(false)
	var none_paused := A.layers.values().all(func(d): return not (d["p"] as Node).get("stream_paused"))
	ok(all_paused and none_paused, "пауза останавливает все слои фона, снятие паузы запускает")
	R.hush_begin("dead")
	var quiet_ev := A.ev_players.all(func(p): return not (p as AudioStreamPlayer3D).playing)
	R.hush_end()
	ok(quiet_ev, "мёртвая тишина обрывает случайные звуки")
	ok(R.find_children("*", "Node", true, false).filter(func(n): return n is FNAmbience).size() == 1, "под корнем один FNAmbience")
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		var s: Array = saved[id]
		e.level = s[0]
		e.spot = s[1]
		e.prev = s[2]
		e.move_t = s[3]
		e.linger = s[4]
	st.monitor = keep[0]
	st.power = keep[1]
	st.crank_p = keep[2]
	st.dark_need = keep[3]
	st.emergency_used = keep[4]
	R.actors.place_key.clear()

## сырой кадр камеры (480×270) с одним врагом в точке; id "" — пусто
func _hall_frame(R: FiveNightsRoot, st: FNNight, ids: Array, id: String, spot: String, pose: int) -> Image:
	for k in ids:
		var e: FNEnemy = st.enemies[k]
		e.level = maxi(e.level, 1)
		e.spot = spot if k == id else "away"
		e.prev = ""
		e.pose = pose
		e.look = false
		e.move_t = 1.0e6
		e.linger = 1.0e6
	R.actors.place_key.clear()
	await wait(0.35)
	R.cams.cam.global_basis = R.cams.base_basis
	R.cams.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return R.cams.vp.get_texture().get_image()

## доля пикселей (%), у которых хоть один канал отличается больше чем на 0,06
func _hall_diff(a: Image, b: Image) -> float:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), absf(p.b - q.b)) > 0.06:
				n += 1
	return 100.0 * float(n) / float(a.get_width() * a.get_height())

## аномалии камер в настоящей сцене: силуэт, свет, головы, поворот врага, «за спиной»; снимки a_*
func _anomalies(R: FiveNightsRoot, st: FNNight) -> void:
	var A: FNAnomaly = R.anomaly
	var f: FNFacility = R.fac
	ok(f.figures.size() >= 8 and f.lights.size() >= 7 and f.heads.has("storage") and f.movable.size() >= 2, "у комнат есть точки для аномалий: силуэтов %d, комнат со светом %d, тележка и автомат могут «переехать»" % [f.figures.size(), f.lights.size()])
	var meshes := f.find_children("*", "MeshInstance3D", true, false).size()
	var from_files := f.get_children().filter(func(c): return MGModels.is_glb(c)).size()
	# модель из файла — одна сетка вместо десятков деталей из кода, поэтому считаем и то и другое
	ok(meshes > 1200 or (from_files >= 10 and meshes > 400), "комнаты обставлены: деталей %d, моделей из файлов %d" % [meshes, from_files])
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
	L.t = 100.0      # спокойное начало ночи 2 прошло
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
	var _at := -1.0
	for k in 200:
		st2.step(0.1)
		if st2.outcome != "":
			_at = st2.t
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
	st4.t = 100.0      # спокойное начало ночи 2 прошло
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
	st5.t = 100.0      # спокойное начало ночи 2 прошло
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

## iPod есть только в кампании и на арене: в этом режиме нет ни одного плеера, и стрелка ↑ его не открывает
func no_ipod_here(where: String) -> void:
	await key(KEY_UP)
	await get_tree().process_frame
	var n := 0
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var sc = c.get_script()
		if sc != null and String(sc.resource_path).ends_with("/ipod.gd"):
			n += 1
	ok(n == 0, "%s: iPod нет, стрелка ↑ его не открывает" % where)

## подсказки сбоку (mg_hints.gd): всплыла нужная, не перекрывает надписи игры, мышь не ловит; H — справка и обратно
func hints_here(h, where: String, want: String, ui_root: Node) -> void:
	var t0 := GameClock.ms()
	while h != null and not h.shown_log.has(want) and GameClock.ms() - t0 < 12000:
		await get_tree().process_frame
	ok(h != null and h.shown_log.has(want), "%s: подсказка «%s» всплыла сбоку" % [where, want])
	if h == null:
		return
	await get_tree().process_frame
	if h.card != null and h.card.visible and h.card.modulate.a > 0.3:
		var cr: Rect2 = h.card.get_global_rect()
		var hit := ""
		var labels: Array = []
		MGUI._collect(ui_root, labels)
		for l in labels:
			if not h.is_ancestor_of(l) and (l as Control).get_global_rect().intersects(cr.grow(-2.0)):
				hit = (l as Label).text if l is Label else (l as Button).text
				break
		ok(hit == "", "%s: карточка подсказки не закрывает надписи игры%s" % [where, "" if hit == "" else " (закрыла «%s»)" % hit.left(30)])
		ok(h.card.mouse_filter == Control.MOUSE_FILTER_IGNORE and h.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: подсказка не ловит мышь" % where)
	await key(KEY_H)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(h.guide != null and h.guide.visible and h.guide.get_child(0).get_child_count() > 4, "%s: H — справка «что что делает» сбоку" % where)
	await shot("hints_" + where.replace("«", "").replace("»", "").replace(" ", "_"))
	var n_pages: int = h.pages()
	for i in n_pages - 1:
		await key(KEY_H)
		await get_tree().process_frame
	ok(h.guide != null and h.page == n_pages - 1, "%s: H листает справку (%d стр.)" % [where, n_pages])
	await key(KEY_H)
	await get_tree().process_frame
	ok(h.guide == null and h.page == -1, "%s: H после последней страницы — справка убрана" % where)
