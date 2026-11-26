## Район 2 «ПОДЗЕМКА»: каркас (этап 1). Помещения собираются из таблицы ROOMS (прямоугольники) и проёмов DOORS —
## тот же план на этапе 2 соберётся модулями 4 × 4 м. Координаты — PODZEMKA_DESIGN.md, раздел 1; пол всех
## помещений y = 0 (спуск — от y = 5 наверху до 0 внизу; в проекте пол «−5» — сдвиг на 5 м, игре всё равно).
class_name G67Podzemka
extends G67District

const T_WALL := 0.4

## id: [x0, x1, z0, z1, y_пола, y_потолка, поверхность, цвет света, имя]
## Размеры после правки владельца (выше и шире); ROOMS_BASE — прежняя раскладка, от неё пересчитываются привязанные координаты (fit)
const ROOMS := {
	"stairs_top": [-6.0, 6.0, 0.0, 6.0, 5.0, 9.2, "concrete", Color(0.9, 1.0, 0.9), "верх спуска"],
	"link": [6.0, 16.0, 2.0, 4.6, 5.0, 7.7, "concrete", Color(0.8, 0.9, 1.0), "проход к арке дома № 81"],      # стык с двором: сюда герой выходит из-за поворота
	"stairs_shaft": [-3.0, 3.0, -16.0, 0.0, 0.0, 9.2, "concrete", Color(0.7, 1.0, 0.75), "спуск"],
	"stairs": [-6.0, 6.0, -26.0, -16.0, 0.0, 4.4, "tile", Color(0.7, 1.0, 0.75), "спуск"],
	"gate1": [-10.5, 10.5, -44.0, -26.0, 0.0, 4.8, "tile", Color(0.9, 1.0, 0.95), "первый турникет"],
	"gal_a": [-6.25, 6.25, -70.0, -44.0, 0.0, 4.4, "tile", Color(0.95, 1.0, 0.9), "торговая галерея"],
	"gallery": [-11.5, 11.5, -88.0, -70.0, 0.0, 5.6, "tile", Color(1.0, 0.95, 0.8), "площадь галереи"],
	"gal_b": [-6.25, 6.25, -110.0, -88.0, 0.0, 4.4, "tile", Color(0.95, 1.0, 0.9), "торговая галерея"],
	"alley": [-14.0, -11.0, -106.0, -46.0, 0.0, 3.2, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"alley_n": [-11.0, -6.25, -50.0, -46.0, 0.0, 3.2, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"alley_s": [-11.0, -6.25, -106.0, -102.0, 0.0, 3.2, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"cross": [-14.0, 14.0, -134.0, -110.0, 0.0, 5.6, "tile", Color(0.9, 1.0, 0.95), "перекрёсток"],
	"arc_link": [-16.0, -14.0, -126.0, -118.0, 0.0, 4.8, "tile", Color(0.9, 1.0, 0.95), "переход"],
	"arcade": [-44.0, -16.0, -132.0, -109.0, 0.0, 4.8, "tile", Color(0.8, 1.0, 0.85), "зал автоматов"],
	"arc_dead": [-44.0, -38.0, -138.0, -132.0, 0.0, 4.8, "tile", Color(0.8, 1.0, 0.85), "тупик"],
	"casino": [-54.0, -44.0, -126.0, -118.0, 0.0, 3.8, "tile", Color(1.0, 0.5, 0.8), "DOG CASINO 67"],
	"tun_e": [14.0, 36.0, -125.2, -120.0, 0.0, 3.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"tunnel": [36.0, 44.0, -150.0, -120.0, 0.0, 3.8, "puddle", Color(0.75, 0.85, 1.0), "тоннель (расширение)"],
	"tun_n": [38.8, 44.0, -166.0, -150.0, 0.0, 3.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"tun_w": [14.0, 44.0, -171.2, -166.0, 0.0, 3.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"hamster": [44.0, 59.0, -153.0, -139.0, 0.0, 5.0, "earth", Color(1.0, 0.7, 0.35), "КРОТЫ ХОМЯКИ"],
	"tech": [30.8, 38.8, -164.0, -156.0, 0.0, 3.4, "concrete", Color(0.8, 0.9, 1.0), "техпомещение"],
	"staff": [-28.5, -16.5, -150.0, -140.0, 0.0, 3.4, "tile", Color(1.0, 0.85, 0.6), "комната персонала"],
	"cash": [-16.5, 16.5, -166.0, -134.0, 0.0, 6.5, "tile", Color(1.0, 1.0, 0.8), "кассовый комплекс"],
	"pocket": [6.0, 14.0, -170.0, -166.0, 0.0, 3.8, "concrete", Color(1.0, 0.9, 0.5), "закуток за будками"],
	"arena_link": [-4.0, 4.0, -170.0, -166.0, 0.0, 6.5, "tile", Color(1.0, 1.0, 0.8), "ворота арены"],
	"arena": [-12.0, 12.0, -188.0, -170.0, 0.0, 7.5, "tile", Color(1.0, 0.95, 0.75), "арена"],
}

const ROOMS_BASE := {
	"stairs_top": [-6.0, 6.0, 0.0, 6.0, 5.0, 8.2, "concrete", Color(0.9, 1.0, 0.9), "верх спуска"],
	"stairs_shaft": [-3.0, 3.0, -16.0, 0.0, 0.0, 8.2, "concrete", Color(0.7, 1.0, 0.75), "спуск"],
	"stairs": [-6.0, 6.0, -26.0, -16.0, 0.0, 3.2, "tile", Color(0.7, 1.0, 0.75), "спуск"],
	"gate1": [-9.0, 9.0, -44.0, -26.0, 0.0, 3.6, "tile", Color(0.9, 1.0, 0.95), "первый турникет"],
	"gal_a": [-5.0, 5.0, -70.0, -44.0, 0.0, 3.2, "tile", Color(0.95, 1.0, 0.9), "торговая галерея"],
	"gallery": [-10.0, 10.0, -88.0, -70.0, 0.0, 4.5, "tile", Color(1.0, 0.95, 0.8), "площадь галереи"],
	"gal_b": [-5.0, 5.0, -110.0, -88.0, 0.0, 3.2, "tile", Color(0.95, 1.0, 0.9), "торговая галерея"],
	"alley": [-13.0, -11.0, -106.0, -46.0, 0.0, 2.6, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"alley_n": [-11.0, -5.0, -50.0, -46.0, 0.0, 2.6, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"alley_s": [-11.0, -5.0, -106.0, -102.0, 0.0, 2.6, "concrete", Color(1.0, 0.85, 0.6), "служебный проход"],
	"cross": [-12.0, 12.0, -134.0, -110.0, 0.0, 4.5, "tile", Color(0.9, 1.0, 0.95), "перекрёсток"],
	"arc_link": [-16.0, -12.0, -126.0, -118.0, 0.0, 3.6, "tile", Color(0.9, 1.0, 0.95), "переход"],
	"arcade": [-44.0, -16.0, -132.0, -112.0, 0.0, 3.6, "tile", Color(0.8, 1.0, 0.85), "зал автоматов"],
	"arc_dead": [-44.0, -38.0, -138.0, -132.0, 0.0, 3.6, "tile", Color(0.8, 1.0, 0.85), "тупик"],
	"casino": [-54.0, -44.0, -126.0, -118.0, 0.0, 3.0, "tile", Color(1.0, 0.5, 0.8), "DOG CASINO 67"],
	"tun_e": [12.0, 36.0, -124.0, -120.0, 0.0, 2.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"tunnel": [36.0, 44.0, -150.0, -120.0, 0.0, 2.8, "puddle", Color(0.75, 0.85, 1.0), "тоннель (расширение)"],
	"tun_n": [40.0, 44.0, -166.0, -150.0, 0.0, 2.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"tun_w": [14.0, 44.0, -170.0, -166.0, 0.0, 2.8, "puddle", Color(0.75, 0.85, 1.0), "служебный тоннель"],
	"hamster": [44.0, 59.0, -153.0, -139.0, 0.0, 4.0, "earth", Color(1.0, 0.7, 0.35), "КРОТЫ ХОМЯКИ"],
	"tech": [32.0, 40.0, -164.0, -156.0, 0.0, 2.6, "concrete", Color(0.8, 0.9, 1.0), "техпомещение"],
	"staff": [-26.0, -14.0, -150.0, -140.0, 0.0, 2.8, "tile", Color(1.0, 0.85, 0.6), "комната персонала"],
	"cash": [-14.0, 14.0, -166.0, -134.0, 0.0, 5.0, "tile", Color(1.0, 1.0, 0.8), "кассовый комплекс"],
	"pocket": [6.0, 14.0, -170.0, -166.0, 0.0, 3.0, "concrete", Color(1.0, 0.9, 0.5), "закуток за будками"],
	"arena_link": [-4.0, 4.0, -170.0, -166.0, 0.0, 5.0, "tile", Color(1.0, 1.0, 0.8), "ворота арены"],
	"arena": [-12.0, 12.0, -188.0, -170.0, 0.0, 6.0, "tile", Color(1.0, 0.95, 0.75), "арена"],
}

## проёмы: ось стены ("x" — стена x = коорд, проём по z; "z" — стена z = коорд, проём по x), коорд, от, до
const DOORS := [
	["x", 6.0, 2.0, 4.6], ["z", 0.0, -3.0, 3.0], ["z", -16.0, -3.0, 3.0], ["z", -26.0, -4.0, 4.0],
	["z", -44.0, -3.75, 3.75], ["z", -70.0, -3.75, 3.75], ["z", -88.0, -3.75, 3.75], ["z", -110.0, -3.75, 3.75],
	["x", -6.25, -50.0, -46.0], ["x", -6.25, -106.0, -102.0], ["x", -11.0, -50.0, -46.0], ["x", -11.0, -106.0, -102.0],
	["x", -14.0, -126.0, -118.0], ["x", -16.0, -126.0, -118.0], ["z", -132.0, -43.0, -39.0],
	["x", -44.0, -124.0, -120.0],
	["x", 14.0, -125.2, -120.0], ["x", 36.0, -125.2, -120.0], ["z", -150.0, 38.8, 44.0],
	["x", 44.0, -148.0, -144.0], ["x", 38.8, -162.0, -158.0],
	["z", -166.0, 38.8, 44.0], ["x", 14.0, -170.0, -166.5], ["z", -166.0, 8.0, 12.0],
	["z", -134.0, -3.75, 3.75], ["x", -16.5, -147.0, -143.0],
	["z", -166.0, -3.0, 3.0], ["z", -170.0, -3.0, 3.0],
]

## зоны боя (ключи совпадают с G67Data.pz_option); spawns — [[точка]]
const ZONES_BASE := {
	"stairs": {"c": Vector3(0, 0, -21), "h": Vector2(6, 5), "name": "спуск"},
	"gate1": {"c": Vector3(0, 0, -35), "h": Vector2(9, 9), "name": "первый турникет", "spawns": [[Vector3(-7.5, 0.05, -42)], [Vector3(7.5, 0.05, -42)], [Vector3(-7.5, 0.05, -28)], [Vector3(7.5, 0.05, -28)]]},
	"gallery": {"c": Vector3(0, 0, -79), "h": Vector2(10, 9), "name": "торговая галерея", "spawns": [[Vector3(-8.0, 0.05, -84)], [Vector3(6.0, 0.05, -84)], [Vector3(-8.0, 0.05, -74)], [Vector3(6.0, 0.05, -75)]]},
	"cross": {"c": Vector3(0, 0, -122), "h": Vector2(12, 12), "name": "перекрёсток", "spawns": [[Vector3(-10, 0.05, -131)], [Vector3(10, 0.05, -131)], [Vector3(-10, 0.05, -113)], [Vector3(10, 0.05, -113)]]},
	"arcade": {"c": Vector3(-30, 0, -122), "h": Vector2(14, 10), "name": "зал автоматов", "spawns": [[Vector3(-42, 0.05, -130)], [Vector3(-42, 0.05, -114)], [Vector3(-18, 0.05, -130)], [Vector3(-18, 0.05, -114)]]},
	"tunnel": {"c": Vector3(40, 0, -135), "h": Vector2(4, 15), "name": "служебный тоннель", "spawns": [[Vector3(38, 0.05, -148)], [Vector3(42, 0.05, -148)], [Vector3(38, 0.05, -123)], [Vector3(42, 0.05, -123)]]},
	"staff": {"c": Vector3(-20, 0, -145), "h": Vector2(6, 5), "name": "комната персонала"},
	"arena": {"c": Vector3(0, 0, -179), "h": Vector2(12, 9), "name": "арена", "spawns": [[Vector3(-10, 0.05, -186)], [Vector3(10, 0.05, -186)], [Vector3(-10, 0.05, -172)], [Vector3(10, 0.05, -172)]]},
}

## именованные точки (G67District.pt)
const POINTS_BASE := {
	"home": Vector3(0, 5, 3), "storage": Vector3(-9.0, 0, -128.0), "kiosk": Vector3(-20.0, 0, -116.0), "rest": Vector3(-20.0, 0, -145.0),
	"gate_boss": Vector3(0, 0, -160.0), "boss_entry": Vector3(0, 0.05, -173.5), "boss_spot": Vector3(0, 0, -185.0), "fit": Vector3(-3.5, 0, -79.0),
}
## Привязка прежних координат к новой раскладке комнат: точка внутри комнаты ROOMS_BASE переносится в ту же относительную точку ROOMS
static func fit(v: Vector3) -> Vector3:
	for id in ROOMS_BASE:
		var o: Array = ROOMS_BASE[id]
		if v.x >= float(o[0]) and v.x <= float(o[1]) and v.z >= float(o[2]) and v.z <= float(o[3]):
			var n: Array = ROOMS[id]
			var kx := (float(n[1]) - float(n[0])) / (float(o[1]) - float(o[0]))
			var kz := (float(n[3]) - float(n[2])) / (float(o[3]) - float(o[2]))
			return Vector3(float(n[0]) + (v.x - float(o[0])) * kx, v.y, float(n[2]) + (v.z - float(o[2])) * kz)
	return v

static func _room_k(v: Vector3) -> Vector2:
	for id in ROOMS_BASE:
		var o: Array = ROOMS_BASE[id]
		if v.x >= float(o[0]) and v.x <= float(o[1]) and v.z >= float(o[2]) and v.z <= float(o[3]):
			var n: Array = ROOMS[id]
			return Vector2((float(n[1]) - float(n[0])) / (float(o[1]) - float(o[0])), (float(n[3]) - float(n[2])) / (float(o[3]) - float(o[2])))
	return Vector2.ONE

static func _fit_zones() -> Dictionary:
	var r := {}
	for id in ZONES_BASE:
		var z: Dictionary = (ZONES_BASE[id] as Dictionary).duplicate(true)
		var k := _room_k(z["c"])
		z["h"] = Vector2((z["h"] as Vector2).x * k.x, (z["h"] as Vector2).y * k.y)
		z["c"] = fit(z["c"])
		if z.has("spawns"):
			for sp in z["spawns"]:
				sp[0] = fit(sp[0])
		r[id] = z
	return r

static func _fit_points() -> Dictionary:
	var r := {}
	for id in POINTS_BASE:
		r[id] = fit(POINTS_BASE[id])
	return r

static var ZONES: Dictionary = _fit_zones()
static var POINTS: Dictionary = _fit_points()
const FIT_YAW := 1.5708
const STAIRS_TOP := Vector3(0, 5.05, 3.0)
const KEY_LAMPS := ["cross", "gallery", "cash", "arena"]

static func surface_at(pos: Vector3) -> String:
	for id in ROOMS:
		var r: Array = ROOMS[id]
		if pos.x >= float(r[0]) and pos.x <= float(r[1]) and pos.z >= float(r[2]) and pos.z <= float(r[3]) and pos.y >= float(r[4]) - 1.0 and pos.y <= float(r[5]):
			return String(r[6])
	return "tile"

static func room_at(pos: Vector3) -> String:
	for id in ROOMS:
		var r: Array = ROOMS[id]
		if pos.x >= float(r[0]) and pos.x <= float(r[1]) and pos.z >= float(r[2]) and pos.z <= float(r[3]) and pos.y >= float(r[4]) - 1.0 and pos.y <= float(r[5]):
			return String(id)
	return ""

var mat_tile: StandardMaterial3D
var mat_stripe: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_ceil: StandardMaterial3D
var mat_conc: StandardMaterial3D
var mat_earth: StandardMaterial3D
var wall_count := 0
var lamp_pts: Array = []
var lamp_dead: Array = []
var use_modules := false
var mods := {}              # id модуля → [mesh, смещение узла в сцене]
var mod_xf := {}            # id модуля → [Transform3D] для MultiMesh
var sign_nodes: Array = []
var flicker: Array = []
var prop_count := 0
var slot_screen: G67SlotScreen = null
var slot_vp: SubViewport = null
var slot_button: MeshInstance3D = null
var music_casino: Marker3D = null
var music_hamster: Marker3D = null
var door_nodes := {}
var door_open_flags := {}
var dog_node: Node3D = null
var hamsters: Array = []          # [узел, высота, поворот, фаза]: хомяки принюхиваются, вертятся и подпрыгивают
var spit_node: Node3D = null
var dog_yaw := 0.0
var dog_base := Vector3.ZERO
var dog_bark_t := -1.0
var dog_joy_t := -1.0
var dog_next_bark := 4.0
var slot_lamps: Array = []
var lamp_rate := 3.0          # частота мигания ламп корпуса слота; растёт с 50-го спина
const SLOT_POS := Vector3(-52.9, 0.0, -122.0)
const SLOT_YAW := PI * 0.5
var room_of_prop := {}
const MOD := "res://assets/golda67/podzemka/g67_pz_"
const PROP_PATH := "res://assets/golda67/podzemka/g67_pz_"

func _init() -> void:
	boss_spot = POINTS["boss_spot"]

func build() -> void:
	use_modules = ResourceLoader.exists(MOD + "wall_a.glb")
	mat_tile = _m(Color(0.78, 0.8, 0.75), 0.55)
	mat_stripe = _m(Color(0.12, 0.45, 0.22), 0.5)
	mat_floor = _m(Color(0.34, 0.35, 0.36), 0.8)
	mat_ceil = _m(Color(0.5, 0.52, 0.5), 0.9)
	mat_conc = _m(Color(0.45, 0.45, 0.46), 0.9)
	mat_earth = _m(Color(0.32, 0.22, 0.14), 1.0)
	for id in ROOMS:
		_room(String(id), ROOMS[id])
	_ramp()
	_gate_grille()
	if use_modules:
		_modules()
		_decorate()
		_slot_screen()
		_doors()
	_zone_lights()

func _m(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _box(pos: Vector3, size: Vector3, mat: Material, solid := true) -> void:
	if use_modules:
		if not solid:
			return
		_collider(pos, size)
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		sb.collision_layer = cam_layer(size)      # 8 — слой камеры (SpringArm3D в game.gd): без него камера проходила сквозь стены и потолки
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = pos
		add_child(sb)

## вырезать проёмы из отрезка стены [lo, hi] на линии (ось, коорд)
func _cuts(axis: String, coord: float, lo: float, hi: float) -> Array:
	var segs: Array = [[lo, hi]]
	for d in DOORS:
		if String(d[0]) != axis or absf(float(d[1]) - coord) > 0.01:
			continue
		var a := float(d[2])
		var b := float(d[3])
		var next: Array = []
		for s in segs:
			if b <= float(s[0]) or a >= float(s[1]):
				next.append(s)
				continue
			if a > float(s[0]):
				next.append([float(s[0]), a])
			if b < float(s[1]):
				next.append([b, float(s[1])])
		segs = next
	return segs

func _wall(axis: String, coord: float, a: float, b: float, y0: float, y1: float, mat: Material, mid_inside: float) -> void:
	var h := y1 - y0
	for s in _cuts(axis, coord, a, b):
		var lo := float(s[0])
		var hi := float(s[1])
		if hi - lo < 0.05:
			continue
		var len := hi - lo
		var c := (lo + hi) * 0.5
		var size := Vector3(T_WALL, h, len) if axis == "x" else Vector3(len, h, T_WALL)
		var off := T_WALL * 0.5 * mid_inside
		var pos := Vector3(coord + off, y0 + h * 0.5, c) if axis == "x" else Vector3(c, y0 + h * 0.5, coord + off)
		_box(pos, size, mat)
		wall_count += 1
		var ssize := Vector3(0.05, 1.1, len) if axis == "x" else Vector3(len, 1.1, 0.05)
		var spos := Vector3(coord + off * 2.0 + mid_inside * 0.03, y0 + 0.55, c) if axis == "x" else Vector3(c, y0 + 0.55, coord + off * 2.0 + mid_inside * 0.03)
		_box(spos, ssize, mat_stripe, false)

func _room(id: String, r: Array) -> void:
	var x0 := float(r[0])
	var x1 := float(r[1])
	var z0 := float(r[2])
	var z1 := float(r[3])
	var y0 := float(r[4])
	var y1 := float(r[5])
	var surf := String(r[6])
	var wm: Material = mat_conc if surf in ["concrete", "puddle"] else (mat_earth if surf == "earth" else mat_tile)
	if id != "stairs_shaft":
		_box(Vector3((x0 + x1) * 0.5, y0 - 0.25, (z0 + z1) * 0.5), Vector3(x1 - x0 + T_WALL, 0.5, z1 - z0 + T_WALL), mat_earth if surf == "earth" else mat_floor)
	_box(Vector3((x0 + x1) * 0.5, y1 + 0.25, (z0 + z1) * 0.5), Vector3(x1 - x0 + T_WALL, 0.5, z1 - z0 + T_WALL), mat_ceil)
	# стены ставятся внутрь помещения: центр на линии границы со сдвигом внутрь
	_wall("x", x0, z0, z1, y0, y1, wm, 1.0)
	_wall("x", x1, z0, z1, y0, y1, wm, -1.0)
	_wall("z", z0, x0, x1, y0, y1, wm, 1.0)
	_wall("z", z1, x0, x1, y0, y1, wm, -1.0)
	_lamps(id, x0, x1, z0, z1, y1, r[7] as Color)

## Слой преграды: стены (выше 2,2 м), пол и потолок (плиты до 0,6 м) держат камеру; турникеты, тумбы, ограждения — только героя
## (иначе пружина камеры упиралась в турникет за спиной и вставала вплотную к затылку — финал FORTUNA в проходе ботом)
static func cam_layer(size: Vector3) -> int:
	return 1 | 8 if (size.y >= 2.2 or size.y <= 0.6) else 1

func _collider(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = cam_layer(size)          # 8 — слой камеры: стены и потолки держат камеру внутри помещения
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	add_child(sb)

func _lamps(id: String, x0: float, x1: float, z0: float, z1: float, y1: float, col: Color) -> void:
	var nx := maxi(1, int(round((x1 - x0) / 10.0)))
	var nz := maxi(1, int(round((z1 - z0) / 10.0)))
	var dark_zone: bool = id in ["arcade", "arc_dead", "casino", "hamster"]
	var tun_zone: bool = id in ["tun_e", "tunnel", "tun_n", "tun_w", "pocket", "tech"]
	var hard_zone: bool = id in ["cash", "arena", "arena_link"]
	for i in nx:
		for j in nz:
			var hsh := _hash(float(i) * 3.1 + x0, float(j) * 5.7 + z0, 2.0)
			if (dark_zone and hsh < 0.7) or (tun_zone and hsh < 0.4) or (not hard_zone and not dark_zone and hsh < 0.18):
				if not (use_modules and i == 0 and j == 0):
					lamp_dead.append(Vector3(x0 + (float(i) + 0.5) * (x1 - x0) / float(nx), y1 - 0.4, z0 + (float(j) + 0.5) * (z1 - z0) / float(nz)))
					continue
			var l := OmniLight3D.new()
			var warm := _hash(x0 + float(i), z0 + float(j), 7.0)
			l.light_color = Color(1.0, 0.86, 0.6) if warm < 0.3 else (Color(0.8, 1.0, 0.85) if warm < 0.5 else (Color(1.0, 0.95, 0.5) if tun_zone else col))
			if hard_zone:
				l.light_color = Color(1.0, 0.98, 0.9) if warm > 0.3 else Color(1.0, 0.85, 0.35)
			l.light_energy = 0.12 if dark_zone else (0.45 if tun_zone else (1.0 if hard_zone else 0.85))
			l.omni_range = (7.0 if y1 < 5.5 else 9.0) if not hard_zone else 13.0
			if hsh > 0.82 and not hard_zone:
				flicker.append([l, l.light_energy, hsh * 9.0])
			l.position = Vector3(x0 + (float(i) + 0.5) * (x1 - x0) / float(nx), y1 - 0.4, z0 + (float(j) + 0.5) * (z1 - z0) / float(nz))
			l.shadow_enabled = KEY_LAMPS.has(id) and i == 0 and j == 0
			add_child(l)
			if use_modules:
				lamp_pts.append(l.position)
				continue
			var lm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.9, 0.06, 0.2)
			lm.mesh = bm
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = col
			lm.material_override = em
			lm.position = l.position + Vector3(0, 0.38, 0)
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lm)

## Лестница: наклонная плита от (z 0; y 5) до (z −16; y 0)
func _ramp() -> void:
	var top := Vector3(0, 5, 0)
	var bot := Vector3(0, 0, -16)
	var L := top.distance_to(bot)
	var mid := (top + bot) * 0.5
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 0.4, L)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.look_at_from_position(mid + Vector3(0, -0.2, 0), bot + Vector3(0, -0.2, 0), Vector3.UP)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = mat_conc
	sb.add_child(mi)

## Решётка над лестницей (закрыта до победы над Мишей; открывает root)
var grille: Node3D = null

func _gate_grille() -> void:
	grille = Node3D.new()
	add_child(grille)
	grille.position = Vector3(0, 5, 6.0)

# ---------------------------------------------------------------- модули Blender вместо кодовых коробок
func _mod(id: String) -> Array:
	if mods.has(id):
		return mods[id]
	var path := MOD + id + ".glb"
	var out: Array = []
	if ResourceLoader.exists(path):
		var inst: Node = (load(path) as PackedScene).instantiate()
		var best: MeshInstance3D = null
		var most := -1
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh != null and m.mesh.get_surface_count() > 0:
				var vn: int = m.mesh.surface_get_array_len(0)
				if vn > most:
					most = vn
					best = m
		if best != null:
			var xf := best.transform
			var par := best.get_parent()
			while par != null and par != inst and par is Node3D:
				xf = (par as Node3D).transform * xf
				par = par.get_parent()
			out = [best.mesh, xf]
		inst.free()
	else:
		missing.append(path)
	mods[id] = out
	return out

func _put_mod(id: String, xf: Transform3D) -> void:
	if not mod_xf.has(id):
		mod_xf[id] = []
	(mod_xf[id] as Array).append(xf)

func _hash(a: float, b: float, c := 0.0) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453, 1.0)

func _modules() -> void:
	for id in ROOMS:
		var r: Array = ROOMS[id]
		var x0 := float(r[0])
		var x1 := float(r[1])
		var z0 := float(r[2])
		var z1 := float(r[3])
		var y0 := float(r[4])
		var y1 := float(r[5])
		var surf := String(r[6])
		if id == "stairs_shaft":
			continue
		var tunnel_room: bool = id in ["tun_e", "tun_n", "tun_w"]
		var hs := (y1 - y0) / 3.2
		if tunnel_room:
			var along_x: bool = (x1 - x0) > (z1 - z0)
			var L := (x1 - x0) if along_x else (z1 - z0)
			var n := maxi(1, int(round(L / 4.0)))
			for i in n:
				var c := (x0 if along_x else z0) + (float(i) + 0.5) * L / float(n)
				var pos := Vector3(c, y0, (z0 + z1) * 0.5) if along_x else Vector3((x0 + x1) * 0.5, y0, c)
				_put_mod("tunnel", Transform3D(Basis(Vector3.UP, -PI * 0.5 if along_x else 0.0).scaled_local(Vector3(1, hs, L / float(n) / 4.0)), pos))
			continue
		# пол и потолок: сетка 4 × 4 (с подгонкой)
		var nx := maxi(1, int(ceil((x1 - x0) / 4.0)))
		var nz := maxi(1, int(ceil((z1 - z0) / 4.0)))
		for i in nx:
			for j in nz:
				var cx := x0 + (float(i) + 0.5) * (x1 - x0) / float(nx)
				var cz := z0 + (float(j) + 0.5) * (z1 - z0) / float(nz)
				var sx := (x1 - x0) / float(nx) / 4.0
				var sz := (z1 - z0) / float(nz) / 4.0
				var h := _hash(cx, cz)
				var fid := "floor_dry"
				if surf == "puddle" and h < 0.5 or id in ["gallery", "gal_a", "gal_b"] and h < 0.2:
					fid = "floor_wet"
				elif id in ["gate1", "cash", "arena", "arena_link"] and h < 0.5:
					fid = "floor_toll"
				elif h > 0.94:
					fid = "floor_hatch"
				_put_mod(fid, Transform3D(Basis().scaled(Vector3(sx, 1, sz)), Vector3(cx, y0, cz)))
				var cid := "ceil_beam" if h < 0.3 else ("ceil_vent" if h < 0.55 else ("ceil_pipes" if h < 0.8 else "ceil_beam"))
				for lp in lamp_pts:
					if absf((lp as Vector3).x - cx) < 2.0 and absf((lp as Vector3).z - cz) < 2.0 and absf((lp as Vector3).y - y1) < 1.0:
						cid = "ceil_lamp"
				_put_mod(cid, Transform3D(Basis().scaled(Vector3(sx, 1, sz)), Vector3(cx, y1, cz)))
		# стены: сегменты между проёмами, по модулю 4 м
		for side in 4:
			var axis := "x" if side < 2 else "z"
			var coord := x0 if side == 0 else (x1 if side == 1 else (z0 if side == 2 else z1))
			var mi_ := 1.0 if side in [0, 2] else -1.0
			var lo := z0 if axis == "x" else x0
			var hi := z1 if axis == "x" else x1
			for sg in _cuts(axis, coord, lo, hi):
				var a := float(sg[0])
				var b := float(sg[1])
				var L2 := b - a
				if L2 < 0.3:
					continue
				var n2 := maxi(1, int(round(L2 / 4.0)))
				for k in n2:
					var c2 := a + (float(k) + 0.5) * L2 / float(n2)
					var h2 := _hash(c2, coord, 1.0)
					var wid := "wall_conc"
					if surf == "tile":
						wid = "wall_a" if h2 < 0.55 else ("wall_b" if h2 < 0.7 else ("wall_c" if h2 < 0.85 else "wall_d"))
					var d := Vector3(mi_, 0, 0) if axis == "x" else Vector3(0, 0, mi_)
					var pos2 := Vector3(coord + 0.4 * mi_, y0, c2) if axis == "x" else Vector3(c2, y0, coord + 0.4 * mi_)
					if surf == "tile" and y1 - y0 > 3.4:
						_put_mod(wid, Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)).scaled_local(Vector3(L2 / float(n2) / 4.0, 1.0, 1)), pos2))
						_put_mod("wall_conc", Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)).scaled_local(Vector3(L2 / float(n2) / 4.0, (y1 - y0 - 3.2) / 3.2, 1)), pos2 + Vector3(0, 3.2, 0)))
					else:
						_put_mod(wid, Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)).scaled_local(Vector3(L2 / float(n2) / 4.0, hs, 1)), pos2))
	_put_mod("stairs", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0)))
	for id in mod_xf:
		var md: Array = _mod(String(id))
		if md.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = md[0]
		var xs: Array = mod_xf[id]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, (xs[i] as Transform3D) * (md[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "mod_" + String(id)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

# ---------------------------------------------------------------- предметы и надписи
## [модель, x, z, поворот (рад), y, масштаб, коллизия]
const PROPS := [
	["grille", 0.0, 5.6, PI, 5.0, 1.0, false],
	["arrow_sign", 4.0, -20.0, 0.0, 0.0, 1.0, true], ["cross_green", -5.4, -18.0, PI * 0.5, 1.2, 1.0, false],
	["booth", 7.3, -36.0, -PI * 0.5, 0.0, 1.0, true],
	["turnstile", -5.0, -36.0, 0.0, 0.0, 1.0, true], ["turnstile", -2.6, -36.0, 0.0, 0.0, 1.0, true], ["turnstile", 2.6, -36.0, 0.0, 0.0, 1.0, true], ["turnstile", 5.0, -36.0, 0.0, 0.0, 1.0, true],
	["tariff_board", -6.0, -43.4, 0.0, 1.5, 0.8, false], ["queue_stand", -7.0, -30.0, 0.0, 0.0, 1.0, true], ["queue_stand", -5.5, -30.0, 0.0, 0.0, 1.0, true],
	["kiosk_shawarma", -3.7, -54.0, PI * 0.5, 0.0, 1.0, true], ["shawarma_spit", -3.18, -54.6, PI * 0.5, 1.04, 1.0, false], ["kiosk_phones", -3.7, -60.0, PI * 0.5, 0.0, 1.0, true], ["kiosk_socks", -3.6, -66.0, PI * 0.5, 0.0, 1.0, true],
	["kiosk_keys", 3.55, -54.0, -PI * 0.5, 0.0, 1.0, true], ["kiosk_odds", 3.55, -60.0, -PI * 0.5, 0.0, 1.0, true], ["kiosk_exchange", 3.55, -66.0, -PI * 0.5, 0.0, 1.0, true],
	["kiosk_socks", -3.6, -93.0, PI * 0.5, 0.0, 1.0, true], ["kiosk_phones", -3.7, -99.0, PI * 0.5, 0.0, 1.0, true],
	["kiosk_shawarma", 3.7, -93.0, -PI * 0.5, 0.0, 1.0, true], ["kiosk_odds", 3.7, -99.0, -PI * 0.5, 0.0, 1.0, true],
	["bench", -8.0, -79.0, PI * 0.5, 0.0, 1.0, true], ["bench", 8.0, -79.0, -PI * 0.5, 0.0, 1.0, true], ["bin", -8.4, -73.0, 0.0, 0.0, 1.0, true], ["bin", 8.4, -85.0, 0.0, 0.0, 1.0, true],
	["cross_green", 9.6, -72.0, -PI * 0.5, 1.4, 1.0, false], ["vend_drinks", 9.2, -76.0, -PI * 0.5, 0.0, 1.0, true], ["gas_balloon", 3.9, -107.0, 0.0, 0.0, 1.0, true],
	["arrow_sign", 4.5, -114.0, PI, 0.0, 1.0, true], ["storage", -8.5, -133.6, 0.0, 0.0, 1.0, true],
	["column", -6.0, -118.0, 0.0, 0.0, 1.0, true], ["column", 6.0, -118.0, 0.0, 0.0, 1.0, true], ["column", -6.0, -128.0, 0.0, 0.0, 1.0, true], ["column", 6.0, -128.0, 0.0, 0.0, 1.0, true],
	["vend_snacks", -20.0, -130.6, 0.0, 0.0, 1.0, true], ["vend_change", -22.5, -130.6, 0.0, 0.0, 1.0, true], ["vend_drinks", -25.0, -130.6, 0.0, 0.0, 1.0, true], ["vend_broken", -17.5, -130.6, 0.0, 0.0, 1.0, true],
	["arcade_a", -28.0, -115.4, 0.0, 0.0, 1.0, true], ["arcade_b", -31.0, -115.4, 0.0, 0.0, 1.0, true], ["arcade_a", -34.0, -115.4, 0.0, 0.0, 1.0, true],
	["arcade_b", -20.0, -128.6, PI, 0.0, 1.0, true], ["arcade_a", -23.5, -128.6, PI, 0.0, 1.0, true], ["arcade_b", -27.0, -128.6, PI, 0.0, 1.0, true], ["arcade_a", -30.5, -128.6, PI, 0.0, 1.0, true], ["arcade_b", -34.0, -128.6, PI, 0.0, 1.0, true], ["arcade_a", -37.5, -128.6, PI, 0.0, 1.0, true],
	["shutter", -43.5, -129.0, PI * 0.5, 0.0, 1.0, false], ["microwave", -39.0, -113.2, 0.0, 0.8, 1.0, false], ["chess", -40.8, -113.2, 0.0, 0.8, 1.0, false],
	["slot_machine", -52.9, -122.0, PI * 0.5, 0.0, 1.0, true], ["kennel", -50.5, -124.6, 0.0, 0.0, 1.0, true], ["dog", -48.0, -121.0, PI * 0.5, 0.0, 1.0, true], ["collar67", -52.2, -124.8, 0.0, 0.0, 1.0, false],
	["door_tech", 43.4, -150.6, -PI * 0.5, 0.0, 1.0, false], ["door_tech", 39.6, -162.5, PI * 0.5, 0.0, 1.0, false],
	["hamster_wall", 51.5, -152.5, 0.0, 0.0, 1.0, true], ["hamster_props", 49.0, -141.5, 0.0, 0.0, 1.0, false],
	# хомяки перед стеной нор — на полу (на 0,9 и 2,1 м они висели в воздухе в двух метрах от стены: «кроты летают», 2026-11-25)
	["hamster_a", 47.5, -150.2, 0.0, 0.0, 1.0, false], ["hamster_b", 50.0, -150.2, 0.0, 0.0, 1.0, false], ["hamster_c", 53.0, -150.2, 0.0, 0.0, 1.0, false], ["hamster_gold", 55.5, -150.2, 0.0, 0.0, 1.0, false],
	["bottle_1", 9.4, -77.5, 0.0, 0.0, 1.0, false], ["bottle_2", 41.0, -157.5, 0.0, 0.0, 1.0, false], ["bottle_3", -12.0, -80.0, 0.0, 0.0, 1.0, false], ["bottle_4", -41.0, -136.0, 0.0, 0.0, 1.0, false], ["bottle_5", 10.0, -168.0, 0.0, 0.0, 1.0, false],
	["emergency_pack", -22.0, -148.0, 0.0, 0.0, 1.0, false],
	["cash_shield", 13.2, -150.0, -PI * 0.5, 0.0, 1.0, true], ["tariff_board", 0.0, -135.6, PI, 1.8, 1.0, false], ["receipt_printer", -8.0, -150.0, 0.0, 0.0, 1.0, true],
	["queue_stand", -10.0, -140.0, 0.0, 0.0, 1.0, true], ["queue_stand", -8.0, -142.0, 0.0, 0.0, 1.0, true], ["queue_stand", -6.0, -144.0, 0.0, 0.0, 1.0, true],
	["fortuna_wheel", 0.0, -165.4, 0.0, 2.2, 0.7, false],
	["cash_shield", 0.0, -187.2, 0.0, 0.0, 1.0, true], ["tariff_board", 0.0, -187.6, 0.0, 3.0, 1.0, false],
	["turnstile", -9.0, -174.5, 0.0, 0.0, 1.0, true], ["turnstile", -6.0, -174.5, 0.0, 0.0, 1.0, true], ["turnstile", -3.0, -174.5, 0.0, 0.0, 1.0, true], ["turnstile", 3.0, -174.5, 0.0, 0.0, 1.0, true], ["turnstile", 6.0, -174.5, 0.0, 0.0, 1.0, true], ["turnstile", 9.0, -174.5, 0.0, 0.0, 1.0, true],
	["turnstile", -9.0, -179.0, 0.0, 0.0, 1.0, true], ["turnstile", -6.0, -179.0, 0.0, 0.0, 1.0, true], ["turnstile", -3.0, -179.0, 0.0, 0.0, 1.0, true], ["turnstile", 3.0, -179.0, 0.0, 0.0, 1.0, true], ["turnstile", 6.0, -179.0, 0.0, 0.0, 1.0, true], ["turnstile", 9.0, -179.0, 0.0, 0.0, 1.0, true],
	["turnstile", -9.0, -183.5, 0.0, 0.0, 1.0, true], ["turnstile", -6.0, -183.5, 0.0, 0.0, 1.0, true], ["turnstile", -3.0, -183.5, 0.0, 0.0, 1.0, true], ["turnstile", 3.0, -183.5, 0.0, 0.0, 1.0, true], ["turnstile", 6.0, -183.5, 0.0, 0.0, 1.0, true], ["turnstile", 9.0, -183.5, 0.0, 0.0, 1.0, true],
	["bench", -11.0, -178.0, PI * 0.5, 0.0, 1.0, true], ["bench", 11.0, -178.0, -PI * 0.5, 0.0, 1.0, true], ["bench", -11.0, -174.0, PI * 0.5, 0.0, 1.0, true], ["bench", 11.0, -174.0, -PI * 0.5, 0.0, 1.0, true],
]

## Надписи раздела 7 PODZEMKA_DESIGN.md: [текст, x, y, z, поворот, размер, цвет]
const SIGNS := [
	["ВЫХОД (ПЛАТНО)", 0.0, 2.7, -25.6, 0.0, 0.34, Color(0.4, 1.0, 0.5)],
	["ВЫХОД ПЛАТНЫЙ. ПАНИКУ ПРИНИМАЕМ БЕСПЛАТНО", 0.0, 2.2, -16.4, PI, 0.16, Color(1.0, 0.9, 0.4)],
	["ПРОХОД ПО ТАРИФУ", -4.0, 2.9, -26.2, PI, 0.2, Color(1.0, 0.85, 0.3)],
	["ПЕРВЫЙ ПРОХОД ПОЧТИ БЕСПЛАТНЫЙ", 4.0, 2.9, -26.2, PI, 0.14, Color(1.0, 0.85, 0.3)],
	["БЕЗ БИЛЕТА НЕ РАБОТАЕМ", -8.4, 2.2, -33.0, PI * 0.5, 0.16, Color(1.0, 1.0, 1.0)],
	["БЕЗ ОПЛАТЫ НЕ СТОЯТЬ", 8.4, 2.2, -31.0, -PI * 0.5, 0.16, Color(1.0, 1.0, 1.0)],
	["ВЫХОД ОТДЕЛЬНО", 8.4, 2.2, -40.0, -PI * 0.5, 0.16, Color(1.0, 1.0, 1.0)],
	["ПРОХОД ДЛЯ ЛЮДЕЙ. ДЛЯ ОСТАЛЬНЫХ — ТАРИФ", 0.0, 3.0, -43.6, 0.0, 0.17, Color(1.0, 0.85, 0.3)],
	["НЕ СТОЯТЬ В ОЧЕРЕДИ БЕЗ ОЧЕРЕДИ", 0.0, 2.9, -49.5, 0.0, 0.16, Color(1.0, 1.0, 1.0)],
	["НОСКИ. БАФЫ. ОБМЕНУ НЕ ПОДЛЕЖАТ", -4.75, 2.6, -66.0, PI * 0.5, 0.12, Color(1.0, 1.0, 1.0)],
	["РЕМОНТ ТЕЛЕФОНОВ. ЧИНИМ ДО ПОЛНОЙ ПОЛОМКИ", -4.75, 2.6, -60.0, PI * 0.5, 0.1, Color(1.0, 1.0, 1.0)],
	["КЛЮЧИ ЗА 8 МИНУТ. ОТ ЧЕГО — НЕ НАШЕ ДЕЛО", 4.75, 2.6, -54.0, -PI * 0.5, 0.1, Color(1.0, 1.0, 1.0)],
	["ШАУРМА 812. С ЧЕРЕМШОЙ НЕ ПРЕДЛАГАТЬ", -4.75, 2.6, -54.0, PI * 0.5, 0.1, Color(1.0, 1.0, 1.0)],
	["ДЖЕЛОС APPROVED", 9.7, 1.0, -76.0, -PI * 0.5, 0.08, Color(1.0, 0.85, 0.3)],
	["ОБЪЯВЛЕНИЕ О ЗАКРЫТИИ ОБЪЯВЛЕНИЙ", 0.0, 1.6, -109.7, 0.0, 0.1, Color(0.9, 0.9, 0.8)],
	["ВЫХОД БЕСПЛАТНЫЙ →", 4.5, 3.1, -113.7, PI, 0.14, Color(0.4, 1.0, 0.5)],
	["СПРАВКА О ТОМ, ЧТО СПРАВКА НЕ НУЖНА — 67 РУБЛЕЙ", -6.0, 2.0, -110.4, 0.0, 0.11, Color(1.0, 1.0, 1.0)],
	["КАМЕРА ХРАНЕНИЯ. ХРАНИМ. ВЫДАЁМ — ПО ТАРИФУ", -8.5, 3.0, -133.7, 0.0, 0.1, Color(0.4, 1.0, 0.5)],
	["ПЕРВЫЙ ВДОХ БЕСПЛАТНО. ПОСЛЕДУЮЩИЕ — ПО ТАРИФУ", -30.0, 3.0, -111.6, 0.0, 0.16, Color(0.5, 0.95, 1.0)],
	["АВТОМАТ СДАЧУ ДАЁТ. ПОТОМ.", -22.5, 2.3, -115.0, 0.0, 0.09, Color(1.0, 1.0, 1.0)],
	["БИЛЕТ № 8. НЕ СПРАШИВАЙТЕ", -18.0, 2.4, -131.7, PI, 0.12, Color(1.0, 0.85, 0.3)],
	["НЕ ТРОГАТЬ. ТУТ ХОМЯКИ", 43.6, 2.3, -146.0, -PI * 0.5, 0.16, Color(1.0, 0.6, 0.3)],
	["Серега РПлюс заебал бухать. Резолюция: принято к сведению. FORTUNA 812", 39.7, 2.2, -160.0, PI * 0.5, 0.07, Color(0.9, 0.9, 0.8)],
	["В ЭТОЙ ЭКОНОМИКЕ ДАЖЕ МЫСЛИ ПО ТАРИФУ", 41.9, 2.4, -128.0, -PI * 0.5, 0.1, Color(1.0, 1.0, 1.0)],
	["в этой… трубе что-то живёт", 20.0, 1.8, -123.8, PI, 0.09, Color(0.2, 0.2, 0.2)],
	["ВОЗВРАТ ДЕНЕГ НЕ ПРЕДУСМОТРЕН, ДАЖЕ ЕСЛИ ВЫ НЕ ПЛАТИЛИ", 0.0, 3.4, -134.4, PI, 0.14, Color(1.0, 0.85, 0.3)],
	["КАССА № 8 НЕ СУЩЕСТВУЕТ", 12.8, 3.1, -157.4, -PI * 0.5, 0.1, Color(1.0, 0.85, 0.3)],
	["ПРИЁМ ПИЩИ ПО ТАРИФУ", -20.0, 2.0, -149.6, 0.0, 0.14, Color(1.0, 0.9, 0.6)],
]

## Модели владельца (Tripo, PODZEMKA_TRIPO_PROMPTS.md): [файл без .glb, высота, м]. Файл есть — ставится вместо Blender-версии с авто-посадкой
const OWNER_MODELS := {
	"dog": ["g67_pz_dog", 0.96], "hamster_a": ["g67_pz_hamster", 0.5], "hamster_b": ["g67_pz_hamster", 0.5], "hamster_c": ["g67_pz_hamster", 0.5],
	"hamster_gold": ["g67_pz_hamster_gold", 0.55], "slot_machine": ["g67_pz_slot_cabinet", 2.2], "shawarma_spit": ["g67_pz_shawarma_spit", 1.35], "kennel": ["g67_pz_dog_house", 1.5], "microwave": ["g67_pz_microwave", 0.32],
	"arcade_a": ["g67_pz_arcade_machine", 1.8], "arcade_b": ["g67_pz_arcade_machine", 1.8], "vend_drinks": ["g67_pz_vending_drinks", 1.9],
}
## Посадочные точки слота для корпуса владельца (g67_pz_slot_cabinet): смещения от центра низа корпуса, м (лицо по +Z)
## Ассеты Sketchfab (CC0/CC-BY, CREDITS_SKETCHFAB.md): id предмета → файл в podzemka/. Есть файл — ставится вместо Blender-версии в своём размере
const SF_MODELS := {
	"turnstile": "sf_turnstile", "kiosk_odds": "sf_kiosk_a", "kiosk_exchange": "sf_kiosk_a", "kiosk_keys": "sf_kiosk_a", "kiosk_socks": "sf_kiosk_a", "stall": "sf_stall", "boxes": "sf_boxes", "pallet": "sf_pallet", "extinguisher": "sf_extinguisher", "trash": "sf_trash",
	"vend_drinks": "sf_vend_a", "vend_snacks": "sf_vend_b", "vend_change": "sf_vend_c", "vend_broken": "sf_vend_d", "arcade_a": "sf_arcade_a", "arcade_b": "sf_arcade_b", "booth": "sf_booth", "sofa": "sf_sofa", "mop": "sf_mop", "hamster_a": "sf_hamster", "hamster_b": "sf_hamster", "hamster_c": "sf_hamster", "storage": "sf_lockers", "bench": "sf_bench",
}
const SLOT_SOCKETS := {"screen_w": 1.04, "screen": Vector3(0.0, 1.143, 0.345), "screen_tilt": -9.0, "button": Vector3(0.454, 0.684, 0.41), "lamp_x": 0.643, "lamp_z0": 0.69, "lamp_z1": 1.51, "lamp_front": 0.32, "board": Vector3(-0.3, 1.45, 0.45), "jackpot": Vector3(0.3, 1.45, 0.45), "cabinet_height": 2.2}

func _fit_owner(inst: Node3D, height: float) -> void:
	var bb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var a: AABB = m.transform * m.mesh.get_aabb()
		var p := m.get_parent()
		while p != null and p != inst and p is Node3D:
			a = (p as Node3D).transform * a
			p = p.get_parent()
		bb = a if first else bb.merge(a)
		first = false
	if first or bb.size.y < 0.001:
		return
	var k := height / bb.size.y
	inst.scale = Vector3(k, k, k)
	inst.position -= Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * k

func _decorate() -> void:
	all_props_cache = _all_props()
	for pr in all_props_cache:
		var path := PROP_PATH + String(pr[0]) + ".glb"
		var owner_h := 0.0
		if OWNER_MODELS.has(String(pr[0])):
			var op := PROP_PATH.get_base_dir() + "/" + String(OWNER_MODELS[String(pr[0])][0]) + ".glb"
			if ResourceLoader.exists(op):
				path = op
				owner_h = float(OWNER_MODELS[String(pr[0])][1])
		if owner_h <= 0.0 and SF_MODELS.has(String(pr[0])):
			var sp: String = PROP_PATH.get_base_dir() + "/" + String(SF_MODELS[String(pr[0])]) + ".glb"
			if ResourceLoader.exists(sp):
				path = sp
		if not ResourceLoader.exists(path):
			missing.append(path)
			continue
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		add_child(inst)
		var sc := float(pr[5])
		inst.transform = Transform3D(Basis(Vector3.UP, float(pr[3])).scaled_local(Vector3(sc, sc, sc)), (Vector3(float(pr[1]), float(pr[4]), float(pr[2])) if pr.size() > 7 else fit(Vector3(float(pr[1]), float(pr[4]), float(pr[2])))))
		if owner_h > 0.0:
			var wrap := Node3D.new()
			wrap.transform = inst.transform
			remove_child(inst)
			inst.transform = Transform3D.IDENTITY
			add_child(wrap)
			wrap.add_child(inst)
			_fit_owner(inst, owner_h)
			inst = wrap
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prop_count += 1
		inst.name = String(pr[0])
		if String(pr[0]).begins_with("hamster_") and not String(pr[0]) in ["hamster_wall", "hamster_props"]:
			hamsters.append([inst, inst.position.y, inst.rotation.y, _hash(float(pr[1]), float(pr[2]), 9.0) * 6.28])
		if pr.size() > 8 and pr[8] != null:
			var gl := OmniLight3D.new()
			gl.light_color = pr[8] as Color
			gl.light_energy = 0.55
			gl.omni_range = 2.6
			gl.position = Vector3(0, 1.3, 0.7)
			gl.shadow_enabled = false
			inst.add_child(gl)
			if _hash(float(pr[1]), float(pr[2]), 4.0) > 0.55:
				flicker.append([gl, 0.55, float(pr[1]) * 0.7])
		if String(pr[0]) == "shawarma_spit":
			spit_node = inst.find_child("spit", true, false) as Node3D
			for smi in inst.find_children("*", "MeshInstance3D", true, false):
				var sm := (smi as MeshInstance3D).mesh
				for si in sm.get_surface_count():
					var smat := sm.surface_get_material(si) as BaseMaterial3D
					if smat != null:
						smat.emission_enabled = false
			var wl := OmniLight3D.new()
			wl.light_color = Color(1.0, 0.93, 0.8)
			wl.light_energy = 0.7
			wl.omni_range = 2.4
			wl.position = Vector3(0.1, 1.9, 0.5)
			inst.add_child(wl)
			var rl := OmniLight3D.new()
			rl.light_color = Color(1.0, 0.45, 0.15)
			rl.light_energy = 0.12
			rl.omni_range = 0.9
			rl.position = Vector3(0.0, 0.7, -0.45)
			inst.add_child(rl)
		if String(pr[0]) == "dog":
			dog_node = inst
			dog_yaw = float(pr[3])
			dog_base = inst.position
		if bool(pr[6]):
			var bb := AABB()
			var first := true
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				var a: AABB = inst.global_transform.affine_inverse() * (m.global_transform * m.mesh.get_aabb()) if m.mesh != null else AABB()
				bb = a if first else bb.merge(a)
				first = false
			var cpos := inst.transform * (bb.get_center())
			_collider(cpos, Vector3(bb.size.x * sc, bb.size.y * sc, bb.size.z * sc), float(pr[3]))
	for dg in signs_dyn:
		var lb2 := Label3D.new()
		lb2.text = String(dg[0])
		lb2.font_size = 64
		lb2.pixel_size = 0.0034
		lb2.modulate = Color(1.0, 0.92, 0.55)
		lb2.outline_size = 12
		lb2.outline_modulate = Color(0.1, 0.05, 0.0, 0.9)
		lb2.shaded = false
		lb2.double_sided = false
		lb2.position = dg[1]
		lb2.rotation.y = float(dg[2])
		add_child(lb2)
		G67Sign.board(lb2)                          # вывеска на щите, а не буквы в воздухе
		sign_nodes.append(lb2)
	for sg in SIGNS:
		var lb := Label3D.new()
		lb.text = String(sg[0])
		lb.font_size = 64
		lb.pixel_size = float(sg[5]) / 64.0 * 2.2
		lb.modulate = sg[6] as Color
		lb.outline_size = 10
		lb.outline_modulate = Color(0, 0, 0, 0.8)
		lb.width = 1400.0 if String(sg[0]).length() > 24 else 900.0
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.shaded = false
		lb.position = fit(Vector3(float(sg[1]), float(sg[2]), float(sg[3])))
		lb.rotation.y = _inward_yaw(lb.position, float(sg[4]))
		lb.double_sided = false
		lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lb)
		G67Sign.board(lb, 0.4 if float(sg[2]) >= 2.6 else 0.0)      # верхние указатели — на подвесах
		sign_nodes.append(lb)

## свой световой характер зон, мигающие лампы, капель
func _zone_lights() -> void:
	var spots := [
		[Vector3(0, 7.5, 3), Color(0.55, 0.7, 1.0), 2.5, 10.0], [Vector3(0, 1.8, -17), Color(0.3, 1.0, 0.4), 2.2, 7.0],
		[Vector3(-30, 2.6, -122), Color(0.3, 0.8, 1.0), 1.0, 12.0], [Vector3(-26, 2.6, -118), Color(1.0, 0.3, 0.8), 1.0, 10.0],
		[Vector3(-50, 2.0, -122), Color(1.0, 0.25, 0.7), 1.1, 8.0], [Vector3(-48, 2.2, -121), Color(0.2, 0.9, 1.0), 0.7, 6.0],
		[Vector3(51, 2.5, -146), Color(1.0, 0.65, 0.3), 2.4, 12.0], [Vector3(0, 3.5, -179), Color(1.0, 0.95, 0.7), 3.0, 18.0],
		[Vector3(0, 3.0, -150), Color(1.0, 0.95, 0.7), 2.5, 16.0],
	]
	for sp in spots:
		var l := OmniLight3D.new()
		l.position = fit(sp[0])
		l.light_color = sp[1]
		l.light_energy = sp[2]
		l.omni_range = sp[3]
		l.shadow_enabled = false
		add_child(l)
	# мигающие лампы: три ближайших к ключевым точкам
	for pos in [Vector3(0, 3.1, -26), Vector3(40, 2.4, -135), Vector3(-30, 3.2, -122)]:
		var l2 := OmniLight3D.new()
		l2.position = fit(pos)
		l2.light_color = Color(0.85, 0.95, 0.9)
		l2.light_energy = 1.8
		l2.omni_range = 8.0
		l2.shadow_enabled = false
		add_child(l2)
		flicker.append([l2, 1.8, randf() * 5.0])
	# капель: четыре точки
	for pos in [Vector3(22, 2.7, -122), Vector3(42, 2.7, -140), Vector3(-9, 2.5, -80), Vector3(18, 2.7, -168)]:
		var p := GPUParticles3D.new()
		p.amount = 6
		p.lifetime = 1.0
		p.position = fit(pos) + Vector3(0, 0.8, 0)
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 2.0
		pm.initial_velocity_min = 0.4
		pm.initial_velocity_max = 0.8
		pm.gravity = Vector3(0, -9.0, 0)
		p.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.02, 0.07)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.6, 0.75, 0.9, 0.8)
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = mt
		p.draw_pass_1 = qm
		add_child(p)

