class_name G67MailUI
extends G67Diorama
## Почтовые ящики подъезда: жестяной блок ящиков на зелёной стене. Письма — G67Data.MAIL (текст и условие как в игре,
## вид письма и номер квартиры — третье и четвёртое поля): с письмом — из щели торчит конверт и на табличке метка;
## прочитано — закрыт, галочка; ещё не пришло — навесной замок и причина. Остальные ящики — соседские, без писем.
## Enter — открыть ящик: дверца, конверт, клапан, лист выезжает, текст. Esc — назад к тому же ящику.
## Прочитанное — meta.mail_read (номера писем).

const COLS := 5
const ROWS := 3
const NUMS := [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43]
const BOX0 := Vector2(120, 210)
const BOX := Vector2(176, 168)
const GAP := Vector2(12, 14)

var boxes: Array = []          # все ящики (в т.ч. соседские)
var letter_box: Array = []     # ящики с письмами по порядку G67Data.MAIL
var info: Control
var i_no: Label
var i_state: Label
var i_text: Label
var i_why: Label
var i_btn: Button
var view: Control

static func open(g67: Golda67) -> G67MailUI:
	var u := G67MailUI.new()
	u._open_base(g67, "mail")
	u._build()
	return u

func _build() -> void:
	var wall := Wall.new()
	wall.size = STAGE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(wall)
	lab("ПОДЪЕЗД · У ВХОДА", "caps", 13, Color(0.82, 0.86, 0.78), Vector2(70, 28))
	lab("ПОЧТОВЫЕ ЯЩИКИ", "display", 48, Color(0.92, 0.9, 0.82), Vector2(66, 46))
	var fl: Dictionary = G.meta().get("flags", {})
	var read: Array = G.meta().get("mail_read", [])
	var by_num := {}
	for i in G67Data.MAIL.size():
		by_num[int(G67Data.MAIL[i][3])] = i
	for k in NUMS.size():
		var b := Box.new()
		b.num = NUMS[k]
		b.paint = [Color(0.3, 0.42, 0.36), Color(0.28, 0.36, 0.48), Color(0.42, 0.34, 0.26), Color(0.36, 0.38, 0.36)][(k * 7) % 4]
		b.position = BOX0 + Vector2((k % COLS) * (BOX.x + GAP.x), (k / COLS) * (BOX.y + GAP.y))
		b.size = BOX
		b.pivot_offset = BOX * 0.5
		b.seed_v = NUMS[k]
		if by_num.has(NUMS[k]):
			var mi: int = by_num[NUMS[k]]
			var m: Array = G67Data.MAIL[mi]
			var flag := String(m[1])
			b.mail = mi
			b.state = "lock" if flag != "" and not bool(fl.get(flag, false)) else ("read" if read.has(mi) else "new")
			b.why = "Пока пусто. Придёт " + String(G67Data.FLAG_WHY.get(flag, "позже")) + "." if b.state == "lock" else ""
		stage.add_child(b)
		boxes.append(b)
		if b.mail >= 0:
			letter_box.append(b)
	letter_box.sort_custom(func(a, c): return a.mail < c.mail)
	for b in letter_box:
		add_item(b, b.mail)
	_build_info()
	select(0, true)

