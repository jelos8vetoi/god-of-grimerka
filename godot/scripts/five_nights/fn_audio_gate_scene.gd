## «5 НОЧЕЙ», звук P1: сцена прослушивания и сравнения. Открыть scenes/five_nights/audio_gate.tscn и нажать F6, либо:
##   Godot --path godot res://scenes/five_nights/audio_gate.tscn
## Утверждённые варианты (A2, B2, C1 событиями, свои звуки планшета) играют в обычной игре по умолчанию; здесь можно
## послушать каждый звук отдельно, сравнить с прежним и переключить, что играет игра («в игре», user://fn_audio_gate.json).
## «НОЧЬ В БУДКЕ» запускает настоящую игру: своя ночь без врагов, F5 БАЛОН, F6 камеры, F7 шахта (C1 ↔ прежние записи P0),
## F8 — скример БАЛОНА сейчас, F9 — MADK1D идёт по левой шахте (дальше — правила игры: Z закрывает заслонку).
## Запись (кадры и звук самой игры, Movie Maker):
##   Godot --path godot --write-movie <файл.avi> --fixed-fps 30 res://scenes/five_nights/audio_gate.tscn -- --clock=30 --fn-gate-capture=balon|cctv|madk1d|night
extends Control

const DUCT_KINDS := [["far", "далеко"], ["hit", "удар"], ["drag", "волочение"], ["near", "у решётки"], ["presence", "за решёткой"]]
const ROWS := [
	{"key": "balon", "title": "SOUND A — СКРИМЕР БАЛОНА", "a": "A1 · Organic Distortion", "b": "A2 · Physical Impact"},
	{"key": "cctv", "title": "SOUND B — ПЕРЕКЛЮЧЕНИЕ КАМЕРЫ", "a": "B1 · Analog Relay", "b": "B2 · Signal Transition"},
	{"key": "madk1d", "title": "SOUND C — MADK1D В ШАХТЕ (дубли пробы; в игре — событиями, ниже)", "a": "C1 · Heavy Duct Movement", "b": "C2 · Unnatural Crawling"},
]
## скримеры P1.2: [вид, название, из чего собран]
const SCREAMS := [
	["madk1d", "MADK1D", "люк срывается; кошачий рёв и вой из жестяной шахты"],
	["bot", "BOT", "без голоса: удар железа, дуга сварки, гайковёрт, дрель, остановка лебёдки"],
	["clipper", "CLIPPER", "клинок по клинку, ножницы, нож по бруску, мотор машинки; короткий"],
	["ghost", "GHOST", "не крик, а провал пространства: низ грома, замедленный детский крик задом наперёд"],
	["mod", "MOD", "аппаратура сходит с ума: автомат, модем на линии, треск эфира, перемотка кассеты"],
	["dark", "ТЕМНОТА", "после отключения питания: вплотную, сухо — низкий рык, хрип, глухой удар"],
]
const SCARE_KINDS := ["balon", "madk1d", "bot", "clipper", "ghost", "mod", "dark"]
const SCREAM_DB := -1.0            # FiveNightsRoot.SCREAM_DB
const CAM_DB := -12.0              # громкость вызова в игре (событие «cam»)
const CRAWL_DB := -4.0             # MADK1D у решётки (в шахте — −12)
const SERIES := [0.5, 0.5, 0.22, 0.16, 0.12, 0.12, 0.3, 0.14]

var panel: Control
var bg: ColorRect
var info: Label
var scream_p: AudioStreamPlayer
var cam_p: AudioStreamPlayer
var cam_pool: Array = []
var crawl_p: AudioStreamPlayer
var crawl_on := false
var crawl_v := ""
var main_node: Node
var fn                                # FiveNightsRoot настоящей игры
var madk_step := 0
var capture := ""
var guard := false                # запись ночи: закрывать дверь, пока у неё враг (клавишами A и D)
var guard_busy := false
var caption := ""
var scare_k := 0                  # какой скример вызывает F8 в ночи (SCARE_KINDS)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fn-gate-capture="):
			capture = a.substr(18)
	_buses()
	scream_p = _player("Horror")
	cam_p = _player("SFX")
	crawl_p = _player("SFX")
	for k in 6:
		cam_pool.append(_player("SFX"))
	_build()
	if capture != "":
		_capture()

