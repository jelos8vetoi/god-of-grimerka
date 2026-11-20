## УБОРКА НА ТЯГЕ-812 — 3D-аркада: Пахан ведёт настоящую ТЯГУ-812 (tyaga812.glb) по помещению. Пять помещений
## по уровню заказа (квартира, подъезд, офис, склад, мастерская) — своя геометрия, мебель, количество мусора и
## проводов. Задание недели выбирается случайно: убрать всё, только крупное, не задеть чужую технику, найти
## потерянные ценные вещи (подъезжать медленно — иначе щётка их бьёт), помещение в проводах.
## Мусор — настоящие модели разного веса: щётка притягивает, втягивает с пылью, тяжёлому нужна мощность.
## Шланг идёт от розетки: длина ограничена (натянут — краснеет и держит), вокруг мебели наматывается — запутался,
## стоп. Провода соседей на полу — переехал колесом: зацепил. Контейнер полный — к ведру у двери (выгрузка сама).
## Управление: W/S — газ и назад, A/D — поворот, Shift — турбо (если открыто). Навыки и снаряжение — из карьеры.
class_name MLJobPodezd
extends MLJob3D

const LAYOUTS := [
	{"name": "КВАРТИРА", "w": 9.0, "d": 7.0, "trash": 34, "cables": 3, "wall": Color(0.62, 0.58, 0.5), "floor": Color(0.35, 0.26, 0.18)},
	{"name": "ПОДЪЕЗД", "w": 14.0, "d": 5.0, "trash": 42, "cables": 4, "wall": Color(0.36, 0.46, 0.42), "floor": Color(0.3, 0.29, 0.27)},
	{"name": "ОФИС", "w": 12.0, "d": 9.0, "trash": 44, "cables": 7, "wall": Color(0.7, 0.7, 0.68), "floor": Color(0.25, 0.27, 0.32)},
	{"name": "СКЛАД", "w": 14.0, "d": 10.0, "trash": 50, "cables": 4, "wall": Color(0.45, 0.45, 0.47), "floor": Color(0.32, 0.32, 0.31)},
	{"name": "МАСТЕРСКАЯ", "w": 12.0, "d": 10.0, "trash": 52, "cables": 8, "wall": Color(0.5, 0.42, 0.34), "floor": Color(0.24, 0.22, 0.2)},
]
const TASKS := {
	"all": "Убери всё помещение",
	"big": "Убери только крупный мусор — мелочь потом",
	"fragile": "Не задень чужую технику (белая рамка)",
	"valuables": "Найди потерянные ценные вещи — подъезжай медленно",
	"cables": "Тут всё в проводах. Не цепляй.",
}

var rng := RandomNumberGenerator.new()
var L: Dictionary
var task := "all"
var tyaga: Node3D
var model: Node3D
var pos := Vector3.ZERO
var yaw := 0.0
var speed := 0.0
var steer_k := 0.0
var trash: Array = []           # {node, w (вес), big, val (ценная), got, pull}
var obst: Array = []            # {c: Vector2, h: Vector2 (полуразмеры), fragile, node, hit}
var cables: Array = []          # [Vector2 a, Vector2 b]
var hose_pts: Array = []        # Vector3 (верле)
var hose_prev: Array = []
var hose_mesh: ImmediateMesh
var hose_mat: StandardMaterial3D
var socket := Vector3.ZERO
var bin_p := Vector3.ZERO
var hose_len := 7.0
var tension := 0.0
var contacts := 0
var tangle_cd := 0.0
var stuck_t := 0.0
var tangles := 0
var cable_hits := 0
var bumps := 0
var fragile_hits := 0
var broke_val := 0
var load := 0.0
var cap := 30.0
var combo := 0
var combo_t := 0.0
var best_combo := 0
var turbo_t := 0.0
var turbo_cd := 0.0
var hum: AudioStreamPlayer
var need := 0.0
var got_w := 0.0
var bot_target := -1
var bot_stall := 0.0
var bot_wob := 0.0
var bot_pause := 0.0
var bot_idle := 0.0
var bot_back := 0.0
var bot_back_turn := 1.0
var bot_skip := {}
var rng_bot := RandomNumberGenerator.new()
var wash := false               # насадка: false — щётка (мусор), true — мойка (пятна)
var stains_all := 0
var stains_done := 0
var foam_t := 0.0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 3
	L = LAYOUTS[clampi(tier - 1, 0, LAYOUTS.size() - 1)]
	var opts := ["all", "big", "cables"]
	if tier >= 2:
		opts.append("fragile")
	if tier >= 3:
		opts.append("valuables")
	task = opts[rng.randi() % opts.size()]
	keys = [["W/S", "газ, назад"], ["A/D", "руль"], ["Q", "насадка"]] + ([["Shift", "турбо"]] if cv("tyaga_turbo") > 0.0 else [])
	base_setup(f, sf, stress, "УБОРКА НА ТЯГЕ-812 · %s" % L["name"], "", 50.0 + tier * 6.0)
	setup_3d(Color(0.05, 0.05, 0.06), Color(0.55, 0.55, 0.6), 0.45)
	hose_len = 7.0 + float(L["w"]) * 0.35 + cv("tyaga_hose") * 6.0 + (2.0 if eq("tyaga") >= 2 else 0.0)
	cap = (38.0 + 4.0 * tier) * (1.0 + 0.5 * float(eq("tyaga") >= 1)) + 8.0 * eq("tyaga")
	_level()
	time_left += 2.0 * stains_all
	time_max = time_left
	_spawn_tyaga()
	hum = AudioStreamPlayer.new()
	hum.stream = Tyaga._synth_hum()
	hum.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	hum.volume_db = -16.0
	add_child(hum)
	if bot < 0.0:
		hum.play()
	task_l.text = TASKS[task]

