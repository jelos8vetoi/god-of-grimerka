## ТЯГА-812 (этап 07): пылесос Пахана и его три режима. Узел живёт в player.body (поворачивается вместе с героем),
## player.gd в состоянии "tyaga" каждый физический кадр зовёт tick(): здесь решается скорость, поворот, клип и всё,
## что пылесос делает с врагами. Числа — в style_tyaga.gd, точки модели и клипы — в clips_tyaga.gd.
##
##   на ногах (hold): WASD — шаг с пылесосом, ЛКМ держать — ПРИТЯГИВАНИЕ, ПКМ — ВЫБРОС (держать — заряд по области),
##                    E — сесть, пробел — перекат как обычно
##   верхом (ride):   WASD — куда ехать, Ctrl — ускорение, Shift — занос (держать; назад в заносе — разворот на месте),
##                    пробел — прыжок, ЛКМ — удар с разворота, ПКМ — воздушный выстрел, E — сойти; на скорости — таран
##   нагрев: притягивание, выброс и ускорение греют; 100 — перегрев, 2,5 с ничего не работает
class_name Tyaga
extends Node3D

const MODEL := "res://assets/models/tyaga812.glb"

var p
var game
var style: StyleData
var unit: Node3D              # модель; её положение относительно героя — v
var rock: Node3D              # «живой» корпус: дрожь мотора, покачивание на ходу, отдача, приседание (между unit и моделью)
var rock_t := 0.0
var kick := 0.0               # отдача от выстрела воздухом: гаснет сама
var squash := 0.0             # приседание корпуса: >0 — сплющен (приземление, удар), <0 — вытянут (прыжок)
var rock_seen := 0            # сколько событий пылесоса уже отыграно
var rock_amp := 0.0           # для проверок: насколько корпус сейчас отклонён от покоя, м
var v := TyagaClips.V_AWAY
var mode := "off"             # off, in, hold, suck, charge, blast, mount, ride, dismount, out
var mt := 0.0
var heat := 0.0
var lock := 0.0               # перегрев: сколько ещё секунд не работает
var charge_t := 0.0
var tick_t := 0.0
var caught := {}              # id врага → true: стоит у сопла
var pulling: Array = []       # кого тянет сейчас (для проверок)
var speed := 0.0
var heading := 0.0
var vdir := Vector3.FORWARD   # куда на самом деле едет (в заносе отстаёт от носа)
var flip_t := 0.0
var flip_from := 0.0
var spin_t := -1.0
var spin_hit := false
var spin_cd := 0.0
var ram_cd := {}
var air := false
var lean := 0.0
var puff := 0.0
var hum: AudioStreamPlayer
var events: Array = []        # что произошло (для проверок): ["shot", n], ["ram", враг]…
var msg_t := -9.0
var hold_t := 0.0             # сколько держат ПКМ (короткое нажатие с пойманным врагом — бросок)
var thrown: Array = []        # брошенные враги: [{e, t, hit: {id: true}}]

func setup(player, g) -> void:
	p = player
	game = g
	style = Styles.by_id("tyaga812")
	unit = Node3D.new()
	add_child(unit)
	rock = Node3D.new()
	unit.add_child(rock)
	var m: Node3D = (load(MODEL) as PackedScene).instantiate()
	m.rotation.y = PI * 0.5                    # щётка вперёд
	m.scale = Vector3.ONE * TyagaClips.K
	rock.add_child(m)
	unit.visible = false
	hum = AudioStreamPlayer.new()
	hum.stream = _synth_hum()
	hum.bus = "SFX"
	hum.volume_db = -80.0
	add_child(hum)

func riding() -> bool:
	return mode in ["ride", "mount", "dismount"]

func nozzle() -> Vector3:
	return unit.global_transform * TyagaClips.NOZZLE

func fwd() -> Vector3:
	return Vector3(sin(p.face), 0, cos(p.face))

func ready_to_work() -> bool:
	return lock <= 0.0

func _heat(add: float) -> void:
	heat += add
	if heat >= float(StyleTyaga.HEAT["max"]):
		heat = float(StyleTyaga.HEAT["max"])
		lock = float(StyleTyaga.HEAT["lock"])
		game.popup(p.global_position + Vector3(0, 2.3, 0), "ПЕРЕГРЕВ", Color(1.0, 0.5, 0.2))
		game.main.sfx("sfx_crack", -4.0, 0.7)
		events.append(["overheat", 0])

# ---------------- вход и выход из стиля ----------------
## стиль выбран: пылесос выкатывается из-за спины к герою
func enter() -> void:
	mode = "in"
	mt = 0.0
	v = TyagaClips.V_AWAY
	unit.visible = true
	unit.position = v
	if not hum.playing and game.main.testing() == "":
		hum.play()

