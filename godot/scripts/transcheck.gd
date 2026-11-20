## Проверка переходов: `-- --transcheck=<папка>`. Запуск из меню (NEW GAME с двойным нажатием, CONTINUE) и пауза
## в покое, на бегу, в ударе, в перекате, Esc посреди открытия и серия Esc. Снимает ключевые кадры, печатает «TRANS ok / ОШИБКА».
## Сохранение игрока запоминается и возвращается; звук выключен.
extends Node

var main
var out := ""
var fails := 0
var save_text = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_text = FileAccess.get_file_as_string("user://grimerka_save.json") if FileAccess.file_exists("user://grimerka_save.json") else null
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("TRANS ok: " if cond else "TRANS ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func press(k: Key, down := true) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)

func key(k: Key) -> void:
	press(k)
	await wait(0.06)
	press(k, false)
	await wait(0.06)

func click() -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = Vector2(300, 300)
		Input.parse_input_event(e)
		await wait(0.04)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

func skip_dialog() -> void:
	var n := 0
	while main.game != null and main.game.mode == "dlg" and n < 300:
		await key(KEY_ENTER)
		n += 1
	await wait(0.6)

func games() -> int:
	var n := 0
	for c in main.get_children():
		if c.get_script() == preload("res://scripts/game.gd"):
			n += 1
	return n

## Слепок позы: где Пахан, кости рук и головы, кадр анимации.
func snap_pose() -> Dictionary:
	var pl = main.game.player
	var sk: Skeleton3D = pl.rig.skel
	return {"pos": pl.global_position, "face": pl.face, "state": pl.state, "anim": pl.rig.player.current_animation, "t": pl.rig.player.current_animation_position,
		"hand": sk.get_bone_global_pose(pl.rig.bone["rhand"]).origin, "head": sk.get_bone_global_pose(pl.rig.bone["head"]).origin, "lfoot": sk.get_bone_global_pose(pl.rig.bone["lfoot"]).origin}

func same_pose(a: Dictionary, b: Dictionary) -> bool:
	return a["pos"].distance_to(b["pos"]) < 0.001 and absf(a["face"] - b["face"]) < 0.0001 and a["state"] == b["state"] and a["anim"] == b["anim"] \
		and absf(a["t"] - b["t"]) < 0.0001 and a["hand"].distance_to(b["hand"]) < 0.0005 and a["head"].distance_to(b["head"]) < 0.0005 and a["lfoot"].distance_to(b["lfoot"]) < 0.0005

## Пауза из текущего состояния: Esc → наезд → меню → Esc → камера на место; поза не меняется, игра продолжается с того же кадра.
func pause_case(tag: String) -> void:
	var g = main.game
	var pm = g.pause_panel
	var cam0: Transform3D = g.cam.global_transform
	var fov0: float = g.cam.fov
	await key(KEY_ESCAPE)
	var p0 := snap_pose()
	await wait(0.25)
	await shot("pause_%s_1_push.png" % tag)
	ok(pm.state == "opening" and pm.cam_k > 0.05 and pm.cam_k < 0.95, "%s: камера наезжает (k = %.2f)" % [tag, pm.cam_k])
	await wait(0.8)
	await shot("pause_%s_2_open.png" % tag)
	var chest: Vector3 = g.player.global_position + Vector3(0, 1.05, 0)
	var d: float = g.cam.global_position.distance_to(chest)
	ok(pm.state == "open" and get_tree().paused and d < 2.75 and d > 0.85, "%s: меню открыто, камера у Пахана (%.2f м)" % [tag, d])
	var fwd: Vector3 = -g.cam.global_transform.basis.z
	ok(fwd.angle_to(chest - g.cam.global_position) < 0.2, "%s: камера смотрит на Пахана" % tag)
	ok(same_pose(p0, snap_pose()), "%s: поза, место и кадр анимации не изменились (%s, %.2f с)" % [tag, p0["anim"], p0["t"]])
	ok(not g.hud_root.visible, "%s: HUD игры спрятан под меню" % tag)
	await key(KEY_ESCAPE)
	await wait(0.18)
	await shot("pause_%s_3_close.png" % tag)
	var t0 := GameClock.ms()
	while get_tree().paused and GameClock.ms() - t0 < 2000:
		await get_tree().process_frame
	ok(not get_tree().paused and pm.state == "closed", "%s: игра продолжается" % tag)
	var back_ok: bool = g.cam.global_position.distance_to(cam0.origin) < 0.05 and absf(g.cam.fov - fov0) < 0.5 and g.cam.h_offset == pm.cam_h
	ok(back_ok, "%s: камера вернулась на прежнее место (%.3f м)" % [tag, g.cam.global_position.distance_to(cam0.origin)])
	ok(g.hud_root.visible, "%s: HUD вернулся" % tag)
	var p1 := snap_pose()
	ok(p1["anim"] == p0["anim"] or p0["anim"] == "" or p0["state"] != "move", "%s: та же анимация после паузы (%s → %s)" % [tag, p0["anim"], p1["anim"]])
	await shot("pause_%s_4_back.png" % tag)

func _run() -> void:
	await wait(2.0)
	var menu = main.menu
	# ================= NEW GAME =================
	var had_save := FileAccess.file_exists("user://grimerka_save.json")
	menu.launch(false, 0)
	menu.launch(false, 0)                   # двойное нажатие
	menu._activate()
	await wait(0.12)
	await shot("start_1_press.png")
	await wait(0.55)
	await shot("start_2_cover.png")
	var t0 := GameClock.ms()
	while main.game == null and GameClock.ms() - t0 < 5000:
		await get_tree().process_frame
	ok(main.game != null and games() == 1, "NEW GAME: одна игра, двойное нажатие не создало вторую")
	var g = main.game
	await get_tree().process_frame
	ok(g.intro_busy() and g.mode != "dlg", "облёт идёт, сюжет ещё не начался")
	var pos0: Vector3 = g.player.global_position
	press(KEY_W)
	await wait(0.4)
	await shot("start_3_reveal.png")
	press(KEY_W, false)
	ok(g.player.global_position.distance_to(pos0) < 0.05, "во время облёта Пахан не управляется")
	await key(KEY_ESCAPE)
	ok(not get_tree().paused, "во время облёта пауза не открывается")
	var hud_early: float = (g.hud_root.get_child(0) as CanvasItem).modulate.a
	ok(hud_early < 0.05, "HUD ещё не появился")
	await wait(0.8)
	await shot("start_4_orbit.png")
	await wait(0.9)
	await shot("start_5_hud.png")
	while g.intro_busy() and GameClock.ms() - t0 < 12000:
		await get_tree().process_frame
	await wait(0.6)
	await shot("start_6_done.png")
	var home: Transform3D = g.spring.global_transform * Transform3D(Basis(), Vector3(0, 0, g.spring.get_hit_length()))
	ok(not g.intro_busy() and g.cam.global_position.distance_to(home.origin) < 0.3, "облёт закончен, камера на игровом месте (%.2f м)" % g.cam.global_position.distance_to(home.origin))
	var all_hud := true
	for c in g.hud_root.get_children():
		if c is CanvasItem and (c as CanvasItem).modulate.a < 0.99 and c != g.banner_title and c != g.banner_sub and c != g.toast_label:
			print("TRANS   HUD не проявлен: ", c.name, " ", c.get_class(), " a=", (c as CanvasItem).modulate.a, " ", (c as Label).text if c is Label else "")
			all_hud = false
	ok(all_hud, "HUD появился целиком")
	ok(g.mode == "dlg", "после облёта начался разговор (режим %s)" % g.mode)
	ok(not main.intro_fx.busy and not main.intro_fx.rect.visible, "шторка убрана")
	await skip_dialog()
	pos0 = g.player.global_position
	press(KEY_S)
	await wait(0.5)
	press(KEY_S, false)
	ok(g.player.global_position.distance_to(pos0) > 0.3, "после перехода Пахан бегает")
	await wait(0.6)
	# ================= пауза =================
	await pause_case("idle")
	press(KEY_S)
	await wait(0.35)
	await pause_case("run")
	press(KEY_S, false)
	await wait(0.6)
	await click()
	await wait(0.18)
	ok(g.player.state == "attack", "удар идёт перед паузой")
	await pause_case("attack")
	await wait(1.2)
	await key(KEY_SHIFT)            # перекат — Shift (пробел с этапа движения — прыжок)
	await wait(0.12)
	ok(g.player.state == "roll", "перекат идёт перед паузой")
	await pause_case("roll")
	await wait(1.0)
	# Esc посреди открытия — назад
	var pm = g.pause_panel
	var c0: Vector3 = g.cam.global_position
	await key(KEY_ESCAPE)
	await wait(0.2)
	await key(KEY_ESCAPE)
	await wait(1.0)
	ok(not get_tree().paused and pm.state == "closed" and g.cam.global_position.distance_to(c0) < 0.05, "Esc посреди наезда: камера вернулась, игра идёт")
	# серия Esc
	for i in 7:
		await key(KEY_ESCAPE)
		await wait(0.05)
	await wait(1.6)
	var steady: bool = (pm.state == "open" and get_tree().paused) or (pm.state == "closed" and not get_tree().paused)
	ok(steady, "серия Esc: устойчивое состояние (%s)" % pm.state)
	if pm.state == "open":
		await key(KEY_ESCAPE)
		await wait(1.0)
	ok(pm.state == "closed" and not pm.cam_taken and g.cam.global_position.distance_to(c0) < 0.4, "после серии камера своя")
	# ================= CONTINUE =================
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://grimerka_save.json")) if FileAccess.file_exists("user://grimerka_save.json") else null
	g._to_menu()
	await wait(1.5)
	ok(main.menu != null and main.game == null, "выход в меню")
	if saved is Dictionary:
		main.menu.launch(true)
		t0 = GameClock.ms()
		while (main.game == null or main.game.intro_busy() or main.intro_fx.busy) and GameClock.ms() - t0 < 12000:
			await get_tree().process_frame
		await wait(0.5)
		await shot("continue_done.png")
		ok(main.game != null and main.game.ch == int(saved.get("ch", 0)) and main.game.xp == int(saved.get("xp", 0)), "CONTINUE: глава %d и прослушивания %d из сохранения" % [int(saved.get("ch", 0)), int(saved.get("xp", 0))])
		ok(main.game.step >= int(saved.get("step", 0)), "CONTINUE: шаг из сохранения, начало главы не повторяется (шаг %d, в сохранении %d)" % [main.game.step, int(saved.get("step", 0))])
	else:
		print("TRANS пропуск: сохранения нет — CONTINUE не проверялся")
	ok(Engine.time_scale == 1.0, "скорость времени обычная")
	if save_text == null:
		if FileAccess.file_exists("user://grimerka_save.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grimerka_save.json"))
	else:
		var f := FileAccess.open("user://grimerka_save.json", FileAccess.WRITE)
		f.store_string(save_text)
	print("TRANS итог: ошибок %d (было сохранение: %s)" % [fails, had_save])
	get_tree().quit()
