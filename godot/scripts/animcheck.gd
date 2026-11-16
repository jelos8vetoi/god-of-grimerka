## Проверка боевой анимационной основы (этап 02): --animcheck=<папка>
## На настоящих моделях Пахана (с балоном) и madk1d проверяет каждую боевую роль:
##  — роль находит клип, стиль может подменить клип роли, с оружием в чехле берётся вариант «…Bare»;
##  — стопы стоят на полу в клипах с "ground" (не висят и не тонут), балон не уходит под землю;
##  — циклы замкнуты (первый кадр = последний), нет рывков между соседними кадрами;
##  — события клипов приходят ровно по разу (и в циклах на каждом круге), в том числе при замедлении;
##  — чехол: балон уходит за спину и возвращается в кулак точно на место, след и инерция в чехле молчат.
## Затем снимает раскадровки (16 кадров, две стороны) всех новых клипов: seq_<кто>_<клип>.png.
## В конце печатает «ANIMCHECK ok» или «ANIMCHECK ОШИБОК: n».
extends "res://scripts/posesheet.gd"

const PAHAN_ROLES := ["idle", "combat_idle", "walk", "run", "sprint", "dodge", "roll", "perfect_dodge", "block", "parry", "light", "heavy",
	"launcher", "air_attack", "landing", "stagger", "knockback", "knockdown", "recovery", "finisher", "equip", "unequip", "tag_in", "tag_out", "death"]
const MADK_ROLES := ["idle", "combat_idle", "walk", "run", "sprint", "dodge", "perfect_dodge", "block", "parry", "light", "heavy",
	"launcher", "air_attack", "landing", "stagger", "knockback", "knockdown", "recovery", "tag_in", "tag_out"]
const PAHAN_SEQ := ["CombatIdle", "Walk", "Sprint", "Dodge", "PerfectDodge", "Parry", "AirAttack", "Landing", "Stagger", "Knockback",
	"Knockdown", "Recovery", "Finisher", "Equip", "Unequip", "TagIn", "TagOut"]
const MADK_SEQ := ["CombatIdle", "Walk", "Sprint", "Dodge", "PerfectDodge", "Block", "Parry", "Light", "Heavy", "Launcher", "AirAttack",
	"Landing", "Stagger", "Knockback", "Knockdown", "Recovery", "TagIn", "TagOut"]
## клипы, в которых тело лежит или в воздухе: стопы не обязаны касаться пола
const OFF_GROUND := ["Tuck", "Death", "Knockdown", "Recovery", "AirAttack", "Rage", "Smash", "Charge"]

var fails := 0
var shots := true

func ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "  ОШИБКА  ") + msg)
	if not c:
		fails += 1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--noshots":
			shots = false
	DirAccess.make_dir_recursive_absolute(out)
	await _scene()
	print("ANIMCHECK: Пахан")
	var p := _make("pahan")
	await _check(p, "pahan", PAHAN_ROLES, Poses.pahan_armed())
	await _holster(p)
	if shots:
		pre_shot = _equip_state
		for c in PAHAN_SEQ:
			await _seq(p, "pahan", c)
		pre_shot = Callable()
	p.queue_free()
	await get_tree().process_frame
	print("ANIMCHECK: madk1d")
	var m := _make("madk1d")
	await _check(m, "madk1d", MADK_ROLES, Poses.madk1d())
	if shots:
		for c in MADK_SEQ:
			await _seq(m, "madk1d", c)
	m.queue_free()
	print("ANIMCHECK ok" if fails == 0 else "ANIMCHECK ОШИБОК: %d" % fails)
	get_tree().quit()

func _make(k: String) -> Rig:
	var r := Rig.new()
	add_child(r)
	if k == "pahan":
		r.setup("res://assets/models/pahan.glb", 1.85, Poses.pahan_armed(), true, -1.0)
		r.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
		r.setup_holster("spine2", Poses.PH_HOLSTER_DIR, Poses.PH_HOLSTER_OFF)
	else:
		r.setup("res://assets/models/madk1d.glb", 1.68, Poses.madk1d())
	return r

## поза клипа на доле u без смешивания
func _pose_at(r: Rig, clip: String, u: float) -> void:
	r.player.play("g/" + clip, 0.0)
	r.player.seek(u * r.clip_len(clip), true)
	r.player.pause()

