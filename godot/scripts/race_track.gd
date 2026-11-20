## Трасса гонки: строится кодом из данных RaceData.TRACKS — дорога (сглаженная замкнутая кривая через опорные
## точки), обочины, стены по краям (4 м в высоту — через них не перепрыгнуть), срезка с канавой и мостиком,
## трамплин, ускорители, препятствия, коробки предметов (их держит race.gd), контрольные точки и оформление
## участков: двор, промзона, гаражи, мусорка, заборы. Здесь же — где на трассе гонщик: project() даёт пройденный
## путь s (на срезке — пересчитанный в путь главной дороги), смещение поперёк и половину ширины.
class_name RaceTrack
extends Node3D

const STEP := 1.0                  # шаг точек кривой, м
const SHOULDER := 1.6              # обочина за краем дороги, м
const WALL_H := 4.0                # высота стен (видимые — ниже: барьеры, гаражи, заборы)
const KILL_Y := -3.0               # ниже — упал: возврат на последнюю контрольную точку
const GATE_GAP := 18.0             # контрольные точки не ближе друг к другу, м

var data: Dictionary = {}
var id := ""
# главная дорога
var P := PackedVector3Array()      # точки центра
var W := PackedFloat32Array()      # ширина в точке
var S := PackedFloat32Array()      # путь от начала кривой
var T := PackedVector3Array()      # касательные
var L := 0.0                       # длина круга
# срезка
var SP := PackedVector3Array()
var SS := PackedFloat32Array()
var ST := PackedVector3Array()
var SL := 0.0
var short_w := 6.0
var short_from := 0.0              # путь главной дороги у развилки и у слияния
var short_to := 0.0
var ditch := Vector2(-1, -1)       # канава на срезке: путь срезки от и до
var plank := 3.0
# разметка
var start_s := 0.0                 # финишная черта
var gates: Array = []              # [{s, pos, tan}]; gates[0] — финиш
var boxes: Array = []              # точки коробок предметов
var pads: Array = []               # [{pos, tan, s}]
var ramps: Array = []              # [{s0, s1, h}]
var rings: Array = []              # кольца для трюков: [{pos, tan, node}]
var has_height := false            # у трассы есть участки выше земли (крыши)
var gaps: Array = []               # разрывы главной дороги: [[s от, s до]]

## попадает ли точка главной дороги в разрыв
func in_gap(i: int) -> bool:
	for g in gaps:
		if S[i] >= float(g[0]) and S[i] <= float(g[1]):
			return true
	return false

## стоит ли на этом месте пути трамплин (с запасом на вылет). На трассах с подъёмами уклон дороги сам по себе не
## трамплин: толчок вверх и трюк даёт только настоящий
func ramp_near(s: float) -> bool:
	for r in ramps:
		if fposmod(s - (float(r["s0"]) - 2.0), L) < float(r["s1"]) - float(r["s0"]) + 6.0:
			return true
	return false

## высота дороги под гонщиком (pr — его проекция): по ней считается «упал»
func road_y(pr: Dictionary) -> float:
	if bool(pr.get("short", false)) or not pr.has("i"):
		return 0.0
	return P[int(pr["i"])].y
var obstacle_pts: Array = []       # [центр, радиус] — для ботов
var fill_counts := {}              # сколько чего поставлено заполнением (для проверки)
var mats := {}
var body: StaticBody3D

func build(track_id: String) -> void:
	id = track_id
	data = RaceData.track(track_id)
	_mats()
	_main_curve()
	_short_curve()
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_env()
	_road()
	_walls()
	_ramps()
	_rings()
	_pads()
	_obstacles()
	_gates()
	_boxes()
	if DisplayServer.get_name() != "headless":        # без экрана (сервер, проверки) оформление не нужно: физики в нём нет
		_decor()
		_decks()
		_signs()
		_landmarks()
		_fill()

# ---------------- кривые ----------------
static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## точки кривой через опорные, примерно через STEP метров; ширина — тоже по кривой
static func _sample(pts: Array, closed: bool) -> Array:
	var cp: Array = []
	var hs := PackedFloat32Array()        # высота опорной точки (четвёртое число; нет — 0): дорога может идти по крышам
	for q in pts:
		cp.append(Vector3(float(q[0]), float(q[2]) if q.size() > 2 else 0.0, float(q[1])))   # y здесь — ширина
		hs.append(float(q[3]) if q.size() > 3 else 0.0)
	var n := cp.size()
	var out_p := PackedVector3Array()
	var out_w := PackedFloat32Array()
	var segs := n if closed else n - 1
	for i in segs:
		var i0 := (i - 1 + n) % n if closed or i > 0 else 0
		var i3 := (i + 2) % n if closed or i + 2 < n else n - 1
		var p0: Vector3 = cp[i0]
		var p1: Vector3 = cp[i]
		var p2: Vector3 = cp[(i + 1) % n]
		var p3: Vector3 = cp[i3]
		var a := Vector3(p1.x, 0, p1.z)
		var b := Vector3(p2.x, 0, p2.z)
		var k: int = maxi(2, int(ceil(a.distance_to(b) / STEP)))
		var h1 := hs[i]
		var h2 := hs[(i + 1) % n]
		for j in k:
			var u := float(j) / float(k)
			var c := _cr(p0, p1, p2, p3, u)
			# высота — той же кривой, но без выбросов за пределы соседних точек (ровная крыша остаётся ровной)
			var hh := clampf(_cr(Vector3(hs[i0], 0, 0), Vector3(h1, 0, 0), Vector3(h2, 0, 0), Vector3(hs[i3], 0, 0), u).x, minf(h1, h2), maxf(h1, h2))
			out_p.append(Vector3(c.x, hh, c.z))
			out_w.append(c.y)
	if not closed:
		var e: Vector3 = cp[n - 1]
		out_p.append(Vector3(e.x, hs[n - 1], e.z))
		out_w.append(e.y)
	return [out_p, out_w]

func _main_curve() -> void:
	var r := _sample(data["pts"], true)
	P = r[0]
	W = r[1]
	var n := P.size()
	S.resize(n)
	T.resize(n)
	var acc := 0.0
	for i in n:
		S[i] = acc
		acc += P[i].distance_to(P[(i + 1) % n])
		var dv := P[(i + 1) % n] - P[(i - 1 + n) % n]
		T[i] = Vector3(dv.x, 0, dv.z).normalized()       # касательная — в плане: «вправо» от неё всегда горизонтально
		if absf(P[i].y) > 0.5:
			has_height = true
	L = acc
	start_s = S[nearest_main(_v(data["start"]))]
	# разрывы дороги (прыжки между крышами): там нет ни полотна, ни стен
	gaps = []
	for g in data.get("gaps", []):
		var gc := S[nearest_main(_v(g["at"]))]
		gaps.append([gc - float(g["len"]) * 0.5, gc + float(g["len"]) * 0.5])

func _short_curve() -> void:
	if not data.has("shortcut"):
		return
	var sc: Dictionary = data["shortcut"]
	short_w = float(sc["width"])
	var pts: Array = []
	for q in sc["pts"]:
		pts.append([q[0], q[1], short_w])
	var r := _sample(pts, false)
	SP = r[0]
	var n := SP.size()
	SS.resize(n)
	ST.resize(n)
	var acc := 0.0
	for i in n:
		SS[i] = acc
		if i + 1 < n:
			acc += SP[i].distance_to(SP[i + 1])
		ST[i] = (SP[mini(i + 1, n - 1)] - SP[maxi(i - 1, 0)]).normalized()
	SL = acc
	short_from = S[nearest_main(SP[0])]
	short_to = S[nearest_main(SP[n - 1])]
	var dt: Array = sc.get("ditch", [])
	if dt.size() == 2:
		ditch = Vector2(float(dt[0]) * SL, float(dt[1]) * SL)
	plank = float(sc.get("plank", 3.0))

static func _v(q: Array) -> Vector3:
	return Vector3(float(q[0]), 0, float(q[1]))

