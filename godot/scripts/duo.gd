## Дуэт-атака на [T] (game.tag.duo): не обычная помощь напарника, а одна связанная постановка двоих.
##   1. напарник рывком (не телепортом) подбегает к цели и открывает своим ВЫБРАННЫМ стилем — снимает равновесие;
##   2. враг сбит (enemy.stagger): замах сорван, защиты нет;
##   3. активный герой прыжком к цели и продолжает НАСТОЯЩЕЙ цепочкой своего стиля через ядро боя (combat.begin +
##      следующие нажатия в окнах связки) — хитбоксы, урон и реакции обычные;
##   4. концовка пары: напарник бьёт в тот же миг, что и последний удар героя (DUO IMPACT), — отброс, подброс,
##      в землю или в стену; у каждой из девяти пар стилей своя.
## Работает в обе стороны: Пахан с madk1d-помощником и madk1d с Паханом-помощником. Враг в воздухе — воздушная версия.
## Враг «готов» к добиванию — DUO FINISHER: открытие напарника и добивание стиля героя (execution.gd).
## [T] во время удара: в окне связки — сразу (удар обрывается), раньше — запоминается и срабатывает, когда окно
## откроется или удар закончится (BUF секунд). Без цели — подсказка, перезарядка не тратится.
class_name Duo
extends Node

const RANGE := 8.0
const BUF := 0.7
const FOLLOW_MAX := 2.2          # сколько ждать конца цепочки героя, с
## Открытие напарника по его стилю: клип и доля удара; air_* — в воздухе; stab — снятие равновесия;
## kind — как бьёт: hit (удар вплотную), throw (бутылки летят), pull (тяга подтягивает), wave (звуковая волна).
const OPEN := {
	"vozduh": {"clip": "FullSwing", "len": 0.7, "hit": 0.55, "air": "Upper", "air_len": 0.6, "air_hit": 0.5, "stab": 80.0, "kind": "hit", "title": "БАЛОН"},
	"bottles": {"clip": "BtDoubleThrow", "len": 0.6, "hit": 0.45, "air": "BtJumpThrow", "air_len": 0.5, "air_hit": 0.45, "stab": 70.0, "kind": "throw", "title": "БУТЫЛКИ"},
	"tyaga812": {"clip": "TyagaSuck", "len": 0.55, "hit": 0.95, "air": "TyagaUp", "air_len": 0.5, "air_hit": 0.3, "stab": 75.0, "kind": "pull", "title": "ТЯГА"},
	"skateboard": {"clip": "SkFlipStrike", "len": 0.6, "hit": 0.58, "air": "SkAirStrike", "air_len": 0.42, "air_hit": 0.5, "stab": 70.0, "kind": "hit", "title": "ДОСКА"},
	"guitar": {"clip": "GtFeedback", "len": 0.6, "hit": 0.4, "air": "GtAirRiff", "air_len": 0.45, "air_hit": 0.4, "stab": 75.0, "kind": "wave", "title": "ФИДБЭК"},
	"breaker": {"clip": "LegSweep", "len": 0.56, "hit": 0.5, "air": "AirKick", "air_len": 0.36, "air_hit": 0.45, "stab": 85.0, "kind": "hit", "title": "ПОДСЕЧКА"},
}
## Продолжение героя по его стилю: первый удар и следующие нажатия (через граф связок стиля); у ТЯГИ — приём пылесоса.
const FOLLOW := {
	"vozduh": {"g": ["vz_light1", ["light", "heavy"]], "a": ["vz_air_light", ["heavy"]]},
	"bottles": {"g": ["bt_jab", ["light", "throw"]], "a": ["bt_jump", ["light"]]},
	"skateboard": {"g": ["sk_swing1", ["light", "throw"]], "a": ["sk_airstrike", ["heavy"]]},
	"guitar": {"g": ["gt_body", ["light", "heavy"]], "a": ["gt_airstrike", ["heavy"]]},
	"breaker": {"g": ["br_toprock", ["light", "heavy"]], "a": ["br_air1", ["heavy"]]},
	"tyaga812": {"g": ["point", []], "a": ["up", []]},
}
## Концовка пары (стиль Пахана | стиль madk1d): название, чем кончается и чем звучит.
##   end: knock — отброс, launch — подброс, down — в землю, wall — в стену (сильный отброс к краю).
const PAIRS := {
	"vozduh|skateboard": {"title": "ДОСКА И БАЛОН", "end": "down", "fx": "slam", "col": Color(0.6, 0.9, 1.0)},
	"vozduh|guitar": {"title": "ГРОМКИЙ ВЫХОД", "end": "knock", "fx": "chord", "col": Color(1.0, 0.85, 0.4)},
	"vozduh|breaker": {"title": "ПОДСЕЧКА И БАЛОН", "end": "wall", "fx": "dust", "col": Color(1.0, 0.6, 0.9)},
	"bottles|skateboard": {"title": "СТЕКЛО И ДОСКА", "end": "launch", "fx": "splash", "col": Color(0.55, 0.85, 1.0)},
	"bottles|guitar": {"title": "ЗВОН СТЕКЛА", "end": "knock", "fx": "chord", "col": Color(0.7, 0.95, 1.0)},
	"bottles|breaker": {"title": "МОКРЫЙ ПОЛ", "end": "down", "fx": "splash", "col": Color(0.55, 0.82, 1.0)},
	"tyaga812|skateboard": {"title": "ТЯГА И РАЗГОН", "end": "wall", "fx": "blast", "col": Color(0.75, 0.95, 1.0)},
	"tyaga812|guitar": {"title": "ДАВЛЕНИЕ И ФИДБЭК", "end": "knock", "fx": "chord", "col": Color(0.8, 0.95, 1.0)},
	"tyaga812|breaker": {"title": "ПЕРЕГРУЗКА", "end": "launch", "fx": "blast", "col": Color(1.0, 0.7, 0.4)},
}

