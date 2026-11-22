## Микрособытия двора (G67LifeData.MICRO): по таймеру, не больше одного слышимого за раз; во время боя, роликов, разговоров и
## постановок — ничего. Звуки — синтез G67Sound. Ключ проверки --g67-micro=<id> запускает событие у героя принудительно.
class_name G67YardLife
extends Node

const PLACE := {
	"window_shout": Vector3(0, 8.0, 35.0), "car_alarm": Vector3(31.4, 0.8, -4.5), "old_car_lights": Vector3(-38.6, 0.8, 14.0),
	"garage_crash": Vector3(-43.0, 1.0, -6.0), "door_slam": Vector3(-12.0, 1.2, 36.0), "roof_snow": Vector3(0.0, 3.3, 35.4),
	"intercom_beep": Vector3(-1.6, 1.3, 35.0), "pigeons_turn": Vector3(9.4, 0, 29.4), "pigeon_stare": Vector3(-20, 0, -16),
	"pigeon_67": Vector3(28, 0, -17), "musya": Vector3(-46.0, 1.5, 6.0), "filyai": Vector3(-42.0, 1.0, 3.6),
	"kiosk_shout": Vector3(42.3, 1.9, 7.0), "garage_radio": Vector3(-42.0, 1.0, 3.6), "counter_67": Vector3(33.0, 1.2, -14.0),
}

var golda
var yard
var clock := 0.0
var cds := {}
var next_audible := 20.0
var log: Array = []                       # [время, id] — для проверок
var walkers: Array = []
var musya_done := false
var radio_t := 6.0
var gust := 0.0
var rng := RandomNumberGenerator.new()

static func make(g, yd) -> G67YardLife:
	var L := G67YardLife.new()
	L.golda = g
	L.yard = yd
	L.rng.randomize()
	L.name = "G67YardLife"
	return L

func _hero() -> Node3D:
	return golda.game.player

func _in_zone(zid: String, p: Vector3) -> bool:
	var z: Dictionary = G67Yard.zone(zid)
	var c: Vector3 = z["c"]
	var h: Vector2 = z["h"]
	return absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.y

func _ok_now(e: Dictionary) -> bool:
	if golda.place != "run" or golda.game.get_tree().paused:
		return false
	var bk: G67Barks = golda.barks_get()
	if not bk.can_talk(false) and not bool(e.get("silent", false)):
		return false
	if golda.clip != null or golda.talk_on or golda.scene_t >= 0.0 or golda.ev_cam or golda.ev_busy or golda.room_state == "boss":
		return false
	if golda.room_state == "fight" and not bool(e.get("silent", false)):
		return false
	return true

func _eligible(e: Dictionary) -> bool:
	var id := String(e["id"])
	if clock - float(cds.get(id, -1000.0)) < float(e["cd"]):
		return false
	if not _ok_now(e):
		return false
	var hp: Vector3 = _hero().global_position
	if String(e.get("zone", "")) != "" and not _in_zone(String(e["zone"]), hp):
		return false
	if e.has("dist"):
		var pl: Vector3 = PLACE.get(id, hp)
		if id == "pigeons_turn" or id == "pigeon_stare" or id == "pigeon_67":
			pl = _near_flock(hp)
		var d: float = Vector2(pl.x - hp.x, pl.z - hp.z).length()
		var dr: Array = e["dist"]
		if d < float(dr[0]) or d > float(dr[1]):
			return false
	return true

func _near_flock(hp: Vector3) -> Vector3:
	var best := Vector3(1e6, 0, 1e6)
	for f in yard.flocks:
		var home: Vector3 = f["alt"] if bool(f["at_alt"]) else f["home"]
		if Vector2(home.x - hp.x, home.z - hp.z).length() < Vector2(best.x - hp.x, best.z - hp.z).length():
			best = home
	return best

var btn_t := 25.0

func _intercom_press() -> void:
	var ic = yard.life_props.get("g67_intercom")
	if ic == null or not is_instance_valid(ic):
		return
	var b: Node3D = ic.find_child("btn8", true, false)
	if b == null:
		return
	var p0 := b.position
	var tw := create_tween()
	tw.tween_property(b, "position", p0 + Vector3(0, 0, -0.008), 0.08)
	tw.tween_property(b, "position", p0, 0.12)
	G67Sound.play(self, "click", Vector3(-1.3, 1.2, 34.9), 1.0)

