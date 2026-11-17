## Breaker Style madk1d: поток, Freeze, риск. Движения и связки ведёт ядро боя по данным style_breaker.gd.
##   поток      — каждое новое движение связки (не повтор предыдущего) даёт деление потока, до восьми:
##                +6 % урона за деление. Длинная связка бьёт сильнее, но поток сгорает, если героя ударили
##                или он простоял 1,5 с.
##   риск       — во вращениях (мельница, вертолёт, вращение на голове, флэр, подсечка) урон по герою ×1,3.
##   Freeze     — F в окне комбо: герой застывает в позе и «забирает» поток: СВЭГ за каждое деление и усиление
##                следующего удара. Неуязвимости нет — застыл на виду у врагов.
##   Perfect Freeze — F нажат в момент открытия окна комбо (±0,1 с): вдвое больше СВЭГа, враги рядом оглушены
##                на 0,9 с, следующий удар ×1,5; при потоке от пяти открывается BREAKER FINISHER (F ещё раз).
class_name Breaker
extends Node

const MAX_FLOW := 8
const FLOW_DMG := 0.06
const PERFECT := 0.1          # окно точного Freeze, с
const SPIN_RISK := 1.3
const FINISH_FLOW := 5

var p
var game
var flow := 0
var last_id := ""
var idle_t := 0.0
var press_off := 9.0          # насколько нажатие F было далеко от открытия окна комбо, с
var boost := 1.0              # множитель следующего удара после Freeze
var cashed := 0               # сколько потока забрал последний Freeze
var perfect := false
var events: Array = []        # для проверок: ["freeze", поток], ["perfect", поток], ["broken", 0]…

func setup(player, g) -> void:
	p = player
	game = g

func active() -> bool:
	return p.hero == "madk1d" and p.style.id == "breaker"

func tick(dt: float) -> void:
	if not active():
		return
	if p.state == "attack":
		idle_t = 0.0
	else:
		idle_t += dt
		if idle_t > 1.5 and (flow > 0 or cashed > 0):
			flow = 0                      # поток живёт только в движении
			cashed = 0
			perfect = false
			boost = 1.0
			last_id = ""

## игрок нажал F: запоминаем, насколько точно к открытию окна комбо
func on_press_freeze() -> void:
	var c: AttackData = p.combat.cur
	press_off = absf((c.combo_from - p.combat.k()) * c.duration) if active() and c != null else 9.0

func bonus() -> float:
	return (1.0 + FLOW_DMG * flow) * boost

func can_use(a: AttackData) -> bool:
	if a.extra.get("finisher", false):
		return perfect and cashed >= FINISH_FLOW
	return true

## атака началась: прыжок, нырок, счёт потока, Freeze
func on_start(a: AttackData) -> void:
	if not active():
		return
	if a.extra.has("hop"):
		p.velocity.y = float(a.extra["hop"])
	if a.extra.has("inv"):
		p.inv = max(p.inv, float(a.extra["inv"]))        # нырок под удар в начале движения — доли секунды
	if a.extra.get("freeze", false):
		_freeze()
		return
	if a.extra.get("finisher", false):
		game.banner("BREAKER FINISHER", "", Color(1.0, 0.55, 0.9))
		cashed = 0
		perfect = false
	if a.id != last_id:
		flow = mini(MAX_FLOW, flow + 1)
	last_id = a.id

func _freeze() -> void:
	perfect = press_off <= PERFECT
	press_off = 9.0
	cashed = flow
	var col := Color(1.0, 0.55, 0.9)
	if perfect:
		p.swag = min(100.0, p.swag + 8.0 + 4.0 * flow)
		boost = 1.5
		for e in game.enemies:
			if is_instance_valid(e) and e.alive() and e.global_position.distance_to(p.global_position) < 3.4:
				e.interrupt_weak()
				e.stun(0.9)
		game.popup(p.global_position + Vector3(0, 2.4, 0), "PERFECT FREEZE", col)
		game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.4, 6.4, Color(col.r, col.g, col.b, 0.7), 0.4)
		game.fx.twinkle(p.global_position + Vector3(0, 0.8, 0), 14, col, 1.2)
		game.main.sfx("sfx_parry", -2.0, 1.3)
		game.slowmo(0.25)
		events.append(["perfect", flow])
	else:
		p.swag = min(100.0, p.swag + 2.0 * flow)
		boost = 1.2
		game.popup(p.global_position + Vector3(0, 2.4, 0), "FREEZE", Color(0.8, 0.9, 1.0))
		game.main.sfx("sfx_ui", -4.0, 0.8)
		events.append(["freeze", flow])
	flow = 0
	last_id = "br_freeze"

## попадание: усиление после Freeze потрачено
func on_hit(a: AttackData) -> void:
	if active() and not a.extra.get("freeze", false):
		boost = 1.0

## героя ударили: множитель урона (вращения наказуемы) и потеря потока
func on_hurt() -> float:
	if not active():
		return 1.0
	var c: AttackData = p.combat.cur
	var risky: bool = p.state == "attack" and c != null and (c.extra.get("spinny", false) or c.extra.get("freeze", false))
	if flow > 0 or cashed > 0:
		game.popup(p.global_position + Vector3(0, 2.3, 0), "СБИЛИ", Color(1.0, 0.45, 0.35))
		events.append(["broken", flow])
	flow = 0
	cashed = 0
	perfect = false
	boost = 1.0
	last_id = ""
	return SPIN_RISK if risky else 1.0

func hud() -> String:
	return "поток %s%s%s" % ["▮".repeat(flow), "▯".repeat(MAX_FLOW - flow), "  [F] ФИНАЛ" if perfect and cashed >= FINISH_FLOW else ("  [F] freeze" if flow >= 2 else "")]
