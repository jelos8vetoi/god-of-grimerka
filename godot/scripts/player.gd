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
var pod: PodHand            # физический iPod: карман, левая рука, взгляд на экран (scripts/pod.gd)
var pod_force := false      # проверка позы без интерфейса (--ipodcheck … --hand)
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
	bottles = Bottles.new()
	add_child(bottles)
	bottles.setup(self, game)
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
	if pressed("attack"):
		combat.press("light")
		switch_buf = switch_to != ""
	elif pressed("heavy"):
		combat.press("heavy")
		switch_buf = switch_to != ""
	for i in own_styles.size():
		if pressed("style%d" % (i + 1)):
			set_style(own_styles[i])
	var spd := 5.6 * (1.25 if held("sprint") else 1.0) * (1.2 if rage > 0.0 else 1.0)
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
				if held("sprint") and dir.length() > 0.5 and anim.state == "move":
					combat.open("sprint", 0.12)   # на бегу с рывком: удар с разгона
				if anim_hold <= 0.0 or dir.length() > 0.1:
					var hs := Vector2(velocity.x, velocity.z).length() if dir.length() > 0.1 else 0.0
					anim.tick(dt, hs, turn, is_on_floor(), velocity.y, enemies_near(), held("sprint") or rage > 0.0)
			if pressed("roll"):
				start_roll(dir)
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
			var sk := switch_t / SWITCH_T
			if switch_to == "vozduh" and sk >= 0.36:
				rig.set_holstered(false)
			elif style.id == "vozduh" and sk >= 0.64:
				rig.set_holstered(true)
			if sk >= 1.0:
				_finish_switch()
		"tyaga":
			tyaga.tick(dt, dir)
		"attack":
			combat.tick_attack(dt, dir)
		"charge":
			combat.tick_charge(dt, dir)
		"roll":
			var k := t / 0.5
			velocity.x = roll_dir.x * 8.8 * (1.0 - k * 0.5)
			velocity.z = roll_dir.z * 8.8 * (1.0 - k * 0.5)
			var e: float = clamp((k - 0.08) / 0.8, 0.0, 1.0)
			spin.rotation.x = e * e * (3.0 - 2.0 * e) * TAU
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
	var free := state == "move" or (state == "attack" and combat.cur != null and combat.hit_i > 0) or (state == "tyaga" and tyaga.mode == "hold")
	if not free:
		return false
	combat.interrupt()
	spin_off = 0.0
	switch_to = id
	switch_t = 0.0
	switch_buf = false
	state = "switch"
	bottles.show_prop(false)
	if style.id == "tyaga812":
		tyaga.leave()                 # пылесос откатывается
	if id == "vozduh":
		rig.play_for("Equip", SWITCH_T, 0.08)
	elif style.id == "vozduh":
		rig.play_for("Unequip", SWITCH_T, 0.08)
	elif id == "bottles":
		rig.play_for("BottleDraw", SWITCH_T, 0.08)
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
	rig.set_holstered(style.id != "vozduh")
	rig.style_map = style.roles
	combat.set_style(style)
	if switch_buf:
		combat.buf_time = combat.clock      # удар, нажатый во время смены, срабатывает сразу
	switch_buf = false
	if state == "switch":
		state = "move"
	game.popup(global_position + Vector3(0, 2.3, 0), style.title, style.color)

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
	if style.id == "tyaga812":
		var cells := int(round(tyaga.heat / 12.5))
		var tip := "перегрев!" if tyaga.lock > 0.0 else ("[E] сойти" if tyaga.riding() else "[E] сесть")
		return "[%d] %s  нагрев %s%s  %s" % [n, style.title, "▮".repeat(cells), "▯".repeat(8 - cells), tip]
	if style.ammo_max > 0:
		var have := int(floor(combat.ammo_of(style.id)))
		return "[%d] %s  %s%s" % [n, style.title, "●".repeat(have), "○".repeat(style.ammo_max - have)]
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
	t = 0.0
	roll_dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(face), 0, cos(face))
	face = atan2(roll_dir.x, roll_dir.z)
	inv = 0.38
	perfect = false
	rig.play_role("roll", 0.08)
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
		dmg *= 0.2
		combat.open("block", 0.5)          # принял на блок — можно толкнуть в ответ
		swag = min(100.0, swag + 3.0)
		game.feedback("block", global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.5, -to.normalized(), 1.0, Color(0.7, 0.85, 1.0))
	else:
		game.main.sfx("sfx_hurt", -2.0)
		game.fx.hit(global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.3, -to.normalized(), 0, Color(1.0, 0.3, 0.25))
		game.fx.claw(global_position + Vector3(0, 1.15, 0) + to.normalized() * 0.4, Color(1.0, 0.25, 0.2))
		state = "hurt"
		pod.interrupt()
		t = 0.0
		combat.interrupt()
		_finish_switch()
		tyaga.on_hurt()
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
		hp = 0.0
		state = "dead"
		pod.snap()
		rig.play_for("Death", 1.2, 0.1)
		game.on_player_dead()

func _process(dt: float) -> void:
	# iPod: пока интерфейс открыт, герой держит устройство перед собой. Он встаёт вполоборота к камере,
	# лицом к правому краю кадра — туда, где интерфейс, — иначе iPod у груди закрыт спиной. После — поворачивается обратно.
	var ip = game.ipod
	var pod_open: bool = pod_force or (ip != null and (ip.opened or ip.device.visible) and state == "move")
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
	if pod.busy():
		face = lerp_angle(face, pod_face if pod.want or pod.u >= 1.0 else pod_face0, 1.0 - exp(-5.0 * dt))
		body.rotation.y = face
	# бутылка в кулаке: есть запас, не идёт смена стиля, рука не занята iPod, бутылка ещё не брошена
	bottles.show_prop(style.id == "bottles" and switch_to == "" and state != "dead" and not pod.busy() and combat.ammo_of("bottles") >= 1.0 and not (state == "attack" and combat.hit_i > 0))
	# стопы: прилегание к земле всегда, кроме переката, гибели и полёта; фиксация опоры — только в перемещении
	feet.weight = move_toward(feet.weight, 0.0 if state in ["roll", "dead"] or not is_on_floor() or tyaga.riding() else 1.0, dt * 8.0)
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