func _physics_process(dt: float) -> void:
	if golda == null or yard == null or not is_instance_valid(yard) or golda.place != "run":
		return
	clock += dt
	btn_t -= dt
	if btn_t <= 0.0:
		btn_t = rng.randf_range(35.0, 45.0)
		if _hero().global_position.distance_to(Vector3(-1.3, 1.0, 34.9)) < 20.0:
			_intercom_press()
	_walkers_tick(dt)
	radio_t -= dt
	if radio_t <= 0.0 and _ok_now({"silent": true}):
		radio_t = rng.randf_range(11.0, 16.0)
		if _hero().global_position.distance_to(PLACE["garage_radio"]) < 9.0:
			G67Sound.play(self, "radio_jingle", PLACE["garage_radio"], 1.0)
	next_audible -= dt
	for e in G67LifeData.MICRO:
		if bool(e.get("silent", false)) and e["id"] != "garage_radio":
			if _eligible(e):
				cds[e["id"]] = clock
				fire(String(e["id"]))
	if next_audible > 0.0:
		return
	var cands: Array = []
	for e in G67LifeData.MICRO:
		if not bool(e.get("silent", false)) and _eligible(e):
			cands.append(e)
	if cands.is_empty():
		return
	var pick: Dictionary = cands[rng.randi() % cands.size()]
	cds[pick["id"]] = clock
	next_audible = rng.randf_range(14.0, 26.0)
	fire(String(pick["id"]))

func _marker(pos: Vector3, life := 8.0) -> Node3D:
	var m := Node3D.new()
	golda.add_child(m)
	m.global_position = pos
	golda.get_tree().create_timer(life).timeout.connect(m.queue_free)
	return m

func _resident(id: String):
	return yard.residents.get(id)

func _say_at(pos: Vector3, line: String) -> void:
	var bk: G67Barks = golda.barks_get()
	bk.say(_marker(pos), line, {"force": true, "dur": 4.0})

