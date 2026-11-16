## Проверка сцены гибели: `-- --deathcheck=<папка>`. Гибель в подъезде, от настоящего врага и от босса,
## «Ещё раз», повторная гибель, «В меню». Снимает ключевые кадры, печатает «DEATH ok / ОШИБКА».
## Сохранение игрока запоминается и возвращается; звук на время проверки выключен.
extends Node

var main
var out := ""
var fails := 0
var save_text = null
var cam_prev := Vector3.ZERO     # замер плавности камеры: прямо перед отрисовкой кадра
var cam_step := 0.0
var cam_at := ""
var cam_fresh := true            # первый замер после перерыва только запоминает точку
var cam_watch := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_text = FileAccess.get_file_as_string("user://grimerka_save.json") if FileAccess.file_exists("user://grimerka_save.json") else null
	AudioServer.set_bus_mute(0, true)
	RenderingServer.frame_pre_draw.connect(_cam_sample)
	_run()

## Скорость камеры между соседними отрисованными кадрами (м за кадр, приведённый к 1/60 с).
func _cam_sample() -> void:
	if not cam_watch or main.game == null:
		return
	var p: Vector3 = main.game.cam.global_position
	if cam_fresh:
		cam_fresh = false
		cam_prev = p
		return
	var dt := clampf(get_process_delta_time() / maxf(Engine.time_scale, 0.001), 0.004, 0.05)
	if p.distance_to(cam_prev) / dt > cam_step:
		cam_step = p.distance_to(cam_prev) / dt
		cam_at = "t=%.2f шаг %.3f м за %.4f с, владеет=%s" % [main.game.death.t if main.game.death != null else -1.0, p.distance_to(cam_prev), dt, main.game.death.owns_camera() if main.game.death != null else false]
	cam_prev = p

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("DEATH ok: " if cond else "DEATH ОШИБКА: ") + text)

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
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

func skip_dialog() -> void:
	var n := 0
	while main.game.mode == "dlg" and n < 300:
		await key(KEY_ENTER)
		n += 1
	await wait(0.8)

## Дождаться гибели от чужого удара (здоровье 1). Возвращает, кто убил: true — враг сам.
func die_by_enemy(sec: float) -> bool:
	var g = main.game
	g.player.hp = 1.0
	g.player.inv = 0.0
	var t0 := Time.get_ticks_msec()
	while g.player.state != "dead" and Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
		g.player.hp = minf(g.player.hp, 1.0)
	if g.player.state == "dead":
		return true
	g.player.inv = 0.0
	g.player.take_damage(999.0, g.player.global_position + Vector3(1, 0, 0))
	return false

## Пройти всю сцену со снимками и проверками. tag — имя для файлов.
func watch(tag: String) -> void:
	var g = main.game
	var d = g.death
	ok(d != null and g.over and g.panel == d, "%s: сцена гибели запущена, окно одно" % tag)
	if d == null:
		return
	var cam0: Vector3 = g.cam.global_position
	await wait(0.35)
	await shot(tag + "_1_fall.png")
	ok(d.stage_name == "fall" and g.death_mono < 0.05, "%s: сначала падение, цвет на месте" % tag)
	await key(KEY_ESCAPE)
	ok(not get_tree().paused, "%s: Esc паузу не открывает" % tag)
	cam_fresh = true
	cam_step = 0.0
	cam_watch = true
	var t0 := Time.get_ticks_msec()
	var mid := false
	while d.t < d.T_RISE1 and Time.get_ticks_msec() - t0 < 9000:
		await get_tree().process_frame
		if not mid and d.t > 3.0:
			mid = true
			cam_watch = false                # сохранение снимка подвешивает кадр — это не рывок камеры
			await shot(tag + "_2_rise.png")
			ok(g.death_mono > 0.2 and g.death_mono < 0.95, "%s: на полпути цвет уходит (%.2f)" % [tag, g.death_mono])
			for i in 4:                      # пропустить кадры, растянутые сохранением снимка
				await get_tree().process_frame
			cam_fresh = true
			cam_watch = true
	cam_watch = false
	var step_max := cam_step
	await wait(0.1)
	await shot(tag + "_3_top.png")
	var fwd: Vector3 = -g.cam.global_transform.basis.z
	var body: Vector3 = g.player.global_position + Vector3(0, 0.35, 0)
	var rise: float = g.cam.global_position.y - body.y
	ok(rise > 2.0, "%s: камера поднялась над телом на %.1f м (была на %.1f)" % [tag, rise, cam0.y - body.y])
	ok(fwd.y < -0.75, "%s: смотрит сверху вниз (наклон %.0f°)" % [tag, rad_to_deg(asin(-fwd.y))])
	var sp: Vector2 = g.cam.unproject_position(body) / get_viewport().get_visible_rect().size
	ok(not g.cam.is_position_behind(body) and absf(sp.x - 0.5) < 0.12 and absf(sp.y - 0.5) < 0.14, "%s: тело в центре кадра (%.2f, %.2f)" % [tag, sp.x, sp.y])
	ok(step_max < 8.0, "%s: камера шла плавно, без скачков (до %.1f м/с; %s)" % [tag, step_max, cam_at])
	ok(g.death_mono > 0.99 and g.post.visible, "%s: кадр чёрно-белый" % tag)
	ok(g.hud_root.modulate.a < 0.02, "%s: HUD скрыт" % tag)
	while d.t < d.T_TITLE + 1.3:
		await get_tree().process_frame
	await shot(tag + "_4_title.png")
	ok(d.title.modulate.a > 0.9 and (d.btns[0]["root"] as Control).modulate.a < 0.05, "%s: надпись уже есть, кнопок ещё нет" % tag)
	await wait(1.6)
	await shot(tag + "_5_menu.png")
	ok(d.stage_name == "menu" and (d.btns[1]["root"] as Control).modulate.a > 0.95, "%s: кнопки появились последними" % tag)
	ok(g.player.state == "dead" and g.player.global_position.y > -0.2, "%s: Пахан лежит, сквозь пол не провалился (y = %.2f)" % [tag, g.player.global_position.y])

