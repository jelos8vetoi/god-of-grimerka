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
	var turn := 0.0
	var d := target - global_position
	d.y = 0
	var spd := 8.5 if far > 4.5 else 4.6
	var acting := anim.state == "action" and anim.hold > 0.0   # брейк или приём: стоит на месте, тело ведёт root motion
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
	if hs > 0.3 or p.enemies_near(14.0) or anim.busy():
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
