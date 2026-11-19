## «5 НОЧЕЙ С ПАХАНОМ» — корень мини-игры (сцена scenes/five_nights/five_nights.tscn, main.minigame).
## Пахан устроился ночным охранником в «ОБЛАКО — ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ». Основная игра
## (game.gd) не создаётся. Здесь: мир и свет, будка (FNOffice), помещения (FNFacility), враги на сцене
## (FNActors), камеры (FNCams), логика ночи (FNNight), странности (FNHorror), скримеры (FNScare),
## интерфейс (FNUI), меню-терминал (FNMenu), звук (FNSound через шины audio.gd), сохранение (FNSave).
## Управление: мышь к краю экрана — смотреть влево/вправо; A / D — двери; Q / E (держать) — свет; Z — заслонка
## левой шахты, X — люк; ПРОБЕЛ — планшет камер; 1–8 — камеры; R — СБРОС СИСТЕМЫ; F — сбросить звонок;
## ESC — пауза. Кнопки в будке нажимаются и мышью. В темноте: A и D по очереди — ручной генератор.
class_name FiveNightsRoot
extends Node3D

var main
var env: WorldEnvironment
var office: FNOffice
var fac: FNFacility
var actors: FNActors
var cams: FNCams
var ui: FNUI
var menu: FNMenu
var menu_layer: CanvasLayer
var scare: FNScare
var horror: FNHorror
var anomaly: FNAnomaly             # аномалии камер (fn_anomaly.gd)
var fix_hold := false              # держат C — перезапуск сломанной камеры
var said_broken := false
var said_brown := false
var st: FNNight
var menu_st: FNNight
var state := "menu"                 # menu / night / scare / dead / six
var paused := false
var night := 0
var levels := {}
var quiet := false
var look_key := 0.0
var light_hold := {"l": false, "r": false}
var crank_last := ""
var call_lines: Array = []
var call_t := 0.0
var call_muted := false
var ring_t := -1.0
var ping_beep := 0.0
var duck_k := 0.0
var face_flash := 0.0
var pending_reflection := false
var said_door := false
var hint_t := 0.0
var end_t := 0.0
var finale_done := false
var intro_t := 0.0                  # заставка ночи: пока идёт, часы стоят и враги не ходят
# звук
var amb := {}                       # id → AudioStreamPlayer (петли окружения)
var crawl: AudioStreamPlayer3D      # MADK1D в шахте
var whisper: AudioStreamPlayer      # GHOST: шёпот растёт с одержимостью
var air_tune: AudioStreamPlayer3D   # «последний шанс»
var pool3: Array = []
var pool2: Array = []

func _ready() -> void:
	if main == null:
		main = get_tree().root.get_node_or_null("Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	quiet = main != null and main.testing() != ""
	FNSave.load_all()
	FNSound.warm()
	_env()
	office = FNOffice.new()
	add_child(office)
	office.build()
	fac = FNFacility.new()
	add_child(fac)
	fac.build(office)
	actors = FNActors.new()
	add_child(actors)
	actors.build(office, fac)
	cams = FNCams.new()
	add_child(cams)
	cams.build(fac, get_world_3d())
	ui = FNUI.new()
	add_child(ui)
	ui.setup(self)
	ui.feed.material = cams.mat
	ui.feed.texture = cams.vp.get_texture()     # без текстуры TextureRect не рисуется — шейдер берёт картинку из своего feed
	scare = FNScare.new()
	add_child(scare)
	scare.setup(self)
	horror = FNHorror.new()
	horror.root = self
	add_child(horror)
	anomaly = FNAnomaly.new()
	anomaly.root = self
	add_child(anomaly)
	_audio()
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 8
	add_child(menu_layer)
	menu = FNMenu.new()
	menu_layer.add_child(menu)
	menu.setup(self)
	menu.bg.material = cams.mat
	menu.bg.texture = cams.vp.get_texture()
	apply_fx()
	_menu_scene()
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)

