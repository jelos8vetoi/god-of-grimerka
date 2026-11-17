## Tag Team (этап 10): Пахан и madk1d — одна команда. Игрок ведёт одного, второй — напарник под управлением игры.
##   [Tab] — смена героя. У каждого своё здоровье; стиль, запасы и перезарядки каждого сохраняются.
##   Смена по обстановке (командные приёмы, вошедший герой появляется у цели):
##     в ударе после лёгкого попадания      — TAG ATTACK;
##     в ударе-подбросе или цель в воздухе  — TAG LAUNCHER (цель и герой взлетают — дальше удары в воздухе);
##     в тяжёлом ударе после попадания      — DOUBLE IMPACT (бьют оба);
##     в окне после парирования / уклонения — TAG COUNTER.
##   [T] — помощь напарника, не меняя героя: цель в воздухе — AIR PARTNER COMBO, иначе CROSS ATTACK.
##   Добивание рядом с напарником — TEAM FINISHER (execution.team_hook).
## Ограничения: смена не работает, пока героя бьют (состояние hurt), в добивании и в смене стиля; пауза между
## сменами 2 с, после командного приёма 5 с. Половина полученного урона («серое» здоровье) восстанавливается,
## только пока герой отдыхает напарником. Героя с нулём здоровья уносит на REVIVE секунд; выбыли оба — поражение.
## Напарник сам бьёт врагов рядом с игроком (слабо и не насмерть), отходит от замахов и не лезет под камеру.
class_name TagTeam
extends Node

signal tagged(hero: String, move: String)

const TAG_CD := 2.0
const TEAM_CD := 5.0
const ASSIST_CD := 6.0
const REVIVE := 18.0
const GREY := 0.5            # какая доля урона восстановима
const REGEN := 3.0           # здоровья в секунду у отдыхающего
const BOOST := 1.3           # урон вошедшего героя после командного приёма
const TITLES := {"attack": "TAG ATTACK", "launcher": "TAG LAUNCHER", "double": "DOUBLE IMPACT", "counter": "TAG COUNTER", "cross": "CROSS ATTACK", "air": "AIR PARTNER COMBO", "finisher": "TEAM FINISHER",
	"air_relay": "AIR RELAY", "ground_relay": "GROUND RELAY", "rescue": "RESCUE TAG", "perfect": "PERFECT TAG", "air_tag": "AIR TAG"}
const RESCUE_CD := 8.0        # спасение из-под удара — не чаще
var rescue_cd := 0.0
var relay := {}               # идущая вторая половина AIR RELAY: {e, t, dir}

var game
var p
var b
var hp := {"pahan": 100.0, "madk1d": 100.0}
var grey := {"pahan": 0.0, "madk1d": 0.0}
var down := {"pahan": false, "madk1d": false}
var revive_t := {"pahan": 0.0, "madk1d": 0.0}
var tag_cd := 0.0
var assist_cd := 0.0
var duo: Duo                 # дуэт-атака на [T] (duo.gd)
# AIR TAG: враг в воздухе — Tab передаёт комбо напарнику; подсказка у врага
const AIR_TAGS_MAX := 3       # передач за один полёт врага (дальше Tab — обычная смена)
const AIR_TAG_RANGE := 7.5
const AIR_TAG_CD := 0.35      # после передачи можно передать обратно почти сразу
var hint: Label3D             # подсказка «[TAB] …» у цели
var hint_kind := ""
var hint_e = null
var boost_t := 0.0
var auto_assist := true      # напарник сам вступает в бой
var auto_t := 3.0
var cur_hero := ""
var last_hp := 100.0
var last_max := 100.0
var events: Array = []       # для проверок: [что, герой]

