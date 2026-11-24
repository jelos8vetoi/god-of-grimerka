## Плейтест «ГОЛДА 67» настоящим вводом: `--resolution 1280x720 -- --playtest-golda67=<папка> [--pt-min=МИН] [--pt-pad]`.
## Игра настоящая, из главного меню (PLAY → ГОЛДА 67 → ВОЙТИ В ПОДЪЕЗД), main.user_play() остаётся true: вступления,
## ролики, подсказки и сохранение работают как у игрока. Героем управляют ТОЛЬКО события ввода
## (Input.parse_input_event): WASD в восьми направлениях от камеры, ЛКМ / ПКМ — удары, Shift — уклонение, C — блок,
## E — взаимодействие, Enter — диалоги и экраны, Z — термос, пробел — прыжок при застревании. Положение героя,
## состояние забега и здоровье бот не меняет. Куда идти — читает с мини-карты (цель и маршрут), как игрок.
## С ключом --pt-pad движение и удары идут событиями геймпада (левый стик, кнопки).
## Это НЕ ручной проход человеком: камеру бот не вращает (в проверках курсор не захвачен), дерётся просто.
## Что пишет (строки «G67PT | …»): раз в 5 с — место, цель, здоровье, FPS; застревания (STUCK / BLOCKED) с координатами;
## падения под мир; кадры, где между камерой и героем стена; смерти; ролики; экраны; итог по зонам кадра.
## Запуск — только со своей папкой данных (APPDATA во временной папке grimerka-checks), иначе плейтест откажется.
extends Node

var main
var out := ""
var held := {}
var minutes := 12.0
var pad := false
var t_all := 0.0
var log_t := 0.0
var shot_t := 8.0
var shots := 0
var stuck_t := 0.0
var stuck_from := Vector3.ZERO
var stuck_n := 0
var stuck_total := 0
var blocked: Array = []
var side_t := 0.0
var side_k := 0
var atk_cd := 0.0
var roll_cd := 0.0
var use_cd := 0.0
var ui_cd := 0.0
var n_atk := 0
var deaths := 0
var runs := 0
var seen := {}
var cam_frames := 0
var cam_bad := 0
var cam_bad_at := {}
var fps_zone := {}             # зона -> [сумма dt, кадров, худший dt]
var last_state := ""
var fell := 0
var ev: Array = []             # журнал событий для итога
var moving := false
var last_goal := ""
var goal_t := 0.0
var clips_seen: Array = []
var hub_tries := 0
var dead_now := false
var choice_n := 0
var skip_dvor := false
var immortal := false
var in_dlg := false
var dlg_n := 0
var dlg_t := 0.0
var hub_list: Array = []
var hub_i := 0
var hub_t := 0.0
var hub_used := false
var hub_res := {}
var side_q: Array = []           # побочные цели забега: {id, kind, pos, node}
var side_cur := {}
var side_time := 0.0
var side_path := PackedVector2Array()
var side_path_t := 0.0
var side_built := -1
var side_res: Array = []
var hit_t := 0.0
var w_sig := ""
var w_t := 0.0
var ev_log := {}
var last_dist := ""
var kills0 := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ad := OS.get_environment("APPDATA")
	if ad.find("grimerka-checks") < 0:
		print("G67PT ОШИБКА: запускать только со своей папкой данных (APPDATA в grimerka-checks)")
		get_tree().quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-min="):
			minutes = float(a.substr(9))
		if a == "--pt-pad":
			pad = true
		if a == "--pt-immortal":                 # поддержка здоровья: бой не оценивается, зато бот доходит до всех событий, роликов и боссов
			immortal = true
		if a == "--pt-pz":                       # побочные цели двора не обходим: сразу к спуску (для подготовленного профиля)
			skip_dvor = true
	AudioServer.set_bus_mute(0, true)          # звук на колонки не идёт; шины и музыка работают как обычно
	DirAccess.make_dir_recursive_absolute(out)
	_start()

func say(s: String) -> void:
	print("G67PT | %s" % s)

func note(kind: String, s: String) -> void:
	ev.append([kind, s])
	say("%s: %s" % [kind, s])

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm + ".png"))

func hold(k: Key, on: bool) -> void:
	if bool(held.get(k, false)) == on:
		return
	held[k] = on
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = on
	Input.parse_input_event(e)

func tap(k: Key) -> void:
	hold(k, true)
	await wait(0.07)
	hold(k, false)
	await wait(0.07)

func mouse(b: MouseButton) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = b
		e.pressed = down
		e.position = get_viewport().get_visible_rect().size * 0.5
		e.global_position = e.position
		Input.parse_input_event(e)
		await wait(0.04)

func pad_btn(b: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.05)

func pad_axis(ax: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)

func stop() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_C]:
		hold(k, false)
	if pad:
		pad_axis(JOY_AXIS_LEFT_X, 0.0)
		pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	moving = false

## Идти в сторону точки мира: восемь направлений от камеры
func go(to: Vector3) -> void:
	var g = main.game
	var p = g.player
	var w := Vector2(to.x - p.global_position.x, to.z - p.global_position.z)
	if w.length() < 0.2:
		stop()
		return
	w = w.normalized()
	if side_t > 0.0:                       # обход препятствия: шаг вбок
		w = Vector2(-w.y, w.x) * (1.0 if side_k % 2 == 0 else -1.0)
	var yaw: float = g.cam_yaw
	var f := Vector2(-sin(yaw), -cos(yaw))
	var r := Vector2(cos(yaw), -sin(yaw))
	var fv := w.dot(f)
	var rv := w.dot(r)
	if pad:
		pad_axis(JOY_AXIS_LEFT_X, rv)
		pad_axis(JOY_AXIS_LEFT_Y, -fv)
	else:
		hold(KEY_W, fv > 0.38)
		hold(KEY_S, fv < -0.38)
		hold(KEY_D, rv > 0.38)
		hold(KEY_A, rv < -0.38)
	moving = true

