## GHOST — питается взглядом. Проявляется только на некоторых камерах (склад, игровая, вентиляция, «комната 9»)
## или в левом углу офиса — на несколько секунд, иногда всего на один кадр (безвредно). Пока на него смотрят,
## копится «одержимость» (haunt): шёпот громче, картинка плывёт, по краям краснеет. Отвёл взгляд — спадает.
## Набралась до конца — он здесь. Честно: от первого взгляда до скримера всегда больше STARE_MIN секунд.
class_name FNGhost
extends FNEnemy

const CAMS := ["storage", "arcade", "vent", "room9"]
const STARE_MIN := 1.6           # с: даже при уровне 20 столько можно смотреть до конца
var haunt := 0.0
var show_t := 0.0                # сколько ещё виден
var flicker := false             # проявился на один кадр — безвредно

func setup(st, eid: String, lvl: int) -> void:
	super.setup(st, eid, lvl)
	spot = "away"

func tick(st, dt: float) -> void:
	if level <= 0 or entered:
		return
	var seen: bool = st.sees(spot) and not flicker
	if seen:
		var need := lerpf(3.4, STARE_MIN, float(level) / 20.0)
		haunt += dt / need
		if haunt >= 1.0:
			entered = true
			st.attack(id, spot)
			return
	else:
		haunt = maxf(0.0, haunt - dt * 0.22)
	if spot != "away":
		show_t -= dt
		if show_t <= 0.0:
			go(st, "away", "fade")
			flicker = false
		return
	move_t -= dt
	if move_t <= 0.0:
		move_t = _interval(st)
		if roll(st):
			_move(st)

func _move(st) -> void:
	var opts: Array = CAMS.duplicate()
	if level >= 7:
		opts.append("corner")                      # в углу офиса — видно, если посмотреть налево
	var to: String = opts[st.rng.randi() % opts.size()]
	flicker = st.rng.randf() < 0.25
	show_t = 0.12 if flicker else st.rng.randf_range(4.0, 7.5)
	go(st, to, "flicker" if flicker else "show")
