## Ядро боя (этап 04): одно на все стили. Берёт атаки и граф комбо из StyleData и ведёт удар от нажатия до конца:
##   ввод → буфер → запуск атаки → фазы (замах / попадание / завершение) → окно комбо → следующая атака или выход.
## Владелец (player.gd) отвечает за тело: состояния move / attack / charge, скорость, поворот. Ядро говорит, что делать.
##
##  Буфер ввода    — нажатие помнится style.buffer секунд: нажал чуть раньше окна — удар всё равно продолжит цепочку,
##                   нажал слишком рано — нет (тайминг имеет значение, но не пиксельный).
##  Окно комбо     — [combo_from, combo_to] атаки: в нём буфер запускает следующую атаку по графу стиля.
##  Окно отмены    — перекат отменяет удар после roll_from (по умолчанию — сразу после первого попадания).
##  Завершение     — после recovery атака окончена; оборванная цепочка даёт паузу chain_cd перед новой.
##  Перезарядка    — cooldown атаки: раньше срока она не запустится.
##  Попадание      — в окне [hit, hit + hit_window] каждый кадр: дистанция и сектор (sector), у sweep — ещё путь оружия
##                   между кадрами против капсулы врага. Один удар бьёт одну цель один раз (журнал попаданий).
##  Урон           — damage_for(): база атаки × ПЕРЕГРУЗ × множители; цель получает HitInfo (урон, равновесие, подброс…).
class_name Combat
extends RefCounted

const HOLD_MIN := 0.16        # удержание короче — это нажатие, а не заряд

signal attack_started(a: AttackData)
signal attack_hit(a: AttackData, targets: int)
signal attack_ended(a: AttackData, chained: bool)

var p                         # владелец (CharacterBody3D с rig, face, velocity, swag, rage…)
var game
var style: StyleData
var cur: AttackData           # текущая атака (null — нет)
var prev_id := ""             # предыдущая атака цепочки ("" — цепочка с нуля)
var chain := 0                # номер удара в цепочке, с нуля
var t := 0.0                  # время в атаке, с
var hit_i := 0
var whoosh_i := 0
var slam_done := false
var scrape_done := false
var drop_done := false
var hit_log := {}             # номер попадания → {id цели: true}
var buf_action := ""          # буфер ввода: что нажато и когда
var buf_time := -9.0
var clock := 0.0
var cooldowns := {}           # id атаки → когда снова можно
var chain_block := 0.0        # до какого времени нельзя начать новую цепочку
var dodge_until := -9.0       # до какого времени действует «атака после уклонения»
var heat_q: Array = []
var charge_t := 0.0
var charged := 0.0            # заряд, с которым выпущен текущий удар
var maxed := false
var charge_snd := false        # звук заряда — только если кнопку действительно держат
var ring_cd := 0.0
var tip_prev := Vector3.ZERO  # конец оружия на прошлом кадре (для sweep)
var tip_ok := false
var ammo := {}                # id стиля → запас (бутылки)
var ammo_msg := -9.0
var last_hits := 0            # сколько целей задел последний момент попадания (для проверок)

func _init(owner, g, s: StyleData) -> void:
	p = owner
	game = g
	style = s

## каждый физический кадр: часы ядра и восстановление запаса стилей
func tick(dt: float) -> void:
	clock += dt
	for id in ammo:
		var st: StyleData = Styles.by_id(id)
		if st.ammo_regen > 0.0 and float(ammo[id]) < st.ammo_max:
			ammo[id] = min(float(st.ammo_max), float(ammo[id]) + dt / st.ammo_regen)

func ammo_of(id: String) -> float:
	if not ammo.has(id):
		ammo[id] = float(Styles.by_id(id).ammo_max)
	return ammo[id]

## сменить стиль: текущая атака обрывается, буфер ввода сохраняется (нажатое во время смены сработает после)
func set_style(s: StyleData) -> void:
	interrupt()
	style = s
	if s.ammo_max > 0:
		ammo_of(s.id)

