## Дизайн-система интерфейсов мини-игр GOD OF GRIMERKA — одна на «Микрозаймы», подработки и «5 ночей»:
## цвета, шрифты, шкала размеров, отступы, панели, кнопки с состояниями, плашки клавиш, показатели, полосы.
## Цель: текст занимает ровно столько, сколько нужно; у каждого уровня (заголовок → раздел → основное → подпись →
## техническое) свой размер и вес; ничего не налезает. Стиль у игр общий (чёрный, грязно-белый, красный), характер —
## свой: у «Микрозаймов» бумага и чернила, у «5 ночей» — моноширинный текст старого охранного пульта (MONO).
## Все размеры — в единицах базового экрана 1600×900 (проект растягивает canvas_items / expand).
## Экран собирать контейнерами (HBox / VBox / Margin / Grid), не координатами; проверять MGUI.audit().
class_name MGUI

# ---------- цвета ----------
const INK := Color(0.03, 0.03, 0.035)             # чернила: текст на бумаге, фон панелей
const PANEL := Color(0.045, 0.045, 0.055, 0.93)   # тёмная панель
const PANEL_SOFT := Color(0.045, 0.045, 0.055, 0.72)   # поверх 3D — видно сцену
const LINE := Color(0.2, 0.2, 0.23)               # тонкие разделители и рамки
const PAPER := Color(0.9, 0.88, 0.83)             # грязно-белая карточка
const PAPER_DIM := Color(0.42, 0.41, 0.4)         # недоступная карточка
const TEXT := Color(0.95, 0.96, 0.97)             # основной текст на тёмном
const TEXT_2 := Color(0.7, 0.72, 0.75)            # второстепенный
const TEXT_3 := Color(0.47, 0.49, 0.52)           # подписи и техническое
const RED := Color(0.86, 0.09, 0.11)              # акцент и опасность — только по делу
const GOOD := Color(0.36, 0.83, 0.42)
const WARN := Color(1.0, 0.72, 0.29)
const GOLD := Color(1.0, 0.8, 0.3)

# ---------- шкала текста (px на экране 1600×900) ----------
const H1 := 34        # заголовок экрана
const H2 := 22        # заголовок панели, выбранный раздел
const NUM_L := 30     # главный показатель (деньги, долг)
const NUM := 20       # показатель
const BODY := 16      # основной текст
const SMALL := 14     # описание, вторичное
const MICRO := 12     # подписи, метки, клавиши
# ---------- отступы ----------
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24

static var _fonts := {}
static var _theme: Theme

## шрифты: display — тяжёлая антиква для заголовков и крупных чисел; ui — ровный гротеск для текста (полная
## кириллица, ₽, тире, кавычки); caps — Russo One для коротких подписей и кнопок; mono — пульт, таймеры, техническое
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"display":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Georgia", "Times New Roman", "serif"])
			s.font_weight = 900
			f = s
		"ui":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans", "sans-serif"])
			s.font_weight = 600
			f = s
		"ui_b":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans", "sans-serif"])
			s.font_weight = 800
			f = s
		"mono":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
			s.font_weight = 600
			f = s
		_:
			f = load("res://assets/fonts/RussoOne-Regular.ttf")
	_fonts[kind] = f
	return f

## стили текста: имя → [шрифт, размер, цвет]
const STYLES := {
	"h1": ["display", H1, TEXT], "h2": ["display", H2, TEXT], "num_l": ["display", NUM_L, TEXT], "num": ["display", NUM, TEXT],
	"body": ["ui", BODY, TEXT], "body_b": ["ui_b", BODY, TEXT], "small": ["ui", SMALL, TEXT_2], "micro": ["ui", MICRO, TEXT_3],
	"caps": ["caps", MICRO, TEXT_3], "caps_m": ["caps", SMALL, TEXT_2], "btn": ["caps", SMALL, TEXT],
	"mono": ["mono", SMALL, TEXT_2], "mono_l": ["mono", NUM, TEXT], "mono_s": ["mono", MICRO, TEXT_3], "mono_m": ["mono", BODY + 2, TEXT],
	"caps_l": ["caps", H2, TEXT], "caps_h": ["caps", H1 + 4, TEXT], "caps_xl": ["caps", 60, TEXT],      # caps_xl — только заставки (12:00 AM, гибель)
}

