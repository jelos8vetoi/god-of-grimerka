## ПАХАН НАБРАЛ МИКРОЗАЙМОВ — корень мини-игры (сцена scenes/microloans/microloans.tscn, main.minigame).
## Своя 3D-комната: ночь, стол, потрёпанный ноутбук, телефон с уведомлениями, калькулятор, квитанции, письма,
## энергетик, провода, старый монитор, лампа; за окном двор с панельками и фонарём. Пахан — настоящая модель
## (pahan.glb), сидит за столом и реагирует. Свой свет, камера, окружение, экономика (ml_economy), интерфейс
## (ml_ui), сохранение (ml_save). Основная игра (game.gd) не запускается.
class_name MicroloansRoot
extends Node3D

var main
var econ := MLEconomy.new()
var ui: MLUI
var cam: Camera3D
var pahan: Rig
var phone: MeshInstance3D
var phone_screen: StandardMaterial3D
var lamp: SpotLight3D
var monitor_mat: StandardMaterial3D
var laptop_mat: StandardMaterial3D
var buzz_t := 0.0
var flicker_t := 0.0
var react_t := 0.0
var t := 0.0
var quiet := false
var snd: MLSound                # звук мини-игры (ml_sound.gd)

func _ready() -> void:
	if main == null:
		main = get_tree().root.get_node_or_null("Main")
	quiet = main != null and main.testing() != ""
	snd = MLSound.new()
	snd.muted = quiet and not (main != null and main.audiolog)
	add_child(snd)
	_room()
	ui = MLUI.new()
	ui.root = self
	add_child(ui)
	econ.note.connect(_on_note)
	econ.changed.connect(func():
		ui.refresh()
		_feel())

## новая игра или продолжение
func begin(load_save: bool) -> void:
	if not (load_save and MLSave.load_run(econ)):
		econ.new_game(int(Time.get_ticks_usec() % 2147483647))
		ui.intro()
	ui.refresh()
	ui.show_phase()

func save() -> void:
	MLSave.save_run(econ)

