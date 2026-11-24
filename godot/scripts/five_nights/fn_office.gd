## Будка охранника. Узлы и точки нажатия принадлежат guard_booth.tscn и её подсценам.
## FNOffice только показывает состояние FNNight. Палитрой и примитивами ниже пользуются
## также процедурные комнаты видеонаблюдения, враги и следы прошедших смен.
class_name FNOffice
extends Node3D

## короткий провал света лампы над столом: на него отзываются звук лампы и треск (FNAmbience)
signal lamp_dip

## «единица» света лампы: в ней всё считают (энергии из FNScare и событий ночи — в этих единицах)
const LAMP_UNIT := 1.08

const YAW_MAX := deg_to_rad(64.0)
const LOOK_RATE := 8.0
const W := 2.2
const DOOR_Z := -0.4
# Слой для ниши и стоящих в ней ригов; тот же бит, что в P0.
const DOOR_LAYER := 2
const RollingShutter := preload("res://scripts/five_nights/fn_rolling_shutter.gd")

@onready var cam: Camera3D = $PlayerCamera
@onready var rest_view := cam.transform
@onready var rest_fov := cam.fov
@onready var lamp: OmniLight3D = $Lighting/HouseLamp
@onready var reserve: OmniLight3D = $Lighting/ReserveLamp
@onready var reserve_rated := reserve.light_energy
@onready var desk: SpotLight3D = $Lighting/DeskPool
@onready var spill_rated := lamp.light_energy
@onready var desk_rated := desk.light_energy
@onready var glass_rated: float = $Lighting/StripFixture/Diffuser.material_override.emission_energy_multiplier
@onready var lamp_rated := LAMP_UNIT
@onready var lamp_base := lamp_rated
@onready var lamp_tint := lamp.light_color
@onready var diffuser: StandardMaterial3D = $Lighting/StripFixture/Diffuser.material_override
@onready var scare_light: OmniLight3D = $Lighting/ScareLight
@onready var glow: OmniLight3D = $Console/ScreenGlow
@onready var screen_mat: ShaderMaterial = $Console/MainScreen.material_override
@onready var aux_mat: ShaderMaterial = $Console/AuxScreen.material_override
@onready var grate: Node3D = $Ventilation/WallGrate
@onready var hatch: Node3D = $Ventilation/CeilingHatch
@onready var grate_x := grate.position.x
@onready var hatch_y := hatch.position.y
@onready var grate_eyes: Node3D = $Ventilation/WallGrate/Eyes
@onready var desk_fan: FNDeskFan = $Console/DeskFan
@onready var wall_pivot: Node3D = $Ventilation/WallGrate/DamperPivot
@onready var vent_latch: Node3D = $Ventilation/WallGrate/Drive/LockCam
@onready var leaf_l: Node3D = $Ventilation/CeilingHatch/LeafPivotL
@onready var leaf_r: Node3D = $Ventilation/CeilingHatch/LeafPivotR
signal seal_stop(s: String, closed: bool)
const SEAL_CLOSE := 0.36            # с: клапан падает
const SEAL_OPEN := 0.52             # с: привод поднимает
const SEAL_PARK := 0.47              # м: плита решётки в открытом положении стоит над решёткой на стене
const SEAL_OPEN_ANGLE := 1.5        # рад: заслонка откинута в шахту (≈86°)
const LOCK_BLINK_HZ := 8.0          # янтарная лампа блокировки мигает в ходу, горит 60 % периода
const LOCK_BLINK_DUTY := 0.6
const LOCK_E_MOVE := 0.55           # свет лампы: янтарный в ходу и при догорании после открытия
const LOCK_E_CLOSED := 0.5          # красный свет у закрытой
const LOCK_E_RATE := 6.0            # ед./с: плавная смена вне мигания
const LOCK_AFTERGLOW := 0.8         # с: янтарное догорание после упора открытой
const LOCK_AMBER := Color(1.0, 0.6, 0.2)
const LOCK_RED := Color(1.0, 0.12, 0.08)
const SLAT_CLOSED_K := 0.04545      # ламели люка: закрыто −0.05 рад при открытых −1.1
var seal_k := {"l": 0.0, "t": 0.0}          # видимое положение: 0 открыто … 1 закрыто
var seal_dir := {"l": 0, "t": 0}            # 1 закрывается, −1 открывается, 0 стоит
var seal_since := {"l": 9.0, "t": 9.0}      # секунд с начала хода или с остановки
var seal_hit_t := {"l": 9.0, "t": 9.0}      # секунд с удара MADK1D по закрытой заслонке
var slats: Array = []
var lock_lamp := {}
var lock_glow := {}
var slat_open: Array = []
@onready var crank: Node3D = $WallFixtures/HandGenerator/Crank
@onready var crank_rest := crank.rotation.z
@onready var record_light: MeshInstance3D = $WallFixtures/SecurityCamera/RecordLight
@onready var photo: MeshInstance3D = $WallFixtures/OpeningPhoto/Photo
@onready var writing: Label3D = $NightEffects/Writing
@onready var closet: Node3D = $NightEffects/ClosetDoor
@onready var extra_item: Node3D = $Console/Figurine
@onready var reflection: MeshInstance3D = $Console/Reflection
@onready var dark_eyes: Node3D = $NightEffects/BlackoutEyes

