## Водяра (этап 06): бутылка в руке Пахана, полёт, попадание, разбивание и всплеск.
## Бросок запускает ядро боя (combat.gd) в момент попадания атаки стиля «bottles»; здесь — всё, что после вылета из руки.
## Модель — assets/models/bottle.glb. Звук всплеска синтезируется (в проекте нет записи воды), стекло — sfx_glass.
class_name Bottles
extends Node3D

const MODEL := "res://assets/models/bottle.glb"
const SIZE := 0.34              # высота бутылки, м
const MODEL_H := 98.0           # высота модели в её единицах (ось Y, горлышко вверху)
const GRAVITY := 14.0
const WATER := Color(0.55, 0.82, 1.0)
const MAX_FLYING := 12          # больше бутылок в воздухе одновременно не бывает

var p
var game
var scene: PackedScene
var prop: Node3D                # бутылка в кулаке
var prop_att: BoneAttachment3D
var prop_l: Node3D              # вторая бутылка — в левом кулаке
var prop_l_att: BoneAttachment3D
var hid_r := false             # правая бутылка брошена: появится, когда рука дойдёт до кармана
var hid_l := false
var rico_log: Array = []       # для проверок: [откуда-враг, куда-враг]
var flying: Array = []          # [{node, vel, a: AttackData, power, life, spin}]
var dots: Array = []            # точки траектории при прицеливании
var splash_snd: AudioStreamWAV
var throw_hand := "r"          # какой рукой идёт текущая бутылка серии
var hits_log: Array = []        # для проверок: [{kind, enemy, pos}]

func setup(player, g) -> void:
	p = player
	game = g
	scene = load(MODEL)
	# бутылка в правом кулаке: горлышко в кулаке, корпус выходит со стороны мизинца — как балон
	var r: Rig = p.rig
	prop_att = BoneAttachment3D.new()
	prop_att.bone_name = r.skel.get_bone_name(r.bone["rhand"])
	r.skel.add_child(prop_att)
	var hd: Dictionary = r.hand["r"]
	var Y: Vector3 = (hd["k"] as Vector3) * r.weapon_sign
	var Z: Vector3 = hd["f"]
	Z = (Z - Y * Z.dot(Y)).normalized()
	var hold := Node3D.new()
	var sk_scale: float = r.skel_xf.basis.get_scale().x * r.model.scale.x
	hold.transform = Transform3D(Basis(Y.cross(Z), Y, Z).orthonormalized().scaled(Vector3.ONE / sk_scale), hd["grip"])
	prop_att.add_child(hold)
	prop = _make()
	# модель: низ в нуле, горлышко вверху → переворачиваем, чтобы горлышко (y ≈ 88 %) оказалось в кулаке
	prop.rotation.x = PI
	prop.position.y = SIZE * 0.88
	hold.add_child(prop)
	prop_att.visible = false
	# вторая бутылка в левом кулаке — так же: горлышко в кулаке
	prop_l_att = BoneAttachment3D.new()
	prop_l_att.bone_name = r.skel.get_bone_name(r.bone["lhand"])
	r.skel.add_child(prop_l_att)
	var hl: Dictionary = r.hand["l"]
	var Yl: Vector3 = (hl["k"] as Vector3) * r.weapon_sign
	var Zl: Vector3 = hl["f"]
	Zl = (Zl - Yl * Zl.dot(Yl)).normalized()
	var hold_l := Node3D.new()
	hold_l.transform = Transform3D(Basis(Yl.cross(Zl), Yl, Zl).orthonormalized().scaled(Vector3.ONE / sk_scale), hl["grip"])
	prop_l_att.add_child(hold_l)
	prop_l = _make()
	prop_l.rotation.x = PI
	prop_l.position.y = SIZE * 0.88
	hold_l.add_child(prop_l)
	prop_l_att.visible = false
	splash_snd = _synth_splash()
	for i in 14:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		d.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.7, 0.9, 1.0, 0.8)
		d.material_override = m
		d.visible = false
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		dots.append(d)
	top_level = true

func _make() -> Node3D:
	var n: Node3D = scene.instantiate()
	n.scale = Vector3.ONE * (SIZE / MODEL_H)
	return n

func show_prop(on: bool) -> void:
	prop_att.visible = on
	if not on:
		prop_l_att.visible = false

