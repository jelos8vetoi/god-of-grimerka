## Помещения «ОБЛАКО — ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ», которые видно на камерах: главный зал со сценой,
## игровая зона с автоматами, склад маскотов, серверная, узел вентиляции, комната питания и «комната 9»,
## которой нет на плане. Коридоры 4 и 5 — настоящие, они построены у офиса (FNOffice). Комнаты стоят в стороне
## от будки (x = 60…), у каждой — свой тусклый свет, своя камера (точка и куда смотрит) и места для врагов.
class_name FNFacility
extends Node3D

var office: FNOffice
var cams := {}                     # id → {pos, look, fov}
var spots := {}                    # id → Array[Transform3D] мест в комнате (варианты поз)
var blink: Array = []              # мигающие огоньки серверов
var screens: Array = []            # экраны автоматов (мерцают)
var t := 0.0

func build(o: FNOffice) -> void:
	office = o
	_stage(Vector3(60, 0, 0))
	_arcade(Vector3(85, 0, 0))
	_storage(Vector3(110, 0, 0))
	_server(Vector3(135, 0, 0))
	_vent(Vector3(160, 0, 0))
	_power(Vector3(185, 0, 0))
	_room9(Vector3(210, 0, 0))
	# коридоры у офиса: камера в дальнем конце смотрит к повороту (нишу у двери не видно)
	for s in [-1.0, 1.0]:
		var x: float = s * (FNOffice.W + 1.55)
		var id := "hall_l" if s < 0 else "hall_r"
		cams[id] = {"pos": Vector3(x - s * 0.3, 2.35, -9.5), "look": Vector3(x, 0.9, -1.0), "fov": 62.0}
		spots[id] = [_xf(Vector3(x, 0, -4.6), 0.0), _xf(Vector3(x + s * 0.2, 0, -6.4), 0.0), _xf(Vector3(x, 0, -3.0), 0.0)]

func _xf(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)

func m(k: String) -> Material:
	return office.mats[k]

## коробка комнаты: пол, стены, потолок
func _shell(o: Vector3, size: Vector3, wall := "wall") -> void:
	office.box(o + Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.z), m("floor"), self)
	office.box(o + Vector3(0, size.y + 0.05, 0), Vector3(size.x, 0.1, size.z), m("black"), self)
	office.box(o + Vector3(0, size.y / 2, -size.z / 2), Vector3(size.x, size.y, 0.1), m(wall), self)
	office.box(o + Vector3(0, size.y / 2, size.z / 2), Vector3(size.x, size.y, 0.1), m(wall), self)
	office.box(o + Vector3(-size.x / 2, size.y / 2, 0), Vector3(0.1, size.y, size.z), m(wall), self)
	office.box(o + Vector3(size.x / 2, size.y / 2, 0), Vector3(0.1, size.y, size.z), m(wall), self)

