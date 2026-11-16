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
const LIGHT := [
	{"clip": "Light1", "dur": 0.88, "hits": [0.52], "dmg": 28.0, "range": 2.7, "arc": 2.6, "kb": 4.5, "step": [0.44, 0.64, 4.6], "cancel": 0.68, "drop": 0.75},
	{"clip": "Light2", "dur": 0.86, "hits": [0.5], "dmg": 30.0, "range": 2.7, "arc": 2.6, "kb": 5.0, "step": [0.42, 0.62, 4.6], "cancel": 0.68, "from": 0.17, "drop": 0.74},
	{"clip": "Upper", "dur": 0.86, "hits": [0.5], "dmg": 32.0, "range": 2.7, "arc": 2.2, "kb": 3.0, "launch": 6.0, "step": [0.42, 0.56, 4.0], "cancel": 0.62, "from": 0.12, "scrape": 0.36, "drop": 0.87},
	{"clip": "Heavy", "dur": 1.0, "hits": [0.57], "dmg": 44.0, "range": 3.0, "arc": 2.2, "kb": 4.0, "launch": -18.0, "heavy": true, "slam": 0.61, "step": [0.5, 0.6, 3.6], "from": 0.36, "name": "В ЗЕМЛЮ"},
]
const FINISH := [
	{"clip": "Heavy", "dur": 1.05, "hits": [0.57], "dmg": 60.0, "range": 3.0, "arc": 2.0, "kb": 5.0, "launch": 6.0, "heavy": true, "slam": 0.61, "step": [0.5, 0.6, 4.0], "from": 0.08, "name": "ОВЕРХЕД"},
	{"clip": "Nail", "dur": 0.76, "hits": [0.42], "dmg": 48.0, "range": 2.9, "arc": 1.8, "kb": 3.0, "heavy": true, "stun": 1.5, "step": [0.3, 0.46, 5.0], "from": 0.08, "drop": 0.52, "name": "ГВОЗДЬ"},
	{"clip": "FullSwing", "dur": 0.85, "hits": [0.34], "dmg": 55.0, "range": 3.2, "arc": 3.6, "kb": 15.0, "launch": 6.5, "heavy": true, "charge": true, "step": [0.14, 0.4, 6.5], "name": "ПОЛНЫЙ ЗАМАХ"},
	{"clip": "Spin", "dur": 1.2, "hits": [0.24, 0.37, 0.5, 0.63, 0.76], "dmg": 16.0, "range": 3.0, "arc": 6.3, "kb": 3.0, "spin": 3.0, "heavy": true, "last_launch": 6.0, "from": 0.08, "name": "НУНЧАКИ"},
]
const HEAT := [
	{"clip": "Smash", "dur": 0.92, "hits": [0.59], "dmg": 60.0, "range": 3.2, "arc": 2.4, "kb": 1.0, "launch": 7.5, "heavy": true, "super": true, "slam": 0.6, "cancel": 0.8},
	{"clip": "FullSwing", "dur": 0.85, "hits": [0.34], "dmg": 90.0, "range": 3.4, "arc": 3.0, "kb": 20.0, "launch": 7.0, "heavy": true, "super": true, "step": [0.14, 0.4, 6.0]},
]
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
var atk: Dictionary = {}
var combo := 0
var hit_done := false
var queued := ""
var hit_i := 0
var spin_off := 0.0
var charge_t := 0.0
var heat_q: Array = []
var roll_dir := Vector3.ZERO
var inv := 0.0
var block_t := 0.0
var hurt_t := 0.0
var face := 0.0
var auto_input := {}
var dmg_mul := 1.0   # для автотеста
var trail: Trail
var charge_light: OmniLight3D
var whoosh_i := 0
var slam_done := false
var scrape_done := false
var ring_cd := 0.0
var charged := 0.0    # заряд, с которым выпущен текущий удар (0..1.2)
var maxed := false
var drag: WeaponDrag        # инерция балона поверх анимации
var scrape_p: AudioStreamPlayer
var scr_cd := 0.0
var drop_done := false

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
	rig.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	trail = Trail.new()
	rig.add_child(trail)
	trail.setup(rig, GOLD, 0.22)
	drag = WeaponDrag.new()
	drag.rig = rig
	rig.skel.add_child(drag)
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
	if auto_input.has(a):
		return auto_input[a] == "press"
	return Input.is_action_just_pressed(a)

