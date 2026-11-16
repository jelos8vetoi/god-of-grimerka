## Проводные EarPods: два вкладыша (из assets/models/earpods.glb), разветвитель, штекер и белый провод.
## Узел — ребёнок скелета Пахана с единичным преобразованием, поэтому всё задаётся в пространстве скелета.
## Где вкладыши и куда идёт провод, решает pod.gd; здесь — только модели и построение провода.
## Провод — трубка по кубическим кривым Безье: штекер → разветвитель → два вкладыша, с провисанием от «лишней» длины.
## Длины кусков постоянны: если концы разошлись дальше, разветвитель подтягивается к ним, а не провод растягивается.
class_name EarPods
extends Node3D

const PATH := "res://assets/models/earpods.glb"
const BUD_H := 0.054         # высота вкладыша вместе с ножкой, единицы скелета (голова Пахана ≈ 0.46)
const R := 0.0026            # радиус провода
const SIDES := 6
const MAIN_LEN := 0.36       # штекер → разветвитель
const BRANCH_LEN := 0.25     # разветвитель → вкладыш
static var _parts := {}      # "L"/"R" → {mesh, stem: Vector3 (конец ножки в осях вкладыша), speaker: Vector3}

var buds := {}               # "L"/"R" → Node3D (начало координат — центр головки вкладыша)
var splitter: MeshInstance3D
var plug: MeshInstance3D
var cable: MeshInstance3D
var im: ImmediateMesh
var split_pos := Vector3.ZERO   # где разветвитель в прошлом кадре: держит его на месте, пока его не тянут
var split_ready := false
const SWAY_HZ := 2.1         # собственная частота раскачки провода: ниже — тяжелее, выше — «резиновая верёвка»
const SWAY_DAMP := 0.5       # затухание: пара покачиваний после остановки
const ACC_MAX := 30.0        # предел ускорения точки крепления, ед. скелета/с²
const ACC_SMOOTH := 0.06     # сглаживание ускорений, с: убирает дрожь от неровных кадров
var dyn: Array = []          # [середина: штекер-разветвитель, к L, к R; сам разветвитель] → смещение, скорость, движение в мире
var sim_acc := 0.0
var body_inv := Transform3D()
var body_xf := Transform3D()

func _ready() -> void:
	_load_parts()
	for side in ["L", "R"]:
		var p: Dictionary = _parts[side]
		var pivot := Node3D.new()
		pivot.name = "EarPod" + side
		var mi := MeshInstance3D.new()
		mi.mesh = p["mesh"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		add_child(pivot)
		buds[side] = pivot
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.93, 0.92)
	white.roughness = 0.45
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	im = ImmediateMesh.new()
	cable = MeshInstance3D.new()
	cable.name = "EarPodsCable"
	cable.mesh = im
	cable.material_override = white
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cable)
	# разветвитель: короткая скруглённая втулка; штекер: белый корпус и металлический наконечник
	splitter = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = R * 2.0
	cap.height = R * 9.0
	cap.radial_segments = 10
	cap.rings = 2
	splitter.mesh = cap
	splitter.material_override = white
	splitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splitter)
	plug = MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = R * 1.9
	body.bottom_radius = R * 2.1
	body.height = R * 7.0
	body.radial_segments = 10
	plug.mesh = body
	plug.material_override = white
	plug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = R * 0.9
	tm.bottom_radius = R * 0.9
	tm.height = R * 4.0
	tm.radial_segments = 8
	tip.mesh = tm
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.76, 0.78)
	metal.metallic = 1.0
	metal.roughness = 0.25
	tip.material_override = metal
	tip.position = Vector3(0, -R * 5.0, 0)
	plug.add_child(tip)
	add_child(plug)
	visible = false