func _omni(p: Vector3, e: float, r: float, c := Color(1, 0.92, 0.8)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_energy = e
	l.omni_range = r
	l.light_color = c
	add_child(l)
	return l

func _spot(p: Vector3, look: Vector3, e: float, angle: float, c := Color(1, 0.9, 0.8)) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = p
	l.look_at(look, Vector3.UP if absf((look - p).normalized().y) < 0.95 else Vector3.FORWARD)
	l.light_energy = e
	l.spot_angle = angle
	l.spot_range = (look - p).length() * 2.0
	l.light_color = c
	l.shadow_enabled = true
	return l

## главный зал: сцена с занавесом, столы, баннер
func _stage(o: Vector3) -> void:
	_shell(o, Vector3(14, 4.2, 12))
	office.box(o + Vector3(0, 0.45, -4.4), Vector3(8, 0.9, 3.0), m("black"), self)              # сцена
	office.box(o + Vector3(0, 0.92, -2.9), Vector3(8, 0.06, 0.08), m("red"), self)
	for x in [-4.4, 4.4]:
		office.box(o + Vector3(x, 2.4, -5.0), Vector3(1.2, 3.6, 0.3), m("red"), self)          # занавес
	office.box(o + Vector3(0, 3.9, -5.4), Vector3(9.6, 0.5, 0.2), m("red"), self)
	office.label("ОБЛАКО", o + Vector3(0, 3.35, -5.85), 260, Color(0.85, 0.08, 0.06))
	office.label("ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ", o + Vector3(0, 2.75, -5.85), 70, Color(0.85, 0.82, 0.76))
	for i in 6:
		var p := o + Vector3(-4.0 + float(i % 3) * 4.0, 0, 0.6 + float(i / 3) * 3.0)
		office.box(p + Vector3(0, 0.72, 0), Vector3(1.6, 0.06, 1.0), m("paper"), self)
		office.box(p + Vector3(0, 0.36, 0), Vector3(0.1, 0.72, 0.1), m("metal"), self)
		for cz in [-0.8, 0.8]:
			office.box(p + Vector3(0.3 * cz, 0.45, cz), Vector3(0.42, 0.06, 0.42), m("black"), self)
		# шапочки праздника, забытые на столах
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.08
		cm.height = 0.22
		cone.mesh = cm
		cone.material_override = m("red")
		cone.position = p + Vector3(0.4, 0.86, 0.1)
		cone.rotation.z = 1.2 if i % 2 == 0 else 0.0
		add_child(cone)
	office.label("СОТРУДНИК МЕСЯЦА", o + Vector3(6.94, 2.6, -2.0), 60, Color(0.2, 0.2, 0.2), Vector3(0, -PI / 2, 0))
	_spot(o + Vector3(0, 4.0, 1.0), o + Vector3(0, 0.9, -4.4), 3.5, 28.0, Color(1.0, 0.35, 0.3))
	_omni(o + Vector3(-4, 3.8, 3), 0.35, 7.0)
	_omni(o + Vector3(4, 3.8, 3), 0.25, 7.0)
	cams["stage"] = {"pos": o + Vector3(6.4, 3.9, 5.4), "look": o + Vector3(-0.5, 1.0, -3.0), "fov": 64.0}
	spots["stage"] = [_xf(o + Vector3(0, 0.9, -4.3), 0.0), _xf(o + Vector3(-2.2, 0.9, -4.6), 0.3), _xf(o + Vector3(1.8, 0, 2.2), -0.6)]

## игровая зона: ряды автоматов, стойка выдачи билетов
func _arcade(o: Vector3) -> void:
	_shell(o, Vector3(12, 3.4, 10))
	var names := ["VOZDUH RUN", "BALON FIGHTER", "ТЯГА 812", "MADK SKATE", "ОБЛАКО", "BOT WARS"]
	for i in 6:
		var p := o + Vector3(-4.0 + float(i % 3) * 2.4, 0, -3.0 + float(i / 3) * 4.2)
		var yaw := 0.0 if i < 3 else PI
		var c := Node3D.new()
		c.position = p
		c.rotation.y = yaw
		add_child(c)
		office.box(Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.8), m("black"), c)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.05, 0.08, 0.1)
		sm.emission_enabled = true
		sm.emission = [Color(0.9, 0.2, 0.2), Color(0.3, 0.6, 1.0), Color(0.9, 0.9, 0.9)][i % 3]
		sm.emission_energy_multiplier = 1.2
		office.box(Vector3(0, 1.35, 0.41), Vector3(0.7, 0.5, 0.02), sm, c)
		screens.append(sm)
		office.label(names[i], Vector3(0, 1.75, 0.42), 40, Color(0.85, 0.1, 0.1), Vector3.ZERO, c)
		office.box(Vector3(0, 0.95, 0.42), Vector3(0.8, 0.12, 0.2), m("metal"), c)
	office.box(o + Vector3(4.8, 0.55, 2.0), Vector3(1.4, 1.1, 4.0), m("red"), self)          # стойка билетов
	office.label("БИЛЕТЫ", o + Vector3(4.08, 1.3, 2.0), 50, Color(0.9, 0.86, 0.8), Vector3(0, -PI / 2, 0))
	_omni(o + Vector3(0, 3.1, 0), 0.45, 8.0, Color(0.8, 0.85, 1.0))
	cams["arcade"] = {"pos": o + Vector3(-5.5, 3.1, 4.4), "look": o + Vector3(0.5, 0.9, -1.0), "fov": 66.0}
	spots["arcade"] = [_xf(o + Vector3(-1.6, 0, -1.0), 0.6), _xf(o + Vector3(0.8, 0, 3.0), 2.6), _xf(o + Vector3(3.6, 0, -0.6), -1.4)]

