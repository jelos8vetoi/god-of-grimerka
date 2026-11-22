## Режиссёр музыки: единственный код, который запускает, гасит и выравнивает проигрыватели фоновой музыки.
## Фиксированный набор проигрывателей (две деки по три стема, заглавный трек, отбивка, ролик, диегетический) создаётся
## один раз. audio.gd каждый кадр отдаёт «базовую ситуацию» (set_base), а сцены и диалоги вешают временные «наложения»
## (enter_dialogue, bark, enter_cinematic) — у каждого есть владелец, исчезнувший владелец снимает своё приглушение сам.
## Приглушение — самое глубокое из живых наложений, не сумма. Громкость шин не трогается (это дело audio.gd): режиссёр
## меняет только усиление своих проигрывателей, плавно и в линейной амплитуде.
class_name MusicDirector
extends Node

enum Pri { MENU, EXPLORE, COMBAT, BOSS, DIALOGUE, STORY, CINEMATIC }

const DIR := "res://assets/music/"
const TITLE_PATH := "res://assets/audio/music_dynasty.mp3"
const TITLE_DB := -6.0
const MUTE_DB := -60.0
## вид диалога → [глубина дБ, нарастание с, возврат с]
const KINDS := {"talk": [-6.0, 0.35, 0.9], "story": [-10.0, 0.5, 1.2], "silence": [-60.0, 0.8, 1.5]}
const HOLD := 0.6
const DEBOUNCE := 0.15
const MEMORY_SEC := 120.0
## переход → [затухание прежнего, нарастание нового, пауза перед новым]
const TRANS := {"cross": [1.6, 1.6, 0.0], "menu_in": [1.4, 1.2, 0.0], "menu_out": [2.5, 2.0, 0.0], "gap": [0.9, 1.2, 0.4],
	"boss_in": [0.7, 0.7, 0.0], "cine": [0.8, 1.2, 0.0]}

## кривая усиления 0…1: выше середины — equal-power (sin), ниже — линейно в дБ до −63 дБ; шаг не больше 2 / T дБ за кадр на 60 к/с
static func curve(p: float) -> float:
	if p >= 0.5:
		return sin(minf(p, 1.0) * PI * 0.5)
	if p <= 0.0:
		return 0.0
	return 0.7071 * pow(10.0, -(1.0 - 2.0 * p) * 3.0)

## одна дека: до трёх стемов одной длины, играют вместе
class Deck extends RefCounted:
	var players: Array[AudioStreamPlayer] = []
	var cue := ""
	var prog := 0.0
	var goal := 0.0
	var time := 1.0
	var delay := 0.0
	var lv: Array[float] = [-60.0, -60.0, -60.0]
	var live := false
	func gain() -> float:
		return MusicDirector.curve(prog)

var audio
var decks: Array[Deck] = []
var title: AudioStreamPlayer
var sting: AudioStreamPlayer
var cine: AudioStreamPlayer
var dieg: AudioStreamPlayer3D
var active := -1
var cue := ""                          # какой набор сейчас хозяин музыки ("title" — заглавный трек, "" — тишина)
var ctx := "menu"
var base := {"ctx": "menu", "cue": "title", "layers": [0.0, 0.0, 0.0], "pitch": 1.0, "gain_db": 0.0, "duck_db": 0.0}
var overlays := {}                     # id владельца → наложение
var barks: Array = []
var events: Array = []
var missing := {}
var memory := {}                       # набор → [позиция, когда]
var cache := {}
var duck_db := 0.0
var _att := 0.35
var _rel := 0.9
var pending := ""
var pending_t := 0.0
var title_prog := 0.0
var title_time := 1.2
var title_started := false
var cine_prog := 0.0
var cine_goal := 0.0
var cine_time := 0.4
var cine_owner := 0
var cine_ref: WeakRef
var via_k := 0.0
var via_cue := ""
var clock := 0.0
var silent := false
var _last_ctx := ""
var _dieg_db := 0.0
var _dieg_node: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in 2:
		var d := Deck.new()
		for i in 3:
			var p := AudioStreamPlayer.new()
			p.bus = "MusicBG"
			p.volume_db = -80.0
			add_child(p)
			d.players.append(p)
		decks.append(d)
	title = AudioStreamPlayer.new()
	title.bus = "MusicMenu"
	title.stream = load(TITLE_PATH)
	(title.stream as AudioStreamMP3).loop = true
	title.volume_db = -80.0
	add_child(title)
	sting = AudioStreamPlayer.new()
	sting.bus = "MusicBG"
	add_child(sting)
	cine = AudioStreamPlayer.new()
	cine.bus = "MusicCine"
	cine.volume_db = -80.0
	add_child(cine)
	dieg = AudioStreamPlayer3D.new()
	dieg.bus = "MusicDiegetic"
	dieg.unit_size = 5.0
	dieg.attenuation_filter_cutoff_hz = 4500.0
	dieg.max_db = 0.0
	dieg.volume_db = -80.0
	add_child(dieg)

