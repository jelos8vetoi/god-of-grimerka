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
	rig.setup("res://assets/models/madk1d.glb", 1.68, Poses.madk1d())
	track = AudioStreamPlayer.new()
	track.stream = load("res://assets/audio/adlib_dynasty.wav")
	track.volume_db = -2.0
	track.bus = "SFX"
	add_child(track)

func _physics_process(dt: float) -> void:
	var p = game.player
	var pp: Vector3 = p.global_position
	cd = max(0.0, cd - dt)
	if game.paused_story() or game.over:      # разговор или гибель героя: стоит, не дерётся
		velocity = Vector3(0, velocity.y - 20.0 * dt, 0)
		rig.play("Idle", 0.3)
		move_and_slide()
		body.rotation.y = face
		return
	wait -= dt
	var far := global_position.distance_to(pp)
	if far > 14.0:
		global_position = pp + Vector3(sin(p.face + 1.4), 0, cos(p.face + 1.4)) * 1.8
		target = Vector3.ZERO
		far = 1.8
	var bad := target == Vector3.ZERO or target.distance_to(pp) > 4.6
	if wait <= 0.0 or bad or far > 5.5:
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
	var d := target - global_position
	d.y = 0
	var spd := 8.5 if far > 4.5 else 4.6
	if d.length() > 0.15 and say_t <= 0.0:
		var v: Vector3 = d.normalized() * min(spd, d.length() / dt)
		velocity.x = v.x
		velocity.z = v.z
		face = lerp_angle(face, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
		# далеко отстал — рывок, иначе бег
		if spd > 6.0:
			rig.play_role("sprint", 0.2, spd / 8.5)
		else:
			rig.play_role("run", 0.2, spd / 4.6)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		var aim2: Vector3 = p.aim_dir()
		face = lerp_angle(face, atan2(aim2.x, aim2.z), 1.0 - exp(-4.0 * dt))
		if say_t <= 0.0:
			# враги рядом — боксёрская стойка
			rig.play_role("combat_idle" if p.enemies_near(9.0) else "idle", 0.3)
	if say_t > 0.0:
		say_t -= dt
	velocity.y -= 20.0 * dt
	move_and_slide()
	body.rotation.y = face

func adlib() -> bool:
	if cd > 0.0:
		return false
	cd = cd_max
	say_t = 2.1
	rig.play_for("Cheer", 2.0, 0.08)
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
			e.take_hit(15.0, (e.global_position - global_position).normalized(), 5.0)
			if e.alive():
				e.stun(2.0)
	return true
