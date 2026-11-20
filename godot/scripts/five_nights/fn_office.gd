## Охранная будка «5 НОЧЕЙ С ПАХАНОМ»: вид от первого лица, всё строится кодом.
## Перед Паханом — стол с ЭЛТ-монитором, пульт (заслонки, СБРОС), телефон, кружка «ПАХАН», холодная шаурма,
## инструкции и фото на стене. Слева и справа — проёмы с тяжёлыми ставнями (кнопки ДВЕРЬ и СВЕТ, лампа-индикатор),
## за проёмом — ниша коридора, видная только в свете фонаря. Слева внизу — решётка вентиляции, над столом — люк.
## Лампа под потолком мигает. Редкие перемены в комнате (фото, надпись, предмет, приоткрытая дверь кладовки)
## включает FNHorror. Логику не решает — читает FNNight.
class_name FNOffice
extends Node3D

const EYE := Vector3(0.0, 1.32, 0.62)
const YAW_MAX := deg_to_rad(64.0)
const W := 2.2                     # полуширина комнаты
const DOOR_Z := -0.4               # центр проёмов
const DOOR_W := 1.1
const DOOR_H := 2.15

var cam: Camera3D
var yaw := 0.0                     # −1 налево .. +1 направо (как в FNNight)
var yaw_v := 0.0
var shake := 0.0
var font: Font
var mats := {}
var doors := {}                    # "l"/"r" → MeshInstance3D ставни
var door_y := {"l": 1.0, "r": 1.0} # 1 — поднята (открыта), 0 — опущена
var leds := {}                     # "door_l", "door_r", "seal_l", "seal_t", "ping" → MeshInstance3D
var lights := {}                   # "l"/"r" → SpotLight3D фонаря коридора
var lamp: OmniLight3D
var lamp_base := 0.9
var flick_t := 0.0
var glow: OmniLight3D              # свет от монитора
var screen: MeshInstance3D
var screen_mat: StandardMaterial3D
var grate: Node3D                  # решётка вентиляции слева внизу
var hatch: Node3D                  # люк над столом
var grate_eyes: Node3D
var buttons := {}                  # id → {node, r}
var photo: MeshInstance3D
var photo_tex := {}
var writing: Label3D
var closet: Node3D
var extra_item: Node3D
var reflection: MeshInstance3D
var dark_eyes: Node3D
var scare_light: OmniLight3D       # свет у лица Пахана — только в скримере: высвечивает морду врага
var t := 0.0
var power_on := true
var desk_model: Node3D = null     # пульт охранника из файла (fn_security_desk.glb); null — стол собран кодом
const DESK_K := 1.78               # ширина модели пульта в метрах (1 «единица модели»)
const DESK_Z := -1.05              # где стоит центр модели

func build() -> void:
	font = load("res://assets/fonts/RussoOne-Regular.ttf")
	_mats()
	_room()
	_desk()
	_doors()
	_vents()
	_decor()
	scare_light = OmniLight3D.new()
	scare_light.position = EYE + Vector3(0.0, -0.25, -0.15)
	scare_light.omni_range = 3.2
	scare_light.light_energy = 0.0
	scare_light.shadow_enabled = false
	add_child(scare_light)
	cam = Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.03
	cam.far = 220.0
	cam.position = EYE
	add_child(cam)
	cam.current = true

# ---------------- материалы: грязно-белое, чёрное, красное ----------------
func _mats() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	noise.fractal_octaves = 5
	var grime := NoiseTexture2D.new()
	grime.noise = noise
	grime.width = 256
	grime.height = 256
	grime.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.36, 0.33, 0.29))
	grad.set_color(1, Color(0.78, 0.76, 0.7))
	grime.color_ramp = grad
	mats["wall"] = _m(Color(1, 1, 1), 0.95, grime, Vector3(3, 2, 1))
	var n2 := FastNoiseLite.new()
	n2.frequency = 0.12
	var dirt := NoiseTexture2D.new()
	dirt.noise = n2
	dirt.seamless = true
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.05, 0.05, 0.05))
	g2.set_color(1, Color(0.22, 0.21, 0.2))
	dirt.color_ramp = g2
	mats["floor"] = _m(Color(1, 1, 1), 0.85, dirt, Vector3(4, 4, 1))
	mats["black"] = _m(Color(0.04, 0.04, 0.045), 0.6)
	mats["metal"] = _m(Color(0.32, 0.33, 0.34), 0.45, null, Vector3.ONE, 0.6)
	mats["shutter"] = _m(Color(0.2, 0.21, 0.22), 0.5, grime, Vector3(1, 3, 1), 0.5)
	mats["red"] = _m(Color(0.72, 0.05, 0.05), 0.6)
	mats["desk"] = _m(Color(0.18, 0.15, 0.13), 0.8, grime, Vector3(2, 1, 1))
	mats["paper"] = _m(Color(0.86, 0.84, 0.78), 0.95)
	mats["plastic"] = _m(Color(0.62, 0.6, 0.55), 0.7)
	mats["red_led"] = _glow(Color(1.0, 0.08, 0.05), 3.0)
	mats["green_led"] = _glow(Color(0.25, 1.0, 0.35), 2.2)
	mats["off_led"] = _m(Color(0.08, 0.06, 0.06), 0.4)
	mats["eye"] = _glow(Color(1.0, 0.92, 0.85), 6.0)
	mats["eye_red"] = _glow(Color(1.0, 0.1, 0.06), 7.0)

