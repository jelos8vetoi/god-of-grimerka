## Живой фон «5 НОЧЕЙ»: записи CC0 (assets/audio/fn/amb) в точках будки и редкие звуки здания (assets/audio/fn/sfx).
## Слои дышат (дрейф громкости, порывы сквозняка, провалы лампы вместе со светом), монитор «глушит» комнату через шину
## Room, угроза у двери затихает фон и запрещает случайные звуки, отключение питания останавливает электрику и
## раскручивает вентиляторы вниз. Уровни и высоты считаются всегда (проверки читают числа), проигрывание — только когда
## звук включён (FiveNightsRoot._snd_ok). Громкость всех слоёв и звуков — один MASTER_DB.
class_name FNAmbience
extends Node

const AMB_DIR := "res://assets/audio/fn/amb/"
const MASTER_DB := 0.5
const MUTE := -60.0
const OUT_RUMBLE_A := -3.0           # при отключении гул здания тише на столько дБ
## имя, точка ("" — без места, "b:" — AudioPoints будки, "c:" — AudioPoints пульта), громкость
const LAYERS := [
	["rumble_a", "", -11.0], ["rumble_b", "", -15.0], ["far_bed", "", -13.0],
	["vent", "b:VentUnit", -6.0], ["draft", "b:Draft", -8.0], ["vent_air", "b:Hatch", -16.0], ["lamp_hum", "b:Lamp", -15.0],
	["crt_whine", "c:Crt", -24.0], ["panel_hum", "b:Panel", -15.0], ["deskfan", "c:Fan", -10.0], ["tablet_noise", "", MUTE],
]
const ELECTRIC := ["lamp_hum", "crt_whine", "panel_hum", "tablet_noise"]
## id (файлы sfx/<id>_N), места (Vector3 или "@Точка"), дБ, с какой ночи, вес, можно ли при отключении
const EVENTS := [
	{"id": "creak", "pos": [Vector3(-3.75, 1.4, -9.5), Vector3(3.75, 1.4, -9.5), Vector3(0.5, 4.5, -3)], "db": -1.1, "night": 0, "w": 3.0, "out": true},
	{"id": "clang", "pos": [Vector3(-15, 1, -7), Vector3(15, 1, -9), Vector3(0, 1, -18)], "db": 7.4, "night": 0, "w": 2.0, "out": true},
	{"id": "rattle", "pos": [Vector3(-1.6, 0.6, -8), Vector3(0.4, 3.8, -6)], "db": 0.4, "night": 0, "w": 2.0, "out": true},
	{"id": "relay", "pos": ["@Panel"], "db": -6.4, "night": 0, "w": 2.0, "out": false},
	{"id": "zap", "pos": ["@Panel", "@Lamp"], "db": 0.4, "night": 0, "w": 1.0, "out": false},
	{"id": "knock", "pos": [Vector3(-15, 1, -7), Vector3(15, 1, -9), Vector3(0, 1.5, 10)], "db": 13.4, "night": 1, "w": 2.0, "out": true},
	{"id": "thud", "pos": [Vector3(0.5, 5, -3), Vector3(0, 1.5, 10)], "db": 0.1, "night": 1, "w": 2.0, "out": true},
	{"id": "grind", "pos": [Vector3(-15, 1, -7), Vector3(15, 1, -9)], "db": 2.1, "night": 1, "w": 1.0, "out": true},
	{"id": "groan", "pos": [Vector3(0, 1, -18), Vector3(0.5, 4.5, -3)], "db": 0.4, "night": 2, "w": 2.0, "out": true},
	{"id": "drag", "pos": [Vector3(-15, 1, -7), Vector3(15, 1, -9), Vector3(0.5, 5, -3)], "db": 1.3, "night": 2, "w": 1.0, "out": true},
]

