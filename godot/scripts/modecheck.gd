## Проверка главного меню и экрана «ВЫБОР РЕЖИМА»: `--resolution 1280x720 -- --modecheck=<папка>`.
## Идёт как игрок: клавиатура (W/S, стрелки, Enter, Esc), мышь (наведение, клик), геймпад (крестовина, A, B),
## CONTINUE, PLAY → STORY MODE (CONTINUE / NEW GAME / LOAD GAME / НАЗАД), TRAINING ARENA, VACUUM RACING, SETTINGS,
## EXTRAS, возвраты назад, разные размеры окна (16:9, 4:3, 21:9, маленькое) — всё в пределах экрана, сохранение
## игрока не меняется (файл тот же байт в байт; NEW GAME запускается и сохранение возвращается). Последним — EXIT.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://grimerka_training.json"]

var main
var out := ""
var fails := 0
var kept := {}
var exit_pressed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("MODECHECK ok: " if cond else "MODECHECK ОШИБКА: ") + text)

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

func pad(b: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.06)

func click(c: Control) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await wait(0.12)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await wait(0.06)

func hover(c: Control) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await wait(0.15)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s_%dx%d.png" % [name, img.get_width(), img.get_height()]))

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func save_same() -> bool:
	var p: String = KEEP[0]
	if kept[p] == null:
		return not FileAccess.file_exists(p)
	return FileAccess.file_exists(p) and FileAccess.get_file_as_string(p) == kept[p]

## вернуть сохранение игрока как было (после NEW GAME, который пишет своё)
func restore_save() -> void:
	var p: String = KEEP[0]
	if kept[p] == null:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	else:
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(kept[p])
		f.close()

func panel_names(mm) -> Array:
	var r: Array = []
	for row in mm.panel_rows:
		var tx = row["text"]
		r.append(String(tx.call()) if tx is Callable else String(tx))
	return r

## пункт экрана с таким текстом
func pick(mm, name: String) -> bool:
	var names := panel_names(mm)
	var i := names.find(name)
	if i < 0:
		return false
	mm._panel_select(i, false)
	return true

## все видимые элементы экрана режимов внутри окна
func inside(mm) -> bool:
	var vr := get_viewport().get_visible_rect()
	var all := true
	for c in mm.modes.cards:
		var r: Rect2 = (c["root"] as Control).get_global_rect()
		var tl: Rect2 = (c["title"] as Label).get_global_rect()
		if not vr.grow(2.0).encloses(tl) or not vr.grow(2.0).has_point(r.position):
			all = false
	for l in [mm.modes.desc_title, mm.modes.desc_text]:
		if not vr.grow(2.0).encloses((l as Control).get_global_rect()):
			all = false
	return all

