## Модели предметов гонки. У каждого предмета — свой объёмный вид с узнаваемым силуэтом: он крутится над гонщиком,
## пока предмет в руках, показан в HUD, вылетает при использовании и лежит на дороге ловушкой.
## Если в проекте есть файл godot/assets/racing/item_<id>.glb (модель владельца из Tripo — промпты в
## godot/docs/TRIPO_PROMPTS_GAMEPLAY.md), берётся он; пока файла нет — модель собирается здесь из деталей.
## Собранные модели — не «куб с цветом»: баллон с вентилем и соплом, мешок с узлом и фитилём, раструб с витками
## шланга, флакон с пузырями, шестигранный фильтр, рупор с баллончиком, ракета из ржавой трубы, мотор с обмоткой.
## Вперёд у моделей — +Z (как у гонщика), размер 1.0 — около 0,9 м в самом длинном месте.
class_name RaceItems

static var _mats := {}

static func mat(key: String, col: Color, rough := 0.6, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	n.scale = scl
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mi(parent, c, m, pos, rot)

static func box(parent: Node3D, size: Vector3, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, m, pos, rot)

static func ball(parent: Node3D, r: float, m: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return _mi(parent, s, m, pos, Vector3.ZERO, scl)

static func ring(parent: Node3D, r: float, thick: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 18
	t.ring_segments = 8
	return _mi(parent, t, m, pos, rot)

## модель предмета; size — множитель размера
static func model(id: String, size := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "item_" + id
	var file := "res://assets/racing/item_%s.glb" % id
	if ResourceLoader.exists(file):
		var g: Node3D = (load(file) as PackedScene).instantiate()
		var bb := _aabb(g)
		var k: float = 0.9 / maxf(0.01, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
		g.scale = Vector3.ONE * k
		g.position = -bb.get_center() * k
		root.add_child(g)
		root.set_meta("glb", true)
	else:
		_build(id, root)
	root.scale = Vector3.ONE * size
	return root

## Границы модели в координатах n (без его собственного масштаба и сдвига): трансформы вложенных узлов glb
## складываются по пути вниз. Раньше бралась только своя трансформа сетки — у моделей Tripo родительские узлы
## повёрнуты и масштабированы, центр выходил мимо, и предмет крутился вокруг чужой точки (уезжал из карточки HUD).
static func _aabb(n: Node3D) -> AABB:
	var acc: Array = []
	for c in n.get_children():
		_walk(c, Transform3D.IDENTITY, acc)
	var out := AABB()
	for i in acc.size():
		out = acc[i] if i == 0 else out.merge(acc[i])
	return out

static func _walk(n: Node, xf: Transform3D, acc: Array) -> void:
	var x := xf
	if n is Node3D:
		x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(x * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_walk(c, x, acc)

static func _build(id: String, r: Node3D) -> void:
	var steel := mat("steel", Color(0.62, 0.64, 0.68), 0.35, 0.8)
	var dark := mat("dark", Color(0.1, 0.1, 0.12), 0.7, 0.2)
	var rust := mat("rust", Color(0.52, 0.27, 0.14), 0.85, 0.3)
	match id:
		"turbo_balloon":
			# красный газовый баллон: купол, жёлтый пояс, вентиль-барашек, сопло с пламенем
			var red := mat("tb_red", Color(0.86, 0.12, 0.1), 0.4, 0.3, 0.12)
			cyl(r, 0.2, 0.2, 0.5, red, Vector3(0, 0.02, 0))
			ball(r, 0.2, red, Vector3(0, 0.27, 0), Vector3(1, 0.7, 1))
			cyl(r, 0.207, 0.207, 0.07, mat("tb_band", Color(1.0, 0.82, 0.15), 0.5, 0.2, 0.25), Vector3(0, 0.1, 0))
			cyl(r, 0.05, 0.07, 0.1, steel, Vector3(0, 0.44, 0))
			box(r, Vector3(0.26, 0.03, 0.05), steel, Vector3(0, 0.5, 0))
			box(r, Vector3(0.05, 0.03, 0.26), steel, Vector3(0, 0.5, 0))
			cyl(r, 0.13, 0.06, 0.12, dark, Vector3(0, -0.29, 0))
			cyl(r, 0.11, 0.0, 0.32, mat("tb_fire", Color(1.0, 0.55, 0.1), 0.3, 0.0, 2.6, 0.9), Vector3(0, -0.5, 0))
			cyl(r, 0.06, 0.0, 0.2, mat("tb_fire2", Color(1.0, 0.95, 0.6), 0.3, 0.0, 3.2), Vector3(0, -0.44, 0))
		"dust_bomb":
			# мешок пылесборника: пузатый, с перетянутой горловиной, фитилём и заплаткой
			var sack := mat("db_sack", Color(0.55, 0.47, 0.36), 0.95)
			ball(r, 0.3, sack, Vector3(0, -0.06, 0), Vector3(1.0, 0.88, 1.0))
			ball(r, 0.2, sack, Vector3(0.08, 0.1, 0.05), Vector3(1.0, 0.8, 1.0))
			cyl(r, 0.07, 0.11, 0.12, sack, Vector3(0, 0.25, 0))
			ring(r, 0.085, 0.022, mat("db_rope", Color(0.86, 0.14, 0.12), 0.8), Vector3(0, 0.24, 0))
			cyl(r, 0.13, 0.06, 0.08, sack, Vector3(0, 0.34, 0))
			cyl(r, 0.012, 0.012, 0.22, dark, Vector3(0.05, 0.47, 0), Vector3(0, 0, -0.5))
			ball(r, 0.045, mat("db_spark", Color(1.0, 0.8, 0.25), 0.3, 0.0, 3.5), Vector3(0.11, 0.56, 0))
			box(r, Vector3(0.17, 0.15, 0.02), mat("db_patch", Color(0.32, 0.28, 0.24), 0.95), Vector3(-0.1, -0.05, 0.285), Vector3(0.1, -0.35, 0.2))
			for k in 3:
				ball(r, 0.07 + 0.02 * k, mat("db_puff", Color(0.75, 0.7, 0.62), 1.0, 0.0, 0.0, 0.55), Vector3(-0.3 + 0.07 * k, 0.05 + 0.13 * k, -0.1 + 0.1 * k))
		"super_suck":
			# раструб пылесоса: широкий зев, гофра из колец, синий корпус, рукоять
			var blue := mat("ss_blue", Color(0.2, 0.55, 0.95), 0.45, 0.2, 0.15)
			cyl(r, 0.33, 0.12, 0.3, blue, Vector3(0, 0, 0.22), Vector3(PI / 2, 0, 0))
			ring(r, 0.33, 0.03, steel, Vector3(0, 0, 0.37), Vector3(PI / 2, 0, 0))
			cyl(r, 0.27, 0.27, 0.02, mat("ss_void", Color(0.02, 0.03, 0.06), 0.9, 0.0, 0.0), Vector3(0, 0, 0.34), Vector3(PI / 2, 0, 0))
			for k in 4:
				ring(r, 0.12 - 0.006 * k, 0.03, dark, Vector3(0, 0, 0.02 - 0.085 * k), Vector3(PI / 2, 0, 0))
			cyl(r, 0.09, 0.09, 0.36, dark, Vector3(0, 0, -0.13), Vector3(PI / 2, 0, 0))
			box(r, Vector3(0.06, 0.24, 0.09), blue, Vector3(0, -0.18, -0.12), Vector3(0.35, 0, 0))
			ring(r, 0.2, 0.012, mat("ss_glow", Color(0.45, 0.8, 1.0), 0.3, 0.0, 1.1), Vector3(0, 0, 0.44), Vector3(PI / 2, 0, 0))
		"soap":
			# флакон средства для посуды: плечи, красная крышка-носик, этикетка, пузыри
			var body := mat("so_body", Color(0.35, 0.85, 0.5), 0.25, 0.0, 0.12, 0.92)
			cyl(r, 0.17, 0.2, 0.42, body, Vector3(0, -0.08, 0), Vector3.ZERO, 12)
			cyl(r, 0.08, 0.17, 0.14, body, Vector3(0, 0.2, 0), Vector3.ZERO, 12)
			cyl(r, 0.075, 0.075, 0.1, mat("so_cap", Color(0.9, 0.14, 0.12), 0.4), Vector3(0, 0.31, 0))
			cyl(r, 0.02, 0.035, 0.12, mat("so_tip", Color(0.95, 0.95, 0.95), 0.4), Vector3(0, 0.41, 0))
			box(r, Vector3(0.24, 0.2, 0.02), mat("so_label", Color(0.97, 0.95, 0.88), 0.7), Vector3(0, -0.06, 0.185))
			box(r, Vector3(0.16, 0.05, 0.022), mat("so_label_r", Color(0.9, 0.14, 0.12), 0.6), Vector3(0, -0.02, 0.19))
			var bub := mat("so_bub", Color(0.85, 0.95, 1.0), 0.05, 0.3, 0.3, 0.45)
			ball(r, 0.1, bub, Vector3(0.27, 0.3, 0.05))
			ball(r, 0.065, bub, Vector3(0.33, 0.12, -0.08))
			ball(r, 0.045, bub, Vector3(0.2, 0.46, -0.02))
			ball(r, 0.08, bub, Vector3(-0.29, 0.22, 0.02))
		"filter":
			# шестигранный фильтр-щит: зелёная рама, гофрированная вставка, четыре защёлки
			var green := mat("fi_green", Color(0.25, 0.85, 0.45), 0.4, 0.3, 0.3)
			var hex := Node3D.new()
			hex.rotation = Vector3(PI / 2, 0, 0)
			r.add_child(hex)
			cyl(hex, 0.4, 0.4, 0.12, green, Vector3.ZERO, Vector3.ZERO, 6)
			cyl(hex, 0.31, 0.31, 0.14, mat("fi_core", Color(0.92, 0.92, 0.86), 0.9), Vector3.ZERO, Vector3.ZERO, 6)
			for k in 7:
				box(hex, Vector3(0.5 - absf(k - 3) * 0.07, 0.16, 0.022), mat("fi_pleat", Color(0.7, 0.7, 0.62), 0.9), Vector3(0, 0, -0.21 + 0.07 * k))
			for k in 6:
				var a := TAU * k / 6.0 + PI / 6.0
				box(hex, Vector3(0.09, 0.16, 0.06), steel, Vector3(cos(a) * 0.37, 0, sin(a) * 0.37), Vector3(0, -a, 0))
			ring(r, 0.43, 0.014, mat("fi_glow", Color(0.4, 0.95, 0.55), 0.3, 0.0, 0.9), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		"air_blast":
			# рупор-гудок на баллончике сжатого воздуха: раструб, шейка, баллончик с кнопкой
			var white := mat("ab_white", Color(0.93, 0.95, 0.98), 0.35, 0.2)
			cyl(r, 0.3, 0.05, 0.42, mat("ab_horn", Color(0.95, 0.22, 0.18), 0.4, 0.2, 0.1), Vector3(0, 0.12, 0.17), Vector3(PI / 2, 0, 0))
			ring(r, 0.3, 0.022, white, Vector3(0, 0.12, 0.38), Vector3(PI / 2, 0, 0))
			cyl(r, 0.05, 0.05, 0.16, steel, Vector3(0, 0.12, -0.1), Vector3(PI / 2, 0, 0))
			cyl(r, 0.11, 0.11, 0.4, white, Vector3(0, -0.16, -0.17))
			ball(r, 0.11, white, Vector3(0, 0.04, -0.17), Vector3(1, 0.6, 1))
			cyl(r, 0.112, 0.112, 0.1, mat("ab_stripe", Color(0.2, 0.5, 0.95), 0.4), Vector3(0, -0.18, -0.17))
			cyl(r, 0.04, 0.04, 0.06, mat("ab_btn", Color(0.9, 0.14, 0.12), 0.4), Vector3(0, 0.2, -0.17))
			for k in 3:
				ring(r, 0.14 + 0.07 * k, 0.012, mat("ab_wave%d" % k, Color(0.7, 0.88, 1.0), 0.3, 0.0, 0.7, 0.7 - 0.18 * k), Vector3(0, 0.12, 0.46 + 0.07 * k), Vector3(PI / 2, 0, 0))
		"missile":
			# ракета из ржавой трубы: мятый нос-конус, три хомута, четыре кривых стабилизатора, сопло с огнём
			cyl(r, 0.13, 0.13, 0.56, rust, Vector3(0, 0, -0.02), Vector3(PI / 2, 0, 0), 12)
			cyl(r, 0.0, 0.13, 0.26, mat("mi_nose", Color(0.82, 0.16, 0.12), 0.5, 0.3), Vector3(0, 0, 0.39), Vector3(-PI / 2, 0, 0), 12)
			for k in 3:
				ring(r, 0.135, 0.016, steel, Vector3(0, 0, 0.18 - 0.2 * k), Vector3(PI / 2, 0, 0))
			for k in 4:
				var a := PI / 4 + PI / 2 * k
				box(r, Vector3(0.02, 0.24, 0.2), steel, Vector3(cos(a) * 0.19, sin(a) * 0.19, -0.26), Vector3(0.25, 0, a - PI / 2))
			cyl(r, 0.1, 0.07, 0.08, dark, Vector3(0, 0, -0.34), Vector3(PI / 2, 0, 0))
			cyl(r, 0.0, 0.09, 0.3, mat("mi_fire", Color(1.0, 0.5, 0.1), 0.3, 0.0, 2.8, 0.9), Vector3(0, 0, -0.52), Vector3(PI / 2, 0, 0))
			box(r, Vector3(0.1, 0.012, 0.16), mat("mi_tape", Color(0.75, 0.75, 0.7), 0.8), Vector3(0.0, 0.134, 0.02))
		"overclock":
			# мотор пылесоса: корпус с рёбрами охлаждения, медная обмотка, вал, клеммы, молния
			var body2 := mat("oc_body", Color(0.22, 0.24, 0.28), 0.45, 0.6)
			cyl(r, 0.22, 0.22, 0.34, body2, Vector3(0, 0, 0), Vector3(0, 0, PI / 2))
			for k in 5:
				cyl(r, 0.27, 0.27, 0.025, steel, Vector3(-0.14 + 0.07 * k, 0, 0), Vector3(0, 0, PI / 2), 18)
			cyl(r, 0.17, 0.17, 0.12, mat("oc_copper", Color(0.85, 0.45, 0.18), 0.35, 0.8, 0.2), Vector3(0.23, 0, 0), Vector3(0, 0, PI / 2))
			cyl(r, 0.045, 0.045, 0.24, steel, Vector3(0.36, 0, 0), Vector3(0, 0, PI / 2))
			cyl(r, 0.1, 0.1, 0.05, dark, Vector3(0.46, 0, 0), Vector3(0, 0, PI / 2), 8)
			box(r, Vector3(0.18, 0.1, 0.16), body2, Vector3(-0.02, 0.26, 0))
			cyl(r, 0.022, 0.022, 0.1, mat("oc_term_r", Color(0.9, 0.15, 0.12), 0.4), Vector3(-0.07, 0.35, 0))
			cyl(r, 0.022, 0.022, 0.1, mat("oc_term_b", Color(0.2, 0.5, 0.95), 0.4), Vector3(0.03, 0.35, 0))
			var bolt := mat("oc_bolt", Color(0.3, 0.85, 1.0), 0.3, 0.0, 1.6)
			box(r, Vector3(0.05, 0.2, 0.03), bolt, Vector3(-0.3, 0.12, 0.0), Vector3(0, 0, 0.5))
			box(r, Vector3(0.05, 0.2, 0.03), bolt, Vector3(-0.33, -0.02, 0.0), Vector3(0, 0, -0.6))
			box(r, Vector3(0.05, 0.2, 0.03), bolt, Vector3(-0.3, -0.16, 0.0), Vector3(0, 0, 0.5))
		_:
			cyl(r, 0.25, 0.25, 0.5, rust)

## лужа на дороге (мыло): пятно с бликом, пузыри и опрокинутый флакон
static func puddle(rad: float) -> Node3D:
	var n := Node3D.new()
	var slick := mat("pd_slick", Color(0.8, 0.95, 1.0), 0.03, 0.4, 0.15, 0.72)
	cyl(n, rad, rad, 0.03, slick, Vector3(0, 0.03, 0), Vector3.ZERO, 22)
	cyl(n, rad * 0.62, rad * 0.62, 0.035, mat("pd_slick2", Color(0.95, 1.0, 1.0), 0.02, 0.5, 0.3, 0.55), Vector3(rad * 0.18, 0.035, -rad * 0.1), Vector3.ZERO, 16)
	var bub := mat("so_bub", Color(0.85, 0.95, 1.0), 0.05, 0.3, 0.3, 0.45)
	for k in 7:
		var a := TAU * k / 7.0 + 0.4
		ball(n, 0.1 + 0.05 * (k % 3), bub, Vector3(cos(a) * rad * 0.6, 0.1, sin(a) * rad * 0.6))
	var b := model("soap", 0.9)
	b.position = Vector3(-rad * 0.3, 0.2, rad * 0.25)
	b.rotation = Vector3(0, 0.7, PI / 2 + 0.1)
	n.add_child(b)
	return n
