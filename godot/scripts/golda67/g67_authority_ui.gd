class_name G67AuthorityUI
extends CanvasLayer
## Экран «АВТОРИТЕТ РАЙОНА» (стол улучшений в подъезде). Логика не здесь: ветки, цены, максимумы и условия —
## G67Data.UPGRADES / UP_COST, покупка и сохранение — Golda67.buy_up. Экран только показывает и покупает.
## Композиция — сцена 1600×900, вписанная в окно: шапка (название, смысл, жетон РЕСПЕКТА, вложено в дерево),
## слева сетка 3×3 из трёх групп (ТЕЛО, ЗАБЕГ, ЗАПАС — по порядку веток в данных), справа «удостоверение»
## выбранной ветки (уровень, сейчас → после, цена, печать состояния, действие или причина отказа). Полосы
## подсказок клавиш нет (решение владельца), HUD игры на время экрана спрятан.
## Управление: W/A/S/D или стрелки (и крестовина геймпада) — по сетке, Enter / пробел / A — купить уровень,
## Esc / B — закрыть; мышь: наведение выбирает, клик по карточке или по кнопке — купить. Подсказок клавиш на экране нет.

signal closed

const STAGE := Vector2(1600, 900)
const GROUPS := ["ТЕЛО", "ЗАБЕГ", "ЗАПАС"]
const BG := Color(0.055, 0.055, 0.06)
const PAPER := Color(0.84, 0.79, 0.67)
const PAPER_INK := Color(0.12, 0.1, 0.09)

var G: Golda67
var kind := "upgrades"
var cards: Array = []
var sel := 0
var stage: Control
var shade: ColorRect
var resp_l: Label
var spent_l: Label
var delta_l: Label
var doc: Control              # «удостоверение» справа
var d_no: Label
var d_name: Label
var d_face: Control
var d_level: Label
var d_now: Label
var d_after: Label
var d_cost: Label
var d_text: Label
var d_why: Label
var d_btn: Button
var d_stamp := ""
var opened_ms := 0
var shown_resp := 0.0

static func open(g67: Golda67) -> G67AuthorityUI:
	var u := G67AuthorityUI.new()
	u.G = g67
	u.layer = 56
	u.process_mode = Node.PROCESS_MODE_ALWAYS
	g67.game.add_child(u)
	u._build()
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	g67.events.append(["hub_ui", "upgrades"])
	return u

func _respect() -> int:
	return int(G.meta().get("respect", 0))

# ---------------------------------------------------------------- сборка
func _build() -> void:
	opened_ms = GameClock.ms()
	_hud(false)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.78, 0.18)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_fit()
	get_viewport().size_changed.connect(_fit)
	var board := Board.new()
	board.size = STAGE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(board)
	_header()
	_grid()
	_doc()
	shown_resp = float(_respect())
	_refresh_all()
	_select(0, true)
	# появление: доска чуть поднимается, карточки — по очереди
	stage.modulate.a = 0.0
	var tw := stage.create_tween().set_parallel(true)
	tw.tween_property(stage, "modulate:a", 1.0, 0.18)
	for i in cards.size():
		var c: G67UpCard = cards[i]
		var home := c.position
		c.position = home + Vector2(0, 18)
		c.modulate.a = 0.0
		tw.tween_property(c, "position", home, 0.22).set_delay(0.03 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(0.03 * i)

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2(k, k)
	stage.position = (vs - STAGE * k) * 0.5

func _lab(text: String, font: String, sz: int, col: Color, pos: Vector2, w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MGUI.font(font))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	if w > 0.0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(l)
	return l

func _header() -> void:
	_lab("СТОЛ В ПОДЪЕЗДЕ · ГОЛДА 67", "caps", 13, G67UpCard.BEIGE_DIM, Vector2(70, 42))
	_lab("АВТОРИТЕТ РАЙОНА", "display", 54, G67UpCard.BEIGE, Vector2(66, 56))
	_lab("Улучшения навсегда: покупаются за РЕСПЕКТ, который не сгорает, и работают в каждом забеге.", "ui", 16, Color(0.62, 0.6, 0.56), Vector2(70, 126), 720)
	# жетон РЕСПЕКТА справа: значок владельца, баланс, сколько вложено в дерево
	var tok := Token.new()
	tok.position = Vector2(1130, 40)
	tok.size = Vector2(400, 96)
	tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tok)
	var ic := G67Icons.rect("icon_respect", 74)
	if ic != null:
		ic.position = Vector2(1146, 51)
		stage.add_child(ic)
	_lab("РЕСПЕКТ НА РУКАХ", "caps", 12, G67UpCard.BEIGE_DIM, Vector2(1236, 52))
	resp_l = _lab("0", "mono", 40, G67UpCard.GOLD, Vector2(1234, 66))
	delta_l = _lab("", "mono", 22, G67UpCard.RED, Vector2(1380, 76))
	spent_l = _lab("", "caps", 11, G67UpCard.BEIGE_DIM, Vector2(1236, 114))

