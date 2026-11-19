## Звукарь на тусе: 1) собрать цепочку — кликнуть/нажать устройства по порядку сигнала (микрофон → пульт →
## усилитель → колонки), ошибка — фон в колонках; 2) уровни — выбрать фейдер (1–3), держать его в зелёной
## зоне стрелками, пока прыгают метры; 3) бит — ноты по трём дорожкам, жми A / S / D в момент, когда нота
## на линии (стресс сужает окно). 45 секунд.
class_name MLJobSound
extends MLJob

const CHAIN := ["МИКРОФОН", "ПУЛЬТ", "УСИЛИТЕЛЬ", "КОЛОНКИ"]
var stage := 0
var order: Array = []           # как лежат устройства на столе (номера CHAIN)
var next_dev := 0
var feedback := 0
var faders := [0.2, 0.8, 0.5]
var targets := [0.6, 0.35, 0.75]
var sel_f := 0
var hold_t := 0.0
var wob := 0.0
var notes: Array = []           # [время, дорожка, итог: 0 — ждёт, 1 — попал, -1 — мимо]
var song_t := 0.0
var hits := 0
var rng := RandomNumberGenerator.new()
var info: Label
var bot_t := 0.0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	base_setup(f, sf, stress, "ЗВУКАРЬ НА ТУСЕ", "Шаг 1: собери цепочку сигнала. Шаг 2: выставь уровни (1–3 — фейдер, ↑↓ — громкость). Шаг 3: попади в бит (A S D).", 45.0)
	rng.seed = seed_v
	order = [0, 1, 2, 3]
	for k in 6:
		var a := rng.randi() % 4
		var b := rng.randi() % 4
		var tmp = order[a]
		order[a] = order[b]
		order[b] = tmp
	for k in 3:
		targets[k] = rng.randf_range(0.25, 0.85)
	var t := 1.5
	for k in 22:
		notes.append([t, rng.randi() % 3, 0])
		t += [0.5, 0.5, 0.25, 0.75][rng.randi() % 4]
	info = txt(self, "", 24, WHITE, Vector2(120, 200), serif)

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	wob += dt
	match stage:
		0:
			info.text = "Собери цепочку: что подключить %s? (1–4 или клик) · фон: %d" % ["первым" if next_dev == 0 else "дальше", feedback]
		1:
			info.text = "Уровни: держи все три фейдера в зелёном 2 секунды (%.1f с)" % hold_t
			var all_ok := true
			for k in 3:
				var jitter: float = sin(wob * (2.0 + k) + k) * 0.03 * (1.0 + stress_k)
				if absf(faders[k] + jitter - targets[k]) > 0.07:
					all_ok = false
			hold_t = hold_t + dt if all_ok else maxf(0.0, hold_t - dt * 0.5)
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
				faders[sel_f] = clampf(faders[sel_f] + dt * 0.6, 0.0, 1.0)
			if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
				faders[sel_f] = clampf(faders[sel_f] - dt * 0.6, 0.0, 1.0)
			if hold_t >= 2.0:
				stage = 2
				song_t = 0.0
		2:
			song_t += dt
			info.text = "БИТ: A · S · D, когда нота на белой линии. Попаданий %d из %d" % [hits, notes.size()]
			for n in notes:
				if int(n[2]) == 0 and song_t - float(n[0]) > _window():
					n[2] = -1
			if song_t > float(notes.back()[0]) + 0.6:
				_end()
	if bot >= 0.0:
		_bot(dt)
	queue_redraw()

func _window() -> float:
	return lerpf(0.13, 0.08, stress_k)

func _bot(dt: float) -> void:
	bot_t += dt
	match stage:
		0:
			if bot_t > 0.3:
				bot_t = 0.0
				var want: int = order.find(next_dev)
				pick_dev(want if rng.randf() < bot else (want + 1) % 4)
		1:
			for k in 3:
				var d: float = targets[k] - faders[k]
				faders[k] = clampf(faders[k] + clampf(d, -dt * 0.6, dt * 0.6) * (1.0 if rng.randf() < bot else -0.5), 0.0, 1.0)
		2:
			for n in notes:
				if int(n[2]) == 0 and absf(song_t - float(n[0])) < 0.03 and rng.randf() < bot:
					hit(int(n[1]))

