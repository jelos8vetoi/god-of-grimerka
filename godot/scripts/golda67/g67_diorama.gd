class_name G67Diorama
extends CanvasLayer
## Общая основа «физических» экранов подъезда (архив, доска объявлений, почтовые ящики): сцена STAGE, вписанная в
## окно, без полосы подсказок клавиш (решение владельца: управление и так понятно), игровой HUD на время экрана
## спрятан. Выбор — по направлению среди предметов сцены (items), а не по списку: W/A/S/D, стрелки, крестовина
## геймпада; Enter / пробел / E / A — открыть; Esc / Backspace / B — назад или закрыть; мышь — наведение и клик.
## Наследник задаёт предметы (add_item), а действия — в _activate(i) и _back() (true — шаг назад обработан сам).

signal closed

const STAGE := Vector2(1600, 900)

var G: Golda67
var kind := ""
var stage: Control
var shade: ColorRect
var items: Array = []          # [{node: Control, key}]
var sel := -1
var mode := "list"            # наследник меняет на свои подрежимы (чтение, просмотр); в "busy" ввод не принимается
var opened_ms := 0
var _hud_was := {}

func _open_base(g67: Golda67, what: String) -> void:
	G = g67
	kind = what
	layer = 56
	process_mode = Node.PROCESS_MODE_ALWAYS
	g67.game.add_child(self)
	opened_ms = GameClock.ms()
	_hide_hud(true)
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.025, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.94, 0.2)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_fit()
	get_viewport().size_changed.connect(_fit)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	g67.events.append(["hub_ui", what])

## Мелкая подсказка «Esc — закрыть» в углу: только первые 3 с после открытия
func esc_hint() -> Label:
	var l := lab("Esc — закрыть", "caps", 12, Color(0.85, 0.82, 0.72, 0.8), Vector2(1400, 866))
	l.create_tween().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(3.0)
	return l

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2(k, k)
	stage.position = (vs - STAGE * k) * 0.5

## HUD игры (портреты, полосы, строка вверху) не выглядывает из-под экрана
func _hide_hud(v: bool) -> void:
	var g = G.game
	for nm in ["combat_hud", "hud_root"]:
		var n = g.get(nm)
		if n != null and is_instance_valid(n) and "visible" in n:
			if v:
				_hud_was[nm] = n.visible
				n.visible = false
			elif _hud_was.has(nm):
				n.visible = _hud_was[nm]