# ---------------- уровень ----------------
func _level() -> void:
	var w: float = L["w"]
	var d: float = L["d"]
	var wall := MGProps._m(L["wall"], 0.9, 0.0, 1, 1.2)
	var fl := MGProps._m(L["floor"], 0.8, 0.0, 2, 1.5)
	room_box(Vector3.ZERO, w, d, 2.8, wall, fl, true)
	sun(Vector3(-1.0, 0.5, 0), 0.6)
	light(Vector3(-w * 0.25, 2.6, 0), 1.2, w * 0.7)
	light(Vector3(w * 0.25, 2.6, 0), 1.0, w * 0.7)
	socket = Vector3(-w / 2 + 0.08, 0.3, d / 2 - 1.2)
	MGProps.box(world_root, socket, Vector3(0.04, 0.1, 0.12), MGProps.mat("plastic"))
	bin_p = Vector3(-w / 2 + 0.7, 0, d / 2 - 0.6)
	var bn := at(bin_p)
	MGProps.cyl(bn, Vector3(0, 0.3, 0), 0.3, 0.26, 0.6, MGProps.mat("green_paint"))
	MGProps.text(at(bin_p + Vector3(0, 0.75, 0.3)), "ведро", Vector3.ZERO, 26, Color(0.95, 0.9, 0.8))
	match int(tier):
		1:
			_furn(Vector3(-2.5, 0, -2.4), Vector2(0.9, 0.45), "ml_armchair", func(r): MGProps.armchair(r), 0.0)
			_furn(Vector3(0.5, 0, -2.6), Vector2(0.6, 0.4), "ml_job_old_tv", func(r): MGProps.crt(r), 0.0, true)
			_furn(Vector3(0.5, 0, 0.3), Vector2(0.8, 0.45), "", func(r): MGProps.party_table(r, 3), 0.0)
			_furn(Vector3(3.8, 0, -2.8), Vector2(0.6, 0.3), "ml_wardrobe", func(r): MGProps.wardrobe(r), 0.0)
			_furn(Vector3(3.9, 0, 1.5), Vector2(0.3, 0.3), "ml_fridge", func(r): MGProps.fridge(r), -PI / 2)
			MGProps.rug(at(Vector3(0.5, 0, 0.3)), 3.0, 2.2)
		2:
			for k in 4:
				_furn(Vector3(-5.5 + k * 3.6, 0, -2.2), Vector2(0.5, 0.25), "", func(r): MGProps.locker(r, 0.0, "КВ. %d" % (40 + k)), 0.0)
			_furn(Vector3(2.0, 0, 1.5), Vector2(0.5, 0.25), "", func(r): MGProps.janitor_cart(r), 0.3)
			_furn(Vector3(-2.0, 0, 1.6), Vector2(0.4, 0.4), "", func(r): MGProps.carton(r, Vector3(0.7, 0.5, 0.6), "КОЛЯСКА"), 0.2)
			MGProps.text(at(Vector3(0, 2.0, -2.44)), "ПОДЪЕЗД 3 · НЕ КУРИТЬ", Vector3.ZERO, 44, Color(0.85, 0.82, 0.75))
		3:
			for k in 6:
				var p := Vector3(-4.0 + float(k % 3) * 4.0, 0, -2.0 + float(k / 3) * 3.6)
				_furn(p, Vector2(0.8, 0.4), "ml_desk", func(r): MGProps.desk(r, 1.6, 0.8), 0.0, true)
				_furn(p + Vector3(0, 0.78, 0), Vector2(0.01, 0.01), "", func(r): MGProps.laptop(r), 0.0, true)
				_furn(p + Vector3(0, 0, 0.75), Vector2(0.3, 0.3), "", func(r): MGProps.office_chair(r), PI)
		4:
			for k in 3:
				_furn(Vector3(-4.0 + k * 4.0, 0, -3.6), Vector2(1.1, 0.35), "fn_mascot_shelf", func(r): MGProps.mascot_shelf(r, k), 0.0)
			for k in 5:
				_furn(Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-1, 3)), Vector2(0.4, 0.35), "", func(r): MGProps.carton(r, Vector3(0.8, 0.6, 0.7), "ПАЛЛЕТ"), rng.randf())
		_:
			for k in 3:
				_furn(Vector3(-3.5 + k * 3.5, 0, -3.5), Vector2(0.9, 0.4), "ml_desk", func(r): MGProps.desk(r, 1.8, 0.8), 0.0, true)
				_furn(Vector3(-3.5 + k * 3.5, 0.78, -3.5), Vector2(0.01, 0.01), "", func(r): MGProps.console_open(r), 0.3, true)
			_furn(Vector3(3.5, 0, 2.5), Vector2(0.7, 0.45), "fn_generator", func(r): MGProps.generator(r), -PI / 2)
			_furn(Vector3(-3.0, 0, 2.0), Vector2(0.45, 0.25), "", func(r): MGProps.janitor_cart(r), 0.0)
	# провода соседей: от розеток по полу
	var nc: int = int(L["cables"]) + (4 if task == "cables" else 0)
	for k in nc:
		var a := Vector2(rng.randf_range(-w / 2 + 1, w / 2 - 1), -d / 2 + 0.1 if k % 2 == 0 else d / 2 - 0.1)
		var b := a + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(1.5, d * 0.6) * (1.0 if k % 2 == 0 else -1.0))
		cables.append([a, b])
		MGProps.cable(world_root, Vector3(a.x, 0.02, a.y), Vector3(b.x, 0.02, b.y), -0.0, 0.02, MGProps.mat("rubber") if k % 3 else MGProps.mat("red_dark"))
		MGProps.box(world_root, Vector3(b.x, 0.03, b.y), Vector3(0.12, 0.05, 0.08), MGProps.mat("plastic"))      # вилка-удлинитель
	# мусор
	var n: int = int(L["trash"])
	for k in n:
		var p := Vector3(rng.randf_range(-w / 2 + 0.6, w / 2 - 0.6), 0, rng.randf_range(-d / 2 + 0.6, d / 2 - 0.6))
		if _blocked(Vector2(p.x, p.z), 0.25):
			continue
		var kind := rng.randi() % 10
		var big := kind >= 8
		var node := at(p, rng.randf() * TAU)
		var wgt := 1.0
		if big:
			wgt = 4.0
			if kind == 9 and MGModels.has("ml_job_trash_set"):
				MGModels.spawn("ml_job_trash_set", node, Vector3.ZERO, 0.0, Vector3(0.42, 0.26, 0.42), Callable())
			elif MGModels.has("ml_job_parcel_box"):
				MGModels.spawn("ml_job_parcel_box", node, Vector3.ZERO, 0.0, Vector3(0.32, 0.26, 0.28), Callable())
			else:
				MGProps.carton(node, Vector3(0.32, 0.22, 0.26), "")
		elif kind >= 5:
			wgt = 2.0
			MGProps.cyl(node, Vector3(0, 0.04, 0), 0.035, 0.035, 0.12, MGProps.mat("red") if kind % 2 else MGProps.mat("steel"), Vector3(PI / 2, 0, 0))
		else:
			MGProps.ball(node, Vector3(0, 0.035, 0), 0.05, MGProps.mat("paper") if kind % 2 else MGProps.mat("card"), Vector3(1, 0.7, 1.2))
		trash.append({"node": node, "w": wgt, "big": big, "val": false, "got": false, "pull": 0.0})
	if task == "valuables" or tier >= 4:
		for k in 3 + tier / 2:
			var p := Vector3(rng.randf_range(-w / 2 + 1, w / 2 - 1), 0, rng.randf_range(-d / 2 + 1, d / 2 - 1))
			var node := at(p)
			match k % 3:
				0: MGProps.phone(node)
				1: MGProps.wallet(node)
				_: MGProps.keys(node)
			var glint := MGProps.ball(node, Vector3(0, 0.08, 0), 0.025, MGProps.glow(Color(1.0, 0.85, 0.3), 3.0))
			glint.name = "glint"
			trash.append({"node": node, "w": 1.0, "big": false, "val": true, "got": false, "pull": 0.0})
	# пятна: въевшаяся грязь на полу. Щёткой оттирается вчетверо дольше, чем мойкой; на скорости — почти никак:
	# по пятну надо пройти медленно. Слой сходит на глазах (пятно бледнеет).
	for k in 3 + tier:
		var sp := Vector3(rng.randf_range(-w / 2 + 1.0, w / 2 - 1.0), 0, rng.randf_range(-d / 2 + 1.0, d / 2 - 1.0))
		var sr := rng.randf_range(0.4, 0.62)
		if _blocked(Vector2(sp.x, sp.z), sr):
			continue
		var sn := at(sp, rng.randf() * TAU)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = [Color(0.2, 0.13, 0.07, 0.88), Color(0.1, 0.1, 0.11, 0.88), Color(0.3, 0.08, 0.07, 0.88)][k % 3]
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.roughness = 0.35
		var flat := MGModels.spawn_flat("ml_job_stain_set", sn, Vector3(0, 0.004, 0), 0.0, sr * 2.4, sr * 1.3)
		if flat != null:
			flat.scale = Vector3(1.0, 0.35, 1.0)            # пятно — плёнка на полу, а не лепёшка
			for gm in flat.find_children("*", "MeshInstance3D", true, false):
				(gm as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trash.append({"node": sn, "w": 3.0, "big": false, "val": false, "got": false, "pull": 0.0, "stain": true, "hp": 1.0, "r": sr, "mat": sm, "glb": flat.find_children("*", "MeshInstance3D", true, false)})
			stains_all += 1
			continue
		for q in 3:
			var blob := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = sr * (1.0 - q * 0.22)
			cm.bottom_radius = cm.top_radius
			cm.height = 0.006
			cm.radial_segments = 14
			blob.mesh = cm
			blob.material_override = sm
			blob.position = Vector3(rng.randf_range(-0.2, 0.2) * q, 0.008 + q * 0.002, rng.randf_range(-0.2, 0.2) * q)
			blob.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))
			sn.add_child(blob)
		trash.append({"node": sn, "w": 3.0, "big": false, "val": false, "got": false, "pull": 0.0, "stain": true, "hp": 1.0, "r": sr, "mat": sm})
		stains_all += 1
	for t in trash:
		if _counts(t):
			need += float(t["w"])

