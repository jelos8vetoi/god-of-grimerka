## Модели окружения гонок (godot/assets/racing/*.glb, сгенерированы в Tripo AI — tools/tripo-gen.cjs).
## Каждая модель приводится к своему игровому размеру (SIZE, метры: ширина x, высота y, глубина z), ставится
## основанием на землю и центром в точку; FRONT — куда у модели «лицо» (дверь гаража, окно ларька): на сколько
## её повернуть, чтобы лицо смотрело по +Z. Столкновения у оформления — свои простые формы в race_track.gd,
## модели только вид. Нет файла — трасса строится из простых форм, как раньше.
class_name RaceProps

const DIR := "res://assets/racing/"
## размеры в игре, м — те же, что в tools/tripo-models.json
const SIZE := {
	"garage": Vector3(3.6, 2.8, 5.0), "khrushchevka": Vector3(24.0, 14.0, 10.0), "panel_tower": Vector3(14.0, 26.0, 12.0),
	"factory_hall": Vector3(20.0, 10.0, 14.0), "water_tank": Vector3(5.0, 8.0, 5.0), "pipe_bridge": Vector3(16.0, 7.0, 2.0),
	"dumpster": Vector3(1.9, 1.4, 1.3), "trash_pile": Vector3(3.0, 1.2, 2.5), "fence_section": Vector3(6.0, 2.2, 0.3),
	"street_lamp": Vector3(1.2, 6.0, 1.5), "tire_stack": Vector3(1.2, 1.4, 1.2), "barrel": Vector3(0.8, 1.1, 0.8),
	"traffic_cone": Vector3(0.5, 0.75, 0.5), "billboard": Vector3(8.0, 6.0, 1.0), "kiosk": Vector3(3.0, 2.8, 2.5),
	"bus_stop": Vector3(5.0, 3.0, 2.0), "tunnel_section": Vector3(16.0, 8.0, 12.0), "bridge_section": Vector3(16.0, 4.0, 12.0),
	"old_car": Vector3(1.7, 1.5, 4.1), "item_box": Vector3(1.0, 1.0, 1.0),
	"birch_tree": Vector3(4.0, 8.0, 4.0), "bare_tree": Vector3(5.0, 7.0, 5.0), "bush": Vector3(2.5, 1.4, 2.0),
	"playground": Vector3(8.0, 4.5, 6.0), "power_pole": Vector3(1.6, 8.0, 0.6), "heating_pipe": Vector3(10.0, 2.0, 1.2),
	"bench": Vector3(2.0, 1.0, 0.8), "transformer_booth": Vector3(3.5, 3.5, 3.0), "tower_crane": Vector3(12.0, 32.0, 4.0),
	"old_van": Vector3(2.0, 2.2, 4.4), "gazebo": Vector3(4.0, 3.2, 4.0),
}
## поворот модели, чтобы её лицо смотрело по +Z: Tripo выгружает модели лицом по +X (export_orientation "+x"),
## поэтому по умолчанию −90°; отдельные исключения — здесь (подобраны по листу --propsheet)
const FRONT_DEFAULT := -PI * 0.5
const FRONT := {}
## как вписывать: "height" — по высоте (пропорции модели), "box" — целиком в план x·z, "width" — по ширине x,
## "long" — длинной стороной в плане (модель могла лечь вдоль любой оси)
## (пролёты и секции: важна длина, которой они стыкуются)
const FIT := {"heating_pipe": "long", "tower_crane": "height", "fence_section": "width", "pipe_bridge": "width", "tunnel_section": "width", "bridge_section": "width", "khrushchevka": "box", "panel_tower": "height", "billboard": "width"}

static var _cache := {}        # id → [PackedScene, AABB модели]