func _build_info() -> void:
	info = Plate.new()
	info.position = Vector2(1120, 210)
	info.size = Vector2(430, 540)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(info)
	var x := 1150.0
	i_no = lab("", "display", 40, Color(0.92, 0.9, 0.82), Vector2(x, 236))
	i_state = lab("", "caps", 15, Color(0.95, 0.75, 0.4), Vector2(x, 296))
	i_text = lab("", "ui", 17, Color(0.82, 0.82, 0.76), Vector2(x, 340), 370)
	i_why = lab("", "ui_b", 16, Color(0.95, 0.5, 0.4), Vector2(x, 560), 370)
	i_btn = Button.new()
	i_btn.position = Vector2(x, 660)
	i_btn.size = Vector2(370, 58)
	i_btn.focus_mode = Control.FOCUS_NONE
	i_btn.add_theme_font_override("font", MGUI.font("caps"))
	i_btn.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.16, 0.14) if st != "hover" else Color(0.2, 0.26, 0.22)
		if st == "disabled":
			sb.bg_color = Color(0.1, 0.1, 0.1, 0.4)
		sb.border_color = Color(0.85, 0.82, 0.7) if st != "disabled" else Color(0.3, 0.3, 0.3)
		sb.set_border_width_all(2)
		i_btn.add_theme_stylebox_override(st, sb)
	i_btn.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82))
	i_btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.42))
	i_btn.pressed.connect(func():
		if mode == "list":
			_activate(sel))
	stage.add_child(i_btn)

func _kind_name(m: Array) -> String:
	return String({"flyer": "Листовка", "ad": "Реклама", "news": "Газетная вырезка"}.get(String(m[2]), "Письмо"))

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(items[prev]["node"] as Box).lift(false)
	var b: Box = items[i]["node"]
	b.lift(true)
	var m: Array = G67Data.MAIL[b.mail]
	i_no.text = "КВ. %d" % b.num
	i_why.text = ""
	match b.state:
		"new":
			i_state.text = "В ЯЩИКЕ ЧТО-ТО ЕСТЬ"
			i_text.text = "%s — торчит из щели, ещё не прочитано." % _kind_name(m)
			i_btn.text = "ОТКРЫТЬ ЯЩИК"
			i_btn.disabled = false
		"read":
			i_state.text = "ПРОЧИТАНО"
			i_text.text = "%s. Можно перечитать." % _kind_name(m)
			i_btn.text = "ОТКРЫТЬ ЯЩИК"
			i_btn.disabled = false
		_:
			i_state.text = "ЗАПЕРТО"
			i_text.text = "Ящик на замке, внутри пусто."
			i_why.text = b.why
			i_btn.text = "ЗАПЕРТО"
			i_btn.disabled = true

func _activate(i: int) -> void:
	if i < 0:
		return
	var b: Box = items[i]["node"]
	if b.state == "lock":
		G.game.main.ui("deny")
		b.shake()
		i_why.modulate = Color(1.6, 1.3, 1.3)
		i_why.create_tween().tween_property(i_why, "modulate", Color.WHITE, 0.4)
		return
	mode = "busy"
	G.game.main.ui("value", 0.8)               # щелчок замка
	var tw := b.create_tween()
	tw.tween_method(func(v: float):
		b.door = v
		b.queue_redraw(), 0.0, 1.0, 0.22)
	await tw.finished
	_open_letter(b)

## Письмо: конверт крупно → клапан открывается → лист выезжает → текст
func _open_letter(b: Box) -> void:
	mode = "read"
	G.game.main.ui("card")
	var m: Array = G67Data.MAIL[b.mail]
	view = Control.new()
	view.z_index = 20
	view.size = STAGE
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(view)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = STAGE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(dim)
	var lt := Letter.new()
	lt.text = String(m[0])
	lt.look = String(m[2])
	lt.num = b.num
	lt.size = Vector2(760, 860)
	lt.position = Vector2(420, 20)
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(lt)
	lt.play()
	var read: Array = G.meta().get("mail_read", [])
	if not read.has(b.mail):
		read.append(b.mail)
		G.meta()["mail_read"] = read
		G.save()
	b.state = "read"
	b.queue_redraw()
	G.events.append(["mail_read", b.mail])

func _back() -> bool:
	if mode == "read":
		view.queue_free()
		view = null
		mode = "list"
		G.game.main.ui("back")
		var b: Box = items[sel]["node"]
		var tw := b.create_tween()
		tw.tween_method(func(v: float):
			b.door = v
			b.queue_redraw(), 1.0, 0.0, 0.18)
		var keep := sel
		sel = -1
		select(keep, true)
		return true
	return false