func k() -> float:
	return t / cur.duration if cur != null else 0.0

## фаза текущей атаки: startup (до первого попадания), active (окна попаданий), recovery (после), "" — атаки нет
func phase() -> String:
	if cur == null:
		return ""
	var kk := k()
	if kk < float(cur.hits[0]):
		return "startup"
	if kk <= float(cur.hits[cur.hits.size() - 1]) + cur.hit_window:
		return "active"
	return "recovery"

func in_combo_window() -> bool:
	return cur != null and k() > cur.combo_from and k() <= cur.combo_to

func can_roll_cancel() -> bool:
	if cur == null or not heat_q.is_empty():
		return false
	var from := cur.roll_from if cur.roll_from >= 0.0 else float(cur.hits[0]) + 0.06
	return k() > from

# ---------------- ввод ----------------
## нажатие запоминается в буфере (light / heavy)
func press(action: String) -> void:
	buf_action = action
	buf_time = clock

func buffered() -> String:
	return buf_action if clock - buf_time <= style.buffer else ""

func clear_buffer() -> void:
	buf_action = ""

func ready_at(a: AttackData) -> bool:
	if a == null or clock < float(cooldowns.get(a.id, -9.0)):
		return false
	if a.ammo > 0 and ammo_of(style.id) < a.ammo:
		if clock - ammo_msg > 1.2:
			ammo_msg = clock
			game.popup(p.global_position + Vector3(0, 2.2, 0), "пусто — подожди", Color(0.7, 0.85, 1.0))
		return false
	return true

## Из стойки: если в буфере есть нажатие и можно начать — начинает. true — атака (или заряд) пошла.
func try_start() -> bool:
	var act := buffered()
	if act == "" or not style.ready:
		return false
	var a: AttackData = null
	var from_dodge := false
	if clock <= dodge_until and style.after_dodge.has(act):
		a = style.attack(style.after_dodge[act])     # атака сразу после уклонения: оружие уже в движении
		from_dodge = a != null
	if a == null:
		if act == "light" and clock < chain_block:
			return false                               # пауза после оборванной цепочки: нельзя спамить первым ударом
		a = style.next("", act)
	if not ready_at(a):
		return false
	clear_buffer()
	dodge_until = -9.0
	chain = 0
	prev_id = ""
	begin(a, from_dodge)
	return true

## уклонение закончено: на короткое время открыты «атаки после уклонения»
func dodged() -> void:
	dodge_until = clock + style.dodge_window

# ---------------- запуск ----------------
## начать атаку (или её заряд). chained — удар продолжает цепочку: клип стартует с a.from.
func begin(a: AttackData, chained := false) -> void:
	if a.charge and not chained_charge_skip:
		_begin_charge(a)
		return
	_launch(a, chained)

var chained_charge_skip := false   # внутреннее: заряд уже набран, запускаем сам удар

func _launch(a: AttackData, chained: bool) -> void:
	cur = a
	t = 0.0
	hit_i = 0
	whoosh_i = 0
	slam_done = false
	scrape_done = false
	drop_done = false
	hit_log = {}
	tip_ok = false
	charged = 0.0
	p.state = "attack"
	p.face = target_face(a.reach, p.input_dir())
	p.body.rotation.y = p.face
	p.rig.play_for(a.clip, a.duration, 0.12 if chained else 0.08)
	if chained and a.from > 0.0:
		t = a.from * a.duration
		p.rig.player.seek(a.from * p.rig.clip_len(a.clip), true)
	p.trail.boost = a.trail_boost
	p.trail.set_color(style.color_hot if a.power >= 2 or p.rage > 0.0 else style.color)
	if a.cooldown > 0.0:
		cooldowns[a.id] = clock + a.cooldown
	attack_started.emit(a)