func _env() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.55)
	e.ambient_light_energy = 0.05
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.ssao_enabled = true
	e.ssao_intensity = 2.5
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.05, 0.06)
	e.fog_density = 0.035
	env.environment = e
	add_child(env)

func apply_fx() -> void:
	var k := float(FNSave.v("settings")["fx"])
	ui.fx_k = k
	cams.fx_k = k

# ---------------- звук ----------------
func _audio() -> void:
	for a in [["hum", "Ambient", -8.0], ["fan", "Ambient", -14.0], ["buzz", "Ambient", -26.0], ["whine", "SFX", -60.0]]:
		var p := AudioStreamPlayer.new()
		p.stream = FNSound.get_stream(a[0])
		p.bus = a[1]
		p.volume_db = a[2] + FNSound.trim(a[0])
		p.set_meta("base", a[2] + FNSound.trim(a[0]))
		add_child(p)
		amb[a[0]] = p
	crawl = _p3("crawl")
	crawl.volume_db = -60.0
	air_tune = _p3("music_box_air")
	air_tune.position = FNOffice.point("door_l") + Vector3(0, 1.6, 0)
	whisper = AudioStreamPlayer.new()
	whisper.stream = FNSound.get_stream("whisper")
	whisper.bus = "Voice"
	whisper.volume_db = -60.0
	add_child(whisper)
	for k in 8:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 6.0              # было 3: шаги в коридоре за 6–8 м гасли почти до нуля
		p3.max_db = 0.0                 # вблизи не громче, чем задано (иначе дверь у уха шла с +6 дБ и перегружала)
		add_child(p3)
		pool3.append(p3)
	for k in 6:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		pool2.append(p2)