func _m(c: Color, rough: float, tex: Texture2D = null, uv := Vector3.ONE, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.uv1_triplanar = true
	return m

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(p: Vector3, s: Vector3, m: Material, parent: Node = self, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func label(text: String, p: Vector3, size: int, col: Color, rot := Vector3.ZERO, parent: Node = self, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.0012
	l.modulate = col
	l.outline_size = 0
	l.position = p
	l.rotation = rot
	l.double_sided = false
	l.shaded = true
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width
	parent.add_child(l)
	return l

# ---------------- комната и ниши коридоров ----------------
func _room() -> void:
	var H := 2.7
	box(Vector3(0, -0.05, 0), Vector3(W * 2 + 0.4, 0.1, 3.6), mats["floor"])
	box(Vector3(0, H + 0.05, 0), Vector3(W * 2 + 0.4, 0.1, 3.6), mats["black"])
	box(Vector3(0, H / 2, -1.75), Vector3(W * 2, H, 0.1), mats["wall"])          # передняя
	box(Vector3(0, H / 2, 1.65), Vector3(W * 2, H, 0.1), mats["wall"])           # задняя
	for s in [-1.0, 1.0]:
		var x: float = s * (W + 0.05)
		# стена с проёмом: перед проёмом, за ним, над ним
		var z0 := DOOR_Z - DOOR_W / 2
		var z1 := DOOR_Z + DOOR_W / 2
		box(Vector3(x, H / 2, (-1.75 + z0) / 2), Vector3(0.1, H, z0 + 1.75), mats["wall"])
		box(Vector3(x, H / 2, (z1 + 1.65) / 2), Vector3(0.1, H, 1.65 - z1), mats["wall"])
		box(Vector3(x, (DOOR_H + H) / 2, DOOR_Z), Vector3(0.1, H - DOOR_H, DOOR_W), mats["wall"])
		# красная полоса по стене на уровне пояса — акцент
		box(Vector3(x - s * 0.06, 1.0, (z1 + 1.65) / 2), Vector3(0.02, 0.06, 1.65 - z1), mats["red"])
		# рама проёма
		box(Vector3(x - s * 0.07, DOOR_H + 0.05, DOOR_Z), Vector3(0.06, 0.1, DOOR_W + 0.16), mats["black"])
		for zz in [z0 - 0.05, z1 + 0.05]:
			box(Vector3(x - s * 0.07, DOOR_H / 2, zz), Vector3(0.06, DOOR_H, 0.1), mats["black"])
		# ниша за проёмом: пол, потолок, стены; дальше поворот коридора (в темноту)
		var nx: float = s * (W + 1.1)
		box(Vector3(nx, -0.05, DOOR_Z), Vector3(2.0, 0.1, DOOR_W + 0.2), mats["floor"])
		box(Vector3(nx, DOOR_H + 0.3, DOOR_Z), Vector3(2.0, 0.1, DOOR_W + 0.2), mats["black"])
		box(Vector3(nx, DOOR_H / 2 + 0.15, z1 + 0.1), Vector3(2.0, DOOR_H + 0.3, 0.1), mats["wall"])
		box(Vector3(s * (W + 2.15), DOOR_H / 2 + 0.15, DOOR_Z), Vector3(0.1, DOOR_H + 0.3, DOOR_W + 0.2), mats["wall"])
		box(Vector3(s * (W + 0.42), DOOR_H / 2 + 0.15, z0 - 0.1), Vector3(0.85, DOOR_H + 0.3, 0.1), mats["wall"])    # ниша закрыта со стороны стола
		# сам коридор уходит от ниши вглубь (−Z) — его видно на камере 4/5, а нишу нет
		var cx: float = s * (W + 1.55)
		box(Vector3(cx, -0.05, -5.2), Vector3(1.3, 0.1, 9.2), mats["floor"])
		box(Vector3(cx, 2.55, -5.2), Vector3(1.3, 0.1, 9.2), mats["black"])
		box(Vector3(s * (W + 0.85), 1.25, -5.6), Vector3(0.1, 2.5, 8.4), mats["wall"])   # ближняя к офису стена — скрывает нишу
		box(Vector3(s * (W + 2.25), 1.25, -5.2), Vector3(0.1, 2.5, 9.2), mats["wall"])
		box(Vector3(cx, 1.25, -9.85), Vector3(1.3, 2.5, 0.1), mats["wall"])
		# фонарь коридора: висит в проёме, светит в нишу
		var sp := SpotLight3D.new()
		sp.position = Vector3(s * (W + 0.15), DOOR_H - 0.1, DOOR_Z)
		sp.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(90.0) * s, 0.0)
		sp.spot_angle = 55.0
		sp.spot_range = 5.0
		sp.light_energy = 0.0
		sp.light_color = Color(1.0, 0.93, 0.8)
		sp.shadow_enabled = true
		add_child(sp)
		lights["l" if s < 0 else "r"] = sp
		# лампочка в коридоре: еле живая
		var cl := OmniLight3D.new()
		cl.position = Vector3(cx, 2.3, -6.0)
		cl.omni_range = 4.5
		cl.light_energy = 0.25
		cl.light_color = Color(0.75, 0.8, 0.7)
		add_child(cl)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 2.45, -0.1)
	lamp.omni_range = 5.5
	lamp.light_energy = lamp_base
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.shadow_enabled = true
	add_child(lamp)
	var shade := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.22
	cyl.height = 0.16
	shade.mesh = cyl
	shade.material_override = mats["metal"]
	shade.position = Vector3(0, 2.55, -0.1)
	add_child(shade)
	box(Vector3(0, 2.5, -0.1), Vector3(0.06, 0.06, 0.06), _glow(Color(1, 0.9, 0.7), 4.0))

# ---------------- стол, монитор, пульт ----------------
func _desk() -> void:
	if MGModels.has("fn_security_desk"):
		_desk_model()
	else:
		_desk_code()
	# отражение в выключенном экране — фигура за спиной (событие)
	reflection = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.26)
	reflection.mesh = q
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0, 0, 0, 0.8)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reflection.material_override = rm
	reflection.position = screen.position + Vector3(0.14, 0, 0.008)
	reflection.visible = false
	add_child(reflection)
	# пульт на столе: заслонки и СБРОС (у модели из файла — перед клавиатурой, по центру)
	var po := Vector3(0.77, -0.027, -0.04) if desk_model != null else Vector3.ZERO
	var panel := box(Vector3(-0.72, 0.84, -0.78) + po, Vector3(0.6, 0.06, 0.28), mats["black"])
	panel.rotation.x = deg_to_rad(-12.0)
	_button("seal_l", Vector3(-0.88, 0.885, -0.75) + po, mats["metal"], 0.06, "ВЕНТ. Z")
	_button("seal_t", Vector3(-0.68, 0.885, -0.75) + po, mats["metal"], 0.06, "ЛЮК X")
	_button("reset", Vector3(-0.48, 0.885, -0.75) + po, mats["red"], 0.06, "СБРОС R")
	_led("seal_l", Vector3(-0.88, 0.88, -0.86) + po)
	_led("seal_t", Vector3(-0.68, 0.88, -0.86) + po)
	_led("ping", Vector3(-0.48, 0.88, -0.86) + po)
	label("СЕРВЕР", Vector3(-0.48, 0.883, -0.9) + po, 18, Color(0.8, 0.2, 0.2), Vector3(deg_to_rad(-90), 0, 0))
	# инструкция на стене
	var note := box(Vector3(-0.85, 1.55, -1.69), Vector3(0.42, 0.56, 0.01), mats["paper"])
	label("ИНСТРУКЦИЯ ОХРАННИКА\n\n1. Смотреть камеры до 6:00\n2. Не открывать незнакомым\n3. Из вентиляции зовут — не отвечать\n\nНЕ КОРМИТЬ BOT ПОСЛЕ 22:00", Vector3(-0.85, 1.55, -1.683), 15, Color(0.08, 0.08, 0.08), Vector3.ZERO, self, 330)
	note.rotation.z = 0.03

