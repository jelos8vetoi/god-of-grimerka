## Мир района приквела «ГОЛДА 67»: общий интерфейс двора (G67Yard) и подземки (G67Podzemka).
## Root и world обращаются к текущему району через статический реестр (use / zone_of / pt / event_spots),
## а к самому узлу мира — через world.district. Методы-заглушки ниже пустые: район переопределяет нужные.
class_name G67District
extends Node3D

## Активный район: "yard" | "podzemka" (ставит G67World при постройке мира)
static var cur := "yard"

static func use(id: String) -> void:
	cur = id

static func is_podzemka() -> bool:
	return cur == "podzemka"

## Зоны боя: {id: {c, h, name, spawns?, stand?, stand_yaw?}}
static func zones() -> Dictionary:
	return G67Podzemka.ZONES if cur == "podzemka" else G67Yard.ZONES

static func zone_of(id: String) -> Dictionary:
	var zs: Dictionary = zones()
	if zs.has(id):
		return zs[id]
	return zs[("gate1" if cur == "podzemka" else "podezd")]

static func has_zone(id: String) -> bool:
	return zones().has(id)

static func entry_pts(id: String) -> Array:
	var z: Dictionary = zone_of(id)
	var c: Vector3 = z["c"]
	var h: Vector2 = z["h"] - Vector2(1.4, 1.4)
	return [Vector3(c.x - h.x, 0.05, c.z + h.y * 0.35), Vector3(c.x + h.x, 0.05, c.z - h.y * 0.35),
		Vector3(c.x - h.x * 0.35, 0.05, c.z - h.y), Vector3(c.x + h.x * 0.35, 0.05, c.z + h.y)]

static func surface(pos: Vector3) -> String:
	if cur == "podzemka":
		return G67Podzemka.surface_at(pos)
	return G67Yard.surface_at(pos)

## Именованные точки района: home, storage, kiosk, rest, gate_boss, boss_entry, boss_spot, fit, fit_yaw
static func pt(name: String) -> Vector3:
	if cur == "podzemka":
		return G67Podzemka.POINTS.get(name, Vector3.ZERO)
	match name:
		"home": return G67Yard.HOME_DOOR
		"storage": return G67Yard.STORAGE_POS
		"kiosk": return G67Yard.KIOSK_POS
		"rest": return G67Yard.REST_POS
		"gate_boss": return G67Yard.GATE_BOSS
		"boss_entry": return G67Yard.BOSS_ENTRY
		"fit": return G67Yard.HANGER_POS
		"boss_spot": return Vector3(2, 0, -44.5)
	return Vector3.ZERO

static func fit_yaw() -> float:
	return G67Podzemka.FIT_YAW if cur == "podzemka" else G67Yard.HANGER_YAW

static func event_spots() -> Dictionary:
	return {} if cur == "podzemka" else G67Yard.EVENT_SPOTS

## ---- поля и методы, которые дёргает root; у района без этих понятий остаются пустыми
var solids: Array = []
var missing: Array = []
var hero: Node3D = null
var boss_spot := Vector3.ZERO
var lifes: Array = []

func court_k(_k: float) -> void:
	pass

func flood_on(_i: int, _on := true) -> void:
	pass

func flood_all(_e: float, _col := Color(1.0, 0.92, 0.75)) -> void:
	pass

func siren_look(_pos: Vector3) -> void:
	pass

func crowd_react(_kind: String) -> int:
	return 0