func attack(heavy := false) -> void:
	n_atk += 1
	if pad:
		pad_btn(JOY_BUTTON_Y if heavy else JOY_BUTTON_X)
	else:
		mouse(MOUSE_BUTTON_RIGHT if heavy else MOUSE_BUTTON_LEFT)

func G():
	var g = main.game
	return g.golda if g != null and is_instance_valid(g) and "golda" in g else null

func zone_name() -> String:
	var gg = G()
	if gg == null:
		return "меню"
	if gg.place == "hub":
		return "подъезд"
	if G67District.is_podzemka():
		var p: Vector3 = main.game.player.global_position
		for id in G67Podzemka.ROOMS:
			var q: Array = G67Podzemka.ROOMS[id]
			if p.x >= float(q[0]) and p.x <= float(q[1]) and p.z >= float(q[2]) and p.z <= float(q[3]):
				return "ПЗ:" + String(id)
		return "ПЗ:?"
	var pp: Vector3 = main.game.player.global_position
	return "двор:%s%s" % ["С" if -pp.z > 30.0 else ("Ю" if -pp.z < -40.0 else "Ц"), "В" if pp.x > 40.0 else ("З" if pp.x < -40.0 else "")]

func _start() -> void:
	await until(func(): return main.menu != null and is_instance_valid(main.menu), 15.0)
	await wait(1.5)
	await shot("00_menu")
	var mm = main.menu
	var names: Array = []
	for it in mm.ITEMS:
		names.append(String(it[0]))
	var want := names.find("PLAY")
	for i in names.size() + 1:
		if mm.sel == want:
			break
		await tap(KEY_S)
	note("МЕНЮ", "клавишами дошли до PLAY: %s" % str(mm.sel == want))
	await tap(KEY_ENTER)
	await wait(1.0)
	var idx: int = ModeSelect.index_of("golda67")
	for i in 10:
		if mm.modes.sel == idx:
			break
		await tap(KEY_D)
		await wait(0.15)
	await shot("01_modes")
	note("МЕНЮ", "карточка ГОЛДА 67 выбрана: %s (карточка %d)" % [str(mm.modes.sel == idx), mm.modes.sel])
	await tap(KEY_ENTER)
	await wait(0.8)
	await shot("02_golda_panel")
	if OS.get_cmdline_user_args().has("--pt-new"):                 # «НОВАЯ ИГРА»: вниз на пункт, подтверждение — вверх с «НАЗАД» на «НАЧАТЬ С НУЛЯ»
		var had := G67Save.exists()
		var m0: Dictionary = G67Save.load_all()["meta"] if had else {}
		await tap(KEY_S)
		await wait(0.3)
		await tap(KEY_ENTER)
		await wait(0.8)
		await shot("02b_new_confirm")
		await tap(KEY_W)
		await wait(0.3)
		await tap(KEY_ENTER)
		var ok_new: bool = await until(func(): return G() != null, 40.0)
		var m1: Dictionary = G67Save.load_all()["meta"] if G67Save.exists() else {}
		var olds := Array(DirAccess.get_files_at(OS.get_user_data_dir())).filter(func(f): return String(f).begins_with("golda67_save_old_"))
		note("НОВАЯ ИГРА", "было сохранение %s (РЕСПЕКТ %d, забегов %d, флаги %s) → игра запущена %s, теперь РЕСПЕКТ %d, забегов %d, флаги %s, ролики %s, копий старого %d" % [str(had),
			int(m0.get("respect", 0)), int(m0.get("runs", 0)), str(m0.get("flags", {})), str(ok_new), int(m1.get("respect", 0)), int(m1.get("runs", 0)), str(m1.get("flags", {})), str(m1.get("clips_seen", [])), olds.size()])
		if not ok_new:
			_finish()
			return
		set_process(true)
		return
	await tap(KEY_ENTER)
	var ok: bool = await until(func(): return G() != null, 40.0)
	note("МЕНЮ", "игра ГОЛДА 67 запущена из меню: %s" % str(ok))
	if not ok:
		_finish()
		return
	set_process(true)

func _ui_tick(gg, g) -> bool:
	if gg.clip != null:
		var cid := String(gg.clip.get("id")) if "id" in gg.clip else "?"
		if not seen.has("clip_" + cid + str(runs)):
			seen["clip_" + cid + str(runs)] = true
			clips_seen.append(cid)
			note("РОЛИК", "%s (зона %s)" % [cid, zone_name()])
			_later_shot("clip_%s" % cid, 3.0)
		stop()
		return true
	if g.mode == "dlg":
		stop()
		if not in_dlg:
			in_dlg = true
			dlg_n += 1
			dlg_t = 0.0
		dlg_t += get_process_delta_time()
		if dlg_t > 90.0 and not seen.has("dlg_long%d" % dlg_n):
			seen["dlg_long%d" % dlg_n] = true
			note("ЗАВИС", "диалог не кончается 90 с: зона %s" % zone_name())
		if ui_cd <= 0.0:
			ui_cd = 0.5
			tap(KEY_ENTER)
		return true
	in_dlg = false
	if gg.hub_ui != null:
		stop()
		var kind := String(gg.hub_ui.kind)
		if not seen.has("ui_" + kind):
			seen["ui_" + kind] = true
			note("ЭКРАН", kind)
			_later_shot("ui_" + kind, 0.6)
		if not seen.has("ui_open_%d" % gg.hub_ui.get_instance_id()):
			seen["ui_open_%d" % gg.hub_ui.get_instance_id()] = true
			ui_cd = 0.8                      # экран только что открылся: первые доли секунды он нажатий не принимает
		if ui_cd <= 0.0:
			ui_cd = 1.4
			if kind == "choice":
				var n_opt: int = gg.hub_ui.items.size()
				var idx: int = (runs + choice_n) % maxi(1, n_opt)
				choice_n += 1
				for k in n_opt:                      # закрытый вариант не выбрать — берём следующий открытый
					if bool(gg.hub_ui.items[idx]["node"].enabled):
						break
					idx = (idx + 1) % n_opt
				note("ВЫБОР", "вариант %d из %d: «%s» (%s)" % [idx + 1, n_opt, String(gg.hub_ui.items[idx]["key"]), zone_name()])
				_pick(idx)
			elif kind in ["fit", "result"]:
				tap(KEY_ENTER)
			elif kind == "kiosk":
				if not seen.has("kiosk_bought" + String(gg.shop) + str(runs)):
					seen["kiosk_bought" + String(gg.shop) + str(runs)] = true
					var hp_b: float = g.player.hp
					var gold_b: int = int(gg.run.get("golda", 0))
					tap(KEY_ENTER)
					_buy_report(gg, g, hp_b, gold_b)
				else:
					tap(KEY_ESCAPE)
			else:
				tap(KEY_ESCAPE)
		return true
	if g.panel != null or get_tree().paused:
		stop()
		if ui_cd <= 0.0:
			ui_cd = 1.2
			tap(KEY_ENTER)
		return true
	return false

