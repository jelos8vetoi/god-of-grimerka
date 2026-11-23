## Плейтест гонок «руками»: `--resolution 1280x720 -- --playtest-race=<папка> [--pt-level=easy|normal|hard] [--pt-races=N]`.
## Игра идёт настоящая, из меню; гонщиком управляют НАСТОЯЩИЕ КЛАВИШИ (InputEventKey через Input.parse_input_event —
## тот же путь, что у клавиатуры игрока: W газ, S тормоз, A/D руль, Shift занос, Ctrl турбо, E предмет, пробел прыжок).
## Водитель — простой «человек»: смотрит на дорогу впереди, рулит рывками (клавиша либо нажата, либо нет), перед
## крутым поворотом тормозит или пускает занос, турбо жмёт на прямой, предмет — как получил. Ошибается и бьётся.
## Что пишет (строки «PT | …»): пробы разгона, наката, тормоза и турбо на стартовой прямой (заезд на время), затем
## полные гонки на три круга с соперниками — скорость по секундам, времена кругов, места, предметы, заносы, удары,
## самые длинные отрезки «ничего не происходит». Снимки — каждые 15 с гонки и на событиях.
## Настройки и рекорды игрока не пишутся. Это инструмент плейтеста, а не проверка «прошло / не прошло».
extends Node

var main
var out := ""
var level := "normal"
var races := 1
var held := {}
var driving := false
var race: Race
var me: RaceRider
var log_t := 0.0
var sec_log: Array = []          # [t, скорость, место, круг]
var ev_from := 0
var quiet_t := 0.0               # сколько секунд подряд без событий
var quiet_max := 0.0
var last_ev_n := 0
var shot_t := 0.0
var shot_n := 0
var pwm := 0.0
var item_t := 0.0
var drift_want := false
var notes: Array = []
var path_real := 0.0             # сколько гонщик проехал на самом деле (по положению), м
var path_s := 0.0                # сколько продвинулся по трассе, м
var last_pos := Vector3.ZERO
var ticks := 0
var wall0 := 0
var debug := false
var track_id := ""              # --pt-track=<id>: на какой трассе играть (по умолчанию — первая)
var items_only := false         # --pt-items: только снимки предметов (лист моделей, предмет над гонщиком и в HUD)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-level="):
			level = a.substr(11)
		elif a == "--pt-items":
			items_only = true
		elif a.begins_with("--pt-track="):
			track_id = a.substr(11)
		elif a == "--pt-debug":
			debug = true
		elif a.begins_with("--pt-races="):
			races = int(a.substr(11))
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func say(s: String) -> void:
	print("PT | " + s)
	notes.append(s)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := GameClock.ms()
	while GameClock.ms() - t0 < int(sec * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm + ".png"))

## клавиша нажата / отпущена (событие уходит только при смене состояния — как у настоящей клавиатуры)
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

func release_all() -> void:
	for k in held.keys():
		hold(k, false)

func _open_race(row: String) -> bool:
	var mm = main.menu
	mm.open_modes(ModeSelect.index_of("race"))
	await wait(0.6)
	await tap(KEY_ENTER)
	await wait(0.4)
	var names: Array = []
	for r in mm.panel_rows:
		var tx = r["text"]
		names.append(String(tx.call()) if tx is Callable else String(tx))
	mm._panel_select(names.find(row), false)
	await tap(KEY_ENTER)
	var ok: bool = await until(func(): return main.race != null and is_instance_valid(main.race), 20.0)
	if ok:
		race = main.race
		me = race.local
	return ok