## шины игры, если сцена запущена сама по себе: SFX и Horror с его ограничителем (как в audio.gd)
func _buses() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	if AudioServer.get_bus_index("Horror") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Horror")
		AudioServer.set_bus_send(i, "SFX")
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(i, lim)

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _build() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	panel = TabContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := _tab("P1 — УТВЕРЖДЕНО")
	_build_screams(_tab("СКРИМЕРЫ (P1.2)"))
	var head := Label.new()
	head.text = "5 НОЧЕЙ С ПАХАНОМ — AUDIO QUALITY GATE (P1)"
	head.add_theme_font_size_override("font_size", 26)
	box.add_child(head)
	for row in ROWS:
		var key: String = row["key"]
		var t := Label.new()
		t.text = String(row["title"])
		t.add_theme_font_size_override("font_size", 19)
		box.add_child(t)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		box.add_child(h)
		for v in FNAudioGate.VARIANTS:
			h.add_child(_btn("ORIGINAL" if v == "" else String(row[v]), _play.bind(key, v)))
		if key == "cctv":
			for v in FNAudioGate.VARIANTS:
				h.add_child(_btn("серия %s" % FNAudioGate.NAMES[v], _series.bind(v)))
		if key == "madk1d":
			h.add_child(_btn("СТОП", _stop_all))
		var lab := Label.new()
		lab.text = "   в игре:"
		h.add_child(lab)
		h.add_child(_option(key, ["", "a"] if key == "madk1d" else FNAudioGate.VARIANTS, {"": "записи P0", "a": "C1"} if key == "madk1d" else FNAudioGate.NAMES))
	# события шахты: C1, разложенный на события, и прежние записи P0 на тех же местах
	var dt := Label.new()
	dt.text = "MADK1D — СОБЫТИЯ ШАХТЫ (так играет игра)"
	dt.add_theme_font_size_override("font_size", 19)
	box.add_child(dt)
	for v in ["a", ""]:
		var hd := HBoxContainer.new()
		hd.add_theme_constant_override("separation", 8)
		box.add_child(hd)
		var ld := Label.new()
		ld.text = "C1:        " if v == "a" else "записи P0:"
		hd.add_child(ld)
		for k in DUCT_KINDS:
			hd.add_child(_btn(String(k[1]), _duct_one.bind(String(k[0]), v)))
		hd.add_child(_btn("заход целиком", _duct_run.bind(v)))
	# планшет
	var tt := Label.new()
	tt.text = "ПЛАНШЕТ — ПОДЪЁМ И ОПУСКАНИЕ"
	tt.add_theme_font_size_override("font_size", 19)
	box.add_child(tt)
	var ht := HBoxContainer.new()
	ht.add_theme_constant_override("separation", 8)
	box.add_child(ht)
	for it in [["подъём", true, "a"], ["опускание", false, "a"], ["прежний подъём", true, ""], ["прежнее опускание", false, ""]]:
		ht.add_child(_btn(String(it[0]), _tablet.bind(bool(it[1]), String(it[2]))))
	var lt := Label.new()
	lt.text = "   в игре:"
	ht.add_child(lt)
	ht.add_child(_option("tablet", ["", "a"], {"": "прежний", "a": "новый"}))
	box.add_child(_btn("НОЧЬ В БУДКЕ — послушать в игре (F5 / F6 / F7 — вариант, F8 — скример, F9 — MADK1D)", _game))
	var note := Label.new()
	note.text = "Кнопки играют теми же шинами и с той же громкостью, что игра. «в игре» — что играет обычная игра; по умолчанию — утверждённые A2, B2, C1 и новый планшет.\nMADK1D: дубли пробы (ORIGINAL — прежние 1,6 с подряд) оставлены для сравнения; в игре шахта звучит событиями. «заход целиком» — без места в пространстве, порядок каждый раз другой."
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(1, 1, 1, 0.65)
	box.add_child(note)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	info = Label.new()
	info.position = Vector2(16, 10)
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 6)
	info.visible = false
	layer.add_child(info)

func _tab(title: String) -> VBoxContainer:
	var c := CenterContainer.new()
	c.name = title
	panel.add_child(c)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	c.add_child(box)
	return box

func _title(box: Control, text: String, size := 19) -> void:
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", size)
	box.add_child(t)