static func has(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func _info(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var ps: PackedScene = load(DIR + id + ".glb")
	var inst: Node3D = ps.instantiate()
	var acc := [AABB(), false]
	for c in inst.get_children():
		if c is Node3D:
			_walk(c, (c as Node3D).transform, acc)
	inst.free()
	_cache[id] = [ps, acc[0]]
	return _cache[id]

static func _walk(n: Node3D, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = b if not acc[1] else (acc[0] as AABB).merge(b)
		acc[1] = true
	for c in n.get_children():
		if c is Node3D:
			_walk(c, xf * (c as Node3D).transform, acc)

## поставить модель: основанием на землю в pos, лицом по направлению yaw (как у дороги: atan2(x, z)).
## k — множитель размера (разнообразие). Возвращает узел или null, если модели нет.
static func spawn(id: String, parent: Node, pos: Vector3, yaw: float, k := 1.0, shadows := true) -> Node3D:
	if not has(id):
		return null
	var info := _info(id)
	var ps: PackedScene = info[0]
	var bb: AABB = info[1]
	var want: Vector3 = SIZE.get(id, Vector3.ONE) * k
	var turn: float = float(FRONT.get(id, FRONT_DEFAULT))
	var bs := bb.size
	if absf(fmod(absf(turn), PI) - PI * 0.5) < 0.1:
		bs = Vector3(bs.z, bs.y, bs.x)
	var s: float
	var fit := String(FIT.get(id, "height"))
	if fit == "box":
		s = minf(want.x / maxf(bs.x, 0.001), want.z / maxf(bs.z, 0.001))
	elif fit == "width":
		s = want.x / maxf(bs.x, 0.001)
	elif fit == "long":
		s = maxf(want.x, want.z) / maxf(maxf(bs.x, bs.z), 0.001)
	else:
		s = want.y / maxf(bs.y, 0.001)
	var root := Node3D.new()
	root.name = id
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var m: Node3D = ps.instantiate()
	var holder := Node3D.new()
	holder.rotation.y = turn
	root.add_child(holder)
	holder.add_child(m)
	m.scale = Vector3.ONE * s
	var c := bb.get_center()
	m.position = Vector3(-c.x, -bb.position.y, -c.z) * s
	if not shadows:
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Много одинаковых моделей одним MultiMesh на каждую поверхность модели: деревья, кусты, машины —
## одна отрисовка на вид, а не сотни узлов. xfs — [место, поворот, k]. vis_end — дальше не рисуется (м).
static func batch(id: String, parent: Node, xfs: Array, vis_end := 0.0, shadows := true) -> int:
	if not has(id) or xfs.is_empty():
		return 0
	var info := _info(id)
	var bb: AABB = info[1]
	var turn: float = float(FRONT.get(id, FRONT_DEFAULT))
	var bs := bb.size
	if absf(fmod(absf(turn), PI) - PI * 0.5) < 0.1:
		bs = Vector3(bs.z, bs.y, bs.x)
	var want: Vector3 = SIZE.get(id, Vector3.ONE)
	var fit := String(FIT.get(id, "height"))
	var s0: float = want.y / maxf(bs.y, 0.001)
	if fit == "box":
		s0 = minf(want.x / maxf(bs.x, 0.001), want.z / maxf(bs.z, 0.001))
	elif fit == "width":
		s0 = want.x / maxf(bs.x, 0.001)
	elif fit == "long":
		s0 = maxf(want.x, want.z) / maxf(maxf(bs.x, bs.z), 0.001)
	var c := bb.get_center()
	var base := Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(-c.x, -bb.position.y, -c.z))
	# сетки модели с их местом внутри файла
	var inst: Node3D = (info[0] as PackedScene).instantiate()
	var meshes: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local := Transform3D()
		var n: Node = m
		while n != inst:
			local = (n as Node3D).transform * local
			n = n.get_parent()
		meshes.append([m.mesh, local, m.get_active_material(0)])
	inst.free()
	for md in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = md[0]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			var x: Array = xfs[k]
			var sc: float = s0 * float(x[2])
			var t := Transform3D(Basis(Vector3.UP, float(x[1])).scaled(Vector3.ONE * sc), x[0]) * base * (md[1] as Transform3D)
			mm.set_instance_transform(k, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = id + "_batch"
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mmi.visibility_range_end = vis_end
			mmi.visibility_range_end_margin = 10.0
		parent.add_child(mmi)
	return xfs.size()
