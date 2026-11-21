class_name G67BoardUI
extends G67Diorama
## Доска объявлений подъезда: пробковая доска в деревянной раме на крашеной стене, листки жильцов приколоты
## кнопками и скотчем. Листки — G67Data.BOARD (текст и условие появления как в игре; вид листка — третье поле):
## афиша, машинописный лист, объявление с печатью. Ещё не появившееся — заклеенный лист «ПОКА НЕ ДОСТУПНО» с
## причиной. Справа — тот же листок крупно. Enter — снять листок и прочитать вблизи, Esc — повесить обратно.
## Прочитанное — meta.board_read (номера листков); до прочтения на листке наклейка «НОВОЕ».

## место листка на доске: [x, y, w, h, наклон]
const PLACES := [[130, 196, 330, 404, -0.035], [500, 214, 300, 250, 0.03], [520, 512, 330, 268, -0.02]]

var notes: Array = []
var big: Note
var reader: Control

static func open(g67: Golda67) -> G67BoardUI:
	var u := G67BoardUI.new()
	u._open_base(g67, "board")
	u._build()
	return u

func _build() -> void:
	var wall := Wall.new()
	wall.size = STAGE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(wall)
	lab("ПОДЪЕЗД · ПЕРВЫЙ ЭТАЖ · У ЛЕСТНИЦЫ", "caps", 13, Color(0.3, 0.3, 0.28), Vector2(660, 34))
	var fl: Dictionary = G.meta().get("flags", {})
	var read: Array = G.meta().get("board_read", [])
	for i in G67Data.BOARD.size():
		var b: Array = G67Data.BOARD[i]
		var p: Array = PLACES[i % PLACES.size()]
		var flag := String(b[1])
		var n := Note.new()
		n.text = String(b[0])
		n.look = String(b[2]) if b.size() > 2 else "tariff"
		n.locked = flag != "" and not bool(fl.get(flag, false))
		n.why = "Появится " + String(G67Data.FLAG_WHY.get(flag, "позже")) + "." if n.locked else ""
		n.fresh = not n.locked and not read.has(i)
		n.seed_v = 31 + i * 7
		n.position = Vector2(p[0], p[1])
		n.size = Vector2(p[2], p[3])
		n.rot = float(p[4])
		n.rotation = n.rot
		n.pivot_offset = n.size * 0.5
		stage.add_child(n)
		notes.append(n)
		add_item(n, i)
		# появление: листки по очереди «прикалываются»
		n.modulate.a = 0.0
		n.scale = Vector2.ONE * 1.06
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "modulate:a", 1.0, 0.16).set_delay(0.06 * i)
		tw.tween_property(n, "scale", Vector2.ONE, 0.2).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# справа — выбранный листок крупно
	big = Note.new()
	big.position = Vector2(1110, 150)
	big.size = Vector2(440, 560)
	big.pivot_offset = big.size * 0.5
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.large = true
	stage.add_child(big)
	select(0, true)

func _on_select(i: int, prev: int) -> void:
	if prev >= 0:
		(notes[prev] as Note).lift(false)
	var n: Note = notes[i]
	n.lift(true)
	big.copy_from(n)
	big.rotation = 0.02
	big.modulate.a = 0.6
	var tw := big.create_tween().set_parallel(true)
	tw.tween_property(big, "modulate:a", 1.0, 0.14)
	tw.tween_property(big, "rotation", 0.0, 0.18)

func _activate(i: int) -> void:
	if i < 0:
		return
	var n: Note = notes[i]
	if n.locked:
		G.game.main.ui("deny")
		n.shake()
		return
	# снять листок и прочитать вблизи
	mode = "read"
	G.game.main.ui("open", 1.1)
	reader = Control.new()
	reader.z_index = 20
	reader.size = STAGE
	reader.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(reader)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.size = STAGE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader.add_child(dim)
	var r := Note.new()
	r.large = true
	r.copy_from(n)
	r.fresh = false
	r.size = Vector2(600, 760)
	r.position = Vector2(500, 70)
	r.pivot_offset = r.size * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader.add_child(r)
	r.scale = Vector2.ONE * 0.6
	r.rotation = n.rot
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "rotation", -0.01, 0.22)
	var read: Array = G.meta().get("board_read", [])
	if not read.has(i):
		read.append(i)
		G.meta()["board_read"] = read
		G.save()
	n.fresh = false
	n.queue_redraw()
	big.fresh = false
	big.queue_redraw()
	G.events.append(["board_read", i])

func _back() -> bool:
	if mode == "read":
		reader.queue_free()
		reader = null
		mode = "list"
		G.game.main.ui("back")
		return true
	return false

