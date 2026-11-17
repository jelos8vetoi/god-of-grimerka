## Боевой HUD (левый нижний угол) по утверждённому концепту: два портрета героев внахлёст (активный — цветной
## и крупный, второй — меньше и чёрно-белый), рваная бумага, имя, HP и СВЭГ, три карточки стилей с настоящими
## 3D-моделями оружия и три ромба способностей с перезарядкой.
## Всё читает из игры: game.player (герой, стиль, здоровье, СВЭГ, запасы), game.buddy (ад-либ). Своей логики боя нет.
## Стол 1600×900 прижат к левому нижнему углу и уменьшен (SCALE): HUD занимает около трети ширины экрана.
## Текст остаётся чётким: размер шрифта задаётся в настоящих пикселях экрана, а надпись растягивается обратно (_fit). Модели рисуются в маленьких SubViewport
## со своим миром: вращается и обновляется только выбранная карточка, остальные — застывший кадр.
class_name CombatHud
extends Control

const STAGE := Vector2(1600, 900)
const SCALE := 0.55           # доля от «полного» размера концепта
const WHITE := Color(0.93, 0.92, 0.89)
const INK := Color(0.05, 0.05, 0.06)
const GREY := Color(0.55, 0.55, 0.56)
const RED := Color(0.52, 0.06, 0.06)
const NAMES := {"pahan": "ПАХАН", "madk1d": "MADK1D"}
const SHORT := {"vozduh": "БАЛОН", "bottles": "ВОДЯРА", "tyaga812": "ТЯГА-812", "skateboard": "СКЕЙТ", "guitar": "ГИТАРА", "breaker": "BREAKER"}
const ICONS := {"adlib": "symbol_02", "heat": "flame_05", "rage": "fire_01", "bottle": "spark_05", "ride": "twirl_02", "dist": "trace_05", "trick": "star_06", "chord": "magic_03", "freeze": "star_08"}

## подложка: чернота из угла, диагональные царапины и зерно
const BACK := """
shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float a = smoothstep(1.05, 0.2, uv.x) * smoothstep(-0.05, 0.75, uv.y);
	a = clamp(a * 1.15, 0.0, 0.9);
	float d = uv.x * 2.2 + uv.y * 1.3;
	float line = step(0.93, fract(d * 7.0 + h(vec2(floor(d * 7.0), 1.0)) * 0.3)) * step(0.35, h(vec2(floor(d * 7.0), 7.0)));
	float torn = step(0.45, h(floor(vec2(uv.x * 220.0, d * 60.0))));
	vec3 col = vec3(0.0) + vec3(0.9) * line * torn * smoothstep(0.75, 0.0, uv.x) * 0.5;
	col += (h(uv * 700.0 + floor(TIME * 20.0)) - 0.5) * 0.05;
	COLOR = vec4(col, max(a, line * torn * 0.35 * smoothstep(0.8, 0.0, uv.x) * smoothstep(0.0, 0.5, uv.y)));
}
"""
## портреты и модели: mono — доля чёрно-белого с полутоном, dim — яркость
const PIC := """
shader_type canvas_item;
uniform float mono = 0.0;
uniform float dim = 1.0;
uniform float tone = 0.18;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	l = smoothstep(0.03, 0.8, l);
	float q = mix(l, floor(l * 5.0 + 0.5) / 5.0, 0.5);
	vec2 g = mat2(vec2(0.707, 0.707), vec2(-0.707, 0.707)) * (FRAGCOORD.xy / 3.5);
	float ht = step(length(fract(g) - 0.5), (1.0 - q) * 0.5) * step(q, 0.6) * step(0.1, q);
	q -= ht * tone;
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	float mn = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = c.a * (1.0 - mn);
	vec3 col = mix(c.rgb, vec3(q), mono);
	col = mix(col, vec3(1.0), rim * 0.8) * dim;
	COLOR = vec4(col, c.a);
}
"""

