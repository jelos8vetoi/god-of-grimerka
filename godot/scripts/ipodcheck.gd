## Автопроверка iPod: `-- --ipodcheck=<папка>`. Жмёт настоящие клавиши и кнопки мыши, снимает кадры в папку
## и печатает строки «IPOD ok / IPOD ОШИБКА». Если в папке лежат test.mp3 и test.wav — проверяет ещё и импорт.
## Звук на время проверки заглушён на общей шине: уровни меряются по шинам, слушать ничего не нужно.
extends Node

var game
var out := ""
var fails := 0
var ipod
var pl
var audio

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	_run()

func ok(cond: bool, text: String) -> void:
	if not cond:
		fails += 1
	print(("IPOD ok: " if cond else "IPOD ОШИБКА: ") + text)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: Key, down := true) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)

func tap(k: Key, hold := 0.07) -> void:
	key(k)
	await wait(hold)
	key(k, false)
	await wait(0.07)

func mouse(button: MouseButton, pos: Vector2, down := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = down
	# точки считаем в координатах холста, а событие мыши приходит в пикселях окна
	var wpos: Vector2 = get_viewport().get_final_transform() * pos
	e.position = wpos
	e.global_position = wpos
	Input.parse_input_event(e)

func click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	mouse(button, pos)
	await wait(0.07)
	mouse(button, pos, false)
	await wait(0.07)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name))
	# рядом — увеличенный втрое фрагмент с самим iPod: мелкий текст экрана иначе не разглядеть
	if ipod.device.visible:
		var r := Rect2i((get_viewport().get_final_transform() * device_rect()).grow(10.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 8 and r.size.y > 8:
			var z := img.get_region(r)
			z.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_LANCZOS)
			z.save_png(out.path_join(name.get_basename() + "_zoom.png"))

func peak(bus: String) -> float:
	return AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(bus), 0)

## Встать на пункт текущей страницы и выбрать его.
func choose(item: String) -> void:
	var items: Array = ipod._items()
	var idx := items.find(item)
	if idx < 0:
		ok(false, "на странице «%s» нет пункта «%s»" % [ipod.page, item])
		return
	var n := 0
	while ipod.selected != idx and n < 12:
		await tap(KEY_S)
		n += 1
	await tap(KEY_ENTER)
	await wait(0.3)

func device_rect() -> Rect2:
	return ipod.device.get_global_transform() * Rect2(Vector2.ZERO, ipod.device.size)

