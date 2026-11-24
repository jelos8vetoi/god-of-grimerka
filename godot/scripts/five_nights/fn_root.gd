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
@onready var office: FNOffice = $GuardBooth
@onready var hall_l: FNCorridor = $Cam4Corridor
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
var night_token := 0              # растёт в каждом start_night: отложенные реплики старой ночи молчат
var tut_duct := false             # подсказки ночи 2 про MADK1D: каждая — один раз за попытку
var tut_vent_l := false
var tut_vent_t := false
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
var face_flash := 0.0
var pending_reflection := false
var said_door := false
var far_pool: Array = []          # два проигрывателя для дальних ходов врагов (FNCues)
var far_q: Array = []             # отложенные удары: [осталось с, id, позиция, дБ, высота]
var far_last := {}                # враг → st.t последнего дальнего звука
var cue_log: Array = []           # для проверок: [st.t, враг, точка, вид, id, позиция]
var said_far := false
var hint_t := 0.0
var end_t := 0.0
var finale_done := false
var intro_t := 0.0                  # заставка ночи: пока идёт, часы стоят и враги не ходят
# звук
var tension := FNTension.new()      # фаза и уровень напряжения ночи
var ambience: FNAmbience             # фон будки и случайные звуки здания
var crawl: AudioStreamPlayer3D      # MADK1D в шахте
var whisper: AudioStreamPlayer      # GHOST: шёпот растёт с одержимостью
var air_tune: AudioStreamPlayer3D   # «последний шанс»
var pool3: Array = []
var pool2: Array = []
var call_voice: AudioStreamPlayer3D   # голос начальника в трубке (assets/voice/FN_*.mp3, шина PhoneVoice → Voice, из трубки на столе)
var pahan_voice: AudioStreamPlayer  # мысли Пахана вслух (assets/voice/V_*.mp3 — его голос из кампании, шина Voice)
## Говорит всегда кто-то один. Строки по центру экрана (мысли Пахана и подсказки) идут очередью say_q: следующая
## появляется, когда прошлая отстояла своё и Пахан договорил. Пахан не начинает посреди реплики начальника — ждёт её
## конца; начальник не начинает следующую реплику (и телефон не звонит), пока Пахан говорит или ждёт очереди.
var say_q: Array = []               # [[текст, секунды, голосом Пахана?]]
var say_t := 0.0                    # сколько ещё держится текущая строка
const SAY_MAX := 3                  # длиннее очередь не копим: старая подсказка уже не к месту