func _buy_report(gg, g, hp_b: float, gold_b: int) -> void:
	await wait(0.8)
	note("ПОКУПКА", "ларёк: здоровье %d → %d, голда %d → %d" % [int(hp_b), int(g.player.hp), gold_b, int(gg.run.get("golda", 0))])

func _later_shot(nm: String, t: float) -> void:
	await wait(t)
	shots += 1
	await shot("%02d_%s" % [shots, nm])

func _process(dt: float) -> void:
	var gg = G()
	if gg == null:
		return
	var g = main.game
	var p = g.player
	t_all += dt
	ui_cd -= dt
	atk_cd -= dt
	roll_cd -= dt
	use_cd -= dt
	side_t -= dt
	if t_all > minutes * 60.0:
		set_process(false)
		_finish()
		return
	# --- наблюдение: кадр, камера, падение
	var zn := zone_name()
	var fz: Array = fps_zone.get(zn, [0.0, 0, 0.0])
	fz[0] = float(fz[0]) + dt
	fz[1] = int(fz[1]) + 1
	fz[2] = maxf(float(fz[2]), dt)
	fps_zone[zn] = fz
	if p.global_position.y < -30.0 and not seen.has("fell%d" % fell):
		seen["fell%d" % fell] = true
		fell += 1
		note("ПРОВАЛ", "герой под миром: %s зона %s" % [str(p.global_position), zn])
		_later_shot("fell", 0.1)
	if gg.clip == null and g.mode != "dlg" and gg.hub_ui == null and not g.intro_busy():
		cam_frames += 1
		var q := PhysicsRayQueryParameters3D.create(g.cam.global_position, p.global_position + Vector3(0, 1.4, 0))
		q.exclude = [p.get_rid()]
		q.collision_mask = 8
		if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			cam_bad += 1
			cam_bad_at[zn] = int(cam_bad_at.get(zn, 0)) + 1
			if int(cam_bad_at[zn]) == 30:
				note("КАМЕРА", "между камерой и героем преграда уже 30 кадров: зона %s, герой %s, камера %s" % [zn, str(p.global_position), str(g.cam.global_position)])
				_later_shot("cam_" + zn.replace(":", "_"), 0.05)
	log_t -= dt
	if log_t <= 0.0:
		log_t = 5.0
		say("t=%d с зона %s место %s цель «%s» hp %d/%d состояние %s/%s голда %d FPS %d" % [int(t_all), zn, gg.place, last_goal, ceili(p.hp), int(p.max_hp), gg.room_state, g.mode,
			int(gg.run.get("golda", 0)) if not gg.run.is_empty() else 0, int(Engine.get_frames_per_second())])
	shot_t -= dt
	if shot_t <= 0.0:
		shot_t = 25.0
		shots += 1
		shot("%02d_t%04d_%s" % [shots, int(t_all), zn.replace(":", "_")])
	if g.over or (g.death != null):
		stop()
		if not dead_now:
			dead_now = true
			deaths += 1
			note("СМЕРТЬ", "№%d в зоне %s, комната %s, побеждено за забег %d, ударов нанесено %d" % [deaths, zn, str(gg.room), int(gg.run.get("kills", 0)) if not gg.run.is_empty() else -1, n_atk])
			_later_shot("death", 1.0)
		if ui_cd <= 0.0:
			ui_cd = 1.5
			tap(KEY_ENTER)
		return
	dead_now = false
	if g.intro_busy() and gg.clip == null and gg.hub_ui == null and g.mode != "dlg":
		stop()
		return
	_watch(gg, g, p, dt)
	if immortal and is_instance_valid(p) and p.hp > 0.0 and p.hp < p.max_hp:
		p.hp = p.max_hp
	if _ui_tick(gg, g):
		return
	# --- что делать
	if gg.place == "hub":
		_hub(gg, g, p, dt)
	else:
		_run_tick(gg, g, p, dt)
	_stuck(gg, p, dt)

func _hub(gg, g, p, dt: float) -> void:
	last_goal = "выйти во двор"
	if not seen.has("hub%d" % runs):
		seen["hub%d" % runs] = true
		note("ПОДЪЕЗД", "вход №%d: герой %s, точек %d" % [runs + 1, str(p.global_position), gg.world.points.size()])
		_later_shot("hub", 1.0)
		use_cd = 4.0                              # не выходим в ту же секунду: ролик возвращения запускается через 1,2 с
		if runs > 0:                              # повторный вход: снова к тем, у кого бывает новое — DJ FLÜRR, телевизор, КРОТ, почта, доска
			hub_list = []
			for hid in ["flurr", "krot", "tv", "mail", "notices", "upgrades"]:
				if not gg.point(hid).is_empty():
					hub_list.append(hid)
			hub_i = 0
			hub_t = 0.0
			hub_res = {}
			seen.erase("hub_toured")
			note("ПОДЪЕЗД", "повторный обход: %s" % ", ".join(hub_list))
	if _hub_tour(gg, g, p, dt):
		return
	var pt: Dictionary = gg.point("exit")
	if pt.is_empty():
		return
	var to: Vector3 = pt["pos"]
	if p.global_position.y > 1.0:                    # с площадки — сначала вниз по пролёту
		to = _hub_stairs(p, false)
	if String(gg.near) == "exit":
		stop()
		if use_cd <= 0.0:
			use_cd = 1.5
			runs += 1
			tap(KEY_E)
		return
	go(to)

