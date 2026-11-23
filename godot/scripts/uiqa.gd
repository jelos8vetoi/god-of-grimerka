## Сквозная проверка интерфейса: `-- --uiqa=<папка>` (с `--resolution WxH` — на нужном размере окна).
## Идёт как игрок: главное меню → все его экраны → Continue → диалог, HUD, iPod → пауза и все вкладки → настройки →
## 20 открытий паузы подряд → экран поражения, мастерская → выход в меню. Жмёт настоящие клавиши и мышь,
## снимает каждый экран, меряет FPS и число узлов, печатает «UIQA ok / ОШИБКА» и итог.
## Сохранение и настройки игрока запоминаются в начале и возвращаются в конце; звук на время проверки выключен.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json"]

var main
var out := ""
var fails := 0
var screens := 0
var buttons := 0
var moves := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else (null as Variant)
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("UIQA ok: " if cond else "UIQA ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.06)

func click(pos: Vector2) -> void:
	var w: Vector2 = get_viewport().get_final_transform() * pos
	var m := InputEventMouseMotion.new()
	m.position = w
	m.global_position = w
	Input.parse_input_event(m)
	await wait(0.06)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = w
		e.global_position = w
		Input.parse_input_event(e)
		await wait(0.06)

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var vs := get_viewport().get_texture().get_image()
	vs.save_png(out.path_join("%dx%d_%s.png" % [vs.get_width(), vs.get_height(), nm]))
	screens += 1

## Один цикл паузы: открыть, показать страницу, закрыть — с ожиданием по состоянию, а не по часам.
func cycle(pm, page: int) -> void:
	await key(KEY_ESCAPE)
	var t0 := GameClock.ms()
	while not (pm.is_open and get_tree().paused) and GameClock.ms() - t0 < 3000:
		await get_tree().process_frame
	await wait(0.7)
	pm._open_page(page)
	await wait(0.1)
	pm._close_card()
	await key(KEY_ESCAPE)
	t0 = GameClock.ms()
	while (get_tree().paused or pm.is_open) and GameClock.ms() - t0 < 3000:
		await get_tree().process_frame
	await wait(0.15)

func centre(c: Control) -> Vector2:
	return c.get_global_transform() * (c.size * 0.5)

## Средний FPS за секунду при выключенной синхронизации.
func fps(sec := 1.0) -> float:
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < int(sec * 1000000.0):
		await get_tree().process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t0) / 1000000.0)

