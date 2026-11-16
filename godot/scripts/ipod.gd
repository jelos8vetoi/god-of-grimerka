## iPod: компактный 2D-оверлей в духе классического iPod.
## На первом этапе отвечает за внешний вид, меню, ввод и безопасное открытие поверх игры.
extends CanvasLayer

const ID3 = preload("res://scripts/id3.gd")
const DEVICE_SIZE := Vector2(204, 341)
const SLIDE_TIME := 0.48
const CLOSE_TIME := 0.36
const OVERLAY_ALPHA := 0.10
const SCREEN_RECT := Rect2(19, 19, 167, 125)
const WHEEL_RECT := Rect2(39, 178, 127, 127)
const SETTINGS_PATH := "user://grimerka_ipod.json"
const USER_MUSIC_DIR := "user://ipod_music"
enum RepeatMode { OFF, ONE, ALL }
enum UIMotionMode { OFF, REDUCED, FULL }
const BLOCKED_GAME_ACTIONS := [
	&"up", &"down", &"left", &"right", &"roll", &"attack", &"heavy",
	&"block", &"sprint", &"adlib", &"rage", &"heat", &"pause",
]
const BUILTIN_TRACKS := [
	{"id": "dynasty", "title": "Dynasty", "artist": "GOD OF GRIMERKA", "path": "res://assets/audio/music_dynasty.mp3", "local": false},
]
const PAGES := {
	"Menu": ["Музыка", "Плейлисты", "Сейчас играет", "Настройки"],
	"Музыка": ["Встроенная музыка"],
	"Плейлисты": ["Все треки", "Встроенная музыка", "Моя музыка"],
	"Настройки": ["Воспроизведение", "Звук"],
	"Воспроизведение": ["Repeat"],
	"Звук": ["Громкость", "Reverb Depth", "Bass Boost", "Звуки кнопок", "Анимации UI"],
}

var game
var opened := false
var page := "Menu"
var selected := 0
var page_history: Array[String] = []
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var input_captured := false
var release_guard := false
var slide: Tween
var accent_tween: Tween
var emerge := 1.0   # 0 — интерфейс ещё «в руке» героя (маленький, на месте 3D-устройства), 1 — на своём месте
var focus_amount := 0.0
var motion_amount := 0.0
var player: AudioStreamPlayer
var file_dialog: FileDialog
var tracks: Array[Dictionary] = []
var track_index := -1
var volume := 0.7
var reverb_depth := 0.6
var bass_boost := 0.0
var repeat_mode := RepeatMode.OFF
var button_sounds_enabled := true
var button_sounds_volume := 0.55
var ui_motion_mode := UIMotionMode.FULL
var earbuds_in := false    # EarPods в ушах Пахана: закрытие iPod их не снимает, сохраняется вместе с настройками
var save_clock := 0.0
var mix_volume := 0.0
var mix_reverb := 0.0
var mix_bass := 0.0
var reverb: AudioEffectReverb
var lowpass: AudioEffectLowPassFilter
var bass_eq: AudioEffectEQ6
var limiter: AudioEffectHardLimiter
var ui_players: Array[AudioStreamPlayer] = []
var ui_streams: Dictionary = {}
var ui_player_cursor := 0
var last_ui_sound_ms := -1000
var overlay: ColorRect

var root: Control
var device: Panel
var screen: Panel
var display_root: Control
var page_label: Label
var state_label: Label
var content: VBoxContainer
var title_label: Label
var artist_label: Label
var count_label: Label
var progress: ProgressBar
var time_label: Label
var total_label: Label
var row_labels: Array[Label] = []
var selection_bar: Panel
var center_button: Button
var wheel_buttons: Array[Button] = []
var wheel_button_by_action: Dictionary = {}
var wheel_feedback_by_action: Dictionary = {}
var wheel_tweens: Dictionary = {}
var menu_art: Panel
var menu_art_texture: TextureRect
var menu_art_note: Label
var cover_texture: TextureRect
var cover_previous_texture: TextureRect
var cover_note: Label
var cover_key := "__unset__"
var cover_cache: Dictionary = {}
var hint_panel: Panel
var hint_shown := false
var hint_time := 0.0
var composition_target := Vector2.ZERO
var composition_ready := false
var composition_check_clock := 0.0
var persistence_enabled := true
var displayed_page := ""
var page_transition_direction := 0
var page_selection: Dictionary = {}
var screen_tween: Tween
var highlight_tween: Tween
var cover_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 18
	_build_ui()
	_setup_audio()
	_setup_ui_audio()
	if persistence_enabled:
		_load_settings()
	else:
		tracks.clear()
		for builtin in BUILTIN_TRACKS:
			tracks.append((builtin as Dictionary).duplicate(true))
	_build_file_dialog()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()
	set_process(true)


func _process(dt: float) -> void:
	if release_guard and not _conflicting_input_is_pressed():
		release_guard = false
	# удар по герою или гибель: iPod убирается сам
	if opened and game != null and game.player != null and game.player.state in ["hurt", "dead"]:
		close()
	var pause_factor := 0.3 if get_tree().paused else 1.0
	var dialogue_factor := 0.42 if game != null and game.mode == "dlg" else 1.0
	var focus_factor := 0.8 if opened else 1.0
	var wanted_volume := volume * pause_factor * dialogue_factor * focus_factor
	mix_volume = lerpf(mix_volume, wanted_volume, 1.0 - exp(-5.0 * dt))
	mix_bass = lerpf(mix_bass, bass_boost, 1.0 - exp(-7.0 * dt))
	_apply_bass_boost(mix_bass)
	# The EQ reaches +6 dB at 100 Hz. A small broadband trim preserves headroom;
	# the final limiter catches combined EQ/reverb peaks without touching Master.
	player.volume_linear = mix_volume * db_to_linear(-2.5 * mix_bass)
	var wanted_reverb := reverb_depth if opened else 0.0
	mix_reverb = lerpf(mix_reverb, wanted_reverb, 1.0 - exp(-4.5 * dt))
	reverb.wet = mix_reverb * 0.46
	reverb.dry = 1.0 - mix_reverb * 0.2
	reverb.room_size = 0.48 + mix_reverb * 0.3
	reverb.damping = 0.72 - mix_reverb * 0.12
	lowpass.cutoff_hz = lerpf(21000.0, 9400.0, mix_reverb)
	overlay.color.a = OVERLAY_ALPHA * focus_amount
	screen.modulate = Color(1.0 + 0.12 * focus_amount, 1.0 + 0.14 * focus_amount, 1.0 + 0.17 * focus_amount, 1.0)
	if game != null and game.has_method("set_ipod_visual_focus"):
		var pod = _pod()
		var follow := 1.0 if pod == null else 0.3 + 0.7 * smoothstep(0.3, 1.0, float(pod.u))
		game.set_ipod_visual_focus(focus_amount * follow, motion_amount, _focus_point_normalized())
	if game != null and game.main != null and game.main.audio != null:
		game.main.audio.ipod_focus_target = 1.0 if opened else 0.0
	# Re-evaluate composition at a low rate and only accept meaningful camera changes.
	# Fixed body bounds ignore pose animation, so the UI never chases hands or idle motion.
	if device.visible and emerge < 1.0:
		_place_emerging()
	elif opened and device.visible and (not is_instance_valid(slide) or not slide.is_running()):
		composition_check_clock += dt
		if composition_check_clock >= 0.2:
			composition_check_clock = 0.0
			var candidate := _calculate_open_position()
			if not composition_ready or composition_target.distance_to(candidate) >= 32.0:
				composition_target = candidate
				composition_ready = true
		device.position = device.position.lerp(composition_target, 1.0 - exp(-5.0 * dt))
	if player.playing and not player.stream_paused:
		save_clock += dt
		if save_clock >= 5.0:
			save_clock = 0.0
			_save_settings()
	if hint_panel != null and hint_panel.visible:
		hint_time = maxf(0.0, hint_time - dt)
		hint_panel.modulate.a = clampf(hint_time / 1.2, 0.0, 1.0)
		if hint_time <= 0.0:
			hint_panel.visible = false
	_refresh_playback(dt)


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ipod") and not e.is_echo():
		if _can_toggle():
			toggle()
			get_viewport().set_input_as_handled()
		return
	if not opened:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-1)
			_hint_used()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(1)
			_hint_used()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_activate_wheel_action("menu", _back, false)
			_hint_used()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT and screen.get_global_rect().has_point(e.position):
			if _select_screen_row(e.position):
				_play_ui_sound("select")
			_hint_used()
			get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed:
		if e.echo and e.physical_keycode not in [KEY_W, KEY_S, KEY_DOWN]:
			return
		match e.physical_keycode:
			KEY_ENTER:
				_activate_wheel_action("select", _select)
			KEY_W:
				_scroll(-1)
			KEY_S, KEY_DOWN:
				_scroll(1)
			KEY_A, KEY_LEFT:
				_activate_wheel_action("previous", _prev)
			KEY_D, KEY_RIGHT:
				_activate_wheel_action("next", _next)
			KEY_SPACE:
				_activate_wheel_action("play", _play)
			KEY_ESCAPE, KEY_BACKSPACE:
				_activate_wheel_action("menu", _back)
			_:
				return
		_hint_used()
		get_viewport().set_input_as_handled()