func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_dog_anim(_dt, t)
	if spit_node != null and is_instance_valid(spit_node):
		spit_node.rotate_y(_dt * 0.55)
	for lp in slot_lamps:
		var on := (int(t * lamp_rate) + int(lp[2])) % 2 == 0
		(lp[1] as StandardMaterial3D).emission_energy_multiplier = 2.4 if on else 0.15
	if slot_button != null:
		var pressed: bool = slot_screen != null and slot_screen.spinning
		slot_button.scale.y = 0.55 if pressed else 1.0
	for f in flicker:
		var l: OmniLight3D = f[0]
		var ph := float(f[2])
		var k := 1.0 if fmod(t + ph, 3.7) > 0.5 else (0.2 if int(t * 18.0 + ph * 5.0) % 3 == 0 else 1.0)
		l.light_energy = float(f[1]) * k
	for h in hamsters:
		var hn: Node3D = h[0]
		if not is_instance_valid(hn):
			continue
		var hp := float(h[3])
		hn.position.y = float(h[1]) + absf(sin(t * 5.0 + hp)) * 0.012 + pow(maxf(0.0, sin(t * 1.1 + hp)), 10.0) * 0.14
		hn.rotation.y = float(h[2]) + sin(t * 0.6 + hp) * 0.7 + sin(t * 2.3 + hp * 2.0) * 0.08