## стол, собранный кодом: столешница, ЭЛТ-монитор, клавиатура, телефон, кружка, шаурма, бумаги
func _desk_code() -> void:
	box(Vector3(0, 0.78, -0.95), Vector3(2.4, 0.06, 0.85), mats["desk"])
	for x in [-1.1, 1.1]:
		box(Vector3(x, 0.38, -0.95), Vector3(0.08, 0.76, 0.8), mats["black"])
	# ЭЛТ-монитор
	box(Vector3(0, 1.08, -1.15), Vector3(0.66, 0.54, 0.6), mats["plastic"])
	box(Vector3(0, 1.08, -1.48), Vector3(0.48, 0.42, 0.2), mats["plastic"])
	_screen(Vector3(0, 1.1, -0.848), Vector2(0.54, 0.4), Vector3(0, 1.1, -0.6))
	label("CAM", Vector3(-0.22, 0.86, -0.842), 26, Color(0.7, 0.68, 0.6))
	# клавиатура, телефон, кружка, шаурма, бумаги
	box(Vector3(0, 0.83, -0.72), Vector3(0.48, 0.03, 0.16), mats["plastic"])
	var phone := box(Vector3(0.72, 0.86, -0.8), Vector3(0.24, 0.08, 0.18), mats["black"])
	box(Vector3(0.72, 0.92, -0.8), Vector3(0.26, 0.05, 0.07), mats["black"], self, Vector3(0, 0, 0.1))
	buttons["phone"] = {"node": phone, "r": 0.09}
	var mug := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.045
	mc.bottom_radius = 0.042
	mc.height = 0.11
	mug.mesh = mc
	mug.material_override = mats["paper"]
	mug.position = Vector3(0.38, 0.865, -0.7)
	add_child(mug)
	label("ПАХАН", Vector3(0.38, 0.87, -0.654), 22, Color(0.75, 0.05, 0.05))
	# холодная шаурма в фольге
	var sh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.04
	cap.height = 0.22
	sh.mesh = cap
	sh.material_override = _m(Color(0.75, 0.74, 0.72), 0.35, null, Vector3.ONE, 0.8)
	sh.rotation = Vector3(0, deg_to_rad(70), deg_to_rad(90))
	sh.position = Vector3(0.95, 0.85, -1.05)
	add_child(sh)
	box(Vector3(0.95, 0.885, -1.05), Vector3(0.05, 0.02, 0.08), _m(Color(0.6, 0.35, 0.2), 0.9), self, Vector3(0, deg_to_rad(70), 0))
	for k in 4:
		box(Vector3(-0.15 + k * 0.03, 0.812 + k * 0.002, -1.32 + k * 0.01), Vector3(0.21, 0.002, 0.29), mats["paper"], self, Vector3(0, k * 0.15, 0))