var photo_tex := {
	"normal": preload("res://assets/fn_curated/oblako/opening_photo.jpg"),
	"wrong": preload("res://assets/fn_curated/oblako/opening_photo_wrong.jpg"),
}
var yaw := 0.0                     # −1 налево .. +1 направо (как в FNNight)
var yaw_v := 0.0
const PITCH_UP := deg_to_rad(36.0)   # взгляд вверх (на люк над столом): pitch_k 0…1
var pitch_k := 0.0
var pitch_v := 0.0
var pitch_target := 0.0            # 0 — прямо, 1 — вверх; ставит ввод (FiveNightsRoot)
var shake := 0.0
var font: Font = preload("res://assets/fonts/RussoOne-Regular.ttf")
var mats := {}
var doors := {}
var door_y := {"l": 1.0, "r": 1.0}
var lights := {}
var buttons := {}
var leds := {}
var t := 0.0
var flick_t := 2.4
var beams_aimed := false
var beam_t := {}                  # сторона → сколько секунд горит фонарь
var lamp_k := 1.0                 # текущий свет лампы относительно её обычного (для звука лампы)
var tension_k := 0.0              # уровень напряжения ночи (ставит корень): лампа мерцает чуть сильнее
var instab := 0.0                 # нестабильность питания: растёт к поздним ночам (только вид)
var crt_next := 12.0
var crt_dip := 0.0
var led_glow := {}
var event_gain := 1.0
var supply := 1.0
var power_on := true

var door_parts := {}               # ламели створки [узел, низ] — их читает проверка; двигает и прячет их сама створка (fn_rolling_shutter.gd)

var wall_base_y := 0.0

func _ready() -> void:
	_mats()
	wall_base_y = wall_pivot.position.y
	_bind_door("l", $LeftDoor, $LeftControls, "A", "Q")
	_bind_door("r", $RightDoor, $RightControls, "D", "E")
	_isolate_door_lighting()
	_bind_button("phone", $Console/PhoneHit, 0.1)
	var panel := $Console/Switchboard
	_bind_button("seal_l", panel.get_node("LeftSeal"), 0.06)
	_bind_button("seal_t", panel.get_node("TopSeal"), 0.06)
	_bind_button("reset", panel.get_node("Reset"), 0.06)
	leds["seal_l"] = panel.get_node("LeftSealLED")
	leds["seal_t"] = panel.get_node("TopSealLED")
	leds["ping"] = panel.get_node("ResetLED")

func _bind_door(side: String, doorway: Node3D, controls: Node3D, door_key: String, light_key: String) -> void:
	doors[side] = doorway.get_node("Track/Shutter")
	door_parts[side] = []
	for c in doors[side].get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			door_parts[side].append([c, (c as Node3D).position.y + (c as MeshInstance3D).mesh.get_aabb().position.y])
	lights[side] = doorway.get_node("Beam")
	leds["door_" + side] = controls.get_node("LED")
	led_glow[side] = controls.get_node("LedGlow")
	_bind_button("door_" + side, controls.get_node("DoorHit"), 0.13)
	_bind_button("light_" + side, controls.get_node("LightHit"), 0.12)
	(controls.get_node("DoorLabel") as Label3D).text = "ДВЕРЬ  ·  " + door_key
	(controls.get_node("LightLabel") as Label3D).text = "СВЕТ  ·  " + light_key

func _isolate_door_lighting() -> void:
	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light != lights["l"] and light != lights["r"] and light != scare_light:
			light.light_cull_mask &= ~DOOR_LAYER
	for recess in [$Shell/LeftRecess, $Shell/RightRecess]:
		for child in recess.get_children():
			var surface := child as MeshInstance3D
			if surface == null:
				continue
			var source := surface.material_override as BaseMaterial3D
			if source == null:
				continue
			var local := source.duplicate() as BaseMaterial3D
			local.disable_ambient_light = true
			surface.material_override = local
			surface.layers = DOOR_LAYER

