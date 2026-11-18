## Пахан: бег относительно камеры, комбо балоном, тяжёлый удар, перекат с неуязвимостью, блок/парирование, ПЕРЕГРУЗ, аура.
extends CharacterBody3D

const HEIGHT := 1.85
## Стиль боя балоном — как Slugger (бита) в Yakuza 0: широкие махи, цепочка из 4 лёгких,
## тяжёлый удар добивает по-разному в зависимости от того, после скольких лёгких нажат, полный замах заряжается удержанием ПКМ,
## Heat-действие [E] — добивание с замедлением.
## Поля удара: dur — длительность клипа, hits — доли клипа, когда балон проходит цель (совпадают с ключами в poses.gd),
## step — [с, по, скорость]: шаг в удар, cancel — с какой доли можно продолжить цепочку, launch — подброс врага,
## slam — когда балон бьёт в землю, scrape — когда чиркает по земле, drop — когда после удара падает на землю,
## from — с какой доли клипа начинать, если удар идёт в цепочке (балон уже не за спиной, а там, где его оставил прошлый удар).
## Цепочка лёгких — один тяжёлый рисунок: мах вправо-налево → наотмашь обратно → рывок снизу вверх (подбрасывает) →
## двумя руками сверху в землю (сбивает подброшенного вниз). Каждый следующий удар бьёт весомее предыдущего.
const GOLD := Color(1.0, 0.8, 0.42)
const HOT := Color(1.0, 0.45, 0.15)

