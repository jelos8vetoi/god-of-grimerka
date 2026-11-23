## «ГОЛДА 67», новый ДВОР — «МИКРОРАЙОН 67», 300 × 290 м (редизайн, 2026-11-25).
## Мир собирается из данных, а не из чисел в коде:
##   data/dvor2/layout.json   — план района (tools/dvor_plan_v3.py): дома, дороги, тротуары, тропы, отметки
##   data/dvor2/props.json    — декорации кластерами (tools/dvor_props.py), лампы подъездов и огни бочек
##   data/dvor2/manifest.json — размеры моделей (tools/dvor2_assets.py) и точки арки дома № 81
##   assets/golda67/dvor2/<id>.glb — модели района (одна сетка на модель)
## План: X — восток, Y — север; в игре x = X, z = −Y. Поворот вокруг вертикали совпадает (rotation.y = угол плана).
## Арка дома № 81: створки решётки gate_L / gate_R и цепь gate_chain — отдельные узлы модели; open_gate() их открывает.
## Пока класс не подключён к забегу (Golda67 строит прежний G67Yard): смотреть — «-- --dvor2view=<папка>».
class_name G67Dvor2
extends Node3D

const DIR := "res://assets/golda67/dvor2/"
const DATA := "res://data/dvor2/"
const COURT_BOARD := "game:g67_court_board"
## модели без преграды для героя (плоские, мелкие или те, под которыми проходят)
const NO_BODY := ["manhole", "crow_2", "sled", "cat_statue", "boombox", "laundry", "gazebo", "yard_shelter", "swings", "seesaw", "snow_pile", "trashbag",
	"box_cardboard", "crate_plastic", "bush_bare", "tyre_old", "log_dead", "sign_1", "sign_5", "sign_10", "sign_11", "sign_13", "snowman", "pole_wires"]
## модели-«стволы»: преграда — тонкий цилиндр, а не габарит кроны
const TRUNK := ["tree_", "pine_", "snow_pine", "pole_concrete", "lamp_", "billboard_"]
const LIGHT := {"street": [5.0, 17.0, Color(1.0, 0.66, 0.34)], "yard": [4.2, 13.0, Color(1.0, 0.7, 0.4)], "door": [2.2, 6.5, Color(1.0, 0.78, 0.5)],
	"shop": [3.0, 8.0, Color(1.0, 0.86, 0.66)], "rink": [5.0, 26.0, Color(0.92, 0.96, 1.0)], "shawa": [2.0, 8.0, Color(1.0, 0.55, 0.16)],
	"fire": [1.6, 5.0, Color(1.0, 0.36, 0.08)], "arch": [1.5, 8.0, Color(1.0, 0.8, 0.5)]}

var layout: Dictionary = {}
var props: Dictionary = {}
var man: Dictionary = {}
var missing: Array = []
var lamps: Array = []            # [[x, y, высота, вид]] в координатах плана
var court := Rect2()             # коробка Миши в координатах плана (x, y — юго-западный угол)
var arch: Dictionary = {}        # дом № 81: {x, y, st — данные лестницы}
var gate_open := false
var count := {"models": 0, "bodies": 0, "lights": 0}
var _scenes: Dictionary = {}
var _mats: Dictionary = {}
var _gate_l: Node3D
var _gate_r: Node3D
var _gate_chain: Node3D
var _gate_block: StaticBody3D

static func to3(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x, h, -y)

