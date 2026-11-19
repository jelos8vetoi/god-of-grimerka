## Модели мини-игр: если в godot/assets/minigames лежит <id>.glb (Tripo, tools/tripo-minigames.json), ставится он —
## вписанный в нужный размер, лицом к +Z, основанием на пол; если файла нет — модель, собранная кодом (MGProps).
## Так модели владельца встают на место без правки кода: положил файл, `--import` — и сцена его подхватила.
## У Tripo лицо модели по +X — поворачиваем на −90° (как RaceProps); у кого иначе — FRONT.
class_name MGModels

const DIR := "res://assets/minigames/"
const FRONT_DEFAULT := -PI * 0.5
const FRONT := {}
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
	return root