# ---------------------------------------------------------------- рисунки
class Wall extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.6, 0.56))
		draw_rect(Rect2(Vector2(0, 470), Vector2(size.x, size.y - 470)), Color(0.19, 0.31, 0.25))
		draw_line(Vector2(0, 470), Vector2(size.x, 470), Color(0.11, 0.19, 0.15), 3.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for k in 30:
			draw_circle(Vector2(rng.randf_range(0, size.x), rng.randf_range(0, 460)), rng.randf_range(4, 16), Color(0.5, 0.5, 0.46, 0.16))
		# корпус блока ящиков
		var blk := Rect2(Vector2(100, 190), Vector2(5 * 188 + 8, 3 * 182 + 8))
		draw_rect(Rect2(blk.position + Vector2(8, 10), blk.size), Color(0, 0, 0, 0.45))
		draw_rect(blk, Color(0.22, 0.24, 0.23))
		draw_rect(blk, Color(0.12, 0.13, 0.12), false, 3.0)

## Ящик: жесть с потёртой краской, табличка с номером, щель, скважина; состояние — конверт, галочка или замок
class Box extends Control:
	var num := 0
	var paint := Color(0.3, 0.4, 0.35)
	var mail := -1
	var state := ""
	var why := ""
	var seed_v := 1
	var sel := false
	var door := 0.0
	func lift(v: bool) -> void:
		sel = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.05 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func shake() -> void:
		var x0 := position.x
		var tw := create_tween()
		for k in 4:
			tw.tween_property(self, "position:x", x0 + (4.0 if k % 2 == 0 else -4.0), 0.035)
		tw.tween_property(self, "position:x", x0, 0.035)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var dim := 1.0 if mail >= 0 else 0.72
		# внутренность (видна, когда дверца открыта)
		draw_rect(r, Color(0.06, 0.06, 0.06))
		var dw := size.x * (1.0 - 0.82 * door)
		var dr := Rect2(Vector2.ZERO, Vector2(dw, size.y))
		draw_rect(dr, Color(paint.r * dim, paint.g * dim, paint.b * dim))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		for k in 7:                                       # сколы краски до металла
			var p := Vector2(rng.randf_range(4, dw - 14), rng.randf_range(4, size.y - 10))
			draw_rect(Rect2(p, Vector2(rng.randf_range(4, 14), rng.randf_range(2, 6))), Color(0.5, 0.48, 0.44, 0.5))
		draw_rect(Rect2(Vector2(0, size.y - 8), Vector2(dw, 8)), Color(0.42, 0.25, 0.12, 0.45))      # ржавчина по низу
		draw_rect(dr, Color(0.1, 0.1, 0.1), false, 2.0)
		if door > 0.5:
			return
		# щель для писем и вентиляционные прорези
		draw_rect(Rect2(Vector2(size.x * 0.18, 26), Vector2(size.x * 0.64, 8)), Color(0.03, 0.03, 0.03))
		for k in 3:
			draw_rect(Rect2(Vector2(size.x * (0.22 + k * 0.2), size.y * 0.55), Vector2(size.x * 0.12, 4)), Color(0.05, 0.05, 0.05, 0.8))
		# табличка с номером
		var pr := Rect2(Vector2(size.x * 0.28, size.y * 0.32), Vector2(size.x * 0.44, 26))
		draw_rect(pr, Color(0.86, 0.84, 0.76) * Color(dim, dim, dim, 1.0))
		draw_rect(pr, Color(0.2, 0.2, 0.2), false, 1.0)
		var fm := MGUI.font("mono")
		draw_string(fm, pr.position + Vector2(8, 19), "КВ. %d" % num, HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 10, 15, Color(0.1, 0.09, 0.08))
		# скважина
		var kc := Vector2(size.x - 24, size.y * 0.72)
		draw_circle(kc, 6, Color(0.6, 0.58, 0.5))
		draw_circle(kc, 2.5, Color(0.05, 0.05, 0.05))
		match state:
			"new":
				# конверт торчит из щели, метка на табличке
				draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.24, 30), Vector2(size.x * 0.7, 26), Vector2(size.x * 0.71, 2), Vector2(size.x * 0.25, 6)]), Color(0.88, 0.84, 0.72))
				draw_line(Vector2(size.x * 0.25, 6), Vector2(size.x * 0.48, 18), Color(0.6, 0.55, 0.45), 1.0)
				draw_line(Vector2(size.x * 0.71, 2), Vector2(size.x * 0.48, 18), Color(0.6, 0.55, 0.45), 1.0)
				draw_circle(pr.position + Vector2(pr.size.x + 10, 13), 5.0, Color(0.85, 0.2, 0.15))
			"read":
				draw_line(pr.position + Vector2(pr.size.x + 4, 14), pr.position + Vector2(pr.size.x + 10, 20), Color(0.5, 0.85, 0.5), 2.5)
				draw_line(pr.position + Vector2(pr.size.x + 10, 20), pr.position + Vector2(pr.size.x + 20, 6), Color(0.5, 0.85, 0.5), 2.5)
			"lock":
				G67Diorama.draw_padlock(self, Vector2(size.x * 0.5, size.y * 0.78), 1.15)
		if sel:
			draw_rect(r.grow(3), Color(0.95, 0.8, 0.45), false, 2.5)

