## Экран слота DOG CASINO 67: 2D-сцена в SubViewport 1024 × 586 (раскладка — по снимку владельца), поле 5 × 3, пять барабанов
## останавливаются слева направо. До 67-го спина поле целиком из ротвейлеров не выпадает (не больше 4 за раз), на 67-м — все 15 ячеек.
## Картинки — assets/golda67/podzemka/slot/*.png; нет файла — временный символ (цветной круг и буква).
class_name G67SlotScreen
extends Control

signal finished(result: Dictionary)

const DIR := "res://assets/golda67/podzemka/slot/"
## Все координаты — в пикселях исходного снимка 1024 × 586 (slot_reference.jpg); вьюпорт и фон в тех же пропорциях и в том же масштабе
const SRC_SIZE := Vector2(1024, 586)
const REEL_RECT := Rect2(128, 95, 780, 408)
const COLS := 5
const ROWS := 3
const GRID_X := [128.0, 284.0, 440.0, 596.0, 752.0, 908.0]
const GRID_Y := [95.0, 231.0, 367.0, 503.0]
## Положение спрайта в ячейке (от левого верхнего угла ячейки, пиксели исходного снимка) и размер: как на примере
const SPR := {"dog": [Vector2(5, 7), Vector2(148, 126)], "dog2": [Vector2(4, 9), Vector2(148, 122)], "house": [Vector2(0, -37), Vector2(154, 174)],
	"paw": [Vector2(-3, -17), Vector2(159, 174)], "a": [Vector2(38, 25), Vector2(76, 88)], "k": [Vector2(38, 23), Vector2(76, 88)]}
## Выступ символов за ячейку (верх будки, лапа BONUS): маска шире REEL_RECT на CLIP_PAD сверху и по бокам
const CLIP_PAD := Vector2(8, 40)
const SYMS := ["dog", "dog2", "house", "paw", "a", "k"]
const WEIGHTS := {"dog": 8, "dog2": 12, "house": 12, "paw": 12, "a": 30, "k": 26}
const FALLBACK := {"dog": Color(0.2, 0.35, 0.8), "dog2": Color(0.75, 0.25, 0.6), "house": Color(0.9, 0.7, 0.15), "paw": Color(0.8, 0.1, 0.15), "a": Color(0.85, 0.2, 0.15), "k": Color(0.95, 0.8, 0.2)}
const LETTERS := {"dog": "РОТ", "dog2": "ШИ", "house": "БУД", "paw": "ЛАП", "a": "A", "k": "K"}

var tex := {}
var reels: Array = []              # на столбец: [clip, [3 + 1 TextureRect]]
var field: Array = []              # [столбец][строка] → символ
var spinning := false
var spin_n := 0
var rng := RandomNumberGenerator.new()
var lbl_spin: Label
var bar_fill: ColorRect
var _jp_since := -1.0
var lbl_left: Label
var lbl_msg: Label
var lbl_jp: Label
var coins: CPUParticles2D

func _ready() -> void:
	custom_minimum_size = Vector2(1024, 586)
	size = Vector2(1024, 586)
	rng.randomize()
	for s in SYMS:
		tex[s] = _load(s)
	var bg := TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = _load_path(DIR + "bg.png")
	bg.set_deferred("size", Vector2(1024, 586))
	bg.position = Vector2.ZERO
	bg.custom_minimum_size = Vector2(1024, 586)
	if bg.texture == null:
		var cr := ColorRect.new()
		cr.color = Color(0.35, 0.6, 0.9)
		cr.size = Vector2(1024, 586)
		add_child(cr)
		var wood := ColorRect.new()
		wood.color = Color(0.4, 0.18, 0.15)
		wood.position = Vector2(GRID_X[0], GRID_Y[0])
		wood.size = Vector2(GRID_X[5] - GRID_X[0], GRID_Y[3] - GRID_Y[0])
		add_child(wood)
	else:
		add_child(bg)
	for c in 5:
		var clip := Control.new()
		clip.clip_contents = true
		clip.position = Vector2(GRID_X[c] - CLIP_PAD.x, GRID_Y[0] - CLIP_PAD.y)
		clip.size = Vector2(GRID_X[c + 1] - GRID_X[c] + CLIP_PAD.x * 2.0, GRID_Y[3] - GRID_Y[0] + CLIP_PAD.y)
		add_child(clip)
		var cells: Array = []
		for r in 4:
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			clip.add_child(tr)
			cells.append(tr)
		reels.append([clip, cells])
	_panel()
	field = []
	for c in 5:
		field.append(["a", "k", "a"])
	_show_field()

