## ТЯГА-812 (этап 07): пылесос Пахана и его три режима. Узел живёт в player.body (поворачивается вместе с героем),
## player.gd в состоянии "tyaga" каждый физический кадр зовёт tick(): здесь решается скорость, поворот, клип и всё,
## что пылесос делает с врагами. Числа — в style_tyaga.gd, точки модели и клипы — в clips_tyaga.gd.
##
##   на ногах (hold): WASD — шаг с пылесосом, ЛКМ держать — ПРИТЯГИВАНИЕ, ПКМ — ВЫБРОС (держать — заряд по области),
##                    E — сесть, пробел — перекат как обычно
##   верхом (ride):   WASD — куда ехать, Ctrl — ускорение, Shift — занос (держать; назад в заносе — разворот на месте),
##                    пробел — прыжок, ЛКМ — удар с разворота, ПКМ — воздушный выстрел, E — сойти; на скорости — таран
##   этап 3 — на ногах: F — ШИРОКИЙ выброс (с пойманным у сопла — КОЛЕНО); отпустить ПКМ с блоком — В ЗЕМЛЮ,
##            с прыжком — ВВЕРХ; короткий выброс по врагу у сопла — В УПОР;
##            верхом: назад — тормоз и задний ход, ЛКМ в заносе — ХЛЫСТ, ЛКМ в прыжке — ПРИЗЕМЛЕНИЕ,
##            таран в заносе — БОРТОМ, в прыжке — С НЕБА; связки режимов — StyleTyaga.LINKS
##   шланг: модель цельная, поэтому кости строятся здесь (_rig_hose): труба идёт за руками героя, шланг гнётся
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
var hum_frame := -9          # кадр, когда гул в последний раз получил уровень от пылесоса (_hum)
var events: Array = []        # что произошло (для проверок): ["shot", n], ["ram", враг]…
var msg_t := -9.0
var hold_t := 0.0             # сколько держат ПКМ (короткое нажатие с пойманным врагом — бросок)
var thrown: Array = []        # брошенные враги: [{e, t, hit: {id: true}}]
# этап 3
const HOSE_N := 5             # звеньев шланга: кость 0 — корпус, HOSE_N — труба со щёткой
var model: Node3D             # модель пылесоса (в её осях заданы кости)
var hskel: Skeleton3D         # кости, построенные в коде
var prig                      # риг Пахана: откуда брать руки
var wand_q := Quaternion.IDENTITY   # куда труба повёрнута относительно покоя
var wand_p := Vector3.ZERO          # и куда сдвинута, ед. модели
var w_hi := Vector3.ZERO      # точки трубы в осях модели
var w_lo := Vector3.ZERO
var w_mid := Vector3.ZERO
var w_c := Vector3.ZERO
var w_noz := Vector3.ZERO
var act := {}                 # приём на ногах: {kind, a, hit}
var clip_t := 0.0             # сколько ещё не трогать клип (идёт короткий клип приёма)
var link_from := ""           # последний приём: для связок
var link_t := 0.0
var rev := false              # задний ход
var braking := false
var kick_cd := 0.0
var dh_t := -1.0              # удар в заносе
var dh_hit := false
var slam := false             # падает камнем после ЛКМ в прыжке
var drifting := false
var side_k := 0.0             # на сколько радиан пылесос несёт боком

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
	model = m
	_rig_hose(m)
	rock.add_child(m)
	unit.visible = false
	prig = (p.heroes["pahan"] as Dictionary)["rig"] if p.heroes.has("pahan") else p.rig
	if hskel != null:
		(prig.skel as Skeleton3D).skeleton_updated.connect(_wand_update)
	hum = AudioStreamPlayer.new()
	hum.stream = _synth_hum()
	hum.bus = "SFX"
	hum.volume_db = -80.0
	add_child(hum)

# ---------------- кости шланга и трубы ----------------
## точка пылесоса (м, оси героя) → оси модели
static func to_model(pt: Vector3) -> Vector3:
	return Vector3(-pt.z, pt.y, pt.x) / TyagaClips.K

