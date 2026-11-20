## Томск для трассы «КРЫШИ ТОМСКА»: узнаваемые здания и городские объекты, собранные кодом по формам настоящих
## (деревянные дома с шатрами и резьбой на Красноармейской, главный корпус университета, телебашня, полосатые трубы
## ГРЭС, пожарная каланча, мост через Томь, памятник Чехову на набережной, деревянный рубль, ПАЗик, трамвай).
## Это силуэты и характерные детали, а не копии: без чужих фотографий и текстур. Если в проекте есть файл
## godot/assets/racing/tomsk_<вид>.glb (промпты — godot/docs/TRIPO_PROMPTS_GAMEPLAY.md), берётся он.
## Столкновений у построек нет: они стоят вне дороги. spawn(вид, родитель, место, поворот, масштаб).
class_name RaceTomsk

static var _m := {}

static func mat(key: String, col: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_m[key] = m
	return m

static func box(p: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func cyl(p: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, m: Material, sides := 12, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

## двускатная крыша: призма вдоль оси z
static func gable(p: Node3D, pos: Vector3, size: Vector3, m: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	p.add_child(mi)
	return mi

## окно с резным наличником: рама, «корона» сверху и «фартук» снизу
static func window(p: Node3D, pos: Vector3, yaw: float, w: float, h: float, trim: Material, lit: bool) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	box(n, Vector3.ZERO, Vector3(w, h, 0.06), mat("glass_on", Color(1.0, 0.8, 0.45), 0.4, 1.3) if lit else mat("glass_off", Color(0.1, 0.13, 0.18), 0.3))
	box(n, Vector3(0, 0, 0.02), Vector3(w + 0.3, 0.1, 0.1), trim)
	box(n, Vector3(0, h * 0.5 + 0.08, 0.03), Vector3(w + 0.34, 0.16, 0.1), trim)
	box(n, Vector3(0, -h * 0.5 - 0.08, 0.03), Vector3(w + 0.34, 0.16, 0.1), trim)
	for sx in [-1.0, 1.0]:
		box(n, Vector3(sx * (w * 0.5 + 0.1), 0, 0.03), Vector3(0.14, h + 0.3, 0.1), trim)
	# корона наличника — зубцы резьбы
	for k in 5:
		box(n, Vector3((k - 2) * (w + 0.3) / 5.0, h * 0.5 + 0.27 + (0.1 if k == 2 else 0.0), 0.03), Vector3(0.16, 0.22 + (0.14 if k == 2 else 0.0), 0.08), trim)

## шатёр: высокая четырёхгранная пирамида со шпилем
static func tent(p: Node3D, pos: Vector3, r: float, h: float, m: Material) -> void:
	cyl(p, pos + Vector3(0, h * 0.5, 0), 0.0, r, h, m, 4, Vector3(0, PI / 4, 0))
	cyl(p, pos + Vector3(0, h + 0.7, 0), 0.0, 0.07, 1.4, mat("spire", Color(0.75, 0.7, 0.5), 0.4))

## модели владельца, скачанные с сайта Tripo (tripo_convert_*.glb), смотрят лицом по +X; здесь лицо — +Z
const FRONT := -PI * 0.5

static func spawn(kind: String, parent: Node3D, pos: Vector3, yaw := 0.0, k := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "tomsk_" + kind
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * k
	parent.add_child(n)
	var file := "res://assets/racing/tomsk_%s.glb" % kind
	if ResourceLoader.exists(file):
		# модель владельца вписывается в те же габариты, что у сборки кодом: по высоте, не шире и не глубже её
		# с запасом; длинная сторона модели — вдоль длинной стороны сборки (автобус, трамвай, мост)
		var ref := Node3D.new()
		_build(kind, ref)
		var want := _box_of(ref, Transform3D.IDENTITY)
		ref.free()
		var g: Node3D = (load(file) as PackedScene).instantiate()
		var have := _box_of(g, Transform3D.IDENTITY)
		var turn := FRONT                               # лицо модели (+X) — на лицо сборки (+Z)
		have = AABB(Vector3(have.position.z, have.position.y, have.position.x), Vector3(have.size.z, have.size.y, have.size.x))
		if (want.size.x > want.size.z * 1.4 and have.size.z > have.size.x * 1.4) or (want.size.z > want.size.x * 1.4 and have.size.x > have.size.z * 1.4):
			turn += PI * 0.5                            # длинная сторона не совпала (автобус, трамвай, мост) — ещё на четверть
			have = AABB(Vector3(have.position.z, have.position.y, have.position.x), Vector3(have.size.z, have.size.y, have.size.x))
		var s: float = want.size.y / maxf(have.size.y, 0.001)
		s = minf(s, minf(want.size.x * 1.25 / maxf(have.size.x, 0.001), want.size.z * 1.25 / maxf(have.size.z, 0.001)))
		var holder := Node3D.new()
		holder.rotation.y = turn
		n.add_child(holder)
		holder.add_child(g)
		g.scale = Vector3.ONE * s
		var own := _box_of(g, Transform3D.IDENTITY)            # в координатах самой модели (до масштаба)
		g.position = Vector3(-own.get_center().x * s, -own.position.y * s, -own.get_center().z * s)
		holder.position = Vector3(want.get_center().x, want.position.y, want.get_center().z)
		n.set_meta("glb", true)
		return n
	_build(kind, n)
	return n

## габариты всего, что нарисовано внутри узла (в его координатах)
static func _box_of(nd: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var acc: Array = []
	_walk(nd, xf, acc)
	for a in acc:
		out = a if first else out.merge(a)
		first = false
	return out

static func _walk(nd: Node, xf: Transform3D, acc: Array) -> void:
	for c in nd.get_children():
		var x := xf
		if c is Node3D:
			x = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			acc.append(x * (c as MeshInstance3D).mesh.get_aabb())
		_walk(c, x, acc)

## сборка кодом (запасная, когда файла нет; и мерка габаритов для файла)
static func _build(kind: String, n: Node3D) -> void:
	var white := mat("trim", Color(0.93, 0.92, 0.86))
	match kind:
		"wooden_tent":
			# зелёный деревянный особняк: два этажа, угловая башня с высоким шатром, резные наличники, крыльцо
			var wood := mat("w_green", Color(0.24, 0.42, 0.33))
			var roof := mat("r_green", Color(0.16, 0.3, 0.24), 0.6)
			box(n, Vector3(0, 3.2, 0), Vector3(13, 6.4, 9), wood)
			for fl in 2:
				box(n, Vector3(0, 0.2 + fl * 3.2, 0), Vector3(13.2, 0.18, 9.2), white)
			gable(n, Vector3(0, 7.9, 0), Vector3(9.6, 3.0, 13.4), roof, PI / 2)
			box(n, Vector3(5.2, 5.0, 3.4), Vector3(3.4, 10.0, 3.4), wood)
			box(n, Vector3(5.2, 10.1, 3.4), Vector3(3.9, 0.3, 3.9), white)
			tent(n, Vector3(5.2, 10.2, 3.4), 2.6, 6.5, roof)
			for fl in 2:
				for q in 4:
					window(n, Vector3(-4.6 + q * 2.4, 1.9 + fl * 3.2, 4.53), 0.0, 1.0, 1.6, white, (q + fl) % 3 == 0)
				window(n, Vector3(5.2, 2.0 + fl * 3.2, 5.13), 0.0, 1.0, 1.7, white, fl == 1)
			box(n, Vector3(-3.0, 1.4, 5.3), Vector3(2.6, 0.14, 1.8), white)       # козырёк крыльца
			for sx in [-1.0, 1.0]:
				cyl(n, Vector3(-3.0 + sx * 1.1, 0.7, 6.0), 0.09, 0.09, 1.4, white)
		"wooden_dragons":
			# тёмный сруб с голубыми фронтонами, центральная башня с острым шатром, на концах стропил — «драконьи головы»
			var dark := mat("w_dark", Color(0.3, 0.2, 0.14))
			var blue := mat("w_blue", Color(0.32, 0.55, 0.78))
			var roof2 := mat("r_brown", Color(0.2, 0.12, 0.1), 0.6)
			box(n, Vector3(0, 3.0, 0), Vector3(15, 6.0, 9), dark)
			gable(n, Vector3(0, 7.4, 0), Vector3(9.6, 2.8, 15.4), roof2, PI / 2)
			for sx in [-1.0, 1.0]:
				box(n, Vector3(sx * 5.0, 6.9, 4.56), Vector3(4.2, 1.6, 0.1), blue)      # голубые фронтоны
				gable(n, Vector3(sx * 5.0, 8.4, 4.0), Vector3(4.6, 1.5, 2.2), roof2)
			box(n, Vector3(0, 5.0, 4.0), Vector3(3.6, 10.0, 3.2), dark)
			box(n, Vector3(0, 9.0, 5.62), Vector3(2.6, 1.4, 0.1), blue)
			tent(n, Vector3(0, 10.0, 4.0), 2.7, 7.5, roof2)
			for q in 7:                                # драконы: зубчатые головы на выпусках стропил
				for sz in [-1.0, 1.0]:
					var hx := -6.9 + q * 2.3
					box(n, Vector3(hx, 6.2, sz * 5.0), Vector3(0.28, 0.28, 0.9), white, Vector3(0.35 * sz, 0, 0))
					box(n, Vector3(hx, 6.5, sz * 5.45), Vector3(0.3, 0.42, 0.34), mat("dragon", Color(0.75, 0.2, 0.15)))
			for fl in 2:
				for q in 5:
					if q == 2:
						continue
					window(n, Vector3(-6.0 + q * 3.0, 1.8 + fl * 3.0, 4.53), 0.0, 0.95, 1.9, white, (q * 2 + fl) % 4 == 0)
			window(n, Vector3(0, 6.2, 5.63), 0.0, 1.0, 2.2, white, true)
		"wooden_firebirds":
			# светлый дом с пышным резным фронтоном; на коньке и по углам — «жар-птицы»
			var ochre := mat("w_ochre", Color(0.62, 0.45, 0.25))
			var roof3 := mat("r_rust", Color(0.45, 0.2, 0.14), 0.6)
			var gold := mat("bird", Color(0.95, 0.6, 0.15), 0.5, 0.25)
			box(n, Vector3(0, 2.8, 0), Vector3(12, 5.6, 8.5), ochre)
			gable(n, Vector3(0, 6.9, 0), Vector3(9.2, 2.6, 12.4), roof3, PI / 2)
			gable(n, Vector3(0, 7.2, 3.6), Vector3(5.4, 3.2, 2.0), roof3)
			box(n, Vector3(0, 6.5, 4.64), Vector3(4.6, 1.9, 0.1), white)
			for q in 9:                                # кружево под карнизом
				box(n, Vector3(-5.6 + q * 1.4, 5.35, 4.3), Vector3(0.5, 0.5 if q % 2 == 0 else 0.28, 0.08), white)
			for bp in [Vector3(0, 9.3, 3.6), Vector3(-5.6, 6.2, 4.4), Vector3(5.6, 6.2, 4.4)]:
				# птица: тело, шея с головой, хвост веером
				box(n, bp, Vector3(0.55, 0.4, 0.9), gold)
				box(n, bp + Vector3(0, 0.45, 0.42), Vector3(0.2, 0.6, 0.2), gold, Vector3(0.4, 0, 0))
				for t in 3:
					box(n, bp + Vector3((t - 1) * 0.3, 0.35, -0.6), Vector3(0.14, 0.9, 0.08), mat("bird_tail", Color(0.85, 0.2, 0.12), 0.5, 0.2), Vector3(-0.7, (t - 1) * 0.35, 0))
			for fl in 2:
				for q in 4:
					window(n, Vector3(-4.2 + q * 2.8, 1.7 + fl * 2.8, 4.28), 0.0, 1.0, 1.6, white, (q + fl * 3) % 3 == 1)
		"tsu":
			# главный корпус университета: длинное белое здание, зелёная крыша, портик с фронтоном, крылья, роща
			var wall := mat("tsu_wall", Color(0.93, 0.92, 0.88))
			var groof := mat("tsu_roof", Color(0.25, 0.45, 0.38), 0.6)
			box(n, Vector3(0, 6.0, 0), Vector3(64, 12, 14), wall)
			box(n, Vector3(0, 12.4, 0), Vector3(65, 0.8, 15), groof)
			for sx in [-1.0, 1.0]:
				box(n, Vector3(sx * 27, 6.5, 6), Vector3(12, 13, 12), wall)
				box(n, Vector3(sx * 27, 13.3, 6), Vector3(12.8, 0.8, 12.8), groof)
			box(n, Vector3(0, 7.5, 8), Vector3(16, 15, 6), wall)
			gable(n, Vector3(0, 16.6, 8.2), Vector3(17, 3.4, 6.4), groof)
			for q in 4:
				box(n, Vector3(-5.4 + q * 3.6, 6.5, 11.2), Vector3(0.9, 11, 0.5), wall)
			for fl in 3:
				for q in 19:
					box(n, Vector3(-27 + q * 3.0, 2.6 + fl * 3.5, 7.02 if absf(-27 + q * 3.0) > 9 else 11.02), Vector3(1.2, 2.0, 0.08), mat("glass_on", Color(1.0, 0.8, 0.45), 0.4, 1.3) if (q + fl) % 5 == 0 else mat("glass_off", Color(0.1, 0.13, 0.18), 0.3))
			for q in 10:                               # университетская роща
				var tp := Vector3(-30 + q * 6.6, 0, 20 + (q % 3) * 3.0)
				cyl(n, tp + Vector3(0, 2.0, 0), 0.25, 0.3, 4.0, mat("trunk", Color(0.86, 0.85, 0.8)))
				cyl(n, tp + Vector3(0, 5.6, 0), 0.4, 2.4, 4.4, mat("leaf", Color(0.8, 0.55, 0.15)), 7)
		"tv_tower":
			# телебашня: решётчатая мачта в красно-белую полосу, площадки, антенна
			for q in 12:
				var hh := 14.0
				var r0 := 7.0 - q * 0.5
				cyl(n, Vector3(0, q * hh + hh * 0.5, 0), maxf(0.6, r0 - 0.5), maxf(0.7, r0), hh, mat("tw_red", Color(0.8, 0.15, 0.12)) if q % 2 == 0 else mat("tw_white", Color(0.92, 0.92, 0.9)), 4, Vector3(0, PI / 4, 0))
			for q in 3:
				cyl(n, Vector3(0, 60 + q * 40, 0), 5.0 - q, 5.0 - q, 1.2, mat("tw_deck", Color(0.3, 0.3, 0.33)), 10)
			cyl(n, Vector3(0, 184, 0), 0.15, 0.5, 32, mat("tw_red", Color(0.8, 0.15, 0.12)), 6)
			box(n, Vector3(0, 200.5, 0), Vector3(0.6, 0.6, 0.6), mat("tw_lamp", Color(1.0, 0.15, 0.1), 0.4, 3.0))
		"gres":
			# электростанция: корпус и две высокие трубы в красно-белую полосу, над ними — пар
			box(n, Vector3(0, 9, 0), Vector3(46, 18, 22), mat("gres_wall", Color(0.5, 0.48, 0.45)))
			box(n, Vector3(-8, 21, 0), Vector3(20, 6, 16), mat("gres_wall2", Color(0.42, 0.4, 0.38)))
			for sx in [-1.0, 1.0]:
				for q in 9:
					cyl(n, Vector3(sx * 12, 18 + q * 9 + 4.5, -6), 2.6 - q * 0.12, 2.75 - q * 0.12, 9.0, mat("tw_red", Color(0.8, 0.15, 0.12)) if q % 2 == 1 else mat("tw_white", Color(0.92, 0.92, 0.9)), 12)
				for q in 4:
					var puff := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 4.0 + q * 2.2
					sm.height = sm.radius * 1.6
					sm.radial_segments = 8
					sm.rings = 5
					puff.mesh = sm
					var pmat := StandardMaterial3D.new()
					pmat.albedo_color = Color(0.9, 0.9, 0.92, 0.55 - q * 0.1)
					pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					puff.material_override = pmat
					puff.position = Vector3(sx * 12 + q * 5.0, 104 + q * 7.0, -6 + q * 2.0)
					n.add_child(puff)
		"kalancha":
			# пожарное депо из красного кирпича с высокой каланчой; наверху — пожарный с биноклем
			var brick := mat("brick", Color(0.55, 0.2, 0.14))
			box(n, Vector3(0, 4.5, 0), Vector3(20, 9, 11), brick)
			gable(n, Vector3(0, 10.4, 0), Vector3(11.6, 2.8, 20.6), mat("r_iron", Color(0.3, 0.32, 0.3), 0.5), PI / 2)
			for q in 4:
				box(n, Vector3(-6.6 + q * 4.4, 2.2, 5.52), Vector3(3.0, 4.2, 0.1), mat("gate", Color(0.75, 0.12, 0.1)))
				box(n, Vector3(-6.6 + q * 4.4, 4.5, 5.54), Vector3(3.4, 0.25, 0.1), white)
			box(n, Vector3(0, 13, -2), Vector3(4.4, 26, 4.4), brick)
			box(n, Vector3(0, 26.3, -2), Vector3(5.6, 0.4, 5.6), white)
			for q in 8:
				cyl(n, Vector3(cos(q * TAU / 8.0) * 2.6, 27.1, -2 + sin(q * TAU / 8.0) * 2.6), 0.07, 0.07, 1.4, mat("rail", Color(0.2, 0.2, 0.22)))
			cyl(n, Vector3(0, 28.6, -2), 0.0, 2.6, 2.6, mat("r_iron", Color(0.3, 0.32, 0.3), 0.5), 8)
			box(n, Vector3(1.2, 27.5, -0.6), Vector3(0.5, 1.5, 0.4), mat("fireman", Color(0.12, 0.12, 0.14)))
			box(n, Vector3(1.2, 28.5, -0.6), Vector3(0.4, 0.4, 0.4), mat("helmet", Color(0.9, 0.75, 0.2), 0.4))
		"bridge":
			# мост через Томь: длинное полотно на быках, под ним — река
			box(n, Vector3(0, -0.5, 0), Vector3(600, 0.4, 150), mat("river", Color(0.2, 0.3, 0.42), 0.15))
			box(n, Vector3(0, 12, 0), Vector3(360, 1.6, 12), mat("deck", Color(0.5, 0.5, 0.52)))
			for q in 9:
				box(n, Vector3(-160 + q * 40, 5.6, 0), Vector3(5, 11.2, 9), mat("pier", Color(0.42, 0.42, 0.44)))
				box(n, Vector3(-160 + q * 40, 10.2, 0), Vector3(30, 2.0, 10.5), mat("deck", Color(0.5, 0.5, 0.52)), Vector3(0, 0, 0))
			for q in 18:
				cyl(n, Vector3(-170 + q * 20, 15.4, 5.6), 0.12, 0.12, 5.0, mat("rail", Color(0.2, 0.2, 0.22)))
				box(n, Vector3(-170 + q * 20, 18.0, 5.6), Vector3(0.5, 0.3, 0.5), mat("glass_on", Color(1.0, 0.8, 0.45), 0.4, 1.3))
		"chekhov":
			# памятник на набережной: длинное пальто, босые ноги, шляпа, очки, зонт
			var bronze := mat("bronze", Color(0.35, 0.28, 0.18), 0.45)
			cyl(n, Vector3(0, 0.15, 0), 0.9, 1.0, 0.3, mat("pier", Color(0.42, 0.42, 0.44)), 10)
			cyl(n, Vector3(0, 1.35, 0), 0.26, 0.5, 2.1, bronze, 8)
			box(n, Vector3(0, 2.7, 0), Vector3(0.44, 0.52, 0.42), bronze)
			cyl(n, Vector3(0, 3.04, 0), 0.34, 0.5, 0.1, bronze, 10)
			cyl(n, Vector3(0, 3.22, 0), 0.24, 0.27, 0.3, bronze, 10)
			for sx in [-1.0, 1.0]:
				box(n, Vector3(sx * 0.18, 0.36, 0.3), Vector3(0.18, 0.12, 0.42), bronze)       # босые ступни
				cyl(n, Vector3(sx * 0.12, 2.75, 0.22), 0.09, 0.09, 0.03, mat("spire", Color(0.75, 0.7, 0.5), 0.4), 8, Vector3(PI / 2, 0, 0))
			cyl(n, Vector3(0.55, 1.5, 0.1), 0.03, 0.03, 2.2, bronze, 6, Vector3(0, 0, 0.12))     # зонт-трость
		"ruble":
			# деревянный рубль: огромная монета из бруса на подставке
			var wood2 := mat("w_pine", Color(0.78, 0.6, 0.36))
			cyl(n, Vector3(0, 1.7, 0), 1.5, 1.5, 0.3, wood2, 24, Vector3(PI / 2, 0, 0))
			cyl(n, Vector3(0, 1.7, 0.16), 1.25, 1.25, 0.04, mat("w_pine2", Color(0.66, 0.48, 0.26)), 24, Vector3(PI / 2, 0, 0))
			box(n, Vector3(0, 1.7, 0.2), Vector3(0.2, 1.2, 0.04), wood2)
			box(n, Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 0.8), mat("pier", Color(0.42, 0.42, 0.44)))
		"paz":
			# ПАЗик: маленький пузатый автобус, бело-зелёный, с табличкой маршрута
			var body := mat("paz_w", Color(0.9, 0.9, 0.86))
			box(n, Vector3(0, 1.45, 0), Vector3(2.4, 2.1, 6.6), body)
			box(n, Vector3(0, 0.75, 0), Vector3(2.44, 0.7, 6.64), mat("paz_g", Color(0.2, 0.5, 0.32)))
			box(n, Vector3(0, 2.6, 0), Vector3(2.2, 0.3, 6.2), body)
			for q in 4:
				for sx in [-1.0, 1.0]:
					box(n, Vector3(sx * 1.22, 1.8, -2.2 + q * 1.45), Vector3(0.05, 0.75, 1.1), mat("glass_off", Color(0.1, 0.13, 0.18), 0.3))
			box(n, Vector3(0, 1.85, 3.32), Vector3(2.0, 0.9, 0.05), mat("glass_off", Color(0.1, 0.13, 0.18), 0.3))
			for sx in [-1.0, 1.0]:
				for sz in [-2.1, 2.1]:
					cyl(n, Vector3(sx * 1.15, 0.45, sz), 0.45, 0.45, 0.3, mat("tyre", Color(0.06, 0.06, 0.07)), 12, Vector3(0, 0, PI / 2))
				box(n, Vector3(sx * 0.8, 0.95, 3.33), Vector3(0.36, 0.22, 0.05), mat("glass_on", Color(1.0, 0.8, 0.45), 0.4, 1.3))
		"tram":
			# трамвай: красно-жёлтый вагон с дугой
			box(n, Vector3(0, 1.9, 0), Vector3(2.5, 2.6, 13), mat("tram_y", Color(0.92, 0.75, 0.2)))
			box(n, Vector3(0, 0.95, 0), Vector3(2.54, 0.9, 13.04), mat("tram_r", Color(0.75, 0.14, 0.12)))
			box(n, Vector3(0, 3.35, 0), Vector3(2.3, 0.3, 12.4), mat("tw_deck", Color(0.3, 0.3, 0.33)))
			for q in 7:
				for sx in [-1.0, 1.0]:
					box(n, Vector3(sx * 1.27, 2.3, -5.0 + q * 1.68), Vector3(0.05, 0.9, 1.3), mat("glass_on", Color(1.0, 0.8, 0.45), 0.4, 1.3) if q % 2 == 0 else mat("glass_off", Color(0.1, 0.13, 0.18), 0.3))
			box(n, Vector3(0, 4.3, -1.0), Vector3(0.06, 1.8, 0.06), mat("rail", Color(0.2, 0.2, 0.22)), Vector3(0.5, 0, 0))
			box(n, Vector3(0, 5.1, -1.5), Vector3(1.6, 0.05, 0.05), mat("rail", Color(0.2, 0.2, 0.22)))
		_:
			box(n, Vector3(0, 2, 0), Vector3(4, 4, 4), white)
