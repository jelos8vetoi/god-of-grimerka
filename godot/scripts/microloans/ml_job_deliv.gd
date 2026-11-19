## ДОСТАВКА — 3D от третьего лица: Пахан (настоящая модель) разносит посылки по двору с панельками.
## Двор из моделей гонок (хрущёвки, гаражи, лавки, машины, фонари, берёзы, мусорки, киоск выдачи), у домов —
## подъезды с номерами. Посылок за маршрут — по навыкам и рюкзаку; у каждой адрес («ДОМ 2 · ПОД. 3»), хрупкость
## и иногда причуда получателя (ждёт на лавке, у гаража). Прохожие ходят по двору; врезался на бегу — посылка
## бьётся (хрупкая — вдвое). Погода по уровню заказа: дождь и лужи (скользко), вечер, снег. Shift — бег (выносливость).
## Стрелка над Паханом показывает адрес; знакомый курьер (навык) — ещё и короткий путь.
class_name MLJobDeliv
extends MLJob3D

const SIZE := 26.0
var rng := RandomNumberGenerator.new()
var rng_bot := RandomNumberGenerator.new()
var pahan: Rig
var box_node: Node3D
var arrow: Node3D
var path_l: MeshInstance3D
var pos := Vector3.ZERO
var yaw := 0.0
var vel := Vector3.ZERO
var stamina := 1.0
var obst: Array = []                # {c: Vector2, r: float} (круги) и прямоугольники {c, h}
var rects: Array = []
var doors: Array = []               # {p: Vector3, name}
var parcels: Array = []             # {to: int, name, fragile, cond, done, quirk}
var cur := 0
var peds: Array = []                # {rig, a, b, t, spd}
var puddles: Array = []             # [Vector2, r]
var weather := "clear"
var hits := 0
var chain := 0
var best_chain := 0
var parcel_t := 0.0
var stumble_t := 0.0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 11
	weather = ["clear", "clear", "rain", "night", "snow"][clampi(tier - 1, 0, 4)]
	base_setup(f, sf, stress, "ДОСТАВКА · %s" % {"clear": "ДЕНЬ", "rain": "ДОЖДЬ", "night": "ВЕЧЕР", "snow": "СНЕГ"}[weather], "WASD — идти · Shift — бег (выносливость) · у двери подъезда посылка отдаётся сама · не врезайся с посылкой", 60.0 + tier * 8.0)
	var bg := Color(0.45, 0.55, 0.65) if weather == "clear" else (Color(0.05, 0.06, 0.1) if weather == "night" else Color(0.3, 0.33, 0.37))
	setup_3d(bg, Color(0.6, 0.62, 0.68), 0.6 if weather != "night" else 0.25)
	env.fog_enabled = weather != "clear"
	env.fog_density = 0.03 if weather == "rain" else (0.02 if weather == "snow" else 0.01)
	env.fog_light_color = bg
	_yard()
	_parcels()
	_pahan()
	_peds()
	if weather in ["rain", "snow"]:
		_precip()

