## Район ДВОР приквела «ГОЛДА 67» — один цельный постсоветский двор, а не набор отдельных арен.
## Строится один раз на забег и не сдвигается (координаты двора = координаты мира); этапы забега — это ЗОНЫ одного и
## того же двора (ZONES): у подъезда, гаражи, детская площадка, парковка у ларька, северный проезд, беседка, хоккейная
## «коробка» Миши Минасяна. Бой привязан к прямоугольнику зоны (game.set_arena), из любой зоны видны остальные: дома,
## гаражи, ракета на площадке, прожекторы коробки.
##
## План (координаты двора, м; +Z — юг, дом Пахана; −Z — север, коробка):
##
##   z=−58   [девятиэтажка]   [хрущёвка]   [девятиэтажка]            дальний план: башни, кран
##   z=−38        беседка F        КОРОБКА E (арена Миши)
##   z=−21   ───────────── проезд ─────────────────────┐
##   z=−8    гаражи        ДЕТСКАЯ ПЛОЩАДКА C     парковка │ дом
##   z=+4     B (ряд)        тропинки             D ларёк │ (восток)
##   z=+21                 У ПОДЪЕЗДА A                    │
##   z=+30   ───────────── проезд вдоль дома ──────────────┘
##   z=+40   [ хрущёвка Пахана — подъезд ][ хрущёвка ]
##
## Модели — настоящие дома и уличные вещи проекта (assets/racing, лицом по +X) и модели приквела (assets/golda67).
## Повторяющиеся модели различаются оттенком, ростом и посадкой (tint), у каждой вещи есть причина стоять там, где она стоит.
class_name G67Yard
extends Node3D

const R := "res://assets/racing/"
## зоны двора (координаты двора = координаты мира): c — центр боя, h — полуразмеры прямоугольника боя (x, z),
## stand — где стоит турнирная стойка варианта «бой» (лицом по stand_yaw), name — название
const ZONES := {
	"podezd": {"c": Vector3(0, 0, 21), "h": Vector2(14.6, 14.6), "name": "у подъезда", "spawns": [[Vector3(-17.5, 0, 25), "из-за гаражей слева"], [Vector3(18.0, 0, 25), "от парковки справа"], [Vector3(-12, 0, 4.5), "с площадки"], [Vector3(9, 0, 4.5), "из-за площадки"]]},
	"garages": {"c": Vector3(-30, 0, 4), "h": Vector2(14.6, 14.6), "name": "гаражи", "spawns": [[Vector3(-38, 0, 21.5), "из-за гаражей с юга"], [Vector3(-22, 0, -13.5), "щель с северного проезда"], [Vector3(-30, 0, -13.5), "с северного проезда"], [Vector3(-12.5, 0, 10), "от подъезда"]], "stand": Vector3(-17.0, 0, 4.0), "stand_yaw": PI * 0.5},
	"playground": {"c": Vector3(1, 0, -8), "h": Vector2(14.6, 14.6), "name": "детская площадка", "spawns": [[Vector3(-16.5, 0, -10), "из-за гаражей"], [Vector3(18.5, 0, -12), "со стороны парковки"], [Vector3(1, 0, -25.5), "с северного проезда"], [Vector3(-6, 0, 9.5), "от подъезда"]], "stand": Vector3(3.5, 0, 5.1), "stand_yaw": 0.0},
	"parking": {"c": Vector3(30, 0, 2), "h": Vector2(14.6, 14.6), "name": "парковка у ларька", "spawns": [[Vector3(42, 0, -15.5), "из арки"], [Vector3(22, 0, 19.5), "из-за машин"], [Vector3(30, 0, 19.5), "из-за ларька"], [Vector3(12.5, 0, -6), "с площадки"]], "stand": Vector3(16.9, 0, 2.0), "stand_yaw": -PI * 0.5},
	"proezd": {"c": Vector3(2, 0, -21.5), "h": Vector2(20, 5.2), "name": "северный проезд"},
	"gazebo": {"c": Vector3(-27, 0, -31), "h": Vector2(14.6, 14.6), "name": "беседка"},
	"sport": {"c": Vector3(2, 0, -38.25), "h": Vector2(12.6, 10.9), "name": "коробка", "spawns": [[Vector3(2, 0, -25.5), "калитка коробки"], [Vector3(-13.5, 0, -44), "из-за борта слева"], [Vector3(17.5, 0, -44), "из-за борта справа"], [Vector3(2, 0, -52.5), "из-за трона"]]},
}
const HALF := 14.6             # полуразмер обычной зоны боя
const GATE_BOSS := Vector3(2.0, 0.0, -25.6)       # калитка коробки снаружи: отсюда начинается бой с Мишей
const BOSS_ENTRY := Vector3(2.0, 0.05, -33.0)     # где герой встаёт, когда бой с Мишей начался
const REST_POS := Vector3(-26.4, 0.0, -30.6)      # лавка в беседке
const STORAGE_POS := Vector3(-43.4, 0.0, -0.5)    # открытый бокс гаража
const KIOSK_POS := Vector3(39.9, 0.0, 7.0)        # окно «ШАУРМА 67»
const HANGER_POS := Vector3(-4.2, 0.0, 4.6)       # вешалка с бафами на детской площадке (у ковровыбивалки)
const HANGER_YAW := 0.5
## заначки: места в углах и закоулках двора (за гаражами, у арки, у беседки, за ларьком, под бельём, у ракеты, у трибуны,
## у мусорки, у щита…); на забег выбирается STASH_N — монета g67_golda_coin, 8–15 голды
const STASH := [
	Vector3(-41.5, 0, 22.0), Vector3(-40.0, 0, -15.0), Vector3(42.0, 0, -13.5), Vector3(-22.0, 0, -34.5),
	Vector3(41.8, 0, 13.5), Vector3(10.5, 0, 21.8), Vector3(6.8, 0, -13.0), Vector3(20.5, 0, -31.0),
	Vector3(-17.0, 0, 30.5), Vector3(38.5, 0, -21.0), Vector3(30.0, 0, 23.0), Vector3(-14.5, 0, 9.5),
]
const STASH_N := 5
## Места коротких событий и дверь «ТРЯПОК»: постоянные предметы двора
const EVENT_SPOTS := {"burmalda": Vector3(33.0, 0.0, -14.0), "button": Vector3(-18.0, 0.0, -15.0), "rags": Vector3(-43.4, 0.0, 8.2)}
const STASH_R := 1.2
const HOME_DOOR := Vector3(0.0, 0.0, 34.2)      # перед дверью подъезда (сама дверь — z 35.2): отсюда домой в хаб

var solids: Array = []         # [центр в координатах двора, радиус] — где нельзя появляться врагам
var missing: Array = []
var m_asphalt: StandardMaterial3D
var m_walk: StandardMaterial3D
var m_curb: StandardMaterial3D
var m_path: StandardMaterial3D
var m_snow: StandardMaterial3D
var m_court: StandardMaterial3D
var m_line: StandardMaterial3D
var m_sand: StandardMaterial3D
var m_carpet: StandardMaterial3D
var misha_car: Node3D
var queue: Array = []          # жители в очереди за шаурмой (узлы)
## Очередь у «ШАУРМА 67»: места от окошка назад. Последнее место — за ними — занимает КРОТ (G67Data.KROT, встреча 1).
## Очередь у «ШАУРМА 67»: места от окошка назад, около метра друг от друга, у каждого своё дело:
## первый наклонился к продавцу и показывает рукой, второй смотрит меню над окошком (и иногда оборачивается
## к стоящему сзади), третий в телефоне. Последнее место — за ними — занимает КРОТ (G67Data.KROT, встреча 1).
## Ещё один уже купил и ест в стороне от окошка.
const QUEUE_SPOTS := [Vector3(40.15, 0.07, 7.0), Vector3(39.05, 0.07, 7.12), Vector3(37.95, 0.07, 6.9)]
const QUEUE_ROLES := [
	{"base": "NOrder", "alts": ["NPocketsSide"]},
	{"base": "NMenu", "alts": ["NTalk"], "poi": Vector3(37.95, 1.5, 6.9)},
	{"base": "NPhone", "alts": ["NIdleL"]},
]
const EATER := {"pos": Vector3(40.1, 0.07, 4.9), "yaw": -0.6, "base": "NEat", "alts": ["NIdleL"]}
## Кто может стоять в очереди: модель, рост, со скелетом ли (тогда стоит и покачивается, как живой)
const QUEUE_PEOPLE := [
	{"path": "res://assets/minigames/npc_customer.glb", "h": 1.74, "rig": true, "key": "npc_customer"},
	{"path": "res://assets/minigames/npc_neighbor.glb", "h": 1.58, "rig": true, "key": "npc_neighbor"},
]
var people := {}               # фоновые жители двора: id → Rig
var residents := {}            # id → G67Resident
## Запасные места жителей (первое место — из PEOPLE): они ходят между ними по расписанию
const LIFE_PLACES := {
	"g67_npc_babushka": [
		{"pos": Vector3(7.6, 0.0, 30.6), "yaw": PI * 0.6, "base": "NBag", "alts": ["NBagRest"], "act": "feed", "act_clip": "NPoint", "act_len": 5.0},
		{"pos": Vector3(1.6, 0.0, 32.4), "yaw": PI, "base": "NBag", "alts": ["NScarf"]},
		{"pos": Vector3(3.5, 0.07, 34.3), "yaw": PI, "base": "NSitBag", "alts": ["NBagRest"]},
	],
	"g67_npc_taxi_driver": [
		{"pos": Vector3(31.3, 0.02, 12.0), "yaw": PI, "base": "NHips", "alts": ["NTaxiPhone"], "act": "wipe", "act_clip": "NJacket", "act_len": 6.0},
		{"pos": Vector3(27.2, 0.02, 12.8), "yaw": PI * 0.5, "base": "NSmoke", "alts": ["NTaxiPhone"]},
		{"pos": Vector3(29.6, 0.02, 9.6), "yaw": -PI * 0.5, "base": "NLeanBack", "alts": ["NHips"], "act": "car", "act_len": 8.0, "hide": true},
	],
	"g67_npc_ushanka": [
		{"pos": Vector3(-40.0, 0.02, -0.8), "yaw": PI, "base": "NThink", "alts": ["NPocketsSide"]},
		{"pos": Vector3(-38.2, 0.02, 3.6), "yaw": 1.2, "base": "NSmoke", "alts": ["NCross"]},
		{"pos": Vector3(-41.0, 0.02, 3.0), "yaw": -0.72, "base": "NThink", "alts": ["NPocketsSide"]},
	],
	"g67_npc_schoolboy": [
		{"pos": Vector3(4.0, 0.02, -4.0), "yaw": 1.6, "base": "NPhone", "alts": ["NStrap"]},
		{"pos": Vector3(11.0, 0.02, 3.2), "yaw": -1.0, "base": "NPhone", "alts": ["NIdleL"]},
	],
}

## Сирена кнопки: все жители в 30 м поворачиваются к столбу; у одного-двух — реплика
func siren_look(pos: Vector3) -> void:
	var said := 0
	for rid in residents:
		var R: G67Resident = residents[rid]
		if (R.rig as Node3D).global_position.distance_to(pos) < 30.0:
			R.siren(pos, said < 2)
			said += 1

## Бабушка кормит голубей: ближайшая стайка сбегается к точке
func feed_near(pos: Vector3) -> void:
	var best: Dictionary = {}
	var bd := 1e9
	for f in flocks:
		var d: float = Vector2(pos.x - (f["home"] as Vector3).x, pos.z - (f["home"] as Vector3).z).length()
		if d < bd:
			bd = d
			best = f
	if best.is_empty() or bd > 14.0:
		return
	for b in best["birds"]:
		var gp: G67Pigeon = b["p"]
		if is_instance_valid(gp):
			gp.feed(pos)