var game
var rig: Rig
var body: Node3D      # поворот по направлению взгляда
var spin: Node3D      # кувырок вокруг центра тела
var aura: GPUParticles3D
var aura2: GPUParticles3D
var aura_ring: MeshInstance3D
var step_cd := 0.0
var aura_light: OmniLight3D
var hp := 100.0
var max_hp := 100.0
var swag := 0.0
var slow_t := 0.0             # замедлен (снаряд HATER, яд): бег медленнее
var rage := 0.0
var state := "move"
var t := 0.0
var spin_off := 0.0
var roll_dir := Vector3.ZERO
var inv := 0.0
var block_t := 0.0
var hurt_t := 0.0
var face := 0.0
var auto_input := {}
var dmg_mul := 1.0   # множитель урона: прокачка (game.gd) и автотест
var trail: Trail
var charge_light: OmniLight3D
var pod: PodHand            # физический iPod героя под управлением: карман, левая рука, взгляд на экран (scripts/pod.gd); у каждого героя свой — heroes[id]["pod"]
var pod_force := false      # проверка позы без интерфейса (--ipodcheck … --hand)
var pod_turn_back := false   # iPod убран, а поворот обратно ещё не доигран (у madk1d рука освобождается раньше, чем у Пахана)
var pod_synced := false     # наушники уже взяты из сохранения iPod
var pod_face := 0.0         # куда герой повёрнут, пока смотрит в iPod
var pod_face0 := 0.0        # и куда вернуться
var drag: WeaponDrag        # инерция балона поверх анимации
var style: StyleData        # текущий боевой стиль (styles.gd)
var combat: Combat          # ядро боя: буфер ввода, окна комбо, попадания, урон (combat.gd)
var bottles: Bottles         # водяра: в руке, в полёте, всплеск (bottles.gd)
var tyaga: Tyaga             # пылесос ТЯГА-812: езда, притягивание, выброс (tyaga.gd)
var own_styles: Array = ["vozduh", "bottles", "tyaga812"]   # стили Пахана: [1], [2], [3]
var switch_to := ""          # идёт смена стиля: на какой
var switch_t := 0.0
var switch_buf := false      # во время смены нажали удар: сработает сразу после
const SWITCH_T := 0.42
var hero := "pahan"          # кем управляет игрок: pahan / madk1d (смена — Tab, game.swap_heroes)
var heroes := {}             # имя → {rig, anim, feet, trail, styles, style}
var board_out := false       # доска madk1d в руке (иначе — за спиной)
var board_t := -1.0          # идёт перенос доски: рука тянется за спину
var board_to := false
var fight_t := 0.0           # сколько ещё секунд считается, что идёт бой (доска в руке)
var reach: ArmReach          # правая рука madk1d за спину и обратно поверх любой анимации
const BOARD_SWAP := 0.36
var wbones := {}             # кости оружия (weaponbones.gd): id стиля или "board_ride" → WeaponBones
const GUITAR_BACK_FLIP := PI   # модель гитары сдвинута от своей оси по толщине на ~0,14 м: без разворота корпус уходил внутрь тела
var board_n := Vector3.UP     # нормаль деки доски madk1d в осях её меша (от колёс к шкурке)
var board_mi: MeshInstance3D
var madk_pod: PodHand        # iPod madk1d (до сборки heroes)
var m_weapons := {}          # оружие madk1d по стилям: id → {att, weapon, bone, grip}
var skate: Skate             # скейтборд: езда и трюки (skate.gd)
var guitar: Guitar           # электрогитара: ритм, дисторшн, волны и звук (guitar.gd)
var breaker: Breaker         # Breaker Style: поток, Freeze, риск (breaker.gd)
var execution: Execution     # контекстные добивания (execution.gd)
var feel := {}               # «живое» оружие: стиль → WeaponFeel (weaponfeel.gd); "board_ride" — доска под ногами
var flow: WeaponFlow         # смена стиля в бою: отмена удара, Perfect Swap, входы стилей (weaponflow.gd)
var roll_kind := "f"         # куда уклонение относительно героя: f — кувырок вперёд, l / r — вбок, b — назад
var idle_var_t := 0.0        # сколько герой стоит без дела: по таймеру — вариация покоя
var idle_var_next := 9.0
var switch_info: Dictionary = {}      # какой переход идёт: клип и моменты смены оружия (SwapClips.INFO)
var switch_len := 0.42       # длительность идущей смены стиля (Perfect Swap — короче)
var FINISH: Array = []      # тяжёлые удары стиля по числу лёгких перед ними (для съёмки трейлера)
var scrape_p: AudioStreamPlayer
var scr_cd := 0.0
var anim_hold := 0.0        # реакция (парирование, идеальный уклон, отброс) доигрывает, стойка её не перебивает
var perfect := false        # в этом перекате был идеальный уклон
var anim: AnimState         # перемещение: старт, бег, остановка, поворот, падение (anim_state.gd)
var feet: FootIK            # стопы на земле и без скольжения (foot_ik.gd)
var turn_to := NAN          # стоя: развернуться на месте к этому углу (переступанием, TurnL/TurnR)

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	body = Node3D.new()
	add_child(body)
	spin = Node3D.new()
	spin.position.y = 0.9
	body.add_child(spin)
	rig = Rig.new()
	spin.add_child(rig)
	rig.position.y = -0.9
	rig.setup("res://assets/models/pahan.glb", HEIGHT, Poses.pahan_armed(), true, -1.0)
	# Балон VOZDUH: горлышко в кулаке, корпус выходит со стороны мизинца
	style = Styles.by_id("vozduh")
	rig.attach(style.weapon["path"], style.weapon["side"], style.weapon["opt"])
	_weapon_bones(rig, style)
	feel["vozduh"] = WeaponFeel.on(rig.weapon.get_child(0), "vozduh")
	combat = Combat.new(self, game, style)
	FINISH = [style.next("", "heavy"), style.next("vz_light1", "heavy"), style.next("vz_light2", "heavy"), style.next("vz_upper", "heavy")]
	trail = Trail.new()
	rig.add_child(trail)
	trail.setup(rig, GOLD, 0.22)
	drag = WeaponDrag.new()
	drag.rig = rig
	rig.skel.add_child(drag)
	rig.setup_holster("spine2", Poses.PH_HOLSTER_DIR, Poses.PH_HOLSTER_OFF)
	rig.clip_event.connect(_on_clip_event)
	anim = AnimState.new(rig, Poses.pahan_armed(), PahanMoves.PROFILE)
	feet = FootIK.new()
	feet.setup(rig)
	feet.exclude = [get_rid()]
	rig.skel.add_child(feet)
	pod = PodHand.new()
	pod.setup(rig)
	rig.skel.add_child(pod)
	heroes["pahan"] = {"rig": rig, "anim": anim, "feet": feet, "trail": trail, "styles": own_styles, "style": "vozduh", "pod": pod}
	# madk1d как второй герой игрока: свой риг, оружие стилей, состояния анимации и стопы
	var mr := Rig.new()
	spin.add_child(mr)
	mr.position.y = -0.9
	var mdefs := Poses.madk1d()
	mr.setup("res://assets/models/madk1d.glb", 1.68, mdefs)
	for sid in ["skateboard", "guitar"]:
		var sd: StyleData = Styles.by_id(sid)
		if sd.ready and not sd.weapon.is_empty():
			var att: Node3D = mr.attach(sd.weapon["path"], sd.weapon["side"], sd.weapon["opt"])
			m_weapons[sid] = {"att": att, "weapon": mr.weapon, "bone": mr.weapon_bone, "grip": mr.weapon_grip}
			feel[sid] = WeaponFeel.on(mr.weapon.get_child(0), sid)
			_weapon_bones(mr, sd)
			att.visible = false
	# доска в покое — за спиной: место в чехле и слой руки, которая за ней тянется
	if m_weapons.has("skateboard"):
		var bw: Dictionary = m_weapons["skateboard"]
		mr.weapon = bw["weapon"]
		mr.weapon_bone = bw["bone"]
		mr.setup_holster("spine2", MadkWeaponClips.BOARD_BACK_DIR, MadkWeaponClips.BOARD_BACK_OFF, _board_back_roll(mr, bw["weapon"]))
		bw["back_att"] = mr.back_att
		bw["back_xf"] = mr.back_xf
		bw["hand_att"] = mr.hand_att
		bw["hand_xf"] = mr.hand_xf
		(bw["weapon"] as Node3D).reparent(mr.back_att, false)
		(bw["weapon"] as Node3D).transform = mr.back_xf
		reach = ArmReach.new()
		reach.setup(mr)
		mr.skel.add_child(reach)
	# iPod и наушники madk1d: тот же слой, что у Пахана, точки позы пересчитаны под его тело (PodHand.MADK1D).
	# Оружие он не отпускает к ноге, как Пахан балон, — убирает за спину (_madk_pod_gear).
	var mpod := PodHand.new()
	mpod.setup(mr, PodHand.MADK1D)
	mpod.manage_weapon = false
	mr.skel.add_child(mpod)
	madk_pod = mpod
	if m_weapons.has("guitar"):
		# гитара за спиной на время iPod: она в левой руке, а iPod достаёт как раз левая.
		# Ось модели гитары идёт от головки грифа к корпусу: «вниз-вправо» — гриф над левым плечом, корпус у правого
		# бедра (крест-накрест с доской). Вешается тем же Rig.setup_holster, что и доска, — одна формула на обе вещи.
		var gw: Dictionary = m_weapons["guitar"]
		var gnode: Node3D = gw["weapon"]
		gw["hand_att"] = gnode.get_parent()
		gw["hand_xf"] = gnode.transform
		var groll := 0.0
		var gmi := WeaponBones._mesh(gnode)
		if gmi != null:
			var gab: AABB = gmi.mesh.get_aabb()
			var thin := 0
			for ax in 3:
				if gab.size[ax] < gab.size[thin]:
					thin = ax
			var gn := Vector3.ZERO
			gn[thin] = 1.0                      # гитара плоская: тонкая ось — нормаль корпуса
			groll = _back_roll(mr, gnode, gmi, gn, MadkWeaponClips.GUITAR_BACK_DIR) + GUITAR_BACK_FLIP
		var keep := [mr.weapon, mr.weapon_bone, mr.back_att, mr.back_xf, mr.hand_att, mr.hand_xf, mr.weapon_hand_bone]
		mr.weapon = gnode
		mr.weapon_bone = gw["bone"]
		mr.back_att = null
		mr.setup_holster("spine2", MadkWeaponClips.GUITAR_BACK_DIR, MadkWeaponClips.GUITAR_BACK_OFF, groll)
		gw["back_att"] = mr.back_att
		gw["back_xf"] = mr.back_xf
		mr.weapon = keep[0]
		mr.weapon_bone = keep[1]
		mr.back_att = keep[2]
		mr.back_xf = keep[3]
		mr.hand_att = keep[4]
		mr.hand_xf = keep[5]
		mr.weapon_hand_bone = keep[6]
	var mt := Trail.new()
	mr.add_child(mt)
	mt.setup(mr, Color(0.36, 0.82, 1.0), 0.2)
	var mf := FootIK.new()
	mf.setup(mr)
	mf.exclude = [get_rid()]
	mr.skel.add_child(mf)
	mr.clip_event.connect(_on_clip_event)
	mr.visible = false
	var mstyles := []
	for sid in ["skateboard", "guitar", "breaker"]:
		if Styles.by_id(sid).ready:
			mstyles.append(sid)
	heroes["madk1d"] = {"rig": mr, "anim": AnimState.new(mr, mdefs, MadkMoves.PROFILE), "feet": mf, "trail": mt, "styles": mstyles, "style": mstyles[0] if not mstyles.is_empty() else "", "pod": madk_pod}
	skate = Skate.new()
	body.add_child(skate)
	skate.setup(self, game)
	feel["board_ride"] = WeaponFeel.on(skate.spinner.get_child(0), "board_ride")
	var rb := WeaponBones.on(skate.spinner.get_child(0), "x", -48.9, 48.9, "board_ride")      # дека под ногами прогибается
	if rb != null:
		rb.normal = skate.deck_n
		wbones["board_ride"] = rb
	guitar = Guitar.new()
	add_child(guitar)
	guitar.setup(self, game)
	breaker = Breaker.new()
	add_child(breaker)
	breaker.setup(self, game)
	flow = WeaponFlow.new()
	add_child(flow)
	flow.setup(self, game)
	execution = Execution.new()
	add_child(execution)
	execution.setup(self, game)
	combat.attack_started.connect(func(a: AttackData) -> void: breaker.on_start(a))
	combat.attack_started.connect(func(a: AttackData) -> void:
		if a.extra.has("hop") and not breaker.active():
			velocity.y = max(velocity.y, float(a.extra["hop"])))      # удар в прыжке чуть подвешивает героя
	combat.attack_hit.connect(_on_attack_hit)
	combat.attack_started.connect(func(_a: AttackData) -> void:
		fight_t = 4.0
		if hero == "madk1d" and style.id == "skateboard" and not board_out and not skate.on:
			board_place(true)      # удар с доской за спиной: выхватил сразу, замах это прячет
			board_t = -1.0)
	bottles = Bottles.new()
	add_child(bottles)
	bottles.setup(self, game)
	feel["bottles"] = WeaponFeel.on(bottles.prop, "bottles")
	feel["bottles_l"] = WeaponFeel.on(bottles.prop_l, "bottles")
	tyaga = Tyaga.new()
	body.add_child(tyaga)
	tyaga.setup(self, game)
	scrape_p = AudioStreamPlayer.new()
	var scr: AudioStreamWAV = load("res://assets/audio/sfx_scrape.wav")
	scr.loop_mode = AudioStreamWAV.LOOP_FORWARD
	scr.loop_end = int(scr.get_length() * scr.mix_rate)
	scrape_p.stream = scr
	scrape_p.bus = "SFX"
	scrape_p.volume_db = -80.0
	add_child(scrape_p)
	charge_light = OmniLight3D.new()
	charge_light.omni_range = 5.0
	charge_light.light_energy = 0.0
	charge_light.light_color = HOT
	add_child(charge_light)
	_make_aura()