## Каждый кадр: какие бутылки видны в руках. on — стиль выбран и руки свободны; запас решает, сколько их:
## одна — в правой, две и больше — в обеих. Брошенная бутылка появляется снова, когда рука в конце клипа
## доходит до кармана (extra.draw атаки), а не сразу.
func update_props(on: bool) -> void:
	var c = p.combat
	var a: AttackData = c.cur
	if a == null or a.projectile == "" or c.k() >= float(a.extra.get("draw", 0.84)):
		hid_r = false
		hid_l = false
	var have: float = c.ammo_of("bottles")
	prop_att.visible = on and have >= 1.0 and not hid_r
	prop_l_att.visible = on and have >= 2.0 and not hid_l

func hand_pos() -> Vector3:
	return prop_att.global_position

## Цели броска по убыванию удобства: враги в секторе перед героем на дистанции атаки.
func targets_for(a: AttackData) -> Array:
	var fwd := Vector3(sin(p.face), 0, cos(p.face))
	var list := []
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > a.reach or dist < 0.3:
			continue
		var ang := fwd.angle_to(d / dist)
		if ang > a.arc * 0.5:
			continue
		list.append([(1.0 - ang / (a.arc * 0.5)) * 2.0 + (1.0 - dist / a.reach), e])
	list.sort_custom(func(x, y): return x[0] > y[0])
	return list.map(func(it): return it[1])

## Откуда вылетает бутылка: правая рука (стиль «Водяра») или левая (бросок из комбо балоном).
func throw_from(a: AttackData) -> Vector3:
	if String(a.extra.get("hand", "r")) == "l" or throw_hand == "l":
		var r: Rig = p.rig
		return (r.skel.global_transform * r.skel.get_bone_global_pose(r.bone["lhand"])).origin
	return hand_pos() if prop_att.is_inside_tree() else p.global_position + Vector3(0, 1.3, 0)

## Куда и с какой скоростью летит бросок: в цель (центр корпуса, с упреждением — враг может бежать или лететь),
## без цели — вперёд по взгляду с отклонением yaw. Возвращает [откуда, скорость, цель].
func aim(a: AttackData, power: float, target = null, yaw := 0.0) -> Array:
	var from := throw_from(a)
	var fwd := Vector3(sin(p.face + yaw), 0, cos(p.face + yaw))
	var at: Vector3 = p.global_position + fwd * 9.0 + Vector3(0, 0.9, 0)
	var speed: float = float(a.extra.get("speed", 17.0)) * (1.0 + 0.25 * power)
	if target == null and yaw == 0.0:
		var list := targets_for(a)
		if not list.is_empty():
			target = list[0]
	if target != null:
		at = target.global_position + Vector3(0, float(target.height) * 0.6, 0)
		var t0: float = max(0.22, (at - from).length() / speed)
		var lead: Vector3 = target.velocity * t0            # упреждение: где цель будет, когда бутылка долетит
		if target.state == "air":
			lead.y -= 0.5 * 20.0 * t0 * t0                # подброшенный падает
		at += lead.limit_length(4.0)
		at.y = max(at.y, target.global_position.y - 2.0)
	var d2 := at - from
	var tm: float = max(0.22, d2.length() / speed) * (1.0 + 0.6 * float(a.extra.get("arc_up", 0.0)))      # навес: летит дольше и выше
	return [from, d2 / tm + Vector3(0, 0.5 * GRAVITY * tm, 0), target]

