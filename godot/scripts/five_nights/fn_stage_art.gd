## Главный зал. Вся геометрия здесь декоративная, в координатах исходной оболочки 14 × 4,2 × 12 м.
extends Node3D

const WOOD := preload("res://assets/fn_curated/phase3/finishes/wood.tres")
const LIME := preload("res://assets/fn_curated/phase3/finishes/lime.tres")
const CHALK := preload("res://assets/fn_curated/phase3/finishes/chalk.tres")
const OXBLOOD := preload("res://assets/fn_curated/phase3/finishes/oxblood.tres")
const CHAIR := preload("res://assets/fn_curated/phase3/models/painted_wooden_chair_01/painted_wooden_chair_01.gltf")
const PENDANT := preload("res://assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf")
const SERVICE_DOOR := preload("res://assets/fn_curated/phase2/models/service_door.glb")
const TOOLBOX := preload("res://assets/fn_curated/models/metal_toolbox/metal_toolbox.gltf")
const SHOW_POSTER := preload("res://assets/fn_curated/oblako/show_poster.tres")
const STAGE_DRAWING := preload("res://assets/fn_curated/oblako/kids_stage.tres")
const BALON_STICKER := preload("res://assets/fn_curated/oblako/sticker_balon.tres")
const TYPE := preload("res://assets/fonts/RussoOne-Regular.ttf")

var lights: Array[Light3D] = []
var stage_wood: StandardMaterial3D
var velvet: StandardMaterial3D
var iron: StandardMaterial3D

func build() -> void:
	stage_wood = _finish(WOOD, Color("#876742"), 0.96)
	velvet = _finish(CHALK, Color("#8d343e"), 1.0)
	velvet.uv1_scale = Vector3.ONE * 3.1
	velvet.normal_scale = 0.26
	velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	iron = _finish(CHALK, Color("#454743"), 1.0)
	_shell()
	_stage()
	_auditorium()
	_lighting()

func _shell() -> void:
	var ceiling := _finish(CHALK, Color("#4c4a43"), 1.0)
	var floorboards := _finish(WOOD, Color("#6a5943"), 1.0)
	MGProps.box(self, Vector3(0, -0.05, 0), Vector3(14, 0.1, 12), floorboards)
	MGProps.box(self, Vector3(0, 4.25, 0), Vector3(14, 0.1, 12), ceiling)
	for side in [-1, 1]:
		var sign := float(side)
		MGProps.box(self, Vector3(sign * 7.0, 2.1, 0), Vector3(0.1, 4.2, 12), LIME)
		MGProps.box(self, Vector3(0, 2.1, sign * 6.0), Vector3(14, 4.2, 0.1), LIME)
		MGProps.box(self, Vector3(sign * 6.94, 0.56, 0), Vector3(0.025, 1.12, 11.88), OXBLOOD)
		MGProps.box(self, Vector3(0, 0.56, sign * 5.94), Vector3(13.88, 1.12, 0.025), OXBLOOD)
		for y in [0.09, 1.12]:
			MGProps.box(self, Vector3(sign * 6.914, y, 0), Vector3(0.053, 0.055, 11.88), WOOD)
			MGProps.box(self, Vector3(0, y, sign * 5.914), Vector3(13.88, 0.055, 0.053), WOOD)
	for z in [-3.02, 0.4, 3.72]:
		MGProps.box(self, Vector3(0, 4.09, z), Vector3(13.91, 0.22, 0.22), ceiling)

