## Район 2 «ПОДЗЕМКА»: каркас (этап 1). Помещения собираются из таблицы ROOMS (прямоугольники) и проёмов DOORS —
## тот же план на этапе 2 соберётся модулями 4 × 4 м. Координаты — PODZEMKA_DESIGN.md, раздел 1; пол всех
## помещений y = 0 (спуск — от y = 5 наверху до 0 внизу; в проекте пол «−5» — сдвиг на 5 м, игре всё равно).
class_name G67Podzemka
extends G67District

const T_WALL := 0.4

## id: [x0, x1, z0, z1, y_пола, y_потолка, поверхность, цвет света, имя]
const ROOMS := {
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
	["z", 0.0, -3.0, 3.0], ["z", -16.0, -3.0, 3.0], ["z", -26.0, -4.0, 4.0],
	["z", -44.0, -3.0, 3.0], ["z", -70.0, -3.0, 3.0], ["z", -88.0, -3.0, 3.0], ["z", -110.0, -3.0, 3.0],
	["x", -5.0, -50.0, -46.0], ["x", -5.0, -106.0, -102.0], ["x", -11.0, -50.0, -46.0], ["x", -11.0, -106.0, -102.0],
	["x", -12.0, -126.0, -118.0], ["x", -16.0, -126.0, -118.0], ["z", -132.0, -43.0, -39.0],
	["x", -44.0, -124.0, -120.0],
	["x", 12.0, -124.0, -120.0], ["x", 36.0, -124.0, -120.0], ["z", -150.0, 40.0, 44.0],
	["x", 44.0, -148.0, -144.0], ["x", 40.0, -161.5, -158.5],
	["z", -166.0, 40.0, 44.0], ["x", 14.0, -169.5, -166.5], ["z", -166.0, 8.0, 12.0],
	["z", -134.0, -3.0, 3.0], ["x", -14.0, -147.0, -143.0],
	["z", -166.0, -3.0, 3.0], ["z", -170.0, -3.0, 3.0],
]

## зоны боя (ключи совпадают с G67Data.pz_option); spawns — [[точка]]
const ZONES := {
	"stairs": {"c": Vector3(0, 0, -21), "h": Vector2(6, 5), "name": "спуск"},
	"gate1": {"c": Vector3(0, 0, -35), "h": Vector2(9, 9), "name": "первый турникет", "spawns": [[Vector3(-7.5, 0.05, -42)], [Vector3(7.5, 0.05, -42)], [Vector3(-7.5, 0.05, -28)], [Vector3(7.5, 0.05, -28)]]},
	"gallery": {"c": Vector3(0, 0, -79), "h": Vector2(10, 9), "name": "торговая галерея", "spawns": [[Vector3(-8.5, 0.05, -86)], [Vector3(8.5, 0.05, -86)], [Vector3(-8.5, 0.05, -72)], [Vector3(8.5, 0.05, -72)]]},
	"cross": {"c": Vector3(0, 0, -122), "h": Vector2(12, 12), "name": "перекрёсток", "spawns": [[Vector3(-10, 0.05, -131)], [Vector3(10, 0.05, -131)], [Vector3(-10, 0.05, -113)], [Vector3(10, 0.05, -113)]]},
	"arcade": {"c": Vector3(-30, 0, -122), "h": Vector2(14, 10), "name": "зал автоматов", "spawns": [[Vector3(-42, 0.05, -130)], [Vector3(-42, 0.05, -114)], [Vector3(-18, 0.05, -130)], [Vector3(-18, 0.05, -114)]]},
	"tunnel": {"c": Vector3(40, 0, -135), "h": Vector2(4, 15), "name": "служебный тоннель", "spawns": [[Vector3(38, 0.05, -148)], [Vector3(42, 0.05, -148)], [Vector3(38, 0.05, -123)], [Vector3(42, 0.05, -123)]]},
	"staff": {"c": Vector3(-20, 0, -145), "h": Vector2(6, 5), "name": "комната персонала"},
	"arena": {"c": Vector3(0, 0, -179), "h": Vector2(12, 9), "name": "арена", "spawns": [[Vector3(-10, 0.05, -186)], [Vector3(10, 0.05, -186)], [Vector3(-10, 0.05, -172)], [Vector3(10, 0.05, -172)]]},
}

## именованные точки (G67District.pt)
const POINTS := {
	"home": Vector3(0, 5, 3), "storage": Vector3(-9.0, 0, -128.0), "kiosk": Vector3(-20.0, 0, -116.0), "rest": Vector3(-20.0, 0, -145.0),
	"gate_boss": Vector3(0, 0, -160.0), "boss_entry": Vector3(0, 0.05, -173.5), "boss_spot": Vector3(0, 0, -185.0), "fit": Vector3(-3.5, 0, -79.0),
}
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

func _init() -> void:
	boss_spot = POINTS["boss_spot"]

func build() -> void:
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

func _m(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _box(pos: Vector3, size: Vector3, mat: Material, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
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

func _lamps(id: String, x0: float, x1: float, z0: float, z1: float, y1: float, col: Color) -> void:
	var nx := maxi(1, int(round((x1 - x0) / 8.0)))
	var nz := maxi(1, int(round((z1 - z0) / 8.0)))
	for i in nx:
		for j in nz:
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 1.5
			l.omni_range = 9.0 if y1 < 5.5 else 12.0
			l.position = Vector3(x0 + (float(i) + 0.5) * (x1 - x0) / float(nx), y1 - 0.4, z0 + (float(j) + 0.5) * (z1 - z0) / float(nz))
			l.shadow_enabled = KEY_LAMPS.has(id) and i == 0 and j == 0
			add_child(l)
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
