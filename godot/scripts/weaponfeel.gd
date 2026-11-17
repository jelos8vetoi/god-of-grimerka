## «Живое» оружие: модель в руке откликается на то, что с ней делают.
##   удар попал  — оружие вздрагивает вокруг кулака и гудит, затухая (у гитары дольше — струны), коротко сминается вдоль оси;
##   мах         — пока идёт активная часть удара, оружие чуть вытягивается вдоль оси (смазанный след);
##   покой       — едва заметно покачивается в руке, а не стоит как вкопанное;
##   езда        — доска под ногами мелко дребезжит тем сильнее, чем выше скорость.
## Двигается только внутренний узел модели: точка хвата, зона удара и IK рук считаются по прежним узлам и не меняются.
## Ось оружия в этом узле — Y (так его ставит rig.attach); для моделей без оси (бутылка, доска под ногами) — axis: false.
class_name WeaponFeel
extends Node

## shake — на сколько радиан вздрагивает, ring — секунд затухания, freq — частота гула, squash — смятие при ударе,
## stretch — вытягивание в махе, idle — покачивание в покое, rumble — дребезг от скорости
const SETS := {
	"vozduh": {"shake": 0.12, "ring": 0.16, "freq": 34.0, "squash": 0.06, "stretch": 0.07, "idle": 0.4},
	"bottles": {"shake": 0.1, "ring": 0.22, "freq": 46.0, "squash": 0.04, "stretch": 0.0, "idle": 1.4, "axis": false},
	"skateboard": {"shake": 0.08, "ring": 0.2, "freq": 44.0, "squash": 0.05, "stretch": 0.06, "idle": 0.7},
	"guitar": {"shake": 0.06, "ring": 0.5, "freq": 72.0, "squash": 0.03, "stretch": 0.05, "idle": 0.7},
	"board_ride": {"shake": 0.06, "ring": 0.2, "freq": 50.0, "squash": 0.1, "stretch": 0.0, "idle": 0.0, "rumble": 0.02, "axis": false},
}

var node: Node3D
var base: Transform3D
var cfg: Dictionary
var ring := 0.0          # сила гула после удара, 0…1
var ring_t := 0.0
var punch := 0.0         # смятие от удара
var smear := 0.0         # вытягивание в махе
var drive := 0.0         # скорость езды, 0…1 (доска)
var t := 0.0
var peak := 0.0          # для проверок: наибольшее отклонение за всё время, рад

static func on(target: Node3D, set_id: String) -> WeaponFeel:
	var f := WeaponFeel.new()
	f.node = target
	f.base = target.transform
	f.cfg = SETS[set_id]
	target.add_child(f)
	return f

## оружием попали: power 0 — лёгкий удар, 1 — тяжёлый, 2 — добивание
func hit(power: float) -> void:
	ring = clampf(0.5 + 0.3 * power, 0.0, 1.2)
	ring_t = 0.0
	punch = clampf(0.6 + 0.3 * power, 0.0, 1.3)

## идёт активная часть маха
func swing(k := 1.0) -> void:
	smear = max(smear, k)

func _process(dt: float) -> void:
	if node == null or not node.is_visible_in_tree():
		return
	t += dt
	ring_t += dt
	var amp: float = ring * exp(-ring_t / float(cfg["ring"]))
	if amp < 0.005:
		ring = 0.0
		amp = 0.0
	smear = move_toward(smear, 0.0, dt * 7.0)
	punch = lerpf(punch, 0.0, 1.0 - exp(-16.0 * dt))
	var w: float = float(cfg["freq"])
	var sh: float = float(cfg["shake"]) * amp + float(cfg.get("rumble", 0.0)) * drive
	var idle: float = 0.012 * float(cfg["idle"])
	var rot := Vector3(sin(ring_t * w) * sh + sin(t * 1.7) * idle, 0.0, sin(ring_t * w * 1.31 + 1.0) * sh + sin(t * 1.3 + 0.5) * idle)
	if drive > 0.0:
		rot += Vector3(sin(t * 83.0), 0.0, sin(t * 67.0 + 0.4)) * float(cfg.get("rumble", 0.0)) * drive
	var sy := 1.0
	var sx := 1.0
	if bool(cfg.get("axis", true)):
		sy = 1.0 + float(cfg["stretch"]) * smear - float(cfg["squash"]) * punch
		sx = 1.0 - 0.4 * float(cfg["stretch"]) * smear + 0.5 * float(cfg["squash"]) * punch
	else:
		sy = 1.0 - float(cfg["squash"]) * punch
		sx = 1.0 + 0.5 * float(cfg["squash"]) * punch
	node.transform = base * Transform3D(Basis.from_euler(rot).scaled(Vector3(sx, sy, sx)), Vector3.ZERO)
	peak = max(peak, abs(rot.x) + abs(rot.z))

## насколько оружие сейчас отклонено от покоя (для проверок), рад
func offset() -> float:
	return (base.basis.inverse() * node.transform.basis).get_euler().length()
