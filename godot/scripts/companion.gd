## madk1d: сам ходит вокруг Пахана (спереди и по бокам, не закрывая камеру); Q — ад-либ: трек «династия», оглушение врагов рядом.
extends CharacterBody3D

var game
var rig: Rig
var body: Node3D
var target := Vector3.ZERO
var wait := 0.0
var face := 0.0
var say_t := 0.0
var cd := 0.0
var cd_max := 10.0
var track: AudioStreamPlayer
var anim: AnimState         # перемещение и движения (anim_state.gd), профиль быстрый — MadkMoves.PROFILE
var feet: FootIK
var idle_t := 0.0           # сколько стоит без дела: время от времени выдаёт брейк-движение
var show_cd := 9.0
var look := "madk1d"         # кого показывает напарник: когда игрок управляет madk1d, рядом идёт Пахан
var looks := {}              # имя → {rig, anim, feet}
var foe = null               # враг, к которому напарник идёт ударить сам (tagteam._ai)
var foe_t := 0.0
var dodge_cd := 0.0
var stuck_t := 0.0
var ko := false              # выбыл: лежит, пока не вернётся (tagteam.revive)
var events: Array = []       # для проверок: ["hit", тип врага], ["dodge", 0]
# дуэт-атака (duo.gd): напарник рывком к цели и бьёт своим выбранным стилем
var duo_on := false
var duo_from := Vector3.ZERO
var duo_to := Vector3.ZERO
var duo_at := Vector3.ZERO
var duo_t := 0.0
var duo_len := 0.2
var duo_air := false
var duo_act_t := 0.0
var duo_style := ""
var duo_e = null             # цель дуэта: напарник ведёт её, пока бежит и бьёт
var duo_off := Vector3.ZERO  # где встать относительно цели
var gear := {}               # оружие напарника по стилям: id стиля → узел (видно только в дуэте)
const CLIPS := {"madk1d": {"hit": ["RoundKick", 0.45], "heavy": ["SpinKick", 0.5], "air": ["AirKick", 0.34]}, "pahan": {"hit": ["Light1", 0.6], "heavy": ["FullSwing", 0.7], "air": ["Upper", 0.6]}}

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.75
	add_child(col)
	collision_layer = 4
	collision_mask = 1
	body = Node3D.new()
	add_child(body)
	rig = Rig.new()
	body.add_child(rig)
	var defs := Poses.madk1d()
	rig.setup("res://assets/models/madk1d.glb", 1.68, defs)
	anim = AnimState.new(rig, defs, MadkMoves.PROFILE)
	feet = FootIK.new()
	feet.setup(rig)
	feet.exclude = [get_rid()]
	rig.skel.add_child(feet)
	looks["madk1d"] = {"rig": rig, "anim": anim, "feet": feet}
	# оружие madk1d-напарника: доска и гитара в руках — достаются на дуэт-атаку
	for sid in ["skateboard", "guitar"]:
		var sd: StyleData = Styles.by_id(sid)
		if sd.ready and not sd.weapon.is_empty():
			var att: Node3D = rig.attach(sd.weapon["path"], sd.weapon["side"], sd.weapon["opt"])
			if sid == "skateboard":
				var bm := WeaponBones._mesh(rig.weapon.get_child(0).get_child(0).get_child(0))
				if bm != null:
					Skate.fix_mesh(bm)      # у модели доски лишние колёса со стороны шкурки
			att.visible = false
			gear[sid] = att
	track = AudioStreamPlayer.new()
	track.stream = load("res://assets/audio/adlib_dynasty.wav")
	track.volume_db = -2.0
	track.bus = "SFX"
	add_child(track)