## Принудительный запуск (ключ --g67-micro и проверки)
func fire(id: String) -> void:
	var hp: Vector3 = _hero().global_position
	cds[id] = clock
	log.append([clock, id])
	var bk: G67Barks = golda.barks_get()
	match id:
		"window_light":
			yard.win_timer = 0.0
		"window_shout":
			_window_shout()
		"window_shape":
			_window_shape()
		"car_alarm":
			G67Sound.play(self, "car_alarm", PLACE[id], 1.0)
			yard.scare(PLACE[id], 14.0)
			var tx = _resident("g67_npc_taxi_driver")
			if tx != null:
				bk.say(tx.rig, bk.pick("tx_siren", G67LifeData.BARKS["g67_npc_taxi_driver"]["siren"]))
		"old_car_lights":
			for sx in [-0.8, 0.8]:                                    # фары у фургона у гаражей (−38,6; 14,0)
				var l := OmniLight3D.new()
				yard.add_child(l)
				l.position = Vector3(-37.2, 0.7, 14.0 + sx * 1.1)
				l.light_color = Color(1.0, 0.95, 0.8)
				l.light_energy = 3.5
				l.omni_range = 6.0
				golda.get_tree().create_timer(2.0).timeout.connect(l.queue_free)
			if rng.randf() < 0.4:
				bk.pahan_say("car_lights")
		"garage_crash":
			G67Sound.play(self, "crash", Vector3(-43.4, 1.0, 13.0), 1.0)           # закрытый гараж № 3
			var us = _resident("g67_npc_ushanka")
			if us != null:
				var r: Node3D = us.rig
				var to: Vector3 = Vector3(-43.4, 1.0, -6.0) - r.global_position       # смотрит на гараж № 8
				var tw := create_tween()
				tw.tween_property(r, "rotation:y", atan2(to.x, to.z), 0.4)
				tw.tween_interval(2.0)
				tw.tween_property(r, "rotation:y", r.rotation.y + PI, 0.5)
		"garage_radio":
			G67Sound.play(self, "radio_jingle", PLACE[id], 1.0)
		"door_slam":
			G67Sound.play(self, "door_slam", PLACE[id], 1.0)
			fire("walker")
		"walker":
			_spawn_walker()
		"roof_snow":
			var at: Vector3 = PLACE[id]
			G67Sound.play(self, "snow_slide", at, 1.0)
			_snow_puff(Vector3(at.x, 0.4, at.z + 0.6))
			if Vector2(hp.x - at.x, hp.z - (at.z - 0.8)).length() < 2.2:
				golda._ev_say("V|Спасибо, блядь.")
		"lamp_blink":
			var best: OmniLight3D = null
			var bd := 1e9
			for lm in yard.lamps:
				if is_instance_valid(lm):
					var d: float = lm.global_position.distance_to(hp)
					if d < bd:
						bd = d
						best = lm
			if best != null:
				var e0 := best.light_energy
				var tw2 := create_tween()
				tw2.tween_property(best, "light_energy", 0.0, 0.05)
				tw2.tween_interval(rng.randf_range(0.6, 1.2))
				tw2.tween_callback(func():
					if is_instance_valid(best):
						G67Sound.play(self, "lamp_crackle", best.global_position, 1.0))
				tw2.tween_property(best, "light_energy", e0, 0.1)
		"intercom_beep":
			G67Sound.play(self, "intercom_beep", PLACE[id], 1.0)
			var arr: Array = G67LifeData.INTERCOM[4 + (rng.randi() % 2)]
			_say_at(PLACE[id] + Vector3(0, 0.6, 0), String(arr[0]))
		"wind_gust":
			gust = 3.0
			yard.gust(3.0)
			var sw = yard.life_props.get("g67_swing_set")
			if sw != null and is_instance_valid(sw):
				var seat: Node3D = sw.find_child("seat", true, false)
				if seat != null:
					var tws := create_tween()
					for i in 4:
						tws.tween_property(seat, "rotation:x", 0.35 * (1.0 if i % 2 == 0 else -1.0), 0.7)
					tws.tween_property(seat, "rotation:x", 0.0, 0.8)
			G67Sound.play(self, "swing_creak", Vector3(-1.0, 1.2, -3.0), 1.0)
		"pigeons_turn":
			var f: Dictionary = yard.nearest_flock(hp)
			if not f.is_empty():
				var ang := rng.randf_range(0.0, TAU)
				for b in f["birds"]:
					var gp: G67Pigeon = b["p"]
					if is_instance_valid(gp):
						gp.yaw_to = ang
						gp.turn_in = 4.0
						gp.peck_in = 4.0
		"pigeon_stare":
			var f2: Dictionary = yard.nearest_flock(hp)
			if not f2.is_empty():
				var b0: Dictionary = f2["birds"][0]
				var gp2: G67Pigeon = b0["p"]
				var tp: Vector3 = hp - (b0["n"] as Node3D).global_position
				gp2.yaw_to = atan2(tp.x, tp.z)
				gp2.turn_in = 8.0
				gp2.peck_in = 8.0
				bk.pahan_say("pigeon_stare")
		"pigeon_67":
			var f3: Dictionary = yard.nearest_flock(hp)
			if not f3.is_empty():
				var n: Node3D = (f3["birds"][0] as Dictionary)["n"]
				var gp3: G67Pigeon = (f3["birds"][0] as Dictionary)["p"]
				gp3.flight = true
				var tw3 := create_tween()
				for i in 3:
					tw3.tween_property(n, "rotation:z", 0.7, 0.18)
					tw3.tween_property(n, "rotation:z", -0.7, 0.18)
				tw3.tween_property(n, "rotation:z", 0.0, 0.15)
				tw3.tween_callback(func(): gp3.flight = false)
		"musya":
			if not musya_done:
				musya_done = true
				_say_at(PLACE[id], "Z2|Муся, это ты?")
				golda.get_tree().create_timer(5.0).timeout.connect(func():
					bk.pahan_say("musya", true)
					var pg := G67Models.spawn("g67_pigeon", yard, Vector3(-46.5, 0.05, 3.0), 1.2, Vector3(0.35, 0.35, 0.35))
					var gpm := G67Pigeon.attach(pg, 777)
					gpm.feed(Vector3(-44.3, 0.05, 6.0))
					golda.get_tree().create_timer(14.0).timeout.connect(pg.queue_free))
		"filyai":
			G67Sound.play(self, "radio_jingle", PLACE[id], 2.0)
			for rid in ["g67_npc_ushanka", "g67_npc_schoolboy"]:
				var rr = _resident(rid)
				if rr != null:
					var rg: Node3D = rr.rig
					var tws := create_tween()
					for i in 4:
						tws.tween_property(rg, "rotation:z", 0.08, 0.25)
						tws.tween_property(rg, "rotation:z", -0.08, 0.25)
					tws.tween_property(rg, "rotation:z", 0.0, 0.0)
					if rid == "g67_npc_ushanka":
						tws.tween_callback(func():
							if is_instance_valid(rr.life):
								rr.life.stage("NCross", 0.05)         # резко замер, «ничего не было»
							filyai_froze = clock
							get_tree().create_timer(2.5).timeout.connect(func():
								if is_instance_valid(rr.life):
									rr.life.resume()))
		"schoolboy_show":
			var sc = _resident("g67_npc_schoolboy")
			var tgt = _resident("g67_npc_babushka" if rng.randf() < 0.5 else "g67_npc_taxi_driver")
			if sc != null and tgt != null:
				sc.visit((tgt.rig as Node3D).global_position + Vector3(1.2, 0, 0.6), 7.0)
		"kiosk_shout":
			G67Sound.play(self, "cough", PLACE[id], 1.0)
			_say_at(PLACE[id], bk.pick("kiosk", G67LifeData.KIOSK_SHOUTS))
		"queue_move":
			_queue_move()
		"counter_67":
			var cl := _counter_node()
			G67Sound.play(self, "counter_click", PLACE[id], 1.0)
			if cl != null:
				var tw7 := create_tween()
				tw7.tween_callback(func():
					if is_instance_valid(cl):
						cl.text = "7")
				tw7.tween_interval(0.5)
				tw7.tween_callback(func():
					if is_instance_valid(cl):
						cl.text = "6"
					G67Sound.play(self, "counter_click", PLACE[id], 1.0))

