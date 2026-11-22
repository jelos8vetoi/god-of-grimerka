class_name G67KioskUI
extends G67Diorama
## Ларёк «ШАУРМА 67» — окно шаурмичной с улицы: световой короб с названием, в окне вертел, на стекле изнутри
## приклеены ламинированные ценники товаров (G67Data.KIOSK): название, цена в голде, что даёт, сколько осталось
## на забег. Недоступный — бледный с причиной (нет голды, кончилось, бафов больше нет). «С СОБОЙ» не висит,
## если брать уже нечего. Справа на прилавке — кошелёк (голда) и здоровье; после покупки из окна выдают чек.

const CARD := Vector2(300, 300)

var cards: Array = []
var leave_n: Control
var wallet: Label
var hp_l: Label
var receipt: Control
var receipt_l: Label

static func open(g67: Golda67) -> G67KioskUI:
	var u := G67KioskUI.new()
	u._open_base(g67, "kiosk")
	u._build()
	return u

func _build() -> void:
	var front := Front.new()
	front.size = STAGE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(front)
	lab("ДВОР · ПАРКОВКА · ОКНО ЛАРЬКА", "caps", 13, Color(0.86, 0.72, 0.52), Vector2(70, 160))
	var shown: Array = []
	for k in G67Data.KIOSK:
		if String(k["id"]) == "togo" and G.togo_pool().is_empty():
			continue                         # брать нечего — ценник не висит
		shown.append(k)
	var x0 := 800.0 - (shown.size() * CARD.x + (shown.size() - 1) * 30.0) * 0.5
	for i in shown.size():
		var k: Dictionary = shown[i]
		var c := Price.new()
		c.ui = self
		c.item = k
		c.tex = G67Icons.tex("icon_kiosk_" + String(k["id"]))
		c.position = Vector2(x0 + i * (CARD.x + 30.0), 300)
		c.size = CARD
		c.pivot_offset = Vector2(CARD.x * 0.5, 0)
		c.rotation = [-0.02, 0.012, -0.008][i % 3]
		stage.add_child(c)
		var nm := lab(String(k["name"]), "display", 26, Color(0.12, 0.08, 0.05), Vector2(18, 128), CARD.x - 36, c)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.size = Vector2(CARD.x - 36, 0)
		_fit_one(nm, 26, CARD.x - 36)
		c.desc_l = lab(String(k["desc"]), "ui", 15, Color(0.24, 0.18, 0.12), Vector2(18, 164), CARD.x - 36, c)
		c.state_l = lab("", "caps", 13, Color(0.5, 0.14, 0.1), Vector2(18, 266), CARD.x - 36, c)
		cards.append(c)
		add_item(c, String(k["id"]))
	# прилавок: кошелёк и здоровье
	var wl := lab("ГОЛДА", "caps", 13, Color(0.32, 0.24, 0.14), Vector2(1270, 690))
	wl.z_index = 1
	wallet = lab("", "mono", 40, Color(0.5, 0.1, 0.06), Vector2(1316, 704))
	hp_l = lab("", "ui_b", 17, Color(0.22, 0.16, 0.1), Vector2(1270, 760))
	var lv := Leave.new()
	lv.position = Vector2(84, 712)
	lv.size = Vector2(250, 86)
	lv.pivot_offset = lv.size * 0.5
	stage.add_child(lv)
	leave_n = lv
	add_item(lv, "leave")
	receipt = Receipt.new()
	receipt.position = Vector2(560, 650)
	receipt.size = Vector2(480, 120)
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt.modulate.a = 0.0
	stage.add_child(receipt)
	receipt_l = lab("", "mono", 17, Color(0.16, 0.14, 0.12), Vector2(24, 44), 430, receipt)
	_refresh()
	select(0, true)

func _fit_one(l: Label, sz: int, w: float) -> void:
	var f := MGUI.font("display")
	while sz > 16 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 2
	l.add_theme_font_size_override("font_size", sz)

func _refresh() -> void:
	wallet.text = str(int(G.run.get("golda", 0)))
	var p = G.game.player
	hp_l.text = "Здоровье %d / %d" % [int(ceil(p.hp)), int(p.max_hp)]
	for c in cards:
		var pc: Price = c
		var id := String(pc.item["id"])
		pc.why = G.kiosk_why(id)
		pc.left = G.kiosk_left(id)
		pc.price = G.kiosk_price(id)
		pc.state_l.text = (("ОСТАЛОСЬ: %d" % pc.left) if int(pc.item.get("per_visit", 1)) > 0 else "+40 здоровья") if pc.why == "" else pc.why.to_upper()
		pc.state_l.add_theme_color_override("font_color", Color(0.2, 0.36, 0.16) if pc.why == "" else Color(0.55, 0.14, 0.1))
		pc.modulate = Color.WHITE if pc.why == "" else Color(0.72, 0.68, 0.64)
		pc.queue_redraw()

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		_node(prev).call("set_selected", false)
	_node(i).call("set_selected", true)

