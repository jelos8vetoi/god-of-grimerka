## Погода и случайные ситуации VACUUM RACING.
## Погода (WEATHERS) выбирается перед заездом и правда меняет езду: сцепление, тормоз, разгон, заряд заноса,
## снос ветром, видимость. Ситуации (HAPPENINGS) случаются посреди гонки раз в 18–30 с: «буханка» переезжает
## дорогу, прорыв теплотрассы подбрасывает, гопники скатывают шины, мусоровоз рассыпает хлам, ливень,
## «акция» в коробках, попутный ветер, голуби. Решает и считает только власть гонки (офлайн — игра, по сети —
## хост, race_net шлёт клиентам «happening» с местом), клиенты строят тот же вид по тем же данным.
class_name RaceWeather
extends Node3D

## mods: grip — сцепление, brake — тормоз, accel — разгон, charge — заряд заноса, vmax — предел скорости,
## bot — темп ботов (видимость). fog — плотность тумана, sky — [верх, горизонт], light — сила солнца.
const WEATHERS := {
	"clear": {"name": "ЯСНО", "icon": "☀", "desc": "сухой асфальт", "mods": {}, "fog": 0.0032},
	"rain": {"name": "ЛИВЕНЬ", "icon": "☂", "desc": "мокро: сцепление хуже, заносы длиннее и заряжаются быстрее, тормоз слабее",
		"mods": {"grip": 0.7, "brake": 0.8, "charge": 1.3}, "fog": 0.009, "sky": [Color(0.22, 0.24, 0.3), Color(0.45, 0.48, 0.52)], "light": 0.55},
	"fog": {"name": "ТУМАН", "icon": "≋", "desc": "видно метров на сорок, боты осторожнее",
		"mods": {"bot": 0.95}, "fog": 0.035, "sky": [Color(0.6, 0.62, 0.66), Color(0.75, 0.76, 0.78)], "light": 0.6},
	"wind": {"name": "ВЕТЕР", "icon": "➶", "desc": "порывы сносят вбок, по ветру быстрее, против — медленнее",
		"mods": {}, "wind": 7.5, "fog": 0.004, "sky": [Color(0.28, 0.36, 0.55), Color(0.85, 0.7, 0.55)], "light": 1.1},
	"ice": {"name": "ГОЛОЛЁД", "icon": "❄", "desc": "первый снег в Томске: держит слабо, тормоз и разгон хуже, заносы — подарок",
		"mods": {"grip": 0.45, "brake": 0.55, "accel": 0.85, "charge": 1.2}, "fog": 0.008, "sky": [Color(0.55, 0.6, 0.7), Color(0.85, 0.87, 0.9)], "light": 0.8, "snow": true},
	"dust": {"name": "ПЫЛЬНАЯ БУРЯ", "icon": "☁", "desc": "по трассе гуляют облака пыли — в них медленнее и ничего не видно",
		"mods": {"bot": 0.97}, "fog": 0.014, "sky": [Color(0.55, 0.45, 0.32), Color(0.8, 0.62, 0.42)], "light": 0.75, "storm": true},
	"night": {"name": "НОЧЬ", "icon": "☾", "desc": "темно, горят фонари и фары, видно только освещённое",
		"mods": {"bot": 0.97}, "fog": 0.006, "sky": [Color(0.02, 0.02, 0.05), Color(0.08, 0.07, 0.12)], "light": 0.08, "night": true},
}
const WEATHER_ORDER := ["random", "clear", "rain", "fog", "wind", "ice", "dust", "night"]
const VAN := Vector3(4.4, 2.2, 2.0)   # коробка столкновения буханки: длина (вдоль хода), высота, ширина
const VAN_HIT := 0.25                 # запас к касанию: буханка — твёрдое тело и толкает гонщика носом, вплотную не подходит

