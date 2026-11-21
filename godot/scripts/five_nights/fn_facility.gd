## Помещения «ОБЛАКО — ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ», которые видно на камерах: главный зал со сценой,
## игровая зона с автоматами, склад маскотов, серверная, узел вентиляции, комната питания, служебка (видна из правого
## коридора) и «комната 9», которой нет на плане. Коридоры 4 и 5 подходят к нишам редактируемой будки.
## Модели — MGModels: .glb владельца из godot/assets/minigames (tools/tripo-minigames.json), а пока его нет —
## собранные кодом (MGProps). У каждой комнаты свой свет, своя история в предметах, своя камера (точка, куда смотрит,
## размах поворота sway) и места для врагов. Для аномалий камер (FNAnomaly) комнаты отдают: свет (lights), силуэт в
## углу (figure), предметы, которые могут «переехать» (movable), головы, которые могут повернуться к камере (heads).
class_name FNFacility
extends Node3D

var office: FNOffice
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

func build(o: FNOffice) -> void:
	office = o
	_figure("office", Vector3(-0.45, 0, 1.25), PI)   # аномалия камеры за спиной охранника
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
		cams[id] = {"pos": Vector3(x - s * 0.3, 2.35, -9.5), "look": Vector3(x, 0.9, -1.0), "fov": 62.0, "sway": 4.0}
		spots[id] = [_xf(Vector3(x, 0, -4.6), 0.0), _xf(Vector3(x + s * 0.2, 0, -6.4), 0.0), _xf(Vector3(x, 0, -3.0), 0.0)]
		_hall(s, x, id)

func _xf(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)

func m(k: String) -> Material:
	return office.mats[k]

## модель в слот: .glb владельца или код
## Модели из файла в тёмных комнатах чуть светятся своим цветом — иначе на камере сливаются в пятно. Камера ночного
## видения сильно усиливает яркость, поэтому числа крошечные; чёрным стойкам подсветка не нужна (свет в проходе).
const GLB_LIFT := 0.012
const GLB_LIFT_BY := {"fn_mascot_shelf": 0.025, "fn_prize_counter": 0.02, "fn_generator": 0.02, "fn_server_rack": 0.0}

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

## коробка комнаты: пол, стены, потолок, плинтус, потолочные балки
func _shell(o: Vector3, size: Vector3, wall := "wall") -> void:
	office.box(o + Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.z), m("floor"), self)
	office.box(o + Vector3(0, size.y + 0.05, 0), Vector3(size.x, 0.1, size.z), m("black"), self)
	office.box(o + Vector3(0, size.y / 2, -size.z / 2), Vector3(size.x, size.y, 0.1), m(wall), self)
	office.box(o + Vector3(0, size.y / 2, size.z / 2), Vector3(size.x, size.y, 0.1), m(wall), self)
	office.box(o + Vector3(-size.x / 2, size.y / 2, 0), Vector3(0.1, size.y, size.z), m(wall), self)
	office.box(o + Vector3(size.x / 2, size.y / 2, 0), Vector3(0.1, size.y, size.z), m(wall), self)
	for z in [-size.z / 2 + 0.06, size.z / 2 - 0.06]:
		office.box(o + Vector3(0, 0.06, z), Vector3(size.x, 0.12, 0.03), m("black"), self)
	for x in [-size.x / 2 + 0.06, size.x / 2 - 0.06]:
		office.box(o + Vector3(x, 0.06, 0), Vector3(0.03, 0.12, size.z), m("black"), self)
	var k := -size.x / 2 + 1.5
	while k < size.x / 2 - 0.5:
		office.box(o + Vector3(k, size.y - 0.12, 0), Vector3(0.18, 0.24, size.z), m("shutter"), self)
		k += 3.0