# ---------- наборы ----------
func stems_of(nm: String) -> Array:
	if cache.has(nm):
		return cache[nm]
	var out: Array = []
	for part in (["p1", "p2", "p3"] if nm.begins_with("boss_") else ["base", "drive"]):
		var path: String = DIR + nm + "_" + part + ".wav"
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamWAV:
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD
				st.loop_end = int(st.get_length() * st.mix_rate)
			out.append(st)
	cache[nm] = out
	return out

func has_cue(nm: String) -> bool:
	return nm == "title" or not stems_of(nm).is_empty()

## want, если у него есть файлы; иначе fallback, если есть он; иначе "". Промах записывается один раз.
func resolve_cue(want: String, fallback := "") -> String:
	if want == "" or has_cue(want):
		return want
	var got := fallback if fallback != "" and has_cue(fallback) else ""
	if not missing.has(want):
		missing[want] = got
		_ev("missing", want, "", "заменён на «%s»" % got)
	return got

# ---------- журнал ----------
func _ev(ev: String, c := "", owner := "", reason := "", trans := "") -> void:
	var n := 0
	for d in decks:
		for p in d.players:
			n += 1 if p.playing else 0
	var e := {"t": snappedf(clock, 0.001), "ev": ev, "cue": c, "ctx": ctx, "owner": owner, "reason": reason, "transition": trans,
		"duck_db": snappedf(duck_db, 0.1), "gain_db": snappedf(float(base.get("gain_db", 0.0)), 0.1), "voice": _voice(), "players": n}
	events.append(e)
	if events.size() > 200:
		events.pop_front()
	if audio != null and audio.main != null and (audio.main.audiolog or audio.main.musiclog):
		print("MUSICDIR ", JSON.stringify(e))

func _voice() -> bool:
	for k in overlays:
		var o: Dictionary = overlays[k]
		if o["type"] in ["dialogue", "cinematic"]:
			return true
	for b in barks:
		if is_instance_valid(b) and (b as AudioStreamPlayer).playing:
			return true
	return false

func snapshot() -> Dictionary:
	var ds: Array = []
	for d in decks:
		ds.append({"cue": d.cue, "gain": snappedf(d.gain(), 0.001), "live": d.live})
	var ov: Array = []
	for k in overlays:
		var o: Dictionary = overlays[k]
		ov.append({"type": o["type"], "kind": o["kind"], "owner": o["name"], "leaving": o["leaving"]})
	var playing := 0
	for d in decks:
		for p in d.players:
			playing += 1 if p.playing else 0
	return {"cue": cue, "ctx": ctx, "decks": ds, "duck_db": duck_db, "overlays": ov, "playing": playing, "missing": missing,
		"title_prog": title_prog, "title_started": title_started}

func active_players() -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = []
	if active >= 0:
		for i in decks[active].players.size():
			if decks[active].players[i].stream != null:
				out.append(decks[active].players[i])
	return out

# ---------- наложения ----------
func _key(owner: Object) -> int:
	return owner.get_instance_id()

func _name(owner: Object) -> String:
	return str(owner.get("name")) if owner is Node else str(owner)