## Аура полного СВЭГа и ПЕРЕГРУЗА: языки пламени вокруг героя, искры-звёзды и рунный круг под ногами (текстуры Kenney).
func _make_aura() -> void:
	aura = _aura_emitter("flame_05", 38, 0.95, Vector2(0.75, 1.0), 1.3, 2.6)
	aura2 = _aura_emitter("star_07", 16, 1.2, Vector2(0.17, 0.17), 0.7, 1.9)
	aura_ring = game.fx.flat(self, "magic_02", Color(1.0, 0.75, 0.3, 0.0), 2.7, 0.06)
	aura_light = OmniLight3D.new()
	aura_light.position.y = 1.0
	aura_light.omni_range = 4.0
	aura_light.light_energy = 0.0
	aura_light.light_color = Color(1, 0.7, 0.3)
	add_child(aura_light)

func _aura_emitter(tex_name: String, amount: int, life: float, size: Vector2, v0: float, v1: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.position.y = 0.15
	p.local_coords = true   # аура держится на герое, а не остаётся шлейфом позади
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.6
	pm.emission_ring_inner_radius = 0.25
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = v0
	pm.initial_velocity_max = v1
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1, 0.0))
	var curve := CurveTexture.new()
	curve.curve = c
	pm.scale_curve = curve
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = load("res://assets/fx/%s.png" % tex_name)
	m.albedo_color = Color(1.0, 0.75, 0.25)
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	add_child(p)
	return p

func pressed(a: String) -> bool:
	if game.intro_busy():
		return false
	if game.ipod != null and game.ipod.captures_gameplay_input():
		return false
	if auto_input.has(a):
		return auto_input[a] == "press"
	return Input.is_action_just_pressed(a)

func held(a: String) -> bool:
	if game.intro_busy():
		return false
	if game.ipod != null and game.ipod.captures_gameplay_input():
		return false
	if auto_input.has(a):
		return true
	return Input.is_action_pressed(a)

func input_dir() -> Vector3:
	if game.intro_busy():
		return Vector3.ZERO
	if game.ipod != null and game.ipod.captures_gameplay_input():
		return Vector3.ZERO
	var v := Vector2.ZERO
	if auto_input.has("move"):
		v = auto_input["move"]
	else:
		v = Vector2(Input.get_axis("left", "right"), Input.get_axis("down", "up"))
	if v.length() > 1.0:
		v = v.normalized()
	var yaw: float = game.cam_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return fwd * v.y + right * v.x

## прыжок с места и на бегу: в воздухе герой управляется и может бить и бросать
const JUMP_V := {"pahan": 7.2, "madk1d": 8.4}

func start_jump() -> void:
	velocity.y = float(JUMP_V.get(hero, 7.5))
	anim_hold = 0.0
	turn_to = NAN
	anim.jump()
	game.fx.dust(global_position + Vector3(0, 0.1, 0), 4, game.fx.DUST, 0.5)
	game.feedback("step", global_position, Vector3.UP, 1.0, Color.WHITE)

func aim_dir() -> Vector3:
	var yaw: float = game.cam_yaw
	return Vector3(-sin(yaw), 0, -cos(yaw))