## Физический iPod в руке героя (scripts/pod.gd); null, если героя ещё нет.
func _pod():
	if game == null:
		return null
	var p = game.get("player")
	if p == null or not is_instance_valid(p):
		return null
	return p.get("pod")


## Где на экране сейчас дисплей устройства в руке героя; null — если руки не видно.
func _hand_point():
	var pod = _pod()
	var camera := get_viewport().get_camera_3d()
	if pod == null or camera == null or not pod.device.visible:
		return null
	var world: Vector3 = pod.screen_world()
	if camera.is_position_behind(world):
		return null
	return camera.unproject_position(world)


## Интерфейс вырастает из устройства в руке и уходит в него обратно: так видно, что это один и тот же iPod.
func _place_emerging() -> void:
	var k := emerge * emerge * (3.0 - 2.0 * emerge)
	var base := _base_scale()
	var hand = _hand_point()
	if hand == null:
		device.scale = base * lerpf(0.92, 1.0, k)
		device.position = _closed_position().lerp(_open_position(), k)
		device.modulate.a = 1.0 if _pod() == null else clampf(emerge * 3.0, 0.0, 1.0)
		return
	var small := base * 0.09
	device.scale = small.lerp(base, k)
	# точка поворота панели — её правый нижний угол; ставим так, чтобы центр экрана интерфейса лёг на дисплей в руке
	var centre := SCREEN_RECT.get_center()
	var from: Vector2 = (hand as Vector2) - DEVICE_SIZE - (centre - DEVICE_SIZE) * small
	device.position = from.lerp(_open_position(), k)
	device.modulate.a = clampf(emerge * 3.0, 0.0, 1.0)


func _can_toggle() -> bool:
	if game == null or game.over:
		return false
	if opened:
		return true
	return not get_tree().paused and not game.paused_story()


func toggle() -> void:
	if opened:
		close()
	else:
		open()


func open() -> void:
	if opened:
		return
	# A reopen during the closing tween continues the same input context. Do not
	# replace the saved captured-mouse mode with the temporary visible mode.
	var continuing_context := input_captured
	opened = true
	input_captured = true
	release_guard = false
	if not continuing_context:
		previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var was_visible := device.visible
	device.visible = true
	device.mouse_filter = Control.MOUSE_FILTER_STOP
	composition_target = _calculate_open_position()
	composition_ready = true
	composition_check_clock = 0.0
	if not hint_shown:
		hint_shown = true
		hint_time = 7.0
		hint_panel.modulate.a = 1.0
		hint_panel.visible = true
	if not was_visible:
		emerge = 0.0
		_place_emerging()
	_start_focus_animation(true)
	center_button.grab_focus()
	_refresh()


func close(fast := false) -> void:
	if not opened and not fast:
		return
	opened = false
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_release_all_wheel_buttons(fast)
	if fast:
		_kill_visual_tweens()
		focus_amount = 0.0
		motion_amount = 0.0
		device.position = _closed_position()
		device.scale = _base_scale()
		device.modulate.a = 1.0
		emerge = 1.0
		device.visible = false
		input_captured = false
		release_guard = false
		_stop_ui_sounds()
		_reset_screen_motion()
		if game != null and game.has_method("set_ipod_visual_focus"):
			game.set_ipod_visual_focus(0.0, 0.0)
		_restore_mouse()
		return
	_start_focus_animation(false)
	_save_settings()


func _restore_mouse() -> void:
	if get_tree().paused or game.panel != null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = previous_mouse_mode


func captures_gameplay_input() -> bool:
	# пока герой убирает iPod в карман, левая рука занята: удары и бег ждут
	var pod = _pod()
	return input_captured or release_guard or (pod != null and pod.busy())


func _finish_input_context() -> void:
	input_captured = false
	release_guard = _conflicting_input_is_pressed()


func _conflicting_input_is_pressed() -> bool:
	for action in BLOCKED_GAME_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and input_captured:
		release_guard = true
		_release_all_wheel_buttons(true)
		_stop_ui_sounds()
		_reset_screen_motion()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and opened:
		# Some desktop window managers change the cursor mode while focus is away.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_visual_tweens() -> void:
	if is_instance_valid(slide):
		slide.kill()
	if is_instance_valid(accent_tween):
		accent_tween.kill()