func _load_path(p: String) -> Texture2D:
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

func _load(s: String) -> Texture2D:
	var t := _load_path(DIR + "sym_" + s + ".png")
	if t != null:
		return t
	var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = FALLBACK[s]
	for y in 160:
		for x in 160:
			if Vector2(x - 80, y - 80).length() < 70:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _panel() -> void:
	var pl := ColorRect.new()
	pl.color = Color(0.1, 0.06, 0.04, 0.88)
	pl.position = Vector2(175, 520)
	pl.size = Vector2(190, 52)
	add_child(pl)
	lbl_spin = _label("SPIN: 0 / 67", Vector2(182, 522), 20, Color(1.0, 0.85, 0.3))
	lbl_left = _label("ДО ДЖЕКПОТА: 67", Vector2(182, 543), 15, Color(0.9, 0.9, 0.9))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.25, 0.1, 0.1)
	bar_bg.position = Vector2(182, 563)
	bar_bg.size = Vector2(176, 6)
	add_child(bar_bg)
	bar_fill = ColorRect.new()
	bar_fill.color = Color(1.0, 0.82, 0.2)
	bar_fill.position = Vector2(182, 563)
	bar_fill.size = Vector2(0, 6)
	add_child(bar_fill)
	_label("67 SPIN JACKPOT", Vector2(247, 560), 9, Color(1, 1, 1))
	var pc := ColorRect.new()
	pc.color = Color(0.1, 0.06, 0.04, 0.88)
	pc.position = Vector2(372, 512)
	pc.size = Vector2(318, 34)
	add_child(pc)
	lbl_msg = _label("[E] КРУТИТЬ · УДЕРЖИВАЙ — ТУРБО", Vector2(376, 516), 17, Color(1, 1, 1))
	lbl_jp = _label("", Vector2(128, 240), 96, Color(1.0, 0.85, 0.2))
	lbl_jp.size = Vector2(780, 130)
	lbl_jp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_jp.add_theme_constant_override("outline_size", 16)
	lbl_jp.add_theme_color_override("font_outline_color", Color(0.4, 0.05, 0.05))
	lbl_jp.visible = false
	coins = CPUParticles2D.new()
	coins.position = Vector2(512, 40)
	coins.emitting = false
	coins.amount = 90
	coins.lifetime = 2.4
	coins.one_shot = true
	coins.explosiveness = 0.9
	coins.direction = Vector2(0, 1)
	coins.spread = 70.0
	coins.initial_velocity_min = 180.0
	coins.initial_velocity_max = 420.0
	coins.gravity = Vector2(0, 520)
	coins.scale_amount_min = 6.0
	coins.scale_amount_max = 12.0
	coins.color = Color(1.0, 0.82, 0.2)
	add_child(coins)