var root: FiveNightsRoot
var layers := {}                  # имя → {p: проигрыватель, base: дБ, db: текущая громкость слоя без MASTER_DB}
var ev_players: Array = []
var points := {}                  # имя точки → Vector3
var room_cutoff := 20500.0
var room_gain := 0.0
var duck_k := 0.0
var hold_t := 0.0
var t := 0.0
var last_event := ""
var event_t := 30.0
var ev_i := 0
var phase := {}                   # имя → случайные фазы дрейфа
var gust := 0.25                  # огибающая порывов сквозняка (линейная)
var gust_phase := "idle"
var gust_t := 20.0
var fan_spin := 1.0
var vent_spin := 1.0
var fan_dead := false
var vent_dead := false
var stall_t := 0.0
var stall_next := 60.0
var stall_k := 1.0
var was_out := false
var cur_st: FNNight
var breath_phase := "idle"        # задержанное дыхание: idle / fade / hold / recover
var breath_t := 0.0               # сколько секунд идёт текущая фаза
var breath_next := 120.0          # через сколько секунд можно начать следующую
var breath_len := 6.0
var breath_k := 0.0               # 0..1: насколько провалились вентиляция и вентилятор
var breath_done := false
var breath_at := 0.5
var since_event := 99.0
var later: Array = []             # [секунд до, id, точка, дБ]

func build(r: FiveNightsRoot) -> void:
	root = r
	var office: Node = r.office
	for n in ["VentUnit", "Draft", "Hatch", "Lamp", "Panel"]:
		points[n] = (office.get_node("AudioPoints/" + n) as Node3D).global_position
	for n in ["Crt", "Fan"]:
		points[n] = (office.get_node("Console/AudioPoints/" + n) as Node3D).global_position
	var bus := "Room" if AudioServer.get_bus_index("Room") >= 0 else "Ambient"
	for l in LAYERS:
		var name: String = l[0]
		var s := load(AMB_DIR + name + ".ogg") as AudioStreamOggVorbis
		s.loop = true
		var place: String = l[1]
		var p: Node
		if place == "":
			var p2 := AudioStreamPlayer.new()
			p2.stream = s
			p2.bus = "Ambient" if name == "tablet_noise" else bus
			p = p2
		else:
			var p3 := AudioStreamPlayer3D.new()
			p3.stream = s
			p3.bus = bus
			p3.unit_size = 3.0
			p3.max_db = 0.0
			p = p3
		add_child(p)
		if p is AudioStreamPlayer3D:
			(p as AudioStreamPlayer3D).global_position = points[place.substr(2)]
		layers[name] = {"p": p, "base": float(l[2]), "db": float(l[2])}
		phase[name] = [randf() * TAU, randf() * TAU]
	for k in 4:
		var e := AudioStreamPlayer3D.new()
		e.bus = bus
		e.unit_size = 10.0
		e.max_db = 12.0
		e.attenuation_filter_cutoff_hz = 3500.0
		e.attenuation_filter_db = -10.0
		add_child(e)
		ev_players.append(e)
	stall_next = randf_range(40.0, 90.0)
	r.office.lamp_dip.connect(_on_lamp_dip)

func _exit_tree() -> void:
	if root != null and root.main != null and root.main.audio != null:
		root.main.audio.room(20500.0, 0.0)

## текущая громкость слоя, дБ (с MASTER_DB)
func level(name: String) -> float:
	var p: Node = layers[name]["p"]
	return (p as Node).get("volume_db")

func pitch(name: String) -> float:
	return float((layers[name]["p"] as Node).get("pitch_scale"))

func duck(on: bool) -> void:
	duck_k = 1.0 if on else 0.0

func hold(sec: float) -> void:
	hold_t = maxf(hold_t, sec)

## угроза рядом: кто-то у двери или шахты, MADK1D в воздуховоде, или недавно было событие
func events_blocked(st: FNNight) -> bool:
	if hold_t > 0.0:
		return true
	if st == null:
		return false
	for id in st.enemies:
		var e: FNEnemy = st.enemies[id]
		if e.level > 0 and (e._at_door() or (id == "madk1d" and e.spot.begins_with("duct_"))):
			return true
	return false

func next_gap(n: int) -> float:
	return randf_range(0.55, 1.7) * (50.0 - 4.0 * float(mini(n, 5)))

func pick_event(n: int, outage: bool) -> String:
	var pool: Array = []
	var total := 0.0
	for e in EVENTS:
		if int(e["night"]) > n or (outage and not bool(e["out"])) or String(e["id"]) == last_event:
			continue
		pool.append(e)
		total += float(e["w"])
	if pool.is_empty():
		return ""
	var r := randf() * total
	for e in pool:
		r -= float(e["w"])
		if r <= 0.0:
			last_event = String(e["id"])
			return last_event
	last_event = String((pool.back() as Dictionary)["id"])
	return last_event