func _begin_charge(a: AttackData) -> void:
	cur = a
	p.state = "charge"
	t = 0.0
	charge_t = 0.0
	ring_cd = 0.0
	maxed = false
	p.face = target_face(4.0, p.input_dir())
	p.rig.play(a.charge_clip if a.charge_clip != "" else style.charge_clip, 0.12)
	charge_snd = false

## Heat-действие стиля: цепочка атак style.heat подряд
func begin_heat() -> void:
	heat_q = []
	for i in range(1, style.heat.size()):
		heat_q.append(style.attack(style.heat[i]))
	chain = 0
	prev_id = ""
	_launch(style.attack(style.heat[0]), false)

# ---------------- цель ----------------
## Куда бить: к ближайшему врагу в секторе перед собой (по движению или по камере), иначе — просто вперёд
func target_face(reach: float, want: Vector3) -> float:
	var a: Vector3 = want.normalized() if want.length() > 0.3 else p.aim_dir()
	var best := Vector3.ZERO
	var bs := -1.0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > reach + 1.2 or dist < 0.05:
			continue
		var ang := a.angle_to(d / dist)
		if ang > 1.05:
			continue
		var score := (1.0 - ang / 1.05) * 2.0 + (1.0 - dist / (reach + 1.2))
		if score > bs:
			bs = score
			best = d
	if bs >= 0.0:
		return atan2(best.x, best.z)
	return atan2(a.x, a.z)

## вплотную перед нами враг — в него не шагаем
func blocked(fwd: Vector3) -> bool:
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var d: Vector3 = e.global_position - p.global_position
			d.y = 0
			if d.length() < 1.15 + e.radius and d.normalized().dot(fwd) > 0.4:
				return true
	return false

# ---------------- кадр атаки ----------------
## Состояние "attack": шаг в удар, звуки замаха, попадания, удары в землю, окно комбо, конец. dir — ввод движения.
func tick_attack(dt: float, dir: Vector3) -> void:
	var a := cur
	if a == null:
		p.state = "move"
		return
	t += dt
	var kk := k()
	var fwd := Vector3(sin(p.face), 0, cos(p.face))
	if a.step.size() == 3 and kk >= float(a.step[0]) and kk < float(a.step[1]) and not blocked(fwd):
		# шаг в удар: тело идёт за оружием
		p.velocity.x = fwd.x * float(a.step[2])
		p.velocity.z = fwd.z * float(a.step[2])
	else:
		p.velocity.x = move_toward(p.velocity.x, 0.0, 45.0 * dt)
		p.velocity.z = move_toward(p.velocity.z, 0.0, 45.0 * dt)
	var hs: Array = a.hits
	while whoosh_i < hs.size() and kk >= float(hs[whoosh_i]) - 0.12:
		whoosh_i += 1
		game.main.sfx(a.sfx_swing if a.sfx_swing != "" else ("sfx_swing_heavy" if a.heavy else "sfx_swing"), -3.0, 0.85 if a.power >= 2 else 1.0)
	# моменты попадания: каждый открывает окно, в котором цель может быть задета один раз
	while hit_i < hs.size() and kk >= float(hs[hit_i]):
		hit_i += 1
		if a.projectile != "":
			# дистанционная атака: в момент «попадания» снаряд вылетает из руки, урон нанесёт он сам
			ammo[style.id] = max(0.0, ammo_of(style.id) - a.ammo)
			p.launch_projectile(a, charged)
		else:
			_resolve_hits(hit_i - 1, hit_log.get(hit_i - 1, {}).is_empty())
	if a.detect == "sweep" and hit_i < hs.size() and kk >= float(hs[hit_i]) - a.hit_lead:
		_resolve_hits(hit_i, hit_log.get(hit_i, {}).is_empty(), true)     # хитбокс оружия открыт ещё до момента удара: задевает по пути
	if a.projectile == "" and hit_i > 0 and kk <= float(hs[hit_i - 1]) + a.hit_window:
		_resolve_hits(hit_i - 1, false)      # окно ещё открыто: добираем тех, кто вошёл в зону позже
	_track_tip()
	if a.slam >= 0.0 and not slam_done and kk >= a.slam:
		slam_done = true
		_slam(fwd)
	if a.scrape >= 0.0 and not scrape_done and kk >= a.scrape:
		scrape_done = true
		var wp: Array = p.rig.weapon_points()
		if not wp.is_empty():
			game.fx.scrape(wp[1], fwd)
			game.main.sfx("sfx_slash", -10.0, 0.7)
	if a.drop >= 0.0 and not drop_done and kk >= a.drop:
		drop_done = true
		# оружие после удара падает на землю
		var wpd: Array = p.rig.weapon_points()
		game.feedback("drop", wpd[1] if not wpd.is_empty() else p.global_position + fwd, fwd, 1.0, style.color)
	# вертушка: разгон и торможение, а не ровное вращение
	p.spin_off = -TAU * a.spin * smoothstep(0.14, 0.88, kk)
	# комбо: ввод из буфера срабатывает в окне комбо; тяжёлые цепочку лёгким не продолжают
	var nxt: AttackData = null
	var act := buffered()
	if heat_q.is_empty() and act != "":
		nxt = style.next(a.id, act)
		if not ready_at(nxt):
			nxt = null
	if p.pressed("roll") and can_roll_cancel():
		p.spin_off = 0.0
		_end(false)
		p.start_roll(dir)
	elif not heat_q.is_empty() and kk > a.combo_from:
		p.spin_off = 0.0
		var h: AttackData = heat_q.pop_front()
		attack_ended.emit(a, true)
		_launch(h, false)
	elif nxt != null and kk > a.combo_from and kk <= a.combo_to:
		p.spin_off = 0.0
		clear_buffer()
		prev_id = a.id
		chain = 0 if act == "heavy" else chain + 1     # тяжёлый завершает цепочку: его отклик не растёт от числа лёгких
		attack_ended.emit(a, true)
		begin(nxt, true)
	elif kk >= a.recovery:
		p.spin_off = 0.0
		_end(true)
		p.state = "move"