func _stage() -> void:
	MGProps.box(self, Vector3(0, 0.45, -4.4), Vector3(8, 0.9, 3), stage_wood)
	MGProps.box(self, Vector3(0, 0.61, -2.874), Vector3(8, 0.53, 0.048), OXBLOOD)
	MGProps.box(self, Vector3(0, 0.874, -2.858), Vector3(8, 0.073, 0.07), stage_wood)
	for step in 2:
		MGProps.box(self, Vector3(-2.7, (step + 1) * 0.14, -2.46 - step * 0.22),
			Vector3(1.38, (step + 1) * 0.28, 0.36), stage_wood)
	for side in [-1, 1]:
		var s := float(side)
		# Боковые порталы остаются за пределами двух точек на сцене.
		MGProps.box(self, Vector3(s * 4.27, 2.365, -3.08), Vector3(0.38, 2.94, 0.34), OXBLOOD)
		MGProps.box(self, Vector3(s * 4.07, 2.365, -2.90), Vector3(0.069, 2.94, 0.054), stage_wood)
		_curtain(Vector3(s * 3.61, 0.91, -3.22), 1.02, 2.87, s)
		MGModels.spawn("fn_stage_speaker", self, Vector3(s * 3.65, 0.90, -4.25), -s * 0.38,
			Vector3(0.62, 1.47, 0.60), func(r): MGProps.speaker(r))
	MGProps.box(self, Vector3(0, 3.904, -3.08), Vector3(8.92, 0.41, 0.40), OXBLOOD)
	MGProps.box(self, Vector3(0, 3.728, -2.87), Vector3(8.86, 0.058, 0.075), stage_wood)
	_curtain(Vector3(0, 3.49, -3.12), 8.29, 0.39, 0.0)

	# Крашеный задник с фирменным рисунком «Облака», читаемый под остаточным светом сцены.
	var backdrop := _finish(CHALK, Color("#677b79"), 0.97)
	var paint := _finish(CHALK, Color("#a8b9af"), 1.0)
	MGProps.box(self, Vector3(0, 2.37, -5.89), Vector3(6.76, 2.63, 0.065), backdrop)
	for s in [-1, 1]:
		MGProps.box(self, Vector3(float(s) * 3.34, 2.37, -5.844), Vector3(0.035, 2.61, 0.014), paint)
		MGProps.box(self, Vector3(0, 2.37 + float(s) * 1.276, -5.844), Vector3(6.70, 0.027, 0.014), paint)
	for side in [-1, 1]:
		var s := float(side)
		_cloud(self, Vector3(s * 2.37, 2.53 - s * 0.28, -5.842), 0.56, paint)
		_cloud(self, Vector3(s * 1.76, 1.38 + s * 0.08, -5.842), 0.37, paint)
	_print(self, "О Б Л А К О", Vector3(0.0, 3.28, -5.836), 170, Color("#ded2b1"))
	_print(self, "ЦЕНТР РАЗВЛЕЧЕНИЙ И ХРАНЕНИЯ ДАННЫХ", Vector3(0.0, 2.86, -5.836), 35, Color("#bcb7a3"))

	var mic := _node(Vector3(0.77, 0.90, -3.50))
	MGProps.cyl(mic, Vector3(0, 0.65, 0), 0.014, 0.014, 1.30, iron)
	MGProps.cyl(mic, Vector3(0, 0.02, 0), 0.16, 0.16, 0.03, iron)
	MGProps.caps(mic, Vector3(0.015, 1.33, 0.06), 0.026, 0.13, iron, Vector3(0.72, 0, 0))
	MGProps.tube(self, PackedVector3Array([
		Vector3(0.76, 0.94, -3.50), Vector3(1.53, 0.926, -3.63), Vector3(2.42, 0.93, -3.46),
		Vector3(3.12, 0.94, -3.76), Vector3(3.43, 0.96, -4.24),
	]), 0.012, MGProps.mat("rubber"))
	_prop(TOOLBOX, Vector3(3.45, 0.91, -5.20), -0.35)

