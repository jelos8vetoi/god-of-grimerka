## Локации приквела «ГОЛДА 67». Наследует построитель кампании (свет, пол, помощники _box / _static_box / _light),
## но оформление своё — из моделей владельца (G67Models). Сейчас — хаб «ПОДЪЕЗД» (godot/docs/golda67/HUB_DESIGN.md).
## points — предметы, с которыми можно взаимодействовать: {id, title, hint, pos}; их читает контроллер Golda67.
##
## ПОДЪЕЗД — настоящая планировка панельного дома, а не комната с вещами (ось Z: +Z — улица, −Z — вглубь дома):
##
##        z = −6 ┌───────────────────────────────┐  площадка первого этажа, y = 1,5 м
##               │ ТВ   кв.1   сервант     кв.2  │  двери квартир, сервант и телевизор у стен
##               │ лавка                    кв.3 │  лавка dj flürr — вдоль левой стены
##        z = −1,7├───────┐                 стол  │
##               │ пролёт │   площадка     стойка│
##               │  вверх │  (перила)      стилей│
##        z = 1  ├───────┴───перила───────┬решёт.┤  край площадки над холлом; решётка на верхние этажи
##               │ ступени  дверь колясочной│пролёт│  y = 0: нижний холл
##               │ почтовые              стенд    │
##               │ ящики   ХОЛЛ           карта   │  ниша справа от входа
##        z = 6  └──────┐ тамбур ┌────────────────┘
##        z = 7,6       └─дверь──┘                    выход во двор
class_name G67World
extends "res://scripts/world.gd"

const HUB_X := 3.0        # полуширина лестничной клетки
const Z_BACK := -6.0      # дальняя стена площадки
const Z_EDGE := 1.0       # край площадки над холлом
const Z_FRONT := 6.0      # стена с входом
const Z_DOOR := 7.6       # входная дверь (конец тамбура)
const Z_STAIR_TOP := -1.7 # где пролёт выходит на площадку
const STAIR_X := -1.6     # правый край первого пролёта
const FLIGHT2_X := 1.6    # левый край второго пролёта
const LAND_Y := 1.5       # высота площадки первого этажа
const CEIL_Y := 4.7       # потолок лестничной клетки
const WALL_H := 3.83      # высота стенового модуля при ширине 4,35 м
const WALL_W := 4.35
const HUB_Z := 7.6        # для проверок: дальше этого по Z идти некуда

var points: Array = []
var actors := {}         # id → Rig (персонажи хаба)
var missing: Array = []  # модели, которых не нашлось (для проверки)
var spawn_pos := Vector3(0.0, 0.05, 5.0)
var m_green: StandardMaterial3D
var m_white: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_door: StandardMaterial3D
var m_wood: StandardMaterial3D

func _theme(d: String) -> Dictionary:
	if d == "g67_hub":
		return {"indoor": true, "sky": [Color(0.02, 0.02, 0.025)], "amb": Color(0.36, 0.36, 0.34), "fog": Color(0.1, 0.1, 0.1), "fog_d": 0.006,
			"key": Color(1, 0.95, 0.85), "key_e": 0.0, "g": [Color(0.3, 0.29, 0.27), Color(0.36, 0.35, 0.33)], "glow": 0.45, "exp": 1.0}
	if d == "g67_dvor":
		return {"sky": [Color(0.03, 0.05, 0.12), Color(0.2, 0.17, 0.28)], "fog": Color(0.2, 0.22, 0.32), "fog_d": 0.012, "key": Color(0.6, 0.7, 1.0), "key_e": 0.5,
			"g": [Color(0.55, 0.58, 0.66), Color(0.78, 0.82, 0.9)], "p": "snow"}
	return super._theme(d)

# ---------------------------------------------------------------- помощники
func _put(id: String, pos: Vector3, yaw: float, size: Vector3, fit := "h", solid := true) -> Node3D:
	var n := G67Models.spawn(id, self, pos, yaw, size, fit)
	if String(n.get_meta("from", "")) != "glb":
		missing.append(id)
		return n
	if solid:
		var s: Vector3 = n.get_meta("size", size)
		var sz := Vector3(s.x, s.y, s.z)
		if absf(fmod(absf(yaw), PI) - PI * 0.5) < 0.1:
			sz = Vector3(s.z, s.y, s.x)
		_static_box(pos + Vector3(0, sz.y * 0.5, 0), sz)
	return n

## Преграда только для камеры (слой 8, героя и врагов не трогает): потолок, стена над проёмом, сетка над бортом
func _cam_box(pos: Vector3, size: Vector3) -> void:
	_body_box(pos, size, 0.0, 8)

## Преграда только для героя и врагов (слой 1), камера её не видит: перила, низкая ограда
func _body_box(pos: Vector3, size: Vector3, rot: float, layer: int) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot
	add_child(sb)

func _point(id: String, title: String, hint: String, pos: Vector3) -> void:
	points.append({"id": id, "title": title, "hint": hint, "pos": pos})

func _actor(id: String, path: String, height: float, pos: Vector3, yaw: float, clips := {}) -> Rig:
	if not ResourceLoader.exists(path):
		missing.append(path)
		return null
	var r := Rig.new()
	add_child(r)
	r.setup(path, height, clips if not clips.is_empty() else Poses.pahan(), true, 1.0, id + ("_k" if not clips.is_empty() else ""))
	r.position = pos
	r.rotation.y = yaw
	r.play("Idle", 0.0)
	actors[id] = r
	return r

## Стеновой модуль владельца (зелёная краска, побелка, батарея): низ в точке pos, длина len вдоль стены.
## Лицо модуля — внутрь помещения (yaw: 0 — смотрит на +Z). mirror — батарея с другой стороны.
func _wall(pos: Vector3, yaw: float, length: float, mirror := false) -> void:
	var n := G67Models.spawn("g67_podezd_wall", self, pos, yaw, Vector3(WALL_W, 9, 9), "w")
	if String(n.get_meta("from", "")) != "glb":
		missing.append("g67_podezd_wall")
		return
	n.scale = Vector3((length / WALL_W) * (-1.0 if mirror else 1.0), 1.0, 1.0)

## Гладкая стена тем же двухцветием (для узких простенков, куда модуль с батареей не лезет): низ — зелёная краска
## до 2,1 м, выше — побелка. size.y — полная высота от pos.y.
func _plain_wall(pos: Vector3, size: Vector3) -> void:
	var paint := minf(2.1, size.y)
	_box(pos + Vector3(0, paint * 0.5, 0), Vector3(size.x, paint, size.z), m_green)
	if size.y > paint:
		_box(pos + Vector3(0, paint + (size.y - paint) * 0.5, 0), Vector3(size.x, size.y - paint, size.z), m_white)

