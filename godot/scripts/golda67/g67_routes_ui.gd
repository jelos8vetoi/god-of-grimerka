class_name G67RoutesUI
extends G67Diorama
## Карта маршрутов — лист в клетку, приколотый к стене: сверху от руки — четыре района турнира по порядку (ДВОР →
## ПОДЗЕМКА → ЛЕНТА → БОТОФЕРМА; пройденный обведён, открытый — с флажком, закрытые — бледные с «?»), ниже — план
## ДВОРА: зоны стоят там же, где во дворе (G67Yard.ZONES), этапы забега пронумерованы (шаблон G67Data.DISTRICTS.routes на следующий забег),
## следующая встреча КРОТА — красная кнопка. Выбирается район или зона; справа — страничка блокнота с описанием.

const PLAN := Rect2(118, 352, 940, 470)       # план двора на листе
const WORLD := Rect2(-48, -54, 94, 91)        # двор в метрах (x, z)
const CITY_Y := 230.0

var marks: Array = []          # {kind: "district"/"zone", id, pos}
var route: Array = []          # шаблон маршрута следующего забега (номер забега % 3) или идущего на паузе
var note: Control
var n_head: Label
var n_name: Label
var n_state: Label
var n_text: Label

static func open(g67: Golda67) -> G67RoutesUI:
	var u := G67RoutesUI.new()
	u._open_base(g67, "routes")
	u._build()
	return u

static func plan_pos(c: Vector3) -> Vector2:
	return PLAN.position + Vector2((c.x - WORLD.position.x) / WORLD.size.x * PLAN.size.x, (c.z - WORLD.position.y) / WORLD.size.y * PLAN.size.y)

func _build() -> void:
	route = route_now()
	var sheet := Sheet.new()
	sheet.ui = self
	sheet.size = STAGE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sheet)
	lab("ПОДЪЕЗД · ХОЛЛ · КАРТА НА СТЕНЕ", "caps", 13, Color(0.7, 0.68, 0.6), Vector2(70, 30))
	lab("КАРТА МАРШРУТОВ", "display", 46, Color(0.92, 0.9, 0.82), Vector2(66, 46))
	var fl: Dictionary = G.meta().get("flags", {})
	var prev_ok := true
	for i in G67Data.DISTRICT_LIST.size():
		var d: Dictionary = G67Data.DISTRICT_LIST[i]
		var beaten := bool(fl.get(String(d["flag"]), false))
		var m := Mark.new()
		m.kind = "district"
		m.id = String(d["id"])
		m.label = String(d["name"])
		m.state = "beaten" if beaten else ("open" if prev_ok else "lock")
		m.info = d
		m.idx = i
		m.position = Vector2(170 + i * 250, CITY_Y) - Vector2(70, 50)
		m.size = Vector2(140, 100)
		m.pivot_offset = m.size * 0.5
		stage.add_child(m)
		marks.append(m)
		add_item(m, m.id)
		prev_ok = beaten
	for zid in G67Yard.ZONES:
		var z: Dictionary = G67Yard.ZONES[zid]
		var m2 := Mark.new()
		m2.kind = "zone"
		m2.id = String(zid)
		m2.label = String(z["name"])
		m2.info = z
		m2.route = route
		m2.position = plan_pos(z["c"]) - Vector2(60, 34)
		m2.size = Vector2(120, 68)
		m2.pivot_offset = m2.size * 0.5
		m2.state = "open"
		stage.add_child(m2)
		marks.append(m2)
		add_item(m2, m2.id)
	_build_note()
	select(0, true)

func _build_note() -> void:
	note = Notebook.new()
	note.position = Vector2(1150, 150)
	note.size = Vector2(400, 680)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(note)
	var x := 1186.0
	n_head = lab("", "caps", 14, Color(0.45, 0.12, 0.1), Vector2(x, 196))
	n_name = lab("", "display", 34, Color(0.12, 0.12, 0.2), Vector2(x, 218))
	n_state = lab("", "caps", 15, Color(0.12, 0.1, 0.08), Vector2(x, 290))
	n_text = lab("", "ui", 17, Color(0.18, 0.18, 0.26), Vector2(x, 332), 336)

## Что происходит в зоне: этапы забега ДВОРА, где она стоит, и встреча КРОТА
func zone_lines(zid: String) -> Array:
	var out: Array = []
	for i in route.size():
		for o in route[i]:
			if String(o["place"]) == zid:
				out.append("%d · %s" % [i + 1, String(G67Data.ROOM_NAMES[String(o["type"])])])
	return out

## Какой шаблон маршрута сейчас: у забега на паузе — его, иначе — шаблон следующего забега
func route_now() -> Array:
	var tpl := int(G.meta().get("runs", 0)) % 3
	if G.paused_run():
		tpl = int(((G.data["run"] as Dictionary).get("run", {}) as Dictionary).get("tpl", 0))
	return G67Data.route_of(G67Data.DISTRICTS["dvor"], tpl)