func _run() -> void:
	await wait(2.0)
	RaceSave.loaded = false
	RaceSave.v("level")
	RaceSave.persist = false
	RaceSave.data["level"] = level
	RaceSave.data["track"] = track_id if RaceData.TRACKS.has(track_id) else String(RaceData.TRACK_ORDER[0])
	say("уровень соперников: %s · круг трассы и число кругов берутся из меню как у игрока" % level)
	if items_only:
		RaceSave.data["weather"] = "clear"
		RaceSave.data["happen"] = false
		await _items()
		print("PLAYTEST-RACE done")
		get_tree().quit()
		return
	# ---------- пробы езды: заезд на время, пустая трасса ----------
	if await _open_race("TIME TRIAL"):
		say("TIME TRIAL: кругов %d, длина круга %.0f м, контрольных точек %d" % [race.laps, race.track.L, race.track.gates.size()])
		await until(func(): return race.go, 12.0)
		await _feel()
		await shot("feel_end")
		release_all()
		race.quit(false)
		await wait(1.5)
	# ---------- полные гонки ----------
	for n in races:
		if not await _open_race("SINGLE RACE"):
			say("ГОНКА %d НЕ ЗАПУСТИЛАСЬ" % (n + 1))
			break
		say("ГОНКА %d: кругов %d, участников %d (%s)" % [n + 1, race.laps, race.riders.size(), ", ".join(race.riders.map(func(r): return r.title))])
		await until(func(): return race.state == "countdown", 8.0)
		await shot("g%d_countdown" % (n + 1))
		await until(func(): return race.go, 8.0)
		sec_log = []
		path_real = 0.0
		path_s = 0.0
		last_pos = me.global_position
		ticks = 0
		wall0 = GameClock.ms()
		quiet_t = 0.0
		quiet_max = 0.0
		last_ev_n = me.events.size()
		ev_from = me.events.size()
		shot_t = 0.0
		driving = true
		var fin: bool = await until(func(): return race.state == "results" or me.finished, 75.0 if debug else 420.0)
		driving = false
		release_all()
		await until(func(): return race.state == "results", 40.0)
		await shot("g%d_results" % (n + 1))
		_report(n + 1, fin)
		race.quit(false)
		await wait(1.5)
	say("плейтест гонок закончен")
	print("PLAYTEST-RACE done")
	get_tree().quit()

## снимки предметов: лист всех моделей на дороге, затем каждый предмет над гонщиком и в карточке HUD, ловушки на дороге
func _items() -> void:
	if not await _open_race("SINGLE RACE"):
		return
	await until(func(): return race.go, 14.0)
	for r in race.riders:
		r.set_meta("auto", RaceInput.new())
	await wait(0.5)
	var f := me.fwd()
	var right := f.cross(Vector3.UP)
	var base := me.global_position + f * 7.0 + Vector3(0, 1.2, 0)
	var sheet: Array = []
	for k in RaceData.ITEM_IDS.size():
		var m := RaceItems.model(String(RaceData.ITEM_IDS[k]), 1.7)
		race.add_child(m)
		m.global_position = base + right * (float(k % 4) - 1.5) * 2.1 + Vector3(0, 1.9 if k < 4 else 0.0, 0)
		m.rotation.y = atan2(f.x, f.z) + 2.5
		sheet.append(m)
	var cam2 := Camera3D.new()
	cam2.fov = 50.0
	race.add_child(cam2)
	cam2.global_position = me.global_position + f * 0.5 + Vector3(0, 2.2, 0)
	cam2.look_at(base + Vector3(0, 0.9, 0), Vector3.UP)
	cam2.current = true
	await wait(0.3)
	await shot("items_sheet")
	for m in sheet:
		m.queue_free()
	cam2.queue_free()
	race.cam.current = true
	for id in RaceData.ITEM_IDS:
		me.item = String(id)
		await wait(0.7)
		await shot("item_hold_" + String(id))
	me.item = ""
	# ловушки и снаряд на дороге перед гонщиком
	race._hazard("soap", me.global_position + f * 6.0, 2.1, 20.0, me)
	race._hazard("dust_bomb", me.global_position + f * 11.0 + right * 2.5, 3.6, 7.0, me)
	me.shield_t = 9.0
	me.overclock_t = 5.0
	await wait(0.6)
	await shot("item_road_and_auras")
	me.item = "missile"
	race.use_item(me)
	await wait(0.12)
	await shot("item_missile_fly")
	# кольца у трамплинов и зрители у старта — отдельной камерой
	var cam3 := Camera3D.new()
	cam3.fov = 55.0
	cam3.far = 500.0
	race.add_child(cam3)
	cam3.current = true
	for k in race.track.rings.size():
		var rg: Dictionary = race.track.rings[k]
		cam3.global_position = (rg["pos"] as Vector3) - (rg["tan"] as Vector3) * 13.0 + Vector3(2.5, 1.2, 0)
		cam3.look_at(rg["pos"] as Vector3, Vector3.UP)
		await wait(0.25)
		await shot("ring_%d" % k)
	if race.crowd != null and not race.crowd.people.is_empty():
		for r in race.riders:
			r.set_meta("auto", RaceInput.new())
		var who: Dictionary = race.crowd.people[0]
		var tr2: RaceTrack = race.track
		var mid: Vector3 = tr2.P[tr2.at_s(tr2.start_s)]
		cam3.global_position = mid + Vector3(-9, 2.2, 0.0)
		cam3.look_at(mid + Vector3(8, 0.8, 0), Vector3.UP)
		race.crowd.cheer_all()
		await wait(1.2)
		await shot("crowd_start")
		cam3.global_position = (who["pos"] as Vector3) + Vector3(2.5, 1.4, -3.5)
		cam3.look_at((who["pos"] as Vector3) + Vector3(0, 0.9, 0), Vector3.UP)
		await wait(0.4)
		await shot("crowd_close")
	say("предметы: лист моделей, %d снимков «в руках», ловушки и ракета; колец %d, зрителей %d" % [RaceData.ITEM_IDS.size(), race.track.rings.size(), race.crowd.people.size() if race.crowd != null else 0])

