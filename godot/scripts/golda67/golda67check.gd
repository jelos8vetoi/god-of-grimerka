## Проверка приквела «ГОЛДА 67»: `--resolution 1280x720 -- --golda67check=<папка>`.
## Идёт из главного меню как игрок: PLAY → вторая карточка «ГОЛДА 67» → экран режима → подъезд. Проверяет порядок
## режимов, запуск, хаб из моделей (ни одной пропавшей), ходьбу настоящими клавишами, предметы и подсказку [E],
## что сохранение кампании не изменилось, и возврат в меню на карточку приквела.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://golda67_save.json", "user://golda67_save.json.bak"]

var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("GOLDA67CHECK ok: " if cond else "GOLDA67CHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: Key, hold := 0.06) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await wait(hold if down else 0.06)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func save_same() -> bool:
	var p := "user://grimerka_save.json"
	var now = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	return now == kept[p]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	# ================= меню: вторая карточка =================
	var mm = main.menu
	ok(mm != null and mm is Menu, "главное меню открыто")
	var ids: Array = []
	for m in ModeSelect.MODES:
		ids.append(String(m["id"]))
	ok(ids == ["story", "golda67", "training", "race", "microloans", "five_nights"], "порядок режимов: %s" % ", ".join(ids))
	ok(ModeSelect.index_of("golda67") == 1, "«ГОЛДА 67» — вторая карточка")
	var nos: Array = []
	for m in ModeSelect.MODES:
		nos.append(String(m["no"]))
	ok(nos == ["01", "02", "03", "04", "05", "06"], "номера на карточках идут подряд (%s)" % ", ".join(nos))
	mm._select(1, false)
	await key(KEY_ENTER)
	await wait(0.5)
	var ms: ModeSelect = mm.modes
	ok(ms.visible and ms.cards.size() == 6, "экран выбора режима: %d карточек" % ms.cards.size())
	ms.select(0, false, true)
	await wait(0.2)
	await key(KEY_S)
	await wait(0.5)
	ok(ms.sel == 1 and String(ModeSelect.MODES[ms.sel]["id"]) == "golda67", "клавиша S с первой карточки выбирает «ГОЛДА 67»")
	ok(String(ms.desc_title.text).contains("02"), "описание выбранного режима: «%s»" % ms.desc_title.text)
	await wait(0.6)
	await shot("01_card")
	# клик мышью по второй карточке открывает экран приквела, а не тренировку
	ms.select(0, false, true)
	var c: Control = ms.cards[1]["root"]
	var pos: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var mo := InputEventMouseMotion.new()
	mo.position = pos
	mo.global_position = pos
	Input.parse_input_event(mo)
	await wait(0.2)
	ok(ms.sel == 1, "мышь: наведение на вторую карточку выбирает её")
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await wait(0.08)
	await wait(0.4)
	ok(mm.panel != null and mm.panel_rows.size() == 2, "клик по второй карточке открывает экран «ГОЛДА 67» (%d пунктов)" % (mm.panel_rows.size() if mm.panel != null else -1))
	await shot("02_panel")
	# Esc — назад к режимам, Enter — снова экран
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel == null and ms.visible and ms.sel == 1, "Esc — назад на карточку приквела")
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null, "Enter на карточке открывает экран режима")
	# ================= запуск =================
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.golda != null and main.game.golda.world != null, 25.0)
	ok(started, "«ВОЙТИ В ПОДЪЕЗД» запускает режим")
	if not started:
		_finish()
		return
	await wait(3.0)
	var g = main.game
	var G: Golda67 = g.golda
	ok(g.training == null and g.mode == "golda67", "режим приквела (mode = %s), это не арена" % g.mode)
	ok(G.place == "hub" and G.world is G67World, "место — подъезд")
	ok(G.world.missing.is_empty(), "все модели хаба на месте (нет: %s)" % ", ".join(G.world.missing))
	ok(G.world.points.size() >= 9, "предметов хаба: %d" % G.world.points.size())
	ok(G.world.actors.has("g67_dj_flurr") and is_instance_valid(G.world.actors["g67_dj_flurr"]), "dj flürr стоит в подъезде")
	ok(String(g.top_label.text).begins_with("ГОЛДА 67"), "строка вверху: «%s»" % g.top_label.text)
	ok(not g.xp_label.visible, "счётчика опыта кампании нет")
	await shot("03_hub")
	# ================= ходьба настоящими клавишами =================
	var P = g.player
	var p0: Vector3 = P.global_position
	var e2 := InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = true
	Input.parse_input_event(e2)
	await wait(1.2)
	e2 = InputEventKey.new()
	e2.keycode = KEY_W
	e2.physical_keycode = KEY_W
	e2.pressed = false
	Input.parse_input_event(e2)
	await wait(0.3)
	var moved: float = P.global_position.distance_to(p0)
	ok(moved > 1.0, "Пахан идёт по подъезду на W (прошёл %.2f м)" % moved)
	ok(absf(P.global_position.x) < G67World.HUB_X and absf(P.global_position.z) < G67World.HUB_Z, "стены держат: Пахан внутри площадки %s" % str(P.global_position))
	ok(P.global_position.y < 0.6, "Пахан на полу (y = %.2f)" % P.global_position.y)
	await shot("04_walk")
	# ================= предметы и подсказка =================
	var seen := 0
	for pt in G.world.points:
		P.global_position = Vector3(pt["pos"].x, 0.05, pt["pos"].z)
		P.velocity = Vector3.ZERO
		await wait(0.25)
		if G.near == String(pt["id"]) and G.prompt.visible and String(G.prompt.text).contains(String(pt["title"])):
			seen += 1
		else:
			print("GOLDA67CHECK   нет подсказки у «%s» (near = %s)" % [pt["id"], G.near])
	ok(seen == G.world.points.size(), "подсказка [E] появляется у каждого предмета (%d из %d)" % [seen, G.world.points.size()])
	var tv: Dictionary = G.point("tv")
	P.global_position = Vector3(tv["pos"].x, 0.05, tv["pos"].z)
	await wait(0.3)
	await shot("05_prompt")
	var n0 := G.events.size()
	await key(KEY_E)
	await wait(0.3)
	ok(G.events.size() > n0 and G.events[-1] == ["use", "tv"], "клавиша E у телевизора срабатывает")
	P.global_position = Vector3(0.0, 0.05, 0.0)
	await wait(0.3)
	ok(G.near == "" and not G.prompt.visible, "вдали от предметов подсказки нет")
	# снимки хаба с разных точек
	for v in [["06_view_back", Vector3(0, 0.05, 3.0), PI], ["07_view_front", Vector3(0, 0.05, -2.5), 0.0], ["08_view_left", Vector3(2.0, 0.05, 0.5), PI * 0.5], ["09_view_right", Vector3(-2.0, 0.05, 0.5), -PI * 0.5]]:
		P.global_position = v[1]
		P.face = v[2]
		g.cam_yaw = v[2]
		await wait(0.8)
		await shot(String(v[0]))
	# ================= пауза и сохранения =================
	g.set_paused(true)
	await wait(0.6)
	ok(get_tree().paused and not G.prompt.visible, "пауза работает, подсказка скрыта")
	await shot("10_pause")
	g.set_paused(false)
	await wait(0.4)
	ok(save_same(), "сохранение кампании не изменилось")
	ok(not FileAccess.file_exists("user://golda67_save.json") or kept["user://golda67_save.json"] == FileAccess.get_file_as_string("user://golda67_save.json"), "проверка не пишет сохранение приквела игрока")
	# ================= выход =================
	g._to_menu()
	var back: bool = await until(func(): return main.menu != null and is_instance_valid(main.menu) and main.game == null, 10.0)
	await wait(1.0)
	ok(back, "выход в меню")
	if back:
		ok(main.menu.modes.visible and main.menu.modes.sel == 1, "после выхода открыт выбор режима на карточке «ГОЛДА 67»")
		await shot("11_back")
	_finish()

func _finish() -> void:
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	AudioServer.set_bus_mute(0, false)
	print("GOLDA67CHECK ok" if fails == 0 else "GOLDA67CHECK ОШИБКА: %d" % fails)
	get_tree().quit()