## Окно на фасаде: тёплое стекло, свет и (при flap) створка на петле слева
func _window_prop(x: float, flap: bool) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(x, 8.0, 34.82)
	yard.add_child(root)
	var glow := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 1.2)
	glow.mesh = qm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.78, 0.45)
	glow.material_override = gm
	glow.rotation.y = PI
	root.add_child(glow)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.78, 0.45)
	lt.light_energy = 1.4
	lt.omni_range = 7.0
	lt.position = Vector3(0, 0, -0.8)
	root.add_child(lt)
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.45, 0, -0.03)
	root.add_child(pivot)
	if flap:
		var fm := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(0.9, 1.2)
		fm.mesh = fq
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.25, 0.2, 0.17)
		fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.material_override = fmat
		fm.position = Vector3(0.45, 0, 0)
		pivot.add_child(fm)
	golda.get_tree().create_timer(9.0).timeout.connect(root.queue_free)
	return {"root": root, "pivot": pivot, "glow": glow}

func _window_shout() -> void:
	var hp: Vector3 = _hero().global_position
	var x := clampf(hp.x + rng.randf_range(-4.0, 4.0), -30.0, 30.0)
	last_window_x = x
	var w := _window_prop(x, true)
	var pv: Node3D = w["pivot"]
	var pos := Vector3(x, 8.0, 34.5)
	var tw := create_tween()
	tw.tween_property(pv, "rotation:y", 1.5, 0.4)
	G67Sound.play(self, "door_slam", pos, 1.6)
	var bk: G67Barks = golda.barks_get()
	get_tree().create_timer(0.5).timeout.connect(func(): bk.say(_marker(pos, 5.0), bk.pick("window", G67LifeData.WINDOW_SHOUTS), {"force": true, "dur": 4.0}))
	get_tree().create_timer(4.2).timeout.connect(func():
		if is_instance_valid(pv):
			create_tween().tween_property(pv, "rotation:y", 0.0, 0.25)
			G67Sound.play(self, "door_slam", pos, 1.6))

func _window_shape() -> void:
	var hp: Vector3 = _hero().global_position
	var x := clampf(hp.x + rng.randf_range(-6.0, 6.0), -30.0, 30.0)
	last_window_x = x
	var w := _window_prop(x, false)
	var root: Node3D = w["root"]
	var sil := Node3D.new()
	sil.position = Vector3(0.3, -0.15, -0.06)
	root.add_child(sil)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.03, 0.03, 0.04)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.5, 0.05)
	body.mesh = bm
	body.material_override = dm
	body.position = Vector3(0, -0.2, 0)
	sil.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.26
	head.mesh = hm
	head.material_override = dm
	head.position = Vector3(0, 0.15, 0)
	sil.add_child(head)
	var tw := create_tween()
	tw.tween_property(sil, "position:x", 0.0, 0.8)
	tw.tween_interval(rng.randf_range(4.0, 6.0))
	tw.tween_property(sil, "position:x", -0.7, 1.0)
	tw.tween_callback(root.queue_free)