func krot_zone() -> String:
	var k := G.krot_next()
	return String(k.get("where", "")) if not k.is_empty() else ""

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(marks[prev] as Mark).set_selected(false)
	var m: Mark = marks[i]
	m.set_selected(true)
	if m.kind == "district":
		n_head.text = "РАЙОН № %d" % (m.idx + 1)
		n_name.text = m.label
		match m.state:
			"beaten":
				n_state.text = "ПРОЙДЕН"
				n_text.text = "Босс района — %s — побеждён.\nВ район можно вернуться: выход — дверь подъезда." % String(m.info["boss"])
			"open":
				n_state.text = "ОТКРЫТ"
				n_text.text = "Босс района — %s.\nВыход — дверь подъезда, семь этапов, в конце — босс." % String(m.info["boss"]) if m.id == "dvor" else ("Босс района — %s.\nДорога через арку открыта. Продолжение турнира — в следующей главе." % String(m.info["boss"]))
			_:
				n_state.text = "ЗАКРЫТ"
				n_text.text = "Босс района — ???\nОткроется после победы над боссом прошлого района."
	else:
		n_head.text = "ДВОР · ЗОНА"
		n_name.text = m.label.substr(0, 1).to_upper() + m.label.substr(1)
		var ls := zone_lines(m.id)
		n_state.text = ("ЭТАПЫ ЗАБЕГА: " + ", ".join(ls.map(func(s): return String(s).get_slice(" ", 0)))) if not ls.is_empty() else "ВНЕ МАРШРУТА"
		var txt := "\n".join(ls.map(func(s): return "Этап " + String(s)))
		if m.id == "podezd":
			txt = "Отсюда начинается забег — первый бой у самого подъезда.\nСюда же можно вернуться посреди забега.\n\n" + txt
		if krot_zone() == m.id:
			txt += "\n\nКРОТ: следующая встреча — здесь."
		n_text.text = txt
	# название — в одну строку: длинное («Парковка у ларька») мельче
	var f := MGUI.font("display")
	var sz := 34
	while sz > 20 and f.get_string_size(n_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > 336.0:
		sz -= 1
	n_name.add_theme_font_size_override("font_size", sz)
	note.queue_redraw()

func _activate(i: int) -> void:
	if i >= 0:
		(marks[i] as Mark).pulse()
		G.game.main.ui("card")

# ---------------------------------------------------------------- рисунки
## Лист в клетку на стене: районы от руки, план двора (дома, проезды, позиции), КРОТ
class Sheet extends Control:
	var ui
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.26, 0.25))
		var p := Rect2(Vector2(70, 118), Vector2(1040, 742))
		draw_colored_polygon(G67Diorama.paper_poly(Rect2(p.position + Vector2(8, 10), p.size), 3, 2.0), Color(0, 0, 0, 0.4))
		draw_colored_polygon(G67Diorama.paper_poly(p, 3, 2.0), Color(0.93, 0.92, 0.86))
		for x in range(int(p.position.x) + 10, int(p.end.x), 22):
			draw_line(Vector2(x, p.position.y + 4), Vector2(x, p.end.y - 4), Color(0.5, 0.6, 0.75, 0.22), 1.0)
		for y in range(int(p.position.y) + 10, int(p.end.y), 22):
			draw_line(Vector2(p.position.x + 4, y), Vector2(p.end.x - 4, y), Color(0.5, 0.6, 0.75, 0.22), 1.0)
		for c in [p.position + Vector2(14, 14), Vector2(p.end.x - 14, p.position.y + 14)]:   # кнопки
			draw_circle(c, 7, Color(0.62, 0.14, 0.1))
		var pen := Color(0.16, 0.18, 0.36)
		var f := MGUI.font("caps")
		draw_string(f, Vector2(100, 160), "ТУРНИР 67 · РАЙОНЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, pen)
		# дорога между районами
		for i in 3:
			draw_dashed_line(Vector2(170 + i * 250 + 76, G67RoutesUI.CITY_Y), Vector2(170 + (i + 1) * 250 - 76, G67RoutesUI.CITY_Y), pen, 2.0, 8.0)
			var tip := Vector2(170 + (i + 1) * 250 - 76, G67RoutesUI.CITY_Y)
			draw_line(tip, tip + Vector2(-10, -6), pen, 2.0)
			draw_line(tip, tip + Vector2(-10, 6), pen, 2.0)
		draw_line(Vector2(100, 310), Vector2(1080, 310), Color(pen, 0.4), 1.5)
		draw_string(f, Vector2(100, 338), "ДВОР · ПЛАН", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, pen)
		# план двора: дома по периметру штриховкой, проезды
		var pl := G67RoutesUI.PLAN
		draw_rect(pl, Color(pen, 0.5), false, 1.5)
		for side in [Rect2(pl.position, Vector2(pl.size.x, 22)), Rect2(Vector2(pl.position.x, pl.end.y - 22), Vector2(pl.size.x, 22)),
				Rect2(pl.position, Vector2(26, pl.size.y)), Rect2(Vector2(pl.end.x - 26, pl.position.y), Vector2(26, pl.size.y))]:
			var s: Rect2 = side
			for k in range(0, int(s.size.x + s.size.y), 9):
				var a := s.position + Vector2(k, 0)
				var b := a + Vector2(-s.size.y, s.size.y)
				draw_line(a.clamp(s.position, s.end), b.clamp(s.position, s.end), Color(pen, 0.25), 1.0)
		draw_string(f, Vector2(pl.get_center().x - 40, pl.end.y - 6), "ПОДЪЕЗД", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, pen)
		# маршрут забега: этапы по порядку через первую зону каждого этапа
		var route: Array = ui.route
		var pts: Array = []
		for opts in route:
			pts.append(G67RoutesUI.plan_pos(G67Yard.ZONES[String(opts[0]["place"])]["c"]))
		for i in pts.size() - 1:
			draw_dashed_line(pts[i], pts[i + 1], Color(0.7, 0.18, 0.14, 0.6), 2.5, 10.0)
		# КРОТ: красная кнопка у его следующей зоны
		var kz: String = ui.krot_zone()
		if kz != "" and G67Yard.ZONES.has(kz):
			var kp := G67RoutesUI.plan_pos(G67Yard.ZONES[kz]["c"]) + Vector2(70, -30)
			draw_circle(kp, 9, Color(0.75, 0.12, 0.1))
			draw_circle(kp - Vector2(2, 2), 3, Color(1, 0.7, 0.6))
			draw_string(f, kp + Vector2(14, 5), "КРОТ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.12, 0.1))

## Отметка на карте: район (кружок от руки) или зона двора (подпись и номера этапов)
class Mark extends Control:
	var kind := "zone"
	var id := ""
	var idx := 0
	var label := ""
	var state := "open"
	var info: Dictionary
	var route: Array = []
	var selected := false
	func set_selected(v: bool) -> void:
		selected = v
		z_index = 2 if v else 0
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.08 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func pulse() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 1.16, 0.08)
		tw.tween_property(self, "scale", Vector2.ONE * 1.08, 0.14)
	func _draw() -> void:
		var pen := Color(0.16, 0.18, 0.36)
		var red := Color(0.72, 0.16, 0.12)
		var c := size * 0.5
		var f := MGUI.font("caps")
		var fd := MGUI.font("display")
		if kind == "district":
			var lock := state == "lock"
			var col := Color(pen, 0.3) if lock else pen
			# кружок от руки: два витка с разным радиусом
			draw_arc(c, 42, 0.2, TAU + 0.5, 28, col, 2.5)
			draw_arc(c, 45, 0.9, TAU + 0.2, 28, Color(col, col.a * 0.6), 1.5)
			var tw := fd.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(fd, Vector2(c.x - tw * 0.5, c.y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
			if state == "beaten":
				draw_arc(c, 52, 0, TAU, 32, red, 3.0)
				draw_line(c + Vector2(30, -40), c + Vector2(52, -60), red, 3.0)
			elif state == "open":
				draw_line(c + Vector2(30, -36), c + Vector2(30, -66), red, 2.5)          # флажок
				draw_colored_polygon(PackedVector2Array([c + Vector2(30, -66), c + Vector2(54, -59), c + Vector2(30, -52)]), red)
			else:
				draw_string(fd, c + Vector2(-8, -24), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(pen, 0.35))
		else:
			draw_circle(c, 7, Color(0.72, 0.16, 0.12))
			var nums: Array = []
			for i in route.size():
				for o in route[i]:
					if String(o["place"]) == id:
						nums.append(str(i + 1))
			var tw2 := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f, Vector2(c.x - tw2 * 0.5, c.y + 26), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, pen)
			for k in nums.size():
				var nc := c + Vector2(-10 * (nums.size() - 1) + k * 20, -18)
				draw_arc(nc, 9, 0, TAU, 16, red, 2.0)
				draw_string(MGUI.font("mono"), nc + Vector2(-4, 5), String(nums[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, red)
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.98, 0.62, 0.2, 0.9), false, 2.5)

## Страничка блокнота на пружине
class Notebook extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.45))
		draw_rect(r, Color(0.95, 0.94, 0.88))
		for y in range(70, int(size.y) - 10, 30):
			draw_line(Vector2(16, y), Vector2(size.x - 16, y), Color(0.5, 0.6, 0.78, 0.35), 1.0)
		draw_line(Vector2(26, 0), Vector2(26, size.y), Color(0.85, 0.35, 0.35, 0.5), 1.5)
		for k in 12:
			draw_arc(Vector2(16 + k * 32, 6), 8, PI, TAU, 10, Color(0.55, 0.55, 0.58), 3.0)
