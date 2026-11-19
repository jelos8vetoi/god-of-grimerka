## Интерфейс «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» в стиле GOD OF GRIMERKA (чёрные панели, рваные белые карточки, красные
## предупреждения, большие цифры долга) на столе 1600×900: HUD, уведомления телефона, экраны фаз дня, займы
## с мелким шрифтом, КАРТА ДОЛГОВ (граф займов: перетащи деньги на долг, выбери стратегию, посмотри последствия
## до подтверждения), вещи, магазин, события, звонки (переговоры), подработки (мини-игры), концовки, пауза.
class_name MLUI
extends CanvasLayer

const RED := Color(0.86, 0.09, 0.11)
const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const GREEN := Color(0.4, 0.9, 0.45)
const STAGE := Vector2(1600, 900)

var root                       # MicroloansRoot
var stage: Control
var font: Font
var serif: SystemFont
var hud := {}
var panel: Control             # открытый экран (слева)
var rows: Array = []           # [{label, act, ok}]
var sel := 0
var overlay: Control           # мини-игра или переговоры поверх всего
var notes_box: VBoxContainer
var screen := ""
var flow_sel: Array = []       # выбранные в карте долгов займы (для объединения)
var flow_focus := -1
var drag_money := false
var drag_pos := Vector2.ZERO
var pay_amount := 0
var flow_canvas: Control

func _ready() -> void:
	layer = 10
	font = load("res://assets/fonts/RussoOne-Regular.ttf")
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Bodoni MT Black", "Bodoni MT", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 900
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(stage)
	_hud()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k: float = min(vs.x / STAGE.x, vs.y / STAGE.y)
	stage.scale = Vector2.ONE * k
	stage.position = (vs - STAGE * k) * 0.5

func econ() -> MLEconomy:
	return root.econ

func txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func torn(w: float, h: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, rng.randf_range(-4.0, 4.0)))
		x += rng.randf_range(10.0, 26.0)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w + rng.randf_range(-8.0, 10.0), y))
		y += rng.randf_range(8.0, 16.0)
	x = w
	while x > 0.0:
		pts.append(Vector2(x, h + rng.randf_range(-4.0, 5.0)))
		x -= rng.randf_range(10.0, 26.0)
	y = h
	while y > 0.0:
		pts.append(Vector2(rng.randf_range(-10.0, 6.0), y))
		y -= rng.randf_range(8.0, 16.0)
	return pts

static func rub(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if v < 0 else "") + s + out + " ₽"

# ---------------- HUD ----------------
func _hud() -> void:
	var top := Polygon2D.new()
	top.polygon = torn(1560, 118, 3)
	top.color = Color(0.03, 0.03, 0.035, 0.88)
	top.position = Vector2(20, 14)
	stage.add_child(top)
	hud["day"] = txt(stage, "", 40, WHITE, Vector2(44, 22), serif)
	hud["phase"] = txt(stage, "", 20, RED, Vector2(48, 76), serif)
	txt(stage, "ДОЛГ", 16, SILVER, Vector2(360, 26))
	hud["debt"] = txt(stage, "", 60, RED, Vector2(356, 40), serif)
	txt(stage, "ДЕНЬГИ", 16, SILVER, Vector2(820, 26))
	hud["money"] = txt(stage, "", 44, WHITE, Vector2(816, 46), serif)
	txt(stage, "СТРЕСС", 14, SILVER, Vector2(1140, 30))
	txt(stage, "РЕПУТАЦИЯ", 14, SILVER, Vector2(1140, 64))
	for k in [["stress", 52, RED], ["rep", 86, WHITE]]:
		var bg := ColorRect.new()
		bg.color = Color(0.18, 0.18, 0.2)
		bg.position = Vector2(1250, int(k[1]) - 18)
		bg.size = Vector2(200, 12)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bg)
		var fg := ColorRect.new()
		fg.color = k[2]
		fg.position = bg.position
		fg.size = Vector2(0, 12)
		fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(fg)
		hud[k[0]] = fg
		hud[String(k[0]) + "_n"] = txt(stage, "", 16, WHITE, Vector2(1460, int(k[1]) - 24))
	hud["actions"] = txt(stage, "", 22, WHITE, Vector2(1140, 96), serif)
	notes_box = VBoxContainer.new()
	notes_box.position = Vector2(1180, 150)
	notes_box.size = Vector2(400, 400)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_box.add_theme_constant_override("separation", 6)
	stage.add_child(notes_box)