var tag                      # TagTeam
var game
var p
var b
var phase := ""              # "", open, lead, follow
var t := 0.0
var e = null                 # цель
var air := false
var fin := false             # DUO FINISHER
var relay := false           # AIR TAG: вошедший по Tab герой прыгает к цели в воздухе и бьёт своим стилем; дальше ведёт игрок
var pair := ""
var mate_style := ""
var my_style := ""
var opened := false
var nexts: Array = []
var last_id := ""
var buf_t := -9.0
var lead_vel := Vector3.ZERO
var lead_len := 0.3
var hero0 := ""
var events: Array = []       # для проверок: ["start", пара, кто ведёт], ["break", враг], ["end", пара, end], ["abort", почему], ["none", 0]
var bottles_fly: Array = []  # бутылки напарника в полёте: {n, from, to, t, len}

func setup(tt) -> void:
	tag = tt
	game = tt.game
	p = tt.p
	b = tt.b

func active() -> bool:
	return phase != ""

## Стиль напарника — тот, что выбран у него сейчас (у неактивного героя он хранится в player.heroes)
func style_of(h: String) -> String:
	return p.style.id if h == p.hero else String(p.heroes[h]["style"])

## Цель: враг, которого герой сейчас бьёт → ближайший перед камерой → ближайший в радиусе.
func pick():
	var a: AttackData = p.combat.cur
	if p.state == "attack" and a != null:
		for idx in p.combat.hit_log:
			for id in (p.combat.hit_log[idx] as Dictionary):
				var en = instance_from_id(int(id))
				if en != null and _valid(en):
					return en
	var best = null
	var bs := -1e9
	var aim: Vector3 = p.aim_dir()
	for en in game.enemies:
		if not _valid(en):
			continue
		var d: Vector3 = en.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > RANGE:
			continue
		var sc: float = -dist + (d / max(dist, 0.001)).dot(aim) * 3.0
		if sc > bs:
			bs = sc
			best = en
	return best