## стиль меняется: пылесос откатывается и исчезает
func leave() -> void:
	if riding():
		_to_hold()
	mode = "out"
	mt = 0.0
	_clear_ride()

func _to_hold() -> void:
	mode = "hold"
	mt = 0.0
	_clear_ride()

func _clear_ride() -> void:
	speed = 0.0
	spin_t = -1.0
	p.spin_off = 0.0
	p.body.rotation.z = 0.0
	p.body.rotation.x = 0.0
	lean = 0.0
	caught = {}
	pulling = []

## Корпус пылесоса живёт: мотор мелко трясёт его (сильнее при работе и перегреве), на ходу он переваливается
## с колеса на колесо и подпрыгивает, при выстреле воздухом — отдача назад, при прыжке вытягивается, при
## приземлении и таране приседает. Всё — небольшие смещения узла rock: руки героя держат трубу в прежней точке.
func _process(dt: float) -> void:
	if unit == null or not unit.visible:
		return
	rock_t += dt
	# события пылесоса → отдача и приседание
	if rock_seen > events.size():
		rock_seen = 0
	while rock_seen < events.size():
		var ev: Array = events[rock_seen]
		rock_seen += 1
		match String(ev[0]):
			"shot", "throw", "bolt":
				kick = 1.0
			"burst":
				kick = 1.6
			"land", "bump", "ram", "bowl", "flip":
				squash = 1.0
			"jump":
				squash = -0.8
			"overheat":
				squash = 0.6
	kick = move_toward(kick, 0.0, dt * 5.0)
	squash = lerpf(squash, 0.0, 1.0 - exp(-9.0 * dt))
	# мощность мотора: на холостом еле заметна, при работе и перегреве — сильная
	var power := 0.0
	match mode:
		"hold", "in":
			power = 0.25
		"suck":
			power = 1.0
		"charge":
			power = 0.6 + 0.6 * clampf(charge_t / 1.0, 0.0, 1.0)
		"blast":
			power = 0.8
		"ride", "mount", "dismount":
			power = 0.35 + 0.5 * clampf(speed / 12.0, 0.0, 1.0)
	if lock > 0.0:
		power = 1.3
	var hs: float = Vector2(p.velocity.x, p.velocity.z).length()
	var roll_k: float = clampf(hs / 6.0, 0.0, 1.0)
	var step: float = rock_t * (7.0 + hs * 1.2)
	# дрожь мотора — три несовпадающие частоты, без случайного шума
	var jx: float = sin(rock_t * 61.0) * 0.004 * power
	var jz: float = sin(rock_t * 53.0 + 1.3) * 0.003 * power
	var jy: float = abs(sin(rock_t * 47.0 + 0.7)) * 0.004 * power
	# на ходу: с колеса на колесо и вверх-вниз
	var roll: float = sin(step) * 0.05 * roll_k + sin(rock_t * 71.0) * 0.006 * power
	var bob: float = abs(sin(step)) * 0.014 * roll_k
	# работа: при втягивании нос клюёт вперёд, при выстреле корпус отбрасывает назад и задирает
	var pitch: float = (0.07 if mode == "suck" else 0.0) + sin(rock_t * 9.0) * 0.012 * power - 0.2 * kick
	rock.position = Vector3(jx, jy + bob, jz - 0.1 * kick)
	rock.rotation = Vector3(pitch, 0.0, roll)
	var breathe: float = 1.0 + sin(rock_t * 9.0) * 0.012 * power
	rock.scale = Vector3(breathe * (1.0 + 0.1 * squash), breathe * (1.0 - 0.16 * squash), breathe * (1.0 + 0.1 * squash))
	rock_amp = rock.position.length() + abs(roll) * 0.3 + abs(pitch) * 0.3

## героя ударили: с пылесоса сбивает, заряд и притягивание обрываются
func on_hurt() -> void:
	if mode in ["off", "out", "in"]:
		return
	if riding():
		v = TyagaClips.V_RIDE
	_to_hold()

# ---------------- кадр ----------------
func idle_tick(dt: float) -> void:
	_thrown_tick(dt)
	# стиль не выбран или герой занят (перекат, урон): пылесос только докатывается на место и остывает
	_cool(dt)
	if mode == "out":
		mt += dt
		v = v.lerp(TyagaClips.V_AWAY, 1.0 - exp(-9.0 * dt))
		if mt > 0.35:
			mode = "off"
			unit.visible = false
	elif mode != "off":
		v = v.lerp(TyagaClips.V_HOLD, 1.0 - exp(-10.0 * dt))
	unit.position = v
	_hum(0.0)