func _physics_process(dt: float) -> void:
	if state == "dead":
		velocity = Vector3.ZERO
		return
	t += dt
	inv = max(0.0, inv - dt)
	anim_hold = max(0.0, anim_hold - dt)
	if game.paused_story():
		# диалог, мастерская: стоим
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		spin_off = 0.0
		spin.rotation.x = 0.0
		if state != "move":
			combat.interrupt()
			_finish_switch()
			tyaga.on_hurt()
			skate.off()
			state = "move"
		rig.play("Idle", 0.3)
		move_and_slide()
		body.rotation.y = face
		aura.emitting = false
		trail.enabled = false
		aura2.emitting = false
		game.charge_zoom = 0.0
		return
	if rage > 0.0:
		rage = max(0.0, rage - dt)
	var dir := input_dir()
	# нажатия ударов помнит буфер ядра боя: сработают, когда откроется окно
	combat.tick(dt)
	guitar.tick(dt)
	breaker.tick(dt)
	if pressed("throw"):
		breaker.on_press_freeze()          # Breaker: точность Freeze считается от момента нажатия
	if pressed("attack") or pressed("heavy") or pressed("throw"):
		guitar.on_press()                  # гитара: нажатие в такт усиливает удар
	if pressed("attack"):
		combat.press("light")
		switch_buf = switch_to != ""
	elif pressed("heavy"):
		combat.press("heavy")
		switch_buf = switch_to != ""
	elif pressed("throw"):
		combat.press("throw")          # [F]: бутылка левой рукой, не меняя стиль (если стиль это умеет)
	for i in own_styles.size():
		if pressed("style%d" % (i + 1)):
			set_style(own_styles[i])
	if pressed("tag"):
		if game.tag.try_tag():      # смена героя и командные приёмы — tagteam.gd
			return
	if pressed("assist"):
		game.tag.try_assist()
	if pressed("overdrive"):
		game.hype.try_start()
	slow_t = max(0.0, slow_t - dt)
	var spd := 5.6 * (1.25 if held("sprint") else 1.0) * (1.2 if rage > 0.0 else 1.0) * (0.6 if slow_t > 0.0 else 1.0)
	# ТЯГА-812: в этом стиле «свободное» состояние героя ведёт пылесос
	if style.id == "tyaga812" and state == "move" and switch_to == "":
		state = "tyaga"
	if state != "tyaga":
		tyaga.idle_tick(dt)
	match state:
		"move", "block":
			var blocking := held("block")
			if blocking and state != "block":
				state = "block"
				block_t = 0.0
			elif not blocking and state == "block":
				state = "move"
			if state == "block":
				block_t += dt
				spd = 1.8
				face = lerp_angle(face, atan2(aim_dir().x, aim_dir().z), 1.0 - exp(-14.0 * dt))
				if anim_hold <= 0.0:
					rig.play_role("block", 0.1)
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			if state == "move":
				if dir.length() > 0.1:
					# тяжёлый: на старте разворачивается медленнее, чем на бегу
					face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-(6.0 if anim.state == "start" else 12.0) * dt))
					anim_hold = 0.0
				# старт, бег, шаг, рывок, остановка, стойка — решает AnimState; скорость круга шага подогнана под скорость тела.
				# Пыль из-под ног на рывке — по событиям шага в клипе (_on_clip_event)
				var turn := 0.0
				if dir.length() > 0.1 or anim_hold > 0.0:
					turn_to = NAN
				elif not is_nan(turn_to):
					# тяжёлый разворот на месте: тело поворачивается не быстрее 3 рад/с, ноги переступают
					turn = angle_difference(face, turn_to)
					face = rotate_toward(face, turn_to, 3.0 * dt)
					if abs(angle_difference(face, turn_to)) < 0.02:
						turn_to = NAN
				if style.id == "skateboard" and state == "move" and held("sprint") and dir.length() > 0.3 and is_on_floor():
					skate.mount()            # Ctrl на бегу: доска под ноги
					return
				if held("sprint") and dir.length() > 0.5 and anim.state == "move":
					combat.open("sprint", 0.12)   # на бегу с рывком: удар с разгона
				# вариация покоя: стоит без дела, врагов нет — раз в 9–15 с осматривает оружие
				if dir.length() < 0.1 and anim_hold <= 0.0 and is_on_floor() and not enemies_near(14.0) and is_nan(turn_to) and (style.id == "vozduh" or style.roles.has("idle_var")) and not pod.want:
					idle_var_t += dt
					if idle_var_t > idle_var_next:
						idle_var_t = 0.0
						idle_var_next = randf_range(9.0, 15.0)
						if rig.play_role_for("idle_var", 2.6, 0.2) != "":
							anim_hold = 2.6
				elif dir.length() >= 0.1 or enemies_near(14.0):
					idle_var_t = 0.0
				if anim_hold <= 0.0 or dir.length() > 0.1:
					var hs := Vector2(velocity.x, velocity.z).length() if dir.length() > 0.1 else 0.0
					anim.tick(dt, hs, turn, is_on_floor(), velocity.y, enemies_near(), held("sprint") or rage > 0.0)
			if pressed("roll") and is_on_floor():
				start_roll(dir)
			elif pressed("jump") and is_on_floor() and state == "move":
				start_jump()
			elif combat.try_start():
				pass
			elif pressed("heat"):
				try_heat()
			elif pressed("rage") and swag >= 100.0:
				start_rage()
		"switch":
			# смена стиля: балон уходит за спину или возвращается в кулак по событию клипа
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
			switch_t += dt
			var sk := switch_t / switch_len
			if hero == "madk1d":
				spin_off = -TAU * float(switch_info.get("spin", 1.0)) * smoothstep(0.1, 0.6, sk)
				if sk >= float(switch_info.get("at", 0.55)):
					equip_madk(switch_to)
				if sk >= 1.0:
					spin_off = 0.0
					_finish_switch()
				velocity.y -= 20.0 * dt
				move_and_slide()
				body.rotation.y = face + spin_off
				return
			if switch_to == "vozduh" and sk >= float(switch_info.get("grab", 0.36)):
				rig.set_holstered(false)
			elif style.id == "vozduh" and sk >= float(switch_info.get("stow", 0.64)):
				rig.set_holstered(true)
			if sk >= 1.0:
				_finish_switch()
		"tyaga":
			tyaga.tick(dt, dir)
		"skate":
			skate.tick(dt, dir)
		"exec":
			execution.tick(dt)
		"duo":
			game.tag.duo.lead_step(dt)      # прыжок к цели в дуэт-атаке (duo.gd)
		"overdrive":
			velocity.x = 0.0          # постановку ведёт hype.gd
			velocity.z = 0.0
		"attack":
			combat.tick_attack(dt, dir)
		"charge":
			combat.tick_charge(dt, dir)
		"roll":
			var k := t / 0.5
			velocity.x = roll_dir.x * 8.8 * (1.0 - k * 0.5)
			velocity.z = roll_dir.z * 8.8 * (1.0 - k * 0.5)
			var e: float = clamp((k - 0.08) / 0.8, 0.0, 1.0)
			spin.rotation.x = e * e * (3.0 - 2.0 * e) * TAU if roll_kind == "f" else 0.0      # кувырок — только вперёд
			if k >= 1.0:
				spin.rotation.x = 0.0
				state = "move"
				game.fx.dust(global_position + Vector3(0, 0.15, 0), 5, game.fx.DUST, 0.6)
				combat.dodged()
				if perfect:
					combat.open("perfect", 0.7)
					swag = min(100.0, swag + 12.0)
					# идеальный уклон: вышел из переката низко, балон уже отведён для ответа
					perfect = false
					rig.play_role_for("perfect_dodge", 0.55, 0.06)
					anim_hold = 0.45
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
			if t > 0.35:
				state = "move"
		"rage":
			velocity = Vector3.ZERO
			if t > 0.75:
				state = "move"
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face + spin_off
	var tr := false
	if state == "attack" and combat.cur != null:
		var hh: Array = combat.cur.hits
		var kk := combat.k()
		tr = kk >= float(hh[0]) - 0.16 and kk <= float(hh[hh.size() - 1]) + 0.14
	trail.enabled = tr
	if tr and feel.has(style.id):
		(feel[style.id] as WeaponFeel).swing(1.0)
	_board_tick(dt)
	if feel.has("board_ride"):
		(feel["board_ride"] as WeaponFeel).drive = clampf(skate.speed / 10.0, 0.0, 1.0) if skate.on else 0.0
	if state != "charge":
		game.charge_zoom = 0.0
	var glow := 2.0 if rage > 0.0 else (1.0 if swag >= 100.0 else 0.0)
	aura.emitting = glow > 0.0
	var mat := (aura.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.35, 0.12) if rage > 0.0 else Color(1.0, 0.78, 0.3)
	aura.amount_ratio = 1.0 if glow > 1.5 else 0.6
	aura_light.light_energy = lerp(aura_light.light_energy, glow * 1.6, 1.0 - exp(-6.0 * dt))
	aura_light.light_color = mat.albedo_color
	aura2.emitting = aura.emitting
	((aura2.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = mat.albedo_color
	var rm := aura_ring.material_override as StandardMaterial3D
	rm.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, lerpf(rm.albedo_color.a, 0.8 if glow > 0.0 else 0.0, 1.0 - exp(-5.0 * dt)))
	aura_ring.rotation.y += dt * (2.6 if rage > 0.0 else 0.9)

## враги рядом — герой в боевой стойке, а не в расслабленной
func enemies_near(r := 10.0) -> bool:
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and e.global_position.distance_to(global_position) < r:
			return true
	return false

## события внутри клипов (rig.clip_event): шаги — пыль на рывке ровно в момент касания стопы
func _on_clip_event(_clip: String, ev: String) -> void:
	if ev.begins_with("step") and state == "move" and (held("sprint") or rage > 0.0) and Vector2(velocity.x, velocity.z).length() > 3.0:
		game.feedback("step", global_position + Vector3(0, 0.12, 0))

## Сменить боевой стиль. Можно из стойки и из удара после его попадания (бросил бутылку → балон → тяжёлый).
func set_style(id: String) -> bool:
	if id == style.id or switch_to != "" or not Styles.by_id(id).ready or game.paused_story():
		return false
	var free: bool = state == "move" or flow.can_cancel() or (state == "tyaga" and tyaga.mode in ["hold", "in", "off"])      # и пока пылесос ещё выкатывается
	if not free:
		return false
	switch_len = flow.begin(style.id, id)      # до interrupt: Perfect Swap судится по идущему удару
	combat.interrupt()
	spin_off = 0.0
	switch_to = id
	switch_t = 0.0
	switch_buf = false
	state = "switch"
	bottles.show_prop(false)
	switch_info = SwapClips.info(style.id, id)      # у каждой пары стилей свой переход
	var sw_clip := String(switch_info.get("clip", ""))
	if hero == "madk1d":
		rig.play_for(sw_clip if sw_clip != "" else "StyleSwitch", switch_len, 0.06)
		game.feedback("equip", global_position + Vector3(0, 1.2, 0))
		return true
	if style.id == "tyaga812":
		tyaga.leave()                 # пылесос откатывается
	if sw_clip != "":
		rig.play_for(sw_clip, switch_len, 0.06)
	elif id == "vozduh":
		rig.play_for("Equip", switch_len, 0.08)
	elif style.id == "vozduh":
		rig.play_for("Unequip", switch_len, 0.08)
	elif id == "bottles":
		rig.play_for("BottleDraw", switch_len, 0.08)
	else:
		rig.play("TyagaHold", 0.3)
	if id == "tyaga812":
		tyaga.enter()                 # пылесос выкатывается из-за спины, пока идёт смена
	game.feedback("equip", global_position + Vector3(0, 1.2, 0))
	return true

## смена закончена (или прервана ударом по герою): оружие и стиль — в конечном состоянии
func _finish_switch() -> void:
	if switch_to == "":
		return
	style = Styles.by_id(switch_to)
	switch_to = ""
	spin_off = 0.0
	if hero == "madk1d":
		equip_madk(style.id)
	else:
		rig.set_holstered(style.id != "vozduh")
	rig.style_map = style.roles
	combat.set_style(style)
	if switch_buf:
		combat.buf_time = combat.clock      # удар, нажатый во время смены, срабатывает сразу
	switch_buf = false
	var done: bool = state == "switch"
	if state == "switch":
		state = "move"
	game.popup(global_position + Vector3(0, 2.3, 0), style.title, style.color)
	if done:
		flow.finish(style.id)
	else:
		flow.abort()                 # смену оборвали (ударили, сменили героя): оружие на месте, награды нет

## Сменить героя под управлением игрока. Риг, состояния анимации, стопы, след и набор стилей — свои у каждого.
func set_hero(id: String) -> void:
	if id == hero or not heroes.has(id):
		return
	combat.interrupt()
	_finish_switch()
	if hero == "pahan":
		if style.id == "tyaga812":
			tyaga.leave()
		bottles.show_prop(false)
		bottles.hide_preview()
	else:
		skate.off()
	heroes[hero]["style"] = style.id
	rig.visible = false
	trail.enabled = false
	hero = id
	var h: Dictionary = heroes[id]
	rig = h["rig"]
	anim = h["anim"]
	feet = h["feet"]
	if h.has("pod") and h["pod"] != pod:
		pod.snap()                # iPod ушедшего героя — сразу в карман (наушники остаются как были)
		pod.want = false
		pod = h["pod"]
		pod_synced = false        # у вошедшего — те же наушники, что хранит ipod.gd
	trail = h["trail"]
	own_styles = h["styles"]
	rig.visible = true
	style = Styles.by_id(String(h["style"]))
	combat.set_style(style)
	rig.style_map = style.roles
	if id == "madk1d":
		equip_madk(style.id)
	spin_off = 0.0
	spin.rotation.x = 0.0
	state = "move"

## Кости оружия: модель лежит внутри крепления (кулак → масштаб → ось → модель), ось и концы — из StyleData.weapon.
func _weapon_bones(r: Rig, sd: StyleData) -> void:
	if r.weapon == null or not WeaponBones.SETS.has(sd.id):
		return
	var opt: Dictionary = sd.weapon["opt"]
	var m: Node3D = r.weapon.get_child(0).get_child(0).get_child(0)
	if sd.id == "skateboard":
		var bmi := WeaponBones._mesh(m)
		if bmi != null:
			board_n = Skate.fix_mesh(bmi)[0]      # у модели доски колёса с обеих сторон деки: лишние убираем и у доски в руке
			board_mi = bmi
	var wb := WeaponBones.on(m, String(opt.get("axis", "y")), float(opt.get("from", 0.0)), float(opt.get("to", 1.0)), sd.id)
	if wb != null:
		wbones[sd.id] = wb

## Поворот доски за спиной вокруг её длинной оси: перебрать и взять тот, при котором шкурка смотрит в спину
## (нормаль деки — вперёд по телу), колёса — наружу. Считается по той же формуле, что Rig.setup_holster.
func _board_back_roll(r: Rig, w: Node3D) -> float:
	if board_mi == null:
		return 0.0
	return _back_roll(r, w, board_mi, board_n, MadkWeaponClips.BOARD_BACK_DIR)

## То же для любого плоского предмета: поворот, при котором нормаль n_mesh (оси меша) смотрит вперёд по телу.
func _back_roll(r: Rig, w: Node3D, mi: MeshInstance3D, n_mesh: Vector3, d: Array) -> float:
	# нормаль в осях крепления оружия: от меша вверх по цепочке узлов до него
	var m := Basis()
	var n: Node = mi
	while n != null and n != w:
		if n is Node3D:
			m = (n as Node3D).transform.basis * m
		n = n.get_parent()
	var nn: Vector3 = (m * n_mesh).normalized()
	var b: int = r.bone["spine2"]
	var gq: Quaternion = r._globals(r.rest_rot)[0][b]
	var up := (gq.inverse() * r.dir_sk(Vector3(d[0], d[1], d[2]))).normalized()
	var fwd: Vector3 = r.dir_sk(Vector3(0, 0, 1)).normalized()
	var best := 0.0
	var bs := -9.0
	for i in 144:
		var roll := TAU * float(i) / 144.0
		var q := Quaternion(Vector3.UP, up) * Quaternion(Vector3.UP, roll)
		var ns: Vector3 = gq * (Basis(q) * nn)
		var sc: float = ns.normalized().dot(fwd)
		if sc > bs:
			bs = sc
			best = roll
	return best

## оружие madk1d по стилю: в кулаке видно только оно
func equip_madk(sid: String) -> void:
	var r: Rig = heroes["madk1d"]["rig"]
	for k2 in m_weapons:
		(m_weapons[k2]["att"] as Node3D).visible = k2 == sid and not skate.on
	if m_weapons.has("skateboard"):
		board_place(sid == "skateboard" and (fight_t > 0.0 or enemies_near(9.0)))      # в бою доска сразу в руке, иначе за спиной
		board_t = -1.0
	if m_weapons.has(sid):
		r.weapon = m_weapons[sid]["weapon"]
		r.weapon_bone = m_weapons[sid]["bone"]
		r.weapon_grip = m_weapons[sid]["grip"]
	else:
		r.weapon_bone = -1            # стиль без оружия: следа и точек оружия нет

## показать или спрятать оружие в руке (доска уходит под ноги)
func show_weapon(on: bool) -> void:
	if hero == "madk1d" and m_weapons.has(style.id):
		(m_weapons[style.id]["att"] as Node3D).visible = on
		if on and style.id == "skateboard":
			board_place(fight_t > 0.0 or enemies_near(9.0))      # сошёл с доски: в бою она в руке, иначе за спину
			board_t = -1.0

## madk1d с iPod: обе руки свободны — доска за спиной, гитара тоже за спину (она в левой руке, а iPod достаёт левая).
var guitar_back := false
func _madk_pod_gear(on: bool) -> void:
	if on and board_out:
		board_place(false)
		board_t = -1.0
	if not m_weapons.has("guitar") or not (m_weapons["guitar"] as Dictionary).has("back_att"):
		return
	var back: bool = on and style.id == "guitar"
	if back == guitar_back:
		return
	guitar_back = back
	var gw: Dictionary = m_weapons["guitar"]
	var w: Node3D = gw["weapon"]
	var to: Node3D = gw["back_att"] if back else gw["hand_att"]
	if w.get_parent() != to:
		w.reparent(to, false)
	w.transform = gw["back_xf"] if back else gw["hand_xf"]
	var r: Rig = heroes["madk1d"]["rig"]
	r.weapon_bone = -1 if back else int(gw["bone"])
	r.style_map = {} if back else style.roles      # гитара за спиной — обычная стойка, руки свободны

## Доска madk1d: в руке (out) или за спиной. За спиной она не оружие: след и точки удара молчат, стойка — без оружия.
func board_place(out: bool) -> void:
	if not m_weapons.has("skateboard"):
		return
	var bw: Dictionary = m_weapons["skateboard"]
	var w: Node3D = bw["weapon"]
	board_out = out
	var to: Node3D = bw["hand_att"] if out else bw["back_att"]
	if w.get_parent() != to:
		w.reparent(to, false)
	w.transform = bw["hand_xf"] if out else bw["back_xf"]
	if hero == "madk1d" and style.id == "skateboard":
		var r: Rig = heroes["madk1d"]["rig"]
		r.weapon_bone = int(bw["bone"]) if out else -1
		r.style_map = style.roles if out else {}

## Каждый кадр: доска за спиной в покое, в руке — в бою (враги рядом, удар, урон). Достаёт и убирает рука поверх
## анимации (ArmReach): тянется за плечо, в верхней точке доска меняет место. На доске верхом и в чужих стилях
## доска в руках не нужна; в брейке её нет и за спиной — там крутятся на спине.
func _board_tick(dt: float) -> void:
	if not m_weapons.has("skateboard") or reach == null:
		return
	var bw: Dictionary = m_weapons["skateboard"]
	(bw["back_att"] as Node3D).visible = not skate.on and style.id != "breaker"
	fight_t = max(0.0, fight_t - dt)
	if state in ["attack", "charge", "exec", "overdrive", "hurt", "block"] or enemies_near(9.0):
		fight_t = max(fight_t, 2.5)
	if hero != "madk1d" or style.id != "skateboard" or switch_to != "" or skate.on or state == "dead":
		board_t = -1.0
		reach.w = move_toward(reach.w, 0.0, dt * 8.0)
		return
	var want: bool = fight_t > 0.0 and not pod.busy()      # с iPod в руках доска за спиной
	if board_t < 0.0 and want != board_out and state == "move":
		board_t = 0.0
		board_to = want
	if board_t >= 0.0:
		board_t += dt
		var k: float = clampf(board_t / BOARD_SWAP, 0.0, 1.0)
		var r: Rig = heroes["madk1d"]["rig"]
		reach.target = r.skel.get_bone_global_pose(r.bone["spine2"]) * (bw["back_xf"] as Transform3D).origin
		reach.w = sin(k * PI)
		if k >= 0.5 and board_out != board_to:
			board_place(board_to)
			game.main.sfx("sfx_roll", -14.0, 1.6 if board_to else 1.2)
		if k >= 1.0:
			board_t = -1.0
			reach.w = 0.0
	else:
		reach.w = move_toward(reach.w, 0.0, dt * 8.0)

## множитель урона от состояния героя (заряды трюков, ритм, дисторшн) — его спрашивает ядро боя
## Усиления момента складываются (а не перемножаются) и вместе не выше Balance.MOMENT_CAP:
## ресурс стиля (заряды скейта, ритм и дисторшн гитары, поток и Freeze Breaker) + Perfect Swap + Tag-бонус.
## Раньше они перемножались, а у скейта и гитары Tag-бонус не учитывался вовсе (docs/DAMAGE_BALANCE.md).
func damage_bonus(a: AttackData) -> float:
	var team: float = game.tag.bonus() if game.tag != null else 1.0
	var add: float = (_style_bonus(a) - 1.0) + (flow.bonus() - 1.0) + (team - 1.0)
	return clampf(1.0 + add, 0.1, Balance.MOMENT_CAP)

func _style_bonus(_a: AttackData) -> float:
	if hero == "madk1d" and style.id == "skateboard":
		return skate.bonus()
	if guitar.active():
		return guitar.bonus()
	if breaker.active():
		return breaker.bonus()
	return 1.0

## ядро боя: хватает ли герою ресурса на атаку
func can_use(a: AttackData) -> bool:
	if breaker.active():
		return breaker.can_use(a)
	return guitar.can_use(a) if guitar.active() else true

## ядро боя: можно ли продолжить цепочку раньше окна комбо (RIFF CANCEL гитары тратит деление ритма)
func early_cancel(_a: AttackData, act: String) -> bool:
	return guitar.active() and act == "throw" and guitar.spend_riff()

## ядро боя: момент удара — звук и волна способности
func on_attack_moment(a: AttackData, _idx: int) -> void:
	if guitar.active():
		guitar.moment(a)

## попадание ударом ядра: заряды трюков потрачены
func _on_attack_hit(a: AttackData, n: int) -> void:
	if hero == "madk1d" and style.id == "skateboard":
		skate.charges = 0
	guitar.on_hit(a, n)
	breaker.on_hit(a)
	flow.on_hit()
	if n > 0:
		var wf: WeaponFeel = feel.get("board_ride" if skate.on else style.id)
		if wf != null:
			wf.hit(float(a.power))      # удар отдаётся в самом оружии
		if a.extra.has("trick") and n == 1 and hero == "madk1d":
			# трюковой удар на ногах попал: заряд трюка, как за трюк на доске
			skate.charges = mini(int(StyleSkateboard.RIDE["max_charges"]), skate.charges + int(a.extra["trick"]))
			skate.events.append(["trick", a.id])
		var wb: WeaponBones = wbones.get("board_ride" if skate.on else style.id)
		if wb != null:
			if skate.on:
				wb.bump(0.6 + 0.3 * float(a.power))
			else:
				wb.kick(float(a.power))      # и гнёт его: конец отбрасывает
		if style.id == "bottles" and a.projectile == "":
			(feel["bottles_l"] as WeaponFeel).hit(float(a.power))

## ядро боя: момент броска — снаряд вылетает из руки
func launch_projectile(a: AttackData, charged: float) -> void:
	if a.projectile == "bottle":
		bottles.throw(a, clampf(charged / 0.6, 0.0, 1.0))

## ядро боя: прицел при удержании (null — убрать)
func aim_preview(a: AttackData, power: float) -> void:
	if a == null:
		bottles.hide_preview()
	else:
		bottles.preview(a, power)

## строка HUD: стиль и запас
func style_hud() -> String:
	var n := own_styles.find(style.id) + 1
	if style.id == "guitar":
		return "[%d] %s  %s" % [n, style.title, guitar.hud()]
	if style.id == "breaker":
		return "[%d] %s  %s" % [n, style.title, breaker.hud()]
	if style.id == "skateboard":
		return "[%d] %s  трюки %s%s  %s" % [n, style.title, "◆".repeat(skate.charges), "◇".repeat(3 - skate.charges), "на доске" if skate.on else "[Ctrl] на доску"]
	if style.id == "tyaga812":
		var cells := int(round(tyaga.heat / 12.5))
		var tip := "перегрев!" if tyaga.lock > 0.0 else ("[E] сойти" if tyaga.riding() else "[E] сесть")
		return "[%d] %s  нагрев %s%s  %s" % [n, style.title, "▮".repeat(cells), "▯".repeat(8 - cells), tip]
	if style.ammo_max > 0:
		var have := int(floor(combat.ammo_of(style.id)))
		return "[%d] %s  %s%s" % [n, style.title, "●".repeat(have), "○".repeat(style.ammo_max - have)]
	if style.id == "vozduh":
		return "[%d] %s   [F] %s" % [n, style.title, "●".repeat(int(floor(combat.ammo_of("bottles"))))]
	return "[%d] %s" % [n, style.title]

## начать атаку стиля напрямую (съёмка, проверки); обычный путь — буфер и combat.try_start()
func start_attack(a: AttackData, chained := false) -> void:
	combat.begin(a, chained)

## тяжёлый удар: n — после скольких лёгких (0 — с места)
func start_finisher(n: int, chained := false) -> void:
	combat.chain = 0
	combat.begin(FINISH[min(n, FINISH.size() - 1)], chained)

## Heat-действие: рядом враг и есть 40 СВЭГа — цепочка добивания стиля с замедлением и наездом камеры
func try_heat() -> void:
	if execution.try_start():          # рядом враг, которого можно добить, — добивание вместо Heat
		return
	if guitar.active():
		guitar.distort()               # у гитары E — DISTORTION
		return
	if swag < 40.0:
		game.popup(global_position + Vector3(0, 2.2, 0), "нужно 40 СВЭГа", Color(0.7, 0.75, 0.85))
		return
	if style.heat.is_empty():
		return
	var best = null
	var bd := 3.4
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var d: float = e.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = e
	if best == null:
		return
	swag -= 40.0
	var to: Vector3 = best.global_position - global_position
	game.cam_yaw = atan2(-to.x, -to.z)
	# вариант добивания — по положению цели: в воздухе, оглушена / лежит, стоит
	var ctx := "air" if best.state == "air" else ("stun" if best.state in ["stun", "down", "getup"] else "")
	if ctx != "air":
		best.stun(2.5)
	inv = 1.7
	game.heat_cam(1.5)
	game.banner("HEAT", "прилёт VOZDUHом", Color(1, 0.75, 0.2))
	game.bark("heat", 4.0)
	combat.begin_heat(ctx)

func start_roll(dir: Vector3) -> void:
	state = "roll"
	if game.read != null:
		game.read.call_deferred("on_roll", roll_kind)      # сторону уклонения запоминают враги (player_read.gd)
	t = 0.0
	roll_dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(face), 0, cos(face))
	# в бою герой не отворачивается от врага: вбок и назад — шаг-уклонение, вперёд — кувырок
	roll_kind = "f"
	# сторона считается от ближайшего врага, а не от взгляда: на бегу герой и так смотрит туда, куда бежит
	var near = null
	var nd := 8.0
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var dd: float = e.global_position.distance_to(global_position)
			if dd < nd:
				nd = dd
				near = e
	if dir.length() > 0.1 and near != null:
		var fw: Vector3 = near.global_position - global_position
		fw.y = 0
		fw = fw.normalized() if fw.length() > 0.05 else Vector3(sin(face), 0, cos(face))
		var lf := Vector3(fw.z, 0, -fw.x)
		if roll_dir.dot(fw) < -0.5:
			roll_kind = "b"
		elif abs(roll_dir.dot(lf)) > 0.6:
			roll_kind = "l" if roll_dir.dot(lf) > 0.0 else "r"
		if roll_kind != "f":
			face = atan2(fw.x, fw.z)          # лицом к врагу
	inv = 0.38
	perfect = false
	if roll_kind == "f":
		face = atan2(roll_dir.x, roll_dir.z)
		rig.play_role("roll", 0.08)
	else:
		rig.play_role_for("dodge_" + roll_kind, 0.5, 0.06)
	game.fx.dust(global_position + Vector3(0, 0.15, 0), 6, game.fx.DUST, 0.7)
	game.main.sfx("sfx_roll", -6.0)

