## Ворота контрольных точек VACUUM RACING — только вид. Логика (порядок, пересечение, круги, сеть) — в race.gd
## (_pass_gate), здесь лишь читается race.local.next_gate.
## Каждая точка — простая аркадная арка над дорогой: светлая рамка со скруглёнными верхними углами (одна сетка,
## один вызов отрисовки) и гирлянда лампочек по её лицу (MultiMesh). Внутри арки ничего нет — дорогу видно.
## Следующие ворота яркие, лампочки бегут красно-белой волной, над аркой ромб; за ними — тусклее; остальные
## едва светятся. Проезд — короткая вспышка и лёгкий «вздох» арки. Материалы без освещения: днём, ночью и в
## дождь арка выглядит одинаково. Цвета — палитра HUD: белый и красный.
class_name RaceGates
extends Node3D

const H := 4.6                     # высота арки, м
const R := 1.5                     # радиус скругления верхних углов, м
const TH := 0.34                   # толщина рамки, м
const BULB_STEP := 0.55            # шаг лампочек вдоль арки, м
const WHITE := Color(0.95, 0.96, 0.97)
const RED := Color(0.86, 0.09, 0.11)
const DIM := Color(0.55, 0.57, 0.6)

var race
var gates: Array = []              # [{root, frame, halo, bulbs (MultiMesh), gem, k, e, burst, pos}]
var seen_next := -1
var clock := 0.0

func setup(r) -> void:
	race = r
	var xf: RaceTrack = r.track
	for k in xf.gates.size():
		gates.append(_make(xf.gates[k], k))