func _auditorium() -> void:
	# Между столами остаётся диагональ от контрольной точки в зале к ступеням сцены.
	_table(Vector3(-4.83, 0, -0.60), -0.21, 0)
	_table(Vector3(-3.71, 0, 2.80), 0.52, 1)
	_table(Vector3(4.04, 0, 2.22), -0.67, 2)
	_prop(CHAIR, Vector3(-4.49, 0, -1.60), -0.24)
	_prop(CHAIR, Vector3(-4.52, 0, 0.44), 2.89)
	_prop(CHAIR, Vector3(-3.26, 0, 1.61), 0.43)
	_prop(CHAIR, Vector3(-4.23, 0, 3.69), -2.65)
	_prop(CHAIR, Vector3(4.47, 0, 1.12), -0.37)
	_prop(CHAIR, Vector3(3.66, 0, 3.40), 2.45)

	_prop(SERVICE_DOOR, Vector3(-6.87, 0, -3.35), PI / 2)
	var foyer := _node(Vector3(-6.911, 2.21, -1.21), PI / 2)
	var paper := _finish(CHALK, Color("#bcb088"), 1.0)
	MGProps.box(foyer, Vector3(0, 0, 0), Vector3(1.06, 1.30, 0.027), WOOD)
	MGProps.quad(foyer, Vector3(-0.018, 0.008, 0.018), Vector2(0.79, 1.185), SHOW_POSTER, Vector3(0, 0, 0.027))
	MGProps.quad(foyer, Vector3(0.437, -0.497, 0.020), Vector2(0.127, 0.127), BALON_STICKER, Vector3(0, 0, -0.11))
	MGProps.quad(self, Vector3(-6.941, 1.89, 0.34), Vector2(0.51, 0.3825), STAGE_DRAWING, Vector3(0, PI / 2, -0.049))

	# Кабель идёт к служебной двери, а не пересекает главный план на уровне лиц.
	for offset: float in [0.0, 0.064]:
		MGProps.tube(self, PackedVector3Array([
			Vector3(-6.88, 2.15 + offset, -3.70), Vector3(-6.88, 2.81 + offset, -3.71),
			Vector3(-6.88, 2.94 + offset, -3.58), Vector3(-6.88, 2.92 + offset, -0.24),
			Vector3(-6.88, 2.89 + offset, 2.86),
		]), 0.012, iron)
	# Остатки флажков над столами, со свободным створом перед сценой.
	var garland := PackedVector3Array()
	for i in 12:
		var x := lerpf(-6.88, -2.18, float(i) / 11.0)
		var y := 3.71 - sin(float(i) / 11.0 * PI) * 0.23
		garland.append(Vector3(x, y, 0.85))
		if i % 2 == 1 and i < 10:
			var flag := MGProps.box(self, Vector3(x, y - 0.112, 0.85), Vector3(0.17, 0.225, 0.008),
				OXBLOOD if i % 4 == 1 else paper, Vector3(0.07, 0.0, 0.29 - 0.053 * i))
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MGProps.tube(self, garland, 0.009, MGProps.mat("rubber"))

func _table(at: Vector3, yaw: float, index: int) -> void:
	MGModels.spawn("fn_party_table", self, at, yaw, Vector3(2.30, 1.57, 1.27),
		func(r): MGProps.party_table(r, index))

func _lighting() -> void:
	# Все источники направлены ниже потолка. Насыщенность задают материалы, не цветные прожекторы.
	var stage_key := Vector3(2.67, 3.56, -3.39)
	var stage_target := Vector3(-0.48, 2.03, -5.10)
	_stage_fixture(stage_key, stage_target)
	_prop(PENDANT, Vector3(-4.77, 3.96, -0.92), 0.0, 0.57)
	_spot("StageKey", stage_key, stage_target, 8.25, 41.0, 8.5, Color("#ffdbad"))
	_spot("StageWing", Vector3(-3.17, 3.53, -5.36), Vector3(-0.20, 1.80, -4.01),
		3.55, 39.0, 7.2, Color("#dfd9c1"))
	_spot("UpperBackdrop", Vector3(-0.78, 3.92, -4.51), Vector3(-0.10, 2.55, -5.91),
		1.55, 51.0, 4.1, Color("#e0c49f"))
	_spot("PosterWash", Vector3(-4.81, 3.21, -0.93), Vector3(-6.48, 1.19, -1.60),
		1.75, 42.0, 5.0, Color("#e7d4ae"))
	_spot("HouseSpill", Vector3(4.46, 3.74, 3.86), Vector3(2.0, 0.72, 1.20),
		1.10, 41.0, 5.9, Color("#c1c6b7"))

