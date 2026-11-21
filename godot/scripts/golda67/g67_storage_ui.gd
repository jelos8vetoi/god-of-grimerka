class_name G67StorageUI
extends G67Diorama
## КЛАДОВКА — открытый гаражный бокс во дворе: под лампочкой на верстаке лежат два артефакта (Golda67.storage_offer),
## под каждым — бумажка на малярном скотче: название, редкость, что делает. Снизу — карманы куртки (слоты забега:
## занятые — значок, пустые — пунктир). Взять — Enter или клик; если карманы полны, выбираешь, что выложить.
## «Оставить и уйти» — картонка у ворот (или Esc): гараж остаётся открытым до выбора двери.

const RAR_COL := {"обычный": Color(0.62, 0.62, 0.6), "редкий": Color(0.86, 0.66, 0.24), "событие": Color(0.36, 0.66, 0.42)}
const ART_X := [470.0, 1010.0]
const SLOT := Vector2(96, 96)

var offer: Array = []
var arts_n: Array = []          # Thing на верстаке
var slots_n: Array = []         # Pocket
var leave_n: Control
var tapes: Array = []           # [название, редкость, эффект] под каждым артефактом
var pick := ""                  # выбранный артефакт, когда карманы полны и надо выложить другой
var note: Label
var slot0 := 0                  # индекс первого кармана среди items

static func open(g67: Golda67) -> G67StorageUI:
	var u := G67StorageUI.new()
	u._open_base(g67, "storage")
	u._build()
	return u

func _build() -> void:
	var room := Garage.new()
	room.size = STAGE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(room)
	lab("ДВОР · ГАРАЖИ · ОТКРЫТЫЙ БОКС", "caps", 13, Color(0.72, 0.66, 0.55), Vector2(70, 112))
	lab("КЛАДОВКА", "display", 46, Color(0.94, 0.88, 0.74), Vector2(66, 128))
	lab("Возьми одно. Второе останется лежать в гараже.", "ui", 17, Color(0.78, 0.72, 0.62), Vector2(70, 190))
	offer = G.storage_offer().duplicate()
	for k in offer.size():
		var id := String(offer[k])
		var a := Golda67.art_info(id)
		var t := Thing.new()
		t.tex = G67Icons.tex("icon_art_" + id)
		t.rar = String(a["rar"])
		t.position = Vector2(ART_X[k] - 140.0, 268)
		t.size = Vector2(280, 300)
		t.pivot_offset = Vector2(140, 300)
		stage.add_child(t)
		arts_n.append(t)
		add_item(t, "art%d" % k)
		var tp := Tape.new()
		tp.seed_v = 11 + k * 7
		tp.position = Vector2(ART_X[k] - 190.0, 604)
		tp.size = Vector2(380, 168)
		tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tp.rotation = -0.015 if k == 0 else 0.012
		stage.add_child(tp)
		var r := lab(("%s · %s" % ["АРТЕФАКТ", String(a["rar"])]).to_upper(), "caps", 13, RAR_COL.get(String(a["rar"]), Color.GRAY).darkened(0.35), Vector2(20, 16), 0.0, tp)
		var n := lab(String(a["name"]), "display", 26, Color(0.12, 0.1, 0.08), Vector2(20, 34), 340, tp)
		_fit_one(n, 26, 340)
		var d := lab(String(a["desc"]), "ui", 16, Color(0.22, 0.18, 0.14), Vector2(20, 72), 340, tp)
		tapes.append([n, r, d])
	# карманы куртки — слоты забега
	lab("КАРМАНЫ КУРТКИ", "caps", 13, Color(0.72, 0.66, 0.55), Vector2(84, 790))
	slot0 = items.size()
	var have: Array = G.arts()
	for i in G.slots():
		var pk := Pocket.new()
		pk.art = String(have[i]) if i < have.size() else ""
		pk.tex = G67Icons.tex("icon_art_" + pk.art) if pk.art != "" else null
		pk.position = Vector2(84 + i * (SLOT.x + 16), 808)
		pk.size = Vector2(SLOT.x, 80)
		stage.add_child(pk)
		slots_n.append(pk)
		add_item(pk, "slot%d" % i)
	var lv := Leave.new()
	lv.position = Vector2(1300, 792)
	lv.size = Vector2(240, 86)
	lv.pivot_offset = lv.size * 0.5
	stage.add_child(lv)
	leave_n = lv
	add_item(lv, "leave")
	note = lab("", "ui_b", 17, Color(0.98, 0.84, 0.5), Vector2(700, 812), 560)
	_note()
	select(0, true)