# ---------------- двор ----------------
func _yard() -> void:
	MGProps.box(world_root, Vector3(0, -0.05, 0), Vector3(SIZE * 2.4, 0.1, SIZE * 2.4), MGProps._m(Color(0.25, 0.25, 0.26) if weather != "snow" else Color(0.85, 0.87, 0.9), 0.9, 0.0, 2, 0.4))
	MGProps.box(world_root, Vector3(0, -0.04, 0), Vector3(SIZE * 1.1, 0.1, 3.0), MGProps._m(Color(0.36, 0.35, 0.33), 0.9, 0.0, 2, 0.6))       # тротуар крестом
	MGProps.box(world_root, Vector3(0, -0.04, 0), Vector3(3.0, 0.1, SIZE * 1.1), MGProps._m(Color(0.36, 0.35, 0.33), 0.9, 0.0, 2, 0.6))
	sun(Vector3(-0.9, 0.6, 0), 1.3 if weather == "clear" else 0.5, Color(1, 0.95, 0.85) if weather != "night" else Color(0.4, 0.5, 0.8))
	var houses := [[Vector3(0, 0, -SIZE), 0.0], [Vector3(0, 0, SIZE), PI], [Vector3(-SIZE, 0, 0), PI / 2], [Vector3(SIZE, 0, 0), -PI / 2]]
	for hi in houses.size():
		var hp: Vector3 = houses[hi][0]
		var hy: float = houses[hi][1]
		var b := MGModels.spawn("_none_", world_root, hp, hy, Vector3(24, 14, 10), func(r):
			if RaceProps.has("khrushchevka"):
				RaceProps.spawn("khrushchevka", r, Vector3.ZERO, 0.0, 1.0, true)
			else:
				MGProps.box(r, Vector3(0, 7, 0), Vector3(24, 14, 10), MGProps.mat("cream")))
		var fw := Vector3(sin(hy), 0, cos(hy))        # лицо дома — во двор
		var rt := Vector3(cos(hy), 0, -sin(hy))
		var c2 := Vector2(hp.x, hp.z)
		rects.append({"c": c2, "h": Vector2(12.4, 5.4) if absf(sin(hy)) < 0.5 else Vector2(5.4, 12.4)})
		for di in 3:
			var dp := hp + fw * 5.3 + rt * (-8.0 + di * 8.0)
			var dn := at(dp, hy)
			MGProps.box(dn, Vector3(0, 1.1, 0), Vector3(1.3, 2.2, 0.15), MGProps.mat("blue_paint"))
			MGProps.box(dn, Vector3(0, 2.4, 0.5), Vector3(2.0, 0.1, 1.2), MGProps.mat("metal"))
			MGProps.text(dn, "ДОМ %d · ПОД. %d" % [hi + 1, di + 1], Vector3(0, 2.75, 0.12), 70, Color(0.95, 0.92, 0.85))
			var lamp := light(dp + fw * 0.6 + Vector3(0, 2.3, 0), 1.2 if weather == "night" else 0.3, 5.0, Color(1.0, 0.8, 0.5))
			lamp.shadow_enabled = false
			doors.append({"p": dp + fw * 0.9, "name": "ДОМ %d · ПОД. %d" % [hi + 1, di + 1]})
	# киоск выдачи — старт
	_prop("kiosk", Vector3(-4.5, 0, 4.5), 0.6, 1.6)
	MGProps.text(at(Vector3(-4.5, 3.2, 4.5), 0.6), "ПУНКТ ВЫДАЧИ", Vector3.ZERO, 90, Color(0.95, 0.3, 0.25))
	for p in [[Vector3(6, 0, 6), 0.4], [Vector3(-8, 0, -6), 1.2], [Vector3(9, 0, -9), 0.0], [Vector3(-12, 0, 11), 2.0]]:
		_prop("bench", p[0], p[1], 1.0)
	for p in [Vector3(12, 0, 4), Vector3(-6, 0, 13)]:
		_prop("old_car", p, rng.randf() * TAU, 2.2)
	for p in [Vector3(-14, 0, -14), Vector3(14, 0, 14), Vector3(-15, 0, 4), Vector3(4, 0, -15)]:
		_prop("birch_tree", p, rng.randf() * TAU, 0.6)
	for p in [Vector3(3.5, 0, 9), Vector3(-9, 0, -3)]:
		_prop("dumpster", p, 0.3, 1.1)
	for p in [Vector3(15, 0, -14), Vector3(17, 0, -14)]:
		_prop("garage", p, PI, 2.0)
	_prop("playground", Vector3(9, 0, 9), 0.5, 3.5)
	for p in [Vector3(-2, 0, -9), Vector3(10, 0, -2), Vector3(-10, 0, 8)]:
		_prop("street_lamp", p, 0.0, 0.3)
		if weather == "night":
			light(p + Vector3(0, 5.5, 0), 2.5, 12.0, Color(1.0, 0.7, 0.4))
	# лужи (скользко) и мусор
	if weather in ["rain", "snow"]:
		for k in 8:
			var lp := Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
			var lr := rng.randf_range(0.8, 1.6)
			puddles.append([lp, lr])
			MGProps.cyl(world_root, Vector3(lp.x, 0.01, lp.y), lr, lr, 0.01, MGProps.mat("glass") if weather == "rain" else MGProps.mat("paper"), Vector3.ZERO, 16)

func _prop(id: String, p: Vector3, yaw_v: float, r: float) -> void:
	if RaceProps.has(id):
		RaceProps.spawn(id, world_root, p, yaw_v, 1.0, true)
	else:
		MGProps.carton(at(p, yaw_v), Vector3(r, 1.0, r), "")
	obst.append({"c": Vector2(p.x, p.z), "r": r})

