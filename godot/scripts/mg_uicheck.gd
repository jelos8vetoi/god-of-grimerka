## Проверка интерфейсов мини-игр: `--resolution 1600x900 -- --uicheck=<папка>` (`--ui-only=ml|jobs|fn|long` — часть,
## `--ui-sizes=1600x900,1280x720` — свои размеры окна).
## Обходит все экраны «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» (утро, событие, день, подработки, займы, карта долгов, магазин,
## вещи, бизнес, дерево развития, ЛЕГЕНДА РАЙОНА, подтверждение, пауза, уведомления, вечер, звонок коллектора и ящик
## стола, концовка), HUD и итог пяти подработок и «5 НОЧЕЙ С ПАХАНОМ» (терминал и его разделы, заставка ночи, будка,
## звонок, планшет камер, сломанная камера, пауза, темнота с генератором, гибель, 6 AM) — в каждом размере окна:
## 16:9 (1600×900, 1280×720, 1920×1080, 2560×1440), 16:10 (1440×900) и 21:9 (1680×720). На каждом — MGUI.audit:
## текст за экраном, за своей панелью, наложения, обрезанный текст. Отдельно — «длинные тексты»: те же экраны
## с нарочно длинными названиями, описаниями и суммами. Мышь и клавиатура: наведение и клик по пунктам, клавиши.
## Сохранения игрока не пишутся (persist = false) и сверяются байт в байт. Снимки — <экран>_<ширина>x<высота>.png.
## Итог: «UICHECK ok».
extends Node

const KEEP := ["user://grimerka_save.json", "user://microloans_save.json", "user://microloans_save.json.bak", "user://five_nights_save.json", "user://five_nights_save.json.bak"]
const SIZES := [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1440, 900), Vector2i(1680, 720)]
const LONG := "Очень длинное название пункта для проверки переполнения интерфейса мини-игр"
const LONG_T := "Очень длинное описание: Пахан взял ещё один заём под 2,5 % в день, чтобы перекрыть предыдущий, и теперь должен 1 234 567 ₽ сразу четырём конторам, а до срока осталось 2 дн."

var main
var out := ""
var fails := 0
var notes := 0
var kept := {}
var sizes: Array = []
var only := ""
var shots_n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	MLSave.persist = false
	FNSave.persist = false
	AudioServer.set_bus_mute(0, true)
	sizes = SIZES.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ui-only="):
			only = a.substr(10)
		elif a.begins_with("--ui-sizes="):
			sizes = []
			for s in a.substr(11).split(","):
				var wh := s.split("x")
				sizes.append(Vector2i(int(wh[0]), int(wh[1])))
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("UICHECK ok: " if cond else "UICHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	shots_n += 1

func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.05)

func _resize(sz: Vector2i) -> void:
	var w := get_window()
	if w.size != sz:
		w.size = sz
		for i in 5:
			await get_tree().process_frame

## экран во всех размерах окна: аудит вёрстки и снимок; freeze — на время обхода игра стоит на паузе
func visit(name: String, node: Node, freeze := false) -> void:
	if freeze:
		get_tree().paused = true
	var bad := 0
	var real := ""
	for sz in sizes:
		await _resize(sz)
		await get_tree().process_frame
		var ws := get_window().size
		if ws != sz and not real.contains("%dx%d" % [sz.x, sz.y]):
			real += " (окно %dx%d дало %dx%d)" % [sz.x, sz.y, ws.x, ws.y]
		var issues: Array = MGUI.audit(node, get_viewport().get_visible_rect()) if is_instance_valid(node) else ["экран пропал"]
		for s in issues:
			print("UICHECK   %s @%dx%d: %s" % [name, sz.x, sz.y, String(s).replace("\n", " / ")])
		bad += issues.size()
		await shot("%s_%dx%d" % [name, sz.x, sz.y])
	await _resize(sizes[0])
	if freeze:
		get_tree().paused = false
	notes += bad
	ok(bad == 0, "%s: %d размеров окна, замечаний %d%s" % [name, sizes.size(), bad, real])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	await _resize(sizes[0])
	var scr := DisplayServer.screen_get_size()
	print("UICHECK   экран %dx%d, размеры окна: %s" % [scr.x, scr.y, ", ".join(sizes.map(func(s): return "%dx%d" % [s.x, s.y]))])
	if only in ["", "ml", "jobs", "long"]:
		await _microloans()
	if only in ["", "fn", "long"]:
		await _five_nights()
	_finish()