## пульт охранника из файла (fn_security_desk.glb): стол с двумя ЭЛТ, вентилятором, телефонами и клавиатурой —
## одной моделью. Рабочее остаётся рабочим: экран камер светится поверх стекла большого монитора, красный телефон
## нажимается (сброс звонка), пульт заслонок стоит перед клавиатурой. Разметка — в единицах модели (ширина = 1):
## столешница y 0,44; экран большого монитора — центр (−0,027; 0,727), 0,28 × 0,22, стекло на z −0,09;
## красный телефон (0,375; 0,48; 0,0).
func _desk_model() -> void:
	desk_model = MGModels.spawn("fn_security_desk", self, Vector3(0, 0, DESK_Z), 0.0, Vector3(DESK_K, 0.8706 * DESK_K, 1.3), func(_r): pass)
	_screen(du(Vector3(-0.027, 0.727, -0.094)), Vector2(0.272, 0.212) * DESK_K, du(Vector3(-0.027, 0.727, 0.06)))
	var phone := Node3D.new()                       # красный телефон модели: невидимая точка нажатия
	phone.position = du(Vector3(0.375, 0.47, 0.0))
	add_child(phone)
	buttons["phone"] = {"node": phone, "r": 0.1}

## точка на модели пульта: единицы модели → координаты будки
func du(u: Vector3) -> Vector3:
	return Vector3(u.x * DESK_K, u.y * DESK_K, DESK_Z + u.z * DESK_K)

## экран камер: светится слабее, пока планшет опущен, и ярче — когда поднят (tick); рядом — его свет
func _screen(p: Vector3, size: Vector2, light_p: Vector3) -> void:
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.03, 0.05, 0.04)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.2, 0.42, 0.3)
	screen_mat.emission_energy_multiplier = 0.25
	screen_mat.roughness = 0.15
	screen = box(p, Vector3(size.x, size.y, 0.01), screen_mat)
	glow = OmniLight3D.new()
	glow.position = light_p
	glow.omni_range = 1.8
	glow.light_energy = 0.35
	glow.light_color = Color(0.5, 0.9, 0.65)
	add_child(glow)

func _button(id: String, p: Vector3, m: Material, r: float, text := "", parent: Node = self) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r * 0.55
	c.bottom_radius = r * 0.6
	c.height = 0.03
	b.mesh = c
	b.material_override = m
	b.position = p
	parent.add_child(b)
	buttons[id] = {"node": b, "r": r}
	if text != "":
		var bl := label(text, p + Vector3(0, 0.02, 0.062), 22, Color(0.96, 0.94, 0.88), Vector3(deg_to_rad(-90), 0, 0))
		bl.outline_size = 6
		bl.outline_modulate = Color(0, 0, 0, 0.9)
	return b

func _led(id: String, p: Vector3) -> void:
	var l := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.012
	s.height = 0.024
	l.mesh = s
	l.material_override = mats["off_led"]
	l.position = p
	add_child(l)
	leds[id] = l