## Дверь квартиры: коробка, полотно, ручка, глазок, табличка с номером, коврик. Стоит в стене, лицом по yaw.
func _apt_door(pos: Vector3, yaw: float, number: String, tint: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var leaf_m := _mat(tint, 0.0, 0.55)
	var parts := [
		[Vector3(0, 1.05, 0.0), Vector3(1.06, 2.1, 0.1), m_metal],        # коробка
		[Vector3(0, 1.02, 0.04), Vector3(0.9, 2.0, 0.08), leaf_m],         # полотно
		[Vector3(0.34, 1.0, 0.1), Vector3(0.04, 0.16, 0.05), m_metal],     # ручка
		[Vector3(0, 1.5, 0.085), Vector3(0.05, 0.05, 0.02), m_metal],      # глазок
		[Vector3(0, 1.72, 0.085), Vector3(0.16, 0.09, 0.015), _mat(Color(0.8, 0.7, 0.35), 0.0, 0.4)],   # табличка
		[Vector3(0, 0.012, 0.42), Vector3(0.8, 0.02, 0.5), _mat(Color(0.3, 0.16, 0.12), 0.0, 0.95)],    # коврик
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[0]
		root.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = number
	lbl.font_size = 40
	lbl.pixel_size = 0.0016
	lbl.modulate = Color(0.12, 0.1, 0.06)
	lbl.position = Vector3(0, 1.72, 0.096)
	root.add_child(lbl)

## Перила: стойки и поручень от a до b (на высоте пола этих точек), плюс невидимая стенка, чтобы не упасть.
func _railing(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	var mid := (a + b) * 0.5
	var yaw := atan2(d.x, d.z)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.07, 0.05, len)
	top.mesh = tb
	top.material_override = m_wood
	top.position = mid + Vector3(0, 0.95, 0)
	top.rotation.y = yaw
	add_child(top)
	var n := int(ceil(len / 0.22))
	for i in n + 1:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.93, 0.025)
		bar.mesh = bm
		bar.material_override = m_metal
		bar.position = a + d * (float(i) / float(n)) + Vector3(0, 0.465, 0)
		add_child(bar)
	var sz := Vector3(0.12, 1.3, len)
	_body_box(mid + Vector3(0, 0.65, 0), sz, yaw, 1)          # камера смотрит сквозь прутья

## Лампа: плафон на потолке или стене и свет от него
func _lamp(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var shade := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.18
	shade.mesh = sm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = col
	glow.emission_enabled = true
	glow.emission = col
	glow.emission_energy_multiplier = 2.2
	shade.material_override = glow
	shade.position = pos
	add_child(shade)
	var l := OmniLight3D.new()
	l.position = pos - Vector3(0, 0.25, 0)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = true
	add_child(l)
	return l

## Наклонная плита под ступенями: от (z0, y0) до (z1, y1) на ширине x0…x1 — по ней идут ноги
func _ramp(x0: float, x1: float, z0: float, y0: float, z1: float, y1: float) -> void:
	var run := z1 - z0
	var rise := y1 - y0
	var length := sqrt(run * run + rise * rise)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 | 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(absf(x1 - x0), 0.3, length)
	cs.shape = bs
	sb.add_child(cs)
	var ang := atan2(rise, -run)          # подъём при движении к −Z — положительный наклон вокруг X
	sb.rotation.x = ang
	var n := Vector3(0, cos(ang), sin(ang))            # нормаль плиты
	sb.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5) - n * 0.15
	add_child(sb)

# ---------------------------------------------------------------- ПОДЪЕЗД
func _deco_g67_hub(_T: Dictionary) -> void:
	m_green = _concrete(Color(0.07, 0.2, 0.09), Color(0.1, 0.27, 0.12), 0.35, 31)
	m_white = _concrete(Color(0.52, 0.51, 0.45), Color(0.66, 0.65, 0.58), 0.5, 21)
	m_floor = _concrete(Color(0.3, 0.29, 0.27), Color(0.38, 0.37, 0.34), 0.6, 5)
	m_metal = _mat(Color(0.2, 0.21, 0.23), 0.0, 0.45)
	m_door = _mat(Color(0.22, 0.13, 0.09), 0.0, 0.6)
	m_wood = _mat(Color(0.42, 0.29, 0.16), 0.0, 0.7)
	var X := HUB_X
	var t := 0.44                       # на сколько модуль стены утоплен за плоскость стены (его толщина / 2)

	# ---------- камерные преграды: потолок клетки, стена над проёмом тамбура, потолок тамбура, верх над вторым пролётом ----------
	_cam_box(Vector3(0, CEIL_Y + 0.1, (Z_BACK + Z_DOOR) * 0.5), Vector3(2 * X + 2.6, 0.2, Z_DOOR - Z_BACK + 2.6))
	_cam_box(Vector3(0, 2.2 + (CEIL_Y - 2.2) * 0.5, Z_FRONT + 0.15), Vector3(2.8, CEIL_Y - 2.2, 0.3))
	_cam_box(Vector3(0, 2.7, (Z_FRONT + Z_DOOR) * 0.5 + 0.15), Vector3(3.0, 0.2, Z_DOOR - Z_FRONT))
	_cam_box(Vector3((FLIGHT2_X + X) * 0.5, 3.0 + (CEIL_Y - 3.0) * 0.5, 3.85), Vector3(X - FLIGHT2_X, CEIL_Y - 3.0, 0.3))
	# ---------- коробка лестничной клетки: потолок и побелка выше модулей ----------
	_box(Vector3(0, CEIL_Y + 0.1, (Z_BACK + Z_DOOR) * 0.5), Vector3(2 * X + 2.6, 0.2, Z_DOOR - Z_BACK + 2.6), m_white)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * (X + 1.0), CEIL_Y * 0.5, 0.0), Vector3(0.5, CEIL_Y, Z_FRONT - Z_BACK + 2.0), m_white)      # за модулями, не в одной плоскости с ними
		_static_box(Vector3(sx * (X + 0.5), CEIL_Y * 0.5, 0.0), Vector3(1.0, CEIL_Y, Z_FRONT - Z_BACK + 1.0))
	_box(Vector3(0, CEIL_Y * 0.5, Z_BACK - 1.0), Vector3(2 * X + 2.4, CEIL_Y, 0.5), m_white)
	_static_box(Vector3(0, CEIL_Y * 0.5, Z_BACK - 0.5), Vector3(2 * X + 2.0, CEIL_Y, 1.0))

	# ---------- площадка первого этажа (y = 1,5): плита пола ----------
	_box(Vector3(0, LAND_Y * 0.5, (Z_BACK + Z_STAIR_TOP) * 0.5), Vector3(2 * X, LAND_Y, Z_STAIR_TOP - Z_BACK), m_floor)
	_static_box(Vector3(0, LAND_Y * 0.5, (Z_BACK + Z_STAIR_TOP) * 0.5), Vector3(2 * X, LAND_Y, Z_STAIR_TOP - Z_BACK))
	_box(Vector3((STAIR_X + X) * 0.5, LAND_Y * 0.5, (Z_STAIR_TOP + Z_EDGE) * 0.5), Vector3(X - STAIR_X, LAND_Y, Z_EDGE - Z_STAIR_TOP), m_floor)
	_static_box(Vector3((STAIR_X + X) * 0.5, LAND_Y * 0.5, (Z_STAIR_TOP + Z_EDGE) * 0.5), Vector3(X - STAIR_X, LAND_Y, Z_EDGE - Z_STAIR_TOP))
	# торец площадки над холлом — зелёная краска, как стены
	_box(Vector3((STAIR_X + FLIGHT2_X) * 0.5, LAND_Y * 0.5, Z_EDGE + 0.02), Vector3(FLIGHT2_X - STAIR_X, LAND_Y, 0.04), m_green)
	_box(Vector3(STAIR_X - 0.02, LAND_Y * 0.5, (Z_STAIR_TOP + Z_EDGE) * 0.5), Vector3(0.04, LAND_Y, Z_EDGE - Z_STAIR_TOP), m_green)

	# ---------- стены площадки (модули стоят на плите) ----------
	_wall(Vector3(-1.5, LAND_Y, Z_BACK - t), 0.0, 3.0)
	_wall(Vector3(1.5, LAND_Y, Z_BACK - t), 0.0, 3.0, true)
	_wall(Vector3(-X - t, LAND_Y, (Z_BACK + Z_STAIR_TOP) * 0.5), PI * 0.5, Z_STAIR_TOP - Z_BACK)
	_wall(Vector3(X + t, LAND_Y, -4.25), -PI * 0.5, 3.5)
	_wall(Vector3(X + t, LAND_Y, -0.75), -PI * 0.5, 3.5, true)
	# ---------- стены холла и пролёта (от земли) ----------
	_wall(Vector3(-X - t, 0, 0.225), PI * 0.5, 3.85)
	_wall(Vector3(-X - t, 0, 4.075), PI * 0.5, 3.85, true)
	_wall(Vector3(X + t, 0, 4.85), -PI * 0.5, 2.3)
	# простенки у входа и стена ниши (узкие — гладкие, тем же двухцветием)
	_plain_wall(Vector3(-2.1, 0, Z_FRONT + 0.15), Vector3(1.8, CEIL_Y, 0.3))
	_plain_wall(Vector3(2.1, 0, Z_FRONT + 0.15), Vector3(1.8, CEIL_Y, 0.3))
	_static_box(Vector3(-2.1, CEIL_Y * 0.5, Z_FRONT + 0.15), Vector3(1.8, CEIL_Y, 0.3))
	_static_box(Vector3(2.1, CEIL_Y * 0.5, Z_FRONT + 0.15), Vector3(1.8, CEIL_Y, 0.3))
	_box(Vector3(0, 2.2 + (CEIL_Y - 2.2) * 0.5, Z_FRONT + 0.15), Vector3(2.4, CEIL_Y - 2.2, 0.3), m_white)       # над проёмом тамбура

	# ---------- первый пролёт: из холла на площадку, вдоль левой стены ----------
	var st := G67Models.spawn("g67_stair_flight", self, Vector3((-X + STAIR_X) * 0.5, 0, (Z_EDGE + Z_STAIR_TOP) * 0.5), 0.0, Vector3(9, 9, Z_EDGE - Z_STAIR_TOP), "d")
	if String(st.get_meta("from", "")) != "glb":
		missing.append("g67_stair_flight")
	_ramp(-X, STAIR_X, Z_EDGE, 0.0, Z_STAIR_TOP, LAND_Y)
	_railing(Vector3(STAIR_X, LAND_Y, Z_STAIR_TOP), Vector3(STAIR_X, LAND_Y, Z_EDGE))          # край площадки над пролётом
	_railing(Vector3(STAIR_X, LAND_Y, Z_EDGE), Vector3(FLIGHT2_X, LAND_Y, Z_EDGE))             # край площадки над холлом

	# ---------- второй пролёт: на верхние этажи, за решёткой ----------
	_box(Vector3((FLIGHT2_X + X) * 0.5, LAND_Y * 0.5, 2.35), Vector3(X - FLIGHT2_X, LAND_Y, 2.7), m_green)      # кладка под пролётом
	_static_box(Vector3((FLIGHT2_X + X) * 0.5, CEIL_Y * 0.5, 2.35), Vector3(X - FLIGHT2_X, CEIL_Y, 2.7))
	var st2 := G67Models.spawn("g67_stair_flight", self, Vector3((FLIGHT2_X + X) * 0.5, LAND_Y, 2.35), PI, Vector3(9, 9, 2.7), "d")
	if String(st2.get_meta("from", "")) != "glb":
		missing.append("g67_stair_flight")
	_box(Vector3((FLIGHT2_X + X) * 0.5, 3.0 + (CEIL_Y - 3.0) * 0.5, 3.85), Vector3(X - FLIGHT2_X, CEIL_Y - 3.0, 0.3), m_white)   # стена над верхом пролёта
	# решётка у начала пролёта: жильцы верхних этажей закрыли проход
	for i in 8:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 2.1, 0.03)
		bar.mesh = bm
		bar.material_override = m_metal
		bar.position = Vector3(FLIGHT2_X + 0.1 + float(i) * 0.175, LAND_Y + 1.05, Z_EDGE - 0.02)
		add_child(bar)
	for y in [0.15, 1.05, 2.05]:
		_box(Vector3((FLIGHT2_X + X) * 0.5, LAND_Y + y, Z_EDGE - 0.02), Vector3(X - FLIGHT2_X, 0.05, 0.04), m_metal)
	_box(Vector3(FLIGHT2_X + 0.75, LAND_Y + 1.05, Z_EDGE - 0.06), Vector3(0.1, 0.14, 0.06), _mat(Color(0.55, 0.45, 0.2), 0.0, 0.4))   # замок
	_static_box(Vector3((FLIGHT2_X + X) * 0.5, LAND_Y + 1.1, Z_EDGE - 0.02), Vector3(X - FLIGHT2_X, 2.2, 0.2))

	# ---------- холл: стена под площадкой с дверью колясочной ----------
	_put("g67_service_door", Vector3(0.0, 0, Z_EDGE + 0.12), 0.0, Vector3(1.0, LAND_Y - 0.08, 0.6), "h", false)
	_static_box(Vector3(0.0, 0.7, Z_EDGE + 0.1), Vector3(1.1, 1.4, 0.3))
	# почтовые ящики — на левой стене у входа, на уровне глаз
	_put("g67_mailboxes", Vector3(-X + 0.12, 1.05, 4.3), PI * 0.5, Vector3(1.5, 0.8, 0.5), "h", false)
	_point("mail", "ПОЧТОВЫЕ ЯЩИКИ", "листовки турнира", Vector3(-X + 0.9, 0, 4.3))
	# ниша справа от входа: карта маршрутов на стене, стенд турнира в углу
	_plain_wall(Vector3((FLIGHT2_X + X) * 0.5, 0, 3.78), Vector3(X - FLIGHT2_X, 3.0, 0.16))
	_put("g67_route_board", Vector3((FLIGHT2_X + X) * 0.5, 0.95, 3.9), 0.0, Vector3(1.25, 1.0, 0.4), "h", false)
	_point("routes", "КАРТА МАРШРУТОВ", "ДВОР", Vector3((FLIGHT2_X + X) * 0.5, 0, 4.7))
	_put("g67_poster_stand", Vector3(X - 0.3, 0, 5.35), -PI * 0.5, Vector3(1.0, 1.9, 0.5))
	# доска объявлений — у стены под вторым пролётом, лицом в холл
	_put("g67_notice_board", Vector3(FLIGHT2_X - 0.28, 0, 2.3), -PI * 0.5, Vector3(1.4, 1.7, 0.5))
	_point("notices", "ДОСКА ОБЪЯВЛЕНИЙ", "ТУРНИР 67 — 67 000 ГОЛДЫ", Vector3(FLIGHT2_X - 1.1, 0, 2.3))

	# ---------- тамбур и входная дверь ----------
	for sx in [-1.0, 1.0]:
		_plain_wall(Vector3(sx * 1.35, 0, (Z_FRONT + Z_DOOR) * 0.5 + 0.15), Vector3(0.3, 2.6, Z_DOOR - Z_FRONT - 0.3))
		_static_box(Vector3(sx * 1.35, 1.3, (Z_FRONT + Z_DOOR) * 0.5 + 0.15), Vector3(0.3, 2.6, Z_DOOR - Z_FRONT))
	_box(Vector3(0, 2.7, (Z_FRONT + Z_DOOR) * 0.5 + 0.15), Vector3(3.0, 0.2, Z_DOOR - Z_FRONT), m_white)
	_put("g67_podezd_entrance", Vector3(0, 0, Z_DOOR + 0.9), 0.0, Vector3(3.0, 2.9, 3.0), "h", false)
	_static_box(Vector3(0, 1.3, Z_DOOR + 0.35), Vector3(3.2, 2.6, 0.5))
	_point("exit", "ВЫХОД ВО ДВОР", "начать забег", Vector3(0.0, 0, Z_DOOR - 0.7))
	# окно над входом: зимние сумерки с улицы
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.35, 0.55)
	glass.emission_enabled = true
	glass.emission = Color(0.3, 0.42, 0.7)
	glass.emission_energy_multiplier = 1.4
	_box(Vector3(0, 3.5, Z_FRONT + 0.02), Vector3(1.5, 1.1, 0.06), glass)
	_box(Vector3(0, 3.5, Z_FRONT + 0.0), Vector3(0.05, 1.1, 0.08), m_white)
	_box(Vector3(0, 3.5, Z_FRONT + 0.0), Vector3(1.5, 0.05, 0.08), m_white)
	_box(Vector3(0, 2.9, Z_FRONT - 0.1), Vector3(1.7, 0.06, 0.26), m_white)         # подоконник

	# ---------- площадка первого этажа: двери квартир и вещи жильцов вдоль стен ----------
	_apt_door(Vector3(-1.75, LAND_Y, Z_BACK + 0.03), 0.0, "1", Color(0.26, 0.15, 0.1))
	_apt_door(Vector3(2.3, LAND_Y, Z_BACK + 0.03), 0.0, "2", Color(0.16, 0.18, 0.22))
	_apt_door(Vector3(X - 0.03, LAND_Y, -4.7), -PI * 0.5, "3", Color(0.3, 0.2, 0.12))
	# сервант, вынесенный на площадку, — между дверями первой и второй квартиры
	_put("g67_artifact_cabinet", Vector3(0.35, LAND_Y, Z_BACK + 0.42), 0.0, Vector3(1.6, 1.9, 0.9))
	_point("artifacts", "КОЛЛЕКЦИЯ АРТЕФАКТОВ", "пока пусто", Vector3(0.35, LAND_Y, Z_BACK + 1.3))
	# телевизор на тумбочке — в дальнем левом углу
	_box(Vector3(-X + 0.42, LAND_Y + 0.28, Z_BACK + 0.45), Vector3(0.62, 0.56, 0.5), m_wood)
	_static_box(Vector3(-X + 0.42, LAND_Y + 0.55, Z_BACK + 0.45), Vector3(0.75, 1.1, 0.7))
	_put("res://assets/minigames/menu_crt_tv.glb", Vector3(-X + 0.42, LAND_Y + 0.56, Z_BACK + 0.45), PI * 0.25, Vector3(0.75, 0.62, 0.75), "h", false)
	_light(Vector3(-X + 0.9, LAND_Y + 1.0, Z_BACK + 0.9), Color(0.55, 0.7, 1.0), 0.8, 3.5)
	_point("tv", "ТЕЛЕВИЗОР", "ОБЛАКО LIVE · АРХИВ ПИЗДЕЦА", Vector3(-X + 1.1, LAND_Y, Z_BACK + 1.2))
	# лавка dj flürr — вдоль левой стены, он сидит на ней лицом к площадке
	_put("res://assets/racing/bench.glb", Vector3(-X + 0.38, LAND_Y, -3.55), 0.0, Vector3(2.4, 0.9, 2.4))
	var fl := _actor("g67_dj_flurr", G67Models.DIR + "g67_dj_flurr.glb", 1.8, Vector3(-X + 0.42, LAND_Y, -3.55), PI * 0.5)
	if fl != null:
		G67Models.sit(fl, 0.47)
	_point("flurr", "DJ FLÜRR", "поговорить", Vector3(-X + 1.3, LAND_Y, -3.55))
	# стол улучшений и стойка стилей — вдоль правой стены, между дверью третьей квартиры и решёткой
	_put("res://assets/minigames/ml_desk.glb", Vector3(X - 0.42, LAND_Y, -2.75), -PI * 0.5, Vector3(1.3, 0.85, 0.8))
	_point("upgrades", "АВТОРИТЕТ РАЙОНА", "улучшения за РЕСПЕКТ", Vector3(X - 1.3, LAND_Y, -2.75))
	_put("g67_style_rack", Vector3(X - 0.3, LAND_Y, -0.75), -PI * 0.5, Vector3(1.4, 1.9, 0.8))
	_point("styles", "СТОЙКА СТИЛЕЙ", "Балон VOZDUH", Vector3(X - 1.2, LAND_Y, -0.75))

	# ---------- свет: плафоны на потолке и под площадкой, как в жилом доме ----------
	_lamp(Vector3(0.0, CEIL_Y - 0.12, -3.6), Color(1.0, 0.86, 0.62), 2.6, 9.0)          # над площадкой
	_lamp(Vector3(-0.3, CEIL_Y - 0.12, 3.4), Color(1.0, 0.88, 0.68), 2.2, 9.0)          # над холлом
	_lamp(Vector3(0.0, 2.52, Z_DOOR - 0.8), Color(1.0, 0.82, 0.55), 1.0, 4.0)           # в тамбуре
	_light(Vector3(0.0, 3.3, Z_FRONT - 0.6), Color(0.45, 0.6, 1.0), 0.9, 6.0)           # от окна