# ======================= ПАХАН НАБРАЛ МИКРОЗАЙМОВ =======================
func _microloans() -> void:
	main.start_minigame("microloans")
	var started: bool = await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is MicroloansRoot, 15.0)
	ok(started, "«Микрозаймы» запущены")
	if not started:
		return
	var R: MicroloansRoot = main.minigame
	await wait(1.5)
	var e := R.econ
	var U := R.ui
	var C: MLCareer = e.career
	C.from_dict({})
	e.new_game(4242)
	e.event_today = ""
	U.show_phase()
	await wait(0.5)
	if only in ["", "ml"]:
		await _ml_screens(R, e, U, C)
	if only in ["", "jobs"]:
		await _ml_jobs(R, e, U)
	if only in ["", "long"]:
		await _ml_long(R, e, U)
	R.quit_to_menu()
	await until(func(): return main.menu != null, 8.0)
	await wait(0.5)

func _ml_screens(R: MicroloansRoot, e: MLEconomy, U: MLUI, C: MLCareer) -> void:
	await visit("ml01_morning", U)
	e.event_today = String(MLData.EVENTS.keys()[0])
	e.event_done = false
	U.show_phase()
	await wait(0.4)
	await visit("ml02_morning_event", U)
	e.event_done = true
	e.phase = "day"
	e.actions = MLData.ACTIONS
	U.show_phase()
	await wait(0.4)
	await visit("ml03_day", U)
	# клавиатура и мышь на экране дня: выбор ходит, наведение выбирает, клик открывает
	var s0 := U.sel
	await key(KEY_S)
	ok(U.sel == s0 + 1, "клавиша S переводит выбор на следующий пункт")
	var row: Control = U.rows[3]["box"]
	var mm := InputEventMouseMotion.new()
	mm.position = row.get_global_rect().get_center() * get_viewport().get_screen_transform().get_scale()
	mm.global_position = mm.position
	Input.parse_input_event(mm)
	await wait(0.15)
	ok(U.sel == 3, "наведение мыши выбирает пункт (выбран %d)" % U.sel)
	U.jobs()
	await wait(0.4)
	await visit("ml04_jobs", U)
	await key(KEY_D)
	await key(KEY_S)
	ok(U.sel != 0, "в сетке карточек WASD ходит по карточкам (выбрана %d)" % U.sel)
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(U.screen == "day", "Esc возвращает из раздела на экран дня")
	U.offers()
	await wait(0.4)
	await visit("ml05_offers", U)
	U.debt_flow()
	await wait(0.4)
	await visit("ml06_debts", U)
	U._flow_keys(KEY_E)
	await wait(0.2)
	await visit("ml07_debts_pay", U)
	U.pay_amount = 0
	U.flow_sel = e.active().slice(0, 2).map(func(L): return int(L["id"]))
	U._flow_side()
	await wait(0.2)
	await visit("ml08_debts_merge", U)
	U.flow_sel = []
	U.shop()
	await wait(0.4)
	await visit("ml09_shop", U)
	e.inventory = [0, 1, 2, 3, 4, 5, 6, 7, 0, 3]
	U.items_screen()
	await wait(0.4)
	await visit("ml10_items", U)
	e.money = 300000
	for b in ["workshop", "cleaning"]:
		for k in 2:
			var c := C.biz_up(b, e.money)
			e.money -= maxi(0, c)
		e.money -= maxi(0, C.hire(b, e.money))
	R.biz_visuals()
	U.biz_screen()
	await wait(0.4)
	await visit("ml11_biz", U)
	C.d["points"] = 6
	U.dev_tree()
	await wait(0.6)
	await visit("ml12_tree", U)
	var T := U.tree_ui
	T._pick(String(T.order[T.order.size() - 1]))
	await wait(0.2)
	await visit("ml13_tree_last_node", U)
	for id in T.order:                                   # подпись выбранного узла — у каждого узла, по очереди
		T._pick(String(id))
		await get_tree().process_frame
		var bad: Array = MGUI.audit(U, get_viewport().get_visible_rect())
		if not bad.is_empty():
			notes += bad.size()
			fails += 1
			print("UICHECK ОШИБКА: дерево, узел %s: %s" % [id, bad[0]])
			break
	U.legend_screen()
	await wait(0.4)
	await visit("ml14_legend", U)
	U._confirm_prestige()
	await wait(0.4)
	await visit("ml15_confirm", U)
	ok(U.sel == 0 and String(U.rows[0]["text"]).begins_with("НЕТ"), "подтверждение: по умолчанию выбран безопасный ответ")
	U.show_phase()
	await wait(0.2)
	await key(KEY_ESCAPE)
	await wait(0.4)
	ok(U.screen == "pause", "Esc на экране дня открывает паузу")
	await visit("ml16_pause", U)
	U.show_phase()
	await wait(0.3)
	U.notify("Срок по займу «Быстроденьги 24» — завтра. К оплате 12 400 ₽.", "bad")
	U.notify("Подработка: уборка подъезда. Зачислено 1 850 ₽.", "money")
	U.notify("Звонок: «Срочно Финанс» ждёт ответа.", "call")
	await wait(0.4)
	await visit("ml17_notifications", U)
	await wait(4.5)
	for L in e.active().slice(0, 2):
		L["due"] = e.day
		L["status"] = "overdue"
		L["overdue"] = 2
	e.phase = "evening"
	U.show_phase()
	await wait(0.4)
	await visit("ml18_evening", U)
	var tgt: Dictionary = e.active()[0]
	var N: MLNegotiation = U.negotiate(int(tgt["id"]), func(): pass)
	await wait(1.6)
	ok(not U.topbar.visible, "во время звонка строка показателей убрана — экран звонка один")
	await visit("ml19_call", U, true)
	await until(func(): return not N.speaking, 4.0)
	N.play(3)
	await wait(0.2)
	await visit("ml20_call_drawer", U, true)
	N.pick_doc(0)
	N._end()
	await wait(1.4)
	ok(U.topbar.visible, "после звонка строка показателей вернулась")
	e.ending = "pit"
	U.ending()
	await wait(0.4)
	await visit("ml21_ending", U)
	e.ending = ""
	e.phase = "day"
	e.actions = MLData.ACTIONS
	U.show_phase()
	await wait(0.3)