func _start_focus_animation(opening: bool) -> void:
	_kill_visual_tweens()
	var duration := SLIDE_TIME if opening else CLOSE_TIME
	var base_scale := _base_scale()
	slide = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide.set_parallel(true)
	slide.tween_property(self, "focus_amount", 1.0 if opening else 0.0, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN_OUT)
	# панель интерфейса появляется, когда рука уже подняла iPod, и вырастает из него (см. _place_emerging);
	# при закрытии уходит обратно в руку, и только потом герой убирает устройство в карман
	var pod = _pod()
	var device_delay := 0.0
	if opening:
		device_delay = 0.10 if pod == null else 0.8 * (1.0 - float(pod.u)) * float(pod.open_time())
	slide.tween_property(self, "emerge", 1.0 if opening else 0.0, 0.42 if opening else duration).set_delay(device_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	if not opening:
		slide.tween_callback(func():
			device.visible = false
			device.scale = _base_scale()
			device.modulate.a = 1.0
			emerge = 1.0
			_stop_ui_sounds()
			_reset_screen_motion()
			_finish_input_context()
			_restore_mouse()).set_delay(duration)
	accent_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	accent_tween.tween_property(self, "motion_amount", 0.34 if opening else 0.16, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	accent_tween.tween_property(self, "motion_amount", 0.0, 0.26 if opening else 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _layout() -> void:
	if device == null:
		return
	device.scale = _base_scale()
	device.pivot_offset = DEVICE_SIZE
	composition_target = _calculate_open_position()
	composition_ready = true
	if device.visible and emerge < 1.0:
		_place_emerging()
		return
	device.position = _open_position() if opened else _closed_position()


func _base_scale() -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	var scale_k: float = clamp(min(viewport.x / 1600.0, viewport.y / 900.0), 0.82, 1.35) * 1.25
	return Vector2.ONE * scale_k


func _open_position() -> Vector2:
	if not composition_ready:
		composition_target = _calculate_open_position()
		composition_ready = true
	return composition_target


func _calculate_open_position() -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	var scaled := DEVICE_SIZE * _base_scale()
	var protected := _pahan_protected_rect(viewport)
	var safe_margin := clampf(viewport.x * 0.025, 24.0, 64.0)
	var scale := _base_scale()
	# The hint is a child above/right of the body, so reserve room for it as well.
	var minimum := Vector2(safe_margin, safe_margin + 57.0 * scale.y)
	var maximum := Vector2(viewport.x - safe_margin - scaled.x - 44.0 * scale.x,
		viewport.y - safe_margin - scaled.y)
	var gap := clampf(50.0 * viewport.x / 1600.0, 36.0, 75.0)
	var protected_end := protected.position + protected.size
	var shoulder_y := protected.position.y + protected.size.y * 0.16
	var right_x := protected_end.x + gap
	var stable_right_x := maximum.x
	var candidates: Array[Vector2] = [
		Vector2(right_x, shoulder_y),
		Vector2(stable_right_x, shoulder_y),
		Vector2(stable_right_x, protected.position.y - scaled.y - gap),
		Vector2(stable_right_x, protected_end.y + gap),
		Vector2(protected.position.x - gap - scaled.x, shoulder_y),
	]
	for raw in candidates:
		var candidate := Vector2(clampf(raw.x, minimum.x, maximum.x), clampf(raw.y, minimum.y, maximum.y))
		var ipod_rect := Rect2(candidate, scaled)
		if _inside_safe_area(candidate, scaled, minimum, maximum) and not ipod_rect.intersects(protected):
			return candidate
	# Expected game compositions always fit one candidate. This final corner is stable;
	# choose the one with the smallest overlap if an unusual camera makes separation impossible.
	var corners: Array[Vector2] = [minimum, Vector2(maximum.x, minimum.y), Vector2(minimum.x, maximum.y), maximum]
	var best := Vector2(maximum.x, minimum.y)
	var best_overlap := INF
	for corner in corners:
		var overlap := Rect2(corner, scaled).intersection(protected).get_area()
		if overlap < best_overlap:
			best_overlap = overlap
			best = corner
	return best


func _inside_safe_area(position: Vector2, _size: Vector2, minimum: Vector2, maximum: Vector2) -> bool:
	return position.x >= minimum.x and position.y >= minimum.y and position.x <= maximum.x and position.y <= maximum.y


func _pahan_protected_rect(viewport: Vector2) -> Rect2:
	var fallback := Rect2(viewport.x * 0.39, viewport.y * 0.23, viewport.x * 0.18, viewport.y * 0.58)
	if game == null:
		return fallback
	var subject = game.get("player")
	var camera := get_viewport().get_camera_3d()
	if not (subject is Node3D) or camera == null:
		return fallback
	var subject_node := subject as Node3D
	var camera_right := camera.global_transform.basis.x.normalized()
	var points: Array[Vector3] = []
	for height in [-0.05, 0.85, 1.95]:
		for side in [-0.72, 0.72]:
			points.append(subject_node.global_position + Vector3.UP * height + camera_right * side)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		if camera.is_position_behind(point):
			return fallback
		var projected := camera.unproject_position(point)
		if not is_finite(projected.x) or not is_finite(projected.y):
			return fallback
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	var padding := clampf(viewport.x * 0.012, 12.0, 28.0)
	return Rect2(minimum, maximum - minimum).grow(padding)


func _closed_position() -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	return Vector2(_open_position().x, viewport.y + 34)


func _focus_point_normalized() -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return Vector2(0.74, 0.58)
	var centre := _open_position() + DEVICE_SIZE * _base_scale() * 0.5
	return Vector2(centre.x / viewport.x, centre.y / viewport.y)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.035, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	device = Panel.new()
	device.size = DEVICE_SIZE
	device.visible = false
	device.clip_contents = false
	device.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, 18, Color.TRANSPARENT, 0, Color(0, 0, 0, 0.42), 16))
	root.add_child(device)
	var body := TextureRect.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.texture = _make_body_texture()
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_SCALE
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(body)
	hint_panel = Panel.new()
	hint_panel.position = Vector2(0, -57)
	hint_panel.size = Vector2(248, 47)
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	hint_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.035, 0.05, 0.88), 8,
		Color(0.48, 0.68, 0.82, 0.28), 1, Color(0, 0, 0, 0.28), 6))
	device.add_child(hint_panel)
	var hint_label := _label("W/S  меню  ·  Enter  выбрать  ·  Esc  назад\nA/D  трек  ·  Space  пауза  ·  ↑  убрать", 8, Color("e4eef4"), true)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("line_spacing", 2)
	hint_panel.add_child(hint_label)

	screen = Panel.new()
	screen.position = SCREEN_RECT.position
	screen.size = SCREEN_RECT.size
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.clip_contents = true
	screen.add_theme_stylebox_override("panel", _style(Color("dbe9e4"), 3, Color("a9bbb6"), 1, Color(0.28, 0.88, 0.78, 0.28), 8))
	device.add_child(screen)

	var lcd_glow := _gradient_rect(Vector2(1, 1), screen.size - Vector2(2, 2),
		[Color("eef9f3"), Color("d6e8e2"), Color("c8ded9")], [0.0, 0.58, 1.0])
	lcd_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(lcd_glow)
	var scan := ColorRect.new()
	scan.position = Vector2(0, 19)
	scan.size = Vector2(SCREEN_RECT.size.x, 1)
	scan.color = Color(0.34, 0.45, 0.46, 0.3)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(scan)

	page_label = _label("iPod", 12, Color("142027"), true)
	page_label.position = Vector2(6, 1)
	page_label.size = Vector2(132, 17)
	screen.add_child(page_label)
	state_label = _label("", 12, Color("142027"), true)
	state_label.position = Vector2(143, 1)
	state_label.size = Vector2(22, 17)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(state_label)

	display_root = Control.new()
	display_root.position = Vector2.ZERO
	display_root.size = screen.size
	display_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(display_root)
	selection_bar = Panel.new()
	selection_bar.position = Vector2(3, 22)
	selection_bar.size = Vector2(161, 25)
	selection_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_bar.add_theme_stylebox_override("panel", _style(Color("2f82c5"), 0, Color("246da6"), 1))
	display_root.add_child(selection_bar)

	content = VBoxContainer.new()
	content.position = Vector2(3, 22)
	content.size = Vector2(168, 106)
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_root.add_child(content)
	for i in 4:
		var row_bg := PanelContainer.new()
		row_bg.custom_minimum_size = Vector2(0, 25)
		row_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		row_bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row_bg.mouse_entered.connect(_hover_row.bind(i))
		content.add_child(row_bg)
		var row := _label("", 12, Color("17232a"), i == 0)
		row.custom_minimum_size = Vector2(0, 25)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_theme_constant_override("line_spacing", 0)
		row_labels.append(row)
		row_bg.add_child(row)

	# На главном экране Classic справа от меню находится крупная обложка.
	menu_art = Panel.new()
	menu_art.position = Vector2(83, 22)
	menu_art.size = Vector2(84, 100)
	menu_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_art.clip_contents = true
	menu_art.add_theme_stylebox_override("panel", _style(Color("20252a"), 1, Color("7a858a"), 1))
	display_root.add_child(menu_art)
	menu_art_texture = TextureRect.new()
	menu_art_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	menu_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_art.add_child(menu_art_texture)
	menu_art_note = _make_note_label(31)
	menu_art.add_child(menu_art_note)

	_build_now_playing()
	_build_wheel()


