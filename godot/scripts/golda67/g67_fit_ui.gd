class_name G67FitUI
extends G67Diorama
## ВЫБЕРИ БАФ — вешалка на детской площадке (и награда за элиту): на перекладине висят три бумажные бирки, на каждой
## значок, название, «НОВЫЙ» или «ур. 1 → 2», пометка «РЕДКИЙ» и описание целиком. Ниже — «ПЕРЕВЫБРАТЬ», если остались.
## Выбор обязателен: Esc ничего не закрывает, бирки только вздрагивают. A/D и стрелки, Enter / Пробел / E, мышь, геймпад.

const CARD := Vector2(440, 520)
const CARD_X := [110.0, 580.0, 1050.0]
const CARD_Y := 250.0

var opts: Array = []
var rare := false
var cards: Array = []
var reroll_n: Control = null

static func open(g67: Golda67, options: Array, is_rare: bool):
	var u = load("res://scripts/golda67/g67_fit_ui.gd").new()
	u._open_base(g67, "fit")
	u.opts = options
	u.rare = is_rare
	u._build()
	return u

func _build() -> void:
	var wall := Wall.new()
	wall.size = STAGE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(wall)
	lab("ДВОР · СУМКА С ДОБЫЧЕЙ" if (G.world != null and G.world.dvor != null) else ("ПОДЗЕМКА · НАГРАДА" if G67District.is_podzemka() else "ДВОР · ДЕТСКАЯ ПЛОЩАДКА · ВЕШАЛКА"), "caps", 13, Color(0.72, 0.68, 0.6), Vector2(70, 70))
	lab("ВЫБЕРИ БАФ", "display", 46, Color(0.94, 0.88, 0.74), Vector2(66, 88))
	lab("Действует до конца забега", "ui", 18, Color(0.78, 0.72, 0.62), Vector2(70, 152))
	for k in opts.size():
		var id := String(opts[k])
		var f: Dictionary = G67Data.FITS[id]
		var c := Card.new()
		c.position = Vector2(float(CARD_X[k]), CARD_Y)
		c.size = CARD
		c.pivot_offset = Vector2(CARD.x * 0.5, 0)
		c.seed_v = 21 + k * 5
		c.rare = bool(f["rare"])
		c.tex = G67Icons.fit(id)
		stage.add_child(c)
		var lv := G.fit_lv(id)
		lab("БАФ · РЕДКИЙ" if c.rare else "БАФ", "caps", 16, Color(0.7, 0.14, 0.12) if c.rare else Color(0.36, 0.3, 0.22), Vector2(30, 128), 0.0, c)
		var nm := lab(String(f["name"]), "display", 32, Color(0.12, 0.1, 0.08), Vector2(30, 152), 380, c)
		var sz := 32
		var fnt := MGUI.font("display")
		while sz > 20 and fnt.get_string_size(nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > 380:
			sz -= 2
		nm.add_theme_font_size_override("font_size", sz)
		lab("НОВЫЙ" if lv == 0 else "ур. %d → %d" % [lv, lv + 1], "ui_b", 20, Color(0.7, 0.14, 0.12) if lv == 0 else Color(0.2, 0.32, 0.5), Vector2(30, 200), 380, c)
		lab(String(f["desc"]), "ui", 18, Color(0.2, 0.17, 0.13), Vector2(30, 246), 380, c)
		cards.append(c)
		add_item(c, id)
	if int(G.run.get("rerolls", 0)) > 0:
		var rr := Reroll.new()
		rr.position = Vector2(560, 800)
		rr.size = Vector2(480, 64)
		rr.pivot_offset = rr.size * 0.5
		rr.text = "ПЕРЕВЫБРАТЬ · осталось %d" % int(G.run["rerolls"])
		stage.add_child(rr)
		reroll_n = rr
		add_item(rr, "reroll")
	select(0, true)

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		items[prev]["node"].call("set_selected", false)
	items[i]["node"].call("set_selected", true)

func _activate(i: int) -> void:
	if i < 0 or mode != "list":
		return
	var key := String(items[i]["key"])
	if key == "reroll":
		G.game.main.ui("confirm")
		G.fit_reroll(rare)
		return
	mode = "busy"
	G.take_fit(key)

func _back() -> bool:
	G.game.main.ui("deny")
	for c in cards:
		(c as Card).wobble()
	return true

# ---------------------------------------------------------------- рисунки
## Стена площадки: тёмная доска, перекладина вешалки
class Wall extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.15))
		for x in range(0, int(size.x), 64):
			draw_rect(Rect2(Vector2(x, 0), Vector2(60, size.y)), Color(0.15, 0.15, 0.17))
		draw_rect(Rect2(Vector2(60, 214), Vector2(1480, 14)), Color(0.5, 0.5, 0.52))
		draw_rect(Rect2(Vector2(60, 226), Vector2(1480, 6)), Color(0.22, 0.22, 0.24))
		for x in [90.0, 1510.0]:
			draw_rect(Rect2(Vector2(x - 8, 200), Vector2(16, 60)), Color(0.34, 0.34, 0.36))
		draw_colored_polygon(PackedVector2Array([Vector2(300, 232), Vector2(1300, 232), Vector2(1560, 800), Vector2(40, 800)]), Color(1.0, 0.9, 0.6, 0.035))

class Card extends Control:
	var seed_v := 1
	var rare := false
	var tex: Texture2D
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.04 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func wobble() -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation", 0.03, 0.05)
		tw.tween_property(self, "rotation", -0.025, 0.07)
		tw.tween_property(self, "rotation", 0.0, 0.05)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_line(Vector2(size.x * 0.5, -22), Vector2(size.x * 0.5, 16), Color(0.7, 0.66, 0.5), 3.0)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, seed_v, 2.0), Color(0.93, 0.9, 0.82))
		draw_circle(Vector2(size.x * 0.5, 20), 7, Color(0.13, 0.13, 0.15))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 6)), Color(0.74, 0.12, 0.12) if rare else Color(0.86, 0.66, 0.24))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(size.x * 0.5 - 48, 34), Vector2(96, 96)), false)
		if rare:
			draw_rect(Rect2(Vector2(size.x - 130, 40), Vector2(104, 28)), Color(0.74, 0.12, 0.12, 0.85), false, 2.5)
			draw_string(MGUI.font("caps"), Vector2(size.x - 120, 60), "РЕДКИЙ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.74, 0.12, 0.12))
		if selected:
			draw_rect(r.grow(5), Color(0.98, 0.8, 0.4), false, 3.0)

class Reroll extends Control:
	var text := ""
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, 9, 2.0), Color(0.62, 0.48, 0.3))
		var f := MGUI.font("display")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f, Vector2((size.x - w) * 0.5, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.16, 0.1, 0.05))
		if selected:
			draw_rect(r.grow(3), Color(0.98, 0.8, 0.4), false, 2.5)
