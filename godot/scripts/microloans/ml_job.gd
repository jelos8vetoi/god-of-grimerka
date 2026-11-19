## Основа подработки-мини-игры: окно во весь стол интерфейса, компактный HUD на дизайн-системе MGUI — слева вверху
## плашка «название · цель · прогресс», справа вверху таймер и счёт, внизу одна строка клавиш. Итог — finished(score,
## extra). Каждая подработка — свой файл (ml_job_podezd / repair / deliv / junk / sound) со своим управлением.
## Стресс Пахана мешает: у каждой игры от него сужаются окна или дрожит управление (stress_k 0..1).
class_name MLJob
extends Control

signal finished(score: float, extra: Array)

const RED := MGUI.RED
const WHITE := MGUI.TEXT
const GREY := MGUI.TEXT_3
const GREEN := MGUI.GOOD

var font: Font
var serif: SystemFont
var stress_k := 0.0
var time_left := 30.0
var time_max := 30.0
var done := false
var title_l: Label
var hint_l: Label             # цель (одна короткая строка)
var time_l: Label
var time_bar: Dictionary
var result_l: Label
var left_box: VBoxContainer   # плашка слева: сюда 3D-подработка добавляет прогресс
var right_box: VBoxContainer  # плашка справа: таймер, счёт
var keys: Array = []          # короткие подсказки клавиш: [["WASD", "ехать"], …] — задать до base_setup
var bot := -1.0               # проверка: бот-игрок качества 0..1 (−1 — играет человек)
var career: MLCareer          # навыки и снаряжение Пахана (мини-игра читает свои параметры: tyaga_*, repair_*, …)
var tier := 1                 # уровень заказа 1..5: сложнее и дороже (MLUI.job_tier)
var snd: MLSound              # звук мини-игры

## параметр навыков для мини-игры (без карьеры — 0)
func cv(key: String) -> float:
	return career.v(key) if career != null else 0.0

func eq(tool: String) -> int:
	return career.eq(tool) if career != null else 0

func sfx(kind: String, pitch := 1.0) -> void:
	if snd != null:
		snd.play(kind, pitch)

## title — короткое название заказа, goal — цель одной строкой (подробности — по ходу, в подсказке tip)
func base_setup(f: Font, sf: SystemFont, stress: int, title: String, goal: String, t: float) -> void:
	font = f
	serif = sf
	stress_k = clampf((float(stress) - 40.0) / 60.0, 0.0, 1.0)
	time_left = t
	time_max = t
	size = (get_parent() as Control).size if get_parent() is Control and (get_parent() as Control).size.x >= 1600.0 else Vector2(1600, 900)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.035, 0.94)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true             # фон — под рисунком самой подработки (_draw), а не поверх
	add_child(bg)
	# слева вверху: название заказа, цель, прогресс
	var lp := MGUI.panel(true, MGUI.RED, MGUI.S3)
	lp.position = Vector2(16, 16)
	lp.custom_minimum_size = Vector2(340, 0)
	add_child(lp)
	left_box = MGUI.vbox(MGUI.S1)
	lp.add_child(left_box)
	title_l = MGUI.label(title, "caps", MGUI.TEXT_2)
	left_box.add_child(title_l)
	hint_l = MGUI.label(goal, "body_b", MGUI.TEXT, 316.0)
	hint_l.max_lines_visible = 2
	left_box.add_child(hint_l)
	# справа вверху: таймер и счёт
	var rp := MGUI.panel(true, null, MGUI.S3)
	rp.custom_minimum_size = Vector2(190, 0)
	rp.position = Vector2(size.x - 16 - 190, 16)
	add_child(rp)
	right_box = MGUI.vbox(MGUI.S1)
	rp.add_child(right_box)
	time_l = MGUI.label("", "mono_l")
	right_box.add_child(time_l)
	time_bar = MGUI.bar(166, 4, MGUI.RED)
	right_box.add_child(time_bar["box"])
	# внизу: клавиши одной строкой
	if not keys.is_empty():
		var kp := MGUI.panel(true, null, MGUI.S2)
		add_child(kp)
		kp.add_child(MGUI.hints(keys))
		_place_keys.call_deferred(kp)
	result_l = MGUI.label_3d("", "h1")
	result_l.position = Vector2(0, 700)
	result_l.size = Vector2(size.x, 44)
	result_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(result_l)

func _place_keys(kp: Control) -> void:
	if is_instance_valid(kp):
		kp.position = Vector2((size.x - kp.size.x) * 0.5, size.y - kp.size.y - 14.0)

func txt(parent: Node, s: String, fs: int, col: Color, pos: Vector2, f: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else MGUI.font("ui"))
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
	var k := clampf(time_left / time_max, 0.0, 1.0)
	MGUI.set_bar(time_bar, k, MGUI.RED if k < 0.25 else MGUI.TEXT_2)
	time_l.text = "%d:%02d" % [int(maxf(time_left, 0.0)) / 60, int(maxf(time_left, 0.0)) % 60]
	time_l.add_theme_color_override("font_color", MGUI.RED if k < 0.25 else MGUI.TEXT)
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
