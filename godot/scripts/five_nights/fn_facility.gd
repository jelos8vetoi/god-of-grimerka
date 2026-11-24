## Помещения «ОБЛАКО — ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ», которые видно на камерах: главный зал со сценой,
## игровая зона с автоматами, склад маскотов, серверная, узел вентиляции, комната питания, служебка (видна из правого
## коридора) и «комната 9», которой нет на плане. Коридор 4 (левый) — сцена cam4_corridor.tscn (FNCorridor), коридор 5
## строится здесь; оба подходят к нишам будки.
## Модели — MGModels: .glb владельца из godot/assets/minigames (tools/tripo-minigames.json), а пока его нет —
## собранные кодом (MGProps). У каждой комнаты свой свет, своя история в предметах, своя камера (точка, куда смотрит,
## размах поворота sway) и места для врагов. Для аномалий камер (FNAnomaly) комнаты отдают: свет (lights), силуэт в
## углу (figure), предметы, которые могут «переехать» (movable), головы, которые могут повернуться к камере (heads).
class_name FNFacility
extends Node3D

const StageArt := preload("res://scripts/five_nights/fn_stage_art.gd")

const CHALK := preload("res://assets/fn_curated/phase3/finishes/chalk.tres")
const LIME := preload("res://assets/fn_curated/phase3/finishes/lime.tres")
const RED_DADO := preload("res://assets/fn_curated/phase3/finishes/oxblood.tres")
const GREEN_DADO := preload("res://assets/fn_curated/phase3/finishes/jade.tres")
const DARK_DADO := preload("res://assets/fn_curated/phase3/finishes/slate.tres")
const CONCRETE := preload("res://assets/fn_curated/phase3/finishes/concrete.tres")
const LINO := preload("res://assets/fn_curated/phase3/finishes/lino.tres")
const DUCT_STEEL := preload("res://assets/fn_curated/phase2/materials/metal_plate_02.tres")
const PENDANT := preload("res://assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf")
const TOOLBOX := preload("res://assets/fn_curated/models/metal_toolbox/metal_toolbox.gltf")
const SERVICE_DOOR := preload("res://assets/fn_curated/phase2/models/service_door.glb")
const UTILITY_BOX := preload("res://assets/fn_curated/models/utility_box_01/utility_box_01.gltf")
const WORKBENCH := preload("res://assets/fn_curated/models/metal_office_desk/metal_office_desk.gltf")

var office: FNOffice
var hall_l: FNCorridor             # левый коридор — сцена, собранная в редакторе
var cams := {}                     # id → {pos, look, fov, sway}
var spots := {}                    # id → Array[Transform3D] мест в комнате (варианты поз)
var blink: Array = []              # мигающие огоньки (материалы)
var screens: Array = []            # экраны (ShaderMaterial) — мерцают
var lights := {}                   # id комнаты → Array[Light3D] (для аномалий «свет»)
var figures := {}                  # id комнаты → силуэт в углу (скрыт)
var movable := {}                  # id комнаты → [узел, другое положение, другой поворот]
var heads := {}                    # id комнаты → Array[Node3D] (головы маскотов)
var gauges: Array = []
var balloons: Array = []
var t := 0.0

func build(o: FNOffice, left: FNCorridor) -> void:
	office = o
	hall_l = left
	_figure("office", Vector3(-0.45, 0, 1.25), PI)   # аномалия камеры за спиной охранника
	_stage(Vector3(60, 0, 0))
	_arcade(Vector3(85, 0, 0))
	_storage(Vector3(110, 0, 0))
	_server(Vector3(135, 0, 0))
	_vent(Vector3(160, 0, 0))
	_power(Vector3(185, 0, 0))
	_room9(Vector3(210, 0, 0))
	# левый коридор — сцена: камера, места врагов и силуэт берутся из неё
	cams["hall_l"] = left.view
	spots["hall_l"] = left.spot_xf
	figures["hall_l"] = left.figure
	# правый коридор: камера в дальнем конце смотрит к повороту (нишу у двери не видно)
	var x: float = FNOffice.W + 1.55
	cams["hall_r"] = {"pos": Vector3(x - 0.27, 2.25, -9.42), "look": Vector3(x + 0.12, 1.12, -2.0), "fov": 56.0, "sway": 2.0}
	spots["hall_r"] = [_xf(Vector3(x, 0, -4.6), 0.0), _xf(Vector3(x + 0.2, 0, -6.4), 0.0), _xf(Vector3(x, 0, -3.0), 0.0)]
	_hall(1.0, x, "hall_r")

func _xf(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)

func m(k: String) -> Material:
	return office.mats[k]

## модель в слот: .glb владельца или код
## Модели из файла в тёмных комнатах чуть светятся своим цветом — иначе на камере сливаются в пятно. Камера ночного
## видения сильно усиливает яркость, поэтому числа крошечные; чёрным стойкам подсветка не нужна (свет в проходе).
const GLB_LIFT := 0.012
const GLB_LIFT_BY := {"fn_mascot_shelf": 0.006, "fn_prize_counter": 0.005, "fn_generator": 0.003, "fn_server_rack": 0.0, "fn_arcade_cabinet": 0.004}

func put(id: String, p: Vector3, yaw: float, size: Vector3, build_fn: Callable) -> Node3D:
	var r := MGModels.spawn(id, self, p, yaw, size, build_fn)
	var lk: float = GLB_LIFT_BY.get(id, GLB_LIFT)
	if lk > 0.0:
		MGModels.lift(r, lk)
	return r

## пустой узел в точке — для мелких моделей кодом
func node(p: Vector3, yaw := 0.0, parent: Node = self) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	parent.add_child(n)
	return n