var game
var stage: Control
var serif: SystemFont
var tech: SystemFont
var worn: ShaderMaterial
var portraits := {}            # герой → {root, pic, red, vp, k}
var name_l: Label
var hp_fill: ColorRect
var hp_text: Label
var sw_fill: ColorRect
var sw_text: Label
var sw_name: Label
var style_head: Label
var cards: Array = []          # [{root, frame, pic, name, tag}]
var previews := {}             # id стиля → {vp, holder, warm}
var slots: Array = []          # [{icon, key, name, time, pips, fill}]
var shown_hero := ""
var shown_style := ""
var tab_tag: Control
var hype_fill: ColorRect       # Team Hype — общая шкала под карточками стилей
var hype_text: Label
var mate_fill: ColorRect       # здоровье напарника — тонкая полоса под его портретом
var mate_grey: ColorRect
const BAR_W := 330.0

func setup(g) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	worn = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	worn.set_shader_parameter("amount", 0.16)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_back()
	_build_portraits()
	_build_bars()
	_build_cards()
	_build_slots()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport_rect().size
	# в узком окне HUD ужимается по ширине, но не занимает больше 70 % ширины экрана
	var k: float = min(vs.y / STAGE.y * SCALE, vs.x * 0.5 / 1010.0)
	stage.scale = Vector2.ONE * k
	stage.position = Vector2(0, vs.y - STAGE.y * k)
	# чёткий текст: буквы рисуются сразу в размере экрана, без растягивания картинки
	for n in stage.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.has_meta("box"):
			l.set_meta("box", l.size)
		l.add_theme_font_size_override("font_size", maxi(7, int(round(float(l.get_meta("fs")) * k))))
		l.scale = Vector2.ONE / k
		l.size = (l.get_meta("box") as Vector2) * k

func _text(parent: Node, s: String, size: int, col: Color, pos: Vector2, f: Font = null, rough := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else tech)
	l.add_theme_font_size_override("font_size", size)
	l.set_meta("fs", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 0 if col == INK else 3)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## рваный лист бумаги w×h
func _paper(w: float, h: float, seed_v: int, col: Color) -> Polygon2D:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, r.randf_range(-5.0, 5.0)))
		x += r.randf_range(7.0, 20.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + r.randf_range(-6.0, 7.0), y))
		y += r.randf_range(7.0, 18.0)
	x = w
	while x > 0.0:
		pts.append(Vector2(x, h + r.randf_range(-5.0, 6.0)))
		x -= r.randf_range(7.0, 20.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(r.randf_range(-7.0, 6.0), y))
		y -= r.randf_range(7.0, 18.0)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	return p

