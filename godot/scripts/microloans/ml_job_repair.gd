## Ремонт телефона в три шага: 1) диагноз — по симптому выбрать деталь (1–4); 2) пайка — соединить провода
## одного цвета: выбрать слева (клик / W·S) и справа (клик / 1–5), неверный — искра; 3) включение — пробел,
## когда стрелка в зелёной зоне (стресс её сужает), три попытки. 35 секунд на всё.
class_name MLJobRepair
extends MLJob

const PARTS := ["РАЗЪЁМ ЗАРЯДКИ", "ШЛЕЙФ ЭКРАНА", "АККУМУЛЯТОР", "АНТЕННА"]
const SYMPTOMS := ["не заряжается, гнездо шатается", "экран чёрный, но звук уведомлений есть", "греется и выключается на 30%", "ловит сеть только у окна"]
const COLORS := [Color(0.9, 0.2, 0.2), Color(0.25, 0.5, 0.95), Color(0.95, 0.85, 0.2), Color(0.3, 0.85, 0.35), Color(0.95, 0.95, 0.95)]
var stage := 0
var answer := 0
var diag_ok := false
var right: Array = []           # какой цвет у каждой правой клеммы
var links := {}                 # левая → правая
var sel_left := 0
var sparks := 0
var needle := 0.0
var needle_dir := 1.0
var tries := 0
var boot_ok := false
var rng := RandomNumberGenerator.new()
var info: Label
var bot_t := 0.0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	base_setup(f, sf, stress, "РЕМОНТ ТЕЛЕФОНА", "Шаг 1: что сломано? Шаг 2: спаяй провода по цветам. Шаг 3: включи, когда стрелка в зелёном (пробел).", 35.0)
	rng.seed = seed_v
	answer = rng.randi() % PARTS.size()
	right = [0, 1, 2, 3, 4]
	for k in 8:
		var a := rng.randi() % 5
		var b := rng.randi() % 5
		var tmp = right[a]
		right[a] = right[b]
		right[b] = tmp
	info = txt(self, "", 26, WHITE, Vector2(120, 210), serif)
	info.size = Vector2(1360, 80)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	match stage:
		0:
			info.text = "Клиент: «%s». Какая деталь? (1–4 или клик)" % SYMPTOMS[answer]
		1:
			info.text = "Спаяй провода по цветам: выбери слева (W/S или клик), потом клемму справа (1–5 или клик). Искр: %d" % sparks
		2:
			info.text = "Включение: жми ПРОБЕЛ, когда стрелка в зелёной зоне. Попыток: %d из 3" % (3 - tries)
			needle += needle_dir * dt * (1.1 + 0.6 * stress_k)
			if needle > 1.0 or needle < 0.0:
				needle_dir *= -1.0
				needle = clampf(needle, 0.0, 1.0)
	if bot >= 0.0:
		_bot(dt)
	queue_redraw()

func _bot(dt: float) -> void:
	bot_t += dt
	if bot_t < 0.35:
		return
	bot_t = 0.0
	match stage:
		0:
			pick_part(answer if rng.randf() < bot else (answer + 1) % 4)
		1:
			var want: int = right.find(sel_left)
			pick_right(want if rng.randf() < bot else (want + 1) % 5)
		2:
			var zone := _zone()
			if (needle > zone.x and needle < zone.y) or rng.randf() > bot:
				boot()

func _zone() -> Vector2:
	var w := lerpf(0.22, 0.12, stress_k)
	return Vector2(0.62 - w * 0.5, 0.62 + w * 0.5)

func pick_part(i: int) -> void:
	if stage != 0:
		return
	diag_ok = i == answer
	stage = 1

func pick_right(i: int) -> void:
	if stage != 1 or i < 0 or i > 4:
		return
	if int(right[i]) == sel_left:
		links[sel_left] = i
		while links.has(sel_left) and links.size() < 5:
			sel_left = (sel_left + 1) % 5
		if links.size() >= 5:
			stage = 2
	else:
		sparks += 1

func boot() -> void:
	if stage != 2:
		return
	tries += 1
	var z := _zone()
	if needle > z.x and needle < z.y:
		boot_ok = true
		_end()
	elif tries >= 3:
		_end()

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	match stage:
		0:
			if k >= KEY_1 and k <= KEY_4:
				pick_part(k - KEY_1)
		1:
			if k == KEY_W or k == KEY_UP:
				sel_left = posmod(sel_left - 1, 5)
			elif k == KEY_S or k == KEY_DOWN:
				sel_left = posmod(sel_left + 1, 5)
			elif k >= KEY_1 and k <= KEY_5:
				pick_right(k - KEY_1)
		2:
			if k == KEY_SPACE:
				boot()
	get_viewport().set_input_as_handled()

func _gui_input(e: InputEvent) -> void:
	if done or not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = e.position
	match stage:
		0:
			for i in 4:
				if Rect2(Vector2(140 + i * 340, 330), Vector2(310, 120)).has_point(p):
					pick_part(i)
		1:
			for i in 5:
				if Rect2(Vector2(360, 330 + i * 80), Vector2(120, 50)).has_point(p):
					sel_left = i
				if Rect2(Vector2(1120, 330 + i * 80), Vector2(120, 50)).has_point(p):
					pick_right(i)
		2:
			boot()

func _end() -> void:
	var s := (0.35 if diag_ok else 0.0) + (0.35 * clampf(1.0 - 0.15 * float(sparks), 0.0, 1.0) if stage >= 2 else 0.1 * float(links.size()) / 5.0) + (0.3 if boot_ok else 0.0)
	finish(s, [], "ТЕЛЕФОН ОЖИЛ!" if boot_ok and diag_ok else ("ВКЛЮЧИЛСЯ, НО…" if boot_ok else "НЕ ВКЛЮЧАЕТСЯ"))

func _draw() -> void:
	match stage:
		0:
			for i in 4:
				var r := Rect2(Vector2(140 + i * 340, 330), Vector2(310, 120))
				draw_rect(r, Color(0.1, 0.1, 0.11))
				draw_rect(r, WHITE, false, 2.0)
				draw_string(serif, r.position + Vector2(18, 70), "[%d] %s" % [i + 1, PARTS[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, WHITE)
		1:
			for i in 5:
				var l := Rect2(Vector2(360, 330 + i * 80), Vector2(120, 50))
				draw_rect(l, COLORS[i])
				if i == sel_left and not links.has(i):
					draw_rect(l.grow(6), WHITE, false, 3.0)
				var r2 := Rect2(Vector2(1120, 330 + i * 80), Vector2(120, 50))
				draw_rect(r2, Color(0.15, 0.15, 0.16))
				draw_rect(Rect2(r2.position + Vector2(8, 8), Vector2(34, 34)), COLORS[int(right[i])])
				draw_string(font, r2.position + Vector2(56, 36), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, WHITE)
			for a in links:
				var y1 := 355.0 + float(a) * 80.0
				var y2 := 355.0 + float(links[a]) * 80.0
				draw_line(Vector2(480, y1), Vector2(1120, y2), COLORS[int(a)], 5.0)
		2:
			var bar := Rect2(Vector2(300, 420), Vector2(1000, 50))
			draw_rect(bar, Color(0.15, 0.15, 0.16))
			var z := _zone()
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * z.x, 0), Vector2(bar.size.x * (z.y - z.x), 50)), GREEN)
			var x := bar.position.x + bar.size.x * needle
			draw_line(Vector2(x, 400), Vector2(x, 490), WHITE, 5.0)
