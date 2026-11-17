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
var clip_t := 0.0             # идёт короткий клип (посадка, приземление): езду пока не включаем
var braking := false
var push_cd := 0.0            # до следующего толчка ногой
var lean := 0.0
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
	_stand_on_wheels(m)
	spinner.add_child(m)
	board.visible = false

func fwd() -> Vector3:
	return Vector3(sin(heading), 0, cos(heading))

## Поставить модель доски на колёса. Длинная ось модели — x, а вокруг неё модель в файле повёрнута на произвольный
## угол: нормаль деки ищем по треугольникам с весом по площади (поперёк неё площадь разбросана уже всего).
## У этой модели подвески с колёсами торчат с ОБЕИХ сторон деки (так её сгенерировали). Низ — сторона с рисунком
## (в осях модели она смотрит в +z); лишние колёса со стороны шкурки, где стоят ноги, из сетки убираем.
## Сам файл модели не меняется; то же делается с доской в руке и за спиной (player._weapon_bones).
var deck_n := Vector3.UP      # нормаль деки в осях модели (от колёс к шкурке) — нужна костям доски
func _stand_on_wheels(m: Node3D) -> void:
	var k: float = LEN / 97.9
	var mi := WeaponBones._mesh(m)
	if mi == null or mi.mesh == null:
		m.rotation.y = PI * 0.5
		m.scale = Vector3.ONE * k
		return
	var info: Array = fix_mesh(mi)
	var n: Vector3 = info[0]
	var lo: float = info[1]
	var deck_d: float = info[2]
	deck_n = n
	# оси модели → оси доски: длинная ось вдоль хода, нормаль деки вверх
	var from := Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n))
	var to := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(0, 0, -1).cross(Vector3.UP))
	m.basis = (to * from.inverse()).scaled(Vector3.ONE * k)
	m.position = Vector3(0, -lo * k, 0)      # колёса на земле: самая нижняя точка модели — на высоте 0
	deck_h = (deck_d - lo) * k               # высота шкурки над землёй