func _furn(p: Vector3, half: Vector2, id: String, build: Callable, yaw: float, fragile := false) -> void:
	var n: Node3D
	if id == "ml_desk":
		n = MGModels.wide_desk(world_root, p, yaw, half.x * 2.0, half.y * 2.0, 0.78, build)
	elif id != "":
		n = MGModels.spawn(id, world_root, p, yaw, Vector3(half.x * 2.0, 1.0, half.y * 2.0), build)
	else:
		n = at(p, yaw)
		build.call(n)
	if fragile and task == "fragile":
		var fr := MGProps.box(n, Vector3(0, 0.02, 0), Vector3(half.x * 2.0 + 0.3, 0.01, half.y * 2.0 + 0.3), MGProps.glow(Color(1, 1, 1), 0.6))
		fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if half.x > 0.05:
		obst.append({"c": Vector2(p.x, p.z), "h": half + Vector2(0.15, 0.15), "fragile": fragile or task == "fragile" and id == "", "node": n, "hit": 0.0})

func _blocked(p: Vector2, r: float) -> bool:
	for o in obst:
		var c: Vector2 = o["c"]
		var h: Vector2 = o["h"]
		if absf(p.x - c.x) < h.x + r and absf(p.y - c.y) < h.y + r:
			return true
	return false