## Табличка справа: железная, как сам блок
class Plate extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.45))
		draw_rect(r, Color(0.16, 0.18, 0.17))
		draw_rect(r, Color(0.32, 0.34, 0.32), false, 2.0)
		for p in [Vector2(10, 10), Vector2(size.x - 10, 10), Vector2(10, size.y - 10), Vector2(size.x - 10, size.y - 10)]:
			draw_circle(p, 3.5, Color(0.42, 0.42, 0.4))

## Письмо: конверт, клапан, лист с текстом. Вид листа — по виду письма: листовка, реклама с подписью, газетная вырезка
class Letter extends Control:
	var text := ""
	var look := "flyer"
	var num := 0
	var ph := 0.0                 # 0..1 конверт, 1..2 клапан, 2..3 лист выезжает
	func play() -> void:
		var tw := create_tween()
		tw.tween_property(self, "ph", 3.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(queue_redraw)
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var k := clampf(ph, 0.0, 1.0)
		var flap := clampf(ph - 1.0, 0.0, 1.0)
		var out := clampf(ph - 2.0, 0.0, 1.0)
		var ew := 600.0
		var eh := 300.0
		var ec := Vector2(size.x * 0.5, size.y - eh * 0.5 - 10)
		var er := Rect2(ec - Vector2(ew, eh) * 0.5 * (0.7 + 0.3 * k), Vector2(ew, eh) * (0.7 + 0.3 * k))
		var a := k
		# лист за конвертом: выезжает вверх
		var sh := 540.0
		var sr := Rect2(Vector2(er.position.x + 30, er.position.y + 20 - 440.0 * out), Vector2(er.size.x - 60, sh))
		var fy := lerpf(er.position.y + 150, er.position.y - 110, flap)
		var flap_poly := PackedVector2Array([er.position, Vector2(er.end.x, er.position.y), Vector2(er.get_center().x, fy)])
		if flap >= 0.5:
			draw_colored_polygon(flap_poly, Color(0.74, 0.69, 0.56, a))      # открытый клапан — за листом
		if out > 0.0:
			_sheet(sr, out)
		# конверт
		draw_rect(Rect2(er.position + Vector2(6, 8), er.size), Color(0, 0, 0, 0.4 * a))
		draw_rect(er, Color(0.86, 0.81, 0.68, a))
		draw_line(er.position, er.get_center() + Vector2(0, 30), Color(0.7, 0.64, 0.52, a), 1.5)
		draw_line(Vector2(er.end.x, er.position.y), er.get_center() + Vector2(0, 30), Color(0.7, 0.64, 0.52, a), 1.5)
		# адрес и почтовый штемпель
		var fm := MGUI.font("mono")
		draw_string(fm, er.position + Vector2(30, er.size.y - 70), "ПОДЪЕЗД · КВ. %d" % num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.2, 0.18, 0.4, a))
		draw_line(er.position + Vector2(30, er.size.y - 60), er.position + Vector2(300, er.size.y - 60), Color(0.3, 0.28, 0.24, 0.5 * a), 1.0)
		var pc := er.position + Vector2(er.size.x - 90, 70)
		draw_arc(pc, 38, 0, TAU, 28, Color(0.25, 0.25, 0.45, 0.55 * a), 2.0)
		draw_string(fm, pc - Vector2(16, -6), "67", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.25, 0.25, 0.45, 0.6 * a))
		# клапан закрыт — поверх конверта
		if flap < 0.5:
			draw_colored_polygon(flap_poly, Color(0.8, 0.75, 0.62, a))
	func _sheet(r: Rect2, a: float) -> void:
		var paper := Color(0.95, 0.94, 0.9) if look != "news" else Color(0.86, 0.84, 0.76)
		draw_colored_polygon(G67Diorama.paper_poly(r, num, 1.2), Color(paper, a))
		var ink := Color(0.1, 0.09, 0.08, a)
		var fd := MGUI.font("display")
		var fu := MGUI.font("ui")
		var fc := MGUI.font("caps")
		var x := r.position.x + 34
		var w := r.size.x - 68
		var head := text.get_slice(":", 0)
		var body := text.substr(text.find(":") + 1).strip_edges()
		var sign := ""
		if body.contains("Подпись — "):
			sign = body.substr(body.find("Подпись — ") + 10).trim_suffix(".")
			body = body.substr(0, body.find("Подпись — ")).strip_edges()
		match look:
			"news":
				draw_string(fd, Vector2(x, r.position.y + 54), head, HORIZONTAL_ALIGNMENT_LEFT, w, 30, ink)
				draw_line(Vector2(x, r.position.y + 68), Vector2(x + w, r.position.y + 68), ink, 2.0)
				draw_line(Vector2(x, r.position.y + 74), Vector2(x + w, r.position.y + 74), ink, 1.0)
				draw_multiline_string(fu, Vector2(x, r.position.y + 118), body, HORIZONTAL_ALIGNMENT_LEFT, w, 21, -1, ink)
				for k in 8:                                 # колонки газетного набора ниже — серые строки без текста
					draw_line(Vector2(x, r.position.y + 330 + k * 22), Vector2(x + w * (0.55 if k % 3 == 2 else 1.0), r.position.y + 330 + k * 22), Color(0, 0, 0, 0.1 * a), 7.0)
			"ad":
				draw_rect(Rect2(Vector2(x, r.position.y + 30), Vector2(w, 40)), Color(0.12, 0.1, 0.09, a))
				draw_string(fc, Vector2(x + 14, r.position.y + 58), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.78, 0.4, a))
				draw_multiline_string(fd, Vector2(x, r.position.y + 130), body, HORIZONTAL_ALIGNMENT_LEFT, w, 30, -1, ink)
				if sign != "":
					draw_set_transform(Vector2(x + w - 230, r.position.y + 290), -0.06, Vector2.ONE)
					draw_string(fd, Vector2.ZERO, sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.2, 0.2, 0.5, a))
					draw_line(Vector2(-10, 10), Vector2(230, 6), Color(0.2, 0.2, 0.5, 0.6 * a), 1.5)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_string(fc, Vector2(x, r.position.y + 50), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.14, 0.1, a))
				draw_string(fd, Vector2(r.end.x - 230, r.position.y + 400), "67", HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(0.85, 0.6, 0.2, 0.3 * a))
				draw_multiline_string(fd, Vector2(x, r.position.y + 130), body, HORIZONTAL_ALIGNMENT_LEFT, w, 36, -1, ink)
