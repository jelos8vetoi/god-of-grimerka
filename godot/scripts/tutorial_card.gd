## Карточка боевого обучения: чёрно-белая манга с красным акцентом, как меню и пауза.
## Затемнение кадра → красная полоса с полутоном → рваный чёрный лист → крупный заголовок с красной чертой →
## плашки клавиш (текущие клавиши из InputMap) → текст → «СОВЕТ» → большая кнопка «ЗАКРЫТЬ».
## Живёт поверх всего (hud), работает на остановленной игре (PROCESS_MODE_ALWAYS). Закрытие — кнопка, Enter, Пробел, Esc;
## первые LOCK секунд ввод глотается без закрытия: карточку не смахнуть случайным нажатием посреди боя.
## Пока карточка открыта, весь ввод забирает она (_input) — ни игра, ни меню паузы его не получают.
class_name TutorialCard
extends Control

signal closed

const STAGE := Vector2(1600, 900)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.76, 0.78, 0.81)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const RED := Color(0.78, 0.07, 0.1)
const LOCK := 0.55
const W := 1010.0               # ширина листа
const X0 := 300.0               # левый край листа
const PAD := 64.0               # отступ текста внутри листа
const HALFTONE := """
shader_type canvas_item;
// полутон под 45°: точки растут слева направо — как растр на печатной полосе манги
uniform float cell = 9.0;
uniform vec4 dot_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amount = 0.55;
uniform float grow = 1.0;
void fragment() {
	vec2 q = FRAGCOORD.xy / cell;
	q = vec2(q.x + q.y, q.y - q.x) * 0.7071;
	vec2 g = fract(q) - 0.5;
	float r = mix(0.1, 0.5, clamp((SCREEN_UV.x - 0.05) * grow, 0.0, 1.0));
	float d = 1.0 - smoothstep(r - 0.07, r + 0.07, length(g));
	COLOR.rgb = mix(COLOR.rgb, dot_col.rgb, d * amount);
}
"""

var data: Dictionary = {}       # {"tag","title","keys","text","tip"} или карточка стиля {"title","who","slot","core","keys","base","adv","tip"}
var counter := ""               # «3 / 25»
var replay := false             # открыта из паузы: подпись другая
var root: Control
var veil: ColorRect
var btn: Control
var btn_fill: Polygon2D
var btn_label: Label
var opened_ms := 0
var closing := false
var hover := false
var serif: SystemFont
var tech: SystemFont
var tech_b: SystemFont
var worn: ShaderMaterial

## Имя клавиши действия для плашки: первая привязка InputMap (мышь — ЛКМ/ПКМ, клавиши — по-русски, где принято)
static func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return action.to_upper()
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "ЛКМ"
				MOUSE_BUTTON_RIGHT: return "ПКМ"
				MOUSE_BUTTON_MIDDLE: return "СКМ"
				MOUSE_BUTTON_WHEEL_UP: return "КОЛЕСО ↑"
				MOUSE_BUTTON_WHEEL_DOWN: return "КОЛЕСО ↓"
				_: return "МЫШЬ %d" % (e as InputEventMouseButton).button_index
		if e is InputEventKey:
			var k := e as InputEventKey
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			match code:
				KEY_SPACE: return "ПРОБЕЛ"
				KEY_ESCAPE: return "ESC"
				KEY_UP: return "↑"
				KEY_DOWN: return "↓"
				KEY_LEFT: return "←"
				KEY_RIGHT: return "→"
			return OS.get_keycode_string(code).to_upper()
	return "—"

