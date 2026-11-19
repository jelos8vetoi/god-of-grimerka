## РАЗБОР ХЛАМА — 3D-комната, заваленная вещами на настоящей физике (RigidBody3D): коробки, техника, провода,
## журналы, инструменты. Клик — поднять вещь (она всплывает перед камерой, крутится), видно, что это, состояние и
## оценку цены (без навыка — разброс, с «Глазом на хлам» — точнее). Решение: [1] ПРОДАТЬ, [2] РАЗОБРАТЬ на запчасти,
## [3] ОСТАВИТЬ себе (займёт место, вместимость — навыки), [4] бросить обратно. Решённая вещь летит в свой ящик.
## Некоторые вещи ценнее, чем выглядят (редкие — чаще с навыками). Время ограничено. Итог — как раньше:
## список [номер вещи, решение] — деньги и инвентарь считает экономика (junk_done).
class_name MLJobJunk
extends MLJob3D

var rng := RandomNumberGenerator.new()
var rng_bot := RandomNumberGenerator.new()
var items: Array = []           # {body, idx, cond, rare, est_lo, est_hi, decided}
var held := -1
var picks: Array = []
var bins := {}                  # решение → позиция ящика
var cap := 3
var kept := 0
var bot_t := 0.0
var info_l: Label
var hold_node: Node3D

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 9
	base_setup(f, sf, stress, "РАЗБОР ХЛАМА", "клик — поднять вещь · 1 ПРОДАТЬ · 2 РАЗОБРАТЬ · 3 ОСТАВИТЬ · 4 положить обратно · что-то здесь стоит денег", 45.0 + tier * 5.0)
	setup_3d(Color(0.06, 0.05, 0.045), Color(0.6, 0.55, 0.5), 0.55)
	cap = 3 + int(cv("junk_cap"))
	_room()
	_items()
	cam.fov = 52.0
	cam.look_at_from_position(Vector3(0, 2.3, 2.9), Vector3(0, 0.2, -0.9), Vector3.UP)
	hold_node = at(Vector3(0, 1.7, 1.9))
	info_l = txt(self, "", 20, WHITE, Vector2(60, 280))
	info_l.size = Vector2(520, 220)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_task()

func _room() -> void:
	room_box(Vector3(0, 0, -0.5), 7.0, 6.0, 2.8, MGProps._m(Color(0.5, 0.46, 0.4), 0.95, 0.0, 1, 1.0), MGProps._m(Color(0.3, 0.24, 0.18), 0.8, 0.0, 2, 1.2))
	light(Vector3(0, 2.6, 0), 1.8, 7.0, Color(1.0, 0.88, 0.65), true)
	light(Vector3(-2.5, 2.0, 1.5), 0.6, 5.0, Color(0.7, 0.8, 1.0))
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7, 0.2, 6)
	gs.shape = bs
	ground.add_child(gs)
	ground.position = Vector3(0, -0.1, -0.5)
	world_root.add_child(ground)
	for wx in [[Vector3(0, 1.4, -3.5), Vector3(7, 2.8, 0.2)], [Vector3(-3.5, 1.4, -0.5), Vector3(0.2, 2.8, 6)], [Vector3(3.5, 1.4, -0.5), Vector3(0.2, 2.8, 6)], [Vector3(0, 1.4, 2.6), Vector3(7, 2.8, 0.2)]]:
		var wb := StaticBody3D.new()
		var ws := CollisionShape3D.new()
		var wbs := BoxShape3D.new()
		wbs.size = wx[1]
		ws.shape = wbs
		wb.add_child(ws)
		wb.position = wx[0]
		world_root.add_child(wb)
	# шкаф и полки — для вида и физики
	MGProps.shelf(at(Vector3(-2.4, 0.05, -3.2)))
	MGProps.wardrobe(at(Vector3(2.6, 0, -2.9), -0.3))
	for k in 6:                                          # завалы по углам — для вида
		MGProps.carton(at(Vector3(-3.0 + float(k % 2) * 0.5, float(k / 2) * 0.45, -2.2 + float(k % 3) * 0.4), 0.3 * k), Vector3(0.6, 0.45, 0.5), ["", "ХЛАМ", "РАЗНОЕ"][k % 3])

	# три ящика для решений
	var names := {"sell": ["ПРОДАТЬ", Color(0.4, 0.9, 0.45)], "scrap": ["РАЗОБРАТЬ", Color(1.0, 0.7, 0.25)], "keep": ["ОСТАВИТЬ", Color(0.55, 0.85, 1.0)]}
	var k := 0
	for id in ["sell", "scrap", "keep"]:
		var p := Vector3(-1.5 + k * 1.5, 0, 1.0)
		var b := at(p)
		MGProps.carton(b, Vector3(0.9, 0.5, 0.6), "")
		MGProps.text(at(p + Vector3(0, 0.7, 0.3)), names[id][0], Vector3.ZERO, 48, names[id][1])
		bins[id] = p + Vector3(0, 0.6, 0)
		k += 1