## Найти нормаль деки и убрать из сетки лишние подвески со стороны шкурки. Возвращает [нормаль (от колёс к шкурке),
## нижняя точка вдоль нормали, где дека вдоль нормали]. Нужна и доске под ногами, и доске в руке.
static func fix_mesh(mi: MeshInstance3D) -> Array:
	var cen := PackedVector3Array()      # центры треугольников
	var area := PackedFloat32Array()
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size() - 2, 3):
			var p0 := vs[idx[t]]
			var p1 := vs[idx[t + 1]]
			var p2 := vs[idx[t + 2]]
			cen.append((p0 + p1 + p2) / 3.0)
			area.append((p1 - p0).cross(p2 - p0).length() * 0.5)
	var wsum := 0.0
	var my := 0.0
	var mz := 0.0
	for i in cen.size():
		wsum += area[i]
		my += cen[i].y * area[i]
		mz += cen[i].z * area[i]
	my /= max(0.0001, wsum)
	mz /= max(0.0001, wsum)
	var cyy := 0.0
	var czz := 0.0
	var cyz := 0.0
	for i in cen.size():
		cyy += (cen[i].y - my) * (cen[i].y - my) * area[i]
		czz += (cen[i].z - mz) * (cen[i].z - mz) * area[i]
		cyz += (cen[i].y - my) * (cen[i].z - mz) * area[i]
	var wide: float = 0.5 * atan2(2.0 * cyz, cyy - czz)      # куда в плоскости y-z доска шире всего
	var n := Vector3(0, -sin(wide), cos(wide))               # поперёк этого направления — нормаль деки
	if n.z > 0.0:
		n = -n                                                # шкурка — в сторону −z, рисунок и рабочие колёса — в +z
	# где по толщине сама дека: слой с наибольшей площадью
	var bins := {}
	for i in cen.size():
		var bkey: int = roundi(cen[i].dot(n))
		bins[bkey] = float(bins.get(bkey, 0.0)) + area[i]
	var deck_d := 0.0
	var best := -1.0
	for bkey in bins:
		if float(bins[bkey]) > best:
			best = bins[bkey]
			deck_d = float(bkey)
	# убрать лишние подвески со стороны шкурки: всё выше деки в средней части (нос и хвост загнуты вверх — их не трогаем)
	var out := ArrayMesh.new()
	var lo := 1e9
	var hi := -1e9
	for si in mi.mesh.get_surface_count():
		var arr2: Array = mi.mesh.surface_get_arrays(si)
		var vs2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
		var idx2: PackedInt32Array = arr2[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, idx2.size() - 2, 3):
			var c: Vector3 = (vs2[idx2[t]] + vs2[idx2[t + 1]] + vs2[idx2[t + 2]]) / 3.0
			if c.dot(n) > deck_d + 2.5 and abs(c.x) < 40.0:
				continue
			keep.append(idx2[t])
			keep.append(idx2[t + 1])
			keep.append(idx2[t + 2])
			for j in 3:
				var d: float = vs2[idx2[t + j]].dot(n)
				lo = min(lo, d)
				hi = max(hi, d)
		arr2[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
		out.surface_set_material(si, mi.mesh.surface_get_material(si))
	mi.mesh = out
	return [n, lo, deck_d]

var deck_h := 0.11            # высота шкурки над землёй, м

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
	p.rig.position.y = -0.9 + deck_h + 0.012     # стопы на шкурке: высота деки — из самой модели
	p.rig.rotation.y = STANCE
	p.rig.play_for("SkateMount", 0.3, 0.06)      # шаг-подскок на доску
	clip_t = 0.3
	push_cd = 0.32
	braking = false
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
	clip_t = max(0.0, clip_t - dt)
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
			p.rig.play_for("SkateLand", 0.3, 0.04)      # присел, гася удар
			clip_t = 0.3
		diving = false
		if charges > 0:
			p.combat.open("dodge", 0.9)          # после трюков — окно ответного удара
		events.append(["land", n])
		if p.wbones.has("board_ride"):
			(p.wbones["board_ride"] as WeaponBones).bump(1.0)      # дека прогнулась под весом
	# ---- руление и скорость ----
	var want := dir.length() > 0.2
	sliding = p.held("roll") and grounded and speed > 3.0
	var h0 := heading
	# назад на ходу — торможение хвостом: нос не разворачивается, пока доска не встанет
	braking = want and grounded and not sliding and speed > 1.5 and fwd().dot(dir.normalized()) < -0.6
	if want and not braking:
		heading = rotate_toward(heading, atan2(dir.x, dir.z), float(R["steer_slide"] if sliding else R["steer"]) * (1.0 if grounded else 0.4) * dt)
	var turn: float = angle_difference(h0, heading) / max(dt, 0.0001)
	if braking:
		speed = move_toward(speed, 0.0, 16.0 * dt)
	elif sliding:
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
			if p.wbones.has("board_ride"):
				(p.wbones["board_ride"] as WeaponBones).bump(-0.7)      # щелчок хвостом: дека выгнулась обратно
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
	# карвинг: в повороте герой с доской наклоняется внутрь дуги
	lean = lerpf(lean, clampf(-turn * 0.07 * clampf(speed / 8.0, 0.0, 1.0), -0.32, 0.32) if grounded else 0.0, 1.0 - exp(-8.0 * dt))
	p.body.rotation.z = lean
	if grounded and not air and spin_t < 0.0 and clip_t <= 0.0:
		p.rig.play("SkateSlide" if sliding else ("SkateBrake" if braking else "SkateRide"), 0.12)
	# толчки: пока едет по своей воле, раз в пару секунд задняя нога отталкивается от земли
	if grounded and not air and spin_t < 0.0 and want and not sliding and not braking:
		push_cd -= dt
		if push_cd <= 0.0 and clip_t <= 0.0:
			push_cd = 2.3
			p.rig.play_for("SkatePush", 0.6, 0.08)
			clip_t = 0.6
			game.fx.dust(p.global_position - fwd() * 0.3 + Vector3(0, 0.05, 0), 2, game.fx.DUST, 0.4)
			events.append(["push", 0])
	elif clip_t > 0.0 and p.rig.cur == "SkatePush" and (sliding or braking or air):
		clip_t = 0.0      # занос, тормоз или прыжок обрывают толчок
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