# ---------------------------------------------------------------- район ДВОР
## Двор строится один раз на забег и не сдвигается (yard.position = 0, координаты мира = координаты двора, g67_yard.gd).
## Бой привязан к зоне двора (G67Yard.ZONES): game.set_arena(центр, полуразмеры), на время боя зону огораживают.
var room: Dictionary = {}
var gates: Array = []          # варианты следующего этапа: [{option, icon, root, label, stand, auto, pos}]
var yard: G67Yard
## Бой Миши (G67Misha.hook_target): за что цепляется цепь — турники и борта коробки, в координатах мира
var hook_points: Array = []
var hook_rect := Rect2(-14, -14, 28, 28)
var throne := Vector3(0, 0.03, -10.0)
var statist: Rig = null        # Миша на троне до боя: виден через сетку весь забег

func build_yard() -> void:
	deco = "g67_dvor"
	var T := _theme("g67_dvor")
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = T["sky"][0]
	sm.sky_horizon_color = T["sky"][1]
	sm.ground_bottom_color = T["sky"][0]
	sm.ground_horizon_color = T["sky"][1]
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = T["fog"]
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# луна: холодный боковой свет с длинными тенями; тёплое — только от фонарей и окон
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.62, 0.72, 1.0)
	key.light_energy = 0.55
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 70.0
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-140), 0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.52, 0.7)
	fill.light_energy = 0.22
	fill.rotation = Vector3(deg_to_rad(-30), deg_to_rad(50), 0)
	add_child(fill)
	yard = G67Yard.new()
	add_child(yard)
	yard.build()
	yard.position = Vector3.ZERO
	hook_points = []
	for bp in G67Yard.BARS:
		hook_points.append(Vector3(float(bp[0]), 0, float(bp[1])))
	var cr: Rect2 = G67Yard.COURT
	hook_rect = Rect2(cr.position.x + 0.3, cr.position.y + 0.3, cr.size.x - 0.6, cr.size.y - 0.6)
	throne = G67Yard.THRONE
	missing.append_array(yard.missing)
	_cam_court()
	_misha_statist()
	_particles(T)