func _node(i: int) -> Control:
	return items[i]["node"]

func _activate(i: int) -> void:
	if i < 0:
		return
	var key := String(items[i]["key"])
	if key == "leave":
		close()
		return
	var pc: Price = _node(i)
	var paid_price: int = G.kiosk_price(key)
	var got := G.kiosk_buy(key)
	if got == "":
		G.game.main.ui("deny")
		pc.wobble()
		return
	G.game.main.ui("confirm")
	pc.wobble()
	receipt_l.text = "%s — %d голды\n%s" % [String(pc.item["name"]), paid_price, got]
	var tw := receipt.create_tween()
	receipt.position.y = 690.0
	tw.tween_property(receipt, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(receipt, "position:y", 650.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()

# ---------------------------------------------------------------- рисунки
## Фасад ларька: крашеные панели, световой короб «ШАУРМА 67», окно с вертелом, прилавок
class Front extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1))                   # ночь
		draw_rect(Rect2(Vector2(40, 40), Vector2(size.x - 80, size.y - 40)), Color(0.55, 0.3, 0.16))     # фасад
		for x in range(40, int(size.x) - 40, 90):
			draw_line(Vector2(x, 40), Vector2(x, size.y), Color(0.45, 0.24, 0.12), 2.0)
		# световой короб
		var box := Rect2(Vector2(300, 52), Vector2(1000, 96))
		draw_rect(box.grow(18), Color(1.0, 0.85, 0.4, 0.08))
		draw_rect(box, Color(0.98, 0.84, 0.32))
		draw_rect(box, Color(0.5, 0.36, 0.1), false, 3.0)
		var f := MGUI.font("display")
		var t := "ШАУРМА 67"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		draw_string(f, Vector2(800 - w * 0.5, 124), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.5, 0.07, 0.05))
		# окно: тёплая глубина, вертел слева, полосатый навес
		var win := Rect2(Vector2(130, 196), Vector2(1340, 440))
		draw_rect(win, Color(0.3, 0.16, 0.08))
		draw_rect(Rect2(win.position, Vector2(win.size.x, 160)), Color(0.5, 0.26, 0.1, 0.5))
		for k in 12:
			draw_rect(Rect2(Vector2(130 + k * 112, 176), Vector2(56, 22)), Color(0.82, 0.16, 0.12))
			draw_rect(Rect2(Vector2(186 + k * 112, 176), Vector2(56, 22)), Color(0.94, 0.9, 0.82))
		draw_colored_polygon(PackedVector2Array([Vector2(196, 230), Vector2(244, 230), Vector2(232, 560), Vector2(208, 560)]), Color(0.55, 0.3, 0.14))
		draw_line(Vector2(220, 210), Vector2(220, 590), Color(0.7, 0.7, 0.7), 4.0)
		draw_rect(Rect2(Vector2(160, 230), Vector2(24, 330)), Color(1.0, 0.45, 0.15, 0.35))     # жар
		draw_rect(win, Color(0.2, 0.12, 0.06), false, 10.0)
		draw_line(Vector2(win.position.x, win.position.y + 6), Vector2(win.end.x, win.position.y + 6), Color(1, 1, 1, 0.06), 3.0)
		# прилавок
		draw_rect(Rect2(Vector2(90, 636), Vector2(1420, 34)), Color(0.66, 0.66, 0.68))
		draw_rect(Rect2(Vector2(90, 668), Vector2(1420, 10)), Color(0.3, 0.3, 0.32))
		# кошелёк на прилавке справа: картонная подставка под деньги
		draw_rect(Rect2(Vector2(1250, 680), Vector2(250, 120)), Color(0.85, 0.78, 0.6))
		draw_rect(Rect2(Vector2(1250, 680), Vector2(250, 120)), Color(0.4, 0.3, 0.2), false, 2.0)
		var gt := G67Icons.tex("icon_golda")
		if gt != null:
			draw_texture_rect(gt, Rect2(Vector2(1262, 708), Vector2(46, 46)), false)