## ближайшая точка главной дороги (полный перебор — для постройки и возврата на трассу)
func nearest_main(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in P.size():
		var d := Vector2(P[i].x - p.x, P[i].z - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	return best

func nearest_short(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in SP.size():
		var d := Vector2(SP[i].x - p.x, SP[i].z - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	return best

static func _local(pts: PackedVector3Array, p: Vector3, hint: int, win: int, closed: bool) -> int:
	var n := pts.size()
	var best := hint
	var bd := INF
	for k in range(-win, win + 1):
		var i := hint + k
		if closed:
			i = posmod(i, n)
		elif i < 0 or i >= n:
			continue
		var d := Vector2(pts[i].x - p.x, pts[i].z - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	return best

## Где гонщик: h — его память о прошлом месте {i, si, short}. Возвращает путь s по главной дороге (на срезке —
## пересчитанный), смещение lat (+ вправо), половину ширины half, касательную tan, на срезке ли short.
func project(p: Vector3, h: Dictionary) -> Dictionary:
	var i := _local(P, p, int(h.get("i", nearest_main(p))), 18, true)
	var right_m: Vector3 = T[i].cross(Vector3.UP)
	var lat_m := (p - P[i]).dot(right_m)
	var half_m: float = W[i] * 0.5
	var r := {"i": i, "s": S[i], "lat": lat_m, "half": half_m, "tan": T[i], "short": false, "si": int(h.get("si", 0)), "w": W[i]}
	if SP.size() > 1:
		var near_short: bool = bool(h.get("short", false)) or Vector2(p.x - SP[0].x, p.z - SP[0].z).length() < 25.0 or Vector2(p.x - SP[SP.size() - 1].x, p.z - SP[SP.size() - 1].z).length() < 25.0 or abs(lat_m) > half_m + SHOULDER + 1.0
		if near_short:
			var si := _local(SP, p, int(h.get("si", nearest_short(p))), 18, false)
			if not bool(h.get("short", false)) and abs(lat_m) > half_m + SHOULDER + 1.0:
				si = nearest_short(p)
			var right_s: Vector3 = ST[si].cross(Vector3.UP)
			var lat_s := (p - SP[si]).dot(right_s)
			var d_s := Vector2(p.x - SP[si].x, p.z - SP[si].z).length()
			var d_m := Vector2(p.x - P[i].x, p.z - P[i].z).length()
			if d_s < d_m and abs(lat_s) < short_w * 0.5 + SHOULDER + 1.5:
				var span := fposmod(short_to - short_from, L)
				r = {"i": i, "s": fposmod(short_from + SS[si] / max(SL, 1.0) * span, L), "lat": lat_s, "half": short_w * 0.5, "tan": ST[si], "short": true, "si": si, "w": short_w, "ss": SS[si]}
			r["si"] = si
	return r

## точка, касательная и ширина главной дороги на пути s
func at_s(s: float) -> int:
	s = fposmod(s, L)
	var lo := 0
	var hi := S.size() - 1
	while lo < hi:
		var m := (lo + hi + 1) >> 1
		if S[m] <= s:
			lo = m
		else:
			hi = m - 1
	return lo

func point(s: float) -> Vector3:
	return P[at_s(s)]

func tangent(s: float) -> Vector3:
	return T[at_s(s)]

func width(s: float) -> float:
	return W[at_s(s)]

## на сколько радиан поворачивает дорога на участке [s, s + ahead] — для ботов
func turn_ahead(s: float, ahead: float) -> float:
	var a := T[at_s(s)]
	var b := T[at_s(s + ahead)]
	return abs(atan2(a.cross(b).y, a.dot(b)))

## точка срезки на её пути
func short_point(ss: float) -> int:
	ss = clampf(ss, 0.0, SL)
	var lo := 0
	var hi := SS.size() - 1
	while lo < hi:
		var m := (lo + hi + 1) >> 1
		if SS[m] <= ss:
			lo = m
		else:
			hi = m - 1
	return lo

## путь от финиша: 0..L
func from_start(s: float) -> float:
	return fposmod(s - start_s, L)

## есть ли здесь пол (канава на срезке — нет, кроме мостика)
func in_ditch(pr: Dictionary) -> bool:
	return bool(pr["short"]) and float(pr.get("ss", -1.0)) > ditch.x and float(pr.get("ss", -1.0)) < ditch.y

# ---------------- материалы и окружение ----------------
func _mat(col: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _mats() -> void:
	var asphalt := _mat(Color(0.13, 0.13, 0.145), 0.85)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	asphalt.albedo_texture = nt
	asphalt.uv1_scale = Vector3(0.25, 0.25, 1)
	mats["road"] = asphalt
	mats["short"] = _mat(Color(0.3, 0.25, 0.19), 1.0)
	mats["shoulder"] = _mat(Color(0.32, 0.27, 0.2), 1.0)
	mats["ground"] = _mat(Color(0.2, 0.23, 0.17), 1.0)
	mats["line"] = _mat(Color(0.92, 0.92, 0.88), 0.6)
	mats["curb_r"] = _mat(Color(0.78, 0.12, 0.12), 0.7)
	mats["curb_w"] = _mat(Color(0.92, 0.92, 0.9), 0.7)
	mats["barrier"] = _mat(Color(0.62, 0.62, 0.6), 0.9)
	mats["garage"] = _mat(Color(0.42, 0.36, 0.3), 0.9)
	mats["garage2"] = _mat(Color(0.33, 0.38, 0.42), 0.9)
	mats["rust"] = _mat(Color(0.5, 0.28, 0.16), 0.8)
	mats["green"] = _mat(Color(0.16, 0.36, 0.22), 0.8)
	mats["metal"] = _mat(Color(0.5, 0.52, 0.55), 0.45)
	mats["pipe"] = _mat(Color(0.62, 0.45, 0.2), 0.6)
	mats["wood"] = _mat(Color(0.45, 0.3, 0.17), 1.0)
	mats["water"] = _mat(Color(0.08, 0.12, 0.13), 0.05)
	var dm := _mat(Color(0.1, 0.22, 0.28), 0.03)
	dm.metallic = 0.4
	mats["ditch"] = dm
	mats["panel"] = _mat(Color(0.55, 0.53, 0.5), 0.95)
	mats["panel2"] = _mat(Color(0.45, 0.5, 0.56), 0.95)
	mats["panel3"] = _mat(Color(0.62, 0.5, 0.48), 0.95)
	mats["window"] = _mat(Color(1.0, 0.78, 0.45), 0.5, 1.6)
	mats["window_off"] = _mat(Color(0.1, 0.11, 0.13), 0.4)
	mats["pad"] = _mat(Color(1.0, 0.82, 0.2), 0.4, 2.2)
	mats["red"] = _mat(Color(0.85, 0.1, 0.12), 0.6, 0.4)
	mats["white"] = _mat(Color(0.95, 0.95, 0.95), 0.7)
	mats["black"] = _mat(Color(0.05, 0.05, 0.06), 0.8)
	mats["cone"] = _mat(Color(1.0, 0.45, 0.1), 0.6)
	mats["lamp"] = _mat(Color(1.0, 0.85, 0.6), 0.4, 3.0)
	mats["snow"] = _mat(Color(0.8, 0.86, 0.96), 0.85)
	if winter():
		# зимний вечер: снег вместо травы и пыли, укатанный снег на обочине, мокрый тёмный асфальт, окна и фонари ярче
		(mats["ground"] as StandardMaterial3D).albedo_color = Color(0.84, 0.86, 0.92)
		(mats["shoulder"] as StandardMaterial3D).albedo_color = Color(0.58, 0.64, 0.76)
		asphalt.albedo_color = Color(0.2, 0.21, 0.27)
		asphalt.roughness = 0.55
		(mats["window"] as StandardMaterial3D).emission_energy_multiplier = 3.2
		(mats["lamp"] as StandardMaterial3D).emission_energy_multiplier = 6.0
		(mats["barrier"] as StandardMaterial3D).albedo_color = Color(0.5, 0.55, 0.66)

## зимний облик трассы (data["look"]["winter"]): снег, синий вечер, голые деревья, сугробы, снегопад
func winter() -> bool:
	return bool((data.get("look", {}) as Dictionary).get("winter", false))

## зимой вдоль дороги — фонари с настоящим тёплым светом: пятна на снегу против синих сумерек (без теней — дёшево)
func _street_lights() -> void:
	var s := 12.0
	var k := 0
	while s < L:
		var i := at_s(s)
		s += 34.0
		k += 1
		if in_gap(i) or _zone_of(i) == "scaffold":
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var right: Vector3 = T[i].cross(Vector3.UP)
		var p: Vector3 = P[i] + right * side * (W[i] * 0.5 + SHOULDER + 1.1)
		_lamp(p, atan2(right.x * -side, right.z * -side))
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.72, 0.4)
		ol.light_energy = 6.0
		ol.omni_range = 24.0
		ol.omni_attenuation = 1.3
		ol.position = p + Vector3(0, 4.6, 0) - right * side * 1.5
		add_child(ol)

var snow_fx: CPUParticles3D
func _snowfall() -> void:
	snow_fx = CPUParticles3D.new()
	snow_fx.amount = 900
	snow_fx.lifetime = 5.0
	snow_fx.preprocess = 5.0
	snow_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_fx.emission_box_extents = Vector3(34, 1, 34)
	snow_fx.direction = Vector3(0.25, -1, 0.1)
	snow_fx.spread = 12.0
	snow_fx.gravity = Vector3(0, -1.2, 0)
	snow_fx.initial_velocity_min = 2.5
	snow_fx.initial_velocity_max = 4.5
	snow_fx.scale_amount_min = 0.6
	snow_fx.scale_amount_max = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	qm.material = fm
	snow_fx.mesh = qm
	snow_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snow_fx)

func _process(_dt: float) -> void:
	if snow_fx != null:
		var c := get_viewport().get_camera_3d()
		if c != null:
			snow_fx.global_position = c.global_position + Vector3(0, 14, 0) - c.global_transform.basis.z * 14.0

static func _col(a) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))

func _env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.28, 0.48)
	sm.sky_horizon_color = Color(0.98, 0.62, 0.4)
	sm.ground_bottom_color = Color(0.12, 0.12, 0.14)
	sm.ground_horizon_color = Color(0.55, 0.5, 0.52)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.55, 0.64)
	env.fog_density = 0.0032
	# у трассы может быть свой вид неба и света (data["look"]) — чтобы трассы отличались с первого взгляда
	var look: Dictionary = data.get("look", {})
	if look.has("sky_top"):
		sm.sky_top_color = _col(look["sky_top"])
		sm.sky_horizon_color = _col(look["sky_horizon"])
		env.fog_light_color = _col(look["fog"])
		env.fog_density = float(look.get("fog_density", 0.0032))
	if winter():
		sm.ground_bottom_color = Color(0.05, 0.07, 0.14)
		sm.ground_horizon_color = _col(look["sky_horizon"]).darkened(0.25)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.42, 0.47, 0.62)
		env.ambient_light_energy = 0.75
		env.glow_intensity = 0.95
		env.glow_hdr_threshold = 0.85
		env.adjustment_enabled = true
		env.adjustment_saturation = 0.95
		env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = _col(look["sun"]) if look.has("sun") else Color(1.0, 0.8, 0.62)
	sun.light_energy = float(look.get("sun_energy", 1.25))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-60), 0)
	if winter():
		sun.rotation = Vector3(deg_to_rad(-24), deg_to_rad(140), 0)      # низкая луна с другой стороны: длинные синие тени
	add_child(sun)
	if winter():
		_snowfall()
		_street_lights()
	# земля вокруг (только вид: ездить по ней нельзя — стены)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	g.mesh = pm
	g.position = Vector3(40, -0.06, 60)
	g.material_override = mats["ground"]
	add_child(g)

