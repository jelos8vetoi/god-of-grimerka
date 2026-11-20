## ПАХАН НАБРАЛ МИКРОЗАЙМОВ — корень мини-игры (сцена scenes/microloans/microloans.tscn, main.minigame).
## Своя 3D-комната: ночь, стол, потрёпанный ноутбук, телефон с уведомлениями, калькулятор, квитанции, письма,
## энергетик, провода, старый монитор, лампа; за окном двор с панельками и фонарём. Пахан — настоящая модель
## (pahan.glb), сидит за столом и реагирует. Свой свет, камера, окружение, экономика (ml_economy), интерфейс
## (ml_ui), сохранение (ml_save). Основная игра (game.gd) не запускается.
class_name MicroloansRoot
extends Node3D

var main
var econ := MLEconomy.new()
var career := MLCareer.new()        # прокачка и бизнесы — переживают недели (ml_career.gd)
var ui: MLUI
var cam: Camera3D
var pahan: Rig
var phone: MeshInstance3D
var phone_screen: StandardMaterial3D
var lamp: SpotLight3D
var monitor_mat: StandardMaterial3D
var laptop_mat: Material
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
	MLSave.load_career(career)
	econ.career = career
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
		_feel()
		dirty = true)                       # любое изменение денег, долгов и заказов сохраняется сразу (см. _save_tick)

## новая игра или продолжение
func begin(load_save: bool) -> void:
	if load_save and MLSave.load_run(econ):
		# вышел из игры посреди подработки — заказ брошен: действие потрачено, оплаты нет
		econ.job_abandon()
	else:
		# новая игра поверх идущей недели — неделя брошена: это «яма» с последствиями, а не бесплатный сброс долгов
		if MLSave.has_run() and MLSave.load_run(econ):
			econ.surrender()
		econ.new_game(int(Time.get_ticks_usec() % 2147483647))
		ui.intro()
	ui.refresh()
	ui.show_phase()
	desk_refresh()
	biz_visuals()

func save() -> void:
	dirty = false
	MLSave.save_run(econ)

