## Основа 3D-подработки «Микрозаймов»: поверх обычной MLJob (таймер, заголовок, итог, бот для проверок) —
## свой 3D-мир в SubViewport на весь экран (своя физика, свет, туман, камера), компактный HUD (задача, прогресс,
## оценка, подсказка) и экран результата: звёзды, разбор начисления, оплата. Наследники строят уровень в world_root,
## ведут камеру cam и зовут show_result(score, строки разбора, extra) вместо finish().
class_name MLJob3D
extends MLJob

var vpc: SubViewportContainer
var vp: SubViewport
var world_root: Node3D
var cam: Camera3D
var env: Environment
var task_l: Label
var prog_bg: ColorRect
var prog_fg: ColorRect
var score_l: Label
var tip_l: Label
var combo_l: Label
var result_box: Control
var level_name := ""

## общий 3D-каркас: вызвать в setup наследника после base_setup
func setup_3d(bg := Color(0.02, 0.02, 0.03), ambient := Color(0.5, 0.5, 0.55), amb_e := 0.4) -> void:
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.size = size
	vpc.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vpc)
	move_child(vpc, 1)                         # под HUD (заголовок, таймер), над фоном
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(1600, 900)
	vp.physics_object_picking = true
	vpc.add_child(vp)
	world_root = Node3D.new()
	vp.add_child(world_root)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = amb_e
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	world_root.add_child(we)
	cam = Camera3D.new()
	cam.fov = 55.0
	world_root.add_child(cam)
	cam.current = true
	# HUD: задача и прогресс слева сверху, оценка справа, подсказка снизу
	var plate := Panel.new()
	plate.position = Vector2(60, 160)
	plate.size = Vector2(520, 96)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.85)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 5
	sb.border_color = RED
	plate.add_theme_stylebox_override("panel", sb)
	add_child(plate)
	task_l = txt(plate, "", 18, WHITE, Vector2(16, 10))
	task_l.size = Vector2(490, 40)
	task_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prog_bg = ColorRect.new()
	prog_bg.color = Color(0.18, 0.18, 0.2)
	prog_bg.position = Vector2(16, 66)
	prog_bg.size = Vector2(488, 12)
	prog_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(prog_bg)
	prog_fg = ColorRect.new()
	prog_fg.color = GREEN
	prog_fg.position = prog_bg.position
	prog_fg.size = Vector2(0, 12)
	prog_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(prog_fg)
	score_l = txt(self, "", 30, WHITE, Vector2(1200, 165), serif)
	score_l.size = Vector2(340, 40)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_l = txt(self, "", 26, Color(1.0, 0.8, 0.3), Vector2(1200, 208), serif)
	combo_l.size = Vector2(340, 36)
	combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip_l = txt(self, "", 18, Color(0.85, 0.86, 0.88), Vector2(0, 836))
	tip_l.size = Vector2(1600, 30)
	tip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_l.position.y = 700
	if bot >= 0.0:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