## Отделка общая для заведения, с разным цоколем в публичных и служебных зонах.
func _shell(o: Vector3, size: Vector3, paving: Material, wall: Material, dado: Material = null) -> void:
	office.box(o + Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.z), paving, self)
	office.box(o + Vector3(0, size.y + 0.05, 0), Vector3(size.x, 0.1, size.z), CHALK, self)
	var x := size.x * 0.5
	var z := size.z * 0.5
	for side in [-1.0, 1.0]:
		office.box(o + Vector3(0, size.y * 0.5, side * z), Vector3(size.x, size.y, 0.1), wall, self)
		office.box(o + Vector3(side * x, size.y * 0.5, 0), Vector3(0.1, size.y, size.z), wall, self)
		if dado != null:
			office.box(o + Vector3(0, 0.49, side * (z - 0.063)), Vector3(size.x - 0.14, 0.98, 0.023), dado, self)
			office.box(o + Vector3(side * (x - 0.063), 0.49, 0), Vector3(0.023, 0.98, size.z - 0.14), dado, self)
			for y in [0.07, 0.98]:
				office.box(o + Vector3(0, y, side * (z - 0.087)), Vector3(size.x - 0.21, 0.047, 0.038), DARK_DADO, self)
				office.box(o + Vector3(side * (x - 0.087), y, 0), Vector3(0.038, 0.047, size.z - 0.21), DARK_DADO, self)
	if dado != null:
		for k in range(1, int(size.z / 1.55)):
			office.box(o + Vector3(0, size.y - 0.063, -z + float(k) * 1.55), Vector3(size.x - 0.12, 0.126, 0.11), DARK_DADO, self)

func _prop(scene: PackedScene, p: Vector3, yaw := 0.0, uniform_scale := 1.0) -> void:
	var model := scene.instantiate() as Node3D
	model.position = p
	model.rotation.y = yaw
	model.scale = Vector3.ONE * uniform_scale
	add_child(model)

func _sign(p: Vector3, yaw: float, words: String, width: float, pixels: int, backing: Material, ink: Color) -> void:
	var plaque := node(p, yaw)
	MGProps.box(plaque, Vector3.ZERO, Vector3(width, 0.27, 0.038), backing)
	MGProps.text(plaque, words, Vector3(0, 0, 0.025), pixels, ink).shaded = true