func _stage_fixture(from: Vector3, aim: Vector3) -> void:
	var direction := (aim - from).normalized()
	var bracket := _node(from - direction * 0.24)
	bracket.look_at(to_global(aim))
	MGProps.cyl(bracket, Vector3(0, 0, 0), 0.10, 0.14, 0.34, iron, Vector3(PI / 2, 0, 0))
	MGProps.cyl(bracket, Vector3(0, 0, -0.18), 0.084, 0.084, 0.024, MGProps.mat("cream"), Vector3(PI / 2, 0, 0))
	MGProps.tube(self, PackedVector3Array([
		from - direction * 0.25, from - direction * 0.18 + Vector3(0, 0.26, 0),
		Vector3(2.68, 3.98, -3.39), Vector3(3.83, 4.00, -3.03),
	]), 0.012, MGProps.mat("rubber"))

func _spot(label: String, from: Vector3, aim: Vector3, energy: float, angle: float, reach: float, tint: Color) -> void:
	var light := SpotLight3D.new()
	light.name = label
	light.position = from
	light.light_energy = energy
	light.light_color = tint
	light.light_specular = 0.04
	light.spot_range = reach
	light.spot_attenuation = 1.35
	light.spot_angle = angle
	light.spot_angle_attenuation = 1.12
	light.shadow_enabled = true
	light.set_meta("base", energy)
	light.set_meta("col", tint)
	add_child(light)
	light.look_at(to_global(aim))
	lights.append(light)

func _finish(source: StandardMaterial3D, tint: Color, roughness: float) -> StandardMaterial3D:
	var finish := source.duplicate() as StandardMaterial3D
	finish.albedo_color = tint
	finish.roughness = roughness
	finish.metallic_specular = 0.0
	return finish

func _node(at: Vector3, yaw := 0.0) -> Node3D:
	var part := Node3D.new()
	part.position = at
	part.rotation.y = yaw
	add_child(part)
	return part

func _prop(scene: PackedScene, at: Vector3, yaw: float, uniform_scale := 1.0) -> void:
	var prop := scene.instantiate() as Node3D
	prop.position = at
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * uniform_scale
	add_child(prop)

func _print(parent: Node3D, words: String, at: Vector3, pixels: int, ink: Color) -> void:
	var letters := MGProps.text(parent, words, at, pixels, ink)
	letters.font = TYPE
	letters.shaded = true

func _cloud(parent: Node3D, center: Vector3, size: float, ink: Material) -> void:
	for lobe: Vector3 in [Vector3(-0.36, 0.02, 0.31), Vector3(-0.02, 0.19, 0.43), Vector3(0.37, 0.07, 0.30)]:
		MGProps.cyl(parent, center + Vector3(lobe.x, lobe.y, 0) * size,
			lobe.z * size, lobe.z * size, 0.004, ink, Vector3(PI / 2, 0, 0), 32)

func _curtain(at: Vector3, width: float, height: float, side: float) -> void:
	var columns := 24 if side != 0.0 else 96
	const ROWS := 10
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in ROWS + 1:
		var v := float(row) / ROWS
		for col in columns + 1:
			var u := float(col) / columns
			var tie := exp(-18.0 * pow(v - 0.46, 2))
			var fold := sin(TAU * (u * (7.0 if side != 0.0 else 27.0) + v * 0.09))
			var x := (u - 0.5) * width * (1.0 - 0.24 * tie * absf(side)) + side * tie * 0.15
			var hem := (1.0 - v) * (0.023 + 0.036 * sin(u * TAU * 3.5))
			mesh.set_uv(Vector2(u, v))
			mesh.add_vertex(Vector3(x, v * height + hem, fold * (0.064 if side != 0.0 else 0.04)))
	for row in ROWS:
		for col in columns:
			var a := row * (columns + 1) + col
			for i in [a, a + columns + 1, a + 1, a + 1, a + columns + 1, a + columns + 2]:
				mesh.add_index(i)
	mesh.generate_normals()
	var fabric := MeshInstance3D.new()
	fabric.mesh = mesh.commit()
	fabric.material_override = velvet
	fabric.position = at
	add_child(fabric)