func _run() -> void:
	await wait(2.0)
	var vs := get_viewport().get_visible_rect().size
	print("UIQA окно %s, холст %s" % [str(get_window().size), str(vs)])
	# ================= главное меню =================
	var mm = main.menu
	ok(mm != null and mm is Menu, "главное меню открыто")
	await shot("menu_main")
	var has_save: bool = mm.has_save
	var s0: int = mm.sel
	await key(KEY_S)
	ok(mm.sel == (s0 + 1) % mm.ITEMS.size(), "меню: S — вниз")
	await key(KEY_W)
	ok(mm.sel == s0, "меню: W — вверх")
	await key(KEY_DOWN)
	await key(KEY_UP)
	ok(mm.sel == s0, "меню: стрелки работают")
	moves += 4
	# PLAY → экран выбора режима: у каждого режима свой экран, Esc — назад
	mm._select(1, false)
	await key(KEY_ENTER)
	await wait(0.5)
	ok(mm.modes.visible, "меню: PLAY открывает экран выбора режима")
	await shot("menu_modes")
	for k in ModeSelect.MODES.size():
		mm.modes.select(k, false)
		await wait(0.4)
		await key(KEY_ENTER)
		await wait(0.3)
		ok(mm.panel != null, "режим «%s»: Enter открывает экран" % ModeSelect.MODES[k]["title"])
		await shot("menu_mode_" + String(ModeSelect.MODES[k]["id"]))
		buttons += mm.panel_rows.size()
		await key(KEY_ESCAPE)
		await wait(0.2)
		ok(mm.panel == null and mm.modes.visible and main.game == null, "режим «%s»: Esc — назад к режимам" % ModeSelect.MODES[k]["title"])
		moves += 3
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(not mm.modes.visible, "экран режимов: Esc — назад на главный список")
	for it in [[2, "settings"], [3, "extras"]]:
		mm._select(int(it[0]), false)
		await key(KEY_ENTER)
		await wait(0.3)
		ok(mm.panel != null, "меню: Enter открывает «%s»" % mm.ITEMS[int(it[0])][0])
		await shot("menu_" + String(it[1]))
		var n: int = mm.panel_rows.size()
		var p0: int = mm.panel_sel
		await key(KEY_S)
		ok(n < 2 or mm.panel_sel != p0, "«%s»: S двигает выбор (%d пунктов)" % [mm.ITEMS[int(it[0])][0], n])
		buttons += n
		await key(KEY_ESCAPE)
		await wait(0.2)
		ok(mm.panel == null and main.game == null, "«%s»: Esc закрывает, игра не запустилась" % mm.ITEMS[int(it[0])][0])
		moves += 3
	# подтверждение новой игры: Enter по умолчанию — «Отмена», сохранение цело
	if has_save:
		mm.open_modes(0)
		await wait(0.3)
		await key(KEY_ENTER)
		await wait(0.2)
		mm._panel_select(1, false)            # STORY MODE: CONTINUE, NEW GAME, LOAD GAME, НАЗАД
		await key(KEY_ENTER)
		await wait(0.2)
		await key(KEY_ENTER)
		await wait(0.2)
		ok(mm.panel != null and String(mm.panel_rows[0]["text"]) == "CONTINUE" and main.game == null and FileAccess.get_file_as_string(KEEP[0]) == kept[KEEP[0]], "новая игра: «Отмена» по умолчанию — назад к сюжету, сохранение не тронуто")
		await key(KEY_ESCAPE)
		await wait(0.2)
		await key(KEY_ESCAPE)
		await wait(0.3)
		moves += 2
	# настройки: каждая строка меняется и возвращается
	mm._select(2, false)
	await key(KEY_ENTER)
	await wait(0.3)
	var changed := 0
	var total := 0
	for i in mm.panel_rows.size():
		var r: Dictionary = mm.panel_rows[i]
		if r["adj"] == null:
			continue
		var t0: String = String((r["text"] as Callable).call())
		if t0.begins_with("ПОЛНЫЙ ЭКРАН") or t0.begins_with("РАЗМЕР ОКНА"):
			continue                      # окно посреди проверки не трогаем
		total += 1
		mm.panel_sel = i
		# сначала вниз, потом обратно вверх: значение на максимуме тоже меняется и возвращается
		await key(KEY_A)
		var t1: String = String((r["text"] as Callable).call())
		await key(KEY_D)
		var t2: String = String((r["text"] as Callable).call())
		if t1 == t0:                       # было на минимуме: пробуем вверх и назад
			await key(KEY_D)
			t1 = String((r["text"] as Callable).call())
			await key(KEY_A)
			t2 = String((r["text"] as Callable).call())
		if t1 != t0 and t2 == t0:
			changed += 1
		else:
			print("UIQA   строка не меняется или не возвращается: ", t0, " → ", t1, " → ", t2)
	ok(changed == total and total >= 9, "настройки: меняются клавишами A/D %d из %d строк" % [changed, total])
	buttons += total
	# сохранение и перезагрузка настроек
	var fov0: float = float(Opts.v("fov"))
	Opts.put("fov", 70.0)
	Opts.put("sens", 1.3)
	Opts.loaded = false
	ok(float(Opts.v("fov")) == 70.0 and absf(float(Opts.v("sens")) - 1.3) < 0.001, "настройки читаются из файла заново (угол 70, чувствительность 130%)")
	Opts.put("fov", fov0)
	Opts.put("sens", 1.0)
	# последний пункт виден после прокрутки
	mm._panel_select(mm.panel_rows.size() - 1, false)
	await wait(0.2)
	var last: Label = mm.panel_rows[mm.panel_rows.size() - 1]["label"]
	var sc := last.get_parent().get_parent() as ScrollContainer
	ok(sc.get_global_rect().encloses(last.get_global_rect()), "настройки: последний пункт «Назад» виден в списке")
	await shot("menu_settings_bottom")
	await key(KEY_ESCAPE)
	await wait(0.2)
	# мышь: наведение выбирает, клик открывает
	var row: Control = mm.rows[1]["root"]
	await click(centre(row))
	await wait(0.4)
	ok(mm.sel == 1 and mm.modes.visible, "меню: клик мышью по PLAY открывает выбор режима")
	await click(centre(mm.modes.cards[0]["root"]))
	await wait(0.3)
	ok(mm.panel != null, "мышь: клик по STORY MODE открывает экран сюжета")
	await key(KEY_ESCAPE)
	await wait(0.2)
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(not mm.modes.visible, "Esc, Esc — назад на главный список")
	buttons += 6
	await key(KEY_ESCAPE)
	await wait(0.2)
	# ================= игра =================
	mm._select(0 if has_save else 1, false)
	if has_save:
		await key(KEY_ENTER)
	else:
		mm.launch(false, 0)
	await wait(2.5)
	var game = main.game
	# запуск из меню идёт через кинематографичный переход: ждём, пока камера займёт место и откроется ввод
	var tq := GameClock.ms()
	while game != null and (game.intro_busy() or (main.intro_fx != null and main.intro_fx.busy)) and GameClock.ms() - tq < 10000:
		await get_tree().process_frame
	ok(game != null and not game.intro_busy(), "переход из меню завершился, управление отдано")
	ok(game != null and main.menu == null, "%s запускает игру, меню убрано" % ("Continue" if has_save else "New Game"))
	if game == null:
		_finish()
		return
	var pm = game.pause_panel
	await shot("game_dialog")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(not get_tree().paused, "Esc в диалоге паузу не открывает")
	var n2 := 0
	while game.mode == "dlg" and n2 < 200:
		await key(KEY_ENTER)
		n2 += 1
	await wait(1.2)
	await shot("game_hud")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var f_game := await fps(1.5)
	# iPod: Esc работает внутри него, паузу не открывает
	await key(KEY_UP)
	var t_ip := GameClock.ms()
	while not game.player.pod.buds_in() and GameClock.ms() - t_ip < 12000:
		await get_tree().process_frame
	await wait(1.2)
	ok(game.ipod.opened, "↑ открывает iPod")
	await shot("game_ipod")
	await key(KEY_ENTER)
	await wait(0.4)
	await key(KEY_ESCAPE)
	await wait(0.4)
	ok(game.ipod.opened and not get_tree().paused, "Esc при открытом iPod — назад внутри iPod, не пауза")
	await key(KEY_UP)
	await wait(2.2)
	ok(not game.ipod.captures_gameplay_input(), "iPod закрыт, управление свободно")
	moves += 4
	# ================= пауза =================
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	await key(KEY_ESCAPE)
	await wait(0.9)
	ok(get_tree().paused and pm.is_open, "Esc открывает паузу")
	await shot("pause_main")
	var f_pause := await fps(1.5)
	for i in 6:
		pm._select(i, false)
		await key(KEY_ENTER)
		await wait(0.35)
		ok(pm.card != null, "пауза: Enter открывает «%s»" % pm.TABS[i][0])
		await shot("pause_%d_%s" % [i, ["status", "development", "group", "quest", "music", "system"][i]])
		# ничего не вылезает за карточку и за экран
		var bad := ""
		for c in pm.card_body.find_children("*", "Label", true, false):
			var l := c as Label
			if not l.is_visible_in_tree() or l.text == "":
				continue
			var gr := l.get_global_rect()
			var inside_scroll := false
			var par := l.get_parent()
			while par != null and par != pm.card_body:
				if par is ScrollContainer:
					inside_scroll = true
				par = par.get_parent()
			if not inside_scroll and (gr.end.x > pm.card_body.get_global_rect().end.x + 2.0 or gr.end.y > pm.card_body.get_global_rect().end.y + 2.0):
				bad += " [" + l.text.left(24) + "]"
		ok(bad == "", "«%s»: текст не выходит за карточку%s" % [pm.TABS[i][0], bad])
		var nrows: int = pm.card_rows.size()
		buttons += nrows
		var c0: int = pm.card_sel
		await key(KEY_S)
		ok(nrows < 2 or pm.card_sel != c0, "«%s»: S двигает выбор (%d пунктов)" % [pm.TABS[i][0], nrows])
		if i == 5:
			pm._card_select(nrows - 1)
			await wait(0.2)
			var lastr: Label = pm.card_rows[nrows - 1]["label"]
			var scr := lastr.get_parent().get_parent() as ScrollContainer
			ok(scr.get_global_rect().encloses(lastr.get_global_rect()), "«СИСТЕМА»: последний пункт виден после прокрутки")
			await shot("pause_5_system_bottom")
		await key(KEY_ESCAPE)
		await wait(0.2)
		ok(pm.card == null and pm.is_open and get_tree().paused and pm.sel == i, "«%s»: Esc — назад к вкладкам, выбор на месте" % pm.TABS[i][0])
		moves += 3
	var f_switch_min := 9999.0
	for i in 6:
		pm._select(i, false)
		pm._open_page(i)
		f_switch_min = min(f_switch_min, await fps(0.25))
		pm._close_card()
	# угол обзора из паузы действует в игре
	pm._open_page(5)
	await wait(0.2)
	for i in pm.card_rows.size():
		var tx = pm.card_rows[i]["text"]
		if tx is Callable and String(tx.call()).begins_with("УГОЛ ОБЗОРА"):
			pm.card_sel = i
	await key(KEY_D)
	await key(KEY_D)
	ok(float(Opts.v("fov")) == fov0 + 4.0, "пауза: D меняет угол обзора (%d°)" % int(Opts.v("fov")))
	pm._close_card()
	# мышь по вкладке
	await click(centre(pm.tabs[1]["root"]))
	await wait(0.3)
	ok(pm.sel == 1 and pm.card != null, "пауза: клик по вкладке РАЗВИТИЕ открывает её")
	pm._close_card()
	await key(KEY_ESCAPE)
	await wait(0.7)
	ok(not get_tree().paused and absf(game.cam.fov - (fov0 + 4.0)) < 1.0, "после паузы камера с новым углом обзора (%.0f°)" % game.cam.fov)
	Opts.put("fov", fov0)
	# 20 открытий и закрытий подряд
	for i in 20:
		await cycle(pm, i % 6)
	await wait(0.5)
	var mem_mid := Performance.get_monitor(Performance.MEMORY_STATIC)
	for i in 10:                         # ещё десять: первый показ страниц уже позади, расти памяти не с чего
		await cycle(pm, i % 6)
	await wait(0.5)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem1 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var f_after := await fps(1.5)
	ok(not get_tree().paused and not pm.is_open, "20 циклов паузы: игра идёт, меню закрыто")
	ok(absi(nodes1 - nodes0) < 40, "узлы после 20 циклов: %d → %d" % [nodes0, nodes1])
	ok(absf(mem1 - mem_mid) < 4.0 * 1048576.0, "память на циклах 21–30 не растёт: %.1f → %.1f МБ" % [mem_mid / 1048576.0, mem1 / 1048576.0])
	ok(f_after > f_game * 0.65, "FPS после 30 циклов не просел: %.0f → %.0f" % [f_game, f_after])   # замер шумный: порог с запасом
	print("UIQA производительность: игра %.0f FPS · пауза %.0f FPS · переключение вкладок (минимум за 0,25 с) %.0f FPS · после 20 циклов %.0f FPS · память %.1f → %.1f МБ (первый показ страниц) · узлы %d → %d · сирот %d" % [f_game, f_pause, f_switch_min, f_after, mem0 / 1048576.0, mem1 / 1048576.0, nodes0, nodes1, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	# ================= мастерская, поражение =================
	var mode0: String = game.mode
	var step0: int = game.step
	game._open_shop()
	await wait(0.4)
	await shot("game_shop")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(not get_tree().paused and game.panel != null, "Esc при открытой мастерской паузу не открывает")
	game._close_panel()
	game.mode = mode0
	game.step = step0
	MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	game.player.inv = 0.0
	game.tag.down[game.tag.mate()] = true    # напарник выбыл: иначе Tag Team передаст бой ему и поражения не будет
	game.player.take_damage(game.player.hp + 50.0, game.player.global_position + Vector3(1, 0, 0))
	await wait(3.0)
	ok(game.panel != null and game.over, "поражение: окно «Пахан упал»")
	await shot("game_defeat")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(not get_tree().paused, "Esc на экране поражения паузу не открывает")
	game._retry()
	game.tag.down[game.tag.mate()] = false
	await wait(0.6)
	n2 = 0
	while game.mode == "dlg" and n2 < 200:
		await key(KEY_ENTER)
		n2 += 1
	await wait(1.0)
	# ================= выход в меню =================
	await key(KEY_ESCAPE)
	await wait(0.9)
	pm._open_page(5)
	await wait(0.2)
	for i in pm.card_rows.size():
		if pm.card_rows[i]["text"] is String and String(pm.card_rows[i]["text"]) == "В ГЛАВНОЕ МЕНЮ":
			pm.card_sel = i
	await key(KEY_ENTER)
	await wait(0.3)
	await shot("pause_confirm_menu")
	ok(pm.card != null and pm.card_rows.size() == 2 and get_tree().paused, "выход в меню спрашивает подтверждение")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(pm.card != null and main.game != null, "«Остаться» по умолчанию возвращает в «Систему»")
	pm._confirm_menu()
	await wait(0.2)
	pm.card_sel = 1
	await key(KEY_ENTER)
	await wait(1.5)
	ok(main.menu != null and main.menu is Menu and not get_tree().paused, "выход в главное меню: меню открыто, пауза снята")
	await shot("menu_after_game")
	moves += 6
	_finish()

func _finish() -> void:
	# вернуть сохранение и настройки игрока
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	print("UIQA итог: ошибок %d · снимков %d · пунктов и кнопок %d · переходов %d" % [fails, screens, buttons, moves])
	get_tree().quit()