func _bind_button(id: String, node: Node3D, radius: float) -> void:
	buttons[id] = {"node": node, "r": radius, "rest": node.position}

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
	mats["paper"] = _m(Color(0.86, 0.84, 0.78), 0.95)
	mats["red_led"] = _glow(Color(1.0, 0.08, 0.05), 3.0)
	mats["green_led"] = _glow(Color(0.25, 1.0, 0.35), 2.2)
	mats["off_led"] = _m(Color(0.08, 0.06, 0.06), 0.4)
	mats["amber_led"] = _glow(Color(1.0, 0.55, 0.08), 3.0)
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

## Следы прошлых смен: с каждой ночью будка выглядит хуже. Ночь 1 — чисто, одна зарубка. Дальше: зарубки по
## числу смен, царапины на косяке, бумаги на полу и опрокинутая кружка, отпечаток ладони и красная аварийная
## лампа, подпись под фото меняется, на шестую ночь — надпись на стене не гаснет. n — номер ночи с нуля.
var dress_root: Node3D
var alarm_lamp: OmniLight3D
var alarm_lens: MeshInstance3D
func dress(n: int) -> void:
	if is_instance_valid(dress_root):
		remove_child(dress_root)
		dress_root.queue_free()
	dress_root = Node3D.new()
	dress_root.name = "ShiftMarks"
	add_child(dress_root)
	alarm_lamp = null
	alarm_lens = null
	event_gain = 1.0
	var k: int = clampi(n, 0, 6)
	var chalk := _glow(Color(0.85, 0.82, 0.75), 0.25)
	# зарубки на стене справа от стола: по одной на смену, каждая пятая — поперёк
	for q in k + 1:
		@warning_ignore("integer_division")
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
		alarm_lens = box(Vector3(W - 0.05, 2.36, 0.0), Vector3(0.08, 0.1, 0.16), mats["red"], dress_root)
		alarm_lamp = OmniLight3D.new()
		alarm_lamp.light_color = Color(1.0, 0.1, 0.06)
		alarm_lamp.light_energy = 0.0
		alarm_lamp.omni_range = 3.2
		alarm_lamp.light_cull_mask &= ~DOOR_LAYER
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
	lamp_base = lamp_rated * float([0.9, 0.9, 0.85, 0.78, 0.7, 0.6, 0.75][k]) / 0.9
	instab = [0.0, 0.15, 0.3, 0.5, 0.7, 1.0, 0.6][k]

## Аварийная лампа над правой дверью.
func alarm_pulse(danger: bool, dt: float) -> void:
	if alarm_lamp == null or not is_instance_valid(alarm_lamp):
		return
	var want := (0.55 + 0.45 * sin(t * 5.0)) * 0.9 if danger and power_on else 0.0
	alarm_lamp.light_energy = lerpf(alarm_lamp.light_energy, want, 1.0 - exp(-6.0 * dt))
	alarm_lens.material_override = mats["red_led"] if power_on and alarm_lamp.light_energy > 0.35 else mats["red"]

## вентилятор на столе: скорость берётся у ambience.fan_spin, питания у него своего нет
func fan_tick(dt: float, spin: float) -> void:
	desk_fan.tick(dt, spin)