func _diamond(r: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	p.color = col
	return p

func _outline(pts: PackedVector2Array, w: float, col: Color) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.closed = true
	l.width = w
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_SHARP
	return l

func _pic_mat(mono: float, dim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PIC
	m.shader = sh
	m.set_shader_parameter("mono", mono)
	m.set_shader_parameter("dim", dim)
	return m

func _world(vp: SubViewport) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.7, 0.0)
	key.light_energy = 1.0
	vp.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation = Vector3(-0.2, PI - 0.5, 0.0)
	back.light_energy = 0.5
	vp.add_child(back)

func _vp(px: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_world(vp)
	return vp

# ---------------- подложка ----------------
func _build_back() -> void:
	var b := ColorRect.new()
	b.position = Vector2(0, 520)
	b.size = Vector2(1160, 380)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BACK
	m.shader = sh
	b.material = m
	stage.add_child(b)

# ---------------- портреты ----------------
const P_ACTIVE := [Vector2(18, 596), 1.0]
const P_REST := [Vector2(168, 772), 0.5]

func _build_portraits() -> void:
	for hero in ["madk1d", "pahan"]:
		var vp := _vp(384)
		var cam := Camera3D.new()
		cam.fov = 22.0
		vp.add_child(cam)
		var r := Rig.new()
		vp.add_child(r)
		if hero == "pahan":
			r.setup("res://assets/models/pahan.glb", 1.74, Poses.pahan(), false, 1.0, "menu_pahan")
		else:
			r.setup("res://assets/models/madk1d.glb", 1.68, Poses.madk1d(), false, 1.0, "pause_madk1d")
		r.rotation.y = 0.42
		# голова героя: по кости, чтобы кадр держался на лице у обеих моделей
		var head_y := 1.2
		if r.bone.has("head") and int(r.bone["head"]) >= 0:
			head_y = (r.skel.global_transform * r.skel.get_bone_global_rest(int(r.bone["head"]))).origin.y + 0.2
		cam.position = Vector3(0.0, head_y + 0.05, 3.3)
		cam.look_at_from_position(cam.position, Vector3(0, head_y - 0.06, 0))
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(root)
		var red := _paper(232, 250, 31, RED)
		red.position = Vector2(26, 34)
		red.rotation = -0.05
		root.add_child(red)
		var paper := _paper(214, 232, 17 if hero == "pahan" else 23, WHITE)
		paper.position = Vector2(8, 52)
		paper.rotation = 0.03
		paper.material = worn
		root.add_child(paper)
		var pic := TextureRect.new()
		pic.texture = vp.get_texture()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.size = Vector2(290, 290)
		pic.position = Vector2(-28, 2)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.material = _pic_mat(0.0, 1.0)
		root.add_child(pic)
		portraits[hero] = {"root": root, "pic": pic, "red": red, "paper": paper, "vp": vp, "k": 0.0, "warm": 40}
	# бирка TAB: смена героя
	tab_tag = Control.new()
	tab_tag.position = Vector2(30, 800)
	tab_tag.rotation = -0.06
	stage.add_child(tab_tag)
	var tp := _paper(104, 74, 5, WHITE)
	tp.material = worn
	tab_tag.add_child(tp)
	_text(tab_tag, "TAB", 30, INK, Vector2(16, 0), serif)
	_text(tab_tag, "⇄", 30, INK, Vector2(30, 30), tech)
	# здоровье напарника: белым — сколько есть, серым — сколько ещё восстановится
	var mb := ColorRect.new()
	mb.color = Color(0.2, 0.2, 0.21, 0.9)
	mb.position = Vector2(176, 886)
	mb.size = Vector2(116, 8)
	mb.z_index = 3
	stage.add_child(mb)
	mate_grey = ColorRect.new()
	mate_grey.color = Color(0.5, 0.5, 0.52)
	mate_grey.size = Vector2(0, 8)
	mb.add_child(mate_grey)
	mate_fill = ColorRect.new()
	mate_fill.color = WHITE
	mate_fill.size = Vector2(116, 8)
	mb.add_child(mate_fill)

func _place_portraits(dt: float, snap := false) -> void:
	for hero in portraits:
		var d: Dictionary = portraits[hero]
		var goal := 1.0 if hero == shown_hero else 0.0
		d["k"] = goal if snap else move_toward(float(d["k"]), goal, dt * 4.0)
		var k: float = float(d["k"])
		var e := k * k * (3.0 - 2.0 * k)
		var root: Control = d["root"]
		root.position = (P_REST[0] as Vector2).lerp(P_ACTIVE[0], e) + Vector2(sin(e * PI) * 50.0, 0)
		root.scale = Vector2.ONE * lerpf(float(P_REST[1]), float(P_ACTIVE[1]), e)
		(d["red"] as Polygon2D).modulate.a = e
		var m: ShaderMaterial = (d["pic"] as TextureRect).material
		m.set_shader_parameter("mono", 1.0 - e)
		m.set_shader_parameter("dim", lerpf(0.62, 1.0, e))
		(d["paper"] as Polygon2D).color = WHITE.lerp(Color(0.42, 0.42, 0.42), 1.0 - e)
		# активный портрет — ниже по порядку рисования (за вторым), второй лежит поверх, как в концепте
		root.z_index = 0 if e > 0.5 else 1
		# портрет рисуется заново только пока прогревается: дальше — застывший кадр
		var vp: SubViewport = d["vp"]
		if int(d["warm"]) > 0:
			d["warm"] = int(d["warm"]) - 1
			if int(d["warm"]) == 0:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

# ---------------- имя и полосы ----------------
func _build_bars() -> void:
	name_l = _text(stage, "ПАХАН", 54, WHITE, Vector2(300, 590), serif, true)
	for i in 4:
		var s := Polygon2D.new()
		s.polygon = PackedVector2Array([Vector2(14, 0), Vector2(22, 0), Vector2(8, 26), Vector2(0, 26)])
		s.color = WHITE
		s.material = worn
		s.position = Vector2(540 + i * 14, 628)
		s.name = "slash%d" % i
		stage.add_child(s)
	_text(stage, "HP", 25, WHITE, Vector2(300, 650), serif)
	hp_text = _text(stage, "", 24, WHITE, Vector2(300, 651), serif)
	hp_text.size = Vector2(BAR_W, 30)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_fill = _bar(Vector2(300, 683))
	sw_name = _text(stage, "СВЭГ", 25, WHITE, Vector2(300, 696), serif)
	sw_text = _text(stage, "", 24, WHITE, Vector2(300, 697), serif)
	sw_text.size = Vector2(BAR_W, 30)
	sw_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sw_fill = _bar(Vector2(300, 729))

func _bar(pos: Vector2) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.21, 0.9)
	bg.position = pos
	bg.size = Vector2(BAR_W, 14)
	stage.add_child(bg)
	var f := ColorRect.new()
	f.color = WHITE
	f.position = pos
	f.size = Vector2(BAR_W, 14)
	stage.add_child(f)
	return f

# ---------------- карточки стилей ----------------
const CARD := 92.0
const CARD_X := 676.0
const CARD_GAP := 22.0
const CARD_Y := 622.0

func _build_cards() -> void:
	style_head = _text(stage, "СТИЛЬ", 20, GREY, Vector2(CARD_X + 22, 580), serif)
	var ln := ColorRect.new()
	ln.color = Color(1, 1, 1, 0.25)
	ln.position = Vector2(CARD_X + 222, 596)
	ln.size = Vector2(CARD * 3 + CARD_GAP * 2 - 222, 2)
	stage.add_child(ln)
	# Team Hype: общая шкала команды
	var hb := ColorRect.new()
	hb.color = Color(0.2, 0.2, 0.21, 0.9)
	hb.position = Vector2(CARD_X, CARD_Y + CARD + 38)
	hb.size = Vector2(CARD * 3 + CARD_GAP * 2, 10)
	stage.add_child(hb)
	hype_fill = ColorRect.new()
	hype_fill.color = WHITE
	hype_fill.size = Vector2(0, 10)
	hb.add_child(hype_fill)
	hype_text = _text(stage, "HYPE", 17, GREY, Vector2(CARD_X + CARD * 3 + CARD_GAP * 2 + 10, CARD_Y + CARD + 30), serif)
	for i in 3:
		var root := Control.new()
		root.position = Vector2(CARD_X + i * (CARD + CARD_GAP), CARD_Y)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(root)
		var bgc := ColorRect.new()
		bgc.color = Color(0, 0, 0, 0.55)
		bgc.size = Vector2(CARD, CARD)
		root.add_child(bgc)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.size = Vector2(CARD, CARD)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.material = _pic_mat(0.8, 1.0)
		(pic.material as ShaderMaterial).set_shader_parameter("tone", 0.0)
		root.add_child(pic)
		var r := RandomNumberGenerator.new()
		r.seed = 40 + i
		var pts := PackedVector2Array()
		for c in [Vector2(0, 0), Vector2(CARD, 0), Vector2(CARD, CARD), Vector2(0, CARD)]:
			pts.append(c + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3)))
		var frame := _outline(pts, 2.0, GREY)
		root.add_child(frame)
		var tag := _paper(24, 26, 60 + i, WHITE)
		tag.position = Vector2(-9, -11)
		tag.rotation = -0.12
		root.add_child(tag)
		_text(root, str(i + 1), 22, INK, Vector2(-3, -15), serif)
		var nm := _text(root, "", 19, WHITE, Vector2(-12, CARD + 6), serif)
		nm.size = Vector2(CARD + 24, 26)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards.append({"root": root, "frame": frame, "pic": pic, "name": nm, "tag": tag})