func _feet_low(r: Rig) -> float:
	var low := INF
	for fp in r.foot_pts:
		low = min(low, (r.skel.global_transform * r.skel.get_bone_global_pose(fp[0])).origin.y)
	return low

## куда смотрит каждая кость (её ось +Y в мире): поворот кости вокруг своей оси невидим и не считается рывком
func _rots(r: Rig) -> Array:
	var a := []
	for k in Rig.ORDER:
		var b: int = r.bone[k]
		a.append((r.skel.global_transform.basis * r.skel.get_bone_global_pose(b).basis).y.normalized() if b >= 0 else Vector3.UP)
	return a

func _check(r: Rig, who: String, roles: Array, defs: Dictionary) -> void:
	# роли
	var miss := []
	for role in roles:
		if r.role_clip(role) == "":
			miss.append(role)
	ok(miss.is_empty(), "%s: у всех %d ролей есть клип%s" % [who, roles.size(), "" if miss.is_empty() else " (нет: %s)" % ", ".join(miss)])
	r.style_map = {"light": "Heavy"}
	ok(r.role_clip("light") == "Heavy", "%s: стиль подменяет клип роли (light → %s)" % [who, r.role_clip("light")])
	r.style_map = {}
	# опорная высота стоп — первый кадр покоя
	_pose_at(r, "Idle", 0.0)
	await get_tree().process_frame
	var base := _feet_low(r)
	for clip in defs:
		var def: Dictionary = defs[clip]
		var ground: bool = def.get("ground", false) or def.get("smooth", false)
		var n := 160
		var lo := INF
		var hi := -INF
		var tip_low := INF
		var tip_u := 0.0
		var jump := 0.0
		var jump_at := ""
		var lifts := false
		for kk in def["k"]:
			if float((kk[1] as Dictionary).get("lift", 0.0)) > 0.0:
				lifts = true
		var prev: Array = []
		for i in n + 1:
			var u := float(i) / n
			_equip_state(r, clip, u)
			_pose_at(r, clip, u)
			if ground and not OFF_GROUND.has(clip):
				var d := _feet_low(r) - base
				lo = min(lo, d)
				hi = max(hi, d)
			if who == "pahan" and not OFF_GROUND.has(clip) and not r.holstered:
				var wp := r.weapon_points(0.0, 1.0)
				if not wp.is_empty():
					if (wp[1] as Vector3).y < tip_low:
						tip_low = (wp[1] as Vector3).y
						tip_u = u
			var rots := _rots(r)
			if not prev.is_empty():
				for j in rots.size():
					var dj := rad_to_deg((prev[j] as Vector3).angle_to(rots[j]))
					if dj > jump:
						jump = dj
						jump_at = "%s у %.2f" % [Rig.ORDER[j], u]
			prev = rots
		var notes := []
		if ground and not OFF_GROUND.has(clip):
			var cyc: bool = def.get("smooth", false)
			notes.append("стопы %+.3f…%+.3f м" % [lo, hi])
			# в беге есть фаза полёта: проверяем только, что нога касается пола и не тонет
			if abs(lo) > 0.035 or (not cyc and not lifts and hi > 0.035):
				ok(false, "%s %s: стопы не на полу (%+.3f…%+.3f м)" % [who, clip, lo, hi])
		if tip_low < INF:
			notes.append("конец балона %.2f м у %.2f" % [tip_low, tip_u])
			if tip_low < -0.07:
				ok(false, "%s %s: балон уходит под землю (%.2f м)" % [who, clip, tip_low])
		# рывок: насколько кость повернулась за 1/160 клипа. Быстрый удар на мелком шаге даёт немного,
		# перескок решения IK (локоть или кисть на другую сторону) остаётся большим при любом шаге
		var lim := 45.0
		notes.append("макс. шаг %.0f° (%s)" % [jump, jump_at])
		if jump > lim:
			ok(false, "%s %s: рывок %.0f° за 1/160 клипа" % [who, clip, jump])
		if def.get("loop", false):
			_pose_at(r, clip, 0.0)
			var a := _rots(r)
			_pose_at(r, clip, 1.0)
			var b := _rots(r)
			var gap := 0.0
			for j in a.size():
				gap = max(gap, rad_to_deg((a[j] as Vector3).angle_to(b[j])))
			notes.append("стык цикла %.1f°" % gap)
			if gap > 2.0:
				ok(false, "%s %s: цикл не замкнут (%.1f°)" % [who, clip, gap])
		print("    %s %s: %s" % [who, clip, ", ".join(notes)])
	r.set_holstered(false)
	# события: проигрываем вручную с шагом кадра, считаем пришедшие
	var got := {}
	var on := func(c: String, e: String) -> void: got[c + ":" + e] = int(got.get(c + ":" + e, 0)) + 1
	r.clip_event.connect(on)
	for clip in r.events:
		got.clear()
		var loop: bool = (defs[clip] as Dictionary).get("loop", false)
		var dur := r.clip_len(clip)
		var rounds := 2.25 if loop else 1.0
		r.play(clip, 0.0, 0.5)          # замедление вдвое: события всё равно ровно по разу на круг
		r.player.seek(0.0, true)
		var steps := int(dur * rounds / 0.5 / (1.0 / 60.0))
		for s in steps:
			r.player.advance(1.0 / 60.0)
			r._process(1.0 / 60.0)
		var ev: Dictionary = r.events[clip]
		var good := true
		var line := []
		for e in ev:
			var fr: Array = ev[e] if ev[e] is Array else [ev[e]]
			var want := 0
			for f in fr:
				want += int(floor(rounds - float(f))) + 1 if loop else (1 if float(f) < 0.999 else 0)
			var have: int = got.get(clip + ":" + String(e), 0)
			line.append("%s %d/%d" % [e, have, want])
			if have != want:
				good = false
		ok(good, "%s %s: события по кадрам (%s)" % [who, clip, ", ".join(line)])
	r.clip_event.disconnect(on)

