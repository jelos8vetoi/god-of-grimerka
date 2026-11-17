## Weapon Flow (этап 11): смена стиля — часть боя, а не подмена модели в руке.
##   Weapon Cancel — удар можно оборвать сменой стиля, но только после попадания и только если это не «тяжёлое
##                   обязательство»: виды атак NO_CANCEL (Heat, завершители цепочки, удары в землю, Freeze,
##                   приёмы пылесоса и доски) и атаки с extra.no_swap доигрываются до конца. Промахнулся — жди конца удара.
##   Perfect Swap  — смена нажата в окне комбо удара, который попал (в тот же момент, когда можно продолжать цепочку):
##                   смена вдвое быстрее, следующий удар сильнее (BOOST) — до первого попадания, не дольше BOOST_T;
##                   счётчик цепочки не обнуляется; открывается окно особого ответа нового стиля (как после точного
##                   уклонения); СВЭГ +8; сигнал perfect — для Team Hype (этап 12).
##   Без бесконечных комбо: между Perfect Swap пауза PERFECT_CD; возврат в тот же стиль, из которого только что
##                   пришёл (A → B → A за STALE_T секунд), Perfect не даёт; усиление тратится одним попаданием.
## У каждого стиля свой вход (FLOW): клип, эффект и звук появления оружия. Выход — клип уходящего стиля в player.set_style.
class_name WeaponFlow
extends Node

signal swapped(from: String, to: String, perfect: bool)

const T_NORMAL := 0.42
const T_PERFECT := 0.22
const BOOST := 1.35
const BOOST_T := 2.5
const PERFECT_CD := 1.2
const STALE_T := 4.0
const NO_CANCEL := ["heat", "finisher", "slam", "freeze", "tyaga", "skate"]
## intro — клип входа (после появления оружия), t — его длительность, fx — эффект появления
const FLOW := {
	"vozduh": {"title": "Балон", "intro": "", "fx": "thud"},
	"bottles": {"title": "Водяра", "intro": "", "fx": "splash"},
	"tyaga812": {"title": "ТЯГА-812", "intro": "", "fx": "wind"},
	"skateboard": {"title": "Скейт", "intro": "MSwing1", "t": 0.28, "fx": "sparks"},
	"guitar": {"title": "Гитара", "intro": "MStrum", "t": 0.3, "fx": "chord"},
	"breaker": {"title": "Breaker", "intro": "Toprock", "t": 0.3, "fx": "step"},
}

var p
var game
var boost_t := 0.0
var perfect_cd := 0.0
var pending := false          # идущая смена — Perfect
var keep_chain := 0
var last_from := ""
var last_to := ""
var last_t := -99.0
var from_id := ""
var events: Array = []        # для проверок: [что, откуда, куда]

func setup(player, g) -> void:
	p = player
	game = g

func _physics_process(dt: float) -> void:
	boost_t = max(0.0, boost_t - dt)
	perfect_cd = max(0.0, perfect_cd - dt)

## Можно ли оборвать текущий удар сменой стиля
func can_cancel() -> bool:
	var a: AttackData = p.combat.cur
	if p.state != "attack" or a == null or p.combat.hit_i <= 0:
		return false
	if NO_CANCEL.has(a.kind) or bool(a.extra.get("no_swap", false)):
		return false
	return p.combat.k() >= float(a.hits[0]) + 0.03

## Будет ли смена в стиль `to` прямо сейчас Perfect Swap
func judge(to: String) -> bool:
	if not can_cancel() or perfect_cd > 0.0 or not p.combat.in_combo_window():
		return false
	if to == last_from and p.style.id == last_to and game.clock - last_t < STALE_T:
		return false                      # туда-обратно между двумя стилями — без награды
	return true

## Смена началась. Возвращает её длительность.
func begin(from: String, to: String) -> float:
	pending = judge(to)
	keep_chain = p.combat.chain
	from_id = from
	events.append(["perfect" if pending else ("cancel" if p.state == "attack" else "swap"), from, to])
	if pending:
		var col: Color = Styles.by_id(to).color_hot
		game.popup(p.global_position + Vector3(0, 2.6, 0), "PERFECT SWAP", col)
		game.fx.ground_ring(p.global_position + Vector3(0, 0.05, 0), 0.3, 3.2, Color(col.r, col.g, col.b, 0.7), 0.3)
		game.fx.twinkle(p.global_position + Vector3(0, 1.0, 0), 10, col, 0.9)
		game.main.sfx("sfx_parry", -5.0, 1.5)
		game.slowmo(0.1)
	return T_PERFECT if pending else T_NORMAL

## Смена закончилась: оружие нового стиля в руке
func finish(to: String) -> void:
	var f: Dictionary = FLOW.get(to, {})
	var col: Color = Styles.by_id(to).color
	var at: Vector3 = p.global_position
	match String(f.get("fx", "")):
		"thud":
			game.fx.dust(at + Vector3(0, 0.1, 0), 6, game.fx.DUST, 0.8)
			game.main.sfx("sfx_thud", -8.0, 0.9)
		"splash":
			game.fx.sparks(at + Vector3(0, 1.2, 0), Vector3.UP, 8, Color(0.6, 0.85, 1.0), 0.7, 70.0)
			game.main.sfx("sfx_ui", -6.0, 1.4)
		"wind":
			game.fx.ground_ring(at + Vector3(0, 0.05, 0), 0.4, 2.6, Color(0.85, 0.93, 1.0, 0.5), 0.35)
			game.main.sfx("sfx_roll", -8.0, 0.7)
		"sparks":
			game.fx.sparks(at + Vector3(0, 0.2, 0), Vector3(sin(p.face), 0.3, cos(p.face)), 10, col, 1.0, 30.0)
			game.main.sfx("sfx_roll", -7.0, 1.3)
		"chord":
			game.fx.lightning(at, 1.6, col)
			p.guitar.play("chord", -10.0, 1.2)
		"step":
			game.fx.twinkle(at + Vector3(0, 0.3, 0), 8, col, 0.8)
			game.main.sfx("sfx_ui", -7.0, 1.0)
	if String(f.get("intro", "")) != "" and p.state in ["switch", "move"]:
		p.rig.play_for(String(f["intro"]), float(f["t"]) * (0.6 if pending else 1.0), 0.05)
		p.anim_hold = float(f["t"]) * 0.5
	if pending:
		pending = false
		boost_t = BOOST_T
		perfect_cd = PERFECT_CD
		p.combat.chain = keep_chain + 1          # цепочка продолжается
		p.combat.open("perfect", 0.8)            # особый ответ нового стиля
		p.swag = min(100.0, p.swag + 8.0)
		events.append(["perfect_done", from_id, to])
		swapped.emit(from_id, to, true)
	else:
		swapped.emit(from_id, to, false)
	last_from = from_id
	last_to = to
	last_t = game.clock

func bonus() -> float:
	return BOOST if boost_t > 0.0 else 1.0

## усиление после Perfect Swap тратится одним попаданием
func on_hit() -> void:
	boost_t = 0.0

## смену прервали (героя ударили): награды нет
func abort() -> void:
	pending = false