func _fit_one(l: Label, sz: int, w: float) -> void:
	var f := MGUI.font("display")
	while sz > 16 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 2
	l.add_theme_font_size_override("font_size", sz)

func _note() -> void:
	if pick != "":
		note.text = "Карманы полны. Выбери, что выложить вместо «%s»." % String(Golda67.art_info(pick)["name"])
	elif G.arts().size() >= G.slots():
		note.text = "Карманы полны: возьмёшь новое — выложишь одно из старых."
	else:
		note.text = "Свободно карманов: %d из %d." % [G.slots() - G.arts().size(), G.slots()]

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
	if key.begins_with("art"):
		var id := String(offer[int(key.substr(3))])
		if G.arts().size() < G.slots():
			_take(id, "")
		else:
			pick = id
			for t in arts_n:
				(t as Thing).picked = false
				t.queue_redraw()
			(arts_n[int(key.substr(3))] as Thing).picked = true
			arts_n[int(key.substr(3))].queue_redraw()
			_note()
			G.game.main.ui("card")
			select(slot0)
	elif key.begins_with("slot"):
		var pk: Pocket = _node(i)
		if pick != "" and pk.art != "":
			_take(pick, pk.art)
		else:
			G.game.main.ui("deny")
			pk.wobble()
	elif key == "leave":
		_leave()

func _take(id: String, replace: String) -> void:
	if not G.take_art(id, replace):
		G.game.main.ui("deny")
		return
	mode = "busy"
	var k := offer.find(id)
	if k >= 0:
		var t: Thing = arts_n[k]
		var tw := t.create_tween()
		tw.tween_property(t, "position:y", t.position.y - 30.0, 0.12)
		tw.parallel().tween_property(t, "scale", Vector2.ONE * 1.12, 0.12)
		tw.tween_property(t, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.45, true, false, true).timeout
	close()
	G.leave_storage()

func _leave() -> void:
	G.game.main.ui("back")
	close()
	G.leave_storage()

func _back() -> bool:
	if pick != "":
		pick = ""
		for t in arts_n:
			(t as Thing).picked = false
			t.queue_redraw()
		_note()
		select(0)
		return true
	_leave()
	return true

