class_name G67UpCard
extends Control
## Карточка ветки «АВТОРИТЕТА РАЙОНА». Одна система на девять веток: общий язык (номер, группа, название, шкала
## уровня, ценник, печать состояния), а «лицо» у каждой своё — материал подложки и рисунок (draw_face):
## ЗДОРОВЬЕ — металлическая пластина с крестом и шкалой здоровья, УРОН — бордовые косые полосы и резкая цифра,
## ВОССТАНОВЛЕНИЕ — штриховка закрытой системы и замок, ВАРИАНТЫ ЛЕЧЕНИЯ — ячейки вариантов, РЕДКИЕ ФИТСЫ —
## коллекционная карточка с тиснением, ПОВТОРНЫЙ ВЫБОР — две карточки и стрелка, СЛОТЫ — ячейки снаряжения,
## СТАРТОВАЯ ГОЛДА — монеты владельца, МАРШРУТЫ — схема районов. Всё рисуется кодом: картинок-заглушек нет.
## Состояния: buy — можно купить сейчас, short — не хватает РЕСПЕКТА, max — максимум, lock — ветка закрыта.

const SIZE := Vector2(300, 190)
const INK := Color(0.06, 0.06, 0.065)
const PLATE := Color(0.13, 0.13, 0.14)
const PLATE_LOCK := Color(0.085, 0.085, 0.09)
const BEIGE := Color(0.86, 0.81, 0.69)
const BEIGE_DIM := Color(0.55, 0.52, 0.46)
const GOLD := Color(0.88, 0.69, 0.3)
const BORDO := Color(0.5, 0.1, 0.12)
const RED := Color(0.78, 0.16, 0.15)
const GREY := Color(0.42, 0.42, 0.44)
const BLUE := Color(0.32, 0.5, 0.78)

var id := ""
var info: Dictionary = {}
var idx := 0
var group := ""
var lv := 0
var mx := 1
var cost := 0
var state := "buy"
var selected := false
var t := 0.0
var flash := 0.0               # вспышка покупки 1 → 0
var stamp_k := 0.0             # «КУПЛЕНО»: штамп падает на карточку
var shake := 0.0
var golda: Texture2D
var respect: Texture2D

func setup(u: Dictionary, i: int, grp: String) -> void:
	info = u
	id = String(u["id"])
	idx = i
	group = grp
	mx = int(u["max"])
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	golda = G67Icons.tex("icon_golda")
	respect = G67Icons.tex("icon_respect")

func refresh(level: int, price: int, have: int) -> void:
	lv = level
	cost = price
	if not bool(info["live"]):
		state = "lock"
	elif lv >= mx:
		state = "max"
	elif have >= cost:
		state = "buy"
	else:
		state = "short"
	queue_redraw()

func _process(dt: float) -> void:
	t += dt
	var busy := flash > 0.0 or stamp_k > 0.0 or shake > 0.0 or selected
	flash = maxf(0.0, flash - dt * 2.2)
	stamp_k = maxf(0.0, stamp_k - dt * 0.9)
	shake = maxf(0.0, shake - dt * 3.0)
	position.x += 0.0
	if busy:
		queue_redraw()