## Насколько вершина модели принадлежит трубе: 1 — труба и щётка, 0 — корпус, между — шланг (по высоте).
## Модель — один кусок, части различаются только положением: труба идёт наискось от щётки (x ≈ −49, y = 0)
## к ручке (x ≈ 17, y ≈ 94), шланг спускается от ручки сзади (x > 33) и по полу уходит в корпус (y < 38).
static func hose_w(vel: Vector3) -> float:
	if vel.y > 85.0:
		return 1.0
	var line: float = 0.70 * vel.y - 49.0
	var by_h: float = smoothstep(12.0, 85.0, vel.y)
	if vel.y <= 38.0:
		if vel.x < (-17.0 if vel.y < 14.0 else line + 12.0):
			return 1.0
		return by_h * smoothstep(30.0, 38.0, vel.x)
	if vel.x < line + 14.0:
		return 1.0
	return by_h

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null

## Кости в коде: каждой вершине — две соседние кости цепочки корпус → шланг → труба.
func _rig_hose(m: Node3D) -> void:
	var mi := _find_mesh(m)
	if mi == null or mi.mesh == null:
		return
	var src: Mesh = mi.mesh
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var ws := PackedFloat32Array()
		bones.resize(vs.size() * 4)
		ws.resize(vs.size() * 4)
		for i in vs.size():
			var u: float = hose_w(vs[i]) * float(HOSE_N)
			var b0: int = mini(int(u), HOSE_N - 1)
			var fr: float = u - float(b0)
			bones[i * 4] = b0
			bones[i * 4 + 1] = b0 + 1
			ws[i * 4] = 1.0 - fr
			ws[i * 4 + 1] = fr
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = ws
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	out.custom_aabb = src.get_aabb().grow(70.0)
	hskel = Skeleton3D.new()
	hskel.name = "HoseSkel"
	for k in HOSE_N + 1:
		hskel.add_bone("hose%d" % k)
	mi.get_parent().add_child(hskel)
	hskel.transform = mi.transform
	mi.mesh = out
	mi.skin = hskel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("../HoseSkel")
	w_hi = to_model(TyagaClips.TUBE_HI)
	w_lo = to_model(TyagaClips.TUBE_LO)
	w_mid = to_model(TyagaClips.TUBE_MID)
	w_c = (w_hi + w_lo) * 0.5
	w_noz = to_model(TyagaClips.NOZZLE)

## После каждого обновления скелета героя: труба встаёт туда, где её держат руки, шланг тянется между ней и корпусом.
## На ногах трубу задают обе руки (положение и наклон), верхом — правая (только сдвиг, труба как рычаг).
func _wand_update() -> void:
	if hskel == null or not unit.visible:
		return
	var sk: Skeleton3D = prig.skel
	var q := Quaternion.IDENTITY
	var xf := Vector3.ZERO
	if p.hero == "pahan" and p.state == "tyaga" and mode in ["hold", "suck", "charge", "blast", "act", "ride"]:
		var inv: Transform3D = model.global_transform.affine_inverse() * sk.global_transform
		var hr: Vector3 = inv * (sk.get_bone_global_pose(prig.bone["rhand"]) * ((prig.hand["r"] as Dictionary)["grip"] as Vector3))
		if mode == "ride":
			xf = (hr - w_mid).limit_length(14.0)
		else:
			var hl: Vector3 = inv * (sk.get_bone_global_pose(prig.bone["lhand"]) * ((prig.hand["l"] as Dictionary)["grip"] as Vector3))
			var d0: Vector3 = w_hi - w_lo
			var d1: Vector3 = hr - hl
			if abs(d1.length() - d0.length()) < d0.length() * 0.4:      # обе руки на трубе
				q = Quaternion(d0.normalized(), d1.normalized())
				var ang: float = q.get_angle()
				if ang > 1.5:
					q = Quaternion.IDENTITY.slerp(q, 1.5 / ang)
				xf = ((hr + hl) * 0.5 - w_c).limit_length(55.0)
	wand_q = wand_q.slerp(q, 0.5)
	wand_p = wand_p.lerp(xf, 0.5)
	for k in HOSE_N + 1:
		var t: float = float(k) / float(HOSE_N)
		var qt: Quaternion = Quaternion.IDENTITY.slerp(wand_q, t)
		hskel.set_bone_pose_rotation(k, qt)
		hskel.set_bone_pose_position(k, w_c + wand_p * t - qt * w_c)

## где сопло на самом деле (с учётом того, куда руки повернули трубу) — для эффектов
func nozzle_real() -> Vector3:
	if hskel == null:
		return nozzle()
	return model.global_transform * (wand_q * (w_noz - w_c) + w_c + wand_p)

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
	rev = false
	braking = false
	slam = false
	dh_t = -1.0
	act = {}