## Экран слота: SubViewport с 2D-сценой на плоскости перед окном корпуса; физические барабаны убраны
func _slot_screen() -> void:
	var cab: Node3D = get_node_or_null("slot_machine") as Node3D
	if cab != null:
		for ch in cab.get_children():
			if String(ch.name).begins_with("casino_reel"):
				ch.queue_free()
	slot_vp = SubViewport.new()
	slot_vp.size = Vector2i(1024, 586)
	slot_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	slot_vp.transparent_bg = false
	add_child(slot_vp)
	slot_screen = G67SlotScreen.new()
	slot_vp.add_child(slot_screen)
	slot_screen.finished.connect(func(r: Dictionary):
		if bool(r["jackpot"]):
			dog_joy()
		elif int(r["gold"]) > 0:
			dog_bark())
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(SLOT_SOCKETS["screen_w"], SLOT_SOCKETS["screen_w"] * 586.0 / 1024.0)
	q.mesh = qm
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = slot_vp.get_texture()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = mt
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sk: Vector3 = SLOT_SOCKETS["screen"]
	q.transform = Transform3D(Basis(Vector3.UP, SLOT_YAW) * Basis(Vector3.RIGHT, deg_to_rad(float(SLOT_SOCKETS["screen_tilt"]))), SLOT_POS + Basis(Vector3.UP, SLOT_YAW) * sk)
	q.name = "slot_screen_quad"
	add_child(q)
	var yb := Basis(Vector3.UP, SLOT_YAW)
	var bm := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.055
	bc.bottom_radius = 0.06
	bc.height = 0.05
	bm.mesh = bc
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.9, 0.05, 0.05)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.1, 0.05)
	bmat.emission_energy_multiplier = 1.6
	bm.material_override = bmat
	bm.transform = Transform3D(yb * Basis(Vector3.RIGHT, deg_to_rad(80.0)), SLOT_POS + yb * (SLOT_SOCKETS["button"] as Vector3))
	bm.name = "spin_button"
	add_child(bm)
	slot_button = bm
	for side in [-1.0, 1.0]:
		for i in 7:
			var t := float(i) / 6.0
			var lm := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.018
			sm.height = 0.036
			lm.mesh = sm
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(1.0, 0.9, 0.5)
			lmat.emission_enabled = true
			lmat.emission = Color(1.0, 0.85, 0.4)
			lmat.emission_energy_multiplier = 2.0
			lm.material_override = lmat
			lm.transform = Transform3D(Basis(), SLOT_POS + yb * Vector3(side * float(SLOT_SOCKETS["lamp_x"]), lerpf(float(SLOT_SOCKETS["lamp_z0"]), float(SLOT_SOCKETS["lamp_z1"]), t), float(SLOT_SOCKETS["lamp_front"])))
			lm.name = "slot_lamp"
			add_child(lm)
			slot_lamps.append([lm, lmat, (i + (0 if side < 0.0 else 1)) % 2])