# ---------------- ставни и кнопки у проёмов ----------------
func _doors() -> void:
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0 else "r"
		var x: float = s * (W - 0.02)
		var d := box(Vector3(x, DOOR_H / 2 + DOOR_H, DOOR_Z), Vector3(0.12, DOOR_H, DOOR_W), mats["shutter"])
		# рёбра ставни
		for k in 7:
			box(Vector3(-s * 0.065, -DOOR_H / 2 + 0.15 + k * 0.3, 0), Vector3(0.02, 0.05, DOOR_W - 0.06), mats["metal"], d)
		box(Vector3(-s * 0.07, -DOOR_H / 2 + 0.06, 0), Vector3(0.03, 0.12, DOOR_W), mats["red"], d)
		doors[side] = d
		# панель с кнопками ближе к Пахану
		var pz := DOOR_Z + DOOR_W / 2 + 0.38
		box(Vector3(x - s * 0.04, 1.2, pz), Vector3(0.04, 0.62, 0.3), mats["black"])
		_button("door_" + side, Vector3(x - s * 0.08, 1.36, pz), mats["red"], 0.13, "", self).rotation.z = deg_to_rad(90) * s
		_button("light_" + side, Vector3(x - s * 0.08, 1.06, pz), mats["paper"], 0.12, "", self).rotation.z = deg_to_rad(90) * s
		# подписи у кнопок проёма: крупно, с обводкой и клавишей — читаются с места охранника
		for pair in [["ДВЕРЬ · %s" % ("A" if s < 0 else "D"), 1.52], ["СВЕТ · %s" % ("Q" if s < 0 else "E"), 0.9]]:
			var dl := label(String(pair[0]), Vector3(x - s * 0.065, float(pair[1]), pz), 34, Color(0.97, 0.95, 0.9), Vector3(0, -deg_to_rad(90) * s, 0))
			dl.outline_size = 10
			dl.outline_modulate = Color(0, 0, 0, 0.95)
			dl.shaded = false
		_led("door_" + side, Vector3(x - s * 0.07, 1.62, pz))

# ---------------- вентиляция ----------------
func _vents() -> void:
	# решётка слева внизу на передней стене
	grate = Node3D.new()
	grate.position = Vector3(-1.62, 0.36, -1.69)
	add_child(grate)
	box(Vector3(0, 0, -0.05), Vector3(0.64, 0.44, 0.04), mats["black"], grate)
	for k in 6:
		box(Vector3(0, -0.18 + k * 0.072, 0.0), Vector3(0.6, 0.025, 0.02), mats["metal"], grate)
	grate_eyes = Node3D.new()
	grate_eyes.position = Vector3(0, 0.02, -0.18)
	grate_eyes.visible = false
	grate.add_child(grate_eyes)
	for ex in [-0.07, 0.07]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018
		sm.height = 0.036
		e.mesh = sm
		e.material_override = mats["eye_red"]
		e.position = Vector3(ex, 0, 0)
		grate_eyes.add_child(e)
	label("ВЕНТ", Vector3(-1.62, 0.66, -1.695), 16, Color(0.75, 0.1, 0.1))
	# люк над столом
	hatch = Node3D.new()
	hatch.position = Vector3(0.35, 2.69, -0.95)
	add_child(hatch)
	box(Vector3.ZERO, Vector3(0.72, 0.03, 0.72), mats["metal"], hatch)
	for k in 5:
		box(Vector3(-0.28 + k * 0.14, -0.02, 0), Vector3(0.03, 0.02, 0.66), mats["black"], hatch)