## Подставить клавиши: «{heavy}» → «ПКМ»
static func fill(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_]+)\\}")
	var out := s
	for m in re.search_all(s):
		out = out.replace(m.get_string(0), key_name(m.get_string(1)))
	return out

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	tech_b = SystemFont.new()
	tech_b.font_names = tech.font_names
	tech_b.font_weight = 700
	worn = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Menu.WORN_SHADER
	worn.shader = ws
	veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.62)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	root = Control.new()
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	opened_ms = Time.get_ticks_msec()
	# появление: лист въезжает слева с лёгким поворотом, полоса — справа; время реальное (стоп-кадр и пауза не мешают)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	var sheet: Node2D = root.get_node("Sheet")
	sheet.position.x -= 60.0
	sheet.rotation -= 0.035
	tw.tween_property(sheet, "position:x", sheet.position.x + 60.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "rotation", sheet.rotation + 0.035, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var band: Node2D = root.get_node("Band")
	band.position.x += 90.0
	tw.tween_property(band, "position:x", band.position.x - 90.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	veil.size = vs
	var k: float = minf(vs.x / STAGE.x, vs.y / STAGE.y)
	root.scale = Vector2.ONE * k
	root.position = (vs - STAGE * k) * 0.5

func locked() -> bool:
	return Time.get_ticks_msec() - opened_ms < int(LOCK * 1000.0)

# ---------------- сборка ----------------
func _build() -> void:
	var style_card := data.has("core")
	# красная полоса через весь кадр, по ней полутон
	var band := Polygon2D.new()
	band.name = "Band"
	band.polygon = PackedVector2Array([Vector2(-80, 300), Vector2(1700, 150), Vector2(1700, 610), Vector2(-80, 760)])
	band.color = RED
	var hm := ShaderMaterial.new()
	var hs := Shader.new()
	hs.code = HALFTONE
	hm.shader = hs
	band.material = hm
	root.add_child(band)
	# лист: тень-смещение, чёрная бумага с рваным краем, белая кромка
	var sheet := Node2D.new()
	sheet.name = "Sheet"
	sheet.position = Vector2(X0, 0)
	sheet.rotation = deg_to_rad(-1.1)
	root.add_child(sheet)
	var body := Node2D.new()                   # текст кладётся сюда, высота листа считается по нему
	var y := _content(body, style_card)
	var h: float = maxf(y + 40.0, 420.0)
	var top: float = clampf((STAGE.y - h) * 0.5, 30.0, 200.0)
	sheet.position.y = top
	var poly := PauseMenu.torn(W, h, 211 + h as int, 30.0)
	var shadow := Polygon2D.new()
	shadow.polygon = poly
	shadow.color = Color(0, 0, 0, 0.85)
	shadow.position = Vector2(16, 18)
	sheet.add_child(shadow)
	var plate := Polygon2D.new()
	plate.polygon = poly
	plate.color = Color(0.045, 0.045, 0.052, 0.98)
	sheet.add_child(plate)
	var edge := Line2D.new()
	edge.points = poly
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	edge.material = worn
	sheet.add_child(edge)
	# серый полутон в правом верхнем углу листа
	var dots := Polygon2D.new()
	dots.polygon = PackedVector2Array([Vector2(W - 330, 0), Vector2(W, 0), Vector2(W, 230)])
	dots.color = Color(0.045, 0.045, 0.052)
	var dm := ShaderMaterial.new()
	dm.shader = hs
	dm.set_shader_parameter("dot_col", Color(0.32, 0.33, 0.36))
	dm.set_shader_parameter("amount", 0.8)
	dm.set_shader_parameter("cell", 7.0)
	dots.material = dm
	sheet.add_child(dots)
	sheet.add_child(body)
	# кнопка «ЗАКРЫТЬ» — красная, справа внизу, наползает на край листа
	btn = Control.new()
	btn.name = "Close"
	btn.size = Vector2(330, 78)
	btn.position = Vector2(W - 300, h - 40)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bshadow := Polygon2D.new()
	bshadow.polygon = _para(330, 78, 18)
	bshadow.color = INK
	bshadow.position = Vector2(8, 8)
	btn.add_child(bshadow)
	btn_fill = Polygon2D.new()
	btn_fill.polygon = _para(330, 78, 18)
	btn_fill.color = RED
	btn.add_child(btn_fill)
	btn_label = Label.new()
	btn_label.text = "ЗАКРЫТЬ"
	btn_label.add_theme_font_override("font", serif)
	btn_label.add_theme_font_size_override("font_size", 42)
	btn_label.add_theme_color_override("font_color", WHITE)
	btn_label.size = btn.size
	btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(btn_label)
	var hint := _label("ENTER · ПРОБЕЛ · ESC", tech_b, 16, SILVER.darkened(0.25))
	hint.position = Vector2(W - 300 - 270, h - 42)
	hint.size = Vector2(250, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sheet.add_child(hint)
	# кнопка — Control внутри Node2D: у Control-родителя нет, поэтому кладём её в отдельный Control поверх листа
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2.ZERO
	holder.size = STAGE
	sheet.add_child(holder)
	holder.add_child(btn)

## Содержимое листа; возвращает высоту
func _content(body: Node2D, style_card: bool) -> float:
	var y := 26.0
	# метка над заголовком: раздел и номер
	var tag_text := ("СТИЛЬ " + key_name(String(data.get("slot", ""))) + " · " + String(data.get("who", ""))) if style_card else String(data.get("tag", ""))
	tag_text += "   ·   " + ("ПОВТОР ПОДСКАЗКИ" if replay else "БОЕВОЕ ОБУЧЕНИЕ") + ("   " + counter if counter != "" and not replay else "")
	var tw: float = tech_b.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var chip := Polygon2D.new()
	chip.polygon = _para(tw + 40.0, 30.0, 10.0)
	chip.color = RED
	chip.position = Vector2(PAD - 14, y)
	body.add_child(chip)
	var tl := _label(tag_text, tech_b, 17, WHITE)
	tl.position = Vector2(PAD + 6, y + 3)
	body.add_child(tl)
	y += 44.0
	# заголовок: крупно, растянут, с потёртостью; длинный — меньше
	var title := fill(String(data.get("title", "")))
	var fs := 88
	while fs > 48 and serif.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.12 > W - PAD * 2.0:
		fs -= 4
	var th := _label(title, serif, fs, WHITE)
	th.material = worn
	th.scale = Vector2(1.12, 1.0)
	th.position = Vector2(PAD - 4, y - fs * 0.12)
	th.rotation = deg_to_rad(-1.5)
	th.name = "Title"
	body.add_child(th)
	y += fs * 1.05
	var bar := Polygon2D.new()
	var bw: float = minf(serif.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.12, W - PAD * 2.0)
	bar.polygon = PackedVector2Array([Vector2(0, 0), Vector2(bw, -6), Vector2(bw - 6, 4), Vector2(-4, 9)])
	bar.color = RED
	bar.position = Vector2(PAD, y)
	body.add_child(bar)
	y += 26.0
	if style_card:
		y = _para_text(body, fill(String(data["core"])), y, 25, WHITE, serif) + 10.0
	# клавиши
	for k in data.get("keys", []):
		y = _key_row(body, k, y) + 6.0
	y += 8.0
	if style_card:
		y = _section(body, "БАЗА", fill(String(data["base"])), y)
		y = _section(body, "СВЯЗКА", fill(String(data["adv"])), y)
	else:
		for line in data.get("text", []):
			var dot := Polygon2D.new()
			dot.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, 0), Vector2(7, 9), Vector2(-2, 9)])
			dot.color = RED
			dot.position = Vector2(PAD, y + 11)
			body.add_child(dot)
			y = _para_text(body, fill(String(line)), y, 22, SILVER, tech, PAD + 24.0) + 6.0
	if String(data.get("tip", "")) != "":
		y += 8.0
		y = _section(body, "СОВЕТ", fill(String(data["tip"])), y, true)
	return y + 30.0

