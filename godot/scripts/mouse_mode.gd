## Режим мыши в одном месте. Игра решает, хочет ли она захватить курсор (want), а тихий режим проверок (quiet)
## не даёт по-настоящему забрать мышь у человека за компьютером: автопроверки (--*check, --autotest, --smoke…)
## идут в окне без фокуса, курсор остаётся свободным. Логика игры при этом та же — проверки сверяют want.
class_name MouseMode

static var quiet := false
static var want: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

static func set_to(m: Input.MouseMode) -> void:
	want = m
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if quiet else m

static func captured() -> bool:
	return want == Input.MOUSE_MODE_CAPTURED

## Тихий режим: окно проверки не забирает фокус и стоит в правом нижнем углу экрана
static func make_quiet(w: Window) -> void:
	quiet = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	w.set_flag(Window.FLAG_NO_FOCUS, true)
	var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.position = scr.position + scr.size - w.size - Vector2i(8, 8)