func _ml_jobs(_R: MicroloansRoot, e: MLEconomy, U: MLUI) -> void:
	e.ending = ""
	e.phase = "day"
	for jid in MLData.JOB_ORDER:
		e.actions = MLData.ACTIONS
		e.stress = 20
		e.rep = maxi(e.rep, 60)                 # «Звукарь» открыт с репутации 50: заказ теперь нельзя взять в обход условия
		e.job_pending = {}                      # прошлый заказ проверки не сдавался — он не должен мешать следующему
		var J: MLJob = U.run_job(String(jid), 0.9)
		await wait(3.0)
		if not is_instance_valid(J):
			ok(false, "подработка %s закрылась раньше времени" % jid)
			continue
		await visit("job_%s_hud" % jid, J, true)
		J.bot = -1.0
		if J is MLJob3D:
			(J as MLJob3D).show_result(0.82, ["убрано 92 % · контейнер 60 % · шланг 80 %", "серия ×4: +18 % к оплате", "задето проводов: 2"])
		else:
			J.finish(0.82)
		await wait(0.5)
		await visit("job_%s_result" % jid, J, true)
		await until(func(): return U.overlay == null, 6.0)
		await wait(0.4)

func _ml_long(R: MicroloansRoot, e: MLEconomy, U: MLUI) -> void:
	# длинные названия, описания, значения и метки — во всех трёх видах раздела; огромные суммы в строке показателей
	e.ending = ""
	e.phase = "day"
	e.money = 9999999
	for L in e.active():
		L["balance"] = 2345678.0
	e.changed.emit()
	var mk := func(n: int, thumbs: bool) -> Array:
		var items: Array = []
		for k in n:
			var spec := {"icon": "doc", "sub": LONG_T, "value": "до 1 234 567 ₽", "tag": "очень длинная метка действия", "col": MGUI.GOLD}
			if thumbs:
				spec["thumb"] = "job_repair"
			items.append([LONG.to_upper() + " %d" % (k + 1), func(): pass, (func(): return "не хватает денег и ещё двух условий сразу") if k == 1 else Callable(), spec])
		return items
	U.screen = "day"
	U.open(LONG.to_upper(), [LONG_T, LONG_T], mk.call(14, false))
	await wait(0.4)
	await visit("long_ml_list", U)
	U.open(LONG.to_upper(), [LONG_T], mk.call(9, true), 0.0, "cards")
	await wait(0.4)
	await visit("long_ml_cards", U)
	U.open(LONG.to_upper(), [LONG_T], mk.call(30, true), 0.0, "grid")
	await wait(0.4)
	await visit("long_ml_grid", U)
	U.show_phase()
	await wait(0.3)
	for k in 3:
		U.notify(LONG_T, ["bad", "money", "info"][k])
	await wait(0.4)
	await visit("long_ml_notifications", U)
	await wait(4.5)
	U.debt_flow()
	await wait(0.4)
	await visit("long_ml_debts", U)
	var N: MLNegotiation = U.negotiate(int(e.active()[0]["id"]), func(): pass)
	N.text_full = LONG_T + " " + LONG_T
	N.promise = 1234567
	await wait(2.8)
	await visit("long_ml_call", U, true)
	N._end()
	await wait(1.4)
	e.actions = MLData.ACTIONS
	var J: MLJob = U.run_job("podezd", 0.9)
	await wait(2.0)
	if is_instance_valid(J):
		J.title_l.text = LONG.to_upper()
		J.hint_l.text = LONG
		if J is MLJob3D:
			(J as MLJob3D).tip_l.text = LONG
		await wait(0.2)
		await visit("long_job_hud", J, true)
		J.bot = -1.0
		(J as MLJob3D).show_result(0.3, [LONG_T, LONG_T, LONG_T])
		await wait(0.5)
		await visit("long_job_result", J, true)
		await until(func(): return U.overlay == null, 6.0)
	e.money = 3000
	R.econ.changed.emit()
	await wait(0.3)