# ---------------------------------------------------------------- рисунки
## Стена подъезда (верх побелён, низ — зелёная краска) и пробковая доска в деревянной раме с обрывками старых листков
class Wall extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.62, 0.58))
		draw_rect(Rect2(Vector2(0, 560), Vector2(size.x, size.y - 560)), Color(0.2, 0.32, 0.26))
		draw_line(Vector2(0, 560), Vector2(size.x, 560), Color(0.12, 0.2, 0.16), 3.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for k in 40:                                     # пятна на побелке
			draw_circle(Vector2(rng.randf_range(0, size.x), rng.randf_range(0, 540)), rng.randf_range(3, 18), Color(0.5, 0.5, 0.46, 0.18))
		var fr := Rect2(Vector2(70, 70), Vector2(990, 790))
		draw_rect(Rect2(fr.position + Vector2(8, 10), fr.size), Color(0, 0, 0, 0.45))
		draw_rect(fr, Color(0.36, 0.22, 0.12))
		var cork := fr.grow(-22)
		draw_rect(cork, Color(0.6, 0.44, 0.27))
		for k in 900:                                    # зерно пробки
			var p := Vector2(rng.randf_range(cork.position.x, cork.end.x), rng.randf_range(cork.position.y, cork.end.y))
			draw_rect(Rect2(p, Vector2(2, 2)), Color(0.42, 0.29, 0.16, 0.5) if k % 2 == 0 else Color(0.72, 0.55, 0.35, 0.4))
		# надпись на раме
		var f := MGUI.font("display")
		draw_string(f, Vector2(100, 60), "ДОСКА ОБЪЯВЛЕНИЙ", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(0.92, 0.9, 0.82))
		# обрывки старых объявлений, следы скотча и пустые кнопки (не листки — память о них)
		var scraps := [[Rect2(870, 120, 150, 210), 0.05], [Rect2(860, 520, 160, 120), -0.08], [Rect2(110, 700, 120, 120), 0.04]]
		for s in scraps:
			var sr: Rect2 = s[0]
			draw_set_transform(sr.get_center(), s[1], Vector2.ONE)
			var loc := Rect2(-sr.size * 0.5, sr.size)
			draw_colored_polygon(G67Diorama.paper_poly(Rect2(loc.position, Vector2(loc.size.x, loc.size.y * 0.3)), int(sr.position.x), 5.0), Color(0.78, 0.76, 0.68, 0.7))
			for k in 7:                                  # отрывные язычки, половина оторвана
				if k % 3 == 1 or k == 4:
					continue
				var tab := Rect2(loc.position + Vector2(6 + k * 21, loc.size.y * 0.3), Vector2(13, loc.size.y * (0.42 if k % 2 == 0 else 0.3)))
				draw_rect(tab, Color(0.78, 0.76, 0.68, 0.65))
				draw_line(tab.position + Vector2(6, 8), tab.position + Vector2(6, tab.size.y - 6), Color(0.3, 0.3, 0.4, 0.35), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for p in [Vector2(800, 690), Vector2(980, 440), Vector2(320, 640)]:
			draw_rect(Rect2(p, Vector2(46, 14)), Color(0.9, 0.86, 0.6, 0.35))
		for p in [Vector2(760, 150), Vector2(900, 460), Vector2(260, 160)]:
			draw_circle(p, 5.0, Color(0.55, 0.12, 0.1))
			draw_circle(p - Vector2(1.5, 1.5), 2.0, Color(0.9, 0.5, 0.45))

## Листок: бумага своего вида, кнопка или скотч, текст из данных, сгиб, пятно, «НОВОЕ»; закрытый — заклеен
class Note extends Control:
	var text := ""
	var look := "tariff"
	var locked := false
	var why := ""
	var fresh := false
	var large := false
	var seed_v := 1
	var rot := 0.0
	var sel := false
	func copy_from(o: Note) -> void:
		text = o.text
		look = o.look
		locked = o.locked
		why = o.why
		fresh = o.fresh
		seed_v = o.seed_v
		queue_redraw()
	func lift(v: bool) -> void:
		sel = v
		z_index = 2 if v else 0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2.ONE * (1.05 if v else 1.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", rot * (0.3 if v else 1.0), 0.14)
		queue_redraw()
	func shake() -> void:
		var tw := create_tween()
		for k in 4:
			tw.tween_property(self, "rotation", rot + (0.03 if k % 2 == 0 else -0.03), 0.04)
		tw.tween_property(self, "rotation", rot * 0.3, 0.04)
	func _draw() -> void:
		var k := size.x / 330.0
		var r := Rect2(Vector2.ZERO, size)
		var paper: Color = {"poster": Color(0.93, 0.85, 0.62), "tariff": Color(0.92, 0.91, 0.86), "official": Color(0.88, 0.86, 0.8)}.get(look, Color(0.9, 0.9, 0.86))
		draw_colored_polygon(G67Diorama.paper_poly(Rect2(r.position + Vector2(5, 8) * k, r.size), seed_v, 2.0), Color(0, 0, 0, 0.35 if not sel else 0.5))
		draw_colored_polygon(G67Diorama.paper_poly(r, seed_v, 2.0), paper)
		# сгиб и пятно влаги
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.52), Color(0, 0, 0, 0.06), 2.0)
		draw_circle(Vector2(size.x * 0.78, size.y * 0.8), 24 * k, Color(0.6, 0.5, 0.3, 0.08))
		var fd := MGUI.font("display")
		var fm := MGUI.font("mono")
		var fc := MGUI.font("caps")
		var ink := Color(0.12, 0.1, 0.09)
		if locked:
			# заклеен чистым листом крест-накрест скотчем
			draw_rect(r.grow(-8 * k), Color(0.8, 0.79, 0.74))
			draw_line(Vector2(10, 10) * k, size - Vector2(10, 10) * k, Color(0.9, 0.86, 0.6, 0.55), 18 * k)
			draw_line(Vector2(size.x - 10 * k, 10 * k), Vector2(10 * k, size.y - 10 * k), Color(0.9, 0.86, 0.6, 0.55), 18 * k)
			draw_string(fc, Vector2(22 * k, size.y * 0.5), "ПОКА НЕ ДОСТУПНО", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40 * k, int(20 * k), Color(0.4, 0.12, 0.1))
			if large and why != "":
				draw_string(MGUI.font("ui_b"), Vector2(22 * k, size.y * 0.5 + 34 * k), why, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40 * k, int(15 * k), Color(0.3, 0.26, 0.22))
		else:
			var parts := text.split(" · ")
			match look:
				"poster":
					# выцветшая афиша: крупная «67», заголовок, полоса
					draw_rect(Rect2(Vector2(14, 14) * k, Vector2(size.x - 28 * k, 26 * k)), Color(0.72, 0.16, 0.12, 0.85))
					draw_string(fc, Vector2(24 * k, 33 * k), "ОБЛАКО · РАЙОН", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(0.98, 0.9, 0.78))
					draw_string(fd, Vector2(20 * k, size.y * 0.42), "67", HORIZONTAL_ALIGNMENT_LEFT, -1, int(150 * k), Color(0.78, 0.5, 0.12, 0.85))
					_wrap(fd, String(parts[0]), Vector2(20 * k, size.y * 0.58), size.x - 40 * k, int(34 * k), Color(0.62, 0.12, 0.1))
					if parts.size() > 1:
						_wrap(MGUI.font("ui_b"), String(parts[1]), Vector2(20 * k, size.y * 0.75), size.x - 40 * k, int(18 * k), ink)
				"tariff":
					# машинописный лист: строки тарифов
					draw_string(fc, Vector2(20 * k, 40 * k), "ТАРИФЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), Color(0.3, 0.26, 0.22))
					var y := 80.0 * k
					for pt in parts:
						_wrap(fm, String(pt), Vector2(20 * k, y), size.x - 40 * k, int(17 * k), ink)
						draw_line(Vector2(20 * k, y + 10 * k), Vector2(size.x - 20 * k, y + 10 * k), Color(0, 0, 0, 0.12), 1.0)
						y += 46.0 * k
				"official":
					# объявление с печатью
					draw_string(fc, Vector2(20 * k, 40 * k), "ОБЪЯВЛЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), ink)
					draw_line(Vector2(20, 52) * k, Vector2(size.x - 20 * k, 52 * k), ink, 1.5)
					_wrap(MGUI.font("ui_b"), text, Vector2(20 * k, 92 * k), size.x - 40 * k, int(20 * k), ink)
					var sc := Vector2(size.x - 70 * k, size.y - 70 * k)
					draw_set_transform(sc, -0.3, Vector2.ONE)
					draw_arc(Vector2.ZERO, 44 * k, 0, TAU, 32, Color(0.2, 0.3, 0.6, 0.7), 3.0)
					draw_arc(Vector2.ZERO, 34 * k, 0, TAU, 32, Color(0.2, 0.3, 0.6, 0.5), 1.5)
					draw_string(fd, Vector2(-20 * k, 12 * k), "67", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * k), Color(0.2, 0.3, 0.6, 0.75))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# кнопка сверху (у афиши — скотч по углам)
		if look == "poster" and not locked:
			for p in [Vector2(0, 0), Vector2(size.x - 50 * k, 0)]:
				draw_rect(Rect2(p + Vector2(0, -4) * k, Vector2(50, 18) * k), Color(0.92, 0.88, 0.62, 0.55))
		else:
			draw_circle(Vector2(size.x * 0.5, 12 * k), 7 * k, Color(0.6, 0.14, 0.1) if look != "tariff" else Color(0.55, 0.5, 0.42))
			draw_circle(Vector2(size.x * 0.5 - 2 * k, 10 * k), 2.5 * k, Color(1, 0.7, 0.6, 0.7))
		if fresh:
			G67Diorama.draw_new(self, Vector2(size.x - 72 * k, size.y - 34 * k), -0.1)
		if sel and not large:
			draw_polyline(G67Diorama.paper_poly(r.grow(4), seed_v, 2.0) + PackedVector2Array([G67Diorama.paper_poly(r.grow(4), seed_v, 2.0)[0]]), Color(0.95, 0.75, 0.4), 2.0)
	func _wrap(f: Font, s: String, at: Vector2, w: float, sz: int, col: Color) -> void:
		draw_multiline_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, w, sz, -1, col)
