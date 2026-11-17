## Скейтборд madk1d: езда и трюки (стиль «skateboard»). Узел живёт в player.body; герой в состоянии "skate".
## Вход — зажать Ctrl на бегу: доска из руки ложится под ноги. Отпустил Ctrl на земле — доска снова в руке.
##   на доске:  WASD — куда ехать; Shift — слайд (низко и боком: сбивает тех, кого задел); пробел — олли;
##              ЛКМ — удар с разгона (сход в атаку); ПКМ — Board Spin: оборот на месте, бьёт вокруг
##   в воздухе: F — трюк (без направления — kickflip, влево — heelflip, вправо — shove-it, назад — 360 flip);
##              ЛКМ — удар в воздухе; ПКМ — пикирование и удар с приземления
## Трюк, докрученный до конца, даёт заряд (до трёх): каждый заряд +25 % к следующему удару доской, удар в воздухе
## с зарядом ещё и подвешивает — можно бить снова. Приземлился посреди трюка — падение: заряды сгорают, 0,85 с лежишь.
class_name Skate
extends Node3D

const MODEL := "res://assets/models/skateboard.glb"
const LEN := 0.94               # та же длина, что у доски в руке (0,56 роста madk1d)
const AIR_LIFT := 0.2          # на сколько доска поднимается за ногами в прыжке, м
const STANCE := -PI * 0.5      # поворот тела на доске: левый бок по ходу, ноги вдоль деки

var p
var game
var style: StyleData
var board: Node3D             # доска под ногами
var spinner: Node3D           # её вращение в трюках
var on := false
var speed := 0.0
var heading := 0.0
var vdir := Vector3.FORWARD
var air := false
var diving := false
var trick := ""               # идущий трюк
var trick_t := 0.0
var charges := 0
var bail_t := 0.0
var sliding := false
var slide_hit := {}
var spin_t := -1.0
var spin_done := false
var air_cd := 0.0
var puff := 0.0
var events: Array = []        # для проверок: ["trick", имя], ["bail", 0], ["land", n]…

func setup(player, g) -> void:
	p = player
	game = g
	style = Styles.by_id("skateboard")
	board = Node3D.new()
	add_child(board)
	spinner = Node3D.new()
	board.add_child(spinner)
	var m: Node3D = (load(MODEL) as PackedScene).instantiate()
	m.rotation.y = PI * 0.5                     # длинная ось — вперёд
	m.scale = Vector3.ONE * (LEN / 97.9)
	spinner.add_child(m)
	board.visible = false

func fwd() -> Vector3:
	return Vector3(sin(heading), 0, cos(heading))

## встать на доску (из бега)
func mount() -> void:
	on = true
	heading = p.face
	vdir = fwd()
	speed = max(Vector2(p.velocity.x, p.velocity.z).length(), 5.0)
	air = false
	diving = false
	trick = ""
	sliding = false
	spin_t = -1.0
	bail_t = 0.0
	board.visible = true
	p.show_weapon(false)
	p.rig.position.y = -0.9 + float(StyleSkateboard.RIDE["deck"])     # стопы на деке
	p.rig.rotation.y = STANCE
	p.rig.play("SkateRide", 0.1)
	p.state = "skate"
	game.main.sfx("sfx_roll", -8.0, 1.5)
	events.append(["mount", 0])

## сойти: доска возвращается в руку
func off(to_state := "move") -> void:
	if not on:
		return
	on = false
	board.visible = false
	spinner.rotation = Vector3.ZERO
	board.rotation = Vector3.ZERO
	p.show_weapon(true)
	p.rig.position.y = -0.9
	p.rig.rotation.y = 0.0
	p.spin_off = 0.0
	p.body.rotation.z = 0.0
	sliding = false
	trick = ""
	if p.state == "skate":
		p.state = to_state

func bonus() -> float:
	return 1.0 + float(StyleSkateboard.RIDE["charge_mul"]) * charges

