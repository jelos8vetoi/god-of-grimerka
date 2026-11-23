## Проверка стиля «Водяра», этап 2: -- --bottlecheck=<папка>, запускать с --resolution 1280x720.
## Две бутылки в руках и возврат брошенной из кармана, удары вплотную и броски издалека, связки удар ↔ бросок,
## двойной бросок с двух рук, рикошет, LAST DROP, бросок в прыжке, на бегу и в скольжении, вариация покоя.
## В конце — «BOTTLECHECK ok» или «BOTTLECHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var B: Bottles
var started := false
var frame_n := 0
var log_ids: Array = []

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("BOTTLE ok: " if c else "BOTTLE ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nm))

func tap(a: String) -> void:
	await get_tree().physics_frame
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}

var hooked := false

func stage() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	B = P.bottles
	if P.hero != "pahan":
		game.swap_heroes()
	await frames(2)
	game.tag.reset()
	if not hooked:
		hooked = true
		P.combat.attack_started.connect(func(a: AttackData) -> void: log_ids.append(a.id))
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.7
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 9999.0
	P.swag = 0.0
	P.auto_input = {}
	P.combat.interrupt()
	game.buddy.global_position = Vector3(-9, 0.05, 10)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await frames(40)
	if P.style.id != "bottles":
		await tap("style2")
		var n := 0
		while (P.state == "switch" or P.switch_to != "") and n < 150:
			await get_tree().physics_frame
			n += 1
		await frames(40)
	P.combat.ammo["bottles"] = 6.0
	P.combat.windows.clear()
	B.hits_log = []
	B.rico_log = []
	log_ids = []
	await frames(4)

