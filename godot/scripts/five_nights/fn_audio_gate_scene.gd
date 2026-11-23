## AUDIO QUALITY GATE (P1) «5 НОЧЕЙ»: сцена прослушивания трёх звуков — ORIGINAL / A / B.
## Открыть scenes/five_nights/audio_gate.tscn в редакторе и нажать F6, либо:
##   Godot --path godot res://scenes/five_nights/audio_gate.tscn
## Кнопки играют звуки теми же шинами и с той же громкостью, что игра. «В ИГРЕ» — какой вариант услышит обычная
## игра (user://fn_audio_gate.json; ORIGINAL — как было). «НОЧЬ В БУДКЕ» запускает настоящую игру отсюда же: своя ночь
## без врагов, варианты переключаются на ходу — F5 БАЛОН, F6 камеры, F7 MADK1D; F8 — скример БАЛОНА сейчас;
## F9 — MADK1D: шахта → решётка → ушёл. Скример отсюда в статистику смертей не пишется.
## Запись для сравнения (кадры и звук самой игры, Movie Maker):
##   Godot --path godot --write-movie <файл.avi> --fixed-fps 30 res://scenes/five_nights/audio_gate.tscn -- --clock=30 --fn-gate-capture=balon|cctv|madk1d
extends Control

const ROWS := [
	{"key": "balon", "title": "SOUND A — СКРИМЕР БАЛОНА", "a": "A1 · Organic Distortion", "b": "A2 · Physical Impact"},
	{"key": "cctv", "title": "SOUND B — ПЕРЕКЛЮЧЕНИЕ КАМЕРЫ", "a": "B1 · Analog Relay", "b": "B2 · Signal Transition"},
	{"key": "madk1d", "title": "SOUND C — MADK1D В ШАХТЕ", "a": "C1 · Heavy Duct Movement", "b": "C2 · Unnatural Crawling"},
]
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
var caption := ""

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
	panel = CenterContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
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
		var ob := OptionButton.new()
		for v in FNAudioGate.VARIANTS:
			ob.add_item(String(FNAudioGate.NAMES[v]))
		ob.select(FNAudioGate.VARIANTS.find(FNAudioGate.variant(key)))
		ob.item_selected.connect(func(i: int): FNAudioGate.choose(key, String(FNAudioGate.VARIANTS[i])))
		h.add_child(ob)
	box.add_child(_btn("НОЧЬ В БУДКЕ — послушать в игре (F5 / F6 / F7 — вариант, F8 — скример, F9 — MADK1D)", _game))
	var note := Label.new()
	note.text = "Кнопки играют теми же шинами и с той же громкостью, что игра. «в игре» — что услышит обычная игра; ORIGINAL — как было.\nMADK1D: ORIGINAL — 1,6 с подряд без пауз (так его играет игра); A и B — дубли по 10–11 с, следующий — другой."
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

func _btn(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	return b

func _stop_all() -> void:
	crawl_on = false
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
	cam_p.volume_db = CAM_DB + FNAudioGate.CAM_DB
	cam_p.play()

func _series(v: String) -> void:
	for gap in SERIES:
		_cam(v)
		await get_tree().create_timer(float(gap)).timeout

func _process(_dt: float) -> void:
	if crawl_on and not crawl_p.playing:            # как в игре: кончился — играет снова (вариант — следующий дубль)
		crawl_p.stream = FNSound.get_stream("crawl") if crawl_v == "" else FNAudioGate._take("crawl_" + crawl_v, FNAudioGate.CRAWL_TAKES, "ogg")
		crawl_p.volume_db = CRAWL_DB
		crawl_p.play()
	if info.visible and capture == "":
		info.text = "AUDIO GATE   F5 БАЛОН: %s   F6 КАМЕРЫ: %s   F7 MADK1D: %s   |   F8 — скример БАЛОНА   F9 — MADK1D: шахта → решётка → ушёл" % [
			FNAudioGate.NAMES[FNAudioGate.variant("balon")], FNAudioGate.NAMES[FNAudioGate.variant("cctv")], FNAudioGate.NAMES[FNAudioGate.variant("madk1d")]]

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

func _cycle(key: String) -> void:
	var i := FNAudioGate.VARIANTS.find(FNAudioGate.variant(key))
	FNAudioGate.choose(key, String(FNAudioGate.VARIANTS[(i + 1) % FNAudioGate.VARIANTS.size()]))
	if key == "madk1d" and fn.crawl.playing:
		fn.crawl.stop()                           # следующий кадр игра сама запустит выбранный вариант

## скример БАЛОНА тем же путём, что в игре (FNScare.play → экран гибели), но без записи в статистику
func _scare() -> void:
	if fn.state != "night":
		return
	fn.state = "scare"
	fn.call_voice.stop()
	fn.air_tune.stop()
	fn.crawl.stop()
	fn.whisper.stop()
	fn.ui.show_dark(false)
	fn.ui.hints("")
	fn.ui.sub("")
	await fn.scare.play("balon", "door_l", 0)
	fn.ui.hurt = 0.0
	fn._dead("balon", "door_l")

## MADK1D: 0 — в левую шахту, 1 — к решётке (не входит), 2 — уходит
func _madk() -> void:
	if fn.state != "night":
		return
	var m: FNEnemy = fn.st.enemies["madk1d"]
	m.level = 1
	match madk_step:
		0:
			m.go(fn.st, "duct_l")
		1:
			m.go(fn.st, "vent_l")
			m.linger = 1.0e9
		_:
			m.go(fn.st, "vent", "retreat")
	m.move_t = 1.0e9
	madk_step = (madk_step + 1) % 3

# ---------------- запись сравнения ----------------
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame

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
				while fn.state != "dead":
					await get_tree().process_frame
				print("GATE | экран гибели, крик играет: ", fn.scream_p.playing, " позиция ", snappedf(fn.scream_p.get_playback_position(), 0.01))
				await _wait(4.5)
				print("GATE | через 4,5 с крик играет: ", fn.scream_p.playing)
			# рестарт во время крика: «ЕЩЁ РАЗ» через 0,3 с после гибели
			_night()
			await _wait(7.5)
			_scare()
			while fn.state != "dead":
				await get_tree().process_frame
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
			for v in FNAudioGate.VARIANTS:
				FNAudioGate.choose("madk1d", v, false)
				seed(67)
				madk_step = 0
				_say("MADK1D — %s: в шахте" % names[v])
				_madk()
				await _wait(7.0)
				_say("MADK1D — %s: у решётки" % names[v])
				_madk()
				await _wait(9.0)
				_say("MADK1D — %s: ушёл" % names[v])
				_madk()
				await _wait(2.5)
				print("GATE | ушёл: звук шахты играет ", fn.crawl.playing, ", дБ ", snappedf(fn.crawl.volume_db, 0.1))
	print("GATE | готово")
	get_tree().quit()