## бросок: бутылки вылетают из руки. extra.count — сколько (двойной, веер): каждая в свою цель,
## а если целей меньше — веером по сторонам от первой.
func throw(a: AttackData, power: float) -> void:
	var n: int = a.extra.get("count", 1)
	var list := targets_for(a)
	var fan: float = a.extra.get("fan", 0.14)
	var both: bool = a.extra.get("both", false)
	for i in n:
		throw_hand = "l" if both and i % 2 == 1 else "r"      # двумя руками — по очереди
		var am: Array
		if i < list.size():
			am = aim(a, power, list[i])
		elif list.is_empty():
			am = aim(a, power, null, (i - (n - 1) * 0.5) * fan * 2.0 + (0.0001 if n == 1 else 0.0)) if n > 1 else aim(a, power)
		else:
			am = aim(a, power, list[0])
			am[1] = (am[1] as Vector3).rotated(Vector3.UP, (i - list.size() + 1) * fan * (1.0 if i % 2 == 0 else -1.0))
		if flying.size() >= MAX_FLYING:
			# предел объектов в полёте: самая старая бутылка разбивается на месте
			var old: Dictionary = flying.pop_front()
			_shatter(old, (old["node"] as Node3D).global_position, Vector3.UP, null)
			(old["node"] as Node3D).queue_free()
		var node := _make()
		add_child(node)
		node.global_position = am[0]
		flying.append({"node": node, "vel": am[1], "a": a, "power": power, "life": 3.0, "spin": Vector3(randf_range(6, 11), randf_range(-3, 3), randf_range(-4, 4)), "rico": int(a.extra.get("ricochet", 0)), "mul": 1.0,
			"telemetry_hero": p.hero, "telemetry_style": p.style.id})
		if throw_hand == "l":
			hid_l = true
		else:
			hid_r = true
	throw_hand = "r"
	if String(a.extra.get("hand", "r")) == "l":
		hid_r = false                 # бросок левой из комбо балоном: правая занята балоном
	game.main.sfx("sfx_swing", -6.0, 1.3 if power < 0.3 else 1.0)

## траектория при прицеливании (удержание тяжёлого)
func preview(a: AttackData, power: float) -> void:
	var am := aim(a, power)
	var pos: Vector3 = am[0]
	var v: Vector3 = am[1]
	for i in dots.size():
		var tm := (i + 1) * 0.055
		var d: MeshInstance3D = dots[i]
		d.visible = true
		d.global_position = pos + v * tm + Vector3(0, -0.5 * GRAVITY * tm * tm, 0)
		(d.material_override as StandardMaterial3D).albedo_color.a = 0.85 - 0.05 * i

func hide_preview() -> void:
	for d in dots:
		(d as MeshInstance3D).visible = false

func _physics_process(dt: float) -> void:
	if flying.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for i in range(flying.size() - 1, -1, -1):
		var f: Dictionary = flying[i]
		var n: Node3D = f["node"]
		var from := n.global_position
		f["vel"] = (f["vel"] as Vector3) + Vector3(0, -GRAVITY * dt, 0)
		var home = f.get("home")      # отскок рикошета доводится до цели: она успевает сдвинуться
		if home != null and is_instance_valid(home) and home.alive():
			var aim_at: Vector3 = home.global_position + Vector3(0, float(home.height) * 0.6, 0) - from
			if aim_at.length() > 0.05:
				f["vel"] = aim_at.normalized() * 20.0
		var to := from + (f["vel"] as Vector3) * dt
		f["life"] = float(f["life"]) - dt
		var hit_e = null
		var hit_at := to
		# хёртбокс врага — капсула (радиус, высота): ближайшая точка пути бутылки за кадр
		for e in game.enemies:
			if not is_instance_valid(e) or not e.alive() or (f.get("seen", []) as Array).has(e):      # рикошет не бьёт тех, кого уже задел
				continue
			var mid: Vector3 = e.global_position + Vector3(0, float(e.height) * 0.5, 0)
			var c: Vector3 = Geometry3D.get_closest_point_to_segment(mid, from, to)
			if Vector2(c.x - mid.x, c.z - mid.z).length() <= float(e.radius) + 0.2 and c.y >= e.global_position.y - 0.1 and c.y <= e.global_position.y + float(e.height) + 0.25:
				hit_e = e
				hit_at = c
				break
		var normal := Vector3.UP
		var world := false
		if hit_e == null:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1)
			var skip: Array[RID] = [p.get_rid()]
			for se in (f.get("seen", []) as Array):      # отскок стартует у тела врага: его самого луч не видит
				if is_instance_valid(se) and se is CollisionObject3D:
					skip.append(se.get_rid())
			q.exclude = skip
			var r: Dictionary = space.intersect_ray(q)
			if not r.is_empty():
				world = true
				hit_at = r["position"]
				normal = r["normal"]
		if hit_e != null or world or float(f["life"]) <= 0.0:
			_shatter(f, hit_at, normal, hit_e)
			n.queue_free()
			flying.remove_at(i)
			continue
		n.global_position = to
		n.rotation += (f["spin"] as Vector3) * dt