## Фоновые жители (решение владельца: четверо, без квестов, без толпы): модель, рост, место, поворот, вещь в руке.
## Стоят там, где им естественно быть; пройти сквозь них нельзя; в бою не участвуют.
const PEOPLE := [
	# бабушка у лавки возле подъезда: стоит с авоськой, иногда отдыхает или поправляет платок; голову поворачивает медленно
	{"id": "g67_npc_babushka", "h": 1.5, "pos": Vector3(4.9, 0.07, 34.1), "yaw": PI + 0.35, "carry": "mixamorig_RightHand",
		"base": "NBag", "alts": ["NBagRest", "NScarf"], "turn": 1.0, "look_r": 9.0, "poi": Vector3(0, 1.4, 22)},
	# мужик в ушанке у открытого гаража: руки в карманах; курит, скрещивает руки, переминается; поглядывает на коробку Миши
	{"id": "g67_npc_ushanka", "h": 1.72, "pos": Vector3(-43.2, 0.02, 1.2), "yaw": PI * 0.5 - 0.6,
		"base": "NPocketsSide", "alts": ["NSmoke", "NCross", "NIdleL"], "poi": Vector3(2, 1.5, -38)},
	# школьник на детской площадке: в телефоне; держит рюкзак за лямку, поправляет рюкзак
	{"id": "g67_npc_schoolboy", "h": 1.28, "pos": Vector3(-5.4, 0.02, -5.0), "yaw": 0.7,
		"base": "NPhone", "alts": ["NStrap", "NStraps", "NIdleL"], "poi": Vector3(2, 1.5, -38)},
	# таксист у своей машины на парковке: опёрся на неё спиной; телефон, руки на поясе, поправляет куртку; смотрит на дорогу
	{"id": "g67_npc_taxi_driver", "h": 1.76, "pos": Vector3(30.2, 0.02, 9.6), "yaw": -PI * 0.5,
		"base": "NLeanBack", "alts": ["NTaxiPhone", "NHips", "NJacket"], "poi": Vector3(30, 1.4, 22), "shot_side": -1.0},
]
var lifes: Array = []          # поведение всех жителей (G67Life): кому смотреть на героя — ставит Golda67
static var secret_tag := false     # победил Мишу — у подъезда появляется маленькое граффити
static var crowd_seed := 1
## Коробка Миши: турники (x, z, поворот, размер), борта и место трона — их читает бой (зацеп цепи) и постановка выхода
const BARS := [[-8.0, -43.5, 0.2, 2.7], [12.2, -33.0, PI * 0.5, 2.5]]
const COURT := Rect2(-11.0, -49.5, 26.0, 22.5)
const THRONE := Vector3(2.0, 0.03, -48.0)
## Трибуна у восточного борта: место, длина вдоль борта и ряды (сдвиг от центра к площадке и высота — в долях размеров модели)
const TRIBUNE := Vector3(17.7, 0.02, -38.5)
const TRIBUNE_LEN := 5.2
const TRIBUNE_ROWS := [[-0.28, 0.27], [0.0, 0.46], [0.27, 0.64]]
const ARENA_C := Vector3(2.0, 0, -38.0)
## Восемь зрителей (ТЗ владельца): ряд и место вдоль трибуны или своё место; excited — как охотно реагирует на удары
const FANS := [
	{"row": 0, "z": -1.7, "base": "SLean", "alts": ["SWatch"], "excited": 0.35},                   # наклонился вперёд, смотрит внимательно
	{"row": 0, "z": 1.4, "base": "SCross", "alts": [], "excited": 0.1},                             # сидит, руки скрещены
	{"row": 1, "z": -1.0, "base": "SWatch", "alts": ["SLean"], "excited": 0.95},                    # эмоционально реагирует на сильные удары
	{"row": 1, "z": 0.4, "base": "STalk", "alts": ["SWatch"], "excited": 0.25},                     # разговаривает с соседом
	{"row": 1, "z": 1.9, "base": "SWatch", "alts": ["SStand"], "excited": 0.4, "alt_hold": Vector2(4.0, 4.0)},     # иногда встаёт и садится
	{"row": 2, "z": -0.6, "base": "SFilm", "alts": ["SWatch"], "excited": 0.2},                     # снимает на телефон
	{"row": 2, "z": 1.0, "base": "SWatch", "alts": ["SPoint"], "excited": 0.4},                     # показывает пальцем на площадку
	{"pos": Vector3(-12.6, 0, -36.0), "base": "NCross", "alts": ["NIdleL"], "excited": 0.15},      # просто стоит у борта и смотрит
]
var tribune: Node3D
var flood: Array = []          # лампы четырёх мачт (OmniLight3D): до боя приглушены, включаются по очереди
var court_lights: Array = []   # общий свет коробки: [лампа, базовая энергия]
var fans: Array = []           # зрители у коробки (Rig)     # меняется на каждый забег: очередь каждый раз другая
var boss_spot := Vector3(2, 0, -44.5)        # где ждёт Миша (у своей машины, на ковре)

## Точки входа врагов в зону боя: четыре места у края зоны (из-за гаражей, из соседнего подъезда, из-за машин, с проезда…)
static func entry_points(id: String) -> Array:
	var z: Dictionary = zone(id)
	var c: Vector3 = z["c"]
	var h: Vector2 = z["h"] - Vector2(1.4, 1.4)
	return [Vector3(c.x - h.x, 0.05, c.z + h.y * 0.35), Vector3(c.x + h.x, 0.05, c.z - h.y * 0.35),
		Vector3(c.x - h.x * 0.35, 0.05, c.z - h.y), Vector3(c.x + h.x * 0.35, 0.05, c.z + h.y)]

## Поверхность под ногами для шагов: «ice» в коробке, «asphalt» на парковке и проезде, иначе «snow» (в подъезде шаги — бетон)
static func surface_at(pos: Vector3) -> String:
	for zid in ["sport", "parking", "proezd"]:
		var z: Dictionary = ZONES[zid]
		var c: Vector3 = z["c"]
		var h: Vector2 = z["h"]
		if absf(pos.x - c.x) <= h.x and absf(pos.z - c.z) <= h.y:
			return "ice" if zid == "sport" else "asphalt"
	return "snow"

static func zone(id: String) -> Dictionary:
	return ZONES.get(id, ZONES["podezd"])