## P1.2, скримеры: у каждого своя запись; ORIGINAL — один из трёх прежних дублей
func _build_screams(box: VBoxContainer) -> void:
	_title(box, "СКРИМЕРЫ — P1.2, играют по умолчанию (БАЛОН A2 — вкладка P1)", 24)
	for it in SCREAMS:
		var kind := String(it[0])
		_title(box, "%s — %s" % [it[1], it[2]], 16)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		box.add_child(h)
		h.add_child(_btn("ORIGINAL", _scream_one.bind(kind, "")))
		h.add_child(_btn("NEW", _scream_one.bind(kind, "a")))
		h.add_child(_btn("в будке ▶", _booth_scare.bind(kind)))
		var lab := Label.new()
		lab.text = "   в игре:"
		h.add_child(lab)
		h.add_child(_option("scream_" + kind, ["", "a"], {"": "ORIGINAL", "a": "NEW"}))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	box.add_child(hb)
	hb.add_child(_btn("СТОП", _stop_all))
	hb.add_child(_btn("в игре: ВСЕ NEW", _all_trial.bind(true)))
	hb.add_child(_btn("в игре: ВСЕ ORIGINAL", _all_trial.bind(false)))
	_title(box, "«в будке ▶» — настоящая ночь без врагов и этот скример через 4 с (ТЕМНОТА — питание гаснет, нападение приходит по правилам игры).
В ночи: F10 — какой скример, F12 — ORIGINAL / NEW, F8 — вызвать. Выбор «в игре» действует и на обычную игру.", 13)

func _scream_one(kind: String, v: String) -> void:
	scream_p.stop()
	scream_p.stream = FNSound.scream_pick(kind)[0] if v == "" else load(FNAudioGate.DIR + "scream_%s.wav" % kind)
	scream_p.volume_db = SCREAM_DB
	scream_p.play()

func _all_trial(on: bool) -> void:
	for it in SCREAMS:
		FNAudioGate.choose("scream_" + String(it[0]), "a" if on else "")
	get_tree().reload_current_scene()

func _booth_scare(kind: String) -> void:
	scare_k = SCARE_KINDS.find(kind)
	await _game()
	await get_tree().create_timer(4.0).timeout
	_scare()

func _option(key: String, variants: Array, names: Dictionary) -> OptionButton:
	var ob := OptionButton.new()
	for v in variants:
		ob.add_item(String(names[v]))
	ob.select(maxi(0, variants.find(FNAudioGate.variant(key))))
	ob.item_selected.connect(func(i: int): FNAudioGate.choose(key, String(variants[i])))
	return ob

## событие шахты отдельно: v "a" — C1, "" — прежние записи P0
func _duct_one(kind: String, v: String, db := -4.0) -> void:
	var id := String((FNAudioGate.DUCT_NEW if v == "a" else FNAudioGate.DUCT_OLD)[kind])
	for p in cam_pool:
		var a := p as AudioStreamPlayer
		if not a.playing:
			a.stream = FNSound.pick(id)
			a.volume_db = db + FNSound.trim(id)
			a.play()
			return

## заход целиком по плану игры (FNCues.duct_plan) за 8 с: вход, фразы, затишье, удар в решётку, присутствие, уход
var duct_run_id := 0
func _duct_run(v: String) -> void:
	duct_run_id += 1
	var me := duct_run_id
	var D: Dictionary = FNCues.DUCT
	var need := 8.0
	var evs: Array = [[0.0, "far", float(D["enter"]["db"])]]
	for ph in FNCues.duct_plan():
		for e in ph[2]:
			evs.append([float(ph[0]) * need + float(e[1]), String(e[0]), float(e[2])])
	evs.append([need, "arrive", float(D["arrive"]["db"])])
	var t := need
	for k in 3:
		t += randf_range(D["at_grate"]["gap"][0], D["at_grate"]["gap"][1])
		evs.append([t, "presence", float(D["at_grate"]["db"])])
	evs.append([t + 1.5, "hit", float(D["leave"]["db"][0])])
	evs.append([t + 2.4, "far", float(D["leave"]["db"][1])])
	var t0 := Time.get_ticks_msec()
	for e in evs:
		var wait := float(e[0]) - float(Time.get_ticks_msec() - t0) / 1000.0
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		if me != duct_run_id:
			return
		if String(e[1]) == "arrive":
			var a := cam_pool[5] as AudioStreamPlayer
			a.stream = FNSound.pick(String(D["arrive"]["id"]))
			a.volume_db = float(e[2]) - 14.0 + FNSound.trim(String(D["arrive"]["id"]))
			a.play()
		else:
			_duct_one(String(e[1]), v, float(e[2]) - 8.0)          # −8 дБ: в игре звук идёт из шахты, с расстояния

func _tablet(on: bool, v: String) -> void:
	cam_p.stream = FNSound.get_stream("cam") if v == "" else load(FNAudioGate.DIR + ("tablet_up.wav" if on else "tablet_down.wav"))
	cam_p.pitch_scale = 1.0 if v != "" else (0.8 if on else 0.6)
	cam_p.volume_db = -10.0 + (FNSound.trim("cam") if v == "" else FNAudioGate.CAM_DB)
	cam_p.play()

func _btn(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	return b

func _stop_all() -> void:
	crawl_on = false
	duct_run_id += 1
	crawl_p.stop()
	scream_p.stop()
	cam_p.stop()

func _play(key: String, v: String) -> void:
	match key:
		"balon":
			scream_p.stop()
			scream_p.stream = FNSound.scream_pick("balon")[0] if v == "" else load(FNAudioGate.DIR + "balon_%s.wav" % v)
			scream_p.volume_db = SCREAM_DB
			scream_p.play()
		"cctv":
			_cam(v)
		"madk1d":
			crawl_p.stop()
			crawl_v = v
			crawl_on = true

## как в игре: прежний звук — свободным проигрывателем из шести (щелчки ложатся друг на друга), вариант — одним
func _cam(v: String) -> void:
	if v == "":
		for p in cam_pool:
			var a := p as AudioStreamPlayer
			if not a.playing:
				a.stream = FNSound.get_stream("cam")
				a.volume_db = CAM_DB + FNSound.trim("cam")
				a.play()
				return
		return
	cam_p.stream = FNAudioGate._take("cam_" + v, FNAudioGate.CAM_TAKES, "wav")
	cam_p.pitch_scale = 1.0
	cam_p.volume_db = CAM_DB + FNAudioGate.CAM_DB
	cam_p.play()

func _series(v: String) -> void:
	for gap in SERIES:
		_cam(v)
		await get_tree().create_timer(float(gap)).timeout

func _process(_dt: float) -> void:
	if guard and not guard_busy and fn != null and fn.state == "night":
		for sd in ["l", "r"]:
			var at_door: bool = fn.st.enemies.values().any(func(e): return e.spot == "door_" + sd)
			if at_door != bool(fn.st.door[sd]):
				guard_busy = true
				_guard_key(KEY_A if sd == "l" else KEY_D)
				break
	if crawl_on and not crawl_p.playing:            # как в игре: кончился — играет снова (вариант — следующий дубль)
		crawl_p.stream = FNSound.get_stream("crawl") if crawl_v == "" else FNAudioGate._take("crawl_" + crawl_v, FNAudioGate.CRAWL_TAKES, "ogg")
		crawl_p.volume_db = CRAWL_DB
		crawl_p.play()
	if info.visible and capture == "":
		var sk := String(SCARE_KINDS[scare_k])
		info.text = "F5 БАЛОН: %s   F6 КАМЕРЫ: %s   F7 ШАХТА: %s   |   F10 скример: %s   F12: %s   F8 — вызвать   |   F9 — MADK1D по левой шахте (Z — заслонка)" % [
			FNAudioGate.NAMES[FNAudioGate.variant("balon")], FNAudioGate.NAMES[FNAudioGate.variant("cctv")], "C1" if FNAudioGate.variant("madk1d") != "" else "записи P0",
			sk.to_upper(), FNAudioGate.NAMES[FNAudioGate.variant("balon")] if sk == "balon" else ("NEW" if FNAudioGate.variant("scream_" + sk) != "" else "ORIGINAL")]

# ---------------- настоящая игра ----------------
func _game() -> void:
	if main_node != null:
		return
	_stop_all()
	panel.visible = false
	bg.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	main_node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main_node.name = "Main"
	get_tree().root.add_child(main_node)
	await get_tree().create_timer(0.6).timeout
	main_node.call("start_minigame", "five_nights")
	fn = main_node.get("minigame")
	for k in 3:
		await get_tree().process_frame
	_night()
	info.visible = true

## своя ночь без врагов: будка, фон и только то, что вызвано отсюда
func _night() -> void:
	var lv := {}
	for id in FNData.ORDER:
		lv[id] = 0
	madk_step = 0
	fn.start_night(FNData.NIGHTS.size(), lv)

func _input(e: InputEvent) -> void:
	if fn == null or capture != "" or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match (e as InputEventKey).keycode:
		KEY_F5:
			_cycle("balon")
		KEY_F6:
			_cycle("cctv")
		KEY_F7:
			_cycle("madk1d")
		KEY_F8:
			_scare()
		KEY_F9:
			_madk()
		KEY_F10:
			scare_k = (scare_k + 1) % SCARE_KINDS.size()
		KEY_F12:
			var sk := String(SCARE_KINDS[scare_k])
			_cycle("balon" if sk == "balon" else "scream_" + sk)

func _cycle(key: String) -> void:
	var vs: Array = ["", "a"] if key == "madk1d" or key.begins_with("scream_") else FNAudioGate.VARIANTS
	FNAudioGate.choose(key, String(vs[(vs.find(FNAudioGate.variant(key)) + 1) % vs.size()]))

## выбранный скример (scare_k) тем же путём, что в игре (FNScare.play → экран гибели), но без записи в статистику
func _scare() -> void:
	if fn.state != "night":
		return
	var eid := String(SCARE_KINDS[scare_k])
	if eid == "dark":                     # питание гаснет; нападение из темноты приходит по правилам игры
		fn.st.power = 0.0
		return
	var at := "vent_l" if eid == "madk1d" else "door_l"
	fn.state = "scare"
	fn.call_voice.stop()
	fn.air_tune.stop()
	fn.whisper.stop()
	fn.ui.show_dark(false)
	fn.ui.hints("")
	fn.ui.sub("")
	await fn.scare.play(eid, at, 0)
	fn.ui.hurt = 0.0
	fn._dead(eid, at)

## MADK1D идёт по левой шахте; дальше всё решают правила игры (у решётки стоит, ломится в закрытую заслонку, уходит)
func _madk() -> void:
	if fn.state != "night":
		return
	var m: FNEnemy = fn.st.enemies["madk1d"]
	if m.spot.begins_with("duct_") or m.spot.begins_with("vent_"):
		return
	m.level = maxi(m.level, 5)
	m.rest_until = 0.0
	fn.st.arrive_gate = 0.0
	m.go(fn.st, "duct_l")

# ---------------- запись сравнения ----------------
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## ждать условие не дольше sec секунд игры
func _until(cond: Callable, sec := 40.0) -> void:
	var left := sec
	while left > 0.0 and not cond.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
	if left <= 0.0:
		print("GATE | ожидание не дождалось")

func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame

func _guard_key(k: Key) -> void:
	await _wait(0.45)                     # человек закрывает не мгновенно
	await _key(k)
	await _wait(0.3)
	guard_busy = false

func _say(text: String) -> void:
	caption = text
	info.text = text
	info.add_theme_font_size_override("font_size", 22)
	info.visible = true
	print("GATE | ", text)

func _capture() -> void:
	await _game()
	var names := {"": "ORIGINAL", "a": "VARIANT A", "b": "VARIANT B"}
	match capture:
		"balon":
			fn.scare.force_hush = "dead"
			for v in FNAudioGate.VARIANTS:
				FNAudioGate.choose("balon", v, false)
				seed(67)
				if v != "":
					_night()
				_say("БАЛОН — %s" % names[v])
				await _wait(7.5)
				_scare()
				await _until(func(): return fn.state == "dead", 20.0)
				print("GATE | экран гибели, крик играет: ", fn.scream_p.playing, " позиция ", snappedf(fn.scream_p.get_playback_position(), 0.01))
				await _wait(4.5)
				print("GATE | через 4,5 с крик играет: ", fn.scream_p.playing)
			# рестарт во время крика: «ЕЩЁ РАЗ» через 0,3 с после гибели
			_night()
			await _wait(7.5)
			_scare()
			await _until(func(): return fn.state == "dead", 20.0)
			await _wait(0.3)
			var was: bool = fn.scream_p.playing
			_night()
			await get_tree().process_frame
			print("GATE | рестарт во время крика: до ", was, ", после ", fn.scream_p.playing)
			await _wait(1.0)
		"cctv":
			await _wait(6.0)
			for v in FNAudioGate.VARIANTS:
				FNAudioGate.choose("cctv", v, false)
				seed(67)
				_say("КАМЕРЫ — %s" % names[v])
				await _wait(0.8)
				await _key(KEY_SPACE)
				await _wait(1.4)
				for k in [KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]:
					await _key(k)
					await _wait(0.75)
				for k in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]:        # быстрый ввод
					await _key(k)
					await _wait(0.1)
				await _wait(1.0)
				print("GATE | после серии: пул занят ", fn.pool2.filter(func(p): return p.playing).size(), ", свой проигрыватель ", fn.gate_cam_p != null and fn.gate_cam_p.playing)
				await _key(KEY_1)
				await _wait(0.6)
				await _key(KEY_SPACE)
				await _wait(1.6)
		"madk1d":
			await _wait(4.0)
			for v in ["", "a"]:
				FNAudioGate.choose("madk1d", v, false)
				seed(67)
				_say("MADK1D — %s: идёт по шахте" % ("записи P0" if v == "" else "C1 событиями"))
				fn.cue_log.clear()
				_madk()
				var m: FNEnemy = fn.st.enemies["madk1d"]
				await _until(func(): return m.spot.begins_with("vent_"))
				_say("MADK1D — %s: у решётки" % ("записи P0" if v == "" else "C1 событиями"))
				m.linger = 1.0e9
				await _wait(7.0)
				var zk: Key = KEY_X if m.spot == "vent_t" else KEY_Z
				await _key(zk)
				_say("MADK1D — %s: заслонка закрыта" % ("записи P0" if v == "" else "C1 событиями"))
				await _until(func(): return not (m.spot.begins_with("vent_") or m.spot.begins_with("duct_")))
				await _wait(3.0)
				await _key(zk)
				print("GATE | заход: ", ",".join(PackedStringArray(fn.cue_log.filter(func(c): return c[3] == "duct").map(func(c): return "%s@%.1f(%s %+.0f)" % [c[7], c[0], c[4], c[6] + FNSound.trim(c[4])]))))
				m.level = 0
				await _wait(1.5)
		"night":
			# фрагмент обычной ночи с утверждёнными звуками: вторая ночь, игра идёт сама; камеры, заход MADK1D, скример БАЛОНА
			fn.start_night(1)
			fn.scare.force_hush = "dead"
			_say("НОЧЬ 2 — утверждённые звуки P1")
			await _wait(9.0)
			info.visible = false
			await _key(KEY_SPACE)
			await _wait(1.2)
			for k in [KEY_4, KEY_7, KEY_2]:
				await _key(k)
				await _wait(1.3)
			await _key(KEY_SPACE)
			guard = true
			await _until(func(): return fn.st.t >= float(fn.st.calm("madk1d")[1]) + 1.0 or fn.state != "night", 90.0)      # ночь идёт сама: до этой секунды MADK1D к решётке не выходит
			_madk()
			var mk: FNEnemy = fn.st.enemies["madk1d"]
			await _until(func(): return mk.spot.begins_with("vent_") or fn.state != "night")
			await _wait(4.0)
			var zk2: Key = KEY_X if mk.spot == "vent_t" else KEY_Z
			await _key(zk2)
			await _until(func(): return not (mk.spot.begins_with("vent_") or mk.spot.begins_with("duct_")) or fn.state != "night")
			await _wait(2.5)
			await _key(zk2)
			await _wait(3.0)
			await _key(KEY_SPACE)
			await _wait(1.0)
			for k in [KEY_5, KEY_1, KEY_3, KEY_6, KEY_1]:
				await _key(k)
				await _wait(0.5)
			await _key(KEY_SPACE)
			await _wait(4.0)
			guard = false
			if fn.state == "night":
				_scare()
			await _until(func(): return fn.state == "dead", 20.0)
			await _wait(4.0)
			fn.start_night(1)
			await get_tree().process_frame
			print("GATE | рестарт: крик ", fn.scream_p.playing, ", щелчок ", fn.gate_cam_p != null and fn.gate_cam_p.playing, ", планшет ", fn.gate_tab_p != null and fn.gate_tab_p.playing, ", пул3 ", fn.pool3.filter(func(p): return p.playing).size(), ", очередь ", fn.far_q.size())
			await _wait(5.0)
			fn.to_terminal()
			await _wait(0.3)
			print("GATE | в меню охраны: крик ", fn.scream_p.playing, ", пул3 ", fn.pool3.filter(func(p): return p.playing).size(), ", пул2 ", fn.pool2.filter(func(p): return p.playing).size(), ", очередь ", fn.far_q.size())
			await _wait(2.0)
	print("GATE | готово")
	get_tree().quit()
