extends CanvasLayer

signal picked(id: String)

const Mods := preload("res://scripts/survival_modifiers.gd")
const COLORS := [Color(0.9, 0.9, 0.9), Color(0.55, 0.82, 1), Color(0.86, 0.65, 1), Color(1, 0.8, 0.45)]
var choices: Array[String] = []
var picked_once := false
## Выбор открывается посреди боя: 1/2/3 — ещё и смена стиля, пробел — прыжок (и нажатие кнопки в фокусе), ЛКМ — удар,
## а курсор стоит в центре экрана, как раз на карточках. Первые LOCK мс нажатия не принимаются.
const LOCK := 600
var opened_ms := 0

func build(options: Array[String], mods) -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	choices = options
	opened_ms = GameClock.ms()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.025, 0.04, 0.92)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = minf(750.0, get_viewport().get_visible_rect().size.x * 0.86)
	center.add_child(box)
	var title := Label.new()
	title.text = "УСИЛЕНИЕ ЗАБЕГА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var first: Button
	for i in choices.size():
		var id := choices[i]
		var card: Array = Mods.CARDS[id]
		var strip := VBoxContainer.new()
		box.add_child(strip)
		var slash := Polygon2D.new()
		slash.color = COLORS[card[2]]
		strip.add_child(slash)
		strip.resized.connect(func():
			var w := strip.size.x
			slash.polygon = PackedVector2Array([Vector2(5, 0), Vector2(w - 3, 2), Vector2(w - 11, 5), Vector2(0, 3)]))
		var button := Button.new()
		button.text = "%d  ·  %s  ·  %s  ·  %d/%d" % [i + 1, card[0], Mods.RARITIES[card[2]], mods.rank(id) + 1, card[3]]
		button.add_theme_color_override("font_color", COLORS[card[2]])
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size.y = 43
		strip.add_child(button)
		button.pressed.connect(_pick.bind(id))
		if i == 0:
			first = button
		var description := Label.new()
		description.text = card[1]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strip.add_child(description)
		strip.modulate.a = 0.0
		# Выбор открывается посреди боя, когда игра может стоять в стоп-кадре (time_scale 0,05) или замедлении:
		# без этого карточки проявлялись по нескольку секунд.
		create_tween().set_ignore_time_scale(true).tween_property(strip, "modulate:a", 1.0, 0.18).set_delay(i * 0.04)
	var hint := Label.new()
	hint.text = "Выбери одно усиление  ·  1 / 2 / 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	first.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot: int = event.physical_keycode - KEY_1
		if slot >= 0 and slot < choices.size():
			get_viewport().set_input_as_handled()
			_pick(choices[slot])

func _pick(id: String) -> void:
	if GameClock.ms() - opened_ms < LOCK:
		return
	if not picked_once:
		picked_once = true
		picked.emit(id)