## Случайные ситуации: t — сколько длится, w — вес выбора, need — только при такой погоде
const HAPPENINGS := {
	"buhanka": {"title": "БУХАНКА ПОЕХАЛА ЗА ХЛЕБОМ", "sub": "через дорогу переезжает машина — объезжай", "t": 6.0, "w": 3},
	"steam": {"title": "ПРОРВАЛО ТЕПЛОТРАССУ", "sub": "столб пара подбрасывает всех, кто проезжает", "t": 9.0, "w": 3},
	"tires": {"title": "С ГАРАЖЕЙ СКАТИЛИ ШИНЫ", "sub": "шины на дороге — не врежься", "t": 12.0, "w": 3},
	"trash": {"title": "МУСОРОВОЗ НЕ ДОВЁЗ", "sub": "хлам на дороге: там медленнее", "t": 12.0, "w": 2},
	"downpour": {"title": "ВНЕЗАПНЫЙ ЛИВЕНЬ", "sub": "15 секунд скользко", "t": 15.0, "w": 2, "need": ["clear", "wind", "dust"]},
	"promo": {"title": "АКЦИЯ В ПЫЛЕСБОРНИКАХ", "sub": "10 секунд в коробках только ТУРБО-БАЛЛОНЫ", "t": 10.0, "w": 2},
	"tailwind": {"title": "ПОПУТНЫЙ ВЕТЕР", "sub": "на этом участке дует в спину — разгон", "t": 10.0, "w": 2},
	"pigeons": {"title": "ГОЛУБИ! ПРИГНИСЬ!", "sub": "стая над дорогой: в ней медленнее", "t": 7.0, "w": 2},
	"blackout": {"title": "ОТКЛЮЧИЛИ СВЕТ", "sub": "фонари погасли — только фары", "t": 9.0, "w": 3, "need": ["night"]},
}

var race
var id := "clear"
var W: Dictionary = {}
var mods := {"grip": 1.0, "brake": 1.0, "accel": 1.0, "charge": 1.0, "vmax": 1.0, "bot": 1.0}
var wind := Vector3.ZERO           # ветер сейчас (м/с), сносит вбок
var wind_dir := 0.0
var gust := 0.0
var particles: GPUParticles3D
var env: Environment
var sun: DirectionalLight3D
var lamps: Array = []              # свет фонарей ночью
var heads: Array = []              # фары гонщиков ночью
var storm_t := 4.0
var active: Array = []             # идущие ситуации: {kind, t, s, pos, nodes, hit, data}
var next_t := 22.0
var last_kind := ""
var happen_log: Array = []         # что было (для проверки): [вид, путь]
var happen_on := true
var downpour_t := 0.0
var promo_t := 0.0
var rng := RandomNumberGenerator.new()

func setup(r, weather: String, happenings: bool, seed_v: int) -> void:
	race = r
	rng.seed = seed_v
	if weather == "random" or not WEATHERS.has(weather):
		var ids: Array = WEATHERS.keys()
		weather = String(ids[rng.randi() % ids.size()])
	id = weather
	W = WEATHERS[id]
	if id == "dust" and race.track != null and race.track.winter():
		W = (W as Dictionary).duplicate()            # на зимней трассе пыли нет — это метель (езда та же)
		W["name"] = "МЕТЕЛЬ"
		W["desc"] = "по трассе гуляют снежные заряды — в них медленнее и ничего не видно"
	happen_on = happenings
	next_t = rng.randf_range(16.0, 24.0)
	for k in W["mods"]:
		mods[k] = float(W["mods"][k])
	wind_dir = rng.randf() * TAU
	_look()

