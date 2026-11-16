## Главное меню: чёрно-белая манга-гранж композиция по утверждённому концепту.
## Слева — логотип и диагональный список пунктов с рваной белой плашкой на выбранном, справа — настоящие
## 3D-модели madk1d и Пахана (отдельный SubViewport со своим миром), пропущенные через монохромный шейдер
## с полутоном и белым контуром. Фон (гранж, мазки, кольца, силуэт города, отражающий пол) рисует шейдер.
## Сцена собрана на «столе» 1600×900, который вписывается в окно; фон тянется на всё окно.
## Управление: W/S или стрелки — выбор, Enter/Пробел/ЛКМ — подтвердить, Esc — назад; мышь работает везде.
class_name Menu
extends Control

const CHAPTERS := 1            # сколько глав сейчас в игре: только первая; дальше вместо глав будет открытый мир
const STAGE := Vector2(1600, 900)
const SAVE := "user://grimerka_save.json"
const DISPLAY := "user://grimerka_display.json"
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const ITEMS := [
	["CONTINUE", "Продолжить игру с последнего сохранения."],
	["NEW GAME", "Начать новое прохождение GOD OF GRIMERKA."],
	["LOAD GAME", "Посмотреть доступное сохранение."],
	["SETTINGS", "Настройки изображения, звука и управления."],
	["EXTRAS", "Дополнительная информация об игре."],
	["EXIT", "Выйти из GOD OF GRIMERKA."],
]
const MIRROR := 660.0        # насколько ниже героев лежит их отражение (подобрано под уровень ступней в кадре)
const SIZES := [90, 56, 52, 47, 43, 40]

const BG_SHADER := """
shader_type canvas_item;
uniform float aspect = 1.777;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 5; i++) { s += a * n(p); p *= 2.03; a *= 0.5; } return s; }
float tower(float x) {
	float c = floor(x * 46.0);
	float t = 0.05 + 0.16 * h(vec2(c, 3.0));
	t += step(0.86, h(vec2(c, 9.0))) * 0.14;
	return t * smoothstep(0.25, 0.55, x / aspect) * (0.6 + 0.4 * n(vec2(x * 3.0, 1.0)));
}
float ring(vec2 p, vec2 c, float r, float w) {
	float d = abs(length(p - c) - r);
	float a = atan(p.y - c.y, p.x - c.x);
	return (1.0 - smoothstep(w * 0.35, w, d)) * smoothstep(0.35, 0.6, fbm(vec2(a * 3.0, r * 9.0)));
}
void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	float v = 0.03 + 0.045 * fbm(p * 3.0);
	// диагональные мазки сухой кистью
	vec2 d = vec2(p.x * 0.93 - p.y * 0.36, p.x * 0.36 + p.y * 0.93);
	float lane = fbm(vec2(d.x * 0.9, d.y * 9.0));
	float brush = smoothstep(0.52, 0.72, lane) * smoothstep(0.3, 0.75, fbm(vec2(d.x * 26.0, d.y * 2.0)));
	v += brush * 0.2;
	// широкая светлая полоса за логотипом
	float slash = (1.0 - smoothstep(0.0, 0.11, abs(d.y - 0.1 + 0.02 * fbm(vec2(d.x * 5.0, 2.0))))) * (1.0 - smoothstep(0.2, 1.25, d.x));
	v += slash * 0.1 * (0.4 + fbm(vec2(d.x * 40.0, d.y * 6.0)));
	// кольца за героями
	v += ring(p, vec2(aspect * 0.73, 0.5), 0.4, 0.012) * 0.55;
	v += ring(p, vec2(aspect * 0.8, 0.62), 0.27, 0.006) * 0.4;
	// горизонт: зарево, силуэт города, окна
	float hor = 0.74;
	float glow = smoothstep(0.28, hor, UV.y) * smoothstep(0.3, 0.7, UV.x) * 0.2 * (0.6 + 0.4 * fbm(p * 2.0));
	if (UV.y < hor) {
		v += glow;
		float t = tower(p.x);
		if (UV.y > hor - t) {
			v = 0.035 + 0.02 * n(p * 40.0);
			vec2 w = vec2(p.x * 230.0, UV.y * 150.0);
			v += step(0.93, h(floor(w))) * step(0.25, fract(w.x)) * 0.22;
		}
	} else {
		// мокрый пол: отражение города и блики
		float depth = (UV.y - hor) / (1.0 - hor);
		float rip = 0.004 * sin(UV.y * 260.0) + 0.01 * (n(vec2(p.x * 30.0, UV.y * 6.0)) - 0.5);
		float t = tower(p.x + rip);
		float refl = (UV.y - hor < t * 0.9) ? 0.02 : glow_floor_dummy();
		v = 0.035 + refl;
	}
	// брызги туши и зерно
	float spl = smoothstep(0.8, 0.82, n(p * 120.0) * fbm(p * 14.0) * 1.75);
	v += spl * 0.4 * smoothstep(0.55, 0.75, fbm(p * 1.6 + 7.0));
	v += (h(p * 900.0) - 0.5) * 0.035;
	vec2 q = UV - 0.5;
	v *= 1.0 - dot(q, q) * 0.9;
	COLOR = vec4(vec3(v) * vec3(0.97, 0.99, 1.03), 1.0);
}
"""

