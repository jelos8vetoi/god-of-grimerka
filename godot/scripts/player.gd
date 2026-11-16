## Пахан: бег относительно камеры, комбо балоном, тяжёлый удар, перекат с неуязвимостью, блок/парирование, ПЕРЕГРУЗ, аура.
extends CharacterBody3D

const HEIGHT := 1.85
## Стиль боя балоном — как Slugger (бита) в Yakuza 0: широкие махи, цепочка из 4 лёгких,
## тяжёлый удар добивает по-разному в зависимости от того, после скольких лёгких нажат, полный замах заряжается удержанием ПКМ,
## Heat-действие [E] — добивание с замедлением.
const LIGHT := [
	{"clip": "Light1", "dur": 0.4, "hits": [0.5], "dmg": 20.0, "range": 2.6, "arc": 2.6, "kb": 3.5},
	{"clip": "Light2", "dur": 0.4, "hits": [0.52], "dmg": 20.0, "range": 2.6, "arc": 2.6, "kb": 3.5},
	{"clip": "Light1", "dur": 0.38, "hits": [0.5], "dmg": 22.0, "range": 2.6, "arc": 2.6, "kb": 4.0},
	{"clip": "Spin", "dur": 0.55, "hits": [0.35, 0.8], "dmg": 18.0, "range": 2.9, "arc": 6.3, "kb": 5.0, "spin": 1.0},
]
const FINISH := [
	{"clip": "Heavy", "dur": 0.8, "hits": [0.56], "dmg": 55.0, "range": 3.0, "arc": 2.0, "kb": 10.0, "heavy": true, "name": "ОВЕРХЕД"},
	{"clip": "Light3", "dur": 0.55, "hits": [0.5], "dmg": 45.0, "range": 2.9, "arc": 1.8, "kb": 6.0, "heavy": true, "stun": 1.5, "name": "ГВОЗДЬ"},
	{"clip": "FullSwing", "dur": 0.6, "hits": [0.45], "dmg": 55.0, "range": 3.2, "arc": 3.6, "kb": 16.0, "heavy": true, "charge": true, "name": "ПОЛНЫЙ ЗАМАХ"},
	{"clip": "Spin", "dur": 1.1, "hits": [0.12, 0.3, 0.48, 0.66, 0.84], "dmg": 16.0, "range": 3.0, "arc": 6.3, "kb": 3.0, "spin": 3.0, "heavy": true, "name": "НУНЧАКИ"},
]
const HEAT := [
	{"clip": "Smash", "dur": 0.75, "hits": [0.55], "dmg": 60.0, "range": 3.2, "arc": 2.4, "kb": 0.5, "heavy": true, "stun": 2.0},
	{"clip": "FullSwing", "dur": 0.7, "hits": [0.45], "dmg": 90.0, "range": 3.4, "arc": 3.0, "kb": 20.0, "heavy": true},
]

var game
var rig: Rig
var body: Node3D      # поворот по направлению взгляда
var spin: Node3D      # кувырок вокруг центра тела
var aura: GPUParticles3D
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
	_make_aura()

func _make_aura() -> void:
	aura = GPUParticles3D.new()
	aura.amount = 90
	aura.lifetime = 1.1
	aura.position.y = 0.2
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.55
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.scale_curve = curve
	aura.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _dot_tex()
	m.albedo_color = Color(1.0, 0.75, 0.25)
	m.vertex_color_use_as_albedo = true
	q.material = m
	aura.draw_pass_1 = q
	aura.emitting = false
	add_child(aura)
	aura_light = OmniLight3D.new()
	aura_light.position.y = 1.0
	aura_light.omni_range = 4.0
	aura_light.light_energy = 0.0
	aura_light.light_color = Color(1, 0.7, 0.3)
	add_child(aura_light)