## надпись в стиле style; wrap_w > 0 — перенос по ширине (подпись сама растёт вниз)
static func label(text: String, style := "body", col = null, wrap_w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, style, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_w
	return l

static func style_label(l: Label, style: String, col = null) -> void:
	var st: Array = STYLES.get(style, STYLES["body"])
	l.add_theme_font_override("font", font(String(st[0])))
	l.add_theme_font_size_override("font_size", int(st[1]))
	l.add_theme_color_override("font_color", col if col != null else st[2])
	l.add_theme_constant_override("line_spacing", 1)

## надпись поверх 3D-сцены: с тёмной обводкой, чтобы читалась на любом фоне
static func label_3d(text: String, style := "body", col = null) -> Label:
	var l := label(text, style, col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 5)
	return l

# ---------- панели ----------
static func box(bg: Color, radius := 4, border := 0, border_col := LINE, pad := S3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.set_content_margin_all(pad)
	return sb

## тёмная панель с тонкой рамкой; accent — цветная полоса слева (статус, не украшение)
static func panel(soft := false, accent = null, pad := S4) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(PANEL_SOFT if soft else PANEL, 4, 1, LINE, pad)
	if accent != null:
		sb.border_width_left = 4
		sb.border_color = accent
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func vbox(sep := S2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func hbox(sep := S2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func vsep() -> ColorRect:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(1, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hsep() -> ColorRect:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## показатель: мелкая подпись сверху, значение под ней; возвращает {box, cap, val}
static func stat(caption: String, value := "", val_style := "num") -> Dictionary:
	var v := vbox(0)
	var c := label(caption, "caps")
	var l := label(value, val_style)
	v.add_child(c)
	v.add_child(l)
	return {"box": v, "cap": c, "val": l}

## полоса прогресса: {box, fill}; set_bar(d, 0..1, цвет)
static func bar(w: float, h := 6.0, col := GOOD) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.17, 0.2)
	bg.custom_minimum_size = Vector2(w, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := ColorRect.new()
	fg.color = col
	fg.size = Vector2(0, h)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fg)
	return {"box": bg, "fill": fg, "w": w, "h": h}

static func set_bar(d: Dictionary, k: float, col = null) -> void:
	var fg: ColorRect = d["fill"]
	fg.size = Vector2(float(d["w"]) * clampf(k, 0.0, 1.0), float(d["h"]))
	if col != null:
		fg.color = col

## плашка клавиши «W/S»
static func keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(0.14, 0.14, 0.16), 3, 1, Color(0.36, 0.36, 0.4), 0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, "mono_s", TEXT))
	return p

## строка подсказок управления: [["W/S", "выбор"], ["Enter", "открыть"]] — коротко, одной строкой
static func hints(pairs: Array) -> HBoxContainer:
	var h := hbox(S2)
	for pr in pairs:
		h.add_child(keycap(String(pr[0])))
		var l := label(String(pr[1]), "micro", TEXT_2)
		h.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(S2, 0)
		h.add_child(gap)
	return h

## метка-чип: короткий статус («1 действие», «куплено»)
static func chip(text: String, col := TEXT_3) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(col.r, col.g, col.b, 0.14), 3, 0, LINE, 0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, "caps", col))
	return p

