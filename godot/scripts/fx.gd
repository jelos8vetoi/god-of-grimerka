## Эффекты боя: вспышки попаданий, искры, пыль, ударные кольца, трещины и гарь на земле, обломки, вспышки света.
## Текстуры — Kenney Particle Pack (CC0), лежат в assets/fx. Частицы берутся из заранее созданных наборов по кругу,
## поэтому удар ничего не создаёт на лету, кроме пары плоских спрайтов.
extends Node3D

const DIR := "res://assets/fx/"
const DUST := Color(0.78, 0.74, 0.7, 0.5)

var game
var tex := {}
var spark_pool: Array = []
var spark_i := 0
var dust_pool: Array = []
var dust_i := 0
var chunk_pool: Array = []
var chunk_i := 0
var lights: Array = []
var light_i := 0
var decals: Array = []

func _ready() -> void:
	for n in ["star_08", "star_04", "flare_01", "magic_05", "magic_03", "circle_02", "circle_05", "scorch_01", "scorch_02", "spark_05", "spark_06", "smoke_04", "smoke_07", "trace_01", "light_01", "twirl_02", "dirt_02"]:
		tex[n] = load(DIR + n + ".png")
	for i in 10:
		spark_pool.append(_make_sparks())
	for i in 8:
		dust_pool.append(_make_dust(tex["smoke_04"] if i % 2 == 0 else tex["smoke_07"]))
	for i in 3:
		chunk_pool.append(_make_chunks())
	for i in 3:
		var l := OmniLight3D.new()
		l.omni_range = 6.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)

# ---------- наборы частиц ----------
func _fade_curve(grow: bool) -> CurveTexture:
	var c := Curve.new()
	if grow:
		c.add_point(Vector2(0, 0.35))
		c.add_point(Vector2(0.3, 0.85))
		c.add_point(Vector2(1, 1.0))
	else:
		c.add_point(Vector2(0, 1.0))
		c.add_point(Vector2(0.6, 0.7))
		c.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = c
	return ct

func _alpha_ramp(a0: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, a0))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt

func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 42.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -22.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.scale_curve = _fade_curve(false)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex["trace_01"]
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

func _make_dust(t: Texture2D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 8, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.flatness = 0.85
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, 0.7, 0)
	pm.damping_min = 4.0
	pm.damping_max = 7.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -40.0
	pm.angular_velocity_max = 40.0
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	pm.scale_curve = _fade_curve(true)
	pm.color_ramp = _alpha_ramp(1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = t
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

func _make_chunks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.95
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 48.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 8.5
	pm.gravity = Vector3(0, -20.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.scale_curve = _fade_curve(false)
	p.process_material = pm
	var b := BoxMesh.new()
	b.size = Vector3(0.11, 0.08, 0.13)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.19, 0.2)
	m.roughness = 0.9
	b.material = m
	p.draw_pass_1 = b
	add_child(p)
	return p

# ---------- кирпичики ----------
func sparks(pos: Vector3, dir: Vector3, count: int, col: Color, speed := 1.0, spread := 42.0) -> void:
	var p: GPUParticles3D = spark_pool[spark_i]
	spark_i = (spark_i + 1) % spark_pool.size()
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = 5.0 * speed
	pm.initial_velocity_max = 15.0 * speed
	pm.color = col
	p.amount_ratio = clampf(count / 40.0, 0.05, 1.0)
	p.global_position = pos
	p.restart()
	p.emitting = true

func dust(pos: Vector3, count := 12, col := DUST, power := 1.0, flat := 0.85) -> void:
	var p: GPUParticles3D = dust_pool[dust_i]
	dust_i = (dust_i + 1) % dust_pool.size()
	var pm := p.process_material as ParticleProcessMaterial
	pm.flatness = flat
	pm.initial_velocity_min = 1.5 * power
	pm.initial_velocity_max = 4.5 * power
	pm.color = col
	p.amount_ratio = clampf(count / 18.0, 0.1, 1.0)
	p.global_position = pos
	p.restart()
	p.emitting = true

func chunks(pos: Vector3, count := 16) -> void:
	var p: GPUParticles3D = chunk_pool[chunk_i]
	chunk_i = (chunk_i + 1) % chunk_pool.size()
	p.amount_ratio = clampf(count / 22.0, 0.1, 1.0)
	p.global_position = pos
	p.restart()
	p.emitting = true

func light(pos: Vector3, col: Color, energy := 6.0, sec := 0.22, rng := 6.0) -> void:
	var l: OmniLight3D = lights[light_i]
	light_i = (light_i + 1) % lights.size()
	l.global_position = pos
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, sec).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _mat(t: Texture2D, col: Color, add: bool, billboard: bool, on_top := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = t
	m.albedo_color = col
	m.no_depth_test = on_top
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m

static var _quad: QuadMesh

func _sprite(t: String, pos: Vector3, col: Color, add := true, billboard := true, on_top := false) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = _mat(tex[t], col, add, billboard, on_top)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	return mi

## вспышка-звезда в точке удара: мгновенно раздувается и гаснет
func flash(pos: Vector3, size: float, col: Color, t := "star_08", sec := 0.16) -> void:
	var mi := _sprite(t, pos, col, true, true, true)
	mi.scale = Vector3.ONE * size * 0.35
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, sec * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.6, sec * 0.7)
	tw.parallel().tween_property(mi.material_override, "albedo_color:a", 0.0, sec * 0.7)
	tw.tween_callback(mi.queue_free)