func held(a: String) -> bool:
	if auto_input.has(a):
		return true
	return Input.is_action_pressed(a)

func input_dir() -> Vector3:
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
	if game.paused_story():
		# диалог, мастерская: стоим
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		spin_off = 0.0
		spin.rotation.x = 0.0
		if state != "move":
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
	var spd := 5.6 * (1.25 if held("sprint") else 1.0) * (1.2 if rage > 0.0 else 1.0)
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
				rig.play("Block", 0.1)
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			if state == "move":
				if dir.length() > 0.1:
					face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * dt))
					rig.play("Run", 0.18, spd / 5.6)
					step_cd -= dt
					if step_cd <= 0.0 and (held("sprint") or rage > 0.0):
						step_cd = 0.24
						game.fx.dust(global_position + Vector3(0, 0.12, 0), 3, game.fx.DUST, 0.45)
				else:
					rig.play("Idle", 0.25)
			if pressed("roll"):
				start_roll(dir)
			elif pressed("attack"):
				combo = 0
				start_attack(LIGHT[0])
			elif pressed("heavy"):
				start_finisher(0)
			elif pressed("heat"):
				try_heat()
			elif pressed("rage") and swag >= 100.0:
				start_rage()
		"attack":
			var k := t / float(atk["dur"])
			var fwd := Vector3(sin(face), 0, cos(face))
			var st: Array = atk.get("step", [])
			if st.size() == 3 and k >= float(st[0]) and k < float(st[1]) and not _blocked(fwd):
				# шаг в удар: тело идёт за балоном
				velocity.x = fwd.x * float(st[2])
				velocity.z = fwd.z * float(st[2])
			else:
				velocity.x = move_toward(velocity.x, 0.0, 45.0 * dt)
				velocity.z = move_toward(velocity.z, 0.0, 45.0 * dt)
			var hs: Array = atk["hits"]
			while whoosh_i < hs.size() and k >= float(hs[whoosh_i]) - 0.12:
				whoosh_i += 1
				game.main.sfx("sfx_swing_heavy" if atk.has("heavy") else "sfx_swing", -3.0, 0.85 if atk.has("super") else 1.0)
			while hit_i < hs.size() and k >= float(hs[hit_i]):
				hit_i += 1
				_deal_hit()
			if atk.has("slam") and not slam_done and k >= float(atk["slam"]):
				slam_done = true
				_slam(fwd)
			if atk.has("scrape") and not scrape_done and k >= float(atk["scrape"]):
				scrape_done = true
				var wp := rig.weapon_points()
				if not wp.is_empty():
					game.fx.scrape(wp[1], fwd)
					game.main.sfx("sfx_slash", -10.0, 0.7)
			if atk.has("drop") and not drop_done and k >= float(atk["drop"]):
				drop_done = true
				var wpd := rig.weapon_points()
				if not wpd.is_empty():
					game.fx.scrape(wpd[1], fwd)
					game.fx.dust(wpd[1] + Vector3(0, 0.08, 0), 6, game.fx.DUST, 0.7)
					game.fx.ground_ring(wpd[1], 0.3, 1.9, Color(1.0, 0.9, 0.7, 0.55), 0.25)
					game.fx.scorch(wpd[1], 0.8, GOLD)
				game.main.sfx("sfx_clang", -5.0, 0.7)
				game.main.sfx("sfx_thud", -4.0, 0.8)
				game.shake(0.2)
				game.fov_kick = max(game.fov_kick, 1.5)
			# вертушка: разгон и торможение, а не ровное вращение
			spin_off = -TAU * float(atk.get("spin", 0.0)) * smoothstep(0.14, 0.88, k)
			if heat_q.is_empty():
				if pressed("attack") and not atk.has("heavy"):
					queued = "light"
				elif pressed("heavy") and not atk.has("heavy"):
					queued = "heavy"
			var can: float = atk.get("cancel", 0.62)
			if pressed("roll") and k > float(hs[0]) + 0.06 and heat_q.is_empty():
				spin_off = 0.0
				start_roll(dir)
			elif not heat_q.is_empty() and k > can:
				spin_off = 0.0
				start_attack(heat_q.pop_front())
			elif k >= 0.9 or (queued != "" and k > can):
				spin_off = 0.0
				if queued == "light" and combo < LIGHT.size() - 1:
					combo += 1
					start_attack(LIGHT[combo], true)
				elif queued == "heavy":
					start_finisher(combo + 1, true)
				else:
					state = "move"
					combo = 0
		"charge":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
			charge_t = min(1.2, charge_t + dt)
			face = lerp_angle(face, _aim_face(4.0, dir), 1.0 - exp(-10.0 * dt))
			# заряд видно и слышно: кольца стягиваются к ногам, балон светится, камера поджимается и дрожит
			var c := charge_t / 1.2
			ring_cd -= dt
			if ring_cd <= 0.0:
				ring_cd = 0.24 - 0.1 * c
				game.fx.ground_ring(global_position, 3.2 + 1.5 * c, 0.5, Color(1.0, 0.6 - 0.2 * c, 0.2, 0.55), 0.26)
			game.charge_zoom = c
			game.rumble(0.1 + 0.16 * c)
			if charge_t >= 0.95 and not maxed:
				maxed = true
				var wp2 := rig.weapon_points()
				if not wp2.is_empty():
					game.fx.flash(wp2[1], 1.6, Color(1.0, 0.75, 0.4), "magic_03", 0.3)
				game.main.sfx("sfx_parry", -6.0, 1.5)
				game.popup(global_position + Vector3(0, 2.3, 0), "МАКС!", Color(1, 0.6, 0.2))
			if not held("heavy") or charge_t >= 1.2:
				var fs2: Dictionary = FINISH[2].duplicate()
				fs2["dmg"] = float(fs2["dmg"]) * (1.0 + charge_t)
				fs2["kb"] = float(fs2["kb"]) * (1.0 + charge_t * 0.5)
				fs2["launch"] = float(fs2["launch"]) + charge_t * 2.0
				if charge_t > 0.6:
					fs2["super"] = true
				var keep := charge_t
				start_attack(fs2)
				charged = keep
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
	if state == "attack":
		var hh: Array = atk["hits"]
		var kk := t / float(atk["dur"])
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