## Собака — жёсткая модель (Tripo, без скелета): дыхание, поворот за героем, лай (рывок назад и вверх со сжатием), прыжок радости на джекпоте
func dog_bark() -> void:
	dog_bark_t = 0.0

func dog_joy() -> void:
	dog_joy_t = 0.0

func _dog_anim(dt: float, t: float) -> void:
	if dog_node == null or not is_instance_valid(dog_node):
		return
	var yaw := dog_yaw
	var hv: Node3D = hero as Node3D if hero != null and is_instance_valid(hero) else null
	if hv != null:
		var to: Vector3 = hv.global_position - dog_node.global_position
		if to.length() < 9.0:
			var want := atan2(to.x, to.z)
			var d := wrapf(want - dog_yaw, -PI, PI)
			yaw = dog_yaw + clampf(d, -0.7, 0.7)
		if to.length() < 6.0:
			dog_next_bark -= dt
			if dog_next_bark <= 0.0:
				dog_next_bark = randf_range(5.0, 8.0)
				dog_bark()
	var breath := 1.0 + 0.012 * sin(t * 3.2)
	var pos := dog_base
	var pitch := 0.0
	var sq := Vector3(1.0 / sqrt(breath), breath, 1.0 / sqrt(breath))
	if dog_bark_t >= 0.0:
		dog_bark_t += dt
		var k := dog_bark_t / 0.35
		if k >= 1.0:
			dog_bark_t = -1.0
		else:
			var p := sin(k * PI)
			pitch = -0.16 * p
			pos += Vector3(0, 0.05 * p, 0)
			sq = Vector3(1.0 + 0.04 * p, 1.0 - 0.06 * p, 1.0 + 0.04 * p)
	if dog_joy_t >= 0.0:
		dog_joy_t += dt
		var kj := dog_joy_t / 1.8
		if kj >= 1.0:
			dog_joy_t = -1.0
		else:
			pos += Vector3(0, absf(sin(kj * PI * 3.0)) * 0.45 * (1.0 - kj), 0)
			pitch = -0.1 * sin(kj * PI * 6.0)
	dog_node.position = pos
	dog_node.rotation = Vector3(pitch, yaw, 0)
	dog_node.scale = sq