## заслонки вентиляции: картинка следует за st.seal каждый кадр (без твинов — ничто не застрянет); логика закрывается мгновенно
func _vents(st: FNNight, dt: float, snap := false) -> void:
	if slats.is_empty():
		for i in 6:
			var sl := hatch.get_node_or_null("Slat%d" % (i + 1)) as Node3D
			if sl != null:
				slats.append(sl)
				slat_open.append(sl.rotation.z)
	if lock_lamp.is_empty():
		lock_lamp["l"] = $Ventilation/WallGrate/LockLamp
		lock_lamp["t"] = $Ventilation/CeilingHatch/LockLamp
		lock_glow["l"] = $Ventilation/WallGrate/LockLamp/Glow
		lock_glow["t"] = $Ventilation/CeilingHatch/LockLamp/Glow
	var mad: FNEnemy = st.enemies["madk1d"]
	for s in ["l", "t"]:
		var goal := 1.0 if st.seal[s] else 0.0
		var k: float = seal_k[s]
		if snap:
			k = goal
			seal_dir[s] = 0
			seal_since[s] = 9.0
			seal_hit_t[s] = 9.0
		elif k != goal:
			var dirn := 1 if goal > k else -1
			if int(seal_dir[s]) != dirn:
				seal_dir[s] = dirn
				seal_since[s] = 0.0
			seal_since[s] = float(seal_since[s]) + dt
			k = move_toward(k, goal, dt / (SEAL_CLOSE if dirn > 0 else SEAL_OPEN))
			if k == goal:
				seal_dir[s] = 0
				seal_since[s] = 0.0
				seal_stop.emit(s, goal > 0.5)
		else:
			seal_since[s] = float(seal_since[s]) + dt
		seal_hit_t[s] = float(seal_hit_t[s]) + dt
		seal_k[s] = k
		var moving := int(seal_dir[s]) != 0
		_lock_lamp(s, st, k, moving, dt, snap)
		var closing := int(seal_dir[s]) > 0 or (not moving and k >= 0.5)
		var f := 0.0
		if closing:
			f = 1.0 - k * k                                  # падает под весом
		else:
			f = 1.0 - pow(k, 3.0)                            # привод: быстрый срыв, мягкий упор
		var ss: float = seal_since[s]
		var extra := 0.0
		var jolt := 0.0
		if not moving and k >= 1.0:
			extra += 0.087 * exp(-ss * 14.0) * absf(sin(ss * 38.0))      # отскок листа, ≤5°
			jolt += 0.003 * exp(-ss * 10.0) * sin(ss * 60.0)
			if mad.level > 0 and mad.spot == "vent_" + s:
				extra += 0.021 * sin(t * 70.0) * (1.0 if fposmod(t, 1.3) < 0.35 else 0.0)      # дребезжит, пока MADK1D за ним
		elif not moving:
			extra += 0.02 * exp(-ss * 8.0) * sin(ss * 40.0)
			jolt += 0.0015 * exp(-ss * 8.0) * sin(ss * 50.0)
		elif int(seal_dir[s]) < 0:
			extra += 0.05 * exp(-ss * 25.0) * sin(ss * 80.0)                # срыв защёлки
		var ht: float = seal_hit_t[s]
		extra += 0.07 * exp(-ht * 14.0) * sin(ht * 50.0)
		jolt += 0.004 * exp(-ht * 12.0) * sin(ht * 70.0)
		var ang := SEAL_OPEN_ANGLE * f + extra
		if s == "l":
			wall_pivot.rotation.x = 0.0
			vent_latch.rotation.z = lerpf(0.82, -0.29, smoothstep(0.72, 1.0, k))
			wall_pivot.position.y = wall_base_y + SEAL_PARK * f + clampf(extra * 0.17, -0.015, 0.015)
			var at_l: bool = mad.spot == "vent_l" and mad.level > 0 and not st.seal["l"]
			grate.position.x = grate_x + jolt + (sin(t * 37.0) * 0.004 if at_l else 0.0)
		else:
			leaf_l.rotation.z = ang
			leaf_r.rotation.z = -ang
			hatch.position.y = hatch_y - 0.02 * k + jolt
			for i in slats.size():
				(slats[i] as Node3D).rotation.z = float(slat_open[i]) * lerpf(1.0, SLAT_CLOSED_K, k)

## лампа блокировки на раме: нет питания — погашена, в ходу — мигает янтарным, закрыта — красная, открыта — гаснет с догоранием
func _lock_lamp(s: String, st: FNNight, k: float, moving: bool, dt: float, snap: bool) -> void:
	var lamp_n: MeshInstance3D = lock_lamp[s]
	var glw: OmniLight3D = lock_glow[s]
	var live: bool = power_on and not st.glitches.has("leds_off")
	var mat: Material = mats["off_led"]
	var want := 0.0
	var col := LOCK_AMBER
	if live:
		if moving:
			if fposmod(t, 1.0 / LOCK_BLINK_HZ) < LOCK_BLINK_DUTY / LOCK_BLINK_HZ:
				mat = mats["amber_led"]
				want = LOCK_E_MOVE
		elif k >= 1.0:
			mat = mats["red_led"]
			want = LOCK_E_CLOSED
			col = LOCK_RED
		else:
			want = LOCK_E_MOVE * clampf(1.0 - float(seal_since[s]) / LOCK_AFTERGLOW, 0.0, 1.0)
	lamp_n.material_override = mat
	glw.light_color = col
	if moving or snap or not live:
		glw.light_energy = want
	else:
		glw.light_energy = move_toward(glw.light_energy, want, LOCK_E_RATE * dt)