func start_rage() -> void:
	state = "rage"
	t = 0.0
	rage = 8.0
	swag = 0.0
	rig.play_for("Rage", 0.8, 0.08)
	game.main.sfx("sfx_rage", 0.0)
	game.shake(0.8)
	game.fx.slam(global_position, 1.5, HOT)
	game.fx.lightning(global_position, 5.0, HOT)
	game.bark("rage", 4.0)
	game.punch(1.0, global_position + Vector3(0, 1.0, 0))
	game.hitstop(0.12)
	game.banner("ПЕРЕГРУЗ!", "урон ×1.6 на 8 секунд", Color(1, 0.4, 0.15))
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and e.global_position.distance_to(global_position) < 5.0:
			e.take_hit(40.0, (e.global_position - global_position).normalized(), 9.0, true, 6.0)

func take_damage(dmg: float, from: Vector3, attacker = null) -> void:
	if state == "dead":
		return
	if inv > 0.0:
		if state == "roll":
			perfect = true
			game.feedback("perfect_dodge", global_position)
		return
	dmg *= breaker.on_hurt()             # Breaker: во вращении бьют больнее, поток сгорает
	var to: Vector3 = from - global_position
	to.y = 0
	if state == "block" and aim_dir().angle_to(to.normalized()) < 1.4:
		if block_t < 0.22 and attacker:
			attacker.stun(1.6)
			game.feedback("parry", global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.6, to.normalized(), 1.0, Color(0.5, 0.85, 1.0))
			rig.play_role_for("parry", 0.45, 0.05)
			anim_hold = 0.4
			combat.open("parry", 0.8)      # окно ответа: следующий удар — контратака
			game.bark("parry", 5.0)
			swag = min(100.0, swag + 20.0)
			return
		rig.play_role_for("block_heavy" if dmg >= 18.0 else "block_hit", 0.42 if dmg >= 18.0 else 0.26, 0.03)      # удар пришёл в блок
		anim_hold = 0.4 if dmg >= 18.0 else 0.24
		dmg *= 0.2
		combat.open("block", 0.5)          # принял на блок — можно толкнуть в ответ
		swag = min(100.0, swag + 3.0)
		game.feedback("block", global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.5, -to.normalized(), 1.0, Color(0.7, 0.85, 1.0))
	else:
		game.main.sfx("sfx_hurt", -2.0)
		game.fx.hit(global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.3, -to.normalized(), 0, Color(1.0, 0.3, 0.25))
		game.fx.claw(global_position + Vector3(0, 1.15, 0) + to.normalized() * 0.4, Color(1.0, 0.25, 0.2))
		game.fx.enemy_hit(attacker, global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.3, -to.normalized())      # рисунок типа врага / цвет босса
		state = "hurt"
		pod.interrupt()
		t = 0.0
		combat.interrupt()
		_finish_switch()
		tyaga.on_hurt()
		skate.off("hurt")
		spin.rotation.x = 0.0
		velocity = -to.normalized() * 4.0
		# сильный удар отбрасывает (герой остаётся на ногах), обычный — вздрагивает; длительность оглушения та же
		if dmg >= 18.0:
			rig.play_role_for("knockback", 0.6, 0.05)
			anim_hold = 0.55
		else:
			# откуда пришёл удар: спереди — вздрагивает, сзади — бросает вперёд, сбоку — сгибает в сторону
			var tn := to.normalized() if to.length() > 0.01 else Vector3(sin(face), 0, cos(face))
			var fw := Vector3(sin(face), 0, cos(face))
			var left := Vector3(cos(face), 0, -sin(face))
			var role := "hit"
			if fw.dot(tn) < -0.4:
				role = "HitBack"
			elif abs(left.dot(tn)) > 0.6:
				role = "HitL" if left.dot(tn) > 0.0 else "HitR"
			rig.play_role_for(role, 0.4, 0.06)
	if rage > 0.0:
		dmg *= 0.65
	hp -= dmg
	game.damage_flash()
	if hp > 0.0 and hp < max_hp * 0.4:
		game.bark("hurt", 14.0)
		game.bark("worry", 22.0)
	inv = 0.55
	if hp <= 0.0:
		if game.tag != null and game.tag.on_down():      # героя сменил напарник — бой продолжается
			return
		hp = 0.0
		state = "dead"
		pod.snap()
		rig.play_for("Death", 1.2, 0.1)
		game.on_player_dead()