# ---------------------------------------------------------------- рисунки
## Бокс изнутри: бетон, поднятые рольворота сверху, полки с банками, лампочка на проводе и её свет на верстаке
class Garage extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.14, 0.13))
		for y in range(96, 600, 34):                       # блоки стены
			var off := 0 if (y / 34) % 2 == 0 else 60
			for x in range(-60 + off, int(size.x), 120):
				draw_rect(Rect2(Vector2(x, y), Vector2(118, 32)), Color(0.19, 0.18, 0.165))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 92)), Color(0.36, 0.38, 0.36))      # поднятые ворота
		for k in 8:
			draw_line(Vector2(0, 10 + k * 11), Vector2(size.x, 10 + k * 11), Color(0.24, 0.26, 0.25), 3.0)
		draw_rect(Rect2(Vector2(0, 88), Vector2(size.x, 8)), Color(0.08, 0.08, 0.08))
		# полки с банками справа
		for row in 2:
			var y := 230.0 + row * 120.0
			draw_rect(Rect2(Vector2(1290, y), Vector2(250, 8)), Color(0.32, 0.24, 0.15))
			for k in 5:
				var c: Color = [Color(0.5, 0.36, 0.2), Color(0.32, 0.42, 0.5), Color(0.6, 0.55, 0.3), Color(0.4, 0.3, 0.28), Color(0.45, 0.5, 0.4)][(k + row) % 5]
				draw_rect(Rect2(Vector2(1300 + k * 48, y - 40 - (k % 2) * 10), Vector2(34, 40 + (k % 2) * 10)), c)
		# провод и лампочка, свет на верстак
		draw_line(Vector2(740, 96), Vector2(740, 168), Color(0.05, 0.05, 0.05), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(700, 178), Vector2(780, 178), Vector2(1260, 600), Vector2(220, 600)]), Color(1.0, 0.85, 0.55, 0.07))
		draw_circle(Vector2(740, 182), 16, Color(1.0, 0.9, 0.6))
		draw_circle(Vector2(740, 182), 34, Color(1.0, 0.85, 0.5, 0.12))
		# верстак
		draw_rect(Rect2(Vector2(160, 560), Vector2(1180, 30)), Color(0.42, 0.29, 0.16))
		draw_rect(Rect2(Vector2(160, 588), Vector2(1180, 10)), Color(0.24, 0.16, 0.08))
		for x in [190.0, 1290.0]:
			draw_rect(Rect2(Vector2(x, 598), Vector2(24, 170)), Color(0.3, 0.2, 0.1))
		# пол
		draw_rect(Rect2(Vector2(0, 770), Vector2(size.x, size.y - 770)), Color(0.2, 0.19, 0.18))
		draw_line(Vector2(0, 770), Vector2(size.x, 770), Color(0.1, 0.1, 0.1), 3.0)
		# масляное пятно и покрышка
		draw_set_transform(Vector2(1120, 840), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 70, Color(0.08, 0.08, 0.09, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Артефакт на верстаке: на сложенной тряпке, в свете лампы
class Thing extends Control:
	var tex: Texture2D
	var rar := ""
	var selected := false
	var picked := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.06 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func _draw() -> void:
		var rc: Color = G67StorageUI.RAR_COL.get(rar, Color.GRAY)
		# тряпка
		draw_colored_polygon(PackedVector2Array([Vector2(20, size.y - 18), Vector2(size.x - 14, size.y - 26), Vector2(size.x - 4, size.y - 2), Vector2(8, size.y + 4)]), Color(0.46, 0.2, 0.16) if rar != "редкий" else Color(0.22, 0.24, 0.4))
		draw_set_transform(Vector2(size.x * 0.5, size.y - 10), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, size.x * 0.42, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if selected:
			draw_circle(Vector2(size.x * 0.5, size.y * 0.48), size.x * 0.46, Color(rc, 0.12))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(25, 18), Vector2(size.x - 50, size.x - 50)), false)
		if picked:
			draw_rect(Rect2(Vector2(6, 4), size - Vector2(12, 0)), Color(0.98, 0.8, 0.4), false, 3.0)
		elif selected:
			draw_rect(Rect2(Vector2(6, 4), size - Vector2(12, 0)), Color(0.98, 0.8, 0.4, 0.75), false, 2.0)

## Бумажка на малярном скотче
class Tape extends Control:
	var seed_v := 1
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, seed_v, 1.6), Color(0.93, 0.9, 0.82))
		for x in [size.x * 0.2, size.x * 0.8]:
			draw_rect(Rect2(Vector2(x - 34, -10), Vector2(68, 22)), Color(0.86, 0.8, 0.6, 0.85))

## Карман куртки: занятый — значок артефакта на ткани, пустой — пунктир и стёжка
class Pocket extends Control:
	var art := ""
	var tex: Texture2D
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		queue_redraw()
	func wobble() -> void:
		var tw := create_tween()
		tw.tween_property(self, "position:x", position.x + 5.0, 0.04)
		tw.tween_property(self, "position:x", position.x - 4.0, 0.05)
		tw.tween_property(self, "position:x", position.x, 0.04)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.2, 0.22, 0.26))
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 16)), Color(0.15, 0.16, 0.2))
		for x in range(6, int(size.x) - 4, 9):
			draw_line(Vector2(x, 20), Vector2(x + 4, 20), Color(0.5, 0.52, 0.56, 0.6), 1.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(14, 18), Vector2(size.x - 28, size.y - 22)), false)
		else:
			draw_rect(r.grow(-10), Color(0.5, 0.52, 0.56, 0.35), false, 1.0)
		if selected:
			draw_rect(r.grow(2), Color(0.98, 0.8, 0.4), false, 2.5)

## Картонка у ворот: «ОСТАВИТЬ И УЙТИ»
class Leave extends Control:
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		create_tween().tween_property(self, "rotation", -0.04 if v else 0.0, 0.1)
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.45))
		draw_colored_polygon(G67Diorama.paper_poly(r, 5, 2.4), Color(0.62, 0.48, 0.3))
		var f := MGUI.font("display")
		draw_string(f, Vector2(18, 38), "ОСТАВИТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.16, 0.1, 0.05))
		draw_string(f, Vector2(18, 70), "И УЙТИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.16, 0.1, 0.05))
		if selected:
			draw_rect(r.grow(3), Color(0.98, 0.8, 0.4), false, 2.5)