# ---------------------------------------------------------------- рисунок
func _draw() -> void:
	var off := Vector2(sin(t * 60.0) * 5.0 * shake, 0)
	draw_set_transform(off, 0.0, Vector2.ONE)
	var w := SIZE.x
	var h := SIZE.y
	var lock := state == "lock"
	# подложка: угол срезан, у металла — заклёпки; тень снизу
	var cut := 14.0
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h), Vector2(0, h)])
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(4, 5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(poly, _plate_col())
	_material(w, h, lock)
	# рамка: выбранная — бежевая с уголками, остальные — тонкая
	var edge := BEIGE if selected else (Color(0.24, 0.24, 0.26) if not lock else Color(0.17, 0.17, 0.18))
	var pl := poly.duplicate()
	pl.append(poly[0])
	draw_polyline(pl, edge, 2.0 if selected else 1.0, true)
	if selected:
		for c in [[Vector2(-6, -6), Vector2(14, 0), Vector2(0, 14)], [Vector2(w + 6, h + 6), Vector2(-14, 0), Vector2(0, -14)],
				[Vector2(-6, h + 6), Vector2(14, 0), Vector2(0, -14)]]:
			draw_line(c[0], c[0] + c[1], BEIGE, 3.0)
			draw_line(c[0], c[0] + c[2], BEIGE, 3.0)
	# шапка: номер и группа
	var fm := MGUI.font("mono")
	var fc := MGUI.font("caps")
	var fd := MGUI.font("display")
	draw_string(fm, Vector2(14, 22), "№ %02d" % (idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BEIGE_DIM if not lock else GREY)
	draw_string(fc, Vector2(64, 22), group, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _accent() if not lock else GREY)
	# название
	var title_col := BEIGE if not lock else GREY
	var tl := _title_lines()
	var ts := 22 if tl.size() == 1 else 18
	for line in tl:
		while ts > 14 and fd.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > SIZE.x - 132.0:
			ts -= 1                       # одно длинное слово («ВОССТАНОВЛЕНИЕ») — мельче, но не на рисунок
	for k in tl.size():
		draw_string(fd, Vector2(14, 52 + k * 20), String(tl[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, title_col)
	var vy := 0.0 if tl.size() == 1 else 12.0
	# лицо карточки
	draw_face(self, id, Rect2(w - 112, 30, 96, 96), lock, lv, mx, t, golda)
	# сейчас → после
	var now := G67UpCard.value_text(id, lv)
	var nxt := G67UpCard.value_text(id, mini(lv + 1, mx))
	var fu := MGUI.font("ui_b")
	if lock:
		draw_string(fu, Vector2(14, 90 + vy), "система закрыта", HORIZONTAL_ALIGNMENT_LEFT, w - 130, 14, GREY)
	elif state == "max":
		draw_string(fu, Vector2(14, 90 + vy), now, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(fu, now, 15, w - 130), BEIGE)
	else:
		draw_string(fu, Vector2(14, 84 + vy), now, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(fu, now, 13, w - 130), BEIGE_DIM)
		draw_string(fu, Vector2(14, 104 + vy), "→ " + nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(fu, "→ " + nxt, 15, w - 130), GOLD if state == "buy" else BEIGE)
	# шкала уровня: сегменты; купленные — бежевые, следующий — мигает контуром
	var seg_w := minf(26.0, (w - 150.0) / float(mx) - 4.0)
	for k in mx:
		var r := Rect2(14 + k * (seg_w + 4.0), h - 46, seg_w, 9)
		if k < lv:
			draw_rect(r, _accent())
		elif k == lv and state == "buy":
			draw_rect(r, Color(GOLD, 0.35 + 0.35 * (0.5 + 0.5 * sin(t * 5.0))), false, 1.5)
		else:
			draw_rect(r, Color(0.26, 0.26, 0.28) if not lock else Color(0.18, 0.18, 0.19), false, 1.0)
	draw_string(fm, Vector2(14, h - 16), "УР. %d / %d" % [lv, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BEIGE_DIM if not lock else GREY)
	# ценник справа внизу
	_price_tag(Rect2(w - 118, h - 44, 104, 30))
	# печати
	# печать — в правом нижнем углу, где у открытой ветки ценник: подписи и рисунок не перекрывает
	if state == "max":
		_stamp(Vector2(w - 82, h - 32), "МАКСИМУМ", GOLD, -0.12, 0.92)
	elif lock:
		_stamp(Vector2(w - 76, h - 32), "ЗАКРЫТО", GREY, -0.1, 0.92)
	if stamp_k > 0.0:
		var k2: float = 1.0 + 0.6 * pow(stamp_k, 3.0)
		_stamp(Vector2(w * 0.5, h * 0.5), "КУПЛЕНО", RED, -0.2, k2, clampf(stamp_k * 2.0, 0.0, 1.0))
	if flash > 0.0:
		draw_colored_polygon(poly, Color(GOLD, 0.25 * flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Размер шрифта, при котором строка влезает в ширину (не меньше 11)
func _fit(f: Font, text: String, sz: int, wmax: float) -> int:
	while sz > 11 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > wmax:
		sz -= 1
	return sz

## Название в одну строку, если влезает; иначе — две строки по словам (не режем посреди слова)
func _title_lines() -> Array:
	var fd := MGUI.font("display")
	var nm := String(info["name"])
	if fd.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= SIZE.x - 132.0:
		return [nm]
	var words := nm.split(" ")
	if words.size() < 2:
		return [nm]
	var half := int(ceil(words.size() / 2.0))
	return [" ".join(words.slice(0, half)), " ".join(words.slice(half))]

func _plate_col() -> Color:
	if state == "lock":
		return PLATE_LOCK
	match id:
		"heal", "reroll", "routes":
			return Color(0.17, 0.155, 0.135)      # картон и бумага: тёплый тёмный
		"rare":
			return Color(0.14, 0.12, 0.1)
		"dmg":
			return Color(0.12, 0.08, 0.085)
	return PLATE

func _accent() -> Color:
	match id:
		"hp": return Color(0.82, 0.3, 0.26)
		"dmg": return RED
		"rare", "gold": return GOLD
		"reroll", "slots": return BLUE
	return BEIGE

## Материал подложки: свой у каждой ветки (смысловой, не декор)
func _material(w: float, h: float, lock: bool) -> void:
	if lock:
		# штриховка закрытой системы
		for k in range(-int(h), int(w), 14):
			draw_line(Vector2(k, h), Vector2(k + h, 0), Color(1, 1, 1, 0.025), 2.0)
		return
	match id:
		"hp", "slots":
			for p in [Vector2(9, 9), Vector2(9, h - 9), Vector2(w - 9, h - 9)]:      # заклёпки металлической пластины
				draw_circle(p, 3.2, Color(0.3, 0.3, 0.32))
				draw_circle(p - Vector2(0.8, 0.8), 1.4, Color(0.5, 0.5, 0.52))
		"dmg":
			for k in range(-40, int(w), 34):                                   # косые бордовые полосы — агрессия
				draw_colored_polygon(PackedVector2Array([Vector2(k + 120, 0), Vector2(k + 136, 0), Vector2(k + 76, h), Vector2(k + 60, h)]), Color(BORDO, 0.35))
		"rare":
			var foil := PackedVector2Array([Vector2(3, 3), Vector2(SIZE.x - 17, 3), Vector2(SIZE.x - 3, 17), Vector2(SIZE.x - 3, SIZE.y - 3), Vector2(3, SIZE.y - 3), Vector2(3, 3)])
			draw_polyline(foil, Color(GOLD, 0.35 + 0.15 * sin(t * 2.0)), 1.0)                  # тиснение коллекционной карточки
		"heal", "reroll", "routes":
			for k in 7:                                                        # линовка картона
				draw_line(Vector2(10, 120 + k * 0.0 + k * 9), Vector2(w - 10, 120 + k * 9), Color(1, 1, 1, 0.018), 1.0)

func _price_tag(r: Rect2) -> void:
	var fm := MGUI.font("mono")
	if state == "lock" or state == "max":
		return
	var buy := state == "buy"
	var col := GOLD if buy else GREY
	draw_rect(r, Color(0, 0, 0, 0.35))
	draw_rect(r, col, false, 1.0)
	if respect != null:
		draw_texture_rect(respect, Rect2(r.position + Vector2(6, 3), Vector2(24, 24)), false, Color(1, 1, 1, 1.0 if buy else 0.45))
	draw_string(fm, r.position + Vector2(36, 21), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if not buy:
		draw_string(MGUI.font("caps"), r.position + Vector2(0, -6), "НЕ ХВАТАЕТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RED)

## Печать: рамка с неровным краем и текстом под наклоном
func _stamp(c: Vector2, text: String, col: Color, ang: float, k: float, a := 1.0) -> void:
	var fc := MGUI.font("caps")
	var sz := 18
	var tw := fc.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_set_transform(c, ang, Vector2(k, k))
	var r := Rect2(-tw * 0.5 - 10, -16, tw + 20, 30)
	var cc := Color(col, 0.85 * a)
	draw_rect(r, cc, false, 2.5)
	draw_rect(r.grow(-4), Color(col, 0.35 * a), false, 1.0)
	draw_string(fc, Vector2(-tw * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, cc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- значения и рисунки (общие с удостоверением)
## «Сейчас» и «после покупки»: точные числа по уровню (эффекты — G67Data.UPGRADES, Golda67)
static func value_text(uid: String, level: int) -> String:
	match uid:
		"hp": return "здоровье %d" % (100 + 10 * level)
		"dmg": return "урон +%d %%" % (4 * level) if level > 0 else "урон без надбавки"
		"res": return "перезарядки −%d %%" % (8 * level) if level > 0 else "перезарядки как есть"
		"heal": return "вариантов лечения: %d" % (1 + level)
		"rare": return "редкие бафы +%d %%" % (6 * level) if level > 0 else "редкие — как повезёт"
		"reroll": return "перевыборов: %d" % level if level > 0 else "перевыборов нет"
		"slots": return "слотов: %d" % (3 + level)
		"gold": return "на старте %d голды" % (30 * level) if level > 0 else "на старте без голды"
		"routes": return ["старт: ДВОР", "старт: ПОДЗЕМКА", "старт: ЛЕНТА", "старт: БОТОФЕРМА"][clampi(level, 0, 3)]
	return ""

## Рисунок ветки в квадрате r (общий для карточки и удостоверения)
static func draw_face(ci: CanvasItem, uid: String, r: Rect2, lock: bool, level: int, _maxl: int, tt: float, coin: Texture2D) -> void:
	var c := r.get_center()
	var s := r.size.x / 96.0
	var ink := BEIGE if not lock else Color(0.3, 0.3, 0.32)
	match uid:
		"hp":
			# крест на круглом жетоне и короткая шкала здоровья
			ci.draw_circle(c, 34 * s, Color(0.2, 0.2, 0.21))
			ci.draw_arc(c, 34 * s, 0, TAU, 32, ink, 2.0 * s)
			var red := Color(0.82, 0.3, 0.26) if not lock else ink
			ci.draw_rect(Rect2(c - Vector2(7, 20) * s, Vector2(14, 40) * s), red)
			ci.draw_rect(Rect2(c - Vector2(20, 7) * s, Vector2(40, 14) * s), red)
		"dmg":
			# три косых разреза — удар
			for k in 3:
				var o := Vector2((k - 1) * 18, (k - 1) * 4) * s
				ci.draw_line(c + o + Vector2(-14, 26) * s, c + o + Vector2(14, -26) * s, RED if not lock else ink, 6.0 * s)
			ci.draw_line(c + Vector2(-38, 30) * s, c + Vector2(38, 30) * s, ink, 2.0 * s)
		"res":
			# часы со стрелкой назад
			ci.draw_arc(c, 30 * s, 0.6, TAU - 0.2, 28, ink, 4.0 * s)
			ci.draw_line(c, c + Vector2(0, -18) * s, ink, 3.0 * s)
			ci.draw_line(c, c + Vector2(12, 6) * s, ink, 3.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(26, -14) * s, c + Vector2(38, -22) * s, c + Vector2(34, -6) * s]), ink)
		"heal":
			# ячейки вариантов: открытые — закрашены, следующий — контуром
			for k in 3:
				var rr := Rect2(c + Vector2(-42 + k * 30, -14) * s, Vector2(24, 28) * s)
				if k < 1 + level and not lock:
					ci.draw_rect(rr, Color(0.36, 0.7, 0.42))
					ci.draw_rect(Rect2(rr.get_center() - Vector2(2, 7) * s, Vector2(4, 14) * s), INK)
					ci.draw_rect(Rect2(rr.get_center() - Vector2(7, 2) * s, Vector2(14, 4) * s), INK)
				else:
					ci.draw_rect(rr, ink, false, 1.5 * s)
		"rare":
			# огранённый камень
			var pts := PackedVector2Array([c + Vector2(0, -30) * s, c + Vector2(28, -8) * s, c + Vector2(0, 32) * s, c + Vector2(-28, -8) * s])
			ci.draw_colored_polygon(pts, GOLD if not lock else Color(0.22, 0.22, 0.23))
			ci.draw_line(c + Vector2(-28, -8) * s, c + Vector2(28, -8) * s, INK, 2.0 * s)
			ci.draw_line(c + Vector2(0, -30) * s, c + Vector2(-10, -8) * s, INK, 1.5 * s)
			ci.draw_line(c + Vector2(0, -30) * s, c + Vector2(10, -8) * s, INK, 1.5 * s)
			ci.draw_line(c + Vector2(-10, -8) * s, c + Vector2(0, 32) * s, INK, 1.5 * s)
			ci.draw_line(c + Vector2(10, -8) * s, c + Vector2(0, 32) * s, INK, 1.5 * s)
			if not lock:
				var g := 0.5 + 0.5 * sin(tt * 3.0)
				ci.draw_line(c + Vector2(22, -30) * s, c + Vector2(22, -18) * s, Color(BEIGE, g), 2.0 * s)
				ci.draw_line(c + Vector2(16, -24) * s, c + Vector2(28, -24) * s, Color(BEIGE, g), 2.0 * s)
		"reroll":
			# две карточки и круговая стрелка
			ci.draw_rect(Rect2(c + Vector2(-34, -26) * s, Vector2(34, 46) * s), Color(0.24, 0.23, 0.21))
			ci.draw_rect(Rect2(c + Vector2(-34, -26) * s, Vector2(34, 46) * s), ink, false, 1.5 * s)
			ci.draw_rect(Rect2(c + Vector2(-6, -18) * s, Vector2(34, 46) * s), Color(0.3, 0.29, 0.26))
			ci.draw_rect(Rect2(c + Vector2(-6, -18) * s, Vector2(34, 46) * s), ink, false, 1.5 * s)
			ci.draw_arc(c + Vector2(30, -26) * s, 12 * s, PI * 0.9, PI * 2.2, 14, BLUE if not lock else ink, 3.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(38, -40) * s, c + Vector2(46, -30) * s, c + Vector2(34, -30) * s]), BLUE if not lock else ink)
		"slots":
			# пять ячеек снаряжения: открытые, следующая, закрытые с замком
			for k in 5:
				var rr2 := Rect2(c + Vector2(-38 + k * 17, -9) * s, Vector2(14, 18) * s)
				var open := k < 3 + level
				ci.draw_rect(rr2, Color(0.2, 0.22, 0.26) if open and not lock else Color(0.12, 0.12, 0.13))
				ci.draw_rect(rr2, BLUE if open and not lock else ink, false, 1.5 * s)
				if not open:
					ci.draw_arc(rr2.get_center() + Vector2(0, -2) * s, 3.0 * s, PI, TAU, 8, ink, 1.2 * s)
					ci.draw_rect(Rect2(rr2.get_center() + Vector2(-4, -1) * s, Vector2(8, 6) * s), ink)
		"gold":
			# стопки монет владельца: по уровню
			if coin != null:
				for k in clampi(level + 1, 1, 4):
					ci.draw_texture_rect(coin, Rect2(c + Vector2(-34 + k * 12, 6 - k * 10) * s, Vector2(40, 40) * s), false, Color(1, 1, 1, 1.0 if not lock else 0.3))
		"routes":
			# схема районов: ДВОР горит, остальные — по уровню
			var pts2 := [c + Vector2(-34, 22) * s, c + Vector2(-10, -4) * s, c + Vector2(14, 18) * s, c + Vector2(36, -20) * s]
			for k in 3:
				ci.draw_dashed_line(pts2[k], pts2[k + 1], ink, 2.0 * s, 5.0 * s)
			for k in 4:
				ci.draw_circle(pts2[k], 7 * s, GOLD if (k <= level and not lock) else Color(0.2, 0.2, 0.21))
				ci.draw_arc(pts2[k], 7 * s, 0, TAU, 12, ink, 1.5 * s)
	if lock:
		# замок закрытой ветки поверх рисунка
		var lc := r.position + Vector2(r.size.x - 18 * s, 14 * s)
		ci.draw_arc(lc + Vector2(0, -4) * s, 6 * s, PI, TAU, 10, Color(0.62, 0.6, 0.55), 2.2 * s)
		ci.draw_rect(Rect2(lc + Vector2(-8, -4) * s, Vector2(16, 13) * s), Color(0.62, 0.6, 0.55))
		ci.draw_rect(Rect2(lc + Vector2(-1.5, 0) * s, Vector2(3, 5) * s), INK)

# ---------------------------------------------------------------- анимации
func bought() -> void:
	flash = 1.0
	stamp_k = 1.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.08, 0.06)
	tw.tween_property(self, "scale", Vector2.ONE * (1.04 if selected else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func denied() -> void:
	shake = 1.0

func set_selected(v: bool) -> void:
	if selected == v:
		return
	selected = v
	z_index = 1 if v else 0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * (1.04 if v else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()