## склад маскотов: стеллажи с головами, коробки, висящий костюм
func _storage(o: Vector3) -> void:
	_shell(o, Vector3(10, 3.2, 9))
	for k in 3:
		var x := -3.8 + k * 3.0
		office.box(o + Vector3(x, 1.2, -3.8), Vector3(2.4, 2.4, 0.6), m("metal"), self)
		for j in 3:
			var head := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.28
			sp.height = 0.56
			head.mesh = sp
			head.material_override = m("paper") if (k + j) % 2 == 0 else m("red")
			head.position = o + Vector3(x - 0.75 + j * 0.75, 1.75, -3.55)
			add_child(head)
			for ex in [-0.09, 0.09]:
				office.box(head.position + Vector3(ex, 0.05, 0.26), Vector3(0.05, 0.07, 0.02), m("black"), self)
	for i in 8:
		office.box(o + Vector3(randf_range(-4, 4), 0.35, randf_range(-1, 3.5)), Vector3(0.8, 0.7, 0.7), m("desk"), self, Vector3(0, randf_range(0, 1), 0))
	# висящий костюм Балона на крюке
	var hang := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.32
	cc.bottom_radius = 0.38
	cc.height = 1.2
	hang.mesh = cc
	hang.material_override = m("red")
	hang.position = o + Vector3(3.6, 1.9, 1.5)
	add_child(hang)
	_omni(o + Vector3(-1, 2.9, 1), 0.3, 6.0, Color(1.0, 0.85, 0.65))
	cams["storage"] = {"pos": o + Vector3(4.4, 2.9, 4.0), "look": o + Vector3(-1.0, 0.8, -1.5), "fov": 64.0}
	spots["storage"] = [_xf(o + Vector3(-1.5, 0, 0.5), 0.8), _xf(o + Vector3(1.0, 0, -2.6), 0.2), _xf(o + Vector3(-3.0, 0, 2.4), 1.6)]
	spots["ghost_storage"] = [_xf(o + Vector3(2.6, 0, -2.9), 0.6)]

## серверная: стойки с мигающими огнями, кабели по полу
func _server(o: Vector3) -> void:
	_shell(o, Vector3(10, 3.0, 9), "black")
	for row in 2:
		for k in 4:
			var p := o + Vector3(-3.0 + k * 2.0, 0, -2.0 + row * 3.8)
			office.box(p + Vector3(0, 1.1, 0), Vector3(0.8, 2.2, 1.0), m("metal"), self)
			for j in 6:
				var led := StandardMaterial3D.new()
				led.albedo_color = Color(0.1, 1.0, 0.3) if (j + k) % 3 else Color(1.0, 0.15, 0.1)
				led.emission_enabled = true
				led.emission = led.albedo_color
				led.emission_energy_multiplier = 2.0
				led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				office.box(p + Vector3(-0.25 + (j % 3) * 0.25, 0.6 + (j / 3) * 0.9, 0.51 * (1 if row == 0 else -1)), Vector3(0.05, 0.05, 0.01), led, self)
				blink.append(led)
	office.label("СЕРВЕР 06 — ОБЛАКО ХРАНИТ ВСЁ", o + Vector3(0, 2.5, -4.44), 60, Color(0.8, 0.1, 0.1))
	_omni(o + Vector3(0, 2.7, 0), 0.22, 6.0, Color(0.55, 0.75, 1.0))
	cams["server"] = {"pos": o + Vector3(4.4, 2.7, 3.8), "look": o + Vector3(-1.0, 0.9, -0.5), "fov": 64.0}
	spots["server"] = [_xf(o + Vector3(0, 0, 0.0), -0.9), _xf(o + Vector3(-2.0, 0, 0.0), 0.5), _xf(o + Vector3(2.0, 0, 3.2), 2.8)]

## узел вентиляции: жестяной короб, развилка налево и вверх
func _vent(o: Vector3) -> void:
	_shell(o, Vector3(4, 1.4, 8), "shutter")
	office.box(o + Vector3(-1.4, 0.7, -2.6), Vector3(1.2, 1.2, 0.05), m("black"), self)      # проём левой шахты
	office.box(o + Vector3(0.6, 1.38, -1.0), Vector3(1.0, 0.05, 1.0), m("black"), self)      # проём вверх
	office.label("← ЛЕВАЯ", o + Vector3(-1.4, 1.2, -2.55), 40, Color(0.75, 0.1, 0.1))
	office.label("ВВЕРХ ↑", o + Vector3(0.6, 1.2, -2.0), 40, Color(0.75, 0.1, 0.1))
	for k in 6:
		office.box(o + Vector3(0, 0.0, -3.4 + k * 1.3), Vector3(4, 0.02, 0.06), m("metal"), self)
	_omni(o + Vector3(0, 1.2, 2.5), 0.4, 4.0, Color(0.7, 0.8, 0.7))
	cams["vent"] = {"pos": o + Vector3(0.6, 1.2, 3.6), "look": o + Vector3(-0.3, 0.3, -2.0), "fov": 70.0}
	spots["vent"] = [_xf(o + Vector3(-0.2, 0.25, -0.5), 0.0)]
	spots["ghost_vent"] = [_xf(o + Vector3(1.2, 0.0, -2.8), 0.2)]