func _cool(dt: float) -> void:
	lock = max(0.0, lock - dt)
	heat = max(0.0, heat - float(StyleTyaga.HEAT["cool"]) * dt)
	spin_cd = max(0.0, spin_cd - dt)
	for id in ram_cd.keys():
		ram_cd[id] = float(ram_cd[id]) - dt
		if float(ram_cd[id]) <= 0.0:
			ram_cd.erase(id)
	if lock > 0.0:
		puff -= dt
		if puff <= 0.0:
			puff = 0.12
			game.fx.dust(unit.global_transform * TyagaClips.SEAT, 2, Color(0.25, 0.25, 0.28, 0.6), 0.5, 0.0)

## состояние "tyaga" героя: dir — ввод движения в мире
func tick(dt: float, dir: Vector3) -> void:
	mt += dt
	_thrown_tick(dt)
	var heat0 := heat
	match mode:
		"off", "out":
			enter()
		"in":
			v = v.lerp(TyagaClips.V_HOLD, 1.0 - exp(-12.0 * dt))
			_foot(dt, dir, 0.6)
			if mt > 0.35:
				v = TyagaClips.V_HOLD
				mode = "hold"
				game.fx.dust(unit.global_position, 5, game.fx.DUST, 0.6)
		"hold":
			v = v.lerp(TyagaClips.V_HOLD, 1.0 - exp(-14.0 * dt))
			_foot(dt, dir, 1.0)
			if p.pressed("roll"):
				p.start_roll(dir)
			elif p.pressed("heat"):
				if not p.execution.try_start():      # рядом враг, которого можно добить, — добивание, иначе сесть верхом
					_mount()
			elif p.held("attack") and ready_to_work():
				mode = "suck"
				mt = 0.0
				tick_t = 0.0
				game.main.sfx("sfx_charge", -8.0, 0.7)
			elif p.pressed("heavy") and ready_to_work():
				mode = "charge"
				mt = 0.0
				charge_t = 0.0
				hold_t = 0.0
			elif (p.held("attack") or p.pressed("heavy")) and not ready_to_work():
				_say("перегрев — остывает")
		"suck":
			_suck(dt, dir)
		"charge":
			_charge(dt, dir)
		"blast":
			p.velocity.x = move_toward(p.velocity.x, 0.0, 16.0 * dt)
			p.velocity.z = move_toward(p.velocity.z, 0.0, 16.0 * dt)
			if mt > 0.42:
				mode = "hold"
		"mount":
			var k: float = clampf(mt / float(StyleTyaga.RIDE["mount"]), 0.0, 1.0)
			v = TyagaClips.V_HOLD.lerp(TyagaClips.V_RIDE, k)       # пылесос подкатывается под героя, пока тот прыгает на него
			p.velocity.x = move_toward(p.velocity.x, 0.0, 30.0 * dt)
			p.velocity.z = move_toward(p.velocity.z, 0.0, 30.0 * dt)
			if k >= 1.0:
				mode = "ride"
				mt = 0.0
				heading = p.face
				vdir = fwd()
				speed = 0.0
				p.rig.play("RideSit", 0.1)
				game.fx.dust(p.global_position + Vector3(0, 0.1, 0), 5, game.fx.DUST, 0.6)
		"ride":
			_ride(dt, dir)
		"dismount":
			var k2: float = clampf(mt / float(StyleTyaga.RIDE["dismount"]), 0.0, 1.0)
			v = TyagaClips.V_RIDE.lerp(TyagaClips.V_HOLD, k2)
			p.velocity.x = move_toward(p.velocity.x, 0.0, 30.0 * dt)
			p.velocity.z = move_toward(p.velocity.z, 0.0, 30.0 * dt)
			if k2 >= 1.0:
				_to_hold()
	if heat <= heat0:
		_cool(dt)
	else:
		lock = max(0.0, lock - dt)
		spin_cd = max(0.0, spin_cd - dt)
	unit.position = v
	_hum(1.0 if mode == "suck" else (0.75 if mode == "ride" and speed > 1.0 else (0.9 if mode == "charge" else 0.25)))

func _say(text: String) -> void:
	if game.clock - msg_t > 1.5:
		msg_t = game.clock
		game.popup(p.global_position + Vector3(0, 2.2, 0), text, Color(0.8, 0.9, 1.0))

## на ногах: шаг с пылесосом
func _foot(dt: float, dir: Vector3, k: float) -> void:
	var spd: float = float(StyleTyaga.RIDE["walk"]) * k
	p.velocity.x = dir.x * spd
	p.velocity.z = dir.z * spd
	if dir.length() > 0.1:
		p.face = lerp_angle(p.face, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * dt))
		p.rig.play("TyagaWalk", 0.2, clampf(spd * dir.length() / 2.6, 0.5, 1.8))
	else:
		p.rig.play("TyagaHold", 0.25)