func _run_tick(gg, g, p, dt: float) -> void:
	if not seen.has("run_in%d" % runs):
		seen["run_in%d" % runs] = true
		note("ЗАБЕГ", "район %s, герой %s" % [String(gg.run.get("district", "?")), str(p.global_position)])
	var dist_now := String(gg.run.get("district", "?"))
	if dist_now != last_dist:
		if last_dist != "":
			note("ПЕРЕХОД", "%s → %s: герой %s, камера %s, бафов %d, голда %d, предметы %s" % [last_dist, dist_now, str(p.global_position), str(g.cam.global_position), (gg.run.get("fits", {}) as Dictionary).size(), int(gg.run.get("golda", 0)), str(gg.run.get("items", {}))])
			_later_shot("arrive_" + dist_now, 0.6)
		last_dist = dist_now
	var goal: Dictionary = gg.minimap.goal() if gg.minimap != null else {"text": "", "pos": null}
	var gtext := String(goal.get("text", ""))
	if gtext != last_goal:
		note("ЦЕЛЬ", "«%s» (зона %s, прошло %d с с прошлой)" % [gtext, zone_name(), int(goal_t)])
		last_goal = gtext
		goal_t = 0.0
		_later_shot("goal", 0.8)
	goal_t += dt
	if goal_t > 240.0 and not seen.has("slow_" + gtext):
		seen["slow_" + gtext] = true
		note("ДОЛГО", "цель «%s» не выполнена за 4 минуты: зона %s, герой %s" % [gtext, zone_name(), str(p.global_position)])
	if p.hp < p.max_hp * 0.45 and gg.item_n("thermos") > 0 and use_cd <= 0.0:
		use_cd = 1.0
		if pad:
			pad_btn(JOY_BUTTON_DPAD_LEFT)
		else:
			tap(KEY_Z)
		note("ПРЕДМЕТ", "термос, здоровье %d" % int(p.hp))
	# бой
	var foe = null
	var fd := 99.0
	if gg.room_state in ["fight", "boss"]:
		for e in g.enemies:
			if is_instance_valid(e) and e.alive() and not bool(e.get("post")):
				var d: float = e.global_position.distance_to(p.global_position)
				if String(e.kind) == "hater" and d < 14.0:
					d *= 0.5                     # стрелка достаём первым: издалека он опаснее всех
				if d < fd:
					fd = d
					foe = e
	if foe != null:
		if not seen.has("fight_" + str(gg.room) + str(runs)):
			seen["fight_" + str(gg.room) + str(runs)] = true
			note("БОЙ", "%s, врагов %d, здоровье %d, побеждено за забег %d" % [str(gg.room), g.enemies.size(), int(p.hp), int(gg.run.get("kills", 0))])
			_later_shot("fight", 1.5)
		var danger := false
		for e in g.enemies:
			if is_instance_valid(e) and e.alive() and String(e.state) in ["wind", "special"] and e.global_position.distance_to(p.global_position) < 3.6:
				danger = true
		fd = foe.global_position.distance_to(p.global_position)
		last_fd = fd
		dbg_t -= dt
		if dbg_t <= 0.0:
			dbg_t = 1.0
			var q2 := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.0, 0), foe.global_position + Vector3(0, 1.0, 0), 1)
			q2.exclude = [p.get_rid(), foe.get_rid()]
			var hit2: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q2)
			say("  бой: до врага %.1f (%s, %s) герой %s hp %d ударов %d | герой (%.1f, %.1f) враг (%.1f, %.1f) между ними %s" % [fd, String(foe.kind), String(foe.state), String(p.state), int(p.hp), n_atk,
				p.global_position.x, p.global_position.z, foe.global_position.x, foe.global_position.z, ("преграда " + String(hit2["collider"].name) + " " + str((hit2["position"] as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))) if not hit2.is_empty() else "свободно"])
		if danger and roll_cd <= 0.0:
			roll_cd = 0.9
			var off: Vector3 = (p.global_position - foe.global_position).normalized()
			go(p.global_position + Vector3(-off.z, 0, off.x) * 4.0)          # уклонение вбок: с места боя не уходим
			if pad:
				pad_btn(JOY_BUTTON_B)
			else:
				tap(KEY_SHIFT)
			return
		var ctr = null
		if gg.turf != null and not gg.turf.active.is_empty():
			ctr = gg.turf.active["c"]
		if fd > 2.1:
			hold(KEY_C, false)
			go(foe.global_position)
		else:
			hold(KEY_C, false)
			if fd > 1.3:
				go(foe.global_position)        # не отпускаем направление: герой бьёт туда, куда идёт
			else:
				stop()
			if atk_cd <= 0.0:
				atk_cd = 0.27
				attack(n_atk % 3 == 2)
			hits_log(gg, p)
		return
	if _event_tick(gg, g, p, dt):
		return
	if _side(gg, g, p, dt):
		return
	# точка под рукой: сумка, прилавок, ларёк, передышка, ворота, события
	var near := String(gg.near)
	if near != "" and use_cd <= 0.0 and (near.begins_with("bag_") or near in ["rags_dv", "rest_dv", "elite_fit"] or (near == "krot" and not seen.has("krot" + str(runs))) or near.begins_with("gate") or (near == "kiosk" and not seen.has("kiosk" + str(runs)))
			or (near.begins_with("evdv_") and not seen.has(near + str(runs))) or (near == "trader_dv" and not seen.has("trader" + str(runs))) or (near.begins_with("secret") and true)
			or (near in ["ev_button", "ev_burmalda"] and not seen.has(near + str(runs)))):
		use_cd = 2.0
		seen[near + str(runs)] = true
		if near == "kiosk":
			seen["kiosk" + str(runs)] = true
		if near == "trader_dv":
			seen["trader" + str(runs)] = true
		note("ВЗАИМОДЕЙСТВИЕ", "[E] %s" % near)
		stop()
		if pad:
			pad_btn(JOY_BUTTON_RIGHT_SHOULDER)
		else:
			tap(KEY_E)
		_later_shot("use_" + near, 1.0)
		return
	# спуск в Подземку ногами: решётка → марш → площадка → проём → коридор (точки читаются у района, как у игрока с глаз)
	if gg.world.dvor != null and gg.world.dvor.gate_open and gtext.find("Подземку") >= 0 and gg.room_state == "open":
		var dv = gg.world.dvor
		var top: Vector3 = dv.stairs_top()
		var bot: Vector3 = dv.stairs_bottom()
		var lk: Vector3 = dv.link_point()
		var pp: Vector3 = p.global_position
		if Vector2(pp.x - top.x, pp.z - top.z).length() < 2.0 or pp.y < -0.3:
			if not seen.has("desc%d" % runs):
				seen["desc%d" % runs] = true
				note("СПУСК", "у решётки, иду вниз по лестнице: герой %s" % str(pp))
				_later_shot("descent_top", 0.3)
			var door := Vector3(bot.x, bot.y, bot.z + 3.6)
			if pp.y > -4.6:
				go(bot)
				if pp.y < -2.0 and not seen.has("desc_mid%d" % runs):
					seen["desc_mid%d" % runs] = true
					_later_shot("descent_stairs", 0.05)
			elif not seen.has("desc_door%d" % runs):
				go(door)
				if pp.distance_to(door) < 0.7:
					seen["desc_door%d" % runs] = true
					_later_shot("descent_landing", 0.05)
			else:
				go(lk)
				if pp.distance_to(lk) < 3.0 and not seen.has("desc_corr%d" % runs):
					seen["desc_corr%d" % runs] = true
					_later_shot("descent_corridor", 0.05)
			return
	var gp = goal.get("pos")
	if p.hp < p.max_hp * 0.7 and gg.world.dvor != null and int(gg.run.get("golda", 0)) >= 30 and not seen.has("kiosk" + str(runs)) and gg.room_state == "open":
		var kp: Dictionary = gg.point("kiosk")
		if not kp.is_empty():
			if not seen.has("heal_go" + str(runs)):
				seen["heal_go" + str(runs)] = true
				note("РЕШЕНИЕ", "здоровья %d — иду к «ШАУРМЕ 67» за лечением" % int(p.hp))
			gp = kp["pos"]
			gg.minimap._route(p.global_position, gp)
	if gp == null or gp == Vector3.INF:
		stop()
		return
	# идём по маршруту мини-карты: точка в нескольких метрах впереди
	var path: PackedVector2Array = gg.minimap.path
	var to: Vector3 = gp
	if path.size() >= 3:
		var here := Vector2(p.global_position.x, p.global_position.z)
		var k := 1
		while k < path.size() - 1 and path[k].distance_to(here) < (1.7 if G67District.is_podzemka() else 3.0):
			k += 1
		to = Vector3(path[k].x, p.global_position.y, path[k].y)
	go(to)

