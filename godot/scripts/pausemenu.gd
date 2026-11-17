## Меню паузы: чёрно-белая композиция по утверждённому референсу.
## Слева — шесть огромных наклонённых названий вкладок, сверху по центру — логотип, справа — настоящий Пахан в игровом мире:
## пауза замораживает его в той позе, в какой застала, а игровая камера плавно наезжает на него (см. «камера» ниже).
## Справа внизу — две белые панели с настоящими здоровьем и прослушиваниями, подсказки управления.
## Игровой мир останавливается сразу (game.set_paused), меню раскрывается слоями, пока едет камера.
## Вкладки показывают только то, что в игре есть: СТАТУС, РАЗВИТИЕ, ГРУППА, ЗАДАНИЕ, МУЗЫКА, СИСТЕМА.
## Все будущие системы прокачки добавляются во вкладку РАЗВИТИЕ (см. docs/PROGRESSION_MENU_INTEGRATION.md).
class_name PauseMenu
extends Control

const STAGE := Vector2(1600, 900)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const RED := Color(0.62, 0.08, 0.1)          # единственный цветной акцент — метка у выбранной вкладки
# вкладка: [название, позиция, размер шрифта, наклон в градусах]
const TABS := [
	["СТАТУС", Vector2(430, -6), 84, 20.0],
	["РАЗВИТИЕ", Vector2(215, 84), 100, 12.0],
	["ГРУППА", Vector2(40, 214), 118, 4.0],
	["ЗАДАНИЕ", Vector2(14, 372), 132, -1.5],
	["МУЗЫКА", Vector2(150, 566), 112, -13.0],
	["СИСТЕМА", Vector2(380, 716), 92, -23.0],
]
const HINTS := ["Здоровье, СВЭГ, перегруз, глава", "Улучшения за прослушивания", "Пахан и madk1d", "Что сейчас делать", "iPod: трек и управление", "Настройки и выход"]
## Подложка меню: замерший мир почти без цвета, слева (под вкладками) уходит в черноту, справа, где Пахан, светлее;
## поверх — редкие диагональные штрихи и плёночное зерно.
const PAUSE_BG := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen, uv, 0.0).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 col = mix(c, vec3(l), 0.85);
	float left = 1.0 - smoothstep(0.12, 0.62, uv.x);
	col *= 1.0 - (0.3 + 0.6 * left);
	vec2 q = (uv - vec2(0.68, 0.48)) * vec2(1.6, 1.0);
	col *= 1.0 - smoothstep(0.35, 1.0, length(q)) * 0.45;
	float d = uv.x * 0.93 - uv.y * 0.36;
	col += 0.03 * step(0.985, fract(d * 9.0 + h(vec2(floor(d * 9.0), 3.0)) * 0.2));
	col += (h(uv * 900.0 + floor(TIME * 24.0)) - 0.5) * 0.06;
	COLOR = vec4(col, 1.0);
}
"""

var game
var stage: Control
var bg: ColorRect
var bg_mat: ShaderMaterial
var serif: SystemFont
var tech: SystemFont
var worn: ShaderMaterial
var tabs: Array = []            # [{root, label, band, tag}]
var layers: Array = []          # элементы в порядке появления: [узел, исходная позиция]
var sel := 3
var is_open := false
var closing := false
var card: Control
var card_live: Array = []       # функции, обновляющие открытую страницу каждый кадр
var card_body: VBoxContainer
var buddy_vp: SubViewport       # портрет madk1d для страницы «Группа»
var card_rows: Array = []       # [{label, text, act, adj}]
var card_sel := 0
var hp_text: Label
var hp_fill: ColorRect
var xp_text: Label
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	worn = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PAUSE_BG
	bg_mat.shader = sh
	bg.material = bg_mat
	add_child(bg)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_rings()
	char_mat = ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = Menu.CHAR_SHADER
	char_mat.shader = cs
	_build_logo()
	_build_tabs()
	_build_panels()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	bg.position = Vector2.ZERO
	bg.size = vs
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func _text(parent: Node, s: String, size: int, col: Color, pos: Vector2, f: Font = null, rough := false) -> Label:
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

static func torn(w: float, h: float, seed_v: int, tail := 60.0) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	var x := -tail
	while x < w:
		pts.append(Vector2(x, r.randf_range(-5.0, 4.0)))
		x += r.randf_range(9.0, 26.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + r.randf_range(-14.0, 22.0) + 30.0 * (1.0 - absf(y / h - 0.5) * 2.0), y))
		y += r.randf_range(7.0, 15.0)
	x = w
	while x > -tail:
		pts.append(Vector2(x, h + r.randf_range(-4.0, 6.0)))
		x -= r.randf_range(9.0, 26.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(-tail + r.randf_range(-20.0, 10.0), y))
		y -= r.randf_range(8.0, 16.0)
	return pts

func _layer(n: CanvasItem) -> void:
	layers.append([n, (n as Node).get("position")])

# ---------------- композиция ----------------
func _build_rings() -> void:
	# большие дуги и клин за героем — как круги и геометрия на референсе
	var g := Node2D.new()
	stage.add_child(g)
	for d in [[Vector2(1130, 470), 420.0, 2.0, 0.5], [Vector2(1180, 430), 300.0, 5.0, 0.7], [Vector2(560, 560), 360.0, 1.5, 0.3]]:
		var l := Line2D.new()
		var pts := PackedVector2Array()
		for i in 97:
			var a := TAU * i / 96.0
			pts.append((d[0] as Vector2) + Vector2(cos(a), sin(a)) * float(d[1]))
		l.points = pts
		l.width = float(d[2])
		l.default_color = Color(1, 1, 1, float(d[3]))
		g.add_child(l)
	var wedge := Polygon2D.new()
	wedge.polygon = PackedVector2Array([Vector2(1330, 0), Vector2(1600, 0), Vector2(1600, 130), Vector2(1540, 96), Vector2(1560, 250), Vector2(1450, 120)])
	wedge.color = WHITE
	wedge.material = worn
	g.add_child(wedge)
	_layer(g)

func _build_logo() -> void:
	var logo := Control.new()
	logo.position = Vector2(770, 22)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(logo)
	var a := _text(logo, "GOD OF", 74, WHITE, Vector2(34, 0), serif, true)
	a.size = Vector2(420, 80)
	_text(logo, "GRIMERKA", 78, WHITE, Vector2(0, 66), serif, true)
	_layer(logo)

func _build_tabs() -> void:
	for i in TABS.size():
		var d: Array = TABS[i]
		var size: int = d[2]
		var root := Control.new()
		root.position = d[1]
		root.rotation = deg_to_rad(float(d[3]))
		var w: float = serif.get_string_size(d[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		root.size = Vector2(w + 20, size * 1.1)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		stage.add_child(root)
		var band := Polygon2D.new()
		band.polygon = torn(w + 60.0, size * 1.02, 31 + i, 40.0)
		band.position = Vector2(0, size * 0.1)
		band.color = WHITE
		band.material = worn
		root.add_child(band)
		var lab := _text(root, d[0], size, WHITE, Vector2.ZERO, serif, true)
		var tag := Polygon2D.new()
		tag.polygon = torn(190.0, 34.0, 60 + i, 10.0)
		tag.color = RED
		tag.position = Vector2(w * 0.55, size * 0.98)
		tag.rotation = deg_to_rad(-5.0)
		root.add_child(tag)
		var tl := _text(tag, "ОТКРЫТЬ  ⏎", 20, WHITE, Vector2(18, 3), serif)
		tl.size = Vector2(170, 28)
		tabs.append({"root": root, "label": lab, "band": band, "tag": tag})
		root.mouse_entered.connect(func(): if card == null and is_open and not closing: _select(i))
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and card == null and is_open and not closing:
				_select(i)
				_open_page(i))
		_layer(root)

func _build_panels() -> void:
	# две белые шероховатые панели с настоящими значениями
	for i in 2:
		var p := Control.new()
		p.position = Vector2(1150, 716 + i * 60)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(p)
		var plate := Polygon2D.new()
		plate.polygon = PackedVector2Array([Vector2(26, 0), Vector2(420, 0), Vector2(420, 50), Vector2(0, 50)])
		plate.color = WHITE
		plate.material = worn
		p.add_child(plate)
		_text(p, "ЗДОРОВЬЕ" if i == 0 else "ПРОСЛУШИВАНИЯ", 12, INK, Vector2(44, 3), serif)
		var mark := Polygon2D.new()
		mark.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)]) if i == 0 else PackedVector2Array([Vector2(-7, -9), Vector2(9, 0), Vector2(-7, 9)])
		mark.color = INK
		mark.position = Vector2(62, 33)
		p.add_child(mark)
		var sep := ColorRect.new()
		sep.color = GREY
		sep.position = Vector2(86, 18)
		sep.size = Vector2(2, 26)
		p.add_child(sep)
		var val := _text(p, "", 34, INK, Vector2(100, 8), serif)
		val.size = Vector2(300, 40)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 0:
			hp_text = val
			var back := ColorRect.new()
			back.color = Color(0, 0, 0, 0.25)
			back.position = Vector2(100, 43)
			back.size = Vector2(300, 4)
			p.add_child(back)
			hp_fill = ColorRect.new()
			hp_fill.color = INK
			hp_fill.position = Vector2(100, 43)
			hp_fill.size = Vector2(300, 4)
			p.add_child(hp_fill)
		else:
			xp_text = val
		_layer(p)
	var hints := Control.new()
	hints.position = Vector2(1210, 846)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hints)
	var x := 0.0
	for h in [["Enter", "Выбрать"], ["Esc", "Назад"]]:
		var k := ColorRect.new()
		k.color = Color(0.86, 0.87, 0.89)
		k.position = Vector2(x, 0)
		k.size = Vector2(52, 24)
		hints.add_child(k)
		var kl := _text(k, h[0], 13, INK, Vector2.ZERO)
		kl.size = k.size
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text(hints, h[1], 18, WHITE, Vector2(x + 60, -1), serif)
		x += 170.0
	_layer(hints)

# ---------------- камера: наезд на настоящего Пахана ----------------
## Мир стоит (SceneTree.paused), Пахан замер ровно в той позе, в какой его застала пауза: аниматор и физика стоят вместе с миром.
## Игровая камера в паузе не обновляется, поэтому её ведёт меню (этот узел работает и на паузе): по дуге вокруг груди Пахана
## — от того места, где камера была, к крупному плану спереди-сбоку. Пахан смещён вправо (h_offset), слева — вкладки.
## При закрытии та же дуга назад, а в конце камере возвращаются точные локальное положение, угол обзора и смещения.
const T_IN := 0.7
const T_OUT := 0.45
const CAM_DIST := 2.6       # до груди Пахана в крупном плане, м
const CAM_HIGH := 0.18      # чуть выше груди
const CAM_FOV := 50.0
const CAM_SIDE := -0.8      # h_offset: Пахан в правой части кадра
const SIDE_ANGLE := 1.0     # насколько сбоку от лица, рад
var state := "closed"       # closed → opening → open → closing → closed
var cam_k := 0.0            # 0 — игровая камера, 1 — крупный план
var cam_taken := false
var cam_home := Transform3D()
var cam_from := Transform3D()
var cam_fov := 62.0
var cam_h := 0.0
var cam_v := 0.0
var pivot_pt := Vector3.ZERO
var orbit := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # угол, радиус, высота — у игровой камеры и у крупного плана
var cam_tw: Tween
var char_mat: ShaderMaterial    # монохромный материал для портрета madk1d на странице «Группа»

static func _ease(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _take_camera() -> void:
	var cam: Camera3D = game.cam
	cam_home = cam.transform
	cam_from = cam.global_transform
	cam_fov = cam.fov
	cam_h = cam.h_offset
	cam_v = cam.v_offset
	var pl = game.player
	pivot_pt = pl.global_position + Vector3(0, 1.05, 0)
	var rel := cam_from.origin - pivot_pt
	var a0 := atan2(rel.x, rel.z)
	var f: float = pl.face
	var al := f + SIDE_ANGLE
	var ar := f - SIDE_ANGLE
	var a1 := al if absf(angle_difference(a0, al)) <= absf(angle_difference(a0, ar)) else ar
	orbit = [a0, Vector2(rel.x, rel.z).length(), rel.y, a1, CAM_DIST, CAM_HIGH]
	cam_taken = true

## Где камера при k (0..1): по дуге вокруг груди, взгляд из исходного поворачивается к груди; стены не пробивает.
func cam_pose(k: float) -> Transform3D:
	var e := _ease(k)
	var a: float = float(orbit[0]) + angle_difference(float(orbit[0]), float(orbit[3])) * e
	var r: float = lerpf(float(orbit[1]), float(orbit[4]), e)
	var hh: float = lerpf(float(orbit[2]), float(orbit[5]), e)
	var pos := pivot_pt + Vector3(sin(a) * r, hh, cos(a) * r)
	if e > 0.0:
		var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(pivot_pt, pos)
		q.exclude = [game.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			var dir := (pos - pivot_pt).normalized()
			pos = pivot_pt + dir * maxf(0.9, ((hit["position"] as Vector3) - pivot_pt).length() - 0.25)
	if e <= 0.0:
		return cam_from
	var look := Basis.looking_at(pivot_pt + Vector3(0, -0.05, 0) - pos, Vector3.UP)
	var qb := cam_from.basis.get_rotation_quaternion().slerp(look.get_rotation_quaternion(), e)
	return Transform3D(Basis(qb), pos)

func _apply_camera() -> void:
	if not cam_taken or game == null or not is_instance_valid(game.cam):
		return
	var e := _ease(cam_k)
	game.cam.global_transform = cam_pose(cam_k)
	game.cam.fov = lerpf(cam_fov, CAM_FOV, e)
	game.cam.h_offset = lerpf(cam_h, CAM_SIDE, e)
	game.cam.v_offset = lerpf(cam_v, 0.0, e)

func _give_camera_back() -> void:
	if cam_taken and game != null and is_instance_valid(game.cam):
		game.cam.transform = cam_home
		game.cam.fov = cam_fov
		game.cam.h_offset = cam_h
		game.cam.v_offset = cam_v
	cam_taken = false
	cam_k = 0.0

func _cam_to(k: float, sec: float) -> Tween:
	if is_instance_valid(cam_tw):
		cam_tw.kill()
	cam_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cam_tw.tween_property(self, "cam_k", k, maxf(0.05, sec))
	return cam_tw

# ---------------- открыть / закрыть ----------------
func open() -> void:
	if state == "opening" or state == "open":
		return
	var resume := state == "closing"            # Esc посреди закрытия: разворачиваемся обратно
	state = "opening"
	is_open = true
	closing = false
	visible = true
	_close_card()
	if not resume:
		_take_camera()
		game.hud_root.visible = false
		game.main.sfx("sfx_ui", -8.0, 0.62)
	_cam_to(1.0, T_IN * (1.0 - cam_k)).tween_callback(func(): if state == "opening": state = "open")
	# интерфейс: слоями, каждый следующий на 40 мс позже; пока камера едет
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	bg.modulate.a = 0.0 if not resume else bg.modulate.a
	tw.tween_property(bg, "modulate:a", 1.0, 0.4).set_delay(0.0 if resume else 0.3)      # мир темнеет к концу наезда, пока Пахан ещё не справа
	for i in layers.size():
		var n: CanvasItem = layers[i][0]
		var home: Vector2 = layers[i][1]
		if not resume:
			n.modulate.a = 0.0
			n.set("position", home + Vector2(-34.0 if home.x < 700.0 else 34.0, 0.0))
		tw.tween_property(n, "modulate:a", 1.0, 0.18).set_delay(0.12 + i * 0.04)
		tw.tween_property(n, "position", home, 0.22).set_delay(0.12 + i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_select(sel, false)
	_refresh()

## Закрыть с анимацией: меню уходит, камера возвращается по той же дуге, игра продолжается с того же кадра.
func close() -> void:
	if not is_open or closing:
		return
	state = "closing"
	closing = true
	_close_card()
	game.main.sfx("sfx_ui", -10.0, 0.8)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for i in layers.size():
		var n: CanvasItem = layers[layers.size() - 1 - i][0]
		tw.tween_property(n, "modulate:a", 0.0, 0.14).set_delay(i * 0.018)
	tw.tween_property(bg, "modulate:a", 0.0, 0.3).set_delay(0.08)
	_cam_to(0.0, T_OUT * maxf(0.35, cam_k)).tween_callback(func():
		if state == "closing":
			game.set_paused(false))

## Скрыть сразу, без анимации (вызывает game.set_paused(false)): камера и HUD — на место.
func shut() -> void:
	if is_instance_valid(cam_tw):
		cam_tw.kill()
	_give_camera_back()
	state = "closed"
	is_open = false
	closing = false
	visible = false
	_close_card()
	if game != null and is_instance_valid(game.hud_root):
		game.hud_root.visible = true

# ---------------- вкладки ----------------
func _select(i: int, sound := true) -> void:
	if sound and i != sel:
		game.main.sfx("sfx_ui", -10.0, 1.2)
	sel = i
	for k in tabs.size():
		var on := k == i
		var tb: Dictionary = tabs[k]
		(tb["band"] as Polygon2D).visible = on
		(tb["tag"] as Polygon2D).visible = on
		(tb["label"] as Label).add_theme_color_override("font_color", INK if on else WHITE)
		(tb["label"] as Label).material = null if on else worn
		(tb["root"] as Control).z_index = 2 if on else 0
	((tabs[i]["tag"] as Polygon2D).get_child(0) as Label).text = "ОТКРЫТЬ  ⏎"

func _open_page(i: int) -> void:
	game.main.sfx("sfx_ui")
	var top := _card(TABS[i][0])
	match i:
		0:
			_big(top, "ПАХАН", 46)
			_bar(top, "ЗДОРОВЬЕ", func(): return game.player.hp / game.player.max_hp, func(): return "%d / %d" % [ceili(game.player.hp), int(game.player.max_hp)])
			_bar(top, "СВЭГ", func(): return game.player.swag / 100.0, func(): return "%d / 100" % int(game.player.swag))
			_plate(top, func(): return "ПЕРЕГРУЗ: " + ("идёт, ещё %.0f с" % game.player.rage if game.player.rage > 0.0 else ("готов — [R]" if game.player.swag >= 100.0 else "копится, нужен полный СВЭГ")))
			_line(top, func(): return "▶  %d прослушиваний" % game.xp, 26, WHITE, serif)
			_line(top, func(): return "Глава %d · %s" % [game.ch + 1, String(game.chapter()["name"])], 19, SILVER)
			_rows([["НАЗАД", _close_card]])
		1:
			_line(top, func(): return "▶  %d" % game.xp, 54, WHITE, serif)
			_line(top, func(): return "прослушиваний · осталось улучшений: %d из 15" % (15 - int(game.up["hp"]) - int(game.up["dmg"]) - int(game.up["q"])), 17, SILVER)
			var rows: Array = []
			for r in [["hp", "ЗДОРОВЬЕ +20"], ["dmg", "СИЛА +12% УРОНА"], ["q", "АД-ЛИБ MADK1D −1,5 с"]]:
				var k: String = r[0]
				var nm: String = r[1]
				rows.append([func():
					var lv := int(game.up[k])
					var pips := "■".repeat(lv) + "□".repeat(5 - lv)
					if lv >= 5:
						return "%s   %s   максимум" % [nm, pips]
					return "%s   %s   %d%s" % [nm, pips, game._cost(k), "" if game.xp >= game._cost(k) else "  ✕"],
					func():
						if game.buy_upgrade(k):
							game.main.sfx("sfx_ui", -4.0, 1.4)])
			rows.append(["НАЗАД", _close_card])
			_rows(rows)
			_note("■ — купленный уровень, число — цена следующего, ✕ — не хватает прослушиваний. Покупка не двигает сюжет и не лечит. Сюда же придут деревья навыков, стили и командные способности.")
		2:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 18)
			top.add_child(row)
			var a := VBoxContainer.new()
			a.custom_minimum_size = Vector2(390, 0)
			a.add_theme_constant_override("separation", 4)
			row.add_child(a)
			_big(a, "ПАХАН", 38)
			_line(a, func(): return "герой · Балон VOZDUH · урон ×%.2f" % game.player.dmg_mul, 17, SILVER)
			_bar(a, "ЗДОРОВЬЕ", func(): return game.player.hp / game.player.max_hp, func(): return "%d / %d" % [ceili(game.player.hp), int(game.player.max_hp)], 380.0)
			_big(a, "MADK1D", 38)
			_line(a, func(): return "напарник · действует сам", 17, SILVER)
			_bar(a, "АД-ЛИБ [Q]", func(): return 1.0 - clampf(game.buddy.cd / max(0.1, game.buddy.cd_max), 0.0, 1.0), func(): return "готов" if game.buddy.cd <= 0.0 else "%.0f с" % game.buddy.cd, 380.0)
			row.add_child(_buddy_portrait())
			_rows([["НАЗАД", _close_card]])
		3:
			_line(top, func(): return "ГЛАВА %d" % (game.ch + 1), 18, GREY)
			_big(top, String(game.chapter()["name"]), 40)
			_line(top, func(): return String(game.chapter().get("place", "")), 18, SILVER)
			_line(top, func():
				var n: int = (game.chapter()["steps"] as Array).size()
				var s: int = clampi(game.step, 0, n)
				return "■".repeat(s) + "▣" + "□".repeat(max(0, n - s - 1)) + "   шаг %d из %d" % [s + 1, n], 22, WHITE)
			_plate(top, func(): return "СЕЙЧАС: " + game.objective())
			_rows([["НАЗАД", _close_card]])
		4:
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 20)
			top.add_child(row2)
			row2.add_child(_ipod_art())
			var b := VBoxContainer.new()
			b.custom_minimum_size = Vector2(430, 0)
			b.add_theme_constant_override("separation", 4)
			row2.add_child(b)
			_line(b, func():
				var n: Dictionary = game.ipod.now_playing()
				return (String(n["title"]) if n["has"] else "трек не выбран"), 34, WHITE, serif)
			_line(b, func(): return String(game.ipod.now_playing()["artist"]), 18, SILVER)
			_bar(b, "", func():
				var n: Dictionary = game.ipod.now_playing()
				return float(n["pos"]) / max(1.0, float(n["len"])), func():
				var n: Dictionary = game.ipod.now_playing()
				return "%s / %s" % [_time(float(n["pos"])), _time(float(n["len"]))], 420.0)
			_line(b, func():
				var n: Dictionary = game.ipod.now_playing()
				return ("▶ играет" if n["playing"] else ("Ⅱ пауза" if n["paused"] else "■ остановлен")) + ("   ·   трек %d из %d" % [int(n["index"]) + 1, int(n["count"])] if n["has"] else ""), 17, SILVER)
			_line(b, func(): return "EarPods: " + ("в ушах — слышны только музыка и голоса" if game.ipod.earbuds_in else "не надеты (наденет при открытии iPod, ↑)"), 15, GREY)
			_rows([
				["◀◀  ПРЕДЫДУЩИЙ", func(): game.ipod.pause_step_track(-1)],
				[func(): return "▶ Ⅱ  " + ("ПАУЗА" if game.ipod.now_playing()["playing"] else "ИГРАТЬ"), func(): game.ipod.pause_toggle_play()],
				["СЛЕДУЮЩИЙ  ▶▶", func(): game.ipod.pause_step_track(1)],
				[func(): return "ГРОМКОСТЬ IPOD: %d%%" % roundi(float(game.ipod.volume) * 100.0), null, func(d: int): game.ipod.pause_set_volume(snappedf(float(game.ipod.volume) + 0.05 * d, 0.05))],
				["НАЗАД", _close_card]])
		5:
			var acts: Array = [["ВЕРНУТЬСЯ В ИГРУ", close]]
			for r in Opts.rows(get_window(), game.main.audio, game.ipod):
				acts.append([r[0]] if r.size() == 1 else [r[0], null, r[1]])
			acts.append(["#УПРАВЛЕНИЕ"])
			acts.append(["#WASD — бег · мышь — камера · ЛКМ — удары · ПКМ — добивание · E — Heat · Пробел — прыжок · Shift — уклонение · C — блок · Tab — смена героя · T — помощь напарника · Q — ад-либ · R — ПЕРЕГРУЗ · ↑ — iPod · Esc — пауза · F11 — полный экран"])
			acts.append(["#ИГРА"])
			acts.append(["В ГЛАВНОЕ МЕНЮ", func(): _confirm_menu()])
			acts.append(["НАЗАД", _close_card])
			_rows(acts)

## Подтверждение выхода в главное меню: прогресс сохранён на начало текущего шага.
func _confirm_menu() -> void:
	var top := _card("В МЕНЮ?")
	_line(top, func(): return "Игра сохранена на начало текущего шага главы — «Continue» вернёт сюда.", 18, SILVER)
	_rows([["ОСТАТЬСЯ", func(): _open_page(5)], ["ВЫЙТИ В ГЛАВНОЕ МЕНЮ", func(): game._to_menu()]])

static func _time(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

# ---------------- карточка страницы и её детали ----------------
## Тёмная рваная карточка слева с заголовком. Возвращает верхний блок — туда страница кладёт свою композицию;
## пункты добавляет _rows (прокручиваемый список под ней).
func _card(title: String) -> VBoxContainer:
	_close_card()
	card = Control.new()
	card.size = STAGE
	card.z_index = 10        # поверх выбранной вкладки
	stage.add_child(card)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.size = Vector2(900, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(shade)
	var plate := Polygon2D.new()
	plate.polygon = torn(700.0, 690.0, 91)
	plate.color = Color(0.05, 0.05, 0.06, 0.97)
	plate.position = Vector2(110, 110)
	card.add_child(plate)
	var edge := Line2D.new()
	edge.points = plate.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	plate.add_child(edge)
	var head := _text(card, title, 70, WHITE, Vector2(108, 116), serif, true)
	head.rotation = deg_to_rad(-2.0)
	card_body = VBoxContainer.new()
	card_body.position = Vector2(118, 216)
	card_body.size = Vector2(672, 540)
	card_body.add_theme_constant_override("separation", 8)
	card.add_child(card_body)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	card_body.add_child(top)
	card_live = []
	card_rows = []
	card_sel = 0
	for tb in tabs:                     # плашка и метка выбранной вкладки не торчат из-за карточки
		(tb["band"] as Polygon2D).visible = false
		(tb["tag"] as Polygon2D).visible = false
		(tb["label"] as Label).add_theme_color_override("font_color", WHITE)
	card.modulate.a = 0.0
	card.position = Vector2(-26, 0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.14)
	tw.tween_property(card, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return top

## Пункты страницы. Элемент: ["#ЗАГОЛОВОК"], [текст|функция, действие] или [функция, null, изменение(±1)].
func _rows(actions: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_body.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(650, 0)
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	for a in actions:
		if a[0] is String and String(a[0]).begins_with("#"):
			var h := Label.new()
			h.text = String(a[0]).substr(1)
			h.add_theme_font_override("font", tech)
			h.add_theme_font_size_override("font_size", 15)
			h.add_theme_color_override("font_color", GREY)
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.custom_minimum_size = Vector2(640, 28)
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			box.add_child(h)
			continue
		var i := card_rows.size()
		var l := Label.new()
		l.add_theme_font_override("font", serif)
		l.add_theme_font_size_override("font_size", 27)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.add_child(l)
		card_rows.append({"label": l, "text": a[0], "act": a[1] if a.size() > 1 else null, "adj": a[2] if a.size() > 2 else null})
		l.mouse_entered.connect(func(): _card_select(i))
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
				_card_select(i)
				_card_activate(-1 if e.button_index == MOUSE_BUTTON_RIGHT else 1))
	_refresh()

func _line(parent: Node, fn: Callable, size: int, col: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f if f != null else tech)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	parent.add_child(l)
	card_live.append(func(): l.text = String(fn.call()))
	return l

func _big(parent: Node, s: String, size: int) -> void:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	l.material = worn
	l.clip_text = true
	l.custom_minimum_size = Vector2(300, size * 1.15)
	parent.add_child(l)

func _note(s: String) -> void:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", tech)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", GREY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	card_body.add_child(l)

## Полоса показателя: подпись слева, значение справа, под ними — заполнение.
func _bar(parent: Node, title: String, frac: Callable, text: Callable, w := 650.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 46)
	parent.add_child(c)
	var t := _text(c, title, 15, SILVER, Vector2(0, 2), serif)
	t.size = Vector2(w * 0.5, 20)
	var val := _text(c, "", 24, WHITE, Vector2(w * 0.4, -4), serif)
	val.size = Vector2(w * 0.6, 30)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.16)
	back.position = Vector2(0, 30)
	back.size = Vector2(w, 9)
	c.add_child(back)
	var fill := ColorRect.new()
	fill.color = WHITE
	fill.position = Vector2(0, 30)
	fill.size = Vector2(w, 9)
	fill.material = worn
	c.add_child(fill)
	card_live.append(func():
		val.text = String(text.call())
		fill.size.x = w * clampf(float(frac.call()), 0.0, 1.0))

## Белая рваная плашка с чёрным текстом — для главного на странице.
func _plate(parent: Node, fn: Callable) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(650, 50)
	parent.add_child(c)
	var p := Polygon2D.new()
	p.polygon = torn(630.0, 42.0, 17, 6.0)
	p.position = Vector2(6, 4)
	p.color = WHITE
	p.material = worn
	c.add_child(p)
	var l := _text(c, "", 21, INK, Vector2(18, 10), serif)
	l.size = Vector2(610, 30)
	l.clip_text = true
	card_live.append(func(): l.text = String(fn.call()))

## Портрет madk1d для страницы «Группа»: своя маленькая сцена, создаётся один раз и рисуется только пока страница открыта.
func _buddy_portrait() -> Control:
	if buddy_vp == null:
		buddy_vp = SubViewport.new()
		buddy_vp.size = Vector2i(320, 420)
		buddy_vp.own_world_3d = true
		buddy_vp.transparent_bg = true
		buddy_vp.msaa_3d = Viewport.MSAA_4X
		add_child(buddy_vp)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1, 1, 1)
		env.ambient_light_energy = 0.3
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		we.environment = env
		buddy_vp.add_child(we)
		var key := DirectionalLight3D.new()
		key.rotation = Vector3(-0.5, 0.7, 0.0)
		key.light_energy = 0.85
		buddy_vp.add_child(key)
		var cam := Camera3D.new()
		cam.fov = 24.0
		cam.position = Vector3(0.0, 0.92, 4.6)
		buddy_vp.add_child(cam)
		var r := Rig.new()
		buddy_vp.add_child(r)
		r.setup("res://assets/models/madk1d.glb", 1.68, Poses.madk1d(), false, 1.0, "pause_madk1d")
		r.rotation.y = -0.35
	buddy_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var t := TextureRect.new()
	t.texture = buddy_vp.get_texture()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(230, 300)
	t.material = char_mat
	return t

## Рисунок iPod для страницы «Музыка»: серебристый корпус, экран с нотой и колесо.
func _ipod_art() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(170, 270)
	var body := Panel.new()
	body.size = Vector2(160, 262)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.8, 0.81, 0.83)
	sb.set_corner_radius_all(18)
	sb.border_color = WHITE
	sb.set_border_width_all(2)
	body.add_theme_stylebox_override("panel", sb)
	c.add_child(body)
	var scr := ColorRect.new()
	scr.color = INK
	scr.position = Vector2(14, 14)
	scr.size = Vector2(132, 98)
	body.add_child(scr)
	var note := _text(scr, "♫", 54, WHITE, Vector2.ZERO, serif)
	note.size = scr.size
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_live.append(func(): note.modulate.a = 1.0 if game.ipod.now_playing()["playing"] else 0.35)
	for d in [[52.0, WHITE], [20.0, Color(0.7, 0.71, 0.73)]]:
		var w := Panel.new()
		var r: float = d[0]
		w.size = Vector2(r * 2.0, r * 2.0)
		w.position = Vector2(80 - r, 186 - r)
		var ws := StyleBoxFlat.new()
		ws.bg_color = d[1]
		ws.set_corner_radius_all(int(r))
		w.add_theme_stylebox_override("panel", ws)
		body.add_child(w)
	return c

func _card_select(i: int) -> void:
	if i != card_sel:
		game.main.sfx("sfx_ui", -10.0, 1.2)
	card_sel = i
	_refresh()
	if i < card_rows.size():
		var cur: Label = card_rows[i]["label"]
		var sc := cur.get_parent().get_parent() as ScrollContainer
		if sc != null:
			sc.ensure_control_visible.call_deferred(cur)

## dir: +1 — Enter / вправо, −1 — влево (только у настроек).
func _card_activate(dir := 1) -> void:
	if card_rows.is_empty():
		return
	var r: Dictionary = card_rows[card_sel]
	if r["adj"] != null:
		game.main.sfx("sfx_ui", -6.0, 1.1 if dir > 0 else 0.9)
		(r["adj"] as Callable).call(dir)
	elif r["act"] != null and dir > 0:
		game.main.sfx("sfx_ui")
		(r["act"] as Callable).call()
	if card != null:
		_refresh()

func _close_card() -> void:
	if card != null:
		card.queue_free()
		card = null
		card_rows = []
		card_live = []
		card_body = null
		if not tabs.is_empty():
			_select(sel, false)
	if buddy_vp != null:
		buddy_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Настоящие значения — каждый кадр: панели и открытая страница.
func _refresh() -> void:
	if game == null or game.player == null:
		return
	hp_text.text = "%d / %d" % [ceili(game.player.hp), int(game.player.max_hp)]
	hp_fill.size.x = 300.0 * clampf(game.player.hp / game.player.max_hp, 0.0, 1.0)
	xp_text.text = str(game.xp)
	for fn in card_live:
		(fn as Callable).call()
	for k in card_rows.size():
		var r: Dictionary = card_rows[k]
		var l: Label = r["label"]
		var txt = r["text"]
		l.text = ("▶ " if k == card_sel else "   ") + (String(txt.call()) if txt is Callable else String(txt)) + ("   ◀ ▶" if k == card_sel and r["adj"] != null else "")
		l.add_theme_color_override("font_color", WHITE if k == card_sel else GREY)

# ---------------- ввод ----------------
func _unhandled_input(e: InputEvent) -> void:
	if not is_open or closing or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	var up := k == KEY_W or k == KEY_UP
	var down := k == KEY_S or k == KEY_DOWN
	var ok := k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	var back := k == KEY_ESCAPE or k == KEY_BACKSPACE
	if card != null:
		if up and not card_rows.is_empty():
			_card_select(posmod(card_sel - 1, card_rows.size()))
		elif down and not card_rows.is_empty():
			_card_select(posmod(card_sel + 1, card_rows.size()))
		elif ok or k == KEY_D or k == KEY_RIGHT:
			_card_activate(1)
		elif k == KEY_A or k == KEY_LEFT:
			_card_activate(-1)
		elif back:
			game.main.sfx("sfx_ui", -8.0, 0.8)
			_close_card()
	elif up:
		_select(posmod(sel - 1, TABS.size()))
	elif down:
		_select(posmod(sel + 1, TABS.size()))
	elif ok:
		_open_page(sel)
	elif back:
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	_apply_camera()
	if is_open:
		_refresh()