func setup(g) -> void:
	game = g
	p = g.player
	b = g.buddy
	# герои друг с другом не сталкиваются: при смене напарник встаёт туда, где только что стоял игрок,
	# и раньше его выталкивало вверх и в сторону
	auto_assist = game.main.testing() == ""      # в проверках напарник сам не дерётся, пока проверка не включит его
	duo = Duo.new()
	add_child(duo)
	duo.setup(self)
	hint = Label3D.new()
	hint.font = game.main.font
	hint.font_size = 34
	hint.pixel_size = 0.004
	hint.outline_size = 10
	hint.outline_modulate = Color(0, 0, 0, 0.85)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.no_depth_test = true
	hint.visible = false
	game.add_child(hint)
	b.add_collision_exception_with(p)
	p.add_collision_exception_with(b)
	reset()
	p.execution.team_hook = _team_finish

func reset() -> void:
	if duo != null:
		duo.reset()
	_hide_hint()
	for h in hp:
		hp[h] = p.max_hp
		grey[h] = 0.0
		down[h] = false
		revive_t[h] = 0.0
	cur_hero = p.hero
	last_hp = p.hp
	last_max = p.max_hp
	tag_cd = 0.0
	assist_cd = 0.0
	boost_t = 0.0
	if b.ko:
		b.revive()

func mate() -> String:
	return "madk1d" if p.hero == "pahan" else "pahan"

func bonus() -> float:
	return BOOST if boost_t > 0.0 else 1.0

func _physics_process(dt: float) -> void:
	if game == null or p == null:
		return
	# героя сменили (Tab или проверка напрямую): у вошедшего своё здоровье
	if p.hero != cur_hero:
		cur_hero = p.hero
		p.hp = max(1.0, float(hp[cur_hero]))
		last_hp = p.hp
	if p.max_hp != last_max:
		hp[mate()] = clampf(float(hp[mate()]) + (p.max_hp - last_max), 1.0, p.max_hp)
		last_max = p.max_hp
	if p.hp < last_hp:
		grey[cur_hero] = float(grey[cur_hero]) + (last_hp - p.hp) * GREY
	last_hp = p.hp
	hp[cur_hero] = p.hp
	if game.paused_story() or game.over:
		return
	tag_cd = max(0.0, tag_cd - dt)
	_hint_tick()
	rescue_cd = max(0.0, rescue_cd - dt)
	if not relay.is_empty():
		# вторая половина AIR RELAY: напарник вбивает переданного врага в землю
		relay["t"] = float(relay["t"]) - dt
		if float(relay["t"]) <= 0.0:
			var re = relay["e"]
			var rd: Vector3 = relay["dir"]
			relay = {}
			if is_instance_valid(re) and re.alive():
				strike(re, 20.0, 30.0, rd, 3.0, -16.0, true, 1)
				game.fx.sparks(re.global_position + Vector3(0, 1.0, 0), Vector3.DOWN, 10, Color(1, 1, 1, 0.9), 1.0, 40.0)
				events.append(["relay_slam", mate()])
	assist_cd = max(0.0, assist_cd - dt)
	boost_t = max(0.0, boost_t - dt)
	var o := mate()
	if down[o]:
		revive_t[o] = float(revive_t[o]) - dt
		if float(revive_t[o]) <= 0.0:
			down[o] = false
			hp[o] = p.max_hp * 0.3
			grey[o] = 0.0
			b.revive()
			game.popup(b.global_position + Vector3(0, 2.2, 0), "%s СНОВА В БОЮ" % ("MADK1D" if o == "madk1d" else "ПАХАН"), Color(0.6, 1.0, 0.7))
			events.append(["revive", o])
	elif float(grey[o]) > 0.0:
		var r: float = min(float(grey[o]), REGEN * dt)
		grey[o] = float(grey[o]) - r
		hp[o] = min(p.max_hp, float(hp[o]) + r)
	_ai(dt)

# ---------------- смена героя ----------------
## Почему сейчас нельзя сменить героя ("" — можно)
func tag_block() -> String:
	if game.paused_story() or game.over:
		return "story"
	if down[mate()]:
		return "down"
	if tag_cd > 0.0:
		return "cooldown"
	if p.switch_to != "":
		return "switch"
	if duo != null and duo.active() and not (duo.relay_open() and air_target() != null):
		return "duo"           # идёт дуэт-атака: сменить героя нельзя, пока не кончится (кроме передачи по воздуху)
	if p.state == "hurt" and rescue_cd <= 0.0:
		return ""               # RESCUE TAG: напарник вытаскивает из-под ударов
	if not p.state in ["move", "block", "attack", "tyaga", "skate"]:
		return p.state          # hurt, roll, exec, rage, dead, charge…
	return ""