# ---------------- вид ----------------
func _look() -> void:
	var xf: RaceTrack = race.track
	for c in xf.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D and sun == null:
			sun = c
	if env != null:
		env.fog_density = float(W.get("fog", 0.0032))
		if W.has("sky") and not (xf.winter() and not bool(W.get("night", false))):      # у зимней трассы небо своё
			var sm := env.sky.sky_material as ProceduralSkyMaterial
			sm.sky_top_color = W["sky"][0]
			sm.sky_horizon_color = W["sky"][1]
			sm.ground_horizon_color = (W["sky"][1] as Color).darkened(0.2)
			env.fog_light_color = (W["sky"][1] as Color).darkened(0.1)
		if bool(W.get("night", false)):
			env.ambient_light_energy = 0.55 if xf.winter() else 0.25      # на снегу ночью светлее, и дорогу должно быть видно
			env.glow_intensity = 1.0
	if sun != null and W.has("light"):
		sun.light_energy = float(W["light"])
	if id == "rain" or id == "ice":
		var road: StandardMaterial3D = xf.mats["road"]
		if id == "rain":
			road.roughness = 0.18
			road.metallic = 0.25
		else:
			road.albedo_color = Color(0.55, 0.58, 0.62)
			road.roughness = 0.25
			(xf.mats["ground"] as StandardMaterial3D).albedo_color = Color(0.82, 0.84, 0.88)
			(xf.mats["shoulder"] as StandardMaterial3D).albedo_color = Color(0.7, 0.72, 0.76)
	if id in ["rain", "ice", "dust", "wind"]:
		particles = _precip(id)
	if bool(W.get("night", false)):
		_night_lights()

## осадки вокруг камеры: капли, снег, пыль, листья
func _precip(kind: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 1600 if kind == "rain" else (900 if kind == "ice" else 500)
	p.lifetime = 1.2 if kind == "rain" else 3.0
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.15, -1, 0) if kind == "rain" else Vector3(1, -0.2, 0.3)
	pm.spread = 6.0 if kind == "rain" else 35.0
	pm.initial_velocity_min = 24.0 if kind == "rain" else (2.0 if kind == "ice" else 9.0)
	pm.initial_velocity_max = 30.0 if kind == "rain" else (4.0 if kind == "ice" else 15.0)
	pm.gravity = Vector3(0, -9.8 if kind == "rain" else -1.5, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.7) if kind == "rain" else (Vector2(0.12, 0.12) if kind == "ice" else Vector2(0.25, 0.18))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if kind == "rain" else BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = {"rain": Color(0.75, 0.82, 0.95, 0.45), "ice": Color(1, 1, 1, 0.9), "dust": Color(0.6, 0.5, 0.36, 0.55), "wind": Color(0.85, 0.55, 0.2, 0.9)}[kind]
	if race.track != null and race.track.winter() and kind in ["dust", "wind"]:
		m.albedo_color = Color(0.92, 0.95, 1.0, 0.6)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

func _night_lights() -> void:
	var xf: RaceTrack = race.track
	var n := 0
	for c in xf.get_children():
		if c is Node3D and String(c.name).begins_with("street_lamp") and n < 24:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.78, 0.45)
			l.light_energy = 2.2
			l.omni_range = 14.0
			l.position = (c as Node3D).position + Vector3(0, 5.6, 0)
			add_child(l)
			lamps.append(l)
			n += 1
	if n == 0:
		# фонарей-моделей нет — свет вдоль дороги через каждые 40 м
		var s := 0.0
		while s < xf.L and n < 20:
			var i := xf.at_s(s)
			var l2 := OmniLight3D.new()
			l2.light_color = Color(1.0, 0.78, 0.45)
			l2.light_energy = 2.0
			l2.omni_range = 16.0
			l2.position = xf.P[i] + xf.T[i].cross(Vector3.UP) * (xf.W[i] * 0.5 + 2.5) + Vector3(0, 5.5, 0)
			add_child(l2)
			lamps.append(l2)
			s += 40.0
			n += 1
	for r in race.riders:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.95, 0.85)
		sp.light_energy = 4.0
		sp.spot_range = 26.0
		sp.spot_angle = 32.0
		sp.position = Vector3(0, 0.7, 0.5)
		sp.rotation = Vector3(-0.12, PI, 0)
		(r as RaceRider).pivot.add_child(sp)
		heads.append(sp)