func _run() -> void:
	await wait(2.0)
	main.start_game(false, 0)
	await wait(2.0)
	var g = main.game
	await skip_dialog()
	var cam_home: Transform3D = g.cam.transform
	# ---- 1. гибель в подъезде (низкий потолок) ----
	g.player.inv = 0.0
	g.player.take_damage(999.0, g.player.global_position + Vector3(1, 0, 0))
	await wait(0.1)
	g.player.inv = 0.0
	g.player.take_damage(999.0, g.player.global_position + Vector3(1, 0, 0))     # второй смертельный удар сцену не перезапускает
	await wait(0.1)
	ok(g.hud.find_children("*", "DeathSeq", true, false).size() == 1 if g.death != null else false, "повторный удар по мёртвому второй сцены не создаёт")
	await watch("hall")
	await key(KEY_D)
	ok(g.death.sel == 1, "D выбирает «В меню»")
	await key(KEY_A)
	await key(KEY_ENTER)
	await wait(0.6)
	ok(not g.over and g.death == null and g.death_mono == 0.0 and g.player.state == "move" and g.player.hp == g.player.max_hp, "«Ещё раз»: игра идёт, здоровье полное, сцена убрана")
	ok(g.cam.transform.basis.is_equal_approx(cam_home.basis), "камера вернулась на место")
	await wait(0.5)
	ok((not g.post.visible or g.death_mono == 0.0) and g.hud_root.modulate.a > 0.95, "цвет и HUD вернулись")
	await skip_dialog()
	await shot("after_retry.png")
	# ---- 2. гибель от настоящего врага во дворе ----
	g._exit_hall()
	await wait(2.0)
	var guard := 0
	while g.mode != "fight" and guard < 40:
		await skip_dialog()
		await wait(0.3)
		guard += 1
	ok(g.mode == "fight", "бой во дворе начался")
	var by_enemy := await die_by_enemy(30.0)
	ok(by_enemy, "Пахана убил обычный враг")
	await wait(0.05)
	await watch("enemy")
	var alive_cd: float = g.buddy.cd
	ok(g.buddy.velocity.length() < 0.5, "напарник в сцене гибели стоит")
	await key(KEY_ENTER)
	await wait(0.8)
	ok(not g.over and g.death == null, "«Ещё раз» после врага")
	# ---- 3. повторная гибель и промотка сцены ----
	guard = 0
	while g.mode != "fight" and guard < 40:
		await skip_dialog()
		await wait(0.3)
		guard += 1
	await die_by_enemy(30.0)
	await wait(1.0)
	await key(KEY_ENTER)                    # промотка к кнопкам
	await wait(0.4)
	ok(g.death != null and g.death.stage_name == "menu" and g.death_mono > 0.99, "повторная гибель; Enter проматывает сцену к кнопкам")
	await key(KEY_ENTER)
	await wait(0.8)
	# ---- 4. гибель от босса ----
	g._clear_fight()
	g.step = 4
	g.next_step()
	await wait(1.0)
	guard = 0
	while g.mode != "boss" and guard < 40:
		await skip_dialog()
		await wait(0.3)
		guard += 1
	ok(g.mode == "boss" and g.boss_e != null, "бой с боссом начался")
	var by_boss := await die_by_enemy(40.0)
	ok(by_boss, "Пахана убил босс")
	await wait(0.05)
	await watch("boss")
	# ---- 5. «В меню» ----
	await key(KEY_D)
	await key(KEY_ENTER)
	await wait(1.5)
	ok(main.menu != null and main.game == null and not get_tree().paused, "«В меню»: главное меню открыто")
	ok(Engine.time_scale == 1.0, "скорость времени обычная")
	await shot("menu_after_death.png")
	if save_text == null:
		if FileAccess.file_exists("user://grimerka_save.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grimerka_save.json"))
	else:
		var f := FileAccess.open("user://grimerka_save.json", FileAccess.WRITE)
		f.store_string(save_text)
	print("DEATH итог: ошибок %d" % fails)
	get_tree().quit()