func to_menu() -> void:
	if main.game != null and is_instance_valid(main.game):
		main.game._to_menu()
	await until(func(): return main.menu != null and is_instance_valid(main.menu) and main.game == null, 10.0)
	await wait(1.0)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	var win := get_window()
	var size0 := win.size
	# ================= 1. главное меню =================
	var mm = main.menu
	ok(mm != null and mm is Menu, "главное меню открыто")
	var names: Array = []
	for it in mm.ITEMS:
		names.append(String(it[0]))
	ok(names == ["CONTINUE", "PLAY", "SETTINGS", "EXTRAS", "EXIT"], "главный список: %s" % ", ".join(names))
	var has_save: bool = mm.has_save
	ok(mm.sel == (0 if has_save else 1), "по умолчанию выбран %s" % ("CONTINUE" if has_save else "PLAY"))
	await shot("01_main")
	# клавиатура по главному списку
	var s0: int = mm.sel
	await key(KEY_S)
	ok(mm.sel == (s0 + 1) % names.size(), "S — вниз")
	await key(KEY_W)
	await key(KEY_DOWN)
	await key(KEY_UP)
	ok(mm.sel == s0, "W и стрелки — вверх/вниз")
	await pad(JOY_BUTTON_DPAD_DOWN)
	ok(mm.sel == (s0 + 1) % names.size(), "геймпад: крестовина вниз")
	await pad(JOY_BUTTON_DPAD_UP)
	# ================= 2. CONTINUE =================
	mm._select(0, false)
	if not has_save:
		await key(KEY_ENTER)
		await wait(0.5)
		ok(main.game == null and mm.panel == null and not mm.launching, "CONTINUE без сохранения ничего не запускает")
	# ================= 3. PLAY → экран режимов =================
	mm._select(1, false)
	await key(KEY_ENTER)
	await wait(0.5)
	var ms: ModeSelect = mm.modes
	ok(ms.visible and ms.cards.size() == 6, "PLAY открывает экран выбора режима (%d карточек)" % ms.cards.size())
	var titles: Array = []
	for m in ModeSelect.MODES:
		titles.append(String(m["title"]))
	ok(titles == ["STORY MODE", "ГОЛДА 67", "TRAINING ARENA", "VACUUM RACING", "PAHAN MICROLOANS", "FIVE NIGHTS WITH PAHAN"], "режимы: %s" % ", ".join(titles))
	ok((mm.list as Control).modulate.a < 0.05, "главный список ушёл с экрана")
	await shot("02_modes_story")
	await key(KEY_S)
	await wait(0.45)
	ok(ms.sel == 1 and String(ModeSelect.MODES[ms.sel]["id"]) == "golda67", "S — второй режим: ГОЛДА 67")
	ok(ms.arts[1]["vp"] != null and (ms.arts[1]["vp"] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS, "композиция «ГОЛДА 67» рисуется, когда она выбрана")
	await shot("02b_modes_golda67")
	await key(KEY_S)
	await wait(0.45)
	ok(ms.sel == 2 and String(ModeSelect.MODES[ms.sel]["id"]) == "training", "третий — TRAINING ARENA")
	ok(ms.arts[2]["vp"] != null and (ms.arts[2]["vp"] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS, "композиция арены рисуется, когда она выбрана")
	await shot("03_modes_training")
	await key(KEY_DOWN)
	await wait(0.45)
	ok(ms.sel == 3, "стрелка — четвёртый режим")
	await shot("04_modes_race")
	await wait(0.4)
	ok((ms.arts[2]["vp"] as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED, "невыбранная композиция не рисуется (кадр не тратится)")
	await key(KEY_S)
	await wait(0.45)
	ok(ms.sel == 4, "пятый — ПАХАН НАБРАЛ МИКРОЗАЙМОВ")
	await shot("04b_modes_microloans")
	await key(KEY_S)
	await wait(0.45)
	ok(ms.sel == 5 and (ms.arts[5]["vp"] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS, "шестой — 5 НОЧЕЙ С ПАХАНОМ, его композиция рисуется")
	await shot("04c_modes_five_nights")
	await key(KEY_S)
	ok(ms.sel == 0, "по кругу — снова первый")
	# быстрое листание (как колесом или зажатой клавишей): прежние композиции не остаются поверх новой
	for n in 9:
		await key(KEY_S if n % 3 != 2 else KEY_W)
		await wait(0.07)
	await wait(0.6)
	var ghost: Array = []
	for k in ms.arts.size():
		if k != ms.sel and (ms.arts[k]["root"] as Control).modulate.a > 0.02:
			ghost.append(String(ModeSelect.MODES[k]["id"]))
	ok(ghost.is_empty() and (ms.arts[ms.sel]["root"] as Control).modulate.a > 0.98, "быстрое листание: видна только выбранная композиция (лишние: %s)" % str(ghost))
	await shot("04d_modes_fast_switch")
	while ms.sel != 0:
		await key(KEY_S)
		await wait(0.1)
	# мышь: наведение выбирает, клик открывает
	await hover(ms.cards[1]["root"])
	ok(ms.sel == 1, "мышь: наведение на карточку выбирает режим")
	await hover(ms.cards[0]["root"])
	ok(ms.sel == 0, "мышь: наведение на STORY MODE")
	# ================= 4. STORY MODE =================
	await click(ms.cards[0]["root"])
	await wait(0.3)
	var sn := panel_names(mm)
	var want_story: Array = (["CONTINUE"] if has_save else []) + ["NEW GAME", "LOAD GAME", "НАЗАД"]
	ok(mm.panel != null and sn == want_story, "клик по STORY MODE: %s" % ", ".join(sn))
	await shot("05_story")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel == null and ms.visible, "Esc со STORY MODE — назад на экран режимов")
	# ================= 5. NEW GAME =================
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null, "Enter на STORY MODE открывает экран сюжета")
	if has_save:
		pick(mm, "NEW GAME")
		await key(KEY_ENTER)
		await wait(0.3)
		ok(panel_names(mm) == ["НАЧАТЬ ЗАНОВО", "ОТМЕНА"] and mm.panel_sel == 1, "NEW GAME при сохранении — подтверждение, по умолчанию «ОТМЕНА»")
		await shot("06_new_confirm")
		await key(KEY_ENTER)
		await wait(0.3)
		ok(panel_names(mm) == want_story and save_same(), "«ОТМЕНА» возвращает на экран сюжета, сохранение не тронуто")
		pick(mm, "NEW GAME")
		await key(KEY_ENTER)
		await wait(0.3)
		await key(KEY_ESCAPE)
		await wait(0.3)
		ok(panel_names(mm) == want_story, "Esc в подтверждении — тоже на экран сюжета")
	# ================= 6. LOAD GAME =================
	pick(mm, "LOAD GAME")
	await key(KEY_ENTER)
	await wait(0.3)
	var ln := panel_names(mm)
	ok(mm.panel != null and ln.back() == "НАЗАД" and (ln.has("ЗАГРУЗИТЬ") == has_save), "LOAD GAME: %s" % ", ".join(ln))
	await shot("07_load")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(panel_names(mm) == want_story, "Esc с LOAD GAME — на экран сюжета")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel == null and ms.visible and save_same(), "сохранение игрока не изменилось, пока ходили по экранам")
	# запуск из сюжета: LOAD GAME → ЗАГРУЗИТЬ (или NEW GAME без сохранения)
	await key(KEY_ENTER)
	await wait(0.3)
	if has_save:
		pick(mm, "LOAD GAME")
		await key(KEY_ENTER)
		await wait(0.3)
		pick(mm, "ЗАГРУЗИТЬ")
	else:
		pick(mm, "NEW GAME")
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.player != null, 15.0)
	ok(started, "запуск из STORY MODE: игра пошла (%s)" % ("LOAD GAME" if has_save else "NEW GAME"))
	if started and has_save:
		var d = JSON.parse_string(String(kept[KEEP[0]]))
		ok(int(main.game.ch) == int(d.get("ch", 0)) and int(main.game.xp) == int(d.get("xp", 0)), "загружено то же сохранение: глава %d, опыт %d" % [int(main.game.ch) + 1, int(main.game.xp)])
	await wait(3.0)
	await shot("08_story_game")
	await to_menu()
	restore_save()
	mm = main.menu
	ms = mm.modes
	ok(mm.has_save == has_save and save_same(), "после выхода в меню сохранение на месте")
	# NEW GAME при сохранении: правда начинается новая игра, сохранение потом возвращаем
	if has_save:
		mm.open_modes(0)
		await wait(0.4)
		await key(KEY_ENTER)
		await wait(0.3)
		pick(mm, "NEW GAME")
		await key(KEY_ENTER)
		await wait(0.3)
		pick(mm, "НАЧАТЬ ЗАНОВО")
		await key(KEY_ENTER)
		await wait(0.2)
		var ng: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.player != null, 15.0)
		ok(ng and int(main.game.ch) == 0 and int(main.game.step) <= 0, "NEW GAME → «НАЧАТЬ ЗАНОВО»: новая игра с первой главы (глава %d, шаг %d, опыт %d)" % [int(main.game.ch) + 1, int(main.game.step), int(main.game.xp)] if ng else "NEW GAME не запустился")
		await wait(2.0)
		await to_menu()
		restore_save()
		main.show_menu()
		await wait(1.0)
		mm = main.menu
		ms = mm.modes
		ok(mm.has_save and save_same(), "старое сохранение возвращено и читается меню")
	# ================= 7. TRAINING ARENA =================
	mm._select(1, false)
	await key(KEY_ENTER)
	await wait(0.4)
	ms.select(ModeSelect.index_of("training") - 1, false)
	await key(KEY_S)
	await wait(0.3)
	await pad(JOY_BUTTON_A)
	await wait(0.3)
	ok(mm.panel != null and mm.panel_rows.size() == 4 and mm.panel_sel == 2, "геймпад A на TRAINING ARENA: прежний экран выбора героя и стиля")
	await shot("09_training")
	await pad(JOY_BUTTON_B)
	await wait(0.3)
	ok(mm.panel == null and ms.visible and ms.sel == ModeSelect.index_of("training"), "геймпад B — назад на экран режимов")
	await key(KEY_ENTER)
	await wait(0.3)
	mm.train_hero = "pahan"
	mm.train_style = "vozduh"
	await key(KEY_ENTER)
	var tr: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.training != null and main.game.training.targets.size() >= 3, 20.0)
	ok(tr, "TRAINING ARENA запускается с экрана режимов")
	await wait(2.0)
	await shot("10_training_game")
	await to_menu()
	mm = main.menu
	ms = mm.modes
	ok(save_same(), "после арены сохранение не изменилось")
	# ================= 9. VACUUM RACING =================
	mm.open_modes(ModeSelect.index_of("race"))
	await wait(0.5)
	await key(KEY_ENTER)
	await wait(0.3)
	if mm.race_ready():
		ok(mm.panel != null or (mm.get("race_menu") != null), "VACUUM RACING открывает меню гонок")
	else:
		ok(mm.panel != null and panel_names(mm) == ["НАЗАД"], "VACUUM RACING ещё не готов: честная плашка и одна кнопка «НАЗАД»")
		ok(String(ms.cards[2]["tag_l"].text) == "СКОРО", "на карточке гонок — «СКОРО»")
	await shot("11_race")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel == null and ms.visible, "Esc с гонок — на экран режимов")
	# ================= 8. назад на главный список =================
	var back_l: Label = ms.get_children().filter(func(c): return c is Label and (c as Label).text == "◀ НАЗАД")[0]
	await hover(back_l)
	await click(back_l)
	await wait(0.4)
	ok(not ms.visible and (mm.list as Control).modulate.a > 0.9, "клик по «◀ НАЗАД» — главный список вернулся")
	mm.open_modes(0)
	await wait(0.3)
	await key(KEY_ESCAPE)
	await wait(0.4)
	ok(not ms.visible and mm.panel == null and main.game == null, "Esc на экране режимов — на главный список, игра не закрылась")
	# ================= 10–11. SETTINGS, EXTRAS =================
	for it in [[2, "SETTINGS", "12_settings"], [3, "EXTRAS", "13_extras"]]:
		mm._select(int(it[0]), false)
		await key(KEY_ENTER)
		await wait(0.3)
		ok(mm.panel != null and panel_names(mm).back() == "НАЗАД", "%s открывается (%d пунктов)" % [it[1], mm.panel_rows.size()])
		await shot(String(it[2]))
		await key(KEY_ESCAPE)
		await wait(0.3)
		ok(mm.panel == null and not ms.visible, "%s: Esc — назад на главный список" % it[1])
	# ================= 14. разные размеры окна =================
	if win.mode == Window.MODE_WINDOWED:
		for sz in [Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(2560, 1080), Vector2i(1152, 648)]:
			win.size = sz
			await wait(0.4)
			mm.open_modes(ModeSelect.index_of("race"))
			await wait(0.6)
			var vr := get_viewport().get_visible_rect()
			ok(inside(mm), "окно %dx%d (холст %dx%d): карточки и описание в кадре" % [sz.x, sz.y, int(vr.size.x), int(vr.size.y)])
			await shot("14_modes")
			mm.close_modes()
			await wait(0.3)
		win.size = size0
		await wait(0.3)
	# ================= 15. сохранения =================
	ok(save_same(), "сохранение игрока байт в байт как до проверки")
	# ================= 12. EXIT =================
	_restore()
	print("MODECHECK итог: ошибок %d" % fails)
	mm._select(4, false)
	exit_pressed = true
	await key(KEY_ENTER)
	await wait(3.0)
	ok(false, "EXIT не закрыл игру")
	print("MODECHECK ОШИБКА: %d" % fails)
	get_tree().quit()

func _restore() -> void:
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	AudioServer.set_bus_mute(0, false)

## EXIT закрыл игру: дерево разбирается — последнее слово проверки
func _exit_tree() -> void:
	if exit_pressed:
		print("MODECHECK ok: EXIT закрывает игру")
		print("MODECHECK ok" if fails == 0 else "MODECHECK ОШИБКА: %d" % fails)
