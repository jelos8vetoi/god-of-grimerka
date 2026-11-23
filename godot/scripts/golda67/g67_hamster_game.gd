## «ТАПАЙ ХОМЯКОВ» — мини-игра секретной комнаты (PODZEMKA_DESIGN, раздел 4): 45 с, стена нор 3 × 8, до трёх хомяков одновременно.
## Попадание +10 × комбо (×1…×5), быстрый рыжий +25, золотой в короне +67 (один-два за игру). Промах по пустой норе или пропуск хомяка сбрасывает комбо.
## Удержание Esc/E 1,2 с — пропуск; короткое Esc — пауза. Логика (`step`, `tap_hole`, `simulate`) не зависит от отрисовки — бот в проверках.
class_name G67HamsterGame
extends Control

signal finished(result: Dictionary)

const TIME_TOTAL := 45.0
const COLS := 8
const ROWS := 3
const BASE_SCORE := 10
const FAST_SCORE := 25
const GOLD_SCORE := 67
const GOLD_TIMES := [14.0, 31.0]

var holes: Array = []                 # Rect2 каждой норы на экране
var hams: Array = []                  # {hole, age, life, kind, hit, hit_t}
var t_left := TIME_TOTAL
var score := 0
var combo := 1
var best_combo := 1
var hits := 0
var misses := 0
var golds := 0
var spawn_cd := 0.4
var running := false
var paused := false
var done := false
var hold := 0.0
var rng := RandomNumberGenerator.new()
var headless := false

func _ready() -> void:
	rng.randomize()
	size = Vector2(1280, 720)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	start()

func _layout() -> void:
	holes = []
	var sz := Vector2(1280, 720)
	var cw := 120.0
	var ch := 110.0
	var x0 := (sz.x - float(COLS) * cw) * 0.5
	for r in ROWS:
		for c in COLS:
			holes.append(Rect2(x0 + float(c) * cw + (30.0 if r % 2 == 1 else 0.0) - 15.0, 170.0 + float(r) * 165.0, cw - 20.0, ch))

func start() -> void:
	t_left = TIME_TOTAL
	score = 0
	combo = 1
	best_combo = 1
	hits = 0
	misses = 0
	golds = 0
	hams = []
	spawn_cd = 0.4
	running = true
	done = false

func _life(t: float) -> float:
	var k := 1.0 - t_left / TIME_TOTAL
	return lerpf(rng.randf_range(0.9, 1.6), rng.randf_range(0.6, 1.0), k)

func _free_holes() -> Array:
	var used := {}
	for h in hams:
		used[int(h["hole"])] = true
	var out: Array = []
	for i in holes.size():
		if not used.has(i):
			out.append(i)
	return out

func _spawn() -> void:
	var fr := _free_holes()
	if fr.is_empty():
		return
	var elapsed := TIME_TOTAL - t_left
	var kind := "normal"
	for gt in GOLD_TIMES:
		if golds + _gold_alive() < GOLD_TIMES.find(gt) + 1 and elapsed >= float(gt) and _gold_alive() == 0 and golds < GOLD_TIMES.find(gt) + 1:
			kind = "gold"
	if kind != "gold" and rng.randf() < 0.14:
		kind = "fast"
	var life := _life(elapsed)
	if kind == "fast":
		life *= 0.7
	elif kind == "gold":
		life = 1.4
	hams.append({"hole": fr[rng.randi() % fr.size()], "age": 0.0, "life": life, "kind": kind, "hit": false, "hit_t": 0.0})

func _gold_alive() -> int:
	var n := 0
	for h in hams:
		if String(h["kind"]) == "gold" and not bool(h["hit"]):
			n += 1
	return n

## Один шаг логики: время, появление и уход хомяков
func step(dt: float) -> void:
	if not running or paused or done:
		return
	t_left -= dt
	spawn_cd -= dt
	if spawn_cd <= 0.0 and hams.filter(func(h): return not bool(h["hit"])).size() < 3:
		_spawn()
		spawn_cd = lerpf(0.55, 0.3, 1.0 - t_left / TIME_TOTAL) * rng.randf_range(0.8, 1.2)
	for h in hams.duplicate():
		h["age"] = float(h["age"]) + dt
		if bool(h["hit"]):
			h["hit_t"] = float(h["hit_t"]) + dt
			if float(h["hit_t"]) > 0.45:
				hams.erase(h)
		elif float(h["age"]) > float(h["life"]):
			hams.erase(h)
			misses += 1
			combo = 1
	if t_left <= 0.0:
		_end(false)

## Удар по норе idx: попадание или промах по пустой норе
func tap_hole(idx: int) -> bool:
	if not running or paused or done:
		return false
	for h in hams:
		if int(h["hole"]) == idx and not bool(h["hit"]) and float(h["age"]) > 0.12:
			h["hit"] = true
			hits += 1
			var base := BASE_SCORE
			if String(h["kind"]) == "fast":
				base = FAST_SCORE
			elif String(h["kind"]) == "gold":
				base = GOLD_SCORE
				golds += 1
			score += base * combo
			combo = mini(combo + 1, 5)
			best_combo = maxi(best_combo, combo)
			return true
	combo = 1
	return false

