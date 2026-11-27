## Финиш и экран результатов VACUUM RACING. Создаётся в RaceHud.finale_start на финише игрока, живёт на столе
## 1600×900 (hud.stage). Два такта:
##  1) сразу на финише — затемнение и косая чёрная полоса «ФИНИШ», звучит «Династия» с возгласа (RaceData.FINALE);
##  2) на дропе (бас вступает; время — по позиции проигрывания, а не по таймеру) — вспышка, полоса улетает,
##     врываются место, статистика, таблица и кнопки. Нет файла песни — второй такт через FINALE.fallback.
## Палитра и шрифт — как у HUD гонок (красный, чёрный, белый; Russo One). Таблица обновляется вживую, пока
## остальные едут; finalize() — когда гонка закончилась для всех. Кнопки — hud.menu_rows (ввод в RaceHud._input).
extends Control

const WHITE := Color(0.95, 0.96, 0.97)
const SILVER := Color(0.72, 0.74, 0.77)
const GREY := Color(0.46, 0.48, 0.51)
const INK := Color(0.03, 0.03, 0.035)
const RED := Color(0.86, 0.09, 0.11)
const STAGE := Vector2(1600, 900)

var hud
var race
var player: AudioStreamPlayer
var clock := 0.0
var dropped := false
var final := false
var shade: ColorRect
var intro: Node2D
var ui: Control                    # всё, что врывается на дропе
var rows_box: Control
var rows_t := 0.0
var rows_sig := ""
var btns: Array = []               # [Polygon2D, Line2D, Label]
var rays: Polygon2D
var hero: Label
var cfg: Dictionary = RaceData.FINALE

func _ready() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.position = Vector2(-2000, -2000)
	shade.size = STAGE + Vector2(4000, 4000)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	create_tween().tween_property(shade, "color:a", 0.5, 0.25)
	_intro()
	_music()