var dbg_t := 0.0
var last_fd := 99.0
var hp_last := -1.0
var dmg_in := 0.0
var fight_t0 := 0.0

func hits_log(_gg, p) -> void:
	if hp_last >= 0.0 and p.hp < hp_last:
		dmg_in += hp_last - p.hp
	hp_last = p.hp

func _stuck(gg, p, dt: float) -> void:
	if not moving or (gg.room_state in ["fight", "boss"] and last_fd < 3.0):        # вплотную к врагу толкотня — не застревание
		stuck_t = 0.0
		stuck_from = p.global_position
		return
	stuck_t += dt
	if stuck_t < (1.2 if gg.room_state in ["fight", "boss"] else 2.5):
		return
	var moved: float = Vector2(p.global_position.x - stuck_from.x, p.global_position.z - stuck_from.z).length()
	stuck_t = 0.0
	stuck_from = p.global_position
	if moved > 0.6:
		stuck_n = 0
		return
	stuck_n += 1
	stuck_total += 1
	side_k += 1
	side_t = 1.2
	if gg.room_state in ["fight", "boss"]:
		var sp := p.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
		var info: Array = []
		for hgt in [0.15, 0.5, 1.0]:
			for dv in [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)]:
				var qq := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, hgt, 0), p.global_position + Vector3(0, hgt, 0) + dv * 1.5, 0xFFFFFFFF)
				qq.exclude = [p.get_rid()]
				var hh: Dictionary = sp.intersect_ray(qq)
				if not hh.is_empty():
					var cn: Node = hh["collider"]
					info.append("h%.2f %s: %s/%s слой %d на %.2f м" % [hgt, str(dv), String(cn.get_parent().name), String(cn.name), int(cn.get("collision_layer")), (hh["position"] as Vector3).distance_to(p.global_position + Vector3(0, hgt, 0))])
		var sq := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.6
		sq.shape = sph
		sq.transform = Transform3D(Basis(), p.global_position + Vector3(0, 0.9, 0))
		sq.collision_mask = 0xFFFFFFFF
		sq.exclude = [p.get_rid()]
		for hit3 in sp.intersect_shape(sq, 8):
			var c3: Node = hit3["collider"]
			if c3 is Node3D and not (c3 as Node3D).global_position.y < -0.4:
				info.append("рядом %s/%s (%s) в %s слой %d" % [String(c3.get_parent().name), String(c3.name), c3.get_class(), str((c3 as Node3D).global_position.snapped(Vector3(0.1, 0.1, 0.1))), int(c3.get("collision_layer"))])
		say("  упёрся в бою: герой %s скорость %s на полу %s | %s" % [str(p.global_position), str(p.velocity.snapped(Vector3(0.1, 0.1, 0.1))), str(p.is_on_floor()), " ; ".join(info)])
		side_t = 1.6                       # в бою обходим препятствие молча: это не находка, а манёвр
		tap(KEY_SPACE)
		return
	note("STUCK", "№%d подряд: герой %s, зона %s, цель «%s», состояние героя %s" % [stuck_n, str(p.global_position), zone_name(), last_goal, String(p.state)])
	if stuck_n == 1:
		_later_shot("stuck", 0.05)
	tap(KEY_SPACE)
	if stuck_n >= 8:
		stuck_n = 0
		var key := "%d_%d_%s" % [int(p.global_position.x / 3.0), int(p.global_position.z / 3.0), last_goal]
		if not blocked.has(key):
			blocked.append(key)
			note("BLOCKED", "не пройти: герой %s, зона %s, цель «%s»" % [str(p.global_position), zone_name(), last_goal])
			_later_shot("blocked", 0.05)

