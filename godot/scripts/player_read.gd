## Что враги «знают» об игроке: только уже случившееся (сколько держит блок, повторяет ли один удар, в какую сторону
## уклоняется, сколько времени в воздухе, заходит ли за спину босса, на какой дистанции дерётся, каким стилем).
## Будущих нажатий не читает. Значения — скользящие средние за последние ~6–8 секунд; решения врагов (enemy_ai.gd,
## boss_moves.gd) берут отсюда повод выбрать подходящий приём, но приём всё равно идёт с замахом и меткой.
## Узел живёт в game (game.read), опрос — 10 раз в секунду, не каждый кадр.
class_name PlayerRead
extends Node

const RATE := 0.1           # опрос, с
const DECAY := 0.12         # доля в секунду, на которую «забывается» прошлое (≈8 с памяти)

var game
var acc := 0.0
var block_streak := 0.0     # сколько секунд подряд держит блок
var idle_front := 0.0       # сколько секунд стоит без ударов
var air := 0.0              # доля времени в воздухе (0…1)
var close := 0.5            # доля времени вплотную к ближайшему врагу (0…1)
var behind := 0.0           # доля ударов по боссу сзади или сбоку (0…1)
var dodge_l := 0.0          # сколько уклонений влево / вправо недавно
var dodge_r := 0.0
var same_hits := 0          # ударов подряд одной и той же атакой
var last_attack := ""
var style_use := {}         # стиль → доля недавних ударов
var swings := 0             # ударов всего (для проверок)

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var c: Combat = g.player.combat
	c.attack_started.connect(_on_attack)

func _on_attack(a: AttackData) -> void:
	swings += 1
	idle_front = 0.0
	if a.id == last_attack:
		same_hits += 1
	else:
		same_hits = 1
		last_attack = a.id
	var sid: String = String(game.player.style.id)
	for k in style_use:
		style_use[k] = float(style_use[k]) * 0.9
	style_use[sid] = float(style_use.get(sid, 0.0)) + 0.1
	# удар по боссу со спины или сбоку
	var b = game.boss_e
	if b != null and is_instance_valid(b) and b.alive():
		var to: Vector3 = game.player.global_position - b.global_position
		to.y = 0
		if to.length() < 4.5:
			var fw := Vector3(sin(b.face), 0, cos(b.face))
			behind = lerpf(behind, 1.0 if fw.dot(to.normalized()) < 0.2 else 0.0, 0.25)

## Уклонение: сторона относительно ближайшего врага (зовёт player.start_roll)
func on_roll(kind: String) -> void:
	if kind == "l":
		dodge_l += 1.0
	elif kind == "r":
		dodge_r += 1.0

func _process(dt: float) -> void:
	acc += dt
	if acc < RATE:
		return
	var step := acc
	acc = 0.0
	var p = game.player
	var forget := exp(-DECAY * step)
	dodge_l *= forget
	dodge_r *= forget
	block_streak = block_streak + step if p.state == "block" else 0.0
	idle_front += step
	air = lerpf(air, 1.0 if not p.is_on_floor() else 0.0, 1.0 - forget)
	var near := 99.0
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			near = minf(near, e.global_position.distance_to(p.global_position))
	close = lerpf(close, 1.0 if near < 2.8 else 0.0, 1.0 - forget)
	behind *= forget

## Любимая сторона уклонения: "l", "r" или "" (если явного перекоса нет)
func dodge_side() -> String:
	if dodge_l + dodge_r < 2.5:
		return ""
	if dodge_l > dodge_r * 1.8:
		return "l"
	if dodge_r > dodge_l * 1.8:
		return "r"
	return ""

## Стиль, которым игрок бьёт чаще всего, и его доля
func main_style() -> Array:
	var best := ""
	var bv := 0.0
	var sum := 0.0
	for k in style_use:
		sum += float(style_use[k])
		if float(style_use[k]) > bv:
			bv = float(style_use[k])
			best = String(k)
	return [best, bv / sum if sum > 0.0 else 0.0]

## Сводка для проверок и отладки
func facts() -> Dictionary:
	return {"block": snappedf(block_streak, 0.1), "idle": snappedf(idle_front, 0.1), "air": snappedf(air, 0.01), "close": snappedf(close, 0.01),
		"behind": snappedf(behind, 0.01), "dodge": dodge_side(), "same": same_hits, "style": main_style()[0]}