## Размеры модели по сеткам (в осях корня модели)
func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D()
		var n: Node = m
		while n != root and n != null:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box: AABB = xf * m.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

## Модель из файла: по центру и вписана в единичный размер
func _model(path: String, fit := 1.0, lay := false) -> Node3D:
	var w: Node3D = (load(path) as PackedScene).instantiate()
	var box := _bounds(w)
	var k: float = fit / max(0.001, max(box.size.x, max(box.size.y, box.size.z)))
	var pivot := Node3D.new()
	var turn := Node3D.new()
	pivot.add_child(turn)
	turn.add_child(w)
	if lay and box.size.z >= box.size.x and box.size.z >= box.size.y:
		turn.rotation.y = PI * 0.5
	elif lay and box.size.y >= box.size.x:
		turn.rotation.z = PI * 0.5
	w.scale = Vector3.ONE * k
	w.position = -(box.position + box.size * 0.5) * k
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pivot

## Маленькая сцена с настоящей моделью стиля: создаётся при первом показе
func _preview(id: String) -> Dictionary:
	if previews.has(id):
		return previews[id]
	var vp := _vp(192)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.18
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.75, 3.0), Vector3.ZERO)
	var holder := Node3D.new()
	vp.add_child(holder)
	match id:
		"vozduh":
			var b := _model("res://assets/models/balon.glb", 1.2)
			b.rotation = Vector3(0, 0, -0.6)
			holder.add_child(b)
		"bottles":
			for i in 2:
				var bt := _model(Bottles.MODEL, 1.05)
				bt.position = Vector3(-0.2 + i * 0.4, 0.04 - i * 0.08, 0.1 - i * 0.2)
				bt.rotation = Vector3(0, i * 1.2, -0.22 + i * 0.4)
				holder.add_child(bt)
		"tyaga812":
			holder.add_child(_model(Tyaga.MODEL, 1.2))
		"skateboard", "guitar":
			var sd: StyleData = Styles.by_id(id)
			var w := _model(String(sd.weapon["path"]), 1.25, true)
			w.rotation = Vector3(0, 0, 0.75) if id == "guitar" else Vector3(0.45, 0, 0.3)
			holder.add_child(w)
		"breaker":
			# Breaker — не оружие: сам madk1d в позе Freeze
			var r := Rig.new()
			holder.add_child(r)
			r.setup("res://assets/models/madk1d.glb", 1.1, Poses.madk1d(), false, 1.0, "pause_madk1d")
			r.position = Vector3(0, -0.45, 0)
			r.play("FreezePose", 0.0)
	var d := {"vp": vp, "holder": holder, "warm": 90 if id == "breaker" else 8}
	previews[id] = d
	return d