func _dot_tex() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	g.width = 64
	g.height = 64
	return g

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
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
			var k := t / float(atk["dur"])
			if k < 0.45:
				velocity += aim_dir() * 2.2 * dt * 10.0 * (1.0 - k)
			var hs: Array = atk["hits"]
			while hit_i < hs.size() and k >= float(hs[hit_i]):
				hit_i += 1
				_deal_hit()
			spin_off = -TAU * float(atk.get("spin", 0.0)) * clamp(k, 0.0, 1.0)
			if heat_q.is_empty():
				if pressed("attack") and not atk.has("heavy"):
					queued = "light"
				elif pressed("heavy") and not atk.has("heavy"):
					queued = "heavy"
			if pressed("roll") and k > 0.35 and heat_q.is_empty():
				spin_off = 0.0
				start_roll(dir)
			elif k >= 1.0 or (queued != "" and k > 0.6):
				spin_off = 0.0
				if not heat_q.is_empty():
					start_attack(heat_q.pop_front())
				elif queued == "light" and combo < LIGHT.size() - 1:
					combo += 1
					start_attack(LIGHT[combo])
				elif queued == "heavy":
					start_finisher(combo + 1)
				else:
					state = "move"
					combo = 0
		"charge":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
			charge_t = min(1.2, charge_t + dt)
			face = lerp_angle(face, atan2(aim_dir().x, aim_dir().z), 1.0 - exp(-10.0 * dt))
			if not held("heavy") or charge_t >= 1.2:
				var fs2: Dictionary = FINISH[2].duplicate()
				fs2["dmg"] = float(fs2["dmg"]) * (1.0 + charge_t)
				fs2["kb"] = float(fs2["kb"]) * (1.0 + charge_t * 0.5)
				if charge_t > 0.9:
					game.popup(global_position + Vector3(0, 2.3, 0), "МАКС!", Color(1, 0.6, 0.2))
				start_attack(fs2)
		"roll":
			var k := t / 0.5
			velocity.x = roll_dir.x * 8.8 * (1.0 - k * 0.5)
			velocity.z = roll_dir.z * 8.8 * (1.0 - k * 0.5)
			var e: float = clamp((k - 0.08) / 0.8, 0.0, 1.0)
			spin.rotation.x = e * e * (3.0 - 2.0 * e) * TAU
			if k >= 1.0:
				spin.rotation.x = 0.0
				state = "move"
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
	var glow := 2.0 if rage > 0.0 else (1.0 if swag >= 100.0 else 0.0)
	aura.emitting = glow > 0.0
	var mat := (aura.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.35, 0.12) if rage > 0.0 else Color(1.0, 0.78, 0.3)
	aura.amount_ratio = 1.0 if glow > 1.5 else 0.6
	aura_light.light_energy = lerp(aura_light.light_energy, glow * 1.6, 1.0 - exp(-6.0 * dt))
	aura_light.light_color = mat.albedo_color

func start_attack(a: Dictionary) -> void:
	state = "attack"
	atk = a
	t = 0.0
	hit_done = false
	queued = ""
	hit_i = 0
	face = atan2(aim_dir().x, aim_dir().z)
	body.rotation.y = face
	rig.play_for(a["clip"], a["dur"] * 1.25, 0.08)
	game.main.sfx("sfx_swing_heavy" if a.has("heavy") else "sfx_swing", -4.0)

## тяжёлый удар: n — после скольких лёгких нажат (0 — с места)
func start_finisher(n: int) -> void:
	var fin: Dictionary = FINISH[min(n, FINISH.size() - 1)]
	combo = 0
	if fin.has("charge"):
		state = "charge"
		t = 0.0
		charge_t = 0.0
		face = atan2(aim_dir().x, aim_dir().z)
		rig.play("Charge", 0.1)
		game.main.sfx("sfx_swing", -10.0, 0.6)
		return
	start_attack(fin)

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
	heat_q = [HEAT[1]]
	start_attack(HEAT[0])

func start_roll(dir: Vector3) -> void:
	state = "roll"
	t = 0.0
	roll_dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(face), 0, cos(face))
	face = atan2(roll_dir.x, roll_dir.z)
	inv = 0.38
	rig.play("Tuck", 0.08)
	game.main.sfx("sfx_roll", -6.0)

func start_rage() -> void:
	state = "rage"
	t = 0.0
	rage = 8.0
	swag = 0.0
	rig.play_for("Rage", 0.8, 0.08)
	game.main.sfx("sfx_rage", 0.0)
	game.shake(0.6)
	game.banner("ПЕРЕГРУЗ!", "урон ×1.6 на 8 секунд", Color(1, 0.4, 0.15))
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and e.global_position.distance_to(global_position) < 5.0:
			e.take_hit(40.0, (e.global_position - global_position).normalized(), 9.0, true)

func _deal_hit() -> void:
	var a := aim_dir()
	var hits := 0
	var mul := (1.6 if rage > 0.0 else 1.0) * dmg_mul
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() > float(atk["range"]) + 0.4:
			continue
		if d.length() > 0.5 and a.angle_to(d.normalized()) > float(atk["arc"]) * 0.5:
			continue
		e.take_hit(float(atk["dmg"]) * mul, d.normalized() if d.length() > 0.01 else a, float(atk["kb"]), atk.has("heavy"))
		if atk.has("stun") and is_instance_valid(e) and e.alive():
			e.stun(float(atk["stun"]))
		hits += 1
	if hits > 0:
		swag = min(100.0, swag + 6.0 * hits)
		if atk.has("name") and hit_i == 1:
			game.popup(global_position + Vector3(0, 2.4, 0), atk["name"], Color(1, 0.8, 0.3))
		game.main.sfx("sfx_glass" if randf() < 0.5 else "sfx_hit", -2.0)
		game.hitstop(0.06 if not atk.has("heavy") else 0.12)
		if atk.has("heavy"):
			game.main.sfx("sfx_hit_heavy", 0.0)
			game.shake(0.35)

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
			swag = min(100.0, swag + 20.0)
			game.slowmo(0.4)
			return
		dmg *= 0.2
		game.main.sfx("sfx_block", -2.0)
	else:
		game.main.sfx("sfx_hurt", -2.0)
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
	inv = 0.25
	if hp <= 0.0:
		hp = 0.0
		state = "dead"
		rig.play_for("Death", 1.2, 0.1)
		game.on_player_dead()