## Плавное положение героя между шагами физики. Тело двигается 60 раз в секунду, а кадры рисуются чаще или реже:
## без сглаживания на скорости (скейт, пылесос, бег) герой дрожит относительно камеры. Камера и видимое тело
## берут положение отсюда; столкновения и бой по-прежнему считаются по настоящему положению.
var _vis_prev := Vector3.ZERO
var _vis_cur := Vector3.ZERO
var _rot_prev := Vector3.ZERO
var _rot_cur := Vector3.ZERO
var _vis_ready := false
var _vis_track: Node = null

## Запоминает положение после каждого шага физики. Стоит дочерним узлом: его шаг идёт сразу после шага героя.
class VisTracker extends Node:
	var who
	func _physics_process(_dt: float) -> void:
		who._vis_step()

func _vis_step() -> void:
	var jumped: bool = not _vis_ready or global_position.distance_to(_vis_cur) > 1.5      # перенос в другое место — без проезда
	_vis_prev = global_position if jumped else _vis_cur
	_vis_cur = global_position
	_rot_prev = body.rotation if jumped else _rot_cur
	_rot_cur = body.rotation
	_vis_ready = true

func vis_pos() -> Vector3:
	if not _vis_ready:
		return global_position
	return _vis_prev.lerp(_vis_cur, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))