# ---------------- стены: объявления, фото, кладовка ----------------
func _decor() -> void:
	label("НЕ СПАТЬ.\nНЕ УМИРАТЬ.\nНЕ ПИТЬ ИЗ КУЛЕРА.", Vector3(0.95, 1.8, -1.69), 30, Color(0.7, 0.05, 0.05))
	# фото: Пахан и madk1d на открытии Облака (рисуем силуэты в код-картинке)
	photo_tex["normal"] = _photo(false)
	photo_tex["wrong"] = _photo(true)
	photo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.26)
	photo.mesh = q
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = photo_tex["normal"]
	pm.roughness = 0.6
	photo.material_override = pm
	photo.position = Vector3(0.28, 1.72, -1.694)
	add_child(photo)
	box(Vector3(0.28, 1.72, -1.698), Vector3(0.38, 0.3, 0.01), mats["black"])
	label("ОТКРЫТИЕ ОБЛАКА", Vector3(0.28, 1.54, -1.692), 12, Color(0.2, 0.2, 0.2))
	label("СОТРУДНИК МЕСЯЦА: БАЛОН", Vector3(1.4, 1.35, -1.69), 14, Color(0.15, 0.15, 0.15))
	# надпись, которой не было (событие)
	writing = label("ОН УЖЕ ВНУТРИ", Vector3(-W + 0.06, 1.9, 0.9), 64, Color(0.55, 0.0, 0.0), Vector3(0, deg_to_rad(90), 0))
	writing.visible = false
	# кладовка за спиной слева — дверь иногда приоткрыта
	closet = Node3D.new()
	closet.position = Vector3(-W + 0.06, 0, 1.15)
	add_child(closet)
	box(Vector3(0, 1.0, -0.35), Vector3(0.04, 2.0, 0.7), mats["shutter"], closet)
	box(Vector3(0.03, 1.0, -0.62), Vector3(0.03, 0.08, 0.04), mats["metal"], closet)
	# провода по стене и потолку
	for k in 5:
		var w := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.008
		c.bottom_radius = 0.008
		c.height = 3.4
		w.mesh = c
		w.material_override = mats["black"]
		w.rotation = Vector3(0, 0, deg_to_rad(90))
		w.position = Vector3(0, 2.6 - k * 0.025, -1.66 + k * 0.03)
		add_child(w)
	# предмет, которого не было: маленький Балон на столе (событие)
	extra_item = Node3D.new()
	extra_item.position = Vector3(-0.3, 0.81, -0.66) if desk_model == null else Vector3(-0.33, 0.79, -0.8)
	extra_item.visible = false
	add_child(extra_item)
	var bl := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.035
	bc.bottom_radius = 0.035
	bc.height = 0.14
	bl.mesh = bc
	bl.material_override = mats["red"]
	bl.position.y = 0.07
	extra_item.add_child(bl)
	for ex in [-0.012, 0.012]:
		box(Vector3(ex, 0.1, 0.034), Vector3(0.008, 0.008, 0.004), mats["eye"], extra_item)
	# глаза Балона в темноте у левого проёма
	dark_eyes = Node3D.new()
	dark_eyes.position = Vector3(-W - 0.7, 1.62, DOOR_Z)
	dark_eyes.visible = false
	add_child(dark_eyes)
	for ez in [-0.09, 0.09]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		e.mesh = sm
		e.material_override = mats["eye"]
		e.position = Vector3(0, 0, ez)
		dark_eyes.add_child(e)

## фото на стене — нарисованное кодом: два силуэта; «неправильное» — лица чёрные, глаза красные
## Следы прошлых смен: с каждой ночью будка выглядит хуже. Ночь 1 — чисто, одна зарубка. Дальше: зарубки по
## числу смен, царапины на косяке, бумаги на полу и опрокинутая кружка, отпечаток ладони и красная аварийная
## лампа, подпись под фото меняется, на шестую ночь — надпись на стене не гаснет. n — номер ночи с нуля.
var dress_root: Node3D
var alarm_lamp: OmniLight3D
func dress(n: int) -> void:
	if dress_root != null and is_instance_valid(dress_root):
		dress_root.queue_free()
	dress_root = Node3D.new()
	add_child(dress_root)
	alarm_lamp = null
	var k: int = clampi(n, 0, 6)
	var chalk := _glow(Color(0.85, 0.82, 0.75), 0.25)
	# зарубки на стене справа от стола: по одной на смену, каждая пятая — поперёк
	for q in k + 1:
		var bx := 1.62 + float(q % 5) * 0.045 + float(q / 5) * 0.3
		box(Vector3(bx, 1.02, -1.692), Vector3(0.012, 0.13, 0.004), chalk, dress_root, Vector3(0, 0, 0.06 * (q % 3 - 1)))
	if k >= 4:
		box(Vector3(1.71, 1.02, -1.691), Vector3(0.26, 0.012, 0.004), chalk, dress_root, Vector3(0, 0, 0.35))
	if k >= 1:
		# царапины на косяке левой двери — три борозды наискось
		for q in 3:
			box(Vector3(-W + 0.03, 1.15 + q * 0.07, 0.05 + q * 0.03), Vector3(0.006, 0.01, 0.42), mats["black"], dress_root, Vector3(0.5, 0, 0))
	if k >= 2:
		# бумаги на полу и опрокинутая кружка
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + k
		for q in 4 + k:
			box(Vector3(rng.randf_range(-0.9, 1.1), 0.006 + q * 0.001, rng.randf_range(-0.6, 0.5)), Vector3(0.21, 0.002, 0.3), mats["paper"], dress_root, Vector3(0, rng.randf() * TAU, 0))
		var mug := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.035
		cm.height = 0.09
		mug.mesh = cm
		mug.material_override = mats["paper"]
		mug.position = Vector3(0.62, 0.04, 0.2)
		mug.rotation = Vector3(0, 0.6, PI / 2)
		dress_root.add_child(mug)
		box(Vector3(0.72, 0.004, 0.24), Vector3(0.26, 0.002, 0.16), _m(Color(0.12, 0.07, 0.04), 0.3), dress_root, Vector3(0, 0.5, 0))    # лужа кофе
	if k >= 3:
		# отпечаток ладони на стене у левой двери и красная аварийная лампа над правой
		var hand := _m(Color(0.32, 0.02, 0.02), 0.5)
		box(Vector3(-W + 0.022, 1.42, 0.62), Vector3(0.004, 0.12, 0.1), hand, dress_root)
		for q in 4:
			box(Vector3(-W + 0.022, 1.53 + (0.02 if q in [1, 2] else 0.0), 0.575 + q * 0.03), Vector3(0.004, 0.09, 0.018), hand, dress_root)
		box(Vector3(-W + 0.022, 1.36, 0.6), Vector3(0.004, 0.3, 0.012), hand, dress_root, Vector3(0.12, 0, 0))                      # потёк
		box(Vector3(W - 0.05, 2.36, 0.0), Vector3(0.08, 0.1, 0.16), _glow(Color(0.9, 0.08, 0.05), 1.6), dress_root)
		alarm_lamp = OmniLight3D.new()
		alarm_lamp.light_color = Color(1.0, 0.1, 0.06)
		alarm_lamp.light_energy = 0.0
		alarm_lamp.omni_range = 3.2
		alarm_lamp.position = Vector3(W - 0.25, 2.3, 0.0)
		dress_root.add_child(alarm_lamp)
	if k >= 4:
		# подпись под «сотрудником месяца» перечёркнута, ниже — другое имя
		box(Vector3(1.4, 1.35, -1.688), Vector3(0.42, 0.01, 0.004), _m(Color(0.5, 0.03, 0.03), 0.5), dress_root)
		var l2 := label("СОТРУДНИК МЕСЯЦА: ТЫ", Vector3(1.4, 1.27, -1.688), 16, Color(0.55, 0.02, 0.02), Vector3(0, 0, -0.04), dress_root)
		l2.shaded = false
	if k >= 5:
		var l3 := label("НЕ ДОЛЖЕН БЫЛ ВЫЖИТЬ", Vector3(W - 0.06, 1.75, 0.7), 46, Color(0.5, 0.0, 0.0), Vector3(0, -deg_to_rad(90), 0.03), dress_root)
		l3.shaded = false
	lamp_base = [0.9, 0.9, 0.85, 0.78, 0.7, 0.6, 0.75][k]