## Камера не выходит за борта коробки: сплошные камерные стены по периметру COURT (внутренняя грань — в 0,35 м от борта),
## включая проём калитки; сетка над бортом тоже не пропускает
func _cam_court() -> void:
	var cr: Rect2 = G67Yard.COURT
	var inset := 0.35
	var h := 7.0
	var cx := cr.position.x + cr.size.x * 0.5
	var cz := cr.position.y + cr.size.y * 0.5
	_cam_box(Vector3(cr.position.x + inset - 0.5, h * 0.5, cz), Vector3(1.0, h, cr.size.y + 3.0))
	_cam_box(Vector3(cr.end.x - inset + 0.5, h * 0.5, cz), Vector3(1.0, h, cr.size.y + 3.0))
	_cam_box(Vector3(cx, h * 0.5, cr.position.y + inset - 0.5), Vector3(cr.size.x + 3.0, h, 1.0))
	_cam_box(Vector3(cx, h * 0.5, cr.end.y - inset + 0.5), Vector3(cr.size.x + 3.0, h, 1.0))

## Миша сидит на троне с самого начала забега: та же модель, поза и золотая цепь, что у босса, но это не враг
func _misha_statist() -> void:
	var look: Dictionary = preload("res://scripts/enemy.gd").BOSS_LOOK.get("g67_misha", {})
	if look.is_empty() or not ResourceLoader.exists(String(look.get("path", ""))):
		return
	var poses: Dictionary = Poses.bot()
	poses.merge(G67Misha.clips(), true)
	statist = Rig.new()
	add_child(statist)
	statist.setup(String(look["path"]), 1.75 * float(look["scale"]), poses, true, 1.0, String(look.get("key", "g67_misha")))
	G67Models.misha_chain(statist)
	statist.position = Vector3(throne.x, throne.y, throne.z + 0.2)
	statist.rotation.y = 0.0
	statist.play("MSit", 0.0)

func drop_statist() -> void:
	if statist != null and is_instance_valid(statist):
		statist.queue_free()
	statist = null

## Граница зоны боя. Во дворе на время боя турнир огораживает зону переносными ограждениями (их видно, в них
## упираешься как в забор); после победы ограждения убирают. Невидимые стенки по прямоугольнику зоны закрывают и проём
## калитки коробки. В коробке Миши площадку держат её борта (barriers = false).
var bounds: Node3D

