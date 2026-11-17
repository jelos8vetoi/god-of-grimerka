## Кости оружия, построенные в коде. Модели оружия (балон, доска, гитара) — цельные и без костей; здесь вдоль
## оружия ставится цепочка костей, вершины получают веса по положению, и оружие становится упругим:
##   — конец отстаёт от руки в махе и догоняет с перелётом (пружина на конце, как у настоящего тяжёлого предмета);
##   — от попадания оружие вздрагивает и гудит (kick);
##   — доска под ногами прогибается при приземлении и трюках (bump: концы вверх, середина вниз).
## Изгиб — небольшой и только видимый: точки удара, след и хват считаются по жёсткому оружию.
## Числа — SETS: bend — наибольший изгиб (рад), k — жёсткость пружины, damp — затухание (1 — без колебаний),
## gain — насколько отставание конца превращается в изгиб, from — с какой доли длины оружие гнётся (хват жёсткий).
class_name WeaponBones
extends Node

const N := 5      # звеньев; костей N + 1
const SETS := {
	"vozduh": {"bend": 0.1, "k": 1400.0, "damp": 0.5, "gain": 0.3, "from": 0.2},
	"skateboard": {"bend": 0.3, "k": 700.0, "damp": 0.32, "gain": 0.55, "from": 0.15},
	"guitar": {"bend": 0.16, "k": 1000.0, "damp": 0.4, "gain": 0.4, "from": 0.3},
	"board_ride": {"bend": 0.26, "k": 500.0, "damp": 0.28, "gain": 0.0, "from": 0.0},
}

var model: Node3D            # модель оружия: в её осях заданы кости
var skel: Skeleton3D
var cfg: Dictionary
var axis := Vector3.RIGHT    # вдоль оружия, от хвата к концу (оси модели)
var a0 := Vector3.ZERO       # начало и конец оружия на оси, ед. модели
var a1 := Vector3.ZERO
var sim := Vector3.ZERO      # где сейчас «тяжёлый» конец (мир)
var vel := Vector3.ZERO
var sag := 0.0               # прогиб доски под ногами
var sag_v := 0.0
var started := false
var bend := 0.0              # для проверок: текущий изгиб, рад
var peak := 0.0              # для проверок: наибольший изгиб, рад

static func _mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _mesh(c)
		if r != null:
			return r
	return null

## Построить кости. m — модель оружия, ax — её ось вдоль оружия ("x", "y", "z"), from → to — от навершия к концу
## (те же числа, что в StyleData.weapon), set_id — строка SETS.
static func on(m: Node3D, ax: String, from: float, to: float, set_id: String) -> WeaponBones:
	var mi := _mesh(m)
	if mi == null or mi.mesh == null:
		return null
	var b := WeaponBones.new()
	b.model = m
	b.cfg = SETS[set_id]
	var i: int = {"x": 0, "y": 1, "z": 2}[ax]
	var src: Mesh = mi.mesh
	var c: Vector3 = mi.transform * src.get_aabb().get_center()      # ось идёт через середину модели
	b.a0 = c
	b.a1 = c
	b.a0[i] = from
	b.a1[i] = to
	b.axis = (b.a1 - b.a0).normalized()
	var L: float = (b.a1 - b.a0).length()
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var ws := PackedFloat32Array()
		bones.resize(vs.size() * 4)
		ws.resize(vs.size() * 4)
		for v in vs.size():
			var s: float = clampf(((mi.transform * vs[v]) - b.a0).dot(b.axis) / L, 0.0, 1.0) * float(N)
			var b0: int = mini(int(s), N - 1)
			var fr: float = s - float(b0)
			bones[v * 4] = b0
			bones[v * 4 + 1] = b0 + 1
			ws[v * 4] = 1.0 - fr
			ws[v * 4 + 1] = fr
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = ws
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	out.custom_aabb = src.get_aabb().grow(L * 0.5)
	b.skel = Skeleton3D.new()
	b.skel.name = "WeaponSkel"
	for k in N + 1:
		b.skel.add_bone("w%d" % k)
	mi.get_parent().add_child(b.skel)
	b.skel.transform = mi.transform
	mi.mesh = out
	mi.skin = b.skel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("../WeaponSkel")
	m.add_child(b)
	return b

## попадание: конец оружия отбрасывает (dir — в мире; пусто — поперёк оружия вверх)
func kick(power: float, dir := Vector3.ZERO) -> void:
	if not started:
		return
	var L: float = (model.global_transform * a1 - model.global_transform * a0).length()
	var d := dir
	if d.length() < 0.01:
		d = model.global_transform.basis * axis.cross(Vector3.FORWARD if abs(axis.z) < 0.9 else Vector3.UP)
	vel += d.normalized() * L * (5.0 + 4.0 * power)

## доска под ногами: приземление, трюк — дека прогибается
func bump(power := 1.0) -> void:
	sag_v -= 9.0 * power

func _process(dt: float) -> void:
	if model == null or skel == null or not model.is_visible_in_tree():
		started = false
		return
	dt = min(dt, 0.05)
	var gt := model.global_transform
	var tip: Vector3 = gt * a1
	var L: float = (tip - gt * a0).length()
	if not started or (sim - tip).length() > L * 1.2:
		started = true          # оружие появилось или перескочило (смена стиля, чехол): пружина начинает с покоя
		sim = tip
		vel = Vector3.ZERO
	var k: float = cfg["k"]
	var c: float = 2.0 * sqrt(k) * float(cfg["damp"])
	vel += ((tip - sim) * k - vel * c) * dt
	sim += vel * dt
	sag_v += (-sag * 320.0 - sag_v * 2.0 * sqrt(320.0) * float(cfg["damp"])) * dt
	sag += sag_v * dt
	# отставание конца → изгиб: только поперёк оружия
	var d: Vector3 = gt.affine_inverse().basis * (sim - tip)
	d -= axis * d.dot(axis)
	var Lm: float = (a1 - a0).length()
	var ang: float = clampf(d.length() / Lm * float(cfg["gain"]) * 2.0, 0.0, float(cfg["bend"]))
	var rot_axis: Vector3 = axis.cross(d).normalized() if d.length() > 0.0001 else Vector3.ZERO
	bend = ang + abs(sag) * float(cfg["bend"])
	peak = max(peak, bend)
	var from_k: float = float(cfg["from"]) * float(N)
	var x := Transform3D.IDENTITY
	var side: Vector3 = axis.cross(Vector3.UP if abs(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var mid: float = float(N) * 0.5
	for i in N + 1:
		if i > 0:
			var p: Vector3 = a0 + axis * (Lm * (float(i) - 0.5) / float(N))
			var q := Quaternion.IDENTITY
			var share: float = clampf((float(i) - from_k) / max(0.001, float(N) - from_k), 0.0, 1.0)
			if ang > 0.0001 and share > 0.0:
				q = Quaternion(rot_axis, ang * share * 2.0 / float(N))
			if abs(sag) > 0.0005:
				# прогиб деки: до середины звенья клонятся в одну сторону, после — в другую
				var s2: float = sag * float(cfg["bend"]) * 2.0 / float(N) * (1.0 if float(i) <= mid else -1.0)
				q = q * Quaternion(side, s2)
			var bq := Basis(q)
			x = x * Transform3D(bq, p - bq * p)
		skel.set_bone_pose_rotation(i, x.basis.get_rotation_quaternion())
		skel.set_bone_pose_position(i, x.origin)