## Идёт пешком к точке, потом делает then
func _walk_to(r: Node3D, to: Vector3, spd: float, then := Callable()) -> void:
	var lf = r.get_meta("life") if r.has_meta("life") else null
	if lf != null:
		lf.stage("NWalk", 0.3)
	var d := Vector3(to.x - r.position.x, 0.0, to.z - r.position.z)
	var dur: float = maxf(0.3, d.length() / spd)
	r.rotation.y = atan2(d.x, d.z)
	var tw := create_tween()
	tw.tween_property(r, "position", Vector3(to.x, r.position.y, to.z), dur)
	tw.tween_callback(func():
		if is_instance_valid(r) and lf != null and is_instance_valid(lf):
			lf.resume()
		if then.is_valid():
			then.call())

func _queue_move() -> void:
	var q: Array = yard.queue.filter(func(n): return is_instance_valid(n))
	if q.size() < 3:
		return
	var eater: Node3D = null
	for n in q:
		if String(n.name) == "queue_eater":
			eater = n
	var line: Array = q.filter(func(n): return String(n.name) != "queue_eater")
	var spots: Array = G67Yard.QUEUE_SPOTS
	while line.size() > spots.size():
		var extra: Node3D = line.pop_back()
		extra.queue_free()
	var first: Node3D = line[0]
	var eat_pos: Vector3 = G67Yard.EATER["pos"]
	if eater != null:
		_walk_to(eater, eater.position + Vector3(9.0, 0.0, 7.0), 1.1, func():
			if is_instance_valid(eater):
				eater.queue_free())
		yard.queue.erase(eater)
	_walk_to(first, eat_pos, 1.1, func():
		if is_instance_valid(first):
			first.rotation.y = float(G67Yard.EATER["yaw"])
			first.name = "queue_eater"
			var lf = first.get_meta("life") if first.has_meta("life") else null
			if lf != null:
				lf.base = String(G67Yard.EATER["base"])
				lf.alts = G67Yard.EATER.get("alts", [])
				lf.resume())
	for i in range(1, line.size()):
		var nd: Node3D = line[i]
		var sp: Vector3 = spots[i - 1]
		_walk_to(nd, sp, 0.9, func():
			if is_instance_valid(nd):
				nd.rotation.y = PI * 0.5)
		nd.name = "queue%d" % (i - 1)
	var newp: Dictionary = G67Yard.QUEUE_PEOPLE[rng.randi() % G67Yard.QUEUE_PEOPLE.size()]
	var last: int = spots.size() - 1
	var fresh: Rig = yard._person(String(newp["path"]), String(newp["key"]), float(newp["h"]), (spots[last] as Vector3) + Vector3(5.0, 0.0, 3.0), PI * 0.5, G67Yard.QUEUE_ROLES[last % G67Yard.QUEUE_ROLES.size()], rng.randi())
	fresh.name = "queue%d" % last
	_walk_to(fresh, spots[last], 1.0, func():
		if is_instance_valid(fresh):
			fresh.rotation.y = PI * 0.5)
	yard.queue = line.slice(1)
	yard.queue.append(fresh)
	if first != null:
		yard.queue.append(first)

var counter_lb: Label3D = null
var filyai_froze := -1.0
var last_window_x := 0.0

func _counter_node() -> Label3D:
	if counter_lb != null and is_instance_valid(counter_lb):
		return counter_lb
	var bn: Dictionary = golda.world.ev_nodes.get("burm", {})
	if bn.is_empty():
		return null
	var root: Node3D = bn["root"]
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.12, 0.03)
	box.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.04)
	box.material_override = m
	box.position = Vector3(0.3, 0.9, 0.42)
	root.add_child(box)
	counter_lb = Label3D.new()
	counter_lb.text = "6"
	counter_lb.font_size = 48
	counter_lb.pixel_size = 0.0034
	counter_lb.modulate = Color(0.4, 1.0, 0.5)
	counter_lb.shaded = false
	counter_lb.position = Vector3(0.3, 0.9, 0.445)
	root.add_child(counter_lb)
	return counter_lb

func dust_burst(pos: Vector3, count := 26, col := Color(0.93, 0.94, 0.96)) -> void:
	var holder := Node3D.new()
	yard.add_child(holder)
	holder.global_position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = mat
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.scale = Vector3.ONE * rng.randf_range(0.6, 1.8)
		holder.add_child(mi)
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.1), rng.randf_range(-1.0, 1.0)).normalized()
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mi, "position", dir * rng.randf_range(0.6, 1.6), 1.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", mi.scale * 2.2, 1.3)
	var ft := create_tween()
	ft.tween_property(mat, "albedo_color:a", 0.0, 1.0).set_delay(0.5)
	golda.get_tree().create_timer(2.0).timeout.connect(holder.queue_free)

