## Враги и боссы. Обычные: бот, клиппер (катана), хейтер (посох), тролль, удалённый трек, юрист, модератор (щит), накрутчик.
## Боссы — по данным сюжета (story.json → BOSS): фазы по здоровью, атаки slam/fan/charge/leap/burst/rain/spiral/homing/mines/summon/tp/wall/beam/shock.
extends CharacterBody3D

const KINDS := {
	"bot": {"model": "bot", "height": 1.7, "hp": 60.0, "speed": 3.1, "range": 1.8, "wind": 0.55, "dmg": 9.0, "clip": "Punch", "cool": 1.6, "xp": 10},
	"clipper": {"model": "clipper", "height": 1.8, "hp": 75.0, "speed": 4.4, "range": 2.2, "wind": 0.4, "dmg": 14.0, "clip": "Slash", "cool": 1.4, "lunge": 7.0, "xp": 22},
	"hater": {"model": "hater", "height": 1.75, "hp": 50.0, "speed": 2.6, "range": 11.0, "keep": 7.5, "wind": 0.7, "dmg": 10.0, "clip": "Cast", "cool": 2.4, "ranged": true, "xp": 18},
	"troll": {"model": "bot", "height": 2.5, "hp": 230.0, "speed": 2.0, "range": 2.6, "wind": 0.95, "dmg": 22.0, "clip": "Punch", "cool": 2.2, "slam": 3.2, "tint": Color("6aa544"), "xp": 45},
	"ghost": {"model": "hater", "height": 1.75, "hp": 85.0, "speed": 2.8, "range": 2.0, "wind": 0.5, "dmg": 15.0, "clip": "Cast", "cool": 2.0, "tele": true, "tint": Color("b79cff"), "alpha": 0.6, "emit": 0.4, "xp": 30},
	"lawyer": {"model": "clipper", "height": 1.8, "hp": 100.0, "speed": 2.4, "range": 12.0, "keep": 8.0, "wind": 0.8, "dmg": 12.0, "clip": "Punch", "cool": 2.6, "ranged": true, "homing": true, "noweapon": true, "tint": Color("e4e4ee"), "xp": 30},
	"mod": {"model": "bot", "height": 1.85, "hp": 120.0, "speed": 3.0, "range": 1.9, "wind": 0.5, "dmg": 13.0, "clip": "Punch", "cool": 1.6, "shield": true, "tint": Color("7fa8ff"), "xp": 32},
	"farmer": {"model": "hater", "height": 1.75, "hp": 130.0, "speed": 2.6, "range": 12.0, "keep": 9.0, "wind": 1.0, "dmg": 0.0, "clip": "Cast", "cool": 4.5, "summoner": true, "tint": Color("ffd23b"), "xp": 40},
	# двойник призрака: выглядит как босс, рассыпается с одного удара
	"clone": {"model": "pahan", "height": 2.1, "hp": 1.0, "speed": 4.2, "range": 2.4, "wind": 0.55, "dmg": 12.0, "clip": "Light1", "cool": 1.3, "tint": Color("ff8080"), "alpha": 0.85, "emit": 0.12, "xp": 0},
}
const BOSS_LOOK := {
	"courier": {"model": "drey", "scale": 1.3, "own": true}, "golem": {"model": "bot", "scale": 1.9}, "hype": {"model": "hater", "scale": 1.35},
	"dislike": {"model": "bot", "scale": 1.75}, "major": {"model": "clipper", "scale": 1.4}, "strike": {"model": "hater", "scale": 1.45},
	"botlord": {"model": "bot", "scale": 1.6}, "ghostv": {"model": "pahan", "scale": 1.2, "alpha": 0.85, "emit": 0.12}, "algo": {"model": "hater", "scale": 2.0, "emit": 0.1},
}

var game
var kind := "bot"
var boss_id := ""
var boss: Dictionary = {}
var cfg: Dictionary
var rig: Rig
var body: Node3D
var hp := 1.0
var max_hp := 1.0
var state := "spawn"
var t := 0.0
var cool := 1.0
var stun_t := 0.0
var face := 0.0
var kb := Vector3.ZERO
var ring: MeshInstance3D
var hp_bar: Sprite3D
var bar_img: Image
var height := 1.7
var phase := 0
var move := ""
var move_n := 0
var charge_dir := Vector3.ZERO
var radius := 0.36
var age := 0.0
# отклик на удар
var flash_on := false
var flash_until := 0.0
var hit_clock := -9.0
var hit_dir := Vector3.FORWARD
var sq_tw: Tween
var fly := false            # убитый летит по дуге
var fly_v := Vector3.ZERO
var bounces := 0
var trail: Trail
var spiked := false         # сбит в землю ударом сверху: приземлится с грохотом
var special_cd := 3.5      # до особого приёма босса
var sp_events: Array = []  # [время, что сделать] внутри приёма
var sp_dur := 0.0
var shield_n: Array = []   # призванные боты, которые держат щит
var shield_fx: MeshInstance3D
var glint := false          # предупреждающая вспышка перед ударом уже была
var stars: Node3D           # звёздочки над оглушённым

