## Район ДВОР приквела «ГОЛДА 67» — один цельный постсоветский двор, а не набор отдельных арен.
## Строится один раз на забег; комнаты забега — это ЗОНЫ одного и того же двора (ZONES): у подъезда, гаражи,
## детская площадка, парковка у ларька, беседка, хоккейная «коробка» Миши Минасяна. При переходе двор целиком
## сдвигается так, чтобы зона боя оказалась в начале координат (враги игры держатся квадрата ±15 м вокруг нуля),
## поэтому из любой зоны видны остальные: дома, гаражи, ракета на площадке, прожекторы коробки.
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
## зоны: центр боя, откуда входит герой, где ставятся ворота выбора (север зоны), название
const ZONES := {
	"podezd": {"c": Vector3(0, 0, 21), "name": "у подъезда"},
	"garages": {"c": Vector3(-30, 0, 4), "name": "гаражи"},
	"playground": {"c": Vector3(1, 0, -8), "name": "детская площадка"},
	"parking": {"c": Vector3(30, 0, 2), "name": "парковка у ларька"},
	"gazebo": {"c": Vector3(-27, 0, -31), "name": "беседка"},
	"sport": {"c": Vector3(2, 0, -38), "name": "коробка"},
}
const HALF := 14.6             # полуразмер зоны боя

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
const QUEUE_SPOTS := [Vector3(40.35, 0.07, 7.0), Vector3(39.5, 0.07, 7.15), Vector3(38.65, 0.07, 6.95)]
## Кто может стоять в очереди: модель, рост, со скелетом ли (тогда стоит и покачивается, как живой)
const QUEUE_PEOPLE := [
	{"path": "res://assets/minigames/npc_customer.glb", "h": 1.74, "rig": true, "key": "npc_customer"},
	{"path": "res://assets/minigames/npc_neighbor.glb", "h": 1.58, "rig": true, "key": "npc_neighbor"},
	{"path": "res://assets/racing/npc_spectator.glb", "h": 1.7, "rig": false, "key": "npc_spectator"},
]
static var crowd_seed := 1     # меняется на каждый забег: очередь каждый раз другая
var boss_spot := Vector3(2, 0, -44.5)        # где ждёт Миша (у своей машины, на ковре)

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
	# дом с аркой: через неё турнир уходит дальше, в ПОДЗЕМКУ; над аркой — растяжка
	if _own("g67_house_arch", Vector3(49.6, 0, -15.5), -PI * 0.5, 15.2) != null:
		_sign("ТУРНИР 67", Vector3(44.55, 5.3, -15.5), -PI * 0.5, Color(1.0, 0.8, 0.2), 0.02, 64)
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
	_sign("ПАХАН + MADK1D\nБЫЛИ ТУТ", Vector3(-6.2, 1.4, 35.55), PI, Color(0.2, 0.5, 0.95, 0.9), 0.006, 48)

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
		_sign(str(61 + i), Vector3(-44.0 - back, 2.55, z - 1.7), PI * 0.5, Color(0.9, 0.85, 0.7), 0.005, 48)
	_sign("МИША ГЛАВНЫЙ", Vector3(-44.15, 1.5, 9.5), PI * 0.5, Color(0.85, 0.63, 0.2), 0.008, 56)
	_sign("67", Vector3(-44.1, 1.3, -5.5), PI * 0.5, Color(0.95, 0.75, 0.2), 0.02, 64)
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
	if _own("g67_shawarma_kiosk", Vector3(42.3, 0.07, 7.0), -PI * 0.5, 3.2) == null:
		_put("kiosk", Vector3(42.4, 0.07, 7.0), PI, 3.0)
	_light(Vector3(40.4, 1.8, 7.0), Color(1.0, 0.82, 0.5), 3.0, 9.0)
	_queue()
	_sign("ШАУРМА 67", Vector3(41.2, 3.3, 7.0), -PI * 0.5, Color(1.0, 0.8, 0.2), 0.007, 56)
	_put("bus_stop", Vector3(42.6, 0.07, 19.0), PI, 2.7)
	_put("transformer_booth", Vector3(19.5, 0, -14.5), -PI * 0.5, 3.4)
	_sign("НЕ ВЛЕЗАЙ\nУБЬЁТ", Vector3(19.5, 2.2, -12.75), 0.0, Color(0.9, 0.2, 0.15), 0.005, 48)
	_put("billboard", Vector3(44.0, 0, -19.5), PI * 0.75, 7.0, false)
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
		var node: Node3D
		if bool(who["rig"]):
			var r := Rig.new()
			add_child(r)
			r.setup(String(who["path"]), h, Poses.pahan(), true, 1.0, String(who["key"]))
			r.position = pos
			r.rotation.y = yaw
			r.play("Idle", 0.0)
			if r.player != null:
				r.player.seek(rng.randf_range(0.0, 2.0), true)             # не дышат в такт
			node = r
		else:
			node = G67Models.spawn(String(who["path"]), self, pos, yaw - PI * 0.5, Vector3(99, h, 99))      # модель гонок — лицом по +X
		_tint(node, tones[rng.randi() % tones.size()])
		_solid_box(pos + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
		node.name = "queue%d" % i
		queue.append(node)

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
	_sign("МИША МИНАСЯН", Vector3(2.0, 3.6, -49.25), 0.0, Color(0.95, 0.72, 0.2), 0.016, 64)
	_sign("ГЛАВНЫЙ АВТОРИТЕТ ДВОРА", Vector3(2.0, 2.85, -49.25), 0.0, Color(0.9, 0.85, 0.75), 0.008, 56)
	_light(Vector3(2.0, 3.0, -46.6), Color(1.0, 0.75, 0.3), 3.0, 9.0)
	# турник и брусья у западного борта — укрытие и его «качалка»
	_put("res://assets/golda67/g67_workout_bars.glb", Vector3(-8.0, 0.03, -43.5), 0.2, 2.7)
	_put("res://assets/golda67/g67_workout_bars.glb", Vector3(12.2, 0.03, -33.0), PI * 0.5, 2.5)
	_put("tire_stack", Vector3(-8.6, 0.03, -31.5), 0.6, 1.0)
	# мачты с прожекторами по углам — свет на лёд, длинные тени
	for c in [Vector3(x0 - 0.9, 0, z0 - 0.9), Vector3(x1 + 0.9, 0, z0 - 0.9), Vector3(x0 - 0.9, 0, z1 + 0.9), Vector3(x1 + 0.9, 0, z1 + 0.9)]:
		if _own("g67_floodlight_mast", c, atan2(2.0 - c.x, -38.0 - c.z), 8.6, "h", false) == null:
			_put("street_lamp", c, 0.0, 7.5, false)
		_solid_box(c + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))
	_light(Vector3(x0 + 3.0, 7.0, z0 + 3.0), Color(1.0, 0.93, 0.8), 4.2, 24.0, true)
	_light(Vector3(x1 - 3.0, 7.0, z1 - 3.0), Color(1.0, 0.9, 0.75), 3.6, 24.0)
	_light(Vector3(x1 - 3.0, 7.0, z0 + 3.0), Color(0.95, 0.9, 1.0), 2.4, 20.0)
	# зрители: лавки вдоль восточного борта снаружи и люди на них
	for i in 3:
		_put("bench", Vector3(17.0, 0, -44.0 + i * 5.5), PI, 0.95)
	for s in [[Vector3(16.6, 0, -44.3), 1.72], [Vector3(16.6, 0, -38.2), 1.66], [Vector3(16.7, 0, -33.4), 1.75], [Vector3(-12.6, 0, -36.0), 1.7]]:
		_put("npc_spectator", s[0], PI if s[0].x > 0 else 0.0, s[1], false)
	_drift(Vector3(-13.0, 0.3, -44.0), Vector3(2.0, 1.1, 7.0))
	_drift(Vector3(8.0, 0.3, -51.2), Vector3(9.0, 1.2, 2.2))