func _counts(t: Dictionary) -> bool:
	match task:
		"big":
			return bool(t["big"]) or bool(t["val"])
		"valuables":
			return bool(t["val"]) or not bool(t["big"])
	return true

func _spawn_tyaga() -> void:
	tyaga = Node3D.new()
	world_root.add_child(tyaga)
	model = Node3D.new()
	tyaga.add_child(model)
	var body := fit_model("res://assets/models/tyaga812.glb", model, 1.05)
	body.rotation.y = -PI / 2                    # у Tripo лицо по +X — разворачиваем вперёд (−Z)
	if body.get_child_count() == 0:
		MGProps.box(model, Vector3(0, 0.25, 0), Vector3(0.5, 0.4, 0.8), MGProps.mat("red"))
	if eq("tyaga") >= 4:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = MGProps.glow(Color(1.0, 0.75, 0.2), 0.25)
	# щётка спереди — видимая, ширина по навыкам
	var brush := MGProps.box(model, Vector3(0, 0.04, -0.55), Vector3(0.5 * (1.0 + cv("tyaga_brush")), 0.05, 0.12), MGProps.mat("plastic_black"))
	brush.name = "brush"
	pos = Vector3(-float(L["w"]) / 2 + 1.5, 0, float(L["d"]) / 2 - 1.5)
	yaw = PI
	tyaga.position = pos
	# шланг: точки от розетки к пылесосу
	hose_mesh = ImmediateMesh.new()
	var hm := MeshInstance3D.new()
	hm.mesh = hose_mesh
	hose_mat = StandardMaterial3D.new()
	hose_mat.albedo_color = Color(0.12, 0.12, 0.13)
	hose_mat.roughness = 0.6
	hm.material_override = hose_mat
	world_root.add_child(hm)
	for k in 16:
		var p := socket.lerp(pos + Vector3(0, 0.3, 0), float(k) / 15.0)
		hose_pts.append(p)
		hose_prev.append(p)
	cam.look_at_from_position(pos + Vector3(0, 3.2, 3.6), pos, Vector3.UP)

# ---------------- игра ----------------
func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	var inp := _bot_input() if bot >= 0.0 else axis()
	var throttle := -inp.y
	var turn := inp.x
	if stress_k > 0.0:
		turn += sin(time_left * 6.0) * 0.25 * stress_k
	if stuck_t > 0.0:
		stuck_t -= dt
		throttle = minf(throttle, 0.0) * 0.5
	turbo_cd = maxf(0.0, turbo_cd - dt)
	tangle_cd = maxf(0.0, tangle_cd - dt)
	if cv("tyaga_turbo") > 0.0 and turbo_t <= 0.0 and turbo_cd <= 0.0 and (Input.is_physical_key_pressed(KEY_SHIFT) and bot < 0.0 or bot >= 0.0 and load < cap * 0.5 and rng_bot.randf() < dt * 0.3):
		turbo_t = 3.0 + (1.5 if eq("tyaga") >= 4 else 0.0)
		turbo_cd = 8.0
		sfx("whoosh", 1.4)
	turbo_t = maxf(0.0, turbo_t - dt)
	var vmax := 3.2 * (1.0 + 0.25 * float(eq("tyaga") >= 3)) * (1.5 if turbo_t > 0.0 else 1.0)
	speed = move_toward(speed, throttle * vmax, (6.0 if absf(throttle) > 0.1 else 4.0) * dt)
	yaw -= turn * dt * 2.6 * clampf(0.55 + absf(speed) / vmax, 0.55, 1.2) * signf(speed if absf(speed) > 0.2 else 1.0)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var np := pos + fwd * speed * dt
	np = _collide(np)
	np = _hose_limit(np)
	_cables(pos, np)
	pos = np
	tyaga.position = pos
	tyaga.rotation.y = yaw
	steer_k = lerpf(steer_k, turn * signf(speed), 1.0 - exp(-6.0 * dt))
	model.rotation.z = -steer_k * 0.12 * absf(speed) / vmax
	model.rotation.x = lerpf(model.rotation.x, -throttle * 0.06, 1.0 - exp(-8.0 * dt))
	if bot >= 0.0:
		wash = bot >= 0.5 and bot_target >= 0 and trash[bot_target].has("stain")      # невнимательный насадку не меняет — трёт щёткой
	_wash(dt, fwd)
	_suck(dt, fwd)
	_hose(dt)
	_unload()
	combo_t -= dt
	if combo_t <= 0.0 and combo > 0:
		combo = 0
	combo_l.text = "серия ×%d" % combo if combo >= 3 else ""
	combo_l.visible = combo >= 3
	var k_got := got_w / maxf(1.0, need)
	progress(k_got)
	score_l.text = "убрано %d %%\nконтейнер %d %%\nшланг %d %%\n[Q] %s" % [int(k_got * 100.0), int(load / cap * 100.0), int(clampf(tension, 0.0, 1.0) * 100.0), "МОЙКА" if wash else "ЩЁТКА"]
	tip_l.text = "Контейнер полон — к ведру у двери" if load >= cap else ("Шланг натянут" if tension > 0.95 else ("Запутался — сдай назад" if stuck_t > 0.0 else ""))
	hum.pitch_scale = 0.8 + absf(speed) / vmax * 0.5 + (0.25 if turbo_t > 0.0 else 0.0)
	hum.volume_db = -16.0 + (4.0 if load < cap else -4.0)
	# камера: сзади-сверху, мягко
	var want := pos - fwd * 3.0 + Vector3(0, 3.0, 0)
	# камера не уходит за стены (сзади, слева, справа); спереди комната открыта
	want.x = clampf(want.x, -float(L["w"]) / 2 + 0.4, float(L["w"]) / 2 - 0.4)
	want.z = maxf(want.z, -float(L["d"]) / 2 + 0.4)
	cam.position = cam.position.lerp(want, 1.0 - exp(-4.0 * dt))
	cam.look_at(pos + fwd * 1.0 + Vector3(0, 0.3, 0), Vector3.UP)
	if k_got >= 0.999:
		_end()