# ---------------------------------------------------------------- помощники
func _noise_mat(a: Color, b: Color, freq: float, uv: float, rough := 0.9, seed_n := 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.seed = seed_n
	var nt := NoiseTexture2D.new()
	nt.noise = n
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	nt.color_ramp = g
	m.albedo_texture = nt
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	m.roughness = rough
	return m

func _flat(col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _box(pos: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi

## плита покрытия: от (x0, z0) до (x1, z1), верх на высоте y
func _slab(x0: float, z0: float, x1: float, z1: float, y: float, mat: Material) -> void:
	_box(Vector3((x0 + x1) * 0.5, y - 0.05, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), 0.1, absf(z1 - z0)), mat)

## бордюр вдоль отрезка
func _curb(a: Vector3, b: Vector3) -> void:
	var d := b - a
	_box((a + b) * 0.5 + Vector3(0, 0.07, 0), Vector3(0.22, 0.14, d.length()), m_curb, atan2(d.x, d.z))

## протоптанная тропинка от a до b
func _path(a: Vector3, b: Vector3, w := 1.5) -> void:
	var d := b - a
	_box((a + b) * 0.5 + Vector3(0, 0.012, 0), Vector3(w, 0.024, d.length()), m_path, atan2(d.x, d.z))

func _solid_box(pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 | 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	add_child(sb)
	solids.append([Vector3(pos.x, 0, pos.z), maxf(size.x, size.z) * 0.6 + 0.5])
	return sb

## Столб-цилиндр для коллизии: стволы, кусты, кучи — герой обходит, враги тоже (та же маска, что у остальной статики)
func _pillar(pos: Vector3, r: float, h: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 | 8
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = h
	cs.shape = cy
	sb.add_child(cs)
	sb.position = Vector3(pos.x, h * 0.5, pos.z)
	add_child(sb)
	solids.append([Vector3(pos.x, 0, pos.z), r + 0.4])

## Модель по пути или id: низ в pos, высота h, лицо (у моделей гонок — +X) повёрнуто на угол yaw.
## solid — поставить столкновение по габаритам. Возвращает корень.
func _put(id: String, pos: Vector3, yaw: float, h: float, solid := true, wide := 99.0) -> Node3D:
	var path := id if id.begins_with("res://") else (R + id + ".glb")
	var n := G67Models.spawn(path, self, pos, yaw, Vector3(wide, h, wide))
	if String(n.get_meta("from", "")) != "glb":
		missing.append(id)
		return n
	if solid:
		var s: Vector3 = n.get_meta("size", Vector3.ONE)
		_solid_box(pos + Vector3(0, s.y * 0.5, 0), Vector3(s.x, s.y, s.z), yaw)
	elif id.ends_with("_tree"):
		_pillar(pos, 0.3, 3.0)
	elif id == "bush":
		_pillar(pos, 0.45, 1.0)
	elif id == "trash_pile":
		_pillar(pos, 0.7, 0.8)
	return n

## Модель приквела (assets/golda67, лицо по +Z): yaw — куда смотрит лицо. fit: "h" — по высоте v, "d" — по длине
## вдоль Z, "w" — по ширине вдоль X. Нет файла — возвращает null (место остаётся за прежней заменой).
func _own(id: String, pos: Vector3, yaw: float, v: float, fit := "h", solid := true) -> Node3D:
	if not G67Models.has(id):
		return null
	var size := Vector3(99, v, 99)
	if fit == "d":
		size = Vector3(99, 99, v)
	elif fit == "w":
		size = Vector3(v, 99, 99)
	var n := G67Models.spawn(id, self, pos, yaw, size, fit)
	if solid:
		var s: Vector3 = n.get_meta("size", Vector3.ONE)
		_solid_box(pos + Vector3(0, s.y * 0.5, 0), Vector3(s.x, minf(s.y, 4.0), s.z), yaw)
	return n

## Оттенок экземпляра: материалы модели копируются и подкрашиваются — одинаковые гаражи и дома перестают быть одинаковыми
func _tint(n: Node, col: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		for s in inst.mesh.get_surface_count():
			var src := inst.get_active_material(s)
			if src is StandardMaterial3D:
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = col
				inst.set_surface_override_material(s, m)

func _light(pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	add_child(l)
	return l

func _lamp(pos: Vector3, energy := 3.4, shadow := false) -> void:
	_put("street_lamp", pos, 0.0, 5.2, false)
	_solid_box(pos + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
	lamps.append(_light(pos + Vector3(0, 4.6, 0), Color(1.0, 0.72, 0.42), energy, 15.0, shadow))

## сугроб: несколько слипшихся наметённых бугров разного размера (у бордюров, под деревьями, куда счищают дворники)
func _drift(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	if G67Models.has("g67_snowdrift"):
		# модель владельца: длинная ось — Z; кладём вдоль большей стороны, небольшие — покороче
		var along_x := size.x > size.z
		var length := maxf(size.x, size.z)
		var n := G67Models.spawn("g67_snowdrift", self, Vector3(pos.x, -0.08, pos.z), yaw + (PI * 0.5 if along_x else 0.0) + (PI if int(absf(pos.x + pos.z)) % 2 == 0 else 0.0), Vector3(99, 99, length), "d")
		var wide := minf(size.x, size.z) / maxf(0.01, (n.get_meta("size", Vector3.ONE) as Vector3).x)
		n.scale = Vector3(clampf(wide, 0.8, 2.2), clampf(size.y * 0.9, 0.7, 1.3), 1.0)
		_solid_box(Vector3(pos.x, 0.45, pos.z), Vector3(minf(size.x, size.z) * 0.8, 0.9, length * 0.9) if not along_x else Vector3(length * 0.9, 0.9, minf(size.x, size.z) * 0.8), yaw)
		return
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	root.rotation.y = yaw
	add_child(root)
	var h := int(absf(pos.x * 13.0 + pos.z * 7.0)) % 5
	var parts := [[Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0)], [Vector3(0.28, 0, 0.18), Vector3(0.62, 0.72, 0.7)], [Vector3(-0.3, 0, -0.14), Vector3(0.7, 0.6, 0.62)],
		[Vector3(0.05, 0, -0.3), Vector3(0.5, 0.45, 0.5)], [Vector3(-0.12, 0, 0.32), Vector3(0.45, 0.5, 0.45)]]
	for i in 3 + (h % 3):
		var pr: Array = parts[(i + h) % parts.size()] if i > 0 else parts[0]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 10
		sm.rings = 5
		mi.mesh = sm
		mi.material_override = m_snow
		var o: Vector3 = pr[0]
		var k: Vector3 = pr[1]
		mi.position = Vector3(o.x * size.x, -size.y * 0.18, o.z * size.z)
		mi.scale = Vector3(size.x * k.x, size.y * k.y * 1.25, size.z * k.z)
		root.add_child(mi)

## Рисованная надпись владельца (assets/golda67/decals/<id>.png) — граффити или табличка на стене.
## width — ширина в метрах; glow — светится сама (световой короб). Нет файла — прежняя надпись текстом.
func _decal(id: String, text: String, pos: Vector3, yaw: float, width: float, col: Color, px := 0.01, size := 64, glow := false) -> Node3D:
	var path := "res://assets/golda67/decals/%s.png" % id
	if not ResourceLoader.exists(path):
		return _sign(text, pos, yaw, col, px, size)
	var t: Texture2D = load(path)
	var sp := Sprite3D.new()
	sp.texture = t
	sp.pixel_size = width / float(t.get_width())
	sp.position = pos
	sp.rotation.y = yaw
	sp.double_sided = false
	sp.shaded = not glow
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.name = "decal_%s_%d" % [id, get_child_count()]
	sp.set_meta("decal", id)
	add_child(sp)
	return sp

## Номер бокса: своя рисованная табличка (61–63 от владельца), иначе пустая табличка из той же и цифры поверх
func _house_plate(num: int, pos: Vector3, yaw: float) -> void:
	if ResourceLoader.exists("res://assets/golda67/decals/sign_house_%d.png" % num):
		_decal("sign_house_%d" % num, str(num), pos, yaw, 0.42, Color(0.9, 0.85, 0.7), 0.005, 48)
		return
	var plate := _decal("sign_house_blank", str(num), pos, yaw, 0.42, Color(0.9, 0.85, 0.7), 0.005, 48)
	if not (plate is Sprite3D):
		return
	var l := _sign(str(num), Vector3(0, -0.005, 0.012), 0.0, Color(0.12, 0.11, 0.1), 0.0045, 48)
	remove_child(l)
	plate.add_child(l)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Arial"])
	f.font_weight = 800
	l.font = f
	l.name = "plate_digits_%d" % num

## надпись баллончиком или табличка на стене
func _sign(text: String, pos: Vector3, yaw: float, col: Color, px := 0.01, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	add_child(l)
	return l

# ---------------------------------------------------------------- двор
func build() -> void:
	m_asphalt = _noise_mat(Color(0.1, 0.105, 0.12), Color(0.19, 0.195, 0.21), 0.09, 0.25, 0.92, 3)
	m_walk = _noise_mat(Color(0.33, 0.33, 0.34), Color(0.45, 0.45, 0.46), 0.2, 0.5, 0.9, 7)
	m_curb = _flat(Color(0.5, 0.5, 0.5), 0.9)
	m_path = _noise_mat(Color(0.42, 0.45, 0.52), Color(0.58, 0.62, 0.7), 0.3, 0.6, 0.95, 11)
	m_snow = _noise_mat(Color(0.6, 0.66, 0.78), Color(0.92, 0.95, 1.0), 0.035, 0.09, 0.82, 5)
	# коробку на зиму залили: лёд с намёрзшим снегом, под ним — красная и синяя разметка
	m_court = _noise_mat(Color(0.5, 0.62, 0.74), Color(0.8, 0.88, 0.95), 0.06, 0.2, 0.16, 9)
	m_court.metallic = 0.25
	m_line = _flat(Color(0.75, 0.16, 0.18), 0.4)
	m_sand = _noise_mat(Color(0.5, 0.36, 0.22), Color(0.62, 0.47, 0.3), 0.3, 0.8, 0.95, 13)
	m_carpet = _noise_mat(Color(0.42, 0.06, 0.1), Color(0.56, 0.1, 0.14), 0.5, 1.5, 0.95, 17)
	# земля под снегом (общая, большая) и её твёрдость
	_box(Vector3(0, -0.06, -10), Vector3(260, 0.1, 260), m_snow)
	var floor_sb := StaticBody3D.new()
	floor_sb.collision_layer = 1 | 8
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(400, 1, 400)
	fcs.shape = fbs
	floor_sb.add_child(fcs)
	floor_sb.position = Vector3(0, -0.5, 0)
	add_child(floor_sb)
	# предел двора: по линии фасадов и гаражей; между домами прохода нет (там сугробы и заборы)
	for wl in [[Vector3(0, 2, 36.3), Vector3(100, 4, 1)], [Vector3(0, 2, -53.5), Vector3(100, 4, 1)], [Vector3(-47.5, 2, -8), Vector3(1, 4, 100)], [Vector3(44.8, 2, -8), Vector3(1, 4, 100)]]:
		var wb := StaticBody3D.new()
		wb.collision_layer = 1 | 8
		var wcs := CollisionShape3D.new()
		var wbs := BoxShape3D.new()
		wbs.size = wl[1]
		wcs.shape = wbs
		wb.add_child(wcs)
		wb.position = wl[0]
		add_child(wb)
	_houses()
	_roads()
	_zone_podezd()
	_zone_garages()
	_zone_playground()
	_zone_parking()
	_zone_gazebo()
	_zone_sport()
	_stick_decals()

## Рисованные надписи ложатся на стену вплотную: луч от надписи назад по её лицу находит поверхность модели
## (дом, гараж, будка), надпись встаёт на 5 см перед ней и разворачивается по её нормали. Не нашёл — остаётся как была.
func _stick_decals() -> void:
	var meshes: Array = find_children("*", "MeshInstance3D", true, false)
	for c in get_children():
		if not (c is Sprite3D) or not c.has_meta("decal"):
			continue
		var sp := c as Sprite3D
		var n := sp.global_transform.basis.z.normalized()
		var near: Array = meshes.filter(func(m): return (m as MeshInstance3D).global_position.distance_to(sp.global_position) < 25.0 or (m as MeshInstance3D).get_aabb().size.length() > 12.0)
		var flat := _flat_spot(near, sp, n)
		if not flat.is_empty():
			sp.global_position = Vector3(flat["pos"]) + n * 0.055      # гофра гаражей выступает на 4–5 см
			sp.set_meta("stuck", "flat")
			continue
		var hit := _surface_hit(near, sp.global_position + n * 0.7, -n, 5.0)
		if hit.is_empty():
			continue
		var hn: Vector3 = hit["normal"]
		if hn.dot(n) < 0.0:
			hn = -hn
		if absf(hn.y) > 0.5:
			# скос (верх арки, край крыши): поворот прежний, надпись чуть дальше от поверхности
			sp.global_position = Vector3(hit["pos"]) + n * 0.12
		else:
			sp.rotation.y = atan2(hn.x, hn.z)
			sp.global_position = Vector3(hit["pos"]) + hn * 0.055      # гофра гаражей выступает на 4–5 см
		sp.set_meta("stuck", true)

static var _tri := {}

## Ровный кусок стены под надпись: сетка 3×3 лучей по всей её площади должна попасть в одну плоскость (разброс
## глубины < 10 см, без скосов). Не вышло на месте — надпись сдвигается вдоль стены (до 3 м вбок, до 0,6 м по высоте).
## Возвращает {pos — центр на поверхности, normal} или пусто.
func _flat_spot(meshes: Array, sp: Sprite3D, n: Vector3) -> Dictionary:
	var w := sp.texture.get_width() * sp.pixel_size
	var h := sp.texture.get_height() * sp.pixel_size
	var right := Vector3.UP.cross(n).normalized()
	var offs: Array[Vector2] = []
	for k in 11:
		for dx in ([0.0] if k == 0 else [k * 0.3, -k * 0.3]):
			for dy in [0.0, 0.3, -0.3, 0.6]:
				offs.append(Vector2(dx, dy))
	for o in offs:
		var c: Vector3 = sp.global_position + right * o.x + Vector3.UP * o.y
		var depths: Array[float] = []
		var nsum := Vector3.ZERO
		var ok := true
		for gx in [-0.45, 0.0, 0.45]:
			for gy in [-0.4, 0.0, 0.4]:
				var p: Vector3 = c + right * (w * gx) + Vector3.UP * (h * gy)
				var hit := _surface_hit(meshes, p + n * 0.7, -n, 5.0)
				if hit.is_empty():
					ok = false
					break
				var hn: Vector3 = hit["normal"]
				if hn.dot(n) < 0.0:
					hn = -hn
				if absf(hn.y) > 0.4 or hn.dot(n) < 0.8:
					ok = false
					break
				depths.append((Vector3(hit["pos"]) - c).dot(n))
				nsum += hn
			if not ok:
				break
		if not ok:
			continue
		if depths.max() - depths.min() > 0.1 or -float(depths.min()) > float(sp.get_meta("max_depth", 2.5)):
			continue
		var fn := Vector3(nsum.x, 0.0, nsum.z).normalized()
		return {"pos": c + n * float(depths.max()), "normal": fn}
	return {}

## Ближайшая точка видимой геометрии по лучу: {pos, normal} или пусто
func _surface_hit(meshes: Array, from: Vector3, dir: Vector3, maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	var to := from + dir * maxd
	for mo in meshes:
		var m := mo as MeshInstance3D
		if m == null or m.mesh == null or not m.is_visible_in_tree():
			continue
		var gab: AABB = m.global_transform * m.get_aabb()
		if gab.grow(0.05).intersects_segment(from, to) == null:
			continue
		var tm: TriangleMesh = _tri.get(m.mesh)
		if tm == null:
			tm = m.mesh.generate_triangle_mesh()
			_tri[m.mesh] = tm
		if tm == null:
			continue
		var inv := m.global_transform.affine_inverse()
		var r: Dictionary = tm.intersect_ray(inv * from, (inv.basis * dir).normalized())
		if r.is_empty():
			continue
		var pw: Vector3 = m.global_transform * Vector3(r["position"])
		var d := from.distance_to(pw)
		if d < bd and (pw - from).dot(dir) > 0.0:
			bd = d
			best = {"pos": pw, "normal": (m.global_transform.basis * Vector3(r["normal"])).normalized()}
	return best

## Дома по периметру и дальний план. Фасады разного типа и оттенка, на разной глубине — силуэт двора не ровная коробка.
func _houses() -> void:
	# юг: дом Пахана — две хрущёвки встык, фасадом во двор (на север), подъезд — по центру
	var h1 := _put("khrushchevka", Vector3(-10.7, 0, 40.2), PI * 0.5, 15.0)
	_put("khrushchevka", Vector3(10.4, 0, 40.6), PI * 0.5, 15.4)
	_tint(h1, Color(0.95, 0.92, 0.86))
	_put("res://assets/golda67/g67_podezd_entrance.glb", Vector3(0.0, 0, 34.9), PI, 3.3)
	# запад дома: торец соседней пятиэтажки, развёрнутой боком
	if _own("g67_brick_house", Vector3(-41.5, 0, 45.0), PI * 0.5, 13.6) == null:      # кирпичная «сталинка» на углу
		var h3 := _put("khrushchevka", Vector3(-41.0, 0, 44.0), 0.0, 14.2)
		_tint(h3, Color(0.82, 0.86, 0.92))
	# север: две девятиэтажки и хрущёвка между ними, фасадами на юг
	var t1 := _put("panel_tower", Vector3(-22.0, 0, -59.0), -PI * 0.5, 27.0)
	_tint(t1, Color(0.9, 0.94, 1.0))
	if _own("g67_brick_house", Vector3(1.5, 0, -60.0), 0.0, 14.8) == null:            # кирпичный дом за коробкой
		_put("khrushchevka", Vector3(1.5, 0, -60.5), -PI * 0.5, 15.0)
	_put("panel_tower", Vector3(25.0, 0, -58.2), -PI * 0.5, 29.5)
	# восток: длинный дом вдоль проезда (две хрущёвки), фасадом на запад
	var e1 := _put("khrushchevka", Vector3(49.0, 0, 6.0), PI, 15.0)
	_tint(e1, Color(0.98, 0.9, 0.84))
	# дом с аркой: через неё турнир уходит дальше, в ПОДЗЕМКУ (надпись «ТУРНИР 67» — на щите рядом)
	if _own("g67_house_arch", Vector3(49.6, 0, -15.5), -PI * 0.5, 15.2) != null:
		_light(Vector3(45.5, 2.6, -15.5), Color(1.0, 0.8, 0.5), 2.0, 7.0)
	else:
		_put("khrushchevka", Vector3(49.5, 0, -15.5), PI, 14.6)
	_put("panel_tower", Vector3(50.0, 0, -37.0), PI, 27.0)
	# дальний план: башни за домами, кран стройки, водонапорная башня за гаражами
	for f in [[Vector3(-74, 0, -44), 0.3, 31.0, Color(0.6, 0.66, 0.8)], [Vector3(82, 0, 30), PI, 33.0, Color(0.62, 0.66, 0.78)],
			[Vector3(-70, 0, 34), 0.0, 29.0, Color(0.58, 0.62, 0.76)], [Vector3(60, 0, -86), -PI * 0.5, 34.0, Color(0.55, 0.6, 0.75)],
			[Vector3(-30, 0, -92), -PI * 0.5, 32.0, Color(0.55, 0.6, 0.75)]]:
		var t := _put("panel_tower", f[0], f[1], f[2], false)
		_tint(t, f[3])
	_put("tower_crane", Vector3(96, 0, -70), 0.6, 46.0, false)
	_put("water_tank", Vector3(-58.0, 0, -8.0), 0.0, 11.0, false)
	for p in [Vector3(-52, 0, 26), Vector3(-52, 0, -30), Vector3(57, 0, -52)]:
		_put("power_pole", p, PI * 0.5, 8.5, false)
	# теплотрасса за гаражами — уходит вдаль вдоль всего двора
	for i in 4:
		_put("heating_pipe", Vector3(-50.5, 1.2, -24.0 + i * 13.0), PI * 0.5, 1.6, false)

## Проезды, тротуары, бордюры, тропинки, сугробы
func _roads() -> void:
	# проезд вдоль дома Пахана и тротуар у подъездов
	_slab(-46, 27, 46, 33, 0.02, m_asphalt)
	_slab(-30, 33, 30, 35.6, 0.07, m_walk)
	_curb(Vector3(-30, 0, 33.0), Vector3(-2.2, 0, 33.0))
	_curb(Vector3(2.2, 0, 33.0), Vector3(30, 0, 33.0))
	_curb(Vector3(-46, 0, 27.0), Vector3(-1.6, 0, 27.0))
	_curb(Vector3(1.6, 0, 27.0), Vector3(34.6, 0, 27.0))
	# проезд вдоль восточного дома и карманы парковки
	_slab(35, -23, 41, 27, 0.02, m_asphalt)
	_slab(41, -23, 43.6, 27, 0.07, m_walk)
	_slab(28.4, -7.5, 35, 12.5, 0.02, m_asphalt)
	_curb(Vector3(28.4, 0, -7.5), Vector3(28.4, 0, 12.5))
	_curb(Vector3(35, 0, 12.5), Vector3(35, 0, 27.0))
	_curb(Vector3(35, 0, -23), Vector3(35, 0, -7.5))
	# гаражный проезд
	_slab(-43.4, -19, -36.4, 27, 0.02, m_asphalt)
	_curb(Vector3(-36.4, 0, -19), Vector3(-36.4, 0, 27))
	# северный проезд между площадкой и коробкой
	_slab(-36.4, -23, 35, -19, 0.02, m_asphalt)
	_curb(Vector3(-36.4, 0, -19), Vector3(-1.5, 0, -19))
	_curb(Vector3(1.5, 0, -19), Vector3(35, 0, -19))
	# тропинки, которые протоптали жильцы: от подъезда — к площадке, к гаражам и к ларьку
	_path(Vector3(0, 0, 27), Vector3(0.6, 0, 3.0), 1.7)
	_path(Vector3(-0.8, 0, 22), Vector3(-36.0, 0, 6.0), 1.3)
	_path(Vector3(0.8, 0, 21), Vector3(28.4, 0, 6.0), 1.3)
	_path(Vector3(0.6, 0, -15.5), Vector3(0.8, 0, -19.0), 1.6)
	_path(Vector3(1.6, 0, -23.0), Vector3(2.0, 0, -28.0), 2.2)
	_path(Vector3(-2.0, 0, -23.0), Vector3(-22.0, 0, -29.0), 1.2)
	# сугробы вдоль проездов — туда счищают снег
	for d in [[Vector3(-18, 0.25, 26.2), Vector3(7.0, 1.0, 1.8), 0.0], [Vector3(-33, 0.3, 26.3), Vector3(5.0, 1.2, 2.0), 0.05], [Vector3(20, 0.25, 26.2), Vector3(8.0, 1.0, 1.8), 0.0],
			[Vector3(34.2, 0.3, 20.0), Vector3(1.8, 1.1, 6.0), 0.0], [Vector3(-35.6, 0.3, 16.0), Vector3(1.6, 1.0, 7.0), 0.0], [Vector3(-35.7, 0.25, -9.0), Vector3(1.5, 0.9, 5.5), 0.0],
			[Vector3(-14, 0.25, -18.2), Vector3(8.0, 0.9, 1.6), 0.0], [Vector3(17, 0.3, -18.2), Vector3(9.0, 1.1, 1.7), 0.0], [Vector3(27.6, 0.3, 2.5), Vector3(1.6, 1.0, 6.5), 0.0]]:
		_drift(d[0], d[1], d[2])

## A — у подъезда: откуда Пахан выходит. Лавки у входа, доска объявлений, фонари вдоль проезда, машины у бордюра, мусорка.
func _zone_podezd() -> void:
	_put("bench", Vector3(-3.4, 0.07, 34.6), PI * 0.5, 0.95)
	_put("bench", Vector3(3.4, 0.07, 34.6), PI * 0.5, 0.95)
	_put("res://assets/golda67/g67_notice_board.glb", Vector3(6.6, 0.07, 35.0), PI, 1.8)
	if _own("g67_urn", Vector3(-1.9, 0.07, 33.9), PI, 0.8) == null:             # урна у лавки
		_put("barrel", Vector3(-1.9, 0.07, 33.6), 0.0, 0.75)
	# сушилка с бельём на газоне перед домом: бельё замёрзло колом
	laundry = _own("g67_laundry_lines", Vector3(10.5, 0, 21.0), 0.25, 3.6, "w", false)
	if laundry != null:
		_solid_box(Vector3(8.8, 1.1, 20.6), Vector3(0.3, 2.2, 0.3))
		_solid_box(Vector3(12.2, 1.1, 21.4), Vector3(0.3, 2.2, 0.3))
	_put("res://assets/golda67/g67_poster_stand.glb", Vector3(5.4, 0, 26.0), PI * 0.5, 2.2)      # реклама турнира у дороги
	_lamp(Vector3(-13.5, 0, 26.4), 3.6, true)
	_lamp(Vector3(13.5, 0, 26.4), 3.4)
	_light(Vector3(0, 2.6, 33.6), Color(1.0, 0.82, 0.55), 1.6, 6.0)              # лампа под козырьком
	_put("old_car", Vector3(-9.0, 0.02, 31.4), PI * 0.5, 1.5)                    # соседская «копейка» у бордюра
	var van := _put("old_van", Vector3(17.5, 0.02, 31.2), 0.0, 2.1)
	_tint(van, Color(0.9, 0.95, 1.0))
	# мусорная площадка сбоку от дома: бетонная плита, два бака, куча рядом
	_slab(-25.5, 33.4, -20.0, 36.2, 0.05, m_walk)
	_put("dumpster", Vector3(-24.2, 0.05, 35.0), PI * 0.5, 1.5)
	var d2 := _put("dumpster", Vector3(-22.4, 0.05, 35.1), PI * 0.5 + 0.12, 1.45)
	_tint(d2, Color(0.75, 0.85, 1.0))
	_put("trash_pile", Vector3(-20.6, 0.05, 34.6), 0.7, 0.8, false)
	# деревья на газоне между проездом и тропинками
	_put("bare_tree", Vector3(-8.5, 0, 17.5), 0.4, 7.5, false)
	_solid_box(Vector3(-8.5, 1.5, 17.5), Vector3(0.5, 3.0, 0.5))
	_put("birch_tree", Vector3(9.5, 0, 14.5), 1.2, 8.0, false)
	_solid_box(Vector3(9.5, 1.5, 14.5), Vector3(0.5, 3.0, 0.5))
	_put("bush", Vector3(-6.0, 0, 26.3), 0.0, 1.1, false)
	_put("bush", Vector3(8.6, 0, 26.2), 1.0, 1.3, false)
	_drift(Vector3(-8.5, 0.2, 17.5), Vector3(3.0, 0.7, 3.0))
	if secret_tag:
		var tag := _decal("graffiti_pahan_madk1d", "ПАХАН + MADK1D\nБЫЛИ ТУТ", Vector3(-3.3, 1.7, 36.0), PI, 1.45, Color(0.2, 0.5, 0.95, 0.9), 0.0038, 48)
		tag.name = "secret_tag"
		tag.set_meta("max_depth", 0.9)          # на фасаде, не в нише подъезда
		if tag is Sprite3D:
			(tag as Sprite3D).shaded = false     # стена в тени фонаря: свежая краска должна читаться и ночью
			(tag as Sprite3D).modulate = Color(0.78, 0.82, 0.95)

## B — гаражи: ряд разных гаражей, проезд, фургон, покрышки и бочки у открытого бокса
func _zone_garages() -> void:
	var tones := [Color(1, 1, 1), Color(0.7, 0.85, 0.75), Color(0.95, 0.8, 0.7), Color(0.75, 0.8, 0.95), Color(1, 1, 1), Color(0.9, 0.9, 0.7), Color(0.8, 0.7, 0.7), Color(0.85, 0.95, 0.9)]
	for i in 8:
		var z := -15.5 + i * 5.0
		var back: float = [0.0, 0.25, 0.0, -0.2, 0.3, 0.0, 0.15, -0.1][i]
		if i == 3 and G67Models.has("g67_garage_open"):
			# открытый бокс: внутри верстак, покрышки, горит лампочка — кто-то возится допоздна
			_own("g67_garage_open", Vector3(-45.9, 0, z), PI * 0.5, 3.15)
			_light(Vector3(-45.6, 1.7, z), Color(1.0, 0.8, 0.5), 2.4, 6.0)
			continue
		var g := _put("garage", Vector3(-45.6 - back, 0, z), 0.0, 3.0 + [0.0, 0.15, -0.1, 0.2, 0.0, 0.25, -0.05, 0.1][i])
		_tint(g, tones[i])
		_house_plate(61 + i, Vector3(-44.0 - back, 2.28, z - 1.7), PI * 0.5)
	_decal("graffiti_misha_main", "МИША ГЛАВНЫЙ", Vector3(-44.15, 1.5, 9.5), PI * 0.5, 2.4, Color(0.85, 0.63, 0.2), 0.008, 56)
	_decal("graffiti_67", "67", Vector3(-44.1, 1.3, -5.5), PI * 0.5, 2.0, Color(0.95, 0.75, 0.2), 0.02, 64)
	var van := _put("old_van", Vector3(-38.6, 0.02, 14.0), PI * 0.5, 2.1)
	_tint(van, Color(1.0, 0.85, 0.75))
	_put("tire_stack", Vector3(-42.6, 0.02, 1.4), 0.2, 1.1)
	_put("tire_stack", Vector3(-41.9, 0.02, 2.5), 1.1, 0.8)
	_put("barrel", Vector3(-42.8, 0.02, -3.0), 0.0, 1.0)
	_put("barrel", Vector3(-42.0, 0.02, -3.6), 0.5, 1.0)
	_put("traffic_cone", Vector3(-37.4, 0.02, -8.0), 0.0, 0.6, false)
	_put("trash_pile", Vector3(-42.6, 0.02, 21.5), 2.0, 0.9, false)
	_lamp(Vector3(-35.8, 0, 0.0), 3.4, true)
	_lamp(Vector3(-35.8, 0, -17.2), 2.6)
	_put("bare_tree", Vector3(-24.0, 0, 13.5), 2.0, 7.0, false)
	_solid_box(Vector3(-24.0, 1.5, 13.5), Vector3(0.5, 3.0, 0.5))
	_put("bush", Vector3(-22.5, 0, -4.5), 0.3, 1.2, false)
	_drift(Vector3(-24.0, 0.2, 13.5), Vector3(3.2, 0.7, 2.8))

## C — детская площадка: ракета-горка на песчаной подушке, низкий заборчик, лавки для мам, берёзы
func _zone_playground() -> void:
	_slab(-5.5, -15.5, 9.5, -1.5, 0.03, m_sand)
	_put("playground", Vector3(2.5, 0.03, -9.0), 0.0, 4.4)
	# заборчик: с трёх сторон, вход — с юга, где тропинка
	for i in 3:
		_put("fence_section", Vector3(-5.8, 0, -13.0 + i * 4.7), 0.0, 1.0, false, 4.7)
	for i in 3:
		_put("fence_section", Vector3(9.8, 0, -13.0 + i * 4.7), 0.0, 1.0, false, 4.7)
	for i in 3:
		_put("fence_section", Vector3(-3.4 + i * 4.7, 0, -15.8), PI * 0.5, 1.0, false, 4.7)
		_solid_box(Vector3(-3.4 + i * 4.7, 0.5, -15.8), Vector3(4.7, 1.0, 0.3))
	_solid_box(Vector3(-5.8, 0.5, -8.4), Vector3(0.2, 1.0, 14.0))
	_solid_box(Vector3(9.8, 0.5, -8.4), Vector3(0.2, 1.0, 14.0))
	_put("bench", Vector3(-7.4, 0, -6.5), 0.0, 0.95)
	_put("bench", Vector3(11.4, 0, -10.5), PI, 0.95)
	_own("g67_urn", Vector3(-7.5, 0, -4.7), PI * 0.5, 0.8)
	# ковровыбивалка у тропинки к площадке: ковёр висит с осени
	_own("g67_carpet_rack", Vector3(-7.0, 0, 3.6), 0.2, 2.1)
	# вешалка с бафами рядом: сюда идёт вариант «БАФ» (G67World.gate_spot)
	_own("g67_fit_hanger", HANGER_POS, HANGER_YAW, 1.9)
	_put("birch_tree", Vector3(-9.5, 0, -1.0), 0.0, 8.5, false)
	_solid_box(Vector3(-9.5, 1.5, -1.0), Vector3(0.5, 3.0, 0.5))
	_put("birch_tree", Vector3(-11.0, 0, -4.2), 2.1, 7.2, false)
	_solid_box(Vector3(-11.0, 1.5, -4.2), Vector3(0.5, 3.0, 0.5))
	_put("birch_tree", Vector3(13.0, 0, -2.5), 1.0, 8.0, false)
	_solid_box(Vector3(13.0, 1.5, -2.5), Vector3(0.5, 3.0, 0.5))
	_put("bush", Vector3(-8.0, 0, -13.5), 0.0, 1.2, false)
	_lamp(Vector3(11.8, 0, 2.5), 3.4, true)
	_drift(Vector3(-10.2, 0.2, -2.5), Vector3(4.0, 0.7, 5.0))
	_drift(Vector3(-2.0, 0.2, 1.2), Vector3(3.0, 0.5, 1.6))

## D — парковка у ларька: машины в кармане, ларёк и остановка у проезда, трансформаторная будка, рекламный щит
func _zone_parking() -> void:
	var c1 := _put("old_car", Vector3(31.4, 0.02, -4.5), PI, 1.5)
	_tint(c1, Color(0.8, 0.9, 1.0))
	_put("old_car", Vector3(31.6, 0.02, 0.4), PI, 1.55)
	var c3 := _put("old_car", Vector3(31.3, 0.02, 9.6), 0.0, 1.5)
	_tint(c3, Color(1.0, 0.8, 0.7))
	_put("traffic_cone", Vector3(31.5, 0.02, 5.0), 0.0, 0.6, false)              # кто-то занял место конусом
	# шаурмичная «ШАУРМА 67» — у проезда, окном во двор; здесь КРОТ стоит в очереди (встреча 1)
	if _own("g67_shawarma_kiosk", Vector3(42.3, 0.07, 7.0), -PI * 0.5, 3.2) != null:
		# настоящая шаурмичная: вертел в окне, полосатый навес, жёлтый световой короб на крыше — на нём название
		_decal("sign_shawarma_box", "ШАУРМА 67", Vector3(40.85, 2.6, 7.22), -PI * 0.5, 2.1, Color(0.5, 0.07, 0.05), 0.0042, 64, true)
		_light(Vector3(41.5, 1.6, 7.0), Color(1.0, 0.6, 0.25), 2.2, 4.5)            # жар от вертела
	else:
		_put("kiosk", Vector3(42.4, 0.07, 7.0), PI, 3.0)
		_decal("sign_shawarma_plate", "ШАУРМА 67", Vector3(41.2, 3.3, 7.0), -PI * 0.5, 1.9, Color(1.0, 0.8, 0.2), 0.007, 56)
	_light(Vector3(40.4, 1.8, 7.0), Color(1.0, 0.82, 0.5), 3.0, 9.0)
	_queue()
	_people()
	_put("bus_stop", Vector3(42.6, 0.07, 19.0), PI, 2.7)
	_put("transformer_booth", Vector3(19.5, 0, -14.5), -PI * 0.5, 3.4)
	_decal("graffiti_dont_climb", "НЕ ВЛЕЗАЙ\nУБЬЁТ", Vector3(19.62, 1.08, -12.75), 0.0, 0.92, Color(0.9, 0.2, 0.15), 0.005, 48)
	_put("billboard", Vector3(44.0, 0, -19.5), PI * 0.75, 9.0, false)
	# «ТУРНИР 67» баллончиком поверх рекламы на щите (лицо щита — по +X модели, после поворота — во двор)
	_decal("graffiti_tournament", "ТУРНИР 67", Vector3(43.3, 6.2, -20.2), -PI * 0.75, 5.0, Color(1.0, 0.8, 0.2), 0.02, 64)
	_solid_box(Vector3(44.0, 2.0, -19.5), Vector3(0.6, 4.0, 0.6))
	_lamp(Vector3(34.3, 0, -10.5), 3.4, true)
	_lamp(Vector3(34.3, 0, 15.0), 3.2)
	_put("trash_pile", Vector3(40.6, 0.07, 3.6), 1.0, 0.7, false)
	if _own("g67_urn", Vector3(40.9, 0.07, 10.2), -PI * 0.5, 0.8) == null:
		_put("barrel", Vector3(40.9, 0.07, 10.2), 0.0, 0.75)
	_put("bare_tree", Vector3(22.0, 0, 9.5), 0.8, 7.0, false)
	_solid_box(Vector3(22.0, 1.5, 9.5), Vector3(0.5, 3.0, 0.5))
	_put("bush", Vector3(23.5, 0, -5.0), 0.0, 1.2, false)
	_drift(Vector3(22.0, 0.2, 9.5), Vector3(3.0, 0.7, 3.0))

## Очередь за шаурмой: случайные жители в случайном порядке, разного роста и в разной одежде (оттенок).
## Стоят лицом к окошку, друг за другом; пройти сквозь них нельзя.
func _queue() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crowd_seed * 7919 + 13
	var order: Array = []
	for i in QUEUE_SPOTS.size():
		order.append(rng.randi() % QUEUE_PEOPLE.size())
	# подряд двое одинаковых не стоят
	for i in range(1, order.size()):
		if order[i] == order[i - 1]:
			order[i] = (int(order[i]) + 1 + rng.randi() % (QUEUE_PEOPLE.size() - 1)) % QUEUE_PEOPLE.size()
	var tones := [Color(1, 1, 1), Color(0.82, 0.9, 1.0), Color(1.0, 0.86, 0.78), Color(0.86, 1.0, 0.88), Color(0.95, 0.85, 1.0), Color(0.78, 0.8, 0.86)]
	for i in QUEUE_SPOTS.size():
		var who: Dictionary = QUEUE_PEOPLE[order[i]]
		if not ResourceLoader.exists(String(who["path"])):
			missing.append(String(who["path"]))
			continue
		var pos: Vector3 = (QUEUE_SPOTS[i] as Vector3) + Vector3(0, 0, rng.randf_range(-0.08, 0.08))
		var h: float = float(who["h"]) * rng.randf_range(0.95, 1.06)
		var yaw := PI * 0.5 + rng.randf_range(-0.18, 0.18)                 # лицом к окошку (на восток)
		var node: Node3D = _person(String(who["path"]), String(who["key"]), h, pos, yaw, QUEUE_ROLES[i], 7000 + crowd_seed * 13 + i)
		_tint(node, tones[rng.randi() % tones.size()])
		_solid_box(pos + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
		node.name = "queue%d" % i
		queue.append(node)
	# уже купил: ест в стороне от окошка, спиной к очереди
	var ew: Dictionary = QUEUE_PEOPLE[(crowd_seed + 1) % QUEUE_PEOPLE.size()]
	if ResourceLoader.exists(String(ew["path"])):
		var en := _person(String(ew["path"]), String(ew["key"]), float(ew["h"]), EATER["pos"], float(EATER["yaw"]), EATER, 7100 + crowd_seed)
		_tint(en, tones[(crowd_seed * 3) % tones.size()])
		_solid_box((EATER["pos"] as Vector3) + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
		en.name = "queue_eater"
		queue.append(en)

## Человек со скелетом в своей позе (G67Poses): стоит, дышит; phase — сдвиг, чтобы соседи не двигались в такт
## Человек со скелетом и своим поведением (G67Life): основная поза, другие позы, взгляд. profile — см. G67Life.attach
func _person(path: String, key: String, h: float, pos: Vector3, yaw: float, profile: Dictionary, seed_v: int) -> Rig:
	var r := Rig.new()
	add_child(r)
	r.setup(path, h, G67Poses.clips(), true, 1.0, key + "_yd")      # свой ключ: набор клипов жителя, а не героя
	r.position = pos
	r.rotation.y = yaw
	var pf := profile.duplicate()
	pf["poi_ref"] = self                      # точка интереса — в координатах двора
	var life := G67Life.attach(r, pf, seed_v)
	if life != null:
		lifes.append(life)
		r.set_meta("life", life)
	return r

## Реакция зрителей на бой: сильный удар (hit), смена фазы босса (phase), победа (win). Не все сразу и не в такт:
## каждый со своей вероятностью и задержкой; после реакции — обратно в свою позу.
func crowd_react(kind: String) -> int:
	var n := 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = {"hit": ["RWow", "RLean"], "phase": ["RWow", "RUp", "RLean"], "win": ["RUp", "RYes"], "laugh": ["RYes", "RLean", "RWow"], "start": ["RUp", "RWow"],
		"special": ["RWow", "RUp"], "rise": ["RLean", "RWow", "RUp"], "lose": ["RLean", "RWow"]}.get(kind, ["RLean"])
	for fan in fans:
		if not is_instance_valid(fan) or not fan.has_meta("life"):
			continue
		var p: float = float(fan.get_meta("excited", 0.3))
		if kind != "hit":
			p = minf(1.0, p + 0.35)
		if rng.randf() > p:
			continue
		var life: G67Life = fan.get_meta("life")
		var clip: String = ("S" if bool(fan.get_meta("seated", false)) else "") + String(pool[rng.randi() % pool.size()])
		var delay := rng.randf_range(0.05, 0.7)
		get_tree().create_timer(delay, false).timeout.connect(func():
			if is_instance_valid(life):
				life.react(clip))
		n += 1
	return n

## ---- ДВОР 1.5: предметы жизни двора и надписи
## Предмет жизни: модель assets/golda67/<id>.glb, если есть, иначе серая коробка нужного размера с коллизией (модели — из Blender)
var life_props := {}
var gazebo_people: Array = []
func _noop_unused() -> void:
	pass
var carpet_rack_node: Node3D = null

func _lifeprop(id: String, pos: Vector3, yaw: float, size: Vector3) -> Node3D:
	if G67Models.has(id):
		var n := G67Models.spawn(id, self, pos, yaw, size)
		_solid_box(pos + Vector3(0, size.y * 0.5, 0), size, yaw)
		life_props[id] = n
		return n
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.5, 0.52, 0.55)
	mt.roughness = 0.9
	mi.material_override = mt
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.rotation.y = yaw
	mi.name = id + "_stub"
	add_child(mi)
	_solid_box(pos + Vector3(0, size.y * 0.5, 0), size, yaw)
	life_props[id] = mi
	return mi

func _life_props() -> void:
	# двое за столом беседки: сидят и разговаривают (DUOS gazebo1/gazebo2)
	var seats := [[Vector3(-22.9, 0.0, -30.0), -2.39], [Vector3(-25.5, 0.0, -32.8), 0.75]]
	for i in 2:
		var who: Dictionary = QUEUE_PEOPLE[i % QUEUE_PEOPLE.size()]
		if ResourceLoader.exists(String(who["path"])):
			var r := _person(String(who["path"]), String(who["key"]), float(who["h"]), seats[i][0], float(seats[i][1]), {"base": "STalk", "alts": ["SWatch", "SLean"], "base_hold": Vector2(5.0, 9.0)}, 8100 + i)
			r.name = "gazebo%d" % (i + 1)
			gazebo_people.append(r)
	carpet_rack_node = get_node_or_null("g67_carpet_rack") as Node3D
	_lifeprop("g67_intercom", Vector3(-1.3, 0.9, 35.0), PI, Vector3(0.3, 0.45, 0.12))
	_lifeprop("g67_garage_radio", Vector3(-42.4, 0.0, 4.8), PI * 0.5, Vector3(0.5, 0.35, 0.3))
	_lifeprop("g67_box_nothing", Vector3(-40.6, 0.0, -3.2), 0.3, Vector3(0.7, 0.5, 0.6))
	_lifeprop("g67_puhosos", Vector3(-39.0, 0.0, 8.0), 0.8, Vector3(1.1, 1.0, 0.8))
	_lifeprop("g67_workbench", Vector3(-39.2, 0.0, -2.2), PI * 0.5, Vector3(1.6, 0.9, 0.7))

## Надпись-листок: кинд paper/graffiti/marker/plate/sticker/banner; лицом к yaw (PI — к двору от фасада z = 35)
func _note(kind: String, text: String, pos: Vector3, yaw: float, sub := "", k := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var big := kind == "graffiti"
	var small := kind == "marker" or kind == "sticker"
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 56 if big else (30 if small else 36)
	lb.pixel_size = (0.0075 if big else (0.0035 if small else 0.0042)) * k
	lb.outline_size = 10 if big else 4
	lb.width = 520.0 if not big else 760.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.position = Vector3(0, 0, 0.012)
	lb.shaded = false
	match kind:
		"graffiti":
			lb.modulate = Color(0.95, 0.35, 0.3)
			lb.rotation.z = randf_range(-0.05, 0.05)
		"marker":
			lb.modulate = Color(0.1, 0.1, 0.12)
			lb.outline_modulate = Color(0.85, 0.85, 0.8, 0.0)
		"sticker":
			lb.modulate = Color(1.0, 0.9, 0.2)
			lb.outline_modulate = Color(0, 0, 0, 1)
		"plate":
			lb.modulate = Color(0.08, 0.08, 0.1)
			lb.outline_modulate = Color(0.75, 0.75, 0.78, 1)
		"banner":
			lb.modulate = Color(0.95, 0.9, 0.5)
			lb.outline_modulate = Color(0.1, 0.35, 0.15, 1)
		_:
			lb.modulate = Color(0.06, 0.06, 0.08)
			lb.outline_modulate = Color(0.95, 0.95, 0.92, 1)
	root.add_child(lb)
	if kind in ["paper", "plate", "banner"]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var lines := maxi(1, int(ceil(text.length() / 17.0)))
		qm.size = Vector2(0.62 if kind != "banner" else 1.4, 0.16 + 0.1 * lines) * k
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = {"paper": Color(0.94, 0.93, 0.88), "plate": Color(0.62, 0.64, 0.68), "banner": Color(0.18, 0.4, 0.2)}[kind]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = m
		q.position = Vector3(0, 0, 0.004)
		root.add_child(q)
		(lb as Label3D).position = Vector3(0, 0, 0.014)
	if kind == "paper":
		sway_notes.append(root)
	notes.append({"node": root, "text": text, "sub": sub, "kind": kind})
	return root

var notes: Array = []
var sway_notes: Array = []
## Что где висит. cl — группа для [E]: одна точка на группу, повторное нажатие листает листки группы
const SIGN_AT := {
	"jelos_all": [Vector3(6.4, 1.55, 34.82), PI, "board"], "uk": [Vector3(6.9, 1.25, 34.82), PI, "board"], "serega_board": [Vector3(6.3, 1.0, 34.82), PI, "board"],
	"y2016": [Vector3(6.85, 0.95, 34.82), PI, "board"], "okak1": [Vector3(7.5, 0.7, 34.82), PI, ""],
	"niche": [Vector3(-5.4, 0.9, 34.88), PI, "basement"], "shovel": [Vector3(5.7, 1.3, 33.4), PI, "shovel"],
	"jelos_was": [Vector3(-18.0, 2.2, 35.1), PI, ""], "in_this1": [Vector3(-21.8, 1.4, 35.1), PI, ""],
	"g8_plate": [Vector3(-43.1, 2.6, -6.0), PI * 0.5, ""], "g8_no": [Vector3(-43.1, 1.5, -6.0), PI * 0.5, "g8"], "serega_wall": [Vector3(-43.1, 1.0, 13.0), PI * 0.5, ""],
	"mognut": [Vector3(-43.1, 1.6, 9.5), PI * 0.5, ""], "b42": [Vector3(-43.1, 0.9, 16.0), PI * 0.5, ""], "six7": [Vector3(-43.1, 2.3, 18.5), PI * 0.5, ""],
	"jelos_note": [Vector3(-39.2, 1.0, -2.2), PI, "bench"], "jelos_ok": [Vector3(33.0, 1.0, -14.0), PI, ""], "box_no": [Vector3(-40.6, 0.8, -3.6), PI, ""],
	"puh": [Vector3(-39.0, 1.1, 7.55), PI, ""], "in_this2": [Vector3(-43.1, 1.0, 11.0), PI * 0.5, ""], "okak2": [Vector3(-43.1, 0.8, 20.0), PI * 0.5, ""],
	"rocket": [Vector3(2.5, 1.6, -7.0), 0.0, "rocket"], "carpet": [Vector3(-7.0, 1.7, 4.4), 0.0, ""], "cheremsha": [Vector3(9.7, 1.3, -10.0), -PI * 0.5, "cheremsha"],
	"okak3": [Vector3(0.0, 0.9, -12.6), 0.0, ""], "kiosk_a": [Vector3(41.9, 1.5, 6.2), -PI * 0.5, "kiosk"], "kiosk_b": [Vector3(41.9, 1.5, 6.2), -PI * 0.5, "kiosk"],
	"kiosk_c": [Vector3(41.9, 1.5, 6.2), -PI * 0.5, "kiosk"], "kiosk_d": [Vector3(41.9, 1.5, 6.2), -PI * 0.5, "kiosk"], "place": [Vector3(28.6, 1.0, 9.6), -PI * 0.5, ""],
	"in_this3": [Vector3(31.3, 0.7, 11.3), 0.0, ""], "tp": [Vector3(19.5, 1.7, -12.7), 0.0, ""],
	"gz_note_a": [Vector3(-24.2, 0.92, -31.1), 0.0, "gazebo"], "gz_note_b": [Vector3(-24.2, 0.92, -31.1), 0.0, "gazebo"], "gz_note_c": [Vector3(-24.2, 0.92, -31.1), 0.0, "gazebo"],
	"gz_paper": [Vector3(-23.9, 0.92, -31.4), 0.0, "gazebo"], "court_rules": [Vector3(2.0, 2.6, -26.6), 0.0, "court"], "court_bets": [Vector3(14.6, 1.2, -38.5), -PI * 0.5, "court"],
}
var sign_groups := {}                  # группа → [{pos (точка [E]), cards: [{text, sub}]}]

func _life_signs() -> void:
	var seed_v := G67Yard.crowd_seed
	var pools := {}
	for sg in G67LifeData.SIGNS:
		var id := String(sg["id"])
		if not SIGN_AT.has(id):
			continue
		var pool := String(sg.get("pool", ""))
		if pool != "":
			if not pools.has(pool):
				pools[pool] = []
			(pools[pool] as Array).append(sg)
	var chosen := {}
	for pl in pools:
		var arr: Array = pools[pl]
		chosen[pl] = String(arr[seed_v % arr.size()]["id"])
	var wall8 := false
	for sg in G67LifeData.SIGNS:
		var id := String(sg["id"])
		if not SIGN_AT.has(id):
			if id == "seven_ads":
				for i in 8:
					_note("paper", "№ 7", Vector3(-7.9 + i * 0.34, 1.55, 34.9), PI, "", 0.45)
				sign_groups["wall8"] = {"pos": Vector3(-6.9, 0.0, 34.0), "cards": [{"text": sg["text"], "sub": sg["sub"]}], "title": "ОБЪЯВЛЕНИЯ"}
			continue
		var pool := String(sg.get("pool", ""))
		if pool != "" and String(chosen[pool]) != id:
			continue
		var ad: Array = SIGN_AT[id]
		_note(String(sg["kind"]), String(sg["text"]), ad[0], float(ad[1]), String(sg.get("sub", "")))
		if bool(sg.get("read", false)) and String(ad[2]) != "":
			var cl := String(ad[2])
			if not sign_groups.has(cl):
				var gp: Vector3 = ad[0]
				sign_groups[cl] = {"pos": Vector3(gp.x, 0.0, gp.z) + Vector3(sin(float(ad[1])), 0, cos(float(ad[1]))) * 0.9, "cards": [], "title": "ЛИСТОК"}
			(sign_groups[cl]["cards"] as Array).append({"text": sg["text"], "sub": String(sg.get("sub", ""))})

## Ветер колышет листки сильнее (в порыв)
var note_cull_t := 0.0

func sway_tick(t: float) -> void:
	note_cull_t -= get_process_delta_time()
	if note_cull_t <= 0.0 and hero != null and is_instance_valid(hero):
		note_cull_t = 0.4
		var hp := hero.global_position
		for nt in notes:
			var nd: Node3D = nt["node"]
			if is_instance_valid(nd):
				nd.visible = Vector2(nd.position.x - hp.x, nd.position.z - hp.z).length() < 18.0      # текст дальше 18 м не рисуется
	var k := 0.03 + (0.08 if gust_t > 0.0 else 0.0)
	for n in sway_notes:
		if is_instance_valid(n) and (n as Node3D).visible:
			(n as Node3D).rotation.z = sin(t * 2.0 + (n as Node3D).position.x) * k

## Стайки голубей вне зон боя: сидят, клюют; героя ближе 2,5 м — взлетают дугой и садятся в другом месте
var hero: Node3D = null
var lamps: Array = []
var gust_t := 0.0
var laundry: Node3D = null
var flocks: Array = []

func _flocks() -> void:
	flocks = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var homes := [Vector3(28, 0.05, -17), Vector3(-20, 0.05, -16), Vector3(-38, 0.05, -17), Vector3(9.4, 0.05, 29.4)]
	for hi in homes.size():
		var birds: Array = []
		for k in 4:
			var p: Vector3 = homes[hi] + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			var pg := G67Models.spawn("g67_pigeon", self, p, rng.randf() * TAU, Vector3(0.35, 0.35, 0.35))
			var gp := G67Pigeon.attach(pg, hi * 4 + k)
			birds.append({"n": pg, "p": gp, "off": p - homes[hi], "busy": false})
		flocks.append({"home": homes[hi], "birds": birds, "alt": homes[hi] + Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(-3.0, 3.0)), "at_alt": false})

func _process(_dt: float) -> void:
	win_tick(_dt)
	gust_t = maxf(0.0, gust_t - _dt)
	sway_tick(float(Time.get_ticks_msec()) * 0.001)
	if hero == null or not is_instance_valid(hero):
		return
	var hp := hero.global_position
	for f in flocks:
		var base: Vector3 = f["alt"] if bool(f["at_alt"]) else f["home"]
		if Vector2(hp.x - base.x, hp.z - base.z).length() > 2.5:
			continue
		_flee_flock(f)

func _flee_flock(f: Dictionary) -> void:
	var dest: Vector3 = f["home"] if bool(f["at_alt"]) else f["alt"]
	f["at_alt"] = not bool(f["at_alt"])
	for b in f["birds"]:
		var n: Node3D = b["n"]
		if not is_instance_valid(n):
			continue
		var from := n.global_position
		var to: Vector3 = dest + (b["off"] as Vector3)
		var h := randf_range(6.0, 8.0)
		var gp: G67Pigeon = b["p"]
		gp.flight = true
		var tw := n.create_tween()
		tw.tween_method(func(k: float):
			if is_instance_valid(n):
				n.global_position = from.lerp(to, k) + Vector3(0, sin(PI * k) * h, 0), 0.0, 1.0, randf_range(1.6, 2.2)).set_delay(randf_range(0.0, 0.25))
		tw.tween_callback(func():
			if is_instance_valid(gp):
				gp.home = to
				gp.flight = false)

func scare(pos: Vector3, r: float) -> void:
	for f in flocks:
		var base: Vector3 = f["alt"] if bool(f["at_alt"]) else f["home"]
		if Vector2(pos.x - base.x, pos.z - base.z).length() < r:
			_flee_flock(f)

func nearest_flock(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for f in flocks:
		var base: Vector3 = f["alt"] if bool(f["at_alt"]) else f["home"]
		var d: float = Vector2(pos.x - base.x, pos.z - base.z).length()
		if d < bd:
			bd = d
			best = f
	return best

## Порыв ветра: бельё и качели колышутся сильнее
func gust(sec: float) -> void:
	gust_t = sec
	if laundry != null and is_instance_valid(laundry):
		var tw := create_tween()
		for i in 4:
			tw.tween_property(laundry, "rotation:z", 0.05, 0.4)
			tw.tween_property(laundry, "rotation:z", -0.05, 0.4)
		tw.tween_property(laundry, "rotation:z", 0.0, 0.3)

## Поверхности двора: колеи, цепочки следов, наледь и лужи, заплатки и трещины асфальта, разметка, сугробы — MultiMesh, без коллизий и теней
var detail_nodes: Array = []

func _mm(mesh: Mesh, mat: Material, xf: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	detail_nodes.append(mi)
	return mi

func _alpha_mat(col: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _surface_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var flat := BoxMesh.new()
	flat.size = Vector3(1, 0.006, 1)
	# колеи на проезде: две тёмные полосы утоптанного снега
	var pz: Dictionary = ZONES["proezd"]
	var rut: Array = []
	for lane in [-1.1, 1.1]:
		for i in 22:
			var x: float = (pz["c"] as Vector3).x - 19.0 + i * 1.75
			var t := Transform3D(Basis().scaled(Vector3(1.9, 1, 0.5 + rng.randf() * 0.15)), Vector3(x, 0.03, (pz["c"] as Vector3).z + lane + rng.randf_range(-0.12, 0.12)))
			rut.append(t)
	_mm(flat, _alpha_mat(Color(0.12, 0.13, 0.17, 0.55)), rut)
	# цепочки следов: подъезд — ларёк, подъезд — гаражи, подъезд — беседка
	var steps: Array = []
	for path in [[HOME_DOOR + Vector3(0, 0, -2), KIOSK_POS + Vector3(-1.5, 0, 0)], [HOME_DOOR + Vector3(0, 0, -2), STORAGE_POS + Vector3(3, 0, 0)], [HOME_DOOR + Vector3(-1, 0, -2), Vector3(-25, 0, -29)]]:
		var a: Vector3 = path[0]
		var b: Vector3 = path[1]
		var L := a.distance_to(b)
		var n := int(L / 0.75)
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP)
		var yaw := atan2(dir.x, dir.z)
		for i in n:
			var p := a + dir * (float(i) * 0.75) + side * (0.17 if i % 2 == 0 else -0.17) + Vector3(rng.randf_range(-0.05, 0.05), 0.035, rng.randf_range(-0.05, 0.05))
			steps.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.14, 1, 0.32)), p))
	_mm(flat, _alpha_mat(Color(0.22, 0.24, 0.3, 0.6)), steps)
	# наледь и лужи на парковке, трещины и заплатки асфальта
	var par: Dictionary = ZONES["parking"]
	var pc: Vector3 = par["c"]
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.006
	var pud: Array = []
	for i in 9:
		pud.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(1.0, 2.6), 1, rng.randf_range(0.8, 1.8))), Vector3(pc.x + rng.randf_range(-12.0, 12.0), 0.04, pc.z + rng.randf_range(-9.0, 9.0))))
	_mm(cyl, _alpha_mat(Color(0.08, 0.12, 0.2, 0.8), 0.04, 0.6), pud)
	var cracks: Array = []
	for i in 40:
		var zc: Vector3 = ZONES["parking"]["c"] if i % 2 == 0 else ZONES["proezd"]["c"]
		var rx := 12.0 if i % 2 == 0 else 18.0
		cracks.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, PI)).scaled(Vector3(rng.randf_range(0.6, 2.2), 1, 0.04)), Vector3(zc.x + rng.randf_range(-rx, rx), 0.04, zc.z + rng.randf_range(-4.0, 4.0))))
	_mm(flat, _alpha_mat(Color(0.03, 0.03, 0.04, 0.8)), cracks)
	var patches: Array = []
	for i in 10:
		patches.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)).scaled(Vector3(rng.randf_range(1.0, 2.2), 1, rng.randf_range(0.8, 1.6))), Vector3(pc.x + rng.randf_range(-13.0, 13.0), 0.038, pc.z + rng.randf_range(-9.0, 9.0))))
	_mm(flat, _alpha_mat(Color(0.1, 0.1, 0.12, 0.9), 0.95), patches)
	# потёртая разметка парковочных мест
	var marks: Array = []
	for i in 9:
		marks.append(Transform3D(Basis().scaled(Vector3(0.1, 1, 4.2)), Vector3(pc.x - 11.0 + i * 2.8, 0.045, pc.z - 8.0)))
	_mm(flat, _alpha_mat(Color(0.78, 0.78, 0.74, 0.4), 0.95), marks)
	# сугробы у стен, бордюров и гаражей: низкие пологие бугры
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	var drifts: Array = []
	for i in 70:
		var t := rng.randf()
		var side := i % 3
		var pos := Vector3(lerpf(-44.0, 42.0, t), 0.0, 35.4) if side == 0 else (Vector3(-46.2, 0.0, lerpf(-30.0, 33.0, t)) if side == 1 else Vector3(43.8, 0.0, lerpf(-30.0, 33.0, t)))
		var sc := Vector3(rng.randf_range(1.6, 3.2), rng.randf_range(0.22, 0.42), rng.randf_range(0.7, 1.2))
		drifts.append(Transform3D(Basis(Vector3.UP, 0.0 if side == 0 else PI * 0.5).scaled(sc), pos + Vector3(0, 0.02, 0)))
	_mm(sph, _alpha_mat(Color(0.93, 0.95, 1.0, 1.0), 0.95), drifts)