# ---------------- такт 1: финиш ----------------
func _intro() -> void:
	intro = Node2D.new()
	intro.position = Vector2(-1900, 0)
	add_child(intro)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-200, 470), Vector2(1800, 330), Vector2(1800, 520), Vector2(-200, 660)])
	band.color = INK
	intro.add_child(band)
	var line := Polygon2D.new()
	line.polygon = PackedVector2Array([Vector2(-200, 668), Vector2(1800, 528), Vector2(1800, 542), Vector2(-200, 682)])
	line.color = RED
	intro.add_child(line)
	var l := _lab(intro, "ФИНИШ", 170, WHITE, Vector2(430, 330), hud.serif)
	l.rotation = deg_to_rad(-4.0)
	var tw := intro.create_tween()
	tw.tween_property(intro, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(intro, "position:x", 40.0, 2.6)          # едва ползёт, пока звучит возглас

func _music() -> void:
	var path := String(cfg["path"])
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if not (s is AudioStream):
		return
	if s is AudioStreamMP3:
		s = (s as AudioStreamMP3).duplicate()
		(s as AudioStreamMP3).loop = false                   # заглавная тема зациклена — здесь играем до конца
	player = AudioStreamPlayer.new()
	player.stream = s
	player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	player.volume_db = float(cfg["db"])
	add_child(player)
	player.play(float(cfg["start"]))

## музыка результатов — громкость для проверок и для остановки
func music_playing() -> bool:
	return player != null and player.playing

func _song_pos() -> float:
	if player == null or not player.playing:
		return -1.0
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func _process(dt: float) -> void:
	clock += dt
	if not dropped:
		var wait := float(cfg["drop"]) - float(cfg["start"]) + float(cfg["nudge"])
		var pos := _song_pos()
		if pos >= 0.0 and pos >= float(cfg["drop"]) + float(cfg["nudge"]):
			_drop()
		elif player == null and clock >= float(cfg["fallback"]):
			_drop()
		elif clock >= wait + 0.4:
			_drop()                                           # звук не идёт (немой драйвер) — по часам
		return
	if rays != null:
		rays.rotation += dt * 0.25
	if hero != null and _place() == 1 and String(race.cfg.get("mode", "single")) != "time":
		hero.scale = Vector2.ONE * (1.0 + 0.025 * sin(clock * 5.0))
	rows_t -= dt
	if rows_t <= 0.0:
		rows_t = 0.3
		_rows_refresh()

# ---------------- такт 2: дроп ----------------
func _drop() -> void:
	if dropped:
		return
	dropped = true
	var tw := intro.create_tween().set_parallel(true)
	tw.tween_property(intro, "position:x", 2200.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(intro, "modulate:a", 0.0, 0.22)
	create_tween().tween_property(shade, "color:a", 0.86, 0.12)
	var flash := ColorRect.new()
	flash.color = WHITE
	flash.position = Vector2(-2000, -2000)
	flash.size = STAGE + Vector2(4000, 4000)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ft.tween_callback(flash.queue_free)
	_build()
	move_child(flash, get_child_count() - 1)
	# удар: весь экран коротко вздрагивает
	var base := position
	var kt := create_tween()
	for k in 5:
		kt.tween_property(self, "position", base + Vector2(randf_range(-10, 10), randf_range(-7, 7)) * (1.0 - k * 0.2), 0.03)
	kt.tween_property(self, "position", base, 0.04)

func _place() -> int:
	var me: RaceRider = race.local
	if me == null:
		return 0
	if me.finished:
		var k: int = race.order.find(me)
		return k + 1 if k >= 0 else me.rank
	for k in race.results.size():
		if race.results[k]["rider"] == me:
			return k + 1
	return me.rank

func _build() -> void:
	ui = Control.new()
	ui.size = STAGE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var me: RaceRider = race.local
	var mode := String(race.cfg.get("mode", "single"))
	var place := _place()
	var win: bool = place == 1 and mode != "time" and race.riders.size() > 1
	var n: int = race.riders.size()
	# левая половина — красный осколок с местом
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([Vector2(-60, 40), Vector2(760, -10), Vector2(660, 920), Vector2(-60, 940)])
	shard.color = RED if (win or mode == "time") else Color(0.55, 0.06, 0.08)
	ui.add_child(shard)
	_in(shard, Vector2(-700, 0), 0.0, 0.18)
	var cut := Polygon2D.new()                                 # белая косая черта по краю осколка
	cut.polygon = PackedVector2Array([Vector2(770, -20), Vector2(790, -20), Vector2(690, 940), Vector2(670, 940)])
	cut.color = WHITE
	ui.add_child(cut)
	_in(cut, Vector2(0, -900), 0.05, 0.18)
	if win:
		rays = Polygon2D.new()                                 # лучи за цифрой — только у победителя
		var rp := PackedVector2Array()
		for k in 12:
			var a0 := TAU * float(k) / 12.0
			rp.append_array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * 900.0, Vector2(cos(a0 + 0.16), sin(a0 + 0.16)) * 900.0])
		rays.polygon = rp
		var polys: Array = []
		for k in 12:
			polys.append(PackedInt32Array([k * 3, k * 3 + 1, k * 3 + 2]))
		rays.polygons = polys
		rays.color = Color(1, 1, 1, 0.09)
		rays.position = Vector2(330, 380)
		ui.add_child(rays)
		rays.modulate.a = 0.0
		rays.create_tween().tween_property(rays, "modulate:a", 1.0, 0.4).set_delay(0.1)
	if mode == "time":
		var big := _lab(ui, "ВРЕМЯ", 34, INK, Vector2(70, 150), hud.serif)
		_in(big, Vector2(-200, 0), 0.08)
		hero = _lab(ui, RaceHud.fmt(me.finish_t if me != null else race.t), 128, WHITE, Vector2(54, 200), hud.serif, 14)
		hero.pivot_offset = Vector2(300, 80)
		_punch(hero, 0.06)
	else:
		var shadow := _lab(ui, str(place), 400, INK, Vector2(84, 46), hud.serif)
		hero = _lab(ui, str(place), 400, WHITE, Vector2(64, 26), hud.serif)
		var hw: float = hud.serif.get_string_size(str(place), HORIZONTAL_ALIGNMENT_LEFT, -1, 400).x
		hero.pivot_offset = Vector2(hw * 0.5, 260)
		shadow.pivot_offset = hero.pivot_offset
		_punch(hero, 0.04)
		_punch(shadow, 0.07)
		var of := _lab(ui, "/%d" % n, 70, INK if win else WHITE, Vector2(84 + hw, 330), hud.serif)
		_in(of, Vector2(120, 0), 0.16)
	# плашка под местом: победа — белая с чёрным, иначе — чёрная с белым
	var tag := Node2D.new()
	tag.position = Vector2(70, 560)
	tag.rotation = deg_to_rad(-6.0)
	ui.add_child(tag)
	var tp := Polygon2D.new()
	var tag_text: String = "ПОБЕДА!" if win else ("ЗАЕЗД НА ВРЕМЯ" if mode == "time" else ("ФИНИШ" if me != null and me.finished else "НЕ ДОЕХАЛ"))
	var tag_size := 76 if win else 52
	var tw2: float = hud.serif.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
	tp.polygon = PackedVector2Array([Vector2(-14, 4), Vector2(tw2 + 34, -6), Vector2(tw2 + 26, tag_size * 1.25 + 4), Vector2(-20, tag_size * 1.25 + 12)])
	tp.color = WHITE if win else INK
	tag.add_child(tp)
	_lab(tag, tag_text, tag_size, INK if win else WHITE, Vector2(8, 0), hud.serif)
	_in(tag, Vector2(-600, 40), 0.12, 0.2)
	var place_word := "" if mode == "time" else ("%d МЕСТО ИЗ %d" % [place, n])
	var sub := _lab(ui, place_word + ("   ·   " if place_word != "" else "") + String(RaceData.track(String(race.cfg.get("track", ""))).get("name", "")), 20, WHITE, Vector2(80, 690))
	_in(sub, Vector2(-300, 0), 0.2)
	if win:
		_shards()
	# правая половина — статистика
	var head := _lab(ui, "ИТОГИ ЗАЕЗДА", 44, WHITE, Vector2(840, 54), hud.serif)
	_in(head, Vector2(300, 0), 0.06)
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(0, 0), Vector2(330, -9), Vector2(327, 3), Vector2(-3, 12)])
	slash.color = RED
	slash.position = Vector2(844, 112)
	ui.add_child(slash)
	_in(slash, Vector2(400, 0), 0.1)
	var stats := _stats()
	for k in stats.size():
		var cx := 846.0 + float(k % 3) * 240.0
		var cy := 136.0 + float(k / 3) * 96.0
		var cell := Control.new()
		cell.position = Vector2(cx, cy)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(cell)
		_lab(cell, String(stats[k][0]), 15, SILVER, Vector2(0, 0), hud.tech)
		var v := _lab(cell, String(stats[k][1]), 36, WHITE, Vector2(0, 20), hud.serif)
		if String(stats[k][2]) != "":
			var nw: float = hud.serif.get_string_size(v.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
			var badge := _lab(cell, String(stats[k][2]), 14, WHITE, Vector2(nw + 8, 30), hud.serif)
			var sb := StyleBoxFlat.new()
			sb.bg_color = RED
			sb.content_margin_left = 6.0
			sb.content_margin_right = 6.0
			badge.add_theme_stylebox_override("normal", sb)
		_in(cell, Vector2(260, 0), 0.12 + 0.04 * k)
	# таблица участников (живая, пока другие едут)
	var th := _lab(ui, "ТАБЛИЦА", 18, SILVER, Vector2(846, 340), hud.tech)
	_in(th, Vector2(300, 0), 0.3)
	rows_box = Control.new()
	rows_box.position = Vector2(846, 368)
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rows_box)
	_in(rows_box, Vector2(320, 0), 0.32)
	_rows_refresh()
	_buttons()