func _process(dt: float) -> void:
	if _vis_track == null:
		_vis_track = VisTracker.new()
		_vis_track.who = self
		add_child(_vis_track)
		return
	body.position = vis_pos() - global_position
	var vf := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	if _vis_ready:
		body.rotation = Vector3(lerp_angle(_rot_prev.x, _rot_cur.x, vf), lerp_angle(_rot_prev.y, _rot_cur.y, vf), lerp_angle(_rot_prev.z, _rot_cur.z, vf))
	# iPod: пока интерфейс открыт, герой держит устройство перед собой. Он встаёт вполоборота к камере,
	# лицом к правому краю кадра — туда, где интерфейс, — иначе iPod у груди закрыт спиной. После — поворачивается обратно.
	var ip = game.ipod
	var pod_open: bool = (pod_force or (ip != null and (ip.opened or ip.device.visible) and state == "move"))
	if pod_open and not pod.want:
		if not pod.busy():
			pod_face0 = face
		var cb: Basis = game.cam.global_transform.basis
		var to := cb.x * 0.9 + cb.z * 0.5
		pod_face = atan2(to.x, to.z)
	pod.want = pod_open
	# наушники: надеты ли они, хранит ipod.gd (переживает новую главу и загрузку); здесь — только синхронизация
	if ip != null:
		if not pod_synced:
			pod_synced = true
			pod.set_seated(bool(ip.earbuds_in))
		elif (pod.buds_in() or pod.buds_state() == "STORED") and pod.buds_in() != bool(ip.earbuds_in):
			ip.earbuds_in = pod.buds_in()
			ip._save_settings()
	if hero == "madk1d":
		_madk_pod_gear(pod.want or pod.busy())
	if pod.busy():
		face = lerp_angle(face, pod_face if pod.want or pod.u >= 1.0 else pod_face0, 1.0 - exp(-5.0 * dt))
		body.rotation.y = face
		pod_turn_back = true
	elif pod_turn_back:
		# iPod уже в кармане, а поворот обратно не доигран: доводим, пока игрок сам не повёл героя
		if state == "move" and input_dir().length() < 0.1 and abs(angle_difference(face, pod_face0)) > 0.01:
			face = lerp_angle(face, pod_face0, 1.0 - exp(-8.0 * dt))
			body.rotation.y = face
		else:
			pod_turn_back = false
	# бутылка в кулаке: есть запас, не идёт смена стиля, рука не занята iPod, бутылка ещё не брошена
	bottles.update_props(hero == "pahan" and style.id == "bottles" and switch_to == "" and state != "dead" and not pod.busy())      # две бутылки в руках; брошенная возвращается из кармана
	# стопы: прилегание к земле всегда, кроме переката, гибели и полёта; фиксация опоры — только в перемещении
	feet.weight = move_toward(feet.weight, 0.0 if state in ["roll", "dead"] or not is_on_floor() or tyaga.riding() or skate.on else 1.0, dt * 8.0)
	feet.lock = 1.0 if state in ["move", "block"] and anim.state != "fall" else 0.0
	# в стойке и на бегу балон живёт по инерции; в ударах, блоке и перекате его ведёт анимация
	drag.floor_y = global_position.y + 0.06
	var free := 1.0 if state == "move" or state == "hurt" else 0.0
	drag.weight = move_toward(drag.weight, free, dt * (8.0 if free < drag.weight else 2.5))
	if pod.balloon_free:
		drag.weight = 0.0      # балон отпущен и стоит у ноги — инерция ему не нужна
	var sp: float = drag.scrape_speed if drag.weight > 0.3 else 0.0
	var loud := clampf((sp - 0.8) / 5.0, 0.0, 1.0)
	if loud > 0.0 and not scrape_p.playing and game.main.testing() == "":
		scrape_p.play()
	scrape_p.volume_db = lerpf(scrape_p.volume_db, lerpf(-34.0, -17.0, loud) if loud > 0.0 else -80.0, 1.0 - exp(-10.0 * dt))
	scrape_p.pitch_scale = 0.85 + 0.35 * loud
	scr_cd -= dt
	if sp > 2.2 and scr_cd <= 0.0:
		scr_cd = 0.11
		game.fx.sparks(drag.tip, Vector3.UP, 3, GOLD, 0.3, 55.0)
		if randf() < 0.35:
			game.fx.dust(drag.tip + Vector3(0, 0.05, 0), 2, game.fx.DUST, 0.3)
	var want := 0.0
	if state == "charge":
		want = 1.0 + 4.0 * combat.charge_t
	elif state == "attack" and combat.charged > 0.3 and combat.k() < 0.5:
		want = 5.0
	charge_light.light_energy = lerpf(charge_light.light_energy, want, 1.0 - exp(-14.0 * dt))
	if charge_light.light_energy > 0.05:
		var wp := rig.weapon_points()
		if not wp.is_empty():
			charge_light.global_position = wp[1]