func _show_cards(p) -> void:
	var ids: Array = p.own_styles
	style_head.text = "СТИЛЬ (%s)" % NAMES.get(p.hero, "")
	for i in cards.size():
		var c: Dictionary = cards[i]
		(c["root"] as Control).visible = i < ids.size()
		if i >= ids.size():
			continue
		var id: String = ids[i]
		var pv := _preview(id)
		(c["pic"] as TextureRect).texture = (pv["vp"] as SubViewport).get_texture()
		(c["name"] as Label).text = SHORT.get(id, id)
		var on: bool = id == p.style.id
		(c["frame"] as Line2D).default_color = WHITE if on else GREY
		(c["frame"] as Line2D).width = 6.0 if on else 3.0
		((c["pic"] as TextureRect).material as ShaderMaterial).set_shader_parameter("dim", 1.0 if on else 0.8)
		((c["pic"] as TextureRect).material as ShaderMaterial).set_shader_parameter("mono", 0.55 if on else 1.0)
		(c["name"] as Label).add_theme_color_override("font_color", WHITE if on else GREY)
		(c["root"] as Control).scale = Vector2.ONE * (1.06 if on else 1.0)
		(c["root"] as Control).pivot_offset = Vector2(CARD, CARD) * 0.5

## Вращается и перерисовывается только выбранная модель текущего героя
func _tick_previews(dt: float, p) -> void:
	for id in previews:
		var d: Dictionary = previews[id]
		var vp: SubViewport = d["vp"]
		var live: bool = id == p.style.id and visible and modulate.a > 0.05
		if live:
			(d["holder"] as Node3D).rotation.y += dt * 0.9
		if int(d["warm"]) > 0:
			d["warm"] = int(d["warm"]) - 1
			live = true
		var mode := SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
		if vp.render_target_update_mode != mode:
			vp.render_target_update_mode = mode

# ---------------- способности ----------------
const SLOT_X := [420.0, 590.0, 760.0]
const SLOT_Y := 808.0
const SLOT_R := 36.0