func start_attack(a: Dictionary, chained := false) -> void:
	state = "attack"
	atk = a
	t = 0.0
	hit_done = false
	queued = ""
	hit_i = 0
	whoosh_i = 0
	slam_done = false
	scrape_done = false
	charged = 0.0
	face = _aim_face(float(a["range"]), input_dir())
	body.rotation.y = face
	rig.play_for(a["clip"], a["dur"], 0.12 if chained else 0.08)
	drop_done = false
	if chained and a.has("from"):
		t = float(a["from"]) * float(a["dur"])
		rig.player.seek(float(a["from"]) * rig.clip_len(a["clip"]), true)
	trail.boost = 1.5 if a.has("super") else (1.25 if a.has("heavy") else 1.0)
	trail.set_color(HOT if a.has("super") or rage > 0.0 else GOLD)

## Куда бить: к ближайшему врагу в секторе перед собой (по движению или по камере), иначе — просто вперёд
func _aim_face(reach: float, want: Vector3) -> float:
	var a := want.normalized() if want.length() > 0.3 else aim_dir()
	var best := Vector3.ZERO
	var bs := -1.0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		var dist := d.length()
		if dist > reach + 1.2 or dist < 0.05:
			continue
		var ang := a.angle_to(d / dist)
		if ang > 1.05:
			continue
		var score := (1.0 - ang / 1.05) * 2.0 + (1.0 - dist / (reach + 1.2))
		if score > bs:
			bs = score
			best = d
	if bs >= 0.0:
		return atan2(best.x, best.z)
	return atan2(a.x, a.z)

