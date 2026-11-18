## Проверка тренировочной арены: `--resolution 1280x720 -- --trainingcheck=<папка>`.
## Идёт из главного меню как игрок: пункт TRAINING ARENA, экран выбора героя и стиля, запуск, зоны A–E, все шесть стилей,
## неубиваемая цель, обычный враг, босс, гибель, панель F1 и её действия, упражнения, выход в меню.
## Сохранение и настройки игрока запоминаются в начале и возвращаются в конце; сюжетное сохранение арена не трогает.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://grimerka_training.json"]

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
	print(("TRAININGCHECK ok: " if cond else "TRAININGCHECK ОШИБКА: ") + text)

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

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await wait(2.0)
	# ================= меню =================
	var mm = main.menu
	ok(mm != null and mm is Menu, "главное меню открыто")
	var names: Array = []
	for it in mm.ITEMS:
		names.append(String(it[0]))
	ok(names == ["CONTINUE", "NEW GAME", "LOAD GAME", "TRAINING ARENA", "SETTINGS", "EXTRAS", "EXIT"], "в меню есть TRAINING ARENA, старые пункты на месте (%s)" % ", ".join(names))
	var had_save: bool = mm.has_save
	ok(mm._enabled(0) == had_save, "CONTINUE доступен так же, как раньше (сохранение есть: %s)" % had_save)
	await shot("m_menu")
	mm._select(3, false)
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null and mm.panel_rows.size() == 4, "TRAINING ARENA открывает экран выбора (%d пунктов)" % mm.panel_rows.size())
	ok(mm.panel_sel == 2, "по умолчанию выбран «НАЧАТЬ ТРЕНИРОВКУ»")
	var h0: String = mm.train_hero
	mm._panel_select(0, false)
	await key(KEY_D)
	ok(mm.train_hero != h0 and Training.HERO_STYLES[mm.train_hero].has(mm.train_style), "D меняет героя, стиль — его (%s, %s)" % [mm.train_hero, mm.train_style])
	await key(KEY_A)
	ok(mm.train_hero == h0, "A возвращает героя")
	mm._panel_select(1, false)
	var seen := {}
	for i in 3:
		seen[mm.train_style] = true
		await key(KEY_D)
	ok(seen.size() == 3, "у героя перебираются все три стиля (%s)" % ", ".join(seen.keys()))
	await shot("m_training")
	await key(KEY_ESCAPE)
	await wait(0.2)
	ok(mm.panel == null and main.game == null, "Esc закрывает экран, игра не запустилась")
	# ================= запуск =================
	mm._select(3, false)
	await key(KEY_ENTER)
	await wait(0.2)
	mm.train_hero = "pahan"
	mm.train_style = "vozduh"
	mm.launch_training()
	var started: bool = await until(func(): return main.game != null and is_instance_valid(main.game) and main.game.training != null and main.game.training.targets.size() >= 3, 20.0)
	ok(started, "арена запустилась из меню")
	if not started:
		_finish()
		return
	var g = main.game
	var T: Training = g.training
	var P = g.player
	await wait(2.5)
	ok(g.mode == "training" and g.step == -1 and not g.dlg_box.visible, "сюжет не идёт: режим «training», шаг главы не начат, диалога нет")
	ok(P.hero == "pahan" and String(P.style.id) == "vozduh", "герой и стиль — как выбраны в меню")
	ok(T.targets.has("A") and T.targets.has("B") and T.targets.has("C"), "цели зон A, B, C на месте")
	ok(g.top_label.text.begins_with("ТРЕНИРОВОЧНАЯ АРЕНА") and not g.xp_label.visible, "вверху — арена и зона, опыт скрыт")
	await shot("t_arena")
	# ================= все шесть стилей =================
	var styles_ok := 0
	for h in ["pahan", "madk1d"]:
		for s in Training.HERO_STYLES[h]:
			await T.use(h, s)
			if P.hero == h and String(P.style.id) == s:
				styles_ok += 1
			else:
				print("   стиль не взялся: %s / %s → %s / %s" % [h, s, P.hero, P.style.id])
	ok(styles_ok == 6, "все шесть стилей включаются (%d из 6)" % styles_ok)
	await T.use("pahan", "vozduh")
	# ================= зона A: неубиваемый манекен =================
	T.go_zone("A")
	await wait(0.4)
	var a = T.targets["A"]
	ok(a.train_still and a.train_guard, "манекен зоны A стоит и не умирает")
	var a_pos: Vector3 = a.global_position
	await wait(1.5)
	ok(a.global_position.distance_to(T.ZONES["A"]) < 1.0, "манекен не уходит со своей зоны (%.2f м)" % a.global_position.distance_to(T.ZONES["A"]))
	for i in 3:
		a.take_hit(99999.0, Vector3(0, 0, -1), 2.0, true, 0.0)
		await wait(0.15)
	ok(a.alive() and a.hp > 0.0 and a.hp <= a.max_hp * 0.06, "манекен держит любой урон (%.0f из %.0f)" % [a.hp, a.max_hp])
	# цифры урона: выключатель
	var pops := func() -> int:
		var n := 0
		for c in g.get_children():
			if c is Label3D:
				n += 1
		return n
	await wait(1.2)
	var n0: int = pops.call()
	g.show_dmg = false
	a.take_hit(5.0, Vector3(0, 0, -1), 0.5, false, 0.0)
	await wait(0.05)
	var n_off: int = pops.call()
	g.show_dmg = true
	a.take_hit(5.0, Vector3(0, 0, -1), 0.5, false, 0.0)
	await wait(0.05)
	var n_on: int = pops.call()
	ok(n_off == n0 and n_on > n_off, "цифры урона выключаются и включаются (%d → %d → %d)" % [n0, n_off, n_on])
	T.reset_targets()
	await wait(0.1)
	ok(a.hp == a.max_hp and a.global_position.distance_to(a.train_home) < 0.1, "«ЦЕЛИ НА МЕСТО» — здоровье и место вернулись")
	# ================= зона B: замахи =================
	T.go_zone("B")
	var b = T.targets["B"]
	var swung: bool = await until(func(): return is_instance_valid(b) and b.state in ["wind", "strike", "special"], 8.0)
	ok(swung and b.train_attack, "цель зоны B замахивается сама (%s)" % (b.state if is_instance_valid(b) else "—"))
	await shot("t_zone_b")
	# ================= зона C: воздух =================
	T.go_zone("C")
	await wait(0.3)
	var c = T.targets["C"]
	c.take_hit(10.0, Vector3(0, 0, -1), 1.0, true, 9.0)
	var flew: bool = await until(func(): return c.state == "air", 1.0)
	ok(flew and c.alive(), "цель зоны C подбрасывается и не умирает")
	await wait(2.0)
	# ================= зона D: босс =================
	T.go_zone("D")
	await wait(0.5)
	var boss = T.targets.get("D")
	ok(boss != null and is_instance_valid(boss) and boss.boss_id != "" and g.boss_e == boss, "в зоне D — босс (%s)" % (String(boss.boss_id) if boss != null else "—"))
	await wait(0.3)
	ok(g.boss_box.visible, "полоса здоровья босса видна")
	var acted: bool = await until(func(): return is_instance_valid(boss) and boss.state in ["wind", "strike", "special", "summon"], 12.0)
	ok(acted, "босс сам атакует настоящими приёмами (%s)" % (boss.state if is_instance_valid(boss) else "—"))
	boss.take_hit(999999.0, Vector3(0, 0, -1), 0.0, true, 0.0)
	await wait(0.2)
	ok(boss.alive(), "неубиваемый босс не умирает")
	await shot("t_zone_d")
	ok(boss.global_position.distance_to(T.ZONES["D"]) < 9.0, "босс держится своей зоны (%.1f м)" % boss.global_position.distance_to(T.ZONES["D"]))
	T.set_immortal(false)
	boss.take_hit(999999.0, Vector3(0, 0, -1), 0.0, true, 0.0)
	await wait(0.3)
	ok(not boss.alive() and g.step_done_t < 0.0 and g.mode == "training", "обычный босс умирает, сюжет не двигается")
	T.set_immortal(true)
	# ================= зона E: свободный бой =================
	T.go_zone("E")
	T.kind_i = 1
	T.spawn_free()
	await wait(0.1)
	var fe = g.enemies.back()
	ok(fe != null and fe.kind == "clipper" and not fe.train_guard, "«СОЗДАТЬ ВРАГА» — обычный враг выбранного вида")
	await wait(1.3)
	var xp0: int = g.xp
	fe.take_hit(99999.0, Vector3(0, 0, -1), 2.0, true, 0.0)
	await wait(0.2)
	ok(not fe.alive() and g.xp == xp0, "обычный враг умирает, опыт не начислен (%d)" % g.xp)
	T.spawn_free()
	T.spawn_free()
	await wait(0.2)
	T.clear_enemies()
	await wait(0.2)
	var extra := 0
	for e in g.enemies:
		if is_instance_valid(e) and not T.targets.values().has(e) and e.alive():
			extra += 1
	ok(extra == 0 and T.targets["A"] != null and is_instance_valid(T.targets["A"]), "«УБРАТЬ ВРАГОВ» убирает лишних, цели зон остаются")
	# ================= здоровье, способности, перезарядки =================
	P.hp = 12.0
	T.heal()
	ok(P.hp == P.max_hp, "здоровье восстановлено")
	P.swag = 80.0
	g.hype.value = 50.0
	T.reset_abilities()
	ok(P.swag == 0.0 and g.hype.value == 0.0, "СВЭГ и HYPE сброшены")
	P.combat.cooldowns = {"x": 5.0}
	g.tag.tag_cd = 3.0
	T.reset_cooldowns()
	ok(P.combat.cooldowns.is_empty() and g.tag.tag_cd == 0.0, "перезарядки сброшены")
	# ================= гибель — не поражение =================
	for i in 6:
		if g.over:
			break
		P.inv = 0.0
		g.player.take_damage(99999.0, g.player.global_position + Vector3(0, 0, -1))
		await wait(0.35)
	ok(g.over or T.events.has(["dead"]), "герой погиб")
	var back: bool = await until(func(): return not g.over and g.player.state != "dead", 4.0)
	ok(back and g.player.hp == g.player.max_hp and g.death == null and main.game == g, "после гибели — на ногах с полным здоровьем, без экрана поражения")
	await wait(1.0)
	await shot("t_after_death")
	# ================= панель F1 =================
	await wait(0.4)
	await key(KEY_F1)
	await wait(0.2)
	ok(T.panel != null and get_tree().paused, "F1 открывает панель, игра стоит")
	var s0: int = T.panel.sel
	await key(KEY_S)
	ok(T.panel.sel == s0 + 1, "S двигает выбор в панели")
	await shot("t_panel")
	await key(KEY_ESCAPE)
	await wait(0.2)
	ok(T.panel == null and not get_tree().paused, "Esc закрывает панель, игра идёт")
	# ================= упражнения =================
	T.go_zone("A")
	await wait(1.0)
	await shot("t_zone_a")
	T.set_exercises(true)
	var drill: bool = await until(func(): return g.tutorial.drill_id != "", 12.0)
	ok(drill and not get_tree().paused, "режим упражнений: упражнение началось без паузы (%s)" % g.tutorial.drill_id)
	await shot("t_drill")
	T.set_exercises(false)
	await wait(0.2)
	ok(g.tutorial.drill_id == "", "свободная практика: упражнение снято")
	# ================= сохранения =================
	ok(FileAccess.get_file_as_string(KEEP[0]) == (kept[KEEP[0]] if kept[KEEP[0]] != null else ""), "сюжетное сохранение не изменилось")
	ok(FileAccess.file_exists(Training.SAVE) and Training.prefs()["hero"] == T.hero, "выбор арены записан в свой файл")
	# ================= выход в меню =================
	T.to_menu()
	var menu_back: bool = await until(func(): return main.menu != null and main.game == null, 5.0)
	ok(menu_back, "выход из арены — в главное меню")
	if menu_back:
		await wait(0.5)
		ok(main.menu.has_save == had_save and main.menu._enabled(0) == had_save, "CONTINUE после арены — как до неё")
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
	print("TRAININGCHECK ok" if fails == 0 else "TRAININGCHECK ОШИБКА: %d" % fails)
	get_tree().quit()