## Строка клавиш: белые плашки с чёрными буквами (несколько — через «/»), «ДЕРЖАТЬ» для удержания, подпись серым
func _key_row(body: Node2D, k: Array, y: float) -> float:
	var acts: Array = k[0]
	var cap: String = fill(String(k[1])) if k.size() > 1 else ""
	var kind: String = String(k[2]) if k.size() > 2 else ""
	var x := PAD
	if kind == "hold":
		var hl := _label("ДЕРЖАТЬ", tech_b, 16, RED)
		hl.position = Vector2(x, y + 13)
		body.add_child(hl)
		x += tech_b.get_string_size("ДЕРЖАТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
	for i in acts.size():
		if i > 0:
			var sl := _label("/", tech_b, 26, GREY)
			sl.position = Vector2(x + 2, y + 5)
			body.add_child(sl)
			x += 22.0
		var name := key_name(String(acts[i]))
		var w: float = maxf(58.0, tech_b.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x + 34.0)
		var sh := Polygon2D.new()
		sh.polygon = _para(w, 46, 9)
		sh.color = RED
		sh.position = Vector2(x + 5, y + 5)
		body.add_child(sh)
		var p := Polygon2D.new()
		p.polygon = _para(w, 46, 9)
		p.color = WHITE
		p.position = Vector2(x, y)
		body.add_child(p)
		var kl := _label(name, tech_b, 27, INK)
		kl.position = Vector2(x, y + 4)
		kl.size = Vector2(w, 38)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.name = "Key_" + String(acts[i])
		body.add_child(kl)
		x += w + 8.0
	if cap != "":
		_para_text(body, cap, y + 9, 21, SILVER, tech, x + 12.0)
	return y + 46.0

## Раздел с красной подписью слева («БАЗА», «СВЯЗКА», «СОВЕТ») и текстом справа
func _section(body: Node2D, head: String, text: String, y: float, tip := false) -> float:
	var hw := 128.0
	var chip := Polygon2D.new()
	chip.polygon = _para(hw - 14.0, 28, 8)
	chip.color = WHITE if tip else RED
	chip.position = Vector2(PAD, y + 2)
	body.add_child(chip)
	var hl := _label(head, tech_b, 16, INK if tip else WHITE)
	hl.position = Vector2(PAD, y + 5)
	hl.size = Vector2(hw - 14.0, 22)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hl)
	return _para_text(body, text, y, 22, WHITE if tip else SILVER, tech, PAD + hw) + 10.0

