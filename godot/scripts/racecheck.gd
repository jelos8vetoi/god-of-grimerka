## Проверка гонок на пылесосах: `--resolution 1280x720 -- --racecheck=<папка>`.
## Идёт как игрок: главное меню → PLAY → VACUUM RACING → меню гонок (трасса, соперники, рекорды, управление и
## переназначение клавиши) → SINGLE RACE → облёт и отсчёт (до «ЖМИ» никто не едет) → разгон, тормоз, руль, занос
## (три уровня и ускорение на выходе), турбо, прыжок, трамплин и приземление, стена (не насквозь, отскок),
## толкотня гонщиков, канава (падение и возврат), все шесть предметов и коробка, контрольные точки (пропуск не
## засчитывается), пауза, полная гонка в 3 круга (бот за игрока), финиш игрока и ботов, места и таблица
## результатов, звук, выход в меню гонок, TIME TRIAL, сюжетное сохранение байт в байт и обычная ТЯГА-812 после гонок.
## Снимки трассы и гонки — в папке.
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_display.json", "user://grimerka_audio.json", "user://grimerka_ipod.json", "user://grimerka_training.json", "user://grimerka_race.json"]

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
	print(("RACECHECK ok: " if cond else "RACECHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

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

func inp(th := 0.0, br := 0.0, st := 0.0, drift := false, boost := false, jump := false, item := false) -> RaceInput:
	var r := RaceInput.new()
	r.throttle = th
	r.brake = br
	r.steer = st
	r.drift = drift
	r.boost = boost
	r.jump = jump
	r.item = item
	return r

func peak(b: String) -> float:
	var i := AudioServer.get_bus_index(b)
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0)) if i >= 0 else -200.0

func had(r: RaceRider, k: String, from := 0) -> bool:
	for i in range(from, r.events.size()):
		if String(r.events[i][0]) == k:
			return true
	return false

func count_ev(r: RaceRider, k: String, from := 0) -> int:
	var n := 0
	for i in range(from, r.events.size()):
		if String(r.events[i][0]) == k:
			n += 1
	return n

## поставить гонщика на главную дорогу: путь s, сдвиг поперёк, носом по трассе (+ поворот), со скоростью
func put(r: RaceRider, s: float, lat := 0.0, yaw := 0.0, spd := 0.0) -> void:
	var tr: RaceTrack = main.race.track
	var i := tr.at_s(s)
	var right: Vector3 = tr.T[i].cross(Vector3.UP)
	var h := atan2(tr.T[i].x, tr.T[i].z) + yaw
	r.place(Transform3D(Basis(Vector3.UP, h), tr.P[i] + right * lat + Vector3(0, 0.1, 0)))
	r.speed = spd
	r.proj = tr.project(r.global_position, {})
	r.s = float(r.proj["s"])
	r.prev_s = r.s

## одно нажатие (прыжок, предмет): держим ввод полный шаг физики гонки, потом — следующий
func once(r: RaceRider, a: RaceInput, then: RaceInput) -> void:
	r.set_meta("auto", a)
	await phys(2)
	r.set_meta("auto", then)

## руль «по дороге»: куда повернуть, чтобы держаться середины трассы впереди
func follow(r: RaceRider) -> float:
	var tr: RaceTrack = main.race.track
	var tg: Vector3 = tr.point(r.s + 8.0 + absf(r.speed) * 0.4)
	if r.drifting:
		tg = tr.point(r.s + 14.0)
	var to := tg - r.global_position
	var want := atan2(to.x, to.z)
	if r.drifting:
		return r.steer_for_rate(-angle_difference(atan2(r.vdir.x, r.vdir.z), want) * 2.2)     # в заносе рулят дугой движения
	return clampf(-angle_difference(r.heading, want) * 2.5, -1.0, 1.0)

