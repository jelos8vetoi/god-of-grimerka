## Проверка стиля «ТЯГА-812», этап 3: -- --tyagacheck=<папка>, запускать с --resolution 1280x720.
## Кости шланга и трубы (труба идёт за руками), переходы режимов, приёмы на ногах (широкий, колено, в упор,
## в землю, вверх), связки режимов, перегрев, верхом — толчок, тормоз и задний ход, удар в заносе, таран бортом
## и в прыжке, падение камнем, выстрел на ходу. В конце — «TYAGACHECK ok» или «TYAGACHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var T: Tyaga
var started := false
var frame_n := 0

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
	print(("TYAGA ok: " if c else "TYAGA ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

## крупный план сбоку своей камерой: видно трубу, шланг и руки
func close(name: String, side := 1.0) -> void:
	var f := Vector3(sin(P.face), 0, cos(P.face))
	var r := f.cross(Vector3.UP)
	var at: Vector3 = P.global_position + Vector3(0, 0.75, 0) + f * 0.3
	cam.global_position = at + r * 2.5 * side + f * 1.1 + Vector3(0, 0.55, 0)
	cam.look_at(at, Vector3.UP)
	cam.fov = 50.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	cam.clear_current(true)

func tap(a: String, keep := {}) -> void:
	await get_tree().physics_frame
	var d: Dictionary = keep.duplicate()
	d[a] = "press"
	P.auto_input = d
	await get_tree().physics_frame
	P.auto_input = keep.duplicate()

## был ли такой случай у пылесоса; -1 — нет, иначе второе поле события
func ev(tag: String):
	for e in T.events:
		if String(e[0]) == tag:
			return e[1]
	return -1

func has_link(s: String) -> bool:
	for e in T.events:
		if String(e[0]) == "link" and String(e[1]) == s:
			return true
	return false

func wait_mode(m: String, max_frames := 240) -> void:
	var n := 0
	while T.mode != m and n < max_frames:
		await get_tree().physics_frame
		n += 1

func stage(at := Vector3(0, 0.05, 4.0)) -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	T = P.tyaga
	if P.hero != "pahan":
		game.swap_heroes()
	await frames(2)
	game.tag.reset()
	P.global_position = at
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	P.inv = 9999.0
	P.swag = 0.0
	P.auto_input = {}
	P.combat.interrupt()
	game.buddy.global_position = Vector3(-14, 0.05, 14)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	if T.riding():
		T._to_hold()
	if P.state != "tyaga":
		P.state = "move"
	await frames(20)
	if P.style.id != "tyaga812":
		await tap("style3")
		var n := 0
		while (P.state == "switch" or P.switch_to != "") and n < 150:
			await get_tree().physics_frame
			n += 1
	await wait_mode("hold")
	await frames(30)
	P.global_position = at
	P.face = PI
	T.heat = 0.0
	T.lock = 0.0
	T.events = []
	T.thrown = []
	T.link_t = 0.0
	T.kick_cd = 0.0
	await frames(6)

func foe(at: Vector3, hp := 9999.0):
	var e = game._make_enemy("bot", "", P.global_position + at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = hp
	e.hp = hp
	return e

func mount() -> void:
	await tap("heat")
	await wait_mode("ride")
	await frames(6)

## разогнаться вперёд до скорости v (сразу, без ожидания)
func cruise(v: float) -> void:
	T.heading = PI
	T.vdir = Vector3(0, 0, -1)
	T.speed = v
	T.kick_cd = 1.0
	P.face = PI

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	var st := Styles.by_id("tyaga812")
	ok(st.problems().is_empty() and st.attacks.size() == 17, "стиль: %d воздействий, данные согласованы" % st.attacks.size())
	var bad_links := []
	for k in StyleTyaga.LINKS:
		if not st.attacks.has(k):
			bad_links.append(k)
		for v in StyleTyaga.LINKS[k]:
			if not st.attacks.has(v):
				bad_links.append(v)
	ok(bad_links.is_empty() and StyleTyaga.LINKS.size() >= 8, "связки режимов: %d узлов, все приёмы существуют %s" % [StyleTyaga.LINKS.size(), str(bad_links)])

	# ================= 1. кости шланга =================
	await stage()
	var clips_ok := true
	for id in st.attacks:
		if not P.rig.has_clip((st.attacks[id] as AttackData).clip):
			clips_ok = false
			print("TYAGA нет клипа: ", id, " ", (st.attacks[id] as AttackData).clip)
	for c in ["TyagaSuckIn", "TyagaSuckOut", "TyagaOverheat", "RideKick", "RideBrake", "RideReverse", "RideSlam", "RideShot"]:
		if not P.rig.has_clip(c):
			clips_ok = false
			print("TYAGA нет клипа: ", c)
	ok(clips_ok, "у каждого приёма и перехода есть клип")
	await frames(20)
	var rest_ang: float = T.wand_q.get_angle()
	var rest_off: float = T.wand_p.length() * TyagaClips.K
	ok(T.hskel != null and T.hskel.get_bone_count() == Tyaga.HOSE_N + 1, "кости построены в коде: %d (корпус, звенья шланга, труба)" % (T.hskel.get_bone_count() if T.hskel != null else 0))
	ok(rest_ang < 0.2 and rest_off < 0.1, "в стойке труба на месте: повёрнута на %.2f рад, сдвинута на %.2f м" % [rest_ang, rest_off])
	# веса: щётка и ручка — труба, верх корпуса — корпус, шланг между ними — плавно
	var w_brush: float = Tyaga.hose_w(Tyaga.to_model(TyagaClips.NOZZLE))
	var w_grip: float = Tyaga.hose_w(Tyaga.to_model(TyagaClips.TUBE_HI))
	var w_seat: float = Tyaga.hose_w(Tyaga.to_model(TyagaClips.SEAT))
	var w_hose_hi: float = Tyaga.hose_w(Vector3(42.0, 70.0, -34.0))
	var w_hose_lo: float = Tyaga.hose_w(Vector3(45.0, 25.0, -34.0))
	ok(w_brush == 1.0 and w_grip == 1.0 and w_seat == 0.0 and w_hose_hi > w_hose_lo and w_hose_hi < 1.0 and w_hose_lo > 0.0, "веса: щётка %.1f, ручка %.1f, сиденье %.1f, шланг сверху %.2f и снизу %.2f" % [w_brush, w_grip, w_seat, w_hose_hi, w_hose_lo])
	await shot("01_hold.png")
	await close("c01_hold.png")
	await close("c01_hold_left.png", -1.0)

	# ================= 2. широкий выброс: труба идёт за руками =================
	var f1 = foe(Vector3(-2.2, 0, -3.0))
	var f2 = foe(Vector3(0, 0, -3.6))
	var f3 = foe(Vector3(2.2, 0, -3.0))
	await frames(4)
	T.events = []
	await tap("throw")
	var max_ang := 0.0
	var noz_y := 0.0
	for i in 40:
		await get_tree().physics_frame
		max_ang = max(max_ang, T.wand_q.get_angle())
		noz_y = max(noz_y, T.nozzle_real().y - P.global_position.y)
		if i == 9:
			await shot("02_wide.png")
			await close("c02_wide.png")
	ok(int(ev("wide")) == 3 and f1.hp < 9999.0 and f3.hp < 9999.0, "ШИРОКИЙ: [F] — задеты трое в широком секторе (%s)" % str(ev("wide")))
	ok(max_ang > 0.25 and noz_y > 0.12, "труба идёт за руками: повернулась на %.2f рад, сопло поднялось на %.2f м" % [max_ang, noz_y])
	await wait_mode("hold")

	# ================= 3. переходы притягивания, колено, связка =================
	await stage()
	var k1 = foe(Vector3(0, 0, -4.0))
	await frames(4)
	P.auto_input = {"attack": "hold"}
	await frames(4)
	var in_clip: String = P.rig.cur
	var n := 0
	while not T.caught.has(k1.get_instance_id()) and n < 300:
		await get_tree().physics_frame
		n += 1
	await frames(12)
	var suck_clip: String = P.rig.cur
	var got: bool = T.caught.has(k1.get_instance_id())
	T.events = []
	var hp0: float = k1.hp
	await tap("throw", {"attack": "hold"})
	P.auto_input = {}
	var top := 0.0
	for i in 40:
		await get_tree().physics_frame
		top = max(top, k1.global_position.y - P.global_position.y)
		if i == 10:
			await shot("03_knee.png")
			await close("c03_knee.png")
	ok(in_clip == "TyagaSuckIn" and suck_clip == "TyagaSuck", "переход в притягивание: сначала %s, потом %s" % [in_clip, suck_clip])
	ok(got and int(ev("knee")) == 1 and has_link("tg_suck>tg_knee") and top > 0.3, "притянул → [F] КОЛЕНО: попал (%s), связка засчитана, врага подбросило на %.2f м" % [str(ev("knee")), top])
	var knee_dmg: float = hp0 - k1.hp
	var base: float = P.combat.damage_for(st.attack("tg_knee"), k1)
	ok(abs(knee_dmg - base * StyleTyaga.LINK_MUL) < 0.6, "связка усиливает: урон %.1f при обычном %.1f" % [knee_dmg, base])
	# выход из притягивания
	await stage()
	P.auto_input = {"attack": "hold"}
	await frames(30)
	P.auto_input = {}
	await frames(3)
	ok(P.rig.cur == "TyagaSuckOut", "поток оборвался — переход обратно в стойку: %s" % P.rig.cur)

	# ================= 4. в упор =================
	await stage()
	var p1 = foe(Vector3(0.3, 0, -1.7))
	await frames(4)
	T.events = []
	var z0: float = p1.global_position.z
	await tap("heavy")
	await frames(30)
	await shot("04_point.png")
	await frames(20)
	ok(int(ev("point")) == 1 and int(ev("shot")) == -1 and z0 - p1.global_position.z > 2.5, "В УПОР: короткий выброс по врагу у сопла (%s), отлетел на %.1f м" % [str(ev("point")), z0 - p1.global_position.z])
	# без врага у сопла — обычный выстрел
	await stage()
	T.events = []
	await tap("heavy")
	await frames(20)
	ok(int(ev("shot")) >= 0 and int(ev("point")) == -1, "без врага у сопла — обычный выстрел")

	# ================= 5. в землю → вверх =================
	await stage()
	var g1 = foe(Vector3(0.9, 0, -2.0))
	var g2 = foe(Vector3(-1.2, 0, -1.6))
	await frames(4)
	T.events = []
	await get_tree().physics_frame
	P.auto_input = {"heavy": "press"}
	await get_tree().physics_frame
	P.auto_input = {"heavy": "hold", "block": "hold"}
	await frames(5)
	P.auto_input = {"block": "hold"}
	await frames(2)
	P.auto_input = {}
	var low_noz := 9.0
	for i in 14:
		await get_tree().physics_frame
		low_noz = min(low_noz, T.wand_p.y * TyagaClips.K)
		if i == 11:
			await shot("05_ground.png")
			await close("c05_ground.png")
	await wait_mode("hold")
	var both_up: bool = g1.state == "air" and g2.state == "air"
	ok(int(ev("ground")) == 2 and both_up, "В ЗЕМЛЮ: ПКМ с блоком — подбросило обоих (%s, в воздухе: %s)" % [str(ev("ground")), str(both_up)])
	P.auto_input = {"heavy": "press"}
	await get_tree().physics_frame
	P.auto_input = {"heavy": "hold", "jump": "hold"}
	await frames(3)
	P.auto_input = {"jump": "hold"}
	await frames(2)
	P.auto_input = {}
	var up_ang := 0.0
	for i in 26:
		await get_tree().physics_frame
		up_ang = max(up_ang, T.wand_q.get_angle())
		if i == 10:
			await shot("06_up.png")
			await close("c06_up.png")
			await close("c06_up_left.png", -1.0)
	ok(int(ev("up")) >= 1 and has_link("tg_ground>tg_up") and up_ang > 0.8, "ВВЕРХ: ПКМ с прыжком — по подброшенным (%s), связка «в землю → вверх», сопло задрано на %.2f рад" % [str(ev("up")), up_ang])
	ok(P.state == "tyaga" and P.is_on_floor(), "прыжок и блок при этом не сработали сами по себе (состояние %s)" % P.state)

	# ================= 6. перегрев =================
	await stage()
	T.lock = 2.0
	await frames(20)
	await shot("07_overheat.png")
	await close("c07_overheat.png", -1.0)
	ok(P.rig.cur == "TyagaOverheat", "перегрев: герой отмахивается от дыма (%s)" % P.rig.cur)
	T.lock = 0.0

	# ================= 7. верхом: толчок, тормоз, задний ход =================
	await stage(Vector3(0, 0.05, 9.0))
	await mount()
	T.events = []
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(4)
	var kick_clip: String = P.rig.cur
	var v_kick: float = T.speed
	await frames(60)
	var v_run: float = T.speed
	P.auto_input = {"move": Vector2(0, -1)}
	await frames(8)
	var brake_clip: String = P.rig.cur
	n = 0
	while not T.rev and n < 120:
		await get_tree().physics_frame
		n += 1
	var h_rev: float = T.heading
	var z_rev: float = P.global_position.z
	await frames(50)
	await shot("08_reverse.png")
	await close("c08_reverse.png", -1.0)
	ok(int(ev("kick")) == 0 and kick_clip == "RideKick" and v_kick > 2.5, "с места — толчок ногой (%s, сразу %.1f м/с)" % [kick_clip, v_kick])
	ok(int(ev("brake")) == 0 and brake_clip == "RideBrake" and v_run > 9.0, "назад на ходу — торможение (%s с %.1f м/с)" % [brake_clip, v_run])
	ok(T.rev and T.speed < -3.0 and P.global_position.z - z_rev > 2.0 and abs(angle_difference(h_rev, T.heading)) < 0.3 and P.rig.cur == "RideReverse", "дотормозил и держит «назад» — задний ход: %.1f м/с, откатился на %.1f м, нос не развернулся, клип %s" % [T.speed, P.global_position.z - z_rev, P.rig.cur])
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(40)
	ok(not T.rev and T.speed > 3.0, "вперёд — снова едет вперёд (%.1f м/с)" % T.speed)

	# ================= 8. удар в заносе и выстрел на ходу =================
	await stage(Vector3(0, 0.05, 9.0))
	await mount()
	cruise(9.0)
	var d1 = foe(Vector3(1.6, 0, -2.2))
	P.auto_input = {"move": Vector2(0.6, 1), "roll": "hold"}
	await frames(6)
	T.events = []
	await tap("attack", {"move": Vector2(0.6, 1), "roll": "hold"})
	await frames(4)
	var dh_clip: String = P.rig.cur
	await shot("09_drift_hit.png")
	await frames(20)
	ok(dh_clip == "RideDriftHit" and int(ev("drift")) >= 1 and int(ev("spin")) == -1, "ЛКМ в заносе — ХЛЫСТ вместо волчка (%s, попаданий %s)" % [dh_clip, str(ev("drift"))])
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(30)
	T.events = []
	await tap("heavy", {"move": Vector2(0, 1)})
	await frames(3)
	ok(P.rig.cur == "RideShot" and int(ev("shot")) >= 0, "выстрел на ходу со своим клипом (%s)" % P.rig.cur)

	# ================= 9. таран бортом =================
	await stage(Vector3(0, 0.05, 9.0))
	await mount()
	cruise(9.0)
	T.vdir = Vector3(sin(PI + 0.9), 0, cos(PI + 0.9)).normalized()      # пылесос несёт боком
	var s1 = foe(T.vdir * 2.4)
	P.auto_input = {"move": Vector2(0, 1), "roll": "hold"}
	T.events = []
	n = 0
	while typeof(ev("side")) == TYPE_INT and typeof(ev("ram")) == TYPE_INT and n < 40:
		await get_tree().physics_frame
		n += 1
	await frames(3)
	await shot("10_side_ram.png")
	ok(typeof(ev("side")) != TYPE_INT and typeof(ev("ram")) == TYPE_INT, "в заносе пылесос бьёт БОРТОМ, а не обычным тараном (несло боком)")
	P.auto_input = {}

	# ================= 10. таран в прыжке =================
	await stage(Vector3(0, 0.05, 9.0))
	await mount()
	cruise(8.0)
	var a1 = foe(Vector3(0, 0, -3.4))
	T.events = []
	await tap("jump", {"move": Vector2(0, 1)})
	n = 0
	while typeof(ev("airram")) == TYPE_INT and typeof(ev("ram")) == TYPE_INT and n < 50:
		await get_tree().physics_frame
		n += 1
	await shot("11_air_ram.png")
	ok(typeof(ev("airram")) != TYPE_INT and typeof(ev("ram")) == TYPE_INT, "в прыжке — таран С НЕБА")
	P.auto_input = {}

	# ================= 11. падение камнем =================
	await stage(Vector3(0, 0.05, 9.0))
	await mount()
	var m1 = foe(Vector3(1.4, 0, -1.0))
	var m2 = foe(Vector3(-1.5, 0, 0.6))
	await frames(4)
	T.events = []
	await tap("jump")
	await frames(14)
	var y_top: float = P.global_position.y
	await tap("attack")
	await frames(2)
	var vy: float = P.velocity.y
	var dive_clip: String = P.rig.cur
	await shot("12_dive.png")
	await close("c12_dive.png")
	n = 0
	while int(ev("slam")) < 0 and n < 60:
		await get_tree().physics_frame
		n += 1
	await frames(2)
	await shot("13_slam.png")
	ok(int(ev("dive")) == 0 and vy < -10.0 and dive_clip == "RideSlam" and y_top > 0.8, "ЛКМ в прыжке: камнем вниз с высоты %.1f м (%.0f м/с, %s)" % [y_top, vy, dive_clip])
	ok(int(ev("slam")) == 2 and m1.hp < 9999.0 and m2.hp < 9999.0 and P.rig.cur == "RideSlamLand", "ПРИЗЕМЛЕНИЕ: удар по области — задеты оба (%s), клип %s" % [str(ev("slam")), P.rig.cur])
	await frames(30)
	ok(T.mode == "ride" and not T.slam, "после удара герой остался верхом")
	P.auto_input = {}
	print("TYAGACHECK ok" if fails == 0 else "TYAGACHECK ОШИБОК: %d" % fails)
	get_tree().quit()
