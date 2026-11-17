## Стиль «ТЯГА-812» (Пахан): пылесос с тремя режимами — езда, притягивание, выброс воздуха.
## Это не цепочки ударов: режимы ведёт свой контроллер (tyaga.gd), а связки между ними — таблица LINKS ниже
## (приём, сделанный сразу после другого из таблицы, бьёт сильнее: «СВЯЗКА»);
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
		"extra": {"heat": 16.0, "max": 3, "max_height": 2.2, "swallow": 0.25, "pull_far": 5.0, "pull_near": 9.5, "catch": 1.25, "tick": 0.3, "hold_stun": 0.45, "move": 1.6}}))
	# MODE 3 — выброс: короткое нажатие — воздушный выстрел вперёд
	s.add(AttackData.make({"id": "tg_shot", "kind": "tyaga", "title": "", "clip": "TyagaBlast", "duration": 0.45, "hits": [0.1], "damage": 14.0, "stagger": 30.0, "reach": 6.5, "arc": 0.9,
		"knockback": 12.0, "launch": 2.5, "power": 1, "feedback": "tg_shot", "extra": {"heat": 25.0, "recoil": 4.0}}))
	# …удержание — заряд и мощный выброс по области вокруг сопла; пойманные притягиванием получают в полтора раза больше
	s.add(AttackData.make({"id": "tg_burst", "kind": "tyaga", "title": "ПЕРЕГРУЗКА ДАВЛЕНИЯ", "clip": "TyagaBurst", "duration": 0.55, "hits": [0.1], "damage": 30.0, "stagger": 60.0, "reach": 5.0, "arc": 6.3,
		"knockback": 16.0, "launch": 5.5, "heavy": true, "power": 2, "feedback": "tg_burst", "extra": {"heat": 55.0, "recoil": 7.5, "charge": 0.45, "caught_mul": 1.5}}))
	# бросок пойманного: короткое ПКМ, пока враг у сопла, — он летит вперёд и сбивает тех, в кого попадёт
	s.add(AttackData.make({"id": "tg_throw", "kind": "tyaga", "title": "ЛОВИ", "clip": "TyagaThrow", "duration": 0.45, "hits": [0.1], "damage": 12.0, "stagger": 30.0, "reach": 1.4, "arc": 6.3,
		"knockback": 20.0, "launch": 4.5, "power": 1, "feedback": "tg_shot", "extra": {"heat": 15.0, "fly": 0.8, "tap": 0.18}}))
	s.add(AttackData.make({"id": "tg_bowl", "kind": "tyaga", "clip": "TyagaThrow", "hits": [0.0], "damage": 16.0, "stagger": 35.0, "reach": 1.3, "arc": 6.3, "knockback": 9.0, "launch": 3.0, "power": 1, "feedback": "hit_heavy"}))
	# соскок на скорости: E на ходу — прыжок с пылесоса с ударом вокруг
	s.add(AttackData.make({"id": "tg_leap", "kind": "tyaga", "title": "СОСКОК", "clip": "RideDismount", "hits": [0.5], "damage": 20.0, "stagger": 30.0, "reach": 2.6, "arc": 6.3, "knockback": 8.0, "launch": 3.0,
		"heavy": true, "power": 1, "feedback": "vz_heavy", "extra": {"min_speed": 5.0}}))
	# MODE 1 — езда: таран на скорости и удар с разворота на ходу
	s.add(AttackData.make({"id": "tg_ram", "kind": "tyaga", "clip": "RideSit", "hits": [0.0], "damage": 10.0, "stagger": 35.0, "reach": 1.0, "arc": 2.4, "knockback": 1.3, "launch": 3.0, "power": 1,
		"feedback": "tg_ram", "extra": {"min_speed": 5.0, "per_speed": 1.2, "cd": 0.6, "keep": 0.7, "boost_speed": 12.0, "boost_launch": 6.5}}))
	s.add(AttackData.make({"id": "tg_spin", "kind": "tyaga", "title": "ВОЛЧОК", "clip": "RideSpin", "duration": 0.5, "hits": [0.5], "damage": 18.0, "stagger": 25.0, "reach": 2.5, "arc": 6.3, "knockback": 7.0,
		"heavy": true, "power": 1, "cooldown": 0.8, "feedback": "vz_heavy", "extra": {"heat": 10.0}}))
	# ---------------- этап 3: приёмы на ногах ----------------
	# колено: [F], пока враг пойман у сопла, — подтянул трубой на себя и ударил коленом; враг подлетает
	s.add(AttackData.make({"id": "tg_knee", "kind": "tyaga", "title": "КОЛЕНО", "clip": "TyagaKnee", "duration": 0.42, "hits": [0.42], "damage": 15.0, "stagger": 40.0, "reach": 2.0, "arc": 2.4,
		"knockback": 3.0, "launch": 4.8, "power": 1, "feedback": "hit_heavy", "extra": {"lunge": 4.5}}))
	# широкий выброс: [F] — труба идёт слева направо, слабый, но широкий, замедляет
	s.add(AttackData.make({"id": "tg_wide", "kind": "tyaga", "title": "ШИРОКИЙ", "clip": "TyagaWide", "duration": 0.5, "hits": [0.3], "damage": 9.0, "stagger": 35.0, "reach": 4.6, "arc": 2.7,
		"knockback": 9.0, "power": 1, "feedback": "tg_shot", "extra": {"heat": 20.0, "recoil": 2.5, "slow": 1.5}}))
	# в землю: отпустить ПКМ, держа блок, — волна вокруг сопла подбрасывает всех рядом
	s.add(AttackData.make({"id": "tg_ground", "kind": "tyaga", "title": "В ЗЕМЛЮ", "clip": "TyagaGround", "duration": 0.55, "hits": [0.32], "damage": 12.0, "stagger": 30.0, "reach": 3.4, "arc": 6.3,
		"knockback": 1.5, "launch": 7.5, "heavy": true, "power": 1, "feedback": "tg_burst", "extra": {"heat": 35.0}}))
	# вверх: отпустить ПКМ, держа прыжок, — бьёт по тем, кто в воздухе, и подбрасывает снова; стоящих рядом — слабее
	s.add(AttackData.make({"id": "tg_up", "kind": "tyaga", "title": "ВВЕРХ", "clip": "TyagaUp", "duration": 0.5, "hits": [0.3], "damage": 20.0, "stagger": 30.0, "reach": 4.2, "arc": 2.8,
		"knockback": 3.0, "launch": 7.0, "power": 1, "feedback": "tg_shot", "extra": {"heat": 30.0, "ground_mul": 0.6, "ground_reach": 2.4}}))
	# в упор: короткий выброс, когда враг у самого сопла, — сильнее, отбрасывает дальше, отдача больше
	s.add(AttackData.make({"id": "tg_point", "kind": "tyaga", "title": "В УПОР", "clip": "TyagaPoint", "duration": 0.45, "hits": [0.18], "damage": 22.0, "stagger": 55.0, "reach": 2.2, "arc": 1.8,
		"knockback": 18.0, "launch": 2.0, "heavy": true, "power": 2, "feedback": "tg_burst", "extra": {"heat": 30.0, "recoil": 6.5, "near": 1.3}}))
	# ---------------- этап 3: приёмы верхом ----------------
	# таран бортом: в заносе пылесос несёт боком — враги разлетаются в стороны
	s.add(AttackData.make({"id": "tg_side", "kind": "tyaga", "title": "БОРТОМ", "clip": "RideSideRam", "hits": [0.0], "damage": 12.0, "stagger": 45.0, "reach": 1.3, "arc": 3.8, "knockback": 1.5, "launch": 2.5, "power": 1,
		"feedback": "tg_ram", "extra": {"min_speed": 4.0, "per_speed": 1.2, "cd": 0.6, "keep": 0.8, "boost_speed": 99.0, "boost_launch": 2.5, "slip": 0.3}}))
	# таран в прыжке: сверху, сбивает с ног
	s.add(AttackData.make({"id": "tg_airram", "kind": "tyaga", "title": "С НЕБА", "clip": "RideAirRam", "hits": [0.0], "damage": 16.0, "stagger": 50.0, "reach": 1.4, "arc": 3.0, "knockback": 1.0, "stun": 0.8, "power": 1,
		"feedback": "tg_ram", "extra": {"min_speed": 3.0, "per_speed": 1.4, "cd": 0.6, "keep": 0.85, "boost_speed": 99.0, "boost_launch": 0.0}}))
	# удар в заносе: ЛКМ, пока держишь занос, — мах свободной рукой и ногой по кругу
	s.add(AttackData.make({"id": "tg_drift", "kind": "tyaga", "title": "ХЛЫСТ", "clip": "RideDriftHit", "duration": 0.4, "hits": [0.4], "damage": 14.0, "stagger": 30.0, "reach": 2.7, "arc": 6.3, "knockback": 9.0,
		"power": 1, "cooldown": 0.6, "feedback": "vz_heavy", "extra": {"heat": 6.0}}))
	# удар при приземлении: ЛКМ в прыжке — пылесос падает камнем и бьёт по области
	s.add(AttackData.make({"id": "tg_slam", "kind": "tyaga", "title": "ПРИЗЕМЛЕНИЕ", "clip": "RideSlamLand", "hits": [0.0], "damage": 22.0, "stagger": 45.0, "reach": 3.0, "arc": 6.3, "knockback": 6.0, "launch": 4.5,
		"heavy": true, "power": 2, "feedback": "tg_burst", "extra": {"dive": 18.0}}))
	return s