func enter_dialogue(owner: Object, kind := "talk") -> void:
	var k: Array = KINDS.get(kind, KINDS["talk"])
	var old = overlays.get(_key(owner))
	if old != null and old["type"] == "dialogue":
		if old["kind"] == kind:
			if old["leaving"]:
				old["leaving"] = false
			return
		old["kind"] = kind
		old["db"] = float(k[0])
		old["att"] = float(k[1])
		old["rel"] = float(k[2])
		old["leaving"] = false
		return
	overlays[_key(owner)] = {"type": "dialogue", "ref": weakref(owner), "name": _name(owner), "kind": kind, "db": float(k[0]), "att": float(k[1]), "rel": float(k[2]), "leaving": false, "until": 0.0}
	_ev("overlay_enter", cue, _name(owner), kind)

func leave_dialogue(owner: Object) -> void:
	var o = overlays.get(_key(owner))
	if o != null and o["type"] == "dialogue" and not o["leaving"]:
		o["leaving"] = true
		o["until"] = clock + HOLD
		_ev("overlay_leave", cue, o["name"], "удержание %.1f с" % HOLD)

func bark(p: AudioStreamPlayer) -> void:
	if p != null and not barks.has(p):
		barks.append(p)

func enter_cinematic(owner: Object, opts := {}) -> void:
	if overlays.has(_key(owner)) and overlays[_key(owner)]["type"] == "cinematic":
		return
	var mode := String(opts.get("mode", "silence"))
	overlays[_key(owner)] = {"type": "cinematic", "ref": weakref(owner), "name": _name(owner), "kind": mode, "db": -12.0 if mode == "duck" else 0.0, "att": 0.4, "rel": 1.2, "leaving": false, "until": 0.0}
	_ev("overlay_enter", cue, _name(owner), "cinematic " + mode)
	var c := String(opts.get("cue", ""))
	if c != "":
		var path := c if c.begins_with("res://") else DIR + c + ".wav"
		if ResourceLoader.exists(path):
			cine.stream = load(path)
			cine_owner = _key(owner)
			cine_ref = weakref(owner)
			cine_goal = 1.0
			cine_time = 0.3
			cine.play()

func leave_cinematic(owner: Object) -> void:
	if owner == null:
		return
	var k := _key(owner)
	if overlays.has(k):
		overlays.erase(k)
		_ev("overlay_leave", cue, _name(owner), "cinematic")
	if cine_owner == k:
		cine_goal = 0.0
		cine_time = 0.4

# ---------- вывод базовой ситуации ----------
func set_base(sit: Dictionary) -> void:
	base = sit
	var c := String(sit.get("ctx", "menu"))
	if c != ctx:
		ctx = c
		_ev("ctx", String(sit.get("cue", "")), "", c)

func stinger(file: String) -> void:
	var path := DIR + file + ".wav"
	if ResourceLoader.exists(path) and not silent:
		sting.stream = load(path)
		sting.volume_db = 0.0
		sting.play()
		_ev("stinger", file)

func stop_stinger() -> void:
	sting.stop()

func set_diegetic(stream: AudioStream, node: Node3D, db := 0.0) -> void:
	dieg.stream = stream
	_dieg_node = node
	_dieg_db = db
	if stream != null and not silent:
		dieg.play()

func stop_diegetic() -> void:
	dieg.stop()
	_dieg_node = null

func _pick(new_cue: String) -> String:
	var t := String(base.get("transition", ""))
	if t != "":
		return t
	if new_cue == "title":
		return "menu_in"
	if cue == "title":
		return "menu_out"
	if new_cue.begins_with("boss_"):
		return "boss_in"
	return "cross"

func _idle_deck() -> int:
	var best := -1
	for i in decks.size():
		if i == active:
			continue
		if best < 0 or decks[i].gain() < decks[best].gain():
			best = i
	return best