func _grid() -> void:
	var ups: Array = G67Data.UPGRADES.filter(func(u): return bool(u["live"]))      # неработающие ветки не показываем
	var x0 := 120.0
	var y0 := 178.0
	for gi in GROUPS.size():
		var y := y0 + gi * 220.0
		# вкладка группы: вертикальная полоса с надписью
		var tab := GroupTab.new()
		tab.text = GROUPS[gi]
		tab.position = Vector2(66, y)
		tab.size = Vector2(36, G67UpCard.SIZE.y)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(tab)
		for ci in 3:
			var i := gi * 3 + ci
			if i >= ups.size():
				break
			var c := G67UpCard.new()
			c.setup(ups[i], i, GROUPS[gi])
			c.position = Vector2(x0 + ci * 322.0, y)
			c.mouse_entered.connect(func(): _select(i))
			c.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_select(i)
					_buy())
			stage.add_child(c)
			cards.append(c)

func _doc() -> void:
	doc = Doc.new()
	doc.position = Vector2(1110, 178)
	doc.size = Vector2(430, 630)
	doc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doc.ui = self
	stage.add_child(doc)
	var x := 1136.0
	d_no = _lab("", "mono", 13, Color(PAPER_INK, 0.7), Vector2(x, 196))
	d_name = _lab("", "display", 34, PAPER_INK, Vector2(x, 216), 270)
	d_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	d_face = Face.new()
	d_face.position = Vector2(1404, 204)
	d_face.size = Vector2(112, 112)
	d_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_face.ui = self
	stage.add_child(d_face)
	d_level = _lab("", "caps", 14, PAPER_INK, Vector2(x, 330))
	_lab("СЕЙЧАС", "caps", 11, Color(PAPER_INK, 0.6), Vector2(x, 392))
	d_now = _lab("", "ui_b", 20, PAPER_INK, Vector2(x, 408), 380)
	_lab("ПОСЛЕ ПОКУПКИ", "caps", 11, Color(PAPER_INK, 0.6), Vector2(x, 446))
	d_after = _lab("", "ui_b", 22, G67UpCard.BORDO, Vector2(x, 462), 380)
	d_cost = _lab("", "mono", 18, PAPER_INK, Vector2(x, 510))
	d_text = _lab("", "ui", 15, Color(PAPER_INK, 0.85), Vector2(x, 548), 380)
	d_why = _lab("", "ui_b", 15, G67UpCard.BORDO, Vector2(x, 650), 380)
	d_btn = Button.new()
	d_btn.position = Vector2(x, 724)
	d_btn.size = Vector2(380, 58)
	d_btn.focus_mode = Control.FOCUS_NONE
	d_btn.add_theme_font_override("font", MGUI.font("caps"))
	d_btn.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER_INK if st != "hover" else Color(0.22, 0.08, 0.09)
		if st == "disabled":
			sb.bg_color = Color(PAPER_INK, 0.25)
		sb.border_color = G67UpCard.GOLD if st != "disabled" else Color(PAPER_INK, 0.3)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_offset = Vector2(3, 4)
		d_btn.add_theme_stylebox_override(st, sb)
	d_btn.add_theme_color_override("font_color", G67UpCard.GOLD)
	d_btn.add_theme_color_override("font_hover_color", G67UpCard.GOLD)
	d_btn.add_theme_color_override("font_disabled_color", Color(PAPER_INK, 0.55))
	d_btn.pressed.connect(_buy)
	stage.add_child(d_btn)