## общая тема: кнопки (обычная / наведение / нажата / фокус / недоступна), полосы прокрутки
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_font("font", "Button", font("caps"))
	t.set_font_size("font_size", "Button", SMALL)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_3)
	var n := box(Color(0.1, 0.1, 0.12), 3, 1, LINE, 0)
	n.content_margin_left = S4
	n.content_margin_right = S4
	n.content_margin_top = 7
	n.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", n)
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = PAPER
	hv.border_color = PAPER
	t.set_stylebox("hover", "Button", hv)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.75, 0.73, 0.69)
	t.set_stylebox("pressed", "Button", pr)
	var fc := n.duplicate() as StyleBoxFlat
	fc.bg_color = Color(0, 0, 0, 0)
	fc.border_color = RED
	fc.set_border_width_all(2)
	t.set_stylebox("focus", "Button", fc)
	var ds := n.duplicate() as StyleBoxFlat
	ds.bg_color = Color(0.07, 0.07, 0.08)
	t.set_stylebox("disabled", "Button", ds)
	var grab := box(Color(0.45, 0.45, 0.48), 2, 0, LINE, 0)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.1, 0.1, 0.12), 2, 0, LINE, 0))
	_theme = t
	return t

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func rub(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = NB + s.substr(s.length() - 3) + out       # неразрывный пробел между разрядами: число не рвётся переносом
		s = s.substr(0, s.length() - 3)
	return ("−" if v < 0 else "") + s + out + NB + "₽"

const NB := "\u00A0"
## текст для подписи с переносом: «₽», «%» и единицы не уезжают на новую строку отдельно от числа
static func nb(s: String) -> String:
	for u in [" ₽", " %", " дн.", " шт.", " ч.", " с.", " мин"]:
		s = s.replace(u, NB + String(u).substr(1))
	return s

# ---------- проверка вёрстки ----------
## Аудит вёрстки: видимые надписи и кнопки не должны выходить за экран и за свою панель, налезать друг на друга,
## а текст — обрезаться. Возвращает список замечаний (пусто — чисто). screen — видимая область в координатах холста.
## Надпись с меткой audit_skip не проверяется (всплывающие на долю секунды: «+500 ₽», вспышки), с меткой
## audit_clip — может обрезаться намеренно (длинная строка состояния с многоточием).
static func audit(root: Node, screen: Rect2) -> Array:
	var out: Array = []
	var items: Array = []
	_collect(root, items)
	# открыто модальное окно (метка audit_modal: ящик стола, пауза, карточка гибели) — проверяется только оно:
	# всё, что под ним, затемнено и не читается
	var modal := _modal(root)
	if modal != null:
		items = items.filter(func(c): return modal.is_ancestor_of(c))
	var rects: Array = []
	for c in items:
		var C := c as Control
		var txt := _text_of(C).left(26)
		var r := _ink_rect(C)
		var vis := _clip(C, r)
		rects.append(vis)
		if vis.size.x < 2.0 or vis.size.y < 2.0:
			continue                                   # целиком скрыт прокруткой или обрезкой родителя
		if not screen.grow(2.0).encloses(vis):
			out.append("за экраном: «%s» %s" % [txt, str(vis)])
		var pnl := _panel_of(C)
		if pnl != null and not pnl.get_global_rect().grow(3.0).encloses(vis):
			out.append("за панелью: «%s»" % txt)
		if not C.has_meta("audit_clip") and _cut(C):
			out.append("обрезан текст: «%s»" % txt)
	for i in items.size():
		var ra: Rect2 = rects[i]
		if ra.size.x < 2.0 or ra.size.y < 2.0:
			continue
		for j in range(i + 1, items.size()):
			var rb: Rect2 = rects[j]
			if rb.size.x < 2.0 or rb.size.y < 2.0 or (items[i] as Node).is_ancestor_of(items[j]) or (items[j] as Node).is_ancestor_of(items[i]):
				continue
			if ra.intersects(rb) and ra.intersection(rb).get_area() > 12.0:
				out.append("наложение: «%s» × «%s»" % [_text_of(items[i]).left(22), _text_of(items[j]).left(22)])
	return out

static func _modal(n: Node) -> Node:
	var found: Node = null
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	if n.has_meta("audit_modal"):
		found = n
	for c in n.get_children():
		var m := _modal(c)
		if m != null:
			found = m
	return found

static func _text_of(c: Control) -> String:
	return (c as Label).text if c is Label else ((c as Button).text if c is Button else "")

static func _collect(n: Node, acc: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is Control and (n as Control).modulate.a < 0.05:
		return
	if n is SubViewport:
		return
	if (n is Label or n is Button) and _text_of(n as Control).strip_edges() != "" and (n as Control).is_visible_in_tree() and not n.has_meta("audit_skip"):
		acc.append(n)
	for c in n.get_children():
		_collect(c, acc)

## область, где у надписи правда есть буквы (а не вся её коробка): по настоящему размеру текста и выравниванию
static func _ink_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	if not (c is Label):
		return r.grow(-1.5)
	var l := c as Label
	var ms := l.get_minimum_size() * l.get_global_transform().get_scale()
	var w := minf(r.size.x, ms.x) if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text else r.size.x
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_line_count() <= 1:
		var f := l.get_theme_font("font")
		w = minf(r.size.x, f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x * l.get_global_transform().get_scale().x)
	var x := r.position.x
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x += (r.size.x - w) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x += r.size.x - w
	var h := minf(r.size.y, ms.y)
	var y := r.position.y
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y += (r.size.y - h) * 0.5
	return Rect2(x, y, w, h).grow(-1.5)

## видимая часть прямоугольника: что осталось после обрезки прокруткой и clip_contents у родителей
static func _clip(c: Control, r: Rect2) -> Rect2:
	var p := c.get_parent()
	while p != null:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r

## текст не поместился: обрезан clip_text, скрыт пределом строк или вылез за свою коробку по высоте
static func _cut(c: Control) -> bool:
	if c is Button:
		var b := c as Button
		if not b.clip_text:
			return false
		var bf := b.get_theme_font("font")
		return bf.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x > b.size.x - 4.0
	var l := c as Label
	if l.clip_text:
		var f := l.get_theme_font("font")
		return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x > l.size.x + 1.0
	if l.max_lines_visible > 0 and l.get_line_count() > l.max_lines_visible:
		return true
	return l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_minimum_size().y > l.size.y + 2.0

static func _panel_of(c: Control) -> Control:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return null                              # внутри прокрутки выход за край — норма
		if p is PanelContainer or p is Panel:
			return p as Control
		p = p.get_parent()
	return null