func _parcels() -> void:
	var n := 2 + int(cv("deliv_slots")) + (1 if eq("deliv") >= 2 else 0) + (2 if eq("deliv") >= 4 else 0) + tier / 2
	var used := {}
	for k in n:
		var di := rng.randi() % doors.size()
		while used.has(di):
			di = rng.randi() % doors.size()
		used[di] = true
		var fragile := rng.randf() < 0.35 + tier * 0.05
		var quirk := ""
		if rng.randf() < 0.2 + tier * 0.04:
			quirk = "bench"
		parcels.append({"to": di, "name": doors[di]["name"], "fragile": fragile, "cond": 1.0, "done": false, "quirk": quirk})
	if parcels.size() > 0 and String(parcels[0]["quirk"]) == "bench":
		parcels[0]["quirk"] = ""

func _target() -> Vector3:
	var P: Dictionary = parcels[cur]
	if String(P["quirk"]) == "bench":
		return Vector3(6, 0, 6.8)                   # получатель ждёт на лавке у площадки
	return doors[int(P["to"])]["p"]

func _pahan() -> void:
	pahan = Rig.new()
	world_root.add_child(pahan)
	pahan.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan(), true, -1.0, "fn_deliv_pahan")
	pos = Vector3(-3.0, 0, 6.0)
	pahan.position = pos
	pahan.play("Idle", 0.0)
	box_node = at(Vector3(0, 1.0, 0.45), 0.0, pahan)
	MGProps.carton(box_node, Vector3(0.45, 0.32, 0.36), "ХРУПКОЕ")
	box_node.position.y = 0.9
	arrow = at(Vector3(0, 2.6, 0))
	MGProps.cyl(arrow, Vector3(0, 0, -0.35), 0.0, 0.18, 0.4, MGProps.glow(Color(1.0, 0.3, 0.2), 2.0), Vector3(-PI / 2, 0, 0))
	MGProps.box(arrow, Vector3(0, 0, 0.05), Vector3(0.1, 0.04, 0.45), MGProps.glow(Color(1.0, 0.3, 0.2), 2.0))
	cam.look_at_from_position(pos + Vector3(0, 5, 7), pos, Vector3.UP)

func _peds() -> void:
	for k in 3 + tier:
		var r := Rig.new()
		world_root.add_child(r)
		r.setup("res://assets/models/%s.glb" % ["bot", "clipper", "hater"][k % 3], 1.75, Poses.bot() if k % 3 == 0 else (Poses.clipper() if k % 3 == 1 else Poses.hater()), true, 1.0, "deliv_ped_%d" % (k % 3))
		var a := Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-13, 13))
		var b := Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-13, 13))
		r.position = a
		r.play("Run", 0.0, 0.45)
		peds.append({"rig": r, "a": a, "b": b, "t": rng.randf(), "spd": rng.randf_range(0.04, 0.08)})

func _precip() -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 1200 if weather == "rain" else 700
	gp.lifetime = 1.2 if weather == "rain" else 4.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 0.5, 14)
	pm.gravity = Vector3(0, -22.0 if weather == "rain" else -1.5, 0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.direction = Vector3(0.1, -1, 0)
	gp.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.35) if weather == "rain" else Vector2(0.06, 0.06)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.7, 0.8, 0.9, 0.5) if weather == "rain" else Color(1, 1, 1, 0.9)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = mm
	gp.draw_pass_1 = qm
	gp.position = Vector3(0, 10, 0)
	gp.visibility_aabb = AABB(Vector3(-20, -15, -20), Vector3(40, 20, 40))
	world_root.add_child(gp)
	gp.set_meta("follow", true)
	precip = gp

var precip: GPUParticles3D