# ---------------------------------------------------------------- данные и выбор
func _refresh_all() -> void:
	var have := _respect()
	for c in cards:
		var cc: G67UpCard = c
		cc.refresh(G.up(cc.id), G.up_cost(cc.id), have)
	var spent := 0
	var total := 0
	for u in G67Data.UPGRADES:
		if not bool(u["live"]):
			continue
		var lvl: int = G.up(String(u["id"]))
		for k in int(u["max"]):
			total += int(G67Data.UP_COST[k])
			if k < lvl:
				spent += int(G67Data.UP_COST[k])
	spent_l.text = "ВЛОЖЕНО В ДЕРЕВО: %d ИЗ %d" % [spent, total]
	_doc_fill()

func _select(i: int, instant := false) -> void:
	i = clampi(i, 0, cards.size() - 1)
	if i == sel and not instant:
		return
	if sel >= 0 and sel < cards.size():
		(cards[sel] as G67UpCard).set_selected(false)
	sel = i
	(cards[sel] as G67UpCard).set_selected(true)
	if not instant:
		G.game.main.ui("move", 1.0 + float(i % 3) * 0.04)
	_doc_fill()
	doc.modulate.a = 0.75
	doc.create_tween().tween_property(doc, "modulate:a", 1.0, 0.12)

func _doc_fill() -> void:
	if cards.is_empty():
		return
	var c: G67UpCard = cards[sel]
	var u: Dictionary = c.info
	d_no.text = "УДОСТОВЕРЕНИЕ № %02d · %s" % [c.idx + 1, c.group]
	d_name.text = String(u["name"])
	_fit_name()
	d_level.text = "УРОВЕНЬ %d ИЗ %d" % [c.lv, c.mx]
	d_now.text = G67UpCard.value_text(c.id, c.lv)
	d_text.text = "%s за уровень." % _cap(String(u["per"]))
	d_why.text = ""
	match c.state:
		"lock":
			d_after.text = G67UpCard.value_text(c.id, 1)
			d_cost.text = "ЦЕНА ПЕРВОГО УРОВНЯ: %d РЕСПЕКТА" % int(G67Data.UP_COST[0])
			d_why.text = "Закрыто. Откроется " + String(u.get("wait", "позже")) + "."
			d_btn.text = "ЗАКРЫТО"
			d_btn.disabled = true
			d_stamp = "ЗАКРЫТО"
		"max":
			d_after.text = "дальше некуда — ветка на максимуме"
			d_cost.text = ""
			d_btn.text = "МАКСИМУМ"
			d_btn.disabled = true
			d_stamp = "МАКСИМУМ"
		"short":
			d_after.text = G67UpCard.value_text(c.id, c.lv + 1)
			d_cost.text = "ЦЕНА: %d РЕСПЕКТА" % c.cost
			d_why.text = "Не хватает %d РЕСПЕКТА. Его дают комнаты забега, элита и боссы." % (c.cost - _respect())
			d_btn.text = "НЕ ХВАТАЕТ РЕСПЕКТА"
			d_btn.disabled = true
			d_stamp = ""
		_:
			d_after.text = G67UpCard.value_text(c.id, c.lv + 1)
			d_cost.text = "ЦЕНА: %d РЕСПЕКТА" % c.cost
			d_btn.text = "КУПИТЬ УРОВЕНЬ · %d" % c.cost
			d_btn.disabled = false
			d_stamp = "ДОСТУПНО"
	doc.queue_redraw()
	d_face.queue_redraw()

