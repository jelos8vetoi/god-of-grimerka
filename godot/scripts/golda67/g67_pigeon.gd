## Живой голубь приквела: модель цельная (костей нет), поэтому двигается весь корпус вокруг лап —
## покачивается, иногда поворачивается, время от времени клюёт землю и переступает. Только вид, столкновений нет.
## Ставится поверх готовой модели: G67Pigeon.attach(узел_голубя, номер).
class_name G67Pigeon
extends Node

var bird: Node3D
var home := Vector3.ZERO
var yaw := 0.0            # куда смотрит сейчас
var yaw_to := 0.0         # куда поворачивается
var t := 0.0
var turn_in := 1.0        # через сколько следующий поворот
var peck_in := 2.0        # через сколько клюнет
var peck_t := -1.0        # идёт клевок (секунды от начала), −1 — нет
var pecks := 1            # сколько клевков подряд осталось
var rng := RandomNumberGenerator.new()
var to := Vector3.INF     # куда идёт (корм), в координатах родителя
var flight := false       # взлетел: позицию ведёт стайка (Yard), своё покачивание отключено

const PECK_LEN := 0.42    # один клевок
const PECK_ANGLE := 0.62  # наклон корпуса вперёд, рад

static func attach(node: Node3D, i: int) -> G67Pigeon:
	var p := G67Pigeon.new()
	p.bird = node
	p.home = node.position
	p.yaw = node.rotation.y
	p.yaw_to = p.yaw
	p.rng.seed = 6700 + i * 131
	p.t = p.rng.randf_range(0.0, 5.0)
	p.turn_in = p.rng.randf_range(0.4, 2.5)
	p.peck_in = p.rng.randf_range(0.6, 3.5)
	node.add_child(p)
	return p

## Бросили корм: подбежать к точке (координаты родителя) и поклевать
func feed(at: Vector3) -> void:
	to = at + Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
	to.y = home.y

func _process(dt: float) -> void:
	if bird == null or flight:
		return
	t += dt
	if to != Vector3.INF:
		var d: Vector3 = to - home
		if d.length() < 0.06:
			to = Vector3.INF
			peck_in = 0.05                       # дошёл — сразу клевать
		else:
			home += d.normalized() * minf(d.length(), 0.85 * dt)
			yaw_to = atan2(d.x, d.z)
			turn_in = 0.6
	# поворот: короткий, рывком, как у птицы
	turn_in -= dt
	if turn_in <= 0.0 and peck_t < 0.0:
		yaw_to = yaw + rng.randf_range(-1.1, 1.1)
		turn_in = rng.randf_range(1.2, 3.6)
	yaw = lerp_angle(yaw, yaw_to, minf(1.0, dt * 9.0))
	# клевок: быстро вниз, чуть медленнее обратно; обычно два-три подряд
	var pitch := 0.0
	if peck_t >= 0.0:
		peck_t += dt
		var u := peck_t / PECK_LEN
		pitch = PECK_ANGLE * (smoothstep(0.0, 0.3, u) - smoothstep(0.45, 1.0, u))
		if u >= 1.0:
			pecks -= 1
			peck_t = 0.0 if pecks > 0 else -1.0
			if pecks <= 0:
				peck_in = rng.randf_range(1.6, 4.5)
	else:
		peck_in -= dt
		if peck_in <= 0.0:
			peck_t = 0.0
			pecks = rng.randi_range(1, 3)
	# покачивание и «шаг» на месте
	var bob := sin(t * 5.2) * 0.012
	bird.rotation = Vector3(pitch + sin(t * 2.6) * 0.03, yaw, sin(t * 3.1) * 0.04)
	bird.position = home + Vector3(0, absf(bob) * 0.5, 0)