## [подпись, значение, отметка] — только настоящие замеры гонки
func _stats() -> Array:
	var me: RaceRider = race.local
	var mode := String(race.cfg.get("mode", "single"))
	var tid := String(race.cfg.get("track", ""))
	var out: Array = []
	var fin: bool = me != null and me.finished
	out.append(["ВРЕМЯ ГОНКИ", RaceHud.fmt(me.finish_t) if fin else "—", ""])
	out.append(["ЛУЧШИЙ КРУГ", RaceHud.fmt(me.best_lap) if me != null and me.best_lap > 0.0 else "—", "НОВЫЙ" if race.new_record.contains("lap") else ""])
	out.append(["МАКС. СКОРОСТЬ", "%d км/ч" % roundi(race.top_kmh), ""])
	out.append(["ОБГОНЫ", "—" if mode == "time" else str(race.overtakes), ""])
	out.append(["КОЛЬЦА", "—" if race.track.rings.is_empty() else str(race.rings_got), ""])
	var rec := RaceSave.best(tid, mode) if mode != "online" else 0.0
	out.append(["РЕКОРД ТРАССЫ", RaceHud.fmt(rec) if rec > 0.0 else "—", "НОВЫЙ" if race.new_record.contains("time") else ""])
	return out

func _rows() -> Array:
	var out: Array = []
	var me: RaceRider = race.local
	if race.state == "results" and not race.results.is_empty():
		for k in race.results.size():
			var row: Dictionary = race.results[k]
			var r: RaceRider = row["rider"]
			var right: String = "ВЫШЕЛ" if row["dc"] else ("~" if row["est"] else "") + RaceHud.fmt(float(row["time"]))
			out.append([k + 1, String(row["title"]), right, r == me])
	else:
		for r in race.standings():
			var right := ""
			if r.disconnected:
				right = "ВЫШЕЛ"
			elif r.finished:
				right = RaceHud.fmt(r.finish_t)
			else:
				right = "КРУГ %d / %d" % [mini(r.lap + 1, race.laps), race.laps]
			out.append([r.rank, r.title, right, r == me])
	return out

