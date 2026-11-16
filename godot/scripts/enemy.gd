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
}
const BOSS_LOOK := {
	"courier": {"model": "clipper", "scale": 1.3}, "golem": {"model": "bot", "scale": 1.9}, "hype": {"model": "hater", "scale": 1.35},
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
	if cfg.has("tint") or cfg.has("alpha") or cfg.has("emit"):
		_tint(cfg.get("tint", Color.WHITE), cfg.get("alpha", 1.0), cfg.get("emit", 0.0))
	if not cfg.get("noweapon", false):
		if m == "hater":
			rig.attach("res://assets/models/staff.glb", "r", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.45, "length": 1.05, "shadow": false})
		elif m == "clipper":
			rig.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0, "shadow": false})
			rig.attach("res://assets/models/katana.glb", "r", {"bone": "hips", "axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02], "shadow": false})
		elif m == "pahan":
			rig.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	rig.play_for("Spawn", 1.0, 0.0)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.85
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1) * (height / 1.7)
	ring.position.y = 0.05
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.15, 0.1)
	ring.material_override = rm
	ring.visible = false
	add_child(ring)
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

func _setup_boss() -> void:
	boss = game.story["BOSS"][boss_id]
	var look: Dictionary = BOSS_LOOK.get(boss_id, {"model": "bot", "scale": 1.5})
	cfg = {"model": look["model"], "height": 1.75 * float(look["scale"]), "speed": float(boss["spd"]) / 40.0, "range": 2.4 * float(look["scale"]), "wind": 0.6,
		"dmg": float(boss["dmg"]), "clip": "Slash" if look["model"] == "clipper" else ("Cast" if look["model"] == "hater" else "Punch"), "cool": float(boss.get("gap", 1.5)),
		"tint": Color(boss["c"]), "xp": boss["xp"]}
	if look.has("alpha"):
		cfg["alpha"] = look["alpha"]
	cfg["emit"] = look.get("emit", 0.04)
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
	kb = kb.move_toward(Vector3.ZERO, 22.0 * dt)
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
			ring.scale = Vector3(1.0 + k * 0.4, 0.05, 1.0 + k * 0.4) * (height / 1.7)
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
		"dead":
			velocity = Vector3.ZERO
			if t > 3.0 and boss_id == "":
				position.y -= dt * 0.6
			if t > 5.0 and boss_id == "":
				queue_free()
			return
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face

func _wind(clip: String, w: float) -> void:
	state = "wind"
	t = 0.0
	ring.visible = true
	cfg["wind"] = w
	rig.play_for(clip, w * 2.0, 0.08)

func _teleport_near(pos: Vector3, r: float) -> void:
	var c: Color = cfg.get("tint", Color(0.7, 0.6, 1.0))
	game.shockwave(global_position, c)
	var a := randf() * TAU
	var np := pos + Vector3(cos(a), 0, sin(a)) * r
	if game.in_arena(np, 1.0):
		global_position = np
	game.shockwave(global_position, c)
	game.main.sfx("sfx_cast", -8.0, 1.4)

func _strike(dist: float, dir: Vector3) -> void:
	if cfg.has("summoner"):
		game.main.sfx("sfx_cast", -6.0, 0.7)
		for i in 2:
			game.spawn_enemy("bot", global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		return
	if cfg.has("ranged"):
		game.main.sfx("sfx_cast", -6.0)
		game.spawn_bolt(global_position + Vector3(0, height * 0.75, 0) + dir * 0.6, dir * 9.0, float(cfg["dmg"]), self, cfg.has("homing"))
		return
	game.main.sfx("sfx_slash" if kind == "clipper" else "sfx_swing", -6.0)
	if cfg.has("slam"):
		game.shake(0.3)
		game.shockwave(global_position, Color(0.6, 1.0, 0.4))
		if dist < float(cfg["slam"]):
			game.player.take_damage(float(cfg["dmg"]), global_position, self)
		return
	var reach: float = float(cfg["range"]) + (1.2 if cfg.has("lunge") else 0.3)
	if dist < reach and Vector3(sin(face), 0, cos(face)).angle_to(dir) < 1.1:
		game.player.take_damage(float(cfg["dmg"]), global_position, self)

# ---------------- боссы ----------------
func _boss_pick(dist: float) -> void:
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
			game.shake(0.45)
			game.shockwave(global_position, col)
			game.main.sfx("sfx_hit_heavy", 0.0)
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

func take_hit(dmg: float, dir: Vector3, knock: float, heavy := false) -> void:
	if not alive():
		return
	if cfg.get("shield", false) and not heavy:
		var front := Vector3(sin(face), 0, cos(face))
		if front.dot(-dir) > 0.3:
			dmg *= 0.25
			game.popup(global_position + Vector3(0, height + 0.2, 0), "ЩИТ", Color(0.5, 0.75, 1))
			game.main.sfx("sfx_block", -4.0)
	hp -= dmg
	kb = dir * knock * (0.25 if boss_id != "" else 1.0)
	game.popup(global_position + Vector3(0, height + 0.2, 0), str(int(dmg)), Color(1, 0.9, 0.4) if heavy else Color.WHITE)
	if boss_id != "":
		var phases: Array = boss["phases"]
		var np: int = clamp(int(floor((1.0 - hp / max_hp) * phases.size())), 0, phases.size() - 1)
		if np > phase:
			phase = np
			var barks: Array = boss.get("barks", [])
			if phase < barks.size() and String(barks[phase]) != "":
				game.boss_bark(String(boss["n"]), String(barks[phase]), Color(boss["c"]))
	if hp <= 0.0:
		_die(dir, heavy)
		return
	if state != "stun" and state != "wind" and state != "charge" and (boss_id == "" or heavy):
		state = "hurt"
		t = 0.0
		ring.visible = false
		rig.play_for("Hit", 0.4, 0.05)
	_update_bar()

func _die(dir: Vector3, heavy: bool) -> void:
	state = "dead"
	t = 0.0
	if hp_bar:
		hp_bar.visible = false
	ring.visible = false
	kb = dir * (9.0 if heavy else 5.0) * (0.3 if boss_id != "" else 1.0)
	var front := Vector3(sin(face), 0, cos(face)).dot(-dir) > 0.0
	if cfg["model"] == "pahan":
		rig.play_for("Death", 1.6, 0.06)
	else:
		rig.play_for("DeathA" if front else "DeathB", 0.9 if boss_id == "" else 1.6, 0.06)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	game.main.sfx("sfx_death", -4.0 if boss_id == "" else 2.0)
	game.on_kill(self)