## вплотную перед нами враг — в него не шагаем
func _blocked(fwd: Vector3) -> bool:
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var d: Vector3 = e.global_position - global_position
			d.y = 0
			if d.length() < 1.15 + e.radius and d.normalized().dot(fwd) > 0.4:
				return true
	return false

## балон вошёл в землю
func _slam(fwd: Vector3) -> void:
	var at := global_position + fwd * 1.35
	var wp := rig.weapon_points()
	if not wp.is_empty():
		at = wp[1]
	var big := atk.has("super")
	game.fx.slam(at, 1.35 if big else 1.0, HOT if big or rage > 0.0 else GOLD)
	game.main.sfx("sfx_boom", 0.0, 0.9 if big else 1.1)
	game.shake(0.6 if big else 0.42)
	game.punch(1.0 if big else 0.5, at)

## тяжёлый удар: n — после скольких лёгких нажат (0 — с места)
func start_finisher(n: int, chained := false) -> void:
	var fin: Dictionary = FINISH[min(n, FINISH.size() - 1)]
	combo = 0
	if fin.has("charge"):
		state = "charge"
		t = 0.0
		charge_t = 0.0
		ring_cd = 0.0
		maxed = false
		face = _aim_face(4.0, input_dir())
		rig.play("Charge", 0.12)
		game.main.sfx("sfx_charge", -4.0)
		return
	start_attack(fin, chained)

## Heat-действие: рядом враг и есть 40 СВЭГа — удар сверху и полный замах с замедлением и наездом камеры
func try_heat() -> void:
	if swag < 40.0:
		game.popup(global_position + Vector3(0, 2.2, 0), "нужно 40 СВЭГа", Color(0.7, 0.75, 0.85))
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
	best.stun(2.5)
	inv = 1.7
	game.heat_cam(1.5)
	game.banner("HEAT", "прилёт VOZDUHом", Color(1, 0.75, 0.2))
	game.bark("heat", 4.0)
	heat_q = [HEAT[1]]
	start_attack(HEAT[0])

func start_roll(dir: Vector3) -> void:
	state = "roll"
	t = 0.0
	roll_dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(face), 0, cos(face))
	face = atan2(roll_dir.x, roll_dir.z)
	inv = 0.38
	rig.play("Tuck", 0.08)
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

func _deal_hit() -> void:
	var fwd := Vector3(sin(face), 0, cos(face))
	var hits := 0
	var mul := (1.6 if rage > 0.0 else 1.0) * dmg_mul
	var last: bool = hit_i >= (atk["hits"] as Array).size()
	var launch: float = atk.get("launch", 0.0)
	if last and atk.has("last_launch"):
		launch = atk["last_launch"]
	# сила отклика: 0 — лёгкий, 1 — тяжёлый, 2 — добивание или полный заряд; у серии ударов тяжёлым считается только последний
	var tier := 2 if atk.has("super") else (1 if atk.has("heavy") else 0)
	if atk.has("spin") and atk.has("heavy") and not last:
		tier = 0
	var col := HOT if rage > 0.0 or tier == 2 else GOLD
	var where := global_position + fwd * 1.3 + Vector3(0, 1.1, 0)
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() > float(atk["range"]) + 0.4:
			continue
		if d.length() > 0.5 and fwd.angle_to(d.normalized()) > float(atk["arc"]) * 0.5:
			continue
		var dn: Vector3 = d.normalized() if d.length() > 0.01 else fwd
		where = e.global_position + Vector3(0, e.height * 0.62, 0) - dn * e.radius
		e.take_hit(float(atk["dmg"]) * mul, dn, float(atk["kb"]), atk.has("heavy"), launch)
		game.fx.hit(where, dn, tier if hits < 2 else 0, col)
		if atk.has("stun") and is_instance_valid(e) and e.alive():
			e.stun(float(atk["stun"]))
		hits += 1
	if hits > 0:
		swag = min(100.0, swag + 6.0 * hits)
		if atk.has("name") and hit_i == 1:
			game.popup(global_position + Vector3(0, 2.4, 0), atk["name"], Color(1, 0.8, 0.3))
		game.main.sfx("sfx_glass" if randf() < 0.5 else "sfx_hit", -2.0)
		game.main.sfx("sfx_clang", -2.0 if tier > 0 else -6.0, 0.8 if tier > 0 else 1.0)   # низкий металл
		if tier >= 1:
			game.main.sfx("sfx_hit_heavy", 0.0)
		if tier == 2:
			game.main.sfx("sfx_crack", 1.0)
		game.impact(tier, where, 1.0 + charged * 0.4 + combo * 0.18)
		if tier == 2 or atk.has("name"):
			game.bark("finish", 9.0, 0.7)

