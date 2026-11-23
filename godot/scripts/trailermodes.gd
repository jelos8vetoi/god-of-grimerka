## Съёмка трейлера режимов: `--fixed-fps 30 --resolution 1280x720 -- --trailermodes=<папка>`.
## Кадры JPG по планам (<план><номер>.jpg) для tools/trailer/compose-modes.html:
##   C1–C4 — самые жёсткие комбо основной игры (Team Overdrive Пахана, дуэт-атака, тяжёлая цепочка в толпу,
##           Overdrive madk1d); R1–R3 — VACUUM RACING (ночной облёт, погоня с паром теплотрассы, ливень и занос);
##   M1–M3 — ПАХАН НАБРАЛ МИКРОЗАЙМОВ (карта долгов, звонок коллектора, уборка подъезда);
##   F1–F4 — 5 НОЧЕЙ С ПАХАНОМ (терминал, свет у двери, взгляд в камеру, темнота), S1–S6 — скримеры (S6 — Пахан в негативе).
## Плюс звуки ночей (sfx_*.wav) — их синтез живёт в игре. Сохранения игрока не трогаются.
extends Node

const KEEP := ["user://grimerka_save.json", "user://microloans_save.json", "user://five_nights_save.json", "user://grimerka_race.json"]
var main
var out := ""
var kept := {}
var slow := 1.0
var cam: Camera3D
var count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in KEEP:
		kept[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else (null as Variant)
	MLSave.persist = false
	FNSave.persist = false
	RaceSave.persist = false
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, false).timeout

func until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0) * 4:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func grab(prefix: String, n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("%s%03d.jpg" % [prefix, i]), 0.9)
		count += 1
	print("TRAILERMODES %s: %d кадров" % [prefix, n])

# ---- director для боя (game.gd вызывает) ----
func frame(_dt: float) -> void:
	pass

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return true

func _run() -> void:
	await wait(1.5)
	_export_sfx()
	await _combat()
	await _race()
	await _microloans()
	await _five_nights()
	_finish()

func _export_sfx() -> void:
	for id in ["scream_balon", "scream_madk1d", "scream_bot", "scream_clipper", "scream_ghost", "scream_mod", "scream_pahan", "static", "chime", "hum", "vent_bang", "door_down", "music_box_air", "ping", "cam", "heart", "power_down", "whisper"]:
		FNSound.get_stream(id).save_to_wav(out.path_join("sfx_" + id + ".wav"))

# ---------------- бой ----------------
func _stage(hero := "pahan", ch := 0) -> void:
	var game = main.game
	game.ch = ch
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	var P = game.player
	if P.hero != hero:
		game.swap_heroes(true)
	for k in 3:
		await get_tree().physics_frame
	game.tag.reset()
	P = game.player
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.hp = P.max_hp
	P.auto_input = {}

func _crowd(kinds: Array, r := 2.6) -> void:
	var game = main.game
	var P = game.player
	for i in kinds.size():
		var a := float(i) / float(kinds.size()) * TAU
		game.spawn_enemy(kinds[i], P.global_position + Vector3(sin(a) * r, 0, cos(a) * r - 0.6))

func _combat() -> void:
	main.start_game(false, 0)
	await until(func(): return main.game != null and main.game.player != null, 20.0)
	await wait(2.0)
	var game = main.game
	game.director = self
	cam = game.cam
	# C1 — Team Overdrive Пахана в кольце врагов
	await _stage("pahan", 1)
	_crowd(["bot", "bot", "clipper", "bot", "hater", "bot"])
	await wait(1.2)
	game.hype.value = 100.0
	game.hype.try_start()
	await grab("C1_", 135)
	# C2 — дуэт-атака: напарник открывает, Пахан продолжает цепочкой
	await wait(1.5)
	await _stage("pahan", 2)
	_crowd(["clipper", "bot", "bot"], 2.4)
	await wait(1.0)
	game.tag.duo.try_start()
	await grab("C2_", 105)
	# C3 — тяжёлая цепочка балоном в толпу
	await wait(1.0)
	await _stage("pahan", 0)
	_crowd(["bot", "bot", "bot", "bot", "clipper"], 2.0)
	await wait(0.8)
	_c3_inputs(game.player)                      # нажатия идут параллельно съёмке
	await grab("C3_", 105)
	# C4 — Overdrive madk1d
	await wait(1.0)
	await _stage("madk1d", 3)
	_crowd(["troll", "bot", "bot", "hater", "bot"])
	await wait(1.2)
	game.hype.value = 100.0
	game.hype.try_start()
	await grab("C4_", 135)
	game.director = null
	main.show_menu()
	await wait(1.0)

func _c3_inputs(P) -> void:
	for a in ["attack", "attack", "attack", "heavy", "attack", "attack", "heavy"]:
		P.auto_input = {a: "press"}
		await get_tree().physics_frame
		P.auto_input = {}
		for k in 9:
			await get_tree().physics_frame

