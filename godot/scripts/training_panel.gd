## Панель тренировочной арены (F1): тёмный рваный лист слева, как карточки паузы; строки из Training.rows().
## W/S или ↑/↓ — выбор, A/D или ←/→ — значение, Enter / Пробел / клик — действие, Esc или F1 — закрыть.
## Игра стоит, пока панель открыта (её ставит и снимает Training).
class_name TrainingPanel
extends Control

const STAGE := Vector2(1600, 900)
var arena: Training
var root: Control
var labels: Array = []
var items: Array = []
var sel := 0
var serif: SystemFont
var tech: SystemFont

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Playfair Display Black", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	tech = SystemFont.new()
	tech.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.name = "Veil"
	add_child(veil)
	root = Control.new()
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var plate := Polygon2D.new()
	plate.polygon = PauseMenu.torn(640.0, 760.0, 77)
	plate.color = Color(0.04, 0.04, 0.05, 0.96)
	plate.position = Vector2(110, 70)
	root.add_child(plate)
	var edge := Line2D.new()
	edge.points = plate.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = TutorialCard.WHITE
	plate.add_child(edge)
	var head := _lab("ТРЕНИРОВКА", serif, 60, TutorialCard.WHITE)
	head.position = Vector2(120, 78)
	head.rotation = deg_to_rad(-2.0)
	root.add_child(head)
	var chip := Polygon2D.new()
	chip.polygon = TutorialCard._para(330, 26, 8)
	chip.color = TutorialCard.RED
	chip.position = Vector2(126, 158)
	root.add_child(chip)
	var hint := _lab("W/S — выбор · A/D — значение · ENTER — да · ESC — закрыть", tech, 14, TutorialCard.WHITE)
	hint.position = Vector2(140, 161)
	root.add_child(hint)
	items = arena.rows()
	for i in items.size():
		var l := _lab("", serif, 27, TutorialCard.WHITE)
		l.position = Vector2(150, 204 + i * 41)
		l.size = Vector2(580, 38)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		root.add_child(l)
		labels.append(l)
		l.mouse_entered.connect(func(): sel = i)
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				sel = i
				if e.button_index == MOUSE_BUTTON_LEFT:
					_do(i)
				elif e.button_index == MOUSE_BUTTON_RIGHT:
					_change(i, -1))
	_fit()
	get_viewport().size_changed.connect(_fit)
	_refresh()

func _lab(t: String, f: Font, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	(get_node("Veil") as ColorRect).size = vs
	var k: float = minf(vs.x / STAGE.x, vs.y / STAGE.y)
	root.scale = Vector2.ONE * k
	root.position = (vs - STAGE * k) * 0.5

func _text(i: int) -> String:
	var t = items[i][0]
	return String(t.call()) if t is Callable else String(t)

func _refresh() -> void:
	for i in labels.size():
		var l: Label = labels[i]
		var has_adj: bool = items[i].size() > 2 and items[i][2] != null
		l.text = ("▶ " if i == sel else "   ") + _text(i) + ("   ◀ ▶" if has_adj and i == sel else "")
		l.add_theme_color_override("font_color", TutorialCard.WHITE if i == sel else TutorialCard.SILVER)

func _process(_dt: float) -> void:
	_refresh()

func _do(i: int) -> void:
	var act = items[i][1]
	if act is Callable:
		arena.game.main.sfx("sfx_ui", -6.0, 1.1)
		act.call()

func _change(i: int, d: int) -> void:
	if items[i].size() > 2 and items[i][2] is Callable:
		arena.game.main.sfx("sfx_ui", -10.0, 1.3)
		(items[i][2] as Callable).call(d)

func _input(e: InputEvent) -> void:
	if not is_inside_tree():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: Key = (e as InputEventKey).physical_keycode
		match k:
			KEY_W, KEY_UP:
				sel = posmod(sel - 1, items.size())
			KEY_S, KEY_DOWN:
				sel = posmod(sel + 1, items.size())
			KEY_A, KEY_LEFT:
				_change(sel, -1)
			KEY_D, KEY_RIGHT:
				_change(sel, 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_do(sel)
			KEY_ESCAPE, KEY_F1:
				arena.close_panel()
		get_viewport().set_input_as_handled()
