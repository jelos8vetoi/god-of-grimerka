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
## Пункты: [надпись, описание внизу, (подпись под надписью)]. NEW GAME, LOAD GAME и TRAINING ARENA живут на экране
## выбора режима (PLAY → mode_select.gd): STORY MODE и TRAINING ARENA.
const ITEMS := [
	["CONTINUE", "Продолжить игру с последнего сохранения."],
	["PLAY", "Выбор режима: сюжет, тренировочная арена, гонки на пылесосах.", "ВЫБОР РЕЖИМА · сюжет · арена · гонки"],
	["SETTINGS", "Настройки изображения, звука и управления."],
	["EXTRAS", "Дополнительная информация об игре."],
	["EXIT", "Выйти из GOD OF GRIMERKA."],
]
const MIRROR := 660.0        # насколько ниже героев лежит их отражение (подобрано под уровень ступней в кадре)
const SIZES := [84, 64, 46, 43, 40]

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
var launching := false        # переход в игру начался: меню больше не реагирует
var hero_vp: SubViewport       # сцена с героями (для рендера в установщик: -- --menu-render=<файл.png>)
var chars: TextureRect
var chars_home := Vector2.ZERO
var update_cb := Callable()
var update_tag: Label
var t := 0.0
var modes: ModeSelect          # экран «ВЫБОР РЕЖИМА» (PLAY)
var main_only: Array = []      # что видно только на главном списке: логотип, список, герои, подсказки — гаснет на экране режимов
var panel_back := Callable()   # Esc на открытом экране: куда вернуться (пусто — просто закрыть)
var capture := Callable()      # ждём нажатия клавиши (переназначение гоночных клавиш): получит событие
var online: RaceLobby          # экран ONLINE RACE
var studio: MenuStudio         # 3D-сцена телестудии «ОБЛАКО-ТВ»: пункты меню — телевизоры (menu_studio.gd)
var bed: AudioStreamPlayer     # подложка меню: треск винила и гул (MenuSfx.make_bed, Ambient), уходит вместе с меню

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
	if main != null and main.ui_sfx != null:
		bed = main.ui_sfx.make_bed(self)
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
	bg.visible = false                   # прежний плоский фон: его место заняла студия
	studio = MenuStudio.new()
	add_child(studio)
	studio.setup(ITEMS, serif)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_characters()
	_build_logo()
	_build_corners()
	_build_list()
	studio.set_enabled(0, has_save)
	if rows[0]["sub"] != null:
		studio.set_sub(0, (rows[0]["sub"] as Label).text)
	modes = ModeSelect.new()
	modes.setup(self)
	stage.add_child(modes)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_select(0 if has_save else 1, false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-render="):
			_render_heroes(arg.substr(14))
	# для проверки по снимкам: -- --menu=continue|modes|story|new|load|training|race|settings|extras сразу открывает экран
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			var w := arg.substr(7)
			match w:
				"continue":
					_select(0, false)
					_activate()
				"modes":
					open_modes(0)
				"story", "new", "load", "training", "race":
					open_modes({"training": 1, "race": 2}.get(w, 0))
					if w == "new" or w == "load":
						_open_story()
						_panel_select(panel_rows.size() - 3 if w == "new" else panel_rows.size() - 2, false)
						_panel_activate()
					else:
						open_mode(w)
				"settings", "extras":
					_select(2 if w == "settings" else 3, false)
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
	studio.position = Vector2.ZERO
	studio.size = vs
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
	hero_vp = vp
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
	clip.visible = false                 # плоские герои больше не на главном экране (их рендер нужен экрану режимов и установщику)
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
	logo.position = Vector2(64, 96)
	logo.rotation = deg_to_rad(-3.5)
	logo.scale = Vector2(0.5, 0.5)       # меньше прежнего: главное на экране — студия и её телевизоры
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(logo)
	main_only.append(logo)
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
	main_only.append(_text(stage, "01", 34, WHITE, Vector2(32, 34), serif))
	main_only.append(_text(stage, "/ SEASON 01\n/ CHAPTER %02d\n/ SYS_%s" % [chapter_no(), String(build.get("sha", "dev"))], 13, SILVER, Vector2(86, 36)))
	var dia := Polygon2D.new()
	dia.polygon = PackedVector2Array([Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])
	dia.color = WHITE
	dia.position = Vector2(20, 60)
	stage.add_child(dia)
	main_only.append(dia)
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
	main_only.append(bar)
	main_only.append(dia2)
	main_only.append(_text(stage, "INFORMATION", 14, WHITE, Vector2(48, 822)))
	info = _text(stage, "", 15, SILVER, Vector2(48, 846))
	main_only.append(info)
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
	main_only.append(update_tag)
	update_tag.mouse_filter = Control.MOUSE_FILTER_STOP
	update_tag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	update_tag.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and update_cb.is_valid():
			update_cb.call())