## Корпус пылесоса живёт: мотор мелко трясёт его (сильнее при работе и перегреве), на ходу он переваливается
## с колеса на колесо и подпрыгивает, при выстреле воздухом — отдача назад, при прыжке вытягивается, при
## приземлении и таране приседает. Всё — небольшие смещения узла rock: руки героя держат трубу в прежней точке.
func _process(dt: float) -> void:
	if hum != null and hum.playing and Engine.get_physics_frames() - hum_frame > 3:
		hum.volume_db = move_toward(hum.volume_db, -80.0, 160.0 * dt)
		if hum.volume_db <= -79.0:
			hum.stop()
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
			"shot_ride", "point", "wide", "up":
				kick = 1.0
			"ground", "slam":
				squash = 1.4
			"land", "bump", "ram", "bowl", "flip", "side", "airram", "brake":
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
		"blast", "act":
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
	link_t = max(0.0, link_t - dt)
	clip_t = 0.0
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
	link_t = max(0.0, link_t - dt)
	clip_t = max(0.0, clip_t - dt)
	kick_cd = max(0.0, kick_cd - dt)
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
			elif p.pressed("throw") and ready_to_work():
				_act("wide")
			elif p.held("attack") and ready_to_work():
				mode = "suck"
				game.measure_use(p.hero, style.id, "tg_suck")
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
		"act":
			var aa: AttackData = act["a"]
			p.velocity.x = move_toward(p.velocity.x, 0.0, 14.0 * dt)
			p.velocity.z = move_toward(p.velocity.z, 0.0, 14.0 * dt)
			for e in game.enemies:      # пойманных держим на месте до удара
				if not act["hit"] and is_instance_valid(e) and e.alive() and caught.has(e.get_instance_id()):
					e.stun(0.2)
			if not act["hit"] and mt >= a_time(aa):
				act["hit"] = true
				_act_hit()
			if mt >= aa.duration * 0.94:
				mode = "hold"
				act = {}
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
	_hum(1.0 if mode == "suck" else (0.75 if mode == "ride" and speed > 1.0 else (0.9 if mode == "charge" else (0.6 if mode in ["blast", "act"] else 0.0))))

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
	elif clip_t <= 0.0:
		p.rig.play("TyagaOverheat" if lock > 0.0 else "TyagaHold", 0.25)      # перегрелся — отмахивается от дыма

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
	if mt < 0.18:
		if p.rig.cur != "TyagaSuckIn":
			p.rig.play_for("TyagaSuckIn", 0.18, 0.05)      # переход: шаг вперёд и упор
	else:
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
				e.take_hit(99999.0, to.normalized() if to.length() > 0.01 else -f, 0.0, true, 0.0, null, "phantom_capture", "pahan")
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
				h.telemetry_hero = "pahan"
				h.source = p
				h.pos = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
				e.take_hit_info(h)
				if is_instance_valid(e) and e.alive():
					e.stun(float(ex["hold_stun"]))
				game.fx.sparks(h.pos, to.normalized(), 4, style.color, 0.5)
	caught = now
	if not caught.is_empty():
		_mark("tg_suck")
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
	if p.pressed("throw") and ready_to_work():
		_act("knee" if not caught.is_empty() else "wide")      # [F]: пойманному — коленом, иначе широкий выброс
	elif not p.held("attack") or not ready_to_work():
		mode = "hold"
		pulling = []
		p.rig.play_for("TyagaSuckOut", 0.24, 0.06)      # переход: поток оборвался — качнуло вперёд
		clip_t = 0.24
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
		elif p.held("block"):
			_act("ground")                   # с блоком — в землю
		elif p.held("jump"):
			_act("up")                       # с прыжком — вверх
		elif charge_t < need and _point_blank():
			_act("point")                    # враг у самого сопла — в упор
		else:
			_blast(charge_t >= need)

