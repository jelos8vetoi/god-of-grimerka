## Проверка погоды и случайных ситуаций гонок: `--resolution 1280x720 -- --weathercheck=<папка>`.
## Меню (ПОГОДА, СЛУЧАЙНЫЕ СИТУАЦИИ) → каждая погода в настоящей гонке: тормозной путь, заряд заноса, снос
## ветром, облака бури, ночной свет, туман; снимки w_<погода>.png → каждая ситуация: что делает и что убирается
## → сами по себе случаются в гонке → в заезде на время их нет. Настройки игрока не меняются. «WEATHERCHECK ok».
extends Node

const KEEP := ["user://grimerka_save.json", "user://grimerka_race.json"]
var main
var out := ""
var fails := 0
var kept := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	AudioServer.set_bus_mute(0, true)
	RaceSave.persist = false
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("WEATHERCHECK ok: " if cond else "WEATHERCHECK ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

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

func inp(th := 0.0, br := 0.0, st := 0.0, drift := false) -> RaceInput:
	var r := RaceInput.new()
	r.throttle = th
	r.brake = br
	r.steer = st
	r.drift = drift
	return r

func put(r: RaceRider, s: float, lat := 0.0, spd := 0.0) -> void:
	var tr: RaceTrack = main.race.track
	var i := tr.at_s(s)
	r.place(Transform3D(Basis(Vector3.UP, atan2(tr.T[i].x, tr.T[i].z)), tr.P[i] + tr.T[i].cross(Vector3.UP) * lat + Vector3(0, 0.1, 0)))
	r.speed = spd
	r.proj = tr.project(r.global_position, {})
	r.s = float(r.proj["s"])
	r.prev_s = r.s

func race_with(weather: String, happen := false, mode := "single") -> Race:
	var cfg := RaceMenu.config(mode)
	cfg["weather"] = weather
	cfg["happenings"] = happen
	main.start_race(cfg)
	await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.go, 20.0)
	var race: Race = main.race
	for r in race.riders:
		if r != race.local:
			r.set_meta("auto", RaceInput.new())
			put(r, race.track.start_s - 40.0 - r.slot * 4.0, 0.0, 0.0)
	return race

## тормозной путь с 20 м/с на прямой
func brake_dist(race: Race) -> float:
	var L := race.local
	put(L, race.track.start_s + 15.0, 0.0, 20.0)
	L.set_meta("auto", inp(1.0))
	await phys(3)
	L.speed = 20.0
	var p0 := L.global_position
	L.set_meta("auto", inp(0.0, 1.0))
	var t0 := GameClock.ms()
	while L.speed > 0.5 and GameClock.ms() - t0 < 5000:
		await get_tree().physics_frame
	return L.global_position.distance_to(p0)