func play_event(id: String, at_i := -1) -> bool:
	since_event = 0.0
	for e in EVENTS:
		if String(e["id"]) != id:
			continue
		var spots: Array = e["pos"]
		var at = spots[(randi() if at_i < 0 else at_i) % spots.size()]
		var pos: Vector3 = points[String(at).substr(1)] if at is String else at
		var p: AudioStreamPlayer3D = null
		for k in ev_players.size():
			var c := ev_players[(ev_i + k) % ev_players.size()] as AudioStreamPlayer3D
			if not c.playing:
				p = c
				ev_i = (ev_i + k + 1) % ev_players.size()
				break
		if p == null:
			return false
		p.stream = FNSound.pick(id)
		p.global_position = pos
		p.volume_db = float(e["db"]) + MASTER_DB
		p.pitch_scale = randf_range(0.94, 1.06)
		if root._snd_ok():
			p.play()
		return true
	return false

func stop_events() -> void:
	for p in ev_players:
		(p as AudioStreamPlayer3D).stop()
	later.clear()

func set_paused(on: bool) -> void:
	for k in layers:
		((layers[k]["p"]) as Node).set("stream_paused", on)
	for p in ev_players:
		(p as AudioStreamPlayer3D).stream_paused = on

func _on_lamp_dip() -> void:
	if root.state != "night" or root.st == null or root.st.power_out or root.paused or root.scare.busy:
		return
	if randf() < 0.06 + 0.05 * float(mini(root.night, 5)):
		root.sfx3("zap", points["Lamp"], -18.0 + MASTER_DB, randf_range(0.94, 1.06))

func _drift(name: String, a: float, b: float) -> float:
	var ph: Array = phase[name]
	return 0.75 * sin(TAU * t / a + float(ph[0])) + 0.75 * sin(TAU * t / b + float(ph[1]))

func _new_night(st: FNNight) -> void:
	cur_st = st
	was_out = st.power_out
	event_t = next_gap(root.night)
	gust = 0.25
	gust_phase = "idle"
	gust_t = randf_range(18.0, 50.0)
	fan_spin = 1.0
	vent_spin = 1.0
	fan_dead = false
	vent_dead = false
	stall_t = 0.0
	stall_next = randf_range(40.0, 90.0)
	last_event = ""
	later.clear()

func _gust_step(dt: float) -> void:
	gust_t -= dt
	match gust_phase:
		"idle":
			gust = 0.25
			if gust_t <= 0.0:
				gust_phase = "up"
				gust_t = randf_range(2.0, 4.0)
		"up":
			gust = lerpf(gust, 1.0, clampf(dt / maxf(gust_t, dt), 0.0, 1.0))
			if gust_t <= 0.0:
				gust_phase = "hold"
				gust_t = randf_range(2.0, 6.0)
		"hold":
			gust = 1.0
			if gust_t <= 0.0:
				gust_phase = "down"
				gust_t = randf_range(3.0, 6.0)
		"down":
			gust = lerpf(gust, 0.25, clampf(dt / maxf(gust_t, dt), 0.0, 1.0))
			if gust_t <= 0.0:
				gust_phase = "idle"
				gust = 0.25
				gust_t = randf_range(18.0, 50.0)

## задержанное дыхание: здание на мгновение стихает, один далёкий звук, потом всё возвращается; только в спокойной ночи
func start_breath() -> void:
	breath_phase = "fade"
	breath_t = 0.0
	breath_len = randf_range(5.0, 8.0)
	breath_at = randf_range(0.4, 0.7)
	breath_done = false
	breath_next = randf_range(200.0, 330.0)