func _end(natural: bool) -> void:
	var a := cur
	if natural and chain_block < clock + style.chain_cd and a != null and not a.heavy:
		chain_block = clock + style.chain_cd     # цепочка оборвалась сама: короткая пауза перед новой
	cur = null
	chain = 0
	prev_id = ""
	heat_q = []
	if a != null:
		attack_ended.emit(a, false)

## владелец прервал атаку (получил урон, погиб, начался диалог)
func interrupt() -> void:
	if cur != null:
		_end(false)
	p.aim_preview(null, 0.0)
	p.spin_off = 0.0
	game.charge_zoom = 0.0

# ---------------- заряд ----------------
## Состояние "charge": удержание тяжёлого копит заряд; отпустил или набрал максимум — удар.
func tick_charge(dt: float, dir: Vector3) -> void:
	p.velocity.x = move_toward(p.velocity.x, 0.0, 30.0 * dt)
	p.velocity.z = move_toward(p.velocity.z, 0.0, 30.0 * dt)
	charge_t = min(style.charge_max, charge_t + dt)
	if charge_t < HOLD_MIN and p.held("heavy"):
		return                      # короткое нажатие — обычный удар без заряда: ни звука, ни колец
	if not charge_snd and p.held("heavy"):
		charge_snd = true
		game.main.sfx("sfx_charge", -4.0)
	p.face = lerp_angle(p.face, target_face(max(4.0, cur.reach), dir), 1.0 - exp(-10.0 * dt))
	if cur.projectile != "":
		p.aim_preview(cur, charge_t / style.charge_max)      # прицел: траектория броска
	# заряд видно и слышно: кольца стягиваются к ногам, оружие светится, камера поджимается и дрожит
	var c := charge_t / style.charge_max
	ring_cd -= dt
	if ring_cd <= 0.0 and cur.projectile == "":
		ring_cd = 0.24 - 0.1 * c
		game.fx.ground_ring(p.global_position, 3.2 + 1.5 * c, 0.5, Color(1.0, 0.6 - 0.2 * c, 0.2, 0.55), 0.26)
	game.charge_zoom = c * (0.4 if cur.projectile != "" else 1.0)
	if cur.projectile == "":
		game.rumble(0.1 + 0.16 * c)
	if charge_t >= style.charge_max * 0.79 and not maxed and cur.projectile != "":
		maxed = true
		game.main.sfx("sfx_ui", -6.0, 1.4)
	if charge_t >= style.charge_max * 0.79 and not maxed:
		maxed = true
		var wp2: Array = p.rig.weapon_points()
		if not wp2.is_empty():
			game.fx.flash(wp2[1], 1.6, Color(1.0, 0.75, 0.4), "magic_03", 0.3)
		game.main.sfx("sfx_parry", -6.0, 1.5)
		game.popup(p.global_position + Vector3(0, 2.3, 0), "МАКС!", Color(1, 0.6, 0.2))
	if not p.held("heavy") or (charge_t >= style.charge_max and cur.projectile == ""):
		p.aim_preview(null, 0.0)
		# заряд усиливает удар: урон, отбрасывание, подброс, равновесие; больше половины — отклик как у добивания
		var keep := charge_t * cur.charge_gain
		var fs: AttackData = cur.with({"damage": cur.damage * (1.0 + keep), "knockback": cur.knockback * (1.0 + keep * 0.5), "launch": cur.launch + keep * 2.0,
			"stagger": cur.stagger * (1.0 + keep), "power": 2 if keep > 0.6 else cur.power, "trail_boost": 1.5 if keep > 0.6 else cur.trail_boost})
		var real := charge_t >= HOLD_MIN + 0.1
		if not real:
			keep = 0.0
			fs = cur
		# после настоящего заряда оружие уже занесено: удар стартует с charged_from
		var skip := real and cur.charged_from > 0.0
		if skip:
			fs = fs.with({"from": cur.charged_from})
		_launch(fs, skip)
		charged = keep
		game.charge_zoom = 0.0