## Цель команды: ближайший враг перед героем
func target():
	var best = null
	var bs := -1e9
	var fw := Vector3(sin(p.face), 0, cos(p.face))
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > 5.5:
			continue
		var sc: float = -dist + (d / max(dist, 0.001)).dot(fw) * 1.5
		if sc > bs:
			bs = sc
			best = e
	return best

## Какой командный приём даст смена прямо сейчас ("" — обычная смена)
func context(e) -> String:
	if p.state == "hurt":
		return "rescue"
	if e == null:
		return ""
	# враг уже замахнулся на героя — смена в этот момент точная
	for en in game.enemies:
		if is_instance_valid(en) and en.alive() and en.state == "wind" and en.global_position.distance_to(p.global_position) < 3.4:
			return "perfect"
	var w: Dictionary = p.combat.windows
	var now: float = p.combat.clock
	if now <= float(w.get("parry", -9.0)) or now <= float(w.get("perfect", -9.0)) or now <= float(w.get("dodge", -9.0)):
		return "counter"
	var a: AttackData = p.combat.cur
	if e.state in ["down", "getup"]:
		return "ground_relay"         # враг на земле — вошедший добивает по лежачему
	if e.state == "air" and not p.is_on_floor():
		return "air_relay"            # оба в воздухе — передача врага по воздуху
	if p.state == "attack" and a != null and p.combat.hit_i > 0:
		if a.kind == "launcher" or a.launch > 0.0 or e.state == "air":
			return "launcher"
		if a.heavy or a.power >= 1:
			return "double"
		return "attack"
	return ""

func try_tag() -> bool:
	var why := tag_block()
	if why != "":
		if why in ["hurt", "cooldown", "down"] and game.clock - _msg_t > 0.8:
			_msg_t = game.clock
			game.popup(p.global_position + Vector3(0, 2.3, 0), {"hurt": "не сейчас", "cooldown": "рано", "down": "напарник выбыл"}[why], Color(0.75, 0.78, 0.85))
		events.append(["blocked", why])
		return false
	var ae = air_target()
	if ae != null:
		return _air_tag(ae)
	var e = target()
	var ctx := context(e)
	if ctx in ["rescue", "perfect"]:
		# цель — тот, кто бьёт: ближайший из замахнувшихся и атакующих
		var nd := 4.5
		for en in game.enemies:
			if is_instance_valid(en) and en.alive() and en.state in ["wind", "recover", "charge", "special"] and en.global_position.distance_to(p.global_position) < nd:
				nd = en.global_position.distance_to(p.global_position)
				e = en
		if e == null:
			e = target()
		if ctx == "rescue":
			rescue_cd = RESCUE_CD
			p.state = "move"      # урон оборван: герой уходит из-под ударов
			p.inv = max(p.inv, 0.6)
	var old_pos: Vector3 = p.global_position
	if not game.swap_heroes():
		return false
	tag_cd = TAG_CD
	if ctx != "" and e != null and is_instance_valid(e) and e.alive():
		_team_move(ctx, e, old_pos)
	events.append([ctx if ctx != "" else "tag", p.hero])
	tagged.emit(p.hero, ctx)
	return true
var _msg_t := -9.0