## Связки режимов: что после чего считается связкой (окно LINK_T секунд, урон ×LINK_MUL).
const LINKS := {
	"tg_suck": ["tg_knee", "tg_burst", "tg_throw", "tg_wide"],      # притянул → колено / выброс / бросок
	"tg_knee": ["tg_point", "tg_shot", "tg_ground"],                # колено → в упор / в землю
	"tg_ground": ["tg_up"],                                         # в землю → вверх по подброшенным
	"tg_up": ["tg_shot", "tg_wide"],
	"tg_ram": ["tg_spin", "tg_drift", "tg_leap"],                   # таран → волчок / хлыст / соскок
	"tg_side": ["tg_drift", "tg_spin"],
	"tg_airram": ["tg_slam", "tg_spin"],
	"tg_slam": ["tg_spin", "tg_leap"],
	"tg_leap": ["tg_wide", "tg_ground", "tg_knee"],                 # соскок → приём на ногах
}
const LINK_T := 1.3
const LINK_MUL := 1.3

## параметры езды (не атаки): скорости, руление, занос, прыжок, нагрев
const RIDE := {
	"vmax": 10.5, "vboost": 14.5, "accel": 12.0, "coast": 6.0, "brake": 22.0,
	"steer": 2.8, "steer_drift": 4.8, "grip": 10.0, "grip_drift": 2.2,
	"jump": 7.0, "boost_heat": 20.0, "flip": 0.32,
	"mount": 0.42, "dismount": 0.38, "walk": 4.2,
	"vrev": 4.0, "kick": 3.2,          # задний ход и толчок ногой с места
}
const HEAT := {"max": 100.0, "cool": 22.0, "lock": 2.5}