func _ready() -> void:
	if boss_id != "":
		_setup_boss()
	else:
		cfg = KINDS[kind].duplicate()
		max_hp = cfg["hp"] * float(game.diff_hp)
	hp = max_hp
	height = cfg["height"]
	cool = randf_range(0.6, 1.6)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	radius = 0.36 * height / 1.7
	cap.radius = radius
	cap.height = max(height * 0.9, radius * 2.0 + 0.1)
	col.shape = cap
	col.position.y = cap.height / 2.0
	add_child(col)
	body = Node3D.new()
	add_child(body)
	rig = Rig.new()
	body.add_child(rig)
	var m: String = cfg["model"]
	var poses: Dictionary
	if m == "pahan":
		poses = Poses.pahan_armed()
	elif m == "hater" and not cfg.get("noweapon", false):
		poses = Poses.hater()
	elif m == "clipper" and not cfg.get("noweapon", false):
		poses = Poses.clipper()
	else:
		poses = Poses.bot()
	rig.setup("res://assets/models/" + m + ".glb", height, poses, boss_id != "", -1.0 if m == "pahan" else 1.0, m + ("_n" if cfg.get("noweapon", false) else ""))
	if not cfg.get("own", false) and (cfg.has("tint") or cfg.has("alpha") or cfg.has("emit")):
		_tint(cfg.get("tint", Color.WHITE), cfg.get("alpha", 1.0), cfg.get("emit", 0.0))
	if not cfg.get("noweapon", false):
		if m == "hater":
			rig.attach("res://assets/models/staff.glb", "r", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.45, "length": 1.05, "shadow": false})
		elif m == "clipper":
			rig.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0, "shadow": false})
			rig.attach("res://assets/models/katana.glb", "r", {"bone": "hips", "axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02], "shadow": false})
		elif m == "pahan":
			rig.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	if rig.weapon != null and (m == "clipper" or m == "pahan"):
		trail = Trail.new()
		rig.add_child(trail)
		trail.setup(rig, Color(0.55, 0.9, 1.0) if m == "clipper" else Color(0.75, 0.55, 1.0), 0.3)
		trail.min_speed = 6.0
	rig.play_for("Spawn", 1.0, 0.0)
	# кольцо замаха у ног: текстурное, растёт, пока враг заносит удар
	ring = game.fx.flat(self, "circle_03", Color(1.0, 0.16, 0.1, 0.9), 2.0 * height / 1.7, 0.05, false)
	ring.visible = false
	if boss_id == "":
		bar_img = Image.create(64, 8, false, Image.FORMAT_RGBA8)
		hp_bar = Sprite3D.new()
		hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hp_bar.pixel_size = 0.012
		hp_bar.position.y = height + 0.35
		hp_bar.no_depth_test = true
		hp_bar.visible = false
		add_child(hp_bar)
	game.main.sfx("sfx_spawn", -10.0)
	game.fx.dust(global_position + Vector3(0, 0.15, 0), 8, game.fx.DUST, 0.9)
	game.fx.portal(global_position, 2.8 * height / 1.7, Color(1.0, 0.25, 0.2, 0.75), 1.0)
	if boss_id != "":
		game.fx.lightning(global_position, height * 2.4, Color(boss["c"]))
		game.fx.portal(global_position, 4.5 * height / 1.7, Color(boss["c"]), 1.4, "magic_02")

func _setup_boss() -> void:
	boss = game.story["BOSS"][boss_id]
	var look: Dictionary = BOSS_LOOK.get(boss_id, {"model": "bot", "scale": 1.5})
	cfg = {"model": look["model"], "height": 1.75 * float(look["scale"]), "speed": float(boss["spd"]) / 40.0, "range": 2.4 * float(look["scale"]), "wind": 0.6,
		"dmg": float(boss["dmg"]), "clip": "Slash" if look["model"] == "clipper" else ("Cast" if look["model"] == "hater" else "Punch"), "cool": float(boss.get("gap", 1.5)),
		"tint": Color(boss["c"]), "xp": boss["xp"]}
	if look.has("alpha"):
		cfg["alpha"] = look["alpha"]
	cfg["emit"] = look.get("emit", 0.04)
	cfg["own"] = look.get("own", false)   # своя модель босса: не перекрашиваем
	if look["model"] == "pahan":
		cfg["clip"] = "Light1"
	max_hp = float(boss["hp"]) * 0.75 * float(game.diff_hp)

func _tint(c: Color, alpha: float, emit: float) -> void:
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = Color.WHITE.lerp(c, 0.38)
			if alpha < 1.0:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mat.albedo_color.a = alpha
			if emit > 0.0:
				mat.emission_enabled = true
				mat.emission = c
				mat.emission_energy_multiplier = emit
			inst.set_surface_override_material(s, mat)

func alive() -> bool:
	return state != "dead" and state != "spawn"

func _update_bar() -> void:
	if boss_id != "":
		return
	var k: float = clamp(hp / max_hp, 0.0, 1.0)
	bar_img.fill(Color(0, 0, 0, 0.7))
	bar_img.fill_rect(Rect2i(1, 1, int(62 * k), 6), Color(1, 0.25, 0.2) if stun_t <= 0.0 else Color(1, 0.85, 0.2))
	hp_bar.texture = ImageTexture.create_from_image(bar_img)
	hp_bar.visible = k < 1.0 and state != "dead"

func _physics_process(dt: float) -> void:
	t += dt
	age += dt
	var p = game.player
	var to: Vector3 = p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir: Vector3 = to / max(dist, 0.001)
	velocity.x = kb.x
	velocity.z = kb.z
	if state != "air":
		kb = kb.move_toward(Vector3.ZERO, 22.0 * dt)
	if trail:
		trail.enabled = state == "wind" or (state == "recover" and t < 0.3)
	if game.paused_story() and state != "dead":
		velocity = Vector3.ZERO
		rig.play("Idle", 0.3)
		move_and_slide()
		return
	match state:
		"spawn":
			if t > 1.0:
				state = "chase"
				t = 0.0
		"chase":
			cool -= dt
			if boss_id != "":
				special_cd -= dt
			face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * dt))
			var want: float = cfg.get("keep", 0.0)
			var mv := Vector3.ZERO
			if cfg.has("ranged") or cfg.has("summoner"):
				if dist > want + 1.5:
					mv = dir
				elif dist < want - 1.5:
					mv = -dir
			elif dist > float(cfg["range"]) * 0.85:
				mv = dir
			for o in game.enemies:
				if o != self and is_instance_valid(o) and o.state != "dead":
					var d: Vector3 = global_position - o.global_position
					d.y = 0
					var sep: float = radius + o.radius + 0.4
					if d.length() < sep and d.length() > 0.01:
						mv += d.normalized() * (sep - d.length()) * 1.5
			if p.state == "dead":
				mv = Vector3.ZERO
			velocity.x += mv.x * float(cfg["speed"])
			velocity.z += mv.z * float(cfg["speed"])
			if mv.length() > 0.2:
				rig.play("Run", 0.2, float(cfg["speed"]) / 3.5)
			else:
				rig.play("Idle", 0.3)
			if cool <= 0.0 and p.state != "dead":
				if boss_id != "":
					_boss_pick(dist)
				elif cfg.has("tele") and dist > 3.0:
					_teleport_near(p.global_position, 1.8)
					cool = 0.4
				elif dist < float(cfg["range"]) or cfg.has("summoner"):
					# в ближнем бою одновременно замахиваются не больше двоих — иначе героя держат в вечном оглушении
					if not cfg.has("ranged") and not cfg.has("summoner") and game.melee_attackers() >= 2:
						cool = randf_range(0.25, 0.6)
					else:
						_wind(String(cfg["clip"]), float(cfg["wind"]))
		"wind":
			face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-6.0 * dt))
			var k: float = t / float(cfg["wind"])
			ring.scale = Vector3.ONE * 2.0 * (1.0 + k * 0.4) * (height / 1.7)
			if not glint and k > 0.66:
				# блик перед самым ударом — по нему ставят блок и перекат
				glint = true
				game.fx.flash(global_position + Vector3(0, height * 0.82, 0) + Vector3(sin(face), 0, cos(face)) * radius, 0.9 * height / 1.7, Color(1.0, 0.3, 0.2), "star_07", 0.2)
			if k >= 1.0:
				ring.visible = false
				if boss_id != "":
					_boss_strike(dist, dir)
				else:
					_strike(dist, dir)
				if state == "wind":
					state = "recover"
				t = 0.0
		"charge":
			velocity.x += charge_dir.x * 13.0
			velocity.z += charge_dir.z * 13.0
			rig.play("Run", 0.1, 2.5)
			if dist < float(cfg["range"]) * 0.7 and p.inv <= 0.0:
				p.take_damage(float(cfg["dmg"]) * 1.2, global_position, self)
				state = "recover"
				t = 0.0
			if t > 0.8 or not game.in_arena(global_position + charge_dir, 0.5):
				state = "recover"
				t = 0.0
		"special":
			while not sp_events.is_empty() and t >= float(sp_events[0][0]):
				var ev: Array = sp_events.pop_front()
				(ev[1] as Callable).call()
			if boss_id != "hype":
				face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-5.0 * dt))
			if t > sp_dur:
				state = "recover"
				t = 0.0
		"recover":
			if cfg.has("lunge") and t < 0.15:
				velocity += Vector3(sin(face), 0, cos(face)) * float(cfg["lunge"])
			if t > float(cfg["wind"]) * (0.6 if boss_id != "" else 1.0):
				state = "chase"
				cool = float(cfg["cool"]) * randf_range(0.8, 1.25)
		"hurt":
			if t > 0.35:
				state = "chase"
		"stun":
			stun_t -= dt
			body.rotation.z = sin(t * 18.0) * 0.06
			if stun_t <= 0.0:
				body.rotation.z = 0.0
				state = "chase"
		"air":
			# сбит с ног: летит по дуге, пока не коснётся земли
			if t > 0.12 and is_on_floor():
				game.fx.land(global_position, 1.0)
				if spiked:
					spiked = false
					game.fx.slam(global_position, 0.8, Color(1.0, 0.8, 0.42))
					game.shake(0.3)
					game.main.sfx("sfx_boom", -4.0, 1.1)
				game.main.sfx("sfx_thud", -5.0)
				game.shake(0.1)
				kb *= 0.3
				state = "down"
				t = 0.0
				rig.play_for("GetUp", 9999.0, 0.08)
		"down":
			if t > 0.7:
				state = "getup"
				t = 0.0
				rig.play_for("GetUp", 0.55, 0.05)
		"getup":
			if t > 0.55:
				state = "chase"
				cool = max(cool, 0.5)
		"dead":
			velocity = Vector3.ZERO
			var lim: float = game.ARENA - 0.7
			if fly:
				# тело летит само, без столкновений: дуга, отскок от земли и от края арены
				fly_v.y -= 20.0 * dt
				var np := global_position + fly_v * dt
				if abs(np.x) > lim:
					np.x = clampf(np.x, -lim, lim)
					fly_v.x *= -0.35
				if abs(np.z) > lim:
					np.z = clampf(np.z, -lim, lim)
					fly_v.z *= -0.35
				if np.y <= 0.05 and fly_v.y < 0.0:
					np.y = 0.05
					game.fx.land(np, 1.2)
					game.main.sfx("sfx_thud", -3.0)
					if fly_v.y < -5.0 and bounces < 1:
						bounces += 1
						fly_v = Vector3(fly_v.x * 0.5, -fly_v.y * 0.3, fly_v.z * 0.5)
					else:
						fly = false
						kb = Vector3(fly_v.x, 0, fly_v.z) * 0.4
						t = 0.0
						rig.play_for("GetUp", 9999.0, 0.1)
				global_position = np
			else:
				var sp := global_position + Vector3(kb.x, 0, kb.z) * dt
				global_position = Vector3(clampf(sp.x, -lim, lim), global_position.y, clampf(sp.z, -lim, lim))
				if t > 2.6 and boss_id == "":
					# тело не тонет в полу, а рассыпается дымом с искрами
					game.fx.poof(global_position, height / 1.7, Color(0.85, 0.8, 0.95))
					queue_free()
			body.rotation.y = face
			return
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face