## Фасад дома у подъезда: живые окна (тёплые, «телевизор», тёмные), тарелки, кондиционеры, вывески, козырёк, дым, пятна света на снегу
var win_mm: MultiMeshInstance3D = null
var win_state: Array = []      # на окно: {"kind": warm/tv/dark, "a": текущая яркость, "to": целевая, "ph": фаза}
var win_toggles := 0
var win_timer := 25.0
var facade_nodes: Array = []
var smoke_nodes: Array = []
var sign_texts: Array = []

func _facade_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3535
	var fz := 35.05
	var quad := BoxMesh.new()
	quad.size = Vector3(0.7, 0.95, 0.02)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var xf: Array = []
	win_state = []
	for row in 3:
		for col in 15:
			var x := -30.0 + col * 3.6
			if absf(x) < 4.0 or rng.randf() > 0.4:
				continue                             # у дома свои светящиеся окна: поверх — только редкие «живые»
			var kind := "warm" if rng.randf() < 0.4 else ("tv" if rng.randf() < 0.5 else "dark")
			xf.append(Transform3D(Basis(), Vector3(x + rng.randf_range(-0.15, 0.15), 3.4 + row * 2.9, fz)))
			win_state.append({"kind": kind, "a": 1.0 if kind != "dark" else 0.0, "to": 1.0 if kind != "dark" else 0.0, "ph": rng.randf() * TAU})
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, _win_col(win_state[i]))
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	win_mm = MultiMeshInstance3D.new()
	win_mm.multimesh = mm
	win_mm.material_override = wm
	win_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(win_mm)
	# мягкие тёплые пятна от окон на снегу под домом
	var glow := BoxMesh.new()
	glow.size = Vector3(1.0, 0.004, 1.0)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.7, 0.35, 0.10)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var gx: Array = []
	for i in 9:
		gx.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(2.2, 3.4), 1, rng.randf_range(2.0, 3.2))), Vector3(-30.0 + i * 7.5, 0.05, 32.8)))
	var gi := MultiMeshInstance3D.new()
	var gmm := MultiMesh.new()
	gmm.transform_format = MultiMesh.TRANSFORM_3D
	gmm.mesh = glow
	gmm.instance_count = gx.size()
	for i in gx.size():
		gmm.set_instance_transform(i, gx[i])
	gi.multimesh = gmm
	gi.material_override = gm
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)
	facade_nodes.append(gi)
	# козырёк и лампа над дверью подъезда; тарелки и кондиционеры; застеклённые балконы другим оттенком
	var metal := _flat(Color(0.45, 0.47, 0.5), 0.5)
	var awn := _box(HOME_DOOR + Vector3(0, 3.1, 1.3), Vector3(3.2, 0.12, 1.8), _flat(Color(0.3, 0.2, 0.15), 0.8))
	facade_nodes.append(awn)
	for x in [-26.0, -9.0, 14.0, 31.0]:
		var dish := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.45
		dm.bottom_radius = 0.05
		dm.height = 0.18
		dish.mesh = dm
		dish.material_override = metal
		dish.rotation.x = PI * 0.5 + 0.4
		dish.position = Vector3(x, 8.8 + rng.randf_range(-1.5, 1.5), 34.8)
		add_child(dish)
		facade_nodes.append(dish)
	for x in [-31.0, -3.0, 20.0]:
		var ac := _box(Vector3(x, 6.4 + rng.randf_range(-0.5, 0.5), 34.85), Vector3(0.8, 0.5, 0.35), _flat(Color(0.82, 0.82, 0.8), 0.7))
		facade_nodes.append(ac)
	var glass := _flat(Color(0.35, 0.55, 0.65, 0.55), 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [8.0, 11.5, 15.0]:
		facade_nodes.append(_box(Vector3(x, 5.2, 34.55), Vector3(2.4, 1.1, 0.25), glass))
	for sg in [["ПРОДУКТЫ", -22.0], ["АПТЕКА", 24.0], ["РЕМОНТ ОБУВИ", -34.0]]:
		var lb := _sign(String(sg[0]), Vector3(float(sg[1]), 2.7, 35.0), PI, Color(0.9, 0.85, 0.7), 0.012, 56)
		sign_texts.append(String(sg[0]))
		facade_nodes.append(lb)
	# дым из вентшахт на крыше и из трубы ларька
	for sp in [Vector3(-18, 11.8, 33.5), Vector3(4, 11.8, 33.5), Vector3(15, 11.8, 33.5), KIOSK_POS + Vector3(0.6, 2.6, 0.4)]:
		var pr := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.35, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.2
		pm.gravity = Vector3(0.5, 0.15, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.2
		pr.process_material = pm
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.75, 0.75, 0.8, 0.22)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = smat
		pr.draw_pass_1 = sm
		pr.amount = 24
		pr.lifetime = 6.0
		pr.position = sp
		pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pr)
		smoke_nodes.append(pr)