func _rows_refresh() -> void:
	if rows_box == null:
		return
	var rows := _rows()
	var sig := str(rows)
	if sig == rows_sig:
		return
	rows_sig = sig
	for c in rows_box.get_children():
		c.queue_free()
	for k in mini(rows.size(), 8):
		var row: Array = rows[k]
		var mine: bool = row[3]
		var y := float(k) * 36.0
		if mine:
			var band := Polygon2D.new()
			band.polygon = PackedVector2Array([Vector2(-8, y - 2), Vector2(712, y - 6), Vector2(708, y + 30), Vector2(-12, y + 33)])
			band.color = WHITE
			rows_box.add_child(band)
		var ink := INK if mine else WHITE
		_lab(rows_box, str(row[0]), 24, INK if mine else RED, Vector2(0, y - 2), hud.serif)
		_lab(rows_box, String(row[1]), 20, ink, Vector2(48, y + 1), hud.tech)
		var right := _lab(rows_box, String(row[2]), 20, ink if not String(row[2]).begins_with("КРУГ") else (GREY if mine else SILVER), Vector2(440, y + 1), hud.serif)
		right.size = Vector2(250, 26)
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# ---------------- кнопки ----------------
func _items() -> Array:
	var mode := String(race.cfg.get("mode", "single"))
	var items: Array = []
	if mode == "online":
		if race.authority and race.state == "results" and race.net != null:
			items.append(["ВСЕ В ЛОББИ", func():
				race.net.back_to_lobby()
				race.quit_to_lobby()])
		items.append(["В ГЛАВНОЕ МЕНЮ", func(): race.quit_main()])
	else:
		items.append(["ПОВТОРИТЬ ЗАЕЗД", func(): race.restart()])
		items.append(["В МЕНЮ ГОНОК", func(): race.quit(true)])
		items.append(["В ГЛАВНОЕ МЕНЮ", func(): race.quit_main()])
	return items