## Сохранение после каждого изменения, а не только между фазами: закрыть игру посреди дня и «переиграть»
## неудачную подработку или взятый займ нельзя. Пишем не чаще раза в полсекунды.
var dirty := false
var save_cd := 0.0
func _save_tick(dt: float) -> void:
	save_cd = maxf(0.0, save_cd - dt)
	if dirty and save_cd <= 0.0:
		save_cd = 0.5
		save()

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
	env.ambient_light_color = Color(0.4, 0.42, 0.55)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.07)
	env.fog_density = 0.015
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# стены, пол, потолок: грязно-белые обои с узором, тёмный линолеум, плинтус
	var wall := MGProps._m(Color(0.66, 0.63, 0.57), 0.95, 0.0, 1, 1.4)
	var floor_m := MGProps._m(Color(0.22, 0.17, 0.13), 0.8, 0.0, 2, 1.0)
	_box(Vector3(0, -0.05, 0), Vector3(8, 0.1, 8), floor_m)
	_box(Vector3(0, 1.5, -2.4), Vector3(8, 3.2, 0.1), wall)
	_box(Vector3(-3.0, 1.5, 0), Vector3(0.1, 3.2, 8), wall)
	_box(Vector3(3.0, 1.5, 0), Vector3(0.1, 3.2, 8), wall)
	_box(Vector3(0, 3.1, 0), Vector3(8, 0.1, 8), _mat(Color(0.42, 0.41, 0.38)))
	for x in [-2.94, 2.94]:
		_box(Vector3(x, 0.05, 0), Vector3(0.04, 0.1, 8), MGProps.mat("wood_dark"))
	_box(Vector3(0, 0.05, -2.34), Vector3(6, 0.1, 0.04), MGProps.mat("wood_dark"))
	# окно с ночным двором
	var win := _at(Vector3(1.3, 1.8, -2.34))
	MGProps.window(win, 1.5, 1.15)
	var yard := Node3D.new()
	yard.position = Vector3(1.3, 0, -9)
	add_child(yard)
	if RaceProps.has("khrushchevka"):
		RaceProps.spawn("khrushchevka", yard, Vector3(-4, -4, -14), 0.0, 1.0, false)
		RaceProps.spawn("panel_tower", yard, Vector3(14, -4, -20), -0.4, 1.0, false)
		RaceProps.spawn("street_lamp", yard, Vector3(2.5, -4, -2), 0.6, 1.0, false)
		RaceProps.spawn("birch_tree", yard, Vector3(-2, -4, -4), 0.3, 1.0, false)
	env_ref = env
	var street := OmniLight3D.new()
	street.light_color = Color(1.0, 0.62, 0.3)
	street.light_energy = 2.4
	street.omni_range = 14.0
	street.position = Vector3(3.5, 2.2, -9)
	add_child(street)
	street_l = street
	# фары проезжающей машины: свет проходит за окном и скользит по стене
	car_l = OmniLight3D.new()
	car_l.light_color = Color(1.0, 0.95, 0.85)
	car_l.light_energy = 0.0
	car_l.omni_range = 9.0
	car_l.position = Vector3(-8, 1.2, -5.5)
	add_child(car_l)
	var moon := DirectionalLight3D.new()
	sky_l = moon
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.25
	moon.rotation = Vector3(-0.6, 0.4, 0)
	add_child(moon)
	# мебель: стол, кресло, шкаф, холодильник, полка, ковёр, коробки (свои модели владельца или кодом)
	MGModels.wide_desk(self, Vector3(0, 0, -1.75), 0.0, 2.2, 0.9, 0.782, func(r): MGProps.desk(r, 2.2, 0.9))
	armchair = MGModels.spawn("ml_armchair", self, Vector3(2.1, 0, -0.5), -2.2, Vector3(0.9, 1.0, 0.9), func(r): MGProps.armchair(r))
	# диван-кровать (если есть модель) — слева от стола под полкой; шкаф тогда отъезжает вдоль стены ближе к камере
	sofa = MGModels.has("ml_sofa_bed")
	if sofa:
		MGModels.spawn("ml_sofa_bed", self, Vector3(-2.02, 0, -1.56), 0.0, Vector3(1.7, 1.07, 1.6), func(_r): pass)
	MGModels.spawn("ml_wardrobe", self, Vector3(-2.6, 0, 0.3 if sofa else -1.3), PI / 2, Vector3(1.2, 2.0, 0.6), func(r): MGProps.wardrobe(r))
	MGModels.spawn("ml_fridge", self, Vector3(2.55, 0, -1.95), -PI / 2 + 0.2, Vector3(0.6, 1.5, 0.6), func(r): MGProps.fridge(r))
	shelf = _at(Vector3(-1.5, 1.25, -2.22))
	MGProps.shelf(shelf)
	MGProps.rug(_at(Vector3(0.4, 0, -0.3), 0.1), 2.4, 1.6)
	for k in 3:
		MGProps.carton(_at(Vector3(-2.3 + k * 0.1, k * 0.38, 1.7 if sofa else 0.7), 0.2 * k), Vector3(0.55, 0.38, 0.45), ["ВЕЩИ", "ПРОВОДА", ""][k])
	# стол: ноутбук, телефон, калькулятор, счета, деньги, кошелёк, ключи, кружка, еда, лампа, провода
	var lp := _at(Vector3(-0.15, 0.785, -1.7), 0.1)
	lp.scale = Vector3.ONE * 1.6
	var ld: Dictionary = {}
	if MGModels.has("ml_laptop"):
		var lr := MGModels.spawn("ml_laptop", lp, Vector3.ZERO, 0.0, Vector3(0.36, 0.25, 0.26), func(r): pass)
		laptop_mat = MGProps.screen_mat(Color(0.55, 0.8, 1.0), 1.0, 1.0, 1.0)
		# экран модели тёмный — поверх стекла светится «приложение займов» (разметка в единицах модели)
		MGProps.quad(lr, MGModels.local(lr, Vector3(0.078, 0.469, -0.281)), Vector2(0.68, 0.41) * float(lr.get_meta("k")), laptop_mat)
	else:
		ld = MGProps.laptop(lp)
		laptop_mat = ld["screen"]
	phone = _box(Vector3(0.55, 0.79, -1.45), Vector3(0.09, 0.012, 0.17), MGProps.mat("plastic_black"), Vector3(0, 0.3, 0))
	phone_screen = _mat(Color(0.9, 0.95, 1.0), 0.2, 0.3)
	var scr := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.08, 0.004, 0.155)
	scr.mesh = sm
	scr.material_override = phone_screen
	scr.position.y = 0.008
	phone.add_child(scr)
	MGProps.calculator(_at(Vector3(0.88, 0.785, -1.62), -0.25))
	bills_root = _at(Vector3(0.78, 0.785, -2.0), 0.1)
	cash_root = _at(Vector3(-0.72, 0.785, -1.45), 0.3)
	MGProps.wallet(_at(Vector3(0.28, 0.785, -1.33), 0.6))
	MGProps.keys(_at(Vector3(0.42, 0.785, -1.28), 1.2))
	MGProps.mug(_at(Vector3(-0.62, 0.785, -2.0), 0.5))
	MGProps.food(_at(Vector3(0.38, 0.785, -2.05), -0.3))
	var dl := MGProps.desk_lamp(_at(Vector3(-0.95, 0.785, -2.0), 0.7))
	for k in 4:
		MGProps.cable(self, Vector3(-0.15 + k * 0.08, 0.79, -1.95), Vector3(-0.6 + k * 0.3, 0.02, -2.3), 0.3, 0.008)
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 3.2
	lamp.spot_range = 3.5
	lamp.spot_angle = 55.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(-0.85, 1.2, -1.75)
	lamp.rotation = Vector3(-1.2, -0.6, 0)
	add_child(lamp)
	var room_l := OmniLight3D.new()
	room_l.position = Vector3(0.8, 2.6, 0.2)
	room_l.light_energy = 0.5
	room_l.omni_range = 6.0
	room_l.light_color = Color(1.0, 0.85, 0.7)
	add_child(room_l)
	room_light = room_l
	# стул и Пахан
	MGProps.office_chair(_at(Vector3(0, 0, -0.85), PI))
	pahan = Rig.new()
	add_child(pahan)
	pahan.setup("res://assets/models/pahan.glb", 1.85, RaceVisual.clips(), true, -1.0, "race_pahan")
	pahan.position = Vector3(-0.02, 0.06, -0.95)
	pahan.rotation.y = PI
	pahan.play("RideBoost", 0.0)            # сидит, подавшись к столу
	pahan_home = pahan.transform
	# камера: из-за плеча — стол, телефон, окно; Пахан справа, слева — карточки интерфейса
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.look_at_from_position(Vector3(-1.2, 2.15, 2.5), Vector3(-1.35, 1.0, -1.4), Vector3.UP)
	cam.current = true
	cam_base = cam.transform
	biz_visuals()
	desk_refresh()