# ---------------- комната ----------------
func _mat(col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _box(p: Vector3, s: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	add_child(mi)
	return mi

func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.07)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# стены, пол, потолок: грязно-белые обои, тёмный линолеум
	var wall := _mat(Color(0.62, 0.6, 0.55))
	var floor_m := _mat(Color(0.18, 0.15, 0.13))
	_box(Vector3(0, -0.05, 0), Vector3(8, 0.1, 8), floor_m)
	_box(Vector3(0, 1.5, -2.4), Vector3(8, 3.2, 0.1), wall)          # стена со столом и окном
	_box(Vector3(-3.0, 1.5, 0), Vector3(0.1, 3.2, 8), wall)
	_box(Vector3(3.0, 1.5, 0), Vector3(0.1, 3.2, 8), wall)
	_box(Vector3(0, 3.1, 0), Vector3(8, 0.1, 8), _mat(Color(0.4, 0.39, 0.36)))
	# окно: проём со стеклом, за ним двор
	var glass := _mat(Color(0.08, 0.1, 0.16, 0.25), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var frame := _mat(Color(0.85, 0.85, 0.82))
	var win_c := Vector3(1.3, 1.8, -2.36)
	_box(win_c, Vector3(1.6, 1.2, 0.04), glass)
	for k in [[Vector3(0, 0.62, 0), Vector3(1.7, 0.06, 0.08)], [Vector3(0, -0.62, 0), Vector3(1.7, 0.06, 0.08)], [Vector3(0.82, 0, 0), Vector3(0.06, 1.3, 0.08)], [Vector3(-0.82, 0, 0), Vector3(0.06, 1.3, 0.08)], [Vector3(0, 0, 0), Vector3(0.05, 1.2, 0.06)]]:
		_box(win_c + k[0], k[1], frame)
	# двор за окном: панельки, фонарь, берёза (модели гонок, если есть)
	var yard := Node3D.new()
	yard.position = Vector3(1.3, 0, -9)
	add_child(yard)
	if RaceProps.has("khrushchevka"):
		RaceProps.spawn("khrushchevka", yard, Vector3(-4, -4, -14), 0.0, 1.0, false)
		RaceProps.spawn("panel_tower", yard, Vector3(14, -4, -20), -0.4, 1.0, false)
		RaceProps.spawn("street_lamp", yard, Vector3(2.5, -4, -2), 0.6, 1.0, false)
		RaceProps.spawn("birch_tree", yard, Vector3(-2, -4, -4), 0.3, 1.0, false)
		RaceProps.spawn("old_car", yard, Vector3(1, -4, -6), 1.2, 1.0, false)
	var street := OmniLight3D.new()
	street.light_color = Color(1.0, 0.62, 0.3)
	street.light_energy = 3.0
	street.omni_range = 14.0
	street.position = Vector3(3.5, 2.2, -9)
	add_child(street)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.25
	moon.rotation = Vector3(-0.6, 0.4, 0)
	add_child(moon)
	# стол и вещи
	var wood := _mat(Color(0.32, 0.2, 0.12))
	_box(Vector3(0, 0.74, -1.7), Vector3(2.4, 0.06, 1.0), wood)
	for x in [-1.1, 1.1]:
		for z in [-2.1, -1.3]:
			_box(Vector3(x, 0.37, z), Vector3(0.06, 0.74, 0.06), wood)
	# ноутбук
	laptop_mat = _mat(Color(0.35, 0.55, 0.9), 0.3, 1.4)
	_box(Vector3(-0.15, 0.78, -1.6), Vector3(0.62, 0.025, 0.42), _mat(Color(0.12, 0.12, 0.13)))
	_box(Vector3(-0.15, 0.98, -1.82), Vector3(0.62, 0.4, 0.02), laptop_mat, Vector3(-0.2, 0, 0))
	# старый монитор
	monitor_mat = _mat(Color(0.25, 0.4, 0.3), 0.3, 0.6)
	_box(Vector3(-0.85, 1.0, -2.0), Vector3(0.6, 0.5, 0.5), _mat(Color(0.72, 0.7, 0.62)))
	_box(Vector3(-0.85, 1.02, -1.74), Vector3(0.46, 0.36, 0.01), monitor_mat)
	# телефон
	phone_screen = _mat(Color(0.9, 0.95, 1.0), 0.2, 0.3)
	phone = _box(Vector3(0.55, 0.785, -1.45), Vector3(0.09, 0.012, 0.17), _mat(Color(0.05, 0.05, 0.06)), Vector3(0, 0.3, 0))
	var scr := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.08, 0.004, 0.155)
	scr.mesh = sm
	scr.material_override = phone_screen
	scr.position.y = 0.008
	phone.add_child(scr)
	# калькулятор, квитанции, письма, энергетик, провода
	_box(Vector3(0.85, 0.79, -1.65), Vector3(0.12, 0.02, 0.18), _mat(Color(0.2, 0.2, 0.22)), Vector3(0, -0.2, 0))
	for k in 7:
		_box(Vector3(0.75 + k * 0.004, 0.78 + k * 0.006, -1.95), Vector3(0.3, 0.004, 0.4), _mat(Color(0.95, 0.94, 0.9) if k % 3 else Color(0.95, 0.75, 0.7)), Vector3(0, 0.1 * k, 0))
	var red_letter := _box(Vector3(0.35, 0.78, -2.05), Vector3(0.28, 0.006, 0.18), _mat(Color(0.86, 0.1, 0.12)), Vector3(0, -0.3, 0))
	red_letter.name = "letter"
	var can := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.035
	cy.bottom_radius = 0.035
	cy.height = 0.13
	can.mesh = cy
	can.material_override = _mat(Color(0.1, 0.7, 0.3), 0.3)
	can.position = Vector3(0.25, 0.83, -1.35)
	add_child(can)
	for k in 4:
		var w := _box(Vector3(-0.6 + k * 0.3, 0.77, -2.15), Vector3(0.7, 0.012, 0.012), _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 0.4 * k - 0.6, 0))
		w.name = "wire%d" % k
	# лампа
	_box(Vector3(-1.0, 1.0, -1.5), Vector3(0.04, 0.5, 0.04), _mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0, 0.3))
	_box(Vector3(-0.92, 1.24, -1.5), Vector3(0.18, 0.08, 0.14), _mat(Color(0.8, 0.1, 0.12)))
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 3.2
	lamp.spot_range = 3.5
	lamp.spot_angle = 55.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(-0.85, 1.2, -1.5)
	lamp.rotation = Vector3(-1.2, -0.6, 0)
	add_child(lamp)
	# стул и Пахан
	_box(Vector3(0, 0.45, -0.85), Vector3(0.5, 0.06, 0.5), _mat(Color(0.1, 0.1, 0.12)))
	_box(Vector3(0, 0.75, -0.6), Vector3(0.5, 0.6, 0.06), _mat(Color(0.1, 0.1, 0.12)))
	pahan = Rig.new()
	add_child(pahan)
	pahan.setup("res://assets/models/pahan.glb", 1.85, RaceVisual.clips(), true, -1.0, "race_pahan")
	pahan.position = Vector3(-0.02, 0.06, -0.95)
	pahan.rotation.y = PI
	pahan.play("RideBoost", 0.0)            # сидит, подавшись к столу
	# камера: из-за плеча — стол, телефон, окно
	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.position = Vector3(-1.5, 2.05, 1.55)             # слева сзади: Пахан — в правой, свободной от панели половине
	cam.look_at(Vector3(0.55, 0.95, -1.5), Vector3.UP)
	cam.current = true

