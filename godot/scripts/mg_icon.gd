## Значки интерфейса мини-игр — свои, векторные, рисуются кодом в одном стиле (толстая линия, скошенные формы),
## вместо эмодзи: эмодзи берутся из системного шрифта, цветные, разного веса и выглядят чужими.
## Значок задаётся именем (id) и цветом, рисуется в квадрате 24×24, растянутом под размер узла.
## Новый значок — ветка в _draw_icon. Имена: broom wrench box sliders crate doc map sofa bag cart star shop phone
## warn clock coin trophy mail back crown worker tool moon check lock plus bolt diamond heart sun search call
## camera door power fan lure cross hangup.
class_name MGIcon
extends Control

var id := "star"
var col := Color(0.95, 0.96, 0.97)
var weight := 2.0

static func make(icon_id: String, size_px: float, c: Color) -> MGIcon:
	var i := MGIcon.new()
	i.id = icon_id
	i.col = c
	i.custom_minimum_size = Vector2(size_px, size_px)
	i.size = Vector2(size_px, size_px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i

func set_icon(icon_id: String, c: Color) -> void:
	id = icon_id
	col = c
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y) / 24.0
	var o := (size - Vector2(24, 24) * s) * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s))
	_draw_icon()

func _l(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, col, weight, true)

func _p(pts: Array, closed := false) -> void:
	var arr := PackedVector2Array(pts)
	if closed:
		arr.append(arr[0])
	draw_polyline(arr, col, weight, true)

func _f(pts: Array) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

func _r(x: float, y: float, w: float, h: float, fill := false) -> void:
	draw_rect(Rect2(x, y, w, h), col, fill, -1.0 if fill else weight)

func _c(c: Vector2, r: float, fill := false) -> void:
	if fill:
		draw_circle(c, r, col)
	else:
		draw_arc(c, r, 0, TAU, 20, col, weight, true)