# ---------------- AIR TAG ----------------
## Враг в воздухе, которому можно передать комбо: обычный (не босс), рядом с героем, напарник досягает и свободен,
## и передач за этот полёт меньше AIR_TAGS_MAX. Несколько в воздухе — ближайший по направлению взгляда.
func air_target():
	if down[mate()] or b.ko or (duo != null and duo.active() and not duo.relay_open()):
		return null
	if p.state in ["hurt", "dead", "exec", "overdrive", "roll"] or p.switch_to != "":
		return null
	var best = null
	var bs := -1e9
	var aim: Vector3 = p.aim_dir()
	for en in game.enemies:
		if not is_instance_valid(en) or not en.alive() or en.state != "air" or en.boss_id != "":
			continue
		if int(en.air_tags) >= AIR_TAGS_MAX:
			continue
		var d: Vector3 = en.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > AIR_TAG_RANGE or b.global_position.distance_to(en.global_position) > AIR_TAG_RANGE + 4.0:
			continue
		if en.global_position.y - p.global_position.y < 0.6 and en.velocity.y < 0.0:
			continue                 # уже у самой земли и падает: не успеть
		var sc: float = -dist + (d / max(dist, 0.001)).dot(aim) * 2.0
		if sc > bs:
			bs = sc
			best = en
	return best

## сколько врагов сейчас можно продолжить в воздухе (для подсказки AIR RELAY)
func air_count() -> int:
	var n := 0
	for en in game.enemies:
		if is_instance_valid(en) and en.alive() and en.state == "air" and en.boss_id == "" and int(en.air_tags) < AIR_TAGS_MAX and en.global_position.distance_to(p.global_position) < AIR_TAG_RANGE:
			n += 1
	return n

func _air_tag(ae) -> bool:
	if duo.active():
		duo._done()                  # передача из середины AIR TAG: прошлый герой отпускает цель
	var old_hero: String = p.hero
	if not game.swap_heroes(true):
		return false
	tag_cd = AIR_TAG_CD
	# камера коротко доворачивает к передаче: в кадре цель и вошедший герой
	var cd2: Vector3 = ae.global_position - p.global_position
	if Vector2(cd2.x, cd2.z).length() > 0.3:
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(-cd2.x, -cd2.z), 0.3)
	boost_t = 2.0
	ae.air_tags = int(ae.air_tags) + 1
	# ушедший герой — теперь напарник: короткий удар-поддержка снизу, и в сторону
	b.strike_anim("air", ae.global_position)
	var col: Color = p.style.color_hot
	game.popup(ae.global_position + Vector3(0, float(ae.height) + 0.9, 0), "AIR TAG" if air_count() < 2 else "AIR RELAY", col)
	game.fx.sparks(ae.global_position + Vector3(0, float(ae.height) * 0.5, 0), Vector3.UP, 10, col, 0.9, 50.0)
	duo.air_tag(ae)
	events.append(["air_tag", p.hero, old_hero])
	tagged.emit(p.hero, "air_tag")
	_hide_hint()
	return true

