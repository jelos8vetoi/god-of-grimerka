## MOD — влезает в интерфейс из щитовой (CAM 8). Ход — новый сбой (до MAX_GLITCH): подписи камер меняются
## местами, индикатор двери врёт, индикаторы гаснут, камера показывает старую картинку, ложная тревога,
## счётчик расхода пропадает. Набрал MAX_GLITCH — идёт сам: щитовая → правый коридор → правая дверь
## (ложная картинка правого коридора прячет его — проверяй светом). СБРОС СИСТЕМЫ снимает все сбои и
## отправляет его в щитовую. Если сбоев много долго — он открывает правую дверь сам (слышно лязг, видно глазами).
class_name FNMod
extends FNEnemy

const KINDS := ["labels", "door_fake", "leds_off", "freeze", "fake_alarm", "usage_hide"]
const MAX_GLITCH := 4
var force_t := 0.0

func tick(st, dt: float) -> void:
	if level <= 0 or entered:
		return
	if st.glitches.size() >= MAX_GLITCH and spot in ["power", "hall_r", "door_r"]:
		force_t += dt
		if force_t >= lerpf(30.0, 16.0, float(level) / 20.0) and bool(st.door["r"]):
			force_t = 0.0
			st.force_open("r")
	else:
		force_t = 0.0
	super.tick(st, dt)

func _move(st) -> void:
	if st.glitches.size() < MAX_GLITCH:
		var free: Array = KINDS.filter(func(k): return not st.glitches.has(k))
		if not free.is_empty():
			st.add_glitch(free[st.rng.randi() % free.size()])
			return
	match spot:
		"power":
			go(st, "hall_r")
			if not st.glitches.has("freeze"):
				st.add_glitch("freeze", "hall_r")
		"hall_r":
			go(st, "door_r")
		_:
			go(st, "power")

## СБРОС СИСТЕМЫ
func reset(st) -> void:
	force_t = 0.0
	if spot != "power":
		go(st, "power", "reset")
	move_t = _interval(st) * 1.5