## Текст с переносом по ширине листа; возвращает нижний край
func _para_text(body: Node2D, text: String, y: float, fs: int, col: Color, f: Font, x := PAD) -> float:
	var w: float = W - x - PAD
	var l := _label(text, f, fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(x, y)
	l.size = Vector2(w, 10)
	body.add_child(l)
	var hgt: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	return y + hgt

func _label(t: String, f: Font, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Параллелограмм с наклоном — плашки клавиш, меток и кнопки
static func _para(w: float, h: float, s: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(s, 0), Vector2(w, 0), Vector2(w - s, h), Vector2(0, h)])

# ---------------- ввод и закрытие ----------------
func _process(_dt: float) -> void:
	if btn == null:
		return
	var lit := hover and not locked()
	btn_fill.color = WHITE if lit else (RED if not locked() else RED.darkened(0.45))
	btn_label.add_theme_color_override("font_color", INK if lit else WHITE)

func _input(e: InputEvent) -> void:
	if closing:
		get_viewport().set_input_as_handled()
		return
	var confirm := false
	if e is InputEventKey and e.pressed and not e.echo:
		var c: Key = (e as InputEventKey).physical_keycode
		confirm = c in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]
	elif e is InputEventJoypadButton and e.pressed:
		confirm = (e as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]
	# мышь разбираем сами: кнопка лежит в повёрнутом листе (Node2D), а под карточкой — меню паузы, ему ничего не достаётся
	if e is InputEventMouseMotion:
		hover = _over_btn((e as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		hover = _over_btn(mb.position)
		get_viewport().set_input_as_handled()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and hover:
			close()
		return
	get_viewport().set_input_as_handled()
	if confirm:
		close()

func _over_btn(at: Vector2) -> bool:
	if btn == null:
		return false
	var local: Vector2 = btn.get_global_transform_with_canvas().affine_inverse() * at
	return Rect2(Vector2.ZERO, btn.size).has_point(local)

func close() -> void:
	if closing or locked():
		return
	closing = true
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


# ---------------- панель упражнения (практика) ----------------
## Панель упражнения справа сверху — как активное задание: «ОБУЧЕНИЕ / КОМБО — ШАГ 2/3 / что сделать / клавиши / ПРОПУСТИТЬ».
## Игра не останавливается. Клавиши — из InputMap (fill, key_name). Выполнено — «✓ ВЫПОЛНЕНО» и панель уезжает вправо.
## Кнопка «ПРОПУСТИТЬ» — мышью (когда курсор виден) или Backspace (действие tut_skip, его ловит tutorial.gd).
class Drill extends Control:
	signal skip_pressed

	const PW := 440.0
	var root: Control
	var sheet: Node2D
	var body: Node2D
	var plate: Polygon2D
	var edge: Line2D
	var skip_btn: Control
	var skip_fill: Polygon2D
	var skip_l: Label
	var serif: SystemFont
	var tech: SystemFont
	var tech_b: SystemFont
	var data: Dictionary = {}
	var steps: Array = []
	var cur_id := ""
	var flash_t := 0.0
	var leave_t := -1.0
	var tw: Tween

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		serif = SystemFont.new()
		serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
		serif.font_weight = 900
		tech = SystemFont.new()
		tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
		tech_b = SystemFont.new()
		tech_b.font_names = tech.font_names
		tech_b.font_weight = 700
		root = Control.new()
		root.size = TutorialCard.STAGE
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		sheet = Node2D.new()
		root.add_child(sheet)
		plate = Polygon2D.new()
		plate.color = Color(0.04, 0.04, 0.05, 0.9)
		sheet.add_child(plate)
		edge = Line2D.new()
		edge.width = 1.6
		edge.default_color = TutorialCard.WHITE
		edge.closed = true
		sheet.add_child(edge)
		body = Node2D.new()
		sheet.add_child(body)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size = TutorialCard.STAGE
		sheet.add_child(holder)
		skip_btn = Control.new()
		skip_btn.size = Vector2(196, 30)
		skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.add_child(skip_btn)
		skip_fill = Polygon2D.new()
		skip_fill.polygon = TutorialCard._para(196, 30, 8)
		skip_fill.color = Color(0, 0, 0, 0.0)
		skip_btn.add_child(skip_fill)
		var sl := Line2D.new()
		sl.points = TutorialCard._para(196, 30, 8)
		sl.closed = true
		sl.width = 1.4
		sl.default_color = TutorialCard.RED
		skip_btn.add_child(sl)
		skip_l = _lab("", tech_b, 14, TutorialCard.WHITE)
		skip_l.size = skip_btn.size
		skip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skip_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skip_btn.add_child(skip_l)
		skip_btn.mouse_entered.connect(func(): skip_fill.color = Color(TutorialCard.RED.r, TutorialCard.RED.g, TutorialCard.RED.b, 0.6))
		skip_btn.mouse_exited.connect(func(): skip_fill.color = Color(0, 0, 0, 0.0))
		skip_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				skip_btn.accept_event()
				skip_pressed.emit())
		visible = false
		_fit()
		get_viewport().size_changed.connect(_fit)

	func _fit() -> void:
		var vs := get_viewport_rect().size
		position = Vector2.ZERO
		size = vs
		var k: float = minf(vs.x / TutorialCard.STAGE.x, vs.y / TutorialCard.STAGE.y)
		root.scale = Vector2.ONE * k
		root.position = (vs - TutorialCard.STAGE * k) * 0.5

	func _lab(t: String, f: Font, fs: int, col: Color) -> Label:
		var l := Label.new()
		l.text = t
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", col)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	## занята анимацией (успех / уход) — tutorial.gd держит её видимой
	func busy() -> bool:
		return leave_t >= 0.0

	func open(id: String, d: Dictionary, st: Array) -> void:
		cur_id = id
		data = d
		steps = st
		leave_t = -1.0
		visible = true
		modulate.a = 0.0
		sheet.position.x = 60.0
		if tw != null:
			tw.kill()
		tw = create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
		tw.tween_property(sheet, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Шаг упражнения: заголовок «ИМЯ — ШАГ i/n», что сделать, клавиши, счётчик повторов
	func show_step(_id: String, step: int, n: int, _flash: bool) -> void:
		for c in body.get_children():
			body.remove_child(c)          # сразу из дерева: новые плашки получают свои имена (Key_<действие>)
			c.queue_free()
		if step >= steps.size():
			return
		var st: Dictionary = steps[step]
		var x0: float = TutorialCard.STAGE.x - PW - 26.0
		var y := 74.0
		var chip := Polygon2D.new()
		chip.polygon = TutorialCard._para(118, 24, 8)
		chip.color = TutorialCard.RED
		chip.position = Vector2(x0 + 18, y)
		body.add_child(chip)
		var tl := _lab("ОБУЧЕНИЕ", tech_b, 14, TutorialCard.WHITE)
		tl.position = Vector2(x0 + 30, y + 3)
		body.add_child(tl)
		y += 30.0
		var name: String = TutorialCard.fill(String(data.get("title", cur_id)))
		var head := _lab("%s — ШАГ %d/%d" % [name, step + 1, steps.size()] if steps.size() > 1 else name, serif, 26, TutorialCard.WHITE)
		head.position = Vector2(x0 + 18, y)
		head.size = Vector2(PW - 36, 30)
		head.clip_text = true
		body.add_child(head)
		y += 36.0
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(0, 0), Vector2(PW - 60, -3), Vector2(PW - 63, 2), Vector2(-2, 5)])
		bar.color = TutorialCard.RED
		bar.position = Vector2(x0 + 18, y)
		body.add_child(bar)
		y += 12.0
		var txt := _lab(TutorialCard.fill(String(st.get("t", ""))), tech, 18, TutorialCard.SILVER)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.position = Vector2(x0 + 18, y)
		txt.size = Vector2(PW - 36, 10)
		body.add_child(txt)
		y += tech.get_multiline_string_size(txt.text, HORIZONTAL_ALIGNMENT_LEFT, PW - 36, 18).y + 8.0
		# клавиши
		var kx := x0 + 18.0
		for k in st.get("keys", []):
			var acts: Array = k[0]
			for i in acts.size():
				if i > 0:
					var sl := _lab("/", tech_b, 18, TutorialCard.GREY)
					sl.position = Vector2(kx, y + 3)
					body.add_child(sl)
					kx += 14.0
				var nm := TutorialCard.key_name(String(acts[i]))
				var w: float = maxf(42.0, tech_b.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 22.0)
				var p := Polygon2D.new()
				p.polygon = TutorialCard._para(w, 30, 7)
				p.color = TutorialCard.WHITE
				p.position = Vector2(kx, y)
				body.add_child(p)
				var kl := _lab(nm, tech_b, 18, TutorialCard.INK)
				kl.position = Vector2(kx, y + 3)
				kl.size = Vector2(w, 24)
				kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				kl.name = "Key_" + String(acts[i])
				body.add_child(kl)
				kx += w + 6.0
			if k.size() > 1:
				var cap := _lab(TutorialCard.fill(String(k[1])), tech, 14, TutorialCard.GREY)
				cap.position = Vector2(kx + 2, y + 6)
				body.add_child(cap)
				kx += tech.get_string_size(cap.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
		var need: int = int(st.get("n", 1))
		if need > 1:
			var pr := _lab("%d/%d" % [n, need], serif, 24, TutorialCard.RED)
			pr.position = Vector2(x0 + PW - 70, y)
			body.add_child(pr)
		y += 40.0
		skip_btn.position = Vector2(x0 + PW - 214, y)
		skip_l.text = "ПРОПУСТИТЬ · " + TutorialCard.key_name("tut_skip")
		y += 40.0
		var poly := PackedVector2Array([Vector2(x0, 62), Vector2(x0 + PW, 62), Vector2(x0 + PW - 10, y), Vector2(x0 + 6, y)])
		plate.polygon = poly
		edge.points = poly
		if step > 0 or n > 0:
			# шаг засчитан — короткая вспышка
			var f := create_tween()
			body.modulate = Color(1.6, 1.6, 1.6)
			f.tween_property(body, "modulate", Color.WHITE, 0.25)

	## Конец упражнения: «✓ ВЫПОЛНЕНО» (или «ПРОПУЩЕНО») и панель уезжает вправо
	func finish(state: String) -> void:
		leave_t = 0.0
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		var x0: float = TutorialCard.STAGE.x - PW - 26.0
		var ok := state == "completed"
		var chip := Polygon2D.new()
		chip.polygon = TutorialCard._para(PW - 36, 56, 14)
		chip.color = TutorialCard.RED if ok else Color(0.2, 0.2, 0.22)
		chip.position = Vector2(x0 + 18, 82)
		body.add_child(chip)
		var l := _lab(("✓ ВЫПОЛНЕНО" if ok else "ПРОПУЩЕНО"), serif, 34, TutorialCard.WHITE)
		l.position = Vector2(x0 + 18, 86)
		l.size = Vector2(PW - 36, 48)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.name = "Done"
		body.add_child(l)
		skip_btn.position = Vector2(-999, -999)
		var poly := PackedVector2Array([Vector2(x0, 62), Vector2(x0 + PW, 62), Vector2(x0 + PW - 10, 156), Vector2(x0 + 6, 156)])
		plate.polygon = poly
		edge.points = poly
		if tw != null:
			tw.kill()
		tw = create_tween()
		tw.tween_interval(1.0 if ok else 0.35)
		tw.tween_property(sheet, "position:x", 80.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			leave_t = -1.0
			visible = false
			sheet.position.x = 0.0)