func _valid(en) -> bool:
	if not is_instance_valid(en) or not en.alive() or en.state in ["spawn", "dead"]:
		return false
	if en.boss_id != "" and en.shielded():
		return false                 # босс в неуязвимой фазе
	if p.state == "exec" and p.execution.target == en:
		return false
	return game.in_arena(en.global_position, 0.2)

## [T]
func try_start() -> bool:
	if phase != "":
		return false
	var why: String = tag.assist_block()
	if why != "":
		tag.events.append(["assist_blocked", why])
		return false
	var en = pick()
	if en == null:
		game.popup(p.global_position + Vector3(0, 2.3, 0), "нет цели", Color(0.75, 0.78, 0.85))
		events.append(["none", 0])
		return false                 # перезарядка не тратится
	if p.state == "attack" and not p.combat.in_combo_window():
		buf_t = p.combat.clock       # удар ещё идёт: сработает в окне связки
		events.append(["buffer", 0])
		return true
	if not _free():
		return false
	_begin(en)
	return true

## герой сейчас может начать дуэт (свободен или в окне связки)
func _free() -> bool:
	if p.switch_to != "" or p.state in ["dead", "hurt", "exec", "overdrive", "roll", "switch", "charge"]:
		return false
	if p.state == "attack":
		return p.combat.in_combo_window()
	if p.state == "tyaga":
		return p.tyaga.mode in ["hold", "ride"]
	return true

func _begin(en) -> void:
	e = en
	hero0 = p.hero
	air = en.state == "air"
	fin = en.boss_id == "" and en.exec_ready(true)
	my_style = p.style.id
	mate_style = style_of(tag.mate())
	var ps: String = my_style if p.hero == "pahan" else mate_style
	var ms: String = mate_style if p.hero == "pahan" else my_style
	pair = ps + "|" + ms
	opened = false
	tag.assist_cd = tag.ASSIST_CD
	buf_t = -9.0
	if p.state == "attack":
		p.combat.interrupt()         # обрываем удар в окне связки: дальше — дуэт
	if p.state == "skate":
		p.skate.off()
	if p.tyaga.riding():
		p.tyaga._to_hold()
	phase = "open"
	t = 0.0
	# напарник: рывком к цели, с другой стороны от героя (Cross Strike)
	var from_p: Vector3 = en.global_position - p.global_position
	from_p.y = 0
	from_p = from_p.normalized() if from_p.length() > 0.1 else Vector3(sin(p.face), 0, cos(p.face))
	var side: Vector3 = from_p.cross(Vector3.UP)
	var spot: Vector3 = en.global_position + (side * 0.9 + from_p * 0.6).normalized() * 1.25
	if not game.in_arena(spot, 0.5):
		spot = en.global_position - side * 1.2
	spot.y = b.global_position.y
	var o: Dictionary = OPEN[mate_style]
	b.duo_start(mate_style, spot, en, air)
	en.interrupt_weak()      # цель отвлеклась на рывок напарника: слабый замах сорван
	var col: Color = (PAIRS[pair] as Dictionary)["col"]
	game.popup(en.global_position + Vector3(0, en.height + 1.0, 0), ("DUO FINISHER" if fin else String(o["title"])), col)
	events.append(["start", pair, p.hero, "air" if air else ("fin" if fin else "ground")])
	tag.events.append(["duo", tag.mate()])