func _physics_process(dt: float) -> void:
	if game.madk_away():      # приквел до первой концовки: в забеге напарника нет — не идёт за героем, не отскакивает и не дерётся
		velocity = Vector3.ZERO
		foe = null
		return
	var p = game.player
	var pp: Vector3 = p.global_position
	cd = max(0.0, cd - dt)
	if game.madk_home():      # приквел до первой концовки, подъезд: житель — стоит на месте, поворачивается к герою рядом
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		foe = null
		var to := pp - global_position
		to.y = 0.0
		var want := atan2(to.x, to.z) if to.length() < 5.0 else PI * 0.5
		face = lerp_angle(face, want, 1.0 - exp(-4.0 * dt))
		rig.play("Idle", 0.3)
		move_and_slide()
		body.rotation.y = face
		return
	if game.paused_story() or game.over:      # разговор или гибель героя: стоит, не дерётся
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		rig.play("Idle", 0.3)
		move_and_slide()
		body.rotation.y = face
		return
	if ko:
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		move_and_slide()
		body.rotation.y = face
		return
	if duo_on:
		_duo_tick(dt, p)
		return
	dodge_cd = max(0.0, dodge_cd - dt)
	_team_ai(dt)
	wait -= dt
	var far := global_position.distance_to(pp)
	if far > 14.0:
		global_position = pp + Vector3(sin(p.face + 1.4), 0, cos(p.face + 1.4)) * 1.8
		target = Vector3.ZERO
		far = 1.8
	var bad := target == Vector3.ZERO or (target.distance_to(pp) > 4.6 and foe == null)
	if foe == null and (wait <= 0.0 or bad or far > 5.5):
		var aim: Vector3 = p.aim_dir()
		var base := atan2(aim.x, aim.z)
		for i in 12:
			var a := base + randf_range(-1.5, 1.5)   # спереди и по бокам, не под камерой
			var r := randf_range(1.6, 3.6)
			var c := pp + Vector3(sin(a), 0, cos(a)) * r
			if game.in_arena(c, 0.8):
				target = c
				break
		wait = randf_range(1.6, 3.6)
	var turn := 0.0
	var d := target - global_position
	d.y = 0
	var spd := 8.5 if far > 4.5 or dodge_cd > 1.9 else 4.6      # отскок от замаха — рывком
	var acting := anim.state == "action" and anim.hold > 0.0 and dodge_cd < 2.0   # брейк или приём: стоит на месте, тело ведёт root motion
	if acting:
		velocity.x = 0.0
		velocity.z = 0.0
	elif d.length() > 0.15 and say_t <= 0.0:
		var v: Vector3 = d.normalized() * min(spd, d.length() / dt)
		velocity.x = v.x
		velocity.z = v.z
		face = lerp_angle(face, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		var aim2: Vector3 = p.aim_dir()
		var want_face := atan2(aim2.x, aim2.z)
		turn = angle_difference(face, want_face)
		# большой доворот — шагом на месте (TurnL/TurnR), мелкий — плавно (стопы держит FootIK)
		face = lerp_angle(face, want_face, 1.0 - exp(-(10.0 if anim.state == "turn" else 4.0) * dt))
	if say_t > 0.0:
		say_t -= dt
	else:
		# далеко отстал — рывок; враги рядом — боксёрская стойка; переходы и скорость шага — AnimState
		var hs := Vector2(velocity.x, velocity.z).length()
		anim.tick(dt, hs, turn, is_on_floor(), velocity.y, p.enemies_near(9.0), spd > 6.0)
		_show_off(dt, hs, p)
	if not apply_root(dt):
		velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face
	feet.weight = 1.0 if is_on_floor() else 0.0
	feet.lock = 0.0 if anim.state == "action" else 1.0

## Свои действия напарника в бою: подойти к выбранному врагу и ударить (слабо и не насмерть), отойти от замаха.
func _team_ai(dt: float) -> void:
	# уклонение: рядом враг замахнулся или несётся — отскочить в сторону от него
	if dodge_cd <= 0.0:
		for e in game.enemies:
			if not is_instance_valid(e) or not e.alive():
				continue
			if e.state in ["wind", "charge", "special"] and e.global_position.distance_to(global_position) < 2.6:
				var away: Vector3 = global_position - e.global_position
				away.y = 0
				away = away.normalized() if away.length() > 0.05 else Vector3(sin(face), 0, cos(face))
				var to_spot := global_position + away * 3.2
				if not game.in_arena(to_spot, 0.8):
					to_spot = global_position + away.cross(Vector3.UP) * 3.2
				target = to_spot
				wait = 1.0
				foe = null
				dodge_cd = 2.5
				say_t = 0.0                # отскок важнее недоигранного удара или реплики
				game.fx.dust(global_position + Vector3(0, 0.1, 0), 4, game.fx.DUST, 0.5)
				events.append(["dodge", 0])
				break
	if foe == null:
		return
	foe_t -= dt
	if not is_instance_valid(foe) or not foe.alive() or foe_t <= 0.0 or foe.global_position.distance_to(game.player.global_position) > 9.0:
		foe = null
		return
	var d: Vector3 = foe.global_position - global_position
	d.y = 0
	if d.length() > 1.7:
		target = foe.global_position - d.normalized() * 1.3
		wait = 0.5
		# упёрся в другого врага по дороге — короткий рывок к цели, а не топтание на месте
		stuck_t = stuck_t + dt if get_real_velocity().length() < 0.6 else 0.0
		if stuck_t > 0.35 and game.in_arena(target, 0.5):
			stuck_t = 0.0
			game.fx.dust(global_position + Vector3(0, 0.1, 0), 4, game.fx.DUST, 0.5)
			global_position = Vector3(target.x, global_position.y, target.z)
		return
	stuck_t = 0.0
	# дошёл: один удар. Напарник не добивает — последний удар за игроком
	face = atan2(d.x, d.z)
	strike_anim("hit", foe.global_position)
	game.tag.strike(foe, 7.0, 12.0, d.normalized(), 2.0, 0.0, false, 0, false)
	events.append(["hit", foe.kind])
	foe = null
	wait = 0.8

## напарник сам идёт бить врага
func engage(e) -> void:
	foe = e
	foe_t = 3.0

## анимация удара напарника: hit, heavy или air
func strike_anim(kind: String, at: Vector3) -> void:
	var d: Vector3 = at - global_position
	d.y = 0
	if d.length() > 0.05:
		face = atan2(d.x, d.z)
	var c: Array = (CLIPS[look] as Dictionary)[kind]
	anim.action(String(c[0]), float(c[1]))
	say_t = 0.0
	wait = max(wait, float(c[1]) + 0.2)

## мгновенно оказаться в точке (командный приём): со вспышкой на старом и новом месте
func blink(pos: Vector3, look_dir: Vector3) -> void:
	game.fx.sparks(global_position + Vector3(0, 1.0, 0), Vector3.UP, 6, Color(1, 1, 1, 0.8), 0.5, 60.0)
	if not game.in_arena(pos, 0.5):
		pos = global_position.lerp(pos, 0.8)
	global_position = pos
	velocity = Vector3.ZERO
	target = pos
	wait = 1.0
	foe = null
	if look_dir.length() > 0.05:
		face = atan2(look_dir.x, look_dir.z)
	game.fx.ground_ring(Vector3(pos.x, 0.06, pos.z), 0.3, 2.0, Color(1, 1, 1, 0.5), 0.25)

## выбыл: падает и лежит
func ko_down() -> void:
	ko = true
	foe = null
	say_t = 0.0
	rig.play_for("Death", 9999.0, 0.1)

func revive() -> void:
	ko = false
	anim.action("KipUp" if look == "madk1d" else "recovery", 0.8)
	game.fx.twinkle(global_position + Vector3(0, 1.0, 0), 12, Color(0.6, 1.0, 0.7), 1.0)

## Показать другого героя (смена героя игроком). Пахан-напарник собирается при первом обращении.
func set_look(id: String) -> void:
	if id == look:
		return
	if not looks.has(id):
		var r := Rig.new()
		body.add_child(r)
		var defs := Poses.pahan_armed()
		r.setup("res://assets/models/pahan.glb", 1.85, defs, true, -1.0)
		var sv: StyleData = Styles.by_id("vozduh")
		gear["vozduh"] = r.attach(sv.weapon["path"], sv.weapon["side"], sv.weapon["opt"])
		# пылесос Пахана-напарника: стоит у ног на время дуэт-атаки
		var tg: Node3D = (load(Tyaga.MODEL) as PackedScene).instantiate()
		tg.rotation.y = PI * 0.5
		tg.scale = Vector3.ONE * TyagaClips.K
		tg.position = TyagaClips.V_HOLD
		tg.visible = false
		body.add_child(tg)
		gear["tyaga812"] = tg
		var f := FootIK.new()
		f.setup(r)
		f.exclude = [get_rid()]
		r.skel.add_child(f)
		looks[id] = {"rig": r, "anim": AnimState.new(r, defs, PahanMoves.PROFILE), "feet": f}
	rig.visible = false
	look = id
	rig = looks[id]["rig"]
	anim = looks[id]["anim"]
	feet = looks[id]["feet"]
	rig.visible = true
	rig.play("Idle", 0.0)
	say_t = 0.0

# ---------------- дуэт-атака ----------------
## начать: рывок в точку spot (короткий, по земле; к цели в воздухе — прыжком), лицом к цели at
func duo_start(style_id: String, spot: Vector3, en, in_air: bool) -> void:
	var at: Vector3 = en.global_position
	duo_on = true
	duo_e = en
	duo_off = Vector3(spot.x - at.x, 0, spot.z - at.z)
	duo_style = style_id
	duo_from = global_position
	duo_to = spot
	duo_at = at
	duo_air = in_air
	duo_t = 0.0
	duo_act_t = 0.0
	duo_len = clampf(duo_from.distance_to(spot) / 16.0, 0.12, 0.4)
	foe = null
	say_t = 0.0
	_face_to(at)
	for k in gear:
		var on: bool = k == style_id
		if gear[k] is Node3D:
			(gear[k] as Node3D).visible = on if k != "vozduh" else (on or look == "pahan" and style_id not in ["bottles", "tyaga812"])
	rig.play("Sprint" if not in_air else "Jump", 0.06)
	game.fx.dust(global_position + Vector3(0, 0.1, 0), 5, game.fx.DUST, 0.6)

func duo_ready() -> bool:
	return duo_on and duo_t >= duo_len

func duo_acting() -> bool:
	return duo_act_t > 0.0

func duo_act(clip: String, len: float) -> void:
	if not duo_on:
		return
	_face_to(duo_at if game.player == null else duo_at)
	rig.play_for(clip, len, 0.05)
	duo_act_t = len

## отпустить: напарник снова свой (обычное поведение), оружие убирается
func duo_release() -> void:
	if not duo_on:
		return
	duo_on = false
	duo_act_t = 0.0
	duo_e = null
	for k in gear:
		if k != "vozduh" and gear[k] is Node3D:
			(gear[k] as Node3D).visible = false
	if gear.has("vozduh"):
		(gear["vozduh"] as Node3D).visible = true
	wait = 0.8
	target = global_position
	foe = null

func _face_to(at: Vector3) -> void:
	var d: Vector3 = at - global_position
	d.y = 0
	if d.length() > 0.05:
		face = atan2(d.x, d.z)

func _duo_tick(dt: float, p) -> void:
	# цель движется (идёт к герою, отлетает) — напарник её ведёт
	if duo_e != null and is_instance_valid(duo_e) and duo_e.alive():
		duo_at = duo_e.global_position
		duo_to = Vector3(duo_at.x + duo_off.x, global_position.y, duo_at.z + duo_off.z)
		_face_to(duo_at)
	if duo_t < duo_len:
		duo_t += dt
		var left: float = max(duo_len - duo_t, dt)
		var v: Vector3 = (duo_to - global_position) / left
		v.y = 0
		v = v.limit_length(18.0)
		velocity.x = v.x
		velocity.z = v.z
		if duo_air:
			velocity.y = max(velocity.y, 0.0) if duo_t > dt else 7.5      # прыжок к цели в воздухе
		else:
			velocity.y -= 20.0 * dt
		if duo_t >= duo_len:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		# бьёт: держится вплотную к цели (если её отнесло — шагает следом)
		var gap: Vector3 = duo_to - global_position
		gap.y = 0
		if gap.length() > 0.35:
			var sv: Vector3 = gap.normalized() * min(gap.length() / dt, 7.0)
			velocity.x = sv.x
			velocity.z = sv.z
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
		# в воздухе бьёт, зависнув на миг, потом падает
		velocity.y = 0.0 if duo_air and duo_act_t > 0.0 else velocity.y - 20.0 * dt
	if duo_act_t > 0.0:
		duo_act_t -= dt
	move_and_slide()
	body.rotation.y = face
	feet.weight = 0.0
	var _unused = p

## Root motion и вращение клипа (рывок, прыжковая атака, вертушка, мельница): смещение за кадр — в скорость тела.
## true, если клип сам ведёт и высоту (воздушные приёмы) — тогда гравитацию в этот кадр не применяем.
func apply_root(dt: float) -> bool:
	var rm := anim.root_step()
	if rm.is_empty() or dt <= 0.0:
		return false
	var loc: Vector3 = rm[0]
	var wv := Vector3(sin(face), 0, cos(face)) * loc.z + Vector3(cos(face), 0, -sin(face)) * loc.x
	velocity.x = wv.x / dt
	velocity.z = wv.z / dt
	face += float(rm[1])
	var air: bool = (anim.defs[anim.root_clip] as Dictionary).has("root") and abs(loc.y) > 0.00001 if anim.root_clip != "" else false
	if air:
		velocity.y = loc.y / dt
	return air

## Без врагов и без дела madk1d время от времени выдаёт брейк: шесть шагов, фриз или смену стойки.
func _show_off(dt: float, hs: float, p) -> void:
	if look != "madk1d" or hs > 0.3 or p.enemies_near(14.0) or anim.busy():
		idle_t = 0.0
		return
	idle_t += dt
	if idle_t > show_cd:
		idle_t = 0.0
		show_cd = randf_range(12.0, 20.0)
		var pick: Array = [["SixStep", 2.8], ["Freeze", 1.8], ["StyleSwitch", 0.8]].pick_random()
		anim.action(pick[0], pick[1])
		wait = max(wait, float(pick[1]) + 0.5)

func adlib() -> bool:
	if cd > 0.0:
		return false
	if game.telemetry != null:
		game.telemetry.use(look, "system", "adlib")
	cd = cd_max
	say_t = 2.1
	rig.play_for("Cheer" if look == "madk1d" else "Rage", 2.0, 0.08)
	track.play()
	game.popup(global_position + Vector3(0, 2.1, 0), ["ЭЙ!", "ПОЕХАЛИ!", "КАТЮХА!", "sexyswag!"].pick_random(), Color(0.36, 0.82, 1))
	var wave := Color(0.36, 0.82, 1)
	game.shockwave(global_position, wave)
	game.fx.twirl(global_position, 6.5, wave, 0.7)
	game.fx.twirl(global_position, 3.6, Color(1, 1, 1, 0.7), 0.5, "twirl_03")
	game.fx.twinkle(global_position + Vector3(0, 1.2, 0), 16, wave, 1.2)
	game.fx.light(global_position + Vector3(0, 1.2, 0), wave, 4.0, 0.4, 8.0)
	game.bark("adlib", 0.0)
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and e.global_position.distance_to(global_position) < 7.0:
			e.take_hit(15.0, (e.global_position - global_position).normalized(), 5.0, false, 0.0, null, "adlib", look)
			if e.alive():
				e.stun(2.0)
	return true