const CHAR_SHADER := """
shader_type canvas_item;
uniform float dim = 1.0;
uniform float alpha = 1.0;
uniform float reflect = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	l = smoothstep(0.04, 0.8, l);
	l = mix(l, floor(l * 5.0 + 0.5) / 5.0, 0.55);
	// полутон в средних тонах — печатная фактура
	vec2 g = mat2(vec2(0.707, 0.707), vec2(-0.707, 0.707)) * (FRAGCOORD.xy / 4.5);
	float dotv = length(fract(g) - 0.5);
	float ht = step(dotv, (1.0 - l) * 0.5) * step(l, 0.62) * step(0.12, l);
	l -= ht * 0.2;
	// белый контур по краю силуэта
	vec2 px = TEXTURE_PIXEL_SIZE * 2.2;
	float mn = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = c.a * (1.0 - mn);
	vec3 col = mix(vec3(l), vec3(1.0), rim * 0.85) * dim;
	float a = c.a * alpha;
	if (reflect > 0.0) { a *= reflect * smoothstep(0.5, 1.0, UV.y); }
	COLOR = vec4(col, a);
}
"""

const WORN_SHADER := """
shader_type canvas_item;
uniform float amount = 0.2;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void fragment() {
	vec2 p = FRAGCOORD.xy;
	float m = n(p * 0.012) * 0.5 + n(p * 0.09) * 0.3 + n(p * 0.5) * 0.2;
	COLOR.a *= smoothstep(amount - 0.1, amount + 0.06, m);
}
"""

var main
var stage: Control
var bg: ColorRect
var bg_mat: ShaderMaterial
var serif: SystemFont
var tech: SystemFont
var worn: ShaderMaterial
var list: Control
var band: Polygon2D
var rows: Array = []          # [{root, label, mark, sub}]
var sel := 0
var has_save := false
var save := {}
var story := {}
var build := {}
var info: Label
var panel: Control             # открытый экран (загрузка, настройки, дополнительно, подтверждение)
var panel_rows: Array = []     # [[Label, Callable]]
var panel_sel := 0
var chars: TextureRect
var chars_home := Vector2.ZERO
var update_cb := Callable()
var update_tag: Label
var t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	worn = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WORN_SHADER
	worn.shader = ws
	has_save = FileAccess.file_exists(SAVE)
	if has_save:
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			save = d
		else:
			has_save = false
	if FileAccess.file_exists("res://data/story.json"):
		var s = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
		if s is Dictionary:
			story = s
	if FileAccess.file_exists("res://data/build.json"):
		var b = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
		if b is Dictionary:
			build = b
	_build_bg()
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_characters()
	_build_logo()
	_build_corners()
	_build_list()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_select(0 if has_save else 1, false)
	# для проверки по снимкам: -- --menu=new|load|settings|extras сразу открывает экран
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			var i := ["continue", "new", "load", "settings", "extras"].find(arg.substr(7))
			if i >= 0:
				_select(i, false)
				_activate()
	main._check_update(func(cb: Callable):
		update_cb = cb
		if is_instance_valid(update_tag):
			update_tag.text = "▶ ВЫШЛО ОБНОВЛЕНИЕ — нажми сюда или открой EXTRAS"
			update_tag.visible = true)