func _build_slots() -> void:
	_text(stage, "СПОСОБНОСТИ", 17, GREY, Vector2(300, 750), serif)
	var ln := ColorRect.new()
	ln.color = Color(1, 1, 1, 0.25)
	ln.position = Vector2(470, 762)
	ln.size = Vector2(350, 2)
	stage.add_child(ln)
	for i in 3:
		var root := Control.new()
		root.position = Vector2(SLOT_X[i], SLOT_Y)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(root)
		root.add_child(_diamond(SLOT_R, Color(0, 0, 0, 0.7)))
		# заполнение ромба снизу вверх — ход перезарядки
		var clip := Control.new()
		clip.clip_contents = true
		clip.position = Vector2(-SLOT_R, -SLOT_R)
		clip.size = Vector2(SLOT_R * 2, SLOT_R * 2)
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(clip)
		var fill := _diamond(SLOT_R - 3.0, Color(1, 1, 1, 0.16))
		fill.position = Vector2(SLOT_R, SLOT_R)
		clip.add_child(fill)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(46, 46)
		icon.position = Vector2(-23, -25)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)
		var edge := _outline(PackedVector2Array([Vector2(0, -SLOT_R), Vector2(SLOT_R, 0), Vector2(0, SLOT_R), Vector2(-SLOT_R, 0)]), 3.0, WHITE)
		root.add_child(edge)
		var time := _text(root, "", 26, WHITE, Vector2(-SLOT_R, -19), serif)
		time.size = Vector2(SLOT_R * 2, 32)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var kd := _diamond(16.0, WHITE)
		kd.position = Vector2(0, SLOT_R - 2)
		root.add_child(kd)
		var key := _text(root, "Q", 20, INK, Vector2(-16, SLOT_R - 16), serif)
		key.size = Vector2(32, 26)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var nm := _text(root, "", 19, WHITE, Vector2(-85, SLOT_R + 15), serif)
		nm.size = Vector2(170, 26)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pips: Array = []
		for j in 3:
			var pd := _diamond(6.0, WHITE)
			pd.position = Vector2(-18 + j * 18, SLOT_R + 48)
			root.add_child(pd)
			pips.append(pd)
		slots.append({"root": root, "icon": icon, "key": key, "name": nm, "time": time, "pips": pips, "fill": fill, "clip": clip, "edge": edge, "shown": ""})

## Три способности выбранного стиля — только настоящие: [клавиша, имя, значок, готовность 0..1, подпись]
func abilities(p) -> Array:
	var out: Array = []
	var b = game.buddy
	out.append(["Q", "АД-ЛИБ", "adlib", 1.0 - clampf(b.cd / max(0.01, b.cd_max), 0.0, 1.0), "%.1f" % b.cd if b.cd > 0.0 else ""])
	var rage := ["R", "ПЕРЕГРУЗ", "rage", p.rage / 8.0 if p.rage > 0.0 else p.swag / 100.0, "%.0f" % p.rage if p.rage > 0.0 else ""]
	var id: String = p.style.id
	match id:
		"vozduh":
			out.append(["E", "HEAT", "heat", min(1.0, p.swag / 40.0), ""])
			var st: StyleData = Styles.by_id("bottles")
			out.append(["F", "ВОДЯРА", "bottle", p.combat.ammo_of("bottles") / max(1.0, float(st.ammo_max)), ""])
		"bottles":
			out.append(["E", "HEAT", "heat", min(1.0, p.swag / 40.0), ""])
			out.append(rage)
		"tyaga812":
			out.append(["E", "СОЙТИ" if p.tyaga.riding() else "ЕЗДА", "ride", 0.0 if p.tyaga.lock > 0.0 else 1.0, "%.1f" % p.tyaga.lock if p.tyaga.lock > 0.0 else ""])
			out.append(rage)
		"skateboard":
			out.append(["F", "ТРЮК", "trick", p.skate.charges / 3.0, ""])
			out.append(rage)
		"guitar":
			out.append(["E", "DISTORTION", "dist", 1.0 if p.guitar.distortion > 0.0 else min(1.0, p.swag / Guitar.DIST_COST), "%.0f" % p.guitar.distortion if p.guitar.distortion > 0.0 else ""])
			out.append(["F", "POWER CHORD", "chord", p.guitar.bars / float(Guitar.MAX_BARS), ""])
		"breaker":
			var fin: bool = p.breaker.perfect and p.breaker.cashed >= Breaker.FINISH_FLOW
			out.append(["F", "ФИНАЛ" if fin else "FREEZE", "freeze", 1.0 if fin else min(1.0, p.breaker.flow / float(Breaker.FINISH_FLOW)), ""])
			out.append(rage)
		_:
			out.append(rage)
	return out