# ---------------- гонки ----------------
func _race() -> void:
	var cfg := RaceMenu.config("single")
	cfg["weather"] = "night"
	cfg["happenings"] = false
	main.start_race(cfg)
	await until(func(): return main.race != null and is_instance_valid(main.race), 10.0)
	var race: Race = main.race
	race.hud.visible = false
	await wait(0.4)
	await grab("R1_", 90)                         # облёт ночной трассы
	await until(func(): return race.go, 20.0)
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "hard", 3)
	await wait(2.5)
	race.weather.start("steam", race.local.s + 45.0)
	await grab("R2_", 120)
	race.quit(false)
	await wait(1.0)
	var cfg2 := RaceMenu.config("single")
	cfg2["weather"] = "rain"
	cfg2["happenings"] = false
	main.start_race(cfg2)
	await until(func(): return main.race != null and is_instance_valid(main.race) and main.race.go, 25.0)
	race = main.race
	race.hud.visible = false
	race.local.ai = RaceAI.new()
	race.local.ai.setup(race.local, race, "hard", 5)
	await wait(4.0)
	await grab("R3_", 105)
	race.quit(false)
	await wait(1.0)

# ---------------- микрозаймы ----------------
func _microloans() -> void:
	main.start_minigame("microloans", {"continue": false})
	await wait(2.5)
	var R: MicroloansRoot = main.minigame
	var e := R.econ
	var U := R.ui
	if e.event_today != "" and not e.event_done:
		e.resolve_event((MLData.EVENTS[e.event_today]["choices"] as Array).size() - 1)
	e.next_phase()
	U.show_phase()
	U.debt_flow()
	await wait(0.6)
	await grab("M1_", 75)
	U.show_phase()
	var tgt: Dictionary = e.active()[0]
	U.negotiate(int(tgt["id"]), func(): pass)
	await wait(0.4)
	await grab("M2_", 90)
	U.show_phase()
	await wait(0.3)
	e.actions = maxi(e.actions, 1)
	U.run_job("podezd", 0.9)
	await wait(2.0)
	await grab("M3_", 90)
	main.show_menu()
	await wait(1.0)

# ---------------- 5 ночей ----------------
func _five_nights() -> void:
	main.start_minigame("five_nights")
	await wait(2.0)
	var R: FiveNightsRoot = main.minigame
	await grab("F1_", 60)                         # терминал: живая камера главного зала
	R.start_night(4)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 12.0)
	var st: FNNight = R.st
	for id in st.enemies:
		(st.enemies[id] as FNEnemy).level = 0
	# свет у левой двери — а там он
	var b: FNEnemy = st.enemies["balon"]
	b.level = 1
	b.spot = "door_l"
	b.door_t = -999.0
	R.actors.place_key.clear()
	R.look_key = -1.0
	await wait(1.0)
	R.light_hold["l"] = true
	await grab("F2_", 60)
	R.light_hold["l"] = false
	R.look_key = 0.0
	b.spot = "stage"
	b.look = true
	R.actors.place_key.clear()
	await wait(0.6)
	st.set_monitor(true)
	st.set_cam("stage")
	await wait(0.5)
	await grab("F3_", 60)
	st.set_monitor(false)
	b.look = false
	await wait(0.6)
	st.power = 0.3
	await until(func(): return st.power_out, 5.0)
	await wait(3.1)
	await grab("F4_", 60)                         # темнота, глаза в проёме
	# скримеры
	var cases := [["S1_", "balon", "door_l"], ["S2_", "clipper", "door_l"], ["S3_", "ghost", "stage"], ["S4_", "madk1d", "vent_t"], ["S5_", "bot", "door_r"]]
	for c in cases:
		R.start_night(4)
		await until(func(): return R.state == "night" and R.intro_t <= 0.0, 12.0)
		st = R.st
		for id in st.enemies:
			(st.enemies[id] as FNEnemy).level = 0
		(st.enemies[c[1]] as FNEnemy).level = 10
		await wait(0.4)
		st.attack(c[1], c[2])
		await until(func(): return R.state == "scare", 2.0)
		await grab(c[0], 45)
		await until(func(): return R.state == "dead", 6.0)
	R.start_night(3)
	await until(func(): return R.state == "night" and R.intro_t <= 0.0, 12.0)
	for id in R.st.enemies:
		(R.st.enemies[id] as FNEnemy).level = 0
	await wait(0.5)
	R.double_scare()
	await grab("S6_", 60)                         # Пахан-копия в негативе
	await wait(1.5)
	main.show_menu()
	await wait(0.5)

func _finish() -> void:
	for p in KEEP:
		if kept[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(kept[p])
	print("TRAILERMODES frames=%d" % count)
	get_tree().quit()