func _fit() -> void:
	var vs := get_viewport_rect().size
	# размеры — явно: родитель меню не Control, якоря тут не растягивают
	position = Vector2.ZERO
	size = vs
	bg.position = Vector2.ZERO
	bg.size = vs
	bg_mat.set_shader_parameter("aspect", vs.x / max(1.0, vs.y))
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func chapter_no() -> int:
	return mini(int(save.get("ch", 0)), CHAPTERS - 1) + 1 if has_save else 1

func chapter_name(i: int) -> String:
	var chs: Array = story.get("CH", [])
	return String(chs[i].get("name", "")) if i >= 0 and i < chs.size() else ""

# ---------------- фон ----------------
func _build_bg() -> void:
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BG_SHADER.replace("glow_floor_dummy()", "glow * 0.5 * (1.0 - depth) + 0.05 * smoothstep(0.6, 0.9, n(vec2(p.x * 9.0, UV.y * 90.0))) * (1.0 - depth)")
	m.shader = sh
	bg.material = m
	add_child(bg)
	bg_mat = m

# ---------------- герои ----------------
func _build_characters() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 900)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.55, 0.75, 0.0)
	key.light_energy = 0.85
	vp.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation = Vector3(-0.3, PI - 0.6, 0.0)
	back.light_energy = 0.7
	vp.add_child(back)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0.0, 0.94, 6.1)
	cam.rotation.x = -0.02
	vp.add_child(cam)
	# madk1d — левее и чуть дальше, руки у карманов; Пахан — правее и ближе, с iPod у уха и в наушниках
	var mk := Rig.new()
	vp.add_child(mk)
	var mp := Poses.madk1d()
	var idle: Array = []
	for kf in mp["Idle"]["k"]:
		idle.append([kf[0], Poses.add(kf[1], {"rarm": {"z": 0.12, "x": 0.1}, "larm": {"z": -0.12, "x": 0.1}, "rfa": {"x": -0.5, "y": 0.5}, "lfa": {"x": -0.5, "y": -0.5}, "spine": {"y": 0.12}, "head": {"y": -0.08}})])
	mp["Idle"] = {"d": 3.4, "loop": true, "k": idle}
	mk.setup("res://assets/models/madk1d.glb", 1.68, mp, false, 1.0, "menu_madk1d")
	mk.position = Vector3(-0.66, 0, -0.2)
	mk.rotation.y = 0.16
	var ph := Rig.new()
	vp.add_child(ph)
	ph.setup("res://assets/models/pahan.glb", 1.74, Poses.pahan(), false, 1.0, "menu_pahan")
	ph.position = Vector3(0.52, 0, 0.3)
	ph.rotation.y = -0.2
	var pod := PodHand.new()
	pod.setup(ph)
	pod.pose_hold = true
	if pod.sfx:
		pod.sfx.queue_free()
		pod.sfx = null
	ph.skel.add_child(pod)
	var cm := ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = CHAR_SHADER
	cm.shader = cs
	var tex := vp.get_texture()
	# крупные тёмные портреты за героями — задний графический слой из их же изображения
	var ghost := TextureRect.new()
	ghost.texture = tex
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.size = Vector2(2300, 2070)
	ghost.position = Vector2(330, -330)
	var gm: ShaderMaterial = cm.duplicate()
	gm.set_shader_parameter("dim", 0.34)
	gm.set_shader_parameter("alpha", 0.55)
	ghost.material = gm
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Control.new()
	clip.size = STAGE
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(clip)
	var sky := Control.new()
	sky.size = Vector2(STAGE.x, 600)
	sky.clip_contents = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(sky)
	sky.add_child(ghost)
	chars_home = Vector2(615, 10)
	var mirror := TextureRect.new()
	mirror.texture = tex
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.size = Vector2(1000, 900)
	mirror.flip_v = true
	mirror.position = chars_home + Vector2(0, MIRROR)
	var rm: ShaderMaterial = cm.duplicate()
	rm.set_shader_parameter("dim", 0.5)
	rm.set_shader_parameter("reflect", 0.5)
	mirror.material = rm
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(mirror)
	chars = TextureRect.new()
	chars.texture = tex
	chars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chars.size = Vector2(1000, 900)
	chars.position = chars_home
	chars.material = cm
	chars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(chars)
	chars.set_meta("mirror", mirror)
	chars.set_meta("ghost", ghost)