func foe(at: Vector3, hp := 9999.0):
	var e = game._make_enemy("bot", "", P.global_position + at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

## держать врагов на месте: они не подходят и не бьют
func pin(list: Array, at: Array) -> void:
	for i in list.size():
		if is_instance_valid(list[i]) and list[i].alive():
			list[i].cool = 999.0
			if list[i].state == "chase":
				list[i].global_position = at[i]

func until_free(max_frames := 300) -> void:
	var n := 0
	while P.state != "move" and n < max_frames:
		await get_tree().physics_frame
		n += 1

## цепочка нажатий: каждое — в окне комбо предыдущей атаки
func chain(acts: Array) -> void:
	for i in acts.size():
		if i > 0:
			var n := 0
			while not P.combat.in_combo_window() and P.state == "attack" and n < 240:
				await get_tree().physics_frame
				n += 1
		await tap(acts[i])
		await frames(2)

func _run() -> void:
	# ================= 1. две бутылки в руках =================
	await stage()
	ok(B.prop_att.visible and B.prop_l_att.visible, "в стойке бутылки в обеих руках")
	await shot("01_two_bottles.png")
	await tap("attack")
	var n := 0
	while P.combat.hit_i == 0 and n < 120:
		await get_tree().physics_frame
		n += 1
	await frames(2)
	var gone: bool = not B.prop_att.visible and B.prop_l_att.visible
	var k_gone: float = P.combat.k()
	while P.state == "attack" and P.combat.k() < 0.86:
		await get_tree().physics_frame
	await frames(2)
	var back_in: bool = B.prop_att.visible
	await until_free()
	ok(gone and back_in and k_gone < 0.6, "бросок: правая рука пустеет (на %.0f%% клипа), бутылка возвращается, когда рука доходит до кармана" % (k_gone * 100.0))
	P.combat.ammo["bottles"] = 1.0
	await frames(3)
	var one: bool = B.prop_att.visible and not B.prop_l_att.visible
	P.combat.ammo["bottles"] = 0.2
	await frames(3)
	ok(one and not B.prop_att.visible and not B.prop_l_att.visible, "запас 1 — бутылка только в правой; запас пуст — руки пустые")
	# ================= 2. издалека — броски =================
	await stage()
	var _far = foe(Vector3(0, 0, -8.0))
	await frames(4)
	var am0: float = P.combat.ammo_of("bottles")
	await chain(["attack", "attack", "attack", "attack"])
	await until_free(400)
	ok(log_ids == ["bt_quick", "bt_side", "bt_over", "bt_fan"] and am0 - P.combat.ammo_of("bottles") > 5.0, "издалека ЛКМ ×4: %s, потрачено %.0f бутылок" % [str(log_ids), am0 - P.combat.ammo_of("bottles")])
	# ================= 3. вплотную — удары, запас цел =================
	await stage()
	var near = foe(Vector3(0, 0, -1.9))
	await frames(4)
	am0 = P.combat.ammo_of("bottles")
	var h0: float = near.hp
	P.auto_input = {}
	for i in 5:
		if i > 0:
			n = 0
			while not P.combat.in_combo_window() and P.state == "attack" and n < 240:
				near.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 1.9
				near.kb = Vector3.ZERO
				await get_tree().physics_frame
				n += 1
		await tap("attack")
		await frames(2)
		if i == 2:
			await frames(10)
			await shot("02_double_smash.png")
	await until_free(400)
	ok(log_ids == ["bt_jab", "bt_rev", "bt_dsmash", "bt_spinback", "bt_crush"] and abs(P.combat.ammo_of("bottles") - am0) < 0.6 and h0 - near.hp > 60.0 and B.hits_log.is_empty(), "вплотную ЛКМ ×5: %s; бутылки не тратятся, урон %.0f" % [str(log_ids), h0 - near.hp])
	# CLOSE QUARTERS и удар → бросок
	await stage()
	near = foe(Vector3(0, 0, -1.9))
	await frames(4)
	for act in ["attack", "heavy", "attack", "throw"]:
		n = 0
		while log_ids.size() > 0 and not P.combat.in_combo_window() and P.state == "attack" and n < 240:
			near.global_position = P.global_position + Vector3(sin(P.face), 0, cos(P.face)) * 1.9
			near.kb = Vector3.ZERO
			await get_tree().physics_frame
			n += 1
		await tap(act)
		await frames(2)
	await until_free(400)
	ok(log_ids == ["bt_jab", "bt_elbow", "bt_rev", "bt_close"] and B.hits_log.size() == 1, "CLOSE QUARTERS: тычок → локтем → наотмашь → бросок в упор (%s), бутылка попала" % str(log_ids))
	await stage()
	near = foe(Vector3(0, 0, -1.9))
	await frames(4)
	await chain(["attack", "throw"])
	await until_free(400)
	ok(log_ids == ["bt_jab", "bt_backhand"], "удар × бросок: тычок → F — бросок наотмашь (%s)" % str(log_ids))
	# ================= 4. двойной с двух рук =================
	await stage()
	var e1 = foe(Vector3(-2.0, 0, -8.0))
	var e2 = foe(Vector3(2.0, 0, -8.0))
	await frames(4)
	await chain(["attack", "heavy"])
	n = 0
	while B.flying.size() < 2 and n < 120:
		await get_tree().physics_frame
		n += 1
	var two: bool = B.flying.size() >= 2
	var apart := 0.0
	if two:
		apart = (B.flying[B.flying.size() - 1]["node"] as Node3D).global_position.distance_to((B.flying[B.flying.size() - 2]["node"] as Node3D).global_position)
	await shot("03_double_throw.png")
	var hands_empty: bool = not B.prop_att.visible and not B.prop_l_att.visible
	await until_free(400)
	await frames(60)
	ok(log_ids == ["bt_quick", "bt_double"] and two and apart > 0.25 and hands_empty and e1.hp < 9999.0 and e2.hp < 9999.0, "ДВОЙНОЙ ВСПЛЕСК: две бутылки с двух рук (между ними %.2f м), обе руки пустеют, оба врага облиты" % apart)
	# ================= 5. рикошет =================
	await stage()
	var r1 = foe(Vector3(0, 0, -7.0))
	var r2 = foe(Vector3(3.5, 0, -8.5))
	var r3 = foe(Vector3(-3.0, 0, -10.0))
	var spots := [r1.global_position, r2.global_position, r3.global_position]
	await frames(4)
	for i in 3:
		if i > 0:
			n = 0
			while not P.combat.in_combo_window() and P.state == "attack" and n < 240:
				pin([r1, r2, r3], spots)
				await get_tree().physics_frame
				n += 1
		B.hits_log = []
		for e in [r1, r2, r3]:
			e.hp = 9999.0
		await tap(["attack", "attack", "heavy"][i])
		await frames(2)
	for i in 150:
		pin([r1, r2, r3], spots)
		await get_tree().physics_frame
		if i == 30:
			await shot("04_ricochet.png")
	var d1: float = 9999.0 - r1.hp
	var d2: float = 9999.0 - r2.hp
	var d3: float = 9999.0 - r3.hp
	ok(log_ids == ["bt_quick", "bt_side", "bt_rico"] and B.rico_log.size() >= 2 and d1 > 0.0 and d2 > 0.0 and d3 > 0.0, "РИКОШЕТ: бутылка отскочила %d раза, задеты все трое (урон %.1f, %.1f, %.1f — каждый отскок слабее)" % [B.rico_log.size(), d1, d2, d3])
	# ================= 6. LAST DROP =================
	await stage()
	var ld = foe(Vector3(0, 0, -7.0), 400.0)
	await frames(4)
	P.auto_input = {"heavy": "press"}
	await get_tree().physics_frame
	P.auto_input = {"heavy": "hold"}
	await frames(50)
	P.auto_input = {}
	await frames(60)
	var plain: float = 400.0 - ld.hp
	await until_free(400)
	ld.hp = 400.0
	ld.stun(4.0)
	B.hits_log = []
	P.auto_input = {"heavy": "press"}
	await get_tree().physics_frame
	P.auto_input = {"heavy": "hold"}
	await frames(50)
	P.auto_input = {}
	await frames(60)
	var boosted: float = 400.0 - ld.hp
	ok(plain > 0.0 and boosted > plain * 2.0 and B.hits_log.size() > 0 and B.hits_log[0].get("last_drop", false), "LAST DROP: усиленный бросок по оглушённому — %.0f урона против %.0f по стоящему" % [boosted, plain])
	await until_free(400)
	# ================= 7. в прыжке, на бегу, в скольжении =================
	await stage()
	var _j = foe(Vector3(0, 0, -7.0))
	await frames(4)
	await tap("jump")
	await frames(12)
	await tap("attack")
	n = 0
	while B.flying.is_empty() and n < 90:
		await get_tree().physics_frame
		n += 1
	var from_y: float = (B.flying[0]["node"] as Node3D).global_position.y if not B.flying.is_empty() else 0.0
	await shot("05_jump_throw.png")
	n = 0
	while not P.combat.in_combo_window() and P.state == "attack" and n < 120:
		await get_tree().physics_frame
		n += 1
	await tap("attack")
	await frames(3)
	await until_free(400)
	ok(log_ids == ["bt_jump", "bt_air"] and from_y > 1.6, "в прыжке: бросок сверху (бутылка вылетела с высоты %.1f м) → удар бутылкой сверху (%s)" % [from_y, str(log_ids)])
	await stage()
	_j = foe(Vector3(0, 0, -9.0))
	await frames(4)
	var z0: float = P.global_position.z
	P.combat.open("sprint", 0.3)
	await tap("attack")
	await frames(3)
	var run_id: String = P.combat.cur.id if P.combat.cur != null else ""
	await until_free(400)
	var ran: float = z0 - P.global_position.z
	P.global_position = Vector3(0, 0.05, 4.0)
	z0 = P.global_position.z
	log_ids = []
	P.combat.open("dodge", 0.3)
	await tap("heavy")
	await frames(16)
	await shot("06_slide_throw.png")
	var slide_id: String = P.combat.cur.id if P.combat.cur != null else ""
	await until_free(400)
	var slid: float = z0 - P.global_position.z
	ok(run_id == "bt_run" and ran > 1.2 and slide_id == "bt_slide" and slid > 1.5, "бросок на бегу — герой не останавливается (%.1f м), бросок в скольжении после уклонения — проезжает %.1f м" % [ran, slid])
	await stage()
	_j = foe(Vector3(0, 0, -7.0))
	await frames(4)
	P.combat.open("perfect", 0.3)
	await tap("attack")
	await frames(3)
	ok(P.combat.cur != null and P.combat.cur.id == "bt_double", "точное уклонение × ЛКМ — двойной бросок (%s)" % (P.combat.cur.id if P.combat.cur != null else "—"))
	await until_free(400)
	# ================= 8. вариация покоя =================
	await stage()
	P.idle_var_t = 0.0
	P.idle_var_next = 0.5
	await frames(70)
	ok(P.rig.cur == "BtIdleVar", "от безделья Пахан крутит бутылку в кисти (%s)" % P.rig.cur)
	# ================= 9. F из комбо балоном: бутылка левой рукой =================
	await stage()
	await tap("style1")
	n = 0
	while (P.state == "switch" or P.switch_to != "") and n < 150:
		await get_tree().physics_frame
		n += 1
	await frames(40)
	var _fb = foe(Vector3(0, 0, -2.2))
	await frames(4)
	B.hits_log = []
	log_ids = []
	await chain(["attack", "throw"])
	await frames(40)
	ok(log_ids == ["vz_light1", "vz_bottle"] and not B.hits_log.is_empty() and B.hits_log[0]["kind"] == "enemy" and not P.rig.holstered, "балон: ЛКМ → F — бутылка левой рукой попала по врагу (%s, попаданий %d: %s), балон в руке" % [str(log_ids), B.hits_log.size(), str(B.hits_log.map(func(x): return x["kind"]))])
	await until_free(400)
	print("BOTTLECHECK ok" if fails == 0 else "BOTTLECHECK ОШИБОК: %d" % fails)
	get_tree().quit()