## комната питания: генератор, щитки, таблички
func _power(o: Vector3) -> void:
	_shell(o, Vector3(9, 3.0, 8))
	office.box(o + Vector3(-2.5, 0.8, -2.4), Vector3(2.4, 1.6, 1.4), m("metal"), self)
	for k in 4:
		office.box(o + Vector3(1.2 + k * 0.9, 1.5, -3.94), Vector3(0.7, 1.0, 0.1), m("shutter"), self)
		office.label("ЩИТ %d" % (k + 1), o + Vector3(1.2 + k * 0.9, 2.15, -3.88), 30, Color(0.85, 0.82, 0.75))
	office.label("ВЫСОКОЕ НАПРЯЖЕНИЕ\nНЕ ВЛЕЗАЙ — УБЬЁТ", o + Vector3(-2.5, 2.2, -3.94), 50, Color(0.85, 0.08, 0.06))
	_omni(o + Vector3(0, 2.7, 0), 0.3, 6.0, Color(1.0, 0.75, 0.5))
	cams["power"] = {"pos": o + Vector3(3.8, 2.7, 3.4), "look": o + Vector3(-0.5, 0.9, -1.5), "fov": 64.0}
	spots["power"] = [_xf(o + Vector3(0.2, 0, -1.2), 0.3), _xf(o + Vector3(-1.4, 0, 1.0), 0.9), _xf(o + Vector3(2.5, 0, 0.6), -0.6)]

## комната 9: стул, телевизор с помехами, красная лампа. На плане её нет.
func _room9(o: Vector3) -> void:
	_shell(o, Vector3(6, 2.8, 6))
	office.box(o + Vector3(0, 0.45, -0.5), Vector3(0.5, 0.06, 0.5), m("black"), self)
	office.box(o + Vector3(0, 0.75, -0.73), Vector3(0.5, 0.6, 0.06), m("black"), self)
	var tvm := StandardMaterial3D.new()
	tvm.albedo_color = Color(0.6, 0.6, 0.6)
	tvm.emission_enabled = true
	tvm.emission = Color(0.8, 0.8, 0.8)
	tvm.emission_energy_multiplier = 1.5
	office.box(o + Vector3(0, 1.0, -2.6), Vector3(0.8, 0.6, 0.05), tvm, self)
	screens.append(tvm)
	office.label("ТЫ ТОЖЕ ЗДЕСЬ БУДЕШЬ", o + Vector3(0, 2.2, -2.94), 50, Color(0.6, 0.0, 0.0))
	_omni(o + Vector3(0, 2.5, 0), 0.6, 5.0, Color(1.0, 0.1, 0.08))
	cams["room9"] = {"pos": o + Vector3(2.4, 2.5, 2.4), "look": o + Vector3(0, 0.6, -0.8), "fov": 60.0}
	spots["room9"] = [_xf(o + Vector3(0, 0, -0.5), 0.0)]
	spots["ghost_room9"] = [_xf(o + Vector3(-1.4, 0, -1.8), 0.4)]
	spots["ghost_arcade"] = [_xf(Vector3(85, 0, 0) + Vector3(5.2, 0, -3.6), -0.6)]

func tick(dt: float) -> void:
	t += dt
	for i in blink.size():
		var led: StandardMaterial3D = blink[i]
		led.emission_energy_multiplier = 2.0 if fposmod(t * (1.3 + float(i % 5) * 0.7) + float(i) * 0.37, 1.0) < 0.6 else 0.2
	for i in screens.size():
		(screens[i] as StandardMaterial3D).emission_energy_multiplier = 0.9 + 0.5 * sin(t * (7.0 + i)) * randf()

## место врага в комнате (вариант позы)
func spot(id: String, variant: int) -> Transform3D:
	var arr: Array = spots.get(id, [])
	if arr.is_empty():
		return Transform3D(Basis(), Vector3(0, -50, 0))
	return arr[variant % arr.size()]