func _setup_audio() -> void:
	var bus := AudioServer.get_bus_index("IPod")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "IPod")
		AudioServer.set_bus_send(bus, "Master")
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 21000.0
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.65
	reverb.damping = 0.52
	reverb.spread = 0.82
	reverb.hipass = 0.08
	reverb.dry = 1.0
	reverb.wet = 0.0
	bass_eq = AudioEffectEQ6.new()
	limiter = AudioEffectHardLimiter.new()
	limiter.pre_gain_db = 0.0
	limiter.ceiling_db = -1.0
	limiter.release = 0.12
	while AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.remove_bus_effect(bus, 0)
	AudioServer.add_bus_effect(bus, lowpass)
	AudioServer.add_bus_effect(bus, bass_eq)
	AudioServer.add_bus_effect(bus, reverb)
	AudioServer.add_bus_effect(bus, limiter)
	_apply_bass_boost(0.0)
	player = AudioStreamPlayer.new()
	player.bus = "IPod"
	player.volume_linear = 0.0
	player.finished.connect(_on_track_finished)
	add_child(player)


func _setup_ui_audio() -> void:
	# Button clicks follow the game's SFX setting and never enter the processed IPod bus.
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var sfx_bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus, "SFX")
		AudioServer.set_bus_send(sfx_bus, "Master")
	ui_streams = {
		"navigate": _synth_click(18.0, 620.0, 0.17, false),
		"select": _synth_click(42.0, 360.0, 0.22, false),
		"menu": _synth_click(28.0, 450.0, 0.18, false),
		"track_previous": _synth_click(46.0, 500.0, 0.17, true),
		"track_next": _synth_click(46.0, 570.0, 0.17, true),
		"play": _synth_click(35.0, 390.0, 0.20, false),
	}
	for i in 3:
		var ui_player := AudioStreamPlayer.new()
		ui_player.bus = "SFX"
		ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ui_player)
		ui_players.append(ui_player)


func _synth_click(duration_ms: float, frequency: float, amplitude: float, double_tap: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	stream.stereo = false
	var frame_count := maxi(1, roundi(duration_ms * 0.001 * stream.mix_rate))
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / float(stream.mix_rate)
		var attack := 1.0 - exp(-t * 720.0)
		var envelope := attack * exp(-t * 105.0)
		if double_tap and t >= 0.015:
			var second_t := t - 0.015
			envelope += (1.0 - exp(-second_t * 760.0)) * exp(-second_t * 125.0) * 0.72
		var body := sin(TAU * frequency * t) + sin(TAU * frequency * 0.52 * t) * 0.28
		var sample := clampi(roundi(body * envelope * amplitude * 32767.0), -32768, 32767)
		bytes.encode_s16(frame * 2, sample)
	stream.data = bytes
	return stream


func _play_ui_sound(kind: String) -> bool:
	if not button_sounds_enabled or button_sounds_volume <= 0.001 or not ui_streams.has(kind):
		return false
	var now := Time.get_ticks_msec()
	var minimum_gap := 28 if kind == "navigate" else 34
	if now - last_ui_sound_ms < minimum_gap:
		return false
	var chosen: AudioStreamPlayer
	for offset in ui_players.size():
		var candidate := ui_players[(ui_player_cursor + offset) % ui_players.size()]
		if not candidate.playing:
			chosen = candidate
			ui_player_cursor = (ui_player_cursor + offset + 1) % ui_players.size()
			break
	if chosen == null:
		return false
	last_ui_sound_ms = now
	chosen.stream = ui_streams[kind]
	chosen.volume_linear = button_sounds_volume * 0.32
	chosen.pitch_scale = randf_range(0.99, 1.01)
	chosen.play()
	return true


func _stop_ui_sounds() -> void:
	for ui_player in ui_players:
		ui_player.stop()


func _build_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.title = "Добавить музыку в iPod"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.mp3 ; MP3", "*.ogg ; Ogg Vorbis", "*.wav ; WAV"])
	file_dialog.files_selected.connect(_import_files)
	add_child(file_dialog)


func _load_settings() -> void:
	tracks.clear()
	for builtin in BUILTIN_TRACKS:
		tracks.append((builtin as Dictionary).duplicate(true))
	var resume_id := ""
	var resume_time := 0.0
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			_apply_persisted_options(parsed)
			resume_id = String(parsed.get("track_id", ""))
			resume_time = maxf(0.0, float(parsed.get("time", 0.0)))
			var saved_tracks: Array = parsed.get("tracks", [])
			for item in saved_tracks:
				if item is Dictionary:
					var path := String(item.get("path", ""))
					if path.begins_with("user://") and FileAccess.file_exists(path):
						var saved_cover := String(item.get("cover", ""))
						if saved_cover != "" and not FileAccess.file_exists(saved_cover):
							saved_cover = ""
						tracks.append({"id": String(item.get("id", path)), "title": String(item.get("title", path.get_file().get_basename())),
							"artist": String(item.get("artist", "Моя музыка")), "album": String(item.get("album", "")),
							"cover": saved_cover, "path": path, "local": true})
	if resume_id != "":
		for i in tracks.size():
			if String(tracks[i]["id"]) == resume_id:
				_select_track(i, false, resume_time)
				break


func _save_settings() -> void:
	if player == null or not persistence_enabled:
		return
	var local_tracks: Array = []
	for track in tracks:
		if bool(track.get("local", false)):
			local_tracks.append(track)
	var data := _settings_payload(local_tracks)
	var temp := SETTINGS_PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(SETTINGS_PATH))


func _settings_payload(local_tracks: Array) -> Dictionary:
	return {"version": 3, "volume": volume, "reverb_depth": reverb_depth,
		"bass_boost": bass_boost, "repeat_mode": repeat_mode,
		"button_sounds_enabled": button_sounds_enabled, "button_sounds_volume": button_sounds_volume,
		"ui_motion_mode": ui_motion_mode, "earbuds_in": earbuds_in, "tracks": local_tracks,
		"track_id": String(tracks[track_index]["id"]) if track_index >= 0 and track_index < tracks.size() else "",
		"time": player.get_playback_position() if player.stream != null else 0.0}


func _apply_persisted_options(data: Dictionary) -> void:
	volume = clampf(float(data.get("volume", volume)), 0.0, 1.0)
	reverb_depth = clampf(float(data.get("reverb_depth", reverb_depth)), 0.0, 1.0)
	# Explicit defaults keep version-1 settings compatible.
	bass_boost = clampf(float(data.get("bass_boost", 0.0)), 0.0, 1.0)
	repeat_mode = clampi(int(data.get("repeat_mode", RepeatMode.OFF)), RepeatMode.OFF, RepeatMode.ALL)
	button_sounds_enabled = bool(data.get("button_sounds_enabled", true))
	button_sounds_volume = clampf(float(data.get("button_sounds_volume", 0.55)), 0.0, 1.0)
	ui_motion_mode = clampi(int(data.get("ui_motion_mode", UIMotionMode.FULL)), UIMotionMode.OFF, UIMotionMode.FULL)
	earbuds_in = bool(data.get("earbuds_in", false))
	mix_bass = bass_boost
	_apply_bass_boost(mix_bass)


func _apply_bass_boost(amount: float) -> void:
	if bass_eq == null:
		return
	var strength := clampf(amount, 0.0, 1.0)
	# EQ6 bands are centred at 32, 100, 320, 1k, 3.2k and 10k Hz.
	# The restrained 320 Hz shoulder avoids a hollow jump above the bass range.
	var gains := [4.0 * strength, 6.0 * strength, 0.75 * strength, 0.0, 0.0, 0.0]
	for band in mini(bass_eq.get_band_count(), gains.size()):
		bass_eq.set_band_gain_db(band, gains[band])


func _stream_from_path(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path)
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