## Название в удостоверении: по словам, шрифт меньше, пока самое длинное слово не влезет в строку
func _fit_name() -> void:
	var f := MGUI.font("display")
	var sz := 34
	var longest := 0.0
	while sz > 20:
		longest = 0.0
		for wd in d_name.text.split(" "):
			longest = maxf(longest, f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		if longest <= 262.0:
			break
		sz -= 2
	d_name.add_theme_font_size_override("font_size", sz)

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

func _buy() -> void:
	if cards.is_empty():
		return
	var c: G67UpCard = cards[sel]
	var was := _respect()
	if G.buy_up(c.id):
		G.game.main.ui("confirm", 1.1)
		_refresh_all()
		c.bought()
		var spent := was - _respect()
		delta_l.text = "−%d" % spent
		delta_l.modulate.a = 1.0
		delta_l.position.y = 76
		var tw := delta_l.create_tween().set_parallel(true)
		tw.tween_property(delta_l, "position:y", 52.0, 0.6)
		tw.tween_property(delta_l, "modulate:a", 0.0, 0.6).set_delay(0.25)
		d_after.modulate = Color(1, 1, 1, 0.2)
		d_after.create_tween().tween_property(d_after, "modulate:a", 1.0, 0.3)
	else:
		G.game.main.ui("deny")
		c.denied()
		d_why.modulate = Color(2.0, 1.4, 1.4)
		d_why.create_tween().tween_property(d_why, "modulate", Color.WHITE, 0.4)

func _process(dt: float) -> void:
	# счётчик РЕСПЕКТА догоняет баланс (после покупки — бежит вниз)
	var target := float(_respect())
	if absf(shown_resp - target) > 0.01:
		shown_resp = move_toward(shown_resp, target, maxf(1.0, absf(shown_resp - target)) * dt * 8.0)
	resp_l.text = str(int(round(shown_resp)))

# ---------------------------------------------------------------- ввод
func _input(e: InputEvent) -> void:
	var dir := Vector2i.ZERO
	var act := ""
	if e is InputEventKey and e.pressed:
		match e.physical_keycode:
			KEY_W, KEY_UP: dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN: dir = Vector2i(0, 1)
			KEY_A, KEY_LEFT: dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: dir = Vector2i(1, 0)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: act = "buy"
			KEY_ESCAPE, KEY_BACKSPACE: act = "close"
		if e.echo and act != "":
			act = ""
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_DPAD_UP: dir = Vector2i(0, -1)
			JOY_BUTTON_DPAD_DOWN: dir = Vector2i(0, 1)
			JOY_BUTTON_DPAD_LEFT: dir = Vector2i(-1, 0)
			JOY_BUTTON_DPAD_RIGHT: dir = Vector2i(1, 0)
			JOY_BUTTON_A: act = "buy"
			JOY_BUTTON_B: act = "close"
	else:
		return
	get_viewport().set_input_as_handled()
	if act == "buy" and GameClock.ms() - opened_ms < 150:
		return                       # то же нажатие E, что открыло экран
	if dir != Vector2i.ZERO:
		var col := sel % 3
		@warning_ignore("integer_division")
		var row := sel / 3
		col = posmod(col + dir.x, 3)
		row = posmod(row + dir.y, 3)
		_select(row * 3 + col)
	elif act == "buy":
		_buy()
	elif act == "close":
		close()

## HUD игры не выглядывает из-под экрана (портреты внизу слева)
var _hud_was := {}
func _hud(v: bool) -> void:
	for nm in ["combat_hud", "hud_root"]:
		var n = G.game.get(nm)
		if n != null and is_instance_valid(n) and "visible" in n:
			if not v:
				_hud_was[nm] = n.visible
				n.visible = false
			elif _hud_was.has(nm):
				n.visible = _hud_was[nm]

func close() -> void:
	if not is_inside_tree():
		return
	_hud(true)
	G.game.main.ui("close")
	MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)
	closed.emit()
	queue_free()