# ---------------- игра ----------------
func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	parcel_t += dt
	var inp := _bot_input() if bot >= 0.0 else axis()
	var run := (Input.is_physical_key_pressed(KEY_SHIFT) if bot < 0.0 else bot > 0.5 and stamina > 0.3) and stamina > 0.05
	stamina = clampf(stamina + (-0.35 if run and inp.length() > 0.1 else 0.22) * dt, 0.0, 1.0)
	var spd := (5.2 if run else 3.0) * (1.0 + cv("deliv_speed") + (0.3 if eq("deliv") >= 3 else 0.0)) * (0.8 if weather == "snow" else 1.0)
	if stumble_t > 0.0:
		stumble_t -= dt
		spd *= 0.3
	# идёт относительно камеры
	var cf := -cam.global_basis.z
	cf.y = 0
	cf = cf.normalized()
	var cr := cf.cross(Vector3.UP)
	var want := (cr * inp.x - cf * inp.y) * spd
	var grip := 10.0
	for pd in puddles:
		if Vector2(pos.x, pos.z).distance_to(pd[0]) < float(pd[1]):
			grip = 2.2                              # лужа: скользко, не остановиться
	vel = vel.lerp(want, 1.0 - exp(-grip * dt))
	var np := pos + vel * dt
	np = _collide(np, vel.length())
	pos = np
	pahan.position = pos
	if vel.length() > 0.3:
		yaw = lerp_angle(yaw, atan2(vel.x, vel.z), 1.0 - exp(-10.0 * dt))
		pahan.play("Run", 0.15, clampf(vel.length() / 4.0, 0.4, 1.4))
	else:
		pahan.play("Block", 0.2)                    # стоит, держит коробку перед собой
	pahan.rotation.y = yaw
	box_node.visible = cur < parcels.size()
	_ped_tick(dt)
	# адрес, стрелка, сдача
	if cur < parcels.size():
		var tgt := _target()
		var to := tgt - pos
		arrow.position = pos + Vector3(0, 2.6, 0)
		arrow.rotation.y = atan2(to.x, to.z) + PI
		var P: Dictionary = parcels[cur]
		task_l.text = "%s%s · %s · %d/%d" % [P["name"], " (ждёт на лавке у площадки)" if String(P["quirk"]) == "bench" else "", "ХРУПКОЕ" if bool(P["fragile"]) else "обычная", cur + 1, parcels.size()]
		score_l.text = "посылка %d%% · %d м" % [int(float(P["cond"]) * 100.0), int(to.length())]
		if to.length() < 1.6:
			_deliver()
	progress(float(cur) / float(parcels.size()))
	tip_l.text = "ВЫНОСЛИВОСТЬ: %s" % ("▮".repeat(int(stamina * 10.0)) + "▯".repeat(10 - int(stamina * 10.0)))
	combo_l.text = "ЦЕПОЧКА ×%d" % chain if chain >= 2 else ""
	# камера: сзади-сверху за Паханом
	var back := Vector3(sin(yaw), 0, cos(yaw))
	cam.position = cam.position.lerp(pos - back * 6.0 + Vector3(0, 4.5, 0), 1.0 - exp(-3.0 * dt))
	cam.look_at(pos + Vector3(0, 1.2, 0), Vector3.UP)
	if precip != null:
		precip.position = pos + Vector3(0, 10, 0)
	if cur >= parcels.size():
		_end()

func _collide(np: Vector3, v: float) -> Vector3:
	var p := Vector2(np.x, np.z)
	p = p.clamp(Vector2(-SIZE + 1, -SIZE + 1), Vector2(SIZE - 1, SIZE - 1))
	var hit := false
	for o in obst:
		var c: Vector2 = o["c"]
		var r: float = float(o["r"]) + 0.35
		if p.distance_to(c) < r:
			p = c + (p - c).normalized() * r
			hit = true
	for o in rects:
		var c: Vector2 = o["c"]
		var h: Vector2 = o["h"]
		if absf(p.x - c.x) < h.x and absf(p.y - c.y) < h.y:
			if h.x - absf(p.x - c.x) < h.y - absf(p.y - c.y):
				p.x = c.x + signf(p.x - c.x) * h.x
			else:
				p.y = c.y + signf(p.y - c.y) * h.y
	if hit and v > 3.6:
		_bump(0.12)
	return Vector3(p.x, 0, p.y)

func _bump(k: float) -> void:
	if stumble_t > 0.0 or cur >= parcels.size():
		return
	var P: Dictionary = parcels[cur]
	var loss := k * (2.0 if bool(P["fragile"]) else 1.0) * (0.5 if eq("deliv") >= 1 else 1.0)
	P["cond"] = maxf(0.0, float(P["cond"]) - loss)
	hits += 1
	stumble_t = 0.6
	vel *= -0.3
	sfx("drop", 0.8)
	pop("ПОСЫЛКА −%d%%" % int(loss * 100.0), pos + Vector3(0, 2.0, 0), RED)