func bound_zone(zid: String, barriers: bool) -> void:
	open_bounds()
	var z: Dictionary = G67Yard.zone(zid)
	var c: Vector3 = z["c"]
	var hx: float = (z["h"] as Vector2).x
	var hz: float = (z["h"] as Vector2).y
	bounds = Node3D.new()
	add_child(bounds)
	# проёмы: у каждой точки входа снаружи зоны — ширина 2,5 м на ближайшей стороне
	var gaps := {"n": [], "s": [], "w": [], "e": []}
	for sp in z.get("spawns", []):
		var q: Vector3 = sp[0]
		var dxe: float = absf(q.x - c.x) - hx
		var dze: float = absf(q.z - c.z) - hz
		if dxe < 0.0 and dze < 0.0:
			continue
		if dxe > dze:
			(gaps["e" if q.x > c.x else "w"] as Array).append(clampf(q.z, c.z - hz + 2.0, c.z + hz - 2.0))
		else:
			(gaps["s" if q.z > c.z else "n"] as Array).append(clampf(q.x, c.x - hx + 2.0, c.x + hx - 2.0))
	var open_n := 0
	# невидимые стенки: куски между проёмами; в проёме — стенка только для героя (слой 6), враги проходят
	for side in ["n", "s", "w", "e"]:
		var horiz: bool = side in ["n", "s"]
		var lo: float = (c.x - hx - 1.0) if horiz else (c.z - hz - 1.0)
		var hi: float = (c.x + hx + 1.0) if horiz else (c.z + hz + 1.0)
		var fixed: float = {"n": c.z - hz - 0.5, "s": c.z + hz + 0.5, "w": c.x - hx - 0.5, "e": c.x + hx + 0.5}[side]
		var cuts: Array = (gaps[side] as Array).duplicate()
		cuts.sort()
		var cur := lo
		for g in cuts:
			_bound_box(horiz, fixed, cur, float(g) - 1.25, 1)
			_bound_box(horiz, fixed, float(g) - 1.25, float(g) + 1.25, 32)
			cur = float(g) + 1.25
			open_n += 1
		_bound_box(horiz, fixed, cur, hi, 1)
	if not barriers:
		return
	# ограждения: секции забора в турнирном золоте; напротив точек входа секции нет, по бокам проёма — стойки
	var gold := Color(1.0, 0.82, 0.35)
	var nx := maxi(2, int(round(2.0 * hx / 3.65)))
	var nz := maxi(2, int(round(2.0 * hz / 3.65)))
	var sx := 2.0 * hx / float(nx)
	var sz := 2.0 * hz / float(nz)
	var sides: Array = []
	for i in nx:
		var t := c.x - hx + (float(i) + 0.5) * sx
		sides.append([Vector3(t, 0, c.z - hz), PI * 0.5, sx, "n", t])
		sides.append([Vector3(t, 0, c.z + hz), PI * 0.5, sx, "s", t])
	for i in nz:
		var t := c.z - hz + (float(i) + 0.5) * sz
		sides.append([Vector3(c.x - hx, 0, t), 0.0, sz, "w", t])
		sides.append([Vector3(c.x + hx, 0, t), 0.0, sz, "e", t])
	fence_total = sides.size()
	fence_built = 0
	for q in sides:
		var skip := false
		for g in gaps[q[3]]:
			if absf(float(q[4]) - float(g)) < 1.25 + float(q[2]) * 0.5:
				skip = true
		if skip:
			continue
		fence_built += 1
		var f := G67Models.spawn("res://assets/racing/fence_section.glb", bounds, q[0], q[1], Vector3(99, 1.25, float(q[2]) / 1.15))
		if String(f.get_meta("from", "")) == "glb" and yard != null:
			yard._tint(f, gold)
	for side in ["n", "s", "w", "e"]:
		for g in gaps[side]:
			for e in [-1.25, 1.25]:
				var pp := Vector3(float(g) + e, 0.0, {"n": c.z - hz, "s": c.z + hz}[side]) if side in ["n", "s"] else Vector3({"w": c.x - hx, "e": c.x + hx}[side], 0.0, float(g) + e)
				var post := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.22, 1.5, 0.22)
				post.mesh = bm
				var pm := StandardMaterial3D.new()
				pm.albedo_color = gold
				post.material_override = pm
				post.position = pp + Vector3(0, 0.75, 0)
				bounds.add_child(post)

var fence_total := 0
var fence_built := 0

func _bound_box(horiz: bool, fixed: float, a: float, b: float, layer: int) -> void:
	if b - a < 0.05:
		return
	var sb := StaticBody3D.new()
	sb.collision_layer = layer          # слой 1 — все; слой 6 (32) — только герой (маска героя включает его)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(b - a, 4, 1) if horiz else Vector3(1, 4, b - a)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3((a + b) * 0.5, 2, fixed) if horiz else Vector3(fixed, 2, (a + b) * 0.5)
	bounds.add_child(sb)

## Бой окончен: ограждения убраны, по двору можно ходить
func open_bounds() -> void:
	if bounds != null and is_instance_valid(bounds):
		bounds.queue_free()
	bounds = null

## можно ли поставить врага в эту точку (не внутри машины, гаража или дерева)
func blocked(p: Vector3) -> bool:
	if yard == null:
		return false
	for s in yard.solids:
		var c: Vector3 = s[0] as Vector3
		if Vector2(p.x - c.x, p.z - c.z).length() < float(s[1]) + 0.5:
			return true
	return false

## Где стоит вариант этапа: {pos — точка [E] (нет — вариант стартует сам), mark — над чем висит значок, stand — угол стойки}
static func gate_spot(o: Dictionary) -> Dictionary:
	var type := String(o["type"])
	var zid := String(o.get("place", "podezd"))
	var z: Dictionary = G67Yard.zone(zid)
	match type:
		"battle", "elite":
			if z.has("stand"):
				var sp: Vector3 = z["stand"]
				var yaw: float = float(z["stand_yaw"])
				return {"pos": sp + Vector3(sin(yaw), 0, cos(yaw)) * 1.5, "mark": sp + Vector3(0, 3.0, 0), "stand": sp, "yaw": yaw}
			return {"pos": (z["c"] as Vector3) + Vector3(0, 0, (z["h"] as Vector2).y - 3.0), "mark": (z["c"] as Vector3) + Vector3(0, 3.0, (z["h"] as Vector2).y - 3.0)}
		"fit":
			var hp: Vector3 = G67Yard.HANGER_POS
			return {"pos": hp + Vector3(sin(G67Yard.HANGER_YAW), 0, cos(G67Yard.HANGER_YAW)) * 1.3, "mark": hp + Vector3(0, 2.7, 0)}
		"storage":
			return {"pos": G67Yard.STORAGE_POS, "mark": G67Yard.STORAGE_POS + Vector3(0, 2.7, 0)}
		"break":
			return {"pos": G67Yard.REST_POS, "mark": G67Yard.REST_POS + Vector3(0, 2.4, 0)}
		"boss":
			return {"pos": G67Yard.GATE_BOSS, "mark": G67Yard.GATE_BOSS + Vector3(0, 2.7, 0)}
		"ambush":
			return {"mark": (z["c"] as Vector3) + Vector3(0, 2.7, 0)}
		"kiosk":
			return {"pos": G67Yard.KIOSK_POS, "mark": G67Yard.KIOSK_POS + Vector3(0, 2.7, 0)}
		"event":
			var ep: Vector3 = G67Yard.EVENT_SPOTS.get(String(o.get("ev", "")), z["c"])
			return {"pos": ep, "mark": ep + Vector3(0, 2.6, 0)}
	return {"pos": z["c"], "mark": (z["c"] as Vector3) + Vector3(0, 2.7, 0)}