func _snow_puff(pos: Vector3) -> void:
	dust_burst(pos)
	return
	var pr := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.3)
	pm.spread = 50.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -2.0, 0)
	pr.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	pr.draw_pass_1 = sm
	pr.amount = 40
	pr.lifetime = 1.4
	pr.one_shot = true
	pr.explosiveness = 0.9
	yard.add_child(pr)
	pr.global_position = pos
	pr.emitting = true
	golda.get_tree().create_timer(2.5).timeout.connect(pr.queue_free)

const ROUTES := [
	[Vector3(-14, 0, 34.5), Vector3(-10, 0, 28), Vector3(12, 0, 24), Vector3(22, 0, 14)],
	[Vector3(-34, 0, 10), Vector3(-26, 0, 6), Vector3(-10, 0, -20)],
	[Vector3(46, 0, -14), Vector3(36, 0, -4), Vector3(14, 0, 18), Vector3(4, 0, 30)],
	[Vector3(-12, 0, 33), Vector3(-14, 0, 24), Vector3(-20, 0, -10), Vector3(-24, 0, -28)],
]

func _make_walker(start: Vector3, pts: Array, hold: bool) -> Rig:
	var who: Dictionary = G67Yard.QUEUE_PEOPLE[rng.randi() % G67Yard.QUEUE_PEOPLE.size()]
	var r: Rig = yard._person(String(who["path"]), "walker", float(who["h"]), start, 0.0, {"base": "NWalk", "alts": []}, rng.randi())
	var life: G67Life = r.get_meta("life")
	if life != null:
		life.stage("NWalkBag", 0.1)
	walkers.append({"rig": r, "path": pts, "wait": 0.0, "hold": hold})
	return r

func _spawn_walker() -> void:
	if walkers.size() >= 1:
		return
	var route: Array = ROUTES[rng.randi() % ROUTES.size()]
	var pts: Array = route.duplicate()
	var st: Vector3 = pts.pop_front()
	_make_walker(st, pts, false)

## Прохожий для разговора: подходит к другому участнику и останавливается (роль walker в DUOS)
var duo_walkers := {}

func walker_for(duo: Dictionary) -> Node3D:
	var id := String(duo["id"])
	if duo_walkers.has(id) and is_instance_valid(duo_walkers[id]):
		return duo_walkers[id]
	var tgt = null
	for w in duo["who"]:
		if yard.residents.has(String(w)):
			tgt = yard.residents[String(w)].rig
	if tgt == null:
		return null
	var stop: Vector3 = (tgt as Node3D).global_position + Vector3(1.3, 0, 1.0)
	var r := _make_walker(stop + Vector3(7.0, 0, 5.0), [stop], true)
	r.rotation.y = 0.0
	duo_walkers[id] = r
	return r

func release_walker(duo: Dictionary) -> void:
	var id := String(duo["id"])
	if not duo_walkers.has(id):
		return
	var r = duo_walkers[id]
	duo_walkers.erase(id)
	for w in walkers:
		if w["rig"] == r:
			w["hold"] = false
			(w["path"] as Array).append((r as Node3D).position + Vector3(-9.0, 0, 6.0))

func _walkers_tick(dt: float) -> void:
	for w in walkers.duplicate():
		var r: Rig = w["rig"]
		if not is_instance_valid(r):
			walkers.erase(w)
			continue
		var path: Array = w["path"]
		if path.is_empty():
			if bool(w.get("hold", false)):
				var lh: G67Life = r.get_meta("life") if r.has_meta("life") else null
				if lh != null and lh.cur != "NTalk" and lh.paused:
					lh.base = "NTalk"
					lh.alts = ["NIdleL"]
					lh.resume()
				continue
			r.queue_free()
			walkers.erase(w)
			continue
		var h: Vector3 = _hero().global_position
		var tgt: Vector3 = path[0]
		var to := Vector3(tgt.x - r.position.x, 0, tgt.z - r.position.z)
		if to.length() < 0.3:
			path.pop_front()
			continue
		var rel := Vector3(h.x - r.position.x, 0, h.z - r.position.z)
		if rel.length() < 1.3 and rel.normalized().dot(to.normalized()) > 0.3:
			continue                                         # герой на пути: стоит, пока тот не отойдёт
		var d := to.normalized()
		r.position += d * minf(to.length(), 1.1 * dt)
		r.rotation.y = lerp_angle(r.rotation.y, atan2(d.x, d.z), 1.0 - exp(-5.0 * dt))