func _win_col(w: Dictionary) -> Color:
	var a: float = float(w["a"])
	match String(w["kind"]):
		"warm":
			return Color(1.0, 0.72, 0.35, 0.5 * a)
		"tv":
			return Color(0.55, 0.7, 1.0, 0.42 * a)
	return Color(1.0, 0.72, 0.35, 0.5 * a)

## Окна: «телевизор» мерцает; раз в 20–40 с одно случайное окно плавно гаснет или загорается (0,5 с)
func win_tick(dt: float) -> void:
	if win_mm == null or win_state.is_empty():
		return
	var mm := win_mm.multimesh
	for i in win_state.size():
		var w: Dictionary = win_state[i]
		var changed := false
		if String(w["kind"]) == "tv" and float(w["to"]) > 0.0:
			w["ph"] = float(w["ph"]) + dt * 1.7
			w["a"] = 0.55 + 0.45 * sin(float(w["ph"])) * sin(float(w["ph"]) * 0.37 + 1.0)
			changed = true
		elif absf(float(w["a"]) - float(w["to"])) > 0.001:
			w["a"] = move_toward(float(w["a"]), float(w["to"]), dt * 2.0)
			changed = true
		if changed and (i % 3 == int(Time.get_ticks_msec() / 100) % 3 or String(w["kind"]) != "tv"):
			mm.set_instance_color(i, _win_col(w))
	win_timer -= dt
	if win_timer <= 0.0:
		win_timer = randf_range(20.0, 40.0)
		var k := randi() % win_state.size()
		var w2: Dictionary = win_state[k]
		w2["to"] = 0.0 if float(w2["to"]) > 0.5 else 1.0
		if String(w2["kind"]) == "dark":
			w2["kind"] = "warm"
		win_toggles += 1