## Подсказка у цели: показывается одна — та, что сработает по Tab прямо сейчас.
func _hint_tick() -> void:
	var kind := ""
	var at = null
	if tag_block() == "" or (duo != null and duo.relay_open()):
		var ae = air_target()
		if ae != null:
			kind = "AIR RELAY" if air_count() >= 2 else "AIR TAG"
			at = ae
		elif not game.paused_story() and duo != null and not duo.active():
			for en in game.enemies:
				if is_instance_valid(en) and en.alive() and en.state == "wind" and en.global_position.distance_to(p.global_position) < 3.4:
					kind = "PERFECT TAG"
					at = en
					break
	if kind == "":
		_hide_hint()
		return
	if kind != hint_kind or at != hint_e:
		hint_kind = kind
		hint_e = at
		hint.text = "[TAB] " + kind + ("\nПРОДОЛЖИ КОМБО" if kind != "PERFECT TAG" else "")
		hint.modulate = Color(1.0, 0.86, 0.35) if kind != "PERFECT TAG" else Color(1.0, 0.55, 0.4)
		hint.scale = Vector3.ONE * 0.6
		var tw := hint.create_tween()
		tw.tween_property(hint, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hint.visible = true
	# рядом с врагом, сбоку и выше — не в центре экрана и не поверх цифр урона
	var cam_r: Vector3 = Vector3(cos(game.cam_yaw), 0, -sin(game.cam_yaw))
	hint.global_position = at.global_position + Vector3(0, float(at.height) + 0.35, 0) + cam_r * 0.9

func _hide_hint() -> void:
	if hint != null:
		hint.visible = false
	hint_kind = ""
	hint_e = null

## Вошедший герой появляется у цели и бьёт; что именно — по обстановке
func _team_move(ctx: String, e, old_pos: Vector3) -> void:
	tag_cd = TEAM_CD
	boost_t = 2.5
	# встать с другой стороны цели от ушедшего героя
	var side: Vector3 = e.global_position - old_pos
	side.y = 0
	side = side.normalized() if side.length() > 0.2 else Vector3(sin(p.face), 0, cos(p.face))
	var at: Vector3 = e.global_position + side * 1.5
	if not game.in_arena(at, 0.6):
		at = e.global_position + side.cross(Vector3.UP) * 1.5
	at.y = e.global_position.y if e.state != "air" else 0.05
	game.fx.sparks(p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 8, Color(1, 1, 1, 0.8), 0.6, 60.0)
	p.global_position = at
	p.velocity = Vector3.ZERO
	var dir: Vector3 = (e.global_position - at)
	dir.y = 0
	dir = dir.normalized()
	p.face = atan2(dir.x, dir.z)
	game.cam_yaw = lerp_angle(game.cam_yaw, atan2(-dir.x, -dir.z), 0.35)
	var col: Color = p.style.color_hot
	game.popup(e.global_position + Vector3(0, e.height + 0.8, 0), TITLES[ctx], col)
	game.fx.ground_ring(at + Vector3(0, 0.05, 0), 0.3, 2.6, Color(col.r, col.g, col.b, 0.6), 0.3)
	var k := 1.5 if e.boss_id != "" and e.weak_t > 0.0 else 1.0
	match ctx:
		"attack":
			strike(e, 18.0 * k, 25.0, dir, 5.0, 0.0, false, 1)
		"launcher":
			strike(e, 14.0 * k, 20.0, dir, 1.0, 8.5, true, 1)
			p.velocity.y = 7.5          # герой взлетает вместе с целью
		"double":
			b.strike_anim("heavy", e.global_position)
			strike(e, 34.0 * k, 60.0, dir, 10.0, 0.0, true, 2)
			game.fx.slam(e.global_position, 1.3, col)
			game.shake(0.35)
		"counter":
			strike(e, 24.0 * k, 45.0, dir, 9.0, 0.0, true, 1)
			p.combat.open("parry", 0.8)      # ответ продолжается: окно контратаки у вошедшего героя
		"air_relay":
			# вошедший бьёт врага в воздухе в сторону напарника — тот вбивает его в землю
			p.global_position.y = max(p.global_position.y, e.global_position.y - 0.3)
			p.velocity.y = 5.0
			strike(e, 16.0 * k, 15.0, -dir, 3.0, 5.0, false, 1)
			b.blink(e.global_position - dir * 1.3 + Vector3(0, 0.2, 0), dir)
			b.velocity.y = 5.0
			b.strike_anim("air", e.global_position)
			relay = {"e": e, "t": 0.28, "dir": dir}
		"ground_relay":
			# удар по лежачему: поднимает с земли под продолжение
			strike(e, 26.0 * k, 40.0, dir, 2.0, 5.0, true, 1)
			game.fx.slam(e.global_position, 1.0, col)
			game.shake(0.25)
			p.combat.open("dodge", 0.8)
		"rescue":
			# сбивает нападавшего и даёт уйти: вошедший неуязвим мгновение, окно ответа открыто
			strike(e, 12.0 * k, 70.0, dir, 12.0, 0.0, true, 1)
			if is_instance_valid(e) and e.alive():
				e.stun(1.0)
			p.inv = max(p.inv, 0.8)
			p.combat.open("parry", 0.9)
		"perfect":
			# точная смена под замах: усиленный ответ, враг оглушён, окно точного уклонения у вошедшего
			strike(e, 32.0 * k, 80.0, dir, 11.0, 0.0, true, 2)
			if is_instance_valid(e) and e.alive():
				e.stun(1.4)
			game.fx.slam(e.global_position, 1.2, col)
			game.shake(0.3)
			p.inv = max(p.inv, 0.5)
			p.combat.open("perfect", 1.0)
	_boss_window(e)

## Удар команды: тот же путь, что и у обычных ударов (HitInfo → реакция врага)
func strike(e, dmg: float, stagger: float, dir: Vector3, knock: float, launch: float, heavy: bool, power: int, lethal := true) -> void:
	if not is_instance_valid(e) or not e.alive():
		return
	var h := HitInfo.new()
	h.damage = dmg if lethal or e.boss_id != "" else min(dmg, max(0.0, e.hp - 1.0))
	h.stagger = stagger
	h.dir = dir
	h.knockback = knock
	h.launch = launch
	h.heavy = heavy
	h.power = power
	h.attack_id = "team"
	h.source = p
	h.pos = e.global_position + Vector3(0, e.height * 0.6, 0)
	e.take_hit_info(h)
	game.feedback(["hit_light", "hit_heavy", "hit_super"][clampi(power, 0, 2)], h.pos, dir, 0.9, p.style.color_hot)

## Босс «ОТКРЫТ»: командный приём продлевает окно — но только один раз за окно
func _boss_window(e) -> void:
	if not is_instance_valid(e) or e.boss_id == "" or e.weak_t <= 0.0 or e.has_meta("team_ext"):
		return
	e.set_meta("team_ext", true)
	e.weak_t += 0.6
	e.stun_t += 0.6
	game.popup(e.global_position + Vector3(0, e.height + 1.3, 0), "TEAM BREAK", Color(1.0, 0.55, 0.3))
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(e):
			e.remove_meta("team_ext"))

