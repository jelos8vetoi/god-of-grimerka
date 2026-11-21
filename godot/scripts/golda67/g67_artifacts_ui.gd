class_name G67ArtifactsUI
extends G67Diorama
## Коллекция артефактов — сервант на площадке: деревянный шкаф со стеклянными дверцами, три полки по шесть мест
## (18 артефактов G67Data.ARTIFACTS, значки владельца). Найденные (meta.artifacts) стоят на подставках в цвете,
## ещё не найденные — тёмные силуэты за стеклом с картонкой «?». Цвет таблички — редкость: обычный, редкий, событие.
## Справа — музейная карточка выбранного: значок, название, редкость, эффект, где искать.

const EVENT_SRC := {"garlic_aura": "ЖОНГЛЁР 67", "hamster_aura": "КРОТЫ ХОМЯКИ", "collar_67": "DOG CASINO 67"}
const RAR_COL := {"обычный": Color(0.62, 0.62, 0.6), "редкий": Color(0.86, 0.66, 0.24), "событие": Color(0.36, 0.66, 0.42)}
const CELL := Vector2(152, 196)
const ORIGIN := Vector2(128, 182)

var cells: Array = []
var card: Control
var c_icon: TextureRect
var c_name: Label
var c_rar: Label
var c_desc: Label
var c_src: Label
var count_l: Label

static func open(g67: Golda67) -> G67ArtifactsUI:
	var u := G67ArtifactsUI.new()
	u._open_base(g67, "artifacts")
	u._build()
	return u

func _build() -> void:
	var room := Cabinet.new()
	room.size = STAGE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(room)
	lab("ПОДЪЕЗД · ПЛОЩАДКА · СЕРВАНТ", "caps", 13, Color(0.7, 0.62, 0.5), Vector2(70, 30))
	lab("КОЛЛЕКЦИЯ АРТЕФАКТОВ", "display", 46, Color(0.92, 0.86, 0.72), Vector2(66, 46))
	var got: Array = G.meta().get("artifacts", [])
	count_l = lab("НАЙДЕНО %d ИЗ %d" % [got.size(), G67Data.ARTIFACTS.size()], "mono", 16, Color(0.9, 0.78, 0.5), Vector2(840, 78))
	for i in G67Data.ARTIFACTS.size():
		var a: Dictionary = G67Data.ARTIFACTS[i]
		var c := Cell.new()
		c.art = a
		c.has = got.has(String(a["id"]))
		c.tex = G67Icons.tex("icon_art_" + String(a["id"]))
		c.position = ORIGIN + Vector2((i % 6) * CELL.x, (i / 6) * (CELL.y + 26))
		c.size = CELL
		c.pivot_offset = Vector2(CELL.x * 0.5, CELL.y)
		stage.add_child(c)
		cells.append(c)
		add_item(c, i)
	# стекло дверец поверх полок: блики
	var glass := Glass.new()
	glass.size = STAGE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glass)
	_build_card()
	select(0, true)

func _build_card() -> void:
	card = Museum.new()
	card.ui = self
	card.position = Vector2(1150, 150)
	card.size = Vector2(400, 680)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(card)
	c_icon = TextureRect.new()
	c_icon.position = Vector2(1250, 186)
	c_icon.size = Vector2(200, 200)
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(c_icon)
	var x := 1180.0
	c_rar = lab("", "caps", 14, Color(0.45, 0.12, 0.1), Vector2(x, 408))
	c_name = lab("", "display", 30, Color(0.12, 0.1, 0.08), Vector2(x, 430), 340)
	c_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	c_desc = lab("", "ui", 17, Color(0.2, 0.17, 0.14), Vector2(x, 540), 340)
	c_src = lab("", "ui_b", 15, Color(0.4, 0.3, 0.2), Vector2(x, 720), 340)

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(cells[prev] as Cell).set_selected(false)
	var c: Cell = cells[i]
	c.set_selected(true)
	var a: Dictionary = c.art
	var rar := String(a["rar"])
	c_icon.texture = c.tex
	c_icon.modulate = Color.WHITE if c.has else Color(0.12, 0.1, 0.09, 0.9)
	c_rar.text = ("№ %02d · %s" % [i + 1, rar]).to_upper()
	c_name.text = String(a["name"]) if c.has else "???"
	c_desc.text = String(a["desc"]) if c.has else "Пока не найден. За стеклом только силуэт."
	if rar == "событие":
		c_src.text = "Только в своём событии: «%s»." % String(EVENT_SRC.get(String(a["id"]), "?"))
	else:
		c_src.text = "Лежит в кладовках двора — в забеге выбираешь один из двух."
	_fit_name()
	card.queue_redraw()