# ---------------- каждый шаг ----------------
func tick(dt: float) -> void:
	# ветер: направление медленно гуляет, порывы
	if W.has("wind"):
		wind_dir += rng.randf_range(-0.2, 0.2) * dt
		gust = lerpf(gust, rng.randf_range(0.3, 1.6), dt * 0.8)
		wind = Vector3(sin(wind_dir), 0, cos(wind_dir)) * float(W["wind"]) * gust
	else:
		wind = Vector3.ZERO
	if downpour_t > 0.0:
		downpour_t -= dt
		if downpour_t <= 0.0:
			_set_rain(false)
	promo_t = maxf(0.0, promo_t - dt)
	if particles != null and race.cam != null:
		particles.global_position = race.cam.global_position + Vector3(0, 14, 0) + race.cam.global_basis.z * -10.0
		if id == "wind" or id == "dust":
			var pm := particles.process_material as ParticleProcessMaterial
			pm.direction = Vector3(sin(wind_dir), -0.15, cos(wind_dir)) if id == "wind" else pm.direction
	if race.authority and race.go:
		if bool(W.get("storm", false)):
			storm_t -= dt
			if storm_t <= 0.0:
				storm_t = rng.randf_range(4.0, 7.0)
				var s: float = race.local.s + rng.randf_range(20.0, 60.0) if race.local != null else rng.randf() * race.track.L
				var i: int = race.track.at_s(s)
				var p: Vector3 = race.track.P[i] + race.track.T[i].cross(Vector3.UP) * rng.randf_range(-3.0, 3.0)
				race._hazard("dust_bomb", p, 4.5, 6.0, null)
		if happen_on and state_ok():
			next_t -= dt
			if next_t <= 0.0:
				next_t = rng.randf_range(18.0, 30.0)
				start(_pick(), -1.0)
	for h in active.duplicate():
		_run(h, dt)

func state_ok() -> bool:
	return race.state == "race" and race.t > 8.0

func _pick() -> String:
	var sum := 0
	var opts: Array = []
	for k in HAPPENINGS:
		var hp: Dictionary = HAPPENINGS[k]
		if k == last_kind or (hp.has("need") and not (id in hp["need"])):
			continue
		opts.append(k)
		sum += int(hp["w"])
	var x := rng.randi_range(1, maxi(1, sum))
	for k in opts:
		x -= int(HAPPENINGS[k]["w"])
		if x <= 0:
			return k
	return "steam"

## множители езды для гонщика: погода, ливень-ситуация, попутный ветер рядом
func mod(k: String) -> float:
	return float(mods.get(k, 1.0))

# ---------------- ситуации ----------------
## Начать ситуацию. s < 0 — место выберет власть: впереди лидера (чтобы её увидели все).
func start(kind: String, s: float, from_net := false) -> void:
	if not HAPPENINGS.has(kind):
		return
	if s < 0.0:
		var lead = race.standings()[0] if not race.riders.is_empty() else null
		s = (lead.s if lead != null else 0.0) + rng.randf_range(70.0, 120.0)
	s = fposmod(s, race.track.L)
	# не на развилке и не на трамплине: там ситуация была бы нечестной
	if race.track.SP.size() > 1 and fposmod(s - race.track.short_from, race.track.L) < fposmod(race.track.short_to - race.track.short_from, race.track.L) + 10.0:
		s = fposmod(race.track.short_to + 25.0, race.track.L)
	var hp: Dictionary = HAPPENINGS[kind]
	var i: int = race.track.at_s(s)
	var h := {"kind": kind, "t": float(hp["t"]), "s": s, "pos": race.track.P[i], "tan": race.track.T[i], "w": race.track.W[i], "nodes": [], "hit": {}, "age": 0.0}
	last_kind = kind
	happen_log.append([kind, s])
	active.append(h)
	_build(h)
	race.hud.happening(String(hp["title"]), String(hp["sub"]))
	if race.main != null and race.sound_on:
		race.main.sfx("sfx_wave", -4.0, 0.8)
	if race.net != null and race.authority and not from_net:
		race.net.send_event(-1, "happening", [kind, s])