## бутылка разбилась: стекло, вода, урон и замедление
## «АВАРИЙНЫЙ ЗАПАС 0.5»: всплеск 3,5 м — остальным в радиусе +60 % урона попадания и замедление 40 % на 3 с (боссу +30 % и 20 % на 1,5 с)
func _reserve_splash(at: Vector3, base: float, main_enemy) -> void:
	game.fx.ring(at, 3.5, Color(1.0, 0.85, 0.2, 0.75), 0.45)
	game.fx.sparks(at, Vector3.UP, 22, Color(1.0, 0.9, 0.4), 1.4, 90.0)
	game.popup(at + Vector3(0, 1.4, 0), "ЗАПАС 0.5", Color(1.0, 0.85, 0.3))
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive() or e.global_position.distance_to(at) > 3.5:
			continue
		var boss: bool = String(e.boss_id) != ""
		if e != main_enemy:
			e.take_hit(base * (0.3 if boss else 0.6), (e.global_position - at).normalized(), 2.0, false)
		if is_instance_valid(e):
			e.slow(1.5 if boss else 3.0, 0.2 if boss else 0.4)

func _shatter(f: Dictionary, at: Vector3, normal: Vector3, enemy) -> void:
	var a: AttackData = f["a"]
	var power: float = f["power"]
	var dir: Vector3 = (f["vel"] as Vector3).normalized()
	var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.FORWARD
	var fx = game.fx
	fx.flash(at, 0.9 + 0.5 * power, Color(0.85, 0.95, 1.0), "star_04", 0.12)
	fx.sparks(at, (normal - dir * 0.4).normalized(), 16 + int(10 * power), WATER, 0.9, 70.0)     # брызги
	fx.sparks(at, normal, 8, Color(0.95, 1.0, 1.0), 1.2, 85.0)                                    # осколки
	fx.dust(at, 4, Color(0.7, 0.88, 1.0, 0.4), 0.6, 0.2)
	fx.ring(at, 1.0 + 0.8 * power, Color(WATER.r, WATER.g, WATER.b, 0.6), 0.18)
	game.main.sfx("sfx_glass", -3.0, 1.15)
	_play_splash(at)
	hits_log.append({"kind": "enemy" if enemy != null else "world", "enemy": enemy, "pos": at})
	if game.golda != null and game.golda.get("arena") != null:
		game.golda.arena.bottle_hit(at)
	var slow_s: float = a.extra.get("slow", 0.0)
	var reserve := false
	if enemy != null and game.golda != null and game.golda.has_method("reserve_use"):
		reserve = game.golda.reserve_use()
	if enemy != null:
		var h := HitInfo.new()
		h.damage = p.combat.damage_for(a, enemy) * float(f.get("mul", 1.0))
		if reserve:
			h.damage *= 1.3 if String(enemy.boss_id) != "" else 1.6
			_reserve_splash(at, p.combat.damage_for(a, enemy) * float(f.get("mul", 1.0)), enemy)
		# LAST DROP: усиленный бросок по оглушённому, согнувшемуся или лежащему — кратный урон и подброс
		var ld: float = a.extra.get("last_drop", 0.0)
		if ld > 0.0 and (enemy.state in ["stun", "down", "getup"] or enemy.react_state() in ["HEAVY_STAGGER", "EXECUTION_READY"]):
			h.damage *= ld
			h.launch = 5.0
			game.popup(enemy.global_position + Vector3(0, float(enemy.height) + 0.7, 0), "LAST DROP", Color(0.75, 0.92, 1.0))
			hits_log[hits_log.size() - 1]["last_drop"] = true
		h.stagger = a.stagger
		if game.run_mods != null:
			h.stagger *= 1.0 + 0.18 * game.run_mods.rank("bottles")
			if game.run_mods.rank("bottles") > 0:
				h.telemetry_effects.append("bottles")
		h.dir = flat
		h.knockback = a.knockback
		h.stun = a.stun
		h.heavy = a.heavy
		h.power = a.power
		h.attack_id = a.id
		h.style_id = "bottles"
		h.telemetry_hero = f.get("telemetry_hero", p.hero)
		if game.telemetry != null:
			h.telemetry_style = f.get("telemetry_style", "bottles")
		if enemy.state == "air":
			h.stagger *= 1.5              # по цели в воздухе — сбивает сильнее
			hits_log[hits_log.size() - 1]["air"] = true
		h.source = p
		h.pos = at
		enemy.interrupt_weak()
		enemy.take_hit_info(h)
		if slow_s > 0.0 and is_instance_valid(enemy):
			enemy.slow(slow_s, float(a.extra.get("slow_k", 0.6)))
		p.swag = min(100.0, p.swag + 3.0)
		if game.golda != null and game.golda.fit_lv("refill") > 0 and randf() < [0.15, 0.25, 0.35][game.golda.fit_lv("refill") - 1]:
			p.combat.ammo["bottles"] = minf(float(Styles.by_id("bottles").ammo_max) + 1.0, float(p.combat.ammo_of("bottles")) + 1.0)
			game.popup(p.global_position + Vector3(0, 2.2, 0), "ДОЛИВ", Color(0.62, 0.85, 0.25))
		game.feedback(a.feedback if a.feedback != "" else "bt_hit", at, flat, 1.0, WATER)
		p.combat.attack_hit.emit(a, 1)
		# РИКОШЕТ: бутылка не разбивается, а отскакивает к ближайшему другому врагу; каждый отскок слабее
		if int(f.get("rico", 0)) > 0:
			var next = null
			var nd := 7.5
			for e in game.enemies:
				if is_instance_valid(e) and e.alive() and e != enemy and not (f.get("seen", []) as Array).has(e):
					var dd: float = e.global_position.distance_to(enemy.global_position)
					if dd < nd:
						nd = dd
						next = e
			if next != null:
				var node := _make()
				add_child(node)
				node.global_position = at + Vector3(0, 0.15, 0)
				var to: Vector3 = next.global_position + Vector3(0, float(next.height) * 0.6, 0) - node.global_position
				var tm: float = max(0.18, to.length() / 20.0)
				var seen: Array = (f.get("seen", []) as Array).duplicate()
				seen.append(enemy)
				flying.append({"node": node, "vel": to / tm + Vector3(0, 0.5 * GRAVITY * tm, 0), "a": a, "power": power, "life": 2.0, "spin": Vector3(14, 3, 5), "rico": int(f["rico"]) - 1, "mul": float(f.get("mul", 1.0)) * 0.75, "seen": seen, "home": next,
					"telemetry_hero": f.get("telemetry_hero", p.hero), "telemetry_style": f.get("telemetry_style", "bottles")})
				rico_log.append([enemy, next])
				game.main.sfx("sfx_parry", -10.0, 1.8)
	else:
		# мимо: лужа на земле или всплеск на стене
		fx.ground_ring(Vector3(at.x, at.y + 0.03, at.z), 0.2, 1.4 + power, Color(WATER.r, WATER.g, WATER.b, 0.5), 0.35)
	# всплеск задевает тех, кто рядом: без урона, но мочит (замедляет) и чуть сбивает равновесие
	var splash: float = a.extra.get("splash", 0.0)
	if splash > 0.0:
		for e in game.enemies:
			if is_instance_valid(e) and e.alive() and e != enemy and e.global_position.distance_to(at) <= splash + float(e.radius):
				e.stagger(a.stagger * 0.4)
				if game.telemetry != null:
					game.telemetry.control(f.get("telemetry_hero", p.hero), f.get("telemetry_style", "bottles"), a.id, e, a.stagger * 0.4)
				if slow_s > 0.0:
					e.slow(slow_s * 0.7, float(a.extra.get("slow_k", 0.6)))
				fx.sparks(e.global_position + Vector3(0, float(e.height) * 0.6, 0), Vector3.UP, 5, WATER, 0.5)

func _play_splash(at: Vector3) -> void:
	var sp := AudioStreamPlayer3D.new()
	sp.stream = splash_snd
	sp.bus = "SFX"
	sp.volume_db = -4.0
	sp.pitch_scale = randf_range(0.9, 1.15)
	sp.max_distance = 40.0
	add_child(sp)
	sp.global_position = at
	sp.play()
	sp.finished.connect(sp.queue_free)

## всплеск воды: шум с быстрым спадом, приглушённый простым фильтром (как звуки podsfx.gd — без файлов)
func _synth_splash() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.38)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var rs := 12345
	for i in n:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var noise := float(rs % 2000) / 1000.0 - 1.0
		var t := float(i) / n
		var cut := lerpf(0.55, 0.08, t)                     # фильтр закрывается: «плюх» → шипение капель
		lp += (noise - lp) * cut
		var env := pow(1.0 - t, 2.2) * (1.0 if i > 40 else i / 40.0)
		var v := int(clampf(lp * env * 1.6, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