func refresh() -> void:
	var e := econ()
	if e == null or not is_instance_valid(hud["day"]):
		return
	hud["day"].text = "ДЕНЬ %d / %d" % [e.day, MLData.DAYS]
	hud["phase"].text = MLEconomy.PHASE_NAMES.get(e.phase, "") + ("  ·  коллекторы через %d дн." % (MLData.DAYS - e.day) if e.day < MLData.DAYS else "  ·  ПОСЛЕДНИЙ ДЕНЬ")
	hud["debt"].text = rub(e.total_debt())
	hud["money"].text = rub(e.money)
	hud["stress"].size.x = 200.0 * e.stress / 100.0
	hud["rep"].size.x = 200.0 * e.rep / 100.0
	hud["stress_n"].text = str(e.stress)
	hud["rep_n"].text = str(e.rep)
	hud["actions"].text = "ДЕЙСТВИЙ: %d" % e.actions + ("  (стресс отнял одно)" if e.stress >= 80 else "")
	if e.ending != "" and screen != "ending":
		ending()
	elif panel != null and rows.size() > 0:
		_paint()

## уведомление телефона: вылетает справа
func notify(text: String, kind: String) -> void:
	var col: Color = {"bad": RED, "warn": Color(1.0, 0.75, 0.3), "money": GREEN}.get(kind, WHITE)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07, 0.95)
	sb.border_color = col
	sb.border_width_left = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = ("📱 " if kind != "money" else "💸 ") + text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(370, 0)
	card.add_child(l)
	notes_box.add_child(card)
	notes_box.move_child(card, 0)
	card.modulate.a = 0.0
	card.position.x = 80
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(5.0)
	tw.chain().tween_property(card, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(card.queue_free)
	while notes_box.get_child_count() > 5:
		var c := notes_box.get_child(notes_box.get_child_count() - 1)
		notes_box.remove_child(c)
		c.queue_free()

# ---------------- экран (левая карточка со строками) ----------------
func open(title: String, lines: Array, items: Array, w := 760.0) -> Control:
	close_panel()
	panel = Control.new()
	panel.size = STAGE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var card := Polygon2D.new()
	card.polygon = torn(w, 700.0, title.hash())
	card.color = Color(0.04, 0.04, 0.05, 0.95)
	card.position = Vector2(30, 160)
	panel.add_child(card)
	var edge := Line2D.new()
	edge.points = card.polygon
	edge.closed = true
	edge.width = 2.0
	edge.default_color = WHITE
	card.add_child(edge)
	var h := txt(panel, title, 46, WHITE, Vector2(54, 160), serif)
	h.rotation = deg_to_rad(-1.5)
	var y := 226.0
	for s in lines:
		var l := txt(panel, String(s), 17, SILVER, Vector2(60, y))
		l.size = Vector2(w - 60, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += maxf(26.0, l.get_minimum_size().y + 6.0)
	y += 8.0
	rows = []
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(56, y)
	scroll.size = Vector2(w - 50, 840.0 - y)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(w - 70, 0)
	scroll.add_child(box)
	for it in items:
		var l2 := Label.new()
		l2.add_theme_font_override("font", serif)
		l2.add_theme_font_size_override("font_size", 25)
		l2.mouse_filter = Control.MOUSE_FILTER_STOP
		l2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size = Vector2(w - 80, 0)
		box.add_child(l2)
		var i := rows.size()
		rows.append({"label": l2, "text": it[0], "act": it[1], "why": it[2] if it.size() > 2 else Callable()})
		l2.mouse_entered.connect(func(): _select(i))
		l2.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
				_activate())
	sel = 0
	_paint()
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.15)
	return panel

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	rows = []