## Поворот надписи так, чтобы она читалась из помещения: нормаль (+Z узла) смотрит к центру комнаты (по ближайшей оси)
func _inward_yaw(p: Vector3, given: float) -> float:
	var id := room_at(Vector3(p.x, 0.5, p.z))
	if id == "":
		id = room_at(Vector3(p.x, 0.5, p.z - 0.5))
	if id == "":
		return given
	var r: Array = ROOMS[id]
	var c := Vector2((float(r[0]) + float(r[1])) * 0.5, (float(r[2]) + float(r[3])) * 0.5)
	var d := Vector2(c.x - p.x, c.y - p.z)
	if d.length() < 1.2:
		return given
	if absf(d.x) > absf(d.y):
		return PI * 0.5 if d.x > 0.0 else -PI * 0.5
	return 0.0 if d.y > 0.0 else PI

## Свои ряды и острова (координаты уже новые, без fit): ларьки галереи вплотную, острова автоматов, мелочь. [модель, x, z, yaw, y, масштаб, коллизия, true, свет экрана]
const KIOSK_CYCLE := ["kiosk_odds", "kiosk_shawarma", "kiosk_keys", "kiosk_phones", "kiosk_exchange", "kiosk_socks"]
const KIOSK_SIGNS := {"kiosk_odds": "МЕЛОЧИ · ВСЁ ПО 8", "kiosk_keys": "КЛЮЧИ ЗА 8 МИНУТ", "kiosk_exchange": "ОБМЕН · СДАЧА — ПОТОМ", "kiosk_socks": "НОСКИ. БАФЫ."}
const SCREEN_COLORS := [Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.8), Color(0.4, 1.0, 0.5), Color(1.0, 0.8, 0.3), Color(0.5, 0.5, 1.0)]