## сколько держать занос до 1-го уровня на длинном повороте
func charge_time(race: Race) -> float:
	var L := race.local
	var tr: RaceTrack = race.track
	put(L, tr.S[tr.nearest_main(Vector3(128, 0, 6))], -1.0, 19.0)
	L.set_meta("auto", inp(1.0))
	await phys(3)
	L.set_meta("auto", inp(1.0, 0.0, 0.8, true))
	await phys(3)
	var t0 := GameClock.ms()
	var f0 := Engine.get_physics_frames()
	while L.drift_lvl < 1 and L.drifting and GameClock.ms() - t0 < 4000:
		var tg: Vector3 = tr.point(L.s + 14.0)
		var to := tg - L.global_position
		L.set_meta("auto", inp(1.0, 0.0, L.steer_for_rate(-angle_difference(atan2(L.vdir.x, L.vdir.z), atan2(to.x, to.z)) * 2.2), true))
		await get_tree().physics_frame
	L.set_meta("auto", inp(1.0))
	# настоящее время в заносе до первого уровня (а не счётчик заряда — он и есть то, что погода ускоряет)
	return float(Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second) if L.drift_lvl >= 1 else 99.0

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	RaceSave.loaded = false
	await wait(2.0)
	# ================= меню =================
	var mm = main.menu
	mm.open_modes(2)
	await wait(0.5)
	mm.open_race()
	await wait(0.3)
	var names: Array = []
	for row in mm.panel_rows:
		var tx = row["text"]
		names.append(String(tx.call()) if tx is Callable else String(tx))
	var wi := -1
	for k in names.size():
		if String(names[k]).begins_with("ПОГОДА"):
			wi = k
	ok(wi >= 0 and names.any(func(n): return String(n).begins_with("СЛУЧАЙНЫЕ СИТУАЦИИ")), "в меню гонок есть ПОГОДА и СЛУЧАЙНЫЕ СИТУАЦИИ")
	var seen := {}
	for k in RaceWeather.WEATHER_ORDER.size():
		seen[String(RaceSave.v("weather"))] = true
		mm._panel_select(wi, false)
		mm._panel_activate(1)
	ok(seen.size() == RaceWeather.WEATHER_ORDER.size(), "ПОГОДА перебирает все %d вариантов" % seen.size())
	await shot("w00_menu")
	mm._close()
	# ================= каждая погода =================
	var base_brake := 0.0
	var base_charge := 0.0
	for w in ["clear", "rain", "fog", "wind", "ice", "dust", "night"]:
		var race: Race = await race_with(w)
		ok(race.weather.id == w, "%s: гонка с этой погодой" % RaceWeather.WEATHERS[w]["name"])
		var bd: float = await brake_dist(race)
		var ct: float = await charge_time(race)
		if w == "clear":
			base_brake = bd
			base_charge = ct
		print("WEATHERCHECK   %s: тормозной путь %.1f м, заряд заноса %.2f с" % [w, bd, ct])
		match w:
			"rain":
				ok(bd > base_brake * 1.1 and race.weather.particles != null, "ЛИВЕНЬ: тормозной путь длиннее (%.1f м против %.1f), идёт дождь" % [bd, base_brake])
			"ice":
				ok(bd > base_brake * 1.5, "ГОЛОЛЁД: тормозной путь намного длиннее (%.1f м против %.1f)" % [bd, base_brake])
			"fog":
				ok(race.weather.env.fog_density > 0.02 and race.weather.mod("bot") < 1.0, "ТУМАН: густой туман, боты осторожнее")
			"night":
				ok(race.weather.lamps.size() > 0 and race.weather.heads.size() == race.riders.size(), "НОЧЬ: горят фонари (%d) и фары у всех" % race.weather.lamps.size())
			"wind":
				var L := race.local
				put(L, race.track.start_s + 15.0, 0.0, 15.0)
				L.set_meta("auto", inp(0.6))
				race.weather.gust = 1.5
				var lat0 := L.lat
				await wait(2.0)
				var drift := absf(float(race.track.project(L.global_position, L.proj)["lat"]) - lat0)
				ok(race.weather.wind.length() > 3.0 and drift > 0.4, "ВЕТЕР: %.1f м/с, без руля снесло на %.1f м" % [race.weather.wind.length(), drift])
			"dust":
				var h0 := race.hazards.size()
				await wait(9.0)
				ok(race.hazards.size() > h0, "ПЫЛЬНАЯ БУРЯ: по трассе гуляют облака (%d)" % race.hazards.size())
		if w == "rain":
			ok(ct < base_charge * 0.95, "ЛИВЕНЬ: занос заряжается быстрее (%.2f с против %.2f)" % [ct, base_charge])
		# снимок из-за спины на ходу
		var L2 := race.local
		put(L2, race.track.start_s + 25.0, 0.0, 16.0)
		L2.set_meta("auto", inp(1.0))
		await wait(1.2)
		await shot("w_" + w)
		race.quit(false)
		await until(func(): return main.race == null, 5.0)
	# случайная погода
	var rr: Race = await race_with("random")
	ok(RaceWeather.WEATHERS.has(rr.weather.id), "СЛУЧАЙНАЯ погода выбрала «%s»" % RaceWeather.WEATHERS[rr.weather.id]["name"])
	rr.quit(false)
	await until(func(): return main.race == null, 5.0)
	# ================= ситуации =================
	var race2: Race = await race_with("night", false)
	var W: RaceWeather = race2.weather
	var L3 := race2.local
	var B: RaceRider = race2.riders[1]
	var s0 := race2.track.start_s + 40.0
	# буханка: гонщик на её пути
	W.start("buhanka", s0)
	put(B, s0, 0.0, 0.0)
	var hit: bool = await until(func(): return B.events.any(func(e): return e[0] == "hit_van"), 7.0)
	ok(W.happen_log.size() == 1 and hit, "БУХАНКА переезжает дорогу и сбивает того, кто на пути")
	await until(func(): return W.active.is_empty(), 8.0)
	ok(W.active.is_empty(), "буханка уехала (ситуация кончилась)")
	# теплотрасса: подбрасывает
	W.start("steam", s0)
	put(L3, s0 - 20.0, 0.0, 16.0)
	L3.set_meta("auto", inp(1.0))
	var max_air := 0.0
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < 3000:
		max_air = maxf(max_air, L3.air_t)
		await get_tree().physics_frame
	ok(L3.events.any(func(e): return e[0] == "steam") and max_air > 0.6, "ТЕПЛОТРАССА подбрасывает (в воздухе %.2f с)" % max_air)
	await shot("w_steam")
	for h in W.active.duplicate():
		W._end(h)
	# шины: препятствия на дороге
	W.start("tires", s0)
	await phys(2)
	var sb: StaticBody3D = W.active[0]["nodes"][0]
	var tp: Vector3 = (sb.get_child(0) as CollisionShape3D).position
	put(L3, s0 - 30.0, 0.0, 0.0)
	L3.place(Transform3D(Basis(Vector3.UP, atan2((tp - (tp - race2.track.tangent(s0) * 8.0)).x, race2.track.tangent(s0).z)), tp - race2.track.tangent(s0) * 8.0 + Vector3(0, 0.1, 0)))
	L3.heading = atan2(race2.track.tangent(s0).x, race2.track.tangent(s0).z)
	L3.speed = 14.0
	var e0 := L3.events.size()
	await wait(1.2)
	ok(L3.events.slice(e0).any(func(e): return e[0] == "wall"), "ШИНЫ на дороге — в них врезаешься")
	await shot("w_tires")
	for h in W.active.duplicate():
		W._end(h)
	await phys(2)
	ok(not is_instance_valid(sb) or sb.is_queued_for_deletion(), "шины убраны после ситуации")
	# мусор: медленнее
	W.start("trash", s0)
	put(L3, s0, 0.0, 10.0)
	await phys(3)
	ok(L3.slows.has("trash"), "МУСОРОВОЗ: на хламе медленнее")
	for h in W.active.duplicate():
		W._end(h)
	# ливень-ситуация: скользко, потом сухо
	var g0 := W.mod("grip")
	W.start("downpour", s0)
	ok(W.mod("grip") < g0 and W.particles != null, "ВНЕЗАПНЫЙ ЛИВЕНЬ: скользко (%.2f)" % W.mod("grip"))
	await shot("w_downpour")
	W.downpour_t = 0.01
	await phys(3)
	for h in W.active.duplicate():
		W._end(h)
	ok(absf(W.mod("grip") - g0) < 0.001, "ливень прошёл — сцепление вернулось")
	# акция: в коробках только турбо
	W.start("promo", s0)
	ok(W.box_item("soap") == "turbo_balloon", "АКЦИЯ: из коробки — ТУРБО-БАЛЛОН")
	W.promo_t = 0.0
	ok(W.box_item("soap") == "soap", "акция кончилась — обычные предметы")
	for h in W.active.duplicate():
		W._end(h)
	# попутный ветер
	W.start("tailwind", s0)
	put(L3, s0, 0.0, 12.0)
	L3.set_meta("auto", inp(1.0))
	await phys(4)
	ok(L3.boost_t > 0.1, "ПОПУТНЫЙ ВЕТЕР: разгоняет")
	for h in W.active.duplicate():
		W._end(h)
	# голуби
	W.start("pigeons", s0)
	put(L3, s0, 0.0, 10.0)
	await phys(3)
	ok(L3.slows.has("pigeons"), "ГОЛУБИ: в стае медленнее")
	await shot("w_pigeons")
	for h in W.active.duplicate():
		W._end(h)
	# отключили свет (ночь)
	W.start("blackout", s0)
	ok(W.lamps.all(func(l): return not l.visible), "ОТКЛЮЧИЛИ СВЕТ: фонари погасли")
	await shot("w_blackout")
	for h in W.active.duplicate():
		W._end(h)
	ok(W.lamps.all(func(l): return l.visible), "свет вернулся")
	race2.quit(false)
	await until(func(): return main.race == null, 5.0)
	# ================= сами по себе в гонке =================
	var race3: Race = await race_with("clear", true)
	race3.local.ai = RaceAI.new()
	race3.local.ai.setup(race3.local, race3, "hard", 1)
	for r in race3.riders:
		if r != race3.local and r.has_meta("auto"):
			r.remove_meta("auto")
	Engine.time_scale = 3.0
	await until(func(): return race3.weather.happen_log.size() >= 2, 40.0)
	Engine.time_scale = 1.0
	ok(race3.weather.happen_log.size() >= 2, "в гонке ситуации случаются сами (%s)" % ", ".join(race3.weather.happen_log.map(func(x): return String(x[0]))))
	race3.quit(false)
	await until(func(): return main.race == null, 5.0)
	var race4: Race = await race_with("clear", true, "time")
	ok(not race4.weather.happen_on, "TIME TRIAL: случайных ситуаций нет (честный рекорд)")
	race4.quit(false)
	await until(func(): return main.race == null, 5.0)
	_finish()

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
	print("WEATHERCHECK ok" if fails == 0 else "WEATHERCHECK ОШИБКА: %d" % fails)
	get_tree().quit()