# ---------------------------------------------------------------- рисованные части
## Доска стола: графитовый лист с неровным краем, под удостоверением — тень
class Board extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2(40, 24), size - Vector2(80, 48))
		var pts := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 67
		for k in 40:
			pts.append(Vector2(lerpf(r.position.x, r.end.x, k / 39.0), r.position.y + rng.randf_range(-3, 3)))
		for k in 24:
			pts.append(Vector2(r.end.x + rng.randf_range(-3, 3), lerpf(r.position.y, r.end.y, k / 23.0)))
		for k in 40:
			pts.append(Vector2(lerpf(r.end.x, r.position.x, k / 39.0), r.end.y + rng.randf_range(-3, 3)))
		for k in 24:
			pts.append(Vector2(r.position.x + rng.randf_range(-3, 3), lerpf(r.end.y, r.position.y, k / 23.0)))
		draw_colored_polygon(pts, Color(0.07, 0.07, 0.075, 0.97))
		var pl := pts.duplicate()
		pl.append(pts[0])
		draw_polyline(pl, Color(0.2, 0.2, 0.21), 1.5)
		# линия под шапкой и строка «группа» — как разметка на доске
		draw_line(Vector2(66, 160), Vector2(1534, 160), Color(0.22, 0.22, 0.23), 1.0)
		for k in 60:
			draw_line(Vector2(66 + k * 24, 160), Vector2(66 + k * 24, 166), Color(0.22, 0.22, 0.23), 1.0)

## Жетон РЕСПЕКТА: металлическая табличка с заклёпками
class Token extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color(0.15, 0.15, 0.16))
		draw_rect(r, Color(0.32, 0.3, 0.27), false, 1.5)
		draw_line(Vector2(96, 12), Vector2(96, size.y - 12), Color(0.28, 0.27, 0.25), 1.0)
		for p in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), Vector2(size.x - 8, size.y - 8)]:
			draw_circle(p, 3.0, Color(0.32, 0.32, 0.34))

## Вкладка группы слева от ряда карточек
class GroupTab extends Control:
	var text := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2(8, 0), Vector2(4, size.y)), G67UpCard.BEIGE_DIM)
		var f := MGUI.font("caps")
		draw_set_transform(Vector2(28, size.y * 0.5), -PI * 0.5, Vector2.ONE)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, G67UpCard.BEIGE_DIM)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## «Удостоверение»: бежевая карточка-документ с фото-рамкой, линовкой полей и печатью состояния
class Doc extends Control:
	var ui
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, G67AuthorityUI.PAPER)
		draw_rect(r.grow(-8), Color(G67AuthorityUI.PAPER_INK, 0.35), false, 1.0)
		# полоса шапки документа
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 10)), G67UpCard.BORDO)
		# фото-рамка справа сверху
		draw_rect(Rect2(Vector2(286, 18), Vector2(128, 128)), Color(G67AuthorityUI.PAPER_INK, 0.12))
		draw_rect(Rect2(Vector2(286, 18), Vector2(128, 128)), Color(G67AuthorityUI.PAPER_INK, 0.6), false, 1.5)
		# линовка полей
		for y in [202, 262, 318, 360]:
			draw_line(Vector2(26, y), Vector2(size.x - 26, y), Color(G67AuthorityUI.PAPER_INK, 0.25), 1.0)
		# печать состояния
		if ui != null and String(ui.d_stamp) != "":
			var col := G67UpCard.BORDO if String(ui.d_stamp) == "ДОСТУПНО" else (Color(0.55, 0.42, 0.12) if String(ui.d_stamp) == "МАКСИМУМ" else Color(0.35, 0.33, 0.3))
			var f := MGUI.font("caps")
			var tw := f.get_string_size(ui.d_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_set_transform(Vector2(300, 178), -0.14, Vector2.ONE)
			draw_rect(Rect2(-tw * 0.5 - 12, -18, tw + 24, 34), Color(col, 0.85), false, 2.5)
			draw_string(f, Vector2(-tw * 0.5, 8), ui.d_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Крупный рисунок выбранной ветки в фото-рамке удостоверения
class Face extends Control:
	var ui
	func _draw() -> void:
		if ui == null or ui.cards.is_empty():
			return
		var c: G67UpCard = ui.cards[ui.sel]
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.11))
		G67UpCard.draw_face(self, c.id, Rect2(Vector2(8, 8), size - Vector2(16, 16)), c.state == "lock", c.lv, c.mx, c.t, c.golda)