## Варианты следующего этапа (options — [{type, place}]). Ни ворот, ни столба света: у каждого варианта — его место во
## дворе (турнирная стойка, вешалка, открытый бокс, лавка, калитка) и над ним небольшой значок типа; подойти и нажать [E].
## Вариант «засада» точки не имеет: он стартует сам, когда герой входит в её зону.
func add_gates(options: Array) -> void:
	clear_gates()
	for i in options.size():
		var o: Dictionary = options[i]
		var type := String(o["type"])
		var spot := gate_spot(o)
		var col: Color = G67Data.ROOM_COLOR[type]
		var title := G67Data.stage_title(type, String(o.get("place", "podezd")), String(o.get("ev", "")))
		var root := Node3D.new()
		root.name = "gate_mark%d" % i
		root.position = spot["mark"]
		add_child(root)
		var ic := G67Icons.sprite(String(G67Icons.ROOM.get(type, "")), 0.0016)
		if ic != null:
			root.add_child(ic)
		var lbl := Label3D.new()
		lbl.text = String(G67Data.ROOM_NAMES[type])
		lbl.font_size = 40
		lbl.pixel_size = 0.0035
		lbl.outline_size = 10
		lbl.modulate = col
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = Vector3(0, -0.5 if ic != null else 0.0, 0)
		root.add_child(lbl)
		var lt := OmniLight3D.new()
		lt.light_color = col
		lt.light_energy = 0.7
		lt.omni_range = 4.0
		lt.position = Vector3(0, -0.6, 0)
		root.add_child(lt)
		var stand: Node3D = null
		if spot.has("stand"):
			var sp: Vector3 = spot["stand"]
			stand = G67Models.spawn("g67_poster_stand", self, sp, float(spot["yaw"]), Vector3(1.0, 2.2, 1.0))
			stand.name = "gate_stand%d" % i
			_static_box(sp + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.5), float(spot["yaw"]))
			var sb: Node = get_child(get_child_count() - 1)
			sb.name = "gate_stand_body%d" % i
		var auto := not spot.has("pos")
		gates.append({"root": root, "label": lbl, "option": o, "icon": ic, "stand": stand, "auto": auto, "pos": spot.get("pos", spot["mark"])})
		if not auto:
			_point("gate%d" % i, title, String(G67Data.ROOM_HINT[type]), spot["pos"])

## Варианты сняты: значки, стойки и их точки убраны (этап выбран или начался)
# ---------------------------------------------------------------- предметы событий двора (геометрия кодом)
var ev_nodes := {}