func _collide(np: Vector3) -> Vector3:
	var w: float = L["w"]
	var d: float = L["d"]
	var p := Vector2(np.x, np.z)
	p.x = clampf(p.x, -w / 2 + 0.45, w / 2 - 0.45)
	p.y = clampf(p.y, -d / 2 + 0.45, d / 2 - 0.45)
	for o in obst:
		var c: Vector2 = o["c"]
		var h: Vector2 = o["h"] + Vector2(0.3, 0.3)
		var dx := p.x - c.x
		var dz := p.y - c.y
		if absf(dx) < h.x and absf(dz) < h.y:
			# выталкиваем по меньшей глубине; удар — по скорости
			if h.x - absf(dx) < h.y - absf(dz):
				p.x = c.x + signf(dx) * h.x
			else:
				p.y = c.y + signf(dz) * h.y
			if absf(speed) > 1.4 and float(o["hit"]) <= 0.0:
				o["hit"] = 0.8
				bumps += 1
				sfx("drop", 0.8)
				puff(Vector3(p.x, 0.3, p.y), Color(0.6, 0.6, 0.6), 4)
				var on: Node3D = o["node"]
				var tw := on.create_tween()
				tw.tween_property(on, "rotation:z", 0.06, 0.05)
				tw.tween_property(on, "rotation:z", -0.04, 0.08)
				tw.tween_property(on, "rotation:z", 0.0, 0.1)
				if bool(o["fragile"]):
					fragile_hits += 1
					pop("ЧУЖАЯ ТЕХНИКА!", Vector3(p.x, 1.2, p.y), RED)
			speed *= 0.3
	for o in obst:
		o["hit"] = maxf(0.0, float(o["hit"]) - get_process_delta_time())
	return Vector3(p.x, 0, p.y)

## шланг держит: дальше длины не уедешь (мягко тянет назад)
func _hose_limit(np: Vector3) -> Vector3:
	var to := np - Vector3(socket.x, 0, socket.z)
	var path := _hose_path_len()
	tension = clampf(path / hose_len, 0.0, 1.2)
	if to.length() > hose_len * 0.98:
		np = Vector3(socket.x, 0, socket.z) + to.normalized() * hose_len * 0.98
		speed *= 0.5
	return np

func _hose_path_len() -> float:
	var s := 0.0
	for k in hose_pts.size() - 1:
		s += (hose_pts[k + 1] as Vector3).distance_to(hose_pts[k])
	return s

## шланг: цепочка точек (верле), огибает мебель; обмотался — путается
## Шланг считается постоянным шагом HOSE_H (как провод наушников): раньше затухание и проходы ограничений шли «раз в
## кадр», и при 60 кадрах в секунду шланг успокаивался медленнее и путался чаще, чем при 144.
const HOSE_H := 1.0 / 120.0
var hose_acc := 0.0

func _hose(dt: float) -> void:
	hose_acc = minf(hose_acc + dt, HOSE_H * 8.0)
	while hose_acc >= HOSE_H:
		hose_acc -= HOSE_H
		_hose_step(HOSE_H)
	_hose_check()