## Вкладыши из присланной модели: в файле оба рядом (L слева, R справа), ножкой вниз, без провода.
## Делим треугольники по знаку x, переносим начало в центр головки и приводим к высоте BUD_H.
func _load_parts() -> void:
	if not _parts.is_empty():
		return
	var scn: Node3D = (load(PATH) as PackedScene).instantiate()
	var mi: MeshInstance3D = scn.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D()
	var n: Node = mi
	while n != scn:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var arr := mi.mesh.surface_get_arrays(0)
	var mat := mi.mesh.surface_get_material(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		idx.resize(vs.size())
		for i in vs.size():
			idx[i] = i
	var world := PackedVector3Array()
	world.resize(vs.size())
	for i in vs.size():
		world[i] = xf * vs[i]
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var remap := {}
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for t in range(0, idx.size(), 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			if (world[a].x + world[b].x + world[c].x) * s <= 0.0:
				continue
			for v in [a, b, c]:
				if not remap.has(v):
					remap[v] = nv.size()
					nv.append(world[v])
					nn.append((xf.basis * nr[v]).normalized() if nr.size() > v else Vector3.UP)
					nu.append(uv[v] if uv.size() > v else Vector2.ZERO)
					lo = lo.min(world[v])
					hi = hi.max(world[v])
				ni.append(remap[v])
		var h := hi.y - lo.y
		# центр головки — середина верхней части (выше 55% высоты), конец ножки — низ
		var head := Vector3.ZERO
		var hc := 0
		var stem := Vector3.ZERO
		var sc := 0
		for v in nv:
			if v.y > lo.y + 0.55 * h:
				head += v
				hc += 1
			elif v.y < lo.y + 0.06 * h:
				stem += v
				sc += 1
		head /= max(1, hc)
		stem /= max(1, sc)
		var k := BUD_H / h
		for i in nv.size():
			nv[i] = (nv[i] - head) * k
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = nv
		out[Mesh.ARRAY_NORMAL] = nn
		out[Mesh.ARRAY_TEX_UV] = nu
		out[Mesh.ARRAY_INDEX] = ni
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		mesh.surface_set_material(0, mat)
		# большое отверстие динамика смотрит к середине модели: у L — в +x, у R — в −x
		_parts[side] = {"mesh": mesh, "stem": (stem - head) * k, "speaker": Vector3(-s, 0, 0)}
	scn.free()

## Поворот вкладыша: отверстие динамика смотрит в speaker, ножка — в stem (оба в пространстве скелета).
func bud_basis(side: String, speaker: Vector3, stem: Vector3) -> Basis:
	var sm: Vector3 = _parts[side]["speaker"]
	var tm := Vector3(0, -1, 0)
	var s := speaker.normalized()
	var t := (stem - s * stem.dot(s)).normalized()
	var model := Basis(sm, tm, sm.cross(tm))
	var target := Basis(s, t, s.cross(t))
	return (target * model.inverse()).orthonormalized()

## Конец ножки (куда входит провод) для вкладыша с этим преобразованием.
func stem_end(side: String, xf: Transform3D) -> Vector3:
	return xf * (_parts[side]["stem"] as Vector3)

func place(side: String, xf: Transform3D, show: bool) -> void:
	var b: Node3D = buds[side]
	b.visible = show
	b.transform = xf

## Провод целиком. jack — конец штекера (iPod или карман), jack_dir — куда выходит провод из штекера,
## ends/dirs — концы ножек вкладышей и направления выхода провода из них, want_split — куда разветвитель «хочет».
## dt — шаг кадра; world — скелет в мире (для инерции), body — поза груди относительно позы привязки (обход груди).
func draw(jack: Vector3, jack_dir: Vector3, want_split: Vector3, ends: Array, dirs: Array, show_plug: bool, dt := 0.0, world := Transform3D(), body := Transform3D()) -> Vector3:
	im.clear_surfaces()
	body_inv = body.affine_inverse()
	body_xf = body
	# ---- динамика: середины трёх кусков и разветвитель — грузы на пружинах, их раскачивает движение тела в мире ----
	var mids := [(jack + want_split) * 0.5, (want_split + ends[0]) * 0.5, (want_split + ends[1]) * 0.5, want_split]
	_simulate(mids, dt, world)
	var sp: Vector3 = want_split + dyn[3]["off"]
	# длины постоянны: разветвитель не уходит от штекера и вкладышей дальше длины провода
	for it in 3:
		for e in ends:
			var d: Vector3 = sp - (e as Vector3)
			if d.length() > BRANCH_LEN * 0.97:
				sp = (e as Vector3) + d.normalized() * BRANCH_LEN * 0.97
		var dj := sp - jack
		if dj.length() > MAIN_LEN * 0.97:
			sp = jack + dj.normalized() * MAIN_LEN * 0.97
	sp = _keep_out(sp, R * 2.2)
	split_pos = sp
	split_ready = true
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# к разветвителю провод подходит снизу и держится перед животом (в пространстве скелета +z — вперёд от героя)
	_curve(jack, jack_dir, sp, Vector3(0, -1, 0.3), MAIN_LEN, 18, Vector3(0, 0, 0.045) + dyn[0]["off"])
	for i in ends.size():
		_curve(sp, Vector3.DOWN.lerp((ends[i] - sp).normalized(), 0.5).normalized(), ends[i], dirs[i], BRANCH_LEN, 14, dyn[i + 1]["off"])
	im.surface_end()
	splitter.position = sp
	splitter.basis = _along(jack - sp)
	plug.visible = show_plug
	plug.position = jack + jack_dir.normalized() * R * 3.0
	plug.basis = _along(-jack_dir)
	return sp

## Пружины с затуханием на постоянном шаге 1/120 с — одинаково при 30, 60 и 144 кадрах.
## Раскачку даёт ускорение точки крепления в мире (шаг, поворот, рывок руки), сглаженное, чтобы не было дрожи.
func _simulate(mids: Array, dt: float, world: Transform3D) -> void:
	if dyn.is_empty():
		for i in mids.size():
			dyn.append({"off": Vector3.ZERO, "vel": Vector3.ZERO, "w": Vector3.ZERO, "v": Vector3.ZERO, "acc": Vector3.ZERO, "ready": false})
	if dt <= 0.0:
		return
	var inv := world.basis.inverse()
	for i in mids.size():
		var d: Dictionary = dyn[i]
		var w: Vector3 = world * (mids[i] as Vector3)
		if not d["ready"] or (w - (d["w"] as Vector3)).length() > 1.5:
			d["w"] = w
			d["v"] = Vector3.ZERO
			d["acc"] = Vector3.ZERO
			d["ready"] = true
			continue
		var v: Vector3 = (w - (d["w"] as Vector3)) / dt
		var a: Vector3 = (v - (d["v"] as Vector3)) / dt
		d["w"] = w
		d["v"] = v
		# рывки (телепорт тела, поправка столкновений) ограничены: провод отвечает на движение, а не дёргается
		d["acc"] = (d["acc"] as Vector3).lerp((inv * a).limit_length(ACC_MAX), 1.0 - exp(-dt / ACC_SMOOTH))
	sim_acc += minf(dt, 0.1)
	var h := 1.0 / 120.0
	var wn := TAU * SWAY_HZ
	var steps := 0
	while sim_acc >= h and steps < 12:
		sim_acc -= h
		steps += 1
		for i in mids.size():
			var d: Dictionary = dyn[i]
			var lim := 0.03 if i == 3 else 0.045
			var off: Vector3 = d["off"]
			var vel: Vector3 = d["vel"]
			vel += (-off * wn * wn - vel * 2.0 * SWAY_DAMP * wn - (d["acc"] as Vector3)) * h
			off += vel * h
			if off.length() > lim:
				off = off.normalized() * lim
				vel -= off.normalized() * maxf(0.0, vel.dot(off.normalized()))
			d["off"] = off
			d["vel"] = vel

## Насколько сейчас раскачан провод (для проверки): наибольшее смещение от покоя.
func sway() -> float:
	var m := 0.0
	for d in dyn:
		m = maxf(m, (d["off"] as Vector3).length())
	return m

## Точка провода не уходит внутрь груди и живота: если она за передней поверхностью торса — выносим вперёд.
## Поверхность — по вершинам модели (поза привязки): на уровне живота z ≈ 0.128, к шее уходит назад.
func _keep_out(p: Vector3, pad: float) -> Vector3:
	var q := body_inv * p
	if absf(q.x) < 0.085 and q.y > 0.29 and q.y < 0.5:
		var front := 0.128 - maxf(0.0, q.y - 0.4) * 0.44 + pad
		if q.z < front and q.z > -0.06:
			q.z = front
			return body_xf * q
	return p

## Базис, у которого ось Y смотрит вдоль v (для втулки разветвителя и штекера).
func _along(v: Vector3) -> Basis:
	if v.length() < 0.000001:
		return Basis()
	var y := v.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

## Кусок провода от a до b: из a выходит по da, в b входит против db (db — куда провод уходит из b).
## Провисание: чем больше «лишней» длины (длина куска минус расстояние), тем ниже прогиб.
func _curve(a: Vector3, da: Vector3, b: Vector3, db: Vector3, length: float, n: int, bulge := Vector3.ZERO) -> void:
	var chord := a.distance_to(b)
	var sag: float = clamp((length - chord) * 0.45, 0.0, 0.07)
	var reach := clampf(chord * 0.4, 0.012, 0.08)
	var p1 := a + da.normalized() * reach + Vector3.DOWN * sag + bulge
	var p2 := b + db.normalized() * reach + Vector3.DOWN * sag + bulge
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		pts.append(_keep_out(a * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + b * t * t * t, R * 1.6))
	_tube(pts)

func _tube(pts: Array[Vector3]) -> void:
	var prev_side := Vector3.ZERO
	var rings: Array = []
	for i in pts.size():
		var tan: Vector3 = (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)])
		if tan.length() < 0.000001:
			tan = Vector3.UP
		tan = tan.normalized()
		# перенос рамки вдоль кривой без перекручивания
		var side := prev_side
		if side == Vector3.ZERO or absf(side.dot(tan)) > 0.95:
			side = tan.cross(Vector3.FORWARD if absf(tan.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT)
		side = (side - tan * side.dot(tan)).normalized()
		prev_side = side
		var up := tan.cross(side)
		var ring: Array = []
		for k in SIDES:
			var ang := TAU * k / SIDES
			var nrm := side * cos(ang) + up * sin(ang)
			ring.append([pts[i] + nrm * R, nrm])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in SIDES:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % SIDES]
			var c: Array = rings[i + 1][(k + 1) % SIDES]
			var d: Array = rings[i + 1][k]
			for v in [a, b, c, a, c, d]:
				im.surface_set_normal(v[1])
				im.surface_add_vertex(v[0])
