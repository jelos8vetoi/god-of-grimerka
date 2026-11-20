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
	_static_box(mid + Vector3(0, 0.65, 0), sz, yaw)

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
	_point("door", "КОЛЯСОЧНАЯ", "заколочена", Vector3(0.0, 0, Z_EDGE + 0.9))
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
## Комната забега — ЗОНА одного цельного двора (g67_yard.gd, G67Yard): двор строится целиком и сдвигается так,
## чтобы зона боя была в начале координат (враги игры держатся квадрата ±15 м вокруг нуля). Из любой зоны видны
## остальные — дома, гаражи, площадка, коробка.
var room: Dictionary = {}
var gates: Array = []          # ворота выбора следующей комнаты: [{root, label, option}]
var yard: G67Yard
## Бой Миши (G67Misha.hook_target): за что цепляется цепь — турники и борта коробки, в координатах комнаты
var hook_points: Array = []
var hook_rect := Rect2(-14, -14, 28, 28)
var throne := Vector3(0, 0.03, -10.0)

func build_room(r: Dictionary) -> void:
	room = r
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
	var zc: Vector3 = G67Yard.zone(String(r.get("place", "podezd")))["c"]
	yard.position = -zc
	# коробка Миши в координатах комнаты: за что цепляется цепь и где трон
	hook_points = []
	for bp in G67Yard.BARS:
		hook_points.append(Vector3(float(bp[0]), 0, float(bp[1])) - zc)
	var cr: Rect2 = G67Yard.COURT
	hook_rect = Rect2(cr.position.x - zc.x + 0.3, cr.position.y - zc.z + 0.3, cr.size.x - 0.6, cr.size.y - 0.6)
	throne = G67Yard.THRONE - zc
	missing.append_array(yard.missing)
	var type := String(r.get("type", "battle"))
	if type == "battle" or type == "elite" or type == "boss":
		_zone_bounds(type != "boss")
	_particles(T)

## Граница зоны боя. Невидимых стен во дворе нет: на время боя турнир огораживает площадку переносными
## ограждениями (их видно, в них упираешься как в забор), после победы ограждения убирают — и двор свободен.
## В коробке Миши площадку держат её борта.
var bounds: Node3D

func _zone_bounds(barriers: bool) -> void:
	bounds = Node3D.new()
	add_child(bounds)
	var h := G67Yard.HALF
	for s in [[Vector3(0, 2, -h - 0.5), Vector3(2 * h + 2, 4, 1)], [Vector3(0, 2, h + 0.5), Vector3(2 * h + 2, 4, 1)], [Vector3(-h - 0.5, 2, 0), Vector3(1, 4, 2 * h + 2)], [Vector3(h + 0.5, 2, 0), Vector3(1, 4, 2 * h + 2)]]:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1 | 8
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		sb.add_child(cs)
		sb.position = s[0]
		bounds.add_child(sb)
	if not barriers:
		return
	# ограждения: секции забора в турнирном золоте, встык по периметру
	var n := 8
	var step := 2.0 * h / float(n)
	var gold := Color(1.0, 0.82, 0.35)
	for i in n:
		var t := -h + (float(i) + 0.5) * step
		for q in [[Vector3(t, 0, -h), PI * 0.5], [Vector3(t, 0, h), PI * 0.5], [Vector3(-h, 0, t), 0.0], [Vector3(h, 0, t), 0.0]]:
			var f := G67Models.spawn("res://assets/racing/fence_section.glb", bounds, q[0], q[1], Vector3(99, 1.25, step / 1.15))
			if String(f.get_meta("from", "")) == "glb" and yard != null:
				yard._tint(f, gold)

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
		var c: Vector3 = (s[0] as Vector3) + yard.position
		if Vector2(p.x - c.x, p.z - c.z).length() < float(s[1]) + 0.5:
			return true
	return false

## Ворота выбора следующей комнаты (SPEC, раздел 9: после комнаты — 2–3 двери). options — [{type, place}].
## Ворота стоят не в ряд у стены, а у входа в ту часть двора, куда ведут: до них нужно дойти по двору.
## Над каждыми — тип комнаты и награда; подойти и нажать [E].
func add_gates(options: Array) -> void:
	for i in options.size():
		var o: Dictionary = options[i]
		var zc: Vector3 = G67Yard.zone(String(o.get("place", "podezd")))["c"]
		var pos: Vector3 = zc + Vector3(0, 0, G67Yard.HALF + 1.2) + (yard.position if yard != null else Vector3.ZERO)
		pos.y = 0.0
		var g := G67Models.spawn("g67_room_gate", self, pos, 0.0, Vector3(3.0, 3.2, 1.2))
		if String(g.get_meta("from", "")) != "glb":
			missing.append("g67_room_gate")
		_static_box(pos + Vector3(0, 1.5, 0), Vector3(3.0, 3.0, 0.8))
		var type := String(o["type"])
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [String(G67Data.ROOM_NAMES[type]), String(G67Data.ROOM_HINT[type])]
		lbl.font_size = 56
		lbl.pixel_size = 0.008
		lbl.outline_size = 14
		lbl.modulate = G67Data.ROOM_COLOR[type]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = pos + Vector3(0, 4.2, 0.4)
		add_child(lbl)
		var ic := G67Icons.sprite(String(G67Icons.ROOM.get(type, "")), 0.0036)
		if ic != null:
			ic.position = pos + Vector3(0, 5.75, 0.4)
			add_child(ic)
		# столб света над воротами: их видно через весь двор
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.6
		cm.height = 16.0
		beam.mesh = cm
		var bmat := StandardMaterial3D.new()
		var bc: Color = G67Data.ROOM_COLOR[type]
		bmat.albedo_color = Color(bc.r, bc.g, bc.b, 0.16)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bmat
		beam.position = pos + Vector3(0, 11.0, 0)
		add_child(beam)
		_light(pos + Vector3(0, 2.6, 1.6), G67Data.ROOM_COLOR[type], 2.4, 7.0)
		gates.append({"root": g, "label": lbl, "option": o, "icon": ic})
		_point("gate%d" % i, String(G67Data.ROOM_NAMES[type]), String(G67Data.ROOM_HINT[type]), pos + Vector3(0, 0, 1.7))

## Дверь подъезда во дворе: вернуться домой посреди забега (забег встаёт на паузу)
func add_home() -> void:
	if yard == null:
		return
	for pt in points:
		if String(pt["id"]) == "home":
			return
	_point("home", "ПОДЪЕЗД", "домой: забег сохранится, продолжишь отсюда же", yard.position + G67Yard.HOME_DOOR)

## Место отдыха в комнате ПЕРЕДЫШКА: беседка за гаражами
func add_rest() -> void:
	_point("rest", "БЕСЕДКА", "перевести дух: восстановить здоровье", Vector3(0.6, 0, 0.4))