func _breath_step(st: FNNight, dt: float, live: bool, out: bool) -> void:
	if not live:
		return
	var calm: bool = root.tension == null or root.tension.state in ["CALM", "UNEASY"]
	if breath_phase == "idle":
		breath_next -= dt
		if breath_next <= 0.0 and calm and not out and not events_blocked(st) and not root.scare.busy and not root.paused and root.hush_mode == "" and st.t >= 90.0 and since_event >= 25.0:
			start_breath()
		return
	breath_t += dt
	if (out or not calm) and breath_phase in ["fade", "hold"]:
		breath_phase = "recover"
		breath_t = (1.0 - breath_k) * 4.0
	match breath_phase:
		"fade":
			breath_k = clampf(breath_t / 2.5, 0.0, 1.0)
			if breath_t >= 2.5:
				breath_phase = "hold"
				breath_t = 0.0
		"hold":
			breath_k = 1.0
			if not breath_done and breath_t >= breath_len * breath_at:
				breath_done = true
				if randi() % 2 == 0:
					play_event("clang", randi() % 2)
				else:
					play_event("groan", 0)
			if breath_t >= breath_len:
				breath_phase = "recover"
				breath_t = 0.0
		"recover":
			breath_k = clampf(1.0 - breath_t / 4.0, 0.0, 1.0)
			if breath_t >= 4.0:
				breath_phase = "idle"
				breath_k = 0.0