## сколько проедет и какую скорость наберёт: держим клавиши, пишем скорость
func _probe(title: String, keys: Array, sec: float, every := 0.5) -> void:
	for k in keys:
		hold(k, true)
	var line: Array = []
	var t := 0.0
	var p0 := me.global_position
	while t < sec - 0.001:
		await wait(every)
		t += every
		line.append("%.1fс %.1f" % [t, me.speed])
	say("%s: %s · путь %.0f м" % [title, " | ".join(line), me.global_position.distance_to(p0)])
	for k in keys:
		hold(k, false)

func _feel() -> void:
	var P := RaceData.PHYS
	say("предел скорости по данным: %.1f м/с (%.0f км/ч)" % [float(P["vmax"]), float(P["vmax"]) * 3.6])
	await _probe("ГАЗ с места (W)", [KEY_W], 4.0)
	await _probe("НАКАТ (ничего не нажато)", [], 3.0)
	await _probe("ГАЗ снова (W)", [KEY_W], 2.5)
	await _probe("ТОРМОЗ (S)", [KEY_S], 1.0, 0.25)
	hold(KEY_S, false)
	# остановка и турбо без газа: должно ли турбо само разгонять?
	await until(func(): return absf(me.speed) < 0.6, 6.0)
	me.turbo = 100.0
	var t0 := me.turbo
	await _probe("ТУРБО БЕЗ ГАЗА с места (только Ctrl)", [KEY_CTRL], 1.5, 0.25)
	say("турбо без газа: заряд %.0f → %.0f, скорость %.1f м/с" % [t0, me.turbo, me.speed])
	await _probe("НАКАТ после турбо", [], 1.5)
	me.turbo = 100.0
	await _probe("ГАЗ + ТУРБО (W + Ctrl)", [KEY_W, KEY_CTRL], 2.5, 0.25)
	say("после 2,5 с газ+турбо: заряд %.0f, скорость %.1f" % [me.turbo, me.speed])
	await _probe("ГАЗ после турбо (W)", [KEY_W], 2.0)
	# поворот на полном ходу и занос
	await _probe("РУЛЬ ВПРАВО на ходу (W + D)", [KEY_W, KEY_D], 1.0, 0.25)
	release_all()

# ---------------- водитель ----------------
func _physics_process(dt: float) -> void:
	if not driving or race == null or not is_instance_valid(race) or me == null:
		return
	if race.state != "race" or me.finished or race.paused:
		release_all()
		return
	var xf: RaceTrack = race.track
	var spd := absf(me.speed)
	# куда смотреть: дальше на скорости
	var look := 7.0 + spd * 0.45
	var tg: Vector3 = xf.point(me.s + look)
	if me.on_short:
		tg = xf.point(xf.short_to + 6.0) if float(me.proj.get("ss", 0.0)) > xf.SL - 12.0 else xf.SP[xf.short_point(float(me.proj.get("ss", 0.0)) + look)]
	var to := tg - me.global_position
	var want := atan2(to.x, to.z)
	var diff := -angle_difference(me.heading, want)            # + — надо вправо
	if me.drifting:
		diff = -angle_difference(atan2(me.vdir.x, me.vdir.z), want) * 1.4
	# руль клавишами: большая ошибка — держим, маленькая — короткими нажатиями
	pwm = fmod(pwm + dt * 9.0, 1.0)
	var a := absf(diff)
	var press := a > 0.16 or (a > 0.035 and pwm < clampf(a / 0.16, 0.15, 1.0))
	hold(KEY_D, press and diff > 0.0)
	hold(KEY_A, press and diff < 0.0)
	# скорость в повороте
	var turn := xf.turn_ahead(me.s, 12.0 + spd * 0.9)
	var sharp := turn > 0.75
	var brake := sharp and spd > 15.0 and not me.drifting and not drift_want
	hold(KEY_S, brake)
	hold(KEY_W, not brake)
	# занос в крутом повороте
	if not me.drifting and turn > 0.55 and spd > 11.0 and a > 0.12:
		drift_want = true
	if drift_want and (turn < 0.22 or spd < 7.0):
		drift_want = false
	hold(KEY_SHIFT, drift_want)
	# турбо на прямой, когда есть заряд
	var straight := turn < 0.16 and a < 0.1
	hold(KEY_CTRL, straight and me.turbo > (8.0 if me.turbo_on else 55.0))
	# трюк: в воздухе после трамплина — пробел
	hold(KEY_SPACE, me.ramp_air and me.air_t > 0.12 and me.velocity.y > 1.0 and me.trick_t <= 0.0 and me.trick_n < 1)
	# предмет — через секунду после получения
	if me.item != "":
		item_t += dt
		hold(KEY_E, item_t > 1.0 and item_t < 1.12)
	else:
		item_t = 0.0
		hold(KEY_E, false)
	# журнал
	ticks += 1
	path_real += Vector2(me.global_position.x - last_pos.x, me.global_position.z - last_pos.z).length()
	path_s += absf(race._wrap(me.s - me.prev_s))
	last_pos = me.global_position
	log_t += dt
	if log_t >= 1.0:
		log_t = 0.0
		sec_log.append([race.t, me.speed, me.rank, me.lap])
	if debug:
		for i in range(last_ev_n, me.events.size()):
			if String(me.events[i][0]) in ["gate", "lap", "respawn"]:
				print("PTD | t %.1f %s %s · s %.0f (от старта %.0f) lat %.1f short %s · ждём точку %d на s %.0f" % [race.t, me.events[i][0], str(me.events[i][1]), me.s, race.track.from_start(me.s), me.lat, str(me.on_short), me.next_gate, float(race.track.gates[me.next_gate]["s"])])
	if me.events.size() != last_ev_n:
		last_ev_n = me.events.size()
		quiet_max = maxf(quiet_max, quiet_t)
		quiet_t = 0.0
	else:
		quiet_t += dt
	shot_t += dt
	if shot_t >= 15.0:
		shot_t = 0.0
		shot_n += 1
		shot("run_%02d" % shot_n)