func _swap(new_cue: String) -> bool:
	var idle := _idle_deck()
	var dk: Deck = decks[idle]
	if dk.gain() > 0.02:
		dk.goal = 0.0
		dk.time = 1.0
		return false
	var tr := _pick(new_cue)
	var tt: Array = TRANS[tr]
	if active >= 0:
		decks[active].goal = 0.0
		decks[active].time = float(tt[0])
	if cue == "title" or new_cue == "title":
		title_time = float(tt[0]) if new_cue != "title" else float(tt[1])
	_release(dk)
	var dcue := "" if new_cue == "title" else new_cue
	if dcue != "":
		var stems := stems_of(dcue)
		var from := 0.0
		if memory.has(dcue) and clock - float((memory[dcue] as Array)[1]) <= MEMORY_SEC:
			from = float((memory[dcue] as Array)[0])
		dk.cue = dcue
		dk.live = true
		dk.prog = 0.0
		dk.goal = 1.0
		dk.time = float(tt[1])
		dk.delay = float(tt[2])
		dk.lv = [MUTE_DB, MUTE_DB, MUTE_DB]
		for i in dk.players.size():
			var p := dk.players[i]
			if i < stems.size():
				p.stream = stems[i]
				p.volume_db = -80.0
				p.pitch_scale = float(base.get("pitch", 1.0))
				if not silent:
					p.play(fmod(from, maxf(0.1, (stems[i] as AudioStream).get_length())))
			else:
				p.stream = null
		active = idle
	else:
		active = -1
	cue = new_cue
	if new_cue == "title":
		title_prog = title_prog
	if new_cue.begins_with("boss_") and tr == "boss_in":
		pass
	_ev("cue", new_cue, "", "", tr)
	return true

func _release(dk: Deck) -> void:
	for p in dk.players:
		p.stop()
	dk.live = false
	dk.cue = ""
	dk.prog = 0.0
	dk.goal = 0.0

# ---------- каждый кадр ----------
func _cinematic_silence() -> bool:
	for k in overlays:
		var o: Dictionary = overlays[k]
		if o["type"] == "cinematic" and o["kind"] == "silence":
			return true
	return false

func _duck_goal() -> float:
	var goal := 0.0
	var deep_att := 0.35
	for k in overlays.keys():
		var o: Dictionary = overlays[k]
		var owner = (o["ref"] as WeakRef).get_ref()
		if owner == null or not is_instance_valid(owner):
			_rel = float(o["rel"])
			overlays.erase(k)
			_ev("overlay_expire", cue, String(o["name"]), String(o["kind"]))
			continue
		if o["leaving"] and clock >= float(o["until"]):
			_rel = float(o["rel"])
			overlays.erase(k)
			_ev("overlay_end", cue, String(o["name"]), String(o["kind"]))
			continue
		if o["type"] == "cinematic" and o["kind"] != "duck":
			continue
		if float(o["db"]) < goal:
			goal = float(o["db"])
			deep_att = float(o["att"])
	for b in barks.duplicate():
		if not is_instance_valid(b):
			barks.erase(b)
		elif (b as AudioStreamPlayer).playing and goal > -3.0:
			goal = -3.0
			deep_att = 0.12
			_rel = 0.5
	var polled := float(base.get("duck_db", 0.0))
	if polled < goal:
		goal = polled
		deep_att = 0.35
	if sting.playing and goal > -7.0:
		goal = -7.0
	_att = deep_att
	return goal