## модель из файла, вписанная по длинной стороне в size (м), основанием на пол, центр — в начале координат
func fit_model(path: String, parent: Node, size: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var ps := load(path) as PackedScene
	if ps == null:
		return holder
	var m := ps.instantiate() as Node3D
	var acc: Array = []
	MGModels._walk(m, Transform3D.IDENTITY, acc)
	var bb := AABB()
	for i in acc.size():
		bb = acc[i] if i == 0 else bb.merge(acc[i])
	var s := size / maxf(0.001, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	holder.add_child(m)
	m.scale = Vector3.ONE * s
	var c := bb.get_center()
	m.position = Vector3(-c.x, -bb.position.y, -c.z) * s
	return holder

func light(p: Vector3, e: float, r: float, c := Color(1, 0.9, 0.75), shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_energy = e
	l.omni_range = r
	l.light_color = c
	l.shadow_enabled = shadow
	world_root.add_child(l)
	return l

func sun(rot: Vector3, e: float, c := Color(1, 0.95, 0.85)) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation = rot
	l.light_energy = e
	l.light_color = c
	l.shadow_enabled = true
	world_root.add_child(l)
	return l

func at(p: Vector3, yaw := 0.0, parent: Node = null) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	(parent if parent != null else world_root).add_child(n)
	return n

func progress(k: float) -> void:
	prog_fg.size.x = prog_bg.size.x * clampf(k, 0.0, 1.0)

## всплывающая надпись над точкой мира («+120», «КОМБО ×3», «ЗАЦЕПИЛ!»)
func pop(text: String, world_p: Vector3, col := Color(1, 1, 1)) -> void:
	if cam == null or not cam.is_inside_tree() or cam.is_position_behind(world_p):
		return
	var sp := cam.unproject_position(world_p)
	var l := txt(self, text, 26, col, sp - Vector2(80, 20), serif)
	l.size = Vector2(160, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

## клуб пыли: несколько шариков разлетаются и тают
func puff(p: Vector3, col := Color(0.75, 0.72, 0.66), n := 6, k := 1.0) -> void:
	for i in n:
		var b := MGProps.ball(world_root, p, 0.04 * k, _puff_mat(col))
		var to := p + Vector3(randf_range(-0.25, 0.25), randf_range(0.05, 0.3), randf_range(-0.25, 0.25)) * k
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "position", to, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector3.ONE * 2.2, 0.5)
		tw.chain().tween_callback(b.queue_free)

var _pm := {}
func _puff_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _pm.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pm[key] = m
	return _pm[key]

## итог: звёзды, разбор («убрано 92 % · +18 % комбо · −2 зацепа»), оплата считается в экономике по score
func show_result(score: float, lines: Array, extra: Array = []) -> void:
	if done:
		return
	score = clampf(score, 0.0, 1.0)
	result_box = Panel.new()
	result_box.position = Vector2(520, 300)
	result_box.size = Vector2(560, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.9, 0.85)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 8
	sb.border_color = GREEN if score > 0.5 else RED
	result_box.add_theme_stylebox_override("panel", sb)
	add_child(result_box)
	var stars := 1 + int(score > 0.45) + int(score > 0.7) + int(score > 0.9)
	var st := txt(result_box, "★".repeat(stars) + "☆".repeat(4 - stars), 44, Color(0.85, 0.55, 0.05), Vector2(24, 14), serif)
	st.add_theme_constant_override("outline_size", 0)
	var hd := txt(result_box, "ОТЛИЧНО!" if score > 0.85 else ("НОРМАЛЬНО" if score > 0.5 else "ТАК СЕБЕ"), 32, Color(0.05, 0.05, 0.06), Vector2(24, 70), serif)
	hd.add_theme_constant_override("outline_size", 0)
	var body := txt(result_box, "\n".join(lines.map(func(x): return String(x))), 17, Color(0.18, 0.18, 0.2), Vector2(26, 118))
	body.size = Vector2(510, 170)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("outline_size", 0)
	result_box.scale = Vector2(0.7, 0.7)
	result_box.pivot_offset = result_box.size * 0.5
	result_box.create_tween().tween_property(result_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sfx("clean" if score > 0.5 else "fail")
	done = true
	var tw := create_tween()
	tw.tween_interval(2.4 if bot < 0.0 else 0.05)
	tw.tween_callback(func(): finished.emit(score, extra))

## ввод направления (WASD и стрелки)
func axis() -> Vector2:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	return v.limit_length(1.0)

## пол и стены коробки комнаты (w × d, высота h) из общей библиотеки
func room_box(c: Vector3, w: float, d: float, h: float, wall: Material, floor_m: Material, open_front := true) -> void:
	MGProps.box(world_root, c + Vector3(0, -0.05, 0), Vector3(w, 0.1, d), floor_m)
	MGProps.box(world_root, c + Vector3(0, h / 2, -d / 2), Vector3(w, h, 0.1), wall)
	MGProps.box(world_root, c + Vector3(-w / 2, h / 2, 0), Vector3(0.1, h, d), wall)
	MGProps.box(world_root, c + Vector3(w / 2, h / 2, 0), Vector3(0.1, h, d), wall)
	if not open_front:
		MGProps.box(world_root, c + Vector3(0, h / 2, d / 2), Vector3(w, h, 0.1), wall)