func _photo(wrong: bool) -> ImageTexture:
	var img := Image.create(136, 104, false, Image.FORMAT_RGB8)
	img.fill(Color(0.62, 0.6, 0.55))
	for y in 104:
		for x in 136:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c * (0.85 + 0.15 * sin(x * 0.3 + y * 0.2)))
	var figs := [[44, 0.30], [94, 0.26]]
	for f in figs:
		var cx: int = f[0]
		for y in range(40, 104):
			var hw := 18 if y > 62 else 0
			for x in range(cx - hw, cx + hw):
				if x >= 0 and x < 136:
					img.set_pixel(x, y, Color(0.12, 0.12, 0.13))
		for y in range(22, 62):
			for x in range(cx - 16, cx + 16):
				if Vector2(x - cx, y - 42).length() < 17.0:
					img.set_pixel(x, y, Color(0.08, 0.08, 0.09) if wrong else Color(0.74, 0.66, 0.58))
		if wrong:
			for ex in [-6, 6]:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						img.set_pixel(cx + ex + dx, 40 + dy, Color(1.0, 0.05, 0.05))
		else:
			for ex in [-6, 6]:
				img.set_pixel(cx + ex, 40, Color(0.05, 0.05, 0.05))
			for dx in range(-5, 6):
				img.set_pixel(cx + dx, 49 + (1 if absi(dx) < 3 else 0), Color(0.3, 0.1, 0.1))
	return ImageTexture.create_from_image(img)

# ---------------- каждый кадр ----------------
## аварийная лампа над правой дверью: медленно пульсирует, когда кто-то стоит у любой двери или шахты
func alarm_pulse(danger: bool, dt: float) -> void:
	if alarm_lamp == null or not is_instance_valid(alarm_lamp):
		return
	var want := (0.55 + 0.45 * sin(t * 5.0)) * 0.9 if danger and power_on else 0.0
	alarm_lamp.light_energy = lerpf(alarm_lamp.light_energy, want, 1.0 - exp(-6.0 * dt))