func _ev_mesh(parent: Node, mesh: Mesh, pos: Vector3, col: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.75
	m.metallic = 0.35
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _ev_label(parent: Node, text: String, pos: Vector3, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 8
	l.modulate = col
	l.position = pos
	parent.add_child(l)
	return l

func _evb(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b

## Автомат «Бурмалда», красная кнопка «Можно. А зачем?» и дверь «ТРЯПОК» — постоянные предметы двора
func build_event_props() -> void:
	var sp: Dictionary = G67Yard.EVENT_SPOTS
	# автомат
	var a := Node3D.new()
	a.position = sp["burmalda"]
	add_child(a)
	_ev_mesh(a, _evb(Vector3(1.0, 2.0, 0.8)), Vector3(0, 1.0, 0), Color(0.42, 0.1, 0.09))
	_ev_mesh(a, _evb(Vector3(0.62, 0.5, 0.05)), Vector3(0, 1.45, 0.41), Color(0.05, 0.05, 0.06))
	var win := _ev_label(a, "7 7 7", Vector3(0, 1.45, 0.45), 56, Color(1.0, 0.85, 0.3))
	_ev_label(a, "БУРМАЛДА", Vector3(0, 2.1, 0.2), 48, Color(1.0, 0.8, 0.25))
	var tray := _ev_mesh(a, _evb(Vector3(0.5, 0.22, 0.2)), Vector3(0, 0.45, 0.42), Color(0.08, 0.08, 0.09))
	var lever := Node3D.new()
	lever.position = Vector3(0.55, 1.2, 0.1)
	a.add_child(lever)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.03
	rod.height = 0.5
	_ev_mesh(lever, rod, Vector3(0, 0.25, 0), Color(0.6, 0.6, 0.62))
	var kn := SphereMesh.new()
	kn.radius = 0.08
	kn.height = 0.16
	_ev_mesh(lever, kn, Vector3(0, 0.52, 0), Color(0.8, 0.1, 0.1))
	var lamps: Array = []
	for i in 5:
		var s := SphereMesh.new()
		s.radius = 0.05
		s.height = 0.1
		lamps.append(_ev_mesh(a, s, Vector3(-0.36 + i * 0.18, 1.8, 0.41), Color(1.0, 0.75, 0.2), 1.5))
	var al := OmniLight3D.new()
	al.light_color = Color(1.0, 0.7, 0.3)
	al.light_energy = 0.9
	al.omni_range = 4.0
	al.position = Vector3(0, 1.6, 1.0)
	a.add_child(al)
	win.visible = false
	# потёртость: сколы до металла и ржавые потёки, заклёпки по рёбрам
	var rng := RandomNumberGenerator.new()
	rng.seed = 6767
	for k in 14:
		_ev_mesh(a, _evb(Vector3(rng.randf_range(0.04, 0.12), rng.randf_range(0.03, 0.08), 0.01)), Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.2, 1.9), 0.405), Color(0.62, 0.62, 0.6))
	for k in 7:
		var rx := rng.randf_range(-0.45, 0.45)
		_ev_mesh(a, _evb(Vector3(0.03, rng.randf_range(0.15, 0.5), 0.012)), Vector3(rx, rng.randf_range(0.25, 0.7), 0.406), Color(0.35, 0.16, 0.07))
	var rv := SphereMesh.new()
	rv.radius = 0.018
	rv.height = 0.036
	for i in 8:
		for sx in [-0.46, 0.46]:
			_ev_mesh(a, rv, Vector3(sx, 0.15 + i * 0.25, 0.405), Color(0.6, 0.55, 0.5))
	# решётка динамика и лампа в колпаке
	for i in 5:
		_ev_mesh(a, _evb(Vector3(0.3, 0.012, 0.01)), Vector3(0.0, 1.58 + i * 0.0, 0.0) + Vector3(-0.0, 0.0, 0.0), Color(0.05, 0.05, 0.05)).visible = false
	_ev_mesh(a, _evb(Vector3(0.34, 0.2, 0.02)), Vector3(0.0, 0.8, 0.405), Color(0.06, 0.06, 0.07))
	for i in 5:
		_ev_mesh(a, _evb(Vector3(0.3, 0.014, 0.012)), Vector3(0.0, 0.73 + i * 0.035, 0.418), Color(0.4, 0.4, 0.4))
	var cap_m := SphereMesh.new()
	cap_m.radius = 0.1
	cap_m.height = 0.2
	var cap := _ev_mesh(a, cap_m, Vector3(0, 2.07, 0), Color(1.0, 0.7, 0.2), 2.0)
	# надписи
	var plate := _ev_mesh(a, _evb(Vector3(0.9, 0.2, 0.012)), Vector3(0.0, 1.07, 0.408), Color(0.82, 0.78, 0.62))
	var l2 := _ev_label(a, "Мы не знаем, что внутри.\nНо оно работает", Vector3(0.0, 1.07, 0.416), 30, Color(0.12, 0.1, 0.08))
	l2.pixel_size = 0.0019
	var l3 := _ev_label(a, "Гарантия до первого\nиспользования", Vector3(0.0, 0.3, 0.416), 22, Color(0.9, 0.88, 0.8))
	l3.pixel_size = 0.0034
	l3.position.x = -0.12
	l3.rotation.z = 0.02
	# наклейки: стрелка к рычагу, знак «!», облезлая круглая
	_ev_mesh(a, _evb(Vector3(0.16, 0.04, 0.01)), Vector3(0.28, 1.6, 0.41), Color(1.0, 0.85, 0.1))
	_ev_mesh(a, _evb(Vector3(0.06, 0.12, 0.01)).duplicate(), Vector3(0.38, 1.6, 0.41), Color(1.0, 0.85, 0.1)).rotation.z = 0.8
	var warn := _ev_mesh(a, _evb(Vector3(0.16, 0.14, 0.01)), Vector3(-0.34, 0.55, 0.41), Color(1.0, 0.8, 0.1))
	warn.rotation.z = 0.78
	_ev_label(a, "!", Vector3(-0.34, 0.55, 0.42), 48, Color(0.1, 0.1, 0.1))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.01
	var rd := _ev_mesh(a, cyl, Vector3(0.3, 0.55, 0.41), Color(0.7, 0.2, 0.15))
	rd.rotation.x = PI * 0.5
	# значки барабана: монета, шаурма, артефакт, бирка, носок
	var slots: Array = []
	for si in 3:
		var slot := Node3D.new()
		slot.position = Vector3(-0.2 + si * 0.2, 1.45, 0.44)
		a.add_child(slot)
		var icons: Array = []
		for k in 5:
			var ic := Node3D.new()
			slot.add_child(ic)
			match k:
				0:
					var c0 := CylinderMesh.new()
					c0.top_radius = 0.07
					c0.bottom_radius = 0.07
					c0.height = 0.015
					var m0 := _ev_mesh(ic, c0, Vector3.ZERO, Color(1.0, 0.8, 0.15), 1.5)
					m0.rotation.x = PI * 0.5
				1:
					var c1 := CapsuleMesh.new()
					c1.radius = 0.04
					c1.height = 0.15
					var m1 := _ev_mesh(ic, c1, Vector3.ZERO, Color(0.7, 0.4, 0.2), 0.6)
					m1.rotation.z = PI * 0.5
				2:
					_ev_mesh(ic, _evb(Vector3(0.1, 0.1, 0.02)), Vector3.ZERO, Color(0.3, 0.8, 1.0), 2.0).rotation.z = 0.785
				3:
					_ev_mesh(ic, _evb(Vector3(0.13, 0.08, 0.015)), Vector3.ZERO, Color(0.3, 0.9, 0.4), 1.2)
					_ev_mesh(ic, _evb(Vector3(0.02, 0.02, 0.02)), Vector3(-0.045, 0, 0.01), Color(0, 0, 0))
				4:
					_ev_mesh(ic, _evb(Vector3(0.05, 0.12, 0.015)), Vector3(0, 0.0, 0), Color(0.55, 0.6, 0.7), 0.6)
					_ev_mesh(ic, _evb(Vector3(0.1, 0.05, 0.015)), Vector3(0.025, -0.045, 0), Color(0.55, 0.6, 0.7), 0.6)
			ic.visible = false
			icons.append(ic)
		(icons[si % 5] as Node3D).visible = true
		slots.append(icons)
	_static_box(sp["burmalda"] + Vector3(0, 1.0, 0), Vector3(1.1, 2.0, 0.9), 0.0)
	ev_nodes["burm"] = {"win": win, "lever": lever, "lamps": lamps, "tray": tray, "root": a, "slots": slots, "cap": cap}
	# кнопка на столбе
	var b := Node3D.new()
	b.position = sp["button"]
	b.rotation.y = 0.0
	add_child(b)
	var post := CylinderMesh.new()
	post.top_radius = 0.1
	post.bottom_radius = 0.12
	post.height = 1.3
	_ev_mesh(b, post, Vector3(0, 0.65, 0), Color(0.36, 0.34, 0.3))
	_ev_mesh(b, _evb(Vector3(0.45, 0.28, 0.3)), Vector3(0, 1.42, 0), Color(0.3, 0.3, 0.32))
	var dome := SphereMesh.new()
	dome.radius = 0.12
	dome.height = 0.16
	_ev_mesh(b, dome, Vector3(0, 1.58, 0.02), Color(0.9, 0.08, 0.06), 1.2)
	var lid := Node3D.new()
	lid.position = Vector3(0, 1.62, -0.14)
	b.add_child(lid)
	_ev_mesh(lid, _evb(Vector3(0.36, 0.03, 0.28)), Vector3(0, 0.04, 0.14), Color(0.7, 0.85, 0.9, 0.5))
	_ev_label(b, "МОЖНО. А ЗАЧЕМ?", Vector3(0, 1.95, 0.05), 40, Color(1.0, 0.85, 0.8))
	var bl := OmniLight3D.new()
	bl.light_color = Color(1.0, 0.2, 0.15)
	bl.light_energy = 0.6
	bl.omni_range = 3.0
	bl.position = Vector3(0, 1.7, 0.4)
	b.add_child(bl)
	_ev_label(b, "НЕ НАЖИМАТЬ", Vector3(0, 1.42, 0.16), 34, Color(1.0, 0.3, 0.25))
	var tbl := _ev_mesh(b, _evb(Vector3(0.62, 0.42, 0.02)), Vector3(0, 0.8, 0.13), Color(0.72, 0.7, 0.58))
	tbl.rotation.z = 0.03
	for li in 3:
		var tx: String = ["ЩИТ № 67", "U = ?", "ОТВ. — НИКТО"][li]
		var tl2 := _ev_label(b, tx, Vector3(0, 0.92 - li * 0.12, 0.145), 26, Color(0.1, 0.1, 0.1))
		tl2.pixel_size = 0.0028
	var cab := _ev_mesh(b, _evb(Vector3(0.04, 0.04, 2.2)), Vector3(0.3, 0.03, 1.1), Color(0.05, 0.05, 0.05))
	cab.rotation.y = 0.0
	_ev_mesh(b, _evb(Vector3(0.04, 0.9, 0.04)), Vector3(0.2, 0.45, -0.1), Color(0.05, 0.05, 0.05))
	var hch := Node3D.new()
	hch.position = Vector3(0.8, 0.02, 0.9)
	b.add_child(hch)
	var hm := CylinderMesh.new()
	hm.top_radius = 0.38
	hm.bottom_radius = 0.38
	hm.height = 0.03
	_ev_mesh(hch, hm, Vector3.ZERO, Color(0.12, 0.12, 0.13))
	var hole := _ev_mesh(b, hm, Vector3(0.8, 0.005, 0.9), Color(0.0, 0.0, 0.0))
	hch.set_meta("hole", hole)
	var horn := Node3D.new()
	horn.position = Vector3(0, 2.35, 0.1)
	b.add_child(horn)
	var hc := CylinderMesh.new()
	hc.top_radius = 0.28
	hc.bottom_radius = 0.07
	hc.height = 0.5
	var hmesh := _ev_mesh(horn, hc, Vector3.ZERO, Color(0.5, 0.5, 0.5))
	hmesh.rotation.x = PI * 0.5
	hmesh.position = Vector3(0, 0, 0.2)
	_ev_mesh(b, _evb(Vector3(0.06, 0.5, 0.06)), Vector3(0, 2.1, 0), Color(0.3, 0.3, 0.3))
	_static_box(sp["button"] + Vector3(0, 0.7, 0), Vector3(0.5, 1.4, 0.4), 0.0)
	ev_nodes["button"] = {"lid": lid, "root": b, "hatch": hch, "horn": horn}
	# дверь «ТРЯПОК»: гаражный бокс, тёплый свет из щели
	var d := Node3D.new()
	d.position = sp["rags"]
	d.rotation.y = PI * 0.5
	add_child(d)
	_ev_mesh(d, _evb(Vector3(1.6, 2.2, 0.12)), Vector3(0, 1.1, 0), Color(0.3, 0.33, 0.3))
	_ev_mesh(d, _evb(Vector3(1.4, 0.05, 0.04)), Vector3(0, 0.03, 0.08), Color(1.0, 0.8, 0.45), 3.0)
	var dl := OmniLight3D.new()
	dl.light_color = Color(1.0, 0.75, 0.4)
	dl.light_energy = 0.9
	dl.omni_range = 4.0
	dl.position = Vector3(0, 0.4, 0.9)
	d.add_child(dl)
	ev_nodes["rags"] = d

func ev_spin(sec: float, final := "junk", variant := 0, festive := false) -> void:
	var bn: Dictionary = ev_nodes.get("burm", {})
	if bn.is_empty():
		return
	var slots: Array = bn["slots"]
	var finals := {"gold": [0, 0, 0], "heal": [1, 1, 1], "art": [2, 2, 2], "rare_art": [2, 2, 2], "fit": [3, 3, 3], "junk": [4, 0, 3]}
	var fin: Array = finals.get(final, [4, 0, 3])
	var lamps: Array = bn["lamps"]
	var cap: MeshInstance3D = bn["cap"]
	var capm: StandardMaterial3D = cap.material_override
	var lamp_col := Color(1.0, 0.25, 0.85) if festive else Color(1.0, 0.7, 0.2)
	capm.albedo_color = lamp_col
	capm.emission = lamp_col
	var shown := [-1, -1, -1]
	var tw := create_tween()
	tw.tween_method(func(v: float):
		for si in 3:
			var idx: int = int(fin[si]) if v >= 0.96 else (int(v * 30.0) + si * 2 + (int(v * 12.0) * 3 if variant != 1 or v < 0.6 else 0)) % 5
			if variant == 1 and v > 0.8 and v < 0.96:
				idx = (int(fin[si]) + 4) % 5
			if variant == 2 and v > 0.4 and v < 0.75:
				idx = (int(fin[si]) + 2) % 5
			if shown[si] != idx:
				shown[si] = idx
				for k in 5:
					((slots[si] as Array)[k] as Node3D).visible = k == idx
		for i in lamps.size():
			var rate := 80.0 if festive else 40.0
			var pat := (int(v * rate) + i) % 2 == 0 if (variant == 0 or festive) else ((int(v * rate * 0.5) % 3) == i % 3 if variant == 1 else (int(v * 24.0) % 2 == 0))
			(lamps[i] as MeshInstance3D).visible = pat, 0.0, 1.0, sec)
	tw.tween_callback(func():
		for l in lamps:
			(l as MeshInstance3D).visible = true)
	var lv: Node3D = bn["lever"]
	var tl := create_tween()
	tl.tween_property(lv, "rotation:x", 1.0, 0.3)
	tl.tween_property(lv, "rotation:x", 0.0, 0.5).set_delay(0.3)
	if variant == 2:
		var rt: Node3D = bn["root"]
		var sh := create_tween()
		for k in 8:
			sh.tween_property(rt, "position:x", rt.position.x + (0.03 if k % 2 == 0 else -0.03), 0.06).set_delay(0.0 if k else 1.0)

## Люк у основания столба кнопки: открыть / закрыть
func ev_hatch(open: bool) -> void:
	var bn: Dictionary = ev_nodes.get("button", {})
	if bn.is_empty():
		return
	var h: Node3D = bn["hatch"]
	create_tween().tween_property(h, "position:y", 0.45 if open else 0.02, 0.4)
	create_tween().tween_property(h, "rotation:x", -1.0 if open else 0.0, 0.4)

func ev_lid(open: bool) -> void:
	var bn: Dictionary = ev_nodes.get("button", {})
	if bn.is_empty():
		return
	create_tween().tween_property(bn["lid"], "rotation:x", -1.9 if open else 0.0, 0.45)

func clear_gates() -> void:
	for g in gates:
		for k in ["root", "stand"]:
			var n = g.get(k)
			if n != null and is_instance_valid(n):
				n.queue_free()
	for i in gates.size():
		var b := get_node_or_null("gate_stand_body%d" % i)
		if b != null:
			b.queue_free()
	gates = []
	points = points.filter(func(pt): return not String(pt["id"]).begins_with("gate"))

## Дверь подъезда во дворе: вернуться домой посреди забега (забег сохранится)
func add_home() -> void:
	if yard == null:
		return
	for pt in points:
		if String(pt["id"]) == "home":
			return
	_point("home", "ПОДЪЕЗД", "домой: забег сохранится, продолжишь отсюда же", G67Yard.HOME_DOOR)

## Жители двора: точка «поговорить» следует за жителем (позицию обновляет G67Resident)
func add_residents() -> void:
	if yard == null:
		return
	var names := {"g67_npc_babushka": "БАБУШКА", "g67_npc_taxi_driver": "ТАКСИСТ", "g67_npc_ushanka": "МУЖИК В УШАНКЕ", "g67_npc_schoolboy": "ШКОЛЬНИК"}
	for rid in yard.residents:
		var r: Node3D = yard.people[rid]
		_point("talk_" + String(rid), String(names.get(rid, "ЖИТЕЛЬ")), "поговорить", r.position)

## ---- Подъезд (хаб): кнопка «НЕ НАЖИМАТЬ», листки, дверь квартиры на цепочке, силуэт в окне, телевизор за дверью
var hub_groups := {}
var hub_strip: MeshInstance3D = null
var hub_sil: Node3D = null

func _hub_note(kind: String, text: String, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 36
	lb.pixel_size = 0.0036
	lb.width = 420.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.outline_size = 4
	lb.shaded = false
	lb.modulate = Color(0.06, 0.06, 0.08)
	lb.outline_modulate = Color(0.95, 0.95, 0.92, 1)
	lb.position = Vector3(0, 0, 0.014)
	root.add_child(lb)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.62, 0.34)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.94, 0.93, 0.88) if kind == "paper" else Color(0.62, 0.64, 0.68)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = m
	q.position = Vector3(0, 0, 0.004)
	root.add_child(q)

