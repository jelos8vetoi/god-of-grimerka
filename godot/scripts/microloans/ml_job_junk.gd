## Разбор хлама: восемь вещей по одной, на каждую 6 секунд — 1 ПРОДАТЬ, 2 РАЗОБРАТЬ на детали, 3 ОСТАВИТЬ
## (пригодится для «Решим вопрос» и событий). Цены не показаны — только описание: внимательный поймёт,
## что ценно (коллекционное, целое), а что — пакет с пакетами.
class_name MLJobJunk
extends MLJob

var items: Array = []           # номера MLData.JUNK
var cur := 0
var item_t := 6.0
var picks: Array = []           # [номер, sell/scrap/keep]
var rng := RandomNumberGenerator.new()
var name_l: Label
var hint_l2: Label
var bot_t := 0.0

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	base_setup(f, sf, stress, "РАЗБОР ХЛАМА", "1 — ПРОДАТЬ · 2 — РАЗОБРАТЬ на детали · 3 — ОСТАВИТЬ себе. На вещь 6 секунд. Цен нет — смотри на описание.", 60.0)
	rng.seed = seed_v
	var pool: Array = range(MLData.JUNK.size())
	for k in 8:
		var i := rng.randi() % pool.size()
		items.append(pool[i])
		pool.remove_at(i)
	name_l = txt(self, "", 48, WHITE, Vector2(160, 300), serif)
	hint_l2 = txt(self, "", 24, Color(0.8, 0.8, 0.82), Vector2(164, 380))
	var y := 520.0
	for k in 3:
		var b := txt(self, ["[1] ПРОДАТЬ", "[2] РАЗОБРАТЬ", "[3] ОСТАВИТЬ"][k], 34, WHITE, Vector2(160 + k * 420, y), serif)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var kk := k
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				choose(kk))
	_show()

func _show() -> void:
	if cur >= items.size():
		finish(1.0, picks, "РАЗОБРАНО")
		return
	var it: Array = MLData.JUNK[int(items[cur])]
	name_l.text = "%d/8 · %s" % [cur + 1, it[0]]
	hint_l2.text = String(it[1])
	item_t = 6.0

func _process(dt: float) -> void:
	if done:
		return
	tick_time(dt)
	item_t -= dt
	time_bar.size.x = 1460.0 * clampf(item_t / 6.0, 0.0, 1.0)
	if item_t <= 0.0:
		choose(1)                       # не решил — разбираешь на автомате
	if bot >= 0.0:
		bot_t += dt
		if bot_t > 0.2:
			bot_t = 0.0
			var it: Array = MLData.JUNK[int(items[cur])]
			var best := 0 if int(it[2]) >= int(it[4]) else 1
			if int(it[3]) > int(it[2]) and rng.randf() < 0.5:
				best = 2
			choose(best if rng.randf() < bot else rng.randi() % 3)

func choose(k: int) -> void:
	if done or cur >= items.size():
		return
	picks.append([int(items[cur]), ["sell", "scrap", "keep"][clampi(k, 0, 2)]])
	cur += 1
	_show()

func _unhandled_input(e: InputEvent) -> void:
	if done or bot >= 0.0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_3:
		choose(k - KEY_1)
		get_viewport().set_input_as_handled()