var armchair: Node3D
var sofa := false               # в комнате стоит диван-кровать (ml_sofa_bed.glb): часть вещей сдвинута
var shelf: Node3D
var bills_root: Node3D
var cash_root: Node3D
var room_light: OmniLight3D
var pahan_home := Transform3D()
var cam_base := Transform3D()
var biz_root: Node3D
var up_root: Node3D
var rest_t := 0.0
# ---- живая комната ----
var env_ref: Environment
var street_l: OmniLight3D
var sky_l: DirectionalLight3D
var car_l: OmniLight3D
var car_t := 14.0               # через сколько за окном проедет машина
var car_k := -1.0               # идёт проезд: 0..1
var idle_t := 7.0               # через сколько Пахан сам сменит позу
var spam_t := 40.0              # через сколько придёт случайное сообщение
var lamp_base := 3.2            # яркость настольной лампы по времени суток (мигание — поверх)
var look_yaw := 0.0             # куда Пахан повернулся (к телефону, к окну)
var look_t := 0.0
## Время суток по фазе дня: [цвет неба, свет с улицы (цвет, сила), фонарь, верхний свет, лампа, общий свет]
const DAYLIGHT := {
	"morning": [Color(0.5, 0.58, 0.68), Color(1.0, 0.93, 0.8), 1.0, 0.0, 0.85, 1.4, 0.55],
	"day": [Color(0.55, 0.68, 0.85), Color(1.0, 0.99, 0.94), 1.35, 0.0, 1.0, 0.9, 0.7],
	"evening": [Color(0.5, 0.27, 0.18), Color(1.0, 0.55, 0.3), 0.7, 1.4, 0.55, 3.0, 0.4],
	"night": [Color(0.02, 0.03, 0.06), Color(0.5, 0.6, 0.9), 0.25, 2.4, 0.3, 3.2, 0.25],
}