# ---------------- попадания ----------------
func _track_tip() -> void:
	var wp: Array = p.rig.weapon_points()
	if wp.is_empty():
		tip_ok = false
		return
	tip_prev = wp[1]
	tip_ok = true

## Кого задевает атака прямо сейчас. Возвращает [[враг, направление удара], …]; уже задетых этим моментом — пропускает.
func targets(a: AttackData, idx: int, sweep_only := false) -> Array:
	var out := []
	var fwd := Vector3(sin(p.face), 0, cos(p.face))
	var seen: Dictionary = hit_log.get(idx, {})
	var wp: Array = p.rig.weapon_points() if a.detect == "sweep" else []
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive() or seen.has(e.get_instance_id()):
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		var dn: Vector3 = d.normalized() if d.length() > 0.01 else fwd
		var hit: bool = not sweep_only and d.length() <= a.reach + 0.4 and (d.length() <= 0.5 or fwd.angle_to(dn) <= a.arc * 0.5)
		if not hit and not wp.is_empty() and d.length() <= a.reach + 1.0:
			# sweep: путь конца оружия за кадр и само оружие против капсулы врага (хёртбокс: радиус и высота врага)
			var r: float = float(e.radius) + a.radius
			var top: float = e.global_position.y + float(e.height)
			var segs := [[wp[0], wp[1]]]
			if tip_ok:
				segs.append([tip_prev, wp[1]])
			for sg in segs:
				var c: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3(e.global_position.x, clampf(((sg[0] as Vector3).y + (sg[1] as Vector3).y) * 0.5, e.global_position.y, top), e.global_position.z), sg[0], sg[1])
				if Vector2(c.x - e.global_position.x, c.z - e.global_position.z).length() <= r and c.y >= e.global_position.y - 0.2 and c.y <= top + 0.2:
					hit = true
					break
		if hit:
			out.append([e, dn])
	return out