func _blast(big: bool) -> void:
	var a: AttackData = style.attack("tg_burst" if big else "tg_shot")
	var n := nozzle()
	var f := fwd()
	var hits := 0
	game.measure_use(p.hero, style.id, a.id)
	var lm := _link_mul(a.id)
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
		h.damage = p.combat.damage_for(a, e) * (float(a.extra.get("caught_mul", 1.0)) if caught.has(e.get_instance_id()) else 1.0) * lm
		h.stagger = a.stagger
		if game.run_mods != null:
			h.stagger *= 1.0 + 0.15 * game.run_mods.rank("tyaga")
			if game.run_mods.rank("tyaga") > 0:
				h.telemetry_effects.append("tyaga")
		h.dir = dn
		h.knockback = a.knockback
		h.launch = a.launch
		h.heavy = a.heavy
		h.power = a.power
		h.attack_id = a.id
		h.style_id = style.id
		h.telemetry_hero = "pahan"
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
	_mark(a.id)
	if riding():
		speed = max(0.0, speed - 3.0)          # верхом отдача гасит скорость
		rev = false
		p.rig.play_for("RideShot", 0.35, 0.05)
		clip_t = 0.35
		return
	p.velocity = -f * float(a.extra["recoil"])
	p.rig.play_for(a.clip, a.duration, 0.05)
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
	game.measure_use(p.hero, style.id, a.id)
	var h := HitInfo.new()
	h.damage = p.combat.damage_for(a, best) * _link_mul(a.id)
	h.stagger = a.stagger
	h.dir = f
	h.knockback = a.knockback
	h.launch = a.launch
	h.power = a.power
	h.attack_id = a.id
	h.style_id = style.id
	h.telemetry_hero = "pahan"
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
	p.rig.play_for(a.clip, a.duration, 0.05)
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
			h.telemetry_hero = "pahan"
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
	drifting = drift
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
		if rev and abs(off) < 1.7:
			rev = false
		if abs(off) > 2.4 and speed > 3.0 and grounded:
			if drift:
				flip_t = float(R["flip"])                 # занос + назад: разворот
				flip_from = heading
				game.main.sfx("sfx_scrape", -6.0, 1.3)
				events.append(["flip", 0])
			else:
				if not braking:
					braking = true
					game.main.sfx("sfx_scrape", -9.0, 1.0)
					events.append(["brake", 0])
				speed = move_toward(speed, 0.0, float(R["brake"]) * dt)   # назад без заноса — тормоз
		elif grounded and (rev or (braking and abs(off) > 2.4)):
			# дотормозил и всё ещё держит «назад» — задний ход: нос на месте, пылесос пятится
			if speed > 0.3:
				speed = move_toward(speed, 0.0, float(R["brake"]) * dt)
			else:
				if not rev:
					rev = true
					events.append(["reverse", 0])
				speed = move_toward(speed, -float(R["vrev"]), float(R["accel"]) * 0.7 * dt)
				heading = rotate_toward(heading, target + PI, float(R["steer"]) * 0.6 * dt)
		else:
			braking = false
			if abs(speed) < 0.6 and grounded and kick_cd <= 0.0 and flip_t <= 0.0:
				# с места: толчок ногой
				speed = float(R["kick"])
				kick_cd = 1.2
				p.rig.play_for("RideKick", 0.3, 0.05)
				clip_t = 0.3
				game.fx.dust(p.global_position + Vector3(0, 0.08, 0), 3, game.fx.DUST, 0.5)
				events.append(["kick", 0])
			var rate: float = float(R["steer_drift"] if drift else R["steer"]) * (clampf(speed / 3.0, 0.45, 1.0) if grounded else 0.35)
			var h0 := heading
			heading = rotate_toward(heading, target, rate * dt)
			turn = angle_difference(h0, heading) / max(dt, 0.0001)
			speed = move_toward(speed, float(R["vboost"] if boost else R["vmax"]), float(R["accel"]) * (1.4 if boost else 1.0) * dt)
	else:
		braking = false
		rev = false
		speed = move_toward(speed, 0.0, float(R["coast"]) * dt)
	if boost:
		_heat(float(R["boost_heat"]) * dt)
	# куда едет на самом деле: в заносе сцепление слабое, тело несёт боком
	var hd := Vector3(sin(heading), 0, cos(heading))
	var grip: float = R["grip_drift"] if drift else R["grip"]
	vdir = vdir.lerp(hd, 1.0 - exp(-grip * dt)).normalized() if grounded else vdir
	side_k = vdir.angle_to(hd)
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
		if slam:
			# упал камнем: удар по области вокруг
			slam = false
			var sa: AttackData = style.attack("tg_slam")
			_area_hit(sa, p.global_position, "slam")
			game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.4, sa.reach * 2.0, Color(0.8, 0.95, 1.0, 0.7), 0.35)
			game.fx.dust(p.global_position + Vector3(0, 0.1, 0), 14, game.fx.DUST, 1.2)
			game.main.sfx("sfx_boom", -5.0, 1.4)
			p.rig.play_for("RideSlamLand", 0.35, 0.04)
			clip_t = 0.35
			speed *= 0.5
	# наклон в поворот и на разгоне: пылесос и герой кренятся вместе
	lean = lerpf(lean, clampf(-turn * 0.09 * clampf(speed / 8.0, 0.0, 1.0), -0.38, 0.38) * (1.6 if drift else 1.0), 1.0 - exp(-9.0 * dt))
	p.body.rotation.z = lean
	p.body.rotation.x = lerpf(p.body.rotation.x, -0.12 if air else (0.06 if boost else 0.0), 1.0 - exp(-8.0 * dt))
	# удар с разворота на ходу
	if dh_t >= 0.0:
		# удар в заносе идёт
		dh_t += dt
		var da: AttackData = style.attack("tg_drift")
		if not dh_hit and dh_t >= a_time(da):
			dh_hit = true
			_area_hit(da, p.global_position, "drift")
		if dh_t >= da.duration:
			dh_t = -1.0
	elif spin_t < 0.0 and p.pressed("attack") and air and not slam:
		# ЛКМ в прыжке: камнем вниз
		slam = true
		p.velocity.y = -float(style.attack("tg_slam").extra["dive"])
		p.rig.play_for("RideSlam", 0.3, 0.05)
		clip_t = 1.5
		game.main.sfx("sfx_swing_heavy", -4.0, 0.8)
		events.append(["dive", 0])
	elif spin_t < 0.0 and p.pressed("attack") and drift and spin_cd <= 0.0:
		var da2: AttackData = style.attack("tg_drift")
		dh_t = 0.0
		dh_hit = false
		spin_cd = da2.cooldown
		p.rig.play_for("RideDriftHit", da2.duration, 0.05)
		clip_t = da2.duration
		game.main.sfx("sfx_swing_heavy", -3.0, 1.3)
		_heat(float(da2.extra["heat"]))
	elif spin_t >= 0.0:
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
	if spin_t < 0.0 and dh_t < 0.0 and clip_t <= 0.0 and not air and (p.rig.cur != "RideJump" or not p.rig.player.is_playing()):
		p.rig.play("RideReverse" if rev else ("RideBrake" if braking and speed > 0.3 else ("RideDrift" if drift else ("RideBoost" if boost else "RideSit"))), 0.15)
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
	var a: AttackData = style.attack("tg_airram" if air else "tg_ram")
	if not air and drifting and side_k > float(style.attack("tg_side").extra["slip"]):
		a = style.attack("tg_side")      # несёт боком — бьёт бортом
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
		game.measure_use(p.hero, style.id, a.id)
		h.damage = (a.damage + speed * float(a.extra["per_speed"])) * p.combat.damage_for(a, e) / a.damage
		h.stagger = a.stagger
		h.dir = (f + d.normalized() * (0.4 if a.id == "tg_ram" else 1.6)).normalized()      # бортом — в сторону от пылесоса
		h.knockback = speed * a.knockback
		h.stun = a.stun
		var boosted: bool = speed >= float(a.extra["boost_speed"])
		h.launch = float(a.extra["boost_launch"]) if boosted else a.launch      # таран на ускорении подбрасывает выше
		h.power = a.power
		h.attack_id = a.id
		h.style_id = style.id
		h.telemetry_hero = "pahan"
		h.source = p
		h.pos = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
		e.interrupt_weak()
		e.take_hit_info(h)
		if boosted:
			game.popup(p.global_position + Vector3(0, 2.4, 0), "ТАРАН", Color(0.8, 0.95, 1.0))
		if a.id != "tg_ram":
			game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(0.8, 0.95, 1.0))
			if clip_t <= 0.0:
				p.rig.play_for(a.clip, 0.3, 0.05)
				clip_t = 0.3
		_mark(a.id)
		game.fx.hit(h.pos, h.dir, 1, style.color)
		game.main.sfx("sfx_hit_heavy", -2.0, 1.1)
		game.feedback(a.feedback, h.pos, f, clampf(speed / 10.0, 0.6, 1.4), style.color)
		p.swag = min(100.0, p.swag + 5.0)
		speed *= float(a.extra["keep"]) if e.boss_id == "" else 0.3     # о босса пылесос почти останавливается
		events.append(["ram" if a.id == "tg_ram" else ("side" if a.id == "tg_side" else "airram"), e])