# ======================= 5 НОЧЕЙ С ПАХАНОМ =======================
func _five_nights() -> void:
	main.start_minigame("five_nights")
	var started: bool = await until(func(): return main.minigame != null and is_instance_valid(main.minigame) and main.minigame is FiveNightsRoot, 15.0)
	ok(started, "«5 ночей» запущены")
	if not started:
		return
	var R: FiveNightsRoot = main.minigame
	await wait(1.5)
	FNSave.put("custom", true)
	FNSave.put("night6", true)
	FNSave.put("unlocked", 5)
	var M: FNMenu = R.menu
	if only in ["", "fn"]:
		M.open_main()
		await wait(0.3)
		await visit("fn01_terminal", M)
		var s0 := M.sel
		await key(KEY_S)
		ok(M.sel == posmod(s0 + 1, M.rows.size()), "терминал: клавиша S переводит выбор")
		var b: Control = M.box.get_child(4)
		var mm := InputEventMouseMotion.new()
		mm.position = b.get_global_rect().get_center() * get_viewport().get_screen_transform().get_scale()
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		await wait(0.15)
		ok(M.sel == 4, "терминал: наведение мыши выбирает пункт (выбран %d)" % M.sel)
		for sc in [["fn02_nights", M.open_nights], ["fn03_custom", M.open_custom], ["fn04_archive", M.open_extras], ["fn05_notes", M.open_notes], ["fn06_bios", M.open_bios], ["fn07_endings", M.open_endings], ["fn08_stats", M.open_stats], ["fn09_settings", M.open_settings]]:
			(sc[1] as Callable).call()
			await wait(0.3)
			await visit(String(sc[0]), M)
		await key(KEY_ESCAPE)
		await wait(0.2)
		ok(M.screen == "main", "терминал: Esc возвращает в главный список")
	if only == "long" or only == "":
		var rows: Array = []
		for k in 24:
			rows.append({"text": LONG.to_upper() + " %d" % k, "act": func(): pass, "info": LONG_T + "\n\n" + LONG_T + "\n\n" + LONG_T})
		M._show("long", rows)
		await wait(0.3)
		await visit("long_fn_terminal", M)
		M.open_main()
	R.start_night(0)
	await wait(0.9)
	if only in ["", "fn"]:
		await visit("fn10_night_card", R.ui)
	var night_on: bool = await until(func(): return R.state == "night" and R.st != null and R.intro_t <= 0.0, 14.0)
	ok(night_on, "ночь началась")
	if not night_on:
		return
	var st: FNNight = R.st
	await wait(4.5)
	if only in ["", "fn"]:
		await visit("fn11_office", R.ui)
		R.ui.sub("Алло? Это ночная смена? Слушай внимательно: двери жрут энергию, держи их закрытыми только когда кто-то рядом.", true)
		R.ui.alarm("ЛЕВАЯ ДВЕРЬ ОТКРЫТА СИСТЕМОЙ")
		R.ui.msg("Спокойно. Это просто старое здание.", 30.0)
		await wait(0.3)
		await visit("fn12_office_call", R.ui)
		R.ui.sub("")
		R.ui.msg("", 0.0)
		await key(KEY_SPACE)
		await wait(0.7)
		ok(st.monitor and R.ui.tablet.visible, "Пробел поднимает планшет")
		await visit("fn13_camera", R.ui)
		var fr := R.ui.feed.get_global_rect()
		var over := 0
		for id in R.ui.map_btns:
			if fr.intersects((R.ui.map_btns[id] as Control).get_global_rect()):
				over += 1
		ok(over == 0 and not fr.intersects(R.ui.side.get_global_rect()), "планшет: карта камер и панель — рядом с картинкой, а не поверх неё")
		var vs := get_viewport().get_visible_rect().size
		ok(fr.size.x * fr.size.y > vs.x * vs.y * 0.5, "планшет: картинка камеры занимает больше половины экрана (%d %%)" % int(fr.size.x * fr.size.y / (vs.x * vs.y) * 100.0))
		var cb: Button = R.ui.map_btns["arcade"]
		var cl := InputEventMouseButton.new()
		cl.button_index = MOUSE_BUTTON_LEFT
		cl.position = cb.get_global_rect().get_center() * get_viewport().get_screen_transform().get_scale()
		cl.global_position = cl.position
		for down in [true, false]:
			var c2 := cl.duplicate() as InputEventMouseButton
			c2.pressed = down
			Input.parse_input_event(c2)
			await wait(0.08)
		ok(st.cam == "arcade", "планшет: клик по кнопке карты переключает камеру (%s)" % st.cam)
		(st.enemies["bot"] as FNBot).ping_left = 9.0
		st.set_monitor(true)
		await until(func(): return R.ui.tablet_k >= 1.0, 2.0)
		await wait(0.2)
		await visit("fn14_camera_ping_lure", R.ui)
		st.set_monitor(true)
		st.broken = st.cam
		st.broken_t = 0.0
		await until(func(): return R.ui.tablet_k >= 1.0, 2.0)
		await wait(0.2)
		await visit("fn15_camera_broken", R.ui)
		st.broken = ""
		await key(KEY_SPACE)
		await wait(0.6)
		R.set_paused(true)
		await wait(0.3)
		await visit("fn16_pause", R.ui)
		ok(get_viewport().gui_get_focus_owner() == R.ui.pause_first, "пауза: первая кнопка в фокусе — можно с клавиатуры")
		R.set_paused(false)
		st.power = 0.2
		await until(func(): return st.power_out, 6.0)
		await wait(0.6)
		await visit("fn17_dark_generator", R.ui)
		R._dead("balon", "door")
		await wait(1.0)
		await visit("fn18_dead", R.ui)
		R.ui.six_card(4200, "Смена кончилась. Пахан жив. Пока.", "Пять ночей позади. Журнал смен закрыт.\n\nОТКРЫТА НОЧЬ 6.")
		await wait(3.4)
		await visit("fn19_six_am", R.ui)
	if only in ["", "long"]:
		R.ui.dead_card(LONG.to_upper(), LONG_T + " " + LONG_T, [["ЕЩЁ РАЗ", func(): pass], ["В МЕНЮ ОХРАНЫ", func(): pass]])
		await wait(1.0)
		await visit("long_fn_dead", R.ui)
		R.ui.six_card(1234567, LONG_T, LONG_T + "\n\n" + LONG_T)
		await wait(3.4)
		await visit("long_fn_six", R.ui)
		R.ui.clear_card()
		R.ui.sub(LONG_T + " " + LONG_T, true)
		R.ui.msg(LONG_T, 30.0)
		R.ui.alarm(LONG.to_upper())
		await wait(0.3)
		await visit("long_fn_office", R.ui)
	R.to_terminal()
	await wait(0.6)
	R.quit_to_menu()
	await until(func(): return main.menu != null, 8.0)
	await wait(0.5)

func _finish() -> void:
	var same := true
	for p in KEEP:
		var now = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
		if (now == null) != (kept[p] == null) or (now != null and now != kept[p]):
			same = false
			print("UICHECK   изменён файл %s" % p)
	ok(same, "сохранения игрока не тронуты (байт в байт)")
	MLSave.persist = true
	FNSave.persist = true
	AudioServer.set_bus_mute(0, false)
	print("UICHECK   снимков: %d, замечаний вёрстки: %d" % [shots_n, notes])
	print("UICHECK ok" if fails == 0 else "UICHECK ОШИБКА: %d" % fails)
	get_tree().quit()