func _mount() -> void:
	mode = "mount"
	mt = 0.0
	p.rig.play_for("RideMount", float(StyleTyaga.RIDE["mount"]), 0.06)
	game.main.sfx("sfx_roll", -8.0, 1.2)

# ---------------- MODE 2: притягивание ----------------
func _suck(dt: float, dir: Vector3) -> void:
	var a: AttackData = style.attack("tg_suck")
	var ex: Dictionary = a.extra
	var spd: float = ex["move"]
	p.velocity.x = dir.x * spd
	p.velocity.z = dir.z * spd
	var aim: Vector3 = p.aim_dir()
	p.face = lerp_angle(p.face, atan2(aim.x, aim.z), 1.0 - exp(-5.0 * dt))      # поток идёт туда, куда смотрит камера
	p.rig.play("TyagaSuck", 0.12)
	_heat(float(ex["heat"]) * dt)
	var n := nozzle()
	var f := fwd()
	# кандидаты: в конусе потока, по дистанции; тянем не больше max; тяжёлых и боссов поток не берёт
	var list := []
	var heavy_seen := false
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - n
		d.y = 0
		var dist := d.length()
		if dist > a.reach or (dist > 0.6 and f.angle_to(d / dist) > a.arc * 0.5):
			continue
		if e.boss_id != "" or float(e.height) > float(ex["max_height"]):
			heavy_seen = true
			e.slow(0.4, 0.85)                  # тяжёлого поток только придерживает
			continue
		list.append([dist, e])
	list.sort_custom(func(x, y): return x[0] < y[0])
	if list.size() > int(ex["max"]):
		list.resize(int(ex["max"]))
	if heavy_seen and list.is_empty():
		_say("слишком тяжёлый")
	pulling = []
	var now := {}
	tick_t -= dt
	var do_tick := tick_t <= 0.0
	if do_tick:
		tick_t = float(ex["tick"])
	for it in list:
		var e = it[1]
		var dist: float = it[0]
		pulling.append(e)
		e.interrupt_weak()
		var to: Vector3 = n - e.global_position
		to.y = 0
		if dist > float(ex["catch"]):
			# постепенно: чем ближе к соплу, тем сильнее тянет
			e.kb = to.normalized() * lerpf(float(ex["pull_near"]), float(ex["pull_far"]), clampf(dist / a.reach, 0.0, 1.0))
		else:
			now[e.get_instance_id()] = true
			e.kb = Vector3.ZERO
			if float(e.hp) <= float(e.max_hp) * float(ex["swallow"]):
				# ослабленного затягивает целиком
				var at: Vector3 = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
				game.fx.twirl(at, 2.2, style.color, 0.4)
				game.fx.sparks(at, (n - at).normalized(), 14, style.color, 1.2, 30.0)
				game.popup(at + Vector3(0, 0.8, 0), "ВСОСАЛ", Color(0.8, 0.95, 1.0))
				game.main.sfx("sfx_wave", -6.0, 1.6)
				e.take_hit(99999.0, to.normalized() if to.length() > 0.01 else -f, 0.0, true)
				p.swag = min(100.0, p.swag + 8.0)
				_heat(8.0)
				now.erase(e.get_instance_id())
				events.append(["swallow", e])
				continue
			if do_tick:
				var h := HitInfo.new()
				h.damage = p.combat.damage_for(a, e)
				h.stagger = a.stagger
				h.dir = -to.normalized() if to.length() > 0.01 else f
				h.attack_id = a.id
				h.style_id = style.id
				h.source = p
				h.pos = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
				e.take_hit_info(h)
				if is_instance_valid(e) and e.alive():
					e.stun(float(ex["hold_stun"]))
				game.fx.sparks(h.pos, to.normalized(), 4, style.color, 0.5)
	caught = now
	# вражеские снаряды поток тоже забирает
	for b in game.bolts:
		var bn: Node3D = b["n"]
		var bd: Vector3 = bn.global_position - n
		if bd.length() < a.reach and f.angle_to(Vector3(bd.x, 0, bd.z).normalized()) < a.arc * 0.5:
			b["v"] = (b["v"] as Vector3).lerp(-bd.normalized() * 9.0, 1.0 - exp(-6.0 * dt))
			b["homing"] = false
			if bd.length() < 0.9:
				b["life"] = 0.0
				events.append(["bolt", 0])
	# поток виден: пылинки летят к соплу
	puff -= dt
	if puff <= 0.0:
		puff = 0.05
		var far := n + f * randf_range(2.5, a.reach) + Vector3(randf_range(-1.2, 1.2), randf_range(0.2, 1.4), randf_range(-1.2, 1.2))
		game.fx.sparks(far, (n - far).normalized(), 2, Color(0.8, 0.95, 1.0), 1.4, 6.0)
		game.fx.dust(n + f * 0.5, 1, Color(0.8, 0.9, 1.0, 0.3), 0.4, 0.0)
	game.rumble(0.08)
	if not p.held("attack") or not ready_to_work():
		mode = "hold"
		pulling = []
	elif p.pressed("heavy") and ready_to_work():
		# притянул — и сразу выброс: заряд начинается с половины
		mode = "charge"
		mt = 0.0
		hold_t = 0.0
		charge_t = float(style.attack("tg_burst").extra["charge"]) * 0.5

