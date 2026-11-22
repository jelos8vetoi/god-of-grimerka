## Бой Миши Минасяна («ГОЛДА 67», район ДВОР): три приёма с ясной подготовкой и ясным ответом.
##   ЗАХВАТ          — руки в стороны, сектор перед ним; блок не спасает, только уклонение или шаг из зоны.
##   ЗАЩИТНАЯ СТОЙКА — руки скрещены, золотой сектор спереди; удар в сектор возвращается, со спины стойка сбивается.
##   ЗАЦЕП ЦЕПИ      — бросок цепи по полосе; попал — тянет к себе; промахнулся — цепь цепляется за турник или борт,
##                     и Миша открыт HOOK_OPEN секунд.
## Запускаются из BossMoves.start (состояние босса "special", события по времени e._at). Случайного нет: зона удара —
## та же, что нарисована на земле, взгляд на время приёма замирает (e.sp_lock), числа — константы ниже.
class_name G67Misha
extends RefCounted

## Порядок приёмов по фазам задан в G67Data.BOSSES (phases); сюда phases_for ничего не дописывает
const MOVES := [[], [], []]
const TITLES := {"m_grab": "ЗАХВАТ", "m_guard": "ЗАЩИТНАЯ СТОЙКА", "m_hook": "ЗАЦЕП ЦЕПИ"}

const GRAB_WARN := 0.95      # подготовка захвата, с
const GRAB_R := 3.6          # дальность захвата, м
const GRAB_HALF := 0.8       # половина сектора, рад
const GRAB_DMG := 1.5        # множитель урона босса
const GRAB_MISS := 0.9       # промахнулся — столько стоит открытым

const GUARD_LEN := 2.6       # сколько держит стойку, с
const GUARD_R := 2.6         # радиус золотого сектора (только рисунок: защищён весь перёд)
const GUARD_HALF := 1.25     # половина защищённого сектора, рад
const GUARD_REACH := 4.0     # ответный удар достаёт на столько, м
const GUARD_DMG := 0.8
const GUARD_GAP := 0.5       # ответ не чаще, с
const GUARD_COL := Color(1.0, 0.8, 0.25)

const HOOK_WARN := 0.9       # подготовка броска, с
const HOOK_LEN := 13.0       # длина полосы, м
const HOOK_HALF := 0.9       # половина ширины полосы, м
const HOOK_DMG := 1.0
const HOOK_OPEN := 2.0       # цепь зацепилась — столько Миша открыт, с
const HOOK_SNAP := 1.8       # турник «ловит» цепь, если полоса проходит не дальше этого от него, м

