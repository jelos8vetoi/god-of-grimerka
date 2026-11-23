## Зрители у трассы — живой мир гонки. Стоят за барьерами у старта и у трамплинов, переминаются, поворачиваются
## за гонщиками, вскидывают руки, когда мимо проносятся, и ликуют на финише игрока.
## Это обитатели «Облака» — хейтеры, клипперы и боты (те же модели, что у врагов кампании): покрасить и раздать
## разный рост дешевле, чем заводить отдельную толпу. Когда появится модель зрителя (npc_spectator.glb — промпт
## в godot/docs/TRIPO_PROMPTS_GAMEPLAY.md), она встанет сюда же.
## Производительность: зрителей немного (COUNT), думают по очереди раз в THINK секунды, а те, кто дальше FAR от
## камеры, не анимируются вовсе (и скрыты дальше HIDE).
class_name RaceCrowd
extends Node3D

const COUNT := 10
const THINK := 0.25
const NEAR := 26.0           # ближе — реагирует на гонщика
const FAR := 70.0            # дальше от камеры — стоит столбом (анимация выключена)
const HIDE := 140.0
const MODELS := ["hater", "clipper", "bot", "hater", "drey", "clipper", "bot", "madk1d"]

var race
var people: Array = []       # [{rig, home_yaw, t, cheer, phase, pos}]
var turn := 0
var acc := 0.0
var party := false           # игрок финишировал — все ликуют

func setup(rc) -> void:
	race = rc
	var xf: RaceTrack = rc.track
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(xf.id) + 5
	# где стоять: вдоль стартовой прямой по обе стороны и у каждого трамплина
	var spots: Array = []
	for k in 6:
		spots.append([xf.start_s - 14.0 + k * 7.0, -1.0 if k % 2 == 0 else 1.0])
	for r in xf.ramps:
		spots.append([float(r["s1"]) + 6.0, 1.0])
		spots.append([float(r["s1"]) + 12.0, -1.0])
	for k in mini(COUNT, spots.size()):
		var i := xf.at_s(float(spots[k][0]))
		if xf.P[i].y > 0.5:
			continue                                   # на крышах и лесах зрителям стоять негде — обочины там нет
		var right: Vector3 = xf.T[i].cross(Vector3.UP)
		var side: float = spots[k][1]
		var p: Vector3 = xf.P[i] + right * side * (xf.W[i] * 0.5 + RaceTrack.SHOULDER + 1.9 + rng.randf() * 0.8)
		var id: String = MODELS[k % MODELS.size()]
		var rig := Rig.new()
		add_child(rig)
		rig.setup("res://assets/models/%s.glb" % id, rng.randf_range(1.35, 1.7), RaceVisual.clips(), false, 1.0, "race_" + id)
		rig.position = Vector3(p.x, xf.P[i].y, p.z)
		var yaw := atan2(-right.x * side, -right.z * side)          # лицом к дороге
		rig.rotation.y = yaw
		rig.play("Idle", 0.0)
		people.append({"rig": rig, "home": yaw, "t": rng.randf() * 3.0, "cheer": 0.0, "phase": rng.randf() * TAU, "pos": rig.position, "y": rig.position.y})

func cheer_all() -> void:
	party = true

func _process(dt: float) -> void:
	if race == null or people.is_empty() or race.cam == null:
		return
	acc += dt
	var cam_p: Vector3 = race.cam.global_position
	# лёгкое покачивание — всем, кто на виду (без скелета: только узел)
	for p in people:
		var rig: Rig = p["rig"]
		var d: float = (p["pos"] as Vector3).distance_to(cam_p)
		rig.visible = d < HIDE
		var live: bool = d < FAR
		rig.process_mode = Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED
		if live:
			p["phase"] = float(p["phase"]) + dt * (9.0 if float(p["cheer"]) > 0.0 else 2.2)
			rig.position.y = float(p["y"]) + absf(sin(float(p["phase"]))) * (0.22 if float(p["cheer"]) > 0.0 else 0.02)
			p["cheer"] = maxf(0.0, float(p["cheer"]) - dt)
	if acc < THINK / float(people.size()):
		return
	acc = 0.0
	# по одному за раз: кто рядом из гонщиков — повернуться к нему и вскинуть руки
	turn = (turn + 1) % people.size()
	var q: Dictionary = people[turn]
	var rg: Rig = q["rig"]
	if rg.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var best: RaceRider = null
	var bd := NEAR
	for r in race.riders:
		var dd: float = (r as RaceRider).global_position.distance_to(q["pos"])
		if dd < bd and (r as RaceRider).speed > 4.0:
			bd = dd
			best = r
	if best != null:
		var to: Vector3 = best.global_position - (q["pos"] as Vector3)
		rg.rotation.y = lerp_angle(rg.rotation.y, atan2(to.x, to.z), 0.6)
		if float(q["cheer"]) <= 0.0:
			q["cheer"] = 1.1
			rg.play_for("Rage", 1.0, 0.1)
	elif party:
		if float(q["cheer"]) <= 0.0:
			q["cheer"] = 1.1
			rg.play_for("Rage", 1.0, 0.1)
	else:
		rg.rotation.y = lerp_angle(rg.rotation.y, float(q["home"]), 0.3)