func _ready() -> void:
	if main == null:
		main = get_tree().root.get_node_or_null("Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	quiet = main != null and main.testing() != ""
	FNSave.load_all()
	FNSound.warm()
	fac = FNFacility.new()
	add_child(fac)
	fac.build(office, hall_l)
	actors = FNActors.new()
	add_child(actors)
	actors.build(office, fac)
	office.seal_stop.connect(_on_seal_stop)
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

func apply_fx() -> void:
	var k := float(FNSave.v("settings")["fx"])
	ui.fx_k = k
	cams.fx_k = k

# ---------------- звук ----------------
func _audio() -> void:
	ambience = FNAmbience.new()
	add_child(ambience)
	ambience.build(self)
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
	for k in 2:
		var pf := AudioStreamPlayer3D.new()
		pf.bus = "SFX"
		pf.unit_size = 9.0
		pf.max_db = 0.0
		pf.attenuation_filter_cutoff_hz = 2400.0
		pf.attenuation_filter_db = -24.0
		add_child(pf)
		far_pool.append(pf)
	for k in 6:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		pool2.append(p2)
	call_voice = AudioStreamPlayer3D.new()
	call_voice.bus = "PhoneVoice" if AudioServer.get_bus_index("PhoneVoice") >= 0 else ("Phone" if AudioServer.get_bus_index("Phone") >= 0 else "Voice")
	call_voice.volume_db = 1.0
	call_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	call_voice.panning_strength = 0.45
	call_voice.attenuation_filter_cutoff_hz = 20500.0
	add_child(call_voice)
	var phone_at := office.get_node_or_null("Console/PhoneHit") as Node3D
	if phone_at != null:
		call_voice.global_position = phone_at.global_position
	pahan_voice = AudioStreamPlayer.new()
	pahan_voice.bus = "RoomVoice" if AudioServer.get_bus_index("RoomVoice") >= 0 else "Voice"
	pahan_voice.volume_db = -1.0
	add_child(pahan_voice)

func _p3(id: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = FNSound.get_stream(id)
	p.bus = "SFX"
	p.unit_size = 5.0
	add_child(p)
	return p

## Крик скримера: один проигрыватель на шине Horror (у неё свой ограничитель) — два крика друг на друга не лягут.
## kind — "balon", "ghost", "pahan", "dark"…; громкость — настройка «ГРОМКОСТЬ СКРИМЕРОВ». Возвращает длину, с.
var adapt_log: Array = []          # как обитатели подстраивались под игрока за эту ночь: [кто, как] — для проверки и архива
var scream_p: AudioStreamPlayer
var scream_kind := ""
var scream_var := 0
var scream_at := 0                 # когда запущен последний крик (мс) — для проверки синхронности
func scream(kind: String, vol := 0.0) -> float:
	scream_kind = kind
	scream_at = GameClock.ms()
	var pick := FNSound.scream_pick(kind)
	scream_var = int(pick[1])
	if scream_p == null:
		scream_p = AudioStreamPlayer.new()
		scream_p.bus = "Horror" if AudioServer.get_bus_index("Horror") >= 0 else "SFX"
		add_child(scream_p)
	scream_p.stop()
	scream_p.stream = pick[0]
	var k := clampf(float((FNSave.v("settings") as Dictionary).get("scream", 1.0)), 0.0, 1.0)
	scream_p.volume_db = vol + linear_to_db(maxf(0.0001, k)) + (FNSound.trim("scream_" + kind) if scream_var == 0 else SCREAM_DB)
	if _snd_ok() or scream_force:
		scream_p.play()
	return (pick[0] as AudioStream).get_length()
const SCREAM_DB := -1.0            # общий уровень записанных криков: громко, но ниже ограничителя
var scream_force := false          # проверка: играть крик и в «тихом» режиме (мастер-шина заглушена, пики шины Horror меряются)

## Мёртвая тишина перед скримером. mode: "dead" — пропадает всё (фон, эффекты, голоса), "amb" — только гул и
## вентиляция, "sfx" — обрываются эффекты и голоса, гул остаётся, "none" — ничего. Мгновенно, без затухания.
var hush_mode := ""
func hush_begin(mode: String) -> void:
	hush_mode = mode
	if mode == "none" or mode == "":
		return
	if mode in ["dead", "sfx"]:
		for p in pool2:
			(p as AudioStreamPlayer).stop()
		for p in pool3:
			(p as AudioStreamPlayer3D).stop()
		ambience.stop_events()
		call_voice.stop()
		pahan_voice.stop()
		air_tune.stop()
		crawl.volume_db = -80.0
		whisper.volume_db = -80.0
	if mode in ["dead", "amb"] and main != null and main.audio != null:
		main.audio.hush(true, true)

## скример кончился (экран гибели, новая ночь, терминал): фон возвращается плавно
func hush_end() -> void:
	hush_mode = ""
	if main != null and main.audio != null:
		main.audio.hush(false, false)

func _snd_ok() -> bool:
	return not quiet or (main != null and main.audiolog)

## заслонка дошла до упора: глухой удар (закрытая — громче и ниже)
func _on_seal_stop(s: String, closed: bool) -> void:
	sfx3("damper_stop", FNOffice.point("vent_" + s), -4.0 if closed else -11.0, 1.0 if closed else 1.25)

## дальний ход врага: звук из комнаты, где он встал; молчит при угрозе рядом, в первые секунды ночи, при скримере и чаще раза в FAR_GAP
func _far_cue(e: String, to: String, blocked: bool) -> void:
	if blocked or st.t < FNCues.FAR_FROM or scare.busy or FNCues.far_pos(to) == Vector3.ZERO or not st.enemies.has(e):
		return
	if st.t - float(far_last.get(e, -1000.0)) < FNCues.FAR_GAP:
		return
	far_last[e] = st.t
	var id := FNCues.far_id(e)
	var pos := FNCues.far_pos(to)
	var db: float = float(FNCues.FAR_TRIM[id]) + FNCues.FAR_LEVEL
	var pitch := randf_range(0.92, 1.0)
	cue_log.append([st.t, e, to, "far", id, pos])
	_far_play(id, pos, db, pitch)
	if e == "balon":
		far_q.append([randf_range(FNCues.STEP2_GAP[0], FNCues.STEP2_GAP[1]), id, pos, db + FNCues.STEP2_DB, pitch * FNCues.STEP2_PITCH])
	ambience.cue_dip()
	if night == 0 and e == "balon" and not said_far and not st.monitor and not (FNSave.v("beaten") as Array).has(0):
		said_far = true
		say("В здании кто-то ходит. Проверь камеры.", 3.5)

func _far_play(id: String, pos: Vector3, db: float, pitch: float) -> void:
	if not _snd_ok():
		return
	for p in far_pool:
		var a := p as AudioStreamPlayer3D
		if not a.playing:
			a.stream = FNSound.pick(id)
			a.global_position = pos
			a.volume_db = db
			a.pitch_scale = pitch
			a.play()
			return

## зацикленный поток в одноразовом пуле не играем: он звучал бы до конца процесса
func _loop_stream(s: AudioStream, id: String) -> bool:
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		push_error("FN: зацикленный звук «%s» в одноразовом пуле" % id)
		return true
	return false

## глушит всё разовое: пулы звуков, шёпот и ползание, реплики, помехи и красные вспышки; настройки громкости игрока не трогает
func clear_transients(keep_scream := false) -> void:
	for p in far_pool:
		(p as AudioStreamPlayer3D).stop()
	far_q.clear()
	for p in pool2:
		(p as AudioStreamPlayer).stop()
	for p in pool3:
		(p as AudioStreamPlayer3D).stop()
	if air_tune != null:
		air_tune.stop()
	if crawl != null:
		crawl.stop()
		crawl.volume_db = -60.0
	if whisper != null:
		whisper.stop()
		whisper.volume_db = -60.0
	if call_voice != null:
		call_voice.stop()
	_say_clear()
	if ambience != null:
		ambience.stop_events()
	if not keep_scream and scream_p != null:
		scream_p.stop()
	if ui != null:
		ui.hurt = 0.0
		ui.neg = false
		ui.inv_t = 0.0
	face_flash = 0.0
	if cams != null and cams.mat != null:
		cams.mat.set_shader_parameter("jam", 0.0)
		cams.mat.set_shader_parameter("haunt", 0.0)
	hush_end()

func _exit_tree() -> void:
	hush_end()
	if main != null and is_instance_valid(main) and main.audio != null:
		main.audio.room(20500.0, 0.0)

## звук из точки (направление слышно): шаги у двери, стук в шахте
func sfx3(id: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	if not _snd_ok():
		return
	for p in pool3:
		var a := p as AudioStreamPlayer3D
		if not a.playing:
			var st3 := FNSound.pick(id)
			if _loop_stream(st3, id):
				return
			a.stream = st3
			a.global_position = pos
			a.volume_db = vol + FNSound.trim(id)
			a.pitch_scale = pitch
			a.play()
			return

## звук без места: интерфейс, крик скримера
func sfx2(id: String, vol := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not _snd_ok():
		return
	if id.begins_with("scream_") and pitch == 1.0:
		scream(id.substr(7), vol - 2.0)          # крик скримера — отдельным проигрывателем, из записей
		return
	for p in pool2:
		var a := p as AudioStreamPlayer
		if not a.playing:
			var st2 := FNSound.pick(id)
			if _loop_stream(st2, id):
				return
			a.stream = st2
			a.volume_db = vol + FNSound.trim(id)
			a.pitch_scale = pitch
			a.bus = FNSound.bus_for(id, bus)
			a.play()
			return

## тишина перед появлением: окружение уходит почти в ноль
func duck(on: bool) -> void:
	ambience.duck(on)

# ---------------- меню-терминал ----------------
func _menu_scene() -> void:
	clear_transients()
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
	actors.tick(menu_st, dt, false)
	fac.tick(dt)
	cams.tick(menu_st, dt)

## из меню мини-игры — в меню режимов GOD OF GRIMERKA
func quit_to_menu() -> void:
	clear_transients()
	FNSave.save()
	if main != null and main.has_method("end_minigame"):
		main.end_minigame(ModeSelect.index_of("five_nights"))

## музыка: в терминале — своя тема (хор и колокольчики, loc_fn), ночью музыки нет — только здание и враги
func music_set() -> String:
	return "loc_fn" if state == "menu" else ""

# ---------------- ночь ----------------
func start_night(n: int, lv := {}) -> void:
	clear_transients()
	night_token += 1
	var tok := night_token
	night = n
	levels = lv
	var first_time: bool = (FNSave.v("beaten") as Array).is_empty()
	FNSave.played()
	tut_duct = false
	tut_vent_l = false
	tut_vent_t = false
	if n < 5:
		FNSave.put("current", n)
	st = FNNight.new()
	st.setup(n, int(Time.get_ticks_usec() % 2147483647), lv)
	office.seal_reset(st)
	menu.visible = false
	ui.hud.visible = true
	ui.night_begin(n, first_time)
	ui.show_pause(false)
	ui.show_dark(false)
	paused = false
	scare.restore()
	actors.hide_all()
	office.dark_eyes.visible = false
	office.cam.current = true
	horror.reset(int(st.rng.seed))
	office.dress(n)
	anomaly.reset(int(st.rng.seed))
	said_door = false
	far_last = {}
	far_q.clear()
	cue_log.clear()
	said_far = false
	fix_hold = false
	finale_done = false
	call_muted = false
	face_flash = 0.0
	end_t = 0.0
	crank_last = ""
	light_hold = {"l": false, "r": false}
	air_tune.stop()
	call_voice.stop()
	_say_clear()
	crawl.volume_db = -60.0
	state = "night"
	sfx2("sting_night", -3.0, 1.0, "Music")
	var title: String = "свои уровни" if n >= FNData.NIGHTS.size() else String(FNData.NIGHTS[n]["title"])
	ui.night_card("НОЧЬ %d" % (n + 1) if n < FNData.NIGHTS.size() else "СВОЯ НОЧЬ", title)
	intro_t = 3.6                                  # заставка закрывает и снимки камер ниже
	actors.tick(st, 0.0)
	await cams.capture_all()
	cams.set_cam(st.cam)
	# сначала Пахан говорит своё (с четвёртой секунды), потом звонит телефон
	ring_t = 6.8 if n < FNData.PAHAN["start"].size() else 3.2
	call_lines = (FNData.CALLS[n] as Array).duplicate() if n < FNData.CALLS.size() else []
	call_t = 0.0
	hint_t = 45.0 if n == 0 else 0.0
	ui.hints("")
	# подсказки смены: основы, потом каждый обитатель, который ходит этой ночью (впервые — один раз)
	for id in ["start", "doors", "light", "cams"]:
		ui.tips.tip(id)
	for id in FNData.ORDER:
		var en = st.enemies.get(id)
		if en != null and int(en.level) > 0:
			if id == "madk1d":
				ui.tips.tip("vents")
			if id == "mod":
				ui.tips.tip("reset")
			ui.tips.tip(id)
	get_tree().create_timer(4.0, true, false, true).timeout.connect(func():
		if tok == night_token and state == "night" and n < FNData.PAHAN["start"].size():
			pahan_say(String(FNData.PAHAN["start"][n]), 3.5))

func retry() -> void:
	set_paused(false)
	start_night(night, levels)

func to_terminal() -> void:
	clear_transients()
	set_paused(false)
	call_voice.stop()
	_say_clear()
	scare.restore()
	if st != null:
		st.outcome = "quit"
	_menu_scene()

func set_paused(on: bool) -> void:
	if state != "night" and on:
		return
	paused = on
	ui.show_pause(on)
	ambience.set_paused(on)
	call_voice.stream_paused = on
	pahan_voice.stream_paused = on
	for id in actors.rigs:
		(actors.rigs[id] as Rig).player.speed_scale = 0.0 if on else 1.0

func _process(dt: float) -> void:
	if state == "night" and st != null and st.power < 25.0 and not st.power_out:
		ui.tips.tip("power")
	if st != null and state in ["night", "scare"]:
		tension.tick(st, dt, night)
		office.tension_k = tension.level
	ambience.tick(st, state, dt)
	match state:
		"menu":
			_menu_tick(dt)
		"night":
			if not paused:
				_night_tick(dt)
		"scare":
			if false:
				office.tick(st, dt, office.yaw)
			ui.tick(st, dt, cams)

func _night_tick(dt: float) -> void:
	for q in far_q.duplicate():
		q[0] = float(q[0]) - dt
		if float(q[0]) <= 0.0:
			far_q.erase(q)
			_far_play(String(q[1]), q[2], float(q[3]), float(q[4]))
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
	office.fan_tick(dt, ambience.fan_spin)
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
	_say_tick(dt)
	if intro_t <= 0.0:
		_call_tick(dt)
	_threat_sounds(dt)
	# лицо на камере — один кадр
	if face_flash > 0.0:
		face_flash -= dt
		cams.mat.set_shader_parameter("haunt", 1.0)
	if hint_t > 0.0:
		hint_t -= dt
		ui.hints("office" if hint_t > 0.0 and not st.monitor else "")
	# мышь над кнопкой в самой будке — подсказка, что это за кнопка (та же, что у плашки пульта)
	ui.tip_3d = office.pick(get_viewport().get_mouse_position()) if not st.monitor and not paused and not quiet else ""
	if st.power_out:
		ui.show_dark(not st.emergency_used, st.crank_p / 6.0)
	else:
		ui.show_dark(false)
	# финал пятой ночи: в 5:58 свет мигает, в обоих проёмах — глаза
	if night == 4 and not finale_done and st.t > 6.0 * FNData.HOUR_SEC - 8.0:
		finale_done = true
		_finale()

func _finale() -> void:
	var shift := st
	sfx2("giggle", -4.0, 0.8)
	for k in 6:
		if st != shift or state != "night" or st.power_out:
			break
		office.event_gain = 0.0 if k % 2 == 0 else 2.0
		office.dark_eyes.visible = k % 2 == 0
		await get_tree().create_timer(0.35, true, false, true).timeout
	if st == shift:
		office.event_gain = 1.0
		if not st.power_out:
			office.dark_eyes.visible = false

# ---------------- события ночи → звук и картинка ----------------
## Каждый час ночи — своё событие (не вредят, только давят): час 1 — тихо; час 2 — свет проседает; час 3 — всё
## замолкает на две секунды и три удара издалека; час 4 — телефон звонит один раз и молчит; час 5 — дыхание за спиной.
func _hour_event(h: int) -> void:
	if state != "night" or st == null or st.power_out:
		return
	match h:
		2:
			var shift := st
			for q in 5:
				if st != shift or state != "night" or st.power_out:
					break
				office.event_gain = 0.15 if q % 2 == 0 else 0.7
				await get_tree().create_timer(0.16, true, false, true).timeout
			if st == shift:
				office.event_gain = 1.0
				if state == "night" and not st.power_out:
					sfx2("power_down", -14.0, 1.8)
		3:
			hush_begin("amb")
			await get_tree().create_timer(2.0, true, false, true).timeout
			if state == "night":
				hush_end()
				for q in 3:
					sfx3("knock", FNOffice.point("door_r" if q % 2 == 0 else "door_l") + Vector3(0, 0, -6.0), -4.0, 0.8)
					await get_tree().create_timer(0.55, true, false, true).timeout
		4:
			if not call_voice.playing and call_lines.is_empty():
				sfx2("ring", -6.0)
				await get_tree().create_timer(2.4, true, false, true).timeout
				if state == "night":
					sfx2("click", -4.0, 0.8)
					sfx2("breath", -10.0, 0.8)
		5:
			sfx3("breath", office.cam.global_position + Vector3(0.3, 0.1, 0.9), 2.0, 0.7)
			await get_tree().create_timer(1.2, true, false, true).timeout
			if state == "night" and not pahan_voice.playing:
				msg_hour()

func msg_hour() -> void:
	ui.msg("Последний час.", 3.0)

func _on_event(k: String, d: Dictionary) -> void:
	match k:
		"ping":
			ui.tips.tip("bot")
		"scrape":
			ui.tips.tip("clipper")
		"power_out":
			office.dark_eyes.visible = false
			ui.tips.tip("dark")
		"hour":
			_hour_event(int(d["h"]))
		"adapt":
			adapt_log.append([String(d["e"]), String(d["how"])])
		"move":
			var blocked := ambience.events_blocked(st)
			ambience.hold(6.0)
			var to := String(d["to"])
			var e := String(d["e"])
			if st.monitor and (String(d["from"]) == st.cam or to == st.cam):
				cams.blip(randf_range(0.3, 0.5))           # кадр срывается, когда кто-то выходит из него или входит
				sfx2("static", -18.0, 1.2)
			if FNCues.kind(to) == "far" and FNCues.far_id(e) != "":
				_far_cue(e, to, blocked)
			if night == 1 and e == "madk1d" and not (FNSave.v("beaten") as Array).has(1):
				if to.begins_with("duct_") and not tut_duct:
					tut_duct = true
					say("В шахте кто-то ползёт. Слушай, с какой стороны.", 4.0)
				elif to == "vent_l" and not tut_vent_l:
					tut_vent_l = true
					say("Стук в решётке слева. Z — закрыть заслонку.", 4.0)
				elif to == "vent_t" and not tut_vent_t:
					tut_vent_t = true
					say("Стук над головой. X — закрыть люк.", 4.0)
			if to in ["door_l", "door_r"]:
				duck(true)
				var snd := FNCues.hall_id(e)
				cue_log.append([st.t, e, to, "door", snd, FNOffice.point(to)])
				sfx3(snd, FNOffice.point(to), -2.0 if e != "clipper" else -6.0, 0.9)
			elif to in ["hall_l", "hall_r"]:
				var step_at := FNOffice.point(to)
				if fac.spots.has(to) and st.enemies.has(e):
					step_at = fac.spot(to, (st.enemies[e] as FNEnemy).pose).origin + Vector3(0, 0.2, 0)      # шаг слышен там, где враг стоит в коридоре
				var hid := FNCues.hall_id(e)
				cue_log.append([st.t, e, to, "hall", hid, step_at])
				sfx3(hid, step_at, -9.0, 0.85)
			elif to in ["vent_l", "vent_t"]:
				sfx3("vent_bang", FNOffice.point(to), 2.0, 1.0)
			if String(d.get("why", "")) == "retreat" and String(d["from"]).begins_with("door"):
				sfx3("step", FNOffice.point(String(d["from"])), -12.0, 0.7)
		"heavy_step":
			ambience.hold(6.0)
			sfx3("step_heavy", FNOffice.point("hall_" + String(d["side"])), 0.0, 0.75)
			office.flick_t = 0.09
		"bang":
			ambience.hold(6.0)
			var at := String(d["at"])
			sfx3("vent_bang" if at.begins_with("vent") else "door_down", FNOffice.point(at), 4.0, 0.7)
			if at.begins_with("vent"):
				office.seal_bang(at.substr(5))
			office.shake = 0.5
			if not said_door and at.begins_with("door"):
				said_door = true
				pahan_say(String(FNData.PAHAN["door"][randi() % FNData.PAHAN["door"].size()]), 3.0)
		"scrape":
			ambience.hold(6.0)
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
			ui.toast("door_" + String(d["s"]))
		"light":
			if d["on"]:
				sfx3("click", office.lights[String(d["s"])].global_position, -10.0, 1.3)
		"seal":
			sfx3("click", FNOffice.point("vent_" + String(d["s"])), -4.0, 0.8)
			sfx3("damper_close" if bool(d.get("closed", st.seal[String(d["s"])])) else "damper_open", FNOffice.point("vent_" + String(d["s"])), -5.0)
			office.press("seal_" + String(d["s"]))
			ui.toast("seal_" + String(d["s"]))
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
			ui.toast("reset")
		"force_open":
			sfx3("door_up", FNOffice.point("door_r") + Vector3(-0.5, 1.6, 0), 2.0, 0.85)
			ui.alarm("ПРАВАЯ ДВЕРЬ ОТКРЫТА СИСТЕМОЙ")
		"power_out":
			sfx2("power_down", 0.0)
			pahan_say(String(FNData.PAHAN["dark"][0]), 3.0)
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
			pahan_say(String(FNData.PAHAN["back"][0]), 3.0)
		"stare":
			if st.monitor and st.cam == String(d["at"]):
				sfx2("static", -20.0, 0.7)
				cams.blip(0.12)
		"cam_broken":
			sfx2("power_down", -16.0, 2.6)
			if not said_broken:
				said_broken = true
				say("Одна камера перестала отвечать. Найди её и держи C, пока не перезапустится.", 4.0)
		"cam_fixed":
			sfx2("ping", -8.0, 1.3 if not bool(d["auto"]) else 0.9)
		"brown_warn":
			sfx2("buzz", 4.0, 0.7)
			if not said_brown:
				said_brown = true
				say("Лампы гудят… сейчас будет перебой. Двери держат, а камеры и фонари — нет.", 4.0)
		"brown":
			sfx2("power_down", -8.0, 2.2)
		"brown_end":
			sfx2("click", -2.0, 1.1)
		"lure":
			sfx2("toy", -6.0, 1.0)
			say("Приманка в комнате «%s»." % _cam_name(String(d["room"])), 2.0)
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
		if ring_t - dt <= 0.0 and pahan_pending():
			return                                    # Пахан говорит — телефон зазвонит, когда договорит
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
	if call_t - dt <= 0.0 and pahan_pending():
		return                                        # следующая реплика начальника ждёт, пока Пахан договорит
	call_t -= dt
	if call_t <= 0.0:
		var line: String = call_lines.pop_front()
		ui.sub(line, not call_lines.is_empty())
		call_t = clampf(float(line.length()) * 0.065, 3.2, 6.5)
		var vs := call_stream(line)
		if vs != null and _snd_ok():
			# настоящая озвучка: реплика на экране держится, пока её договаривают
			call_voice.stream = vs
			call_voice.pitch_scale = 0.84 if night == 5 else 1.0        # шестая ночь: звонит уже не Семёныч
			call_voice.play()
			call_t = maxf(2.0, float(vs.get_length()) / call_voice.pitch_scale + 0.45)
		elif _snd_ok():
			sfx2("babble", -10.0, randf_range(0.9, 1.1), "Voice")

## строка по центру экрана — в очередь (подсказка, мысль); voiced — голосом Пахана
func say(text: String, sec := 3.0, voiced := false) -> void:
	while say_q.size() >= SAY_MAX:
		var drop := 0
		for i in say_q.size():                        # сначала выкидываем немую подсказку, реплики голосом — в последнюю очередь
			if not bool(say_q[i][2]):
				drop = i
				break
		say_q.remove_at(drop)
	say_q.append([text, sec, voiced])

## Пахан говорит вслух: строка на экране и его голос (файл — как у реплик кампании: «V|текст»); строка держится,
## пока он договаривает. Нет файла — только строка.
func pahan_say(text: String, sec := 3.0) -> void:
	say(text, sec, true)

static func pahan_path(text: String) -> String:
	return "res://assets/voice/V_%s.mp3" % ("V|" + text).md5_text().substr(0, 10)

## Пахан говорит или ждёт своей очереди сказать
func pahan_pending() -> bool:
	return pahan_voice.playing or say_q.any(func(q): return bool(q[2]))

func _say_clear() -> void:
	say_q.clear()
	say_t = 0.0
	if pahan_voice != null:
		pahan_voice.stop()

func _say_tick(dt: float) -> void:
	say_t = maxf(0.0, say_t - dt)
	if say_t > 0.0 or pahan_voice.playing or say_q.is_empty():
		return
	var q: Array = say_q[0]
	var vs: AudioStream = null
	if bool(q[2]) and _snd_ok() and ResourceLoader.exists(pahan_path(String(q[0]))):
		vs = load(pahan_path(String(q[0]))) as AudioStream
	if vs != null and call_voice.playing:
		return                                        # начальник договаривает реплику — Пахан ждёт её конца
	say_q.pop_front()
	var sec := float(q[1])
	if vs != null:
		pahan_voice.stream = vs
		pahan_voice.play()
		sec = maxf(sec, float(vs.get_length()) + 0.4)
	ui.msg(String(q[0]), sec)
	say_t = sec + 0.2

## файл озвучки реплики звонка: как у остальной озвучки игры — код говорящего и начало md5 от «код|текст»
## (tools/godot-voice.cjs, код FN). Нет файла — null, тогда вместо голоса неразборчивое бормотание.
static func call_path(line: String) -> String:
	return "res://assets/voice/FN_%s.mp3" % ("FN|" + line).md5_text().substr(0, 10)

func call_stream(line: String) -> AudioStream:
	var p := call_path(line)
	return load(p) as AudioStream if ResourceLoader.exists(p) else null

func mute_call() -> void:
	call_muted = true
	call_lines.clear()
	call_voice.stop()
	ui.sub("")
	sfx2("click", -6.0)

# ---------------- скример и гибель ----------------
func _attack(eid: String, at: String) -> void:
	state = "scare"
	light_hold = {"l": false, "r": false}
	call_voice.stop()
	_say_clear()
	ui.show_dark(false)
	ui.hints("")
	ui.sub("")
	air_tune.stop()
	crawl.stop()
	whisper.stop()
	FNSave.died(eid)
	await scare.play("dark" if at == "dark" else eid, at, randi() % 3)
	ui.hurt = 0.0
	_dead(eid, at)

func _dead(eid: String, at: String) -> void:
	state = "dead"
	clear_transients(true)
	sfx2("static", -2.0)
	sfx2("sting_lose", -4.0)
	var nm: String = FNData.ENEMIES[eid]["name"]
	var hint := "Энергия кончилась. Двери, свет и камеры — всё в расход. Экономь: открывай двери, как только ушли." if at == "dark" else String(FNData.ENEMIES[eid]["counter"])
	ui.dead_card(nm, hint, [["ЕЩЁ РАЗ", func(): start_night(night, levels)], ["В МЕНЮ ОХРАНЫ", to_terminal]])
	scare.restore()

func _six() -> void:
	state = "six"
	ui.sub("")
	ui.show_dark(false)
	call_voice.stop()
	_say_clear()
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
		extra = String(FNData.ENDINGS["night6"][1]) + "\n\nОткрыта СВОЯ НОЧЬ: уровни врагов — на твой выбор."
	elif night == 6:
		var all20 := FNData.ORDER.all(func(e): return int(levels.get(e, 0)) >= 20)
		if all20:
			FNSave.ending("custom20")
			extra = String(FNData.ENDINGS["custom20"][1])
	if night == 5:
		await scare.pahan(false)                      # конец шестой: резервная копия пришла за оригиналом
	var line: String = FNData.PAHAN["six"][mini(night, FNData.PAHAN["six"].size() - 1)]
	ui.six_card(pay, line, extra)
	get_tree().create_timer(2.6, true, false, true).timeout.connect(func():       # строка появляется под «6 AM» — тогда и голос
		if state == "six" and ResourceLoader.exists(pahan_path(line)) and _snd_ok():
			pahan_voice.stream = load(pahan_path(line))
			pahan_voice.play())
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

## нажатие плашки пульта мышью: то же, что клавиша (свет — пока держишь)
func deck_press(id: String, down: bool) -> void:
	if paused or st == null or st.outcome != "" or st.power_out:
		return
	if id.begins_with("light_"):
		light_hold[id.substr(6)] = down
		return
	if not down:
		return
	if id == "monitor":
		st.set_monitor(not st.monitor)
	else:
		_toggle(id)

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
			KEY_F1:
				ui.toggle_deck_pin()
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
