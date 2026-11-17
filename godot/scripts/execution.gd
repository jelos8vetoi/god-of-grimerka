## Контекстные добивания обычных врагов (этап 09). Не путать с тяжёлыми завершителями комбо (kind "finisher")
## и с Heat-цепочкой: добивание — отдельное короткое действие по врагу, который «готов» (enemy.exec_ready()).
##   [E] рядом с готовым врагом — добивание стилем, который в руках; СВЭГ не тратит, а даёт.
##   Вариант по обстановке: цель в воздухе — AIR FINISHER (прыжок и удар вниз); сразу после парирования —
##   PARRY FINISHER; сразу после уклонения — COUNTER FINISHER (оба быстрее и берут врага с запасом здоровья до 60 %).
##   Боссов добить нельзя: у них свои окна (enemy.stagger → «ОТКРЫТ»).
## Каждое добивание — строка данных SETS: клип, длительность, удары по времени и чем кончается.
## Командное добивание (этап 10) подключается через team_hook: его зовут на последнем ударе.
class_name Execution
extends Node

signal executed(enemy, style_id: String, ctx: String)

const REACH := 3.4
## beats: [доля времени, сила отклика 0..2]; end: slam — вбить, launch — подбросить и унести, blast — отбросить далеко,
## spike — вниз из воздуха. pull — тянуть цель к себе до этой доли времени (пылесос). spin — оборотов тела, hop — прыжок.
const SETS := {
	"vozduh": {"title": "ПРИГОВОР", "clip": "Finisher", "dur": 1.0, "beats": [[0.55, 2]], "end": "slam", "gap": 1.5},
	"bottles": {"title": "РОЗОЧКА", "clip": "BottleSnap", "dur": 0.8, "beats": [[0.3, 0], [0.6, 2]], "end": "splash", "gap": 1.2},
	"tyaga812": {"title": "НА ВЫДУВ", "clip": "TyagaSuck", "clip2": ["TyagaBlast", 0.6], "dur": 0.95, "beats": [[0.72, 2]], "end": "blast", "pull": 0.6, "gap": 1.6},
	"skateboard": {"title": "ДЕКОЙ В ПОЛ", "clip": "MUpper", "clip2": ["MOver", 0.42], "dur": 0.95, "beats": [[0.26, 1], [0.78, 2]], "end": "slam", "gap": 1.4},
	"guitar": {"title": "ПОСЛЕДНИЙ АККОРД", "clip": "MFinal", "dur": 1.0, "beats": [[0.62, 2]], "end": "chord", "gap": 1.5},
	"breaker": {"title": "НОКАУТ", "clip": "Helicopter", "dur": 0.9, "beats": [[0.32, 0], [0.48, 0], [0.64, 1], [0.8, 2]], "end": "launch", "spin": 2.0, "hop": 5.0, "gap": 1.3},
}
const CTX := {
	"": {"speed": 1.0},
	"air": {"title": "AIR FINISHER", "speed": 1.25, "end": "spike", "hop": 7.5},
	"parry": {"title": "PARRY FINISHER", "speed": 1.4},
	"dodge": {"title": "COUNTER FINISHER", "speed": 1.4},
}

var p
var game
var target = null
var ctx := ""
var data: Dictionary = {}
var t := 0.0
var dur := 1.0
var beat_i := 0
var clip2_done := false
var title := ""
var end := ""
var events: Array = []            # для проверок: [стиль, обстановка, тип врага]
var team_hook: Callable           # этап 10: командное добивание — вызывается на последнем ударе (enemy, dir)

func setup(player, g) -> void:
	p = player
	game = g

func active() -> bool:
	return p.state == "exec"

## Обстановка: только что парировал или уклонился — окно ядра боя ещё открыто
func context_now() -> String:
	var w: Dictionary = p.combat.windows
	var now: float = p.combat.clock
	if now <= float(w.get("parry", -9.0)):
		return "parry"
	if now <= float(w.get("perfect", -9.0)) or now <= float(w.get("dodge", -9.0)):
		return "dodge"
	return ""