func _select_track(index: int, play_now := true, from_time := 0.0) -> void:
	if index < 0 or index >= tracks.size():
		return
	var stream := _stream_from_path(String(tracks[index]["path"]))
	if stream == null:
		game.toast("Не удалось прочитать аудиофайл")
		return
	track_index = index
	player.stream = stream
	player.play(maxf(0.0, from_time))
	player.stream_paused = not play_now
	_go_to_page("Сейчас играет")
	selected = 0
	_refresh()
	_save_settings()


func _import_files(paths: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_MUSIC_DIR))
	var added := 0
	for source in paths:
		var ext := source.get_extension().to_lower()
		if ext not in ["mp3", "ogg", "wav"]:
			continue
		var id := "%d_%d" % [Time.get_unix_time_from_system(), randi()]
		var destination := USER_MUSIC_DIR.path_join(id + "." + ext)
		var input := FileAccess.open(source, FileAccess.READ)
		if input == null:
			continue
		var bytes := input.get_buffer(input.get_length())
		input.close()
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if output == null:
			continue
		output.store_buffer(bytes)
		output.close()
		var metadata: Dictionary = ID3.read(destination) if ext == "mp3" else {}
		var cover_path := ""
		var cover_bytes: PackedByteArray = metadata.get("cover_bytes", PackedByteArray())
		var cover_ext := String(metadata.get("cover_ext", ""))
		if not cover_bytes.is_empty() and cover_ext in ["jpg", "png"]:
			cover_path = USER_MUSIC_DIR.path_join(id + "_cover." + cover_ext)
			var cover_file := FileAccess.open(cover_path, FileAccess.WRITE)
			if cover_file != null:
				cover_file.store_buffer(cover_bytes)
				cover_file.close()
			else:
				cover_path = ""
		var metadata_title := String(metadata.get("title", "")).strip_edges()
		var metadata_artist := String(metadata.get("artist", "")).strip_edges()
		tracks.append({"id": id,
			"title": metadata_title if metadata_title != "" else source.get_file().get_basename(),
			"artist": metadata_artist if metadata_artist != "" else "Моя музыка",
			"album": String(metadata.get("album", "")).strip_edges(), "cover": cover_path,
			"path": destination, "local": true})
		added += 1
	_save_settings()
	if added > 0:
		game.toast("Добавлено треков: %d" % added)
		_select_track(tracks.size() - added)
	else:
		game.toast("Не удалось добавить музыку")


func _remove_current() -> void:
	if track_index < 0 or track_index >= tracks.size() or not bool(tracks[track_index].get("local", false)):
		return
	player.stop()
	var path := String(tracks[track_index]["path"])
	var cover_path := String(tracks[track_index].get("cover", ""))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if cover_path != "" and not _cover_used_elsewhere(cover_path, track_index):
		cover_cache.erase(cover_path)
		if FileAccess.file_exists(cover_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cover_path))
	tracks.remove_at(track_index)
	track_index = -1
	player.stream = null
	page = "Музыка"
	page_history = ["Menu"]
	selected = 0
	_save_settings()
	_refresh()


func _on_track_finished() -> void:
	var next_index := _finished_track_index()
	if next_index >= 0:
		_select_track(next_index)
	else:
		player.stop()
		player.stream_paused = false
		_save_settings()
		_refresh_playback()


func _finished_track_index() -> int:
	if tracks.is_empty() or track_index < 0 or track_index >= tracks.size():
		return -1
	if repeat_mode == RepeatMode.ONE:
		return track_index
	var next_index := track_index + 1
	if next_index < tracks.size():
		return next_index
	return 0 if repeat_mode == RepeatMode.ALL else -1


func _build_now_playing() -> void:
	var cover := Panel.new()
	cover.name = "Cover"
	cover.position = Vector2(7, 27)
	cover.size = Vector2(55, 55)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.clip_contents = true
	cover.add_theme_stylebox_override("panel", _style(Color("20232a"), 2, Color("7f8589"), 1))
	display_root.add_child(cover)
	cover_previous_texture = TextureRect.new()
	cover_previous_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	cover_previous_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_previous_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_previous_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_previous_texture.visible = false
	cover.add_child(cover_previous_texture)
	cover_texture = TextureRect.new()
	cover_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	cover_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(cover_texture)
	cover_note = _make_note_label(25)
	cover.add_child(cover_note)
	title_label = _label("Нет выбранного трека", 10, Color("17232a"), true)
	title_label.position = Vector2(69, 26)
	title_label.size = Vector2(98, 31)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_root.add_child(title_label)
	artist_label = _label("", 10, Color("435a60"))
	artist_label.position = Vector2(69, 58)
	artist_label.size = Vector2(98, 15)
	artist_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_root.add_child(artist_label)
	count_label = _label("0 / 0", 9, Color("435a60"))
	count_label.position = Vector2(69, 74)
	count_label.size = Vector2(98, 15)
	display_root.add_child(count_label)
	progress = ProgressBar.new()
	progress.position = Vector2(39, 111)
	progress.size = Vector2(96, 6)
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _style(Color("9caeaa"), 4))
	progress.add_theme_stylebox_override("fill", _style(Color("397aa2"), 4))
	display_root.add_child(progress)
	time_label = _label("0:00", 8, Color("26373c"))
	time_label.position = Vector2(7, 106)
	time_label.size = Vector2(30, 15)
	display_root.add_child(time_label)
	total_label = _label("0:00", 8, Color("26373c"))
	# правый край с запасом: у самого края экрана последняя цифра длительности обрезалась
	total_label.position = Vector2(126, 106)
	total_label.size = Vector2(37, 15)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	display_root.add_child(total_label)


func _build_wheel() -> void:
	# Корпус рисует плоское колесо; интерактивные подписи остаются отдельными Control.
	var wheel := Control.new()
	wheel.position = WHEEL_RECT.position
	wheel.size = WHEEL_RECT.size
	device.add_child(wheel)
	_add_wheel_button(wheel, "MENU", Vector2(35, 0), Vector2(58, 31), "menu", _back)
	_add_wheel_button(wheel, "◀◀", Vector2(0, 41), Vector2(40, 46), "previous", _prev)
	_add_wheel_button(wheel, "▶▶", Vector2(88, 41), Vector2(39, 46), "next", _next)
	_add_wheel_button(wheel, "▶ Ⅱ", Vector2(35, 96), Vector2(58, 31), "play", _play)
	center_button = _add_wheel_button(wheel, "", Vector2(40, 40), Vector2(48, 48), "select", _select)


func _add_wheel_button(parent: Control, text: String, pos: Vector2, sz: Vector2, action: String, callback: Callable) -> Button:
	var feedback := Panel.new()
	feedback.position = pos
	feedback.size = sz
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.offset_transform_enabled = true
	feedback.modulate.a = 0.0
	feedback.add_theme_stylebox_override("panel", _style(Color(0.055, 0.075, 0.085, 0.18), int(sz.y * 0.5),
		Color(0.025, 0.04, 0.05, 0.28), 1, Color(0, 0, 0, 0.16), 2))
	parent.add_child(feedback)
	var b := Button.new()
	b.text = text
	b.tooltip_text = text if text != "" else "Выбрать"
	b.position = pos
	b.size = sz
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 8 if text == "MENU" else 10)
	b.add_theme_color_override("font_color", Color("5d6266"))
	b.add_theme_color_override("font_hover_color", Color("353a3e"))
	b.add_theme_color_override("font_pressed_color", Color("2d3236"))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _style(Color(0.25, 0.36, 0.42, 0.055), int(sz.y * 0.5), Color(0.42, 0.55, 0.61, 0.16), 1))
	b.add_theme_stylebox_override("pressed", _style(Color(0.08, 0.13, 0.16, 0.16), int(sz.y * 0.5), Color(0.04, 0.07, 0.09, 0.24), 1))
	b.offset_transform_enabled = true
	wheel_buttons.append(b)
	wheel_button_by_action[action] = b
	wheel_feedback_by_action[action] = feedback
	b.button_down.connect(_on_wheel_button_down.bind(action, callback))
	b.button_up.connect(_on_wheel_button_up.bind(action))
	parent.add_child(b)
	return b


