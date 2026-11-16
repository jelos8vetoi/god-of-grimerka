## Враги: бот (кулак), клиппер (катана), хейтер (посох, бьёт издалека). Появление из-под земли, замах с меткой, урон, смерть.
extends CharacterBody3D

const KINDS := {
	"bot": {"model": "res://assets/models/bot.glb", "height": 1.7, "hp": 70.0, "speed": 3.1, "range": 1.8, "wind": 0.55, "dmg": 10.0, "clip": "Punch", "cool": 1.6, "name": "Бот"},
	"clipper": {"model": "res://assets/models/clipper.glb", "height": 1.8, "hp": 55.0, "speed": 4.4, "range": 2.2, "wind": 0.4, "dmg": 14.0, "clip": "Slash", "cool": 1.4, "lunge": 7.0, "name": "Клиппер"},
	"hater": {"model": "res://assets/models/hater.glb", "height": 1.75, "hp": 50.0, "speed": 2.6, "range": 11.0, "keep": 7.5, "wind": 0.7, "dmg": 12.0, "clip": "Cast", "cool": 2.6, "ranged": true, "name": "Хейтер"},
}

var game
var kind := "bot"
var cfg: Dictionary
var rig: Rig
var body: Node3D
var hp := 1.0
var state := "spawn"
var t := 0.0
var cool := 1.0
var stun_t := 0.0
var face := 0.0
var kb := Vector3.ZERO
var ring: MeshInstance3D
var hp_bar: Sprite3D
var bar_img: Image

func _ready() -> void:
	cfg = KINDS[kind]
	hp = cfg["hp"]
	cool = randf_range(0.6, 1.6)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	add_child(col)
	body = Node3D.new()
	add_child(body)
	rig = Rig.new()
	body.add_child(rig)
	rig.setup(cfg["model"], cfg["height"], Poses.enemy(), false)
	var idle := Poses.en({})
	if kind == "hater":
		rig.attach("res://assets/models/staff.glb", "rhand", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.42, "dir": [0, 1, 0.08], "length": 1.05, "pose": idle, "shadow": false})
	elif kind == "clipper":
		rig.attach("res://assets/models/katana.glb", "rhand", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.08, "dir": [-0.25, -0.7, 0.67], "length": 0.62, "pose": idle, "part": func(y): return y > 13.0, "shadow": false})
		rig.attach("res://assets/models/katana.glb", "hips", {"axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "pose": idle, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02], "shadow": false})
	rig.play_for("Spawn", 1.0, 0.0)
	# метка замаха
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.85
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.05
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.15, 0.1)
	rm.emission_enabled = true
	rm.emission = Color(1, 0.1, 0.05)
	ring.material_override = rm
	ring.visible = false
	add_child(ring)
	# полоска здоровья
	bar_img = Image.create(64, 8, false, Image.FORMAT_RGBA8)
	hp_bar = Sprite3D.new()
	hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_bar.pixel_size = 0.012
	hp_bar.position.y = cfg["height"] + 0.35
	hp_bar.no_depth_test = true
	hp_bar.visible = false
	add_child(hp_bar)
	game.main.sfx("sfx_spawn", -10.0)

func alive() -> bool:
	return state != "dead" and state != "spawn"

func _update_bar() -> void:
	var k: float = clamp(hp / float(cfg["hp"]), 0.0, 1.0)
	bar_img.fill(Color(0, 0, 0, 0.7))
	bar_img.fill_rect(Rect2i(1, 1, int(62 * k), 6), Color(1, 0.25, 0.2) if stun_t <= 0.0 else Color(1, 0.85, 0.2))
	hp_bar.texture = ImageTexture.create_from_image(bar_img)
	hp_bar.visible = k < 1.0 and state != "dead"

func _physics_process(dt: float) -> void:
	t += dt
	var p = game.player
	var to: Vector3 = p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir: Vector3 = to / max(dist, 0.001)
	velocity.x = kb.x
	velocity.z = kb.z
	kb = kb.move_toward(Vector3.ZERO, 22.0 * dt)
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
			if cfg.has("ranged"):
				if dist > want + 1.5:
					mv = dir
				elif dist < want - 1.5:
					mv = -dir
			elif dist > float(cfg["range"]) * 0.85:
				mv = dir
			# не толпиться
			for o in game.enemies:
				if o != self and is_instance_valid(o) and o.state != "dead":
					var d: Vector3 = global_position - o.global_position
					d.y = 0
					if d.length() < 1.2 and d.length() > 0.01:
						mv += d.normalized() * (1.2 - d.length()) * 1.5
			if p.state == "dead":
				mv = Vector3.ZERO
			velocity.x += mv.x * float(cfg["speed"])
			velocity.z += mv.z * float(cfg["speed"])
			if mv.length() > 0.2:
				rig.play("Run", 0.2, float(cfg["speed"]) / 3.5)
			else:
				rig.play("Idle", 0.3)
			if cool <= 0.0 and dist < float(cfg["range"]) and p.state != "dead":
				state = "wind"
				t = 0.0
				ring.visible = true
				rig.play_for(cfg["clip"], float(cfg["wind"]) * 2.0, 0.08)
		"wind":
			face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-6.0 * dt))
			var k: float = t / float(cfg["wind"])
			ring.scale = Vector3(1.0 + k * 0.4, 0.05, 1.0 + k * 0.4)
			if k >= 1.0:
				ring.visible = false
				_strike(dist, dir)
				state = "recover"
				t = 0.0
		"recover":
			if cfg.has("lunge") and t < 0.15:
				velocity += Vector3(sin(face), 0, cos(face)) * float(cfg["lunge"])
			if t > float(cfg["wind"]) * 1.0:
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
			if t > 3.0:
				position.y -= dt * 0.6
			if t > 5.0:
				queue_free()
			return
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face