func _wind(clip: String, w: float) -> void:
	state = "wind"
	t = 0.0
	ring.visible = true
	glint = false
	cfg["wind"] = w
	rig.play_for(clip, w * 2.0, 0.08)

func _teleport_near(pos: Vector3, r: float) -> void:
	var c: Color = cfg.get("tint", Color(0.7, 0.6, 1.0))
	game.fx.poof(global_position, height / 1.7, c)
	var a := randf() * TAU
	var np := pos + Vector3(cos(a), 0, sin(a)) * r
	if game.in_arena(np, 1.0):
		global_position = np
	game.fx.twirl(global_position, 3.2, c, 0.5, "twirl_03")
	game.fx.poof(global_position, height / 1.7, c)
	game.main.sfx("sfx_cast", -8.0, 1.4)

func _strike(dist: float, dir: Vector3) -> void:
	if cfg.has("summoner"):
		game.main.sfx("sfx_cast", -6.0, 0.7)
		game.fx.portal(global_position, 4.2, Color(1.0, 0.82, 0.25, 0.8), 0.9, "magic_02")
		game.fx.portal(global_position, 3.0, Color(1.0, 0.82, 0.25, 0.5), 0.9)
		for i in 2:
			game.spawn_enemy("bot", global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		return
	if cfg.has("ranged"):
		game.main.sfx("sfx_cast", -6.0)
		var wp := rig.weapon_points()
		game.fx.muzzle(wp[1] if not wp.is_empty() else global_position + Vector3(0, height * 0.75, 0) + dir * 0.6, Color(0.4, 1.0, 0.55))
		game.spawn_bolt(global_position + Vector3(0, height * 0.75, 0) + dir * 0.6, dir * 9.0, float(cfg["dmg"]), self, cfg.has("homing"))
		return
	game.main.sfx("sfx_slash" if kind == "clipper" else "sfx_swing", -6.0)
	if cfg.has("slam"):
		game.shake(0.4)
		game.fx.slam(global_position + Vector3(sin(face), 0, cos(face)) * 1.3, 1.25, Color(0.6, 1.0, 0.4))
		game.main.sfx("sfx_boom", -3.0)
		if dist < float(cfg["slam"]):
			game.player.take_damage(float(cfg["dmg"]), global_position, self)
		return
	var reach: float = float(cfg["range"]) + (1.2 if cfg.has("lunge") else 0.3)
	if dist < reach and Vector3(sin(face), 0, cos(face)).angle_to(dir) < 1.1:
		game.player.take_damage(float(cfg["dmg"]), global_position, self)

# ---------------- боссы ----------------
func _boss_pick(dist: float) -> void:
	if special_cd <= 0.0:
		special_cd = randf_range(10.0, 13.0) - phase * 1.5
		_special()
		return
	var phases: Array = boss["phases"]
	var moves: Array = phases[min(phase, phases.size() - 1)]
	move = moves[move_n % moves.size()]
	move_n += 1
	match move:
		"charge":
			_wind(String(cfg["clip"]), 0.55)
		"tp":
			_teleport_near(game.player.global_position, 3.5)
			cool = 0.5
		"slam", "shock":
			if dist > float(cfg["range"]) + 2.5:
				cool = 0.3
				move_n -= 1
				return
			_wind(String(cfg["clip"]), 0.75)
		"leap":
			_wind(String(cfg["clip"]), 0.6)
		_:
			_wind("Cast" if cfg["model"] == "hater" else String(cfg["clip"]), 0.65)

func _boss_strike(dist: float, dir: Vector3) -> void:
	var dmg := float(cfg["dmg"])
	var pp: Vector3 = game.player.global_position
	var from := global_position + Vector3(0, height * 0.55, 0)
	var col: Color = cfg["tint"]
	match move:
		"slam":
			game.shake(0.55)
			game.fx.slam(global_position + Vector3(sin(face), 0, cos(face)) * 1.2, 1.7, col)
			game.main.sfx("sfx_boom", 0.0, 0.85)
			if dist < float(cfg["range"]) + 1.6:
				game.player.take_damage(dmg * 1.3, global_position, self)
		"shock":
			game.shockwave(global_position, col)
			game.expanding_ring(global_position, 9.0, 1.2, dmg, self)
		"leap":
			var target := Vector3(pp.x, 0, pp.z)
			game.telegraph(target, 2.6, 0.7, dmg * 1.4, self)
			var tw := create_tween()
			tw.tween_property(self, "global_position", target - dir * 0.8, 0.7).set_trans(Tween.TRANS_QUAD)
			game.main.sfx("sfx_swing_heavy", -2.0)
		"charge":
			charge_dir = dir
			state = "charge"
			t = 0.0
			game.main.sfx("sfx_swing_heavy", -2.0)
		"fan":
			for i in 5:
				game.spawn_bolt(from, dir.rotated(Vector3.UP, (i - 2) * 0.22) * 10.0, dmg * 0.6, self, false, col)
		"burst":
			for i in 14:
				game.spawn_bolt(from, Vector3.FORWARD.rotated(Vector3.UP, i / 14.0 * TAU) * 8.0, dmg * 0.6, self, false, col)
		"spiral":
			for i in 24:
				var b := i
				get_tree().create_timer(i * 0.06, false).timeout.connect(func():
					if is_instance_valid(self) and state != "dead":
						game.spawn_bolt(global_position + Vector3(0, height * 0.55, 0), Vector3.FORWARD.rotated(Vector3.UP, b * 0.55) * 8.0, dmg * 0.5, self, false, col))
		"wall":
			var side := dir.cross(Vector3.UP).normalized()
			var gap := randi_range(-3, 3)
			for i in range(-6, 7):
				if abs(i - gap) <= 1:
					continue
				game.spawn_bolt(from + side * i * 0.9 - dir * 1.0, dir * 7.0, dmg * 0.6, self, false, col)
		"homing":
			for i in 3:
				game.spawn_bolt(from + Vector3(0, 0.3 * i, 0), dir.rotated(Vector3.UP, (i - 1) * 0.6) * 6.0, dmg * 0.7, self, true, col)
		"rain":
			for i in 7:
				var at := pp + Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
				if i == 0:
					at = pp
				game.telegraph(at, 1.6, 0.9 + i * 0.08, dmg * 0.8, self)
		"mines":
			for i in 4:
				game.telegraph(global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 2.0, 1.6, dmg, self)
		"beam":
			for i in 10:
				game.telegraph(global_position + dir * (1.6 + i * 1.5), 1.1, 0.8, dmg * 0.9, self)
		"summon":
			var kinds := ["bot", "clipper", "hater"]
			for i in 2 + phase:
				game.spawn_enemy(kinds[randi() % kinds.size()], global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		_:
			if dist < float(cfg["range"]) + 0.8:
				game.player.take_damage(dmg, global_position, self)

func stun(sec: float) -> void:
	if state == "dead" or state == "spawn":
		return
	if boss_id != "":
		sec *= 0.35
	state = "stun"
	t = 0.0
	stun_t = sec
	ring.visible = false
	rig.play_for("Hit", 0.5, 0.06)
	_update_bar()

func _process(_dt: float) -> void:
	var c: float = game.clock
	if boss_id == "botlord":
		var on := shielded()
		if on and shield_fx == null:
			shield_fx = game.fx._sprite("circle_01", Vector3(0, height * 0.55, 0), Color(1.0, 0.82, 0.3, 0.45), true, true, false, self)
			shield_fx.scale = Vector3.ONE * height * 1.5
		if shield_fx:
			shield_fx.visible = on
	if state == "stun":
		if stars == null:
			stars = game.fx.stun_stars(self, height + 0.3)
		stars.visible = true
		stars.rotation.y = c * 5.0
	elif stars != null and stars.visible:
		stars.visible = false
	if flash_on:
		var a := clampf((flash_until - c) / 0.1, 0.0, 1.0)
		rig.flash(a * 0.55, Color(1.0, 0.9, 0.72))
		if a <= 0.0:
			flash_on = false
	# пока стоит стоп-кадр, тело мелко дрожит поперёк удара — видно, что удар «вошёл»
	if c < game.stop_until and c - hit_clock < 0.35:
		var side := hit_dir.cross(Vector3.UP)
		body.position = side * sin(c * 120.0) * 0.05 + hit_dir * sin(c * 87.0) * 0.02
	elif body.position != Vector3.ZERO:
		body.position = Vector3.ZERO

## вспышка, сплющивание и пружинистый возврат
func _react(dir: Vector3, heavy: bool) -> void:
	hit_clock = game.clock
	hit_dir = dir
	flash_on = true
	flash_until = game.clock + (0.17 if heavy else 0.11)
	rig.flash(0.55, Color(1.0, 0.9, 0.72))
	if sq_tw:
		sq_tw.kill()
	var k := 0.8 if heavy else 0.9
	body.scale = Vector3(2.0 - k, k, 2.0 - k)
	sq_tw = create_tween()
	sq_tw.tween_property(body, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_hit(dmg: float, dir: Vector3, knock: float, heavy := false, launch := 0.0) -> void:
	if not alive():
		return
	if cfg.get("shield", false) and not heavy:
		var front := Vector3(sin(face), 0, cos(face))
		if front.dot(-dir) > 0.3:
			dmg *= 0.25
			launch = 0.0
			game.popup(global_position + Vector3(0, height + 0.2, 0), "ЩИТ", Color(0.5, 0.75, 1))
			game.fx.shield(global_position + Vector3(0, height * 0.6, 0) - dir * radius, -dir, Color(0.5, 0.75, 1.0), 1.5 * height / 1.7)
			game.main.sfx("sfx_block", -4.0)
	if boss_id != "" and shielded():
		dmg *= 0.15
		launch = 0.0
		game.fx.shield(global_position + Vector3(0, height * 0.6, 0) - dir * radius, -dir, Color(1.0, 0.82, 0.3), 1.6 * height / 1.7)
	hp -= dmg
	kb = dir * knock * (0.25 if boss_id != "" else 1.0)
	_react(dir, heavy)
	game.popup(global_position + Vector3(0, height + 0.2, 0), str(int(dmg)), Color(1, 0.9, 0.4) if heavy else Color.WHITE)
	if boss_id != "":
		var phases: Array = boss["phases"]
		var np: int = clamp(int(floor((1.0 - hp / max_hp) * phases.size())), 0, phases.size() - 1)
		if np > phase:
			phase = np
			game.fx.lightning(global_position, height * 2.2, Color(boss["c"]))
			var barks: Array = boss.get("barks", [])
			if phase < barks.size() and String(barks[phase]) != "":
				game.boss_bark(String(boss["n"]), String(barks[phase]), Color(boss["c"]), String(boss.get("sp", "")))
	if hp <= 0.0:
		_die(dir, heavy, launch, knock)
		return
	if launch < 0.0:
		if state == "air" and boss_id == "":
			spiked = true
			velocity.y = launch
			kb = dir * 1.5
			launch = 0.0
		else:
			launch = 4.5
	if launch > 0.0 and boss_id == "":
		# подброс: тяжёлых подкидывает слабее; в воздухе отбрасывание не гаснет
		state = "air"
		t = 0.0
		ring.visible = false
		velocity.y = launch * (0.6 if height > 2.2 else 1.0)
		kb = dir * max(knock, 2.0)
		face = atan2(-dir.x, -dir.z)
		rig.play("Fly", 0.08)
	elif state == "air":
		velocity.y = max(velocity.y, 2.5)   # в воздухе каждый удар чуть подбрасывает
	elif state != "stun" and state != "wind" and state != "charge" and state != "down" and state != "getup" and state != "special" and (boss_id == "" or heavy):
		state = "hurt"
		t = 0.0
		ring.visible = false
		rig.play_for("Hit", 0.45, 0.04)
	_update_bar()

func _die(dir: Vector3, heavy: bool, launch := 0.0, knock := 5.0) -> void:
	var was_air := state == "air"
	state = "dead"
	t = 0.0
	if hp_bar:
		hp_bar.visible = false
	ring.visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	game.main.sfx("sfx_death", -4.0 if boss_id == "" else 2.0)
	if boss_id == "" and (heavy or launch > 0.0 or was_air):
		# тяжёлым ударом тело уносит по дуге
		fly = true
		bounces = 0
		fly_v = dir * clampf(knock * 0.8, 5.0, 16.0) + Vector3(0, max(launch, 4.5), 0)
		face = atan2(-dir.x, -dir.z)
		rig.play("Fly", 0.06)
	else:
		kb = dir * 5.0 * (0.3 if boss_id != "" else 1.0)
		var front := Vector3(sin(face), 0, cos(face)).dot(-dir) > 0.0
		if cfg["model"] == "pahan":
			rig.play_for("Death", 1.6, 0.06)
		else:
			rig.play_for("DeathA" if front else "DeathB", 0.9 if boss_id == "" else 1.6, 0.06)
	game.on_kill(self)

# ---------------- особые приёмы боссов ----------------
func _at(time: float, what: Callable) -> void:
	sp_events.append([time, what])

## щит накрутки: пока живы призванные боты, урон по боссу почти не проходит
func shielded() -> bool:
	shield_n = shield_n.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	return not shield_n.is_empty()

## У каждого босса свой приём со своей анимацией: срабатывает раз в 10–13 секунд (в поздних фазах чаще и сильнее).
## Пока приём идёт, босс открыт для ударов; оглушение его срывает.
func _special() -> void:
	state = "special"
	t = 0.0
	ring.visible = false
	sp_events = []
	sp_dur = 1.5
	var dmg := float(cfg["dmg"])
	var col: Color = cfg["tint"]
	var P = game.player
	var title := ""
	match boss_id:
		"courier":
			# ДОСТАВКА: посылки летят по дуге туда, куда бежит герой, и взрываются
			title = "ДОСТАВКА"
			var n := 3 + phase
			for i in n:
				_at(0.3 + i * 0.42, func():
					rig.play_for("Throw", 0.42, 0.05)
					var to: Vector3 = P.global_position + P.velocity * 0.5 + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
					game.lob(global_position + Vector3(0, height * 0.9, 0), to, 0.85, col)
					game.telegraph(to, 1.9, 0.85, dmg * 0.9, self)
					game.main.sfx("sfx_swing", -5.0, 0.8))
			sp_dur = 0.3 + n * 0.42 + 0.4
			game.bark("drey", 0.0)
		"golem":
			# ОБВАЛ: прыжок, три волны по земле одна за другой и камни с потолка
			title = "ОБВАЛ"
			rig.play_for("Stomp", 1.2, 0.08)
			_at(0.74, func():
				game.fx.slam(global_position, 1.8, col)
				game.main.sfx("sfx_boom", 1.0, 0.75)
				game.shake(0.55)
				for i in 5 + phase * 2:
					game.telegraph(P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), 1.5, 1.0 + i * 0.13, dmg * 0.8, self))
			for i in 3:
				_at(0.74 + i * 0.42, func(): game.expanding_ring(global_position, 12.0, 1.3, dmg, self))
			sp_dur = 2.3
		"hype":
			# СВАЙП: неоновый луч, которым она водит по кругу; во второй фазе лучей два
			title = "СВАЙП"
			rig.play("Point", 0.15)
			var to: Vector3 = P.global_position - global_position
			var a0 := atan2(-to.x, -to.z) + 1.0
			var w := 1.5 * (1.0 if randf() < 0.5 else -1.0)
			game.sweep(self, 13.0, 4.4, w, dmg * 0.8, col, a0)
			if phase >= 1:
				game.sweep(self, 13.0, 4.4, w, dmg * 0.8, col, a0 + PI)
			game.main.sfx("sfx_charge", -2.0, 1.3)
			sp_dur = 4.6
		"dislike":
			# ДИЗЛАЙК: плевки, после которых остаются ядовитые лужи
			title = "ДИЗЛАЙК"
			var n := 4 + phase
			var green := Color(0.5, 0.95, 0.25)
			for i in n:
				_at(0.3 + i * 0.3, func():
					rig.play_for("Spit", 0.3, 0.04)
					var to: Vector3 = P.global_position + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))
					game.lob(global_position + Vector3(0, height * 0.8, 0), to, 0.8, green, false)
					game.telegraph(to, 2.0, 0.8, dmg * 0.7, self, {"pool": 6.0, "col": green})
					game.main.sfx("sfx_cast", -6.0, 0.6))
			sp_dur = 0.3 + n * 0.3 + 0.5
		"major":
			# ПЕЧАТЬ: круг едет за героем, замирает — и сверху падает плита
			title = "ПЕЧАТЬ"
			var n := 2 + phase
			for i in n:
				_at(0.2 + i * 1.25, func():
					rig.play_for("Stamp", 1.2, 0.06)
					game.telegraph(P.global_position, 2.6, 1.15, dmg * 1.4, self, {"chase": 0.4, "stamp": true})
					game.main.sfx("sfx_swing_heavy", -3.0, 0.7))
			sp_dur = 0.2 + n * 1.25 + 0.3
		"strike":
			# СТРАЙК: молнии бьют туда, где герой окажется через мгновение
			title = "СТРАЙК"
			var n := 5 + phase * 2
			rig.play_for("Summon", 0.4 + n * 0.32 + 0.4, 0.1)
			for i in n:
				_at(0.4 + i * 0.32, func(): game.telegraph(P.global_position + P.velocity * 0.25, 1.5, 0.6, dmg * 0.9, self, {"bolt": true, "col": Color(0.72, 0.5, 1.0)}))
			sp_dur = 0.4 + n * 0.32 + 0.5
		"botlord":
			# НАКРУТКА: призывает ботов, и пока они живы, по нему почти не проходит урон
			title = "НАКРУТКА"
			rig.play("Channel", 0.15)
			_at(0.5, func():
				var n := 4 + phase
				for i in n:
					var a := i * TAU / n
					var p := global_position + Vector3(sin(a), 0, cos(a)) * 4.0
					p.x = clampf(p.x, -13.0, 13.0)
					p.z = clampf(p.z, -13.0, 13.0)
					shield_n.append(game._make_enemy("bot", "", Vector3(p.x, 0.05, p.z)))
					game.fx.lightning(p, 4.0, col)
				game.main.sfx("sfx_cast", -3.0, 0.7))
			sp_dur = 1.6
		"ghostv":
			# ЗЕРКАЛО: двойники, которые рассыпаются с одного удара, а сам он меняет место
			title = "ЗЕРКАЛО"
			rig.play_for("Rage", 0.9, 0.08)
			_at(0.45, func():
				for i in 2 + (1 if phase >= 2 else 0):
					var a := randf() * TAU
					var p: Vector3 = P.global_position + Vector3(sin(a), 0, cos(a)) * 4.5
					if game.in_arena(p, 1.0):
						game._make_enemy("clone", "", Vector3(p.x, 0.05, p.z))
						game.fx.poof(p, 1.2, col)
				_teleport_near(P.global_position, 4.5))
			sp_dur = 1.0
		"algo":
			# АЛГОРИТМ: вся арена взрывается, спастись можно только в зелёном круге
			title = "РЕКОМЕНДАЦИЯ"
			rig.play("Ascend", 0.2)
			var safe := Vector3.ZERO
			for i in 10:
				var a := randf() * TAU
				safe = Vector3(sin(a), 0, cos(a)) * randf_range(4.0, 9.0)
				if safe.distance_to(global_position) > 5.0:
					break
			game.wipe(safe, 3.2, 3.4, dmg * 2.2, self, col)
			var tw := create_tween()
			tw.tween_property(rig, "position:y", 1.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(2.5)
			tw.tween_property(rig, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			game.main.sfx("sfx_charge", 0.0, 0.8)
			sp_dur = 3.9
		_:
			state = "chase"
			return
	sp_events.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	game.popup(global_position + Vector3(0, height + 0.7, 0), title, col.lightened(0.3))
	game.main.sfx("sfx_rage", -7.0, 1.3)
	game.fx.ground_ring(global_position, 0.6, 5.0 * height / 1.7, col, 0.45)