func build_hub_life() -> void:
	var bx := -0.85
	var bz := Z_BACK + 0.05
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.03
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.85, 0.1, 0.1)
	dm.emission_enabled = true
	dm.emission = Color(0.8, 0.05, 0.05)
	disc.material_override = dm
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(bx, LAND_Y + 1.15, bz + 0.02)
	add_child(disc)
	_hub_note("plate", "НЕ НАЖИМАТЬ, Я ПРОШУ", Vector3(bx, LAND_Y + 1.5, bz + 0.01), 0.0)
	_point("hub_btn", "КНОПКА", "нажать", Vector3(bx, LAND_Y, Z_BACK + 1.0))
	_hub_note("paper", "Лифта в доме нет. Просьба не вызывать.", Vector3(-HUB_X + 0.04, 1.6, 3.4), PI * 0.5)
	hub_groups["hub_lift"] = {"pos": Vector3(-2.6, 0.0, 1.6), "title": "ЛИСТОК", "cards": [{"text": "Лифта в доме нет. Просьба не вызывать.", "sub": ""}]}
	_hub_note("paper", "Сосед! Твоя музыка слышна в 2016-м. Сделай громче.", Vector3(-1.75, LAND_Y + 1.7, Z_BACK + 0.06), 0.0)
	hub_groups["hub_music"] = {"pos": Vector3(-1.75, LAND_Y, Z_BACK + 1.0), "title": "ЛИСТОК", "cards": [{"text": "Сосед! Твоя музыка слышна в 2016-м. Сделай громче.", "sub": ""}]}
	for cl in hub_groups:
		_point("read_" + String(cl), "ЛИСТОК", "прочитать", hub_groups[cl]["pos"])
	hub_strip = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.05, 1.9)
	hub_strip.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.85, 0.5)
	hub_strip.material_override = sm
	hub_strip.position = Vector3(2.3 - 0.45, LAND_Y + 0.95, Z_BACK + 0.07)
	hub_strip.visible = false
	add_child(hub_strip)
	hub_sil = Node3D.new()
	hub_sil.position = Vector3(0.0, 3.1, Z_FRONT + 0.3)
	var bd := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 0.05)
	bd.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.02, 0.02, 0.03)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bd.material_override = bmat
	hub_sil.add_child(bd)
	var hd := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	hd.mesh = hm
	hd.material_override = bmat
	hd.position = Vector3(0, 0.38, 0)
	hub_sil.add_child(hd)
	hub_sil.visible = false
	add_child(hub_sil)

## Предметы жизни двора и листки: домофон, радио, ковровыбивалка, коробка, ПУХОСОС-8, группы листков (по [E])
func add_life_points() -> void:
	if yard == null:
		return
	_point("intercom", "ДОМОФОН", "нажать", Vector3(-2.2, 0, 34.0))
	_point("g_radio", "ГАРАЖНОЕ РАДИО", "послушать", Vector3(-41.4, 0, 4.8))
	_point("carpet", "КОВРОВЫБИВАЛКА", "выбить ковёр", Vector3(-7.0, 0, 4.7))
	_point("box", "КОРОБКА", "не открывать", Vector3(-40.6, 0, -4.5))
	_point("puh", "ПУХОСОС-8", "завести", Vector3(-39.0, 0, 9.2))
	for cl in yard.sign_groups:
		var gp: Dictionary = yard.sign_groups[cl]
		_point("read_" + String(cl), String(gp.get("title", "ЛИСТОК")), "прочитать", gp["pos"])

## Ларёк «ШАУРМА 67»: окно шаурмичной на парковке — постоянный магазин двора
func add_kiosk() -> void:
	if yard != null:
		_point("kiosk", "ШАУРМА 67", "окно ларька: шаурма за голду", G67Yard.KIOSK_POS)

## Кладовка: открытый бокс у гаражей
func add_storage() -> void:
	if yard != null:
		for pt in points:
			if String(pt["id"]) == "storage":
				return
		_point("storage", "КЛАДОВКА", "открытый бокс: взять один артефакт", G67Yard.STORAGE_POS)
