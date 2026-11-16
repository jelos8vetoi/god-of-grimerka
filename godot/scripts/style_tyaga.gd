## Стиль «ТЯГА-812» (Пахан): пылесос с тремя режимами — езда, притягивание, выброс воздуха.
## Это не цепочки ударов, поэтому у стиля нет графа комбо: режимы ведёт свой контроллер (tyaga.gd),
## а числа каждого воздействия лежат здесь теми же AttackData и доходят до врага тем же HitInfo, что и удары балона.
class_name StyleTyaga

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "tyaga812"
	s.title = "ТЯГА-812"
	s.owner = "pahan"
	s.ready = true
	s.note = "пылесос: езда и таран, притягивание слабых врагов, выброс воздуха; нагревается"
	s.color = Color(0.75, 0.95, 1.0)
	s.color_hot = Color(1.0, 0.6, 0.3)
	s.roles = {"idle": "TyagaHold", "combat_idle": "TyagaHold"}
	# MODE 2 — притягивание: поток из сопла; пойманный у сопла получает тики урона и стоит оглушённый
	s.add(AttackData.make({"id": "tg_suck", "kind": "tyaga", "clip": "TyagaSuck", "hits": [0.0], "damage": 4.0, "stagger": 10.0, "reach": 7.0, "arc": 1.0, "knockback": 0.0,
		"extra": {"heat": 16.0, "max": 3, "max_height": 2.2, "pull_far": 5.0, "pull_near": 9.5, "catch": 1.25, "tick": 0.3, "hold_stun": 0.45, "move": 1.6}}))
	# MODE 3 — выброс: короткое нажатие — воздушный выстрел вперёд
	s.add(AttackData.make({"id": "tg_shot", "kind": "tyaga", "title": "", "clip": "TyagaBlast", "duration": 0.45, "hits": [0.1], "damage": 14.0, "stagger": 30.0, "reach": 6.5, "arc": 0.9,
		"knockback": 12.0, "launch": 2.5, "power": 1, "feedback": "tg_shot", "extra": {"heat": 25.0, "recoil": 4.0}}))
	# …удержание — заряд и мощный выброс по области вокруг сопла; пойманные притягиванием получают в полтора раза больше
	s.add(AttackData.make({"id": "tg_burst", "kind": "tyaga", "title": "ПЕРЕГРУЗКА ДАВЛЕНИЯ", "clip": "TyagaBlast", "duration": 0.55, "hits": [0.1], "damage": 30.0, "stagger": 60.0, "reach": 5.0, "arc": 6.3,
		"knockback": 16.0, "launch": 5.5, "heavy": true, "power": 2, "feedback": "tg_burst", "extra": {"heat": 55.0, "recoil": 7.5, "charge": 0.45, "caught_mul": 1.5}}))
	# MODE 1 — езда: таран на скорости и удар с разворота на ходу
	s.add(AttackData.make({"id": "tg_ram", "kind": "tyaga", "clip": "RideSit", "hits": [0.0], "damage": 10.0, "stagger": 35.0, "reach": 1.0, "arc": 2.4, "knockback": 1.3, "launch": 3.0, "power": 1,
		"feedback": "tg_ram", "extra": {"min_speed": 5.0, "per_speed": 1.2, "cd": 0.6, "keep": 0.7}}))
	s.add(AttackData.make({"id": "tg_spin", "kind": "tyaga", "title": "ВОЛЧОК", "clip": "RideSpin", "duration": 0.5, "hits": [0.5], "damage": 18.0, "stagger": 25.0, "reach": 2.5, "arc": 6.3, "knockback": 7.0,
		"heavy": true, "power": 1, "cooldown": 0.8, "feedback": "vz_heavy", "extra": {"heat": 10.0}}))
	return s

## параметры езды (не атаки): скорости, руление, занос, прыжок, нагрев
const RIDE := {
	"vmax": 10.5, "vboost": 14.5, "accel": 12.0, "coast": 6.0, "brake": 22.0,
	"steer": 2.8, "steer_drift": 4.8, "grip": 10.0, "grip_drift": 2.2,
	"jump": 7.0, "boost_heat": 20.0, "flip": 0.32,
	"mount": 0.42, "dismount": 0.38, "walk": 4.2,
}
const HEAT := {"max": 100.0, "cool": 22.0, "lock": 2.5}
