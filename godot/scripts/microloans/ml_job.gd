## Основа подработки-мини-игры: экран 1600×900, таймер, заголовок, итог. Каждая подработка — свой файл
## (ml_job_podezd / ml_job_repair / ml_job_sound / ml_job_junk) со своим управлением; итог — finished(score, extra).
## Стресс Пахана мешает: у каждой игры от него сужаются окна или дрожит управление (stress_k 0..1).
class_name MLJob
extends Control

signal finished(score: float, extra: Array)

const RED := Color(0.86, 0.09, 0.11)
const WHITE := Color(0.95, 0.96, 0.97)
const GREY := Color(0.5, 0.52, 0.55)
const GREEN := Color(0.4, 0.9, 0.45)

var font: Font
var serif: SystemFont
var stress_k := 0.0
var time_left := 30.0
var time_max := 30.0
var done := false
var title_l: Label
var hint_l: Label
var time_bar: ColorRect
var result_l: Label
var bot := -1.0               # проверка: бот-игрок качества 0..1 (−1 — играет человек)

func base_setup(f: Font, sf: SystemFont, stress: int, title: String, hint: String, t: float) -> void:
	font = f
	serif = sf
	stress_k = clampf((float(stress) - 40.0) / 60.0, 0.0, 1.0)
	time_left = t
	time_max = t
	size = Vector2(1600, 900)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.035, 0.94)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true             # фон — под рисунком самой подработки (_draw), а не поверх
	add_child(bg)
	title_l = txt(self, title, 44, WHITE, Vector2(70, 34), serif)
	hint_l = txt(self, hint, 18, Color(0.75, 0.76, 0.78), Vector2(74, 92))
	hint_l.size = Vector2(1450, 50)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tb := ColorRect.new()
	tb.color = Color(0.18, 0.18, 0.2)
	tb.position = Vector2(70, 140)
	tb.size = Vector2(1460, 8)
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tb)
	time_bar = ColorRect.new()
	time_bar.color = RED
	time_bar.position = tb.position
	time_bar.size = tb.size
	time_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_bar)
	result_l = txt(self, "", 54, WHITE, Vector2(0, 780), serif)
	result_l.size = Vector2(1600, 70)
	result_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func tick_time(dt: float) -> bool:
	if done:
		return false
	time_left -= dt
	time_bar.size.x = 1460.0 * clampf(time_left / time_max, 0.0, 1.0)
	return time_left > 0.0

func finish(score: float, extra: Array = [], text := "") -> void:
	if done:
		return
	done = true
	score = clampf(score, 0.0, 1.0)
	result_l.text = text if text != "" else ("ОТЛИЧНО!" if score > 0.85 else ("НОРМАЛЬНО" if score > 0.5 else "ТАК СЕБЕ"))
	result_l.add_theme_color_override("font_color", GREEN if score > 0.5 else RED)
	var tw := create_tween()
	tw.tween_interval(1.1 if bot < 0.0 else 0.05)
	tw.tween_callback(func(): finished.emit(score, extra))