func _select(i: int) -> void:
	if rows.is_empty():
		return
	sel = posmod(i, rows.size())
	_paint()
	var l: Label = rows[sel]["label"]
	var sc := l.get_parent().get_parent() as ScrollContainer
	if sc != null:
		sc.ensure_control_visible.call_deferred(l)

func _why(r: Dictionary) -> String:
	var w = r["why"]
	return String(w.call()) if w is Callable and (w as Callable).is_valid() else ""

func _paint() -> void:
	for k in rows.size():
		var r: Dictionary = rows[k]
		var tx = r["text"]
		var s: String = String(tx.call()) if tx is Callable else String(tx)
		var why := _why(r)
		(r["label"] as Label).text = ("▶ " if k == sel else "   ") + s + ("  — " + why if why != "" else "")
		(r["label"] as Label).add_theme_color_override("font_color", (WHITE if k == sel else SILVER) if why == "" else GREY)

func _activate() -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	if _why(r) != "":
		if root.main != null and not root.quiet:
			root.main.sfx("sfx_block", -8.0, 1.2)
		return
	if root.main != null and not root.quiet:
		root.main.sfx("sfx_ui")
	(r["act"] as Callable).call()

func _unhandled_input(e: InputEvent) -> void:
	if overlay != null or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if screen == "flow" and _flow_keys(k):
		get_viewport().set_input_as_handled()
		return
	if k == KEY_W or k == KEY_UP:
		_select(sel - 1)
	elif k == KEY_S or k == KEY_DOWN:
		_select(sel + 1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_activate()
	elif k == KEY_ESCAPE:
		if screen in ["offers", "flow", "items", "shop", "jobs"]:
			show_phase()
		elif screen != "ending":
			pause_menu()
	else:
		return
	get_viewport().set_input_as_handled()

# ---------------- фазы ----------------
func intro() -> void:
	notify("Пахан, твои займы на %s. Через 7 дней приходят коллекторы." % rub(econ().total_debt()), "bad")

func show_phase() -> void:
	var e := econ()
	if e.ending != "":
		ending()
		return
	screen = e.phase
	match e.phase:
		"morning":
			_morning()
		"day":
			_day()
		"evening":
			_evening()
	root.save()

func _morning() -> void:
	var e := econ()
	var lines: Array = ["Пахан проснулся. Телефон уже гудит."]
	for L in e.active():
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var d: int = int(L["due"]) - e.day
		lines.append("%s · %s · %s" % [D["short"], rub(int(ceil(L["balance"]))), "ПРОСРОЧЕН %d дн." % int(L["overdue"]) if L["status"] == "overdue" else ("срок СЕГОДНЯ" if d <= 0 else "срок через %d дн." % d)])
	var items: Array = []
	if e.event_today != "" and not e.event_done:
		var E: Dictionary = MLData.EVENTS[e.event_today]
		lines.append("")
		lines.append("СОБЫТИЕ: " + String(E["title"]) + " — " + String(E["text"]))
		for c in (E["choices"] as Array).size():
			var cc := c
			items.append([String(E["choices"][c][0]), func():
				var r := e.resolve_event(cc)
				if r.has("fail"):
					notify(String(r["fail"]), "bad")
					return
				if r.has("talk"):
					var cl := e.active().filter(func(L): return L["status"] == "overdue")
					if not cl.is_empty():
						negotiate(int(cl[0]["id"]), func(): show_phase())
						return
				show_phase()])
	else:
		items.append(["НАЧАТЬ ДЕНЬ", func():
			e.next_phase()
			show_phase()])
	items.append(["КАРТА ДОЛГОВ", func(): debt_flow()])
	open("УТРО · ДЕНЬ %d" % e.day, lines, items)

func _day() -> void:
	var e := econ()
	var no_act := func(): return "действий нет" if e.actions <= 0 else ""
	var items: Array = []
	items.append([func(): return "ПОДРАБОТКИ (%d действ.)" % e.actions, func(): jobs()])
	items.append(["ЗАЙМЫ И ДОГОВОРЫ", func(): offers()])
	items.append(["КАРТА ДОЛГОВ — ПЛАТЕЖИ", func(): debt_flow()])
	items.append([func(): return "ОТДОХНУТЬ (−25 стресса)", func(): e.rest(), no_act])
	items.append([func(): return "ВЕЩИ (%d)" % e.inventory.size(), func(): items_screen()])
	items.append(["МАГАЗИН УЛУЧШЕНИЙ", func(): shop()])
	if e.can_finish():
		items.append(["ВСЁ ВЫПЛАЧЕНО — ЗАКОНЧИТЬ", func(): e.finish()])
	items.append(["ВЕЧЕР →", func():
		e.next_phase()
		show_phase()])
	open("ДЕНЬ %d" % e.day, ["Действий на сегодня: %d. Каждая подработка, отдых или договор — одно действие." % e.actions], items)

func _evening() -> void:
	var e := econ()
	var calls := e.callers()
	var lines: Array = ["Вечер. Звонят те, у кого срок завтра или уже прошёл."] if not calls.is_empty() else ["Вечер. Телефон молчит — подозрительно."]
	var items: Array = []
	for L in calls:
		var id := int(L["id"])
		if int(L.get("called", -1)) == e.day:
			continue
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		items.append(["☎ ОТВЕТИТЬ: %s (%s)" % [D["name"], rub(int(ceil(L["balance"])))], func():
			L["called"] = e.day
			negotiate(id, func(): show_phase())])
		items.append(["✕ СБРОСИТЬ %s (+стресс)" % D["short"], func():
			L["called"] = e.day
			e.stress = clampi(e.stress + 8, 0, 100)
			e.rep = clampi(e.rep - 2, 0, 100)
			e.say("Сбросил звонок %s. Перезвонят." % D["short"], "bad")
			show_phase()])
	items.append(["КАРТА ДОЛГОВ — ПЛАТЕЖИ", func(): debt_flow()])
	items.append(["СПАТЬ (ночь: проценты и штрафы) →", func():
		e.next_phase()
		show_phase()])
	open("ВЕЧЕР · ДЕНЬ %d" % e.day, lines, items)
	if not calls.is_empty():
		root.react("call")

# ---------------- займы ----------------
func offers() -> void:
	screen = "offers"
	var e := econ()
	var lines: Array = ["Сегодня дают. Условия видно сразу, мелкий шрифт — если прочитать договор."]
	var items: Array = []
	for O in e.offers:
		var D: Dictionary = MLData.LENDERS[O["lender"]]
		var id := int(O["id"])
		var clause: String = ("мелкий шрифт: " + (String(MLData.CLAUSES[O["clause"]][0]) if O["clause"] != "" else "нет")) if bool(O["known"]) else "мелкий шрифт: ??? (не читал)"
		lines.append("%s — %s на %d дн., %.1f%% в день · %s" % [D["name"], rub(int(O["amount"])), int(O["term"]), float(O["rate"]) * 100.0, clause])
		var pv := e.preview("take", {"offer": O})
		items.append(["ВЗЯТЬ %s %s → %s" % [D["short"], rub(int(O["amount"])), String(pv["lines"][0])], func():
			e.take(id)
			offers(), func(): return "действий нет" if e.actions <= 0 else ""])
		if not bool(O["known"]):
			items.append(["  изучить договор %s (1 действие)" % D["short"], func():
				e.study(id)
				offers(), func(): return "действий нет" if e.actions <= 0 else ""])
			items.append(["  позвонить оператору %s (+6 стресса)" % D["short"], func():
				e.call_operator(id)
				offers()])
	if e.offers.is_empty():
		lines.append("Сегодня никто не даёт — репутация или день не тот.")
	items.append(["РЕФИНАНСИРОВАТЬ / ОБЪЕДИНИТЬ — в карте долгов", func(): debt_flow()])
	items.append(["НАЗАД", func(): show_phase()])
	open("ЗАЙМЫ", lines, items, 1100.0)

# ---------------- карта долгов ----------------
## Граф: займы — узлы по дням срока (слева направо) и конторам (сверху вниз), рефинансирование — стрелки
## от закрытых к новому. Внизу — пачка денег: перетащи её на узел — откроется платёж. Справа — что будет.
func debt_flow() -> void:
	screen = "flow"
	close_panel()
	panel = Control.new()
	panel.size = STAGE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.93)
	bg.position = Vector2(20, 150)
	bg.size = Vector2(1140, 730)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	txt(panel, "КАРТА ДОЛГОВ ПАХАНА", 40, WHITE, Vector2(44, 156), serif)
	txt(panel, "Тащи пачку денег на долг · клик — выбрать · 1 погасить · 2 минимум · 3 продлить · 4 объединить выбранные · Q самый дорогой · E самый срочный · Esc назад", 14, SILVER, Vector2(48, 206))
	flow_canvas = Control.new()
	flow_canvas.position = Vector2(20, 230)
	flow_canvas.size = Vector2(1140, 640)
	flow_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(flow_canvas)
	flow_canvas.draw.connect(_flow_draw)
	flow_canvas.gui_input.connect(_flow_input)
	var side := txt(panel, "", 16, WHITE, Vector2(1180, 560))
	side.size = Vector2(400, 320)
	side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.name = "side"
	if flow_focus < 0 and not econ().active().is_empty():
		flow_focus = int(econ().active()[0]["id"])
	pay_amount = 0
	_flow_side()