func _physics_process(dt: float) -> void:
	if game == null or game.paused_story() or game.over:
		return
	_bottles_tick(dt)
	if phase == "" and buf_t > -9.0:
		if p.combat.clock - buf_t > BUF or p.state in ["hurt", "dead"]:
			buf_t = -9.0
			events.append(["buffer_lost", 0])
		elif _free():
			var en = pick()
			buf_t = -9.0
			if en != null:
				_begin(en)
	if phase == "":
		return
	t += dt
	# всё, что ломает постановку: цель пропала, героя сбили, героя сменили
	if p.hero != hero0 or p.state in ["hurt", "dead"]:
		_abort("hero")
		return
	if not is_instance_valid(e) or not e.alive():
		_abort("target")
		return
	match phase:
		"open":
			_open_tick()
		"lead":
			_lead_tick(dt)
		"follow":
			_follow_tick()

# ---------------- 1. открытие напарника ----------------
func _open_tick() -> void:
	var o: Dictionary = OPEN[mate_style]
	if not b.duo_ready():
		if t > 0.8:
			_abort("partner")        # не добежал (стена, край арены)
		return
	var len: float = float(o["air_len"] if air else o["len"])
	var hf: float = float(o["air_hit"] if air else o["hit"])
	if not b.duo_acting():
		b.duo_act(String(o["air"] if air else o["clip"]), len)
		t = 0.0
		if String(o["kind"]) == "throw":
			_throw_bottles(2 if not air else 1, len * hf)
		return
	if String(o["kind"]) == "pull" and not opened:
		# тяга: цель подтягивает к напарнику, пока идёт втягивание
		var to: Vector3 = b.global_position - e.global_position
		to.y = 0
		if to.length() > 1.3 and e.boss_id == "" and float(e.height) < 2.3:
			e.kb = to.normalized() * 6.0
		e.interrupt_weak()
	if not opened and t >= len * hf:
		opened = true
		_open_hit(o)
		_start_lead()

func _open_hit(o: Dictionary) -> void:
	var d: Vector3 = e.global_position - b.global_position
	d.y = 0
	d = d.normalized() if d.length() > 0.05 else Vector3(sin(p.face), 0, cos(p.face))
	var col: Color = (PAIRS[pair] as Dictionary)["col"]
	if String(o["kind"]) == "throw":
		return                       # бьют сами бутылки, когда долетят (_bottles_tick)
	var launch := 4.5 if air else 0.0
	tag.strike(e, 10.0, 0.0, d, 1.5, launch, true, 1, false)
	_stab(float(o["stab"]))
	tag._boss_window(e)      # босс «ОТКРЫТ»: дуэт продлевает окно (TEAM BREAK), один раз за окно
	match String(o["kind"]):
		"wave":
			for i in 3:
				game.fx.ring(e.global_position + Vector3(0, 0.9 + i * 0.3, 0), 0.9 + i * 0.5, Color(col.r, col.g, col.b, 0.6 - i * 0.15), 0.2 + i * 0.05)
			p.guitar.play("chord", -6.0, 1.1)
		"pull":
			game.fx.twirl(e.global_position + Vector3(0, 0.9, 0), 1.6, col, 0.35)
		_:
			game.fx.dust(e.global_position + Vector3(0, 0.1, 0), 6, game.fx.DUST, 0.8)

## снять равновесие: дуэт снимает много, но у врага растёт сопротивление (enemy.stagger)
func _stab(v: float) -> void:
	if not is_instance_valid(e) or not e.alive():
		return
	if e.stagger(v):
		events.append(["break", e])
		tag.events.append(["duo_break", tag.mate()])
		game.feedback("hit_heavy", e.global_position + Vector3(0, e.height * 0.6, 0), Vector3.UP, 0.8, Color(1.0, 0.85, 0.4))

