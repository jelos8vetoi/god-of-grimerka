## Модели мини-игр, собранные кодом (запасной вариант MGModels, пока нет .glb): мебель, техника, кабели,
## предметы стола. Каждая функция строит модель в узле r: основание на полу (y = 0), лицо по +Z, размер — в метрах.
## Материалы общие (кэш), с триплэнарной «грязью», чтобы коробки не выглядели гладкими кубами; экраны — свой
## шейдер (строки, мерцание, узор), лампочки — светящиеся. Функции возвращают то, что нужно анимировать.
class_name MGProps

static var _mats := {}
static var _grime: NoiseTexture2D
static var _scratch: NoiseTexture2D

const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 col : source_color = vec4(0.3, 1.0, 0.5, 1.0);
uniform float energy = 1.4;
uniform float seed = 0.0;
uniform float mode = 0.0;      // 0 — узор игры, 1 — строки текста, 2 — помехи, 3 — лицо (смайл)
uniform float on = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 13.0;
	float scan = 0.72 + 0.28 * sin(uv.y * 320.0);
	float flick = 0.92 + 0.08 * sin(t * 57.0 + seed * 3.0);
	float v = 0.0;
	if (mode < 0.5) {
		v = 0.5 + 0.5 * sin(uv.x * 13.0 + t * 1.7 + seed) * sin(uv.y * 8.0 - t * 1.1);
		v = mix(v, step(0.6, h(floor(uv * vec2(24.0, 16.0)) + floor(t * 3.0))), 0.35);
	} else if (mode < 1.5) {
		float row = floor(uv.y * 14.0);
		float len = 0.3 + 0.6 * h(vec2(row, floor(t * 0.5) + seed));
		v = step(uv.x, len) * step(0.25, fract(uv.y * 14.0)) * 0.9;
	} else if (mode < 2.5) {
		v = h(uv * 300.0 + floor(t * 30.0));
	} else {
		vec2 d = uv - vec2(0.5, 0.5);
		float eyes = step(length(d - vec2(-0.16, 0.12)), 0.06) + step(length(d - vec2(0.16, 0.12)), 0.06);
		float mouth = step(abs(length(d - vec2(0.0, 0.05)) - 0.25), 0.03) * step(d.y, -0.05);
		v = clamp(eyes + mouth, 0.0, 1.0) + h(uv * 200.0 + t) * 0.15;
	}
	vec2 dd = uv - 0.5;
	float vign = 1.0 - dot(dd, dd) * 1.8;
	ALBEDO = col.rgb * energy * scan * flick * (0.25 + v) * vign * on;
}
"""

# ---------------- материалы ----------------
static func _tex() -> void:
	if _grime != null:
		return
	_grime = NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.02
	n.fractal_octaves = 5
	_grime.noise = n
	_grime.seamless = true
	_grime.width = 256
	_grime.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.53, 0.5))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	_grime.color_ramp = ramp
	_scratch = NoiseTexture2D.new()
	var n2 := FastNoiseLite.new()
	n2.seed = 19
	n2.frequency = 0.08
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	_scratch.noise = n2
	_scratch.seamless = true
	_scratch.width = 256
	_scratch.height = 256
	var r2 := Gradient.new()
	r2.set_color(0, Color(0.7, 0.68, 0.66))
	r2.set_color(1, Color(1.0, 1.0, 1.0))
	_scratch.color_ramp = r2

static func _m(col: Color, rough: float, metal := 0.0, tex := 1, uv := 1.2) -> StandardMaterial3D:
	_tex()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if tex > 0:
		m.albedo_texture = _grime if tex == 1 else _scratch
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv
	return m

## материал по имени: black, metal, steel, wood, wood_dark, plastic, plastic_black, red, red_dark, paper, card,
## fabric, fabric_red, rubber, glass, brass, cream, green_paint, blue_paint, money, chrome
static func mat(k: String) -> Material:
	if _mats.has(k):
		return _mats[k]
	var m: Material
	match k:
		"black": m = _m(Color(0.06, 0.06, 0.065), 0.7)
		"metal": m = _m(Color(0.36, 0.37, 0.39), 0.45, 0.65, 2)
		"steel": m = _m(Color(0.55, 0.56, 0.58), 0.35, 0.8, 2)
		"chrome": m = _m(Color(0.8, 0.8, 0.82), 0.15, 1.0, 0)
		"wood": m = _m(Color(0.48, 0.32, 0.2), 0.8, 0.0, 2, 2.5)
		"wood_dark": m = _m(Color(0.24, 0.16, 0.11), 0.75, 0.0, 2, 2.5)
		"plastic": m = _m(Color(0.78, 0.76, 0.7), 0.6)
		"plastic_black": m = _m(Color(0.1, 0.1, 0.11), 0.5)
		"red": m = _m(Color(0.72, 0.06, 0.05), 0.55)
		"red_dark": m = _m(Color(0.36, 0.03, 0.03), 0.7)
		"paper": m = _m(Color(0.9, 0.88, 0.82), 0.95, 0.0, 1, 3.0)
		"card": m = _m(Color(0.62, 0.46, 0.3), 0.95, 0.0, 1, 2.0)
		"fabric": m = _m(Color(0.32, 0.31, 0.3), 1.0, 0.0, 1, 4.0)
		"fabric_red": m = _m(Color(0.5, 0.06, 0.06), 1.0, 0.0, 1, 4.0)
		"rubber": m = _m(Color(0.04, 0.04, 0.04), 0.9, 0.0, 0)
		"cream": m = _m(Color(0.86, 0.82, 0.72), 0.7)
		"green_paint": m = _m(Color(0.22, 0.3, 0.24), 0.8, 0.1, 2)
		"blue_paint": m = _m(Color(0.16, 0.22, 0.34), 0.8, 0.1, 2)
		"brass": m = _m(Color(0.7, 0.55, 0.25), 0.3, 0.9, 0)
		"money":
			m = _m(Color(0.55, 0.68, 0.5), 0.9, 0.0, 1, 6.0)
		"glass":
			var g := StandardMaterial3D.new()
			g.albedo_color = Color(0.6, 0.7, 0.75, 0.25)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.roughness = 0.05
			g.metallic = 0.3
			m = g
		_: m = _m(Color(1, 0, 1), 0.5)
	_mats[k] = m
	return m

## свет-материал (лампочка, светодиод), не кэшируется — его можно мигать
static func glow(c: Color, e := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func screen_mat(c: Color, mode := 0.0, seed_v := 0.0, e := 1.4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	m.shader = sh
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("energy", e)
	return m

# ---------------- примитивы ----------------
static func box(r: Node, p: Vector3, s: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	r.add_child(mi)
	return mi

static func cyl(r: Node, p: Vector3, rt: float, rb: float, h: float, m: Material, rot := Vector3.ZERO, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	r.add_child(mi)
	return mi

static func ball(r: Node, p: Vector3, rad: float, m: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = p
	mi.scale = sc
	r.add_child(mi)
	return mi

static func caps(r: Node, p: Vector3, rad: float, h: float, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = rad
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	r.add_child(mi)
	return mi

static func quad(r: Node, p: Vector3, s: Vector2, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = s
	mi.mesh = q
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	return mi

static func text(r: Node, s: String, p: Vector3, px: int, c: Color, rot := Vector3.ZERO, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.font_size = px
	l.pixel_size = 0.0025
	l.modulate = c
	l.outline_size = 0
	l.position = p
	l.rotation = rot
	l.double_sided = false
	if width > 0.0:
		l.width = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	return l

## кабель / шланг: трубка по точкам (сглаживается Катмулл-Ромом), радиус rad
static func tube(r: Node, pts: PackedVector3Array, rad: float, m: Material, ring := 6) -> MeshInstance3D:
	var path := PackedVector3Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in 6:
			var t := float(k) / 6.0
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	path.append(pts[pts.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_n := Vector3.UP
	var rings: Array = []
	for i in path.size():
		var fwd := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		if fwd.length() < 0.01:
			fwd = Vector3.FORWARD
		var side := fwd.cross(prev_n)
		if side.length() < 0.01:
			side = fwd.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(fwd).normalized()
		prev_n = up
		var rr: Array = []
		for k in ring:
			var a := TAU * float(k) / float(ring)
			rr.append([path[i] + (side * cos(a) + up * sin(a)) * rad, (side * cos(a) + up * sin(a))])
		rings.append(rr)
	for i in rings.size() - 1:
		for k in ring:
			var a0: Array = rings[i][k]
			var a1: Array = rings[i][(k + 1) % ring]
			var b0: Array = rings[i + 1][k]
			var b1: Array = rings[i + 1][(k + 1) % ring]
			for v in [a0, b0, a1, a1, b0, b1]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	r.add_child(mi)
	return mi

## провисший кабель между двумя точками
static func cable(r: Node, a: Vector3, b: Vector3, sag: float, rad := 0.012, m: Material = null) -> MeshInstance3D:
	var pts := PackedVector3Array()
	for k in 7:
		var t := float(k) / 6.0
		pts.append(a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
	return tube(r, pts, rad, m if m != null else mat("rubber"))

# ============ «5 НОЧЕЙ»: заведение «ОБЛАКО» ============
## игровой автомат: корпус с наклонным пультом, экраном, козырьком с подсветкой, кнопками; возвращает {screen, marquee}
static func arcade(r: Node3D, title: String, c: Color, seed_v := 0.0) -> Dictionary:
	var body := mat("black")
	box(r, Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.78), body)                        # основание
	box(r, Vector3(0, 1.35, -0.12), Vector3(0.8, 0.95, 0.54), body)                    # верх
	box(r, Vector3(0, 0.98, 0.22), Vector3(0.8, 0.1, 0.4), mat("plastic_black"), Vector3(-0.35, 0, 0))   # пульт
	for sx in [-0.405, 0.405]:
		box(r, Vector3(sx, 1.0, 0.0), Vector3(0.02, 1.95, 0.8), mat("red"))               # боковины с полосой
	var scr := screen_mat(c, 0.0, seed_v, 1.5)
	quad(r, Vector3(0, 1.38, 0.16), Vector2(0.6, 0.46), scr, Vector3(-0.2, 0, 0))
	box(r, Vector3(0, 1.38, 0.14), Vector3(0.68, 0.54, 0.02), mat("plastic_black"), Vector3(-0.2, 0, 0))
	var mq := glow(c.lerp(Color.WHITE, 0.3), 1.6)
	box(r, Vector3(0, 1.86, 0.06), Vector3(0.76, 0.2, 0.06), mq)                      # козырёк
	text(r, title, Vector3(0, 1.86, 0.1), 54, Color(0.05, 0.05, 0.05))
	cyl(r, Vector3(-0.18, 1.06, 0.24), 0.012, 0.012, 0.12, mat("steel"))             # джойстик
	ball(r, Vector3(-0.18, 1.13, 0.24), 0.03, mat("red"))
	for k in 3:
		cyl(r, Vector3(0.04 + k * 0.09, 1.04, 0.24), 0.025, 0.025, 0.02, glow([Color(1, 0.1, 0.1), Color(1, 0.8, 0.1), Color(0.2, 0.5, 1)][k], 1.2), Vector3(-0.35, 0, 0))
	box(r, Vector3(0, 0.42, 0.395), Vector3(0.18, 0.22, 0.01), mat("steel"))          # монетоприёмник
	box(r, Vector3(0, 0.46, 0.4), Vector3(0.03, 0.08, 0.01), glow(Color(1, 0.25, 0.1), 1.0))
	return {"screen": scr, "marquee": mq}

## серверная стойка: стеклянная дверь, юниты с огоньками, пучок кабелей сбоку; возвращает {leds}
static func server_rack(r: Node3D, seed_v := 0) -> Dictionary:
	box(r, Vector3(0, 1.05, 0), Vector3(0.66, 2.1, 0.96), mat("black"))
	var leds: Array = []
	for u in 9:
		var y := 0.25 + u * 0.2
		box(r, Vector3(0, y, 0.43), Vector3(0.58, 0.16, 0.04), mat("metal"))
		for j in 4:
			var on := (u + j + seed_v) % 3 != 0
			var led := glow(Color(0.15, 1.0, 0.35) if on else Color(1.0, 0.15, 0.08), 2.2)
			box(r, Vector3(-0.22 + j * 0.05, y + 0.03, 0.455), Vector3(0.02, 0.02, 0.01), led)
			leds.append(led)
		box(r, Vector3(0.12, y - 0.02, 0.455), Vector3(0.2, 0.05, 0.005), mat("plastic_black"))
	box(r, Vector3(0, 1.05, 0.49), Vector3(0.62, 2.0, 0.01), mat("glass"))
	box(r, Vector3(0.28, 1.1, 0.5), Vector3(0.02, 0.3, 0.03), mat("steel"))           # ручка
	for k in 5:                                                                         # кабели свисают сбоку
		cable(r, Vector3(0.34, 1.8 - k * 0.3, 0.3 - k * 0.08), Vector3(0.36, 0.02, 0.6 + k * 0.12), 0.05, 0.01, mat("plastic_black") if k % 2 else mat("red_dark"))
	text(r, "ОБЛАКО-0%d" % (seed_v + 1), Vector3(0, 2.0, 0.5), 28, Color(0.8, 0.8, 0.8))
	return {"leds": leds}

## стеллаж склада маскотов: полки, пустые головы с огромными глазами, костюмы, коробки; возвращает {heads}
static func mascot_shelf(r: Node3D, seed_v := 0) -> Dictionary:
	for x in [-1.05, 1.05]:
		box(r, Vector3(x, 1.0, 0), Vector3(0.05, 2.0, 0.6), mat("metal"))
	for y in [0.05, 0.75, 1.45, 1.98]:
		box(r, Vector3(0, y, 0), Vector3(2.15, 0.04, 0.6), mat("metal"))
	var heads: Array = []
	var cols := [mat("cream"), mat("red"), mat("plastic"), mat("fabric")]
	for k in 3:
		var hp := Vector3(-0.65 + k * 0.65, 1.47 + 0.26, 0.02)
		var hd := Node3D.new()
		hd.position = hp
		hd.rotation.y = [0.2, -0.15, 0.35][k] + float(seed_v) * 0.1
		r.add_child(hd)
		ball(hd, Vector3.ZERO, 0.26, cols[(k + seed_v) % cols.size()], Vector3(1, 0.92, 0.95))
		for ex in [-0.09, 0.09]:
			ball(hd, Vector3(ex, 0.05, 0.22), 0.065, mat("paper"))
			ball(hd, Vector3(ex, 0.05, 0.27), 0.03, mat("black"))
		box(hd, Vector3(0, -0.1, 0.23), Vector3(0.16, 0.04, 0.03), mat("black"))
		for ey in [-1.0, 1.0]:
			ball(hd, Vector3(ey * 0.2, 0.22, 0), 0.07, cols[(k + 1) % cols.size()])
		heads.append(hd)
	for k in 2:                                                                         # сложенные костюмы
		box(r, Vector3(-0.5 + k * 1.0, 0.92, 0), Vector3(0.8, 0.3, 0.5), mat("fabric") if k == 0 else mat("fabric_red"), Vector3(0, 0, 0.05))
	for k in 3:
		box(r, Vector3(-0.7 + k * 0.7, 0.27, 0.0), Vector3(0.5, 0.4, 0.45), mat("card"), Vector3(0, 0.1 * k, 0))
		text(r, ["ПЕРЧАТКИ", "ГЛАЗА", "НЕ ОТКРЫВАТЬ"][k], Vector3(-0.7 + k * 0.7, 0.3, 0.235), 26, Color(0.15, 0.1, 0.05))
	return {"heads": heads}

## генератор и щит: корпус, манометры, рукоятка, толстые кабели, жёлто-чёрная полоса
static func generator(r: Node3D) -> Dictionary:
	box(r, Vector3(0, 0.6, 0), Vector3(1.3, 1.1, 0.85), mat("green_paint"))
	box(r, Vector3(0, 0.08, 0), Vector3(1.4, 0.16, 0.95), mat("black"))
	for k in 6:
		box(r, Vector3(-0.5 + k * 0.2, 0.75, 0.43), Vector3(0.08, 0.5, 0.01), mat("black"))   # решётка
	var gauges: Array = []
	for k in 2:
		cyl(r, Vector3(0.35 + k * 0.22, 0.95, 0.43), 0.08, 0.08, 0.03, mat("chrome"), Vector3(PI / 2, 0, 0))
		var needle := box(r, Vector3(0.35 + k * 0.22, 0.95, 0.45), Vector3(0.008, 0.07, 0.005), mat("red"))
		gauges.append(needle)
	cyl(r, Vector3(0.66, 0.6, 0.2), 0.03, 0.03, 0.3, mat("steel"), Vector3(0, 0, PI / 2))   # рукоятка
	box(r, Vector3(0.82, 0.6, 0.2), Vector3(0.05, 0.16, 0.05), mat("red"))
	for k in 8:
		box(r, Vector3(-0.6 + k * 0.17, 1.17, 0.43), Vector3(0.085, 0.06, 0.01), mat("black") if k % 2 else _yellow())
	var lamp := glow(Color(1.0, 0.25, 0.1), 2.0)
	ball(r, Vector3(-0.5, 1.2, 0.3), 0.05, lamp)
	cable(r, Vector3(-0.6, 0.9, -0.2), Vector3(-1.3, 0.02, -0.5), 0.15, 0.03)
	cable(r, Vector3(-0.6, 0.7, -0.3), Vector3(-1.5, 0.02, 0.2), 0.12, 0.03, mat("red_dark"))
	return {"gauges": gauges, "lamp": lamp}

static func _yellow() -> Material:
	if not _mats.has("yellow"):
		_mats["yellow"] = _m(Color(0.85, 0.7, 0.1), 0.6)
	return _mats["yellow"]

## стол праздника: скатерть в пятнах, колпаки, стаканы, сдутые шары, торт; стулья вокруг
static func party_table(r: Node3D, seed_v := 0) -> void:
	box(r, Vector3(0, 0.72, 0), Vector3(1.8, 0.05, 0.9), mat("paper"))
	box(r, Vector3(0, 0.6, 0.45), Vector3(1.8, 0.22, 0.01), mat("paper"))               # край скатерти
	box(r, Vector3(0, 0.6, -0.45), Vector3(1.8, 0.22, 0.01), mat("paper"))
	for x in [-0.8, 0.8]:
		for z in [-0.35, 0.35]:
			cyl(r, Vector3(x, 0.36, z), 0.025, 0.025, 0.72, mat("steel"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + seed_v
	for k in 4:
		var p := Vector3(rng.randf_range(-0.7, 0.7), 0.75, rng.randf_range(-0.3, 0.3))
		var hat := cyl(r, p + Vector3(0, 0.1, 0), 0.0, 0.06, 0.2, mat("red") if k % 2 == 0 else mat("cream"), Vector3(0, 0, 1.3 if k == 1 else 0.0))
		hat.position.y = 0.78 if k == 1 else 0.85
		cyl(r, Vector3(rng.randf_range(-0.8, 0.8), 0.79, rng.randf_range(-0.35, 0.35)), 0.035, 0.028, 0.1, mat("plastic"))
	cyl(r, Vector3(0.1, 0.8, 0), 0.18, 0.18, 0.12, mat("cream"))                       # торт
	cyl(r, Vector3(0.1, 0.87, 0), 0.18, 0.18, 0.02, mat("red"))
	box(r, Vector3(0.18, 0.84, 0.05), Vector3(0.14, 0.1, 0.12), mat("black"), Vector3(0, 0.6, 0))   # вырезанный кусок — провал
	for k in 3:
		cyl(r, Vector3(0.05 + k * 0.04, 0.95, -0.02), 0.006, 0.006, 0.08, mat("paper"))
	for k in 4:                                                                          # стулья
		var cx := -0.6 + float(k % 2) * 1.2
		var cz := -0.75 if k < 2 else 0.75
		var ch := Node3D.new()
		ch.position = Vector3(cx, 0, cz)
		ch.rotation.y = 0.0 if k < 2 else PI
		ch.rotation.y += rng.randf_range(-0.3, 0.3)
		r.add_child(ch)
		chair(ch)
	# шарик, привязанный к стулу, наполовину сдулся
	var b := ball(r, Vector3(-0.9, 1.3, -0.9), 0.16, mat("red"), Vector3(1, 1.2, 1))
	b.set_meta("balloon", true)
	cable(r, Vector3(-0.9, 1.12, -0.9), Vector3(-0.7, 0.45, -0.85), 0.05, 0.003, mat("paper"))

static func chair(r: Node3D) -> void:
	box(r, Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42), mat("plastic_black"))
	box(r, Vector3(0, 0.75, -0.2), Vector3(0.42, 0.5, 0.04), mat("plastic_black"), Vector3(-0.1, 0, 0))
	for x in [-0.18, 0.18]:
		for z in [-0.18, 0.18]:
			cyl(r, Vector3(x, 0.22, z), 0.015, 0.015, 0.45, mat("steel"))

## офисное кресло на колёсах
static func office_chair(r: Node3D) -> void:
	box(r, Vector3(0, 0.5, 0), Vector3(0.5, 0.08, 0.48), mat("fabric"))
	box(r, Vector3(0, 0.9, -0.22), Vector3(0.48, 0.62, 0.08), mat("fabric"), Vector3(-0.12, 0, 0))
	cyl(r, Vector3(0, 0.3, 0), 0.03, 0.03, 0.38, mat("steel"))
	for k in 5:
		var a := TAU * k / 5.0
		box(r, Vector3(cos(a) * 0.17, 0.07, sin(a) * 0.17), Vector3(0.34, 0.03, 0.04), mat("plastic_black"), Vector3(0, -a, 0))
		ball(r, Vector3(cos(a) * 0.32, 0.035, sin(a) * 0.32), 0.035, mat("rubber"))
	for sx in [-0.27, 0.27]:
		box(r, Vector3(sx, 0.68, 0.02), Vector3(0.04, 0.03, 0.34), mat("plastic_black"))

## колонка на стойке
static func speaker(r: Node3D) -> void:
	cyl(r, Vector3(0, 0.5, 0), 0.025, 0.025, 1.0, mat("steel"))
	for k in 3:
		box(r, Vector3(0, 0.02, 0), Vector3(0.7, 0.03, 0.04), mat("steel"), Vector3(0, k * PI / 3, 0))
	box(r, Vector3(0, 1.3, 0), Vector3(0.5, 0.7, 0.4), mat("black"))
	cyl(r, Vector3(0, 1.2, 0.2), 0.17, 0.17, 0.02, mat("fabric"), Vector3(PI / 2, 0, 0))
	cyl(r, Vector3(0, 1.48, 0.2), 0.07, 0.07, 0.02, mat("fabric"), Vector3(PI / 2, 0, 0))
	box(r, Vector3(0.12, 1.55, 0.205), Vector3(0.18, 0.04, 0.005), mat("red"), Vector3(0, 0, 0.4))   # изолента
	cable(r, Vector3(0, 1.0, -0.15), Vector3(0.4, 0.02, -0.6), 0.2, 0.012)

## телевизор с кинескопом; возвращает {screen}
static func crt(r: Node3D, c := Color(0.8, 0.8, 0.8), mode := 2.0, seed_v := 0.0) -> Dictionary:
	box(r, Vector3(0, 0.25, -0.05), Vector3(0.58, 0.48, 0.42), mat("plastic"))
	box(r, Vector3(0, 0.25, -0.32), Vector3(0.4, 0.34, 0.2), mat("plastic"))
	var scr := screen_mat(c, mode, seed_v, 1.3)
	quad(r, Vector3(0, 0.27, 0.165), Vector2(0.44, 0.34), scr)
	box(r, Vector3(0, 0.27, 0.16), Vector3(0.5, 0.4, 0.01), mat("plastic_black"))
	for k in 2:
		cyl(r, Vector3(0.24, 0.12 + k * 0.08, 0.17), 0.018, 0.018, 0.02, mat("plastic_black"), Vector3(PI / 2, 0, 0))
	return {"screen": scr}

## потолочная лампа-плафон с решёткой; возвращает {bulb} (материал, его можно гасить)
static func ceiling_lamp(r: Node3D, c := Color(1, 0.92, 0.8)) -> Dictionary:
	cyl(r, Vector3(0, -0.3, 0), 0.005, 0.005, 0.6, mat("rubber"))
	cyl(r, Vector3(0, -0.62, 0), 0.05, 0.22, 0.12, mat("metal"))
	var bulb := glow(c, 3.0)
	ball(r, Vector3(0, -0.7, 0), 0.07, bulb)
	return {"bulb": bulb}

## длинная люминесцентная лампа; возвращает {tube}
static func strip_lamp(r: Node3D, length := 1.2, c := Color(0.85, 0.95, 1.0)) -> Dictionary:
	box(r, Vector3(0, -0.03, 0), Vector3(length, 0.05, 0.18), mat("metal"))
	var tb := glow(c, 2.4)
	cyl(r, Vector3(0, -0.08, 0), 0.025, 0.025, length * 0.95, tb, Vector3(0, 0, PI / 2), 8)
	return {"tube": tb}

## плакат на стене (лицом +Z): лист с рамкой и текстом
static func poster(r: Node3D, title: String, sub: String, c := Color(0.7, 0.05, 0.05), w := 0.6, h := 0.85) -> void:
	box(r, Vector3(0, 0, 0), Vector3(w, h, 0.01), mat("paper"))
	box(r, Vector3(0, h * 0.18, 0.006), Vector3(w * 0.86, h * 0.5, 0.002), mat("black"))
	# размер букв — от размера листа (pixel_size 0,0025 м): заголовок ~6 % высоты листа, подпись ~2,5 %
	var wpx := w * 0.86 / 0.0025
	text(r, title, Vector3(0, h * 0.18, 0.01), maxi(14, int(h * 26.0)), c, Vector3.ZERO, wpx)
	text(r, sub, Vector3(0, -h * 0.3, 0.01), maxi(9, int(h * 11.0)), Color(0.12, 0.12, 0.12), Vector3.ZERO, wpx)
	box(r, Vector3(-w * 0.4, h * 0.46, 0.008), Vector3(0.06, 0.03, 0.002), mat("plastic"))   # скотч
	box(r, Vector3(w * 0.4, h * 0.46, 0.008), Vector3(0.06, 0.03, 0.002), mat("plastic"))

## шкафчик-локер (дверца может быть приоткрыта)
static func locker(r: Node3D, open := 0.0, label := "") -> Node3D:
	box(r, Vector3(0, 0.95, 0), Vector3(0.45, 1.9, 0.5), mat("blue_paint"))
	var door := Node3D.new()
	door.position = Vector3(-0.22, 0, 0.255)
	door.rotation.y = -open
	r.add_child(door)
	box(door, Vector3(0.22, 0.95, 0), Vector3(0.44, 1.86, 0.02), mat("blue_paint"))
	for k in 4:
		box(door, Vector3(0.22, 1.6 - k * 0.04, 0.012), Vector3(0.28, 0.012, 0.005), mat("black"))
	box(door, Vector3(0.38, 1.0, 0.02), Vector3(0.03, 0.12, 0.02), mat("steel"))
	if label != "":
		text(door, label, Vector3(0.22, 1.3, 0.012), 30, Color(0.9, 0.88, 0.8))
	return door

## тележка уборщика: ведро, швабра, мешок
static func janitor_cart(r: Node3D) -> void:
	box(r, Vector3(0, 0.45, 0), Vector3(0.9, 0.05, 0.5), mat("plastic_black"))
	box(r, Vector3(0, 0.12, 0), Vector3(0.9, 0.04, 0.5), mat("plastic_black"))
	for x in [-0.43, 0.43]:
		box(r, Vector3(x, 0.5, 0), Vector3(0.03, 0.9, 0.5), mat("plastic_black"))
	for x in [-0.4, 0.4]:
		for z in [-0.2, 0.2]:
			ball(r, Vector3(x, 0.05, z), 0.05, mat("rubber"))
	cyl(r, Vector3(-0.15, 0.62, 0), 0.16, 0.13, 0.3, _yellow())
	cyl(r, Vector3(-0.15, 1.1, 0.05), 0.012, 0.012, 1.3, mat("wood"), Vector3(0.12, 0, 0))
	ball(r, Vector3(0.22, 0.7, 0), 0.22, mat("plastic_black"), Vector3(1, 1.2, 0.9))

## картонная коробка (крышка приоткрыта)
static func carton(r: Node3D, s := Vector3(0.5, 0.4, 0.4), label := "") -> void:
	box(r, Vector3(0, s.y / 2, 0), s, mat("card"))
	box(r, Vector3(0, s.y + 0.005, 0), Vector3(s.x * 0.98, 0.01, 0.05), _tape())
	box(r, Vector3(0, s.y + 0.06, s.z / 2 - 0.02), Vector3(s.x, 0.12, 0.01), mat("card"), Vector3(-0.6, 0, 0))
	if label != "":
		text(r, label, Vector3(0, s.y * 0.5, s.z / 2 + 0.003), 30, Color(0.12, 0.08, 0.04))

static func _tape() -> Material:
	if not _mats.has("tape"):
		_mats["tape"] = _m(Color(0.75, 0.62, 0.42), 0.3, 0.0, 0)
	return _mats["tape"]

## мусор на полу: смятые бумажки, банка, стаканчик, обёртка — разбросано в круге rad
static func litter(r: Node3D, n: int, rad: float, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed_v
	for k in n:
		var p := Vector3(rng.randf_range(-rad, rad), 0, rng.randf_range(-rad, rad))
		match k % 4:
			0: ball(r, p + Vector3(0, 0.03, 0), 0.04, mat("paper"), Vector3(1, 0.7, 1.2))
			1: cyl(r, p + Vector3(0, 0.03, 0), 0.03, 0.03, 0.12, mat("red"), Vector3(PI / 2, rng.randf() * TAU, 0))
			2: cyl(r, p + Vector3(0, 0.04, 0), 0.04, 0.03, 0.09, mat("paper"), Vector3(PI / 2, rng.randf() * TAU, 0))
			3: box(r, p + Vector3(0, 0.005, 0), Vector3(0.12, 0.01, 0.08), mat("plastic"), Vector3(0, rng.randf() * TAU, 0))

## короб вентиляции (жесть с рёбрами), длина по X
static func duct(r: Node3D, length: float, w := 0.7, h := 0.5) -> void:
	box(r, Vector3(0, 0, 0), Vector3(length, h, w), mat("steel"))
	var k := 0.0
	while k < length:
		box(r, Vector3(-length / 2 + k, 0, 0), Vector3(0.04, h + 0.03, w + 0.03), mat("metal"))
		k += 0.6

## решётка вентиляции на стене
static func vent_grill(r: Node3D, w := 0.8, h := 0.6) -> void:
	box(r, Vector3(0, 0, 0), Vector3(w, h, 0.03), mat("metal"))
	for k in 7:
		box(r, Vector3(0, -h / 2 + 0.06 + k * (h - 0.1) / 6.0, 0.02), Vector3(w * 0.9, 0.025, 0.02), mat("black"), Vector3(0.5, 0, 0))

## щиток с рубильниками
static func fuse_panel(r: Node3D, label := "ЩИТ") -> Array:
	box(r, Vector3(0, 0, 0), Vector3(0.6, 0.85, 0.12), mat("metal"))
	box(r, Vector3(0, 0, 0.065), Vector3(0.52, 0.76, 0.01), mat("black"))
	var leds: Array = []
	for k in 6:
		box(r, Vector3(-0.18 + (k % 3) * 0.18, 0.15 - (k / 3) * 0.3, 0.08), Vector3(0.06, 0.14, 0.04), mat("plastic"))
		var l := glow(Color(0.2, 1.0, 0.3) if k != 4 else Color(1.0, 0.15, 0.08), 1.8)
		box(r, Vector3(-0.18 + (k % 3) * 0.18, 0.26 - (k / 3) * 0.3, 0.075), Vector3(0.02, 0.02, 0.01), l)
		leds.append(l)
	text(r, label, Vector3(0, 0.38, 0.075), 30, Color(0.9, 0.85, 0.75))
	return leds

## стойка выдачи призов: прилавок, полки с мягкими игрушками
static func prize_counter(r: Node3D) -> void:
	box(r, Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.6), mat("red"))
	box(r, Vector3(0, 1.02, 0), Vector3(2.3, 0.05, 0.7), mat("black"))
	box(r, Vector3(0, 1.4, -0.6), Vector3(2.2, 1.6, 0.05), mat("black"))
	for y in [0.9, 1.4, 1.9]:
		box(r, Vector3(0, y, -0.45), Vector3(2.1, 0.03, 0.3), mat("metal"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for k in 12:
		var p := Vector3(-0.9 + (k % 6) * 0.36, 0.98 + (k / 6) * 0.5 + 0.1, -0.45)
		var plush := Node3D.new()
		plush.position = p
		plush.rotation.y = rng.randf_range(-0.4, 0.4)
		r.add_child(plush)
		var col: Material = [mat("cream"), mat("red"), mat("plastic"), mat("fabric")][k % 4]
		ball(plush, Vector3(0, 0, 0), 0.09, col, Vector3(1, 1.1, 0.9))
		ball(plush, Vector3(0, 0.13, 0), 0.07, col)
		for ex in [-0.025, 0.025]:
			ball(plush, Vector3(ex, 0.14, 0.06), 0.012, mat("black"))
	text(r, "ПРИЗЫ ЗА БИЛЕТЫ", Vector3(0, 0.6, 0.31), 50, Color(0.95, 0.92, 0.85))

## занавес сцены: волны ткани
static func curtain(r: Node3D, w: float, h: float) -> void:
	var n := int(w / 0.25)
	for k in n:
		cyl(r, Vector3(-w / 2 + (k + 0.5) * w / n, h / 2, sin(k * 1.7) * 0.05), 0.14, 0.14, h, mat("fabric_red"), Vector3.ZERO, 8)

# ============ «МИКРОЗАЙМЫ»: комната и стол Пахана ============
## деревянный стол с тумбой и ящиком
static func desk(r: Node3D, w := 1.6, d := 0.8) -> void:
	box(r, Vector3(0, 0.76, 0), Vector3(w, 0.05, d), mat("wood"))
	box(r, Vector3(w / 2 - 0.25, 0.37, 0), Vector3(0.45, 0.74, d - 0.04), mat("wood_dark"))
	for k in 3:
		box(r, Vector3(w / 2 - 0.25, 0.6 - k * 0.22, d / 2 - 0.01), Vector3(0.4, 0.18, 0.02), mat("wood"))
		box(r, Vector3(w / 2 - 0.25, 0.62 - k * 0.22, d / 2 + 0.01), Vector3(0.1, 0.02, 0.02), mat("brass"))
	for z in [-d / 2 + 0.05, d / 2 - 0.05]:
		box(r, Vector3(-w / 2 + 0.05, 0.37, z), Vector3(0.05, 0.74, 0.05), mat("wood_dark"))
	box(r, Vector3(-w / 2 + 0.3, 0.77, 0.05), Vector3(0.18, 0.002, 0.12), mat("red"), Vector3(0, 0.3, 0))   # наклейка

## ноутбук: открыт, экран светится; возвращает {screen, lid}
static func laptop(r: Node3D, c := Color(0.55, 0.8, 1.0)) -> Dictionary:
	box(r, Vector3(0, 0.012, 0), Vector3(0.34, 0.024, 0.24), mat("plastic_black"))
	for row in 4:
		for col in 10:
			box(r, Vector3(-0.135 + col * 0.03, 0.026, -0.06 + row * 0.028), Vector3(0.024, 0.004, 0.022), mat("black"))
	box(r, Vector3(0, 0.026, 0.085), Vector3(0.1, 0.002, 0.06), mat("metal"))           # тачпад
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.024, -0.12)
	lid.rotation.x = -0.32
	r.add_child(lid)
	box(lid, Vector3(0, 0.115, -0.005), Vector3(0.34, 0.23, 0.012), mat("plastic_black"))
	var scr := screen_mat(c, 1.0, 1.7, 1.2)
	quad(lid, Vector3(0, 0.12, 0.002), Vector2(0.3, 0.19), scr)
	box(lid, Vector3(0.1, 0.18, -0.012), Vector3(0.06, 0.04, 0.001), mat("red"))     # наклейка на крышке
	return {"screen": scr, "lid": lid}

## смартфон экраном вверх; возвращает {screen}
static func phone(r: Node3D) -> Dictionary:
	box(r, Vector3(0, 0.005, 0), Vector3(0.075, 0.01, 0.155), mat("plastic_black"))
	var scr := screen_mat(Color(0.85, 0.9, 1.0), 1.0, 4.2, 0.5)
	quad(r, Vector3(0, 0.0105, 0), Vector2(0.066, 0.14), scr, Vector3(-PI / 2, 0, 0))
	box(r, Vector3(0.02, 0.011, -0.065), Vector3(0.012, 0.001, 0.004), mat("black"))
	return {"screen": scr}

## калькулятор с кнопками и экранчиком
static func calculator(r: Node3D) -> void:
	box(r, Vector3(0, 0.01, 0), Vector3(0.09, 0.02, 0.15), mat("plastic"))
	box(r, Vector3(0, 0.021, -0.045), Vector3(0.07, 0.002, 0.03), glow(Color(0.6, 0.75, 0.55), 0.6))
	for k in 16:
		box(r, Vector3(-0.027 + (k % 4) * 0.018, 0.022, -0.01 + (k / 4) * 0.018), Vector3(0.013, 0.004, 0.013), mat("plastic_black") if k % 4 != 3 else mat("red"))

## стопка неоплаченных счетов: листы вразнобой, верхний с красной печатью
static func bills(r: Node3D, n := 6, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + seed_v
	for k in n:
		box(r, Vector3(rng.randf_range(-0.02, 0.02), 0.002 + k * 0.003, rng.randf_range(-0.02, 0.02)), Vector3(0.21, 0.002, 0.29), mat("paper"), Vector3(0, rng.randf_range(-0.25, 0.25), 0))
	var top := 0.004 + n * 0.003
	text(r, "СЧЁТ", Vector3(0, top, -0.08), 40, Color(0.1, 0.1, 0.1), Vector3(-PI / 2, 0, 0))
	text(r, "ПРОСРОЧЕНО", Vector3(0.01, top + 0.001, 0.05), 48, Color(0.75, 0.05, 0.04), Vector3(-PI / 2, 0, 0.3))

## пачка денег под резинкой
static func cash(r: Node3D, layers := 3) -> void:
	for k in layers:
		box(r, Vector3(0, 0.005 + k * 0.008, 0), Vector3(0.15, 0.008, 0.07), mat("money"), Vector3(0, k * 0.05, 0))
	box(r, Vector3(0, 0.006 + layers * 0.008 * 0.5, 0), Vector3(0.012, layers * 0.009 + 0.002, 0.072), mat("red"))

## одна купюра (для анимации денег)
static func bill_note(r: Node3D) -> MeshInstance3D:
	return box(r, Vector3.ZERO, Vector3(0.15, 0.002, 0.07), mat("money"))

static func coin(r: Node3D) -> MeshInstance3D:
	return cyl(r, Vector3.ZERO, 0.012, 0.012, 0.003, mat("brass"), Vector3.ZERO, 10)

static func wallet(r: Node3D) -> void:
	box(r, Vector3(0, 0.012, 0), Vector3(0.11, 0.024, 0.09), mat("plastic_black"))
	box(r, Vector3(0.0, 0.02, 0.03), Vector3(0.09, 0.006, 0.04), mat("money"))

static func keys(r: Node3D) -> void:
	cyl(r, Vector3(0, 0.003, 0), 0.018, 0.018, 0.004, mat("steel"), Vector3.ZERO, 12)
	for k in 3:
		box(r, Vector3(0.03 + k * 0.004, 0.004, -0.01 + k * 0.012), Vector3(0.05, 0.003, 0.012), mat("brass") if k == 1 else mat("steel"), Vector3(0, 0.3 * k - 0.3, 0))
	box(r, Vector3(-0.03, 0.006, 0), Vector3(0.025, 0.012, 0.035), mat("red"))         # брелок

## кружка с надписью
static func mug(r: Node3D, label := "ПАХАН") -> void:
	cyl(r, Vector3(0, 0.05, 0), 0.04, 0.038, 0.1, mat("plastic"))
	cyl(r, Vector3(0, 0.098, 0), 0.034, 0.034, 0.005, mat("wood_dark"))
	var h := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.018
	tm.outer_radius = 0.028
	h.mesh = tm
	h.material_override = mat("plastic")
	h.position = Vector3(0.045, 0.05, 0)
	h.rotation = Vector3(PI / 2, 0, 0)
	r.add_child(h)
	text(r, label, Vector3(0, 0.055, 0.041), 9, Color(0.7, 0.05, 0.05))

## стаканчик лапши и коробка пиццы
static func food(r: Node3D) -> void:
	cyl(r, Vector3(-0.08, 0.055, 0), 0.05, 0.04, 0.11, mat("cream"))
	box(r, Vector3(-0.08, 0.112, 0.01), Vector3(0.1, 0.003, 0.1), mat("red"), Vector3(0.3, 0, 0))
	box(r, Vector3(0.12, 0.02, 0.05), Vector3(0.3, 0.04, 0.3), mat("card"), Vector3(0, 0.3, 0))
	text(r, "ПИЦЦА", Vector3(0.12, 0.041, 0.05), 30, Color(0.6, 0.05, 0.04), Vector3(-PI / 2, 0, 0.3))

## отвёртка и пассатижи
static func tools(r: Node3D) -> void:
	cyl(r, Vector3(0, 0.012, 0), 0.012, 0.012, 0.1, mat("red"), Vector3(0, 0, PI / 2))
	cyl(r, Vector3(0.1, 0.012, 0), 0.003, 0.003, 0.1, mat("steel"), Vector3(0, 0, PI / 2))
	box(r, Vector3(0.02, 0.008, 0.07), Vector3(0.16, 0.012, 0.02), mat("steel"), Vector3(0, 0.25, 0))
	box(r, Vector3(-0.04, 0.01, 0.09), Vector3(0.08, 0.016, 0.022), mat("red"), Vector3(0, 0.25, 0))

## кресло (отдых)
static func armchair(r: Node3D) -> void:
	box(r, Vector3(0, 0.25, 0), Vector3(0.85, 0.4, 0.8), mat("fabric"))
	box(r, Vector3(0, 0.5, 0.05), Vector3(0.62, 0.14, 0.62), mat("fabric_red"))
	box(r, Vector3(0, 0.78, -0.33), Vector3(0.85, 0.7, 0.18), mat("fabric"), Vector3(-0.12, 0, 0))
	for sx in [-0.38, 0.38]:
		box(r, Vector3(sx, 0.58, 0), Vector3(0.14, 0.3, 0.8), mat("fabric"))
	box(r, Vector3(0.1, 0.95, -0.3), Vector3(0.5, 0.5, 0.05), mat("red_dark"), Vector3(-0.1, 0.2, 0.1))   # плед

## шкаф с зеркалом
static func wardrobe(r: Node3D) -> void:
	box(r, Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.6), mat("wood_dark"))
	box(r, Vector3(-0.3, 1.1, 0.305), Vector3(0.5, 1.5, 0.01), mat("chrome"))
	box(r, Vector3(0.3, 1.1, 0.305), Vector3(0.56, 1.7, 0.01), mat("wood"))
	box(r, Vector3(0.05, 1.1, 0.32), Vector3(0.02, 0.15, 0.02), mat("brass"))

## холодильник с магнитами
static func fridge(r: Node3D) -> void:
	box(r, Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.6), mat("plastic"))
	box(r, Vector3(0, 1.02, 0.302), Vector3(0.58, 0.01, 0.01), mat("black"))
	box(r, Vector3(0.24, 1.25, 0.32), Vector3(0.03, 0.3, 0.03), mat("chrome"))
	for k in 4:
		box(r, Vector3(-0.15 + k * 0.08, 1.3 - (k % 2) * 0.1, 0.305), Vector3(0.05, 0.05, 0.01), [mat("red"), mat("blue_paint"), _yellow(), mat("black")][k])
	box(r, Vector3(0.0, 0.7, 0.305), Vector3(0.12, 0.12, 0.002), _yellow(), Vector3(0, 0, 0.1))   # записка

## окно с ночным городом за стеклом
static func window(r: Node3D, w := 1.3, h := 1.2) -> void:
	box(r, Vector3(0, 0, -0.06), Vector3(w + 0.12, h + 0.12, 0.08), mat("cream"))
	var city := screen_mat(Color(0.25, 0.3, 0.5), 0.0, 9.0, 0.6)
	quad(r, Vector3(0, 0, -0.02), Vector2(w, h), city)
	box(r, Vector3(0, 0, 0), Vector3(0.04, h, 0.04), mat("cream"))
	box(r, Vector3(0, 0, 0), Vector3(w, 0.04, 0.04), mat("cream"))
	box(r, Vector3(0, -h / 2 - 0.08, 0.06), Vector3(w + 0.2, 0.04, 0.2), mat("cream"))   # подоконник
	cyl(r, Vector3(0.4, -h / 2 - 0.0, 0.08), 0.05, 0.04, 0.1, mat("card"))           # горшок
	ball(r, Vector3(0.4, -h / 2 + 0.1, 0.08), 0.08, mat("green_paint"))

## полка с книгами и коробками
static func shelf(r: Node3D) -> void:
	for y in [0.0, 0.4, 0.8]:
		box(r, Vector3(0, y, 0), Vector3(1.0, 0.03, 0.25), mat("wood"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for k in 14:
		var y := float(k / 7) * 0.4 + 0.12
		var x := -0.45 + float(k % 7) * 0.13
		box(r, Vector3(x, y, 0), Vector3(0.05, rng.randf_range(0.16, 0.24), 0.18), [mat("red"), mat("black"), mat("cream"), mat("blue_paint")][k % 4], Vector3(0, 0, rng.randf_range(-0.08, 0.08)))

## ковёр
static func rug(r: Node3D, w := 2.0, d := 1.4) -> void:
	box(r, Vector3(0, 0.005, 0), Vector3(w, 0.01, d), mat("fabric_red"))
	box(r, Vector3(0, 0.011, 0), Vector3(w * 0.8, 0.002, d * 0.75), mat("red_dark"))

## настольная лампа на зажиме
static func desk_lamp(r: Node3D) -> Dictionary:
	cyl(r, Vector3(0, 0.01, 0), 0.07, 0.08, 0.02, mat("black"))
	cyl(r, Vector3(0, 0.2, -0.04), 0.008, 0.008, 0.4, mat("black"), Vector3(-0.2, 0, 0))
	cyl(r, Vector3(0, 0.38, 0.06), 0.008, 0.008, 0.25, mat("black"), Vector3(1.1, 0, 0))
	cyl(r, Vector3(0, 0.36, 0.17), 0.04, 0.09, 0.12, mat("red"), Vector3(0.6, 0, 0))
	var bulb := glow(Color(1.0, 0.85, 0.6), 3.0)
	ball(r, Vector3(0, 0.32, 0.2), 0.03, bulb)
	return {"bulb": bulb}

# ============ «МИКРОЗАЙМЫ»: техника подработок и вещи из хлама ============
## игровая приставка со снятой крышкой: плата, вентилятор, шлейфы, винты (ремонт)
static func console_open(r: Node3D) -> Dictionary:
	box(r, Vector3(0, 0.02, 0), Vector3(0.32, 0.04, 0.22), mat("plastic_black"))
	var board := box(r, Vector3(0, 0.045, 0), Vector3(0.28, 0.008, 0.19), mat("green_paint"))
	for k in 6:
		box(r, Vector3(-0.1 + (k % 3) * 0.08, 0.055, -0.05 + (k / 3) * 0.08), Vector3(0.04, 0.012, 0.03), mat("black"))
	cyl(r, Vector3(0.09, 0.06, 0.05), 0.04, 0.04, 0.02, mat("plastic"), Vector3.ZERO, 12)
	var screws: Array = []
	for p in [Vector3(-0.14, 0.05, -0.09), Vector3(0.14, 0.05, -0.09), Vector3(-0.14, 0.05, 0.09), Vector3(0.14, 0.05, 0.09)]:
		screws.append(cyl(r, p, 0.008, 0.008, 0.01, mat("steel"), Vector3.ZERO, 8))
	tube(r, PackedVector3Array([Vector3(-0.1, 0.05, 0.08), Vector3(-0.05, 0.07, 0.1), Vector3(0.0, 0.05, 0.07)]), 0.004, mat("red"))
	return {"board": board, "screws": screws}

## микшерный пульт: ручки, фейдеры, индикаторы уровня; возвращает {faders, knobs, meters}
static func mixer(r: Node3D, ch := 6) -> Dictionary:
	box(r, Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 0.45), mat("plastic_black"))
	box(r, Vector3(0, 0.07, -0.18), Vector3(0.6, 0.06, 0.08), mat("plastic_black"), Vector3(-0.4, 0, 0))
	var faders: Array = []
	var knobs: Array = []
	var meters: Array = []
	for c in ch:
		var x := -0.24 + c * (0.48 / float(maxi(1, ch - 1)))
		box(r, Vector3(x, 0.061, 0.1), Vector3(0.012, 0.002, 0.16), mat("black"))
		faders.append(box(r, Vector3(x, 0.07, 0.1), Vector3(0.03, 0.02, 0.025), mat("red") if c == ch - 1 else mat("plastic")))
		for k in 3:
			knobs.append(cyl(r, Vector3(x, 0.07, -0.02 - k * 0.045), 0.012, 0.014, 0.02, mat("plastic"), Vector3.ZERO, 10))
		var m := glow(Color(0.25, 1.0, 0.35), 1.8)
		box(r, Vector3(x, 0.1, -0.2), Vector3(0.018, 0.04, 0.005), m, Vector3(-0.4, 0, 0))
		meters.append(m)
	return {"faders": faders, "knobs": knobs, "meters": meters}

## вещь из хлама по номеру MLData.JUNK: у каждой свой узнаваемый силуэт
static func junk_item(r: Node3D, idx: int) -> void:
	match idx:
		0:  # кассетный плеер
			if MGModels.has("ml_job_radio"):
				MGModels.spawn("ml_job_radio", r, Vector3.ZERO, 0.0, Vector3(0.2, 0.17, 0.12), func(_x): pass)
				return
			box(r, Vector3(0, 0.04, 0), Vector3(0.14, 0.08, 0.03), mat("plastic"))
			box(r, Vector3(0, 0.05, 0.016), Vector3(0.1, 0.05, 0.002), mat("glass"))
			for k in 2:
				cyl(r, Vector3(-0.025 + k * 0.05, 0.05, 0.017), 0.012, 0.012, 0.002, mat("black"), Vector3(PI / 2, 0, 0), 8)
		1:  # сломанный чайник
			cyl(r, Vector3(0, 0.1, 0), 0.08, 0.1, 0.2, mat("steel"))
			cyl(r, Vector3(0.1, 0.12, 0), 0.015, 0.02, 0.1, mat("steel"), Vector3(0, 0, -0.9))
			box(r, Vector3(-0.1, 0.13, 0), Vector3(0.03, 0.12, 0.03), mat("black"))
			ball(r, Vector3(0, 0.02, 0.05), 0.03, mat("black"), Vector3(1, 0.3, 1))      # нагар
		2:  # коробка проводов
			carton(r, Vector3(0.3, 0.18, 0.24), "ПРОВОДА")
			for k in 4:
				cable(r, Vector3(-0.1 + k * 0.06, 0.18, -0.05), Vector3(-0.05 + k * 0.05, 0.25, 0.08), -0.06, 0.008, [mat("red"), mat("black"), mat("blue_paint"), _yellow()][k])
		3:  # кроссовки «найк»
			for sx in [-0.06, 0.06]:
				box(r, Vector3(sx, 0.03, 0), Vector3(0.09, 0.06, 0.26), mat("cream"))
				box(r, Vector3(sx, 0.008, 0), Vector3(0.095, 0.016, 0.27), mat("rubber"))
				box(r, Vector3(sx + 0.046 * signf(sx), 0.035, 0.02), Vector3(0.002, 0.02, 0.08), mat("red"))
		4:  # видеокарта в пыли
			box(r, Vector3(0, 0.02, 0), Vector3(0.26, 0.035, 0.11), mat("plastic_black"))
			box(r, Vector3(0, 0.004, 0), Vector3(0.26, 0.008, 0.11), mat("green_paint"))
			for k in 2:
				cyl(r, Vector3(-0.06 + k * 0.12, 0.04, 0), 0.04, 0.04, 0.008, mat("plastic"), Vector3.ZERO, 12)
			box(r, Vector3(0.135, 0.03, 0), Vector3(0.01, 0.05, 0.11), mat("steel"))
		5:  # стопка журналов
			for k in 6:
				box(r, Vector3(0, 0.005 + k * 0.01, 0), Vector3(0.21, 0.008, 0.28), [mat("red"), mat("cream"), mat("blue_paint")][k % 3], Vector3(0, 0.08 * k - 0.2, 0))
		6:  # пульт
			box(r, Vector3(0, 0.012, 0), Vector3(0.05, 0.024, 0.18), mat("plastic_black"))
			for k in 6:
				box(r, Vector3(-0.012 + (k % 2) * 0.024, 0.026, -0.05 + (k / 2) * 0.04), Vector3(0.014, 0.004, 0.014), mat("plastic"))
			box(r, Vector3(0, 0.026, -0.075), Vector3(0.012, 0.004, 0.012), mat("red"))
		7:  # гитарная педаль
			box(r, Vector3(0, 0.03, 0), Vector3(0.08, 0.06, 0.13), mat("red"))
			cyl(r, Vector3(0, 0.065, 0.03), 0.012, 0.012, 0.015, mat("steel"), Vector3.ZERO, 10)
			for k in 3:
				cyl(r, Vector3(-0.025 + k * 0.025, 0.064, -0.035), 0.008, 0.008, 0.012, mat("black"), Vector3.ZERO, 8)
			ball(r, Vector3(0, 0.062, -0.01), 0.005, glow(Color(1, 0.1, 0.1), 3.0))
		8:  # пакет с пакетами
			ball(r, Vector3(0, 0.1, 0), 0.12, mat("plastic"), Vector3(1, 0.8, 0.8))
			ball(r, Vector3(0.05, 0.18, 0.02), 0.05, mat("plastic"))
		9:  # старый ноутбук (закрыт)
			box(r, Vector3(0, 0.015, 0), Vector3(0.34, 0.03, 0.24), mat("plastic"))
			box(r, Vector3(0.08, 0.031, 0.04), Vector3(0.08, 0.002, 0.06), mat("red"))
		10:  # набор отвёрток
			box(r, Vector3(0, 0.015, 0), Vector3(0.2, 0.03, 0.1), mat("red"))
			for k in 6:
				cyl(r, Vector3(-0.075 + k * 0.03, 0.04, 0), 0.008, 0.008, 0.08, [mat("black"), _yellow(), mat("blue_paint")][k % 3], Vector3(PI / 2, 0, 0), 8)
		_:  # ковёр со стены — рулон
			cyl(r, Vector3(0, 0.07, 0), 0.07, 0.07, 0.6, mat("fabric_red"), Vector3(0, 0, PI / 2), 12)
			cyl(r, Vector3(0.301, 0.07, 0), 0.07, 0.07, 0.002, mat("cream"), Vector3(0, 0, PI / 2), 12)