# ---------------- текст ----------------
func _text(parent: Control, s: String, size: int, col: Color, pos: Vector2, f: Font = null, rough := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else tech)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rough:
		l.material = worn
	parent.add_child(l)
	return l

func _build_logo() -> void:
	var logo := Control.new()
	logo.position = Vector2(70, 84)
	logo.rotation = deg_to_rad(-3.5)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(logo)
	_text(logo, "G", 330, WHITE, Vector2(0, -78), serif, true)
	_text(logo, "OD OF", 90, WHITE, Vector2(252, 22), serif, true)
	_text(logo, "RIMERKA", 124, WHITE, Vector2(232, 100), serif, true)
	_text(logo, "RISE. CONQUER. REWRITE FATE.", 21, SILVER, Vector2(262, 252), serif)
	var plaque := ColorRect.new()
	plaque.color = WHITE
	plaque.position = Vector2(590, 236)
	plaque.size = Vector2(158, 28)
	plaque.rotation = deg_to_rad(-6.0)
	plaque.material = worn
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(plaque)
	_text(plaque, "MAIN MENU //", 19, INK, Vector2(12, 1), serif)

func _build_corners() -> void:
	# слева сверху: сезон, глава, техническая строка
	_text(stage, "01", 34, WHITE, Vector2(32, 34), serif)
	_text(stage, "/ SEASON 01\n/ CHAPTER %02d\n/ SYS_%s" % [chapter_no(), String(build.get("sha", "dev"))], 13, SILVER, Vector2(86, 36))
	var dia := Polygon2D.new()
	dia.polygon = PackedVector2Array([Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])
	dia.color = WHITE
	dia.position = Vector2(20, 60)
	stage.add_child(dia)
	# справа сверху: профиль — без выдуманного уровня, только настоящая глава
	var r := _text(stage, "PLAYER", 12, GREY, Vector2(1380, 30))
	r.size = Vector2(190, 16)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var line := ColorRect.new()
	line.color = SILVER
	line.position = Vector2(1430, 50)
	line.size = Vector2(150, 1)
	stage.add_child(line)
	var nm := _text(stage, "GRIMERKA", 26, WHITE, Vector2(1330, 54), serif)
	nm.size = Vector2(240, 30)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var chl := _text(stage, "CH.", 24, WHITE, Vector2(1440, 86), serif)
	chl.size = Vector2(70, 30)
	chl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key(Vector2(1520, 90), "%02d" % chapter_no(), 46)
	# слева снизу: описание выбранного пункта
	var bar := ColorRect.new()
	bar.color = SILVER
	bar.position = Vector2(0, 831)
	bar.size = Vector2(30, 1)
	stage.add_child(bar)
	var dia2: Polygon2D = dia.duplicate()
	dia2.position = Vector2(36, 831)
	dia2.scale = Vector2(0.6, 0.6)
	stage.add_child(dia2)
	_text(stage, "INFORMATION", 14, WHITE, Vector2(48, 822))
	info = _text(stage, "", 15, SILVER, Vector2(48, 846))
	# справа: подсказки управления
	_hint(Vector2(1395, 668), "CONFIRM", "Enter")
	_hint(Vector2(1395, 704), "BACK", "Esc")
	# справа снизу: настоящая сборка
	var b := _text(stage, "BUILD\n%s\nGOD OF GRIMERKA" % (String(build.get("sha", "dev")) + ((" · " + String(build.get("time", ""))) if build.has("time") else "")), 12, SILVER, Vector2(1270, 822))
	b.size = Vector2(300, 60)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	update_tag = _text(stage, "", 14, WHITE, Vector2(1100, 790))
	update_tag.size = Vector2(470, 22)
	update_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	update_tag.visible = false
	update_tag.mouse_filter = Control.MOUSE_FILTER_STOP
	update_tag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	update_tag.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and update_cb.is_valid():
			update_cb.call())

