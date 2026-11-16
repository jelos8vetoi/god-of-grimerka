## Точка входа: управление, меню, запуск боя, звук. Ключ --autotest=папка — прогон без игрока со скриншотами.
extends Node

const ACTIONS := {
	"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"roll": [KEY_SPACE], "block": [KEY_SHIFT], "sprint": [KEY_CTRL], "adlib": [KEY_Q], "rage": [KEY_R],
	"pause": [KEY_ESCAPE], "fullscreen": [KEY_F11],
}

var game: Node
var menu: Control
var music: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cache := {}
var autotest := ""
var font: Font

func _ready() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in ACTIONS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in [["attack", MOUSE_BUTTON_LEFT], ["heavy", MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(a[0])
		var m := InputEventMouseButton.new()
		m.button_index = a[1]
		InputMap.action_add_event(a[0], m)
	font = load("res://assets/fonts/RussoOne-Regular.ttf")
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/music_dynasty.mp3")
	(music.stream as AudioStreamMP3).loop = true
	music.volume_db = -8.0
	add_child(music)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			autotest = arg.substr(11)
	if autotest != "":
		start_game()
	else:
		show_menu()

func sfx(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not sfx_cache.has(name):
		sfx_cache[name] = load("res://assets/audio/" + name + ".wav")
	for p in sfx_pool:
		if not p.playing:
			p.stream = sfx_cache[name]
			p.volume_db = vol
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	music.volume_db = -6.0
	if not music.playing:
		music.play()
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/winter-menu.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(-330, -260)
	box.size = Vector2(660, 520)
	menu.add_child(box)
	var title := label("GOD OF GRIMERKA", 72, Color("f3ead8"))
	title.add_theme_color_override("font_outline_color", Color(0.5, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	box.add_child(label("САГА О ПАХАНЕ, КЕНТЕ И ДЕВЯТИ СЕРВЕРАХ", 20, Color("e8c98f")))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)
	box.add_child(button("НОВАЯ ИГРА · ТОМСК", start_game))
	box.add_child(button("ВЫХОД", get_tree().quit))
	box.add_child(label("WASD — бег · мышь — камера · ЛКМ — удар балоном · ПКМ — тяжёлый · Пробел — перекат · Shift — блок · Q — ад-либ madk1d · R — ПЕРЕГРУЗ · F11 — полный экран", 15, Color("cfd6e4")))

func label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(420, 64)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.06, 0.75)
	sb.border_color = Color(0.85, 0.65, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	var hv := sb.duplicate()
	hv.bg_color = Color(0.75, 0.2, 0.12, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func(): sfx("sfx_ui"); cb.call())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

func start_game() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if game:
		game.queue_free()
	music.volume_db = -16.0
	if not music.playing:
		music.play()
	game = preload("res://scripts/game.gd").new()
	game.main = self
	add_child(game)