func _run() -> void:
	ipod = game.ipod
	pl = game.player
	audio = game.main.audio
	var vs := get_viewport().get_visible_rect().size
	await wait(1.5)

	# ---- шины: эффекты iPod не должны задевать голос, эффекты и окружение ----
	ok(AudioServer.get_bus_index("IPod") >= 0 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("IPod")) == 4, "шина IPod: фильтр, эквалайзер баса, реверберация, ограничитель")
	for b in ["Voice", "SFX", "Ambient"]:
		ok(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(b)) == 0, "шина %s без эффектов" % b)
	ok(ipod.ui_players[0].bus == "SFX", "щелчки колеса идут мимо баса и реверберации (шина SFX)")

	# ---- диалог ----
	ok(game.mode == "dlg", "игра началась с диалога")
	await tap(KEY_UP)
	await wait(0.3)
	ok(not ipod.opened, "в диалоге iPod не открывается")
	ipod._select_track(0)
	await wait(1.8)
	ok(ipod.player.playing and not ipod.player.stream_paused, "встроенный трек играет: «%s»" % String(ipod.tracks[0]["title"]))
	ok(absf(ipod.mix_volume - ipod.volume * 0.42) < 0.04, "в диалоге трек iPod приглушён (%.2f из %.2f)" % [ipod.mix_volume, ipod.volume])
	print("IPOD уровни в диалоге: IPod %.1f дБ, Music %.1f дБ, Voice %.1f дБ" % [peak("IPod"), peak("Music"), peak("Voice")])
	var n := 0
	while game.mode == "dlg" and n < 200:
		await tap(KEY_ENTER, 0.04)
		n += 1
	ok(game.mode != "dlg", "диалог пролистан клавишей Enter (режим «%s»)" % game.mode)
	await wait(1.2)
	ok(absf(ipod.mix_volume - ipod.volume) < 0.05, "после диалога громкость трека вернулась (%.2f)" % ipod.mix_volume)
	print("IPOD уровни вне диалога, iPod закрыт: IPod %.1f дБ, Music %.1f дБ (набор «%s»)" % [peak("IPod"), peak("Music"), audio.cur])

	# ---- обычное управление до открытия ----
	var p0: Vector3 = pl.global_position
	key(KEY_W)
	await wait(0.5)
	key(KEY_W, false)
	await wait(0.25)
	ok(pl.global_position.distance_to(p0) > 0.3, "до iPod: W двигает Пахана (%.2f м)" % pl.global_position.distance_to(p0))
	var len0: float = game.spring.spring_length
	var mouse0 := Input.mouse_mode

	# ---- открытие ----
	await tap(KEY_UP)
	await wait(1.1)
	ok(ipod.opened and ipod.device.visible, "↑ открывает iPod")
	ok(ipod.captures_gameplay_input(), "ввод игры перехвачен")
	ok(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "курсор виден")
	ok(game.ipod_focus > 0.98, "фокус картинки включён (%.2f)" % game.ipod_focus)
	ok(game.spring.spring_length < len0 * 0.93, "камера приблизилась: %.2f → %.2f" % [len0, game.spring.spring_length])
	ok(game.cam_attributes.dof_blur_far_enabled and game.cam_attributes.dof_blur_amount > 0.2, "мир в расфокусе")
	ok(game.post.visible and game.hud_root.modulate.a < 0.85, "фон затемнён, HUD приглушён (%.2f)" % game.hud_root.modulate.a)
	ok(audio.ipod_focus > 0.9 and audio.ipod_lowpass.cutoff_hz < 7000.0 and audio.ipod_reverb.wet > 0.1, "музыка локации тише и глубже (срез %.0f Гц, реверберация %.2f)" % [audio.ipod_lowpass.cutoff_hz, audio.ipod_reverb.wet])
	ok(ipod.reverb.wet > 0.2 and absf(ipod.mix_volume - ipod.volume * 0.8) < 0.05, "трек iPod с реверберацией (%.2f) и тише (%.2f)" % [ipod.reverb.wet, ipod.mix_volume])
	var dev := device_rect()
	var body: Rect2 = ipod._pahan_protected_rect(vs)
	ok(not dev.intersects(body), "iPod не перекрывает Пахана (зазор %.0f пикс.)" % (dev.position.x - body.end.x))
	ok(dev.get_center().x > body.get_center().x, "iPod справа от Пахана")
	ok(Rect2(Vector2.ZERO, vs).encloses(dev), "iPod целиком в кадре")
	await tap(KEY_ESCAPE)
	await wait(0.35)
	ok(ipod.page == "Menu" and ipod.opened and not get_tree().paused, "Esc — назад в меню iPod, пауза игры не включается")
	await shot("ipod_1_menu.png")

	# ---- клавиши плеера не управляют Паханом ----
	var p1: Vector3 = pl.global_position
	var sel0: int = ipod.selected
	key(KEY_S)
	await wait(0.4)
	key(KEY_S, false)
	await wait(0.1)
	ok(pl.global_position.distance_to(p1) < 0.05 and ipod.selected != sel0, "S листает меню, Пахан стоит")
	await tap(KEY_W)
	ok(ipod.selected == sel0, "W листает меню обратно")
	await click(Vector2(vs.x * 0.2, vs.y * 0.45))
	await wait(0.2)
	ok(pl.state == "move", "ЛКМ мимо iPod не бьёт балоном (состояние «%s»)" % pl.state)
	var was_paused: bool = ipod.player.stream_paused
	await tap(KEY_SPACE)
	await wait(0.2)
	ok(pl.state != "roll" and ipod.player.stream_paused != was_paused, "Пробел — пауза трека, а не перекат")
	var pos_paused: float = ipod.player.get_playback_position()
	await tap(KEY_SPACE)
	await wait(0.2)
	ok(not ipod.player.stream_paused and ipod.player.get_playback_position() >= pos_paused, "Пробел — продолжить с того же места (%.2f → %.2f с, пауза %s)" % [pos_paused, ipod.player.get_playback_position(), ipod.player.stream_paused])

	# ---- библиотека и «Сейчас играет» ----
	await choose("Музыка")
	ok(ipod.page == "Музыка", "раздел «Музыка» открылся")
	await shot("ipod_2_music.png")
	await choose(String(ipod.tracks[0]["title"]))
	ok(ipod.page == "Сейчас играет" and ipod.player.playing, "выбор трека включает его и открывает «Сейчас играет»")
	await wait(0.6)
	var t0: float = ipod.player.get_playback_position()
	mouse(MOUSE_BUTTON_WHEEL_DOWN, vs * 0.5)
	await wait(0.15)
	ok(ipod.player.get_playback_position() - t0 > 4.0, "колёсико мыши перематывает на 5 секунд")
	await tap(KEY_S)
	ok(ipod.player.get_playback_position() - t0 > 9.0, "S перематывает вперёд")
	await tap(KEY_D)
	await wait(0.3)
	ok(ipod.player.playing and ipod.player.get_playback_position() < 2.0, "D — следующий трек (он один, начался заново)")
	await tap(KEY_ENTER)
	ok(ipod.repeat_mode == 1 and ipod._finished_track_index() == ipod.track_index, "Repeat ONE: после конца тот же трек")
	await tap(KEY_ENTER)
	ok(ipod.repeat_mode == 2 and ipod._finished_track_index() == 0, "Repeat ALL: после последнего — первый")
	await tap(KEY_ENTER)
	ok(ipod.repeat_mode == 0 and ipod._finished_track_index() == -1, "Repeat OFF: после последнего остановка")
	# кнопка колеса мышью: нажатие утапливает кнопку и ставит паузу
	var btn: Button = ipod.wheel_button_by_action["play"]
	var bpos: Vector2 = btn.get_global_transform() * (btn.size * 0.5)
	mouse(MOUSE_BUTTON_LEFT, bpos)
	await wait(0.05)
	ok(btn.offset_transform_position.y > 1.0 and ipod.player.stream_paused, "кнопка ▶Ⅱ на колесе нажимается мышью и утапливается (сдвиг %.1f, пауза %s)" % [btn.offset_transform_position.y, ipod.player.stream_paused])
	mouse(MOUSE_BUTTON_LEFT, bpos, false)
	await wait(0.3)
	ok(btn.offset_transform_position.y < 0.1, "кнопка колеса отпускается")
	await tap(KEY_SPACE)
	await shot("ipod_3_now.png")

	# ---- настройки звука ----
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	await wait(0.3)
	if ipod.page != "Menu":
		await tap(KEY_ESCAPE)
		await wait(0.3)
	await choose("Настройки")
	await choose("Звук")
	await choose("Bass Boost")
	ok(ipod.page == "Bass Boost", "страница Bass Boost")
	for i in 10:
		await tap(KEY_S, 0.03)
	await wait(0.8)
	ok(absf(ipod.bass_boost - 0.5) < 0.01 and absf(ipod.bass_eq.get_band_gain_db(1) - 3.0) < 0.3, "Bass Boost 50%%: +%.1f дБ на 100 Гц" % ipod.bass_eq.get_band_gain_db(1))
	await shot("ipod_4_bass.png")
	await tap(KEY_ESCAPE)
	await wait(0.3)
	await choose("Reverb Depth")
	for i in 4:
		await tap(KEY_W, 0.03)
	await wait(1.2)
	ok(absf(ipod.reverb_depth - 0.4) < 0.01 and absf(ipod.reverb.wet - 0.4 * 0.46) < 0.02, "Reverb Depth 40%%: доля реверберации %.2f" % ipod.reverb.wet)
	await tap(KEY_ESCAPE)
	await wait(0.3)
	await choose("Звуки кнопок")
	var bv: float = ipod.button_sounds_volume
	for i in 3:
		await tap(KEY_S, 0.03)
	ok(absf(ipod.button_sounds_volume - bv - 0.15) < 0.01, "громкость звуков кнопок меняется (%.2f → %.2f)" % [bv, ipod.button_sounds_volume])
	ok(ipod._play_ui_sound("select") or ipod.ui_players.any(func(p): return p.playing), "щелчок кнопки звучит")
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	await wait(0.3)

	# ---- импорт своих файлов ----
	var files := PackedStringArray()
	for f in ["test.mp3", "test.wav"]:
		if FileAccess.file_exists(out.path_join(f)):
			files.append(out.path_join(f))
	if files.is_empty():
		print("IPOD пропуск: в папке нет test.mp3 / test.wav — импорт не проверялся")
	else:
		var before: int = ipod.tracks.size()
		ipod._import_files(files)
		await wait(0.6)
		ok(ipod.tracks.size() == before + files.size(), "импортировано файлов: %d" % (ipod.tracks.size() - before))
		var tr: Dictionary = ipod.tracks[before]
		ok(String(tr["title"]) == "Тест Балон" and String(tr["artist"]) == "madk1d", "теги MP3 прочитаны: «%s» — %s" % [tr["title"], tr["artist"]])
		ok(String(tr["cover"]) != "" and ipod._cover_for_track(tr) != null, "обложка из MP3 извлечена")
		ok(ipod.track_index == before and ipod.player.playing, "импортированный MP3 играет")
		await wait(0.5)
		print("IPOD уровень своего MP3: %.1f дБ" % peak("IPod"))
		await shot("ipod_5_cover.png")
		if files.size() > 1:
			ipod._select_track(before + 1)
			await wait(0.5)
			ok(ipod.player.playing and peak("IPod") > -60.0, "импортированный WAV играет (%.1f дБ)" % peak("IPod"))
		# удаление через меню
		var gone := String(ipod.tracks[ipod.track_index]["path"])
		await tap(KEY_ESCAPE)
		await wait(0.3)
		while ipod.page != "Menu":
			await tap(KEY_ESCAPE)
			await wait(0.3)
		await choose("Настройки")
		await choose("Удалить текущий трек")
		ok(not FileAccess.file_exists(gone) and ipod.tracks.size() == before + files.size() - 1, "текущий свой трек удалён вместе с файлом")
		while ipod.tracks.size() > before:
			ipod.track_index = ipod.tracks.size() - 1
			ipod._remove_current()
		ok(DirAccess.get_files_at(ipod.USER_MUSIC_DIR).is_empty(), "после удаления в папке iPod пусто")
		ipod._select_track(0)
		await wait(0.4)

	# ---- закрытие: всё возвращается ----
	await tap(KEY_UP)
	await wait(0.2)
	ok(not ipod.opened and ipod.captures_gameplay_input(), "пока iPod уезжает, удары ещё заблокированы")
	await wait(1.6)
	ok(not ipod.captures_gameplay_input() and not ipod.device.visible, "↑ закрывает iPod")
	ok(Input.mouse_mode == mouse0, "режим мыши вернулся")
	ok(game.ipod_focus < 0.01 and not game.cam_attributes.dof_blur_far_enabled, "расфокус снят")
	ok(absf(game.spring.spring_length - len0) < 0.12, "камера вернулась: %.2f (было %.2f)" % [game.spring.spring_length, len0])
	ok(game.hud_root.modulate.a > 0.99, "HUD снова яркий")
	ok(audio.ipod_focus < 0.02 and audio.ipod_lowpass.cutoff_hz > 21000.0 and audio.ipod_reverb.wet < 0.01, "музыка локации снова чистая")
	ok(ipod.player.playing and ipod.reverb.wet < 0.02, "трек iPod играет дальше без реверберации")
	print("IPOD уровни, iPod закрыт и играет: IPod %.1f дБ, Music %.1f дБ — звучат одновременно" % [peak("IPod"), peak("Music")])
	p0 = pl.global_position
	key(KEY_S)
	await wait(0.5)
	key(KEY_S, false)
	await wait(0.2)
	ok(pl.global_position.distance_to(p0) > 0.3, "после iPod Пахан снова бегает (%.2f м)" % pl.global_position.distance_to(p0))
	mouse(MOUSE_BUTTON_LEFT, vs * 0.4)
	await wait(0.12)
	mouse(MOUSE_BUTTON_LEFT, vs * 0.4, false)
	ok(pl.state == "attack", "после iPod ЛКМ бьёт балоном (состояние «%s»)" % pl.state)
	await wait(1.4)
	await tap(KEY_SPACE)
	ok(pl.state == "roll", "после iPod Пробел — перекат (состояние «%s»)" % pl.state)
	await wait(1.0)
	await shot("ipod_6_closed.png")

	# ---- быстрые нажатия ----
	for i in 6:
		await tap(KEY_UP, 0.03)
	await wait(1.6)
	ok(not ipod.opened and not ipod.captures_gameplay_input() and not ipod.device.visible, "шесть быстрых нажатий ↑: iPod закрыт, ввод свободен")
	ok(Input.mouse_mode == mouse0 and game.ipod_focus < 0.01 and absf(game.spring.spring_length - len0) < 0.12, "после быстрых нажатий камера и мышь на месте")
	for i in 5:
		await tap(KEY_UP, 0.03)
	await wait(1.4)
	ok(ipod.opened and ipod.device.visible and game.ipod_focus > 0.98, "пять быстрых нажатий ↑: iPod открыт")
	await tap(KEY_UP)
	await wait(1.4)

	# ---- пауза игры ----
	var tp: float = ipod.player.get_playback_position()
	game.set_paused(true)
	await wait(1.3)
	ok(absf(ipod.mix_volume - ipod.volume * 0.3) < 0.04, "в паузе трек приглушён (%.2f)" % ipod.mix_volume)
	ok(ipod.player.get_playback_position() > tp, "в паузе позиция трека не сбрасывается (%.1f → %.1f с)" % [tp, ipod.player.get_playback_position()])
	await tap(KEY_UP)
	await wait(0.3)
	ok(not ipod.opened, "в паузе iPod не открывается")
	game.set_paused(false)
	await wait(1.0)
	ok(absf(ipod.mix_volume - ipod.volume) < 0.05 and Input.mouse_mode == mouse0, "после паузы громкость и мышь вернулись")

	# ---- сохранение и восстановление (только если своей библиотеки ещё нет — чужое не трогаем) ----
	if FileAccess.file_exists(ipod.SETTINGS_PATH):
		print("IPOD пропуск: у игрока уже есть сохранение iPod, запись на диск не проверялась")
	else:
		ipod.persistence_enabled = true
		ipod.volume = 0.45
		ipod.repeat_mode = 2
		ipod.bass_boost = 0.35
		ipod.player.seek(20.0)
		await wait(0.2)
		ipod._save_settings()
		ok(FileAccess.file_exists(ipod.SETTINGS_PATH), "настройки записаны на диск")
		ipod.persistence_enabled = false
		var second = load("res://scripts/ipod.gd").new()
		second.game = game
		add_child(second)
		await wait(0.3)
		ok(absf(second.volume - 0.45) < 0.001 and second.repeat_mode == 2 and absf(second.bass_boost - 0.35) < 0.001, "громкость, Repeat и Bass Boost восстановлены")
		ok(second.track_index == 0 and second.player.get_playback_position() > 19.0 and second.player.stream_paused, "трек и место восстановлены (%.1f с, на паузе)" % second.player.get_playback_position())
		second.persistence_enabled = false
		second.queue_free()
		await wait(0.2)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ipod.SETTINGS_PATH))

	print("IPOD итог: ошибок %d" % fails)
	get_tree().quit()