## путь арки в плоскости XY: левая нога → скругление → перекладина → скругление → правая нога
static func _path(hw: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var legs := int(ceil((H - R) / 0.5))
	for i in legs + 1:
		p.append(Vector2(-hw, (H - R) * float(i) / float(legs)))
	for i in range(1, 9):
		var a := PI - PI * 0.5 * float(i) / 8.0
		p.append(Vector2(-hw + R, H - R) + Vector2(cos(a), sin(a)) * R)
	var top := int(ceil((2.0 * (hw - R)) / 0.8))
	for i in range(1, top):
		p.append(Vector2(lerpf(-hw + R, hw - R, float(i) / float(top)), H))
	for i in range(0, 9):
		var a := PI * 0.5 - PI * 0.5 * float(i) / 8.0
		p.append(Vector2(hw - R, H - R) + Vector2(cos(a), sin(a)) * R)
	for i in range(1, legs + 1):
		p.append(Vector2(hw, H - R - (H - R) * float(i) / float(legs)))
	return p

## квадратная «труба» вдоль пути: th — ширина в плоскости арки, dz — половина толщины вдоль дороги
static func _tube(path: PackedVector2Array, th: float, dz: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x) * th * 0.5
		var c := path[i]
		rings.append([Vector3(c.x + n.x, c.y + n.y, -dz), Vector3(c.x + n.x, c.y + n.y, dz),
			Vector3(c.x - n.x, c.y - n.y, dz), Vector3(c.x - n.x, c.y - n.y, -dz)])
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for s in 4:
			var s2 := (s + 1) % 4
			st.add_vertex(a[s])
			st.add_vertex(b[s])
			st.add_vertex(b[s2])
			st.add_vertex(a[s])
			st.add_vertex(b[s2])
			st.add_vertex(a[s2])
	return st.commit()

func _mat(c: Color, add := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.disable_receive_shadows = true
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

func _inst(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _make(g: Dictionary, k: int) -> Dictionary:
	var tan: Vector3 = g["tan"]
	tan.y = 0.0
	tan = tan.normalized() if tan.length() > 0.01 else Vector3.FORWARD
	var right := Vector3.UP.cross(tan).normalized()
	var hw := float(g["w"]) * 0.5 + RaceTrack.SHOULDER * 0.6
	var root := Node3D.new()
	root.transform = Transform3D(Basis(right, Vector3.UP, tan), g["pos"] as Vector3)
	add_child(root)
	var path := _path(hw)
	var frame := _mat(WHITE)
	_inst(root, _tube(path, TH, TH * 0.5), frame)
	var halo := _mat(WHITE, true)                   # мягкий ореол — та же арка толще, складывается со светом
	_inst(root, _tube(path, TH * 2.6, TH * 0.9), halo)
	# лампочки на обеих сторонах рамки (видно и подъезжая, и при взгляде назад)
	var pts: Array = []
	var acc := 0.0
	for i in range(1, path.size()):
		acc += path[i].distance_to(path[i - 1])
		if acc >= BULB_STEP:
			acc = 0.0
			pts.append(path[i])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bulb := SphereMesh.new()
	bulb.radius = 0.1
	bulb.height = 0.2
	bulb.radial_segments = 8
	bulb.rings = 4
	mm.mesh = bulb
	mm.instance_count = pts.size() * 2
	for i in pts.size():
		var p: Vector2 = pts[i]
		for sd in 2:
			mm.set_instance_transform(i * 2 + sd, Transform3D(Basis(), Vector3(p.x, p.y, (TH * 0.5 + 0.06) * (-1.0 if sd == 0 else 1.0))))
	var bm := _mat(WHITE)
	bm.vertex_color_use_as_albedo = true
	bm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = bm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var gem := Label3D.new()
	gem.text = "◆"
	gem.font_size = 96
	gem.pixel_size = 0.012
	gem.outline_size = 18
	gem.outline_modulate = Color(0, 0, 0, 0.6)
	gem.modulate = RED
	gem.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	gem.shaded = false
	gem.position = Vector3(0, H + 1.1, 0)
	root.add_child(gem)
	return {"root": root, "frame": frame, "halo": halo, "bulbs": mm, "nb": pts.size(), "gem": gem,
		"k": k, "e": 0.0, "burst": 0.0, "pos": g["pos"]}

func _process(dt: float) -> void:
	if race == null or gates.is_empty():
		return
	clock += dt
	var me: RaceRider = race.local
	if me == null:
		return
	var nxt: int = me.next_gate
	if nxt != seen_next:
		if seen_next >= 0 and me.get_meta("armed", false):
			gates[seen_next]["burst"] = 1.0         # проехал: вспышка тех, что были следующими
		seen_next = nxt
	var n := gates.size()
	var pulse := 0.5 + 0.5 * sin(clock * 4.0)
	for g in gates:
		var k: int = g["k"]
		var ahead := posmod(k - nxt, n)               # 0 — следующие, 1 — за ними…
		var want := 1.0 if ahead == 0 else (0.4 if ahead == 1 else 0.14)
		if me.finished:
			want = 0.14
		var e: float = lerpf(float(g["e"]), want, 1.0 - exp(-4.0 * dt))
		g["e"] = e
		var b: float = maxf(0.0, float(g["burst"]) - dt * 1.8)
		g["burst"] = b
		var d: float = me.global_position.distance_to(g["pos"] as Vector3)
		var live := e * (0.88 + 0.12 * pulse) + b
		(g["frame"] as StandardMaterial3D).albedo_color = Color(DIM.lerp(WHITE, clampf(e, 0.0, 1.0)), clampf(0.35 + live * 0.65, 0.0, 1.0))
		(g["halo"] as StandardMaterial3D).albedo_color = Color(WHITE.lerp(RED, 0.3), clampf(live * 0.07 + b * 0.12, 0.0, 0.25))
		# гирлянда: у следующих — бегущая красно-белая волна, у остальных — ровный тусклый свет
		var mm: MultiMesh = g["bulbs"]
		var nb: int = g["nb"]
		var off := DIM.darkened(0.5)
		for i in nb:
			var c: Color
			if ahead == 0 and not me.finished:
				var wave := 0.5 + 0.5 * sin(float(i) * 0.9 - clock * 9.0)
				c = RED.lerp(WHITE, wave * wave)
			else:
				c = off.lerp(WHITE, clampf(e * 1.2, 0.0, 1.0))
			c = c.lerp(WHITE, b)
			mm.set_instance_color(i * 2, c)
			mm.set_instance_color(i * 2 + 1, c)
		var gem: Label3D = g["gem"]
		gem.visible = ahead == 0 and not me.finished
		if gem.visible:
			gem.position.y = H + 1.1 + sin(clock * 3.0) * 0.15
			gem.pixel_size = 0.012 * (1.0 + clampf((d - 30.0) / 150.0, 0.0, 1.5))   # издалека ромб крупнее
		# проезд: арка коротко «вздыхает» и возвращается
		(g["root"] as Node3D).scale = Vector3.ONE * (1.0 + (1.0 - b) * b * 0.35)