func tick(dt: float) -> void:
	clock += dt
	silent = String(base.get("ctx", "")) == "quiet"
	var want_cue := String(base.get("cue", ""))
	if _cinematic_silence():
		want_cue = ""
	if silent:
		want_cue = ""
	# смена набора с отложенным запуском
	if want_cue != cue:
		var exempt := ctx == "boss" or _cinematic_silence() or silent
		if pending != want_cue:
			pending = want_cue
			pending_t = 0.0
		pending_t += dt
		if exempt or pending_t >= DEBOUNCE:
			if _swap(want_cue):
				pending = ""
	else:
		if pending != "":
			_ev("debounce_drop", pending, "", "вернулись к «%s» раньше %.2f с" % [cue, DEBOUNCE])
		pending = ""
	# наложения → одно приглушение
	var goal := _duck_goal()
	var span := maxf(absf(goal - duck_db), 6.0)
	duck_db = move_toward(duck_db, goal, span / (_att if goal < duck_db else _rel) * dt)
	# деки
	var layers: Array = base.get("layers", [])
	var gdb := float(base.get("gain_db", 0.0))
	for i in decks.size():
		var d: Deck = decks[i]
		if not d.live:
			continue
		if d.delay > 0.0:
			d.delay -= dt
		else:
			d.prog = move_toward(d.prog, d.goal, dt / maxf(d.time, 0.01))
		for j in d.players.size():
			if d.players[j].stream == null:
				continue
			if i == active:
				var target := linear_to_db(maxf(0.001, float(layers[j]) if j < layers.size() else 0.0))
				d.lv[j] = lerpf(d.lv[j], target, 1.0 - exp(-(2.5 if target > d.lv[j] else 1.2) * dt))
				d.players[j].pitch_scale = float(base.get("pitch", 1.0))
			d.players[j].volume_db = maxf(d.lv[j] + linear_to_db(maxf(d.gain(), 0.0001)) + duck_db + gdb, -80.0)
		if d.goal == 0.0 and d.prog <= 0.0 and i != active:
			memory[d.cue] = [d.players[0].get_playback_position() if d.players[0].playing else 0.0, clock]
			_release(d)
			_ev("deck_stop", d.cue)
	# заглавный трек
	var title_goal := 1.0 if cue == "title" and not silent else 0.0
	title_prog = move_toward(title_prog, title_goal, dt / maxf(title_time, 0.01))
	if title_goal > 0.0 and not title_started and not silent:
		title.play(0.0)
		title_started = true
	if title_started:
		if title_prog > 0.0 and title.stream_paused:
			title.stream_paused = false
		elif title_prog <= 0.0 and title_goal == 0.0 and not title.stream_paused:
			title.stream_paused = true
		title.volume_db = maxf(TITLE_DB + float(base.get("gain_db", 0.0)) + linear_to_db(maxf(curve(title_prog), 0.0001)) + duck_db, -80.0)
	# диегетический выход: тот же набор (первый стем) из точки сцены, перекрёстно с декой за 1,2 с
	var via = base.get("via")
	var via_ok: bool = via != null and is_instance_valid(via) and active >= 0 and decks[active].live and not silent
	via_k = move_toward(via_k, 1.0 if via_ok else 0.0, dt / 1.2)
	if via_ok:
		if not dieg.playing or via_cue != decks[active].cue:
			dieg.stream = decks[active].players[0].stream
			dieg.play(decks[active].players[0].get_playback_position() if decks[active].players[0].playing else 0.0)
			via_cue = decks[active].cue
			_ev("via_start", via_cue, str((via as Node).name))
		dieg.global_position = (via as Node3D).global_position
	if via_k > 0.0 and active >= 0 and decks[active].live:
		var d2: Deck = decks[active]
		dieg.volume_db = maxf(d2.lv[0] + linear_to_db(maxf(d2.gain() * curve(via_k), 0.0001)) + duck_db + gdb, -80.0)
		for j in d2.players.size():
			if d2.players[j].stream != null:
				d2.players[j].volume_db = maxf(d2.lv[j] + linear_to_db(maxf(d2.gain() * curve(1.0 - via_k), 0.0001)) + duck_db + gdb, -80.0)
	elif via_k <= 0.0 and dieg.playing and _dieg_node == null:
		dieg.stop()
		via_cue = ""
	# ролик
	if cine_owner != 0 and cine_goal > 0.0 and (cine_ref == null or cine_ref.get_ref() == null):
		cine_goal = 0.0
		cine_time = 0.4
		_ev("cine_expire", "", "", "владелец ролика удалён")
	cine_prog = move_toward(cine_prog, cine_goal, dt / maxf(cine_time, 0.01))
	cine.volume_db = maxf(linear_to_db(maxf(curve(cine_prog), 0.0001)), -80.0)
	if cine_goal == 0.0 and cine_prog <= 0.0 and cine.playing:
		cine.stop()
	# диегетический
	if _dieg_node != null and is_instance_valid(_dieg_node):
		dieg.global_position = _dieg_node.global_position
		dieg.volume_db = _dieg_db