func _key(pos: Vector2, s: String, w: float) -> ColorRect:
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
	return k

func _hint(pos: Vector2, s: String, key_name: String) -> void:
	var l := _text(stage, s, 17, WHITE, pos, serif)
	l.size = Vector2(110, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	main_only.append(l)
	main_only.append(_key(pos + Vector2(122, 1), key_name, 46))

# ---------------- список пунктов ----------------
func _torn(w: float, h: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	# края лежат в своих полосах (левый x < -50, верх и низ -40…w-30, правый > w-16) и идут монотонно —
	# многоугольник не пересекает сам себя; иначе Godot не может его разбить на треугольники и не рисует вовсе
	var x := -40.0
	while x < w - 30.0:                # верхний край
		pts.append(Vector2(x, rng.randf_range(-5.0, 4.0)))
		x += rng.randf_range(9.0, 26.0)
	var y := 0.0
	while y < h:                       # правый край — рваный, клином
		pts.append(Vector2(w + rng.randf_range(-16.0, 26.0) + 40.0 * (1.0 - absf(y / h - 0.5) * 2.0), y))
		y += rng.randf_range(7.0, 15.0)
	x = w - 30.0
	while x > -40.0:                   # нижний край
		pts.append(Vector2(x, h + rng.randf_range(-4.0, 6.0)))
		x -= rng.randf_range(9.0, 26.0)
	y = h
	while y > 0.0:                     # левый край
		pts.append(Vector2(-60.0 + rng.randf_range(-22.0, 10.0), y))
		y -= rng.randf_range(8.0, 16.0)
	return pts

func _build_list() -> void:
	list = Control.new()
	# список слов заменён телевизорами студии: строки остались невидимыми зонами нажатия поверх экранов
	# (их место каждый кадр берётся из studio.screen_rect)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(list)
	main_only.append(list)
	band = Polygon2D.new()
	band.color = WHITE
	band.material = worn
	band.visible = false
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
		elif ITEMS[i].size() > 2:
			sub = _text(root, String(ITEMS[i][2]), 15, INK, Vector2(40, size * 1.06))
		lab.visible = false
		mark.visible = false
		if sub != null:
			sub.visible = false
		rows.append({"root": root, "label": lab, "mark": mark, "sub": sub, "w": w, "h": size})
		root.mouse_entered.connect(func(): if panel == null and not modes.visible: _select(i, true, "hover"))
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and panel == null and not modes.visible:
				_select(i)
				_activate())
		y += size * (1.42 if sub != null else 1.16)

func _enabled(i: int) -> bool:
	return i != 0 or has_save

func _select(i: int, sound := true, kind := "move") -> void:
	if i != sel and sound:
		main.ui(kind, 1.0 + (2 - i) * 0.04)      # ниже по списку — чуть ниже звук
	sel = i
	studio.select(i)
	info.text = ITEMS[i][1] if _enabled(i) else "Сохранения пока нет — начни новую игру."
	var r: Dictionary = rows[i]
	var root: Control = r["root"]
	var h: float = float(r["h"]) * (1.5 if r["sub"] != null else 1.14)
	band.polygon = _torn(float(r["w"]) + 150.0, h, 7 + i)
	band.position = Vector2(-60.0, root.position.y + float(r["h"]) * 0.04)
	band.scale = Vector2(0.9, 1.0)
	var tw := band.create_tween()
	tw.tween_property(band, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for k in rows.size():
		var on := k == i
		var e := _enabled(k)
		var col := INK if on else (WHITE if k <= 1 else SILVER)
		if not e:
			col = Color(0.3, 0.31, 0.33) if on else Color(0.32, 0.33, 0.35)
		(rows[k]["label"] as Label).add_theme_color_override("font_color", col)
		(rows[k]["label"] as Label).material = null if on else worn
		(rows[k]["mark"] as Polygon2D).color = INK if on else GREY
		(rows[k]["mark"] as Polygon2D).scale = Vector2.ONE * (1.3 if on else 0.8)
		if rows[k]["sub"] != null:
			(rows[k]["sub"] as Label).add_theme_color_override("font_color", Color(0.15, 0.15, 0.17) if on else GREY)

## Запуск игры: нажатый пункт вспыхивает и вытягивается, остальное меню гаснет, затем общий переход (main.cinematic_start).
func launch(from_save: bool, chapter := -1) -> void:
	if launching:
		return
	var line := ("Глава %d · %s" % [chapter_no(), chapter_name(chapter_no() - 1)]) if from_save else "Глава 1 · %s" % chapter_name(0)
	await _launch_fx()
	main.cinematic_start(from_save, chapter, line)

## Тренировочная арена: тот же уход меню, затем main.cinematic_training
func launch_training() -> void:
	if launching:
		return
	_close()
	await _launch_fx()
	main.cinematic_training(train_hero, train_style)

func _launch_fx() -> void:
	launching = true
	main.ui("launch")
	if bed != null:
		bed.create_tween().tween_property(bed, "volume_db", -60.0, 0.8)
	var tw := create_tween().set_parallel(true)
	var b: Polygon2D = band
	if modes.visible:
		b = modes.cards[modes.sel]["band"]      # запуск с экрана режимов: вспыхивает карточка режима
	if not modes.visible:
		studio.flash(sel)
	b.modulate = Color(1.6, 1.6, 1.6)
	tw.tween_property(b, "modulate", Color.WHITE, 0.3)
	tw.tween_property(b, "scale", Vector2(1.22, 1.12), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in rows.size():
		if k != sel:
			tw.tween_property(rows[k]["root"], "modulate:a", 0.0, 0.25).set_delay(0.04 * k)
	for c in stage.get_children():
		if c != list and c != modes and c is CanvasItem:
			tw.tween_property(c, "modulate:a", 0.0, 0.45).set_delay(0.1)
	if modes.visible:
		for k in modes.cards.size():
			if k != modes.sel:
				tw.tween_property(modes.cards[k]["root"], "modulate:a", 0.0, 0.25).set_delay(0.04 * k)
		tw.tween_property(modes, "modulate:a", 0.0, 0.45).set_delay(0.12)
	tw.tween_property(info, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.32).timeout

func _activate() -> void:
	if launching:
		return
	if not _enabled(sel):
		main.ui("deny")
		return
	if String(ITEMS[sel][0]) != "CONTINUE":       # у CONTINUE свой звук — запуск
		main.ui("confirm")
	match String(ITEMS[sel][0]):
		"CONTINUE":
			if has_save:
				launch(true)
		"PLAY":
			open_modes()
		"SETTINGS":
			_open_settings()
		"EXTRAS":
			_open_extras()
		"EXIT":
			get_tree().quit()

# ---------------- выбор режима ----------------
## PLAY: главный список, логотип и герои уходят, выезжает экран режимов
func open_modes(start := -1) -> void:
	_close()
	for n in main_only:
		var c := n as CanvasItem
		c.create_tween().tween_property(c, "modulate:a", 0.0, 0.18)
	main.ui("open")
	modes.open(start)

## назад на главный список
func close_modes() -> void:
	_close()
	modes.close()
	for n in main_only:
		var c := n as CanvasItem
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25)
	_select(sel, false)
	main.ui("back")

## что делает выбранный режим
func open_mode(id: String) -> void:
	match id:
		"story":
			_open_story()
		"training":
			_open_training()
		"race":
			open_race()
		"microloans":
			_open_microloans()
		"five_nights":
			_open_five_nights()

## Мини-игры со своей сценой (main.MINIGAMES): тот же уход меню, что у режимов, затем main.cinematic_minigame
func launch_minigame(id: String, opt := {}) -> void:
	if launching:
		return
	_close()
	await _launch_fx()
	main.cinematic_minigame(id, opt)

## 5 НОЧЕЙ С ПАХАНОМ: экран режима, как у остальных; внутри игры — свой терминал (NEW GAME, NIGHT SELECT…)
func _open_five_nights() -> void:
	var beaten: Array = FNSave.v("beaten")
	var lines: Array = ["Ночная смена в «Облаке»: камеры, двери, свет, вентиляция и энергия — до шести утра."]
	lines.append("Пройдено ночей: %d из 5%s" % [beaten.filter(func(n): return int(n) < 5).size(), " · открыта НОЧЬ 6" if bool(FNSave.v("night6")) else ""])
	lines.append("Хоррор: лучше играть в наушниках — по звуку слышно, откуда идут.")
	_open("5 НОЧЕЙ С ПАХАНОМ", lines, [["ЗАСТУПИТЬ НА СМЕНУ", func(): launch_minigame("five_nights")], ["НАЗАД", _close]])

## ПАХАН НАБРАЛ МИКРОЗАЙМОВ: продолжить неделю или начать новую (своё сохранение, кампания не трогается)
func _open_microloans() -> void:
	var lines: Array = []
	var acts: Array = []
	var all := MLSave.load_all()
	if MLSave.has_run():
		var r: Dictionary = all["run"]
		var debt := 0
		for l in r.get("loans", []):
			if String((l as Dictionary).get("status", "")) != "closed":
				debt += int(ceil(float((l as Dictionary).get("balance", 0.0))))
		lines.append("Неделя идёт: день %d из %d · на руках %d ₽ · долг %d ₽" % [int(r.get("day", 1)), MLData.DAYS, int(r.get("money", 0)), debt])
		acts.append(["ПРОДОЛЖИТЬ", func(): launch_minigame("microloans", {"continue": true})])
	else:
		lines.append("Пахан набрал микрозаймов в четырёх конторах сразу. Семь дней, чтобы выбраться.")
	var ends: Dictionary = all.get("endings", {})
	lines.append("Концовок открыто: %d из %d" % [ends.size(), MLData.ENDINGS.size()])
	acts.append(["НОВАЯ НЕДЕЛЯ", func(): launch_minigame("microloans", {"continue": false})])
	acts.append(["НАЗАД", _close])
	_open("ПАХАН НАБРАЛ МИКРОЗАЙМОВ", lines, acts)

## Гонки на пылесосах: меню гонок — race_menu.gd (RaceMenu), гонка — race.gd через main.cinematic_race
func race_ready() -> bool:
	return true

func race_status() -> String:
	return ""

func open_race(start := 2) -> void:
	RaceMenu.open(self, start)

## Сетевая гонка: экран ONLINE RACE (race_lobby.gd), сеть — main.race_net (race_net.gd)
func open_online() -> void:
	if online == null:
		online = RaceLobby.new()
		online.setup(self)
		stage.add_child(online)
	if main.net_msg != "":
		online.msg_text = main.net_msg
		main.net_msg = ""
	online.open()

## Гонка: тот же уход меню, что у других режимов, затем main.cinematic_race
func launch_race(cfg: Dictionary) -> void:
	if launching:
		return
	_close()
	await _launch_fx()
	main.cinematic_race(cfg)

## STORY MODE: продолжить, начать заново, загрузить — те же функции, что были в главном списке
func _open_story() -> void:
	var lines: Array = []
	var acts: Array = []
	if has_save:
		lines.append("Сохранение: глава %d · %s · шаг %d · опыт %d" % [chapter_no(), chapter_name(chapter_no() - 1), int(save.get("step", 0)) + 1, int(save.get("xp", 0))])
		acts.append(["CONTINUE", func(): launch(true)])
	else:
		lines.append("Сохранения пока нет — начни новую игру. Игра сохраняется сама после каждого шага главы.")
	acts.append(["NEW GAME", _story_new])
	acts.append(["LOAD GAME", _open_load])
	acts.append(["НАЗАД", _close])
	_open("STORY MODE", lines, acts)

func _story_new() -> void:
	if has_save:
		_open("NEW GAME", ["Сохранение будет перезаписано:", "Глава %d · %s" % [chapter_no(), chapter_name(chapter_no() - 1)], "Начать заново с первой главы?"],
			[["НАЧАТЬ ЗАНОВО", func(): launch(false, 0)], ["ОТМЕНА", _back_story]], 1)
		panel_back = _back_story
	else:
		launch(false, 0)

## назад из NEW GAME / LOAD GAME — на экран сюжета, а не на экран режимов
func _back_story() -> void:
	_open_story()
	_panel_select(1 if has_save else 0, false)

# ---------------- экраны ----------------
## Экран поверх меню: тёмная рваная карточка. lines — строки текста; actions — список элементов:
##   ["#ЗАГОЛОВОК"]                      — подзаголовок раздела (не выбирается),
##   [текст или функция текста, действие] — пункт (Enter / ЛКМ),
##   [функция текста, null, изменение]    — настройка: A/D или ←/→ меняют значение, Enter — следующее.
## Длинные списки прокручиваются, выбранный пункт всегда виден.
func _open(title: String, lines: Array, actions: Array, start := 0) -> VBoxContainer:
	_close()
	panel_back = Callable()
	panel = Control.new()
	panel.size = STAGE
	stage.add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.size = STAGE
	panel.add_child(shade)
	var card := Polygon2D.new()
	card.polygon = _torn(700.0, 560.0, 91)
	card.color = Color(0.05, 0.05, 0.06, 0.97)
	card.position = Vector2(120, 230)
	panel.add_child(card)
	var edge := Line2D.new()
	edge.points = card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	card.add_child(edge)
	var head := _text(panel, title, 64, WHITE, Vector2(120, 240), serif, true)
	head.rotation = deg_to_rad(-2.0)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(126, 334)
	scroll.size = Vector2(670, 418)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(650, 0)
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)
	for s in lines:
		box.add_child(_para(String(s), 17, SILVER))
	panel_rows = []
	for a in actions:
		if a[0] is String and String(a[0]).begins_with("#"):
			var h := _para(String(a[0]).substr(1), 15, GREY)
			h.custom_minimum_size = Vector2(0, 30)
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			box.add_child(h)
			continue
		var i := panel_rows.size()
		var l2 := Label.new()
		l2.add_theme_font_override("font", serif)
		l2.add_theme_font_size_override("font_size", 27)
		l2.mouse_filter = Control.MOUSE_FILTER_STOP
		l2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.add_child(l2)
		panel_rows.append({"label": l2, "text": a[0], "act": a[1] if a.size() > 1 else null, "adj": a[2] if a.size() > 2 else null})
		l2.mouse_entered.connect(func(): _panel_select(i, true, "hover"))
		l2.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
				_panel_select(i)
				_panel_activate(-1 if e.button_index == MOUSE_BUTTON_RIGHT else 1))
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.14)
	main.ui("open")
	_panel_select(clampi(start, 0, max(0, panel_rows.size() - 1)), false)
	info.text = "Enter — выбрать · A/D — изменить значение · Esc — назад"
	return box