func freeze_bots(on: bool) -> void:
	for r in main.race.riders:
		if r != main.race.local:
			if on:
				r.set_meta("auto", RaceInput.new())
			elif r.has_meta("auto"):
				r.remove_meta("auto")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	RaceSave.loaded = false
	await wait(2.0)
	# ================= меню =================
	var mm = main.menu
	ok(mm != null and mm.race_ready(), "главное меню открыто, гонки подключены")
	mm.open_modes(2)
	await wait(0.6)
	ok(mm.modes.cards[2]["tag_l"].text == "ДОСТУПНО", "карточка VACUUM RACING — «ДОСТУПНО»")
	await key(KEY_ENTER)
	await wait(0.3)
	var names: Array = []
	for row in mm.panel_rows:
		var tx = row["text"]
		names.append(String(tx.call()) if tx is Callable else String(tx))
	ok(mm.panel != null and names.has("SINGLE RACE") and names.has("TIME TRIAL") and names.has("ONLINE RACE") and names.back() == "НАЗАД", "меню гонок: %s" % ", ".join(names))
	ok(String(names[0]).contains("ТОМСК: ПЫЛЬНЫЙ ЗАЕЗД") and RaceData.TRACK_ORDER.size() == 1, "трасса одна и готовая: «ТОМСК: ПЫЛЬНЫЙ ЗАЕЗД» (будущих в списке нет)")
	await shot("m01_race_menu")
	RaceSave.persist = false                          # проверка не пишет настройки и рекорды игрока
	var lv0 := String(RaceSave.v("level"))
	mm._panel_select(1, false)
	await key(KEY_D)
	ok(String(RaceSave.v("level")) != lv0, "D меняет уровень соперников (%s → %s)" % [lv0, RaceSave.v("level")])
	await key(KEY_A)
	# управление: переназначить газ на T и вернуть
	mm._panel_select(names.find("УПРАВЛЕНИЕ"), false)
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.panel != null and mm.panel_rows.size() == RaceData.ACTIONS.size() + 3, "УПРАВЛЕНИЕ: %d строк" % mm.panel_rows.size())
	await shot("m02_controls")
	mm._panel_select(0, false)
	await key(KEY_ENTER)
	ok(mm.capture.is_valid(), "Enter на «ГАЗ» ждёт клавишу")
	await key(KEY_T)
	ok(RaceSave.keys_of("race_accelerate") == ["T"], "газ переназначен на T (%s)" % str(RaceSave.keys_of("race_accelerate")))
	ok(InputMap.action_get_events("up").size() == 1, "управление кампании не тронуто (up: %d событий)" % InputMap.action_get_events("up").size())
	var sens0 := float(RaceSave.v("steer"))
	mm._panel_select(RaceData.ACTIONS.size(), false)
	await key(KEY_D)
	ok(float(RaceSave.v("steer")) > sens0, "чувствительность руля меняется (%d%%)" % roundi(float(RaceSave.v("steer")) * 100.0))
	await key(KEY_A)
	mm._panel_select(RaceData.ACTIONS.size() + 1, false)
	await key(KEY_ENTER)
	ok(RaceSave.keys_of("race_accelerate").has("W"), "СБРОСИТЬ КЛАВИШИ — газ снова W")
	await key(KEY_ESCAPE)
	await wait(0.3)
	ok(mm.panel != null and mm.panel_rows.size() == names.size(), "Esc из управления — назад в меню гонок")
	# ONLINE RACE — свой экран лобби (сама сеть — --race-netcheck), Esc — назад в меню гонок
	mm._panel_select(names.find("ONLINE RACE"), false)
	await key(KEY_ENTER)
	await wait(0.3)
	ok(mm.online != null and mm.online.visible, "ONLINE RACE открывает экран сетевой игры")
	await shot("m03_online")
	await key(KEY_ESCAPE)
	await wait(0.4)
	ok(mm.panel != null and (mm.online == null or not mm.online.visible) and main.race_net == null, "Esc из ONLINE RACE — назад в меню гонок, сеть не поднята")
	mm._panel_select(names.find("SINGLE RACE"), false)
	# ================= SINGLE RACE =================
	mm._panel_select(names.find("SINGLE RACE"), false)
	await key(KEY_ENTER)
	var started: bool = await until(func(): return main.race != null and is_instance_valid(main.race), 15.0)
	ok(started, "SINGLE RACE запускает гонку")
	if not started:
		_finish()
		return
	var race: Race = main.race
	ok(race.riders.size() == 6 and race.local != null and race.local.rider_id == "pahan", "6 участников: Пахан и пять соперников (%s)" % ", ".join(race.riders.map(func(r): return r.title)))
	ok(main.game == null, "сюжетная игра не создана — отдельный режим")
	ok(race.track.gates.size() == 10 and race.track.L > 400.0, "трасса: круг %.0f м, контрольных точек %d" % [race.track.L, race.track.gates.size()])
	var p0: Vector3 = race.local.global_position
	await until(func(): return race.state == "countdown", 6.0)
	await shot("r01_countdown")
	ok(race.state == "countdown" and not race.go, "облёт, затем отсчёт 3-2-1")
	race.local.set_meta("auto", inp(1.0))
	await wait(1.0)
	ok(race.local.global_position.distance_to(p0) < 0.5, "до «ЖМИ» с газом никто не едет")
	await until(func(): return race.go, 5.0)
	race.local.set_meta("auto", inp(1.0))
	ok(race.go and race.state == "race" and race.hud.count_l.text == "ЖМИ!", "старт: «ЖМИ!»")
	# --- снимки трассы: общий план и участки ---
	freeze_bots(true)
	race.local.set_meta("auto", RaceInput.new())
	var tour := Camera3D.new()
	tour.far = 800.0
	race.add_child(tour)
	tour.current = true
	var tk: RaceTrack = race.track
	var views := [["t01_overview", Vector3(40, 230, 60), Vector3(40, 0, 61)],
		["t02_start", Vector3(-20, 9, -18), Vector3(20, 0, 0)],
		["t03_long_turn", Vector3(120, 22, 40), Vector3(160, 0, 60)],
		["t04_garages", Vector3(118, 7, 120), Vector3(70, 0, 128)],
		["t05_ramp", Vector3(50, 6, 140), Vector3(30, 1, 127)],
		["t06_shortcut_ditch", Vector3(118, 14, 60), Vector3(134, 0, 62)],
		["t07_obstacles", Vector3(-10, 10, 124), Vector3(-45, 0, 96)],
		["t08_final_turn", Vector3(-60, 26, 30), Vector3(-88, 0, 22)]]
	for v in views:
		tour.global_position = v[1]
		tour.look_at(v[2], Vector3.UP if absf((v[1] - v[2]).normalized().y) < 0.99 else Vector3.FORWARD)
		tour.fov = 60.0
		await wait(0.25)
		await shot(String(v[0]))
	tour.queue_free()
	race.cam.current = true
	race.local.place(race.track.grid(0))
	race.local.set_meta("auto", inp(1.0))
	# --- 3. разгон ---
	await wait(2.2)
	var v1: float = race.local.speed
	ok(v1 > 15.0, "разгон: за 2,2 с — %.1f м/с" % v1)
	await shot("r02_accel")
	# --- 4. торможение ---
	race.local.set_meta("auto", inp(0.0, 1.0))
	await wait(0.4)
	ok(race.local.speed < v1 - 8.0, "тормоз: %.1f → %.1f м/с за 0,4 с" % [v1, race.local.speed])
	# --- 5. повороты ---
	var L: RaceRider = race.local
	put(L, race.track.start_s + 30.0, 0.0, 0.0, 14.0)
	var h0 := L.heading
	L.set_meta("auto", inp(1.0, 0.0, 1.0))
	await wait(0.35)
	var dr := angle_difference(h0, L.heading)
	L.set_meta("auto", inp(1.0, 0.0, -1.0))
	await wait(0.35)
	var dl := angle_difference(h0 + dr, L.heading)
	ok(dr < -0.2 and dl > 0.2, "руль: вправо %.2f рад, влево %.2f рад" % [dr, dl])
	# --- 6–7. занос и три уровня ---
	# занос — на длинном повороте, руль подруливает по дороге
	var turn_s: float = race.track.S[race.track.nearest_main(Vector3(128, 0, 6))]
	put(L, turn_s, -1.0, 0.0, 19.0)
	L.boost_t = 0.0
	await phys(3)
	var e0 := L.events.size()
	L.set_meta("auto", inp(1.0, 0.0, 0.8, true))
	await phys(3)
	ok(L.drifting and L.drift_dir > 0.0, "занос: Shift с рулём на скорости — несёт боком")
	var max_drift_v := 0.0
	var walls0 := count_ev(L, "wall", e0)
	var t0 := Time.get_ticks_msec()
	var shot_done := false
	while Time.get_ticks_msec() - t0 < 5000 and L.drifting and L.drift_lvl < 3:
		max_drift_v = maxf(max_drift_v, L.speed)
		L.set_meta("auto", inp(1.0, 0.0, follow(L), true))
		if not shot_done and L.drift_lvl >= 2:
			shot_done = true
			await shot("r03_drift")
		await get_tree().physics_frame
	ok(count_ev(L, "wall", e0) == walls0, "в заносе удаётся пройти длинный поворот без стены")
	ok(count_ev(L, "drift_lvl", e0) == 3 and L.drift_lvl == 3, "заряд заноса: три уровня (%d)" % L.drift_lvl)
	ok(max_drift_v <= float(RaceData.PHYS["vmax"]) * float(RaceData.PHYS["drift_slow"]) + 0.3, "боком не быстрее, чем прямо: %.1f ≤ %.1f м/с" % [max_drift_v, float(RaceData.PHYS["vmax"]) * float(RaceData.PHYS["drift_slow"])])
	L.set_meta("auto", inp(1.0, 0.0, 0.0, false))
	await phys(3)
	ok(had(L, "drift_boost", e0) and L.boost_t > 0.9, "выход из заноса 3-го уровня — ускорение %.2f с" % L.boost_t)
	await wait(0.5)
	ok(L.speed > float(RaceData.PHYS["vmax"]) + 2.0, "ускорение после заноса: %.1f м/с > предела %.1f" % [L.speed, float(RaceData.PHYS["vmax"])])
	# уровни 1 и 2 — каждый даёт своё ускорение
	for lv in [1, 2]:
		put(L, turn_s, -2.0, 0.0, 19.0)
		L.boost_t = 0.0
		await phys(3)
		L.set_meta("auto", inp(1.0, 0.0, 0.8, true))
		await phys(3)
		var tl := Time.get_ticks_msec()
		while L.drift_lvl < lv and Time.get_ticks_msec() - tl < 5000:
			L.set_meta("auto", inp(1.0, 0.0, follow(L), true))
			await get_tree().physics_frame
		L.set_meta("auto", inp(1.0))
		await phys(3)
		ok(absf(L.boost_t - float(RaceData.PHYS["drift_boost"][lv - 1])) < 0.1, "уровень %d → ускорение %.2f с" % [lv, L.boost_t])
	# --- турбо ---
	put(L, race.track.start_s + 20.0, 0.0, 0.0, 15.0)
	L.turbo = 100.0
	L.boost_t = 0.0
	L.set_meta("auto", inp(1.0, 0.0, 0.0, false, true))
	await wait(0.8)
	ok(L.turbo_on and L.turbo < 70.0 and L.speed > float(RaceData.PHYS["vmax"]) + 1.0, "турбо: заряд тратится (%.0f), скорость %.1f" % [L.turbo, L.speed])
	await wait(1.4)
	ok(not L.turbo_on and L.turbo < float(RaceData.PHYS["turbo_min"]), "турбо не бесконечное: кончилось (заряд %.0f)" % L.turbo)
	# --- 8–9. прыжок и трамплин ---
	put(L, race.track.start_s + 30.0, 0.0, 0.0, 15.0)
	L.set_meta("auto", inp(1.0))
	await phys(4)
	e0 = L.events.size()
	await once(L, inp(1.0, 0.0, 0.0, false, false, true), inp(1.0))
	await wait(0.1)
	ok(L.air_t > 0.05 and had(L, "jump", e0), "прыжок пробелом")
	await until(func(): return had(L, "land", e0), 2.0)
	ok(had(L, "land", e0), "приземление после прыжка")
	var ramp: Dictionary = race.track.ramps[0]
	put(L, float(ramp["s0"]) - 30.0, 0.0, 0.0, 20.0)
	e0 = L.events.size()
	var max_air := 0.0
	var max_y := 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		max_air = maxf(max_air, L.air_t)
		max_y = maxf(max_y, L.global_position.y)
		if L.air_t > 0.3 and max_air < 0.35:
			await shot("r04_ramp_air")
		await get_tree().physics_frame
	ok(had(L, "ramp", e0) and max_air > 0.5 and max_y > 2.0, "трамплин: толчок, в воздухе %.2f с, высота %.1f м" % [max_air, max_y])
	ok(had(L, "land", e0) and L.global_position.y > -0.5, "после трамплина — приземление на дорогу")
	var past: float = race.track.from_start(L.s) - race.track.from_start(float(ramp["s1"]))
	ok(past < 60.0, "трамплином не перелететь трассу (за 3 с от трамплина %.0f м)" % past)
	# --- 10. стена ---
	var ws := race.track.start_s + 60.0
	put(L, ws, race.track.width(ws) * 0.5 - 0.5, -0.7, 18.0)
	e0 = L.events.size()
	L.set_meta("auto", inp(1.0))
	var max_lat := 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1200:
		max_lat = maxf(max_lat, absf(float(race.track.project(L.global_position, L.proj)["lat"])))
		await get_tree().physics_frame
	ok(had(L, "wall", e0), "удар о стену засчитан")
	ok(max_lat < race.track.width(ws) * 0.5 + RaceTrack.SHOULDER + 0.6, "сквозь стену не проехать (дальше всего от центра %.1f м)" % max_lat)
	# стена у гаражей: под углом в бок на полной скорости
	var gs: float = race.track.S[race.track.nearest_main(Vector3(85, 0, 127))]
	put(L, gs, 0.0, 0.9, 21.0)
	e0 = L.events.size()
	var vmin := 99.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		vmin = minf(vmin, L.speed)
		await get_tree().physics_frame
	ok(had(L, "wall", e0) and vmin < 17.0, "в узком проезде стена гасит скорость (до %.1f м/с)" % vmin)
	# --- 10. толкотня гонщиков ---
	var B: RaceRider = race.riders[1]
	put(L, race.track.start_s + 40.0, -0.4, 0.0, 10.0)
	put(B, race.track.start_s + 40.0, 0.4, 0.0, 10.0)
	e0 = L.events.size()
	await wait(0.4)
	ok(had(L, "bump", e0) and L.global_position.distance_to(B.global_position) > 0.9, "гонщики толкаются и расходятся (%.2f м)" % L.global_position.distance_to(B.global_position))
	# --- канава на срезке: упал — вернули на контрольную точку ---
	var tr: RaceTrack = race.track
	var di := tr.short_point((tr.ditch.x + tr.ditch.y) * 0.5)
	var right_s: Vector3 = tr.ST[di].cross(Vector3.UP)
	L.place(Transform3D(Basis(Vector3.UP, atan2(tr.ST[di].x, tr.ST[di].z)), tr.SP[di] + right_s * 2.6 + Vector3(0, 0.3, 0)))
	L.set_meta("auto", inp(0.0))
	e0 = L.events.size()
	await until(func(): return had(L, "respawn", e0), 3.0)
	ok(had(L, "respawn", e0) and L.global_position.y > -0.5, "мимо мостика — в канаву и назад на трассу")
	await shot("r05_ditch")
	# ================= 11–12. предметы =================
	put(L, race.track.start_s + 30.0, 0.0, 0.0, 0.0)
	L.set_meta("auto", inp(0.0))
	await phys(3)
	# коробка
	var bx: Dictionary = race.boxes[2]
	var bp: Vector3 = bx["pos"]
	L.item = ""
	L.place(Transform3D(Basis.IDENTITY, Vector3(bp.x, 0.1, bp.z)))
	e0 = L.events.size()
	await phys(3)
	ok(had(L, "item_get", e0) and RaceData.ITEMS.has(L.item) and not (bx["node"] as Node3D).visible, "коробка: подобран «%s», коробка пропала" % (RaceData.ITEMS[L.item]["name"] if L.item != "" else "—"))
	put(L, race.track.start_s + 30.0, 0.0, 0.0, 0.0)
	await wait(RaceData.BOX_RESPAWN + 0.3)
	ok((bx["node"] as Node3D).visible, "коробка вернулась через %.0f с" % RaceData.BOX_RESPAWN)
	var seen := {}
	for k in 300:
		L.rank = 1 + k % 6                              # из коробки на разных местах
		seen[race.roll_item(L)] = true
	ok(seen.size() == 6, "из коробок выпадают все шесть предметов (%d)" % seen.size())
	# турбо-баллон
	put(L, race.track.start_s + 30.0, 0.0, 0.0, 15.0)
	L.item = "turbo_balloon"
	L.item_cd = 0.0
	L.boost_t = 0.0
	await once(L, inp(1.0, 0.0, 0.0, false, false, false, true), inp(1.0))
	await wait(0.5)
	ok(L.item == "" and L.item_boost_t > 0.3 and L.speed > float(RaceData.PHYS["vmax"]) + 3.0, "ТУРБО-БАЛЛОН: ускорение (%.1f м/с)" % L.speed)
	await shot("r06_turbo")
	# пылевой взрыв: соперник сзади въезжает в облако
	put(L, race.track.start_s + 50.0, 0.0, 0.0, 0.0)
	put(B, race.track.start_s + 36.0, 0.0, 0.0, 12.0)
	B.set_meta("auto", inp(0.6))
	L.item = "dust_bomb"
	L.item_cd = 0.0
	var eb := B.events.size()
	await once(L, inp(0.0, 0.0, 0.0, false, false, false, true), inp(0.0))
	ok(race.hazards.size() == 1 and race.hazards[0]["kind"] == "dust_bomb", "ПЫЛЕВОЙ ВЗРЫВ: облако позади")
	await until(func(): return had(B, "hit", eb), 3.0)
	ok(had(B, "hit", eb) and B.slows.has("dust"), "въехал в пыль — замедлен")
	await shot("r07_dust")
	# мыльная лужа
	put(L, race.track.start_s + 120.0, 0.0, 0.0, 0.0)
	put(B, race.track.start_s + 104.0, 0.0, 0.0, 12.0)
	L.item = "soap"
	L.item_cd = 0.0
	eb = B.events.size()
	await once(L, inp(0.0, 0.0, 0.0, false, false, false, true), inp(0.0))
	await until(func(): return had(B, "spin", eb), 3.0)
	ok(had(B, "spin", eb), "МЫЛЬНАЯ ЛУЖА: соперника разворачивает")
	await shot("r08_soap")
	# защитный фильтр: лужа не действует
	await wait(1.2)                                   # разворот на мыле закончился
	put(L, race.track.start_s + 200.0, 0.0, 0.0, 0.0)
	B.item = "filter"
	B.item_cd = 0.0
	await once(B, inp(0.0, 0.0, 0.0, false, false, false, true), inp(0.0))
	ok(B.shield_t > 5.0, "ЗАЩИТНЫЙ ФИЛЬТР включён (%.1f с)" % B.shield_t)
	var C: RaceRider = race.riders[2]
	put(C, race.track.start_s + 216.0, 0.0, 0.0, 0.0)
	put(B, race.track.start_s + 200.0, 0.0, 0.0, 12.0)
	C.item = "soap"
	C.item_cd = 0.0
	B.set_meta("auto", inp(0.6))
	eb = B.events.size()
	await once(C, inp(0.0, 0.0, 0.0, false, false, false, true), inp(0.0))
	await until(func(): return had(B, "blocked", eb), 3.0)
	ok(had(B, "blocked", eb) and not had(B, "spin", eb) and B.shield_t == 0.0, "фильтр снял одно воздействие и кончился")
	# супер-всасывание
	put(L, race.track.start_s + 300.0, 0.0, 0.0, 12.0)
	put(B, race.track.start_s + 316.0, 0.5, 0.0, 12.0)
	B.set_meta("auto", inp(0.6))
	L.item = "super_suck"
	L.item_cd = 0.0
	eb = B.events.size()
	await once(L, inp(0.6, 0.0, 0.0, false, false, false, true), inp(0.6))
	await phys(2)
	ok(had(B, "hit", eb) and B.slows.has("suck") and race.tethers.size() == 1 and L.pull_v.length() > 1.0, "СУПЕР-ВСАСЫВАНИЕ: тянет к сопернику, его тормозит")
	await shot("r09_suck")
	# выброс воздуха
	await wait(1.6)
	put(L, race.track.start_s + 400.0, 0.0, 0.0, 12.0)
	put(B, race.track.start_s + 408.0, 0.3, 0.0, 12.0)
	L.item = "air_blast"
	L.item_cd = 0.0
	eb = B.events.size()
	await once(L, inp(0.6, 0.0, 0.0, false, false, false, true), inp(0.6))
	ok(had(B, "hit", eb) and B.side_v.length() > 3.0 and B.slows.has("blast"), "ВЫБРОС ВОЗДУХА: соперника отбросило вбок (%.1f м/с)" % B.side_v.length())
	await shot("r10_blast")
	# правила: без предмета, после финиша и до «ЖМИ» — ничего
	L.item = ""
	var e1 := L.events.size()
	race.use_item(L)
	ok(not had(L, "item_use", e1), "без предмета использовать нечего")
	B.remove_meta("auto")
	B.set_meta("auto", RaceInput.new())
	# ================= 13–14. контрольные точки =================
	put(L, race.track.start_s - 3.0, 0.0, 0.0, 10.0)
	L.lap = 0
	L.next_gate = 0
	L.set_meta("armed", false)
	L.set_meta("auto", inp(1.0))
	await wait(0.6)
	ok(L.get_meta("armed", false) and L.next_gate == 1, "черта старта: круг 1 начался")
	# прыжок через контрольные точки: перенесли за половину круга — финиш не засчитан
	put(L, race.track.start_s - 3.0, 0.0, 0.0, 10.0)
	L.prev_s = L.s
	await wait(0.6)
	ok(L.lap == 0, "финиш без всех контрольных точек не засчитан (круг %d, ждём точку %d)" % [L.lap, L.next_gate])
	# правильный круг: бот за игрока
	put(L, race.track.start_s + 2.0, 0.0, 0.0, 12.0)
	L.next_gate = 1
	L.remove_meta("auto")
	var ai := RaceAI.new()
	ai.setup(L, race, "hard", 3)
	L.ai = ai
	e0 = L.events.size()
	Engine.time_scale = 3.0
	await until(func(): return L.lap >= 1, 30.0)
	Engine.time_scale = 1.0
	var gates_seen: Array = []
	for i in range(e0, L.events.size()):
		if String(L.events[i][0]) == "gate":
			gates_seen.append(int(L.events[i][1]))
	ok(L.lap == 1 and gates_seen == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0], "полный круг: контрольные точки по порядку %s" % str(gates_seen))
	ok(count_ev(L, "respawn", e0) == 0, "бот проехал круг без падений и застреваний")
	# ================= пауза =================
	await key(KEY_ESCAPE)
	await wait(0.2)
	var pp := L.global_position
	await wait(0.5)
	ok(race.paused and race.hud.pause_panel != null and L.global_position.distance_to(pp) < 0.01, "пауза: гонка стоит")
	await shot("r11_pause")
	await key(KEY_ESCAPE)
	await wait(0.2)
	ok(not race.paused, "Esc — продолжить")
	# ================= 15–17. полная гонка =================
	L.ai = null
	main.start_race(race.cfg)
	await until(func(): return main.race != race and main.race != null, 5.0)
	race = main.race
	L = race.local
	ai = RaceAI.new()
	ai.setup(L, race, "hard", 5)
	L.ai = ai
	await until(func(): return race.go, 8.0)
	await wait(2.0)
	await shot("r12_pack")
	Engine.time_scale = 4.0
	var music_peak := -200.0
	var sfx_peak := -200.0
	var cams := 0
	t0 = Time.get_ticks_msec()
	while race.state != "results" and Time.get_ticks_msec() - t0 < 90000:
		music_peak = maxf(music_peak, peak("Music"))
		sfx_peak = maxf(sfx_peak, peak("SFX"))
		if cams < 4 and race.t > 20.0 + cams * 25.0:
			Engine.time_scale = 1.0
			await shot("r13_race_%d" % cams)
			Engine.time_scale = 4.0
			cams += 1
		await get_tree().process_frame
	Engine.time_scale = 1.0
	ok(race.state == "results", "гонка дошла до результатов (%.0f с гонки)" % race.t)
	var fin := race.riders.filter(func(r): return r.finished)
	ok(L.finished and L.lap == 3, "игрок (бот за него) прошёл 3 круга и финишировал: %s" % RaceHud.fmt(L.finish_t))
	ok(fin.size() >= 4, "соперники тоже финишируют (%d из 6)" % fin.size())
	var resp := 0
	for r in race.riders:
		resp += count_ev(r, "respawn")
	ok(resp <= 3, "за гонку возвратов на трассу: %d" % resp)
	var by_time := true
	for k in range(1, race.results.size()):
		if not race.results[k]["est"] and float(race.results[k]["time"]) < float(race.results[k - 1]["time"]):
			by_time = false
	ok(race.results.size() == 6 and by_time, "таблица результатов: 6 строк по времени")
	ok(L.rank >= 1 and L.rank <= 6 and race.hud.results_panel != null, "экран результатов: игрок на %d месте" % L.rank)
	var items_used := 0
	for r in race.riders:
		items_used += count_ev(r, "item_use")
	ok(items_used >= 4, "боты и игрок пользовались предметами (%d раз)" % items_used)
	ok(music_peak > -45.0 and sfx_peak > -45.0, "звук: музыка гонки (пик %.1f дБ) и эффекты (пик %.1f дБ)" % [music_peak, sfx_peak])
	ok(race.stats["slow"] < race.stats["frames"] * 0.2, "кадр: медленных шагов %d из %d" % [race.stats["slow"], race.stats["frames"]])
	await wait(0.5)
	await shot("r14_results")
	# ================= 18. выход в меню гонок =================
	race.hud._menu_select(race.hud.menu_rows.size() - 2)
	await key(KEY_ENTER)
	await until(func(): return main.menu != null and main.race == null, 5.0)
	await wait(0.6)
	ok(main.menu != null and main.race == null and main.menu.modes.visible and main.menu.panel != null, "«В МЕНЮ ГОНОК»: меню гонок снова открыто")
	# ================= TIME TRIAL =================
	main.menu._panel_select(3, false)
	await key(KEY_ENTER)
	await until(func(): return main.race != null and is_instance_valid(main.race), 10.0)
	race = main.race
	ok(race.riders.size() == 1 and race.boxes.is_empty() and race.cfg["mode"] == "time", "TIME TRIAL: один гонщик, без предметов")
	await until(func(): return race.go, 8.0)
	await wait(1.5)
	await shot("r15_time_trial")
	race.quit(false)
	await until(func(): return main.menu != null and main.race == null, 5.0)
	await wait(0.5)
	# ================= 19. сюжет не тронут =================
	ok(_same(KEEP[0]), "сюжетное сохранение байт в байт как до гонок")
	ok(main.menu.has_save == (kept[KEEP[0]] != null), "CONTINUE после гонок — как до них")
	# ================= 20. обычная ТЯГА-812 после гонок =================
	main.start_training("pahan", "tyaga812")
	await until(func(): return main.game != null and main.game.training != null and main.game.player != null, 15.0)
	var g = main.game
	var p = g.player
	await until(func(): return p.style.id == "tyaga812" and p.state == "tyaga" and p.tyaga.mode == "hold", 10.0)
	ok(p.style.id == "tyaga812" and main.game.training.style == "tyaga812", "арена с выбранным в меню стилем ТЯГА-812 (кампанейский Пахан, стиль %s)" % p.style.id)
	for e2 in g.enemies:
		if is_instance_valid(e2):
			e2.global_position += Vector3(0, 0, -30)          # добивать рядом некого — E сажает на пылесос
	await key(KEY_E)
	await until(func(): return p.tyaga.mode == "ride", 3.0)
	ok(p.tyaga.mode == "ride", "ТЯГА-812 в кампании: сел верхом")
	var pos0: Vector3 = p.global_position
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(1.2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	ok(p.tyaga.speed > 3.0 or p.global_position.distance_to(pos0) > 2.0, "ТЯГА-812 в кампании едет на W (скорость %.1f, проехал %.1f м)" % [p.tyaga.speed, p.global_position.distance_to(pos0)])
	await shot("r16_tyaga_campaign")
	g._to_menu()
	await wait(1.0)
	_finish()

func _same(p: String) -> bool:
	if kept[p] == null:
		return not FileAccess.file_exists(p)
	return FileAccess.file_exists(p) and FileAccess.get_file_as_string(p) == kept[p]

func _finish() -> void:
	Engine.time_scale = 1.0
	RaceSave.persist = true
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	RaceSave.loaded = false
	AudioServer.set_bus_mute(0, false)
	print("RACECHECK ok" if fails == 0 else "RACECHECK ОШИБКА: %d" % fails)
	get_tree().quit()