func _area_hit(a: AttackData, at: Vector3, tag: String) -> void:
	game.measure_use(p.hero, style.id, a.id)
	var hits := 0
	var lm := _link_mul(a.id)
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - at
		d.y = 0
		if d.length() > a.reach + float(e.radius):
			continue
		var h := HitInfo.new()
		h.damage = p.combat.damage_for(a, e) * lm
		h.stagger = a.stagger
		h.dir = d.normalized() if d.length() > 0.05 else fwd()
		h.knockback = a.knockback
		h.launch = a.launch
		h.heavy = a.heavy
		h.power = a.power
		h.attack_id = a.id
		h.style_id = style.id
		h.telemetry_hero = "pahan"
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
	if hits > 0:
		_mark(a.id)
	events.append([tag, hits])

# ---------------- этап 3: приёмы на ногах и связки ----------------
## момент удара приёма, с
func a_time(a: AttackData) -> float:
	return a.duration * float(a.hits[0])

## запомнить приём: следующий из таблицы связок ударит сильнее
func _mark(id: String) -> void:
	link_from = id
	link_t = StyleTyaga.LINK_T

## множитель урона: приём идёт сразу после другого из StyleTyaga.LINKS — связка
func _link_mul(id: String) -> float:
	if link_t > 0.0 and (StyleTyaga.LINKS.get(link_from, []) as Array).has(id):
		events.append(["link", link_from + ">" + id])
		game.popup(p.global_position + Vector3(0, 2.9, 0), "СВЯЗКА", style.color_hot)
		link_t = 0.0
		return StyleTyaga.LINK_MUL
	return 1.0