func _node_pos(L: Dictionary) -> Vector2:
	var e := econ()
	var lane := MLData.LENDER_ORDER.find(String(L["lender"]))
	var x := 120.0 + clampf(float(int(L["due"]) - e.day + 1), 0.0, 8.0) * 115.0
	var same := e.loans.filter(func(o): return o["lender"] == L["lender"] and int(o["due"]) == int(L["due"]) and o["status"] != "closed")
	return Vector2(x, 90.0 + lane * 125.0 + same.find(L) * 34.0)

func _flow_draw() -> void:
	var e := econ()
	var c := flow_canvas
	# дни
	for d in 9:
		var x := 120.0 + d * 115.0
		c.draw_line(Vector2(x, 30), Vector2(x, 560), Color(1, 1, 1, 0.06), 1.0)
		var day := e.day + d - 1
		c.draw_string(font, Vector2(x - 26, 24), ("СЕГОДНЯ" if d == 1 else ("ПРОСРОЧ." if d == 0 else "ДЕНЬ %d" % day)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RED if d == 0 else (WHITE if day == MLData.DAYS else GREY))
	for lane in MLData.LENDER_ORDER.size():
		var D: Dictionary = MLData.LENDERS[MLData.LENDER_ORDER[lane]]
		c.draw_string(font, Vector2(6, 96 + lane * 125), String(D["short"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, D["col"])
	# связи рефинансирования
	for L in e.loans:
		if L.has("from") and L["status"] != "closed":
			for fid in L["from"]:
				var F := e.loan(int(fid))
				if not F.is_empty():
					var a := _node_pos(F) if F["status"] != "closed" else Vector2(60, _node_pos(L).y)
					c.draw_line(a, _node_pos(L), Color(1, 0.75, 0.3, 0.6), 3.0)
	# узлы
	for L in e.active():
		var p := _node_pos(L)
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		var r := Rect2(p - Vector2(54, 16), Vector2(150, 50))
		var focus: bool = int(L["id"]) == flow_focus
		c.draw_rect(r, Color(0.08, 0.08, 0.09))
		c.draw_rect(r, (RED if L["status"] == "overdue" else (D["col"] as Color)) if not focus else WHITE, false, 4.0 if focus else 2.0)
		if flow_sel.has(int(L["id"])):
			c.draw_rect(r.grow(5), Color(1, 0.8, 0.3), false, 2.0)
		c.draw_string(serif, p + Vector2(-46, 6), rub(int(ceil(L["balance"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE)
		c.draw_string(font, p + Vector2(-46, 26), "%.1f%%/д · штр %.0f%%" % [float(L["rate"]) * 100.0, float(L["fine"]) * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SILVER)
	# пачка денег
	var mp := drag_pos if drag_money else Vector2(560, 600)
	c.draw_rect(Rect2(mp - Vector2(60, 22), Vector2(120, 44)), Color(0.25, 0.55, 0.3))
	c.draw_string(serif, mp + Vector2(-52, 8), rub(e.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE)

func _flow_side() -> void:
	if panel == null or panel.get_node_or_null("side") == null:
		return
	var e := econ()
	var L := e.loan(flow_focus)
	var s := ""
	if L.is_empty() or L["status"] == "closed":
		s = "Выбери долг на карте."
	else:
		var D: Dictionary = MLData.LENDERS[L["lender"]]
		s = "%s\nостаток %s · срок день %d%s\nставка %.1f%% в день, штраф %.0f%% в день просрочки\n%s" % [D["name"], rub(int(ceil(L["balance"]))), int(L["due"]), " · ПРОСРОЧКА" if L["status"] == "overdue" else "",
			float(L["rate"]) * 100.0, float(L["fine"]) * 100.0, ("мелкий шрифт: " + String(MLData.CLAUSES[L["clause"]][0])) if bool(L["known"]) and L["clause"] != "" else ""]
		if pay_amount > 0:
			var pv := e.preview("pay", {"id": flow_focus, "amount": pay_amount})
			s += "\n\nПЛАТЁЖ %s (A/D −/+, Enter — оплатить):\n%s" % [rub(pay_amount), _pv(pv)]
		else:
			for kind in ["min", "extend"]:
				var pv2 := e.preview(kind, {"id": flow_focus})
				s += "\n\n[%s] %s%s" % ["2" if kind == "min" else "3", _pv(pv2), ("" if bool(pv2["ok"]) else " — нельзя: " + String(pv2["why"]))]
			var cw := e.can_call(flow_focus)
			s += "

[5] Позвонить в контору и договориться (1 действие)%s" % ("" if cw == "" else " — " + cw)
		if flow_sel.size() >= 1:
			var best := _best_refi()
			if best != "":
				s += "\n\n[4] %s" % _pv(e.preview("refinance", {"ids": flow_sel, "lender": best}))
	(panel.get_node("side") as Label).text = s
	if flow_canvas != null:
		flow_canvas.queue_redraw()
	refresh()

func _pv(pv: Dictionary) -> String:
	var ap := "≈" if pv.get("approx", false) else ""
	return " ".join(pv["lines"]) + " → деньги %s%s, долг %s%s" % [ap, rub(int(pv["money"])), ap, rub(int(pv["debt"]))]

func _best_refi() -> String:
	var e := econ()
	for lid in ["cash", "reshim", "bystro", "srochno"]:
		if bool(e.refinance_info(flow_sel, lid)["ok"]):
			return lid
	return ""

func _flow_input(ev: InputEvent) -> void:
	var e := econ()
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if Rect2(Vector2(500, 578), Vector2(120, 44)).has_point(ev.position) and e.money > 0:
				drag_money = true
				drag_pos = ev.position
				return
			for L in e.active():
				if Rect2(_node_pos(L) - Vector2(54, 16), Vector2(150, 50)).has_point(ev.position):
					flow_focus = int(L["id"])
					if Input.is_key_pressed(KEY_SHIFT) or flow_sel.has(flow_focus):
						if flow_sel.has(flow_focus):
							flow_sel.erase(flow_focus)
						else:
							flow_sel.append(flow_focus)
					pay_amount = 0
					_flow_side()
					return
		elif drag_money:
			drag_money = false
			for L in e.active():
				if Rect2(_node_pos(L) - Vector2(54, 16), Vector2(150, 50)).has_point(ev.position):
					flow_focus = int(L["id"])
					pay_amount = mini(e.money, int(ceil(L["balance"])))
			_flow_side()
	elif ev is InputEventMouseMotion and drag_money:
		drag_pos = ev.position
		flow_canvas.queue_redraw()

func _flow_keys(k: int) -> bool:
	var e := econ()
	var L := e.loan(flow_focus)
	match k:
		KEY_ESCAPE:
			show_phase()
		KEY_ENTER, KEY_KP_ENTER, KEY_1:
			if not L.is_empty():
				e.pay(flow_focus, pay_amount if pay_amount > 0 else int(ceil(L["balance"])))
				pay_amount = 0
				_flow_side()
		KEY_2:
			if not L.is_empty() and not e.pay_min(flow_focus):
				notify(String(e.preview("min", {"id": flow_focus})["why"]), "bad")
			_flow_side()
		KEY_3:
			if not L.is_empty() and not e.extend(flow_focus):
				notify(String(e.extend_info(L)["why"]), "bad")
			_flow_side()
		KEY_4:
			var best := _best_refi()
			if best == "" or not e.refinance(flow_sel, best):
				notify("Объединить нельзя: " + (String(e.refinance_info(flow_sel, "cash")["why"]) if not flow_sel.is_empty() else "выбери долги (Shift+клик)"), "bad")
			flow_sel = []
			flow_focus = int(e.active()[0]["id"]) if not e.active().is_empty() else -1
			_flow_side()
		KEY_5:
			if not L.is_empty() and e.start_call(flow_focus):
				negotiate(flow_focus, func(): debt_flow())
			elif not L.is_empty():
				notify(e.can_call(flow_focus), "bad")
		KEY_A, KEY_LEFT:
			pay_amount = maxi(0, pay_amount - 500)
			_flow_side()
		KEY_D, KEY_RIGHT:
			if not L.is_empty():
				pay_amount = mini(mini(e.money, int(ceil(L["balance"]))), pay_amount + 500)
			_flow_side()
		KEY_Q, KEY_E:
			# стратегии: самый дорогой (ставка+штраф) или самый срочный
			var lst := e.active()
			if lst.is_empty():
				return true
			lst.sort_custom(func(a, b): return (float(a["rate"]) + float(a["fine"]) > float(b["rate"]) + float(b["fine"])) if k == KEY_Q else (int(a["due"]) < int(b["due"])))
			flow_focus = int(lst[0]["id"])
			pay_amount = mini(e.money, int(ceil(lst[0]["balance"])))
			notify(("Самый дорогой" if k == KEY_Q else "Самый срочный") + ": " + String(MLData.LENDERS[lst[0]["lender"]]["short"]), "info")
			_flow_side()
		KEY_W, KEY_S, KEY_UP, KEY_DOWN:
			var lst2 := e.active()
			if lst2.is_empty():
				return true
			var i := lst2.map(func(x): return int(x["id"])).find(flow_focus)
			flow_focus = int(lst2[posmod(i + (1 if k in [KEY_S, KEY_DOWN] else -1), lst2.size())]["id"])
			pay_amount = 0
			_flow_side()
		_:
			return false
	return true

# ---------------- подработки ----------------
func jobs() -> void:
	screen = "jobs"
	var e := econ()
	var items: Array = []
	for jid in MLData.JOB_ORDER:
		var J: Dictionary = MLData.JOBS[jid]
		var j := String(jid)
		items.append(["%s — %s" % [J["name"], J["desc"]], func(): run_job(j), func():
			if e.actions <= 0:
				return "действий нет"
			if not e.job_open(j):
				return "закрыто" + (" (нужна репутация %d или контакты)" % int(J["rep"]) if j == "sound" else " (пылесос сломан)")
			return ""])
	items.append(["НАЗАД", func(): show_phase()])
	open("ПОДРАБОТКИ", ["Каждая — своя мини-игра. Чем лучше сделал, тем больше заплатят. Стресс мешает."], items, 1000.0)

func run_job(jid: String, bot := -1.0) -> MLJob:
	var e := econ()
	var J: MLJob
	match jid:
		"podezd":
			J = MLJobPodezd.new()
		"repair":
			J = MLJobRepair.new()
		"sound":
			J = MLJobSound.new()
		_:
			J = MLJobJunk.new()
	J.bot = bot
	stage.add_child(J)
	J.call("setup", font, serif, e.stress, e.rng.randi())
	overlay = J
	close_panel()
	J.finished.connect(func(score: float, extra: Array):
		overlay = null
		J.queue_free()
		if jid == "junk":
			e.junk_done(extra)
		else:
			e.job_done(jid, score)
		show_phase())
	return J

# ---------------- переговоры ----------------
func negotiate(id: int, after: Callable) -> MLNegotiation:
	var N := MLNegotiation.new()
	stage.add_child(N)
	N.setup(econ(), id, font, serif)
	overlay = N
	close_panel()
	root.react("call")
	if root.main != null and not root.quiet:
		root.main.sfx("sfx_charge", -6.0, 0.6)
	N.done.connect(func(r: Dictionary):
		var tw := N.create_tween()
		tw.tween_interval(0.9 if root.quiet == false else 0.05)
		tw.tween_callback(func():
			overlay = null
			N.queue_free()
			notify(String(r.get("text", "")), "money" if bool(r.get("won", false)) else "bad")
			after.call()))
	return N

# ---------------- вещи и магазин ----------------
func items_screen() -> void:
	screen = "items"
	var e := econ()
	var items: Array = []
	var reshim := e.active().filter(func(L): return L["lender"] == "reshim")
	for k in e.inventory.size():
		var it: Array = MLData.JUNK[int(e.inventory[k])]
		var kk := k
		items.append(["ПРОДАТЬ: %s" % it[0], func():
			e.sell_item(kk)
			items_screen()])
		if not reshim.is_empty():
			var rid := int(reshim[0]["id"])
			items.append(["  отдать Гене в счёт долга: %s" % it[0], func():
				e.barter(kk, rid)
				items_screen()])
	items.append(["НАЗАД", func(): show_phase()])
	open("ВЕЩИ", ["То, что оставил из хлама. Можно продать или отдать «Решим вопрос» в счёт долга — Гена берёт не всё."] if not e.inventory.is_empty() else ["Пусто. Вещи появляются, если в разборе хлама выбрать «ОСТАВИТЬ»."], items)

func shop() -> void:
	screen = "shop"
	var e := econ()
	var items: Array = []
	for uid in MLData.UPGRADE_ORDER:
		var U: Dictionary = MLData.UPGRADES[uid]
		var u := String(uid)
		items.append(["%s — %s (%s)" % [U["name"], U["desc"], "куплено" if e.upgrades.has(u) else rub(int(U["cost"]))], func():
			e.buy(u)
			shop(), func(): return "" if not e.upgrades.has(u) and e.money >= int(U["cost"]) else ("куплено" if e.upgrades.has(u) else "не хватает денег")])
	items.append(["НАЗАД", func(): show_phase()])
	open("МАГАЗИН", ["Улучшения меняют, как играть: видеть мелкий шрифт, точные цифры, лишнее действие, новые ответы в переговорах."], items, 1100.0)

# ---------------- пауза и концовка ----------------
func pause_menu() -> void:
	open("ПАУЗА", ["Игра сохраняется сама после каждой фазы."], [
		["ПРОДОЛЖИТЬ", func(): show_phase()],
		["ЗАНОВО (новая неделя)", func():
			econ().new_game(int(Time.get_ticks_usec() % 2147483647))
			show_phase()],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu()]])
	screen = "pause"

func ending() -> void:
	screen = "ending"
	var e := econ()
	var E: Array = MLData.ENDINGS.get(e.ending, MLData.ENDINGS["pit"])
	MLSave.record_ending(e)
	var lines: Array = [String(E[1]), "", "День %d · деньги %s · долг %s" % [e.day, rub(e.money), rub(e.total_debt())],
		"Займов взято: %d · закрыто: %d (переговорами: %d) · подработок: %d" % [int(e.stats["taken"]), int(e.stats["closed"]), int(e.stats["talk_closed"]), int(e.stats["jobs"])],
		"Переплачено процентами %s, штрафами и комиссиями %s" % [rub(int(e.stats["interest"])), rub(int(e.stats["fines"]))]]
	var all: Dictionary = MLSave.load_all().get("endings", {})
	lines.append("Открыто концовок: %d из %d" % [all.size(), MLData.ENDINGS.size()])
	open(String(E[0]), lines, [
		["ЕЩЁ НЕДЕЛЯ", func():
			e.new_game(int(Time.get_ticks_usec() % 2147483647))
			intro()
			show_phase()],
		["В МЕНЮ РЕЖИМОВ", func(): root.quit_to_menu()]], 1000.0)
	root.react("money" if e.ending != "pit" else "bad")