# ---------------- MODE 3: выброс ----------------
func _charge(dt: float, dir: Vector3) -> void:
	charge_t += dt
	hold_t += dt
	p.velocity.x = move_toward(p.velocity.x, 0.0, 30.0 * dt)
	p.velocity.z = move_toward(p.velocity.z, 0.0, 30.0 * dt)
	var aim: Vector3 = dir if dir.length() > 0.3 else p.aim_dir()
	p.face = lerp_angle(p.face, atan2(aim.x, aim.z), 1.0 - exp(-7.0 * dt))
	p.rig.play("TyagaCharge", 0.1)
	var need: float = style.attack("tg_burst").extra["charge"]
	if charge_t > 0.12:
		game.rumble(0.1 + 0.15 * clampf(charge_t / need, 0.0, 1.0))
		game.charge_zoom = clampf(charge_t / need, 0.0, 1.0) * 0.5
	# пойманных держим у сопла, пока копится заряд
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and caught.has(e.get_instance_id()):
			e.stun(0.3)
	if not p.held("heavy"):
		if hold_t <= float(style.attack("tg_throw").extra["tap"]) and not caught.is_empty():
			_throw()                         # короткое нажатие с пойманным у сопла — бросок
		else:
			_blast(charge_t >= need)

func _blast(big: bool) -> void:
	var a: AttackData = style.attack("tg_burst" if big else "tg_shot")
	var n := nozzle()
	var f := fwd()
	var hits := 0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - (n if big else p.global_position)
		d.y = 0
		var dist := d.length()
		if dist > a.reach + float(e.radius):
			continue
		if not big and dist > 0.8 and f.angle_to(d / dist) > a.arc * 0.5:
			continue
		var dn: Vector3 = d.normalized() if dist > 0.05 else f
		if big and dist < 1.6:
			dn = (dn + f * 1.5).normalized()        # те, кто у самого сопла, улетают вперёд
		var h := HitInfo.new()
		h.damage = p.combat.damage_for(a, e) * (float(a.extra.get("caught_mul", 1.0)) if caught.has(e.get_instance_id()) else 1.0)
		h.stagger = a.stagger
		h.dir = dn
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
		game.fx.hit(h.pos, dn, 1 if big else 0, style.color)
		hits += 1
	# вражеские снаряды сдувает
	for b in game.bolts:
		if ((b["n"] as Node3D).global_position - n).length() < a.reach:
			b["life"] = 0.0
	caught = {}
	pulling = []
	# видно и слышно: вспышка у сопла, кольца, пыль по земле, отдача
	var fx = game.fx
	fx.muzzle(n + Vector3(0, 0.2, 0), style.color)
	if big:
		fx.ground_ring(Vector3(n.x, p.global_position.y + 0.05, n.z), 0.5, a.reach * 1.9, Color(0.8, 0.95, 1.0, 0.7), 0.4)
		fx.ground_ring(Vector3(n.x, p.global_position.y + 0.05, n.z), 0.3, a.reach * 1.2, Color(1, 1, 1, 0.5), 0.3)
		fx.dust(n, 16, game.fx.DUST, 1.4)
		game.main.sfx("sfx_boom", -2.0, 1.25)
		game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(0.8, 0.95, 1.0))
	else:
		for i in 4:
			fx.ring(n + f * (0.8 + i * 1.4) + Vector3(0, 0.7, 0), 1.0 + i * 0.5, Color(0.8, 0.95, 1.0, 0.6 - i * 0.1), 0.2 + i * 0.04)
		fx.dust(n + f * 1.0, 6, game.fx.DUST, 0.9)
	game.main.sfx("sfx_wave", -3.0, 1.3 if not big else 0.9)
	game.feedback(a.feedback, n + f * 1.2 + Vector3(0, 0.6, 0), f, 1.0, style.color)
	game.charge_zoom = 0.0
	_heat(float(a.extra["heat"]))
	events.append(["burst" if big else "shot", hits])
	if riding():
		speed = max(0.0, speed - 3.0)          # верхом отдача гасит скорость
		return
	p.velocity = -f * float(a.extra["recoil"])
	p.rig.play_for("TyagaBlast", a.duration, 0.05)
	mode = "blast"
	mt = 0.0