func tick(st: FNNight, dt: float, look_in: float) -> void:
	alarm_pulse(st.enemies.values().any(func(e): return (e as FNEnemy)._at_door()), dt)
	t += dt
	# взгляд мышью/стрелками: плавно, с инерцией
	yaw_v = lerpf(yaw_v, (look_in - yaw) * 6.0, 1.0 - exp(-12.0 * dt))
	yaw = clampf(yaw + yaw_v * dt, -1.0, 1.0)
	st.yaw = yaw
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.03
	shake = maxf(0.0, shake - dt * 2.5)
	cam.rotation = Vector3(-0.1 + sh.y, -yaw * YAW_MAX + sh.x, sh.x * 0.3)
	cam.position = EYE
	power_on = not st.power_out
	# ставни
	for s in ["l", "r"]:
		var want := 0.0 if st.door[s] else 1.0
		var spd := 5.5 if want < door_y[s] else 3.2
		door_y[s] = move_toward(door_y[s], want, dt * spd)
		var d: MeshInstance3D = doors[s]
		d.position.y = DOOR_H / 2 + DOOR_H * ease(door_y[s], 0.6)
		var sp: SpotLight3D = lights[s]
		var on: bool = st.light[s] and power_on
		var flick := 1.0 if randf() > 0.04 else 0.3
		sp.light_energy = (2.6 * flick) if on else 0.0
	# индикаторы (MOD может врать — настоящая правда только в ставнях и фонарях)
	for s in ["l", "r"]:
		var v := st.door_led(s) if power_on else -1
		(leds["door_" + s] as MeshInstance3D).material_override = mats["red_led"] if v == 1 else (mats["green_led"] if v == 0 else mats["off_led"])
	for s in ["l", "t"]:
		var on2: bool = st.seal[s] and power_on and not st.glitches.has("leds_off")
		(leds["seal_" + s] as MeshInstance3D).material_override = mats["red_led"] if on2 else mats["off_led"]
	var bot: FNBot = st.enemies["bot"]
	var ping_on: bool = bot.ping_left > 0.0 and power_on and fposmod(t, 0.5) < 0.3 and not st.glitches.has("leds_off")
	(leds["ping"] as MeshInstance3D).material_override = mats["red_led"] if ping_on else mats["off_led"]
	# лампа: мигает, иногда гаснет на миг; без света — темнота
	flick_t -= dt
	if flick_t <= 0.0:
		flick_t = randf_range(0.05, 0.4) if randf() < 0.25 else randf_range(1.0, 5.0)
	var lamp_e := lamp_base * (0.25 if flick_t < 0.12 and randf() < 0.5 else 1.0) * (0.92 + 0.08 * sin(t * 17.0))
	lamp.light_energy = lamp_e if power_on else 0.0
	glow.light_energy = (0.55 if st.monitor else 0.3) if power_on else 0.0
	screen_mat.emission_energy_multiplier = (0.9 if st.monitor else 0.22) if power_on else 0.0
	# вентиляция: решётка дрожит, когда он прямо за ней; люк гремит
	var m: FNEnemy = st.enemies["madk1d"]
	var at_l: bool = m.spot == "vent_l"
	var at_t: bool = m.spot == "vent_t"
	grate.position.x = -1.62 + (sin(t * 37.0) * 0.004 if at_l and not st.seal["l"] else 0.0)
	grate_eyes.visible = at_l and (st.light["l"] or fposmod(t, 2.4) < 0.25)
	hatch.rotation.z = (sin(t * 29.0) * 0.012 if at_t and not st.seal["t"] else 0.0)
	hatch.position.y = 2.69 - (0.02 if st.seal["t"] else 0.0)

## что под курсором: ближайшая кнопка на экране в пределах её радиуса
func pick(screen_pos: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for id in buttons:
		var n: Node3D = buttons[id]["node"]
		if not n.is_visible_in_tree() or cam.is_position_behind(n.global_position):
			continue
		var sp := cam.unproject_position(n.global_position)
		var edge := cam.unproject_position(n.global_position + cam.global_transform.basis.x * float(buttons[id]["r"]))
		var rad := maxf(14.0, sp.distance_to(edge))
		var d := sp.distance_to(screen_pos)
		if d < rad and d < bd:
			bd = d
			best = id
	return best

## кнопка физически нажата: утапливается на миг
func press(id: String) -> void:
	if not buttons.has(id):
		return
	var n: Node3D = buttons[id]["node"]
	var tw := create_tween()
	var p0 := n.position
	var dir := -n.global_transform.basis.y * 0.012
	tw.tween_property(n, "position", p0 + n.get_parent().global_transform.basis.inverse() * dir, 0.05)
	tw.tween_property(n, "position", p0, 0.1)

## мировые точки звука и врагов у офиса
static func point(id: String) -> Vector3:
	match id:
		"door_l":
			return Vector3(-W - 0.6, 0.0, DOOR_Z)
		"door_r":
			return Vector3(W + 0.6, 0.0, DOOR_Z)
		"vent_l", "duct_l":
			return Vector3(-1.62, 0.36, -2.1)
		"vent_t", "duct_t":
			return Vector3(0.35, 3.0, -0.95)
		"corner":
			return Vector3(-1.75, 0.0, 1.0)
		"hall_l":
			return Vector3(-W - 1.55, 0.0, -4.6)
		"hall_r":
			return Vector3(W + 1.55, 0.0, -4.6)
	return Vector3(0, 0, -3)