func _omni(room: String, p: Vector3, e: float, r: float, c := Color(1, 0.92, 0.8)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	e *= 1.7                                # на камере (зелёный монохром) детали должны читаться
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.4
	l.light_specular = 0.06
	l.light_color = c
	l.set_meta("base", e)
	l.set_meta("col", c)
	add_child(l)
	if room != "":
		if not lights.has(room):
			lights[room] = []
		(lights[room] as Array).append(l)
	return l

func _spot(room: String, p: Vector3, look: Vector3, e: float, angle: float, reach: float, c := Color(1, 0.9, 0.8)) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = p
	l.look_at(look, Vector3.UP if absf((look - p).normalized().y) < 0.95 else Vector3.FORWARD)
	l.light_energy = e
	l.spot_angle = angle
	l.spot_range = reach
	l.spot_attenuation = 1.1
	l.spot_angle_attenuation = 1.1
	l.light_specular = 0.1
	l.light_color = c
	l.shadow_enabled = true
	l.set_meta("base", e)
	l.set_meta("col", c)
	if room != "":
		if not lights.has(room):
			lights[room] = []
		(lights[room] as Array).append(l)
	return l

## силуэт: чёрная фигура с точками глаз — для аномалии «кто-то стоит в углу»; скрыт
func _figure(room: String, p: Vector3, yaw: float) -> void:
	var f := node(p, yaw)
	MGProps.caps(f, Vector3(0, 0.95, 0), 0.24, 1.6, MGProps.mat("black"))
	MGProps.ball(f, Vector3(0, 1.78, 0), 0.2, MGProps.mat("black"), Vector3(1, 1.15, 1))
	for ex in [-0.065, 0.065]:
		MGProps.ball(f, Vector3(ex, 1.8, 0.17), 0.03, m("eye"))      # в тёмном углу видно только глаза
	f.visible = false
	figures[room] = f

func _lamp_row(_room: String, o: Vector3, y: float, xs: Array, c: Color) -> void:
	for x in xs:
		var n := node(o + Vector3(float(x), y, 0))
		var d := MGProps.strip_lamp(n, 1.2, c)
		blink.append(d["tube"])

# ---------------- коридоры у офиса: свет, кабели, двери, история ----------------
func _hall(s: float, x: float, id: String) -> void:
	var inner := s * (FNOffice.W + 0.85)
	var wall_out := s * (FNOffice.W + 2.2)
	var face := -PI / 2 if s > 0 else PI / 2
	office.box(Vector3(x, -0.05, -5.425), Vector3(1.3, 0.1, 8.75), CONCRETE, self)
	office.box(Vector3(x, 2.55, -5.2), Vector3(1.3, 0.1, 9.2), CHALK, self)
	office.box(Vector3(inner, 1.25, -5.6), Vector3(0.1, 2.5, 8.4), LIME, self)
	office.box(Vector3(s * (FNOffice.W + 2.25), 1.25, -5.2), Vector3(0.1, 2.5, 9.2), LIME, self)
	office.box(Vector3(x, 1.25, -9.85), Vector3(1.3, 2.5, 0.1), LIME, self)
	for wall_x in [inner + s * 0.063, wall_out - s * 0.013]:
		office.box(Vector3(wall_x, 0.50, -5.52), Vector3(0.023, 1.0, 8.15), GREEN_DADO, self)
		office.box(Vector3(wall_x, 1.0, -5.52), Vector3(0.040, 0.047, 8.15), DARK_DADO, self)
		office.box(Vector3(wall_x, 0.07, -5.52), Vector3(0.040, 0.070, 8.15), DARK_DADO, self)
	for z in [-2.92, -6.48, -8.45]:
		MGProps.box(self, Vector3(x, 2.43, z), Vector3(1.22, 0.13, 0.14), DARK_DADO)
	for z in [-3.3, -6.88]:
		var d := MGProps.strip_lamp(node(Vector3(x, 2.49, z), PI / 2), 0.83, Color("#d5dac6"))
		blink.append(d["tube"])
	_spot("", Vector3(x, 2.34, -6.88), Vector3(wall_out, 0.69, -5.9), 2.25, 54, 4.0, Color("#d5dac6"))
	_spot("", Vector3(x, 2.34, -3.30), Vector3(inner, 0.96, -2.55), 2.45, 50, 3.5, Color("#d7c8ac"))
	# кабели вдоль стены под потолком
	for k in 3:
		MGProps.cable(self, Vector3(wall_out - s * 0.05, 2.35 - k * 0.04, -0.8), Vector3(wall_out - s * 0.05, 2.32 - k * 0.04, -9.6), 0.15 + k * 0.05, 0.012, MGProps.mat("rubber"))
	var p1 := node(Vector3(wall_out - s * 0.06, 1.5, -5.2), face)
	MGProps.poster(p1, "ДЕНЬ\nРОЖДЕНИЯ\nВ ОБЛАКЕ", "каждую субботу · аниматоры · торт", Color(0.75, 0.05, 0.05), 0.5, 0.7)
	# дверь служебки приоткрыта, за ней — тележка уборщика и шкафчики (служебные помещения)
	var dz := -6.6
	office.box(Vector3(wall_out, 1.05, dz), Vector3(0.12, 2.1, 0.95), m("black"), self)      # проём
	var door := node(Vector3(wall_out - s * 0.05, 0, dz - 0.45), 0.0)
	MGProps.box(door, Vector3(0, 1.05, 0.46), Vector3(0.05, 2.05, 0.9), MGProps.mat("blue_paint"))
	door.rotation.y = 0.55
	_sign(Vector3(wall_out - s * 0.072, 2.24, dz), face, "СЛУЖЕБНОЕ", 0.92, 33, DARK_DADO, Color("#ddd5b9"))
	_prop(UTILITY_BOX, Vector3(inner + s * 0.09, 1.31, -8.18), -face, 0.51)
	MGProps.poster(node(Vector3(inner + s * 0.064, 1.53, -4.18), -face), "СМЕНА", "инвентарь вернуть", Color("#b28a5a"), 0.43, 0.53)
	var cart := node(Vector3(x + 0.25, 0, -5.4), 0.2)
	MGProps.janitor_cart(cart)
	var lk := node(Vector3(wall_out - s * 0.3, 0, -8.6), face)
	MGProps.locker(lk, 0.35, "ОХРАНА")
	var lk2 := node(Vector3(wall_out - s * 0.3, 0, -9.1), face)
	MGProps.locker(lk2, 0.0, "АНИМАТОР")
	movable[id] = [cart, Vector3(x - 0.2, 0, -3.4), 1.3]   # тележка «сама» переехала ближе
	_figure(id, Vector3(x + s * 0.25, 0, -9.3), 0.0)

# ---------------- главный зал: сцена, занавес, столы праздника ----------------
func _stage(o: Vector3) -> void:
	var room := StageArt.new()
	room.name = "MainHall"
	room.position = o
	add_child(room)
	room.build()
	lights["stage"] = room.lights
	_figure("stage", o + Vector3(-6.2, 0, -5.2), 0.6)
	cams["stage"] = {"pos": o + Vector3(5.73, 3.53, 5.47), "look": o + Vector3(-0.74, 1.12, -3.58), "fov": 51.0, "sway": 1.6}
	spots["stage"] = [_xf(o + Vector3(0, 0.9, -4.3), 0.0), _xf(o + Vector3(-2.2, 0.9, -4.6), 0.3), _xf(o + Vector3(1.8, 0, 2.2), -0.6)]

# ---------------- игровая зона: автоматы, призы, ковёр ----------------
func _arcade(o: Vector3) -> void:
	_shell(o, Vector3(12, 3.4, 10), LINO, LIME, RED_DADO)
	# ковёр с космическим узором — тёмно-синий с красными пятнами
	var rug := MGProps.box(self, o + Vector3(-0.5, 0.004, 0.4), Vector3(9.0, 0.008, 7.0), DARK_DADO)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var names := ["VOZDUH RUN", "BALON FIGHTER", "ТЯГА 812", "MADK SKATE", "ОБЛАКО", "BOT WARS"]
	var cols := [Color(0.9, 0.2, 0.2), Color(0.3, 0.6, 1.0), Color(0.9, 0.9, 0.9), Color(0.95, 0.6, 0.15), Color(0.6, 0.3, 1.0), Color(0.2, 1.0, 0.5)]
	for i in 6:
		@warning_ignore("integer_division")
		var p := o + Vector3(-4.0 + float(i % 3) * 2.4, 0, -3.0 + float(i / 3) * 4.2)
		var yaw: float = [-0.12, 0.05, -0.10, -1.22, -1.52, -1.10][i]
		var title: String = names[i]
		var col: Color = cols[i]
		var cab := put("fn_arcade_cabinet", p, yaw + (0.08 if i == 4 else 0.0), Vector3(0.8, 1.9, 0.9), func(r):
			var d := MGProps.arcade(r, title, col, float(i))
			screens.append(d["screen"])
			blink.append(d["marquee"]))
		if MGModels.is_glb(cab) and i != 4:
			# у модели из файла экран тёмный — поверх стекла светится игра (пятый автомат выключен)
			var sm := MGProps.screen_mat(col, 0.0, float(i), 1.2)
			MGProps.quad(cab, MGModels.local(cab, Vector3(-0.003, 0.673, 0.062)), Vector2(0.31, 0.205) * float(cab.get_meta("k")), sm, Vector3(-0.15, 0, 0))
			screens.append(sm)
		if i == 2:
			movable["arcade"] = [cab, p + Vector3(0.6, 0, 1.1), yaw + 0.9]   # автомат «развернулся»
	# автомат, выключенный из сети, — накрыт тканью
	var cov := node(o + Vector3(4.6, 0, -3.6))
	MGProps.box(cov, Vector3(0, 0.95, 0), Vector3(0.95, 1.9, 0.85), MGProps.mat("fabric"))
	MGProps.box(cov, Vector3(0.1, 1.92, 0.1), Vector3(1.0, 0.08, 0.95), MGProps.mat("fabric"), Vector3(0, 0, 0.06))
	var pc := put("fn_prize_counter", o + Vector3(4.7, 0, 2.0), -PI / 2, Vector3(2.3, 2.0, 1.5), func(r): MGProps.prize_counter(r))
	pc.scale = Vector3.ONE * 0.95
	for k in 6:                                                     # кабели автоматов по полу к розеткам
		@warning_ignore("integer_division")
		MGProps.cable(self, o + Vector3(-4.0 + float(k % 3) * 2.4, 0.05, -3.4 + float(k / 3) * 4.6 + (0.4 if k >= 3 else -0.4)), o + Vector3(-5.9, 0.02, -3.0 + k * 0.8), 0.0, 0.015)
	for k in 3:
		var tk := MGProps.box(self, o + Vector3(-1.0 + k * 0.4, 0.01, 1.2 + k * 0.3), Vector3(0.25, 0.004, 0.08), MGProps.mat("red"), Vector3(0, k, 0))
		tk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prop(SERVICE_DOOR, o + Vector3(5.85, 0, -2.87), -PI / 2)
	_prop(PENDANT, o + Vector3(3.2, 3.34, 1.25), 0.0, 0.58)
	_sign(o + Vector3(5.89, 2.30, 2.0), -PI / 2, "ОБМЕН ЖЕТОНОВ", 1.50, 39, RED_DADO, Color("#e0cba0"))
	for k in 3:
		MGProps.poster(node(o + Vector3(-3.9 + k * 1.55, 1.96, -4.93)), ["КЛУБ ОБЛАКО", "ЖЕТОНЫ", "ДЕНЬ РОЖДЕНИЯ"][k],
			"игровая зона", Color("#c59b67"), 0.62, 0.83)
	MGProps.cable(self, o + Vector3(-4.4, 2.71, -4.81), o + Vector3(4.4, 2.73, -4.81), 0.29, 0.012, MGProps.mat("rubber"))
	for k in 12:
		var along := float(k + 1) / 13.0
		var flag := o + Vector3(lerpf(-4.4, 4.4, along), 2.62 - sin(along * PI) * 0.29, -4.80)
		MGProps.box(self, flag, Vector3(0.15, 0.19, 0.018), RED_DADO if k % 3 == 0 else GREEN_DADO,
			Vector3(0, 0, 0.08 * cos(along * PI)))
	_spot("arcade", o + Vector3(3.26, 2.90, 1.34), o + Vector3(4.4, 1.00, 2.07), 4.4, 48, 5.7, Color("#ffddb0"))
	_spot("arcade", o + Vector3(-2.78, 2.83, -0.78), o + Vector3(-1.85, 0.90, -3.50), 3.35, 54, 5.3, Color("#bacac5"))
	_omni("arcade", o + Vector3(-3.49, 1.38, 2.20), 0.29, 3.35, Color("#b6c8c0"))
	_figure("arcade", o + Vector3(-5.4, 0, -4.2), 0.5)
	cams["arcade"] = {"pos": o + Vector3(-5.47, 2.86, 4.52), "look": o + Vector3(1.08, 0.96, -0.80), "fov": 56.0, "sway": 2.4}
	spots["arcade"] = [_xf(o + Vector3(-1.6, 0, -1.0), 0.6), _xf(o + Vector3(0.8, 0, 3.0), 2.6), _xf(o + Vector3(3.6, 0, -0.6), -1.4)]

# ---------------- склад маскотов: стеллажи с головами, коробки, висящий костюм ----------------
func _storage(o: Vector3) -> void:
	_shell(o, Vector3(10, 3.2, 9), CONCRETE, LIME, GREEN_DADO)
	heads["storage"] = []
	for k in 3:
		var x := -3.4 + k * 3.0
		var sh := put("fn_mascot_shelf", o + Vector3(x, 0, -3.95), 0.0, Vector3(2.2, 2.0, 0.7), func(r):
			var d := MGProps.mascot_shelf(r, k)
			(heads["storage"] as Array).append_array(d["heads"]))
		if MGModels.is_glb(sh):
			# у стеллажа из файла головы — часть модели и повернуться не могут: для аномалии «головы» перед
			# каждым стеллажом лежит по отдельной голове (как та, что на полу)
			(heads["storage"] as Array).append(_loose_head(o + Vector3(x + [0.7, -0.5, 0.3][k], 0.24, -3.2 + k * 0.12), [0.5, -0.4, 2.6][k], ["cream", "fabric", "plastic"][k]))
	# Тара у стен, центральный проход свободен.
	var boxes := [Vector3(-3.96, 0, 2.3), Vector3(-3.93, 0, 1.61), Vector3(-4.16, 0, 2.92),
		Vector3(3.98, 0, -2.46), Vector3(3.54, 0, -2.88), Vector3(-2.94, 0, -2.78)]
	for i in boxes.size():
		var bx := node(o + (boxes[i] as Vector3), -0.2 + float(i % 3) * 0.18)
		MGProps.carton(bx, Vector3(0.64, 0.46, 0.52), ["КОСТЮМЫ", "ГОЛОВЫ", "ВОЗВРАТ"][i % 3])
		if i == 0 or i == 3:
			MGProps.carton(node(Vector3(0.03, 0.46, 0.0), 0.2, bx), Vector3(0.48, 0.31, 0.44), "")
	# висящий костюм Балона на крюке и ещё одна голова на полу — лицом к камере
	var hang := node(o + Vector3(4.44, 0, -0.75), -0.40)
	MGProps.cyl(hang, Vector3(0, 3.0, 0), 0.01, 0.01, 0.5, MGProps.mat("steel"))
	MGProps.caps(hang, Vector3(0, 2.0, 0), 0.35, 1.3, MGProps.mat("fabric_red"))
	for sx in [-0.42, 0.42]:
		MGProps.caps(hang, Vector3(sx, 1.85, 0), 0.1, 0.9, MGProps.mat("fabric_red"), Vector3(0, 0, sx * 0.3))
	(heads["storage"] as Array).append(_loose_head(o + Vector3(2.4, 0.26, 2.6), 2.4, "cream"))
	_prop(WORKBENCH, o + Vector3(-4.17, 0, -0.61), PI / 2, 0.76)
	_prop(TOOLBOX, o + Vector3(-4.03, 0.63, -0.60), 0.22, 0.76)
	_prop(PENDANT, o + Vector3(-1.30, 3.14, -2.0), 0.0, 0.58)
	_prop(SERVICE_DOOR, o + Vector3(4.86, 0, -2.2), -PI / 2, 0.93)
	_sign(o + Vector3(-0.2, 2.46, -4.41), 0.0, "РЕМОНТ МАСКОТОВ", 2.25, 45, GREEN_DADO, Color("#e3d1a5"))
	_spot("storage", o + Vector3(-1.30, 2.69, -1.94), o + Vector3(-1.02, 0.92, -3.95), 5.0, 48, 4.6, Color("#ffdbaf"))
	_spot("storage", o + Vector3(2.46, 2.72, 0.11), o + Vector3(4.44, 1.79, -0.75), 2.65, 37, 4.3, Color("#c2c6b7"))
	_omni("storage", o + Vector3(-3.18, 1.22, -0.44), 0.38, 3.4, Color("#d2c49f"))
	_figure("storage", o + Vector3(-4.4, 0, 3.6), 2.2)
	cams["storage"] = {"pos": o + Vector3(4.26, 2.78, 4.10), "look": o + Vector3(-0.8, 1.12, -2.65), "fov": 57.0, "sway": 2.3}
	spots["storage"] = [_xf(o + Vector3(-1.5, 0, 0.5), 0.8), _xf(o + Vector3(1.0, 0, -2.6), 0.2), _xf(o + Vector3(-3.0, 0, 2.4), 1.6)]
	spots["ghost_storage"] = [_xf(o + Vector3(2.6, 0, -2.9), 0.6)]

## голова маскота, лежащая отдельно (поворачивается в аномалии «головы»)
func _loose_head(p: Vector3, yaw: float, mat_id: String) -> Node3D:
	var fh := node(p, yaw)
	MGProps.ball(fh, Vector3.ZERO, 0.26, MGProps.mat(mat_id))
	for ex in [-0.09, 0.09]:
		MGProps.ball(fh, Vector3(ex, 0.05, 0.22), 0.065, MGProps.mat("paper"))
		MGProps.ball(fh, Vector3(ex, 0.05, 0.27), 0.03, MGProps.mat("black"))
		MGProps.ball(fh, Vector3(ex * 2.2, 0.22, 0), 0.07, MGProps.mat(mat_id))
	MGProps.box(fh, Vector3(0, -0.1, 0.23), Vector3(0.16, 0.04, 0.03), MGProps.mat("black"))
	return fh

# ---------------- серверная: стойки, кабельные лотки, холодный свет ----------------
func _server(o: Vector3) -> void:
	_shell(o, Vector3(10, 3.0, 9), CONCRETE, CHALK, DARK_DADO)
	var n := 0
	for row in 2:
		for k in 4:
			var p := o + Vector3(-3.0 + k * 2.0, 0, -2.0 + row * 3.8)
			var seed_v := n
			# модель из файла — широкая стойка на два отсека: слот шире (между стойками остаётся проход)
			var rk := put("fn_server_rack", p, 0.0 if row == 0 else PI, Vector3(1.15, 2.0, 0.95), func(r):
				var d := MGProps.server_rack(r, seed_v)
				blink.append_array(d["leds"]))
			if MGModels.is_glb(rk):
				# лампочки серверов мигают, как у стойки из кода: по одной на блок в левом отсеке
				for li in 8:
					var lm := MGProps.glow(Color(0.25, 1.0, 0.4) if (li + seed_v) % 3 != 0 else Color(1.0, 0.15, 0.1), 3.0)
					MGProps.ball(rk, MGModels.local(rk, Vector3(-0.086 - 0.02 * (li % 2), [0.828, 0.719, 0.625, 0.539, 0.445, 0.344, 0.242, 0.148][li], 0.28)), 0.018, lm)
					blink.append(lm)
			n += 1
	# кабельный лоток под потолком и пучки к стойкам
	MGProps.box(self, o + Vector3(0, 2.6, -0.1), Vector3(8.6, 0.06, 0.5), MGProps.mat("metal"))
	for k in 8:
		var x := -3.0 + float(k % 4) * 2.0
		@warning_ignore("integer_division")
		var z := -2.0 + float(k / 4) * 3.8
		MGProps.cable(self, o + Vector3(x, 2.58, -0.1), o + Vector3(x + 0.15, 2.1, z), 0.1, 0.02, MGProps.mat("red_dark") if k % 2 else MGProps.mat("blue_paint"))
	var term := node(o + Vector3(4.2, 0, 1.6), -PI / 2)
	_prop(WORKBENCH, o + Vector3(4.17, 0, 1.58), -PI / 2, 0.72)
	var cr := node(Vector3(0, 0.65, -0.05), 0.0, term)
	var d2 := MGProps.crt(cr, Color(0.62, 0.79, 0.66), 1.0, 6.0)
	screens.append(d2["screen"])
	_sign(o + Vector3(0, 2.53, -4.41), 0.0, "ХРАНИЛИЩЕ ОБЛАКО", 2.4, 45, DARK_DADO, Color("#cbd1bc"))
	MGProps.poster(node(o + Vector3(-4.93, 1.54, 0.12), PI / 2), "АРХИВ", "оригиналы не удалять", Color("#bb9b64"), 0.64, 0.79)
	for sx in [-3.05, 2.85]:
		MGProps.box(self, o + Vector3(sx, 2.60, -0.16), Vector3(0.42, 0.085, 8.15), DARK_DADO)
		for z in [-3.0, -1.0, 1.0, 3.0]:
			MGProps.box(self, o + Vector3(sx, 2.76, z), Vector3(0.065, 0.29, 0.056), MGProps.mat("steel"))
	_lamp_row("server", o + Vector3(0, 0, -0.12), 2.85, [-2.4, 1.95], Color("#c8d7d1"))
	_spot("server", o + Vector3(1.95, 2.70, -0.12), o + Vector3(-1.1, 0.94, -1.85), 4.3, 56, 6.0, Color("#b2c9ca"))
	_spot("server", o + Vector3(-2.4, 2.70, -0.12), o + Vector3(-2.48, 0.80, 1.9), 2.5, 42, 4.35, Color("#d5ddd1"))
	_omni("server", o + Vector3(3.75, 1.20, -0.10), 0.45, 3.55, Color("#a3bcab"))
	_omni("server", o + Vector3(-0.15, 1.44, 0.03), 0.68, 3.35, Color("#bbcccd"))
	_figure("server", o + Vector3(-4.3, 0, 3.8), 2.4)
	cams["server"] = {"pos": o + Vector3(4.46, 2.60, 3.88), "look": o + Vector3(-0.65, 1.05, -0.68), "fov": 61.0, "sway": 2.0}
	spots["server"] = [_xf(o + Vector3(0, 0, 0.0), -0.9), _xf(o + Vector3(-2.0, 0, 0.0), 0.5), _xf(o + Vector3(2.0, 0, 3.2), 2.8)]

# ---------------- узел вентиляции: жестяной короб, развилка налево и вверх ----------------
func _vent(o: Vector3) -> void:
	var steel := DUCT_STEEL.duplicate() as StandardMaterial3D
	steel.albedo_color = Color("#898d82")
	steel.metallic = 0.22
	steel.roughness = 0.9
	steel.uv1_triplanar = true
	steel.uv1_world_triplanar = true
	steel.uv1_scale = Vector3.ONE * 0.65
	_shell(o, Vector3(4, 1.4, 8), steel, steel)
	office.box(o + Vector3(-1.4, 0.7, -2.6), Vector3(1.2, 1.2, 0.05), m("black"), self)      # проём левой шахты
	office.box(o + Vector3(0.6, 1.38, -1.0), Vector3(1.0, 0.05, 1.0), m("black"), self)      # проём вверх
	office.label("← ЛЕВАЯ", o + Vector3(-1.4, 1.2, -2.55), 40, Color(0.75, 0.1, 0.1))
	office.label("ВВЕРХ ↑", o + Vector3(0.6, 1.2, -2.0), 40, Color(0.75, 0.1, 0.1))
	for k in 6:
		office.box(o + Vector3(0, 0.01, -3.4 + k * 1.3), Vector3(3.88, 0.018, 0.06), m("metal"), self)
		office.box(o + Vector3(-1.95, 0.7, -3.4 + k * 1.3), Vector3(0.04, 1.4, 0.06), m("metal"), self)
		office.box(o + Vector3(1.92, 0.70, -3.4 + k * 1.3), Vector3(0.052, 1.36, 0.06), m("metal"), self)
		office.box(o + Vector3(0, 1.36, -3.4 + k * 1.3), Vector3(3.88, 0.074, 0.06), m("metal"), self)
	# следы в пыли, клочья ткани, оторванная решётка
	for k in 7:
		var fp := MGProps.box(self, o + Vector3(-0.3 + (k % 2) * 0.3, 0.012, 1.8 - k * 0.6), Vector3(0.14, 0.004, 0.24), MGProps.mat("black"), Vector3(0, 0.1 * (k % 2), 0))
		fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gr := node(o + Vector3(1.1, 0.06, 1.2), 0.5)
	gr.rotation.x = -PI / 2
	MGProps.vent_grill(gr, 0.7, 0.5)
	MGProps.box(self, o + Vector3(-0.9, 0.03, -1.6), Vector3(0.2, 0.05, 0.12), MGProps.mat("fabric_red"), Vector3(0, 0.5, 0.2))
	office.label("НЕ ЗАЛЕЗАТЬ", o + Vector3(1.94, 0.9, 0.5), 32, Color(0.85, 0.8, 0.7), Vector3(0, -PI / 2, 0))
	# Фланец и его крепёж обрамляют развилку; лампа смотрит вдоль шахты.
	var branch := node(o + Vector3(-1.40, 0.68, -2.54))
	for sx in [-0.59, 0.59]:
		MGProps.box(branch, Vector3(sx, 0, 0), Vector3(0.085, 1.20, 0.10), DARK_DADO)
		for y in [-0.44, 0.0, 0.44]:
			MGProps.cyl(branch, Vector3(sx, y, 0.056), 0.024, 0.024, 0.015, MGProps.mat("steel"), Vector3(PI / 2, 0, 0), 6)
	for y in [-0.58, 0.58]:
		MGProps.box(branch, Vector3(0, y, 0), Vector3(1.10, 0.07, 0.10), DARK_DADO)
	MGProps.cable(self, o + Vector3(1.90, 1.20, 3.6), o + Vector3(1.90, 1.20, -3.5), 0.075, 0.018, MGProps.mat("rubber"))
	MGProps.box(self, o + Vector3(1.80, 1.10, 2.34), Vector3(0.20, 0.20, 0.36), DARK_DADO)
	MGProps.box(self, o + Vector3(1.68, 1.10, 2.34), Vector3(0.012, 0.057, 0.22), MGProps.glow(Color("#aebba4"), 0.94))
	_spot("vent", o + Vector3(1.62, 1.08, 2.34), o + Vector3(-0.87, 0.41, -2.58), 3.75, 42, 6.5, Color("#c0caa9"))
	_omni("vent", o + Vector3(-1.35, 0.87, -2.80), 0.29, 2.25, Color("#cfc2a0"))
	_spot("vent", o + Vector3(-1.38, 1.19, 3.25), o + Vector3(0.72, 0.04, 0.52), 1.35, 41, 4.8, Color("#b1c6b8"))
	cams["vent"] = {"pos": o + Vector3(0.82, 1.10, 3.61), "look": o + Vector3(-0.62, 0.40, -2.31), "fov": 61.0, "sway": 0.0}
	spots["vent"] = [_xf(o + Vector3(-0.2, 0.25, -0.5), 0.0)]
	spots["ghost_vent"] = [_xf(o + Vector3(1.2, 0.0, -2.8), 0.2)]

# ---------------- комната питания: генератор, щиты, трубы ----------------
func _power(o: Vector3) -> void:
	_shell(o, Vector3(9, 3.0, 8), CONCRETE, CHALK, GREEN_DADO)
	var g := put("fn_generator", o + Vector3(-2.5, 0, -2.4), 0.24, Vector3(1.4, 1.3, 0.9), func(r):
		var d := MGProps.generator(r)
		gauges.append_array(d["gauges"])
		blink.append(d["lamp"]))
	g.scale = Vector3.ONE * 1.4
	if MGModels.is_glb(g):
		var gl := MGProps.glow(Color(1.0, 0.2, 0.1), 3.0)                # сигнальная лампа над щитком
		MGProps.ball(g, MGModels.local(g, Vector3(0.36, 0.8, 0.0)), 0.03, gl)
		blink.append(gl)
	for k in 4:
		var fp := node(o + Vector3(1.2 + k * 0.9, 1.5, -3.88))
		blink.append_array(MGProps.fuse_panel(fp, "ЩИТ %d" % (k + 1)))
	for k in 3:                                                     # трубы под потолком
		MGProps.cyl(self, o + Vector3(0, 2.6 - k * 0.15, -3.6 + k * 0.2), 0.07, 0.07, 9.0, MGProps.mat("metal"), Vector3(0, 0, PI / 2), 10)
	for k in 4:
		MGProps.cable(self, o + Vector3(1.2 + k * 0.9, 1.1, -3.85), o + Vector3(-1.6, 0.04, -2.0 + k * 0.3), 0.1, 0.025, MGProps.mat("rubber") if k % 2 else MGProps.mat("red_dark"))
	office.label("ВЫСОКОЕ НАПРЯЖЕНИЕ\nНЕ ВЛЕЗАЙ — УБЬЁТ", o + Vector3(-2.5, 2.3, -3.94), 50, Color(0.85, 0.08, 0.06))
	var cn := node(o + Vector3(2.6, 0, 2.2), 0.8)
	MGProps.carton(cn, Vector3(0.6, 0.4, 0.5), "ПРЕДОХРАНИТЕЛИ")
	var bk := node(o + Vector3(3.6, 0, 2.6))
	MGProps.cyl(bk, Vector3(0, 0.2, 0), 0.14, 0.14, 0.4, MGProps.mat("red"))
	_prop(PENDANT, o + Vector3(-2.05, 2.94, -1.36), 0.0, 0.59)
	_prop(TOOLBOX, o + Vector3(-3.4, 0.02, -1.1), -0.27, 0.90)
	_prop(SERVICE_DOOR, o + Vector3(-4.38, 0, 1.62), PI / 2, 0.91)
	_prop(UTILITY_BOX, o + Vector3(4.37, 1.40, -2.0), -PI / 2, 0.62)
	for x in [-3.16, -0.89, 1.40, 3.7]:
		MGProps.box(self, o + Vector3(x, 2.69, -3.42), Vector3(0.064, 0.37, 0.58), DARK_DADO)
	for k in 5:
		MGProps.box(self, o + Vector3(-3.24 + 0.33 * k, 0.006, -0.91), Vector3(0.22, 0.006, 0.075), MGProps.mat("brass"),
			Vector3(0, -0.48, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spot("power", o + Vector3(-2.05, 2.52, -1.36), o + Vector3(-2.51, 0.84, -2.41), 5.7, 46, 4.8, Color("#f0ca92"))
	_spot("power", o + Vector3(2.95, 2.62, -1.15), o + Vector3(2.10, 1.19, -3.83), 4.2, 43, 5.0, Color("#c9d1c0"))
	_omni("power", o + Vector3(-3.38, 1.01, 1.25), 0.18, 3.3, Color("#c5b28a"))
	_figure("power", o + Vector3(4.0, 0, -3.4), -0.6)
	cams["power"] = {"pos": o + Vector3(3.97, 2.66, 3.46), "look": o + Vector3(-0.76, 1.02, -2.52), "fov": 57.0, "sway": 2.2}
	spots["power"] = [_xf(o + Vector3(0.2, 0, -1.2), 0.3), _xf(o + Vector3(-1.4, 0, 1.0), 0.9), _xf(o + Vector3(2.5, 0, 0.6), -0.6)]

# ---------------- комната 9: стул, телевизор с помехами, красная лампа ----------------
func _room9(o: Vector3) -> void:
	_shell(o, Vector3(6, 2.8, 6), CONCRETE, LIME, RED_DADO)
	var ch := node(o + Vector3(0, 0, -0.5), PI)
	MGProps.chair(ch)
	var tv := node(o + Vector3(0, 0.5, -2.6))
	MGProps.box(tv, Vector3(0, -0.25, 0), Vector3(0.7, 0.5, 0.5), MGProps.mat("wood_dark"))
	var d := MGProps.crt(tv, Color(0.9, 0.9, 0.9), 3.0, 9.0)
	screens.append(d["screen"])
	# на полу — фотографии охранников, разложенные кругом
	for k in 8:
		var a := TAU * k / 8.0
		var ph := MGProps.box(self, o + Vector3(cos(a) * 1.3, 0.004, -0.5 + sin(a) * 1.3), Vector3(0.15, 0.003, 0.1), MGProps.mat("paper"), Vector3(0, a, 0))
		ph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	office.label("ТЫ ТОЖЕ ЗДЕСЬ БУДЕШЬ", o + Vector3(0, 2.2, -2.94), 50, Color(0.6, 0.0, 0.0))
	office.label("ОХРАННИК №7 · №8 · №9 · ТЫ", o + Vector3(-2.94, 1.5, 0), 36, Color(0.6, 0.0, 0.0), Vector3(0, PI / 2, 0))
	_prop(SERVICE_DOOR, o + Vector3(-2.86, 0, 1.22), PI / 2, 0.95)
	_prop(PENDANT, o + Vector3(0.20, 2.73, -0.68), 0.0, 0.64)
	MGProps.cable(self, o + Vector3(0.1, 0.15, -2.74), o + Vector3(2.84, 0.10, -2.86), 0.01, 0.014)
	MGProps.poster(node(o + Vector3(1.75, 1.50, -2.93)), "ОБЛАКО", "архив наблюдения", Color("#ad8758"), 0.54, 0.70)
	_spot("room9", o + Vector3(0.20, 2.23, -0.68), o + Vector3(0, 0, -0.5), 2.95, 39, 3.8, Color("#b09072"))
	_omni("room9", o + Vector3(0.1, 0.70, -2.33), 0.15, 2.2, Color("#aaa69a"))
	cams["room9"] = {"pos": o + Vector3(2.39, 2.46, 2.52), "look": o + Vector3(-0.26, 0.72, -0.98), "fov": 54.0, "sway": 0.0}
	spots["room9"] = [_xf(o + Vector3(0, 0, -0.5), 0.0)]
	spots["ghost_room9"] = [_xf(o + Vector3(-1.4, 0, -1.8), 0.4)]
	spots["ghost_arcade"] = [_xf(Vector3(85, 0, 0) + Vector3(5.2, 0, -3.6), -0.6)]

func tick(dt: float) -> void:
	t += dt
	hall_l.tick(dt)
	for i in blink.size():
		var led = blink[i]
		if led is StandardMaterial3D:
			(led as StandardMaterial3D).emission_energy_multiplier = 2.0 if fposmod(t * (1.3 + float(i % 5) * 0.7) + float(i) * 0.37, 1.0) < 0.6 else 0.25
	for i in screens.size():
		var s = screens[i]
		if s is ShaderMaterial:
			(s as ShaderMaterial).set_shader_parameter("energy", 1.1 + 0.4 * sin(t * (5.0 + i)) * randf())
		elif s is StandardMaterial3D:
			(s as StandardMaterial3D).emission_energy_multiplier = 0.9 + 0.5 * sin(t * (7.0 + i)) * randf()
	for g in gauges:
		(g as Node3D).rotation.z = sin(t * 1.3 + float(gauges.find(g))) * 0.6
	for i in balloons.size():
		var b := balloons[i] as Node3D
		b.position.y += sin(t * 0.8 + i) * 0.0006

## место врага в комнате (вариант позы)
func spot(id: String, variant: int) -> Transform3D:
	var arr: Array = spots.get(id, [])
	if arr.is_empty():
		return Transform3D(Basis(), Vector3(0, -50, 0))
	return arr[variant % arr.size()]