func _items() -> void:
	var n := 9 + tier * 2
	for k in n:
		var idx := rng.randi() % MLData.JUNK.size()
		var body := RigidBody3D.new()
		body.mass = rng.randf_range(0.5, 3.0)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.45, 0.26, 0.42)
		cs.shape = sh
		body.add_child(cs)
		var vis := Node3D.new()
		body.add_child(vis)
		vis.scale = Vector3.ONE * 2.2
		vis.position.y = -0.08
		MGProps.junk_item(vis, idx)
		body.position = Vector3(rng.randf_range(-2.5, 2.5), 0.3 + k * 0.25, rng.randf_range(-2.6, 0.6))
		body.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		world_root.add_child(body)
		var it: Array = MLData.JUNK[idx]
		var rare := rng.randf() < 0.08 + cv("junk_rare")
		var cond := rng.randf_range(0.4, 1.0)
		var true_v := int(float(it[2]) * cond * (2.5 if rare else 1.0))
		var spread := clampf(0.6 - cv("junk_eval") * 0.5, 0.05, 0.6)
		items.append({"body": body, "idx": idx, "cond": cond, "rare": rare, "value": true_v, "lo": int(true_v * (1.0 - spread)), "hi": int(true_v * (1.0 + spread) + 50), "decided": false})

func _update_task() -> void:
	var left := items.filter(func(i): return not bool(i["decided"])).size()
	task_l.text = "Осталось вещей: %d · оставить можно ещё %d" % [left, cap - kept]
	progress(1.0 - float(left) / float(maxi(1, items.size())))

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	if bot >= 0.0:
		_bot(dt)
	if held >= 0:
		var b: RigidBody3D = items[held]["body"]
		b.global_position = b.global_position.lerp(hold_node.global_position, 1.0 - exp(-10.0 * dt))
		b.rotate_y(dt * 1.2)
	var got := 0
	for p in picks:
		var it: Array = MLData.JUNK[int(p[0])]
		got += int(it[2]) if p[1] == "sell" else (int(it[4]) if p[1] == "scrap" else 0)
	score_l.text = "≈ %d ₽" % got
	if items.all(func(i): return bool(i["decided"])):
		_end()

func _gui_input(e: InputEvent) -> void:
	if done or bot >= 0.0:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var from := cam.project_ray_origin(e.position)
		var dir := cam.project_ray_normal(e.position)
		var best := -1
		var bd := 0.3
		for k in items.size():
			if bool(items[k]["decided"]) or k == held:
				continue
			var p := (items[k]["body"] as RigidBody3D).global_position
			var dd := (p - from).cross(dir).length()
			if dd < bd:
				bd = dd
				best = k
		if best >= 0:
			pick(best)

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.physical_keycode:
		KEY_1:
			decide("sell")
		KEY_2:
			decide("scrap")
		KEY_3:
			decide("keep")
		KEY_4:
			drop()