## Ламинированный ценник на стекле: картинка товара, название, цена, что даёт, сколько осталось
class Price extends Control:
	var ui
	var item: Dictionary
	var price := 0
	var tex: Texture2D
	var desc_l: Label
	var state_l: Label
	var why := ""
	var left := 0
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.05 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func wobble() -> void:
		var r0 := rotation
		var tw := create_tween()
		tw.tween_property(self, "rotation", r0 + 0.04, 0.05)
		tw.tween_property(self, "rotation", r0 - 0.03, 0.06)
		tw.tween_property(self, "rotation", r0, 0.06)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.4))
		draw_rect(r, Color(0.97, 0.95, 0.88))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 120)), Color(0.98, 0.86, 0.36))
		# товар: картинка владельца или рисунок
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(size.x * 0.5 - 56, 6), Vector2(112, 112)), false)
		else:
			_food(String(item["id"]))
		# цена — красный кружок
		var pc := Vector2(size.x - 52, 92)
		draw_circle(pc, 40, Color(0.78, 0.12, 0.1))
		var f := MGUI.font("display")
		var t := str(price if price > 0 else int(item["price"]))
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		draw_string(f, pc + Vector2(-w * 0.5, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.95, 0.85))
		draw_string(MGUI.font("caps"), pc + Vector2(-17, 26), "ГОЛДЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.88, 0.8))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 3)), Color(1, 1, 1, 0.5))       # блик ламинации
		draw_rect(Rect2(Vector2(size.x * 0.5 - 40, -10), Vector2(80, 20)), Color(0.86, 0.82, 0.66, 0.85))   # скотч
		if why != "":
			draw_set_transform(Vector2(size.x * 0.42, 64), -0.18, Vector2.ONE)
			draw_rect(Rect2(Vector2(-110, -22), Vector2(220, 44)), Color(0.7, 0.12, 0.1, 0.8), false, 3.0)
			var s := "НЕТ" if why != "на забег всё" else "ВСЁ"
			var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(f, Vector2(-sw * 0.5, 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.7, 0.12, 0.1, 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if selected:
			draw_rect(r.grow(4), Color(0.98, 0.8, 0.4), false, 3.0)
	## шаурма в фольге / двойная / пакет «с собой» — простые рисунки, пока нет картинок владельца
	func _food(id: String) -> void:
		var c := Vector2(size.x * 0.4, 62)
		match id:
			"togo":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-38, -30), c + Vector2(38, -30), c + Vector2(46, 46), c + Vector2(-46, 46)]), Color(0.72, 0.56, 0.36))
				draw_line(c + Vector2(-38, -30), c + Vector2(38, -30), Color(0.5, 0.38, 0.22), 3.0)
				draw_string(MGUI.font("display"), c + Vector2(-20, 24), "67", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.5, 0.07, 0.05))
			_:
				var n := 2 if id == "double" else 1
				for k in n:
					var o := c + Vector2(-22 + k * 44, 0) if n == 2 else c
					draw_set_transform(o, -0.5, Vector2.ONE)
					draw_rect(Rect2(Vector2(-22, -44), Vector2(44, 88)), Color(0.86, 0.72, 0.46))
					draw_rect(Rect2(Vector2(-22, 6), Vector2(44, 38)), Color(0.78, 0.8, 0.84))
					draw_line(Vector2(-22, 6), Vector2(22, 6), Color(0.6, 0.62, 0.66), 2.0)
					draw_circle(Vector2(-6, -30), 6, Color(0.36, 0.6, 0.24))
					draw_circle(Vector2(8, -24), 5, Color(0.8, 0.22, 0.14))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Чек из окна после покупки
class Receipt extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.4))
		draw_colored_polygon(G67Diorama.paper_poly(r, 9, 1.2), Color(0.95, 0.94, 0.9))
		draw_string(MGUI.font("caps"), Vector2(24, 28), "ЧЕК · ШАУРМА 67", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.36, 0.3))
		for x in range(10, int(size.x) - 10, 14):
			draw_line(Vector2(x, size.y - 6), Vector2(x + 7, size.y), Color(0.7, 0.68, 0.62), 1.0)

## Табличка «ОТОЙТИ ОТ ОКНА»
class Leave extends Control:
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		create_tween().tween_property(self, "rotation", -0.04 if v else 0.0, 0.1)
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, 4, 2.4), Color(0.62, 0.48, 0.3))
		var f := MGUI.font("display")
		draw_string(f, Vector2(18, 38), "ОТОЙТИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.16, 0.1, 0.05))
		draw_string(f, Vector2(18, 70), "ОТ ОКНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.16, 0.1, 0.05))
		if selected:
			draw_rect(r.grow(3), Color(0.98, 0.8, 0.4), false, 2.5)