## Кого можно добить: ближайший готовый враг перед героем
func pick() -> Array:
	var c := context_now()
	var best = null
	var bd := REACH
	var fw := Vector3(sin(p.face), 0, cos(p.face))
	var aim: Vector3 = p.aim_dir()
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive() or not e.exec_ready(c != ""):
			continue
		var d: Vector3 = e.global_position - p.global_position
		d.y = 0
		var dist := d.length()
		if dist > bd:
			continue
		var dn: Vector3 = d / max(dist, 0.001)
		if dist > 1.2 and dn.dot(fw) < 0.1 and dn.dot(aim) < 0.1:      # вплотную — можно и вполоборота
			continue
		bd = dist
		best = e
	if best == null:
		return []
	return [best, "air" if best.state == "air" else c]

func can_start() -> bool:
	return p.state in ["move", "block", "tyaga"] and SETS.has(p.style.id) and not (p.style.id == "tyaga812" and p.tyaga.riding()) and not (p.style.id == "skateboard" and p.skate.on)

## [E]: если рядом готовый враг — добивание. true — началось.
func try_start() -> bool:
	if not can_start():
		return false
	var pk := pick()
	if pk.is_empty():
		return false
	begin(pk[0], String(pk[1]))
	return true

func begin(e, c := "") -> void:
	target = e
	ctx = c
	data = SETS[p.style.id]
	var cx: Dictionary = CTX.get(c, CTX[""])
	dur = float(data["dur"]) / float(cx["speed"])
	title = String(cx.get("title", data["title"]))
	end = String(cx.get("end", data["end"]))
	t = 0.0
	beat_i = 0
	clip2_done = false
	p.combat.interrupt()
	p.state = "exec"
	p.t = 0.0
	p.inv = max(p.inv, dur + 0.25)
	p.spin_off = 0.0
	var to: Vector3 = e.global_position - p.global_position
	to.y = 0
	p.face = atan2(to.x, to.z)
	p.turn_to = NAN
	p.anim_hold = dur
	p.rig.play_for(String(data["clip"]), dur if not data.has("clip2") else dur * float(data["clip2"][1]), 0.06)
	var hop: float = float(cx.get("hop", data.get("hop", 0.0)))
	if hop > 0.0:
		p.velocity.y = hop
	if e.state != "air":
		e.hold(dur + 0.2)
	else:
		e.velocity.y = max(e.velocity.y, 3.5)       # цель в воздухе чуть зависает под удар
		e.kb = Vector3.ZERO
	game.popup(e.global_position + Vector3(0, e.height + 0.7, 0), title, Color(1.0, 0.82, 0.35))
	game.main.sfx("sfx_parry", -6.0, 0.8)
	game.fov_kick = max(game.fov_kick, -4.0)
	game.slowmo(0.12)
	events.append([p.style.id, c, e.kind])