func _all_props() -> Array:
	var skip := ["microwave", "chess", "kiosk_odds", "kiosk_exchange", "kiosk_keys", "kiosk_socks", "kiosk_phones", "kiosk_shawarma", "shawarma_spit", "arcade_a", "arcade_b"]
	var out: Array = []
	for pr in PROPS:
		if String(pr[0]) == "turnstile" and float(pr[2]) < -170.0:
			continue          # линии арены — игровые объекты G67FortunaArena
		if not String(pr[0]) in skip:
			out.append(pr)
	var bulbs: Array = []
	var k := 0
	for seg in [[-70.0, -44.0], [-110.0, -88.0]]:
		var zn: float = float(seg[1]) - 1.8
		var n := 0
		while zn - 1.5 > float(seg[0]) + 0.3:
			for side: float in [-1.0, 1.0]:
				var door_gap: bool = side < 0.0 and (absf(zn + 48.0) < 3.2 or absf(zn + 104.0) < 3.2)
				if door_gap:
					continue
				var id: String = KIOSK_CYCLE[(k + (0 if side < 0.0 else 3)) % KIOSK_CYCLE.size()]
				var cx: float = side * (6.25 - (1.15 if id in ["kiosk_shawarma", "kiosk_phones"] else 1.28))
				var yaw: float = PI * 0.5 if side < 0.0 else -PI * 0.5
				out.append([id, cx, zn, yaw, 0.0, 1.0, true, true, null])
				if id == "kiosk_shawarma":
					out.append(["shawarma_spit", cx - side * 0.55, zn - 0.6, yaw, 1.04, 1.0, false, true, null])
				if KIOSK_SIGNS.has(id):
					signs_dyn.append([String(KIOSK_SIGNS[id]), Vector3(cx - side * 1.32, 2.55, zn), yaw])
				if _hash(cx, zn, 9.0) > 0.45:
					out.append([["boxes", "pallet", "trash", "boxes"][int(_hash(zn, cx, 3.0) * 4.0) % 4], cx - side * 2.1, zn + 1.0 * side, _hash(cx, zn, 5.0) * 6.0, 0.0, 1.0, false, true, null])
			# провод-времянка с лампочками поперёк прохода
			for b in 9:
				var t := float(b) / 8.0
				bulbs.append(Vector3(lerpf(-6.0, 6.0, t), 3.4 - sin(t * PI) * -0.25 + 0.0, zn + 1.65))
			zn -= 3.35
			k += 1
			n += 1
	# острова автоматов зала: спина к спине, два ряда по шесть
	var zi := 0
	for zc in [-125.5, -116.5]:
		for i in 5:
			var x := -38.0 + float(i) * 2.9
			var a1: String = "arcade_a" if (i + zi) % 2 == 0 else "arcade_b"
			var a2: String = "arcade_b" if (i + zi) % 2 == 0 else "arcade_a"
			var col: Color = SCREEN_COLORS[(i + zi * 2) % SCREEN_COLORS.size()]
			out.append([a1, x, zc - 0.62, 0.0, 0.0, 1.0, true, true, col if i % 2 == 0 else null])
			out.append([a2, x, zc + 0.62, PI, 0.0, 1.0, true, true, SCREEN_COLORS[(i + zi + 2) % SCREEN_COLORS.size()] if i % 2 == 1 else null])
		out.append(["trash", -39.5, zc, 0.0, 0.0, 1.0, false, true, null])
		zi += 1
	for zz in [-130.0, -112.0]:
		out.append(["boxes", -42.0, zz, 0.4, 0.0, 1.0, false, true, null])
		out.append(["pallet", -41.0, zz + 0.9, 0.0, 0.0, 1.0, false, true, null])
	# комната персонала, тоннель, техпомещение, хомячья: мелочь
	out.append(["sofa", -27.1, -145.0, PI * 0.5, 0.0, 1.0, true, true, null])
	out.append(["mop", -17.6, -149.0, 0.5, 0.0, 1.0, false, true, null])
	out.append(["boxes", -18.0, -141.0, 0.3, 0.0, 1.0, false, true, null])
	out.append(["trash", -17.5, -146.0, 0.0, 0.0, 1.0, false, true, null])
	for tp in [[20.0, -123.4], [28.0, -121.0], [41.5, -131.0], [41.0, -146.5], [18.0, -168.0], [30.0, -169.5]]:
		out.append(["pallet", tp[0], tp[1], 0.3, 0.0, 1.0, false, true, null])
		out.append(["boxes", tp[0], tp[1], 0.7, 0.17, 1.0, false, true, null])
	out.append(["boxes", 33.5, -162.0, 0.4, 0.0, 1.0, false, true, null])
	out.append(["mop", 31.5, -158.0, 1.0, 0.0, 1.0, false, true, null])
	for hp in [[46.0, -146.0], [47.5, -143.0], [54.0, -144.5], [56.5, -147.5], [52.0, -142.0], [49.5, -148.5]]:
		out.append(["hamster_a", hp[0], hp[1], _hash(hp[0], hp[1], 6.0) * 6.0, 0.0, 1.3, false, true, null])
	out.append(["microwave", -39.0, -110.6, PI * -0.5, 0.9, 1.0, false, true, null])
	out.append(["chess", -40.2, -110.6, 0.0, 0.9, 1.0, false, true, null])
	_crate(Vector3(-39.6, 0.45, -110.6), Vector3(1.9, 0.9, 0.9))
	out.append(["extinguisher", 2.0, -44.6, 0.0, 0.0, 1.0, false, true, null])
	G67Sound.loop_at(self, "loop_vent", Vector3(11.0, 6.4, 3.3), 22.0)
	# реквизит залов, которые стояли пустыми: перекрёсток, кассы, комната персонала, тоннель, техпомещение.
	# Всё — вдоль стен: середина залов, точки выхода врагов и проходы остаются свободными.
	for q in [
		["bench", -13.2, -114.0, PI * 0.5, true], ["bench", 13.2, -130.0, -PI * 0.5, true], ["vend_snacks", 13.1, -113.0, -PI * 0.5, true], ["vend_change", 13.0, -116.0, -PI * 0.5, true],
		["bin", -13.0, -131.5, 0.0, true], ["bin", 13.0, -127.2, 0.0, true], ["queue_stand", -9.0, -129.6, 0.0, true], ["queue_stand", -9.0, -126.4, 0.0, true],
		["extinguisher", -13.6, -112.0, 0.0, false], ["trash", 12.8, -132.8, 0.0, false], ["boxes", -12.7, -116.6, 0.4, false],
		["bench", -15.6, -158.0, PI * 0.5, true], ["bench", -15.6, -154.0, PI * 0.5, true], ["bin", -15.6, -161.0, 0.0, true], ["vend_drinks", 15.4, -139.0, -PI * 0.5, true],
		["vend_snacks", 15.4, -141.6, -PI * 0.5, true], ["trash", 15.2, -163.6, 0.0, false], ["queue_stand", 9.0, -146.0, 0.0, true], ["queue_stand", 9.0, -154.0, 0.0, true], ["extinguisher", -16.0, -137.0, 0.0, false],
		["storage", -22.5, -149.5, 0.0, true], ["bench", -22.0, -140.8, PI, true], ["vend_broken", -17.3, -143.5, -PI * 0.5, true], ["bin", -27.6, -148.8, 0.0, true],
		["trash", 36.8, -140.0, 0.0, false], ["extinguisher", 43.6, -136.0, 0.0, false], ["boxes", 37.0, -126.6, 0.2, false], ["pallet", 37.2, -144.0, 1.2, false],
		["storage", 34.5, -163.5, 0.0, true], ["pallet", 32.0, -162.6, 0.2, false], ["trash", 37.8, -157.2, 0.0, false]]:
		out.append([q[0], q[1], q[2], q[3], 0.0, 1.0, q[4], true, null])
	_string_bulbs(bulbs)
	return out