func _fit_name() -> void:
	var f := MGUI.font("display")
	var sz := 30
	while sz > 18:
		var longest := 0.0
		for wd in c_name.text.split(" "):
			longest = maxf(longest, f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		if longest <= 336.0 and f.get_multiline_string_size(c_name.text, HORIZONTAL_ALIGNMENT_LEFT, 340, sz).y <= 100.0:
			break
		sz -= 2
	c_name.add_theme_font_size_override("font_size", sz)

func _activate(i: int) -> void:
	if i < 0:
		return
	var c: Cell = cells[i]
	G.game.main.ui("card" if c.has else "deny")
	c.wobble()

# ---------------------------------------------------------------- рисунки
## Сервант: стена, деревянный корпус, три полки с подсветкой, кружевная салфетка сверху
class Cabinet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.16, 0.14))
		for x in range(0, int(size.x), 40):                # обои
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.22, 0.19, 0.16), 14.0)
		var b := Rect2(Vector2(96, 140), Vector2(984, 720))
		draw_rect(Rect2(b.position + Vector2(10, 12), b.size), Color(0, 0, 0, 0.5))
		draw_rect(b, Color(0.34, 0.2, 0.1))
		for k in 14:                                       # шпон
			var y := b.position.y + 10 + k * 52
			draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y + 6.0 * sin(k)), Color(0.25, 0.14, 0.07, 0.6), 1.0)
		var inner := b.grow(-20)
		draw_rect(inner, Color(0.13, 0.1, 0.08))
		for row in 3:
			var y := 182.0 + row * 222.0 + 196.0
			draw_rect(Rect2(Vector2(inner.position.x, y), Vector2(inner.size.x, 12)), Color(0.42, 0.26, 0.13))
			draw_rect(Rect2(Vector2(inner.position.x, y + 12), Vector2(inner.size.x, 4)), Color(0.08, 0.05, 0.03))
		draw_line(Vector2(b.get_center().x, b.position.y + 20), Vector2(b.get_center().x, b.end.y - 20), Color(0.28, 0.17, 0.08), 6.0)   # створки
		# салфетка на верху серванта
		for k in 18:
			draw_circle(Vector2(360 + k * 26, b.position.y - 2), 11, Color(0.9, 0.88, 0.82, 0.9))

## Стекло дверец: несколько косых бликов поверх полок
class Glass extends Control:
	func _draw() -> void:
		for p in [[Vector2(160, 170), 60.0], [Vector2(620, 170), 30.0], [Vector2(880, 170), 46.0]]:
			var a: Vector2 = p[0]
			var w: float = p[1]
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(w, 0), a + Vector2(w - 260, 660), a + Vector2(-260, 660)]), Color(1, 1, 1, 0.035))

## Место на полке: подставка, значок (найден — в цвете, нет — силуэт), табличка редкости, картонка «?»
class Cell extends Control:
	var art: Dictionary
	var has := false
	var tex: Texture2D
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.07 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func wobble() -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation", 0.05, 0.05)
		tw.tween_property(self, "rotation", -0.04, 0.06)
		tw.tween_property(self, "rotation", 0.0, 0.06)
	func _draw() -> void:
		var rar := String(art["rar"])
		var rc: Color = G67ArtifactsUI.RAR_COL.get(rar, Color.GRAY)
		if selected:
			# луч света сверху на выбранную полку
			draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.3, -30), Vector2(size.x * 0.7, -30), Vector2(size.x, size.y), Vector2(0, size.y)]), Color(1, 0.9, 0.7, 0.08))
		# подставка
		draw_rect(Rect2(Vector2(size.x * 0.18, size.y - 22), Vector2(size.x * 0.64, 12)), Color(0.22, 0.16, 0.1))
		draw_rect(Rect2(Vector2(size.x * 0.22, size.y - 26), Vector2(size.x * 0.56, 6)), Color(0.36, 0.26, 0.16))
		if tex != null:
			var r := Rect2(Vector2(14, 6), Vector2(size.x - 28, size.x - 28))
			if has:
				draw_texture_rect(tex, r, false)
			else:
				draw_texture_rect(tex, r, false, Color(0.05, 0.04, 0.04, 0.82))
		# табличка редкости
		draw_rect(Rect2(Vector2(size.x * 0.3, size.y - 8), Vector2(size.x * 0.4, 8)), rc)
		if not has:
			draw_set_transform(Vector2(size.x * 0.62, size.y * 0.52), 0.12, Vector2.ONE)
			draw_rect(Rect2(Vector2(-14, -18), Vector2(28, 34)), Color(0.8, 0.74, 0.6))
			draw_string(MGUI.font("display"), Vector2(-8, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.25, 0.2, 0.15))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if selected:
			draw_rect(Rect2(Vector2(2, 0), size - Vector2(4, 0)), Color(0.98, 0.78, 0.42, 0.9), false, 2.5)

## Музейная карточка на булавке
class Museum extends Control:
	var ui
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.5))
		draw_colored_polygon(G67Diorama.paper_poly(r, 18, 1.2), Color(0.92, 0.9, 0.84))
		draw_rect(Rect2(Vector2(100, 36), Vector2(200, 200)), Color(0.86, 0.83, 0.76))
		draw_rect(Rect2(Vector2(100, 36), Vector2(200, 200)), Color(0.3, 0.26, 0.2, 0.4), false, 1.5)
		draw_circle(Vector2(size.x * 0.5, 14), 7, Color(0.6, 0.14, 0.1))
		draw_line(Vector2(30, 380), Vector2(size.x - 30, 380), Color(0.2, 0.16, 0.12, 0.3), 1.0)
		draw_line(Vector2(30, 560), Vector2(size.x - 30, 560), Color(0.2, 0.16, 0.12, 0.3), 1.0)