## каждый шаг физики, пока герой в состоянии "exec"
func tick(dt: float) -> void:
	t += dt
	var k := t / dur
	var e = target
	var ok: bool = e != null and is_instance_valid(e) and e.alive()
	var dir := Vector3(sin(p.face), 0, cos(p.face))
	# подойти на удобную дистанцию и стоять
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if ok:
		var to: Vector3 = e.global_position - p.global_position
		to.y = 0
		var dist := to.length()
		dir = to / max(dist, 0.001)
		p.face = lerp_angle(p.face, atan2(dir.x, dir.z), 1.0 - exp(-16.0 * dt))
		var gap: float = float(data["gap"])
		if data.has("pull") and k < float(data["pull"]):
			# пылесос тянет цель к раструбу
			e.global_position -= dir * min(dist - gap * 0.75, 7.0 * dt) if dist > gap * 0.75 else Vector3.ZERO
			if Engine.get_physics_frames() % 4 == 0:
				game.fx.sparks(e.global_position + Vector3(0, e.height * 0.6, 0), -dir, 2, Color(0.8, 0.9, 1.0), 0.6, 30.0)
		elif k < 0.3 and abs(dist - gap) > 0.15:
			var step: float = clampf(dist - gap, -6.0 * dt, 9.0 * dt)
			p.velocity.x = dir.x * step / dt
			p.velocity.z = dir.z * step / dt
		if ctx == "air" and e.state == "air" and k < 0.5:
			e.velocity.y = max(e.velocity.y, 0.5)
	if data.has("spin"):
		p.spin_off = -TAU * float(data["spin"]) * smoothstep(0.1, 0.9, k)
	if data.has("clip2") and not clip2_done and k >= float(data["clip2"][1]):
		clip2_done = true
		p.rig.play_for(String(data["clip2"][0]), dur * (1.0 - float(data["clip2"][1])), 0.05)
	var beats: Array = data["beats"]
	while beat_i < beats.size() and k >= float(beats[beat_i][0]):
		var last := beat_i == beats.size() - 1
		if ok:
			_beat(e, dir, int(beats[beat_i][1]), last)
		beat_i += 1
	if k >= 1.0 or (not ok and beat_i >= beats.size()) or (not ok and k > 0.5):
		_finish()

func _beat(e, dir: Vector3, power: int, last: bool) -> void:
	var at: Vector3 = e.global_position + Vector3(0, e.height * 0.6, 0)
	if not last:
		# промежуточный удар: не убивает, только встряхивает
		e.take_hit(min(6.0 + 4.0 * power, max(0.0, e.hp - 1.0)), dir, 0.5, false, 0.0)
		game.feedback("hit_heavy" if power >= 1 else "hit_light", at, dir, 0.8, p.style.color)
		return
	var col: Color = p.style.color_hot
	var knock := 7.0
	var launch := 5.0
	match end:
		"slam":
			knock = 3.0
			launch = 3.0
			game.fx.slam(e.global_position, 1.1, col)
			game.main.sfx("sfx_boom", -3.0, 1.0)
		"splash":
			knock = 6.0
			launch = 4.0
			game.fx.sparks(at, Vector3.UP, 22, Color(0.6, 0.85, 1.0), 1.4, 80.0)
			game.fx.ground_ring(e.global_position + Vector3(0, 0.05, 0), 0.3, 3.2, Color(0.6, 0.85, 1.0, 0.6), 0.4)
			p.bottles._play_splash(at)
		"blast":
			knock = 17.0
			launch = 5.5
			game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.4, 5.0, Color(0.85, 0.93, 1.0, 0.6), 0.35)
			game.fx.dust(e.global_position, 14, game.fx.DUST, 1.4)
			game.main.sfx("sfx_boom", -2.0, 1.3)
		"chord":
			knock = 9.0
			launch = 5.0
			p.guitar.play("chord", -2.0, 0.8)
			game.fx.lightning(e.global_position, 3.5, col)
			game.fx.ground_ring(e.global_position + Vector3(0, 0.05, 0), 0.4, 5.5, Color(col.r, col.g, col.b, 0.6), 0.45)
		"launch":
			knock = 8.0
			launch = 8.0
			game.fx.twinkle(at, 12, col, 1.0)
		"spike":
			knock = 2.0
			launch = -18.0
			game.fx.twinkle(at, 10, col, 0.9)
	if team_hook.is_valid():
		team_hook.call(e, dir)
	var kind: String = e.kind
	e.executed = true
	e.take_hit(e.hp + 10.0, dir, knock, true, launch)
	game.feedback("hit_super", at, dir, 1.0, col)
	game.hitstop(0.09)
	p.swag = min(100.0, p.swag + (22.0 if ctx != "" else 15.0))
	executed.emit(e, p.style.id, ctx)
	events.append(["done", ctx, kind])

func _finish() -> void:
	p.spin_off = 0.0
	p.state = "move"
	p.anim_hold = 0.0
	target = null

## удар по герою во время добивания не проходит (inv), но если состояние сменили извне — аккуратно выйти
func cancel() -> void:
	if p.state == "exec":
		_finish()