func _p3(id: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = FNSound.get_stream(id)
	p.bus = "SFX"
	p.unit_size = 5.0
	add_child(p)
	return p

func _snd_ok() -> bool:
	return not quiet or (main != null and main.audiolog)

## звук из точки (направление слышно): шаги у двери, стук в шахте
func sfx3(id: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	if not _snd_ok():
		return
	for p in pool3:
		var a := p as AudioStreamPlayer3D
		if not a.playing:
			a.stream = FNSound.get_stream(id)
			a.global_position = pos
			a.volume_db = vol + FNSound.trim(id)
			a.pitch_scale = pitch
			a.play()
			return

## звук без места: интерфейс, крик скримера
func sfx2(id: String, vol := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not _snd_ok():
		return
	for p in pool2:
		var a := p as AudioStreamPlayer
		if not a.playing:
			a.stream = FNSound.get_stream(id)
			a.volume_db = vol + FNSound.trim(id)
			a.pitch_scale = pitch
			a.bus = FNSound.bus_for(id, bus)
			a.play()
			return

## тишина перед появлением: окружение уходит почти в ноль
func duck(on: bool) -> void:
	duck_k = 1.0 if on else 0.0

func _amb_tick(dt: float) -> void:
	var on := _snd_ok() and state in ["night", "scare", "menu"]
	var out := st != null and st.power_out and state == "night"
	for id in amb:
		var p: AudioStreamPlayer = amb[id]
		if on and not p.playing:
			p.play()
		elif not on and p.playing:
			p.stop()
		var base: float = p.get_meta("base")
		var want := base - duck_k * 30.0
		if out:
			want = -60.0                         # всё обесточено: тишина
		if id == "whine":
			want = (-26.0 if st != null and st.monitor and state == "night" else -60.0)
		if state == "menu" and id in ["buzz", "whine"]:
			want = -60.0
		p.volume_db = move_toward(p.volume_db, want, dt * 40.0)
	duck_k = maxf(0.0, duck_k - dt * 0.6)

# ---------------- меню-терминал ----------------
func _menu_scene() -> void:
	state = "menu"
	menu.visible = true
	menu.open_main()
	ui.hud.visible = false
	ui.tablet.visible = false
	ui.clear_card()
	menu_st = FNNight.new()
	menu_st.setup(0, 7)
	for id in ["balon", "bot", "madk1d"]:
		var e: FNEnemy = menu_st.enemies[id]
		e.level = 1
		e.spot = "stage"
		e.pose = ["balon", "bot", "madk1d"].find(id)
	menu_st.monitor = true
	menu_st.cam = "stage"
	cams.set_cam("stage")

func _menu_tick(dt: float) -> void:
	# фон: сцена главного зала; изредка кто-то медленно поворачивается к камере
	if randf() < dt * 0.15:
		var e: FNEnemy = menu_st.enemies[["balon", "bot", "madk1d"][randi() % 3]]
		e.look = not e.look
	actors.tick(menu_st, dt)
	fac.tick(dt)
	cams.tick(menu_st, dt)

## из меню мини-игры — в меню режимов GOD OF GRIMERKA
func quit_to_menu() -> void:
	FNSave.save()
	if main != null and main.has_method("end_minigame"):
		main.end_minigame(4)

## музыка: в терминале — своя тема (хор и колокольчики, loc_fn), ночью музыки нет — только здание и враги
func music_set() -> String:
	return "loc_fn" if state == "menu" else ""

## страх: редкие звуки здания в разных местах (скрип в коридоре, капля в служебке, стук за спиной, железо в шахте);
## не чаще раза в 14–30 с, только в тишине ночи и не во время скримера; ни один не означает угрозу — враги звучат своими
var fear_t := 18.0
const FEAR := [["creak", "hall_l", -6.0], ["creak", "hall_r", -6.0], ["drip", "vent_l", -8.0], ["knock", "behind", -10.0], ["clank", "vent_t", -16.0], ["giggle", "hall_r", -14.0]]
func _fear_tick(dt: float) -> void:
	if state != "night" or st == null or st.power_out or scare.busy or intro_t > 0.0:
		return
	fear_t -= dt
	if fear_t > 0.0:
		return
	fear_t = randf_range(14.0, 30.0) - float(night) * 1.5
	var f: Array = FEAR[randi() % (FEAR.size() if night >= 2 else 3)]
	var pos := Vector3(0.0, 1.5, 2.2) if String(f[1]) == "behind" else FNOffice.point(String(f[1])) + Vector3(0, 1.4, 0)
	sfx3(String(f[0]), pos, float(f[2]), randf_range(0.85, 1.1))

# ---------------- ночь ----------------
func start_night(n: int, lv := {}) -> void:
	night = n
	levels = lv
	FNSave.played()
	if n < 5:
		FNSave.put("current", n)
	st = FNNight.new()
	st.setup(n, int(Time.get_ticks_usec() % 2147483647), lv)
	menu.visible = false
	ui.hud.visible = true
	ui.show_pause(false)
	ui.show_dark(false)
	paused = false
	scare.restore()
	actors.hide_all()
	office.dark_eyes.visible = false
	office.cam.current = true
	horror.reset(int(st.rng.seed))
	anomaly.reset(int(st.rng.seed))
	said_door = false
	fix_hold = false
	finale_done = false
	call_muted = false
	face_flash = 0.0
	end_t = 0.0
	crank_last = ""
	light_hold = {"l": false, "r": false}
	air_tune.stop()
	crawl.volume_db = -60.0
	state = "night"
	fear_t = randf_range(16.0, 26.0)
	sfx2("sting_night", -3.0, 1.0, "Music")
	var title: String = "CUSTOM NIGHT" if n >= FNData.NIGHTS.size() else String(FNData.NIGHTS[n]["title"])
	ui.night_card("НОЧЬ %d" % (n + 1) if n < FNData.NIGHTS.size() else "CUSTOM NIGHT", title)
	intro_t = 3.6                                  # заставка закрывает и снимки камер ниже
	actors.tick(st, 0.0)
	await cams.capture_all()
	cams.set_cam(st.cam)
	ring_t = 3.2
	call_lines = (FNData.CALLS[n] as Array).duplicate() if n < FNData.CALLS.size() else []
	call_t = 0.0
	hint_t = 45.0 if n == 0 else 0.0
	ui.hints("")
	get_tree().create_timer(4.0, true, false, true).timeout.connect(func():
		if state == "night" and n < FNData.PAHAN["start"].size():
			ui.msg(String(FNData.PAHAN["start"][n]), 3.5))

func retry() -> void:
	set_paused(false)
	start_night(night, levels)

func to_terminal() -> void:
	set_paused(false)
	scare.restore()
	if st != null:
		st.outcome = "quit"
	_menu_scene()

func set_paused(on: bool) -> void:
	if state != "night" and on:
		return
	paused = on
	ui.show_pause(on)
	for id in amb:
		(amb[id] as AudioStreamPlayer).stream_paused = on
	for id in actors.rigs:
		(actors.rigs[id] as Rig).player.speed_scale = 0.0 if on else 1.0

func _process(dt: float) -> void:
	_amb_tick(dt)
	_fear_tick(dt)
	match state:
		"menu":
			_menu_tick(dt)
		"night":
			if not paused:
				_night_tick(dt)
		"scare":
			office.tick(st, dt, office.yaw) if false else null
			ui.tick(st, dt, cams)

func _night_tick(dt: float) -> void:
	# взгляд: мышь у края экрана или стрелки; при поднятом планшете — прямо
	var vs := get_viewport().get_visible_rect().size
	var mx := get_viewport().get_mouse_position().x / maxf(1.0, vs.x) - 0.5
	var look_in := 0.0
	if absf(mx) > 0.14:
		look_in = clampf((absf(mx) - 0.14) / 0.3, 0.0, 1.0) * signf(mx)
	if look_key != 0.0:
		look_in = look_key
	# мышью смотрит только живой игрок: в проверке окно в углу без фокуса, и настоящая мышь тянула бы взгляд
	var mouse_ok: bool = main == null or main.user_play() or has_meta("look_mouse")
	if st.monitor or not mouse_ok:
		look_in = look_key if not st.monitor else 0.0
	# свет держится, пока держишь кнопку
	for s in ["l", "r"]:
		st.set_light(s, light_hold[s])
	if intro_t > 0.0:
		intro_t -= dt                              # заставка ночи: 12:00 AM ещё не наступило
	else:
		st.step(dt)
	for ev in st.take_events():
		_on_event(ev[0], ev[1])
	if state != "night":
		return
	office.tick(st, dt, look_in)
	# перебой: перед ним лампа будки мигает и гудит, во время — еле тлеет
	if st.brown_warn > 0.0:
		office.lamp.light_energy *= 0.35 if randf() < 0.45 else 1.0
	elif st.brown_t > 0.0:
		office.lamp.light_energy *= 0.22
	if fix_hold:
		st.fix_cam(dt)
	else:
		st.fix_t = maxf(0.0, st.fix_t - dt)
	fac.tick(dt)
	actors.tick(st, dt)
	cams.tick(st, dt)
	ui.tick(st, dt, cams)
	horror.tick(st, dt)
	anomaly.tick(st, dt)
	if intro_t <= 0.0:
		_call_tick(dt)
	_threat_sounds(dt)
	# лицо на камере — один кадр
	if face_flash > 0.0:
		face_flash -= dt
		cams.mat.set_shader_parameter("haunt", 1.0)
	if hint_t > 0.0:
		hint_t -= dt
		ui.hints("A / D — двери · Q / E (держать) — свет\nПРОБЕЛ — камеры · 1–8 — выбор камеры
на камере: L — приманка · C (держать) — перезапуск\nмышь к краю — посмотреть влево и вправо" if hint_t > 0.0 else "")
	if st.power_out:
		ui.show_dark(not st.emergency_used, st.crank_p / 6.0)
	else:
		ui.show_dark(false)
	# финал пятой ночи: в 5:58 свет мигает, в обоих проёмах — глаза
	if night == 4 and not finale_done and st.t > 6.0 * FNData.HOUR_SEC - 8.0:
		finale_done = true
		_finale()

func _finale() -> void:
	sfx2("giggle", -4.0, 0.8)
	for k in 6:
		office.lamp.light_energy = 0.0 if k % 2 == 0 else 1.6
		office.dark_eyes.visible = k % 2 == 0
		await get_tree().create_timer(0.35, true, false, true).timeout
	office.dark_eyes.visible = false

# ---------------- события ночи → звук и картинка ----------------
func _on_event(k: String, d: Dictionary) -> void:
	match k:
		"move":
			var to := String(d["to"])
			var e := String(d["e"])
			if to in ["door_l", "door_r"]:
				duck(true)
				var snd := "clank" if e == "bot" else ("step" if e in ["clipper", "ghost"] else "step_heavy")
				sfx3(snd, FNOffice.point(to), -2.0 if e != "clipper" else -6.0, 0.9)
			elif to in ["hall_l", "hall_r"]:
				sfx3("step", FNOffice.point(to), -10.0, 0.8)
			elif to in ["vent_l", "vent_t"]:
				sfx3("vent_bang", FNOffice.point(to), 2.0, 1.0)
			if String(d.get("why", "")) == "retreat" and String(d["from"]).begins_with("door"):
				sfx3("step", FNOffice.point(String(d["from"])), -12.0, 0.7)
		"heavy_step":
			sfx3("step_heavy", FNOffice.point("hall_" + String(d["side"])), 0.0, 0.75)
			office.lamp.light_energy = 0.1
		"bang":
			var at := String(d["at"])
			sfx3("vent_bang" if at.begins_with("vent") else "door_down", FNOffice.point(at), 4.0, 0.7)
			office.shake = 0.5
			if not said_door and at.begins_with("door"):
				said_door = true
				ui.msg(String(FNData.PAHAN["door"][randi() % FNData.PAHAN["door"].size()]), 3.0)
		"scrape":
			sfx3("scrape", FNOffice.point("door_l"), 2.0, 1.0)
		"flinch":
			sfx3("scream_clipper", FNOffice.point("door_l"), -14.0, 1.6)
		"ping":
			ping_beep = 0.01
		"ping_ok":
			sfx2("click", -6.0, 1.4)
		"ping_lost":
			sfx2("power_down", -14.0, 2.2)
		"door":
			sfx3("door_down" if d["closed"] else "door_up", FNOffice.point("door_" + String(d["s"])) * Vector3(0.75, 1, 1) + Vector3(0, 1.6, 0), -2.0)
			office.press("door_" + String(d["s"]))
		"light":
			if d["on"]:
				sfx3("click", office.lights[String(d["s"])].global_position, -10.0, 1.3)
		"seal":
			sfx3("click", FNOffice.point("vent_" + String(d["s"])), -4.0, 0.8)
			office.press("seal_" + String(d["s"]))
		"monitor":
			sfx2("cam", -10.0, 0.8 if d["on"] else 0.6)
			if not d["on"]:
				horror.on_monitor_down(st)
		"cam":
			sfx2("cam", -12.0)
		"glitch":
			sfx2("static", -16.0, 1.3)
			if String(d["k"]) == "fake_alarm":
				ui.alarm(String(d["d"]))
				sfx2("ping", -6.0, 0.7)
		"reset":
			sfx2("power_down", -10.0, 1.8)
			office.press("reset")
		"force_open":
			sfx3("door_up", FNOffice.point("door_r") + Vector3(-0.5, 1.6, 0), 2.0, 0.85)
			ui.alarm("ПРАВАЯ ДВЕРЬ ОТКРЫТА СИСТЕМОЙ")
		"power_out":
			sfx2("power_down", 0.0)
			ui.msg(String(FNData.PAHAN["dark"][0]), 3.0)
			crawl.volume_db = -60.0
		"dark_eyes":
			office.dark_eyes.visible = true
			if _snd_ok():
				air_tune.play()
		"crank":
			sfx2("crank", -6.0, 0.9 + float(d["p"]) * 0.05)
		"power_back":
			sfx2("click", 0.0)
			office.dark_eyes.visible = false
			air_tune.stop()
			ui.msg("Есть! Шесть процентов. Не трать.", 3.0)
		"stare":
			if st.monitor and st.cam == String(d["at"]):
				sfx2("static", -20.0, 0.7)
		"cam_broken":
			sfx2("power_down", -16.0, 2.6)
			if not said_broken:
				said_broken = true
				ui.msg("Одна камера перестала отвечать. Найди её и держи C, пока не перезапустится.", 4.0)
		"cam_fixed":
			sfx2("ping", -8.0, 1.3 if not bool(d["auto"]) else 0.9)
		"brown_warn":
			sfx2("buzz", 4.0, 0.7)
			if not said_brown:
				said_brown = true
				ui.msg("Лампы гудят… сейчас будет перебой. Двери держат, а камеры и фонари — нет.", 4.0)
		"brown":
			sfx2("power_down", -8.0, 2.2)
		"brown_end":
			sfx2("click", -2.0, 1.1)
		"lure":
			sfx2("toy", -6.0, 1.0)
			ui.msg("Приманка в комнате «%s»." % _cam_name(String(d["room"])), 2.0)
		"attack":
			_attack(String(d["e"]), String(d["at"]))
		"win":
			_six()

func _cam_name(id: String) -> String:
	for c in FNData.CAMS:
		if String(c["id"]) == id:
			return String(c["name"]).to_lower()
	return id

## звуки угрозы, которые идут, пока угроза есть: MADK1D в шахте, шёпот GHOST, писк сервера
func _threat_sounds(dt: float) -> void:
	var m: FNEnemy = st.enemies["madk1d"]
	var near := m.spot in ["duct_l", "duct_t", "vent_l", "vent_t"] and m.level > 0 and not st.power_out
	if near and _snd_ok():
		if not crawl.playing:
			crawl.play()
		crawl.global_position = FNOffice.point(m.spot)
		crawl.volume_db = move_toward(crawl.volume_db, (-4.0 if m.spot.begins_with("vent") else -12.0), dt * 30.0)
	else:
		crawl.volume_db = move_toward(crawl.volume_db, -60.0, dt * 30.0)
		if crawl.volume_db <= -59.0 and crawl.playing:
			crawl.stop()
	var g: FNGhost = st.enemies["ghost"]
	var wv := -60.0 if g.haunt <= 0.02 else lerpf(-26.0, 2.0, clampf(g.haunt, 0.0, 1.0))
	if wv > -59.0 and not whisper.playing and _snd_ok():
		whisper.play()
	whisper.volume_db = move_toward(whisper.volume_db, wv, dt * 40.0)
	var b: FNBot = st.enemies["bot"]
	if b.ping_left > 0.0 and not st.power_out:
		ping_beep -= dt
		if ping_beep <= 0.0:
			ping_beep = 2.0 if b.ping_left > 5.0 else 0.9
			sfx2("ping", -6.0 if b.ping_left > 5.0 else -2.0)

# ---------------- звонок начальника ----------------
func _call_tick(dt: float) -> void:
	if ring_t > 0.0:
		ring_t -= dt
		if ring_t <= 0.0 and not call_lines.is_empty():
			sfx3("ring", Vector3(0.72, 0.9, -0.8), -4.0)
			call_t = 2.4
		return
	if call_muted or call_lines.is_empty():
		if call_lines.is_empty() and call_t > -50.0:
			call_t -= dt
			if call_t <= 0.0:
				ui.sub("")
				call_t = -99.0
		return
	call_t -= dt
	if call_t <= 0.0:
		var line: String = call_lines.pop_front()
		ui.sub("☎  " + line + ("" if call_lines.is_empty() else "\n[F — сбросить звонок]"))
		call_t = clampf(float(line.length()) * 0.065, 3.2, 6.5)
		if _snd_ok():
			sfx2("babble", -10.0, randf_range(0.9, 1.1), "Voice")

func mute_call() -> void:
	call_muted = true
	call_lines.clear()
	ui.sub("")
	sfx2("click", -6.0)

# ---------------- скример и гибель ----------------
func _attack(eid: String, at: String) -> void:
	state = "scare"
	light_hold = {"l": false, "r": false}
	ui.show_dark(false)
	ui.hints("")
	ui.sub("")
	air_tune.stop()
	crawl.stop()
	whisper.stop()
	FNSave.died(eid)
	await scare.play("dark" if at == "dark" else eid, at, randi() % 3)
	ui.hurt = 0.0
	sfx2("static", -2.0)
	_dead(eid, at)

func _dead(eid: String, at: String) -> void:
	state = "dead"
	sfx2("sting_lose", -4.0)
	var nm: String = FNData.ENEMIES[eid]["name"]
	var hint := "Энергия кончилась. Двери, свет и камеры — всё в расход. Экономь: открывай двери, как только ушли." if at == "dark" else String(FNData.ENEMIES[eid]["counter"])
	ui.dead_card(nm, hint, [["ЕЩЁ РАЗ", func(): start_night(night, levels)], ["В МЕНЮ ОХРАНЫ", to_terminal]])
	scare.restore()

func _six() -> void:
	state = "six"
	ui.sub("")
	ui.show_dark(false)
	air_tune.stop()
	crawl.stop()
	whisper.stop()
	sfx2("chime", 0.0, 1.0, "Music")
	var pay: int = FNData.PAY[mini(night, FNData.PAY.size() - 1)]
	var extra := ""
	if night < 6:
		FNSave.beat(night, st.power)
	if night == 4:
		extra = String(FNData.ENDINGS["night5"][1]) + "\n\nОТКРЫТА НОЧЬ 6."
	elif night == 5:
		extra = String(FNData.ENDINGS["night6"][1]) + "\n\nОТКРЫТА CUSTOM NIGHT."
	elif night == 6:
		var all20 := FNData.ORDER.all(func(e): return int(levels.get(e, 0)) >= 20)
		if all20:
			FNSave.ending("custom20")
			extra = String(FNData.ENDINGS["custom20"][1])
	if night == 5:
		await scare.pahan(false)                      # конец шестой: резервная копия пришла за оригиналом
	var line: String = FNData.PAHAN["six"][mini(night, FNData.PAHAN["six"].size() - 1)]
	ui.six_card(pay, line, extra)
	get_tree().create_timer(7.5 if extra == "" else 12.0, true, false, true).timeout.connect(func():
		if state != "six":
			return
		if night < 4:
			start_night(night + 1)
		else:
			_menu_scene())

## безвредный двойник (секрет): на миг Пахан видит себя перед столом
func double_scare() -> void:
	if scare.busy:
		return
	set_paused(false)
	state = "scare"
	await scare.pahan(false)
	if st != null and st.outcome == "":
		state = "night"

## MOD: монитор сам поднимается и показывает помехи
func force_tablet_face() -> void:
	ui.tablet_k = 1.0
	ui.tablet.visible = true
	ui.feed.material = cams.mat
	cams.mat.set_shader_parameter("jam", 1.0)
	cams.mat.set_shader_parameter("haunt", 1.0)
	sfx2("static", 0.0, 0.6)

func ui_slash() -> void:
	var l := Line2D.new()
	var s := get_viewport().get_visible_rect().size
	l.points = PackedVector2Array([Vector2(s.x * 0.1, s.y * 0.15), Vector2(s.x * 0.9, s.y * 0.85)])
	l.width = 14.0
	l.default_color = Color(0.9, 0.05, 0.05, 0.95)
	ui.card.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "width", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func ui_invert(sec: float) -> void:
	ui.inv_t = sec * float(FNSave.v("settings")["fx"])        # мерцающая инверсия в экранном шейдере (0 — выкл. эффекты)

## осколки экрана (MOD)
func shards(at: Vector3) -> void:
	for k in 14:
		var b := office.box(at, Vector3(0.04, 0.03, 0.005), office.mats["paper"], self, Vector3(randf(), randf(), randf()) * TAU)
		var tw := b.create_tween()
		tw.tween_property(b, "position", at + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.6), randf_range(0.2, 0.9)), 0.5)
		tw.tween_callback(b.queue_free)

# ---------------- ввод ----------------
func pick_cam(id: String) -> void:
	if state == "night" and st.monitor and not paused:
		st.set_cam(id)

func _toggle(what: String) -> void:
	match what:
		"door_l":
			st.set_door("l", not st.door["l"])
		"door_r":
			st.set_door("r", not st.door["r"])
		"seal_l":
			st.set_seal("l", not st.seal["l"])
		"seal_t":
			st.set_seal("t", not st.seal["t"])
		"reset":
			if not st.reset_system():
				sfx2("ping", -10.0, 0.6)
		"phone":
			mute_call()

func _crank(k: String) -> void:
	if k != crank_last:
		crank_last = k
		st.crank()

## стрелки — взгляд: ловим раньше интерфейса (иначе их забирает навигация ui_left/ui_right)
func _input(e: InputEvent) -> void:
	if state != "night" or not (e is InputEventKey) or e.echo:
		return
	var k: int = e.keycode
	if k == KEY_LEFT or k == KEY_RIGHT:
		var dir := -1.0 if k == KEY_LEFT else 1.0
		if e.pressed:
			look_key = dir
		elif look_key == dir:
			look_key = 0.0
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	if state == "menu":
		if e is InputEventKey and e.pressed and not e.echo:
			menu.key(e.keycode)
		return
	if state != "night" or st == null:
		return
	if e is InputEventKey:
		var k: int = e.keycode
		if k == KEY_ESCAPE and e.pressed and not e.echo:
			set_paused(not paused)
			return
		if paused:
			return
		if st.power_out:
			if e.pressed and not e.echo and k in [KEY_A, KEY_D]:
				_crank("a" if k == KEY_A else "d")
			return
		match k:
			KEY_Q:
				light_hold["l"] = e.pressed
			KEY_E:
				light_hold["r"] = e.pressed
			KEY_C:
				fix_hold = e.pressed
		if not e.pressed or e.echo:
			return
		match k:
			KEY_A:
				_toggle("door_l")
			KEY_D:
				_toggle("door_r")
			KEY_Z:
				_toggle("seal_l")
			KEY_X:
				_toggle("seal_t")
			KEY_R:
				_toggle("reset")
			KEY_F:
				mute_call()
			KEY_L:
				if st.monitor:
					st.lure(st.cam)
			KEY_SPACE, KEY_S, KEY_TAB:
				st.set_monitor(not st.monitor)
			_:
				if k >= KEY_1 and k <= KEY_9 and st.monitor:
					var i := k - KEY_1
					if i < FNData.CAMS.size():
						st.set_cam(String(FNData.CAMS[i]["id"]))
					elif i == 8 and ui.cam9_btn.visible:
						st.set_cam("room9")
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not paused:
		if st.monitor:
			return
		if st.power_out:
			if e.pressed:
				_crank("m%d" % (randi() % 2))
			return
		var id := office.pick(e.position)
		if id.begins_with("light_"):
			light_hold[id.substr(6)] = e.pressed
			return
		if not e.pressed:
			light_hold = {"l": false, "r": false}
			return
		if id != "":
			_toggle(id)
		elif e.position.y > get_viewport().get_visible_rect().size.y * 0.9:
			st.set_monitor(true)                 # нижний край — поднять планшет