func _tick_slots(p) -> void:
	var list := abilities(p)
	for i in slots.size():
		var s: Dictionary = slots[i]
		(s["root"] as Control).visible = i < list.size()
		if i >= list.size():
			continue
		var a: Array = list[i]
		if String(s["shown"]) != String(a[2]):
			s["shown"] = String(a[2])
			(s["icon"] as TextureRect).texture = load("res://assets/fx/%s.png" % ICONS[a[2]])
		(s["key"] as Label).text = String(a[0])
		(s["name"] as Label).text = String(a[1])
		(s["time"] as Label).text = String(a[4])
		var k: float = clampf(float(a[3]), 0.0, 1.0)
		var ready: bool = k >= 0.999
		(s["icon"] as TextureRect).modulate = Color(1, 1, 1, 1.0 if ready else 0.5) if String(a[4]) == "" else Color(1, 1, 1, 0.15)
		(s["edge"] as Line2D).default_color = WHITE if ready else GREY
		(s["name"] as Label).add_theme_color_override("font_color", WHITE if ready else GREY)
		# заливка поднимается снизу
		var clip: Control = s["clip"]
		var hgt := SLOT_R * 2.0 * k
		clip.position = Vector2(-SLOT_R, SLOT_R - hgt)
		clip.size = Vector2(SLOT_R * 2, hgt)
		(s["fill"] as Polygon2D).position = Vector2(SLOT_R, hgt - SLOT_R)
		(s["fill"] as Polygon2D).color = Color(1, 1, 1, 0.3 if ready else 0.14)
		var pips: Array = s["pips"]
		for j in 3:
			var part: float = clampf(k * 3.0 - j, 0.0, 1.0)
			(pips[j] as Polygon2D).color = Color(WHITE.r, WHITE.g, WHITE.b, 0.2 + 0.8 * part)
			(pips[j] as Polygon2D).scale = Vector2.ONE * (0.7 + 0.3 * part)

# ---------------- каждый кадр ----------------
func _process(dt: float) -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	if shown_hero != p.hero:
		var first := shown_hero == ""
		shown_hero = p.hero
		shown_style = ""
		name_l.text = NAMES.get(p.hero, "")
		_place_portraits(0.0, first)
		var w: float = serif.get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		for i in 4:
			(stage.get_node("slash%d" % i) as Node2D).position.x = 300 + w + 14 + i * 14
	if shown_style != p.style.id:
		shown_style = p.style.id
		_show_cards(p)
	_place_portraits(dt)
	_tick_previews(dt, p)
	_tick_slots(p)
	var hy = game.hype
	if hy != null:
		var full: bool = hy.full() or hy.active()
		hype_fill.size.x = (CARD * 3 + CARD_GAP * 2) * clampf(hy.value / TeamHype.MAX, 0.0, 1.0)
		hype_fill.color = Color(1.0, 0.86, 0.5).lerp(Color(0.9, 0.2, 0.15), 0.5 + 0.5 * sin(game.clock * 8.0)) if full else WHITE
		var want_t := "[G] OVERDRIVE" if full else "HYPE"
		if hype_text.text != want_t:
			hype_text.text = want_t
		hype_text.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5) if full else GREY)
	var tg = game.tag
	if tg != null:
		var o: String = tg.mate()
		var k_hp: float = clampf(float(tg.hp[o]) / p.max_hp, 0.0, 1.0)
		mate_fill.size.x = 116.0 * k_hp
		mate_fill.color = Color(0.85, 0.2, 0.16) if tg.down[o] else WHITE
		mate_grey.size.x = 116.0 * clampf((float(tg.hp[o]) + float(tg.grey[o])) / p.max_hp, 0.0, 1.0)
		tab_tag.modulate.a = 1.0 if tg.tag_block() == "" else 0.45
	hp_fill.size.x = BAR_W * clampf(p.hp / p.max_hp, 0.0, 1.0)
	hp_text.text = "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)]
	var raging: bool = p.rage > 0.0
	sw_fill.size.x = BAR_W * clampf(p.rage / 8.0 if raging else p.swag / 100.0, 0.0, 1.0)
	sw_fill.color = Color(0.85, 0.16, 0.12) if raging else WHITE
	sw_name.text = "ПЕРЕГРУЗ" if raging else "СВЭГ"
	sw_text.text = "%.0f с" % p.rage if raging else ("ПОЛОН · [R]" if p.swag >= 100.0 else "%d%%" % int(p.swag))