func take_damage(dmg: float, from: Vector3, attacker = null) -> void:
	if state == "dead":
		return
	if inv > 0.0:
		if state == "roll":
			game.slowmo(0.5)
			game.popup(global_position + Vector3(0, 2.2, 0), "ТАЙМИНГ!", Color.WHITE)
		return
	var to: Vector3 = from - global_position
	to.y = 0
	if state == "block" and aim_dir().angle_to(to.normalized()) < 1.4:
		if block_t < 0.22 and attacker:
			attacker.stun(1.6)
			game.main.sfx("sfx_parry", 0.0)
			game.popup(global_position + Vector3(0, 2.2, 0), "ПАРИРОВАНИЕ", Color(0.4, 0.85, 1))
			game.fx.hit(global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.6, to.normalized(), 1, Color(0.5, 0.85, 1.0))
			game.punch(0.6, global_position + Vector3(0, 1.1, 0))
			game.bark("parry", 5.0)
			swag = min(100.0, swag + 20.0)
			game.slowmo(0.4)
			return
		dmg *= 0.2
		game.main.sfx("sfx_block", -2.0)
		game.fx.sparks(global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.5, -to.normalized() + Vector3(0, 0.5, 0), 10, Color(0.7, 0.85, 1.0), 0.7)
	else:
		game.main.sfx("sfx_hurt", -2.0)
		game.fx.hit(global_position + Vector3(0, 1.1, 0) + to.normalized() * 0.3, -to.normalized(), 0, Color(1.0, 0.3, 0.25))
		game.fx.claw(global_position + Vector3(0, 1.15, 0) + to.normalized() * 0.4, Color(1.0, 0.25, 0.2))
		state = "hurt"
		t = 0.0
		spin_off = 0.0
		spin.rotation.x = 0.0
		heat_q = []
		velocity = -to.normalized() * 4.0
		rig.play_for("Hit", 0.4, 0.06)
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
		rig.play_for("Death", 1.2, 0.1)
		game.on_player_dead()

func _process(dt: float) -> void:
	# в стойке и на бегу балон живёт по инерции; в ударах, блоке и перекате его ведёт анимация
	drag.floor_y = global_position.y + 0.06
	var free := 1.0 if state == "move" or state == "hurt" else 0.0
	drag.weight = move_toward(drag.weight, free, dt * (8.0 if free < drag.weight else 2.5))
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
		want = 1.0 + 4.0 * charge_t
	elif state == "attack" and charged > 0.3 and t / float(atk["dur"]) < 0.5:
		want = 5.0
	charge_light.light_energy = lerpf(charge_light.light_energy, want, 1.0 - exp(-14.0 * dt))
	if charge_light.light_energy > 0.05:
		var wp := rig.weapon_points()
		if not wp.is_empty():
			charge_light.global_position = wp[1]