# ---------------- дорога ----------------
## лента вдоль кривой: от lat_a до lat_b (смещение поперёк), skip — какие участки не строить
func _ribbon(pts: PackedVector3Array, tans: PackedVector3Array, widths, closed: bool, a_k: float, a_add: float, b_k: float, b_add: float, y: float, mat: Material, collide: bool, skip := Callable()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var n := pts.size()
	var segs := n if closed else n - 1
	var dist := 0.0
	for i in segs:
		var j := (i + 1) % n
		if skip.is_valid() and skip.call(i):
			dist += pts[i].distance_to(pts[j])
			continue
		var wi: float = widths[i] if widths is PackedFloat32Array else float(widths)
		var wj: float = widths[j] if widths is PackedFloat32Array else float(widths)
		var ri: Vector3 = tans[i].cross(Vector3.UP)
		var rj: Vector3 = tans[j].cross(Vector3.UP)
		var a0: Vector3 = pts[i] + ri * (wi * 0.5 * a_k + a_add) + Vector3(0, y, 0)
		var b0: Vector3 = pts[i] + ri * (wi * 0.5 * b_k + b_add) + Vector3(0, y, 0)
		var a1: Vector3 = pts[j] + rj * (wj * 0.5 * a_k + a_add) + Vector3(0, y, 0)
		var b1: Vector3 = pts[j] + rj * (wj * 0.5 * b_k + b_add) + Vector3(0, y, 0)
		var d1 := dist + pts[i].distance_to(pts[j])
		st.set_normal(Vector3.UP)
		# порядок вершин — по часовой, если смотреть сверху (лицевая сторона в Godot): раньше был обратный, и всё
		# полотно — асфальт, обочины, бордюры, разметка — отсекалось как изнанка: ездили по голой земле
		for v in [[a0, Vector2(0, dist)], [b1, Vector2(1, d1)], [b0, Vector2(1, dist)], [a0, Vector2(0, dist)], [a1, Vector2(0, d1)], [b1, Vector2(1, d1)]]:
			st.set_uv(v[1] * Vector2(wi, 1.0) * 0.25)
			st.add_vertex(v[0])
		faces.append_array(PackedVector3Array([a0, b1, b0, a0, a1, b1]))
		dist = d1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	if collide and faces.size() > 0:
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.set_faces(faces)
		sh.backface_collision = true
		cs.shape = sh
		body.add_child(cs)

func _road() -> void:
	# главная дорога, обочины, бордюры, разметка
	var gap_skip := Callable() if gaps.is_empty() else (func(i): return in_gap(i))
	_ribbon(P, T, W, true, -1.0, 0.0, 1.0, 0.0, 0.0, mats["road"], true, gap_skip)
	_ribbon(P, T, W, true, -1.0, -SHOULDER, -1.0, 0.0, -0.01, mats["shoulder"], true, gap_skip)
	_ribbon(P, T, W, true, 1.0, 0.0, 1.0, SHOULDER, -0.01, mats["shoulder"], true, gap_skip)
	for side in [-1.0, 1.0]:
		_ribbon(P, T, W, true, side, -0.45 if side > 0 else 0.0, side, 0.0 if side > 0 else 0.45, 0.012, mats["curb_r"], false, func(i): return (i / 3) % 2 == 0 or in_gap(i))
		_ribbon(P, T, W, true, side, -0.45 if side > 0 else 0.0, side, 0.0 if side > 0 else 0.45, 0.012, mats["curb_w"], false, func(i): return (i / 3) % 2 == 1 or in_gap(i))
	_ribbon(P, T, W, true, 0.0, -0.12, 0.0, 0.12, 0.01, mats["line"], false, func(i): return (i / 3) % 2 == 0 or in_gap(i))
	# финишная черта — шашки
	var fi := at_s(start_s)
	for k in 14:
		for row in 2:
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(W[fi] / 14.0, 0.9)
			q.mesh = pm
			q.material_override = mats["white"] if (k + row) % 2 == 0 else mats["black"]
			var right: Vector3 = T[fi].cross(Vector3.UP)
			q.position = P[fi] + right * (-W[fi] * 0.5 + (k + 0.5) * W[fi] / 14.0) + T[fi] * (row - 0.5) * 0.9 + Vector3(0, 0.02, 0)
			q.rotation.y = atan2(T[fi].x, T[fi].z)
			add_child(q)
	if SP.size() > 1:
		var skip_ditch := func(i): return SS[i] > ditch.x and SS[i] < ditch.y
		_ribbon(SP, ST, short_w, false, -1.0, 0.0, 1.0, 0.0, 0.015, mats["short"], true, skip_ditch)
		_ribbon(SP, ST, short_w, false, -1.0, -SHOULDER, -1.0, 0.0, 0.005, mats["shoulder"], true, skip_ditch)
		_ribbon(SP, ST, short_w, false, 1.0, 0.0, 1.0, SHOULDER, 0.005, mats["shoulder"], true, skip_ditch)
		# канава: вода внизу, мостик поперёк
		var i0 := short_point(ditch.x)
		var i1 := short_point(ditch.y)
		var mid: Vector3 = (SP[i0] + SP[i1]) * 0.5
		var ln := SP[i0].distance_to(SP[i1])
		var yaw := atan2(ST[(i0 + i1) / 2].x, ST[(i0 + i1) / 2].z)
		# вода в канаве — у самой поверхности: её видно, а дна под ней нет — кто не попал на мостик, тонет
		var water := _box(mid + Vector3(0, -0.07, 0), Vector3(short_w + SHOULDER * 2.0 + 1.0, 0.04, ln + 0.5), yaw, mats["ditch"], false)
		water.name = "Ditch"
		_box(mid + Vector3(0, -0.12, 0), Vector3(plank, 0.24, ln + 1.2), yaw, mats["wood"], true)
		for sd in [-1.0, 1.0]:
			var right2: Vector3 = ST[(i0 + i1) / 2].cross(Vector3.UP)
			_box(mid + right2 * sd * (short_w * 0.5 + SHOULDER) + Vector3(0, -0.8, 0), Vector3(0.4, 1.6, ln + 0.6), yaw, mats["black"], false)
		var sign := Label3D.new()
		sign.text = "ОСТОРОЖНО: КАНАВА"
		sign.font_size = 44
		sign.pixel_size = 0.008
		sign.modulate = Color(1.0, 0.85, 0.2)
		sign.outline_size = 14
		var si := short_point(ditch.x - 10.0)
		sign.position = SP[si] + ST[si].cross(Vector3.UP) * (short_w * 0.5 + SHOULDER + 0.6) + Vector3(0, 1.8, 0)
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(sign)

## стена или блок: видимый ящик и (по желанию) столкновение
func _box(pos: Vector3, size: Vector3, yaw: float, mat: Material, collide: bool, vis := true) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	if vis:
		mi = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos
		mi.rotation.y = yaw
		add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		cs.rotation.y = yaw
		body.add_child(cs)
	return mi

# ---------------- стены ----------------
## внутри ли точка другой дороги (там стену не ставим — развилка и слияние срезки)
func _inside_other(p: Vector3, other_short: bool) -> bool:
	if other_short:
		if SP.size() < 2:
			return false
		var si := nearest_short(p)
		var lat := absf((p - SP[si]).dot(ST[si].cross(Vector3.UP)))
		var along := (p - SP[si]).dot(ST[si])
		return lat < short_w * 0.5 + SHOULDER + 0.8 and absf(along) < 2.5
	var i := nearest_main(p)
	return absf((p - P[i]).dot(T[i].cross(Vector3.UP))) < W[i] * 0.5 + SHOULDER + 0.8

func _walls() -> void:
	var mm_pts: Array = []             # [позиция, поворот] видимых бетонных блоков
	_wall_line(P, T, W, true, false, mm_pts)
	if SP.size() > 1:
		_wall_line(SP, ST, PackedFloat32Array([short_w]), false, true, mm_pts)
	# бетонные блоки — одним MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.9, 2.05)
	mm.mesh = bm
	mm.instance_count = mm_pts.size()
	for k in mm_pts.size():
		var b := Basis(Vector3.UP, float(mm_pts[k][1]))
		mm.set_instance_transform(k, Transform3D(b, mm_pts[k][0] + Vector3(0, 0.45, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mats["barrier"]
	add_child(mmi)

func _wall_line(pts: PackedVector3Array, tans: PackedVector3Array, widths: PackedFloat32Array, closed: bool, is_short: bool, mm_pts: Array) -> void:
	var n := pts.size()
	var stride := 2
	var i := 0
	while i < (n if closed else n - 1):
		var j := mini(i + stride, n - 1) if not closed else (i + stride) % n
		var wi: float = widths[i] if widths.size() > 1 else widths[0]
		for side in [-1.0, 1.0]:
			var ri: Vector3 = tans[i].cross(Vector3.UP)
			var rj: Vector3 = tans[j].cross(Vector3.UP)
			var wj: float = widths[j] if widths.size() > 1 else widths[0]
			var a: Vector3 = pts[i] + ri * side * (wi * 0.5 + SHOULDER + 0.3)
			var b: Vector3 = pts[j] + rj * side * (wj * 0.5 + SHOULDER + 0.3)
			var mid := (a + b) * 0.5
			if _inside_other(mid, not is_short):
				continue
			if is_short and (i < 3 or i > n - 5):
				continue                       # концы срезки открыты в главную дорогу
			if not is_short and not gaps.is_empty() and (in_gap(i) or in_gap(j)):
				continue                       # над разрывом стен нет — там летят
			var ln := a.distance_to(b) + 0.15
			var yaw := atan2(b.x - a.x, b.z - a.z)
			_box(mid + Vector3(0, WALL_H * 0.5, 0), Vector3(0.6, WALL_H, ln), yaw, null, true, false)
			mm_pts.append([mid, yaw])
		i += stride

# ---------------- трамплины, ускорители, препятствия ----------------
func _ramps() -> void:
	for r in data.get("ramps", []):
		var c := nearest_main(_v(r["at"]))
		var s0: float = S[c] - float(r["len"]) * 0.5
		var s1: float = s0 + float(r["len"])
		var h: float = float(r["h"])
		var i0 := at_s(s0)
		var i1 := at_s(s1)
		var w: float = W[c] + SHOULDER * 2.0
		var t0: Vector3 = T[i0]
		var right: Vector3 = T[c].cross(Vector3.UP)
		var p0: Vector3 = P[i0]
		var p1: Vector3 = P[i1]
		var pts := PackedVector3Array([
			p0 - right * w * 0.5, p0 + right * w * 0.5,
			p1 - right * w * 0.5, p1 + right * w * 0.5,
			p1 - right * w * 0.5 + Vector3(0, h, 0), p1 + right * w * 0.5 + Vector3(0, h, 0),
		])
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = pts
		cs.shape = sh
		body.add_child(cs)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri in [[0, 4, 1], [1, 4, 5], [2, 3, 4], [3, 5, 4], [0, 2, 4], [1, 5, 3]]:
			for k in tri:
				st.add_vertex(pts[k])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats["wood"]
		add_child(mi)
		# полосы на трамплине
		for k in 5:
			var u := (k + 0.5) / 5.0
			var q := _box(p0.lerp(p1, u) + Vector3(0, h * u + 0.03, 0), Vector3(w * 0.9, 0.05, 0.35), atan2(t0.x, t0.z), mats["curb_r"] if k % 2 == 0 else mats["white"], false)
			q.rotation.x = -atan2(h, float(r["len"]))
		ramps.append({"s0": s0, "s1": s1, "h": h})
		var lab := Label3D.new()
		lab.text = "ТРАМПЛИН"
		lab.font_size = 110
		lab.pixel_size = 0.01
		lab.modulate = Color(1, 0.9, 0.3)
		lab.outline_size = 20
		lab.position = P[at_s(s0 - 10.0)] + Vector3(0, 3.2, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(lab)

## кольца над полётом с трамплина. Модель — race_trick_ring.glb, если есть; иначе кольцо собирается из деталей:
## полосатый обод, лампочки по кругу, две стойки до земли.
func _rings() -> void:
	var R: float = float(RaceData.PHYS["ring_r"])
	for q in data.get("rings", []):
		if int(q[0]) >= ramps.size():
			continue
		var rp: Dictionary = ramps[int(q[0])]
		var i := at_s(float(rp["s1"]) + float(q[1]))
		var right: Vector3 = T[i].cross(Vector3.UP)
		var c: Vector3 = P[i] + right * float(q[3]) + Vector3(0, float(q[2]), 0)
		var n := Node3D.new()
		n.position = c
		n.rotation.y = atan2(T[i].x, T[i].z)
		add_child(n)
		var file := "res://assets/racing/race_trick_ring.glb"
		if ResourceLoader.exists(file):
			# модель владельца: отверстие у неё смотрит вдоль X — разворот на четверть; обод вписан так, чтобы
			# дыра была радиусом R (как у кольца из деталей), центр дыры — в точке кольца; стойки до земли — свои
			var g: Node3D = (load(file) as PackedScene).instantiate()
			var bb := RaceTomsk._box_of(g, Transform3D.IDENTITY)
			var k: float = (R + 0.25) / (0.3 * bb.size.y)
			var hold := Node3D.new()
			hold.rotation.y = PI * 0.5
			n.add_child(hold)
			hold.add_child(g)
			g.scale = Vector3.ONE * k
			g.position = -Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.53, bb.get_center().z) * k
			for sx in [-1.0, 1.0]:
				var hgt2: float = maxf(0.3, float(q[2]) - R * 0.9)
				RaceItems.cyl(n, 0.08, 0.1, hgt2, mats["metal"] if mats.has("metal") else RaceItems.mat("steel", Color(0.62, 0.64, 0.68), 0.35, 0.8), Vector3(sx * R * 0.6, -R * 0.9 - hgt2 * 0.5, 0))
		else:
			for k in 12:
				var a0 := TAU * k / 12.0
				var seg := RaceItems.cyl(n, 0.16, 0.16, R * TAU / 12.0 + 0.05, RaceItems.mat("ring_r" if k % 2 == 0 else "ring_w", Color(0.9, 0.12, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.92), 0.5, 0.2, 0.25), Vector3(cos(a0) * R, sin(a0) * R, 0), Vector3(0, 0, a0))
				seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				RaceItems.ball(n, 0.09, RaceItems.mat("ring_bulb", Color(1.0, 0.9, 0.5), 0.3, 0.0, 2.0), Vector3(cos(a0 + 0.26) * (R + 0.02), sin(a0 + 0.26) * (R + 0.02), 0.17))
			for sx in [-1.0, 1.0]:
				var hgt: float = maxf(0.3, float(q[2]) - R * 0.7)
				RaceItems.cyl(n, 0.08, 0.1, hgt, mats["metal"] if mats.has("metal") else RaceItems.mat("steel", Color(0.62, 0.64, 0.68), 0.35, 0.8), Vector3(sx * R * 0.72, -R * 0.7 - hgt * 0.5, 0))
		rings.append({"pos": c, "tan": T[i], "node": n})

func _pads() -> void:
	for q in data.get("pads", []):
		var i := nearest_main(_v(q))
		var yaw := atan2(T[i].x, T[i].z)
		for k in 3:
			var ch := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(2.2, 1.1, 0.06)
			ch.mesh = pm
			ch.material_override = mats["pad"]
			ch.position = P[i] + T[i] * (k - 1) * 1.3 + Vector3(0, 0.03, 0)
			ch.rotation = Vector3(-PI * 0.5, yaw, 0)
			add_child(ch)
		pads.append({"pos": P[i], "tan": T[i], "s": S[i]})

func _obstacles() -> void:
	for o in data.get("obstacles", []):
		var i := nearest_main(_v(o[0]))
		var right: Vector3 = T[i].cross(Vector3.UP)
		var c: Vector3 = P[i] + right * float(o[1]) * W[i] * 0.5
		if String(o[2]) != "cones":
			obstacle_pts.append([c, 1.9])
		match String(o[2]):
			"barrels":
				for k in 3:
					var p := c + right * (k - 1) * 1.0 + T[i] * (k % 2) * 0.8
					_cyl(p, 0.42, 1.1, mats["rust"] if k != 1 else mats["green"], true, not RaceProps.has("barrel"))
					RaceProps.spawn("barrel", self, p, float(k) * 1.7)
			"tires":
				for k in 3:
					if RaceProps.has("tire_stack"):
						RaceProps.spawn("tire_stack", self, c + right * (k - 1) * 1.15, float(k) * 2.1, 0.9)
					for h in (0 if RaceProps.has("tire_stack") else 2):
						var tm := MeshInstance3D.new()
						var tor := TorusMesh.new()
						tor.inner_radius = 0.25
						tor.outer_radius = 0.55
						tm.mesh = tor
						tm.material_override = mats["black"]
						tm.position = c + right * (k - 1) * 1.15 + Vector3(0, 0.15 + h * 0.3, 0)
						add_child(tm)
					var cs := CollisionShape3D.new()
					var sh := CylinderShape3D.new()
					sh.radius = 0.55
					sh.height = 0.6
					cs.shape = sh
					cs.position = c + right * (k - 1) * 1.15 + Vector3(0, 0.3, 0)
					body.add_child(cs)
			"cones":
				for k in 4:
					if RaceProps.spawn("traffic_cone", self, c + right * (k - 1.5) * 1.6, float(k)) != null:
						continue
					var cm := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.03
					cyl.bottom_radius = 0.22
					cyl.height = 0.6
					cm.mesh = cyl
					cm.material_override = mats["cone"]
					cm.position = c + right * (k - 1.5) * 1.6 + Vector3(0, 0.3, 0)
					add_child(cm)

func _cyl(p: Vector3, r: float, h: float, mat: Material, collide: bool, vis := true) -> void:
	if vis:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = h
		mi.mesh = cm
		mi.material_override = mat
		mi.position = p + Vector3(0, h * 0.5, 0)
		add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		cs.position = p + Vector3(0, h * 0.5, 0)
		body.add_child(cs)

# ---------------- контрольные точки, коробки ----------------
func _gates() -> void:
	var n: int = int(data.get("gates", 10))
	var cands: Array = []
	for k in n * 3:
		var s := fposmod(start_s + L * float(k) / float(n * 3), L)
		cands.append(s)
	# контрольные точки не ставим на участке, который срезка обходит: обе дороги должны засчитываться одинаково
	var span := fposmod(short_to - short_from, L) if SP.size() > 1 else 0.0
	gates = []
	for k in n:
		var want := fposmod(start_s + L * float(k) / float(n), L)
		var s := want
		if span > 0.0:
			var rel := fposmod(s - short_from, L)
			if rel > -4.0 and rel < span + 4.0:
				s = fposmod(short_from - 6.0, L) if rel < span * 0.5 else fposmod(short_to + 6.0, L)
		# не в провале между крышами и не на разбеге перед ним: вернувшийся на точку должен успеть разогнаться для прыжка
		for g in gaps:
			if fposmod(s - (float(g[0]) - 28.0), L) < float(g[1]) - float(g[0]) + 32.0:
				s = fposmod(float(g[0]) - 30.0, L)
		if k == 0:
			s = start_s
		var i := at_s(s)
		gates.append({"s": S[i], "pos": P[i], "tan": T[i], "w": W[i]})
	gates.sort_custom(func(a, b): return from_start(a["s"]) < from_start(b["s"]))
	# Две точки не могут стоять в одном месте: вторую тогда засчитало бы только на следующем витке, и каждый «круг»
	# требовал бы двух проездов трассы (так и было: точки, сдвинутые с участка срезки, вставали на одно место).
	# Оставляем точки не ближе GATE_GAP друг к другу и к финишу.
	var kept: Array = [gates[0]]
	for k in range(1, gates.size()):
		var fs := from_start(float(gates[k]["s"]))
		if fs - from_start(float(kept.back()["s"])) >= GATE_GAP and L - fs >= GATE_GAP:
			kept.append(gates[k])
	gates = kept
	# арка над финишем
	var g0: Dictionary = gates[0]
	var right: Vector3 = (g0["tan"] as Vector3).cross(Vector3.UP)
	var yaw := atan2(g0["tan"].x, g0["tan"].z)
	for sd in [-1.0, 1.0]:
		_box(g0["pos"] + right * sd * (float(g0["w"]) * 0.5 + SHOULDER + 0.6) + Vector3(0, 3.0, 0), Vector3(0.5, 6.0, 0.5), yaw, mats["metal"], true)
	_box(g0["pos"] + Vector3(0, 6.0, 0), Vector3(float(g0["w"]) + SHOULDER * 2.0 + 1.8, 1.3, 0.4), yaw, mats["red"], false)
	var ban := Label3D.new()
	ban.text = String(data["name"])
	ban.font_size = 120
	ban.pixel_size = 0.009
	ban.outline_size = 16
	ban.double_sided = false
	ban.position = g0["pos"] + Vector3(0, 6.0, 0) - (g0["tan"] as Vector3) * 0.25
	ban.rotation.y = yaw + PI
	add_child(ban)
	var ban2: Label3D = ban.duplicate()
	ban2.position = g0["pos"] + Vector3(0, 6.0, 0) + (g0["tan"] as Vector3) * 0.25
	ban2.rotation.y = yaw
	add_child(ban2)
	_start_dress()

## Стартовые огни над дорогой чуть впереди линии и трибуны по обе стороны стартовой прямой со зрителями —
## из моделей владельца (race_start_lights / race_grandstand / npc_spectator); нет файлов — ничего не ставится.
func _start_dress() -> void:
	var fi := at_s(start_s + 14.0)
	var right: Vector3 = T[fi].cross(Vector3.UP)
	var yaw := atan2(T[fi].x, T[fi].z)
	var span: float = W[fi] + SHOULDER * 2.0 + 2.4
	place_glb("res://assets/racing/race_start_lights.glb", P[fi], yaw, Vector3(span, 9.0, 12.0))
	for sd in [-1.0, 1.0]:
		var gi := at_s(start_s - 22.0 + sd * 6.0)
		var r2: Vector3 = T[gi].cross(Vector3.UP)
		var face: Vector3 = -r2 * sd
		var gp: Vector3 = P[gi] + r2 * sd * (W[gi] * 0.5 + SHOULDER + 7.5)
		gp.y = 0.0
		var st := place_glb("res://assets/racing/race_grandstand.glb", gp, atan2(face.x, face.z), Vector3(13.0, 6.0, 8.0))
		if st == null:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id) + int(sd * 7.0)
		for q in 5:
			var row := q % 3
			var lp := Vector3(-4.0 + q * 2.0 + rng.randf_range(-0.4, 0.4), 1.0 + row * 1.15, 1.6 - row * 1.5)
			var fan := place_glb("res://assets/racing/npc_spectator.glb", st.transform * lp, atan2(face.x, face.z) + rng.randf_range(-0.4, 0.4), Vector3(1.2, 1.55, 1.2))
			if fan != null:
				fan.add_to_group("race_fans")

## поставить модель из файла: основанием в точку, лицом по yaw, вписать в размер size (x — ширина, y — высота,
## z — глубина; по высоте, не шире и не глубже). Модели владельца с сайта Tripo смотрят лицом по +X — turn
## доворачивает лицо на +Z узла (RaceTomsk.FRONT). Нет файла — null.
func place_glb(path: String, pos: Vector3, yaw: float, size: Vector3, turn := RaceTomsk.FRONT) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var g: Node3D = (load(path) as PackedScene).instantiate()
	var bb := RaceTomsk._box_of(g, Transform3D.IDENTITY)
	var bs := bb.size
	if absf(fmod(absf(turn), PI) - PI * 0.5) < 0.1:
		bs = Vector3(bs.z, bs.y, bs.x)
	var k: float = minf(size.y / maxf(bs.y, 0.001), minf(size.x / maxf(bs.x, 0.001), size.z / maxf(bs.z, 0.001)))
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var hold := Node3D.new()
	hold.rotation.y = turn
	n.add_child(hold)
	hold.add_child(g)
	g.scale = Vector3.ONE * k
	g.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * k
	return n

func _boxes() -> void:
	boxes = []
	for q in data.get("items", []):
		var i := nearest_main(_v(q))
		var right: Vector3 = T[i].cross(Vector3.UP)
		for k in 5:
			boxes.append(P[i] + right * (k - 2) * (W[i] * 0.18) + Vector3(0, 0.9, 0))

## стартовые места: два ряда за финишной чертой
func grid(k: int) -> Transform3D:
	var s := start_s - 5.0 - float(k / 2) * 5.0
	var i := at_s(s)
	var right: Vector3 = T[i].cross(Vector3.UP)
	var p: Vector3 = P[i] + right * (-2.4 if k % 2 == 0 else 2.4) + T[i] * (0.0 if k % 2 == 0 else -2.0)
	return Transform3D(Basis(Vector3.UP, atan2(T[i].x, T[i].z)), p + Vector3(0, 0.05, 0))

## куда вернуть упавшего: на контрольную точку, по центру, носом по трассе
func respawn(gate_k: int) -> Transform3D:
	var g: Dictionary = gates[posmod(gate_k, gates.size())]
	var t: Vector3 = g["tan"]
	return Transform3D(Basis(Vector3.UP, atan2(t.x, t.z)), (g["pos"] as Vector3) + Vector3(0, 0.3, 0))

# ---------------- оформление ----------------
func _zone_of(i: int) -> String:
	for z in data.get("zones", []):
		var a := S[nearest_main(_v(z["from"]))]
		var b := S[nearest_main(_v(z["to"]))]
		var span := fposmod(b - a, L)
		if fposmod(S[i] - a, L) <= span:
			return String(z["kind"])
	return "yard"

## место свободно от дорог: дальше margin от края главной дороги (любого её участка) и срезки
func _free(p: Vector3, margin: float) -> bool:
	var i := nearest_main(p)
	if Vector2(p.x - P[i].x, p.z - P[i].z).length() < W[i] * 0.5 + SHOULDER + margin:
		return false
	if SP.size() > 1:
		var si := nearest_short(p)
		if Vector2(p.x - SP[si].x, p.z - SP[si].z).length() < short_w * 0.5 + SHOULDER + margin:
			return false
	return true

func _decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var graf: Array = data.get("graffiti", [])
	var gk := 0
	var i := 0
	var n := P.size()
	var bridges := 0
	while i < n:
		var kind := _zone_of(i)
		if kind in ["roof", "scaffold"]:
			i += 8                             # крыши и леса оформляет _decks
			continue
		var right: Vector3 = T[i].cross(Vector3.UP)
		var yaw := atan2(T[i].x, T[i].z)
		# трубопровод над дорогой в промзоне — дважды за круг
		if kind == "industrial" and i % 48 == 16 and bridges < 2 and RaceProps.has("pipe_bridge"):
			bridges += 1
			var span := W[i] + SHOULDER * 2.0 + 2.0
			RaceProps.spawn("pipe_bridge", self, P[i], yaw, span / 16.0)
		for side in [-1.0, 1.0]:
			var edge: Vector3 = P[i] + right * side * (W[i] * 0.5 + SHOULDER + 1.4)
			var out: Vector3 = right * side
			var face := atan2(-out.x, -out.z)            # лицом к дороге
			if not _free(edge + out * 2.5, 0.8) or not _free(edge + out * 5.0, 0.8):
				continue
			match kind:
				"garages":
					var gp: Vector3 = edge + out * 2.6
					_box(gp + Vector3(0, 1.4, 0), Vector3(5.0, 2.8, 3.6), yaw, mats["garage"] if (i / 4) % 2 == 0 else mats["garage2"], true, not RaceProps.has("garage"))
					if RaceProps.has("garage"):
						RaceProps.spawn("garage", self, gp, face, rng.randf_range(0.95, 1.08))
					else:
						var door := _box(edge + out * 0.78 + Vector3(0, 1.1, 0), Vector3(0.06, 2.0, 3.0), yaw, mats["rust"], false)
						door.rotation.y = yaw
					if rng.randf() < 0.45 and graf.size() > 0:
						_graffiti(edge + out * 0.62 + Vector3(0, 2.4, 0), yaw + (PI * 0.5 if side > 0 else -PI * 0.5), String(graf[gk % graf.size()]), rng)
						gk += 1
				"industrial":
					if (i / 8) % 4 == (0 if side > 0 else 2):
						var tank_p: Vector3 = edge + out * 6.0
						if _free(tank_p, 2.5):
							_cyl(tank_p, 2.2, 6.5, mats["metal"], true, not RaceProps.has("water_tank"))
							RaceProps.spawn("water_tank", self, tank_p, face + rng.randf() * TAU)
					elif (i / 8) % 4 == 1 and RaceProps.has("factory_hall") and _free(edge + out * 14.0, 9.0):
						var fp: Vector3 = edge + out * 14.0
						_box(fp + Vector3(0, 5.0, 0), Vector3(14.0, 10.0, 20.0), yaw, null, true, false)
						RaceProps.spawn("factory_hall", self, fp, face)
					elif not RaceProps.has("pipe_bridge"):
						var pp := _box(edge + out * 3.0 + Vector3(0, 3.6, 0), Vector3(0.7, 0.7, 8.0), yaw, mats["pipe"], false)
						pp.rotation.y = yaw
						_box(edge + out * 3.0 + Vector3(0, 1.8, 0), Vector3(0.3, 3.6, 0.3), yaw, mats["metal"], false)
				"dump":
					if rng.randf() < 0.6:
						var dp: Vector3 = edge + out * 2.0
						if RaceProps.spawn("dumpster", self, dp, face + rng.randf_range(-0.3, 0.3)) == null:
							_box(dp + Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.2), yaw + rng.randf_range(-0.3, 0.3), mats["green"], false)
					if rng.randf() < 0.5:
						var tp: Vector3 = edge + out * 4.2
						if RaceProps.spawn("trash_pile", self, tp, rng.randf() * TAU, rng.randf_range(0.8, 1.2)) == null:
							_box(tp + Vector3(0, 0.4, 0), Vector3(2.5, 0.8, 2.0), rng.randf() * TAU, mats["black"], false)
					elif rng.randf() < 0.3:
						RaceProps.spawn("old_car", self, edge + out * 3.5, face + PI * 0.5 + rng.randf_range(-0.4, 0.4))
				"fence":
					var fp2: Vector3 = edge + out * 0.6
					if RaceProps.has("fence_section"):
						# секции забора вдоль дороги: две на шаг 8 м
						for q in 2:
							RaceProps.spawn("fence_section", self, fp2 + T[i] * (q - 0.5) * 4.0, yaw + PI * 0.5, 4.0 / 6.0 * 1.02)
					else:
						var f := _box(fp2 + Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 8.0), yaw, mats["wood"], false)
						f.rotation.y = yaw
					if rng.randf() < 0.3 and graf.size() > 0:
						_graffiti(edge + out * 0.4 + Vector3(0, 1.3, 0), yaw + (PI * 0.5 if side > 0 else -PI * 0.5), String(graf[gk % graf.size()]), rng)
						gk += 1
					if rng.randf() < 0.15:
						RaceProps.spawn("old_car", self, edge + out * 4.0, face + PI * 0.5 + rng.randf_range(-0.3, 0.3))
				_:
					if (i / 6) % 3 == 0:
						if RaceProps.spawn("street_lamp", self, edge + out * 0.8, face) == null:
							_lamp(edge + out * 0.8, yaw)
					elif (i / 8) % 5 == 2 and _free(edge + out * 3.0, 1.5):
						RaceProps.spawn("bus_stop" if side > 0 else "kiosk", self, edge + out * 3.0, face)
			# дома вдали — без моделей коробками (с моделями дома ставит _fill)
			if (i / 24) % 2 == 0 and i % 24 == 0 and not RaceProps.has("khrushchevka"):
				var hp: Vector3 = P[i] + right * side * (W[i] * 0.5 + 26.0)
				if _free(hp, 17.0):
					_house(hp, yaw, rng)
		i += 8
	# рекламные щиты у стартовой прямой
	for k in 2:
		var bj := at_s(start_s + 40.0 + k * 45.0)
		var rgt: Vector3 = T[bj].cross(Vector3.UP)
		var sd := -1.0 if k == 0 else 1.0
		var bp: Vector3 = P[bj] + rgt * sd * (W[bj] * 0.5 + SHOULDER + 5.0)
		if _free(bp, 3.0) and RaceProps.spawn("billboard", self, bp, atan2(-rgt.x * sd, -rgt.z * sd)) != null:
			var bl := Label3D.new()
			bl.text = ["ТЯГА-812\nТЯНЕТ ВСЁ", "ГРИМЕРКА\nНА СВЯЗИ"][k]
			bl.font_size = 160
			bl.pixel_size = 0.012
			bl.modulate = Color(0.95, 0.15, 0.15) if k == 0 else Color(0.05, 0.05, 0.06)
			bl.outline_size = 0
			bl.position = bp + Vector3(0, 4.0, 0) - rgt * sd * 0.6
			bl.rotation.y = atan2(-rgt.x * sd, -rgt.z * sd)
			bl.double_sided = false
			add_child(bl)
	# лужи на обочинах
	for k in 10:
		var j := rng.randi_range(0, n - 1)
		var right2: Vector3 = T[j].cross(Vector3.UP)
		var pu := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(rng.randf_range(1.5, 3.0), rng.randf_range(2.0, 4.0))
		pu.mesh = pm
		pu.material_override = mats["water"]
		pu.position = P[j] + right2 * (W[j] * 0.5 + SHOULDER * 0.5) * (1.0 if k % 2 == 0 else -1.0) + Vector3(0, 0.02, 0)
		pu.rotation.y = rng.randf() * TAU
		add_child(pu)

## Крыши и строительные леса под поднятой дорогой. Крыша — дом под ней (стены с окнами до земли), парапет и то,
## что бывает на крышах: вентшахты, антенны, кондиционеры, тарелки, будки. Леса — стойки, перекладины, раскосы
## и оранжевая сетка. Окна и стойки — одним MultiMesh на вид: их сотни.
func _decks() -> void:
	if not has_height:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + 19
	mats["roofing"] = _mat(Color(0.17, 0.17, 0.19), 0.95)
	mats["net"] = _mat(Color(0.95, 0.42, 0.1), 0.8)
	var win_on: Array = []
	var win_off: Array = []
	var posts: Array = []
	var n := P.size()
	var i := 0
	while i < n:
		var kind := _zone_of(i)
		var y: float = P[i].y
		if not kind in ["roof", "scaffold"] or y < 1.0 or in_gap(i) or in_gap(mini(i + 4, n - 1)):
			i += 4
			continue
		var right: Vector3 = T[i].cross(Vector3.UP)
		var yaw := atan2(T[i].x, T[i].z)
		var half: float = W[i] * 0.5 + SHOULDER
		if kind == "roof":
			var slab := half + 4.6
			var block := int(S[i] / 46.0)
			var fac: Material = [mats["panel"], mats["panel2"], mats["panel3"]][block % 3]
			_box(Vector3(P[i].x, y * 0.5 - 0.12, P[i].z), Vector3(slab * 2.0, y, 4.3), yaw, fac, false)
			_box(P[i] + Vector3(0, -0.1, 0), Vector3(slab * 2.0, 0.12, 4.3), yaw, mats["snow"] if winter() else mats["roofing"], false)      # верх плиты — чуть ниже полотна: разметка и бордюры поверх
			for sd in [-1.0, 1.0]:
				_box(P[i] + right * sd * slab + Vector3(0, 0.3, 0), Vector3(0.3, 0.75, 4.3), yaw, mats["curb_w"], false)      # парапет
				for fl in int(y / 2.8):
					if rng.randf() < 0.8:
						(win_on if rng.randf() < 0.3 else win_off).append([Vector3(P[i].x, 1.6 + fl * 2.8, P[i].z) + right * sd * (slab + 0.03), yaw])
				# то, что стоит на крыше, — между стеной трассы и парапетом
				var rp: Vector3 = P[i] + right * sd * (half + 2.4)
				var pick := rng.randi() % 9
				match pick:
					0:      # вентшахта с козырьком
						_box(rp + Vector3(0, 0.6, 0), Vector3(1.1, 1.2, 1.1), yaw, mats["metal"], false)
						_box(rp + Vector3(0, 1.32, 0), Vector3(1.5, 0.12, 1.5), yaw, mats["rust"], false)
					1:      # антенна-«ёлочка»
						_box(rp + Vector3(0, 2.0, 0), Vector3(0.07, 4.0, 0.07), yaw, mats["metal"], false)
						for q in 4:
							_box(rp + Vector3(0, 2.6 + q * 0.4, 0), Vector3(1.3 - q * 0.22, 0.04, 0.04), yaw + 0.4, mats["metal"], false)
					2:      # кондиционер
						_box(rp + Vector3(0, 0.4, 0), Vector3(1.0, 0.7, 0.5), yaw + rng.randf(), mats["curb_w"], false)
					3:      # спутниковая тарелка
						_box(rp + Vector3(0, 0.7, 0), Vector3(0.08, 1.4, 0.08), yaw, mats["metal"], false)
						var dish := MeshInstance3D.new()
						var dm := CylinderMesh.new()
						dm.top_radius = 0.75
						dm.bottom_radius = 0.2
						dm.height = 0.25
						dish.mesh = dm
						dish.material_override = mats["curb_w"]
						dish.position = rp + Vector3(0, 1.5, 0)
						dish.rotation = Vector3(1.1, rng.randf() * TAU, 0)
						add_child(dish)
					4:      # будка выхода на крышу
						_box(rp + right * sd * 0.6 + Vector3(0, 1.2, 0), Vector3(2.2, 2.4, 2.6), yaw, mats["panel2"], false)
						_box(rp + right * sd * 0.6 - right * sd * 1.12 + Vector3(0, 1.0, 0), Vector3(0.06, 1.9, 0.9), yaw, mats["rust"], false)
					5:      # труба вытяжки
						_cyl(rp, 0.28, 2.6, mats["rust"], false)
		else:
			# леса: стойки по краям, перекладина, сетка сбоку, настил поверх полотна
			for sd in [-1.0, 1.0]:
				posts.append([Vector3(P[i].x, y * 0.5, P[i].z) + right * sd * (half + 0.5), yaw, y])
				if (i / 4) % 2 == 0:
					_box(P[i] + right * sd * (half + 0.5) + Vector3(0, 0.75, 0), Vector3(0.06, 1.5, 4.2), yaw, mats["net"], false)
			_box(P[i] + Vector3(0, -0.22, 0), Vector3(half * 2.0 + 1.2, 0.16, 0.2), yaw, mats["metal"], false)
			if y > 4.0 and (i / 4) % 3 == 0:
				var br := _box(Vector3(P[i].x, y * 0.5, P[i].z), Vector3(half * 2.0 + 1.0, 0.1, 0.1), yaw, mats["metal"], false)
				br.rotation.z = atan2(y, half * 2.0)
		i += 4
	# настил: доски на лесах, рубероид на крышах — тонким слоем поверх асфальта
	_ribbon(P, T, W, true, -1.0, 0.0, 1.0, 0.0, 0.006, mats["wood"], false, func(k): return _zone_of(k) != "scaffold" or in_gap(k))
	_ribbon(P, T, W, true, -1.0, 0.0, 1.0, 0.0, 0.006, mats["roofing"], false, func(k): return _zone_of(k) != "roof" or in_gap(k))
	for pack in [[win_on, mats["window"]], [win_off, mats["window_off"]]]:
		var lst: Array = pack[0]
		if lst.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 1.2, 1.5)
		mm.mesh = bm
		mm.instance_count = lst.size()
		for k in lst.size():
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(lst[k][1])), lst[k][0]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = pack[1]
		add_child(mmi)
	if not posts.is_empty():
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		var pb := BoxMesh.new()
		pb.size = Vector3(0.14, 1.0, 0.14)
		mm2.mesh = pb
		mm2.instance_count = posts.size()
		for k in posts.size():
			mm2.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(posts[k][1])).scaled(Vector3(1.0, float(posts[k][2]), 1.0)), posts[k][0]))
		var mmi2 := MultiMeshInstance3D.new()
		mmi2.multimesh = mm2
		mmi2.material_override = mats["metal"]
		add_child(mmi2)