## картинка сразу равна состоянию (новая ночь): без отскоков и сигналов
## положение плиты решётки в «углах» механизма (0 — закрыта, SEAL_OPEN_ANGLE — открыта): для проверок и записи состояния
func wall_angle() -> float:
	return (wall_pivot.position.y - wall_base_y) / SEAL_PARK * SEAL_OPEN_ANGLE

func seal_reset(st: FNNight) -> void:
	_vents(st, 0.0, true)

## MADK1D ударил в закрытую заслонку и уходит
func seal_bang(s: String) -> void:
	if seal_hit_t.has(s):
		seal_hit_t[s] = 0.0

func instab_eff() -> float:
	return clampf(instab + 0.25 * tension_k, 0.0, 1.0)

func tick(st: FNNight, dt: float, look_in: float) -> void:
	t += dt
	if not beams_aimed:
		beams_aimed = true
		for s in ["l", "r"]:
			var beam: SpotLight3D = lights[s]
			var side := -1.0 if s == "l" else 1.0
			beam.look_at(Vector3(side * 3.09, 1.09, -0.25), Vector3.UP)
			beam.spot_angle = 40.0
	power_on = not st.power_out
	alarm_pulse(false, dt) # Индикатор не выдаёт присутствие за дверью.
	_look(st, dt, look_in)
	for s in ["l", "r"]:
		var want := 0.0 if st.door[s] else 1.0
		var speed := 5.5 if want < door_y[s] else 3.2
		door_y[s] = move_toward(door_y[s], want, dt * speed)
		var door: RollingShutter = doors[s]
		door.set_opening(ease(door_y[s], 0.6))
		var beam: SpotLight3D = lights[s]
		var on: bool = st.light[s] and power_on
		var bt: float = float(beam_t.get(s, 0.0))
		bt = bt + dt if on else 0.0
		beam_t[s] = bt
		# холодный пуск: нарастает за 0,16 с с одним коротким провалом до 60 % на 0,06 с; гаснет за 0,10 с
		var bw := 0.0
		if on:
			bw = 2.6 * clampf(bt / 0.16, 0.0, 1.0) * (0.97 + 0.03 * sin(t * 15.0))
			if bt > 0.045 and bt < 0.085:
				bw *= 0.6
		beam.light_energy = bw if on else move_toward(beam.light_energy, 0.0, 2.6 / 0.10 * dt)
		beam.visible = beam.light_energy > 0.01
	_indicators(st)
	_lighting(st, dt)
	var mad: FNEnemy = st.enemies["madk1d"]
	var at_l := mad.spot == "vent_l"
	var at_t := mad.spot == "vent_t"
	_vents(st, dt)
	grate_eyes.visible = at_l and seal_k["l"] < 0.5 and (st.light["l"] or fposmod(t, 2.4) < 0.25)
	hatch.rotation.z = sin(t * 29.0) * 0.012 if at_t and not st.seal["t"] else 0.0
	crank.rotation.z = lerp_angle(crank.rotation.z, crank_rest - st.crank_p * 1.6, 1.0 - exp(-18.0 * dt))

## Критически затухающая пружина. Углы и область взгляда GHOST остаются в координатах FNNight.
func _look(st: FNNight, dt: float, target: float) -> void:
	var offset := yaw - target
	var speed := yaw_v + LOOK_RATE * offset
	var decay := exp(-LOOK_RATE * dt)
	yaw = clampf(target + (offset + speed * dt) * decay, -1.0, 1.0)
	yaw_v = (yaw_v - LOOK_RATE * speed * dt) * decay
	st.yaw = yaw
	var p_off := pitch_k - pitch_target
	var p_speed := pitch_v + LOOK_RATE * p_off
	pitch_k = clampf(pitch_target + (p_off + p_speed * dt) * decay, 0.0, 1.0)
	pitch_v = (pitch_v - LOOK_RATE * p_speed * dt) * decay
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.03
	shake = maxf(0.0, shake - dt * 2.5)
	cam.position = rest_view.origin
	cam.basis = Basis(Vector3.UP, -yaw * YAW_MAX + sh.x) * rest_view.basis * Basis(Vector3.RIGHT, PITCH_UP * pitch_k) * Basis.from_euler(Vector3(sh.y, 0, sh.x * 0.3))