## поднять вещь: всплывает перед камерой, видно что это и сколько может стоить
func pick(k: int) -> void:
	if held >= 0:
		drop()
	held = k
	var b: RigidBody3D = items[k]["body"]
	b.freeze = true
	var I: Dictionary = items[k]
	var it: Array = MLData.JUNK[int(I["idx"])]
	sfx("open", 1.2)
	info_l.text = "%s%s\n%s\nсостояние: %d%%\nпродать: %s\nразобрать: %d ₽ · Гене: %s\n\n[1] ПРОДАТЬ  [2] РАЗОБРАТЬ  [3] ОСТАВИТЬ  [4] обратно" % [
		it[0], "  ★ РЕДКАЯ" if bool(I["rare"]) and cv("junk_eval") > 0.0 else "", it[1], int(float(I["cond"]) * 100.0),
		("%d ₽" % int(I["value"])) if int(I["hi"]) - int(I["lo"]) < 120 else ("%d–%d ₽" % [int(I["lo"]), int(I["hi"])]), int(it[4]), ("%d ₽" % int(it[3])) if int(it[3]) > 0 else "не возьмёт"]

func drop() -> void:
	if held < 0:
		return
	var b: RigidBody3D = items[held]["body"]
	b.freeze = false
	b.linear_velocity = Vector3(randf_range(-1, 1), 0.5, -1.5)
	held = -1
	info_l.text = ""
	sfx("drop")

func decide(kind: String) -> void:
	if held < 0:
		return
	if kind == "keep" and kept >= cap:
		sfx("fail")
		tip_l.text = "МЕСТА НЕТ — продай или разбери"
		return
	var I: Dictionary = items[held]
	I["decided"] = true
	if kind == "keep":
		kept += 1
	# в «Микрозаймах» цена вещи — из данных; редкая продаётся дороже — добавляем вещь «дороже» через экономику
	picks.append([int(I["idx"]), kind])
	if kind == "sell" and bool(I["rare"]):
		picks.append([int(I["idx"]), "sell"])          # редкая: коллекционер платит вдвое
	var b: RigidBody3D = I["body"]
	b.freeze = false
	var to: Vector3 = bins[kind]
	b.linear_velocity = (to - b.global_position) * 1.6 + Vector3(0, 3.0, 0)
	b.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	sfx({"sell": "coins", "scrap": "keys", "keep": "tab"}[kind])
	pop({"sell": "ПРОДАТЬ", "scrap": "НА ЗАПЧАСТИ", "keep": "СЕБЕ"}[kind], b.global_position + Vector3(0, 0.3, 0), {"sell": GREEN, "scrap": Color(1, 0.7, 0.25), "keep": Color(0.55, 0.85, 1.0)}[kind])
	var bid := b.get_instance_id()
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func():
		var o := instance_from_id(bid)
		if o != null:
			(o as Node).queue_free())
	held = -1
	info_l.text = ""
	_update_task()

## бот: поднимает по очереди и решает по настоящей цене (плохой бот путается)
func _bot(dt: float) -> void:
	bot_t -= dt
	if bot_t > 0.0:
		return
	bot_t = lerpf(0.8, 0.2, bot)
	if held < 0:
		for k in items.size():
			if not bool(items[k]["decided"]):
				pick(k)
				return
		return
	var I: Dictionary = items[held]
	var it: Array = MLData.JUNK[int(I["idx"])]
	var kind := "sell" if int(it[2]) >= int(it[4]) else "scrap"
	if int(it[3]) >= 1500 and kept < cap:
		kind = "keep"
	if rng_bot.randf() > bot:
		kind = ["sell", "scrap"][rng_bot.randi() % 2]
	decide(kind)

func _end() -> void:
	if done:
		return
	var sold := picks.filter(func(p): return p[1] == "sell").size()
	var scr := picks.filter(func(p): return p[1] == "scrap").size()
	show_result(1.0, ["Разобрано вещей: %d из %d" % [items.filter(func(i): return bool(i["decided"])).size(), items.size()],
		"Продать: %d · на запчасти: %d · себе: %d" % [sold, scr, kept],
		"Деньги посчитает скупщик — смотри уведомление"], picks)