## Щиты и таблички у дороги: data["signs"] — [{at: [x, z], side: ±1, text, big, col}]. Доска на двух ногах, надпись
## лицом к едущим. Стоят на высоте дороги (на крыше — на крыше).
func _signs() -> void:
	for sg in data.get("signs", []):
		var i := nearest_main(_v(sg["at"]))
		var right: Vector3 = T[i].cross(Vector3.UP)
		var sd: float = float(sg.get("side", 1))
		var big: bool = bool(sg.get("big", false))
		var w := 7.5 if big else 4.2
		var h := 3.0 if big else 1.7
		var up := 4.6 if big else 2.4
		var p: Vector3 = P[i] + right * sd * (W[i] * 0.5 + SHOULDER + (3.2 if big else 1.6))
		var yaw := atan2(T[i].x, T[i].z)
		var board_col: Color = _col(sg["bg"]) if sg.has("bg") else Color(0.93, 0.92, 0.88)
		_box(p + Vector3(0, up, 0), Vector3(w, h, 0.14), yaw, _mat(board_col, 0.8), false)
		for q in [-1.0, 1.0]:
			_box(p + right * q * (w * 0.5 - 0.3) + Vector3(0, up * 0.5, 0), Vector3(0.16, up, 0.16), yaw, mats["metal"], false)
		var l := Label3D.new()
		l.text = String(sg["text"])
		l.font_size = 96 if big else 64
		l.pixel_size = 0.0125 if big else 0.0085
		l.modulate = _col(sg["col"]) if sg.has("col") else Color(0.06, 0.06, 0.07)
		l.outline_size = 0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = w / l.pixel_size * 0.92
		l.double_sided = false
		l.position = p + Vector3(0, up, 0) - T[i] * 0.09
		l.rotation.y = yaw + PI                       # лицом навстречу движению
		add_child(l)