func pick_dev(slot: int) -> void:
	if stage != 0 or slot < 0 or slot > 3:
		return
	if int(order[slot]) == next_dev:
		next_dev += 1
		if next_dev >= 4:
			stage = 1
	else:
		feedback += 1

func hit(lane: int) -> void:
	if stage != 2:
		return
	var best = null
	var bd := INF
	for n in notes:
		if int(n[2]) == 0 and int(n[1]) == lane:
			var d := absf(song_t - float(n[0]))
			if d < bd:
				bd = d
				best = n
	if best != null and bd <= _window():
		best[2] = 1
		hits += 1

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	match stage:
		0:
			if k >= KEY_1 and k <= KEY_4:
				pick_dev(k - KEY_1)
		1:
			if k >= KEY_1 and k <= KEY_3:
				sel_f = k - KEY_1
		2:
			if k == KEY_A:
				hit(0)
			elif k == KEY_S:
				hit(1)
			elif k == KEY_D:
				hit(2)
	get_viewport().set_input_as_handled()

func _gui_input(e: InputEvent) -> void:
	if done or not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if stage == 0:
		for i in 4:
			if Rect2(Vector2(160 + i * 330, 330), Vector2(300, 150)).has_point(e.position):
				pick_dev(i)
	elif stage == 1:
		for i in 3:
			if Rect2(Vector2(500 + i * 220, 300), Vector2(120, 400)).has_point(e.position):
				sel_f = i

func _end() -> void:
	var s1 := clampf(1.0 - 0.2 * float(feedback), 0.0, 1.0) if stage >= 1 else 0.2 * float(next_dev) / 4.0
	var s2 := 1.0 if stage >= 2 else clampf(hold_t / 2.0, 0.0, 1.0)
	var s3 := float(hits) / float(notes.size()) if stage >= 2 else 0.0
	finish(s1 * 0.25 + s2 * 0.25 + s3 * 0.5, [], "ТУСА КАЧАЕТ!" if s3 > 0.8 else ("ПОКАТИТ" if s3 > 0.45 else "ДИДЖЕЙ ПЛАЧЕТ"))

func _draw() -> void:
	match stage:
		0:
			for i in 4:
				var r := Rect2(Vector2(160 + i * 330, 330), Vector2(300, 150))
				draw_rect(r, Color(0.1, 0.1, 0.11))
				draw_rect(r, WHITE, false, 2.0)
				var on: bool = int(order[i]) < next_dev
				draw_string(serif, r.position + Vector2(18, 84), "[%d] %s" % [i + 1, CHAIN[int(order[i])]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GREEN if on else WHITE)
		1:
			for i in 3:
				var x := 500.0 + i * 220.0
				draw_rect(Rect2(Vector2(x, 300), Vector2(120, 400)), Color(0.1, 0.1, 0.11))
				var ty: float = 700.0 - 400.0 * float(targets[i])
				draw_rect(Rect2(Vector2(x, ty - 28), Vector2(120, 56)), Color(0.2, 0.6, 0.25, 0.6))
				var jitter := sin(wob * (2.0 + i) + i) * 0.03 * (1.0 + stress_k)
				var fy: float = 700.0 - 400.0 * (float(faders[i]) + jitter)
				draw_rect(Rect2(Vector2(x - 10, fy - 10), Vector2(140, 20)), WHITE if i == sel_f else GREY)
				draw_string(font, Vector2(x + 44, 740), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, WHITE)
		2:
			var line_y := 680.0
			for lane in 3:
				var x := 520.0 + lane * 200.0
				draw_rect(Rect2(Vector2(x, 260), Vector2(160, 480)), Color(0.08, 0.08, 0.09))
				draw_string(serif, Vector2(x + 66, 770), ["A", "S", "D"][lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, WHITE)
			draw_line(Vector2(500, line_y), Vector2(1120, line_y), WHITE, 3.0)
			for n in notes:
				var dtn := float(n[0]) - song_t
				if dtn < -0.3 or dtn > 2.2:
					continue
				var y := line_y - dtn * 200.0
				var col := RED if int(n[2]) == 0 else (GREEN if int(n[2]) == 1 else GREY)
				draw_rect(Rect2(Vector2(530.0 + float(n[1]) * 200.0, y - 14), Vector2(140, 28)), col)