func _hose_step(dt: float) -> void:
	var n := hose_pts.size()
	var seg := hose_len / float(n - 1)
	for k in range(1, n - 1):
		var p: Vector3 = hose_pts[k]
		var v: Vector3 = (p - (hose_prev[k] as Vector3)) * 0.9
		hose_prev[k] = p
		p += v + Vector3(0, -9.8, 0) * dt * dt
		p.y = maxf(p.y, 0.05)
		hose_pts[k] = p
	hose_pts[0] = socket
	hose_pts[n - 1] = pos + Vector3(0, 0.32, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.35
	for it in 4:
		for k in n - 1:
			var a: Vector3 = hose_pts[k]
			var b: Vector3 = hose_pts[k + 1]
			var dlt := b - a
			var dd := dlt.length()
			if dd < 0.0001 or dd <= seg:
				continue
			var corr := dlt * (1.0 - seg / dd) * 0.5
			if k != 0:
				hose_pts[k] = a + corr
			if k + 1 != n - 1:
				hose_pts[k + 1] = b - corr
		if it == 3:
			contacts = 0
		for k in range(1, n - 1):
			var p: Vector3 = hose_pts[k]
			for o in obst:
				var c: Vector2 = o["c"]
				var h: Vector2 = o["h"]
				var dx := p.x - c.x
				var dz := p.z - c.y
				if absf(dx) < h.x and absf(dz) < h.y:
					if h.x - absf(dx) < h.y - absf(dz):
						p.x = c.x + signf(dx) * h.x
					else:
						p.z = c.y + signf(dz) * h.y
					if it == 3:
						contacts += 1
			hose_pts[k] = p

func _hose_check() -> void:
	# запутался: шланг вытянут почти на всю длину и обмотан вокруг мебели (касается её в нескольких точках)
	var path := _hose_path_len()
	var need_contacts := 3 + int(cv("tyaga_tangle") * -5.0)
	if path > hose_len * 0.96 and contacts >= need_contacts and stuck_t <= 0.0 and absf(speed) > 0.3 and tangle_cd <= 0.0:
		tangle_cd = 2.5
		stuck_t = 1.0
		tangles += 1
		if bot >= 0.0 and bot_target >= 0:
			bot_skip[bot_target] = true                  # бот: туда шланг не достаёт — бросает цель и сдаёт назад
			bot_target = -1
			bot_back = 0.8
		sfx("zap")
		pop("ШЛАНГ ЗАПУТАЛСЯ!", pos + Vector3(0, 1.2, 0), RED)
	hose_mat.albedo_color = Color(0.12, 0.12, 0.13).lerp(Color(0.8, 0.1, 0.08), clampf((tension - 0.85) * 6.0, 0.0, 1.0))
	_draw_hose()

func _draw_hose() -> void:
	hose_mesh.clear_surfaces()
	hose_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.045
	var ring := 6
	var prev: Array = []
	for k in hose_pts.size():
		var p: Vector3 = hose_pts[k]
		var fwd := ((hose_pts[mini(k + 1, hose_pts.size() - 1)] as Vector3) - (hose_pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(fwd).normalized()
		var cur: Array = []
		for j in ring:
			var a := TAU * j / ring
			cur.append([p + (side * cos(a) + up * sin(a)) * r, side * cos(a) + up * sin(a)])
		if not prev.is_empty():
			for j in ring:
				var a0: Array = prev[j]
				var a1: Array = prev[(j + 1) % ring]
				var b0: Array = cur[j]
				var b1: Array = cur[(j + 1) % ring]
				for vv in [a0, b0, a1, a1, b0, b1]:
					hose_mesh.surface_set_normal(vv[1])
					hose_mesh.surface_add_vertex(vv[0])
		prev = cur
	hose_mesh.surface_end()

## провода соседей: переехал медленно — колесо перекатилось; быстро — зацепил (стоп и минус)
func _cables(a: Vector3, b: Vector3) -> void:
	if stuck_t > 0.0 or a.distance_to(b) < 0.001:
		return
	for c in cables:
		var hit = Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), c[0], c[1])
		if hit != null and absf(speed) <= 1.1:
			sfx("tick", 0.6)                          # аккуратно перекатился через провод
			continue
		if hit != null:
			if rng.randf() < 0.3 * cv("tyaga_hose"):
				continue                               # длинный шланг и аккуратность — иногда проскакиваешь
			cable_hits += 1
			stuck_t = 0.7
			speed = -speed * 0.3
			sfx("zap", 1.2)
			pop("ПРОВОД!", Vector3(b.x, 0.8, b.z), Color(1.0, 0.8, 0.2))
			return

## щётка: притягивает мусор спереди; тяжёлому нужна мощность; ценное — только на малой скорости
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_Q and not done:
		set_nozzle(not wash)

## смена насадки: щётка втягивает мусор, мойка оттирает пятна (и мусор не берёт)
func set_nozzle(w: bool) -> void:
	wash = w
	sfx("tick", 1.5 if w else 0.8)
	pop("МОЙКА" if w else "ЩЁТКА", pos + Vector3(0, 1.0, 0), Color(0.5, 0.85, 1.0) if w else WHITE)

func _wash(dt: float, fwd: Vector3) -> void:
	var nozzle := pos + fwd * 0.6
	foam_t -= dt
	for t in trash:
		if t["got"] or not t.has("stain"):
			continue
		var tp: Vector3 = (t["node"] as Node3D).position
		if Vector2(tp.x - nozzle.x, tp.z - nozzle.z).length() > float(t["r"]) + 0.3:
			continue
		var slow := clampf(1.35 - absf(speed) / 3.2, 0.3, 1.0)          # медленнее — чище
		t["hp"] = float(t["hp"]) - dt * (1.0 + cv("tyaga_power")) * (1.0 if wash else 0.25) * slow / 0.8
		(t["mat"] as StandardMaterial3D).albedo_color.a = clampf(float(t["hp"]), 0.0, 1.0) * 0.88
		for gm in t.get("glb", []):
			(gm as GeometryInstance3D).transparency = 1.0 - clampf(float(t["hp"]), 0.0, 1.0) * 0.95
		bot_stall = 0.0
		if foam_t <= 0.0:
			foam_t = 0.18
			puff(Vector3(nozzle.x, 0.08, nozzle.z), Color(0.85, 0.92, 1.0) if wash else Color(0.6, 0.55, 0.5), 3, 0.8)
			if wash:
				sfx("tick", 1.8)
		if float(t["hp"]) <= 0.0:
			t["got"] = true
			(t["node"] as Node3D).visible = false
			stains_done += 1
			if _counts(t):
				got_w += float(t["w"])
			combo += 1
			combo_t = 1.4
			best_combo = maxi(best_combo, combo)
			sfx("clean", 1.2)
			pop("ЧИСТО!", tp + Vector3(0, 0.6, 0), Color(0.5, 0.85, 1.0))

func _suck(dt: float, fwd: Vector3) -> void:
	if load >= cap or wash:
		return
	var nozzle := pos + fwd * 0.6
	var power := (1.0 + cv("tyaga_power")) * (2.0 if turbo_t > 0.0 else 1.0)
	var reach := 0.55 * (1.0 + cv("tyaga_brush")) * (1.3 if turbo_t > 0.0 else 1.0)
	for t in trash:
		if t["got"] or t.has("stain"):
			continue
		var node: Node3D = t["node"]
		var tp := node.position
		var dist := Vector2(tp.x - nozzle.x, tp.z - nozzle.z).length()
		var smart := cv("tyaga_smart") > 0.0 and float(t["w"]) <= 1.0 and dist < 1.4
		if dist > reach and not smart:
			t["pull"] = maxf(0.0, float(t["pull"]) - dt)
			continue
		if bool(t["val"]) and absf(speed) > 1.3:
			# ценное на скорости — щётка бьёт: повреждено, минус
			t["got"] = true
			broke_val += 1
			node.visible = false
			sfx("drop", 0.6)
			pop("РАЗБИЛ!", tp + Vector3(0, 0.6, 0), RED)
			continue
		t["pull"] = float(t["pull"]) + dt * power / float(t["w"]) * (0.5 if smart else 1.0)
		node.position = tp.lerp(Vector3(nozzle.x, 0.05, nozzle.z), clampf(float(t["pull"]) * 0.6, 0.0, 1.0))
		node.scale = Vector3.ONE * clampf(1.0 - float(t["pull"]) * 0.5, 0.2, 1.0)
		if float(t["pull"]) >= (0.35 if float(t["w"]) <= 1.0 else 0.9):
			t["got"] = true
			node.visible = false
			load += float(t["w"])
			if _counts(t):
				got_w += float(t["w"])
			combo += 1
			combo_t = 1.4
			best_combo = maxi(best_combo, combo)
			puff(Vector3(nozzle.x, 0.1, nozzle.z), Color(0.7, 0.66, 0.6), 4 if float(t["w"]) <= 1.0 else 8)
			sfx("tick" if float(t["w"]) <= 1.0 else "clean", 0.9 + 0.1 * minf(combo, 6))
			if bool(t["val"]):
				pop("НАШЁЛ!", tp + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.3))
			elif combo >= 3 and combo % 3 == 0:
				pop("серия ×%d" % combo, tp + Vector3(0, 0.6, 0), Color(1.0, 0.8, 0.3))
			if load >= cap:
				sfx("alert")