func tick(st: FNNight, state: String, dt: float) -> void:
	t += dt
	duck_k = maxf(0.0, duck_k - dt * 0.6)
	hold_t = maxf(0.0, hold_t - dt)
	var live := state in ["night", "scare"] and st != null
	var menu := state == "menu"
	if live and st != cur_st:
		_new_night(st)
		breath_phase = "idle"
		breath_k = 0.0
		breath_next = randf_range(100.0, 140.0)
		since_event = 0.0
	var n := mini(root.night, 5)
	var out := live and st.power_out
	var mon := live and st.monitor and not out
	var warn := live and st.brown_warn > 0.0 and not out
	var brown := live and st.brown_t > 0.0 and not out
	var threat := live and events_blocked(st)
	since_event += dt
	var lvl: float = root.tension.level if root.tension != null else 0.0
	if gust_phase == "idle":
		gust_t -= dt * (1.0 / (1.0 - 0.35 * lvl) - 1.0)      # чем ближе опасность, тем чаще порывы
	_gust_step(dt)
	# цели слоёв, дБ
	var g := {}
	for k in layers:
		g[k] = float(layers[k]["base"])
	if menu:
		for k in g:
			g[k] = MUTE
		g["rumble_a"] = float(layers["rumble_a"]["base"])
		g["far_bed"] = float(layers["far_bed"]["base"])
		g["vent"] = float(layers["vent"]["base"]) - 6.0
	elif live:
		g["rumble_a"] += 0.5 * float(n) + _drift("rumble_a", 37.0, 53.0)
		g["rumble_b"] += _drift("rumble_b", 41.0, 59.0)
		g["draft"] += linear_to_db(gust)
		g["vent"] -= 0.8 * float(n)
		var office: FNOffice = root.office
		g["lamp_hum"] += linear_to_db(clampf(office.lamp_k, 0.0, 1.5))
		if mon:
			g["tablet_noise"] = -22.0
			g["crt_whine"] += 3.0
		g["rumble_a"] += 2.0 * lvl
		g["far_bed"] -= 3.0 * lvl
		g["vent"] -= 2.5 * lvl
		if threat:
			g["vent"] -= 2.0
			g["far_bed"] -= 3.0
			g["rumble_a"] += 1.5
		if warn:
			g["lamp_hum"] += 6.0 + 3.0 * sin(TAU * 8.0 * t)
		if brown:
			for k in ELECTRIC:
				g[k] = float(g[k]) - 12.0
		if out:
			for k in ELECTRIC:
				g[k] = MUTE
			g["rumble_a"] += OUT_RUMBLE_A
			g["rumble_b"] = MUTE
			g["draft"] += 1.5
			g["vent_air"] -= 3.0
		for k in g:
			if float(g[k]) > MUTE:
				g[k] = maxf(MUTE, float(g[k]) - 30.0 * duck_k)
	else:
		for k in g:
			g[k] = MUTE
	_breath_step(st, dt, live, out)
	if breath_k > 0.0:
		for k in ["vent", "vent_air", "deskfan"]:
			if float(g[k]) > MUTE:
				g[k] = maxf(MUTE, float(g[k]) - 9.0 * breath_k)
	# краевые события питания
	if live and out != was_out:
		var panel: Vector3 = points["Panel"]
		if out:
			fan_dead = true
			vent_dead = true
			root.sfx3("breaker", panel, -6.0 + MASTER_DB)
		else:
			root.sfx3("relay", panel, -10.0 + MASTER_DB)
			later = [[0.0, "lamp_flick", points["Lamp"], -12.0], [0.15, "lamp_flick", points["Lamp"], -12.0]]
		was_out = out
	for i in range(later.size() - 1, -1, -1):
		later[i][0] = float(later[i][0]) - dt
		if float(later[i][0]) <= 0.0:
			root.sfx3(String(later[i][1]), later[i][2], float(later[i][3]) + MASTER_DB)
			later.remove_at(i)
	# вентилятор и вентиляция раскручиваются отдельно
	var fan_goal := 1.0
	var fan_rate := 0.26
	if out:
		fan_goal = 0.35
		fan_rate = 0.13
	elif brown:
		fan_goal = 0.8
	if fan_spin > fan_goal and not out:
		fan_rate = 0.5
	fan_spin = move_toward(fan_spin, fan_goal, fan_rate * dt)
	if fan_dead and fan_spin >= 0.999 and not out:
		fan_dead = false
	vent_spin = move_toward(vent_spin, 0.0 if out else 1.0, (1.0 / 9.0 if out else 0.25) * dt)
	if vent_dead and vent_spin >= 0.999 and not out:
		vent_dead = false
	stall_next -= dt
	if n >= 3 and live and stall_t <= 0.0 and stall_next <= 0.0:
		stall_t = randf_range(2.0, 4.0)
		stall_next = randf_range(40.0, 90.0)
	stall_t = maxf(0.0, stall_t - dt)
	stall_k = move_toward(stall_k, 0.93 if stall_t > 0.0 else 1.0, 0.1 * dt)
	if float(g["deskfan"]) > MUTE and fan_dead:
		g["deskfan"] = lerpf(MUTE, float(g["deskfan"]), clampf((fan_spin - 0.35) / 0.65, 0.0, 1.0))
	if float(g["vent"]) > MUTE and vent_dead:
		g["vent"] = lerpf(MUTE, float(g["vent"]), vent_spin)
	(layers["deskfan"]["p"] as Node).set("pitch_scale", maxf(0.05, fan_spin))
	(layers["vent"]["p"] as Node).set("pitch_scale", maxf(0.05, (0.6 + 0.4 * vent_spin) * (1.0 + 0.008 * sin(TAU * t / 9.0 + float(phase["vent"][0]))) * stall_k))
	# сглаживание и вывод
	var snd := root._snd_ok()
	var on := snd and (live or menu)
	for k in layers:
		var d: Dictionary = layers[k]
		var goal := float(g[k])
		var cur := float(d["db"])
		var rate := 12.0
		if k in ["deskfan", "vent"] and live:
			rate = 1000.0
		elif k in ELECTRIC:
			rate = 250.0 if goal < cur else (130.0 if k == "tablet_noise" else 72.0)
			if k == "tablet_noise" and goal < cur:
				rate = 76.0
		elif goal <= MUTE:
			rate = 40.0
		cur = move_toward(cur, goal, rate * dt)
		d["db"] = cur
		var p: Node = d["p"]
		p.set("volume_db", maxf(cur + MASTER_DB, -80.0))
		if on and not (p.get("playing") as bool):
			p.call("play", randf() * (p.get("stream") as AudioStream).get_length())
		elif not on and snd and (p.get("playing") as bool) and cur <= MUTE + 0.5:
			p.call("stop")
	# комната: монитор глушит верх
	var cut_want := 1600.0 if mon else 20500.0
	var gain_want := -5.0 if mon else 0.0
	var oct := log(room_cutoff) / log(2.0)
	oct = move_toward(oct, log(cut_want) / log(2.0), (12.3 if mon else 7.4) * dt)
	room_cutoff = pow(2.0, oct)
	room_gain = move_toward(room_gain, gain_want, (16.7 if mon else 10.0) * dt)
	if root.main != null and root.main.audio != null:
		root.main.audio.room(room_cutoff, room_gain)
	# случайные звуки здания
	if live:
		var blocked := breath_phase != "idle" or threat or root.intro_t > 0.0 or root.scare.busy or root.paused or root.hush_mode != "" or st.t < 20.0
		if not blocked:
			event_t -= dt
			if event_t <= 0.0:
				var id := pick_event(root.night, out)
				if id != "":
					play_event(id)
				event_t = next_gap(root.night) * (0.8 if out else 1.0) * (1.0 + 0.6 * lvl)