var signs_dyn: Array = []
var all_props_cache: Array = []

func _string_bulbs(pts: Array) -> void:
	if pts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(1.0, 0.85, 0.5)
	mt.emission_enabled = true
	mt.emission = Color(1.0, 0.8, 0.4)
	mt.emission_energy_multiplier = 2.2
	sm.material = mt
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _crate(pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.45, 0.32, 0.18)
	mt.roughness = 0.9
	mi.material_override = mt
	mi.position = pos
	add_child(mi)
	_collider(pos, size)

## Двери секретных комнат: рольставня казино и дверь хомяков — закрыты (блокер + панель), открываются по [E] (open_door)
## Закрытый киоск «ШАРЫ. ПРАЗДНИК. ТАРИФ» с баллоном и связкой шаров у западной стены площади галереи (точка [E] — ролик PZ_BALLOON01)
func _balloon_kiosk() -> void:
	var base := Vector3(-10.6, 0.0, -83.5)
	var kb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 2.2, 2.4)
	kb.mesh = bm
	var km := StandardMaterial3D.new()
	km.albedo_color = Color(0.36, 0.4, 0.38)
	kb.material_override = km
	kb.position = base + Vector3(0, 1.1, 0)
	add_child(kb)
	_collider(kb.position, bm.size)
	var sg := Label3D.new()
	sg.text = "ШАРЫ. ПРАЗДНИК. ТАРИФ"
	sg.font_size = 44
	sg.pixel_size = 0.0045
	sg.modulate = Color(1.0, 0.85, 0.2)
	sg.shaded = false
	sg.rotation.y = PI * 0.5
	sg.position = base + Vector3(0.72, 2.5, 0)
	add_child(sg)
	G67Sign.board(sg)
	var sh := Label3D.new()
	sh.text = "ЗАКРЫТО НА УЧЁТ"
	sh.font_size = 28
	sh.pixel_size = 0.004
	sh.modulate = Color(0.9, 0.9, 0.9)
	sh.shaded = false
	sh.rotation.y = PI * 0.5
	sh.position = base + Vector3(0.72, 1.4, 0)
	add_child(sh)
	G67Sign.board(sh, 0.0, 0.0, Color(0.25, 0.05, 0.05))
	for i in 3:
		var bl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.46
		bl.mesh = sm
		var bmt := StandardMaterial3D.new()
		bmt.albedo_color = [Color(0.95, 0.15, 0.12), Color(1.0, 0.85, 0.12), Color(0.2, 0.85, 0.3)][i]
		bmt.roughness = 0.2
		bl.material_override = bmt
		bl.position = base + Vector3(0.9, 1.9 + 0.15 * float(i % 2), -0.55 + 0.55 * float(i))
		add_child(bl)
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.14
	cm.height = 0.9
	tank.mesh = cm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.7, 0.72, 0.75)
	tm.metallic = 0.6
	tank.material_override = tm
	tank.position = base + Vector3(0.95, 0.45, 0.85)
	add_child(tank)