## есть ли враг у самого сопла (для выброса в упор)
func _point_blank() -> bool:
	var a: AttackData = style.attack("tg_point")
	var n := nozzle()
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var d: Vector3 = e.global_position - n
			d.y = 0
			if d.length() <= float(a.extra["near"]) + float(e.radius):
				return true
	return false

func _info(a: AttackData, e, dir: Vector3, mul: float) -> HitInfo:
	var h := HitInfo.new()
	h.damage = p.combat.damage_for(a, e) * mul
	h.stagger = a.stagger
	h.dir = dir
	h.knockback = a.knockback
	h.launch = a.launch
	h.stun = a.stun
	h.heavy = a.heavy
	h.power = a.power
	h.attack_id = a.id
	h.style_id = style.id
	h.telemetry_hero = "pahan"
	h.source = p
	h.pos = e.global_position + Vector3(0, float(e.height) * 0.55, 0)
	return h

## начать приём на ногах: knee, wide, ground, up, point
func _act(kind: String) -> void:
	var a: AttackData = style.attack("tg_" + kind)
	game.measure_use(p.hero, style.id, a.id)
	act = {"kind": kind, "a": a, "hit": false}
	mode = "act"
	mt = 0.0
	charge_t = 0.0
	game.charge_zoom = 0.0
	pulling = []
	p.rig.play_for(a.clip, a.duration, 0.05)
	if kind == "knee":
		p.velocity = fwd() * float(a.extra["lunge"])
		game.main.sfx("sfx_swing_heavy", -4.0, 1.25)
	else:
		game.main.sfx("sfx_charge", -9.0, 1.3)