## узнаваемые здания и силуэты города: data["landmarks"] — [{kind, at: [x, z], yaw, k}] (race_tomsk.gd)
func _landmarks() -> void:
	for lm in data.get("landmarks", []):
		RaceTomsk.spawn(String(lm["kind"]), self, Vector3(float(lm["at"][0]), float(lm.get("y", 0.0)), float(lm["at"][1])), float(lm.get("yaw", 0.0)), float(lm.get("k", 1.0)))

func _graffiti(p: Vector3, yaw: float, text: String, rng: RandomNumberGenerator) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 90
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = [Color(1, 0.3, 0.3), Color(0.4, 0.9, 1.0), Color(1.0, 0.85, 0.2), Color(0.9, 0.9, 0.9), Color(0.6, 1.0, 0.5)][rng.randi() % 5]
	l.position = p
	l.rotation = Vector3(0, yaw, rng.randf_range(-0.12, 0.12))
	l.double_sided = false
	add_child(l)

func _lamp(p: Vector3, yaw: float) -> void:
	_box(p + Vector3(0, 2.5, 0), Vector3(0.18, 5.0, 0.18), yaw, mats["metal"], false)
	_box(p + Vector3(0, 5.0, 0), Vector3(0.5, 0.2, 0.9), yaw, mats["lamp"], false)