func _on_wheel_button_down(action: String, callback: Callable) -> void:
	_activate_wheel_action(action, callback, false)


func _on_wheel_button_up(action: String) -> void:
	_release_wheel_visual(action)


func _activate_wheel_action(action: String, callback: Callable, keyboard := true) -> bool:
	if not _wheel_action_available(action):
		return false
	_press_wheel_visual(action, keyboard)
	_thumb(action)
	_play_ui_sound(_wheel_sound_kind(action))
	callback.call()
	return true


## Большой палец героя коротко нажимает на колесо настоящего устройства.
func _thumb(kind := "select") -> void:
	var pod = _pod()
	if pod != null:
		pod.press(kind)


func _wheel_action_available(action: String) -> bool:
	match action:
		"previous", "next":
			return not tracks.is_empty()
		"play":
			return player != null and (player.stream != null or not tracks.is_empty())
		"select":
			if page in ["Reverb Depth", "Громкость", "Bass Boost"]:
				return false
			return true
		"menu":
			return opened
	return false


func _wheel_sound_kind(action: String) -> String:
	match action:
		"previous":
			return "track_previous"
		"next":
			return "track_next"
		"play":
			return "play"
		"menu":
			return "menu"
		_:
			return "select"


func _motion_scale() -> float:
	match ui_motion_mode:
		UIMotionMode.REDUCED:
			return 0.55
		UIMotionMode.FULL:
			return 1.0
		_:
			return 0.0


