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
var info_t: Label
var info_p: PanelContainer
var hold_node: Node3D
var stash_idx := 0              # что лежит в тайнике (вещь из MLData.JUNK ценой около 900 ₽)
var stash_found := 0
var stash_lost := 0
var shakes := 0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	rng.seed = seed_v
	rng_bot.seed = seed_v + 9
	keys = [["ЛКМ", "поднять"], ["1", "продать"], ["2", "разобрать"], ["3", "оставить"], ["4", "положить"], ["F", "потрясти"]]
	base_setup(f, sf, stress, "РАЗБОР ХЛАМА", "", 45.0 + tier * 5.0)
	setup_3d(Color(0.06, 0.05, 0.045), Color(0.6, 0.55, 0.5), 0.55)
	cap = 3 + int(cv("junk_cap"))
	_room()
	_items()
	cam.fov = 52.0
	cam.look_at_from_position(Vector3(0, 2.3, 2.9), Vector3(0, 0.2, -0.9), Vector3.UP)
	hold_node = at(Vector3(0, 1.7, 1.9))
	info_p = MGUI.panel(true, MGUI.GOLD, MGUI.S3)
	info_p.position = Vector2(16, 130)
	info_p.custom_minimum_size = Vector2(340, 0)
	info_p.visible = false
	add_child(info_p)
	var iv := MGUI.vbox(MGUI.S1)
	info_p.add_child(iv)
	hints_on("ml_junk", MGHintsData.JUNK)
	info_t = MGUI.label("", "h2", null, 316.0)
	iv.add_child(info_t)
	info_l = MGUI.label("", "small", MGUI.TEXT_2, 316.0)
	iv.add_child(info_l)
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
	MGModels.spawn("ml_wardrobe", world_root, Vector3(2.6, 0, -2.9), -0.3, Vector3(1.2, 2.0, 0.6), func(r): MGProps.wardrobe(r))
	if MGModels.has("ml_job_junk_crate"):
		MGModels.spawn("ml_job_junk_crate", world_root, Vector3(2.3, 0, -1.2), -0.5, Vector3(0.9, 0.98, 0.85), func(_r): pass)
	if MGModels.has("ml_job_old_tv"):
		MGModels.spawn("ml_job_old_tv", world_root, Vector3(-2.5, 0, -0.9), 0.7, Vector3(0.9, 1.0, 0.6), func(_r): pass)
	for k in 6:                                          # завалы по углам — для вида
		@warning_ignore("integer_division")
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

	# тайники: в одной-двух вещах что-то спрятано. Узнать — потрясти [F] (стоит времени). Разобрал такую — нашёл
	# заначку; продал целиком — она ушла скупщику. Тайник кладётся в вещи, которые выгоднее продать: вот и выбор.
	var bd := INF
	for k in MLData.JUNK.size():
		var dv := absf(float(MLData.JUNK[k][2]) - 900.0)
		if dv < bd:
			bd = dv
			stash_idx = k
	var cand := items.filter(func(i): return int(MLData.JUNK[int(i["idx"])][2]) > int(MLData.JUNK[int(i["idx"])][4]))
	for k in mini(cand.size(), 2 if tier >= 3 else 1):
		cand[(k * 3 + rng.randi() % 3) % cand.size()]["stash"] = true

## потрясти вещь в руках: гремит — внутри тайник
func shake() -> void:
	if held < 0 or done:
		return
	var I: Dictionary = items[held]
	if I.has("shaken"):
		return
	I["shaken"] = true
	shakes += 1
	time_left -= 1.2
	var b: RigidBody3D = I["body"]
	var tw := b.create_tween()
	for q in 4:
		tw.tween_property(b, "rotation:z", 0.35 if q % 2 == 0 else -0.35, 0.07)
	tw.tween_property(b, "rotation:z", 0.0, 0.07)
	var has: bool = I.has("stash")
	sfx("keys" if has else "tick", 0.8 if has else 0.6)
	pop("ГРЕМИТ!" if has else "пусто", b.global_position + Vector3(0, 0.35, 0), MGUI.GOLD if has else GREY)
	info_l.text += "\n" + ("Внутри что-то гремит — разбери!" if has else "Внутри пусто.")

func _update_task() -> void:
	var left := items.filter(func(i): return not bool(i["decided"])).size()
	task_l.text = "Осталось вещей: %d · места для себя: %d" % [left, cap - kept]
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
	score_l.text = "набрано ≈ %s" % MGUI.rub(got)
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
		KEY_F:
			shake()

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
	hint("shake")
	if bool(I["rare"]) and cv("junk_eval") > 0.0:
		hint("rare")
	info_p.visible = true
	info_t.text = String(it[0]) + ("  · редкая" if bool(I["rare"]) and cv("junk_eval") > 0.0 else "")
	info_l.text = "%s\nСостояние %d%%\nПродать: %s\nРазобрать: %s · Гене: %s" % [
		String(it[1]).capitalize().left(1) + String(it[1]).substr(1), int(float(I["cond"]) * 100.0),
		MGUI.rub(int(I["value"])) if int(I["hi"]) - int(I["lo"]) < 120 else ("%d–%s" % [int(I["lo"]), MGUI.rub(int(I["hi"]))]), MGUI.rub(int(it[4])), MGUI.rub(int(it[3])) if int(it[3]) > 0 else "не возьмёт"]

func drop() -> void:
	if held < 0:
		return
	var b: RigidBody3D = items[held]["body"]
	b.freeze = false
	b.linear_velocity = Vector3(randf_range(-1, 1), 0.5, -1.5)
	held = -1
	info_p.visible = false
	sfx("drop")

func decide(kind: String) -> void:
	if held < 0:
		return
	if kind == "keep" and kept >= cap:
		sfx("fail")
		tip_l.text = "Места нет — продай или разбери"
		hint("cap")
		return
	var I: Dictionary = items[held]
	I["decided"] = true
	if kind == "keep":
		kept += 1
	# в «Микрозаймах» цена вещи — из данных; редкая продаётся дороже — добавляем вещь «дороже» через экономику
	picks.append([int(I["idx"]), kind])
	if kind == "sell" and bool(I["rare"]):
		picks.append([int(I["idx"]), "sell"])          # редкая: коллекционер платит вдвое
	if I.has("stash"):
		if kind == "scrap":
			stash_found += 1
			picks.append([stash_idx, "sell"])          # заначка из корпуса — отдельной вещью скупщику
			sfx("coins", 1.5)
			pop("ТАЙНИК! +%s" % MGUI.rub(int(MLData.JUNK[stash_idx][2])), (I["body"] as Node3D).global_position + Vector3(0, 0.7, 0), MGUI.GOLD)
		else:
			stash_lost += 1
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
	info_p.visible = false
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
	elif kind == "sell" and not I.has("shaken"):
		shake()                                      # внимательный игрок трясёт то, что собрался продать целиком
		return
	elif I.has("stash"):
		kind = "scrap"
	decide(kind)

func _end() -> void:
	if done:
		return
	var sold := picks.filter(func(p): return p[1] == "sell").size()
	var scr := picks.filter(func(p): return p[1] == "scrap").size()
	show_result(1.0, ["Разобрано вещей: %d из %d" % [items.filter(func(i): return bool(i["decided"])).size(), items.size()],
		"Продать: %d · на запчасти: %d · себе: %d" % [sold, scr, kept],
		("Тайники: найдено %d, ушло скупщику %d" % [stash_found, stash_lost]) if stash_found + stash_lost > 0 else "Деньги посчитает скупщик — смотри уведомление"], picks)