func _build(h: Dictionary) -> void:
	var p: Vector3 = h["pos"]
	var t: Vector3 = h["tan"]
	var right: Vector3 = t.cross(Vector3.UP)
	var half: float = float(h["w"]) * 0.5 + RaceTrack.SHOULDER
	match String(h["kind"]):
		"buhanka":
			var body := AnimatableBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.sync_to_physics = false
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = VAN
			cs.shape = bs
			cs.position.y = 1.1
			body.add_child(cs)
			race.add_child(body)
			var yaw := atan2(right.x, right.z)
			body.global_transform = Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), p - right * (half + 4.0))
			if RaceProps.spawn("old_van", body, Vector3.ZERO, PI * 0.5) == null:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = bs.size
				mi.mesh = bm
				mi.position.y = 1.1
				body.add_child(mi)
			h["nodes"] = [body]
			h["from"] = p - right * (half + 4.0)
			h["to"] = p + right * (half + 4.0)
		"steam":
			var st = race.fx
			h["nodes"] = []
			for k in 3:
				st.pillar(p + right * (k - 1) * 3.0, 6.0, Color(0.9, 0.95, 1.0, 0.8), "smoke_04", 1.0)
		"tires":
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			race.add_child(sb)
			for k in 4:
				var off := right * rng.randf_range(-half * 0.7, half * 0.7) + t * rng.randf_range(-6.0, 6.0)
				var cs2 := CollisionShape3D.new()
				var cy := CylinderShape3D.new()
				cy.radius = 0.6
				cy.height = 1.2
				cs2.shape = cy
				cs2.position = p + off + Vector3(0, 0.6, 0)
				sb.add_child(cs2)
				if RaceProps.spawn("tire_stack", sb, p + off, rng.randf() * TAU, 0.85) == null:
					var mi2 := MeshInstance3D.new()
					var tm := TorusMesh.new()
					tm.inner_radius = 0.25
					tm.outer_radius = 0.6
					mi2.mesh = tm
					mi2.position = p + off + Vector3(0, 0.3, 0)
					sb.add_child(mi2)
				race.fx.dust(p + off + Vector3(0, 0.3, 0), 6, race.fx.DUST, 0.8)
			h["nodes"] = [sb]
		"trash":
			var n := Node3D.new()
			race.add_child(n)
			for k in 4:
				var off2 := right * rng.randf_range(-half * 0.6, half * 0.6) + t * rng.randf_range(-5.0, 5.0)
				if RaceProps.spawn("trash_pile", n, p + off2, rng.randf() * TAU, 0.7) == null:
					var mi3 := MeshInstance3D.new()
					var bm3 := BoxMesh.new()
					bm3.size = Vector3(2, 0.5, 1.5)
					mi3.mesh = bm3
					mi3.position = p + off2 + Vector3(0, 0.25, 0)
					n.add_child(mi3)
			h["nodes"] = [n]
		"downpour":
			_set_rain(true)
			downpour_t = float(h["t"])
		"promo":
			promo_t = float(h["t"])
		"tailwind":
			for k in 3:
				race.fx.streaks(p + t * (k * 6.0 - 6.0) + Vector3(0, 1.0, 0), t, 12, Color(0.9, 0.95, 1.0))
		"pigeons":
			race.fx.twinkle(p + Vector3(0, 2.5, 0), 40, Color(0.75, 0.75, 0.8), 6.0)
		"blackout":
			for l in lamps:
				(l as OmniLight3D).visible = false