func tap_at(p: Vector2) -> void:
	for i in holes.size():
		if (holes[i] as Rect2).grow(10.0).has_point(p):
			tap_hole(i)
			return
	if running and not paused:
		combo = 1

func _end(skipped: bool) -> void:
	if done:
		return
	done = true
	running = false
	finished.emit({"score": score, "best_combo": best_combo, "hits": hits, "misses": misses, "golds": golds, "skipped": skipped})

## Бот: каждые 0,1 с видит хомяков и бьёт каждого с вероятностью acc; возвращает итог
func simulate(acc: float, seed_: int = 1) -> Dictionary:
	rng.seed = seed_
	start()
	var guard := 0
	while running and guard < 2000:
		guard += 1
		step(0.1)
		for h in hams.duplicate():
			if not bool(h["hit"]) and float(h["age"]) > 0.2 and rng.randf() < acc:
				tap_hole(int(h["hole"]))
	return {"score": score, "best_combo": best_combo, "hits": hits, "misses": misses, "golds": golds, "time_left": t_left}

func _process(dt: float) -> void:
	if headless:
		return
	step(dt)
	if Input.is_key_pressed(KEY_ESCAPE) and not done:
		hold += dt
		if hold > 1.2:
			_end(true)
	else:
		hold = 0.0
	queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if headless:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if done:
			finished.emit({"closed": true})
		else:
			tap_at(get_local_mouse_position())
		accept_event()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_E:
			if done:
				finished.emit({"closed": true})
			else:
				tap_at(get_local_mouse_position())
			accept_event()
		elif ev.keycode == KEY_ESCAPE and not done:
			paused = not paused

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.1, 0.06, 0.96))
	for i in holes.size():
		var r: Rect2 = holes[i]
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, 14)), Color(0.4, 0.26, 0.14))
		draw_set_transform(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.78), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r.size.x * 0.42, Color(0.04, 0.02, 0.02))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for h in hams:
		var r2: Rect2 = holes[int(h["hole"])]
		var k := clampf(float(h["age"]) / 0.25, 0.0, 1.0)
		var fall := clampf((float(h["life"]) - float(h["age"])) / 0.2, 0.0, 1.0)
		var up := k * fall
		var c := r2.position + Vector2(r2.size.x * 0.5, r2.size.y * 0.8 - up * r2.size.y * 0.75)
		var kind := String(h["kind"])
		var col := Color(0.86, 0.62, 0.36) if kind == "normal" else (Color(1.0, 0.45, 0.1) if kind == "fast" else Color(1.0, 0.82, 0.2))
		var squash := 0.45 if bool(h["hit"]) else 1.0
		draw_set_transform(c, 0.0, Vector2(1.0 + (1.0 - squash), squash))
		draw_circle(Vector2.ZERO, 36.0, col)
		draw_circle(Vector2(-22, -28), 12.0, col)
		draw_circle(Vector2(22, -28), 12.0, col)
		draw_circle(Vector2(-12, -6), 5.0, Color.BLACK)
		draw_circle(Vector2(12, -6), 5.0, Color.BLACK)
		draw_circle(Vector2(0, 6), 4.0, Color(0.95, 0.5, 0.55))
		if kind == "gold":
			draw_colored_polygon(PackedVector2Array([Vector2(-18, -38), Vector2(-12, -58), Vector2(-4, -42), Vector2(0, -62), Vector2(4, -42), Vector2(12, -58), Vector2(18, -38)]), Color(1.0, 0.9, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(h["hit"]):
			draw_string(ThemeDB.fallback_font, c + Vector2(-20, -50), "* * *", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 0.4))
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(40, 24, 1200, 70), Color(0.08, 0.05, 0.03))
	draw_string(f, Vector2(70, 72), "ОЧКИ %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.85, 0.3))
	draw_string(f, Vector2(480, 72), "КОМБО ×%d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.5, 1.0, 0.6) if combo > 1 else Color(0.8, 0.8, 0.8))
	draw_string(f, Vector2(900, 72), "ВРЕМЯ %.0f" % maxf(t_left, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.5, 0.4) if t_left < 10.0 else Color.WHITE)
	if paused:
		draw_string(f, Vector2(500, 380), "ПАУЗА (Esc)", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color.WHITE)
	if hold > 0.1:
		draw_string(f, Vector2(500, 690), "ПРОПУСК… удерживай Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.8, 0.8))
	if done:
		draw_rect(Rect2(340, 190, 600, 340), Color(0.06, 0.04, 0.03, 0.97))
		draw_string(f, Vector2(380, 260), "ИТОГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1.0, 0.85, 0.3))
		draw_string(f, Vector2(380, 330), "ОЧКИ: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		draw_string(f, Vector2(380, 380), "ЛУЧШЕЕ КОМБО: ×%d" % best_combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		draw_string(f, Vector2(380, 430), "ПОПАДАНИЙ: %d · ПРОПУЩЕНО: %d" % [hits, misses], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.8, 0.8, 0.8))
		draw_string(f, Vector2(380, 495), "[E] / ЛКМ — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.8, 0.8))