func _report(n: int, fin: bool) -> void:
	var P := RaceData.PHYS
	var vmax: float = float(P["vmax"])
	var sum := 0.0
	var top := 0.0
	var near := 0
	var slow := 0
	for row in sec_log:
		var v: float = float(row[1])
		sum += v
		top = maxf(top, v)
		if v >= vmax * 0.9:
			near += 1
		if v < vmax * 0.5:
			slow += 1
	var cnt := maxi(1, sec_log.size())
	say("гонка %d: %s · время %.1f с · место %d из %d" % [n, "финиш" if fin else "НЕ ДОЕХАЛ за 7 минут", me.finish_t if me.finished else race.t, me.rank, race.riders.size()])
	say("гонка %d: круги %s · лучший %.1f с" % [n, ", ".join(me.lap_times.map(func(x): return "%.1f" % float(x))), me.best_lap])
	@warning_ignore("integer_division")
	say("гонка %d: средняя скорость %.1f м/с (%.0f%% предела), максимум %.1f; у предела (≥90%%) %d%% времени, медленнее половины — %d%%" % [n, sum / cnt, sum / cnt / vmax * 100.0, top, near * 100 / cnt, slow * 100 / cnt])
	say("гонка %d: проехано по положению %.0f м, по трассе %.0f м (круг по данным %.0f м × %d = %.0f); шагов физики %d за %.1f с настоящего времени (%.1f в секунду), часы гонки %.1f с" % [n, path_real, path_s, race.track.L, race.laps, race.track.L * race.laps, ticks, float(GameClock.ms() - wall0) / 1000.0, float(ticks) / maxf(0.001, float(GameClock.ms() - wall0) / 1000.0), race.t])
	var c := {}
	for i in range(ev_from, me.events.size()):
		var k := String(me.events[i][0])
		c[k] = int(c.get(k, 0)) + 1
	var keys: Array = c.keys()
	keys.sort()
	say("гонка %d: события игрока — %s" % [n, ", ".join(keys.map(func(k): return "%s×%d" % [k, int(c[k])]))])
	say("гонка %d: самый длинный отрезок без единого события — %.1f с" % [n, maxf(quiet_max, quiet_t)])
	var ranks: Array = []
	var last_lap := -1
	for row in sec_log:
		if int(row[3]) != last_lap:
			last_lap = int(row[3])
			ranks.append("круг %d: место %d" % [last_lap + 1, int(row[2])])
	say("гонка %d: места по кругам — %s" % [n, "; ".join(ranks)])
	var res: Array = []
	for row in race.results:
		res.append("%s %.1f%s" % [row["title"], float(row["time"]), "~" if bool(row["est"]) else ""])
	say("гонка %d: итог — %s" % [n, " | ".join(res)])
	var line: Array = []
	for i in range(0, sec_log.size(), 5):
		line.append("%d" % int(float(sec_log[i][1])))
	say("гонка %d: скорость каждые 5 с, м/с — %s" % [n, " ".join(line)])