func _run(h: Dictionary, dt: float) -> void:
	h["t"] = float(h["t"]) - dt
	h["age"] = float(h["age"]) + dt
	var p: Vector3 = h["pos"]
	var t: Vector3 = h["tan"]
	var right: Vector3 = t.cross(Vector3.UP)
	var half: float = float(h["w"]) * 0.5 + RaceTrack.SHOULDER
	match String(h["kind"]):
		"buhanka":
			var body: AnimatableBody3D = h["nodes"][0]
			var u := clampf(float(h["age"]) / (float(HAPPENINGS["buhanka"]["t"]) - 0.5), 0.0, 1.0)
			var xf := body.global_transform
			xf.origin = (h["from"] as Vector3).lerp(h["to"], u)
			body.global_transform = xf
			if race.authority:
				# касание — по коробке машины в её осях (x — вдоль хода), а не по расстоянию до центра: машина толкает
				# гонщика перед собой и держит его на полдлины + радиус, так что «ближе 2,6 м» могло не наступить никогда
				var rad := float(RaceData.PHYS["radius"]) + VAN_HIT
				var inv := xf.affine_inverse()
				for r in race.riders:
					var lp: Vector3 = inv * r.global_position
					var touch := absf(lp.x) < VAN.x * 0.5 + rad and absf(lp.z) < VAN.z * 0.5 + rad and lp.y > -rad * 2.0 and lp.y < VAN.y + rad
					if touch and not (h["hit"] as Dictionary).has(r.slot):
						(h["hit"] as Dictionary)[r.slot] = true
						r.speed *= 0.4
						r.side_v += right * 6.0
						r.ev("hit_van", 0)
		"steam":
			if fmod(float(h["age"]), 0.35) < dt:
				race.fx.dust(p + right * rng.randf_range(-half * 0.6, half * 0.6) + Vector3(0, 0.5, 0), 6, Color(0.92, 0.95, 1.0, 0.8), 1.6, 0.0)
			for r in race.riders:
				if r.disconnected or not (race.authority or r == race.local):
					continue
				var d: Vector3 = r.global_position - p
				if absf(d.dot(t)) < 3.0 and absf(d.dot(right)) < half and r.is_on_floor() and not (h["hit"] as Dictionary).has(r.slot):
					(h["hit"] as Dictionary)[r.slot] = true
					r.pop_v = 10.5
					r.ev("steam", 0)
			# можно снова: раз в 1,2 с
			if fmod(float(h["age"]), 1.2) < dt:
				h["hit"] = {}
		"trash":
			if race.authority:
				for r in race.riders:
					var d2: Vector3 = r.global_position - p
					if absf(d2.dot(t)) < 6.0 and absf(d2.dot(right)) < half:
						r.add_slow("trash", 0.72, 0.4)
		"tailwind":
			for r in race.riders:
				var d3: Vector3 = r.global_position - p
				if absf(d3.dot(t)) < 18.0 and absf(d3.dot(right)) < half and r.vdir.dot(t) > 0.5 and r.boost_t < 0.3:
					r.boost_t = 0.35
			if fmod(float(h["age"]), 0.5) < dt:
				race.fx.streaks(p + t * rng.randf_range(-15.0, 15.0) + Vector3(0, 1.0, 0), t, 6, Color(0.9, 0.95, 1.0))
		"pigeons":
			if fmod(float(h["age"]), 0.4) < dt:
				race.fx.twinkle(p + Vector3(rng.randf_range(-4, 4), 2.5, rng.randf_range(-4, 4)), 20, Color(0.7, 0.7, 0.75), 4.0)
			if race.authority:
				for r in race.riders:
					if (r.global_position - p).length() < half + 3.0:
						r.add_slow("pigeons", 0.85, 0.3)
	if float(h["t"]) <= 0.0:
		_end(h)

func _end(h: Dictionary) -> void:
	active.erase(h)
	for n in h["nodes"]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	if String(h["kind"]) == "blackout":
		for l in lamps:
			(l as OmniLight3D).visible = true

func _set_rain(on: bool) -> void:
	if on:
		mods["grip"] = minf(mod("grip"), 0.7)
		mods["brake"] = minf(mod("brake"), 0.8)
		mods["charge"] = maxf(mod("charge"), 1.3)
		if particles == null:
			particles = _precip("rain")
		if env != null:
			env.fog_density = maxf(env.fog_density, 0.009)
	else:
		for k in ["grip", "brake", "charge"]:
			mods[k] = float(W["mods"].get(k, 1.0))
		if id != "rain" and particles != null:
			particles.queue_free()
			particles = null
		if env != null:
			env.fog_density = float(W.get("fog", 0.0032))

## что выпадет из коробки: во время «акции» — только ТУРБО-БАЛЛОН
func box_item(normal: String) -> String:
	return "turbo_balloon" if promo_t > 0.0 else normal