# ---------------- помощь напарника ----------------
func assist_block() -> String:
	if game.paused_story() or game.over:
		return "story"
	if down[mate()]:
		return "down"
	if assist_cd > 0.0:
		return "cooldown"
	if p.state in ["dead", "hurt"]:
		return p.state
	return ""

## [T]: дуэт-атака (duo.gd). Старая простая помощь (CROSS ATTACK, AIR PARTNER COMBO) — try_assist_simple.
func try_assist() -> bool:
	return duo.try_start()

func try_assist_simple() -> bool:
	if assist_block() != "":
		events.append(["assist_blocked", assist_block()])
		return false
	var e = target()
	if e == null:
		return false
	assist_cd = ASSIST_CD
	var col := Color(0.36, 0.82, 1.0) if mate() == "madk1d" else Color(1.0, 0.8, 0.42)
	var from_p: Vector3 = e.global_position - p.global_position
	from_p.y = 0
	from_p = from_p.normalized() if from_p.length() > 0.1 else Vector3(sin(p.face), 0, cos(p.face))
	var k := 1.5 if e.boss_id != "" and e.weak_t > 0.0 else 1.0
	if e.state == "air":
		# напарник взлетает к цели и держит её в воздухе
		b.blink(e.global_position + from_p * 1.2 + Vector3(0, -0.4, 0), -from_p)
		b.velocity.y = 6.0
		b.strike_anim("air", e.global_position)
		strike(e, 14.0, 12.0, -from_p * 0.2, 0.5, 5.5, false, 1)
		game.popup(e.global_position + Vector3(0, e.height + 0.8, 0), TITLES["air"], col)
		events.append(["air", mate()])
	else:
		# напарник пролетает сквозь цель с другой стороны
		b.blink(e.global_position + from_p * 1.4, -from_p)
		b.strike_anim("heavy", e.global_position)
		strike(e, 16.0 * k, 30.0, from_p.cross(Vector3.UP), 2.0, 0.0, true, 1)
		game.fx.sparks(e.global_position + Vector3(0, 1.0, 0), -from_p, 10, col, 1.2, 30.0)
		game.popup(e.global_position + Vector3(0, e.height + 0.8, 0), TITLES["cross"], col)
		events.append(["cross", mate()])
	_boss_window(e)
	return true

