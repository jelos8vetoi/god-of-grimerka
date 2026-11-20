extends Control

const Mods := preload("res://scripts/survival_modifiers.gd")
const WIDTH := 294.0
var game
var details: Label
var forecast: Label
var boosts: Label
var progress: ProgressBar
var fill: ColorRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, 194)
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -WIDTH - 20.0
	offset_right = -20.0
	offset_top = 18.0
	offset_bottom = 212.0
	var paper := Polygon2D.new()
	paper.color = Color(0.035, 0.036, 0.048, 0.9)
	paper.polygon = PackedVector2Array([Vector2(9, 0), Vector2(294, 4), Vector2(290, 38),
		Vector2(294, 183), Vector2(278, 194), Vector2(180, 190), Vector2(65, 194), Vector2(0, 187)])
	add_child(paper)
	var cut := Polygon2D.new()
	cut.color = Color(0.93, 0.93, 0.95)
	cut.polygon = PackedVector2Array([Vector2(9, 0), Vector2(294, 4), Vector2(287, 9), Vector2(11, 6)])
	add_child(cut)
	details = _line(Vector2(16, 17), 15, Color.WHITE)      # 18 не помещалось: «Боссы N» обрезалось краем плашки
	forecast = _line(Vector2(16, 70), 14, Color(1.0, 0.81, 0.5))
	progress = ProgressBar.new()
	progress.position = Vector2(16, 115)
	progress.size = Vector2(258, 5)
	progress.show_percentage = false
	progress.mouse_filter = MOUSE_FILTER_IGNORE
	progress.hide()            # значение читают проверки; рисуем свою тонкую полосу — стандартная ниже ~20 px не сжимается и ложилась на строку усилений
	add_child(progress)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.16)
	track.position = Vector2(16, 115)
	track.size = Vector2(258, 4)
	track.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(track)
	fill = ColorRect.new()
	fill.color = Color(1.0, 0.81, 0.5)
	fill.size = Vector2(0, 4)
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	track.add_child(fill)
	boosts = _line(Vector2(16, 126), 13, Color(0.84, 0.87, 0.91))

func _line(at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size.x = WIDTH - 30.0
	label.clip_text = true
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func refresh() -> void:
	var run = game.survival
	var director = run.director
	var view_width := get_viewport_rect().size.x
	game.boss_box.position.x = (view_width - game.boss_box.size.x) * 0.5
	game.toast_label.size.x = view_width
	details.text = "SURVIVAL   //   %s\nУгроза %d%% · Враги %d · Боссы %d" % [
		run.time_text(), roundi(director.threat * 100.0), game.kills, director.bosses_defeated]
	var remaining: float = maxf(0.0, run.next_draft - run.elapsed)
	var draft_text := "До усиления: %d с" % ceili(remaining) if is_finite(remaining) else "Усиления закончились"
	progress.value = 100.0 * (1.0 - clampf(remaining / run.draft_interval, 0.0, 1.0))
	fill.size.x = 258.0 * progress.value / 100.0
	forecast.text = "%s\n%s" % [director.forecast(game), draft_text]
	var names: Array[String] = []
	for id in run.mods.ranks:
		names.append("%s ×%d" % [Mods.CARDS[id][0], run.mods.rank(id)])
	if names.is_empty():
		boosts.text = "УСИЛЕНИЯ · —"
	else:
		var pages := ceili(names.size() / 2.0)
		var page := floori(run.elapsed / 4.0) % pages
		boosts.text = "УСИЛЕНИЯ · %d/%d\n%s" % [page + 1, pages, "\n".join(names.slice(page * 2, page * 2 + 2))]
