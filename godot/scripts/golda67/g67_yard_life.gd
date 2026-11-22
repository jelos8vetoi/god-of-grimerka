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

func _physics_process(dt: float) -> void:
	if golda == null or yard == null or not is_instance_valid(yard) or golda.place != "run":
		return
	clock += dt
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
			var pos := Vector3(clampf(hp.x, -30.0, 30.0), 8.0, 35.0)
			G67Sound.play(self, "door_slam", pos, 1.6)
			_say_at(pos, bk.pick("window", G67LifeData.WINDOW_SHOUTS))
		"window_shape":
			var wins: Array = yard.win_state
			for w in wins:
				if String(w["kind"]) == "warm" and float(w["to"]) > 0.5:
					w["a"] = 0.25
					break
		"car_alarm":
			G67Sound.play(self, "car_alarm", PLACE[id], 1.0)
			yard.scare(PLACE[id], 14.0)
			var tx = _resident("g67_npc_taxi_driver")
			if tx != null:
				bk.say(tx.rig, bk.pick("tx_siren", G67LifeData.BARKS["g67_npc_taxi_driver"]["siren"]))
		"old_car_lights":
			var l := OmniLight3D.new()
			yard.add_child(l)
			l.position = PLACE[id]
			l.light_color = Color(1.0, 0.95, 0.8)
			l.light_energy = 3.0
			l.omni_range = 7.0
			golda.get_tree().create_timer(2.0).timeout.connect(l.queue_free)
			if rng.randf() < 0.4:
				bk.pahan_say("car_lights")
		"garage_crash":
			G67Sound.play(self, "crash", PLACE[id], 1.0)
			var us = _resident("g67_npc_ushanka")
			if us != null:
				var r: Node3D = us.rig
				var to: Vector3 = PLACE["garage_crash"] - r.global_position
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
				golda.get_tree().create_timer(5.0).timeout.connect(func(): bk.pahan_say("musya", true))
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
					tws.tween_property(rg, "rotation:z", 0.0, 0.1)
		"schoolboy_show":
			var sc = _resident("g67_npc_schoolboy")
			var tgt = _resident("g67_npc_babushka" if rng.randf() < 0.5 else "g67_npc_taxi_driver")
			if sc != null and tgt != null:
				sc.visit((tgt.rig as Node3D).global_position + Vector3(1.2, 0, 0.6), 7.0)
		"kiosk_shout":
			G67Sound.play(self, "cough", PLACE[id], 1.0)
			_say_at(PLACE[id], bk.pick("kiosk", G67LifeData.KIOSK_SHOUTS))
		"queue_move", "counter_67":
			if id == "counter_67":
				G67Sound.play(self, "counter_click", PLACE[id], 1.0)

func _snow_puff(pos: Vector3) -> void:
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

func _spawn_walker() -> void:
	if walkers.size() >= 1:
		return
	var who: Dictionary = G67Yard.QUEUE_PEOPLE[rng.randi() % G67Yard.QUEUE_PEOPLE.size()]
	var route: Array = ROUTES[rng.randi() % ROUTES.size()]
	var r: Rig = yard._person(String(who["path"]), "walker", float(who["h"]), route[0], 0.0, {"base": "NWalk", "alts": []}, rng.randi())
	var life: G67Life = r.get_meta("life")
	if life != null:
		life.stage("NWalkBag", 0.1)
	var pts: Array = route.duplicate()
	pts.pop_front()
	walkers.append({"rig": r, "path": pts, "wait": 0.0})

func _walkers_tick(dt: float) -> void:
	for w in walkers.duplicate():
		var r: Rig = w["rig"]
		if not is_instance_valid(r):
			walkers.erase(w)
			continue
		var path: Array = w["path"]
		if path.is_empty():
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