## Командное добивание: напарник рядом и готов — бьёт вместе с последним ударом добивания
func _team_finish(e, dir: Vector3) -> void:
	if down[mate()] or assist_cd > 0.0 or b.global_position.distance_to(p.global_position) > 9.0 or not is_instance_valid(e):
		return
	assist_cd = ASSIST_CD * 0.5
	b.blink(e.global_position + dir * 1.4, -dir)
	b.strike_anim("heavy", e.global_position)
	game.fx.slam(e.global_position, 1.2, Color(1.0, 0.9, 0.6))
	game.popup(e.global_position + Vector3(0, e.height + 1.3, 0), TITLES["finisher"], Color(1.0, 0.9, 0.6))
	p.swag = min(100.0, p.swag + 10.0)
	events.append(["finisher", mate()])

# ---------------- поведение напарника ----------------
func _ai(dt: float) -> void:
	if not auto_assist or down[mate()] or b.ko:
		return
	auto_t -= dt
	if auto_t > 0.0 or b.foe != null:
		return
	auto_t = randf_range(3.2, 4.8)
	# бьёт не ту цель, которую бьёт игрок, если есть другая; только рядом с игроком
	var mine = target()
	var pick = null
	var bd := 7.0
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive() or e.state == "spawn":
			continue
		var d: float = e.global_position.distance_to(p.global_position)
		if d < bd and (e != mine or pick == null):
			if e != mine:
				bd = d
			pick = e
	if pick != null:
		b.engage(pick)

# ---------------- герой выбыл ----------------
## Здоровье активного героя кончилось. true — его сменил напарник, бой продолжается; false — выбыли оба.
func on_down() -> bool:
	var o := mate()
	var me: String = p.hero
	if down[o] or game.over:
		return false
	down[me] = true
	revive_t[me] = REVIVE
	hp[me] = 0.0
	grey[me] = 0.0
	p.hp = 1.0
	p.state = "move"
	p.combat.interrupt()
	if not game.swap_heroes():
		down[me] = false
		return false
	cur_hero = p.hero
	p.hp = max(1.0, float(hp[cur_hero]))
	last_hp = p.hp
	p.inv = 1.5
	tag_cd = 1.0
	b.ko_down()
	game.banner("%s ВЫБЫЛ" % ("ПАХАН" if me == "pahan" else "MADK1D"), "вернётся через %d с" % int(REVIVE), Color(1.0, 0.45, 0.35))
	game.slowmo(0.4)
	events.append(["down", me])
	return true

# ---------------- сохранение ----------------
func save_data() -> Dictionary:
	var styles := {}
	for h in p.heroes:
		styles[h] = p.style.id if h == p.hero else String(p.heroes[h]["style"])
	return {"hero": p.hero, "styles": styles, "hp": hp.duplicate(), "auto": auto_assist}

func load_data(d: Dictionary) -> void:
	if d.is_empty():
		return
	auto_assist = bool(d.get("auto", true))
	var styles: Dictionary = d.get("styles", {})
	for h in styles:
		if p.heroes.has(h) and Styles.ORDER.has(String(styles[h])) and (p.heroes[h]["styles"] as Array).has(String(styles[h])):
			p.heroes[h]["style"] = String(styles[h])
	var want := String(d.get("hero", "pahan"))
	if want != p.hero and p.heroes.has(want):
		game.swap_heroes()
	var cur: String = String(p.heroes[p.hero]["style"])
	if p.style.id != cur:
		p.style = Styles.by_id(cur)
		p.combat.set_style(p.style)
		p.rig.style_map = p.style.roles
		if p.hero == "madk1d":
			p.equip_madk(cur)
		else:
			p.rig.set_holstered(cur != "vozduh")
	var saved: Dictionary = d.get("hp", {})
	for h in hp:
		hp[h] = clampf(float(saved.get(h, p.max_hp)), 1.0, p.max_hp)
	cur_hero = p.hero
	p.hp = float(hp[cur_hero])
	last_hp = p.hp