# ---------------- 2. прыжок героя к цели ----------------
func _start_lead() -> void:
	phase = "lead"
	t = 0.0
	var to: Vector3 = e.global_position - p.global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var reach := 1.5
	if dist <= reach + 0.2 and not air:
		_start_follow()              # уже рядом: сразу бить
		return
	lead_len = clampf(dist / 13.0, 0.18, 0.42)
	var dir: Vector3 = flat / max(dist, 0.001)
	lead_vel = dir * max(0.0, dist - reach) / lead_len
	var dy: float = (e.global_position.y - p.global_position.y) if air else 0.0
	if air and my_style == "tyaga812":
		dy = -0.4                     # пылесос бьёт вверх с земли: подбежать под цель, а не прыгать
	# высота: в воздух — до цели, по земле — короткий подскок (выпад)
	lead_vel.y = (dy + 0.5 * 20.0 * lead_len * lead_len) / lead_len if air else 0.5 * 20.0 * lead_len
	p.face = atan2(dir.x, dir.z)
	p.body.rotation.y = p.face
	p.state = "duo"
	p.velocity = lead_vel
	p.rig.play("Jump" if air or dist > 4.0 else "Sprint", 0.06)
	game.fx.dust(p.global_position + Vector3(0, 0.1, 0), 6, game.fx.DUST, 0.7)
	game.main.sfx("sfx_roll", -6.0, 1.3)
	game.fov_kick = max(float(game.fov_kick), 4.0)

## состояние игрока "duo" (player.gd): лететь к цели
func lead_step(dt: float) -> void:
	if phase != "lead":
		p.state = "move"
		return
	# цель отлетает (подброс, отброс) — прыжок её ведёт: скорость к тому месту, где она сейчас
	var to: Vector3 = e.global_position - p.global_position
	to.y = 0
	var left: float = max(lead_len - t, 0.06)
	var need: float = max(0.0, to.length() - 1.4) / left
	var hv: Vector3 = to.normalized() * clampf(need, 0.0, 22.0) if to.length() > 0.05 else Vector3.ZERO
	p.velocity.x = hv.x
	p.velocity.z = hv.z
	if hv.length() > 0.5:
		p.face = atan2(hv.x, hv.z)
	if air and my_style != "tyaga812":
		# и по высоте: туда, где враг окажется к концу прыжка (он летит по дуге), чуть ниже его центра
		var ty: float = e.global_position.y + float(e.velocity.y) * left - 10.0 * left * left - 0.3
		p.velocity.y = clampf((ty - p.global_position.y) / left + 10.0 * left, -6.0, 14.0)
	if t >= lead_len or p.global_position.distance_to(e.global_position) < 1.6:
		_start_follow()

func _lead_tick(_dt: float) -> void:
	if t > lead_len + 0.4:
		_start_follow()              # упёрся во что-то — бьём оттуда, где есть

# ---------------- 3. продолжение героя ----------------
func _start_follow() -> void:
	phase = "follow"
	t = 0.0
	if p.state == "duo":
		p.state = "move"
	var d: Vector3 = e.global_position - p.global_position
	d.y = 0
	if d.length() > 0.05:
		p.face = atan2(d.x, d.z)
	if fin:
		# DUO FINISHER: добивание стиля героя по этой цели; напарник бьёт вместе с последним ударом
		var col: Color = (PAIRS[pair] as Dictionary)["col"]
		game.popup(e.global_position + Vector3(0, e.height + 1.5, 0), "DUO FINISHER · " + String((PAIRS[pair] as Dictionary)["title"]), col)
		p.execution.begin(e, "")
		tag.events.append(["duo_finisher", tag.mate()])
		events.append(["finisher", pair])
		b.duo_act(String(OPEN[mate_style]["air" if air else "clip"]), 0.6)
		_done()
		return
	var f: Array = FOLLOW[my_style]["a" if air else "g"]
	nexts = [] if relay else (f[1] as Array).duplicate()      # в AIR TAG дальше бьёт игрок
	if my_style == "tyaga812":
		p.state = "tyaga"
		if p.tyaga.mode in ["off", "out", "in"]:
			p.tyaga.mode = "hold"
		p.tyaga._act(String(f[0]))
		last_id = "tg_" + String(f[0])
		return
	var a: AttackData = p.style.attack(String(f[0]))
	if a == null:
		_ending()
		return
	p.combat.begin(a, false)
	last_id = a.id