func _house(p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(18.0, 30.0)
	var h := rng.randf_range(12.0, 16.0)
	_box(p + Vector3(0, h * 0.5, 0), Vector3(10.0, h, w), yaw, [mats["panel"], mats["panel2"], mats["panel3"]][rng.randi() % 3], true)
	for fl in 5:
		for k in int(w / 3.0):
			if rng.randf() < 0.5:
				continue
			var right := Vector3(sin(yaw), 0, cos(yaw))
			var q := _box(p + right * (-w * 0.5 + 1.5 + k * 3.0) + Vector3(0, 2.0 + fl * 2.7, 0), Vector3(10.1, 1.1, 1.2), yaw, mats["window"] if rng.randf() < 0.35 else mats["window_off"], false)
			q.position.y = 2.0 + fl * 2.7

# ---------------- заполнение: локация без пустоты ----------------
## расстояние от точки до края ближайшей дороги (главной или срезки), м
var _cells := {}                   # сетка 12 м: клетка → [[x, z, половина ширины]] — быстрый поиск ближайшей дороги

func _edge_dist(p: Vector3) -> float:
	if _cells.is_empty():
		for i in range(0, P.size(), 2):
			var c := Vector2i(floori(P[i].x / 12.0), floori(P[i].z / 12.0))
			if not _cells.has(c):
				_cells[c] = []
			(_cells[c] as Array).append([P[i].x, P[i].z, W[i] * 0.5 + SHOULDER])
		for i in range(0, SP.size(), 2):
			var c2 := Vector2i(floori(SP[i].x / 12.0), floori(SP[i].z / 12.0))
			if not _cells.has(c2):
				_cells[c2] = []
			(_cells[c2] as Array).append([SP[i].x, SP[i].z, short_w * 0.5 + SHOULDER])
	var d := 60.0                                    # дальше 60 м от дороги точная цифра не нужна
	var cx := floori(p.x / 12.0)
	var cz := floori(p.z / 12.0)
	for ox in range(-5, 6):
		for oz in range(-5, 6):
			var lst = _cells.get(Vector2i(cx + ox, cz + oz))
			if lst == null:
				continue
			for q in lst:
				d = minf(d, Vector2(p.x - float(q[0]), p.z - float(q[1])).length() - float(q[2]))
	return d

## Слоями вокруг дороги и внутри кольца: у дороги — деревья, кусты, скамейки, столбы; дальше — дворы
## (площадки, беседки, машины, будки, теплотрасса, гаражи рядами); ещё дальше — дома, кран, фабрики;
## по краю — холмы. Повторяющееся — MultiMesh (RaceProps.batch), крупное — по одному.
func _fill() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + 77
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in P:
		mn = mn.min(Vector2(p.x, p.z))
		mx = mx.max(Vector2(p.x, p.z))
	mn -= Vector2(90, 90)
	mx += Vector2(90, 90)
	var loop := PackedVector2Array()
	for k in range(0, P.size(), 4):
		loop.append(Vector2(P[k].x, P[k].z))
	var batches := {}            # id → [[место, поворот, k]]
	var big: Array = []          # [центр, радиус] — крупное не налезает друг на друга
	var free_big := func(c: Vector3, r: float) -> bool:
		for b in big:
			if Vector2(c.x - (b[0] as Vector3).x, c.z - (b[0] as Vector3).z).length() < r + float(b[1]):
				return false
		return true
	var drifts: Array = []       # зимой вместо кустов — сугробы
	var is_winter := winter()
	var add := func(pid: String, c: Vector3, yaw: float, k := 1.0) -> void:
		if is_winter:
			if pid == "bush" or pid == "trash_pile":
				drifts.append([c, yaw, k])
				return
			if pid == "birch_tree":
				pid = "bare_tree"                # листвы зимой нет
		if not batches.has(pid):
			batches[pid] = []
		(batches[pid] as Array).append([c, yaw, k])
	var cranes := 0
	var step := 7.0
	var x := mn.x
	while x < mx.x:
		var z := mn.y
		while z < mx.y:
			var c := Vector3(x + rng.randf_range(-2.5, 2.5), 0.0, z + rng.randf_range(-2.5, 2.5))
			z += step
			var d := _edge_dist(c)
			if d < 2.5:
				continue
			if has_height and d < 15.0 and P[nearest_main(c)].y > 2.0:
				continue                       # под крышей — дом, под лесами — стойки: деревьям тут не место
			var inner := Geometry2D.is_point_in_polygon(Vector2(c.x, c.z), loop)
			var face := rng.randf() * TAU
			var r := rng.randf()
			if d < 9.0:
				# у дороги: деревья, кусты, скамейки, столбы
				if r < 0.28:
					add.call("birch_tree" if rng.randf() < 0.6 else "bare_tree", c, face, rng.randf_range(0.8, 1.25))
				elif r < 0.45:
					add.call("bush", c, face, rng.randf_range(0.8, 1.3))
				elif r < 0.5:
					add.call("bench", c, face)
				elif r < 0.54:
					add.call("power_pole", c, face)
			elif d < 30.0:
				# дворы
				if r < 0.16:
					add.call("birch_tree" if rng.randf() < 0.55 else "bare_tree", c, face, rng.randf_range(0.8, 1.3))
				elif r < 0.26:
					add.call("bush", c, face, rng.randf_range(0.8, 1.4))
				elif r < 0.29 and free_big.call(c, 6.0):
					big.append([c, 6.0])
					RaceProps.spawn("playground", self, c, face)
				elif r < 0.32 and free_big.call(c, 4.0):
					big.append([c, 4.0])
					RaceProps.spawn("gazebo", self, c, face)
				elif r < 0.36:
					add.call("old_car" if rng.randf() < 0.6 else "old_van", c, face)
				elif r < 0.38 and free_big.call(c, 3.5):
					big.append([c, 3.5])
					RaceProps.spawn("transformer_booth", self, c, face)
				elif r < 0.395 and free_big.call(c, 7.0):
					big.append([c, 7.0])
					add.call("heating_pipe", c, face)
					for q in [1, 2]:                     # теплотрасса продолжается вдоль своей оси
						add.call("heating_pipe", c + Vector3(sin(face), 0, cos(face)) * 9.6 * q, face)
				elif r < 0.44 and free_big.call(c, 9.0):
					# ряд гаражей
					big.append([c, 9.0])
					for g in 3:
						add.call("garage", c + Vector3(sin(face + PI * 0.5), 0, cos(face + PI * 0.5)) * (g - 1) * 3.7, face)
				elif r < 0.5:
					add.call("dumpster" if rng.randf() < 0.5 else "trash_pile", c, face)
			elif not inner or d < 70.0:
				# дома, кран, фабрики — дальний план
				if r < 0.14 and free_big.call(c, 17.0):
					big.append([c, 17.0])
					add.call("khrushchevka" if rng.randf() < 0.55 else "panel_tower", c, _face_road(c), rng.randf_range(0.9, 1.15))
				elif r < 0.17 and cranes < 3 and free_big.call(c, 10.0):
					cranes += 1
					big.append([c, 10.0])
					RaceProps.spawn("tower_crane", self, c, face)
				elif r < 0.2 and free_big.call(c, 12.0):
					big.append([c, 12.0])
					add.call("factory_hall", c, _face_road(c))
				elif r < 0.42:
					add.call("birch_tree" if rng.randf() < 0.5 else "bare_tree", c, face, rng.randf_range(0.9, 1.4))
			elif r < 0.12:
				add.call("bare_tree", c, face, rng.randf_range(1.0, 1.4))
		x += step
	var counts := {}
	if not drifts.is_empty():
		var dmm := MultiMesh.new()
		dmm.transform_format = MultiMesh.TRANSFORM_3D
		var sp := SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		sp.radial_segments = 10
		sp.rings = 5
		dmm.mesh = sp
		dmm.instance_count = drifts.size()
		for k in drifts.size():
			var kk: float = float(drifts[k][2])
			dmm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(drifts[k][1])).scaled(Vector3(2.2 * kk, 0.55 * kk, 1.5 * kk)), (drifts[k][0] as Vector3) + Vector3(0, -0.1, 0)))
		var dmi := MultiMeshInstance3D.new()
		dmi.multimesh = dmm
		dmi.material_override = mats["snow"]
		dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dmi)
	for pid in batches:
		var far: bool = pid in ["khrushchevka", "panel_tower", "factory_hall"]
		var small: bool = pid in ["bush", "bench", "trash_pile", "dumpster", "power_pole"]
		counts[pid] = RaceProps.batch(pid, self, batches[pid], 0.0 if far else (140.0 if small else 220.0), not small)
	fill_counts = counts
	# холмы по краю: силуэт не обрывается в пустоту
	var hill_mat := _mat(Color(0.22, 0.25, 0.19), 1.0)
	for k in 26:
		var a := TAU * float(k) / 26.0 + rng.randf_range(-0.1, 0.1)
		var cen := Vector3((mn.x + mx.x) * 0.5, 0, (mn.y + mx.y) * 0.5)
		var rad := maxf(mx.x - mn.x, mx.y - mn.y) * 0.62 + rng.randf_range(0, 40)
		var h := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(30.0, 60.0)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		h.mesh = sm
		h.material_override = hill_mat
		h.scale = Vector3(1.0, rng.randf_range(0.25, 0.45), 1.0)
		h.position = cen + Vector3(cos(a), 0, sin(a)) * rad + Vector3(0, -sm.radius * 0.12, 0)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)

## повернуть лицом к ближайшей дороге
func _face_road(c: Vector3) -> float:
	var i := nearest_main(c)
	var to := P[i] - c
	return atan2(to.x, to.z)