## у ведра контейнер выгружается сам
func _unload() -> void:
	if load > 0.0 and Vector2(pos.x - bin_p.x, pos.z - bin_p.z).length() < 1.1:
		if load >= cap * 0.3:
			sfx("whoosh")
			puff(bin_p + Vector3(0, 0.7, 0), Color(0.6, 0.6, 0.6), 8, 1.5)
		load = 0.0

# ---------------- бот (проверки) ----------------
func _bot_input() -> Vector2:
	# плохой «игрок» теряет время: чем ниже качество, тем чаще стоит и думает
	var dt := get_process_delta_time()
	if bot_pause > 0.0:
		bot_pause -= dt
		return Vector2.ZERO
	if rng_bot.randf() < (1.0 - bot) * dt * 0.9:
		bot_pause = 1.3
	# тупик: жмёт газ, а стоит — полсекунды назад с поворотом
	if bot_back > 0.0:
		bot_back -= dt
		return Vector2(bot_back_turn, 0.8)
	if absf(speed) < 0.15:
		bot_idle += dt
		if bot_idle > 1.2:
			bot_idle = 0.0
			bot_back = 0.6
			bot_back_turn = 1.0 if rng_bot.randf() < 0.5 else -1.0
	else:
		bot_idle = 0.0
	if load >= cap:
		return _steer_to(_around(bin_p), 1.0)
	if bot_target < 0 or trash[bot_target]["got"]:
		bot_stall = 0.0
		var bd := INF
		bot_target = -1
		for k in trash.size():
			var t: Dictionary = trash[k]
			if t["got"] or not _counts(t) or bot_skip.has(k):
				continue
			var tp: Vector3 = (t["node"] as Node3D).position
			if (tp - Vector3(socket.x, 0, socket.z)).length() > hose_len * 0.95:
				continue
			var dd := tp.distance_to(pos)
			if dd < bd:
				bd = dd
				bot_target = k
	if bot_target < 0:
		return Vector2.ZERO
	var tgt: Vector3 = (trash[bot_target]["node"] as Node3D).position
	# пятно: встал насадкой на него и стоит, пока не ототрёт (кружить над пятном — мотать шланг)
	if trash[bot_target].has("stain"):
		var fw := Vector3(-sin(yaw), 0, -cos(yaw))
		var nz := pos + fw * 0.6
		if Vector2(tgt.x - nz.x, tgt.z - nz.z).length() < float(trash[bot_target]["r"]) + 0.15:
			bot_stall = 0.0
			bot_idle = 0.0
			return Vector2.ZERO
	var slow := 0.35 if (bool(trash[bot_target]["val"]) or trash[bot_target].has("stain")) and tgt.distance_to(pos) < 1.5 else 1.0
	# впереди провод — аккуратный бот сбрасывает скорость, чтобы перекатиться
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	for c in cables:
		if Geometry2D.segment_intersects_segment(Vector2(pos.x, pos.z), Vector2(pos.x + fwd.x * 1.2, pos.z + fwd.z * 1.2), c[0], c[1]) != null and rng_bot.randf() < bot:
			slow = minf(slow, 0.3)
	# застрял у недостижимой цели (у стены, под мебелью) — бросает её и едет к другой
	bot_stall += get_process_delta_time()
	if bot_stall > 3.5:
		bot_skip[bot_target] = true
		bot_target = -1
		bot_stall = 0.0
		return Vector2(0, 0.6)
	return _steer_to(_around(tgt), lerpf(0.25, 1.0, bot) * slow)