func _at(p: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	return n

## стол показывает, что творится: стопка счетов = долги (красные — просроченные), пачки денег = деньги на руках
func desk_refresh() -> void:
	if bills_root == null:
		return
	for c in bills_root.get_children():
		c.queue_free()
	for c in cash_root.get_children():
		c.queue_free()
	var act := econ.active()
	var n := act.size()
	for k in n:
		var L: Dictionary = act[k]
		var bill := MGProps.box(bills_root, Vector3(randf_range(-0.02, 0.02), 0.002 + k * 0.004, randf_range(-0.02, 0.02)), Vector3(0.21, 0.003, 0.29), MGProps.mat("paper") if L["status"] != "overdue" else MGProps.mat("red"), Vector3(0, randf_range(-0.3, 0.3), 0))
		bill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stacks := clampi(econ.money / 3000, 0, 12)
	for k in stacks:
		var st := Node3D.new()
		st.position = Vector3(float(k % 3) * 0.17, float(k / 3) * 0.03, float(k / 6) * 0.09)
		st.rotation.y = randf_range(-0.2, 0.2)
		cash_root.add_child(st)
		MGProps.cash(st, 3)

## бизнесы и покупки видно в комнате: инструменты и приставка — мастерская, вторая ТЯГА — служба уборки,
## коробки — доставка, колонка и микшер — студия, ящик хлама — склад; уровень — больше вещей
func biz_visuals() -> void:
	if shelf == null:
		return
	if biz_root != null:
		biz_root.queue_free()
	biz_root = Node3D.new()
	add_child(biz_root)
	var C := career
	var lv := func(id): return C.biz_level(id)
	if int(lv.call("workshop")) > 0:
		var n := Node3D.new()
		n.position = Vector3(-1.75, 1.66, -2.22)
		biz_root.add_child(n)
		MGProps.tools(n)
		if int(lv.call("workshop")) >= 2:
			var c2 := Node3D.new()
			c2.position = Vector3(-1.35, 1.66, -2.22)
			c2.scale = Vector3.ONE * 0.8
			biz_root.add_child(c2)
			MGModels.spawn("ml_job_console", c2, Vector3.ZERO, 0.3, Vector3(0.32, 0.08, 0.22), func(r): MGProps.console_open(r))
	if int(lv.call("cleaning")) > 0:
		var ps := load("res://assets/models/tyaga812.glb") as PackedScene
		if ps != null:
			var t2 := ps.instantiate() as Node3D
			biz_root.add_child(t2)
			t2.position = Vector3(-1.45, 0, 0.35) if sofa else Vector3(-2.2, 0, -0.2)
			t2.rotation.y = 0.8
			t2.scale = Vector3.ONE * 0.55
	if int(lv.call("delivery")) > 0 and MGModels.has("ml_job_parcel_cart"):
		MGModels.spawn("ml_job_parcel_cart", biz_root, Vector3(-1.1, 0, 1.0), 0.6, Vector3(0.75, 1.1, 0.6), func(_r): pass)
	elif int(lv.call("delivery")) > 0:
		for k in mini(3, int(lv.call("delivery")) + 1):
			var b := Node3D.new()
			b.position = Vector3(-1.2 + k * 0.05, k * 0.3, 0.9)
			b.rotation.y = 0.3 * k
			biz_root.add_child(b)
			MGProps.carton(b, Vector3(0.45, 0.3, 0.35), "ЗАКАЗ")
	if int(lv.call("studio")) > 0:
		var m := Node3D.new()
		m.position = Vector3(-1.5, 1.26, -2.2)
		m.scale = Vector3.ONE * 0.6
		biz_root.add_child(m)
		MGModels.spawn("ml_job_mixer", m, Vector3.ZERO, 0.0, Vector3(0.6, 0.42, 0.52), func(r): MGProps.mixer(r))
		if MGModels.has("ml_job_amp"):
			MGModels.spawn("ml_job_amp", biz_root, Vector3(1.5, 0, -2.05), 0.25, Vector3(0.5, 0.5, 0.35), func(_r): pass)
		var sp := Node3D.new()
		sp.position = Vector3(1.9, 0, -2.0)
		sp.scale = Vector3.ONE * 0.75
		biz_root.add_child(sp)
		MGProps.speaker(sp)
	if int(lv.call("warehouse")) > 0:
		var j := Node3D.new()
		j.position = Vector3(1.4, 0, 0.9)
		biz_root.add_child(j)
		MGModels.spawn("ml_job_junk_crate", j, Vector3.ZERO, 0.4, Vector3(0.65, 0.72, 0.62), func(r): MGProps.junk_item(r, 2))
	# сотрудники — силуэты на фото-доске у шкафа (сколько наняли)
	var staff := C.staff_total()
	for k in mini(staff, 10):
		var ph := MGProps.box(biz_root, Vector3(-2.93, 1.4 + float(k / 5) * 0.18, (-2.1 if sofa else -0.6) + float(k % 5) * 0.16), Vector3(0.01, 0.14, 0.12), MGProps.mat("paper"))
		ph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# покупки магазина — на столе
	if up_root != null:
		up_root.queue_free()
	up_root = Node3D.new()
	add_child(up_root)
	for u in econ.upgrades:
		desk_item(String(u), false)

func desk_item(u: String, pop := true) -> void:
	if up_root == null:
		return
	var n := Node3D.new()
	up_root.add_child(n)
	match u:
		"scanner":
			n.position = Vector3(0.95, 0.785, -1.95)
			MGProps.box(n, Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.2), MGProps.mat("plastic"))
			MGProps.box(n, Vector3(0, 0.061, 0), Vector3(0.26, 0.002, 0.16), MGProps.glow(Color(0.4, 1.0, 0.5), 0.8))
		"slot", "talk":
			n.position = Vector3(-0.45 if u == "slot" else -0.35, 0.785, -1.25)
			MGProps.box(n, Vector3(0, 0.012, 0), Vector3(0.15, 0.024, 0.21), MGProps.mat("red") if u == "slot" else MGProps.mat("blue_paint"), Vector3(0, 0.3, 0))
		"contacts":
			n.position = Vector3(0.62, 0.785, -1.75)
			MGProps.box(n, Vector3(0, 0.02, 0), Vector3(0.1, 0.04, 0.14), MGProps.mat("blue_paint"))
		"scooter":
			n.position = Vector3(1.6, 0, 0.8)
			n.rotation.y = 0.5
			MLThumbs.build("up_scooter", n)
		"phone":
			phone.material_override = MGProps.mat("red")
		"calc":
			n.position = Vector3(1.0, 0.785, -1.4)
			MGProps.calculator(n)
	if pop:
		n.scale = Vector3.ONE * 0.1
		n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## деньги пришли — купюры вылетают из ноутбука и падают на стол