func tick(dt: float, dir: Vector3) -> void:
	var R: Dictionary = StyleSkateboard.RIDE
	var grounded: bool = p.is_on_floor()
	air_cd = max(0.0, air_cd - dt)
	if bail_t > 0.0:
		# упал: лежит, доска откатилась
		bail_t -= dt
		p.velocity.x = move_toward(p.velocity.x, 0.0, 20.0 * dt)
		p.velocity.z = move_toward(p.velocity.z, 0.0, 20.0 * dt)
		if bail_t <= 0.0:
			off()
		return
	# ---- приземление ----
	if air and grounded and p.velocity.y <= 0.1:
		air = false
		if trick != "":
			_bail()
			return
		var n := 0
		if diving:
			n = _area(style.attack("sk_land"), p.global_position, bonus())
			game.fx.slam(p.global_position, 0.9, style.color)
			game.main.sfx("sfx_boom", -3.0, 1.3)
			charges = 0
		else:
			game.feedback("land", p.global_position)
		diving = false
		if charges > 0:
			p.combat.open("dodge", 0.9)          # после трюков — окно ответного удара
		events.append(["land", n])
	# ---- руление и скорость ----
	var want := dir.length() > 0.2
	sliding = p.held("roll") and grounded and speed > 3.0
	if want and (grounded or true):
		heading = rotate_toward(heading, atan2(dir.x, dir.z), float(R["steer_slide"] if sliding else R["steer"]) * (1.0 if grounded else 0.4) * dt)
	if sliding:
		speed = move_toward(speed, 0.0, float(R["slide_drag"]) * dt)
	elif want and grounded:
		speed = move_toward(speed, float(R["vmax"]), float(R["accel"]) * dt)
	elif grounded:
		speed = move_toward(speed, 0.0, float(R["coast"]) * dt)
	if grounded:
		vdir = vdir.lerp(fwd(), 1.0 - exp(-float(R["grip_slide"] if sliding else R["grip"]) * dt)).normalized()
	if not diving:
		p.velocity.x = vdir.x * speed
		p.velocity.z = vdir.z * speed
	p.face = heading
	# ---- слайд: кого задел — сбивает ----
	if sliding:
		for e in game.enemies:
			if is_instance_valid(e) and e.alive() and not slide_hit.has(e.get_instance_id()) and e.global_position.distance_to(p.global_position) < 1.2 + float(e.radius):
				slide_hit[e.get_instance_id()] = true
				_hit(style.attack("sk_slide"), e, vdir, bonus())
				events.append(["slide_hit", e])
	else:
		slide_hit = {}
	# ---- Board Spin на земле ----
	if spin_t >= 0.0:
		spin_t += dt
		var sa: AttackData = style.attack("sk_spin360")
		var ks: float = spin_t / sa.duration
		p.spin_off = -TAU * smoothstep(0.0, 1.0, ks)
		if not spin_done and ks >= 0.5:
			spin_done = true
			var hits := _area(sa, p.global_position, bonus())
			charges = 0 if hits > 0 else charges
		if ks >= 1.0:
			spin_t = -1.0
			p.spin_off = 0.0
			_gain("boardspin")
	# ---- ввод ----
	if grounded and not air:
		if p.pressed("jump"):
			p.velocity.y = float(R["ollie"])
			air = true
			p.inv = max(p.inv, 0.15)
			p.rig.play_for("SkateOllie", 0.7, 0.06)
			game.main.sfx("sfx_roll", -6.0, 1.7)
			events.append(["ollie", 0])
		elif p.pressed("attack") or (sliding and p.combat.buffered() == "light"):
			# сход в удар: с разгона — мах, из слайда — подсечка
			var a: AttackData = style.attack("sk_sweep" if sliding else "sk_dash")
			p.combat.clear_buffer()
			off("attack")
			p.combat.begin(a, true)
			return
		elif p.pressed("heavy") and spin_t < 0.0 and p.combat.ready_at(style.attack("sk_spin360")):
			spin_t = 0.0
			spin_done = false
			p.combat.cooldowns["sk_spin360"] = p.combat.clock + style.attack("sk_spin360").cooldown
			game.main.sfx("sfx_swing_heavy", -4.0, 1.3)
		elif not p.held("sprint") and spin_t < 0.0:
			off()
			return
	elif air:
		if trick != "":
			trick_t += dt
			var T: Dictionary = StyleSkateboard.TRICKS[trick]
			var kt: float = clampf(trick_t / float(T["t"]), 0.0, 1.0)
			spinner.rotation.z = TAU * float(T["roll"]) * kt
			spinner.rotation.y = TAU * float(T["yaw"]) * kt
			if kt >= 1.0:
				_gain(trick)
				trick = ""
				spinner.rotation = Vector3.ZERO
		elif p.pressed("throw") and not diving:
			# трюк по направлению ввода относительно движения
			var tn := "kickflip"
			if dir.length() > 0.3:
				var side := fwd().cross(dir.normalized()).y
				var along := fwd().dot(dir.normalized())
				tn = "flip360" if along < -0.5 else ("heelflip" if side > 0.3 else ("shoveit" if side < -0.3 else "kickflip"))
			trick = tn
			trick_t = 0.0
			p.rig.play_for("SkateTrick", float(StyleSkateboard.TRICKS[tn]["t"]), 0.05)
			game.main.sfx("sfx_swing", -6.0, 1.6)
		elif p.pressed("attack") and air_cd <= 0.0 and not diving:
			# удар в воздухе; с зарядом — подвешивает, можно бить ещё
			air_cd = 0.3
			p.rig.play_for("SkateAir", 0.3, 0.04)
			var had := charges
			var n2 := _area(style.attack("sk_air"), p.global_position + fwd() * 0.8, bonus(), true)
			if had > 0:
				p.velocity.y = max(p.velocity.y, 3.5)
				charges = 0 if n2 > 0 else charges
			events.append(["air", n2])
		elif p.pressed("heavy") and not diving:
			diving = true
			p.velocity = fwd() * 5.0 + Vector3(0, -16.0, 0)
			p.rig.play("SkateDive", 0.06)
			spinner.rotation.x = -0.5
	# ---- вид ----
	board.rotation.y = lerp_angle(board.rotation.y, PI * 0.5 if sliding else 0.0, 1.0 - exp(-14.0 * dt))
	# в воздухе доска идёт за поджатыми ногами, а не остаётся внизу
	board.position.y = lerpf(board.position.y, AIR_LIFT if air and not diving else 0.0, 1.0 - exp(-16.0 * dt))
	p.body.rotation.z = lerpf(p.body.rotation.z, 0.0, 1.0 - exp(-8.0 * dt))
	if grounded and not air and spin_t < 0.0:
		p.rig.play("SkateSlide" if sliding else "SkateRide", 0.12)
	puff -= dt
	if grounded and puff <= 0.0 and (sliding or speed > 4.0):
		puff = 0.05 if sliding else 0.14
		game.fx.dust(p.global_position - fwd() * 0.4 + Vector3(0, 0.06, 0), 3 if sliding else 1, game.fx.DUST, 0.6 if sliding else 0.35)
		if sliding:
			game.fx.sparks(p.global_position + Vector3(0, 0.06, 0), Vector3.UP, 2, Color(1.0, 0.85, 0.5), 0.35, 55.0)
	game.fov_kick = max(float(game.fov_kick), speed * 0.2)