func _buttons() -> void:
	for b in btns:
		(b[0] as Node).queue_free()
	btns = []
	var items := _items()
	var labels: Array = []
	var x := 846.0
	for k in items.size():
		var w := 236.0
		var holder := Node2D.new()
		holder.position = Vector2(x, 790)
		ui.add_child(holder)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(14, 0), Vector2(w, 0), Vector2(w - 14, 58), Vector2(0, 58)])
		holder.add_child(poly)
		var edge := Line2D.new()
		edge.points = poly.polygon
		edge.closed = true
		edge.width = 2.0
		edge.default_color = WHITE
		holder.add_child(edge)
		var l := _lab(holder, String(items[k][0]), 19, WHITE, Vector2(0, 0), hud.serif)
		l.size = Vector2(w, 58)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		labels.append(l)
		btns.append([holder, poly, edge, l])
		_in(holder, Vector2(0, 160), 0.36 + 0.05 * k, 0.2)
		x += w + 12.0
	if String(race.cfg.get("mode", "single")) == "online" and not (race.authority and race.state == "results"):
		var note := _lab(ui, "Хост решает, ехать ли ещё раз." if race.state == "results" else "Остальные ещё едут — таблица обновляется.", 15, SILVER, Vector2(846, 762), hud.tech)
		btns.append([note, null, null, null])
	hud.menu_sel = 0
	hud.results_menu(items, labels)

## выделение кнопки: красная заливка и чуть крупнее; остальные — чёрные с белой рамкой
func on_select(k: int) -> void:
	var i := 0
	for b in btns:
		if b[1] == null:
			continue
		var sel := i == k
		(b[1] as Polygon2D).color = RED if sel else INK
		(b[2] as Line2D).default_color = WHITE if not sel else Color(1, 1, 1, 0.0)
		var l: Label = b[3]
		if i < hud.menu_rows.size():
			l.text = String(hud.menu_rows[i][2])
		l.add_theme_color_override("font_color", WHITE if sel else SILVER)
		(b[0] as Node2D).scale = Vector2.ONE * (1.06 if sel else 1.0)
		i += 1

## гонка закончилась для всех: таблица окончательная, у хоста сети появляется «ВСЕ В ЛОББИ»
func finalize() -> void:
	if final:
		return
	final = true
	rows_t = 0.0
	if dropped and String(race.cfg.get("mode", "single")) == "online":
		_buttons()

# ---------------- помощники ----------------
func _lab(parent: Node, s: String, sz: int, col: Color, pos: Vector2, f: Font = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f if f != null else hud.tech)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## въезд элемента со сдвига: резко, с лёгким перелётом
func _in(n: CanvasItem, from: Vector2, delay: float, dur := 0.24) -> void:
	var to: Vector2 = n.position
	n.position = to + from
	n.modulate.a = 0.0
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position", to, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 1.0, dur * 0.5).set_delay(delay)

## удар цифры места: влетает огромной и садится
func _punch(l: Label, delay: float) -> void:
	l.scale = Vector2(2.4, 2.4)
	l.modulate.a = 0.0
	l.rotation = deg_to_rad(-14.0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", deg_to_rad(-4.0), 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.08).set_delay(delay)

## победа: белые и красные осколки разлетаются от цифры
func _shards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 812
	for k in 26:
		var p := Polygon2D.new()
		var s := rng.randf_range(10.0, 26.0)
		p.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.4, s * 0.6), Vector2(-s * 0.5, s * 0.3)])
		p.color = WHITE if k % 3 != 0 else INK
		p.position = Vector2(330, 360)
		ui.add_child(p)
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(260.0, 720.0)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(cos(a), sin(a)) * d, rng.randf_range(0.6, 1.1)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", rng.randf_range(-6.0, 6.0), 1.1)
		tw.tween_property(p, "modulate:a", 0.0, 0.5).set_delay(rng.randf_range(0.5, 0.9))
		tw.chain().tween_callback(p.queue_free)
