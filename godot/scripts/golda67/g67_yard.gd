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

func _solid_box(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
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
	_light(pos + Vector3(0, 4.6, 0), Color(1.0, 0.72, 0.42), energy, 15.0, shadow)

## сугроб: несколько слипшихся наметённых бугров разного размера (у бордюров, под деревьями, куда счищают дворники)
func _drift(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	if G67Models.has("g67_snowdrift"):
		# модель владельца: длинная ось — Z; кладём вдоль большей стороны, небольшие — покороче
		var along_x := size.x > size.z
		var length := maxf(size.x, size.z)
		var n := G67Models.spawn("g67_snowdrift", self, Vector3(pos.x, -0.08, pos.z), yaw + (PI * 0.5 if along_x else 0.0) + (PI if int(absf(pos.x + pos.z)) % 2 == 0 else 0.0), Vector3(99, 99, length), "d")
		var wide := minf(size.x, size.z) / maxf(0.01, (n.get_meta("size", Vector3.ONE) as Vector3).x)
		n.scale = Vector3(clampf(wide, 0.8, 2.2), clampf(size.y * 0.9, 0.7, 1.3), 1.0)
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
	if _own("g67_laundry_lines", Vector3(10.5, 0, 21.0), 0.25, 3.6, "w", false) != null:
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
		_solid_box((who["pos"] as Vector3) + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
		people[id] = r

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