func _para(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", tech)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	return l

func _panel_select(i: int, sound := true, kind := "move") -> void:
	if panel_rows.is_empty():
		return
	if sound and i != panel_sel:
		main.ui(kind)
	panel_sel = i
	for k in panel_rows.size():
		var r: Dictionary = panel_rows[k]
		var l: Label = r["label"]
		var txt = r["text"]
		var s: String = String(txt.call()) if txt is Callable else String(txt)
		l.text = ("▶ " if k == i else "   ") + s + ("   ◀ ▶" if k == i and r["adj"] != null else "")
		l.add_theme_color_override("font_color", WHITE if k == i else GREY)
	var cur: Label = panel_rows[i]["label"]
	var sc := cur.get_parent().get_parent() as ScrollContainer
	if sc != null:
		sc.ensure_control_visible.call_deferred(cur)

## dir: +1 — Enter / вправо, −1 — влево (только для настроек).
func _panel_activate(dir := 1) -> void:
	if launching:
		return
	if panel_rows.is_empty():
		return
	var r: Dictionary = panel_rows[panel_sel]
	if r["adj"] != null:
		main.ui("value", 1.08 if dir > 0 else 0.92)
		(r["adj"] as Callable).call(dir)
	elif r["act"] != null and dir > 0:
		main.ui("back" if r["text"] is String and String(r["text"]) == "НАЗАД" else "confirm")
		(r["act"] as Callable).call()
	elif dir < 0:
		main.ui("deny")
	if panel != null:
		_panel_select(panel_sel, false)

func _close() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
		panel_rows = []
		info.text = ITEMS[sel][1] if _enabled(sel) else "Сохранения пока нет — начни новую игру."
		if modes != null and modes.visible:
			info.text = modes.desc_text.text

func _open_load() -> void:
	if not has_save:
		_open("LOAD GAME", ["Сохранений пока нет.", "Игра сохраняется сама — в одну ячейку — после каждого пройденного шага главы."], [["НАЗАД", _back_story]])
		panel_back = _back_story
		return
	var up: Dictionary = save.get("up", {})
	_open("LOAD GAME", [
		"ЯЧЕЙКА 01 — единственная: игра хранит одно сохранение.",
		"Глава %d · %s" % [chapter_no(), chapter_name(chapter_no() - 1)],
		"Шаг главы: %d   ·   Прослушивания: %d" % [int(save.get("step", 0)) + 1, int(save.get("xp", 0))],
		"Улучшения — здоровье: %d · сила: %d · ад-либ madk1d: %d" % [int(up.get("hp", 0)), int(up.get("dmg", 0)), int(up.get("q", 0))],
	], [["ЗАГРУЗИТЬ", func(): launch(true)], ["НАЗАД", _back_story]])
	panel_back = _back_story

## Тренировочная арена: выбор героя и стиля (по умолчанию — прошлый выбор из файла арены), зоны — описанием
var train_hero := ""
var train_style := ""
func _open_training() -> void:
	if train_hero == "":
		var d := Training.prefs()
		train_hero = String(d["hero"])
		train_style = String(d["style"])
	_open("TRAINING ARENA", [
		"Отдельный режим: сюжет не идёт, опыт не начисляется, сохранение игры не меняется.",
		"Зоны: A — манекен · B — замахи (уклонение, блок, парирование) · C — воздух · D — босс с настоящими приёмами · E — свободный бой.",
		"В арене F1 — панель: герой, стиль, зона, враги, здоровье, перезарядки, цифры урона, упражнения. Выход — пауза → В ГЛАВНОЕ МЕНЮ.",
	], [
		[func(): return "ГЕРОЙ: " + ("ПАХАН" if train_hero == "pahan" else "MADK1D"), null, _train_hero_step],
		[func(): return "СТИЛЬ: " + String(Styles.by_id(train_style).title).to_upper(), null, _train_style_step],
		["НАЧАТЬ ТРЕНИРОВКУ", func(): launch_training()],
		["НАЗАД", _close]], 2)

func _train_hero_step(_d: int) -> void:
	train_hero = "madk1d" if train_hero == "pahan" else "pahan"
	train_style = String(Training.HERO_STYLES[train_hero][0])

func _train_style_step(d: int) -> void:
	var list: Array = Training.HERO_STYLES[train_hero]
	train_style = String(list[posmod(list.find(train_style) + d, list.size())])

func _open_settings() -> void:
	var acts: Array = []
	for r in Opts.rows(get_window(), main.audio, null):
		acts.append([r[0]] if r.size() == 1 else [r[0], null, r[1]])
	acts.append(["#УПРАВЛЕНИЕ"])
	acts.append(["#WASD — бег · мышь — камера · ЛКМ — удары · ПКМ — добивание · E — Heat · Пробел — прыжок · Shift — уклонение · C — блок · Tab — смена героя · T — помощь напарника · G — Team Overdrive · Q — ад-либ madk1d · R — ПЕРЕГРУЗ · ↑ — iPod · Esc — пауза · F11 — полный экран"])
	acts.append(["НАЗАД", _close])
	_open("SETTINGS", [], acts)

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

# ---------------- ввод и жизнь ----------------
func _unhandled_input(e: InputEvent) -> void:
	if launching:
		return
	if capture.is_valid() and e is InputEventKey and e.pressed and not e.echo:
		var c := capture
		capture = Callable()
		c.call(e)
		get_viewport().set_input_as_handled()
		return
	var k := 0
	if e is InputEventKey:
		if not e.pressed or e.echo:
			return
		k = e.physical_keycode
	elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
		# геймпад: встроенные действия ui_* (крестовина, левый стик, A — выбрать, B — назад)
		if e.is_action_pressed("ui_up"):
			k = KEY_UP
		elif e.is_action_pressed("ui_down"):
			k = KEY_DOWN
		elif e.is_action_pressed("ui_left"):
			k = KEY_LEFT
		elif e.is_action_pressed("ui_right"):
			k = KEY_RIGHT
		elif e.is_action_pressed("ui_accept"):
			k = KEY_ENTER
		elif e.is_action_pressed("ui_cancel"):
			k = KEY_ESCAPE
		else:
			return
	else:
		return
	var up := k == KEY_W or k == KEY_UP
	var down := k == KEY_S or k == KEY_DOWN
	var ok := k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	if panel != null:
		if up and not panel_rows.is_empty():
			_panel_select(posmod(panel_sel - 1, panel_rows.size()))
		elif down and not panel_rows.is_empty():
			_panel_select(posmod(panel_sel + 1, panel_rows.size()))
		elif ok or k == KEY_D or k == KEY_RIGHT:
			_panel_activate(1)
		elif k == KEY_A or k == KEY_LEFT:
			_panel_activate(-1)
		elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
			main.ui("back")
			if panel_back.is_valid():
				panel_back.call()
			else:
				_close()
		get_viewport().set_input_as_handled()
		return
	if online != null and online.visible:
		if online.handle_key(k):
			get_viewport().set_input_as_handled()
		return
	if modes.visible:
		if up or k == KEY_A or k == KEY_LEFT:
			modes.select(modes.sel - 1)
		elif down or k == KEY_D or k == KEY_RIGHT:
			modes.select(modes.sel + 1)
		elif ok:
			modes.activate()
		elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
			close_modes()
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
	if studio != null and stage != null:
		studio.back_to = 1.0 if (modes != null and modes.visible) or panel != null else 0.0
		for i in rows.size():
			var rc: Rect2 = studio.screen_rect(i)
			var root: Control = rows[i]["root"]
			root.position = (rc.position - stage.position) / stage.scale.x
			root.size = rc.size / stage.scale.x
	if chars == null or modes.visible:
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

## Рендер героев в PNG для установщика (tools/setup): те же модели и свет, что в меню, сразу в чёрно-белом с постеризацией.
func _render_heroes(path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	var img := hero_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := smoothstep(0.04, 0.8, c.r * 0.3 + c.g * 0.59 + c.b * 0.11)
			l = lerpf(l, floorf(l * 5.0 + 0.5) / 5.0, 0.55)
			img.set_pixel(x, y, Color(l, l, l, c.a))
	img.save_png(path)
	print("MENU render ", path)
	get_tree().quit()