func _omni(room: String, p: Vector3, e: float, r: float, c := Color(1, 0.92, 0.8)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	e *= 1.7                                # на камере (зелёный монохром) детали должны читаться
	l.light_energy = e
	l.omni_range = r
	l.light_color = c
	l.set_meta("base", e)
	l.set_meta("col", c)
	add_child(l)
	if room != "":
		if not lights.has(room):
			lights[room] = []
		(lights[room] as Array).append(l)
	return l

func _spot(room: String, p: Vector3, look: Vector3, e: float, angle: float, c := Color(1, 0.9, 0.8)) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = p
	l.look_at(look, Vector3.UP if absf((look - p).normalized().y) < 0.95 else Vector3.FORWARD)
	l.light_energy = e
	l.spot_angle = angle
	l.spot_range = (look - p).length() * 2.0
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

func _lamp_row(room: String, o: Vector3, y: float, xs: Array, c: Color) -> void:
	for x in xs:
		var n := node(o + Vector3(float(x), y, 0))
		var d := MGProps.strip_lamp(n, 1.2, c)
		blink.append(d["tube"])

# ---------------- коридоры у офиса: свет, кабели, двери, история ----------------
func _hall(s: float, x: float, id: String) -> void:
	# От поворота за нишей до CAM 4/5. Ближняя стена закрывает обзор за угол.
	var inner := s * (FNOffice.W + 0.85)
	office.box(Vector3(x, -0.05, -5.425), Vector3(1.3, 0.1, 8.75), m("floor"), self)
	office.box(Vector3(x, 2.55, -5.2), Vector3(1.3, 0.1, 9.2), m("black"), self)
	office.box(Vector3(inner, 1.25, -5.6), Vector3(0.1, 2.5, 8.4), m("wall"), self)
	office.box(Vector3(s * (FNOffice.W + 2.25), 1.25, -5.2), Vector3(0.1, 2.5, 9.2), m("wall"), self)
	office.box(Vector3(x, 1.25, -9.85), Vector3(1.3, 2.5, 0.1), m("wall"), self)
	var hall_lamp := OmniLight3D.new()
	hall_lamp.position = Vector3(x, 2.3, -6.0)
	hall_lamp.omni_range = 4.5
	hall_lamp.light_energy = 0.25
	hall_lamp.light_color = Color(0.75, 0.8, 0.7)
	add_child(hall_lamp)
	var wall_out := s * (FNOffice.W + 2.2)          # внешняя стена коридора (видна на камере)
	var face := -PI / 2 if s > 0 else PI / 2          # лицом в коридор
	for z in [-3.0, -7.0]:
		var n := node(Vector3(x, 2.5, z), PI / 2)
		var d := MGProps.strip_lamp(n, 1.0, Color(0.75, 0.85, 0.75))
		blink.append(d["tube"])
	# кабели вдоль стены под потолком
	for k in 3:
		MGProps.cable(self, Vector3(wall_out - s * 0.05, 2.35 - k * 0.04, -0.8), Vector3(wall_out - s * 0.05, 2.32 - k * 0.04, -9.6), 0.15 + k * 0.05, 0.012, MGProps.mat("rubber"))
	var p1 := node(Vector3(wall_out - s * 0.06, 1.5, -5.2), face)
	MGProps.poster(p1, "НЕ БЕГАТЬ" if s < 0 else "ДЕНЬ\nРОЖДЕНИЯ\nВ ОБЛАКЕ", "по коридору ходят только сотрудники" if s < 0 else "каждую субботу · аниматоры · торт", Color(0.75, 0.05, 0.05), 0.5, 0.7)
	if s < 0:
		# левый: стопка стульев, сдувшиеся шары, лужа
		for k in 3:
			var ch := node(Vector3(x + 0.3, 0.04 + k * 0.12, -8.2), 0.2 * k)
			MGProps.chair(ch)
		for k in 2:
			var b := MGProps.ball(self, Vector3(x - 0.35 + k * 0.2, 0.18, -6.0 - k * 0.3), 0.14, MGProps.mat("red") if k == 0 else MGProps.mat("cream"), Vector3(1, 0.6, 1))
			balloons.append(b)
		MGProps.box(self, Vector3(x, 0.002, -4.0), Vector3(0.7, 0.002, 0.5), MGProps.mat("glass"))
		var sign := node(Vector3(x - 0.2, 0, -3.6), 0.4)
		MGProps.box(sign, Vector3(0, 0.3, 0), Vector3(0.3, 0.6, 0.02), MGProps._yellow(), Vector3(-0.2, 0, 0))
		MGProps.text(sign, "МОКРЫЙ\nПОЛ", Vector3(0, 0.32, 0.02), 30, Color(0.1, 0.1, 0.1))
	else:
		# правый: дверь служебки приоткрыта, за ней — тележка уборщика и шкафчики (служебные помещения)
		var dz := -6.6
		office.box(Vector3(wall_out, 1.05, dz), Vector3(0.12, 2.1, 0.95), m("black"), self)      # проём
		var door := node(Vector3(wall_out - s * 0.05, 0, dz - 0.45), 0.0)
		MGProps.box(door, Vector3(0, 1.05, 0.46), Vector3(0.05, 2.05, 0.9), MGProps.mat("blue_paint"))
		door.rotation.y = 0.55
		MGProps.text(node(Vector3(wall_out - s * 0.07, 2.25, dz), face), "СЛУЖЕБНОЕ", Vector3.ZERO, 40, Color(0.9, 0.88, 0.8))
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
	_shell(o, Vector3(14, 4.2, 12))
	office.box(o + Vector3(0, 0.45, -4.4), Vector3(8, 0.9, 3.0), MGProps.mat("wood_dark"), self)   # сцена
	office.box(o + Vector3(0, 0.92, -2.9), Vector3(8, 0.06, 0.08), m("red"), self)
	for k in 7:
		var lamp := MGProps.glow(Color(1.0, 0.8, 0.4), 1.4)
		MGProps.ball(self, o + Vector3(-3.6 + k * 1.2, 0.93, -2.86), 0.04, lamp)
		blink.append(lamp)
	for side in [-1.0, 1.0]:
		var cn := node(o + Vector3(side * 3.8, 0, -5.2))
		MGProps.curtain(cn, 1.8, 4.0)
		var sp := put("fn_stage_speaker", o + Vector3(side * 3.4, 0.9, -3.4), -side * 0.3, Vector3(0.8, 1.7, 0.85), func(r): MGProps.speaker(r))
		sp.scale = Vector3.ONE * 0.9
	office.box(o + Vector3(0, 3.9, -5.4), Vector3(9.6, 0.5, 0.2), m("red"), self)
	office.label("ОБЛАКО", o + Vector3(0, 3.35, -5.85), 260, Color(0.85, 0.08, 0.06))
	office.label("ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ", o + Vector3(0, 2.75, -5.85), 70, Color(0.85, 0.82, 0.76))
	# микрофон на стойке в центре сцены
	var mic := node(o + Vector3(0.6, 0.9, -3.6))
	MGProps.cyl(mic, Vector3(0, 0.75, 0), 0.01, 0.01, 1.5, MGProps.mat("steel"))
	MGProps.cyl(mic, Vector3(0, 0.02, 0), 0.15, 0.15, 0.03, MGProps.mat("black"))
	MGProps.caps(mic, Vector3(0, 1.55, 0.04), 0.03, 0.14, MGProps.mat("black"), Vector3(0.4, 0, 0))
	MGProps.cable(self, o + Vector3(0.6, 1.0, -3.6), o + Vector3(1.6, 0.92, -4.6), 0.05, 0.008)
	for i in 4:
		var p := o + Vector3(-3.0 + float(i % 2) * 6.0, 0, 0.8 + float(i / 2) * 3.4)
		# высота слота — с шарами над столом: столешница модели приходится на ~0,75 м
		var tb := put("fn_party_table", p, float(i) * 0.15 - 0.2 + (PI if i % 2 == 1 else 0.0), Vector3(2.0, 1.4, 1.1), func(r): MGProps.party_table(r, i))
		for c in tb.get_children():
			if c.has_meta("balloon"):
				balloons.append(c)
	# гирлянда флажков через зал
	var gl := PackedVector3Array()
	for k in 9:
		var tt := float(k) / 8.0
		gl.append(o + Vector3(-6.5 + tt * 13.0, 3.6 - sin(tt * PI) * 0.6, 1.5))
	MGProps.tube(self, gl, 0.006, MGProps.mat("rubber"))
	for k in 16:
		var tt := float(k + 0.5) / 16.0
		MGProps.box(self, o + Vector3(-6.5 + tt * 13.0, 3.48 - sin(tt * PI) * 0.6, 1.5), Vector3(0.18, 0.22, 0.005), MGProps.mat("red") if k % 2 == 0 else MGProps.mat("paper"), Vector3(0, 0, PI / 4))
	office.label("СОТРУДНИК МЕСЯЦА", o + Vector3(6.94, 2.6, -2.0), 60, Color(0.2, 0.2, 0.2), Vector3(0, -PI / 2, 0))
	var ps := node(o + Vector3(6.93, 1.8, -2.0), -PI / 2)
	MGProps.poster(ps, "БАЛОН", "работает без выходных · всегда улыбается", Color(0.75, 0.05, 0.05), 0.7, 0.9)
	MGProps.litter(node(o + Vector3(0, 0, 2.2)), 12, 4.5, 1)
	_spot("stage", o + Vector3(0, 4.0, 1.0), o + Vector3(0, 0.9, -4.4), 3.5, 28.0, Color(1.0, 0.35, 0.3))
	_omni("stage", o + Vector3(-4, 3.8, 3), 0.35, 7.0)
	_omni("stage", o + Vector3(4, 3.8, 3), 0.25, 7.0)
	_figure("stage", o + Vector3(-6.2, 0, -5.2), 0.6)
	cams["stage"] = {"pos": o + Vector3(6.4, 3.9, 5.4), "look": o + Vector3(-0.5, 1.0, -3.0), "fov": 64.0, "sway": 7.0}
	spots["stage"] = [_xf(o + Vector3(0, 0.9, -4.3), 0.0), _xf(o + Vector3(-2.2, 0.9, -4.6), 0.3), _xf(o + Vector3(1.8, 0, 2.2), -0.6)]

# ---------------- игровая зона: автоматы, призы, ковёр ----------------
func _arcade(o: Vector3) -> void:
	_shell(o, Vector3(12, 3.4, 10))
	# ковёр с космическим узором — тёмно-синий с красными пятнами
	var rug := MGProps.box(self, o + Vector3(-0.5, 0.004, 0.4), Vector3(9.0, 0.008, 7.0), MGProps.mat("blue_paint"))
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var names := ["VOZDUH RUN", "BALON FIGHTER", "ТЯГА 812", "MADK SKATE", "ОБЛАКО", "BOT WARS"]
	var cols := [Color(0.9, 0.2, 0.2), Color(0.3, 0.6, 1.0), Color(0.9, 0.9, 0.9), Color(0.95, 0.6, 0.15), Color(0.6, 0.3, 1.0), Color(0.2, 1.0, 0.5)]
	for i in 6:
		var p := o + Vector3(-4.0 + float(i % 3) * 2.4, 0, -3.0 + float(i / 3) * 4.2)
		var yaw := 0.0 if i < 3 else PI
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
		MGProps.cable(self, o + Vector3(-4.0 + float(k % 3) * 2.4, 0.05, -3.4 + float(k / 3) * 4.6 + (0.4 if k >= 3 else -0.4)), o + Vector3(-5.9, 0.02, -3.0 + k * 0.8), 0.0, 0.015)
	MGProps.litter(node(o + Vector3(0, 0, 0.5)), 10, 4.0, 2)
	for k in 3:
		var tk := MGProps.box(self, o + Vector3(-1.0 + k * 0.4, 0.01, 1.2 + k * 0.3), Vector3(0.25, 0.004, 0.08), MGProps.mat("red"), Vector3(0, k, 0))
		tk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni("arcade", o + Vector3(0, 3.1, 0), 0.45, 8.0, Color(0.8, 0.85, 1.0))
	_omni("arcade", o + Vector3(4.0, 2.8, 2.0), 0.25, 4.0, Color(1.0, 0.5, 0.4))
	_figure("arcade", o + Vector3(-5.4, 0, -4.2), 0.5)
	cams["arcade"] = {"pos": o + Vector3(-5.5, 3.1, 4.4), "look": o + Vector3(0.5, 0.9, -1.0), "fov": 66.0, "sway": 6.0}
	spots["arcade"] = [_xf(o + Vector3(-1.6, 0, -1.0), 0.6), _xf(o + Vector3(0.8, 0, 3.0), 2.6), _xf(o + Vector3(3.6, 0, -0.6), -1.4)]

# ---------------- склад маскотов: стеллажи с головами, коробки, висящий костюм ----------------
func _storage(o: Vector3) -> void:
	_shell(o, Vector3(10, 3.2, 9))
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 110
	var labels := ["КОСТЮМЫ", "ГОЛОВЫ", "НЕ ТРОГАТЬ", "БАЛОН — ЗАПЧАСТИ", "", "ГЛАЗА", "", "ВОЗВРАТ"]
	for i in 8:
		var bx := node(o + Vector3(rng.randf_range(-4, 3), 0, rng.randf_range(-1, 3.5)), rng.randf_range(0, 1))
		MGProps.carton(bx, Vector3(rng.randf_range(0.5, 0.8), rng.randf_range(0.35, 0.6), rng.randf_range(0.4, 0.6)), labels[i])
		if i % 3 == 0:
			var top := node(Vector3(0, 0.6, 0), 0.3, bx)
			MGProps.carton(top, Vector3(0.4, 0.3, 0.35), "")
	# висящий костюм Балона на крюке и ещё одна голова на полу — лицом к камере
	var hang := node(o + Vector3(3.6, 0, 1.5))
	MGProps.cyl(hang, Vector3(0, 3.0, 0), 0.01, 0.01, 0.5, MGProps.mat("steel"))
	MGProps.caps(hang, Vector3(0, 2.0, 0), 0.35, 1.3, MGProps.mat("fabric_red"))
	for sx in [-0.42, 0.42]:
		MGProps.caps(hang, Vector3(sx, 1.85, 0), 0.1, 0.9, MGProps.mat("fabric_red"), Vector3(0, 0, sx * 0.3))
	(heads["storage"] as Array).append(_loose_head(o + Vector3(2.4, 0.26, 2.6), 2.4, "cream"))
	_omni("storage", o + Vector3(-1, 2.9, 1), 0.45, 7.0, Color(1.0, 0.85, 0.65))
	_omni("storage", o + Vector3(-1.5, 2.6, -2.6), 0.3, 4.0, Color(0.9, 0.8, 0.7))     # подсветка стеллажей с головами
	var bare := node(o + Vector3(1.5, 3.2, -1.0))
	var bl := MGProps.ceiling_lamp(bare, Color(1.0, 0.8, 0.55))
	blink.append(bl["bulb"])
	_figure("storage", o + Vector3(-4.4, 0, 3.6), 2.2)
	cams["storage"] = {"pos": o + Vector3(4.4, 2.9, 4.0), "look": o + Vector3(-1.0, 0.8, -1.5), "fov": 64.0, "sway": 5.0}
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
	_shell(o, Vector3(10, 3.0, 9), "black")
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
		var z := -2.0 + float(k / 4) * 3.8
		MGProps.cable(self, o + Vector3(x, 2.58, -0.1), o + Vector3(x + 0.15, 2.1, z), 0.1, 0.02, MGProps.mat("red_dark") if k % 2 else MGProps.mat("blue_paint"))
	var term := node(o + Vector3(4.2, 0, 1.6), -PI / 2)
	MGProps.box(term, Vector3(0, 0.38, 0), Vector3(0.9, 0.04, 0.5), MGProps.mat("metal"))
	var cr := node(Vector3(0, 0.4, -0.05), 0.0, term)
	var d2 := MGProps.crt(cr, Color(0.4, 1.0, 0.5), 1.0, 6.0)
	screens.append(d2["screen"])
	office.label("СЕРВЕР 06 — ОБЛАКО ХРАНИТ ВСЁ", o + Vector3(0, 2.5, -4.44), 60, Color(0.8, 0.1, 0.1))
	office.label("ОРИГИНАЛЫ НЕ УДАЛЯТЬ", o + Vector3(-4.94, 1.6, 0), 40, Color(0.7, 0.7, 0.7), Vector3(0, PI / 2, 0))
	_omni("server", o + Vector3(0, 2.7, 0), 0.22, 6.0, Color(0.55, 0.75, 1.0))
	if MGModels.has("fn_server_rack"):
		# чёрные стойки из файла на чёрных стенах: холодный свет в проходе между рядами ложится на их лица
		for sx in [-2.2, 2.2]:
			_omni("server", o + Vector3(sx, 1.5, -0.1), 0.45, 3.6, Color(0.6, 0.8, 1.0))
	_lamp_row("server", o + Vector3(0, 0, 1.0), 2.95, [-3.0, 0.0, 3.0], Color(0.6, 0.8, 1.0))
	_figure("server", o + Vector3(-4.3, 0, 3.8), 2.4)
	cams["server"] = {"pos": o + Vector3(4.4, 2.7, 3.8), "look": o + Vector3(-1.0, 0.9, -0.5), "fov": 64.0, "sway": 5.0}
	spots["server"] = [_xf(o + Vector3(0, 0, 0.0), -0.9), _xf(o + Vector3(-2.0, 0, 0.0), 0.5), _xf(o + Vector3(2.0, 0, 3.2), 2.8)]

# ---------------- узел вентиляции: жестяной короб, развилка налево и вверх ----------------
func _vent(o: Vector3) -> void:
	_shell(o, Vector3(4, 1.4, 8), "shutter")
	office.box(o + Vector3(-1.4, 0.7, -2.6), Vector3(1.2, 1.2, 0.05), m("black"), self)      # проём левой шахты
	office.box(o + Vector3(0.6, 1.38, -1.0), Vector3(1.0, 0.05, 1.0), m("black"), self)      # проём вверх
	office.label("← ЛЕВАЯ", o + Vector3(-1.4, 1.2, -2.55), 40, Color(0.75, 0.1, 0.1))
	office.label("ВВЕРХ ↑", o + Vector3(0.6, 1.2, -2.0), 40, Color(0.75, 0.1, 0.1))
	for k in 6:
		office.box(o + Vector3(0, 0.0, -3.4 + k * 1.3), Vector3(4, 0.02, 0.06), m("metal"), self)
		office.box(o + Vector3(-1.95, 0.7, -3.4 + k * 1.3), Vector3(0.04, 1.4, 0.06), m("metal"), self)
		office.box(o + Vector3(1.95, 0.7, -3.4 + k * 1.3), Vector3(0.04, 1.4, 0.06), m("metal"), self)
	# следы в пыли, клочья ткани, оторванная решётка
	for k in 7:
		var fp := MGProps.box(self, o + Vector3(-0.3 + (k % 2) * 0.3, 0.012, 1.8 - k * 0.6), Vector3(0.14, 0.004, 0.24), MGProps.mat("black"), Vector3(0, 0.1 * (k % 2), 0))
		fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gr := node(o + Vector3(1.1, 0.06, 1.2), 0.5)
	gr.rotation.x = -PI / 2
	MGProps.vent_grill(gr, 0.7, 0.5)
	MGProps.box(self, o + Vector3(-0.9, 0.03, -1.6), Vector3(0.2, 0.05, 0.12), MGProps.mat("fabric_red"), Vector3(0, 0.5, 0.2))
	office.label("НЕ ЗАЛЕЗАТЬ", o + Vector3(1.94, 0.9, 0.5), 32, Color(0.85, 0.8, 0.7), Vector3(0, -PI / 2, 0))
	_omni("vent", o + Vector3(0, 1.2, 2.5), 0.4, 4.0, Color(0.7, 0.8, 0.7))
	cams["vent"] = {"pos": o + Vector3(0.6, 1.2, 3.6), "look": o + Vector3(-0.3, 0.3, -2.0), "fov": 70.0, "sway": 0.0}
	spots["vent"] = [_xf(o + Vector3(-0.2, 0.25, -0.5), 0.0)]
	spots["ghost_vent"] = [_xf(o + Vector3(1.2, 0.0, -2.8), 0.2)]

# ---------------- комната питания: генератор, щиты, трубы ----------------
func _power(o: Vector3) -> void:
	_shell(o, Vector3(9, 3.0, 8))
	var g := put("fn_generator", o + Vector3(-2.5, 0, -2.4), 0.0, Vector3(1.4, 1.3, 0.9), func(r):
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
	_omni("power", o + Vector3(0, 2.7, 0), 0.3, 6.0, Color(1.0, 0.75, 0.5))
	var bare := node(o + Vector3(-1.0, 3.0, 0.5))
	var bl := MGProps.ceiling_lamp(bare, Color(1.0, 0.7, 0.4))
	blink.append(bl["bulb"])
	_figure("power", o + Vector3(4.0, 0, -3.4), -0.6)
	cams["power"] = {"pos": o + Vector3(3.8, 2.7, 3.4), "look": o + Vector3(-0.5, 0.9, -1.5), "fov": 64.0, "sway": 5.0}
	spots["power"] = [_xf(o + Vector3(0.2, 0, -1.2), 0.3), _xf(o + Vector3(-1.4, 0, 1.0), 0.9), _xf(o + Vector3(2.5, 0, 0.6), -0.6)]

# ---------------- комната 9: стул, телевизор с помехами, красная лампа ----------------
func _room9(o: Vector3) -> void:
	_shell(o, Vector3(6, 2.8, 6))
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
	_omni("room9", o + Vector3(0, 2.5, 0), 0.6, 5.0, Color(1.0, 0.1, 0.08))
	cams["room9"] = {"pos": o + Vector3(2.4, 2.5, 2.4), "look": o + Vector3(0, 0.6, -0.8), "fov": 60.0, "sway": 0.0}
	spots["room9"] = [_xf(o + Vector3(0, 0, -0.5), 0.0)]
	spots["ghost_room9"] = [_xf(o + Vector3(-1.4, 0, -1.8), 0.4)]
	spots["ghost_arcade"] = [_xf(Vector3(85, 0, 0) + Vector3(5.2, 0, -3.6), -0.6)]

func tick(dt: float) -> void:
	t += dt
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