## объезд: если мебель между пылесосом и целью — едем к ближайшему углу этой мебели (с запасом)
func _around(tgt: Vector3) -> Vector3:
	var a := Vector2(pos.x, pos.z)
	var b := Vector2(tgt.x, tgt.z)
	for o in obst:
		var c: Vector2 = o["c"]
		var h: Vector2 = o["h"] + Vector2(0.35, 0.35)
		var r := Rect2(c - h, h * 2.0)
		if r.has_point(b):
			continue
		var hit := false
		for k in 9:
			if r.has_point(a.lerp(b, float(k) / 8.0)):
				hit = true
				break
		if not hit:
			continue
		var best := b
		var bd := INF
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				var cp := c + Vector2(cx * (h.x + 0.45), cz * (h.y + 0.45))
				var dd := a.distance_to(cp) + cp.distance_to(b)
				var clear := true                       # до угла — не сквозь мебель
				for j in range(1, 8):
					if r.has_point(a.lerp(cp, float(j) / 8.0)):
						clear = false
						break
				if clear and dd < bd and a.distance_to(cp) > 0.3:
					bd = dd
					best = cp
		return Vector3(best.x, 0, best.y)
	return tgt

func _steer_to(tgt: Vector3, k: float) -> Vector2:
	var to := tgt - pos
	var want := atan2(-to.x, -to.z)
	var dy := wrapf(want - yaw, -PI, PI)
	var turn := clampf(-dy * 2.0, -1.0, 1.0)
	# плохой «игрок» рулит неточно: чем ниже качество, тем сильнее уводит в сторону
	bot_wob += get_process_delta_time() * 2.0
	turn += sin(bot_wob) * (1.0 - bot) * 1.4
	if rng_bot.randf() > bot * 0.98:
		turn += rng_bot.randf_range(-0.8, 0.8)
	# близко к цели — медленнее (иначе кружит вокруг: радиус поворота больше расстояния), сильно не туда — на месте
	var near := clampf(to.length() / 1.6, 0.25, 1.0)
	var thr := k * near * (1.0 if absf(dy) < 0.5 else (0.35 if absf(dy) < 1.4 else 0.0))
	return Vector2(turn, -thr)

func _end() -> void:
	if done:
		return
	hum.stop()
	var k_got := got_w / maxf(1.0, need)
	var combo_b := clampf(float(best_combo) / 20.0, 0.0, 1.0) * 0.08
	var time_b := clampf(time_left / time_max, 0.0, 1.0) * 0.1 if k_got >= 0.999 else 0.0
	var pen := minf(0.3, 0.035 * tangles) + minf(0.2, 0.02 * cable_hits) + 0.06 * fragile_hits + 0.1 * broke_val + 0.01 * bumps
	var score := clampf(k_got * 0.85 + combo_b + time_b - pen, 0.0, 1.0)
	var lines: Array = ["%s · %s" % [L["name"], TASKS[task]], "Убрано: %d %% · лучшая серия ×%d%s" % [int(k_got * 100.0), best_combo, "  ·  быстро: +%d%%" % int(time_b * 100.0) if time_b > 0.0 else ""]]
	var bad: Array = []
	if tangles > 0:
		bad.append("шланг запутался ×%d" % tangles)
	if cable_hits > 0:
		bad.append("провода ×%d" % cable_hits)
	if fragile_hits > 0:
		bad.append("чужая техника ×%d" % fragile_hits)
	if broke_val > 0:
		bad.append("разбито ценного ×%d" % broke_val)
	if bumps > 0:
		bad.append("удары ×%d" % bumps)
	if stains_all > 0:
		lines.append("Пятна оттёрты: %d из %d" % [stains_done, stains_all])
	lines.append(("Штрафы: " + ", ".join(bad)) if not bad.is_empty() else "Без единого штрафа")
	show_result(score, lines)