func _label(t: String, pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _set_cell(tr: TextureRect, sym: String, row: int, jitter := 0.0) -> void:
	var d: Array = SPR[sym]
	tr.texture = tex[sym]
	tr.size = d[1]
	tr.position = (d[0] as Vector2) + CLIP_PAD + Vector2(0, float(row) * (GRID_Y[3] - GRID_Y[0]) / 3.0 + jitter)
	tr.pivot_offset = tr.size * 0.5

func _show_field() -> void:
	for c in 5:
		var cells: Array = reels[c][1]
		for r in 3:
			_set_cell(cells[r + 1], field[c][r], r)
		(cells[0] as TextureRect).texture = null

func _rand_sym() -> String:
	var tot := 0
	for k in WEIGHTS:
		tot += int(WEIGHTS[k])
	var r := rng.randi() % tot
	for k in WEIGHTS:
		r -= int(WEIGHTS[k])
		if r < 0:
			return String(k)
	return "a"

## Поле для спина n: 67-й — все ротвейлеры; иначе случайное, не больше 4 ротвейлеров и без полного поля
func make_field(n: int) -> Array:
	var f: Array = []
	if n > 0 and n % 67 == 0:
		for c in 5:
			f.append(["dog", "dog", "dog"])
		return f
	var dogs := 0
	for c in 5:
		var col: Array = []
		for r in 3:
			var s := _rand_sym()
			if s == "dog":
				if dogs >= 4:
					s = _rand_sym() if _rand_sym() != "dog" else "a"
					if s == "dog":
						s = "k"
				else:
					dogs += 1
			col.append(s)
		f.append(col)
	return f

## Выплаты: 3+ одинаковых подряд слева на любой строке — 1…3 голды
func pays(f: Array) -> Dictionary:
	var gold := 0
	var lines: Array = []
	for r in 3:
		var s: String = f[0][r]
		var run := 1
		for c in range(1, 5):
			if f[c][r] == s:
				run += 1
			else:
				break
		if run >= 3:
			gold += clampi(run - 2, 1, 3)
			lines.append(r)
	return {"gold": gold, "lines": lines}

var _t := 0.0
var _tick := 0.0
var _stop_at: Array = []
var _cols_on: Array = []
var _done := 0
var _jackpot := false
var _turbo := false

func spin(n: int, turbo := false) -> void:
	if spinning:
		return
	spinning = true
	spin_n = n
	_jackpot = n > 0 and n % 67 == 0
	_turbo = turbo
	lbl_jp.visible = false
	_jp_since = -1.0
	bar_fill.size.x = 176.0 * float(n % 67 if n % 67 != 0 else 67) / 67.0
	field = make_field(n)
	lbl_spin.text = "SPIN: %d / 67" % (n % 67 if n % 67 != 0 else 67)
	lbl_left.text = "ДО ДЖЕКПОТА: %d" % (67 - (n % 67) if n % 67 != 0 else 0)
	var base := 0.14 if turbo else 0.6
	_stop_at = []
	for c in 5:
		_stop_at.append(base + (float(c) * 0.07 if turbo else (float(c) * 0.32 if not _jackpot else 0.4 * float(c) + 0.1 * float(c) * float(c))))
	_cols_on = [true, true, true, true, true]
	_done = 0
	_t = 0.0
	_tick = 0.0

func _process(dt: float) -> void:
	if _jp_since >= 0.0:
		_jp_since += dt
		lbl_jp.visible = _jp_since < 2.5 or int(_jp_since * 3.0) % 2 == 0
	if not spinning:
		return
	_t += dt
	_tick -= dt
	var rowh := (GRID_Y[3] - GRID_Y[0]) / 3.0
	for c in 5:
		if not _cols_on[c]:
			continue
		var cells: Array = reels[c][1]
		if _t >= float(_stop_at[c]):
			_cols_on[c] = false
			_done += 1
			for r in 3:
				_set_cell(cells[r + 1], field[c][r], r)
			for r in 4:
				(cells[r] as TextureRect).modulate = Color.WHITE
			(cells[0] as TextureRect).texture = null
			(cells[2] as TextureRect).scale = Vector2(1.08, 1.08)
			create_tween().tween_property(cells[2], "scale", Vector2.ONE, 0.15)
		elif _tick <= 0.0:
			for r in 4:
				_set_cell(cells[r], _rand_sym(), r - 1, rng.randf_range(-0.1, 0.1) * rowh)
				(cells[r] as TextureRect).modulate = Color(1, 1, 1, 0.65)
	if _tick <= 0.0:
		_tick = 0.05
	if _done < 5:
		return
	var pay := pays(field)
	var res := {"jackpot": _jackpot, "gold": int(pay["gold"]) + (67 if _jackpot else 0), "lines": pay["lines"], "field": field}
	if _jackpot:
		lbl_jp.text = "JACKPOT 67"
		lbl_jp.visible = true
		_jp_since = 0.0
		coins.emitting = true
		lbl_msg.text = "ДА НУ НАХУЙ"
	elif int(pay["gold"]) > 0:
		lbl_msg.text = "ВЫИГРЫШ: +%d голды" % int(pay["gold"])
	else:
		lbl_msg.text = "[E] КРУТИТЬ · УДЕРЖИВАЙ — ТУРБО"
	spinning = false
	finished.emit(res)