## Свет у подъезда и неровно мигающая лампа у гаражей
func _door_lamps() -> void:
	_light(HOME_DOOR + Vector3(0, 3.2, 1.5), Color(1.0, 0.82, 0.5), 1.4, 9.0)
	var gl := _light(STORAGE_POS + Vector3(2.5, 3.6, 0.0), Color(1.0, 0.85, 0.55), 1.6, 10.0)
	var tw := gl.create_tween().set_loops()
	for k in [[1.6, 0.9], [0.2, 0.07], [1.5, 0.12], [0.1, 0.05], [1.7, 1.4], [0.5, 0.08]]:
		tw.tween_property(gl, "light_energy", float(k[0]), 0.03)
		tw.tween_interval(float(k[1]))

## Оформление арены Миши: растяжки «ТУРНИР 67», реквизит у трона, царапины на льду, сугробы у бортов
var arena_nodes: Array = []

func _banner(a: Vector3, b: Vector3, text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "banner_" + text.to_lower().replace(" ", "_")
	add_child(root)
	var n := 14
	var cloth := _flat(Color(0.45, 0.05, 0.12), 0.9)
	var gold := _flat(Color(0.85, 0.66, 0.25), 0.5)
	var sag := 0.7
	var span := a.distance_to(b)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0) - Vector3(0, sag * sin(PI * t0), 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sag * sin(PI * t1), 0)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(p0.distance_to(p1) + 0.02, 1.5, 0.03)
		seg.mesh = bm
		seg.material_override = cloth
		root.add_child(seg)
		seg.global_position = (p0 + p1) * 0.5 - Vector3(0, 0.75, 0)
		seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)          # растяжка идёт вдоль X
		for k in [0.0, 1.42]:
			var edge := MeshInstance3D.new()
			var em := BoxMesh.new()
			em.size = Vector3(p0.distance_to(p1) + 0.02, 0.08, 0.05)
			edge.mesh = em
			edge.material_override = gold
			seg.add_child(edge)
			edge.position = Vector3(0, 0.75 - k - 0.04, 0)
	var mid := a.lerp(b, 0.5) - Vector3(0, sag + 0.75, 0)
	var lb := _sign(text, mid + Vector3(0, 0, 0.05), 0.0, Color(0.95, 0.8, 0.35), 0.022, 64)
	lb.name = "banner_text"
	var lb2 := _sign(text, mid + Vector3(0, 0, -0.05), PI, Color(0.95, 0.8, 0.35), 0.022, 64)
	for tl in [lb, lb2]:
		tl.get_parent().remove_child(tl)
		root.add_child(tl)
	var sw := root.create_tween().set_loops()
	sw.tween_property(root, "rotation:x", 0.012, 1.8).set_trans(Tween.TRANS_SINE)
	sw.tween_property(root, "rotation:x", -0.012, 1.8).set_trans(Tween.TRANS_SINE)
	arena_nodes.append(root)
	return root

