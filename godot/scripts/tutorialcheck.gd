## Проверка боевого обучения (tutorial.gd, tutorial_card.gd): -- --tutorialcheck=<папка>, запускать с --resolution 1280x720.
## Первая карточка в первом бою, игра стоит (враг и герой не двигаются, урона нет), случайное нажатие в первые доли секунды
## не закрывает, Enter и клик по «ЗАКРЫТЬ» закрывают и снимают паузу; клавиши — из InputMap (переназначение видно);
## порядок (предшественники, «мгновенные» карточки: воздух, добивание), командные карточки не раньше смены героя;
## шесть карточек стилей (оба героя); чужая пауза не снимается; в диалоге карточек нет; сохранение (ключ "tut") и
## старое сохранение без ключа; список в паузе и повтор. Снимки — в папку. В конце «TUTORIALCHECK ok» или «… ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
var TU

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("TUT ok: " if c else "TUT ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## ожидание в реальном времени — идёт и на паузе, и при замедлении
func real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm))

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := InputEventKey.new()
	u.physical_keycode = code
	u.keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)

func click(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await frames(2)

func card_text(c: Node) -> String:
	var s := ""
	for n in c.find_children("*", "Label", true, false):
		s += (n as Label).text + "\n"
	return s

func key_label(c: Node, action: String) -> String:
	var n := c.find_child("Key_" + action, true, false)
	return (n as Label).text if n != null else ""

## бой с одним спокойным врагом перед героем
func stage(hero := "pahan") -> void:
	game.ch = 0
	game._load_chapter(false)
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	TU = game.tutorial
	if P.hero != hero:
		game.tag.tag_cd = 0.0
		game.swap_heroes()
		await frames(40)
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.auto_input = {}
	P.combat.interrupt()
	game.tag.auto_assist = false
	game.tag.tag_cd = 0.0
	game.buddy.wait = 999.0
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	game.enemies = []
	await frames(2)
	game.mode = "fight"

func foe(dist := 3.5, hp := 9999.0):
	var e = game._make_enemy("bot", "", P.global_position + Vector3(0, 0, -dist))
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

func wait_card(limit := 4.0) -> bool:
	var t0 := GameClock.ms()
	while TU.card == null and GameClock.ms() - t0 < int(limit * 1000.0):
		await frames(1)
	return TU.card != null

func close_enter() -> void:
	await real(TutorialCard.LOCK + 0.1)
	await key(KEY_ENTER)
	await real(0.25)

func _run() -> void:
	await stage()
	TU.force = 0                     # разделы 1–11 — карточки (как в паузе); практика — раздел 12
	ok(TU.on, "обучение включено в проверке")
	TU.reset()
	var e = foe()
	# ---- 1. первая карточка в первом бою ----
	var got: bool = await wait_card(5.0)
	ok(got and TU.shown.size() == 1 and String(TU.shown[0]) == "light", "в первом бою первой появилась «ЛЁГКАЯ АТАКА» (%s)" % [str(TU.shown)])
	ok(get_tree().paused and TU.own_pause, "игра стоит, паузу поставило обучение")
	if TU.card != null:
		ok(key_label(TU.card, "attack") == "ЛКМ", "клавиша на плашке из InputMap: «%s»" % key_label(TU.card, "attack"))
		ok(card_text(TU.card).contains("ЗАКРЫТЬ"), "кнопка «ЗАКРЫТЬ» есть")
	await real(0.35)
	await shot("t01_light.png")
	# ---- 2. пока карточка открыта, мир стоит, ввод в бой не идёт ----
	var ep: Vector3 = e.global_position
	var ehp: float = e.hp
	var pp: Vector3 = P.global_position
	var php: float = P.hp
	var swings: int = TU.attacks
	await key(KEY_SPACE)                     # случайное нажатие в первые доли секунды — не закрывает
	ok(TU.card != null, "нажатие сразу после появления карточку не закрывает")
	await click(Vector2(5, 5))
	await real(0.6)
	ok(e.global_position.distance_to(ep) < 0.001 and e.hp == ehp and P.global_position.distance_to(pp) < 0.001 and P.hp == php, "пока карточка открыта, враг и герой не двигаются, урона нет")
	ok(TU.attacks == swings and P.state == "move", "клик мимо кнопки не стал ударом")
	await key(KEY_ENTER)
	await real(0.25)
	ok(TU.card == null and not get_tree().paused, "Enter закрыл карточку и снял паузу")
	ok(P.combat.buffered() == "", "буфер ударов пуст после закрытия")
	# ---- 3. следующая — карточка текущего стиля; закрыть кликом по кнопке ----
	TU.since = 99.0
	got = await wait_card(3.0)
	ok(got and String(TU.shown.back()) == "style_vozduh", "вторая — карточка стиля «Балон» (%s)" % str(TU.shown))
	await real(0.4)
	await shot("t02_style_vozduh.png")
	if TU.card != null:
		var b: Control = TU.card.btn
		await real(TutorialCard.LOCK)
		# окно 1280×720, а кадр игры растянут из 1600×900: событие мыши — в координатах окна
		await click(get_viewport().get_final_transform() * (b.get_global_transform_with_canvas() * (b.size * 0.5)))
		await real(0.25)
	ok(TU.card == null and not get_tree().paused, "клик по «ЗАКРЫТЬ» закрыл карточку")
	# ---- 4. порядок: тяжёлая после лёгкой; командные — не раньше смены героя ----
	TU.on = false                             # условия проверяем вызовом pick(), сами карточки не всплывают
	TU.since = 99.0
	TU.attacks = 3
	ok(TU.pick() == "heavy", "после лёгкой и стиля — «ТЯЖЁЛАЯ АТАКА» («%s»)" % TU.pick())
	var base := ["light", "heavy", "combo", "dodge", "block", "charge", "throw", "heat", "finisher", "air", "adlib", "rage", "styles", "style_vozduh", "style_bottles", "style_tyaga812", "boss_open", "overdrive"]
	TU.seen = {}
	for id in base:
		TU.seen[id] = true
	var p2: String = TU.pick()
	ok(p2 == "tag", "командные карточки ждут «СМЕНУ ГЕРОЯ»: следующая — «%s»" % p2)
	TU.seen.erase("styles")
	p2 = TU.pick()
	ok(not p2 in ["tag", "assist", "air_tag", "team_moves"], "без «СМЕНЫ СТИЛЯ» командных нет («%s»)" % p2)
	TU.seen["styles"] = true
	TU.seen["tag"] = true
	p2 = TU.pick()
	ok(p2 == "style_skateboard" or p2 == "assist", "после смены героя — стили madk1d и дуэт («%s»)" % p2)
	# ---- 5. мгновенные: враг в воздухе, враг готов к добиванию ----
	TU.seen = {"light": true, "style_vozduh": true, "heavy": true}
	TU.since = 99.0
	var hl := HitInfo.new()
	hl.damage = 1.0
	hl.launch = 9.0
	hl.dir = Vector3(0, 0, -1)
	e.take_hit_info(hl)
	await frames(6)
	ok(e.state == "air" and TU.pick() == "air", "враг в воздухе — «ВОЗДУШНОЕ КОМБО» (%s, «%s»)" % [e.state, TU.pick()])
	var n := 0
	while e.state == "air" and n < 300:
		await frames(1)
		n += 1
	TU.seen["air"] = true
	e.hp = e.max_hp * 0.1
	e.stun(2.0)
	await frames(3)
	ok(e.exec_ready() and TU.pick() == "finisher", "враг под ✕ — «ДОБИВАНИЕ» («%s»)" % TU.pick())
	TU.on = true
	got = await wait_card(2.0)
	ok(got and String(TU.shown.back()) == "finisher", "карточка добивания показана сама")
	await real(0.4)
	await shot("t03_finisher.png")
	await close_enter()
	e.hp = e.max_hp
	# ---- 6. в диалоге карточек нет ----
	TU.seen = {}
	TU.since = 99.0
	game.mode = "dlg"
	await real(0.8)
	ok(TU.card == null, "в диалоге карточка не появляется")
	game.mode = "fight"
	# ---- 7. чужая пауза: меню паузы открыто — обучение само не показывается, повтор не снимает паузу ----
	game.set_paused(true)
	await real(0.8)
	ok(TU.card == null, "при открытой паузе карточка сама не появляется")
	TU.seen = {"light": true, "heavy": true, "dodge": true, "style_vozduh": true}
	game.pause_panel._open_page(5)
	await real(0.3)
	game.pause_panel._tutorial_list()
	await real(0.3)
	ok(game.pause_panel.card_rows.size() == 5, "в паузе список: 4 подсказки и «НАЗАД» (%d)" % game.pause_panel.card_rows.size())
	await shot("t04_pause_list.png")
	game.pause_panel.card_sel = 2
	game.pause_panel._card_activate(1)
	await real(0.3)
	ok(TU.card != null and not TU.own_pause, "из паузы открыт повтор подсказки, пауза чужая")
	await real(0.2)
	await shot("t05_replay.png")
	await close_enter()
	ok(TU.card == null and get_tree().paused and game.pause_panel.visible, "повтор закрыт — пауза осталась, меню на месте")
	ok(TU.shown.size() > 0 and TU.seen.size() == 4, "повтор не меняет список увиденных")
	game.set_paused(false)
	TU.on = false
	await real(0.4)
	# ---- 8. переназначение: карточка берёт новую клавишу ----
	var old_ev: Array = InputMap.action_get_events("heavy")
	InputMap.action_erase_events("heavy")
	var kx := InputEventKey.new()
	kx.physical_keycode = KEY_X
	InputMap.action_add_event("heavy", kx)
	TU.show_card("heavy", true)
	await frames(2)
	if TU.card != null:
		var txt := card_text(TU.card)
		ok(key_label(TU.card, "heavy") == "X" and txt.contains("X посреди") and not txt.contains("ПКМ"), "после переназначения на плашке и в тексте — X, а не ПКМ")
	await real(0.3)
	await shot("t06_rebind.png")
	await close_enter()
	InputMap.action_erase_events("heavy")
	for ev in old_ev:
		InputMap.action_add_event("heavy", ev)
	# ---- 9. все шесть карточек стилей ----
	for sid in Styles.ORDER:
		var cid := "style_" + String(sid)
		ok(TU.show_card(cid, true), "карточка стиля %s" % sid)
		await frames(2)
		if TU.card != null:
			var t2 := card_text(TU.card)
			ok(t2.contains("БАЗА") and t2.contains("СВЯЗКА") and t2.contains("СОВЕТ") and not t2.contains("{"), "%s: механика, база, связка, совет, клавиши подставлены" % sid)
			var sheet: Node2D = TU.card.root.get_node("Sheet")
			var b2: Control = TU.card.btn
			var bottom: float = (sheet.position.y + b2.position.y + b2.size.y) * TU.card.root.scale.y + TU.card.root.position.y
			ok(bottom < get_viewport().get_visible_rect().size.y, "%s: лист с кнопкой помещается в кадр (низ %.0f)" % [sid, bottom])
		await real(0.3)
		await shot("t07_%s.png" % sid)
		await close_enter()
	# все обычные карточки тоже помещаются в кадр
	for id in TutorialData.ORDER:
		TU.show_card(id, true)
		await frames(2)
		if TU.card != null:
			var sheet2: Node2D = TU.card.root.get_node("Sheet")
			var b3: Control = TU.card.btn
			var bottom2: float = (sheet2.position.y + b3.position.y + b3.size.y) * TU.card.root.scale.y + TU.card.root.position.y
			ok(bottom2 < get_viewport().get_visible_rect().size.y and not card_text(TU.card).contains("{"), "%s: в кадре, клавиши подставлены" % id)
		if id in ["combo", "assist", "air_tag", "overdrive"]:
			await real(0.3)
			await shot("t08_%s.png" % id)
		await close_enter()
	# ---- 10. madk1d: его стиль идёт карточкой текущего стиля ----
	await stage("madk1d")
	TU.reset()
	TU.on = false
	TU.seen = {"light": true}
	TU.since = 99.0
	ok(TU.pick() == "style_" + String(P.style.id) and P.hero == "madk1d", "за madk1d — карточка его стиля («%s»)" % TU.pick())
	# ---- 11. сохранение ----
	var sp := out.path_join("save_test.json")
	var f := FileAccess.open(sp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ch": 0, "step": 3, "xp": 7}))
	f = null
	TU.persist = true
	TU.save_path = sp
	TU.seen = {"light": true}
	TU.show_card("heavy")
	await close_enter()
	var d = JSON.parse_string(FileAccess.get_file_as_string(sp))
	ok(d is Dictionary and (d["tut"] as Dictionary).has("light") and (d["tut"] as Dictionary).has("heavy") and int(d["step"]) == 3 and int(d["xp"]) == 7, "увиденные карточки дописаны в сохранение, остальное не тронуто")
	TU.persist = false
	TU.load_data(["light", "style_guitar", "нет_такой"])
	ok(TU.seen.size() == 2 and TU.seen.has("style_guitar"), "загрузка: известные карточки, лишнее отброшено")
	TU.load_data(({"ch": 1} as Dictionary).get("tut", []))
	ok(TU.seen.is_empty(), "старое сохранение без ключа — обучение с начала")
	ok(game.tutorial.save_data() is Dictionary, "save_data — состояния для JSON")
	TU.load_data({"light": "completed", "heavy": "skipped", "dodge": "introduced", "плохой": "completed", "combo": "чушь"})
	ok(TU.state_of("light") == "completed" and TU.state_of("heavy") == "skipped" and TU.state_of("dodge") == "introduced" and not TU.seen.has("плохой") and not TU.seen.has("combo"), "загрузка состояний: сделано / пропущено / показано, мусор отброшен")
	await practice_block()
	ok(not get_tree().paused, "в конце игра не на паузе")
	print("TUTORIALCHECK ok" if fails == 0 else "TUTORIALCHECK ОШИБОК: %d" % fails)
	get_tree().quit()

# ---------------- 12. практика ----------------
func practice_block() -> void:
	await stage()
	TU.reset()
	TU.force = 1
	TU.on = true
	TU.since = 99.0
	var e = game._make_enemy("bot", "", P.global_position + Vector3(0, 0, -1.6))
	e.cool = 999.0
	await frames(80)
	var t0 := GameClock.ms()
	while TU.drill_id == "" and GameClock.ms() - t0 < 4000:
		await frames(1)
	ok(TU.drill_id == "light" and TU.drill != null and TU.drill.visible, "практика: в первом бою — упражнение «лёгкая атака», панель справа сверху (%s)" % TU.drill_id)
	ok(not get_tree().paused and TU.card == null, "практика: игра не на паузе, карточки нет")
	ok(TU.state_of("light") == "introduced", "показ — только «introduced», не «сделано»")
	await real(0.3)
	await shot("t12_drill.png")
	ok(TU.guard_e == e and e.train_guard, "учебная цель назначена и защищена")
	# цель не умирает и реагирует
	var hp0: float = e.hp
	e.take_hit(9999.0, Vector3(0, 0, -1), 4.0, true, 0.0)
	await frames(3)
	ok(e.alive() and e.hp >= e.max_hp * 0.05 - 0.01 and e.hp < hp0, "учебная цель не умирает (%.1f из %.0f), но урон получает" % [e.hp, e.max_hp])
	ok(e.state in ["hurt", "stun", "air", "down"] or e.react != "normal", "учебная цель реагирует на удар (%s / %s)" % [e.state, e.react])
	await frames(40)
	e.global_position = P.global_position + Vector3(0, 0, -1.6)
	e.state = "chase"
	# неправильное действие не засчитывается
	P.auto_input = {"heavy": "press"}
	await frames(1)
	P.auto_input = {}
	await frames(70)
	ok(TU.drill_id == "light" and TU.drill_n == 0, "тяжёлый удар не засчитан за лёгкий (%d)" % TU.drill_n)
	# правильное — засчитывается по попаданию
	for i in 40:
		if TU.drill_id != "light":
			break
		e.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 1.6
		e.state = "chase"
		P.auto_input = {"attack": "press"}
		await frames(1)
		P.auto_input = {}
		await frames(28)
	ok(TU.state_of("light") == "completed", "три попадания лёгкой атакой — упражнение выполнено (%s)" % TU.state_of("light"))
	await frames(10)
	await shot("t13_done.png")
	ok(not e.train_guard, "после упражнения защита с цели снята")
	await frames(90)
	# пропуск и неповтор
	TU.start_drill("heavy")
	await frames(3)
	var kb := InputEventKey.new()
	kb.physical_keycode = KEY_BACKSPACE
	kb.keycode = KEY_BACKSPACE
	kb.pressed = true
	Input.parse_input_event(kb)
	await frames(2)
	var ku := kb.duplicate() as InputEventKey
	ku.pressed = false
	Input.parse_input_event(ku)
	await frames(2)
	ok(TU.state_of("heavy") == "skipped" and TU.drill_id == "", "Backspace — упражнение пропущено (%s)" % TU.state_of("heavy"))
	var again := false
	for i in 20:
		if TU.pick_drill() == "heavy":
			again = true
	ok(not again and TU.done("light") and TU.done("heavy"), "сделанное и пропущенное не повторяются")
	# уклонение от настоящего замаха
	TU.seen["combo"] = "completed"
	if not is_instance_valid(e) or not e.alive():
		e = game._make_enemy("bot", "", P.global_position + Vector3(0, 0, -2.0))     # прежнюю цель могли добить после упражнения
		await real(1.4)
	e.global_position = P.global_position + Vector3(0, 0, -2.0)
	TU.start_drill("dodge")
	await frames(3)
	ok(TU.guard_e != null and TU.guard_e.train_attack, "упражнение защиты: цель замахивается регулярно")
	var foe_n = TU.guard_e
	foe_n.cool = 0.2
	foe_n.global_position = P.global_position + Vector3(0, 0, -1.8)
	var dodged := false
	P.combat.clear_buffer()
	for i in 400:
		await frames(1)
		if foe_n.state == "wind" and P.state == "move":
			# жмём, пока герой не ушёл в перекат (кадр нажатия может прийтись на конец прошлого действия)
			for k in 6:
				P.auto_input = {"move": Vector2(1, 0), "roll": "press"}
				await frames(1)
				P.auto_input = {}
				await frames(1)
				if P.state == "roll":
					dodged = true
					break
			if dodged:
				break
	await frames(20)
	ok(dodged and TU.ev_log.has("dodge_wind") and TU.drill_step >= 1, "уклонение от настоящего замаха засчитано (шаг %d)" % TU.drill_step)
	TU.finish_drill("skipped")
	# клавиши из InputMap
	TU.start_drill("light")
	var old_ev: Array = InputMap.action_get_events("attack")
	InputMap.action_erase_events("attack")
	var kx := InputEventKey.new()
	kx.physical_keycode = KEY_J
	InputMap.action_add_event("attack", kx)
	TU.drill.call("show_step", "light", 0, 0, false)
	await frames(2)
	var kl: Node = TU.drill.find_child("Key_attack", true, false)
	ok(kl != null and (kl as Label).text == "J", "панель: после переназначения — новая клавиша (%s)" % ((kl as Label).text if kl != null else "—"))
	InputMap.action_erase_events("attack")
	for ev in old_ev:
		InputMap.action_add_event("attack", ev)
	TU.finish_drill("skipped")
	# диалог: панели нет, новое упражнение не начинается
	TU.seen = {}
	TU.since = 99.0
	game.mode = "dlg"
	await frames(30)
	ok(TU.drill_id == "", "в диалоге упражнение не начинается")
	game.mode = "fight"
	# все шесть стилей
	var all6 := true
	for sid in Styles.ORDER:
		if TU.steps_of("style_" + String(sid)).is_empty():
			all6 = false
	ok(all6 and TU._resolve_drill("style_cur") == "style_" + String(P.style.id), "у всех шести стилей есть упражнения; текущий стиль определяется (%s)" % TU._resolve_drill("style_cur"))
	# ---- защита цели: только в упражнениях на попадание и не дольше GUARD_MAX ----
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	await frames(5)
	var g1 = game._make_enemy("bot", "", P.global_position + Vector3(0, 0, -2.0))
	await real(1.4)                  # враг выходит из портала около секунды
	TU.start_drill("rage")
	await frames(5)
	ok(TU.guard_e == null and not g1.train_guard, "упражнение без ударов («ПЕРЕГРУЗ») врага не держит — он умирает как обычно")
	TU.finish_drill("skipped")
	TU.start_drill("heavy")
	await frames(5)
	ok(g1.train_guard, "упражнение на удары держит цель")
	TU.guard_t = TU.GUARD_MAX
	await frames(3)
	ok(not g1.train_guard and TU.guard_e == null, "через %d с защита снимается сама — волна не застревает" % int(TU.GUARD_MAX))
	TU.finish_drill("skipped")
	g1.queue_free()
	await frames(5)
	# ---- «БОСС ОТКРЫТ» в настоящем бою: тяжёлыми сбить равновесие → «ОТКРЫТ» → удар; босса не держим ----
	for k in ["light", "style_" + String(P.style.id), "finisher", "air"]:
		TU.seen[k] = "completed"
	var bid: String = String(game.chapter()["steps"].filter(func(x): return String(x["t"]) == "boss")[0]["id"])
	var boss = game._make_enemy("", bid, P.global_position + Vector3(0, 0, -2.2))
	game.boss_e = boss
	game.mode = "boss"
	await real(1.3)
	boss.max_hp = 100000.0              # проверяем путь «открыть», а не «убить»: здоровья с запасом
	boss.hp = boss.max_hp
	TU.since = 99.0
	var is_started: bool = false
	for i in 300:
		await frames(1)
		if TU.drill_id == "boss_open":
			is_started = true
			break
	ok(is_started, "с боссом начинается задание «БОСС ОТКРЫТ» (%s)" % TU.drill_id)
	await real(0.3)
	await shot("t14_boss_open.png")
	var guarded := false
	var opened := false
	var t_b := GameClock.ms()
	var combo_i := 0
	while TU.drill_id == "boss_open" and GameClock.ms() - t_b < 90000:
		guarded = guarded or boss.train_guard
		P.inv = 1.0
		P.hp = P.max_hp
		var to: Vector3 = boss.global_position - P.global_position
		to.y = 0
		if to.length() > 2.6 or to.length() < 1.2:
			P.global_position = boss.global_position - (to.normalized() if to.length() > 0.1 else Vector3(0, 0, -1)) * 1.9
			to = boss.global_position - P.global_position
		P.face = atan2(to.x, to.z)
		# как живой игрок: серия лёгких с тяжёлым в конце, нажатия попадают в буфер связки — без пауз
		combo_i += 1
		P.auto_input = {"heavy": "press"} if combo_i % 4 == 0 or TU.drill_step == 1 else {"attack": "press"}
		await frames(1)
		P.auto_input = {}
		await frames(9)
		opened = opened or float(boss.weak_t) > 0.0
	print("TUT босс: шаг %d, открыт был %s, лог %s" % [TU.drill_step, opened, str(TU.ev_log.slice(-6))])
	ok(opened and TU.state_of("boss_open") == "completed", "настоящими ударами босс открыт и задание выполнено (%s)" % TU.state_of("boss_open"))
	ok(not guarded and not boss.train_guard, "босс ни разу не был «учебной целью» — его можно убить")
	boss.take_hit(9999999.0, Vector3(0, 0, -1), 0.0, true, 0.0)
	await frames(5)
	ok(not boss.alive(), "после задания босс умирает")
	# босса убили раньше, чем открыли: задание снимается, а не висит
	TU.seen.erase("boss_open")
	var boss2 = game._make_enemy("", bid, P.global_position + Vector3(0, 0, -2.5))
	game.boss_e = boss2
	game.mode = "boss"
	TU.since = 99.0
	await real(1.5)
	for i in 200:
		if TU.drill_id == "boss_open":
			break
		await frames(1)
	boss2.take_hit(9999999.0, Vector3(0, 0, -1), 0.0, true, 0.0)
	await real(0.3)
	ok(TU.drill_id != "boss_open" and TU.state_of("boss_open") == "introduced", "босс убит до «ОТКРЫТ» — задание снято и будет у следующего босса (%s)" % TU.state_of("boss_open"))
	game.mode = "fight"
	# обычный враг кампании умирает как раньше
	TU.on = false                    # карточки и упражнения больше не нужны: проверяем только врага
	TU.force = 0
	TU._release_guard()
	var plain = game._make_enemy("bot", "", P.global_position + Vector3(2, 0, -2))
	await frames(80)
	plain.take_hit(9999.0, Vector3(0, 0, -1), 2.0, true, 0.0)
	await frames(3)
	ok(not plain.alive(), "обычный враг кампании умирает штатно")
	TU.force = -1