## Урон атаки по цели: база × ПЕРЕГРУЗ × множители. Одна точка для будущих баффов, навыков и мастерства стиля.
func damage_for(a: AttackData, _target = null) -> float:
	return a.damage * (1.6 if p.rage > 0.0 else 1.0) * float(p.dmg_mul)

func _resolve_hits(idx: int, first: bool, sweep_only := false) -> void:
	var a := cur
	var list := targets(a, idx, sweep_only)
	if first:
		last_hits = 0
	if list.is_empty():
		return
	if not hit_log.has(idx):
		hit_log[idx] = {}
	var last: bool = idx >= a.hits.size() - 1
	var launch := a.launch
	if last and a.last_launch != 0.0:
		launch = a.last_launch
	# сила отклика: у серии ударов тяжёлым считается только последний
	var power := a.power
	if a.hits.size() > 1 and not last:
		power = 0
	var col: Color = style.color_hot if p.rage > 0.0 or power == 2 else style.color
	var fwd := Vector3(sin(p.face), 0, cos(p.face))
	var where: Vector3 = p.global_position + fwd * 1.3 + Vector3(0, 1.1, 0)
	var n := 0
	for it in list:
		var e = it[0]
		var dn: Vector3 = it[1]
		(hit_log[idx] as Dictionary)[e.get_instance_id()] = true
		where = e.global_position + Vector3(0, e.height * 0.62, 0) - dn * e.radius
		var h := HitInfo.new()
		h.damage = damage_for(a, e)
		h.stagger = a.stagger
		h.dir = dn
		h.knockback = a.knockback
		h.launch = launch
		h.stun = a.stun
		h.heavy = a.heavy
		h.power = power
		h.attack_id = a.id
		h.style_id = style.id
		h.source = p
		h.pos = where
		e.take_hit_info(h)
		game.fx.hit(where, dn, power if last_hits + n < 2 else 0, col)
		n += 1
	var was := last_hits
	last_hits += n
	p.swag = min(100.0, p.swag + 6.0 * n)
	if was > 0:
		return                        # цель вошла в зону позже: урон есть, общий отклик уже был
	if a.title != "" and idx == 0:
		game.popup(p.global_position + Vector3(0, 2.4, 0), a.title, Color(1, 0.8, 0.3))
	game.main.sfx("sfx_glass" if randf() < 0.5 else "sfx_hit", -2.0)
	var snd: Array = a.sfx_hit if not a.sfx_hit.is_empty() else (style.hit_sfx[clampi(power, 0, style.hit_sfx.size() - 1)] if not style.hit_sfx.is_empty() else [])
	for s in snd:
		game.main.sfx(s[0], float(s[1]), float(s[2]))
	var ev: String = a.feedback if a.feedback != "" and (last or a.hits.size() == 1) else ["hit_light", "hit_heavy", "hit_super"][clampi(power, 0, 2)]
	if power == 2 and a.feedback != "" and charged > 0.6:
		ev = "hit_super"                # полный заряд: отклик как у добивания
	game.feedback(ev, where, fwd, 1.0 + charged * 0.4 + chain * 0.18, col)
	if power == 2 or a.title != "":
		game.bark("finish", 9.0, 0.7)
	attack_hit.emit(a, n)

## оружие вошло в землю
func _slam(fwd: Vector3) -> void:
	var at: Vector3 = p.global_position + fwd * 1.35
	var wp: Array = p.rig.weapon_points()
	if not wp.is_empty():
		at = wp[1]
	var big := cur.power >= 2
	game.fx.slam(at, 1.35 if big else 1.0, style.color_hot if big or p.rage > 0.0 else style.color)
	game.main.sfx("sfx_boom", 0.0, 0.9 if big else 1.1)
	game.shake(0.6 if big else 0.42)
	game.punch(1.0 if big else 0.5, at)