func _gain(tn: String) -> void:
	var T: Dictionary = StyleSkateboard.TRICKS[tn]
	charges = mini(int(StyleSkateboard.RIDE["max_charges"]), charges + int(T["gain"]))
	p.swag = min(100.0, p.swag + 6.0 * int(T["gain"]))
	game.popup(p.global_position + Vector3(0, 2.3, 0), String(T["title"]), style.color_hot)
	game.fx.twinkle(p.global_position + Vector3(0, 0.6, 0), 6, style.color_hot, 0.7)
	events.append(["trick", tn])

## не докрутил трюк: падение
func _bail() -> void:
	trick = ""
	charges = 0
	diving = false
	speed = 0.0
	bail_t = float(StyleSkateboard.RIDE["bail"])
	spinner.rotation = Vector3(0.4, 1.1, 0.3)
	p.velocity = Vector3.ZERO
	p.rig.position.y = -0.9
	p.rig.rotation.y = 0.0
	p.rig.play_for("Knockdown", bail_t * 0.7, 0.05)
	game.popup(p.global_position + Vector3(0, 2.2, 0), "УПАЛ", Color(1.0, 0.45, 0.35))
	game.main.sfx("sfx_thud", -2.0, 1.0)
	game.shake(0.3)
	game.fx.dust(p.global_position + Vector3(0, 0.1, 0), 8, game.fx.DUST, 0.8)
	events.append(["bail", 0])

func _hit(a: AttackData, e, dir: Vector3, mul: float) -> void:
	var h := HitInfo.new()
	h.damage = p.combat.damage_for(a, e)        # заряды трюков уже учтены: ядро спрашивает player.damage_bonus
	h.stagger = a.stagger
	h.dir = dir
	h.knockback = a.knockback
	h.launch = a.launch
	h.heavy = a.heavy
	h.power = a.power
	h.attack_id = a.id
	h.style_id = style.id
	h.source = p
	h.pos = e.global_position + Vector3(0, float(e.height) * 0.55, 0)
	e.interrupt_weak()
	e.take_hit_info(h)
	game.fx.hit(h.pos, dir, a.power, style.color_hot if mul > 1.0 else style.color)
	game.main.sfx("sfx_hit_heavy" if a.power > 0 else "sfx_hit", -2.0, 1.25)
	game.feedback(a.feedback_event(), h.pos, dir, mul, style.color)
	p.swag = min(100.0, p.swag + 5.0)

func _area(a: AttackData, at: Vector3, mul: float, cone := false) -> int:
	var n := 0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - at
		var flat := Vector3(d.x, 0, d.z)
		if flat.length() > a.reach + float(e.radius) or abs(d.y) > 2.6:
			continue
		if cone and flat.length() > 0.6 and fwd().angle_to(flat.normalized()) > a.arc * 0.5:
			continue
		_hit(a, e, flat.normalized() if flat.length() > 0.05 else fwd(), mul)
		n += 1
	if n > 0 and a.title != "":
		game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, style.color_hot)
	return n