func _finish() -> void:
	stop()
	say("==== ИТОГ: время %d с, забегов начато %d, смертей %d, застреваний %d, мест без прохода %d, провалов под мир %d" % [int(t_all), runs, deaths, stuck_total, blocked.size(), fell])
	say("ролики: %s" % str(clips_seen))
	say("камера: кадров с преградой %d из %d (%.1f %%), по зонам %s" % [cam_bad, cam_frames, 100.0 * float(cam_bad) / maxf(1.0, float(cam_frames)), str(cam_bad_at)])
	for zn in fps_zone:
		var fz: Array = fps_zone[zn]
		if int(fz[1]) > 30:
			say("кадр %s: средний %.0f FPS, худший кадр %.0f мс, время %.0f с" % [zn, float(fz[1]) / maxf(0.001, float(fz[0])), float(fz[2]) * 1000.0, float(fz[0])])
	var gg = G()
	if gg != null:
		say("сохранение: флаги %s, забегов %d, респект %d" % [str(gg.meta().get("flags", {})), int(gg.meta().get("runs", 0)), int(gg.meta().get("respect", 0))])
	await shot("zz_end")
	print("G67PT конец")
	get_tree().quit()


# ================================================================== обход и события
func _pick(idx: int) -> void:
	for i in idx:
		await tap(KEY_S)
		await wait(0.08)
	await tap(KEY_ENTER)

## Сторож: ничего не меняется две с половиной минуты вне боя — запись «ЗАВИС»
func _watch(gg, g, p, dt: float) -> void:
	var sig := "%s|%s|%s|%d|%d|%s|%s" % [gg.place, gg.room_state, last_goal, int(p.global_position.x / 2.0), int(p.global_position.z / 2.0), g.mode, str(gg.hub_ui != null) + str(gg.clip != null)]
	if sig != w_sig or gg.room_state in ["fight", "boss"]:
		w_sig = sig
		w_t = 0.0
		return
	w_t += dt
	if w_t > 150.0 and not seen.has("stall_" + sig):
		seen["stall_" + sig] = true
		note("ЗАВИС", "150 с без изменений: место %s, состояние %s/%s, цель «%s», герой %s, экран %s, ролик %s, событие «%s»" % [gg.place, gg.room_state, g.mode, last_goal, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))),
			String(gg.hub_ui.kind) if gg.hub_ui != null else "нет", str(gg.clip != null), String(gg.dvev.act) if gg.get("dvev") != null and is_instance_valid(gg.dvev) else ""])
		_later_shot("stall", 0.05)

func _hub_stairs(p, up: bool) -> Vector3:
	var fx: float = (-G67World.HUB_X + G67World.STAIR_X) * 0.5
	var low := Vector3(fx, 0.0, G67World.Z_EDGE + 1.6)
	var high := Vector3(fx, G67World.LAND_Y, G67World.Z_STAIR_TOP - 1.0)
	var pp: Vector3 = p.global_position
	if up:
		return low if (pp.y < 0.3 and Vector2(pp.x - low.x, pp.z - low.z).length() > 1.0 and not (absf(pp.x - fx) < 0.9 and pp.z < low.z + 0.3)) else high
	return high if (pp.y > 1.2 and Vector2(pp.x - high.x, pp.z - high.z).length() > 1.0 and not (absf(pp.x - fx) < 0.9 and pp.z > high.z - 0.3)) else low