# ---------------- жизнь комнаты ----------------
func _on_note(text: String, kind: String) -> void:
	ui.notify(text, kind)
	buzz_t = 0.6
	phone_screen.emission_energy_multiplier = 2.4
	phone_screen.albedo_color = Color(1.0, 0.4, 0.35) if kind == "bad" or kind == "warn" else (Color(0.5, 1.0, 0.6) if kind == "money" else Color(0.9, 0.95, 1.0))
	phone_screen.emission = phone_screen.albedo_color
	match kind:
		"money":
			snd.play("money")
		"bad":
			snd.play("alert")
		"warn":
			snd.play("alert", 0.85)
		_:
			snd.play("notify")
	if kind == "money":
		react("money")
	elif kind == "bad":
		react("bad")

## реакции Пахана: деньги — руки вверх, плохо — схватился за голову
func react(kind: String) -> void:
	if react_t > 0.0 and kind != "money":
		return
	react_t = 1.4
	match kind:
		"money":
			pahan.play_for("Rage", 1.2, 0.08)
		"bad":
			pahan.play_for("Hit", 0.9, 0.08)
		"call":
			pahan.play_for("RideJump", 0.9, 0.08)

func _process(dt: float) -> void:
	t += dt
	if buzz_t > 0.0:
		buzz_t -= dt
		phone.position.x = 0.55 + sin(t * 90.0) * 0.003
		if buzz_t <= 0.0:
			phone.position.x = 0.55
			phone_screen.emission_energy_multiplier = 0.3
	if react_t > 0.0:
		react_t -= dt
		if react_t <= 0.0:
			pahan.play("RideBoost" if econ.stress < 70 else "RideBrake", 0.3)
	# лампа мигает, когда стресс высокий
	flicker_t -= dt
	if flicker_t <= 0.0:
		flicker_t = randf_range(0.05, 0.25)
		var k := 1.0 - (randf() * 0.5 if econ.stress >= 70 and randf() < 0.3 else 0.0)
		lamp.light_energy = 3.2 * k
	laptop_mat.emission_energy_multiplier = 1.2 + sin(t * 2.0) * 0.15
	# камера чуть дышит
	cam.position = Vector3(-1.5 + sin(t * 0.3) * 0.02, 2.05 + sin(t * 0.5) * 0.01, 1.55)

## музыка: свой лоу-фай комнаты (loc_ml, tools/godot-music.cjs); слой drive (бит и бас) — когда горит срок или стресс
func music_set() -> String:
	return "loc_ml"

func music_layers() -> Array:
	return [0.75, tension()]

## фон комнаты: холодильник, улица за окном (amb_ml)
func bed_set() -> String:
	return "ml"

## напряжение 0…1: платёж сегодня или завтра, просрочка, стресс от 70
func tension() -> float:
	var k := 0.0
	for l in econ.loans:
		var L: Dictionary = l
		if String(L.get("status", "")) == "closed":
			continue
		if int(L.get("overdue", 0)) > 0:
			return 1.0
		if int(L.get("due", 99)) - econ.day <= 1:
			k = maxf(k, 0.8)
	if econ.stress >= 70:
		k = maxf(k, 1.0 if econ.stress >= 85 else 0.7)
	return k

## отклик на изменения экономики: деньги пришли — монеты, долг уменьшился — печать, стресс вырос — сердце
var _last := {}
func _feel() -> void:
	var now := {"money": econ.money, "debt": econ.total_debt(), "stress": econ.stress}
	if not _last.is_empty():
		if int(now["money"]) > int(_last["money"]):
			snd.play("coins")
		if float(now["debt"]) < float(_last["debt"]) - 0.5:
			snd.play("stamp")
		elif float(now["debt"]) > float(_last["debt"]) + 0.5:
			snd.play("loan")
		if int(now["stress"]) >= int(_last["stress"]) + 5:
			snd.play("stress")
	_last = now

func quit_to_menu() -> void:
	save()
	if main != null:
		main.end_minigame(3)