func _draw_icon() -> void:
	match id:
		"cross":
			_l(Vector2(6, 6), Vector2(18, 18))
			_l(Vector2(18, 6), Vector2(6, 18))
		"hangup":
			draw_arc(Vector2(12, 17), 9.0, PI + 0.5, TAU - 0.5, 12, col, weight + 1.0, true)
			_l(Vector2(4, 5), Vector2(20, 5))
		"broom":
			_l(Vector2(18, 3), Vector2(9, 13))
			_f([Vector2(6, 12), Vector2(11, 16), Vector2(7, 21), Vector2(3, 17)])
		"wrench":
			_l(Vector2(6, 18), Vector2(15, 9))
			draw_arc(Vector2(17, 7), 4.0, -0.3, 3.6, 12, col, weight, true)
		"box":
			_p([Vector2(4, 8), Vector2(12, 4), Vector2(20, 8), Vector2(20, 17), Vector2(12, 21), Vector2(4, 17)], true)
			_p([Vector2(4, 8), Vector2(12, 12), Vector2(20, 8)])
			_l(Vector2(12, 12), Vector2(12, 21))
		"sliders":
			for k in 3:
				_l(Vector2(6 + k * 6, 4), Vector2(6 + k * 6, 20))
				_r(4.0 + k * 6, [13.0, 6.0, 15.0][k], 4, 3, true)
		"crate":
			_r(4, 6, 16, 13)
			_l(Vector2(4, 11), Vector2(20, 11))
			_l(Vector2(9, 6), Vector2(9, 19))
			_l(Vector2(15, 6), Vector2(15, 19))
		"doc":
			_p([Vector2(6, 3), Vector2(15, 3), Vector2(19, 7), Vector2(19, 21), Vector2(6, 21)], true)
			for k in 3:
				_l(Vector2(9, 10 + k * 4), Vector2(16, 10 + k * 4))
		"map":
			_p([Vector2(3, 6), Vector2(9, 4), Vector2(15, 6), Vector2(21, 4), Vector2(21, 18), Vector2(15, 20), Vector2(9, 18), Vector2(3, 20)], true)
			_l(Vector2(9, 4), Vector2(9, 18))
			_l(Vector2(15, 6), Vector2(15, 20))
		"sofa":
			_r(3, 10, 4, 8)
			_r(17, 10, 4, 8)
			_r(7, 7, 10, 7)
			_l(Vector2(7, 18), Vector2(17, 18))
		"bag":
			_r(5, 9, 14, 11)
			draw_arc(Vector2(12, 9), 4.0, PI, TAU, 10, col, weight, true)
		"cart":
			_p([Vector2(3, 5), Vector2(6, 5), Vector2(8, 15), Vector2(18, 15), Vector2(20, 8), Vector2(7, 8)])
			_c(Vector2(9, 19), 1.6, true)
			_c(Vector2(17, 19), 1.6, true)
		"star":
			var pts: Array = []
			for k in 10:
				var a := -PI / 2 + k * PI / 5.0
				pts.append(Vector2(12, 12) + Vector2(cos(a), sin(a)) * (9.0 if k % 2 == 0 else 4.0))
			_f(pts)
		"shop":
			_p([Vector2(3, 9), Vector2(5, 4), Vector2(19, 4), Vector2(21, 9)], true)
			_r(5, 9, 14, 11)
			_r(10, 14, 4, 6, true)
		"phone":
			_r(7, 3, 10, 18)
			_l(Vector2(10, 18), Vector2(14, 18))
		"warn":
			_p([Vector2(12, 3), Vector2(21, 20), Vector2(3, 20)], true)
			_l(Vector2(12, 9), Vector2(12, 14))
			_c(Vector2(12, 17), 1.0, true)
		"clock":
			_c(Vector2(12, 12), 8.5)
			_p([Vector2(12, 7), Vector2(12, 12), Vector2(16, 14)])
		"coin":
			_c(Vector2(12, 12), 8.5)
			_p([Vector2(10, 17), Vector2(10, 7), Vector2(13.5, 7), Vector2(15, 9), Vector2(13.5, 11.5), Vector2(8, 11.5)])
			_l(Vector2(8, 14.5), Vector2(13, 14.5))
		"trophy":
			_p([Vector2(7, 4), Vector2(17, 4), Vector2(16, 12), Vector2(12, 14), Vector2(8, 12)], true)
			_l(Vector2(12, 14), Vector2(12, 18))
			_l(Vector2(8, 20), Vector2(16, 20))
			draw_arc(Vector2(7, 7), 3.0, PI * 0.5, PI * 1.5, 8, col, weight, true)
			draw_arc(Vector2(17, 7), 3.0, -PI * 0.5, PI * 0.5, 8, col, weight, true)
		"mail":
			_r(3, 6, 18, 12)
			_p([Vector2(3, 6), Vector2(12, 13), Vector2(21, 6)])
		"back":
			_p([Vector2(14, 5), Vector2(7, 12), Vector2(14, 19)])
			_l(Vector2(7, 12), Vector2(19, 12))
		"crown":
			_p([Vector2(4, 18), Vector2(3, 8), Vector2(8, 12), Vector2(12, 5), Vector2(16, 12), Vector2(21, 8), Vector2(20, 18)], true)
		"worker":
			_c(Vector2(12, 8), 3.5)
			_p([Vector2(5, 21), Vector2(6, 15), Vector2(18, 15), Vector2(19, 21)])
			_l(Vector2(7, 6), Vector2(17, 6))
		"tool":
			_l(Vector2(5, 19), Vector2(14, 10))
			_r(13, 4, 7, 5, true)
		"moon":
			draw_arc(Vector2(12, 12), 8.0, 0.9, 5.2, 16, col, weight, true)
			draw_arc(Vector2(16, 9), 6.5, 1.6, 4.3, 12, col, weight, true)
		"check":
			_p([Vector2(4, 12), Vector2(10, 18), Vector2(20, 6)])
		"lock":
			_r(6, 11, 12, 9, true)
			draw_arc(Vector2(12, 11), 4.0, PI, TAU, 10, col, weight, true)
		"plus":
			_l(Vector2(12, 5), Vector2(12, 19))
			_l(Vector2(5, 12), Vector2(19, 12))
		"bolt":
			_f([Vector2(14, 2), Vector2(6, 13), Vector2(11, 13), Vector2(9, 22), Vector2(18, 10), Vector2(13, 10)])
		"diamond":
			_f([Vector2(12, 4), Vector2(20, 12), Vector2(12, 20), Vector2(4, 12)])
		"heart":
			_p([Vector2(3, 12), Vector2(8, 12), Vector2(10, 7), Vector2(13, 17), Vector2(15, 12), Vector2(21, 12)])
		"sun":
			_c(Vector2(12, 12), 4.0)
			for k in 8:
				var a := k * TAU / 8.0
				_l(Vector2(12, 12) + Vector2(cos(a), sin(a)) * 6.5, Vector2(12, 12) + Vector2(cos(a), sin(a)) * 9.5)
		"search":
			_c(Vector2(10, 10), 6.0)
			_l(Vector2(15, 15), Vector2(20, 20))
		"call":
			# телефонная трубка наискось: два «уха» и ручка дугой
			draw_arc(Vector2(16.5, 7.5), 9.5, PI * 0.5, PI, 10, col, weight + 1.0, true)
			_c(Vector2(7, 7.5), 3.2, true)
			_c(Vector2(16.5, 17), 3.2, true)
		"camera":
			_r(3, 8, 13, 9)
			_f([Vector2(16, 11), Vector2(21, 8), Vector2(21, 17), Vector2(16, 14)])
		"door":
			_r(6, 3, 12, 18)
			_c(Vector2(15, 12), 1.0, true)
		"power":
			draw_arc(Vector2(12, 13), 7.5, -PI * 0.3, PI * 1.3, 16, col, weight, true)
			_l(Vector2(12, 3), Vector2(12, 12))
		"fan":
			_c(Vector2(12, 12), 9.0)
			for k in 3:
				var a := k * TAU / 3.0
				_l(Vector2(12, 12), Vector2(12, 12) + Vector2(cos(a), sin(a)) * 7.0)
		"lure":
			_c(Vector2(12, 13), 5.0)
			_l(Vector2(12, 3), Vector2(12, 8))
			draw_arc(Vector2(12, 13), 8.5, -0.6, 0.6, 6, col, weight, true)
			draw_arc(Vector2(12, 13), 8.5, PI - 0.6, PI + 0.6, 6, col, weight, true)
		_:
			_c(Vector2(12, 12), 3.0, true)