func _ped_tick(dt: float) -> void:
	for pd in peds:
		pd["t"] = float(pd["t"]) + dt * float(pd["spd"])
		var u := pingpong(float(pd["t"]), 1.0)
		var r: Rig = pd["rig"]
		var a: Vector3 = pd["a"]
		var b: Vector3 = pd["b"]
		var p := a.lerp(b, u)
		var dir := (b - a) * (1.0 if fposmod(float(pd["t"]), 2.0) < 1.0 else -1.0)
		r.position = p
		r.rotation.y = atan2(dir.x, dir.z)
		if p.distance_to(pos) < 0.75 and vel.length() > 2.5:
			_bump(0.15)
			sfx("hm", 1.2)

func _deliver() -> void:
	var P: Dictionary = parcels[cur]
	P["done"] = true
	var fast := parcel_t < 14.0
	chain = chain + 1 if fast and float(P["cond"]) > 0.6 else 0
	best_chain = maxi(best_chain, chain)
	sfx("ok")
	sfx("coins", 1.1)
	pop("ДОСТАВЛЕНО" + (" · ЦЕПОЧКА ×%d" % chain if chain >= 2 else ""), pos + Vector3(0, 2.2, 0), GREEN)
	puff(pos + Vector3(0, 1.0, 0.4), Color(0.9, 0.85, 0.6), 6)
	cur += 1
	parcel_t = 0.0

# ---------------- бот ----------------
func _bot_input() -> Vector2:
	if cur >= parcels.size():
		return Vector2.ZERO
	var tgt := _target()
	var to := tgt - pos
	to.y = 0
	var d := to.normalized()
	# объезд препятствий: ближайший круг впереди — в сторону
	for o in obst:
		var c: Vector2 = o["c"]
		var rel := c - Vector2(pos.x, pos.z)
		if rel.length() < float(o["r"]) + 1.6 and rel.dot(Vector2(d.x, d.z)) > 0.0:
			var side := Vector2(-rel.y, rel.x).normalized()
			d = (d + Vector3(side.x, 0, side.y) * 1.2).normalized()
	for o in rects:
		var c: Vector2 = o["c"]
		var h: Vector2 = o["h"]
		var ahead := Vector2(pos.x, pos.z) + Vector2(d.x, d.z) * 1.5
		if absf(ahead.x - c.x) < h.x + 0.5 and absf(ahead.y - c.y) < h.y + 0.5:
			d = (d + Vector3(signf(pos.x - c.x), 0, signf(pos.z - c.y)) * 0.8).normalized()
	if rng_bot.randf() > bot:
		d = d.rotated(Vector3.UP, rng_bot.randf_range(-0.6, 0.6))
	# в осях камеры: вперёд от камеры — −y
	var cf := -cam.global_basis.z
	cf.y = 0
	cf = cf.normalized()
	var cr := cf.cross(Vector3.UP)
	return Vector2(d.dot(cr), -d.dot(cf)) * lerpf(0.55, 1.0, bot)

func _end() -> void:
	if done:
		return
	var n := parcels.size()
	var ok := 0
	var cond := 0.0
	for P in parcels:
		if bool(P["done"]):
			ok += 1
			cond += float(P["cond"])
	var share := float(ok) / float(maxi(1, n))
	var cavg := cond / float(maxi(1, ok))
	var chain_b := clampf(float(best_chain) / float(maxi(2, n)), 0.0, 1.0) * (0.1 + cv("deliv_chain"))
	var time_b := clampf(time_left / time_max, 0.0, 1.0) * 0.1 if ok == n else 0.0
	var score := clampf(share * 0.65 + share * cavg * 0.2 + chain_b + time_b, 0.0, 1.0)
	show_result(score, ["Доставлено: %d из %d · погода: %s" % [ok, n, {"clear": "ясно", "rain": "дождь", "night": "вечер", "snow": "снег"}[weather]],
		"Состояние посылок: %d%% · удары: %d" % [int(cavg * 100.0), hits],
		"Лучшая цепочка: ×%d%s" % [best_chain, "  ·  быстро: +%d%%" % int(time_b * 100.0) if time_b > 0.0 else ""]])