## Подъезд: подойти к каждому предмету и нажать [E] — один раз за запуск
func _hub_tour(gg, g, p, dt: float) -> bool:
	if seen.has("hub_toured"):
		return false
	if hub_list.is_empty() and runs == 0:
		for pt in gg.world.points:
			if String(pt["id"]) != "exit":
				hub_list.append(String(pt["id"]))
		note("ПОДЪЕЗД", "обход предметов (%d): %s" % [hub_list.size(), ", ".join(hub_list)])
	if hub_i >= hub_list.size():
		seen["hub_toured"] = true
		var bad: Array = []
		for id in hub_list:
			if String(hub_res.get(id, "")) != "ok":
				bad.append("%s — %s" % [id, String(hub_res.get(id, "?"))])
		note("ПОДЪЕЗД", "обход закончен: открыто %d из %d%s" % [hub_list.size() - bad.size(), hub_list.size(), ("; не вышло: " + "; ".join(bad)) if not bad.is_empty() else ""])
		return false
	var id := String(hub_list[hub_i])
	var pt: Dictionary = gg.point(id)
	hub_t += dt
	if hub_used:
		if use_cd <= 0.0:
			hub_used = false
			hub_i += 1
			hub_t = 0.0
		return true
	if pt.is_empty() or hub_t > 40.0:
		hub_res[id] = "нет точки" if pt.is_empty() else "не дошёл за 40 с (герой %s, точка %s)" % [str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(pt["pos"])]
		note("ПОДЪЕЗД", "%s: %s" % [id, String(hub_res[id])])
		hub_i += 1
		hub_t = 0.0
		return true
	if String(gg.near) == id:
		stop()
		if use_cd <= 0.0:
			use_cd = 2.6
			hub_used = true
			hub_res[id] = "ok"
			note("ПОДЪЕЗД", "[E] %s" % id)
			tap(KEY_E)
			_later_shot("hub_" + id, 1.2)
		return true
	var to: Vector3 = pt["pos"]
	if to.y > 1.0 and p.global_position.y < 1.0:
		to = _hub_stairs(p, true)
	elif to.y < 1.0 and p.global_position.y > 1.0:
		to = _hub_stairs(p, false)
	go(to)
	return true

## Что обойти в этом забеге, кроме главной цели: события, торговец, кнопка, автомат, точки и ролики Подземки, двое жителей для удара
func _side_build(gg) -> void:
	side_q = []
	side_cur = {}
	for pt in gg.world.points:
		var id := String(pt["id"])
		if id.begins_with("evdv_") or id in ["ev_button", "ev_burmalda", "trader_dv", "clip_tariff", "clip_cl02", "clip_seller", "clip_cctv", "pz_change", "pz_cert", "balloon", "slot", "shutter", "hamster_door", "krot", "flurr", "reserve_table"] or id.begins_with("bottle"):
			side_q.append({"id": id, "kind": "point", "pos": pt["pos"]})
	if gg.get("folk") != null and gg.folk != null and is_instance_valid(gg.folk) and gg.world.dvor != null:
		var took := {}
		for f in gg.folk.folk:
			var tm := String((f["d"] as Dictionary).get("temper", ""))
			if not took.has(tm) and tm in ["push", "scold", "flee"] and not String(f["id"]).begins_with("ev_") and not String(f["id"]).begins_with("cf_"):
				took[tm] = true
				side_q.append({"id": "hit_" + String(f["id"]), "kind": "hit", "pos": (f["rig"] as Node3D).global_position, "node": f["rig"], "temper": tm})
	note("ОБХОД", "побочных целей %d: %s" % [side_q.size(), ", ".join(side_q.map(func(q): return String(q["id"])))])

func _side_path(gg, from: Vector3, to: Vector3) -> Vector3:
	var M = gg.minimap
	if M == null or M.grid == null:
		return to
	side_path_t -= get_process_delta_time()
	if side_path_t <= 0.0 or side_path.size() < 2:
		side_path_t = 1.0
		side_path = PackedVector2Array()
		var a: Vector2i = M._free_near(M._cell_of(Vector2(from.x, from.z)))
		var b: Vector2i = M._free_near(M._cell_of(Vector2(to.x, to.z)))
		if a.x != 999999 and b.x != 999999:
			var pts: PackedVector2Array = M.grid.get_point_path(a, b)
			for q in pts:
				side_path.append(q + Vector2(M.cell, M.cell) * 0.5)
		if side_path.size() < 2:
			if a == b:
				return to
			say("  путь: нет — от %s (клетка %s) до %s (клетка %s), точек %d" % [str(from.snapped(Vector3(0.1, 0.1, 0.1))), str(a), str(to.snapped(Vector3(0.1, 0.1, 0.1))), str(b), side_path.size()])
			return Vector3.INF
	var here := Vector2(from.x, from.z)
	var k := 0
	var look: float = 1.7 if G67District.is_podzemka() else 3.0
	while k < side_path.size() - 1 and side_path[k].distance_to(here) < look:
		k += 1
	if k >= side_path.size() - 1:
		return to
	return Vector3(side_path[k].x, from.y, side_path[k].y)