func _lighting(st: FNNight, dt: float) -> void:
	# Короткий провал люминофора и более медленный розжиг. Все источники в будке читают одно питание.
	supply = move_toward(supply, 1.0 if power_on else 0.0, dt * (3.8 if power_on else 8.0))
	var was := flick_t
	flick_t -= dt
	if was >= 0.18 and flick_t < 0.18 and power_on:
		lamp_dip.emit()
	if flick_t <= 0.0:
		flick_t = randf_range(2.2, 5.6) * lerpf(1.6, 0.6, instab_eff()) * (0.5 if st.power < 15.0 else 1.0)
	var dip := sin(PI * clampf(flick_t / 0.18, 0.0, 1.0))
	var output := (0.985 + 0.015 * sin(t * 11.0) + 0.02 * sin(t * 0.7 + 1.3) * instab_eff() - lerpf(0.14, 0.42, instab_eff()) * dip) * supply
	output *= 1.0 - 0.03 * maxf(0.0, float(st.usage) - 3.0)
	if st.brown_warn > 0.0:
		output *= 0.68 + 0.31 * cos(st.brown_warn * 17.0)
	elif st.brown_t > 0.0:
		output *= 0.22
	set_lamp_energy(lamp_base * event_gain * output)
	reserve.light_energy = reserve_rated * lerpf(1.0, 0.55, supply)
	crt_next -= dt
	if crt_next <= 0.0:
		crt_dip = 0.06
		crt_next = randf_range(5.0, 14.0) if instab_eff() >= 0.7 else randf_range(9.0, 25.0)
	crt_dip = maxf(0.0, crt_dip - dt)
	var crt_k := (1.0 + 0.035 * sin(t * 2.3) + 0.02 * sin(t * 7.1)) * (0.75 if crt_dip > 0.0 else 1.0)
	glow.light_energy = (0.062 if st.monitor else 0.045) * supply * crt_k
	screen_mat.set_shader_parameter("brightness", (0.68 if st.monitor else 0.49) * supply * crt_k)
	aux_mat.set_shader_parameter("brightness", 0.34 * supply * crt_k)
	record_light.visible = power_on and fposmod(t, 1.6) < 1.1

## Скример и события ночи меняют и сам источник, и стекло светильника.
func set_lamp_energy(energy: float) -> void:
	var k := energy / LAMP_UNIT
	lamp_k = clampf(energy / maxf(lamp_base, 0.001), 0.0, 3.0)
	lamp.light_energy = spill_rated * k
	desk.light_energy = desk_rated * k
	diffuser.emission_energy_multiplier = glass_rated * k

## цвет света лампы (скримеры красят комнату): и рассеянный свет, и пятно на столе
func set_lamp_color(c: Color) -> void:
	lamp.light_color = c
	desk.light_color = c

func _indicators(st: FNNight) -> void:
	# индикаторы (MOD может врать — настоящая правда только в ставнях и фонарях)
	for s in ["l", "r"]:
		var v := st.door_led(s) if power_on else -1
		(leds["door_" + s] as MeshInstance3D).material_override = mats["red_led"] if v == 1 else (mats["green_led"] if v == 0 else mats["off_led"])
		var lg: OmniLight3D = led_glow[s]
		lg.light_energy = 0.05 if v >= 0 else 0.0
		lg.light_color = Color(1.0, 0.08, 0.05) if v == 1 else Color(0.25, 1.0, 0.35)
	for s in ["l", "t"]:
		var on2: bool = st.seal[s] and power_on and not st.glitches.has("leds_off")
		(leds["seal_" + s] as MeshInstance3D).material_override = mats["red_led"] if on2 else mats["off_led"]
	var bot: FNBot = st.enemies["bot"]
	var ping_on: bool = bot.ping_left > 0.0 and power_on and fposmod(t, 0.5) < 0.3 and not st.glitches.has("leds_off")
	(leds["ping"] as MeshInstance3D).material_override = mats["red_led"] if ping_on else mats["off_led"]

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

## Утапливаем движущуюся клавишу. У цельных GLB зона нажатия закреплена на корпусе.
func press(id: String) -> void:
	var button: Dictionary = buttons.get(id, {})
	var node := button.get("node") as MeshInstance3D
	if node == null:
		return
	var previous: Tween = button.get("tween")
	if previous != null and previous.is_valid():
		previous.kill()
	var rest: Vector3 = button["rest"]
	var tween := create_tween()
	button["tween"] = tween
	tween.tween_property(node, "position", rest - node.basis.y * 0.012, 0.05)
	tween.tween_property(node, "position", rest, 0.1)

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