## Бросок пойманного: враг у сопла вылетает вперёд и по пути сбивает других.
func _throw() -> void:
	var a: AttackData = style.attack("tg_throw")
	var n := nozzle()
	var f := fwd()
	var best = null
	var bd := 1e9
	for e in game.enemies:
		if is_instance_valid(e) and e.alive() and caught.has(e.get_instance_id()) and e.global_position.distance_to(n) < bd:
			bd = e.global_position.distance_to(n)
			best = e
	caught = {}
	pulling = []
	if best == null:
		_blast(false)
		return
	var h := HitInfo.new()
	h.damage = p.combat.damage_for(a, best)
	h.stagger = a.stagger
	h.dir = f
	h.knockback = a.knockback
	h.launch = a.launch
	h.power = a.power
	h.attack_id = a.id
	h.style_id = style.id
	h.source = p
	h.pos = best.global_position + Vector3(0, float(best.height) * 0.5, 0)
	best.take_hit_info(h)
	thrown.append({"e": best, "t": float(a.extra["fly"]), "hit": {}})
	game.fx.muzzle(n + Vector3(0, 0.3, 0), style.color)
	game.main.sfx("sfx_wave", -3.0, 1.5)
	game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(0.8, 0.95, 1.0))
	game.feedback(a.feedback, h.pos, f, 1.0, style.color)
	_heat(float(a.extra["heat"]))
	events.append(["throw", best])
	p.velocity = -f * 3.0
	p.rig.play_for("TyagaBlast", a.duration, 0.05)
	mode = "blast"
	mt = 0.0

## брошенный враг летит: кого заденет — тому урон и отброс (каждому один раз)
func _thrown_tick(dt: float) -> void:
	if thrown.is_empty():
		return
	var a: AttackData = style.attack("tg_bowl")
	for i in range(thrown.size() - 1, -1, -1):
		var th: Dictionary = thrown[i]
		th["t"] = float(th["t"]) - dt
		var body = th["e"]
		if float(th["t"]) <= 0.0 or not is_instance_valid(body):
			thrown.remove_at(i)
			continue
		for e in game.enemies:
			if not is_instance_valid(e) or e == body or not e.alive() or (th["hit"] as Dictionary).has(e.get_instance_id()):
				continue
			var d: Vector3 = e.global_position - body.global_position
			d.y = 0
			if d.length() > a.reach + float(e.radius):
				continue
			(th["hit"] as Dictionary)[e.get_instance_id()] = true
			var h := HitInfo.new()
			h.damage = p.combat.damage_for(a, e)
			h.stagger = a.stagger
			h.dir = d.normalized() if d.length() > 0.05 else fwd()
			h.knockback = a.knockback
			h.launch = a.launch
			h.power = a.power
			h.attack_id = a.id
			h.style_id = style.id
			h.source = p
			h.pos = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
			e.interrupt_weak()
			e.take_hit_info(h)
			game.fx.hit(h.pos, h.dir, 1, style.color)
			game.main.sfx("sfx_hit_heavy", -2.0, 1.2)
			game.feedback(a.feedback, h.pos, h.dir, 1.0, style.color)
			events.append(["bowl", e])

