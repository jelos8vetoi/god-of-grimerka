## Модели мини-игр: если в godot/assets/minigames лежит <id>.glb (Tripo, tools/tripo-minigames.json), ставится он —
## вписанный в нужный размер, лицом к +Z, основанием на пол; если файла нет — модель, собранная кодом (MGProps).
## Так модели владельца встают на место без правки кода: положил файл, `--import` — и сцена его подхватила.
## Модели, скачанные с сайта Tripo (их присылает владелец), смотрят лицом по +Z — ставятся без доворота.
## Модели из tools/tripo-gen.cjs (API) смотрят по +X: для таких — FRONT[id] = −PI/2 (как RaceProps).
## Перед тем как класть файл в проект — облегчить: scripts/glbslim.gd (текстуры 4096 → 1024, JPEG).
## Накладки на модель (светящийся экран, лампочки) ставятся в «единицах модели»: 1 ед. = наибольшая сторона,
## начало — центр основания; local(root, u) переводит их в координаты узла (см. разметку в fn_facility.gd).
class_name MGModels

const DIR := "res://assets/minigames/"
const FRONT_DEFAULT := 0.0
## Модели второй партии владельца (tripo_convert_*.glb с сайта, 2026-11-20) смотрят лицом по +X — им доворот −PI/2;
## студийная камера — объективом по −Z, софит — по +Z.
const FRONT := {
	"fn_door_panel": -PI * 0.5, "ml_phone": -PI * 0.5, "ml_cash_stack": -PI * 0.5, "ml_job_trash_set": -PI * 0.5,
	"ml_job_parcel_box": -PI * 0.5, "ml_job_car_dirty": -PI * 0.5,
	"menu_crt_tv": -PI * 0.5, "menu_studio_camera": PI, "menu_spotlight": 0.0,
	"ml_job_part_speaker": -PI * 0.5,
}
static var _cache := {}         # id → [PackedScene, AABB] или null

static func has(id: String) -> bool:
	return _info(id) != null

static func _info(id: String):
	if _cache.has(id):
		return _cache[id]
	var path := DIR + id + ".glb"
	if not ResourceLoader.exists(path):
		_cache[id] = null
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		_cache[id] = null
		return null
	var inst: Node3D = ps.instantiate()
	var acc: Array = []
	_walk(inst, Transform3D.IDENTITY, acc)
	inst.free()
	var bb := AABB()
	for i in acc.size():
		bb = acc[i] if i == 0 else bb.merge(acc[i])
	_cache[id] = [ps, bb]
	return _cache[id]

