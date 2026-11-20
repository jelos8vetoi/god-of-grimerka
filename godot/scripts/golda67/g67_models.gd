## Модели приквела «ГОЛДА 67»: поставить .glb по пути, вписав в нужный размер (как MGModels.spawn, но путь любой:
## свои модели лежат в assets/golda67, часть берётся из гонок и мини-игр). Модели владельца смотрят лицом по +Z;
## у кого иначе — поворот в FRONT. Точка опоры — центр основания.
class_name G67Models
extends RefCounted

const DIR := "res://assets/golda67/"
## доворот лица модели к +Z
const FRONT := {
	"res://assets/minigames/menu_crt_tv.glb": -PI * 0.5,
}
static var _cache := {}         # путь → [PackedScene, AABB] или null

static func path_of(id: String) -> String:
	return id if id.begins_with("res://") else DIR + id + ".glb"

static func has(id: String) -> bool:
	return _info(path_of(id)) != null

static func _info(path: String):
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		_cache[path] = null
		return null
	var inst: Node3D = ps.instantiate()
	var acc: Array = []
	_walk(inst, Transform3D.IDENTITY, acc)
	inst.free()
	var bb := AABB()
	for i in acc.size():
		bb = acc[i] if i == 0 else bb.merge(acc[i])
	_cache[path] = [ps, bb]
	return _cache[path]

static func _walk(n: Node, xf: Transform3D, acc: Array) -> void:
	var x := xf
	if n is Node3D:
		x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(x * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_walk(c, x, acc)

## Поставить модель: pos — точка на полу (у настенных — низ), yaw — поворот, size — габариты [x, y, z], в которые
## модель вписывается целиком с сохранением пропорций. fit: "h" — по высоте (по умолчанию), "w" — по ширине.
## Нет файла — возвращает пустой узел с меткой from = "none" (место видно в проверке, кубов-заглушек не ставим).
static func spawn(id: String, parent: Node, pos: Vector3, yaw: float, size: Vector3, fit := "h") -> Node3D:
	var path := path_of(id)
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var info = _info(path)
	if info == null:
		root.set_meta("from", "none")
		return root
	var ps: PackedScene = info[0]
	var bb: AABB = info[1]
	var turn: float = float(FRONT.get(path, 0.0))
	var bs := bb.size
	if absf(fmod(absf(turn), PI) - PI * 0.5) < 0.1:
		bs = Vector3(bs.z, bs.y, bs.x)
	var s := size.y / maxf(bs.y, 0.001)
	if fit == "w":
		s = size.x / maxf(bs.x, 0.001)
	else:
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
	root.set_meta("size", bs * s)
	return root

## Цепь Миши Минасяна на его риге: файл цепи записан в «единицах модели» (1 = наибольшая сторона, начало — центр
## основания, tools/golda67-chain.cjs). Вешается на кость груди и идёт за анимацией.
static func misha_chain(rig: Rig) -> Node3D:
	var info = _info(DIR + "g67_misha_chain.glb")
	if info == null or rig == null or rig.skel == null:
		return null
	var mi: MeshInstance3D = null
	for n in rig.model.find_children("*", "MeshInstance3D", true, false):
		mi = n
		break
	if mi == null:
		return null
	var bb := mi.mesh.get_aabb()
	var unit: float = maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var b := rig.skel.find_bone("mixamorig_Spine2")
	if b < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_Spine2"
	rig.skel.add_child(att)
	var chain: Node3D = (info[0] as PackedScene).instantiate()
	att.add_child(chain)
	# место цепи в пространстве сетки → в пространство кости (по позе покоя)
	var in_mesh := Transform3D(Basis().scaled(Vector3.ONE * unit), Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
	var mesh_to_skel: Transform3D = rig.skel.global_transform.affine_inverse() * mi.global_transform
	chain.transform = rig.skel.get_bone_global_rest(b).affine_inverse() * mesh_to_skel * in_mesh
	return chain