# ---------------- MODE 1: езда ----------------
func _ride(dt: float, dir: Vector3) -> void:
	var R: Dictionary = StyleTyaga.RIDE
	var grounded: bool = p.is_on_floor()
	var want := dir.length() > 0.2
	var drift: bool = p.held("roll") and grounded and speed > 2.5
	var boost: bool = p.held("sprint") and want and ready_to_work()
	# столкновение со стеной: тело не проехало, сколько должно было
	var real := Vector2(p.get_real_velocity().x, p.get_real_velocity().z).length()
	if speed > 6.0 and real < speed * 0.35 and mt > 0.2:
		speed *= 0.25
		game.shake(0.3)
		game.main.sfx("sfx_thud", -4.0, 0.9)
		game.fx.dust(p.global_position + fwd() * 0.6 + Vector3(0, 0.3, 0), 6, game.fx.DUST, 0.8)
		events.append(["bump", 0])
	var turn := 0.0
	if flip_t > 0.0:
		# разворот на месте: нос проходит пол-оборота за flip секунд
		flip_t = max(0.0, flip_t - dt)
		var kf: float = 1.0 - flip_t / float(R["flip"])
		heading = flip_from + PI * smoothstep(0.0, 1.0, kf)
		turn = 9.0
		speed = move_toward(speed, 2.0, 30.0 * dt)
	elif want:
		var target := atan2(dir.x, dir.z)
		var off := angle_difference(heading, target)
		if abs(off) > 2.4 and speed > 3.0 and grounded:
			if drift:
				flip_t = float(R["flip"])                 # занос + назад: разворот
				flip_from = heading
				game.main.sfx("sfx_scrape", -6.0, 1.3)
				events.append(["flip", 0])
			else:
				speed = move_toward(speed, 0.0, float(R["brake"]) * dt)   # назад без заноса — тормоз
		else:
			var rate: float = float(R["steer_drift"] if drift else R["steer"]) * (clampf(speed / 3.0, 0.45, 1.0) if grounded else 0.35)
			var h0 := heading
			heading = rotate_toward(heading, target, rate * dt)
			turn = angle_difference(h0, heading) / max(dt, 0.0001)
			speed = move_toward(speed, float(R["vboost"] if boost else R["vmax"]), float(R["accel"]) * (1.4 if boost else 1.0) * dt)
	else:
		speed = move_toward(speed, 0.0, float(R["coast"]) * dt)
	if boost:
		_heat(float(R["boost_heat"]) * dt)
	# куда едет на самом деле: в заносе сцепление слабое, тело несёт боком
	var hd := Vector3(sin(heading), 0, cos(heading))
	var grip: float = R["grip_drift"] if drift else R["grip"]
	vdir = vdir.lerp(hd, 1.0 - exp(-grip * dt)).normalized() if grounded else vdir
	p.velocity.x = vdir.x * speed
	p.velocity.z = vdir.z * speed
	p.face = heading
	# прыжок
	if p.pressed("jump") and grounded:
		p.velocity.y = float(R["jump"])
		p.rig.play_for("RideJump", 0.75, 0.06)
		game.main.sfx("sfx_roll", -6.0, 1.4)
		events.append(["jump", 0])
		air = true
	elif air and grounded and p.velocity.y <= 0.1 and mt > 0.1:
		air = false
		game.feedback("land", p.global_position)
		events.append(["land", 0])
	# наклон в поворот и на разгоне: пылесос и герой кренятся вместе
	lean = lerpf(lean, clampf(-turn * 0.09 * clampf(speed / 8.0, 0.0, 1.0), -0.38, 0.38) * (1.6 if drift else 1.0), 1.0 - exp(-9.0 * dt))
	p.body.rotation.z = lean
	p.body.rotation.x = lerpf(p.body.rotation.x, -0.12 if air else (0.06 if boost else 0.0), 1.0 - exp(-8.0 * dt))
	# удар с разворота на ходу
	if spin_t >= 0.0:
		spin_t += dt
		var a: AttackData = style.attack("tg_spin")
		var ks: float = spin_t / a.duration
		p.spin_off = -TAU * smoothstep(0.0, 1.0, ks)
		if not spin_hit and ks >= float(a.hits[0]):
			spin_hit = true
			_area_hit(a, p.global_position, "spin")
		if ks >= 1.0:
			spin_t = -1.0
			p.spin_off = 0.0
	elif p.pressed("attack") and spin_cd <= 0.0:
		var a2: AttackData = style.attack("tg_spin")
		spin_t = 0.0
		spin_hit = false
		spin_cd = a2.cooldown
		p.rig.play_for("RideSpin", a2.duration, 0.05)
		game.main.sfx("sfx_swing_heavy", -3.0, 1.1)
		_heat(float(a2.extra["heat"]))
	elif p.pressed("heavy") and ready_to_work():
		_blast(false)
	# таран
	_ram()
	# клип и следы
	if spin_t < 0.0 and not air and (p.rig.cur != "RideJump" or not p.rig.player.is_playing()):
		p.rig.play("RideDrift" if drift else ("RideBoost" if boost else "RideSit"), 0.15)
	puff -= dt
	if grounded and puff <= 0.0 and (speed > 3.0 or drift):
		puff = 0.05 if drift else 0.11
		var back: Vector3 = p.global_position - hd * 0.5 + Vector3(0, 0.08, 0)
		game.fx.dust(back, 3 if drift else 1, game.fx.DUST, 0.7 if drift else 0.4)
		if drift:
			game.fx.sparks(back, Vector3.UP, 2, Color(1.0, 0.85, 0.5), 0.4, 50.0)
	game.fov_kick = max(float(game.fov_kick), speed * 0.28)
	if p.pressed("heat") and grounded and flip_t <= 0.0 and spin_t < 0.0:
		var leap: AttackData = style.attack("tg_leap")
		if speed >= float(leap.extra["min_speed"]):
			# соскок на ходу: удар вокруг и окно для удара с ходу в любом стиле
			_area_hit(leap, p.global_position, "leap")
			game.fx.dust(p.global_position + Vector3(0, 0.1, 0), 10, game.fx.DUST, 1.0)
			game.popup(p.global_position + Vector3(0, 2.4, 0), leap.title, Color(0.8, 0.95, 1.0))
			p.combat.open("dodge", 0.9)
		mode = "dismount"
		mt = 0.0
		speed = 0.0
		p.body.rotation.z = 0.0
		p.body.rotation.x = 0.0
		p.rig.play_for("RideDismount", float(R["dismount"]), 0.06)