func _strike(dist: float, dir: Vector3) -> void:
	if cfg.has("ranged"):
		game.main.sfx("sfx_cast", -6.0)
		game.spawn_bolt(global_position + Vector3(0, 1.3, 0) + dir * 0.6, dir, float(cfg["dmg"]), self)
		return
	game.main.sfx("sfx_slash" if kind == "clipper" else "sfx_swing", -6.0)
	var reach: float = float(cfg["range"]) + (1.2 if cfg.has("lunge") else 0.3)
	if dist < reach and Vector3(sin(face), 0, cos(face)).angle_to(dir) < 1.1:
		game.player.take_damage(float(cfg["dmg"]), global_position, self)

func stun(sec: float) -> void:
	if state == "dead" or state == "spawn":
		return
	state = "stun"
	t = 0.0
	stun_t = sec
	ring.visible = false
	rig.play_for("Hit", 0.5, 0.06)
	_update_bar()

func take_hit(dmg: float, dir: Vector3, knock: float, heavy := false) -> void:
	if not alive():
		return
	hp -= dmg
	kb = dir * knock
	ring.visible = false
	game.popup(global_position + Vector3(0, float(cfg["height"]) + 0.2, 0), str(int(dmg)), Color(1, 0.9, 0.4) if heavy else Color.WHITE)
	if hp <= 0.0:
		_die(dir, heavy)
		return
	if state != "stun":
		state = "hurt"
		t = 0.0
		rig.play_for("Hit", 0.4, 0.05)
	_update_bar()

func _die(dir: Vector3, heavy: bool) -> void:
	state = "dead"
	t = 0.0
	hp_bar.visible = false
	kb = dir * (9.0 if heavy else 5.0)
	# падает от удара: спиной, если удар пришёл спереди
	var front := Vector3(sin(face), 0, cos(face)).dot(-dir) > 0.0
	rig.play_for("DeathA" if front else "DeathB", 0.9, 0.06)
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true
	game.main.sfx("sfx_death", -4.0)
	game.on_kill(self)