func _arena_decor(x0: float, x1: float, z0: float, z1: float) -> void:
	_banner(Vector3(x0 + 0.5, 6.4, z1 + 0.3), Vector3(x1 - 0.5, 6.4, z1 + 0.3), "ТУРНИР 67")          # над калиткой
	_banner(Vector3(x0 + 0.5, 6.8, z0 - 0.3), Vector3(x1 - 0.5, 6.8, z0 - 0.3), "ТУРНИР 67")          # за троном между мачтами
	# реквизит у трона: ящик с магнитолой, свёрнутый ковёр, покрышки
	var crate := _box(Vector3(5.6, 0.3, -47.6), Vector3(0.8, 0.6, 0.55), _flat(Color(0.35, 0.24, 0.14), 0.9))
	_solid_box(Vector3(5.6, 0.3, -47.6), Vector3(0.8, 0.6, 0.55))
	var radio := _box(Vector3(5.6, 0.75, -47.6), Vector3(0.55, 0.3, 0.25), _flat(Color(0.1, 0.1, 0.12), 0.6))
	for sx in [-0.17, 0.17]:
		var sp := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.07
		cy.bottom_radius = 0.07
		cy.height = 0.03
		sp.mesh = cy
		sp.material_override = _flat(Color(0.3, 0.3, 0.32), 0.7)
		sp.rotation.x = PI * 0.5
		sp.position = Vector3(5.6 + sx, 0.75, -47.46)
		add_child(sp)
	var rug := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.2
	rc.bottom_radius = 0.2
	rc.height = 1.3
	rug.mesh = rc
	rug.material_override = m_carpet
	rug.rotation.z = PI * 0.5
	rug.position = Vector3(-1.9, 0.2, -47.9)
	add_child(rug)
	_put("tire_stack", Vector3(-3.6, 0.03, -48.2), 0.4, 0.7)
	_put("tire_stack", Vector3(-4.3, 0.03, -47.7), 1.1, 0.5)
	# царапины от коньков на льду и наметённый у бортов снег (без коллизии)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6767
	var scr := _flat(Color(0.92, 0.96, 1.0), 0.5)
	for i in 38:
		var cx := rng.randf_range(x0 + 2.0, x1 - 2.0)
		var cz := rng.randf_range(z0 + 2.0, z1 - 2.0)
		var l := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(rng.randf_range(1.0, 3.2), 0.004, 0.025)
		l.mesh = lm
		l.material_override = scr
		l.rotation.y = rng.randf_range(0.0, PI)
		l.position = Vector3(cx, 0.045, cz)
		add_child(l)
	var drift := _flat(Color(0.93, 0.95, 1.0), 0.95)
	for i in 26:
		var side := i % 4
		var t := rng.randf()
		var pos := Vector3(lerpf(x0, x1, t), 0.0, z1 + 0.2) if side == 0 else (Vector3(lerpf(x0, x1, t), 0.0, z0 - 0.2) if side == 1 else (Vector3(x0 - 0.2, 0.0, lerpf(z0, z1, t)) if side == 2 else Vector3(x1 + 0.2, 0.0, lerpf(z0, z1, t))))
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		d.mesh = sm
		d.material_override = drift
		d.scale = Vector3(rng.randf_range(1.2, 2.4), rng.randf_range(0.25, 0.45), rng.randf_range(0.5, 0.9))
		d.position = pos + Vector3(0, 0.05, 0)
		add_child(d)

## Свет коробки: общий свет k (0…1 от нормы); прожекторы мачт — по очереди (flood_on), все сразу (flood_all)
func court_k(k: float) -> void:
	for e in court_lights:
		if is_instance_valid(e[0]):
			(e[0] as OmniLight3D).light_energy = float(e[1]) * k

func flood_on(i: int, on := true) -> void:
	if i >= 0 and i < flood.size() and is_instance_valid(flood[i]):
		(flood[i] as OmniLight3D).light_energy = 1.6 if on else 0.25

