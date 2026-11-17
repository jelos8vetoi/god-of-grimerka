## Проверка оружия madk1d: -- --madkcheck=<папка>, запускать с --resolution 1280x720.
## Скейт: в покое доска за спиной, в бою — в руке (достаёт рукой через плечо, не останавливаясь), после боя
## убирает, на доске верхом её нет ни в руке, ни за спиной. Гитара: левая рука на грифе, правая у струн,
## свои стойка и бег, удары двумя руками, игра. Снимки c*.png — крупные планы.
## В конце — «MADKCHECK ok» или «MADKCHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var P
var R: Rig
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
	print(("MADK ok: " if c else "MADK ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## крупный план своей камерой: ang — с какой стороны (0 — спереди, PI — сзади, ±PI/2 — сбоку)
func close(name: String, ang := 0.6, dist := 2.6) -> void:
	var f := Vector3(sin(P.face + ang), 0, cos(P.face + ang))
	var at: Vector3 = P.global_position + Vector3(0, 0.75, 0)
	cam.global_position = at + f * dist + Vector3(0, 0.45, 0)
	cam.look_at(at, Vector3.UP)
	cam.fov = 50.0
	game.buddy.visible = false      # напарник не должен закрывать кадр
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	cam.clear_current(true)
	game.buddy.visible = true

func tap(a: String, keep := {}) -> void:
	await get_tree().physics_frame
	var d: Dictionary = keep.duplicate()
	d[a] = "press"
	P.auto_input = d
	await get_tree().physics_frame
	P.auto_input = keep.duplicate()

func wait_switch() -> void:
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 200:
		await get_tree().physics_frame
		n += 1

func stage(style_key: String, style_id: String) -> void:
	game.ch = 0
	game._load_chapter(false)
	game.mode = "idle"
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	if P.hero != "madk1d":
		game.swap_heroes()
	await frames(2)
	game.tag.reset()
	R = P.heroes["madk1d"]["rig"]
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	game.cam_yaw = 0.0
	P.velocity = Vector3.ZERO
	if P.skate.on:
		P.skate.off()
	P.state = "move"
	P.inv = 9999.0
	P.auto_input = {}
	P.combat.interrupt()
	P.fight_t = 0.0
	game.buddy.global_position = Vector3(-14, 0.05, 14)
	game.buddy.target = game.buddy.global_position
	game.buddy.wait = 999.0
	await wait_switch()
	await frames(10)
	if P.style.id != style_id:
		await tap(style_key)
		await wait_switch()
	await frames(50)
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	P.fight_t = 0.0
	await frames(6)

func foe(at: Vector3):
	var e = game._make_enemy("bot", "", P.global_position + at)
	e.state = "chase"
	e.cool = 999.0
	e.max_hp = 9999.0
	e.hp = 9999.0
	return e

func bone_w(key: String) -> Vector3:
	return R.skel.global_transform * R.skel.get_bone_global_pose(R.bone[key]).origin

## центр хвата руки в мире
func grip_w(side: String) -> Vector3:
	return R.skel.global_transform * (R.skel.get_bone_global_pose(R.bone["rhand" if side == "r" else "lhand"]) * ((R.hand[side] as Dictionary)["grip"] as Vector3))

func board() -> Node3D:
	return (P.m_weapons["skateboard"] as Dictionary)["weapon"]

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	# ================= 1. скейт: в покое за спиной =================
	await stage("style1", "skateboard")
	await frames(60)
	var bw: Dictionary = P.m_weapons["skateboard"]
	var on_back: bool = board().get_parent() == bw["back_att"] and board().is_visible_in_tree()
	# доска за спиной и не внутри тела: её центр позади позвоночника
	var back_dir := -Vector3(sin(P.face), 0, cos(P.face))
	var behind: float = (board().global_position - bone_w("spine2")).dot(back_dir)
	ok(P.style.id == "skateboard" and on_back and not P.board_out and P.rig.cur != "ArmedIdle", "скейт в покое: доска за спиной (на %.2f м позади позвоночника), руки свободны, стойка «%s»" % [behind, P.rig.cur])
	ok(behind > 0.08, "доска не утоплена в спину: %.2f м от позвоночника" % behind)
	await close("c01_board_back.png", PI - 0.5)
	await close("c01_board_side.png", PI * 0.5)
	await close("c01_board_front.png", 0.4)
	# бег с доской за спиной
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(40)
	await close("c02_board_run.png", PI - 0.7)
	ok(not P.board_out and board().get_parent() == bw["back_att"], "на бегу без врагов доска остаётся за спиной")
	P.auto_input = {}
	await frames(30)
	# ================= 2. враг рядом: достаёт =================
	var e = foe(Vector3(0, 0, -6.0))
	var max_w := 0.0
	var n := 0
	while not P.board_out and n < 120:
		await get_tree().physics_frame
		max_w = max(max_w, P.reach.w)
		n += 1
		if P.reach.w > 0.9:
			await close("c03_board_reach.png", PI * 0.5)
	await frames(30)
	ok(P.board_out and board().get_parent() == bw["hand_att"] and max_w > 0.9 and P.rig.cur == "ArmedIdle" and R.weapon_bone >= 0, "враг рядом — достал доску: рука тянулась за плечо (вес %.2f), доска в руке, стойка «%s»" % [max_w, P.rig.cur])
	await close("c04_board_hand.png", 0.7)
	# удар доской попадает
	e.global_position = P.global_position + Vector3(0, 0, -2.0)
	e.stun(3.0)
	await tap("attack")
	await frames(40)
	ok(e.hp < 9999.0, "удар доской попадает (урон %.0f)" % (9999.0 - e.hp))
	n = 0
	while P.state != "move" and n < 200:
		await get_tree().physics_frame
		n += 1
	# ================= 3. бой кончился: убирает =================
	e.take_hit(99999.0, Vector3(0, 0, -1), 0.0, true)
	n = 0
	while P.board_out and n < 600:
		await get_tree().physics_frame
		n += 1
	await frames(30)
	ok(not P.board_out and board().get_parent() == bw["back_att"] and R.weapon_bone < 0, "врагов нет — через %.1f с доска снова за спиной" % (n / 60.0))
	# ================= 4. удар с доской за спиной: выхватывает сразу =================
	await stage("style1", "skateboard")
	e = foe(Vector3(0, 0, -30.0))      # далеко: «боя нет»
	e.cool = 999.0
	P.fight_t = 0.0
	await frames(4)
	var was_back: bool = not P.board_out
	e.global_position = P.global_position + Vector3(0, 0, -2.0)
	e.stun(3.0)
	P.fight_t = 0.0
	P.board_place(false)
	await tap("attack")
	await frames(3)
	var out_now: bool = P.board_out
	await frames(40)
	ok(was_back and out_now and e.hp < 9999.0, "удар, пока доска за спиной: выхватил сразу и попал (урон %.0f)" % (9999.0 - e.hp))
	n = 0
	while P.state != "move" and n < 200:
		await get_tree().physics_frame
		n += 1
	# ================= 5. верхом: доска под ногами =================
	await stage("style1", "skateboard")
	await frames(30)
	P.auto_input = {"move": Vector2(0, 1), "sprint": "hold"}      # Ctrl на бегу — доска под ноги
	await frames(40)
	var hidden: bool = P.skate.on and not board().is_visible_in_tree()
	await close("c05_board_ride.png", PI * 0.5)
	P.auto_input = {}
	var nn := 0
	while P.skate.on and nn < 300:
		await get_tree().physics_frame
		nn += 1
	await frames(20)
	ok(hidden and not P.skate.on and board().is_visible_in_tree() and not P.board_out, "верхом доска под ногами (ни в руке, ни за спиной), сошёл без врагов — снова за спиной (скрыта верхом: %s, на доске: %s, видна: %s, в руке: %s, бой %.1f, состояние %s)" % [str(hidden), str(P.skate.on), str(board().is_visible_in_tree()), str(P.board_out), P.fight_t, P.state])
	# ================= 6. гитара: как гитарист =================
	await stage("style2", "guitar")
	await frames(60)
	var gw: Dictionary = P.m_weapons["guitar"]
	var gnode: Node3D = gw["weapon"]
	var lh: Vector3 = grip_w("l")
	var rh: Vector3 = grip_w("r")
	var hands: float = lh.distance_to(rh)
	var l_on: float = lh.distance_to(gnode.global_position)
	# левая выше правой и левее (гриф вверх-влево, корпус у правого бедра), обе перед грудью
	var fwd := Vector3(sin(P.face), 0, cos(P.face))
	var left := fwd.cross(Vector3.UP) * -1.0
	var lside: float = (lh - P.global_position).dot(left)
	var rside: float = (rh - P.global_position).dot(left)
	var front: float = ((lh + rh) * 0.5 - bone_w("spine2")).dot(fwd)
	ok(P.rig.cur == "GtIdle" and (gw["att"] as Node3D).visible and gnode.is_visible_in_tree(), "гитара: своя стойка «%s», гитара видна" % P.rig.cur)
	ok(l_on < 0.08 and hands > 0.3 and hands < 0.7 and lh.y > rh.y + 0.08 and lside > rside + 0.2 and front > 0.08, "гитару держат как гитарист: левая на грифе (%.2f м от хвата), правая у струн (между руками %.2f м), левая выше на %.2f м и левее на %.2f м, гитара перед корпусом (%.2f м)" % [l_on, hands, lh.y - rh.y, lside - rside, front])
	ok(not (P.m_weapons["skateboard"]["weapon"] as Node3D).get_parent() == P.m_weapons["skateboard"]["hand_att"], "в стиле гитары доска не в руке")
	await close("c06_guitar_front.png", 0.0)
	await close("c06_guitar_side.png", -PI * 0.45)
	await close("c06_guitar_34.png", 0.7)
	# бег с гитарой: руки остаются на ней
	P.auto_input = {"move": Vector2(0, 1)}
	await frames(40)
	var run_clip: String = P.rig.cur
	var run_hands: float = grip_w("l").distance_to(grip_w("r"))
	await close("c07_guitar_run.png", 0.9)
	P.auto_input = {}
	await frames(30)
	ok(run_clip == "GtRun" and run_hands > 0.3 and run_hands < 0.7, "бег с гитарой: клип «%s», обе руки на гитаре (%.2f м)" % [run_clip, run_hands])
	# удар двумя руками
	e = foe(Vector3(0, 0, -2.0))
	e.stun(4.0)
	await frames(4)
	await tap("attack")
	var min_hands := 9.0
	for i in 30:
		await get_tree().physics_frame
		min_hands = min(min_hands, grip_w("l").distance_to(grip_w("r")))
		if i == 14:
			await close("c08_guitar_swing.png", 0.8)
	ok(e.hp < 9999.0 and min_hands < 0.22, "удар гитарой: правая перехватила гриф (между руками %.2f м), попал (урон %.0f)" % [min_hands, 9999.0 - e.hp])
	n = 0
	while P.state != "move" and n < 200:
		await get_tree().physics_frame
		n += 1
	# POWER CHORD
	e.global_position = P.global_position + Vector3(0, 0, -5.0)
	e.stun(4.0)
	var hp1: float = e.hp
	await tap("throw")
	await frames(10)
	var chord_clip: String = P.rig.cur
	await close("c09_guitar_chord.png", 0.6)
	await frames(40)
	ok(chord_clip == "GtStrum" and e.hp < hp1, "POWER CHORD: клип «%s», волна попала (урон %.0f)" % [chord_clip, hp1 - e.hp])
	# ================= 7. кости оружия: гнётся в махе и от попадания, потом успокаивается =================
	for row in [["madk1d", "style2", "guitar"], ["madk1d", "style1", "skateboard"], ["pahan", "style1", "vozduh"]]:
		if row[0] == "pahan":
			if P.hero != "pahan":
				game.swap_heroes()
			await frames(4)
			game.tag.reset()
			P.global_position = Vector3(0, 0.05, 4.0)
			P.face = PI
			P.state = "move"
			P.inv = 9999.0
			await wait_switch()
			if P.style.id != "vozduh":
				await tap("style1")
				await wait_switch()
			await frames(50)
		else:
			await stage(row[1], row[2])
		var wb: WeaponBones = P.wbones.get(row[2])
		if wb == null:
			ok(false, "%s: костей у оружия нет" % row[2])
			continue
		var e2 = foe(Vector3(0, 0, -2.0))
		e2.stun(5.0)
		await frames(110)      # доску за это время достают из-за спины — ждём, пока рука успокоится
		var rest0: float = wb.bend
		wb.peak = 0.0
		await tap("attack")
		n = 0
		while P.state != "move" and n < 200:
			await get_tree().physics_frame
			n += 1
		var swing_peak: float = wb.peak
		await frames(90)
		ok(wb.skel.get_bone_count() == WeaponBones.N + 1 and swing_peak > 0.03 and swing_peak <= float(wb.cfg["bend"]) + 0.001 and wb.bend < 0.02 and rest0 < 0.02 and e2.hp < 9999.0, "%s: кости построены (%d), в ударе оружие гнётся до %.2f рад (предел %.2f), в покое прямое (%.3f)" % [row[2], wb.skel.get_bone_count(), swing_peak, float(wb.cfg["bend"]), wb.bend])
	# доска под ногами: прогиб при приземлении
	await stage("style1", "skateboard")
	P.auto_input = {"move": Vector2(0, 1), "sprint": "hold"}
	await frames(40)
	var rb: WeaponBones = P.wbones.get("board_ride")
	if rb != null:
		rb.peak = 0.0
	await tap("jump", {"move": Vector2(0, 1), "sprint": "hold"})
	await frames(70)
	ok(rb != null and rb.peak > 0.03, "доска под ногами прогибается на прыжке и приземлении (до %.2f рад)" % (rb.peak if rb != null else 0.0))
	P.auto_input = {}
	await frames(40)
	print("MADKCHECK ok" if fails == 0 else "MADKCHECK ОШИБОК: %d" % fails)
	get_tree().quit()