func _side(gg, g, p, dt: float) -> bool:
	if not (gg.room_state in ["open", "reward"]) or gg.minimap == null or (skip_dvor and not G67District.is_podzemka()):
		return false
	if side_built != runs * 10 + (1 if G67District.is_podzemka() else 0):
		side_built = runs * 10 + (1 if G67District.is_podzemka() else 0)
		_side_build(gg)
	if p.hp < p.max_hp * 0.45:
		return false                              # сначала лечиться и главная цель
	if gg.turf != null:
		for e in gg.turf.encs:
			if not (e["bag"] as Dictionary).is_empty():
				return false                      # сумка важнее
	if side_cur.is_empty():
		var best := -1
		var bd := 85.0 if G67District.is_podzemka() else 120.0
		for i in side_q.size():
			var q: Dictionary = side_q[i]
			var pos: Vector3 = (q["node"] as Node3D).global_position if q.has("node") and is_instance_valid(q["node"]) else q["pos"]
			if absf(pos.y - p.global_position.y) > 3.5:
				continue
			if String(q["id"]) == "reserve_table" and (gg.run.get("bottles", []) as Array).size() < 5:
				continue                          # стол за закрытой дверью: откроется после пятой бутылки
			var d: float = pos.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = i
		if best < 0:
			return false
		side_cur = side_q[best]
		side_q.remove_at(best)
		side_time = 0.0
		side_path = PackedVector2Array()
		hit_t = 0.0
	var id := String(side_cur["id"])
	var kind := String(side_cur["kind"])
	var pos2: Vector3 = (side_cur["node"] as Node3D).global_position if side_cur.has("node") and is_instance_valid(side_cur["node"]) else side_cur["pos"]
	side_time += dt
	if kind == "point" and gg.point(id).is_empty():
		side_res.append([id, "точка исчезла"])
		side_cur = {}
		return true
	if kind == "point":
		pos2 = gg.point(id)["pos"]
	if side_time > 90.0:
		side_res.append([id, "не дошёл за 90 с"])
		note("ОБХОД", "%s: не дошёл за 90 с (герой %s, цель %s)" % [id, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(pos2.snapped(Vector3(0.1, 0.1, 0.1)))])
		_later_shot("side_fail_" + id, 0.05)
		side_cur = {}
		return true
	if kind == "point":
		if String(gg.near) == id:
			stop()
			if use_cd <= 0.0:
				use_cd = 2.5
				seen[id + str(runs)] = true
				if id == "kiosk":
					seen["kiosk" + str(runs)] = true
				note("ОБХОД", "[E] %s (зона %s, голда %d)" % [id, zone_name(), int(gg.run.get("golda", 0))])
				if pad:
					pad_btn(JOY_BUTTON_RIGHT_SHOULDER)
				else:
					tap(KEY_E)
				_later_shot("side_" + id, 1.4)
				side_res.append([id, "ok"])
				if id in ["shutter", "hamster_door"] and not seen.has("again_" + id + str(runs)):      # первое нажатие — ролик, дверь открывает второе
					seen["again_" + id + str(runs)] = true
					side_q.push_front({"id": id, "kind": "point", "pos": side_cur["pos"]})
					if id == "hamster_door":
						side_q.push_front({"id": "hamster_game", "kind": "point", "pos": side_cur["pos"]})
				side_cur = {}
			return true
	else:
		var d2: float = pos2.distance_to(p.global_position)
		if d2 < 1.45 or (d2 < 2.2 and hit_t > 0.0):
			hit_t += dt
			go(pos2)                              # лицом к жителю: удар идёт туда, куда смотрит герой
			if hit_t >= 0.5:
				if use_cd <= 0.0 and not seen.has("did_" + id + str(runs)):
					seen["did_" + id + str(runs)] = true
					use_cd = 2.5
					var hp0: float = p.hp
					var n0: int = gg.folk.log.size()
					attack(false)
					_hit_report(gg, p, id, String(side_cur.get("temper", "")), hp0, n0)
				elif use_cd <= 0.0:
					side_res.append([id, "ok"])
					side_cur = {}
			return true
	var to: Vector3 = _side_path(gg, p.global_position, pos2)
	if to == Vector3.INF:
		side_res.append([id, "нет пути по сетке"])
		note("ОБХОД", "%s: нет пути по сетке" % id)
		side_cur = {}
		return true
	go(to)
	return true

func _hit_report(gg, p, id: String, temper: String, hp0: float, n0: int) -> void:
	await wait(2.0)
	var got: Array = []
	for i in range(n0, gg.folk.log.size()):
		got.append(String(gg.folk.log[i][0]))
	note("УДАР ПО МИРНОМУ", "%s (характер %s): реакции %s, здоровье героя %d → %d, ударов по мирным за забег %d" % [id, temper, str(got), int(hp0), int(p.hp), int(gg.run.get("npc_hits", 0))])

## Мини-игры событий двора: читаем состояние события, жмём только клавиши
func _event_tick(gg, g, p, dt: float) -> bool:
	if gg.get("dvev") == null or gg.dvev == null or not is_instance_valid(gg.dvev) or gg.room_state != "open":
		return false
	var E = gg.dvev
	var act := String(E.act)
	if act == "" or E.state(act) != "task":
		for id in (gg.run.get("ev", {}) as Dictionary):
			var stv := String(gg.run["ev"][id])
			if stv in ["done", "fail", "left"] and String(ev_log.get(id + str(runs), "")) != stv:
				ev_log[id + str(runs)] = stv
				note("СОБЫТИЕ", "%s: исход «%s», голда %d, предметы %s, пройдено событий %d" % [String(id), stv, int(gg.run.get("golda", 0)), str(gg.run.get("items", {})), int(gg.run.get("ev_done", 0))])
		return false
	var st: Dictionary = E.st
	match act:
		"arm", "stuck":
			stop()
			if String(st.get("phase", "")) == "wait":
				_ev_wait(gg, p, act)
			elif E.beat_open() and use_cd <= 0.0:
				use_cd = 0.6
				tap(KEY_E)
		"fridge":
			if String(st.get("phase", "")) == "carry":
				go(p.global_position + Vector3(-4.0, 0, 0.6))
			elif String(st.get("phase", "")) == "wait":
				_ev_wait(gg, p, act)
			else:
				stop()
		"keys":
			var step := int(st.get("step", 0))
			var kp: Dictionary = gg.point("evdv_keys_%d" % step)
			if kp.is_empty():
				stop()
			elif String(st.get("phase", "")) == "crow" and step == 2:
				if p.global_position.distance_to(kp["pos"]) > 3.5:
					go(_side_path(gg, p.global_position, kp["pos"]))
				else:
					stop()                        # постоять у вороны
			elif String(gg.near) == "evdv_keys_%d" % step:
				stop()
				if use_cd <= 0.0:
					use_cd = 1.2
					tap(KEY_E)
			else:
				var tk: Vector3 = _side_path(gg, p.global_position, kp["pos"])
				go(kp["pos"] if tk == Vector3.INF else tk)
		"queue":
			var spot: Vector3 = st.get("spot", p.global_position)
			if p.global_position.distance_to(spot) > 1.0:
				go(spot)
			else:
				stop()
		_:
			return false
	return true


## Дело началось, но ждёт первого [E] у своей точки
func _ev_wait(gg, p, act: String) -> void:
	var pid := "evdv_" + act
	if String(gg.near).begins_with(pid):
		stop()
		if use_cd <= 0.0:
			use_cd = 1.2
			tap(KEY_E)
		return
	for pt in gg.world.points:
		if String(pt["id"]).begins_with(pid):
			go(pt["pos"])
			return
	stop()