func _ram() -> void:
	var a: AttackData = style.attack("tg_ram")
	if speed < float(a.extra["min_speed"]):
		return
	var f := vdir
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive() or ram_cd.has(e.get_instance_id()):
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		if d.length() > a.reach + float(e.radius) or (d.length() > 0.3 and f.angle_to(d.normalized()) > a.arc * 0.5):
			continue
		ram_cd[e.get_instance_id()] = float(a.extra["cd"])
		var h := HitInfo.new()
		h.damage = (a.damage + speed * float(a.extra["per_speed"])) * p.combat.damage_for(a, e) / a.damage
		h.stagger = a.stagger
		h.dir = (f + d.normalized() * 0.4).normalized()
		h.knockback = speed * a.knockback
		var boosted: bool = speed >= float(a.extra["boost_speed"])
		h.launch = float(a.extra["boost_launch"]) if boosted else a.launch      # таран на ускорении подбрасывает выше
		h.power = a.power
		h.attack_id = a.id
		h.style_id = style.id
		h.source = p
		h.pos = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
		e.interrupt_weak()
		e.take_hit_info(h)
		if boosted:
			game.popup(p.global_position + Vector3(0, 2.4, 0), "ТАРАН", Color(0.8, 0.95, 1.0))
		game.fx.hit(h.pos, h.dir, 1, style.color)
		game.main.sfx("sfx_hit_heavy", -2.0, 1.1)
		game.feedback(a.feedback, h.pos, f, clampf(speed / 10.0, 0.6, 1.4), style.color)
		p.swag = min(100.0, p.swag + 5.0)
		speed *= float(a.extra["keep"]) if e.boss_id == "" else 0.3     # о босса пылесос почти останавливается
		events.append(["ram", e])

func _area_hit(a: AttackData, at: Vector3, tag: String) -> void:
	var hits := 0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - at
		d.y = 0
		if d.length() > a.reach + float(e.radius):
			continue
		var h := HitInfo.new()
		h.damage = p.combat.damage_for(a, e)
		h.stagger = a.stagger
		h.dir = d.normalized() if d.length() > 0.05 else fwd()
		h.knockback = a.knockback
		h.launch = a.launch
		h.heavy = a.heavy
		h.power = a.power
		h.attack_id = a.id
		h.style_id = style.id
		h.source = p
		h.pos = e.global_position + Vector3(0, float(e.height) * 0.55, 0)
		e.take_hit_info(h)
		game.fx.hit(h.pos, h.dir, 1, style.color)
		hits += 1
	if hits > 0:
		game.feedback(a.feedback, at + Vector3(0, 0.8, 0), fwd(), 1.0, style.color)
		game.main.sfx("sfx_hit_heavy", -1.0)
		if a.title != "":
			game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(0.8, 0.95, 1.0))
	events.append([tag, hits])

# ---------------- звук мотора ----------------
func _hum(level: float) -> void:
	if not hum.playing:
		return
	if mode == "off":
		level = 0.0
	hum.volume_db = lerpf(hum.volume_db, lerpf(-34.0, -13.0, level) if level > 0.0 else -80.0, 0.12)
	var pitch := 0.8 + 0.5 * level + (clampf(speed / 14.0, 0.0, 1.0) * 0.5 if mode == "ride" else 0.0) - (0.25 if lock > 0.0 else 0.0)
	hum.pitch_scale = lerpf(hum.pitch_scale, pitch, 0.15)

## гул мотора: пила с биением и шум, зацикленный (записи пылесоса в проекте нет)
func _synth_hum() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var rs := 777
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var noise := float(rs % 2000) / 1000.0 - 1.0
		lp += (noise - lp) * 0.35
		var saw := fmod(t * 110.0, 1.0) * 2.0 - 1.0
		var s := saw * 0.35 + sin(t * TAU * 220.0) * 0.2 + sin(t * TAU * 330.0) * 0.1 + lp * 0.5
		s *= 0.85 + 0.15 * sin(t * TAU * 8.0)
		data.encode_s16(i * 2, int(clampf(s * 0.7, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