func _follow_tick() -> void:
	if my_style == "tyaga812":
		if p.tyaga.mode != "act" or bool(p.tyaga.act.get("hit", false)):
			_ending()
		return
	var c = p.combat
	if p.state == "charge":
		c.chained_charge_skip = true      # на всякий случай: заряд в дуэте не держим
		c.interrupt()
		_ending()
		return
	if p.state != "attack" or c.cur == null:
		_ending()                    # цепочка оборвалась (игрок сам ушёл в уклонение и т. п.)
		return
	if not nexts.is_empty() and c.in_combo_window():
		var act: String = nexts.pop_front()
		c.chained_charge_skip = true  # заряжаемый удар в дуэте идёт сразу, без удержания кнопки
		c.press(act)                 # следующий удар — через граф связок стиля, как от игрока
		return
	if nexts.is_empty() and c.hit_i > 0 and c.cur.id != "" and t > 0.1:
		_ending()
		return
	if t > FOLLOW_MAX:
		_ending()

# ---------------- 4. концовка пары ----------------
func _ending() -> void:
	if relay:
		events.append(["relay_end", pair, p.hero])
		_done()
		return
	if not is_instance_valid(e) or not e.alive():
		_done()
		return
	var pr: Dictionary = PAIRS[pair]
	var col: Color = pr["col"]
	var d: Vector3 = e.global_position - p.global_position
	d.y = 0
	d = d.normalized() if d.length() > 0.05 else Vector3(sin(p.face), 0, cos(p.face))
	# напарник бьёт в тот же миг: оба по одной цели с двух сторон
	b.duo_act(String(OPEN[mate_style]["air" if air else "clip"]), 0.45)
	var k: float = 0.6 if e.boss_id != "" else 1.0
	match String(pr["end"]):
		"knock":
			tag.strike(e, 18.0 * k, 30.0, d, 14.0, 0.0, true, 2)
		"launch":
			tag.strike(e, 16.0 * k, 25.0, d, 2.0, 7.5, true, 2)
		"down":
			tag.strike(e, 20.0 * k, 35.0, d, 2.0, -16.0, true, 2)
		"wall":
			tag.strike(e, 18.0 * k, 35.0, d, 18.0, 0.0, true, 2)
	var at: Vector3 = e.global_position + Vector3(0, 0.9, 0)
	match String(pr["fx"]):
		"slam":
			game.fx.slam(e.global_position, 1.3, col)
		"chord":
			for i in 3:
				game.fx.ring(at + Vector3(0, i * 0.25, 0), 1.0 + i * 0.6, Color(col.r, col.g, col.b, 0.6 - i * 0.15), 0.22 + i * 0.05)
			p.guitar.play("chord", -3.0, 0.9)
		"splash":
			game.fx.sparks(at, Vector3.UP, 24, Color(0.55, 0.82, 1.0), 1.2, 80.0)
			game.main.sfx("sfx_glass", -4.0, 1.0)
		"blast":
			game.fx.ground_ring(Vector3(at.x, e.global_position.y + 0.05, at.z), 0.4, 4.0, Color(col.r, col.g, col.b, 0.7), 0.35)
			game.main.sfx("sfx_boom", -4.0, 1.2)
		_:
			game.fx.dust(e.global_position + Vector3(0, 0.1, 0), 12, game.fx.DUST, 1.1)
	game.fx.duo_finale(at, String(p.style.id), String(mate_style), d, 1.0)      # подпись пары: цвета и мотивы обоих стилей
	game.feedback("hit_super", at, d, 1.0, col)
	game.shake(0.35)
	game.popup(e.global_position + Vector3(0, e.height + 1.3, 0), String(pr["title"]), col)
	p.swag = min(100.0, p.swag + 12.0)
	events.append(["end", pair, String(pr["end"])])
	tag.events.append(["duo_end", tag.mate()])
	_done()

