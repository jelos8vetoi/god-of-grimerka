## Основа врага «5 НОЧЕЙ С ПАХАНОМ» — чистая логика без сцены (её же гоняют симуляции FNSim).
## Ход — «возможность»: раз в tick секунд враг бросает d20 и ходит, если выпало ≤ уровня (0 — не ходит,
## 20 — ходит всегда). Куда и как — решает сам враг (_move). У двери — общая логика: пришёл (звук и он виден
## в свете), стоит linger секунд; дверь закрыта — стучит и уходит; открыта — входит (скример).
## Поднятый монитор оттягивает вход до опускания (но не дольше MONITOR_GRACE) — как в жизни: заметишь, только
## когда опустишь планшет. Смерть возможна только из-за ошибки: у каждого входа есть предупреждение заранее.
class_name FNEnemy
extends RefCounted

const MONITOR_GRACE := 3.0       # с: сколько он ждёт, пока ты смотришь в камеры, прежде чем войти всё равно
const BLOCK_LEAVE := [2.4, 4.2]  # с: сколько стучит в закрытую дверь, прежде чем уйти

var id := ""
var level := 0
var spot := ""
var prev := ""
var move_t := 0.0
var door_t := 0.0                # сколько стоит у двери
var linger := 0.0                # сколько простоит, прежде чем войти
var block_t := 0.0               # сколько стучит в закрытую дверь
var block_need := 3.0
var grace_t := 0.0
var look := false                # смотрит прямо в камеру (вид)
var pose := 0                    # вариант позы в комнате (вид)
var moves := 0
var entered := false

func setup(st, eid: String, lvl: int) -> void:
	id = eid
	level = lvl
	spot = String(FNData.ENEMIES[eid]["start"])
	prev = spot
	move_t = _interval(st) * st.rng.randf_range(0.6, 1.2)

func cfg() -> Dictionary:
	return FNData.ENEMIES[id]

func _interval(st) -> float:
	return float(cfg()["tick"]) * st.rng.randf_range(0.88, 1.12)

## шанс хода: d20 ≤ уровня
func roll(st) -> bool:
	return level > 0 and st.rng.randi_range(1, 20) <= level

func tick(st, dt: float) -> void:
	if level <= 0 or entered:
		return
	if _at_door():
		_door_tick(st, dt)
		return
	move_t -= dt
	if move_t <= 0.0:
		move_t = _interval(st)
		if roll(st):
			_move(st)

## свой ход врага — в наследнике
func _move(_st) -> void:
	pass

func _at_door() -> bool:
	return spot in ["door_l", "door_r", "vent_l", "vent_t"]

## какая защита держит эту точку: дверь или заслонка
func _guard(st) -> bool:
	match spot:
		"door_l":
			return bool(st.door["l"])
		"door_r":
			return bool(st.door["r"])
		"vent_l":
			return bool(st.seal["l"])
		"vent_t":
			return bool(st.seal["t"])
	return false

func go(st, to: String, why := "") -> void:
	if to == spot:
		return
	prev = spot
	spot = to
	moves += 1
	look = false
	pose = st.rng.randi_range(0, 2)
	if _at_door():
		door_t = 0.0
		block_t = 0.0
		grace_t = 0.0
		block_need = st.rng.randf_range(BLOCK_LEAVE[0], BLOCK_LEAVE[1])
		var L: Array = cfg()["linger"]
		linger = lerpf(float(L[0]), float(L[1]), float(level) / 20.0) * st.rng.randf_range(0.9, 1.15)
	st.emit("move", {"e": id, "from": prev, "to": to, "why": why})

func _door_tick(st, dt: float) -> void:
	door_t += dt
	if _guard(st):
		block_t += dt
		if block_t >= block_need:
			st.emit("bang", {"e": id, "at": spot})
			_retreat(st)
		return
	block_t = maxf(0.0, block_t - dt * 0.5)
	if door_t < linger:
		return
	if st.monitor and grace_t < MONITOR_GRACE:
		grace_t += dt                          # смотрит в камеры — войдёт, как только опустит (или через 3 с)
		return
	entered = true
	st.attack(id, spot)

## ушёл от закрытой двери — откуда пришёл или на старт
func _retreat(st) -> void:
	go(st, String(cfg()["start"]), "retreat")
	move_t = _interval(st) * 1.3

## для FNSim и проверки: на какой стороне сейчас угроза
func threat() -> String:
	return spot if _at_door() else ""