func _press_wheel_visual(action: String, auto_release: bool) -> void:
	var button := wheel_button_by_action.get(action) as Button
	var feedback := wheel_feedback_by_action.get(action) as Panel
	var scale := _motion_scale()
	if button == null or feedback == null or scale <= 0.0:
		return
	_kill_wheel_tween(action)
	button.offset_transform_position = Vector2(0, 1.5)
	button.self_modulate = Color(0.80, 0.82, 0.84, 1.0)
	feedback.offset_transform_position = Vector2(0, 1.5)
	feedback.modulate.a = 1.0
	if auto_release:
		var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(0.075 * scale)
		tween.set_parallel(true)
		tween.tween_property(button, "offset_transform_position", Vector2.ZERO, 0.12 * scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "self_modulate", Color.WHITE, 0.12 * scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(feedback, "offset_transform_position", Vector2.ZERO, 0.12 * scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(feedback, "modulate:a", 0.0, 0.12 * scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wheel_tweens[action] = tween


func _release_wheel_visual(action: String, immediate := false) -> void:
	var button := wheel_button_by_action.get(action) as Button
	var feedback := wheel_feedback_by_action.get(action) as Panel
	if button == null or feedback == null:
		return
	_kill_wheel_tween(action)
	var duration := 0.0 if immediate else 0.12 * _motion_scale()
	if duration <= 0.0:
		button.offset_transform_position = Vector2.ZERO
		button.self_modulate = Color.WHITE
		feedback.offset_transform_position = Vector2.ZERO
		feedback.modulate.a = 0.0
		return
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(button, "offset_transform_position", Vector2.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "self_modulate", Color.WHITE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "offset_transform_position", Vector2.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wheel_tweens[action] = tween


func _kill_wheel_tween(action: String) -> void:
	var tween = wheel_tweens.get(action)
	if is_instance_valid(tween):
		(tween as Tween).kill()
	wheel_tweens.erase(action)


func _release_all_wheel_buttons(immediate := false) -> void:
	for action in wheel_button_by_action:
		_release_wheel_visual(String(action), immediate)


func _make_body_texture() -> Texture2D:
	# Transparent SVG: the reference photo is not sampled, so no white matte can leak
	# into antialiased edges. Multiple restrained gradients mimic anodized aluminium.
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="612" height="1023" viewBox="0 0 204 341">
<defs>
 <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#f5f6f6"/><stop offset="0.16" stop-color="#d9dcde"/>
  <stop offset="0.54" stop-color="#c5c9cb"/><stop offset="0.82" stop-color="#d9dcdd"/><stop offset="1" stop-color="#aeb3b6"/>
 </linearGradient>
 <linearGradient id="edge" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#858b8e"/><stop offset="0.035" stop-color="#eef0f1"/>
  <stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/><stop offset="0.965" stop-color="#b7bbbd"/><stop offset="1" stop-color="#707679"/>
 </linearGradient>
 <radialGradient id="wheel" cx="45%" cy="38%" r="66%">
  <stop offset="0" stop-color="#fbfbfb"/><stop offset="0.76" stop-color="#eeeeef"/><stop offset="1" stop-color="#d4d6d7"/>
 </radialGradient>
 <linearGradient id="button" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#e9ebec"/><stop offset="1" stop-color="#b5b9bb"/>
 </linearGradient>
</defs>
<rect x="1" y="1" width="202" height="339" rx="18" fill="url(#metal)" stroke="#73797c" stroke-width="0.8"/>
<rect x="2" y="2" width="200" height="337" rx="17" fill="url(#edge)" opacity="0.26"/>
<path d="M18 2 H186 Q201 2 202 18" fill="none" stroke="#ffffff" stroke-opacity="0.7" stroke-width="1"/>
<path d="M2 323 Q2 339 18 339 H186" fill="none" stroke="#777d80" stroke-opacity="0.55" stroke-width="1"/>
<rect x="14" y="14" width="176" height="135" rx="5" fill="#171a1d" stroke="#73787a" stroke-width="0.65"/>
<rect x="17" y="17" width="170" height="129" rx="3.5" fill="#080a0b" opacity="0.5"/>
<circle cx="102" cy="241.5" r="64" fill="#a3a6a8" opacity="0.28"/>
<circle cx="102" cy="240.5" r="63" fill="url(#wheel)" stroke="#b6b9bb" stroke-width="0.55"/>
<circle cx="102" cy="240.5" r="23" fill="url(#button)" stroke="#9da2a5" stroke-width="0.55"/>
<circle cx="99" cy="237.5" r="20" fill="#ffffff" opacity="0.08"/>
</svg>"""
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		push_error("iPod: не удалось создать текстуру корпуса")
		return null
	return ImageTexture.create_from_image(image)


func _make_note_label(font_size: int) -> Label:
	var note := _label("♫", font_size, Color("aeb8bd"), true)
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return note


func _cover_used_elsewhere(path: String, ignored_index: int) -> bool:
	for i in tracks.size():
		if i != ignored_index and String(tracks[i].get("cover", "")) == path:
			return true
	return false


func _cover_for_track(track: Dictionary) -> Texture2D:
	var path := String(track.get("cover", ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	if cover_cache.has(path):
		return cover_cache[path] as Texture2D
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK or image.is_empty():
		return null
	var largest := maxi(image.get_width(), image.get_height())
	if largest > 512:
		var ratio := 512.0 / float(largest)
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	cover_cache[path] = texture
	return texture


func _update_cover() -> void:
	var texture: Texture2D
	var next_key := "none"
	if track_index >= 0 and track_index < tracks.size():
		texture = _cover_for_track(tracks[track_index])
		next_key = String(tracks[track_index].get("id", track_index)) + ":" + String(tracks[track_index].get("cover", ""))
	if menu_art_texture != null:
		menu_art_texture.texture = texture
		menu_art_note.visible = texture == null
	if cover_texture == null or next_key == cover_key:
		return
	cover_key = next_key
	if is_instance_valid(cover_tween):
		cover_tween.kill()
	var previous := cover_texture.texture
	cover_previous_texture.texture = previous
	cover_previous_texture.visible = previous != null
	cover_previous_texture.modulate = Color.WHITE
	cover_texture.texture = texture
	cover_texture.modulate = Color.WHITE
	cover_note.visible = texture == null
	cover_note.modulate = Color.WHITE
	if not opened or _motion_scale() <= 0.0:
		cover_previous_texture.visible = false
		return
	cover_texture.modulate.a = 0.0 if texture != null else 1.0
	cover_note.modulate.a = 0.0 if texture == null else 1.0
	var duration := 0.15 * _motion_scale()
	cover_tween = cover_texture.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	cover_tween.tween_property(cover_texture, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cover_tween.tween_property(cover_note, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cover_tween.tween_property(cover_previous_texture, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cover_tween.chain().tween_callback(func():
		cover_previous_texture.visible = false
		cover_previous_texture.modulate = Color.WHITE)


func _gradient_rect(pos: Vector2, rect_size: Vector2, colors: Array[Color], offsets: Array[float], from := Vector2(0, 0), to := Vector2(0, 1)) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = max(1, int(rect_size.x))
	texture.height = max(1, int(rect_size.y))
	texture.fill_from = from
	texture.fill_to = to
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect


func _style(color: Color, radius: int, border := Color.TRANSPARENT, width := 0, shadow := Color.TRANSPARENT, shadow_size := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if width > 0:
		box.border_color = border
		box.set_border_width_all(width)
	if shadow_size > 0:
		box.shadow_color = shadow
		box.shadow_size = shadow_size
	return box


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", Color(color, 0.12))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _items() -> Array:
	if page == "Музыка":
		var result: Array = tracks.map(func(track): return String(track["title"]))
		result.append("Добавить свою музыку")
		return result
	if page == "Встроенная музыка":
		return tracks.filter(func(track): return not bool(track.get("local", false))).map(func(track): return String(track["title"]))
	if page == "Моя музыка":
		var mine: Array = tracks.filter(func(track): return bool(track.get("local", false))).map(func(track): return String(track["title"]))
		mine.append("Добавить свою музыку")
		return mine
	if page == "Все треки":
		return tracks.map(func(track): return String(track["title"]))
	if page == "Настройки":
		var settings: Array = ["Воспроизведение", "Звук"]
		if track_index >= 0 and bool(tracks[track_index].get("local", false)):
			settings.append("Удалить текущий трек")
		return settings
	return PAGES.get(page, [])


func _scroll(delta: int) -> void:
	_thumb("scroll")
	if page == "Repeat":
		_cycle_repeat(delta)
		_play_ui_sound("navigate")
		return
	if page == "Reverb Depth":
		var old_reverb := reverb_depth
		reverb_depth = clampf(reverb_depth + delta * 0.05, 0.0, 1.0)
		_save_settings()
		_refresh()
		if not is_equal_approx(old_reverb, reverb_depth):
			_play_ui_sound("navigate")
		return
	if page == "Громкость":
		var old_volume := volume
		volume = clampf(volume + delta * 0.05, 0.0, 1.0)
		_save_settings()
		_refresh()
		if not is_equal_approx(old_volume, volume):
			_play_ui_sound("navigate")
		return
	if page == "Bass Boost":
		var old_bass := bass_boost
		bass_boost = clampf(bass_boost + delta * 0.05, 0.0, 1.0)
		_save_settings()
		_refresh()
		if not is_equal_approx(old_bass, bass_boost):
			_play_ui_sound("navigate")
		return
	if page == "Звуки кнопок":
		var old_button_volume := button_sounds_volume
		button_sounds_volume = clampf(button_sounds_volume + delta * 0.05, 0.0, 1.0)
		_save_settings()
		_refresh()
		if not is_equal_approx(old_button_volume, button_sounds_volume):
			_play_ui_sound("navigate")
		return
	if page == "Анимации UI":
		ui_motion_mode = posmod(ui_motion_mode + delta, UIMotionMode.size())
		_save_settings()
		_refresh()
		_play_ui_sound("navigate")
		return
	if page == "Сейчас играет" and player.stream != null:
		var old_position := player.get_playback_position()
		var new_position := clampf(old_position + delta * 5.0, 0.0, player.stream.get_length())
		player.seek(new_position)
		if not is_equal_approx(old_position, new_position):
			_play_ui_sound("navigate")
		return
	var items := _items()
	if items.is_empty():
		return
	var old_selected := selected
	selected = posmod(selected + delta, items.size())
	_refresh()
	if selected != old_selected:
		_play_ui_sound("navigate")


func _select() -> void:
	var items := _items()
	if page == "Сейчас играет":
		_cycle_repeat(1)
		return
	if page == "Repeat":
		_cycle_repeat(1)
		return
	if page == "Звуки кнопок":
		button_sounds_enabled = not button_sounds_enabled
		_save_settings()
		_refresh()
		if button_sounds_enabled:
			_play_ui_sound("select")
		return
	if page == "Анимации UI":
		ui_motion_mode = posmod(ui_motion_mode + 1, UIMotionMode.size())
		_save_settings()
		_refresh()
		return
	if page in ["Reverb Depth", "Громкость", "Bass Boost"]:
		return
	if items.is_empty():
		_go_to_page("Сейчас играет")
	elif selected < items.size():
		var item: String = items[selected]
		if item == "Добавить свою музыку":
			file_dialog.popup_centered_ratio(0.7)
			return
		if item == "Удалить текущий трек":
			_remove_current()
			return
		if page == "Музыка":
			_select_track(selected)
			return
		if page in ["Все треки", "Встроенная музыка", "Моя музыка"]:
			var filtered := tracks
			if page == "Встроенная музыка":
				filtered = tracks.filter(func(track): return not bool(track.get("local", false)))
			elif page == "Моя музыка":
				filtered = tracks.filter(func(track): return bool(track.get("local", false)))
			if selected < filtered.size():
				_select_track(tracks.find(filtered[selected]))
			return
		_go_to_page(item)
	_refresh()


func _back() -> void:
	page_selection[page] = selected
	if not page_history.is_empty():
		page = page_history.pop_back()
	elif page != "Menu":
		page = "Menu"
	else:
		close()
		return
	selected = int(page_selection.get(page, 0))
	page_transition_direction = -1
	_refresh()


func _go_to_page(next_page: String) -> void:
	if next_page == page:
		return
	page_selection[page] = selected
	if page_history.is_empty() or page_history.back() != page:
		page_history.append(page)
	page = next_page
	selected = int(page_selection.get(page, 0))
	page_transition_direction = 1


func _select_screen_row(viewport_position: Vector2) -> bool:
	var local := screen.get_global_transform_with_canvas().affine_inverse() * viewport_position
	if page == "Сейчас играет":
		# The small count/repeat badge is clickable; the rest of Now Playing keeps
		# the established play/pause click behavior.
		if Rect2(65, 69, 104, 24).has_point(local):
			_cycle_repeat(1)
		else:
			if player.stream == null and tracks.is_empty():
				return false
			_play()
		return true
	if local.y < 20.0 or local.x > content.size.x + content.position.x:
		return false
	var items := _items()
	if items.is_empty():
		return false
	var offset: int = max(0, selected - 3)
	var clicked := offset + floori((local.y - 22.0) / 25.0)
	if clicked >= 0 and clicked < items.size():
		selected = clicked
		_refresh()
		_select()
		return true
	return false


func _hover_row(slot: int) -> void:
	if not opened or not content.visible:
		return
	var items := _items()
	var offset: int = max(0, selected - 3)
	var index := offset + slot
	if index >= 0 and index < items.size() and selected != index:
		selected = index
		_hint_used()
		_refresh()


func _hint_used() -> void:
	if hint_panel != null and hint_panel.visible:
		hint_time = minf(hint_time, 2.5)


func _prev() -> void:
	_track_step(-1)


func _next() -> void:
	_track_step(1)


func _track_step(delta: int) -> void:
	var next_index := _manual_track_index(delta)
	if next_index < 0:
		return
	_select_track(next_index)


func _manual_track_index(delta: int) -> int:
	if tracks.is_empty():
		return -1
	var start := track_index if track_index >= 0 else (0 if delta > 0 else tracks.size() - 1)
	return posmod(start + delta, tracks.size())


func _play() -> void:
	if player.stream == null:
		if not tracks.is_empty():
			_select_track(0)
		return
	# У трека на паузе playing == false, поэтому паузу проверяем первой:
	# иначе Пробел после паузы запускал трек с начала вместо продолжения.
	if player.stream_paused:
		player.stream_paused = false
	elif not player.playing:
		player.play()
	else:
		player.stream_paused = true
	_save_settings()
	_refresh_playback()


func _cycle_repeat(delta: int) -> void:
	repeat_mode = posmod(repeat_mode + delta, RepeatMode.size())
	_save_settings()
	_refresh()


func _repeat_indicator() -> String:
	match repeat_mode:
		RepeatMode.ONE:
			return "R1"
		RepeatMode.ALL:
			return "ALL"
		_:
			return "OFF"


func _refresh_playback(dt := 0.0) -> void:
	if player == null:
		return
	state_label.text = "" if player.stream == null else ("Ⅱ" if player.stream_paused else ("▶" if player.playing else "■"))
	if track_index >= 0 and track_index < tracks.size():
		title_label.text = String(tracks[track_index]["title"])
		artist_label.text = String(tracks[track_index].get("artist", ""))
		count_label.text = "%d / %d · %s" % [track_index + 1, tracks.size(), _repeat_indicator()]
		var length := player.stream.get_length() if player.stream != null else 0.0
		var position := player.get_playback_position() if player.stream != null else 0.0
		progress.max_value = maxf(1.0, length)
		progress.value = lerpf(progress.value, position, 1.0 - exp(-14.0 * dt)) if dt > 0.0 else position
		time_label.text = _format_time(position)
		total_label.text = _format_time(length)
	else:
		title_label.text = "Нет выбранного трека"
		artist_label.text = ""
		count_label.text = "0 / %d · %s" % [tracks.size(), _repeat_indicator()]
		progress.value = 0.0
		time_label.text = "0:00"
		total_label.text = "0:00"
	_update_cover()


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), floori(fmod(seconds, 60.0))]


func _refresh() -> void:
	if screen == null:
		return
	if displayed_page == "" or not opened or _motion_scale() <= 0.0:
		_reset_page_transition()
		_refresh_immediate()
		return
	if displayed_page == page:
		_refresh_immediate()
		return
	_start_page_transition(page_transition_direction if page_transition_direction != 0 else 1)


func _start_page_transition(direction: int) -> void:
	_reset_page_transition()
	var motion := _motion_scale()
	var out_time := 0.06 * motion
	var in_time := 0.105 * motion
	var travel := 6.0 * float(signi(direction))
	screen_tween = display_root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	screen_tween.tween_property(display_root, "position", Vector2(-travel, 0), out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	screen_tween.parallel().tween_property(display_root, "modulate:a", 0.52, out_time)
	screen_tween.tween_callback(func():
		_refresh_immediate()
		display_root.position = Vector2(travel, 0)
		display_root.modulate.a = 0.52)
	screen_tween.tween_property(display_root, "position", Vector2.ZERO, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	screen_tween.parallel().tween_property(display_root, "modulate:a", 1.0, in_time)
	page_transition_direction = 0


func _reset_page_transition() -> void:
	if is_instance_valid(screen_tween):
		screen_tween.kill()
	if display_root != null:
		display_root.position = Vector2.ZERO
		display_root.modulate = Color.WHITE


func _reset_screen_motion() -> void:
	_reset_page_transition()
	if is_instance_valid(highlight_tween):
		highlight_tween.kill()
	if is_instance_valid(cover_tween):
		cover_tween.kill()
	if cover_texture != null:
		cover_texture.modulate = Color.WHITE
	if cover_previous_texture != null:
		cover_previous_texture.visible = false
		cover_previous_texture.modulate = Color.WHITE
	if screen != null:
		_refresh_immediate()


func _refresh_immediate() -> void:
	if screen == null:
		return
	displayed_page = page
	page_label.text = "iPod" if page == "Menu" else page
	var now_playing := page == "Сейчас играет"
	var classic_menu := page == "Menu"
	menu_art.visible = classic_menu
	content.size.x = 80.0 if classic_menu else 161.0
	for node_name in ["Cover"]:
		var n := display_root.get_node_or_null(node_name)
		if n:
			n.visible = now_playing
	for n in [title_label, artist_label, count_label, progress, time_label, total_label]:
		if n:
			n.visible = now_playing
	content.visible = not now_playing
	var items := _items()
	if page in ["Reverb Depth", "Громкость", "Bass Boost"]:
		var value := reverb_depth if page == "Reverb Depth" else (volume if page == "Громкость" else bass_boost)
		items = ["  %d%%" % roundi(value * 100.0), "", "  Колесо — изменить"]
	elif page == "Repeat":
		items = ["  Repeat %s" % _repeat_indicator(), "", "  Колесо — изменить"]
	elif page == "Звуки кнопок":
		items = ["  %s · %d%%" % ["Вкл" if button_sounds_enabled else "Выкл", roundi(button_sounds_volume * 100.0)], "", "  Select — вкл/выкл"]
	elif page == "Анимации UI":
		items = ["  %s" % _motion_label(), "", "  Колесо — режим"]
	var offset: int = max(0, selected - 3)
	_update_selection_bar(items, offset, classic_menu, now_playing)
	for i in row_labels.size():
		var row := row_labels[i]
		var row_bg := row.get_parent() as PanelContainer
		row_bg.custom_minimum_size.x = content.size.x
		var index := offset + i
		row.visible = index < items.size()
		row_bg.visible = row.visible
		if not row.visible:
			continue
		var item_text := String(items[index])
		row.text = " " + item_text + (" ›" if classic_menu and index == selected else "")
		if index == selected:
			row.add_theme_color_override("font_color", Color.WHITE)
			row_bg.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			row.add_theme_color_override("font_color", Color("17232a"))
			row_bg.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_refresh_playback()


func _update_selection_bar(items: Array, offset: int, classic_menu: bool, now_playing: bool) -> void:
	if is_instance_valid(highlight_tween):
		highlight_tween.kill()
	selection_bar.visible = not now_playing and not items.is_empty()
	if not selection_bar.visible:
		return
	var slot := clampi(selected - offset, 0, 3)
	var target_position := Vector2(3, 22 + slot * 25)
	var target_size := Vector2(80 if classic_menu else 161, 25)
	if not opened or _motion_scale() <= 0.0:
		selection_bar.position = target_position
		selection_bar.size = target_size
		return
	var duration := 0.11 * _motion_scale()
	highlight_tween = selection_bar.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	highlight_tween.tween_property(selection_bar, "position", target_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	highlight_tween.tween_property(selection_bar, "size", target_size, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _motion_label() -> String:
	match ui_motion_mode:
		UIMotionMode.OFF:
			return "Выкл"
		UIMotionMode.REDUCED:
			return "Быстрые"
		_:
			return "Полные"


func _exit_tree() -> void:
	_save_settings()
	if game != null and game.has_method("set_ipod_visual_focus"):
		game.set_ipod_visual_focus(0.0, 0.0)
	if game != null and game.main != null and game.main.audio != null:
		game.main.audio.ipod_focus_target = 0.0