func _done() -> void:
	phase = ""
	relay = false
	p.combat.chained_charge_skip = false
	nexts = []
	b.duo_release()

func _abort(why: String) -> void:
	if p.state == "duo":
		p.state = "move"
	events.append(["abort", why])
	_done()

## AIR TAG (tagteam._air_tag): героя уже сменили — вошедший прыжком к цели в воздухе и бьёт воздушным ударом
## своего стиля (настоящий удар ядра боя). Дальше цепочку ведёт игрок: никаких автоматических нажатий.
func air_tag(en) -> void:
	e = en
	hero0 = p.hero
	air = true
	fin = false
	relay = true
	my_style = p.style.id
	mate_style = style_of(tag.mate())
	var ps: String = my_style if p.hero == "pahan" else mate_style
	var ms: String = mate_style if p.hero == "pahan" else my_style
	pair = ps + "|" + ms
	opened = true
	buf_t = -9.0
	if p.state == "attack":
		p.combat.interrupt()
	if p.skate.on:
		p.skate.off()
	if p.tyaga.riding():
		p.tyaga._to_hold()
	events.append(["air_tag", pair, p.hero])
	_start_lead()

## AIR TAG ещё идёт, но цепочку уже можно передать дальше (Tab в фазе продолжения)
func relay_open() -> bool:
	return relay and phase == "follow"

## на смене героя, гибели или выходе: всё вернуть в обычный бой
func reset() -> void:
	if p != null and p.state == "duo":
		p.state = "move"
	phase = ""
	relay = false
	buf_t = -9.0
	nexts = []
	for f in bottles_fly:
		if is_instance_valid(f["n"]):
			(f["n"] as Node3D).queue_free()
	bottles_fly = []
	if b != null:
		b.duo_release()

# ---------------- бутылки напарника ----------------
## Пахан-напарник бросает бутылки: настоящие предметы летят по дуге и бьют, когда долетят
func _throw_bottles(n: int, delay: float) -> void:
	for i in n:
		var node: Node3D = p.bottles._make()
		node.visible = false
		game.add_child(node)
		bottles_fly.append({"n": node, "t": -delay - 0.12 * i, "len": 0.32, "side": (i - (n - 1) * 0.5) * 0.4})

func _bottles_tick(dt: float) -> void:
	for i in range(bottles_fly.size() - 1, -1, -1):
		var f: Dictionary = bottles_fly[i]
		f["t"] = float(f["t"]) + dt
		var node: Node3D = f["n"]
		if not is_instance_valid(node):
			bottles_fly.remove_at(i)
			continue
		var kt: float = float(f["t"]) / float(f["len"])
		if kt < 0.0:
			continue
		if not is_instance_valid(e) or not e.alive():
			node.queue_free()
			bottles_fly.remove_at(i)
			continue
		var from: Vector3 = b.global_position + Vector3(0, 1.4, 0)
		var to: Vector3 = e.global_position + Vector3(0, float(e.height) * 0.6, 0)
		var sd: Vector3 = (to - from).cross(Vector3.UP).normalized() * float(f["side"])
		node.visible = true
		node.global_position = from.lerp(to, kt) + sd * sin(kt * PI) + Vector3(0, sin(kt * PI) * 0.9, 0)
		node.rotation += Vector3(14, 3, 5) * dt
		if kt >= 1.0:
			var d: Vector3 = to - from
			d.y = 0
			tag.strike(e, 8.0, 0.0, d.normalized(), 2.0, 3.5 if air else 0.0, false, 1, false)
			e.slow(2.0, 0.6)
			_stab(float(OPEN["bottles"]["stab"]) * 0.5)
			game.fx.sparks(to, Vector3.UP, 16, Color(0.55, 0.82, 1.0), 0.9, 70.0)
			game.main.sfx("sfx_glass", -5.0, 1.15)
			node.queue_free()
			bottles_fly.remove_at(i)