func _key(pos: Vector2, s: String, w: float) -> void:
	var k := ColorRect.new()
	k.color = Color(0.86, 0.87, 0.89)
	k.position = pos
	k.size = Vector2(w, 22)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(k)
	var l := _text(k, s, 13, INK, Vector2.ZERO)
	l.size = k.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _hint(pos: Vector2, s: String, key_name: String) -> void:
	var l := _text(stage, s, 17, WHITE, pos, serif)
	l.size = Vector2(110, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key(pos + Vector2(122, 1), key_name, 46)

# ---------------- список пунктов ----------------
func _torn(w: float, h: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	var x := -60.0
	while x < w:                       # верхний край
		pts.append(Vector2(x, rng.randf_range(-5.0, 4.0)))
		x += rng.randf_range(9.0, 26.0)
	var y := 0.0
	while y < h:                       # правый край — рваный, клином
		pts.append(Vector2(w + rng.randf_range(-16.0, 26.0) + 40.0 * (1.0 - absf(y / h - 0.5) * 2.0), y))
		y += rng.randf_range(7.0, 15.0)
	x = w
	while x > -60.0:                   # нижний край
		pts.append(Vector2(x, h + rng.randf_range(-4.0, 6.0)))
		x -= rng.randf_range(9.0, 26.0)
	y = h
	while y > 0.0:                     # левый край
		pts.append(Vector2(-60.0 + rng.randf_range(-22.0, 10.0), y))
		y -= rng.randf_range(8.0, 16.0)
	return pts

func _build_list() -> void:
	list = Control.new()
	list.position = Vector2(60, 452)
	list.rotation = deg_to_rad(-9.0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(list)
	band = Polygon2D.new()
	band.color = WHITE
	band.material = worn
	list.add_child(band)
	var y := 0.0
	for i in ITEMS.size():
		var size: int = SIZES[i]
		var root := Control.new()
		root.position = Vector2(70 + i * 16, y)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		list.add_child(root)
		var lab := _text(root, ITEMS[i][0], size, WHITE, Vector2.ZERO, serif, true)
		var w: float = serif.get_string_size(ITEMS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		root.size = Vector2(w + 30, size * 1.12)
		var mark := Polygon2D.new()
		mark.polygon = PackedVector2Array([Vector2(0, 0), Vector2(size * 0.32, size * 0.2), Vector2(0, size * 0.4)])
		mark.position = Vector2(-size * 0.62, size * 0.42)
		mark.color = WHITE
		root.add_child(mark)
		var sub: Label = null
		if i == 0:
			var st := "Сохранения пока нет" if not has_save else "Глава %d · %s · шаг %d · опыт %d" % [chapter_no(), chapter_name(chapter_no() - 1), int(save.get("step", 0)) + 1, int(save.get("xp", 0))]
			sub = _text(root, st, 15, INK, Vector2(40, size * 1.1))
		rows.append({"root": root, "label": lab, "mark": mark, "sub": sub, "w": w, "h": size})
		root.mouse_entered.connect(func(): if panel == null: _select(i))
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and panel == null:
				_select(i)
				_activate())
		y += size * (1.42 if i == 0 else 1.16)

func _enabled(i: int) -> bool:
	return i != 0 or has_save

func _select(i: int, sound := true) -> void:
	if i != sel and sound:
		main.sfx("sfx_ui", -10.0, 1.2)
	sel = i
	info.text = ITEMS[i][1] if _enabled(i) else "Сохранения пока нет — начни новую игру."
	var r: Dictionary = rows[i]
	var root: Control = r["root"]
	var h: float = float(r["h"]) * (1.5 if i == 0 else 1.14)
	band.polygon = _torn(float(r["w"]) + 150.0, h, 7 + i)
	band.position = Vector2(-60.0, root.position.y + float(r["h"]) * 0.04)
	band.scale = Vector2(0.9, 1.0)
	var tw := band.create_tween()
	tw.tween_property(band, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for k in rows.size():
		var on := k == i
		var e := _enabled(k)
		var col := INK if on else (WHITE if k == 1 else SILVER)
		if not e:
			col = Color(0.3, 0.31, 0.33) if on else Color(0.32, 0.33, 0.35)
		(rows[k]["label"] as Label).add_theme_color_override("font_color", col)
		(rows[k]["label"] as Label).material = null if on else worn
		(rows[k]["mark"] as Polygon2D).color = INK if on else GREY
		(rows[k]["mark"] as Polygon2D).scale = Vector2.ONE * (1.3 if on else 0.8)
		if rows[k]["sub"] != null:
			(rows[k]["sub"] as Label).add_theme_color_override("font_color", Color(0.15, 0.15, 0.17) if on else GREY)

func _activate() -> void:
	main.sfx("sfx_ui")
	match sel:
		0:
			if has_save:
				main.start_game(true)
		1:
			if has_save:
				_open("NEW GAME", ["Сохранение будет перезаписано:", "Глава %d · %s" % [chapter_no(), chapter_name(chapter_no() - 1)], "Начать заново с первой главы?"],
					[["НАЧАТЬ ЗАНОВО", func(): main.start_game(false, 0)], ["ОТМЕНА", _close]], 1)
			else:
				main.start_game(false, 0)
		2:
			_open_load()
		3:
			_open_settings()
		4:
			_open_extras()
		5:
			get_tree().quit()

# ---------------- экраны ----------------
func _open(title: String, lines: Array, actions: Array, start := 0) -> VBoxContainer:
	_close()
	panel = Control.new()
	panel.size = STAGE
	stage.add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.size = STAGE
	panel.add_child(shade)
	var card := Polygon2D.new()
	card.polygon = _torn(700.0, 520.0, 91)
	card.color = Color(0.05, 0.05, 0.06, 0.97)
	card.position = Vector2(120, 250)
	panel.add_child(card)
	var edge := Line2D.new()
	edge.points = card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	card.add_child(edge)
	var head := _text(panel, title, 64, WHITE, Vector2(120, 262), serif, true)
	head.rotation = deg_to_rad(-2.0)
	var box := VBoxContainer.new()
	box.position = Vector2(126, 356)
	box.size = Vector2(650, 380)
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	for s in lines:
		var l := Label.new()
		l.text = String(s)
		l.add_theme_font_override("font", tech)
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", SILVER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	panel_rows = []
	for i in actions.size():
		var a: Array = actions[i]
		var l2 := Label.new()
		l2.add_theme_font_override("font", serif)
		l2.add_theme_font_size_override("font_size", 30)
		l2.mouse_filter = Control.MOUSE_FILTER_STOP
		l2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		l2.set_meta("text", a[0])
		box.add_child(l2)
		panel_rows.append([l2, a[1]])
		l2.mouse_entered.connect(func(): _panel_select(i))
		l2.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_panel_select(i)
				_panel_activate())
	_panel_select(clampi(start, 0, max(0, panel_rows.size() - 1)), false)
	info.text = "Enter — выбрать · Esc — назад"
	return box

func _panel_select(i: int, sound := true) -> void:
	if panel_rows.is_empty():
		return
	if sound and i != panel_sel:
		main.sfx("sfx_ui", -10.0, 1.2)
	panel_sel = i
	for k in panel_rows.size():
		var l: Label = panel_rows[k][0]
		var txt = l.get_meta("text")
		var s: String = String(txt.call()) if txt is Callable else String(txt)
		l.text = ("▶ " if k == i else "   ") + s
		l.add_theme_color_override("font_color", WHITE if k == i else GREY)

func _panel_activate() -> void:
	if panel_rows.is_empty():
		return
	main.sfx("sfx_ui")
	var cb: Callable = panel_rows[panel_sel][1]
	cb.call()
	if panel != null:
		_panel_select(panel_sel, false)   # переключатели обновляют свою подпись

func _close() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
		panel_rows = []
		info.text = ITEMS[sel][1]

func _open_load() -> void:
	if not has_save:
		_open("LOAD GAME", ["Сохранений пока нет.", "Игра сохраняется сама — в одну ячейку — после каждого пройденного шага главы."], [["НАЗАД", _close]])
		return
	var up: Dictionary = save.get("up", {})
	_open("LOAD GAME", [
		"ЯЧЕЙКА 01 — единственная: игра хранит одно сохранение.",
		"Глава %d · %s" % [chapter_no(), chapter_name(chapter_no() - 1)],
		"Шаг главы: %d   ·   Опыт: %d" % [int(save.get("step", 0)) + 1, int(save.get("xp", 0))],
		"Улучшения — здоровье: %d · сила: %d · ад-либ madk1d: %d" % [int(up.get("hp", 0)), int(up.get("dmg", 0)), int(up.get("q", 0))],
	], [["ЗАГРУЗИТЬ", func(): main.start_game(true)], ["НАЗАД", _close]])

func _open_settings() -> void:
	var box := _open("SETTINGS", ["ЭКРАН"], [
		[func(): return "ПОЛНЫЙ ЭКРАН: " + ("ВКЛ" if is_fullscreen(get_window()) else "ВЫКЛ"), func(): set_fullscreen(get_window(), not is_fullscreen(get_window()))],
		[func(): return "ВЕРТИКАЛЬНАЯ СИНХРОНИЗАЦИЯ: " + ("ВКЛ" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "ВЫКЛ"), func(): set_vsync(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)],
		["НАЗАД", _close]])
	var s := Label.new()
	s.text = "ЗВУК (мышью)"
	s.add_theme_font_override("font", tech)
	s.add_theme_font_size_override("font_size", 17)
	s.add_theme_color_override("font_color", SILVER)
	box.add_child(s)
	main.audio.add_sliders(box)
	# ползунки громкости общие с паузой; здесь перекрашиваем их в белый — меню строго чёрно-белое
	for sl in box.find_children("*", "HSlider", true, false):
		for nm in ["grabber_area", "grabber_area_highlight"]:
			var fill := StyleBoxFlat.new()
			fill.bg_color = WHITE
			fill.set_corner_radius_all(3)
			fill.content_margin_top = 3
			fill.content_margin_bottom = 3
			(sl as HSlider).add_theme_stylebox_override(nm, fill)
	var c := Label.new()
	c.text = "УПРАВЛЕНИЕ: WASD — бег · мышь — камера · ЛКМ — удары · ПКМ — добивание · E — Heat · Пробел — перекат · Shift — блок · Q — ад-либ madk1d · R — ПЕРЕГРУЗ · ↑ — iPod · Esc — пауза · F11 — полный экран"
	c.add_theme_font_override("font", tech)
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", GREY)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(c)

func _open_extras() -> void:
	var acts: Array = []
	if update_cb.is_valid():
		acts.append(["ОБНОВИТЬ ИГРУ", func(): update_cb.call()])
	acts.append(["СТРАНИЦА ИГРЫ НА GITHUB", func(): OS.shell_open(main.RELEASE_URL)])
	acts.append(["НАЗАД", _close])
	_open("EXTRAS", [
		"GOD OF GRIMERKA — экшен про Пахана с Балоном VOZDUH и его кента madk1d. Сейчас в игре первая глава; дальше будет открытый мир.",
		"Сборка: %s%s" % [String(build.get("sha", "запуск из редактора")), (" · " + String(build.get("time", ""))) if build.has("time") else ""],
		"Вышло обновление — можно поставить прямо отсюда." if update_cb.is_valid() else "Обновления проверяются при входе в меню.",
		"Голоса — Fish Audio. Эффекты — Kenney Particle Pack (CC0). Модели — Tripo AI. Музыка локаций синтезирована в игре.",
	], acts)

# ---------------- экран: общее для меню и паузы ----------------
static func is_fullscreen(w: Window) -> bool:
	return w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN

static func set_fullscreen(w: Window, on: bool) -> void:
	w.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
	_save_display(on, DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

static func set_vsync(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	var f := FileAccess.file_exists(DISPLAY)
	var full := false
	if f:
		var d = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY))
		if d is Dictionary:
			full = bool(d.get("fullscreen", false))
	_save_display(full, on)

static func _save_display(full: bool, vsync: bool) -> void:
	var f := FileAccess.open(DISPLAY, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fullscreen": full, "vsync": vsync}))

## Применить сохранённые настройки экрана при запуске игры.
static func apply_display(w: Window) -> void:
	if not FileAccess.file_exists(DISPLAY):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY))
	if d is Dictionary:
		if bool(d.get("fullscreen", false)):
			w.mode = Window.MODE_FULLSCREEN
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(d.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)

## Те же переключатели экрана кнопками — для меню паузы.
static func add_display_buttons(box: Container, w: Window) -> void:
	for kind in ["full", "vsync"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(400, 34)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var refresh := func():
			if kind == "full":
				b.text = "Полный экран: " + ("вкл" if is_fullscreen(w) else "выкл")
			else:
				b.text = "Вертикальная синхронизация: " + ("вкл" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "выкл")
		b.pressed.connect(func():
			if kind == "full":
				set_fullscreen(w, not is_fullscreen(w))
			else:
				set_vsync(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)
			refresh.call())
		refresh.call()
		box.add_child(b)

# ---------------- ввод и жизнь ----------------
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	var up := k == KEY_W or k == KEY_UP
	var down := k == KEY_S or k == KEY_DOWN
	var ok := k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	if panel != null:
		if up and not panel_rows.is_empty():
			_panel_select(posmod(panel_sel - 1, panel_rows.size()))
		elif down and not panel_rows.is_empty():
			_panel_select(posmod(panel_sel + 1, panel_rows.size()))
		elif ok:
			_panel_activate()
		elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
			main.sfx("sfx_ui", -8.0, 0.8)
			_close()
		get_viewport().set_input_as_handled()
		return
	if up:
		_select(posmod(sel - 1, ITEMS.size()))
	elif down:
		_select(posmod(sel + 1, ITEMS.size()))
	elif ok:
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	t += dt
	if chars == null:
		return
	# лёгкий параллакс: герои и их отражение чуть уходят от курсора, задние портреты — в другую сторону
	var vs := get_viewport_rect().size
	var m := (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	var off := Vector2(-m.x * 14.0, -m.y * 6.0 + sin(t * 0.7) * 1.5)
	chars.position = chars.position.lerp(chars_home + off, 1.0 - exp(-5.0 * dt))
	var mirror: TextureRect = chars.get_meta("mirror")
	mirror.position = Vector2(chars.position.x, chars_home.y + MIRROR - (chars.position.y - chars_home.y))
	var ghost: TextureRect = chars.get_meta("ghost")
	ghost.position = ghost.position.lerp(Vector2(330, -330) + Vector2(m.x * 22.0, m.y * 8.0), 1.0 - exp(-3.0 * dt))