func lab(text: String, font: String, sz: int, col: Color, pos: Vector2, w := 0.0, parent: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", MGUI.font(font))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	if w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(w, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else stage).add_child(l)
	l.text = text            # текст — после добавления в сцену: заданный раньше растягивал подпись в одну строку
	return l

func add_item(n: Control, key) -> int:
	var i := items.size()
	items.append({"node": n, "key": key})
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	n.mouse_entered.connect(func():
		if mode == "list":
			select(i))
	n.gui_input.connect(func(e):
		if mode == "list" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			select(i)
			_activate(i))
	return i

func select(i: int, quiet := false) -> void:
	if items.is_empty():
		return
	i = clampi(i, 0, items.size() - 1)
	if i == sel:
		return
	var prev := sel
	sel = i
	_on_select(i, prev)
	if not quiet:
		G.game.main.ui("hover", 1.0 + float(i % 5) * 0.03)

## Соседний предмет в направлении d: ближайший по ходу, сбоку — с тройным штрафом
func step(d: Vector2) -> void:
	if items.is_empty():
		return
	if sel < 0:
		select(0)
		return
	var c0: Vector2 = _center(sel)
	var best := -1
	var bs := INF
	for i in items.size():
		if i == sel:
			continue
		var v: Vector2 = _center(i) - c0
		var along := v.dot(d)
		if along <= 8.0:
			continue
		var side := absf(v.dot(Vector2(-d.y, d.x)))
		var s := along + side * 3.0
		if s < bs:
			bs = s
			best = i
	if best >= 0:
		select(best)

func _center(i: int) -> Vector2:
	var n: Control = items[i]["node"]
	return n.position + n.size * 0.5

func _input(e: InputEvent) -> void:
	if not visible:
		return
	var d := Vector2.ZERO
	var act := ""
	if e is InputEventKey and e.pressed:
		match e.physical_keycode:
			KEY_W, KEY_UP: d = Vector2.UP
			KEY_S, KEY_DOWN: d = Vector2.DOWN
			KEY_A, KEY_LEFT: d = Vector2.LEFT
			KEY_D, KEY_RIGHT: d = Vector2.RIGHT
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: act = "go"
			KEY_ESCAPE, KEY_BACKSPACE: act = "back"
		if e.echo and act != "":
			act = ""
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_DPAD_UP: d = Vector2.UP
			JOY_BUTTON_DPAD_DOWN: d = Vector2.DOWN
			JOY_BUTTON_DPAD_LEFT: d = Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: d = Vector2.RIGHT
			JOY_BUTTON_A: act = "go"
			JOY_BUTTON_B: act = "back"
	else:
		return
	get_viewport().set_input_as_handled()
	if mode == "busy":
		return
	if act == "go" and GameClock.ms() - opened_ms < 150:
		return                       # то же нажатие E, что открыло экран
	if d != Vector2.ZERO:
		_nav(d)
	elif act == "go":
		_activate(sel)
	elif act == "back":
		if not _back():
			close()

## переопределяют наследники
func _on_select(_i: int, _prev: int) -> void:
	pass

func _activate(_i: int) -> void:
	pass

func _back() -> bool:
	return false

func _nav(d: Vector2) -> void:
	if mode == "list":
		step(d)

func close() -> void:
	if not is_inside_tree():
		return
	_hide_hud(false)
	G.game.main.ui("close")
	MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	closed.emit()
	queue_free()

# ---------------------------------------------------------------- общие рисунки
## Бумага с неровным краем (rect в своих координатах), seed — чтобы каждый лист был свой
static func paper_poly(r: Rect2, seed_v: int, rough := 2.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	var nx := maxi(4, int(r.size.x / 22.0))
	var ny := maxi(4, int(r.size.y / 22.0))
	for k in nx:
		pts.append(Vector2(lerpf(r.position.x, r.end.x, k / float(nx)), r.position.y + rng.randf_range(-rough, rough)))
	for k in ny:
		pts.append(Vector2(r.end.x + rng.randf_range(-rough, rough), lerpf(r.position.y, r.end.y, k / float(ny))))
	for k in nx:
		pts.append(Vector2(lerpf(r.end.x, r.position.x, k / float(nx)), r.end.y + rng.randf_range(-rough, rough)))
	for k in ny:
		pts.append(Vector2(r.position.x + rng.randf_range(-rough, rough), lerpf(r.end.y, r.position.y, k / float(ny))))
	return pts

## Наклейка «НОВОЕ»: маленький красный ярлык
static func draw_new(ci: CanvasItem, at: Vector2, ang := -0.08) -> void:
	var f := MGUI.font("caps")
	ci.draw_set_transform(at, ang, Vector2.ONE)
	ci.draw_rect(Rect2(Vector2(0, 0), Vector2(58, 20)), Color(0.74, 0.12, 0.12))
	ci.draw_rect(Rect2(Vector2(0, 0), Vector2(58, 20)), Color(1, 0.85, 0.8, 0.5), false, 1.0)
	ci.draw_string(f, Vector2(7, 15), "НОВОЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.94, 0.88))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Навесной замок: дужка и корпус со скважиной
static func draw_padlock(ci: CanvasItem, c: Vector2, s: float, col := Color(0.55, 0.5, 0.4)) -> void:
	ci.draw_arc(c + Vector2(0, -6) * s, 9.0 * s, PI, TAU, 14, col.darkened(0.2), 4.0 * s)
	ci.draw_rect(Rect2(c + Vector2(-13, -6) * s, Vector2(26, 22) * s), col)
	ci.draw_rect(Rect2(c + Vector2(-13, -6) * s, Vector2(26, 22) * s), col.darkened(0.45), false, 1.5 * s)
	ci.draw_circle(c + Vector2(0, 3) * s, 3.0 * s, Color(0.08, 0.07, 0.06))
	ci.draw_rect(Rect2(c + Vector2(-1.5, 3) * s, Vector2(3, 7) * s), Color(0.08, 0.07, 0.06))

## Цепь из звеньев между точками
static func draw_chain(ci: CanvasItem, a: Vector2, b: Vector2, s: float, col := Color(0.5, 0.48, 0.44, 1.0)) -> void:
	var step := 15.0 * s
	var n := int(a.distance_to(b) / step)
	var ang := (b - a).angle()
	var dark := Color(0.06, 0.06, 0.06, col.a * 0.8)
	for k in n:
		var p := a + (b - a) * (k + 0.5) / float(n)
		if k % 2 == 0:
			# звено плашмя: вытянутое кольцо с тенью и бликом
			ci.draw_set_transform(p + Vector2(1.5, 2.0) * s, ang, Vector2(1.0, 0.55))
			ci.draw_arc(Vector2.ZERO, 9.0 * s, 0, TAU, 14, dark, 4.0 * s)
			ci.draw_set_transform(p, ang, Vector2(1.0, 0.55))
			ci.draw_arc(Vector2.ZERO, 9.0 * s, 0, TAU, 14, col, 3.6 * s)
			ci.draw_arc(Vector2.ZERO, 9.0 * s, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.35 * col.a), 1.4 * s)
		else:
			# звено ребром
			ci.draw_set_transform(p, ang, Vector2.ONE)
			ci.draw_line(Vector2(-8, 1.5) * s, Vector2(8, 1.5) * s, dark, 4.0 * s)
			ci.draw_line(Vector2(-8, 0) * s, Vector2(8, 0) * s, col.darkened(0.15), 3.6 * s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