func _json(n: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(DATA + n)
	var d: Variant = JSON.parse_string(txt)
	if d is Dictionary:
		return d
	missing.append(DATA + n)
	return {}

func _scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var path := (("res://assets/golda67/" + id.substr(5)) if id.begins_with("game:") else (DIR + id)) + ".glb"
	var sc: PackedScene = null
	if ResourceLoader.exists(path):
		sc = load(path) as PackedScene
	if sc == null and not missing.has(path):
		missing.append(path)
	_scenes[id] = sc
	return sc

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = xf * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		if c is Node3D:
			var b := _aabb(c, xf * (c as Node3D).transform)
			if b.size != Vector3.ZERO:
				out = b if first else out.merge(b)
				first = false
	return out

func _tune(n: Node, small: bool, far: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if small:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if far > 0.0:
			mi.visibility_range_end = far
			mi.visibility_range_end_margin = 10.0
	for c in n.get_children():
		_tune(c, small, far)

## Поставить модель: центр основания — в (x, y) плана, низ — на земле. fit > 0 — вписать наибольшую сторону основания в fit метров.
func put(id: String, x: float, y: float, yaw_deg: float, k := 1.0, z := 0.0, fit := 0.0, on_ground := true) -> Node3D:
	var sc := _scene(id)
	if sc == null:
		return null
	var inst := sc.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = id.replace(":", "_").replace("/", "_")
	holder.position = to3(x, y, z)
	holder.rotation.y = deg_to_rad(yaw_deg)
	var big := 1.0
	if man.has(id):
		var m: Dictionary = man[id]
		var lo: Array = m["lo"]
		var sz: Array = m["size"]
		if fit > 0.0:
			k = fit / maxf(maxf(float(sz[0]), float(sz[1])), 0.001)
		inst.position = Vector3(-(float(lo[0]) + float(sz[0]) * 0.5) * k, (-float(lo[2]) * k) if on_ground else 0.0, (float(lo[1]) + float(sz[1]) * 0.5) * k)
		big = maxf(maxf(float(sz[0]), float(sz[1])), float(sz[2])) * k
	else:
		var bb := _aabb(inst, Transform3D.IDENTITY)
		if fit > 0.0:
			k = fit / maxf(maxf(bb.size.x, bb.size.z), 0.001)
		var c := bb.get_center()
		inst.position = Vector3(-c.x * k, -bb.position.y * k, -c.z * k)
		big = maxf(maxf(bb.size.x, bb.size.y), bb.size.z) * k
	inst.scale = Vector3.ONE * k
	holder.add_child(inst)
	add_child(holder)
	_tune(inst, big < 2.5, 110.0 if big < 2.5 else (220.0 if big < 9.0 else 0.0))
	count["models"] = int(count["models"]) + 1
	return holder

func _mat(nm: String, col: Color, rough := 0.9, bump := 0.0) -> StandardMaterial3D:
	if _mats.has(nm):
		return _mats[nm]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if bump > 0.0:
		var nz := FastNoiseLite.new()
		nz.frequency = 0.02
		nz.fractal_octaves = 4
		var tx := NoiseTexture2D.new()
		tx.noise = nz
		tx.as_normal_map = true
		tx.bump_strength = 6.0
		tx.seamless = true
		m.normal_enabled = true
		m.normal_texture = tx
		m.normal_scale = bump
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.12
	_mats[nm] = m
	return m

## Плоская плита (земля, дорога, тротуар): прямоугольник плана w × h, по высоте z0…z1
func slab(x: float, y: float, w: float, h: float, z0: float, z1: float, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, z1 - z0, h)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = to3(x, y, (z0 + z1) * 0.5)
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Преграда: коробка w × h плана, высотой hgt от z0. layer 1 — герой и враги, 8 — камера.
func solid(x: float, y: float, w: float, h: float, hgt: float, yaw_deg := 0.0, z0 := 0.0, layer := 9) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, hgt, h)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = to3(x, y, z0 + hgt * 0.5)
	sb.rotation.y = deg_to_rad(yaw_deg)
	add_child(sb)
	count["bodies"] = int(count["bodies"]) + 1
	return sb

func _trunk(x: float, y: float, r: float, hgt: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 9
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = hgt
	cs.shape = cy
	sb.add_child(cs)
	sb.position = to3(x, y, hgt * 0.5)
	add_child(sb)
	count["bodies"] = int(count["bodies"]) + 1

func _body_for(id: String, x: float, y: float, yaw_deg: float, k: float) -> void:
	if not man.has(id) or NO_BODY.has(id):
		return
	for t in TRUNK:
		if id.begins_with(String(t)):
			_trunk(x, y, 0.32, 4.0)
			return
	var sz: Array = man[id]["size"]
	if float(sz[2]) * k < 0.25:
		return
	solid(x, y, float(sz[0]) * k, float(sz[1]) * k, float(sz[2]) * k, yaw_deg)

func _light(x: float, y: float, h: float, kind: String) -> void:
	var p: Array = LIGHT[kind]
	var l := OmniLight3D.new()
	l.light_color = p[2]
	l.light_energy = float(p[0])
	l.omni_range = float(p[1])
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	l.distance_fade_length = 25.0
	l.position = to3(x, y, h)
	add_child(l)
	count["lights"] = int(count["lights"]) + 1

func _yaw_for(it: Dictionary, id: String) -> float:
	var yw: float = float(it["yaw"])
	if bool(it.get("mark", false)) or id.begins_with("game:") or not man.has(id):
		return yw
	var sz: Array = man[id]["size"]
	var sx: float = float(sz[0])
	var sy: float = float(sz[1])
	var w: float = float(it["w"])
	var h: float = float(it["h"])
	var base := 0.0 if absf(sx - w) + absf(sy - h) <= absf(sy - w) + absf(sx - h) else 90.0
	return base + (180.0 if (is_equal_approx(yw, 180.0) or is_equal_approx(yw, -90.0)) else 0.0)

func build() -> void:
	layout = _json("layout.json")
	props = _json("props.json")
	man = _json("manifest.json")
	if layout.is_empty() or man.is_empty():
		return
	var snow := _mat("snow", Color(0.80, 0.84, 0.92), 0.92, 0.5)
	var road := _mat("road", Color(0.075, 0.08, 0.09), 0.55)
	var lot := _mat("lot", Color(0.12, 0.125, 0.14), 0.6)
	var walk := _mat("walk", Color(0.50, 0.53, 0.58), 0.9, 0.3)
	var slush := _mat("slush", Color(0.30, 0.29, 0.28), 0.6)
	var trod := _mat("trod", Color(0.62, 0.66, 0.74), 0.9, 0.35)
	var ice := _mat("ice", Color(0.50, 0.62, 0.74), 0.12)
	var rut := _mat("rut", Color(0.035, 0.038, 0.045), 0.3)
	var pack := _mat("pack", Color(0.42, 0.44, 0.48), 0.7)
	var x0: float = float(layout["x"][0])
	var x1: float = float(layout["x"][1])
	var y0: float = float(layout["y"][0])
	var y1: float = float(layout["y"][1])
	_arch_data()
	_ground(snow, x0, x1, y0, y1)
	for it_v in layout["items"]:
		var it: Dictionary = it_v
		var id: String = String(it["model"])
		var cat: String = String(it["cat"])
		var x: float = float(it["x"])
		var y: float = float(it["y"])
		var w: float = float(it["w"])
		var h: float = float(it["h"])
		var mark: bool = bool(it.get("mark", false))
		if cat == "road" and not mark:
			var street: bool = String(it["id"]).begins_with("ROAD")
			slab(x, y, w, h, 0.0, 0.05, road if street else lot)
			if street:
				_street(x, y, w, h, slush, pack, rut)
			continue
		if cat == "walk":
			slab(x, y, w, h, 0.0, 0.035, walk)
			continue
		if String(it["id"]) == "COURT":
			_court(x, y, w, h, ice)
			continue
		if id == "":
			continue
		if id == "res_arch_81":
			_arch_house(it)
			continue
		var yw := _yaw_for(it, id)
		if String(it["id"]) == "SHAWA":
			yw += 90.0
		var hd := put(id, x, y, yw, 1.0, 0.0, maxf(w, h) if id.begins_with("game:") else 0.0)
		if hd == null:
			continue
		if not mark:
			solid(x, y, w, h, float(it.get("hgt", 3.0)))
		else:
			_body_for(id, x, y, yw, 1.0)
		if String(it["id"]) == "SHAWA":
			_shawa_sign(x, y - h * 0.5 - 0.12)
	for pts_v in layout.get("paths", []):
		var pts: Array = pts_v
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			slab((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, a.distance_to(b) + 1.0, 1.6, 0.0, 0.025, trod, rad_to_deg((b - a).angle()))
	for q_v in props.get("props", []):
		var q: Dictionary = q_v
		var k: float = 1.0 if q["k"] == null else float(q["k"])
		var hq := put(String(q["m"]), float(q["x"]), float(q["y"]), float(q["yaw"]), k, float(q["z"]))
		if hq != null and float(q["z"]) == 0.0:
			_body_for(String(q["m"]), float(q["x"]), float(q["y"]), float(q["yaw"]), k)
	_streets_furniture(x0, x1, y0, y1)
	_skyline(x0, x1, y0, y1)
	for e_v in props.get("entr", []):
		lamps.append([float(e_v[0]), float(e_v[1]), 2.6, "door"])
	for f_v in props.get("fires", []):
		lamps.append([float(f_v[0]), float(f_v[1]), 1.1, "fire"])
	for lv in lamps:
		_light(float(lv[0]), float(lv[1]), float(lv[2]), String(lv[3]))

func _ground(snow: Material, x0: float, x1: float, y0: float, y1: float) -> void:
	var gx0 := x0 - 200.0
	var gx1 := x1 + 200.0
	var gy0 := y0 - 200.0
	var gy1 := y1 + 200.0
	var parts: Array = [[gx0, gx1, gy0, gy1]]
	if not arch.is_empty():
		var st: Dictionary = arch["st"]
		var hx0: float = float(arch["x"]) + float(st["gate_y"])
		var hx1: float = hx0 + 8.5
		var hy0: float = float(arch["y"]) - float(st["x"][1])
		var hy1: float = float(arch["y"]) - float(st["x"][0])
		parts = [[gx0, hx0, gy0, gy1], [hx1, gx1, gy0, gy1], [hx0, hx1, gy0, hy0], [hx0, hx1, hy1, gy1]]
	for p in parts:
		var w: float = float(p[1]) - float(p[0])
		var h: float = float(p[3]) - float(p[2])
		var cx: float = (float(p[0]) + float(p[1])) * 0.5
		var cy: float = (float(p[2]) + float(p[3])) * 0.5
		slab(cx, cy, w, h, -0.5, 0.0, snow)
		solid(cx, cy, w, h, 0.5, 0.0, -0.5)

func _street(x: float, y: float, w: float, h: float, slush: Material, pack: Material, rut: Material) -> void:
	if w > h:
		for s in [-1.0, 1.0]:
			slab(x, y + s * (h * 0.5 - 0.5), w, 1.0, 0.05, 0.07, slush)
		slab(x, y, w, 0.9, 0.05, 0.062, pack)
		for s in [-2.6, -1.2, 1.2, 2.6]:
			slab(x, y + s, w, 0.42, 0.05, 0.058, rut)
	else:
		for s in [-1.0, 1.0]:
			slab(x + s * (w * 0.5 - 0.5), y, 1.0, h, 0.05, 0.07, slush)
		slab(x, y, 0.9, h, 0.05, 0.062, pack)
		for s in [-2.6, -1.2, 1.2, 2.6]:
			slab(x + s, y, 0.42, h, 0.05, 0.058, rut)

## Каноничная коробка Миши: борта с нахлёстом (щелей нет), калитка 4,4 м с юга, лёд, четыре мачты
func _court(x: float, y: float, w: float, h: float, ice: Material) -> void:
	court = Rect2(x - w * 0.5, y - h * 0.5, w, h)
	var bx0 := x - w * 0.5
	var bx1 := x + w * 0.5
	var by0 := y - h * 0.5
	var by1 := y + h * 0.5
	slab(x, y, w, h, 0.0, 0.04, ice)
	var gw := 4.4
	var seg_s := h / 5.0
	for i in range(6):
		var sg := w / 6.0
		_board(bx0 + (float(i) + 0.5) * sg, by1, 90.0, sg, seg_s)
	for i in range(5):
		_board(bx0, by0 + (float(i) + 0.5) * seg_s, 0.0, seg_s, seg_s)
		_board(bx1, by0 + (float(i) + 0.5) * seg_s, 180.0, seg_s, seg_s)
	for sgn in [-1.0, 1.0]:
		var run := w * 0.5 - gw * 0.5 + 0.55
		var sg2 := run / 3.0
		for i in range(3):
			_board(x + sgn * (gw * 0.5 - 0.55 + (float(i) + 0.5) * sg2), by0, -90.0, sg2, seg_s)
	put("game:g67_court_gate", x, by0, 0.0, 1.0, 0.0, gw)
	# преграды бортов: север, запад, восток целиком; юг — с проёмом калитки
	solid(x, by1, w, 0.3, 2.6)
	solid(bx0, y, 0.3, h, 2.6)
	solid(bx1, y, 0.3, h, 2.6)
	var side := (w - gw) * 0.5
	solid(bx0 + side * 0.5, by0, side, 0.3, 2.6)
	solid(bx1 - side * 0.5, by0, side, 0.3, 2.6)
	for c in [Vector2(bx0 - 1.2, by0 - 1.2), Vector2(bx1 + 1.2, by0 - 1.2), Vector2(bx0 - 1.2, by1 + 1.2), Vector2(bx1 + 1.2, by1 + 1.2)]:
		put("game:g67_floodlight_mast", c.x, c.y, 0.0, 1.0, 0.0, 3.6)
		_trunk(c.x, c.y, 0.6, 6.0)
		lamps.append([c.x, c.y, 11.0, "rink"])

func _board(x: float, y: float, yaw_deg: float, length: float, base_len: float) -> void:
	var hb := put(COURT_BOARD, x, y, yaw_deg, 1.0, 0.0, base_len)
	if hb != null:
		hb.scale = Vector3(1.0, 1.0, length * 1.035 / base_len)      # длинная ось борта — вдоль z узла

func _shawa_sign(x: float, fy: float) -> void:
	slab(x, fy, 4.6, 0.12, 3.25, 4.25, _mat("signbg", Color(0.05, 0.03, 0.03), 0.6))
	for row in [["ШАУРМА 67", 3.78, 150, Color(1.0, 0.5, 0.08)], ["КРУГЛОСУТОЧНО", 3.38, 44, Color(1.0, 0.16, 0.1)]]:
		var lb := Label3D.new()
		lb.text = String(row[0])
		lb.font_size = int(row[2])
		lb.pixel_size = 0.005
		lb.modulate = row[3]
		lb.outline_size = 0
		lb.shaded = false
		lb.position = to3(x, fy - 0.08, float(row[1]))
		add_child(lb)
	lamps.append([x, fy - 3.0, 2.5, "shawa"])

func _streets_furniture(x0: float, x1: float, y0: float, y1: float) -> void:
	# забор «ромбик» по северной, западной и восточной границе; вдоль ГСК
	_fence(x0 + 3.0, y1 - 2.4, x1 - 3.0, y1 - 2.4)
	_fence(x0 + 2.4, y0 + 4.0, x0 + 2.4, y1 - 4.0)
	_fence(x1 - 2.4, y0 + 4.0, x1 - 2.4, y1 - 4.0)
	_fence(-142.0, -3.0, -78.0, -3.0)
	solid((x0 + x1) * 0.5, y0 + 1.0, x1 - x0, 1.0, 3.0)          # насыпь железной дороги — южная граница
	var i := 0
	var lx := int(x0) + 12
	while lx < int(x1) - 8:
		if absi(lx - 66) > 8:
			put("lamp_%d" % (1 + i % 2), float(lx), -30.6, 90.0, 2.4)
			_trunk(float(lx), -30.6, 0.2, 5.0)
			lamps.append([float(lx), -28.6, 8.0, "street"])
		lx += 26
		i += 1
	var ly := int(y0) + 14
	while ly < int(y1) - 8:
		if absi(ly + 24) > 8:
			put("lamp_3", 59.4, float(ly), 0.0, 2.4)
			_trunk(59.4, float(ly), 0.2, 5.0)
			lamps.append([61.6, float(ly), 8.0, "street"])
		ly += 26
	var k := 0
	for p in [[0, -100], [-20, -78], [26, -74], [-96, -104], [-110, -66], [104, -104], [120, -72], [116, 104], [96, 96], [-10, 14], [36, 30], [-46, 100], [20, 100],
			[-30, 60], [40, 60], [-66.3, 34], [-66.3, 78], [112, 34], [-96, 104], [-124, 104]]:
		put("lamp_5", float(p[0]), float(p[1]), float(k * 67 % 360), 2.0)
		_trunk(float(p[0]), float(p[1]), 0.2, 4.0)
		lamps.append([float(p[0]), float(p[1]), 6.2, "yard"])
		k += 1
	for sx in [-44, -36, -30, -20, -12, -6, 0]:
		lamps.append([float(sx), -12.5, 2.6, "shop"])
	for p in [[84, -13, 3.0], [96, -62, 3.0], [-60, 36, 2.4], [-56, 14, 3.0], [-110, 111, 4.0]]:
		lamps.append([float(p[0]), float(p[1]), float(p[2]), "shop"])
	for s in [["sign_5", 56.5, -17.2, 0], ["sign_10", 59.6, -30.2, 0], ["sign_10", 72.4, -17.8, 180], ["sign_11", 59.6, -17.8, 90], ["sign_11", 72.4, -30.2, -90],
			["sign_13", -8, 92.6, 0], ["sign_13", -64, -47, 90], ["sign_11", 20, -30.2, 0], ["sign_11", 20, -17.8, 180], ["sign_10", -73.6, -30.2, 0], ["sign_13", 96, 33.8, 0]]:
		put("sign_1", float(s[1]), float(s[2]), 0.0, 0.3)
		put(String(s[0]), float(s[1]), float(s[2]), float(s[3]), 0.3, 2.1)
		_trunk(float(s[1]), float(s[2]), 0.08, 3.0)
	var px := -44
	while px < 62:
		put("pole_wires", float(px), 93.2, 90.0)
		_trunk(float(px), 93.2, 0.18, 6.0)
		px += 16
	var py := 4
	while py < 90:
		put("pole_wires", -144.5, float(py), 0.0)
		py += 16
	py = -136
	while py < -40:
		put("pole_wires", -66.5, float(py), 0.0)
		_trunk(-66.5, float(py), 0.18, 6.0)
		py += 16
	for p in [[-76, 22, 0], [-76, 45, 90], [-76, 67, 0], [112, 26, 90], [-36, 100, 0]]:
		put("pole_concrete", float(p[0]), float(p[1]), float(p[2]))
		_trunk(float(p[0]), float(p[1]), 0.2, 6.0)

func _fence(ax: float, ay: float, bx: float, by: float) -> void:
	var ln := Vector2(ax, ay).distance_to(Vector2(bx, by))
	var n := int(ln / 3.43)
	var yw := rad_to_deg(atan2(by - ay, bx - ax)) + 90.0
	for i in range(n):
		var t := (float(i) + 0.5) / float(n)
		put("fence_rhombus", ax + (bx - ax) * t, ay + (by - ay) * t, yw)
	solid((ax + bx) * 0.5, (ay + by) * 0.5, ln, 0.4, 3.0, yw - 90.0)

func _skyline(x0: float, x1: float, y0: float, y1: float) -> void:
	for s in [["tower_16_wide", -40.0, y1 + 80.0, 0], ["tower_9_wide", 60.0, y1 + 70.0, 0], ["tower_16_slab", x0 - 80.0, 60.0, 0], ["tower_9_slab", x0 - 70.0, -40.0, 0],
			["tower_9_wide", x1 + 80.0, 70.0, 90], ["tower_16_slab", x1 + 70.0, -50.0, 0], ["tower_9_slab", -40.0, y0 - 80.0, 90], ["tower_16_wide", 90.0, y0 - 90.0, 0],
			["smoke_stacks", -110.0, y1 + 30.0, 0]]:
		put(String(s[0]), float(s[1]), float(s[2]), float(s[3]))
	put("res_long_9", x1 + 42.0, 20.0, 0.0, 0.75)
	put("res_long_9", -70.0, y0 - 44.0, 90.0, 0.75)

# ------------------------------------------------------------------ арка дома № 81 и спуск в Подземку
func _arch_data() -> void:
	for it_v in layout["items"]:
		var it: Dictionary = it_v
		if String(it["model"]) == "res_arch_81" and man.has("res_arch_81"):
			arch = {"x": float(it["x"]), "y": float(it["y"]), "st": man["res_arch_81"]["stairs"]}

## Точка модели арки (оси Blender: x — вдоль дома, y — сквозь дом, z — вверх) → координаты плана. Дом повёрнут на 270°.
func arch_xy(lx: float, ly: float) -> Vector2:
	return Vector2(float(arch["x"]) + ly, float(arch["y"]) - lx)

func _arch_box(x0: float, x1: float, ya: float, yb: float, z0: float, z1: float, layer := 9) -> StaticBody3D:
	var c := arch_xy((x0 + x1) * 0.5, (ya + yb) * 0.5)
	return solid(c.x, c.y, yb - ya, x1 - x0, z1 - z0, 0.0, z0, layer)

func _arch_house(it: Dictionary) -> void:
	var hd := put("res_arch_81", float(it["x"]), float(it["y"]), 270.0, 1.0, 0.0, 0.0, false)
	if hd == null:
		return
	_gate_l = hd.find_child("gate_L", true, false) as Node3D
	_gate_r = hd.find_child("gate_R", true, false) as Node3D
	_gate_chain = hd.find_child("gate_chain", true, false) as Node3D
	var st: Dictionary = arch["st"]
	var hx: float = float(man["res_arch_81"]["size"][0]) * 0.5
	var hy := 9.16
	var gy: float = float(st["gate_y"])
	var sy1: float = float(st["bottom_y"])
	var ax := 5.25
	var az := 4.6
	var sx0: float = float(st["x"][0])
	var sx1: float = float(st["x"][1])
	var hgt: float = float(it.get("hgt", 13.3))
	_arch_box(-hx, -ax, -hy, hy, 0.0, hgt)                       # крылья дома
	_arch_box(ax, hx, -hy, hy, 0.0, hgt)
	_arch_box(-ax, ax, -hy, hy, az, hgt)                          # этажи над проездом
	_arch_box(sx1, 1.25, gy, gy + 8.5, 0.0, az - 0.45)            # парапет с решёткой до потолка
	for cy in [-hy + 0.5, hy - 0.5]:
		_arch_box(0.75, 1.25, cy - 0.25, cy + 0.25, 0.0, az - 0.45)
	_gate_block = _arch_box(sx0, sx1, gy - 0.12, gy + 0.12, 0.0, az - 0.45)
	_arch_box(sx1, sx1 + 0.3, gy, sy1 - 0.3, -5.3, 0.0)           # стена шахты под парапетом
	_arch_box(sx0, ax, sy1, hy, -5.5, -5.0)                       # нижняя площадка и коридор
	_arch_box(sx0, ax, hy - 0.05, hy + 0.3, -5.0, -2.3)           # торцевая стена
	_arch_box(sx1, ax, sy1 - 0.3, sy1, -5.0, -2.3)                # стена коридора
	_arch_box(ax - 0.05, ax + 0.3, sy1, hy, -5.0, -2.3)           # граница сцены — точка стыка с Подземкой
	_arch_box(sx0, 1.25, gy + 8.5, hy, -0.5, 0.0)                 # перекрытие над низом марша (пол прохода)
	# марш: наклонная плита от решётки вниз на 5 м
	var run: float = float(st["run"])
	var drop: float = float(st["drop"])
	var ang := atan2(drop, run)
	var length := sqrt(run * run + drop * drop)
	var mid := arch_xy((sx0 + sx1) * 0.5, gy + run * 0.5)
	var sb := StaticBody3D.new()
	sb.collision_layer = 9
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 0.4, sx1 - sx0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = to3(mid.x, mid.y, -drop * 0.5 - 0.2 * cos(ang))
	sb.rotation.z = -ang
	add_child(sb)
	count["bodies"] = int(count["bodies"]) + 1
	for lv in st["lamps"]:
		var lp := arch_xy(float(lv[0]), float(lv[1]))
		lamps.append([lp.x, lp.y, 3.7, "arch"])
	var bl := arch_xy(-2.2, sy1 - 2.0)
	lamps.append([bl.x, bl.y, -2.6, "arch"])

## Верх лестницы, низ марша и точка стыка с Подземкой — в координатах мира
func stairs_top() -> Vector3:
	var p := arch_xy(-2.25, float(arch["st"]["gate_y"]))
	return to3(p.x, p.y, 0.0)

func stairs_bottom() -> Vector3:
	var p := arch_xy(-2.25, float(arch["st"]["bottom_y"]) + 0.6)
	return to3(p.x, p.y, -5.0)

func link_point() -> Vector3:
	var l: Array = arch["st"]["link"]
	var p := arch_xy(float(l[0]), float(l[1]))
	return to3(p.x, p.y, float(l[2]))

## Открыть решётку: створки расходятся внутрь, цепь с замком исчезает, преграда убирается. instant — без анимации (после загрузки).
func open_gate(instant := false) -> void:
	if gate_open or arch.is_empty():
		return
	gate_open = true
	if is_instance_valid(_gate_block):
		_gate_block.queue_free()
	if is_instance_valid(_gate_chain):
		_gate_chain.visible = false
	var pairs: Array = [[_gate_l, deg_to_rad(95.0)], [_gate_r, deg_to_rad(-95.0)]]
	for p in pairs:
		var n: Node3D = p[0]
		if not is_instance_valid(n):
			continue
		if instant:
			n.rotation.y = float(p[1])
		else:
			var tw := create_tween()
			tw.tween_property(n, "rotation:y", float(p[1]), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