func _doors() -> void:
	_balloon_kiosk()
	music_casino = Marker3D.new()
	music_casino.position = Vector3(-52.2, 1.2, -122.0)
	add_child(music_casino)
	music_hamster = Marker3D.new()
	music_hamster.position = Vector3(48.0, 1.2, -146.0)
	add_child(music_hamster)
	for d in [["shutter", Vector3(-44.25, 0.0, -122.0), Vector3(0.3, 3.6, 4.0), Color(0.55, 0.57, 0.6)], ["hamster", Vector3(44.0, 0.0, -146.0), Vector3(0.3, 3.2, 4.0), Color(0.42, 0.28, 0.16)], ["tech", Vector3(38.7, 0.0, -160.0), Vector3(0.3, 3.2, 4.0), Color(0.3, 0.33, 0.38)]]:
		var size: Vector3 = d[2]
		var pos: Vector3 = d[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = d[3]
		mt.roughness = 0.6
		mt.metallic = 0.5 if String(d[0]) == "shutter" else 0.0
		mi.material_override = mt
		mi.position = pos + Vector3(0, size.y * 0.5, 0)
		add_child(mi)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = mi.position
		add_child(sb)
		door_nodes[String(d[0])] = [mi, sb]
		door_open_flags[String(d[0])] = false

func open_door(id: String) -> bool:
	if not door_nodes.has(id) or bool(door_open_flags.get(id, false)):
		return false
	door_open_flags[id] = true
	var mi: MeshInstance3D = door_nodes[id][0]
	var sb: StaticBody3D = door_nodes[id][1]
	sb.queue_free()
	var tw := mi.create_tween()
	if id == "shutter" or id == "tech":
		tw.tween_property(mi, "position:y", mi.position.y + 3.4, 1.1)
	else:
		tw.tween_property(mi, "rotation:y", PI * 0.5, 0.9)
		tw.parallel().tween_property(mi, "position:z", mi.position.z - 1.8, 0.9)
	return true