func _act_hit() -> void:
	var kind: String = act["kind"]
	var a: AttackData = act["a"]
	var n := nozzle()
	var f := fwd()
	var mul := _link_mul(a.id)
	var hits := 0
	var origin: Vector3 = n if kind == "ground" else p.global_position
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - origin
		d.y = 0
		var dist := d.length()
		if dist > a.reach + float(e.radius):
			continue
		if a.arc < 6.0 and dist > 0.7 and f.angle_to(d / dist) > a.arc * 0.5:
			continue
		var dn: Vector3 = d / dist if dist > 0.05 else f
		var m2 := mul
		if kind == "up" and e.state != "air":
			if dist > float(a.extra["ground_reach"]) + float(e.radius):
				continue
			m2 *= float(a.extra["ground_mul"])      # стоящего рядом задевает слабее
		if kind in ["knee", "point"]:
			dn = f
		var h := _info(a, e, dn, m2)
		e.interrupt_weak()
		e.take_hit_info(h)
		if kind == "wide" and is_instance_valid(e) and e.alive():
			e.slow(float(a.extra["slow"]), 0.6)
		game.fx.hit(h.pos, dn, 1 if a.heavy else 0, style.color)
		hits += 1
	for b in game.bolts:      # снаряды сдувает
		if kind != "knee" and ((b["n"] as Node3D).global_position - n).length() < a.reach:
			b["life"] = 0.0
	caught = {}
	# видно и слышно
	var fx = game.fx
	var nr := nozzle_real()
	var col := Color(0.8, 0.95, 1.0, 0.6)
	match kind:
		"wide":
			for i in range(-2, 3):
				var dd: Vector3 = f.rotated(Vector3.UP, float(i) * 0.5)
				fx.ring(p.global_position + dd * 2.4 + Vector3(0, 0.7, 0), 1.3, col, 0.24)
			fx.muzzle(nr + Vector3(0, 0.1, 0), style.color)
			fx.dust(n + f * 1.2, 8, game.fx.DUST, 1.0)
			game.main.sfx("sfx_wave", -3.0, 1.55)
		"ground":
			fx.ground_ring(Vector3(n.x, p.global_position.y + 0.05, n.z), 0.4, a.reach * 2.0, Color(0.8, 0.95, 1.0, 0.75), 0.4)
			fx.dust(n, 18, game.fx.DUST, 1.5)
			game.main.sfx("sfx_boom", -4.0, 1.5)
		"up":
			for i in 4:
				fx.ring(nr + f * 0.6 + Vector3(0, 0.5 + i * 0.9, 0), 1.0 + i * 0.35, Color(0.8, 0.95, 1.0, 0.6 - i * 0.1), 0.2 + i * 0.05)
			fx.muzzle(nr, style.color)
			game.main.sfx("sfx_wave", -3.0, 1.75)
		"point":
			fx.muzzle(nr + Vector3(0, 0.1, 0), style.color)
			fx.ring(nr + f * 0.8 + Vector3(0, 0.3, 0), 1.8, Color(1, 1, 1, 0.7), 0.2)
			fx.dust(n + f * 0.6, 10, game.fx.DUST, 1.1)
			game.main.sfx("sfx_boom", -3.0, 1.7)
		"knee":
			if hits > 0:
				game.main.sfx("sfx_hit_heavy", -2.0, 1.15)
	if hits > 0 or kind != "knee":
		game.feedback(a.feedback, (p.global_position + f * 1.2 + Vector3(0, 0.8, 0)), f, 1.0, style.color)
	if hits > 0 and a.title != "":
		game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(0.8, 0.95, 1.0))
	if a.extra.has("heat"):
		_heat(float(a.extra["heat"]))
	if a.extra.has("recoil"):
		p.velocity = -f * float(a.extra["recoil"])
	events.append([kind, hits])
	if hits > 0:
		_mark(a.id)

# ---------------- звук мотора ----------------
func _hum(level: float) -> void:
	hum_frame = Engine.get_physics_frames()
	if mode == "off":
		level = 0.0
	if not hum.playing:
		if level <= 0.0 or game.main.testing() != "":
			return
		hum.volume_db = -60.0
		hum.play()                   # гул заводится, только когда пылесос работает
	elif level <= 0.0 and hum.volume_db <= -70.0:
		hum.stop()                   # затих совсем — плеер останавливается, а не крутится беззвучно
		return
	hum.volume_db = lerpf(hum.volume_db, lerpf(-34.0, -13.0, level) if level > 0.0 else -80.0, 0.12)
	var pitch := 0.8 + 0.5 * level + (clampf(speed / 14.0, 0.0, 1.0) * 0.5 if mode == "ride" else 0.0) - (0.25 if lock > 0.0 else 0.0)
	hum.pitch_scale = lerpf(hum.pitch_scale, pitch, 0.15)

## гул мотора: пила с биением и шум, зацикленный (записи пылесоса в проекте нет)
static func _synth_hum() -> AudioStreamWAV:      # static: тот же гул мотора берут гонщики (race_rider.gd)
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