static func _walk(n: Node, xf: Transform3D, acc: Array) -> void:
	var x := xf
	if n is Node3D:
		x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(x * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_walk(c, x, acc)

## Поставить модель id: pos — точка на полу, yaw — поворот, size — нужный размер [x, y, z] (вписывается по высоте,
## но не шире size.x/size.z), build — Callable(root: Node3D), который собирает запасную модель кодом.
static func spawn(id: String, parent: Node, pos: Vector3, yaw: float, size: Vector3, build: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = id
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var info = _info(id)
	if info == null:
		build.call(root)
		root.set_meta("from", "code")
		return root
	var ps: PackedScene = info[0]
	var bb: AABB = info[1]
	var turn: float = float(FRONT.get(id, FRONT_DEFAULT))
	var bs := bb.size
	if absf(fmod(absf(turn), PI) - PI * 0.5) < 0.1:
		bs = Vector3(bs.z, bs.y, bs.x)
	var s := size.y / maxf(bs.y, 0.001)
	s = minf(s, minf(size.x * 1.15 / maxf(bs.x, 0.001), size.z * 1.15 / maxf(bs.z, 0.001)))
	var holder := Node3D.new()
	holder.rotation.y = turn
	root.add_child(holder)
	var m: Node3D = ps.instantiate()
	holder.add_child(m)
	m.scale = Vector3.ONE * s
	var c := bb.get_center()
	m.position = Vector3(-c.x, -bb.position.y, -c.z) * s
	root.set_meta("from", "glb")
	root.set_meta("k", s * maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	return root

## Письменный стол владельца (ml_desk.glb) узкий — около метра. Широкий стол (w ≥ 1,5 м) собирается из двух таких,
## второй — зеркально: тумбы по краям, место для ног посередине. Глубина дотягивается до d (фасад при этом не
## искажается), высота столешницы — h. Нет файла — стол из кода (build).
static func wide_desk(parent: Node, pos: Vector3, yaw: float, w: float, d: float, h: float, build: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "ml_desk"
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var info = _info("ml_desk")
	if info == null:
		build.call(root)
		root.set_meta("from", "code")
		return root
	var bb: AABB = info[1]
	var s := h / bb.size.y
	var n := 2 if w >= 1.5 else 1
	for i in n:
		var half := spawn("ml_desk", root, Vector3((float(i) - 0.5) * w * 0.5 if n == 2 else 0.0, 0, 0), 0.0, Vector3(99, h, 99), func(_r): pass)
		var sx := (w / float(n)) / (bb.size.x * s)
		half.scale = Vector3(-sx if (n == 2 and i == 0) else sx, 1.0, d / (bb.size.z * s))
	root.set_meta("from", "glb")
	return root

## «Подсветить» модель из файла для тёмной сцены: её собственный цвет чуть светится (как усиление камеры ночного
## видения) — иначе тёмная модель в тёмной комнате сливается в пятно. k — сила (0,1–0,3). Материалы общие на все
## копии модели (по одному на исходный материал и силу).
static var _lifted := {}
static func lift(root: Node, k: float) -> void:
	if not is_glb(root):
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var key := "%d|%.2f" % [src.get_instance_id(), k]
			if not _lifted.has(key):
				var m := src.duplicate() as BaseMaterial3D
				m.emission_enabled = true
				m.emission = Color(1, 1, 1)
				m.emission_texture = m.albedo_texture
				m.emission_energy_multiplier = k
				_lifted[key] = m
			mi.set_surface_override_material(i, _lifted[key])

## модель из файла (а не собранная кодом)?
## Плоская вещь, которую Tripo вылепил стоя или наискось (пятна, аккумулятор, шлейф, вскрытый телефон): кладётся
## «лицом» вверх. Плоскость находится по самой модели — направление наименьшего разброса вершин (главные оси) —
## лицевая сторона та, что смотрела по +X. Вписывается в w × d по полу; поворот по полу — yaw. Нет файла — null.
static var _flat_cache := {}
static func spawn_flat(id: String, parent: Node, pos: Vector3, yaw: float, w: float, d: float) -> Node3D:
	var info = _info(id)
	if info == null:
		return null
	var ps: PackedScene = info[0]
	if not _flat_cache.has(id):
		_flat_cache[id] = _flat_basis(ps)
	var b: Basis = _flat_cache[id]
	var root := Node3D.new()
	root.name = id
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var hold := Node3D.new()
	root.add_child(hold)
	var m: Node3D = ps.instantiate()
	hold.add_child(m)
	hold.basis = b
	# габариты после поворота — по самим вершинам (рамка-коробка модели, повёрнутая наискось, раздувается)
	var bb := _vbox(m, b)
	if (w > d * 1.15 and bb.size.z > bb.size.x * 1.15) or (d > w * 1.15 and bb.size.x > bb.size.z * 1.15):
		b = Basis(Vector3.UP, PI * 0.5) * b               # длинная сторона — вдоль длинной стороны места
		bb = _vbox(m, b)
	var s := minf(w / maxf(bb.size.x, 0.001), d / maxf(bb.size.z, 0.001))
	hold.basis = b.scaled(Vector3.ONE * s)
	hold.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * s
	root.set_meta("from", "glb")
	root.set_meta("h", bb.size.y * s)
	return root

static func _vbox(m: Node, b: Basis) -> AABB:
	var pts := PackedVector3Array()
	_verts(m, Transform3D(b, Vector3.ZERO), pts)
	var bb := AABB(pts[0] if pts.size() > 0 else Vector3.ZERO, Vector3.ZERO)
	for p in pts:
		bb = bb.expand(p)
	return bb

static func _flat_basis(ps: PackedScene) -> Basis:
	var inst: Node3D = ps.instantiate()
	var pts := PackedVector3Array()
	_verts(inst, Transform3D.IDENTITY, pts)
	inst.free()
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= maxf(1.0, float(pts.size()))
	var C := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in pts:
		var q := p - c
		for i in 3:
			for j in 3:
				C[i][j] += q[i] * q[j]
	var xf: float = C[0][0] + C[1][1] + C[2][2]
	# наименьшее направление = наибольшее у (tr·I − C): степенной метод
	var v := Vector3(1, 0.3, 0.2).normalized()
	for it in 60:
		var nv := Vector3()
		for i in 3:
			nv[i] = xf * v[i] - (C[i][0] * v.x + C[i][1] * v.y + C[i][2] * v.z)
		v = nv.normalized()
	if v.x < 0.0:
		v = -v                                       # лицо смотрело по +X — оно и будет вверху
	var up := Vector3.UP
	var axis := v.cross(up)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), v.angle_to(up))

static func _verts(n: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var x := xf
	if n is Node3D:
		x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			@warning_ignore("integer_division")
			var step := maxi(1, vs.size() / 4000)
			for i in range(0, vs.size(), step):
				out.append(x * vs[i])
	for ch in n.get_children():
		_verts(ch, x, out)

static func is_glb(root: Node) -> bool:
	return root != null and String(root.get_meta("from", "")) == "glb"

## точка на модели из файла: u — в единицах модели (1 = наибольшая сторона, начало — центр основания, +Z — лицо)
static func local(root: Node, u: Vector3) -> Vector3:
	return u * float(root.get_meta("k", 1.0))