## кольцо ударной волны лицом к камере
func ring(pos: Vector3, size: float, col: Color, sec := 0.22, t := "circle_02") -> void:
	var mi := _sprite(t, pos, col, true, true)
	mi.scale = Vector3.ONE * size * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, sec).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, sec).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

## кольцо по земле; from > to — стягивается к центру (заряд)
func ground_ring(pos: Vector3, from: float, to: float, col: Color, sec := 0.45, t := "circle_02") -> void:
	var mi := _sprite(t, Vector3(pos.x, pos.y + 0.07, pos.z), col, true, false)
	mi.rotation.x = -PI / 2
	mi.scale = Vector3.ONE * from
	if from > to:
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.0
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * to, sec).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT if to > from else Tween.EASE_IN)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0 if to > from else col.a, sec)
	tw.chain().tween_callback(mi.queue_free)

## след на земле: гарь, трещины лучами, сначала раскалённые
func scorch(pos: Vector3, size: float, hot := Color(1.0, 0.5, 0.15)) -> void:
	var y := pos.y + 0.035 + 0.004 * (decals.size() % 5)
	var d := _sprite("scorch_01" if randf() < 0.5 else "scorch_02", Vector3(pos.x, y, pos.z), Color(0.02, 0.02, 0.03, 0.85), false, false)
	d.rotation = Vector3(-PI / 2, randf() * TAU, 0)
	d.scale = Vector3.ONE * size
	var cracks := []
	var n := 5
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + i * TAU / n + randf_range(-0.25, 0.25)
		var ln := size * randf_range(0.55, 0.9)
		var c := _sprite("spark_05" if i % 2 == 0 else "spark_06", Vector3(pos.x + sin(a) * ln * 0.5, y + 0.004, pos.z + cos(a) * ln * 0.5), Color(0.01, 0.01, 0.02, 0.9), false, false)
		c.rotation = Vector3(-PI / 2, a, 0)
		c.scale = Vector3(ln * 0.45, ln, 1.0)
		cracks.append(c)
	var glow := _sprite("scorch_01", Vector3(pos.x, y + 0.01, pos.z), hot, true, false)
	glow.rotation = Vector3(-PI / 2, d.rotation.y, 0)
	glow.scale = Vector3.ONE * size * 1.1
	var gt := glow.create_tween()
	gt.tween_property(glow.material_override, "albedo_color:a", 0.0, 0.7)
	gt.tween_callback(glow.queue_free)
	var all := [d] + cracks
	decals.append(all)
	var tw := d.create_tween()
	tw.tween_interval(4.5)
	tw.tween_method(func(v: float):
		for m in all:
			if is_instance_valid(m):
				((m as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = v, 0.85, 0.0, 1.2)
	tw.tween_callback(func():
		decals.erase(all)
		for m in all:
			if is_instance_valid(m):
				m.queue_free())
	if decals.size() > 8:
		for m in decals.pop_front():
			if is_instance_valid(m):
				m.queue_free()

# ---------- готовые наборы ----------
## Попадание по врагу. tier: 0 — лёгкий, 1 — тяжёлый, 2 — добивание / полный заряд.
func hit(pos: Vector3, dir: Vector3, tier: int, col := Color(1.0, 0.82, 0.45)) -> void:
	var up := (dir + Vector3(0, 0.45, 0)).normalized()
	match tier:
		0:
			flash(pos, 1.1, col, "star_04" if randf() < 0.5 else "star_08", 0.13)
			sparks(pos, up, 12, col, 0.8)
			ring(pos, 1.3, Color(col.r, col.g, col.b, 0.7), 0.16)
		1:
			flash(pos, 1.7, Color.WHITE, "star_08", 0.18)
			flash(pos, 1.5, col, "magic_05", 0.22)
			sparks(pos, up, 28, col, 1.15, 50.0)
			ring(pos, 2.6, col, 0.22)
			dust(pos, 7, Color(1, 0.95, 0.85, 0.35), 0.8, 0.0)
			light(pos, col, 2.6, 0.2)
		_:
			flash(pos, 2.6, Color.WHITE, "star_08", 0.2)
			flash(pos, 2.0, col, "magic_05", 0.28)
			sparks(pos, up, 40, col, 1.5, 60.0)
			sparks(pos, -dir + Vector3(0, 0.6, 0), 14, Color.WHITE, 0.9, 70.0)
			ring(pos, 3.6, col, 0.26)
			dust(pos, 10, Color(1, 0.95, 0.85, 0.35), 1.3, 0.0)
			light(pos, col, 4.5, 0.3, 9.0)

## Удар в землю: гарь и трещины, кольцо, пыль, обломки, вспышка.
func slam(pos: Vector3, size := 1.0, col := Color(1.0, 0.7, 0.3)) -> void:
	var g := Vector3(pos.x, 0.0, pos.z)
	scorch(g, 2.2 * size, col)
	ground_ring(g, 0.6, 5.5 * size, col, 0.4)
	ground_ring(g, 0.4, 3.2 * size, Color.WHITE, 0.25, "circle_05")
	dust(g + Vector3(0, 0.2, 0), 18, DUST, 1.5 * size)
	chunks(g + Vector3(0, 0.1, 0), int(16 * size))
	sparks(g + Vector3(0, 0.15, 0), Vector3.UP, 26, col, 1.1, 75.0)
	flash(g + Vector3(0, 0.4, 0), 2.0 * size, Color(col.r, col.g, col.b, 0.7), "magic_05", 0.2)
	light(g + Vector3(0, 0.8, 0), col, 3.2, 0.3, 8.0)

## Тело упало на землю
func land(pos: Vector3, power := 1.0) -> void:
	dust(Vector3(pos.x, 0.15, pos.z), int(10 * power), DUST, 0.9 * power)
	ground_ring(Vector3(pos.x, 0.0, pos.z), 0.4, 2.2 * power, Color(1, 1, 1, 0.35), 0.3, "circle_05")

## Балон чиркнул по земле
func scrape(pos: Vector3, dir: Vector3) -> void:
	sparks(Vector3(pos.x, 0.08, pos.z), (dir + Vector3(0, 0.7, 0)).normalized(), 14, Color(1.0, 0.75, 0.35), 0.7, 35.0)
	dust(Vector3(pos.x, 0.1, pos.z), 5, DUST, 0.6)

## Первый показ: прогоняем все виды частиц у ног героя, чтобы в бою ничего не подгружалось
func prewarm(pos: Vector3) -> void:
	sparks(pos + Vector3(0, 0.3, 0), Vector3.UP, 6, Color(1, 0.8, 0.4, 0.4))
	dust(pos + Vector3(0, 0.15, 0), 8, DUST, 0.8)
	chunks(pos + Vector3(0, -0.6, 0), 3)
	flash(pos + Vector3(0, 0.3, 0), 0.5, Color(1, 0.8, 0.4, 0.3), "star_04", 0.2)
	ground_ring(pos, 0.5, 3.0, Color(1, 0.85, 0.5, 0.6), 0.5)