## Клипы Миши поверх набора врага (Poses.bot): захват, стойка, цепь натянута, сидит на троне.
static func clips() -> Dictionary:
	var en := Callable(Poses, "en")
	var wide: Dictionary = en.call({"spine": {"x": -0.22}, "rarm": {"x": 0.3, "z": -1.05}, "larm": {"x": 0.3, "z": 1.05}, "rfa": {"x": -0.35}, "lfa": {"x": -0.35}, "rup": {"x": -0.3}, "lup": {"x": -0.3}, "rleg": {"x": 0.5}, "lleg": {"x": 0.5}, "drop": 0.08})
	var clap: Dictionary = en.call({"spine": {"x": 0.5}, "rarm": {"x": -1.45, "z": 0.25}, "larm": {"x": -1.45, "z": -0.25}, "rfa": {"x": -0.7}, "lfa": {"x": -0.7}, "rup": {"x": -0.9}, "lup": {"x": 0.3}, "rleg": {"x": 0.9}, "lleg": {"x": 0.2}, "drop": 0.12})
	var guard: Dictionary = en.call({"spine": {"x": 0.14}, "rarm": {"x": -1.25, "z": 0.55}, "larm": {"x": -1.25, "z": -0.55}, "rfa": {"x": -1.9}, "lfa": {"x": -1.9}, "rup": {"x": -0.28}, "lup": {"x": -0.28}, "rleg": {"x": 0.45}, "lleg": {"x": 0.45}, "drop": 0.07})
	var guard2: Dictionary = en.call({"spine": {"x": 0.19}, "rarm": {"x": -1.3, "z": 0.55}, "larm": {"x": -1.3, "z": -0.55}, "rfa": {"x": -1.9}, "lfa": {"x": -1.9}, "rup": {"x": -0.32}, "lup": {"x": -0.32}, "rleg": {"x": 0.52}, "lleg": {"x": 0.52}, "drop": 0.09})
	var pull: Dictionary = en.call({"spine": {"x": -0.3, "y": 0.25}, "rarm": {"x": -1.5, "z": 0.2}, "rfa": {"x": -0.35}, "larm": {"x": -1.3, "z": -0.3}, "lfa": {"x": -0.6}, "rup": {"x": -0.5}, "lup": {"x": 0.25}, "rleg": {"x": 0.6}, "lleg": {"x": 0.15}, "drop": 0.1})
	var pull2: Dictionary = en.call({"spine": {"x": -0.42, "y": 0.1}, "rarm": {"x": -1.35, "z": 0.2}, "rfa": {"x": -0.7}, "larm": {"x": -1.15, "z": -0.3}, "lfa": {"x": -0.9}, "rup": {"x": -0.6}, "lup": {"x": 0.3}, "rleg": {"x": 0.75}, "lleg": {"x": 0.2}, "drop": 0.14})
	var sit: Dictionary = en.call({"spine": {"x": -0.12}, "rarm": {"z": 0.75, "x": -0.35}, "larm": {"z": -0.75, "x": -0.35}, "rfa": {"x": -0.9}, "lfa": {"x": -0.9}, "rup": {"x": -1.45, "z": -0.2}, "lup": {"x": -1.45, "z": 0.2}, "rleg": {"x": 1.5}, "lleg": {"x": 1.5}, "drop": SIT_DROP})
	var sit2: Dictionary = en.call({"spine": {"x": -0.08}, "head": {"x": 0.08}, "rarm": {"z": 0.75, "x": -0.35}, "larm": {"z": -0.75, "x": -0.35}, "rfa": {"x": -0.9}, "lfa": {"x": -0.9}, "rup": {"x": -1.45, "z": -0.2}, "lup": {"x": -1.45, "z": 0.2}, "rleg": {"x": 1.5}, "lleg": {"x": 1.5}, "drop": SIT_DROP})
	return {
		"MGrab": {"d": 1.0, "k": [[0.0, en.call({})], [0.3, wide, "out"], [0.6, wide], [0.7, clap, "in"], [0.85, clap], [1.0, en.call({}), "io"]]},
		"MGuard": {"d": 1.2, "loop": true, "k": [[0.0, guard], [0.5, guard2], [1.0, guard]]},
		"MStuck": {"d": 0.7, "loop": true, "k": [[0.0, pull], [0.5, pull2], [1.0, pull]]},
		"MSit": {"d": 2.6, "loop": true, "k": [[0.0, sit], [0.5, sit2], [1.0, sit]]},
	}
const SIT_DROP := 0.42

static func start(e, move: String) -> void:
	e.sp_lock = true
	match move:
		"m_grab":
			_grab(e)
		"m_guard":
			_guard(e)
		"m_hook":
			_hook(e)

static func _front(e) -> Vector3:
	return Vector3(sin(e.face), 0, cos(e.face))

static func _aim(e) -> void:
	var d: Vector3 = e.game.player.global_position - e.global_position
	d.y = 0
	if d.length() > 0.1:
		e.face = atan2(d.x, d.z)

## Сектор на земле (та же метка, что у врагов): виден sec секунд, заливка растёт до удара
static func _sector(e, r: float, half: float, sec: float, col: Color, pattern := 0) -> void:
	e.tell_r = r
	e.tell_half = half
	e.tell_lane = 0.0
	e.game.fx.tell_shape(e.tell, e.global_position, e.face, r, half, 0.0, pattern, col)
	e.tell_until = e.age + sec
	e.tell_sec = sec

# ---------------------------------------------------------------- ЗАХВАТ
## Герой в зоне захвата? (та же зона, что нарисована)
static func in_grab(e, at: Vector3) -> bool:
	var d: Vector3 = at - e.global_position
	d.y = 0
	return d.length() <= GRAB_R and (d.length() < 0.3 or _front(e).angle_to(d.normalized()) <= GRAB_HALF)