func money_burst(n: int) -> void:
	for k in clampi(n, 1, 8):
		var b := Node3D.new()
		add_child(b)
		b.position = Vector3(-0.15, 1.05, -1.75)
		MGProps.bill_note(b)
		var to := cash_root.global_position + Vector3(randf_range(-0.15, 0.25), 0.05 + k * 0.004, randf_range(-0.1, 0.12))
		var from := b.position
		var mid := (from + to) * 0.5 + Vector3(0, 0.35, 0)
		var tw := b.create_tween()
		tw.tween_interval(0.06 * k)
		tw.tween_method(func(u: float):
			b.position = from.lerp(mid, u).lerp(mid.lerp(to, u), u)
			b.rotation = Vector3(sin(u * 9.0) * 0.6, u * 4.0, cos(u * 7.0) * 0.4), 0.0, 1.0, 0.6)
		tw.tween_callback(b.queue_free)
	get_tree().create_timer(0.75, true, false, true).timeout.connect(desk_refresh)

## долг уменьшился — верхний счёт улетает со стопки
func bill_off() -> void:
	if bills_root == null or bills_root.get_child_count() == 0:
		return
	var top := bills_root.get_child(bills_root.get_child_count() - 1) as Node3D
	var tw := top.create_tween().set_parallel(true)
	tw.tween_property(top, "position", top.position + Vector3(0.4, 0.5, 0.3), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(top, "rotation", Vector3(1.2, 2.0, 0.5), 0.5)
	tw.chain().tween_callback(desk_refresh)

## отдых: свет теплеет, Пахан пересаживается в кресло, вздыхает; потом обратно за стол
func rest_anim() -> void:
	rest_t = 3.2
	snd.play("sigh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(room_light, "light_color", Color(1.0, 0.7, 0.45), 0.6)
	tw.tween_property(lamp, "light_energy", 1.2, 0.6)
	pahan.global_transform = armchair.global_transform.translated_local(Vector3(0, 0.1, 0.05)).rotated_local(Vector3.UP, PI)
	pahan.play("RideBrake", 0.3)

# ---------------- жизнь комнаты ----------------
func _on_note(text: String, kind: String) -> void:
	ui.notify(text, kind)
	buzz_t = 0.6
	glance(-0.42, 1.4)                        # телефон загудел — Пахан косится на него
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
		"level", "milestone":
			pass                                # свой звук — у баннера (MLUI._banner)
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

## Комната живёт сама: свет меняется по времени суток, за окном проезжают машины, Пахан меняет позу,
## косится на телефон и в окно, на телефон приходят случайные сообщения.
func _life(dt: float) -> void:
	# --- время суток: плавно к значениям фазы ---
	var D: Array = DAYLIGHT.get(econ.phase if econ.ending == "" else "night", DAYLIGHT["night"])
	var k := 1.0 - exp(-1.2 * dt)
	if env_ref != null:
		env_ref.background_color = env_ref.background_color.lerp(D[0], k)
		env_ref.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_ref.ambient_light_color = env_ref.ambient_light_color.lerp((D[1] as Color).lerp(Color(1, 1, 1), 0.4), k)
		env_ref.ambient_light_energy = lerpf(env_ref.ambient_light_energy, float(D[6]), k)
	if sky_l != null:
		sky_l.light_color = sky_l.light_color.lerp(D[1], k)
		sky_l.light_energy = lerpf(sky_l.light_energy, float(D[2]), k)
	if street_l != null:
		street_l.light_energy = lerpf(street_l.light_energy, float(D[3]), k)
	if rest_t <= 0.0 and room_light != null:
		room_light.light_energy = lerpf(room_light.light_energy, float(D[4]), k)
	lamp_base = lerpf(lamp_base, float(D[5]), k)
	# --- машина за окном ---
	if car_k >= 0.0:
		car_k += dt / 2.4
		car_l.position.x = lerpf(-8.0, 9.0, car_k)
		car_l.light_energy = sin(clampf(car_k, 0.0, 1.0) * PI) * (2.6 if econ.phase in ["evening", "night"] else 0.5)
		if car_k >= 1.0:
			car_k = -1.0
			car_l.light_energy = 0.0
	else:
		car_t -= dt
		if car_t <= 0.0:
			car_t = randf_range(16.0, 38.0)
			car_k = 0.0
	# --- Пахан сам меняет позу: откинулся, потянулся, покосился на телефон или в окно ---
	var busy: bool = ui != null and ui.overlay != null and is_instance_valid(ui.overlay)
	look_t = maxf(0.0, look_t - dt)
	var want_yaw := look_yaw if look_t > 0.0 else 0.0
	if rest_t <= 0.0:
		pahan.rotation.y = lerp_angle(pahan.rotation.y, PI + want_yaw, 1.0 - exp(-5.0 * dt))
	idle_t -= dt
	if idle_t <= 0.0 and react_t <= 0.0 and rest_t <= 0.0 and not busy:
		idle_t = randf_range(6.0, 13.0)
		match randi() % 4:
			0:
				pahan.play("RideSit", 0.5)              # выпрямился
				react_t = randf_range(2.0, 3.5)
			1:
				pahan.play("RideBrake", 0.5)            # откинулся
				react_t = randf_range(1.6, 2.6)
			2:
				glance(-0.42, 1.8)                      # на телефон
			3:
				glance(0.5, 2.2)                        # в окно
	# --- случайное сообщение на телефон (в проверках выключено: экраны должны быть одинаковыми) ---
	if not quiet and not busy and econ.ending == "":
		spam_t -= dt
		if spam_t <= 0.0:
			spam_t = randf_range(50.0, 95.0)
			ui.notify(String(MLData.SPAM[randi() % MLData.SPAM.size()]), "info")
			buzz_t = 0.6
			phone_screen.emission_energy_multiplier = 2.4
			phone_screen.albedo_color = Color(0.9, 0.95, 1.0)
			phone_screen.emission = phone_screen.albedo_color
			snd.play("notify")
			glance(-0.42, 1.6)

## Пахан поворачивается: yaw > 0 — к окну, < 0 — к телефону
func glance(yaw: float, sec: float) -> void:
	look_yaw = yaw
	look_t = sec

func _process(dt: float) -> void:
	t += dt
	_save_tick(dt)
	_life(dt)
	if buzz_t > 0.0:
		buzz_t -= dt
		phone.position.x = 0.55 + sin(t * 90.0) * 0.003
		if buzz_t <= 0.0:
			phone.position.x = 0.55
			phone_screen.emission_energy_multiplier = 0.3
	if react_t > 0.0:
		react_t -= dt
		if react_t <= 0.0 and rest_t <= 0.0:
			pahan.play("RideBoost" if econ.stress < 70 else "RideBrake", 0.3)
	if rest_t > 0.0:
		rest_t -= dt
		if rest_t <= 0.0:
			pahan.transform = pahan_home
			pahan.play("RideBoost", 0.3)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(room_light, "light_color", Color(1.0, 0.85, 0.7), 0.8)
	# лампа мигает, когда стресс высокий
	flicker_t -= dt
	if flicker_t <= 0.0:
		flicker_t = randf_range(0.05, 0.25)
		var k := 1.0 - (randf() * 0.5 if econ.stress >= 70 and randf() < 0.3 else 0.0)
		if rest_t <= 0.0:
			lamp.light_energy = lamp_base * k
	if laptop_mat is ShaderMaterial:
		(laptop_mat as ShaderMaterial).set_shader_parameter("energy", 1.1 + sin(t * 2.0) * 0.12)
	# камера чуть дышит
	cam.transform = cam_base.translated(Vector3(sin(t * 0.3) * 0.02, sin(t * 0.5) * 0.01, 0.0))

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
			money_burst(int(now["money"] - _last["money"]) / 1000 + 1)
		elif int(now["money"]) < int(_last["money"]):
			desk_refresh()
		if float(now["debt"]) < float(_last["debt"]) - 0.5:
			snd.play("stamp")
			bill_off()
		elif float(now["debt"]) > float(_last["debt"]) + 0.5:
			snd.play("loan")
			desk_refresh()
		if int(now["stress"]) >= int(_last["stress"]) + 5:
			snd.play("stress")
	_last = now

func quit_to_menu() -> void:
	save()
	if main != null:
		main.end_minigame(3)