func flood_all(e: float, col := Color(1.0, 0.92, 0.75)) -> void:
	for l in flood:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = e
			(l as OmniLight3D).light_color = col

## Жители двора: по одному каждого вида, со скелетом — стоят и дышат, каждый в своём такте
func _people() -> void:
	for i in PEOPLE.size():
		var who: Dictionary = PEOPLE[i]
		var id := String(who["id"])
		if not G67Models.has(id):
			missing.append(id)
			continue
		var r := _person(G67Models.DIR + id + ".glb", id, float(who["h"]), who["pos"], float(who["yaw"]), who, 6000 + i * 31)
		r.name = id
		if who.has("carry"):
			G67Carry.attach(r, String(who["carry"]))
		var bd := _solid_box((who["pos"] as Vector3) + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
		remove_child(bd)                                         # тело жителя едет вместе с ним
		r.add_child(bd)
		bd.position = Vector3(0, 0.9, 0)
		bd.rotation = Vector3.ZERO
		people[id] = r
		var pls: Array = [{"pos": who["pos"], "yaw": float(who["yaw"]), "base": String(who["base"]), "alts": who.get("alts", [])}]
		for extra in LIFE_PLACES.get(id, []):
			pls.append(extra)
		residents[id] = G67Resident.attach(self, r, r.get_meta("life"), bd, id, pls, 7000 + i * 53)

## F — беседка: тихий угол за гаражами, где сидят по вечерам. Здесь передышка перед коробкой.
func _zone_gazebo() -> void:
	_put("gazebo", Vector3(-27.0, 0, -33.5), 0.3, 3.4)
	_light(Vector3(-27.0, 2.2, -33.5), Color(1.0, 0.78, 0.5), 2.2, 7.0)
	_put("bench", Vector3(-22.8, 0, -29.5), PI * 0.8, 0.95)
	_put("barrel", Vector3(-24.2, 0, -31.4), 0.0, 0.8)                          # бочка вместо стола
	_put("birch_tree", Vector3(-33.5, 0, -30.0), 0.0, 8.5, false)
	_solid_box(Vector3(-33.5, 1.5, -30.0), Vector3(0.5, 3.0, 0.5))
	_put("birch_tree", Vector3(-31.0, 0, -38.5), 1.4, 7.6, false)
	_solid_box(Vector3(-31.0, 1.5, -38.5), Vector3(0.5, 3.0, 0.5))
	_put("bare_tree", Vector3(-19.0, 0, -37.0), 0.6, 7.0, false)
	_solid_box(Vector3(-19.0, 1.5, -37.0), Vector3(0.5, 3.0, 0.5))
	_put("bush", Vector3(-30.0, 0, -26.5), 0.0, 1.3, false)
	_put("bush", Vector3(-21.0, 0, -40.0), 1.0, 1.1, false)
	_lamp(Vector3(-18.5, 0, -24.5), 3.0)
	_drift(Vector3(-32.0, 0.25, -34.0), Vector3(4.5, 0.8, 6.0))

## E — хоккейная коробка: арена Миши Минасяна. Борта, разметка, прожекторы; в дальнем конце — «трон» авторитета:
## его машина, ковровая дорожка от ворот, стенды турнира, покрышки и бочки вместо мебели, турник.
func _zone_sport() -> void:
	var x0 := -11.0
	var x1 := 15.0
	var z0 := -49.5
	var z1 := -27.0
	_slab(x0, z0, x1, z1, 0.03, m_court)
	# разметка: рамка, центральная линия, круг
	for ln in [[Vector3((x0 + x1) * 0.5, 0.035, z0 + 0.6), Vector3(x1 - x0 - 1.2, 0.01, 0.12)], [Vector3((x0 + x1) * 0.5, 0.035, z1 - 0.6), Vector3(x1 - x0 - 1.2, 0.01, 0.12)],
			[Vector3(x0 + 0.6, 0.035, (z0 + z1) * 0.5), Vector3(0.12, 0.01, z1 - z0 - 1.2)], [Vector3(x1 - 0.6, 0.035, (z0 + z1) * 0.5), Vector3(0.12, 0.01, z1 - z0 - 1.2)],
			[Vector3((x0 + x1) * 0.5, 0.035, (z0 + z1) * 0.5), Vector3(x1 - x0 - 1.2, 0.01, 0.12)]]:
		_box(ln[0], ln[1], m_line)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.9
	tm.outer_radius = 3.02
	tm.rings = 48
	ring.mesh = tm
	ring.material_override = _flat(Color(0.16, 0.3, 0.7), 0.4)
	ring.scale = Vector3(1, 0.02, 1)
	ring.position = Vector3((x0 + x1) * 0.5, 0.04, (z0 + z1) * 0.5)
	add_child(ring)
	# борта: настоящие борта коробки с сеткой (или секции забора, пока модели нет); калитка — с юга, где ковёр
	var own_board := G67Models.has("g67_court_board")
	var nx := 6
	var gate_x := 2.0
	for i in nx:
		var seg := (x1 - x0) / float(nx)
		var xx := x0 + (float(i) + 0.5) * seg
		if own_board:
			_own("g67_court_board", Vector3(xx, 0, z0), PI * 0.5, seg, "d", false)
			if absf(xx - gate_x) > 2.3:
				_own("g67_court_board", Vector3(xx, 0, z1), -PI * 0.5, seg, "d", false)
		else:
			_put("fence_section", Vector3(xx, 0, z0), PI * 0.5, 1.9, false, seg / 1.15)
			if absf(xx - gate_x) > 3.0:
				_put("fence_section", Vector3(xx, 0, z1), PI * 0.5, 1.9, false, seg / 1.15)
	var nz := 5
	for i in nz:
		var segz := (z1 - z0) / float(nz)
		var zz := z0 + (float(i) + 0.5) * segz
		if own_board:
			_own("g67_court_board", Vector3(x0, 0, zz), 0.0, segz, "d", false)
			_own("g67_court_board", Vector3(x1, 0, zz), PI, segz, "d", false)
		else:
			_put("fence_section", Vector3(x0, 0, zz), 0.0, 1.9, false, segz / 1.15)
			_put("fence_section", Vector3(x1, 0, zz), 0.0, 1.9, false, segz / 1.15)
	_own("g67_court_gate", Vector3(gate_x, 0, z1), 0.0, 4.4, "w", false)
	_pillar(Vector3(gate_x - 2.05, 0, z1), 0.2, 4.0)
	_pillar(Vector3(gate_x + 2.05, 0, z1), 0.2, 4.0)
	_solid_box(Vector3((x0 + x1) * 0.5, 1.0, z0), Vector3(x1 - x0, 2.0, 0.3))
	_solid_box(Vector3(x0, 1.0, (z0 + z1) * 0.5), Vector3(0.3, 2.0, z1 - z0))
	_solid_box(Vector3(x1, 1.0, (z0 + z1) * 0.5), Vector3(0.3, 2.0, z1 - z0))
	_solid_box(Vector3((x0 + gate_x - 1.1) * 0.5, 1.0, z1), Vector3(gate_x - 1.1 - x0, 2.0, 0.3))
	_solid_box(Vector3((gate_x + 1.1 + x1) * 0.5, 1.0, z1), Vector3(x1 - gate_x - 1.1, 2.0, 0.3))
	# ковровая дорожка авторитета: от ворот к его месту
	_slab(1.1, -47.0, 2.9, -26.0, 0.045, m_carpet)
	# «трон» авторитета: кожаное кресло на поддонах в конце ковра, рядом — его машина, по бокам стенды турнира
	if _own("g67_misha_throne", Vector3(2.0, 0.03, -48.0), 0.0, 1.75) == null:
		_put("tire_stack", Vector3(-0.4, 0.03, -47.6), 0.0, 1.0)
	misha_car = _own("g67_misha_car", Vector3(8.6, 0.03, -45.6), -0.7, 4.4, "d")
	if misha_car == null:
		misha_car = _put("old_car", Vector3(8.2, 0.03, -46.4), PI * 0.5 + 0.25, 1.7)
		_tint(misha_car, Color(0.25, 0.22, 0.28))
	_put("res://assets/golda67/g67_poster_stand.glb", Vector3(-2.4, 0.03, -48.4), 0.0, 2.4)
	_put("res://assets/golda67/g67_poster_stand.glb", Vector3(5.2, 0.03, -48.7), 0.0, 2.2)
	_put("barrel", Vector3(3.7, 0.03, -47.9), 0.0, 0.9)
	if _decal("graffiti_misha_banner", "МИША МИНАСЯН", Vector3(2.0, 3.25, -49.25), 0.0, 5.2, Color(0.95, 0.72, 0.2), 0.016, 64) is Label3D:
		_sign("ГЛАВНЫЙ АВТОРИТЕТ ДВОРА", Vector3(2.0, 2.85, -49.25), 0.0, Color(0.9, 0.85, 0.75), 0.008, 56)
	_light(Vector3(2.0, 3.0, -46.6), Color(1.0, 0.75, 0.3), 3.0, 9.0)
	# турник и брусья у западного борта — укрытие и его «качалка»
	for bp in BARS:
		_put("res://assets/golda67/g67_workout_bars.glb", Vector3(bp[0], 0.03, bp[1]), bp[2], bp[3])
	_put("tire_stack", Vector3(-8.6, 0.03, -31.5), 0.6, 1.0)
	_arena_decor(x0, x1, z0, z1)
	_surface_detail()
	_flocks()
	_life_props()
	_life_signs()
	_door_lamps()
	_facade_life()
	# мачты с прожекторами по углам — свет на лёд, длинные тени
	for c in [Vector3(x0 - 0.9, 0, z0 - 0.9), Vector3(x1 + 0.9, 0, z0 - 0.9), Vector3(x0 - 0.9, 0, z1 + 0.9), Vector3(x1 + 0.9, 0, z1 + 0.9)]:
		if _own("g67_floodlight_mast", c, atan2(2.0 - c.x, -38.0 - c.z), 8.6, "h", false) == null:
			_put("street_lamp", c, 0.0, 7.5, false)
		_solid_box(c + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))
		var fl := _light(c + Vector3(0, 8.0, 0) + (Vector3(2.0, 0, -38.0) - c).normalized() * 0.8, Color(1.0, 0.92, 0.75), 0.25, 17.0)
		flood.append(fl)
	for cl in [[Vector3(x0 + 3.0, 7.0, z0 + 3.0), Color(1.0, 0.93, 0.8), 4.2, 24.0, true], [Vector3(x1 - 3.0, 7.0, z1 - 3.0), Color(1.0, 0.9, 0.75), 3.6, 24.0, false],
			[Vector3(x1 - 3.0, 7.0, z0 + 3.0), Color(0.95, 0.9, 1.0), 2.4, 20.0, false]]:
		var lt := _light(cl[0], cl[1], float(cl[2]) * 0.3, cl[3], cl[4])
		court_lights.append([lt, float(cl[2])])
	# зрители: районная трибуна у восточного борта (модель смотрит рядами по +X — развёрнута к площадке) и люди на ней;
	# пока модели нет — лавки вдоль борта
	# зрители: районная трибуна у восточного борта (ряды модели смотрят по +X — развёрнута к площадке).
	# Семеро сидят, у каждого своё поведение (FANS); восьмой стоит у западного борта. Реакции — crowd_react.
	tribune = _own("g67_tribune", TRIBUNE, PI, TRIBUNE_LEN, "d")
	var ts: Vector3 = tribune.get_meta("size", Vector3(2.9, 3.2, TRIBUNE_LEN)) if tribune != null else Vector3.ZERO
	if tribune == null:
		for i in 3:
			_put("bench", Vector3(17.0, 0, -44.0 + i * 5.5), PI, 0.95)
	var fan_tones := [Color(1, 1, 1), Color(0.8, 0.88, 1.0), Color(1.0, 0.84, 0.76), Color(0.84, 1.0, 0.86), Color(0.95, 0.84, 1.0), Color(0.76, 0.78, 0.86)]
	for i in FANS.size():
		var f: Dictionary = FANS[i]
		var who: Dictionary = QUEUE_PEOPLE[i % QUEUE_PEOPLE.size()]
		if not ResourceLoader.exists(String(who["path"])):
			continue
		var h: float = float(who["h"]) * (0.94 if i % 3 == 1 else 1.0)
		var sp: Vector3
		if f.has("row"):
			if tribune == null:
				continue
			var row := int(f["row"])
			# сидит: таз на сиденье ряда
			sp = TRIBUNE + Vector3(ts.x * float(TRIBUNE_ROWS[row][0]), ts.y * float(TRIBUNE_ROWS[row][1]) - G67Poses.SIT_HIP * h, float(f["z"]))
		else:
			sp = f["pos"]
		var fan := _person(String(who["path"]), String(who["key"]), h, sp, atan2(ARENA_C.x - sp.x, ARENA_C.z - sp.z), f, 8000 + i * 17)
		_tint(fan, fan_tones[(i * 5 + 2) % fan_tones.size()])
		fan.name = "fan%d" % i
		fan.set_meta("seated", f.has("row"))
		fan.set_meta("excited", float(f.get("excited", 0.3)))
		fans.append(fan)
	_drift(Vector3(-13.0, 0.3, -44.0), Vector3(2.0, 1.1, 7.0))
	_drift(Vector3(8.0, 0.3, -51.2), Vector3(9.0, 1.2, 2.2))