static func _grab(e) -> void:
	var g = e.game
	_aim(e)
	e.rig.play_for("MGrab", GRAB_WARN / 0.7, 0.08)
	_sector(e, GRAB_R, GRAB_HALF, GRAB_WARN, Color(0.95, 0.9, 1.0), 2)
	g.main.sfx("sfx_cast", -6.0, 0.6)
	e._at(GRAB_WARN, func():
		e._tell_end()
		var P = g.player
		g.main.sfx("sfx_swing_heavy", -2.0, 0.7)
		if in_grab(e, P.global_position) and P.inv <= 0.0 and P.state != "dead":
			var f := _front(e)
			P.take_damage(float(e.cfg["dmg"]) * GRAB_DMG, e.global_position, e, true)      # блок не спасает
			P.velocity = f * 11.0 + Vector3(0, 5.0, 0)                                     # бросок от себя
			g.popup(P.global_position + Vector3(0, 2.2, 0), "ПОЙМАЛ", Color(1.0, 0.4, 0.3))
			g.shake(0.45)
			e.grab_log.append("hit")
			e.sp_dur = GRAB_WARN + 0.6
		else:
			# схватил воздух: стоит согнувшись — время для ударов
			g.popup(e.global_position + Vector3(0, e.height + 0.5, 0), "МИМО", Color(0.8, 0.9, 1.0))
			e.grab_log.append("miss")
			e.sp_dur = GRAB_WARN + GRAB_MISS)
	e.sp_dur = GRAB_WARN + GRAB_MISS

# ---------------------------------------------------------------- ЗАЩИТНАЯ СТОЙКА
static func _guard(e) -> void:
	_aim(e)
	e.guard_until = e.age + GUARD_LEN
	e.rig.play("MGuard", 0.12)
	_sector(e, GUARD_R, GUARD_HALF, GUARD_LEN, GUARD_COL, 1)
	e.game.main.sfx("sfx_block", -3.0, 0.7)
	e._at(GUARD_LEN, func(): _guard_end(e))
	e.sp_dur = GUARD_LEN + 0.35

static func _guard_end(e) -> void:
	e.guard_until = -1.0
	e._tell_end()

static func guarding(e) -> bool:
	return e.guard_until > e.age and e.state == "special"

## Удар по Мише в стойке. true — удар принят на стойку (урона нет, может вернуться); false — прошёл как обычный.
static func guard_hit(e, h) -> bool:
	if not guarding(e):
		return false
	var g = e.game
	var f := _front(e)
	if f.angle_to((-h.dir as Vector3).normalized()) > GUARD_HALF:
		# со спины или сбоку: стойка сбита, удар проходит
		_guard_end(e)
		e.sp_dur = e.t + 0.5
		e.rig.play_for("Hit", 0.5, 0.05)
		g.popup(e.global_position + Vector3(0, e.height + 0.6, 0), "СТОЙКА СБИТА", Color(1.0, 0.85, 0.4))
		e.guard_log.append("broken")
		return false
	var at: Vector3 = e.global_position + Vector3(0, e.height * 0.6, 0) + f * 0.7
	g.feedback("block", at, f, 1.0, GUARD_COL)
	var P = g.player
	if e.age >= e.guard_next and P.global_position.distance_to(e.global_position) <= GUARD_REACH:
		e.guard_next = e.age + GUARD_GAP
		e.rig.play_for("Punch", 0.32, 0.04)
		e.rig.play("MGuard", 0.25)
		g.popup(e.global_position + Vector3(0, e.height + 0.6, 0), "ВЕРНУЛ", GUARD_COL)
		e.guard_log.append("return")
		P.take_damage(float(e.cfg["dmg"]) * GUARD_DMG, e.global_position, e)
	else:
		e.guard_log.append("absorb")
	return true

# ---------------------------------------------------------------- ЗАЦЕП ЦЕПИ
## Куда долетит цепь: [точка, "bars" | "board"]. Турник ловит цепь, если полоса проходит рядом; иначе — борт коробки.
static func hook_target(e) -> Array:
	var w = e.game.world
	var from: Vector3 = e.global_position
	var f := _front(e)
	var best := HOOK_LEN + 1.0
	var out: Array = []
	var pts: Array = w.get("hook_points") if w.get("hook_points") != null else []
	for p in pts:
		var d: Vector3 = (p as Vector3) - from
		d.y = 0
		var along := d.dot(f)
		if along < 2.0 or along > HOOK_LEN or along >= best:
			continue
		if (d - f * along).length() <= HOOK_SNAP:
			best = along
			out = [Vector3(p.x, 1.9, p.z), "bars"]
	if not out.is_empty():
		return out
	# борт: первая стенка прямоугольника коробки на пути
	var rc: Rect2 = w.get("hook_rect") if w.get("hook_rect") != null else Rect2(-14, -14, 28, 28)
	var tmax := HOOK_LEN
	if absf(f.x) > 0.001:
		tmax = minf(tmax, ((rc.end.x if f.x > 0.0 else rc.position.x) - from.x) / f.x)
	if absf(f.z) > 0.001:
		tmax = minf(tmax, ((rc.end.y if f.z > 0.0 else rc.position.y) - from.z) / f.z)
	tmax = maxf(tmax, 1.0)
	var at := from + f * tmax
	return [Vector3(at.x, 1.1, at.z), "board"]