func _holster(r: Rig) -> void:
	var hand0: Transform3D = r.weapon.transform
	var par0: Node = r.weapon.get_parent()
	_pose_at(r, "Idle", 0.0)
	r.set_holstered(true)
	await get_tree().process_frame
	ok(r.holstered and r.weapon.get_parent() == r.back_att and r.weapon_bone == -1 and r.weapon_points().is_empty(), "чехол: балон за спиной, weapon_points пуст (след и инерция молчат)")
	ok(r.role_clip("idle") == "IdleBare" and r.role_clip("run") == "RunBare", "чехол: роли idle/run берут клипы без оружия (%s, %s)" % [r.role_clip("idle"), r.role_clip("run")])
	var back_pos: Vector3 = r.weapon.global_position
	var chest: Vector3 = (r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["spine2"])).origin
	ok(back_pos.distance_to(chest) < 0.6, "чехол: хват балона у спины (%.2f м от груди)" % back_pos.distance_to(chest))
	r.set_holstered(false)
	await get_tree().process_frame
	ok(not r.holstered and r.weapon.get_parent() == par0 and r.weapon.transform.is_equal_approx(hand0) and not r.weapon_points().is_empty(), "чехол: балон вернулся в кулак точно на место")
	# стык «достать»: рука у чехла в момент хвата
	_pose_at(r, "Equip", 0.36)
	r.set_holstered(true)
	await get_tree().process_frame
	var hand_p: Vector3 = (r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["rhand"])).origin
	var grip_back: Vector3 = r.weapon.global_position
	print("    кулак %s, горлышко в чехле %s (доли роста от ног)" % [r.global_transform.affine_inverse() * hand_p / 1.85, r.global_transform.affine_inverse() * grip_back / 1.85])
	ok(hand_p.distance_to(grip_back) < 0.3, "достать: кулак у горлышка в чехле в момент хвата (%.2f м)" % hand_p.distance_to(grip_back))
	_pose_at(r, "Unequip", 0.64)
	await get_tree().process_frame
	hand_p = (r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["rhand"])).origin
	ok(hand_p.distance_to(grip_back) < 0.3, "убрать: кулак у чехла в момент «убрал» (%.2f м)" % hand_p.distance_to(grip_back))
	r.set_holstered(false)

## для раскадровок «достать/убрать»: где балон на этой доле клипа
func _equip_state(r: Rig, clip: String, u: float) -> void:
	if clip.ends_with("Bare"):
		r.set_holstered(true)
	elif clip == "Equip":
		r.set_holstered(u < 0.36)
	elif clip == "Unequip":
		r.set_holstered(u >= 0.64)
	else:
		r.set_holstered(false)

func _seq(r: Rig, who: String, clip: String) -> void:
	var list := []
	for i in 16:
		list.append("%s:%.4f" % [clip, i / 15.0])
	await _render(r, list, "seq_%s_%s.png" % [who, clip])