## Герой на пути цепи? (полоса от Миши до точки зацепа)
static func in_hook(e, at: Vector3, reach: float) -> bool:
	var d: Vector3 = at - e.global_position
	d.y = 0
	var f := _front(e)
	var along := d.dot(f)
	return along >= 0.0 and along <= reach and (d - f * along).length() <= HOOK_HALF

static func _hook(e) -> void:
	var g = e.game
	_aim(e)
	e.tell_r = HOOK_LEN
	e.tell_half = 0.0
	e.tell_lane = HOOK_HALF
	g.fx.tell_shape(e.tell, e.global_position, e.face, HOOK_LEN, 0.0, HOOK_HALF, 0, e.cfg["tint"])
	e.tell_until = e.age + HOOK_WARN
	e.tell_sec = HOOK_WARN
	e.rig.play_for("Throw", HOOK_WARN / 0.55, 0.08)
	g.main.sfx("sfx_cast", -5.0, 0.8)
	e._at(HOOK_WARN, func():
		e._tell_end()
		var P = g.player
		var tg := hook_target(e)
		var anchor: Vector3 = tg[0]
		var flat := Vector3(anchor.x, e.global_position.y, anchor.z)
		var reach: float = flat.distance_to(e.global_position)
		g.main.sfx("sfx_swing_heavy", -1.0, 1.25)
		var chest: Vector3 = e.global_position + Vector3(0, e.height * 0.62, 0)
		if in_hook(e, P.global_position, reach) and P.inv <= 0.0 and P.state != "dead":
			# попал: бьёт и подтягивает к себе
			var f := _front(e)
			_chain(g, chest, P.global_position + Vector3(0, 1.0, 0), 0.45)
			P.take_damage(float(e.cfg["dmg"]) * HOOK_DMG, e.global_position, e)
			P.velocity = -f * 9.0
			e.hook_log.append("hit")
			e.sp_dur = HOOK_WARN + 0.7
			return
		# мимо: цепь намертво цепляется — Миша дёргает её и открыт
		_chain(g, chest, anchor, HOOK_OPEN)
		g.fx.twinkle(anchor, 8, Color(1.0, 0.85, 0.4), 0.9)
		g.main.sfx("sfx_block", -1.0, 1.3)
		e.hook_log.append(String(tg[1]))
		e.state = "stun"
		e.t = 0.0
		e.stun_t = HOOK_OPEN
		e.weak_t = HOOK_OPEN
		e.rig.play("MStuck", 0.1)
		g.popup(e.global_position + Vector3(0, e.height + 0.9, 0), "ЦЕПЬ ЗАЦЕПИЛАСЬ — ОТКРЫТ", Color(1.0, 0.5, 0.3))
		g.fx.boss_open(e))
	e.sp_dur = HOOK_WARN + 0.8

## Натянутая цепь между двумя точками: звенья, вылет за 0,15 с, через sec — убирается
static func _chain(g, from: Vector3, to: Vector3, sec: float) -> void:
	var len := from.distance_to(to)
	if len < 0.3:
		return
	var root := Node3D.new()
	root.name = "misha_hook_chain"
	g.world.add_child(root)
	root.global_position = from
	root.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
	var link := TorusMesh.new()
	link.inner_radius = 0.045
	link.outer_radius = 0.085
	link.rings = 10
	link.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.7, 0.22)
	mat.metallic = 0.9
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.6, 0.15)
	mat.emission_energy_multiplier = 0.35
	link.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	var n := clampi(int(len / 0.15), 2, 110)
	mm.instance_count = n
	for i in n:
		var b := Basis(Vector3(1, 0, 0), PI * 0.5)                     # кольцо вдоль цепи
		if i % 2 == 1:
			b = Basis(Vector3(0, 0, 1), PI * 0.5) * b                   # через одно — поперёк
		mm.set_instance_transform(i, Transform3D(b, Vector3(0, 0, -len * (float(i) + 0.5) / float(n))))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.scale = Vector3(1, 1, 0.02)
	var tw := root.create_tween()
	tw.tween_property(root, "scale:z", 1.0, 0.15)
	tw.tween_interval(maxf(0.05, sec - 0.3))
	tw.tween_property(root, "scale:z", 0.02, 0.15)
	tw.tween_callback(root.queue_free)
