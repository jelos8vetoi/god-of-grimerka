## Автопроверка iPod: `-- --ipodcheck=<папка>`. Жмёт настоящие клавиши и кнопки мыши, снимает кадры в папку
## и печатает строки «IPOD ok / IPOD ОШИБКА». Если в папке лежат test.mp3 и test.wav — проверяет ещё и импорт.
## Форматы импорта (M4A AAC/ALAC, M4B, AIFF, FLAC, WAV, отказы DRM/WMA/Opus) — всегда, на своих файлах (formats_block).
## Звук на время проверки заглушён на общей шине: уровни меряются по шинам, слушать ничего не нужно.
extends Node

var game
var out := ""
var fails := 0
var pause_only := false    # --pause: меню паузы и режим наушников
var buds_only := false     # --buds: наушники EarPods
var hand_only := false
var as_madk := false       # --madk: всё то же, но за madk1d (его тело и свой iPod)
var view_seq := 1
var strip: Array = []      # кадры раскадровки для общего листа          # с какой из четырёх сторон снимать раскадровку     # --hand: только рука, карман, взгляд и связь с интерфейсом
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
	if as_madk:
		var nd := 0
		while game.mode == "dlg" and nd < 200:
			await tap(KEY_ENTER, 0.04)
			nd += 1
		game.tag.tag_cd = 0.0
		game.swap_heroes()
		await wait(1.2)
		ok(pl.hero == "madk1d" and pl.pod == pl.heroes["madk1d"]["pod"] and pl.pod != pl.heroes["pahan"]["pod"], "за madk1d — свой iPod на его скелете")
	if hand_only:
		await _run_hand()
		return
	if buds_only:
		await _run_buds()
		return
	if pause_only:
		AudioServer.set_bus_mute(0, false)
		await _run_pause()
		return

	# ---- шины: эффекты iPod не должны задевать голос, эффекты и окружение ----
	ok(AudioServer.get_bus_index("IPod") >= 0 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("IPod")) == 4, "шина IPod: фильтр, эквалайзер баса, реверберация, ограничитель")
	# на SFX стоит только общий ограничитель громкости (audio.gd, ради криков мини-игр) — эффекты iPod её не задевают
	for b in ["Voice", "SFX", "Ambient"]:
		var bi := AudioServer.get_bus_index(b)
		var bad := 0
		for k in AudioServer.get_bus_effect_count(bi):
			if not (AudioServer.get_bus_effect(bi, k) is AudioEffectHardLimiter):
				bad += 1
		ok(bad == 0, "шина %s без эффектов iPod (только ограничитель громкости)" % b)
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
	var mouse0 := MouseMode.want

	# ---- открытие ----
	await tap(KEY_UP)
	await wait(2.0)
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
	ok(pl.is_on_floor() and ipod.player.stream_paused != was_paused, "Пробел — пауза трека, а не прыжок")
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
		await import_done()
		await wait(0.3)
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

	await formats_block()

	# ---- закрытие: всё возвращается ----
	await tap(KEY_UP)
	await wait(0.2)
	ok(not ipod.opened and ipod.captures_gameplay_input(), "пока iPod уезжает, удары ещё заблокированы")
	await wait(2.2)
	ok(not ipod.captures_gameplay_input() and not ipod.device.visible, "↑ закрывает iPod")
	ok(MouseMode.want == mouse0, "режим мыши вернулся")
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
	ok(pl.velocity.y > 0.5 or not pl.is_on_floor(), "после iPod Пробел — прыжок (состояние «%s»)" % pl.anim.state)
	await wait(1.0)
	await shot("ipod_6_closed.png")

	# ---- быстрые нажатия ----
	for i in 6:
		await tap(KEY_UP, 0.03)
	await wait(2.4)
	ok(not ipod.opened and not ipod.captures_gameplay_input() and not ipod.device.visible, "шесть быстрых нажатий ↑: iPod закрыт, ввод свободен")
	ok(MouseMode.want == mouse0 and game.ipod_focus < 0.01 and absf(game.spring.spring_length - len0) < 0.12, "после быстрых нажатий камера и мышь на месте")
	for i in 5:
		await tap(KEY_UP, 0.03)
	await wait(2.2)
	ok(ipod.opened and ipod.device.visible and game.ipod_focus > 0.98, "пять быстрых нажатий ↑: iPod открыт")
	await tap(KEY_UP)
	await wait(2.2)

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
	ok(absf(ipod.mix_volume - ipod.volume) < 0.05 and MouseMode.want == mouse0, "после паузы громкость и мышь вернулись")

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

# ---------------- рука, карман, взгляд (--hand) ----------------
## Кадр с героем крупно: вырезка вокруг груди, увеличенная вдвое.
func pose_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var c: Vector2 = get_viewport().get_final_transform() * game.cam.unproject_position(pl.global_position + Vector3(0, 0.25, 0))
	var r := Rect2i(Vector2i(c) - Vector2i(230, 250), Vector2i(460, 460)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		img.save_png(out.path_join(name))
		return
	var z := img.get_region(r)
	if name == "":
		strip.append(z.get_region(Rect2i(60, 60, 340, 340)))
		return
	z.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_LANCZOS)
	z.save_png(out.path_join(name))

## Угол между направлением лица и направлением от глаз к центру экрана устройства, рад.
func look_error() -> float:
	return float(pl.pod.dbg["look"])   # меряется внутри слоя анимации: снаружи скелет отдаёт позу без него

## Расстояние от центра кулака до устройства (до точки, за которую его держат), в единицах скелета.
func grip_gap() -> float:
	return float(pl.pod.dbg["gap"])

func _run_hand() -> void:
	var pod = pl.pod
	var sk: Skeleton3D = pl.rig.skel
	var n := 0
	while game.mode == "dlg" and n < 200:
		await tap(KEY_ENTER, 0.04)
		n += 1
	await wait(1.2)
	ok(sk.find_children("PodDevice", "Node3D", false, false).size() == 1, "физический iPod один")
	ok(pod.state == pod.St.STOWED and not pod.device.visible, "в покое iPod в кармане и не виден")
	game.buddy.visible = false   # кент ходит рядом и заслоняет героя на проверочных кадрах
	var face0: float = pl.face
	var yaw0: float = game.cam_yaw
	# поза и доставание iPod проверяются с уже надетыми наушниками (как при повторном открытии);
	# само надевание — в проверке --buds
	pod.set_seated(true)

	# ---- поза просмотра с четырёх сторон, без интерфейса ----
	pl.pod_force = true
	await wait(2.2)
	ok(pod.state == pod.St.INSPECTING, "состояние просмотра: %s" % pod.state_name())
	print("IPOD взгляд: лицо отклонено от центра экрана на %.0f° (остальное — глазами: у головы ограничен наклон)" % rad_to_deg(look_error()))
	ok(grip_gap() < 0.004, "iPod сидит в кулаке: зазор %.4f" % grip_gap())
	ok(float(pod.dbg["reach"]) < 0.97, "рука дотягивается с согнутым локтем: вытянута на %.0f%%" % (100.0 * float(pod.dbg["reach"])))
	for i in 4:
		game.cam_yaw = yaw0 + i * PI * 0.5
		game.cam_pitch = -0.18
		await wait(0.5)
		await pose_shot("hand_view_%d.png" % i)
	# дыхание: за две секунды кисть должна немного сдвинуться
	var w0: Vector3 = pod.device.transform.origin
	var moved := 0.0
	for i in 20:
		await wait(0.1)
		moved = max(moved, (pod.device.transform.origin as Vector3).distance_to(w0))
	ok(moved > 0.0008 and moved < 0.02, "живая поза: кисть движется в пределах %.4f" % moved)
	pl.pod_force = false
	await wait(1.6)
	ok(pod.state == pod.St.STOWED and not pod.device.visible, "убран в карман: %s" % pod.state_name())
	ok(absf(angle_difference(pl.face, face0)) < 0.05, "герой повернулся обратно")

	# ---- раскадровка: достать и убрать ----
	game.cam_yaw = yaw0
	await wait(0.5)
	var seen := {}
	var far := 0.0
	var jump := 0.0
	var prev := Vector3.ZERO
	var prev_ms := 0
	pl.pod_force = true
	await get_tree().process_frame
	await get_tree().process_frame
	game.cam_yaw = yaw0 + view_seq * PI * 0.5   # герой уже выбрал, куда повернуться; снимаем его спереди
	for f in 24:
		await wait(0.03)
		seen[pod.state_name()] = true
		far = max(far, float(pod.dbg["reach"]))
		if pod.device.visible:
			var dp: Vector3 = pod.device.transform.origin
			if prev != Vector3.ZERO:
				jump = max(jump, dp.distance_to(prev) / max(0.016, (Time.get_ticks_msec() - prev_ms) * 0.001))
			prev = dp
			prev_ms = Time.get_ticks_msec()
		await pose_shot("")
	await wait(0.5)
	seen[pod.state_name()] = true
	await pose_shot("")
	pl.pod_force = false
	for f in 18:
		await wait(0.03)
		seen[pod.state_name()] = true
		if pod.device.visible:
			var dp2: Vector3 = pod.device.transform.origin
			jump = max(jump, dp2.distance_to(prev) / max(0.016, (Time.get_ticks_msec() - prev_ms) * 0.001))
			prev = dp2
			prev_ms = Time.get_ticks_msec()
		await pose_shot("")
	await wait(0.6)
	_sheet("hand_sheet.png", 6)
	for st in pod.NAMES:
		ok(seen.has(st) or st == "STOWED", "пройдено состояние %s" % st)
	ok(far < 1.0, "рука всюду дотягивается: наибольшая вытянутость %.0f%%" % (100.0 * far))
	# повторное открытие (наушники уже в ушах) идёт 0.8 с вместо 1.25 — порог скорости больше во столько же
	ok(jump < 2.4, "устройство не телепортируется: наибольшая скорость %.2f ед./с (весь путь ≈ 0.25 ед.)" % jump)

	# ---- настоящее открытие клавишей: связь руки и интерфейса ----
	game.cam_yaw = yaw0
	game.cam_pitch = -0.32
	await wait(0.6)
	await tap(KEY_UP)
	for f in 10:
		await wait(0.2)
		await shot("hand_ui_%d.png" % f)
	await wait(1.0)
	ok(ipod.opened and ipod.emerge >= 1.0 and pod.state == pod.St.INSPECTING, "↑: iPod в руке, интерфейс на месте (появление %.2f, состояние %s)" % [ipod.emerge, pod.state_name()])
	print("IPOD взгляд с интерфейсом: %.0f°" % rad_to_deg(look_error()))
	var dev := device_rect()
	var body: Rect2 = ipod._pahan_protected_rect(get_viewport().get_visible_rect().size)
	ok(not dev.intersects(body), "интерфейс не перекрывает Пахана")
	var pr: int = pod.presses
	await tap(KEY_S)
	ok(pod.presses > pr, "нажатие на колесо двигает большой палец")
	await tap(KEY_UP)
	for f in 4:
		await wait(0.2)
		await shot("hand_ui_close_%d.png" % f)
	await wait(1.4)
	ok(pod.state == pod.St.STOWED and not ipod.captures_gameplay_input(), "↑: iPod в кармане, управление свободно")

	# ---- быстрые нажатия ----
	for i in 7:
		await tap(KEY_UP, 0.03)
		ok(sk.find_children("PodDevice", "Node3D", false, false).size() == 1, "нажатие %d: устройство одно, состояние %s" % [i + 1, pod.state_name()])
	await wait(2.4)
	ok(ipod.opened and pod.state == pod.St.INSPECTING, "после семи быстрых нажатий iPod открыт и в руке")
	await tap(KEY_UP)
	await wait(0.5)
	await tap(KEY_UP)
	await wait(0.3)
	await tap(KEY_UP)
	await wait(2.4)
	ok(not ipod.opened and pod.state == pod.St.STOWED and not ipod.captures_gameplay_input(), "отмена на полпути: iPod в кармане, ввод свободен")
	ok(absf(angle_difference(pl.face, face0)) < 0.05, "после всего герой смотрит туда же, куда раньше (%.2f и %.2f)" % [pl.face, face0])
	var p0: Vector3 = pl.global_position
	key(KEY_S)
	await wait(0.5)
	key(KEY_S, false)
	ok(pl.global_position.distance_to(p0) > 0.3, "герой снова бегает")
	mouse(MOUSE_BUTTON_LEFT, Vector2(300, 300))
	await wait(0.12)
	mouse(MOUSE_BUTTON_LEFT, Vector2(300, 300), false)
	ok(pl.state == "attack", "герой снова бьёт балоном")
	await wait(0.5)
	await pose_shot("hand_after_attack.png")
	print("IPOD итог: ошибок %d" % fails)
	get_tree().quit()

## Лист раскадровки: все кадры из strip сеткой, слева направо, сверху вниз.
func _sheet(name: String, cols: int) -> void:
	if strip.is_empty():
		return
	var w: int = (strip[0] as Image).get_width()
	var h: int = (strip[0] as Image).get_height()
	var rows := int(ceil(strip.size() / float(cols)))
	var img := Image.create(w * cols, h * rows, false, (strip[0] as Image).get_format())
	for i in strip.size():
		img.blit_rect(strip[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	img.save_png(out.path_join(name))
	strip.clear()

# ---------------- EarPods (--buds) ----------------
## Кадр с головой и руками крупно: вырезка вокруг точки на высоте h над ногами героя. name == "" — в лист раскадровки.
func head_shot(name: String, h := 1.15, size := 300) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var c: Vector2 = get_viewport().get_final_transform() * game.cam.unproject_position(pl.global_position + Vector3(0, h, 0))
	var r := Rect2i(Vector2i(c) - Vector2i(size / 2, size / 2), Vector2i(size, size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		return
	var z := img.get_region(r)
	if name == "":
		strip.append(z)
		return
	z.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_LANCZOS)
	z.save_png(out.path_join(name))

## Крупный план отдельной камерой (в тесном подъезде камера игры упирается в стены).
## ang — откуда смотреть: 0 — спереди, +PI/2 — с правого бока героя, −PI/2 — с левого.
func close_shot(name: String, ang: float, dist := 0.95, h := 1.35) -> void:
	var c := Camera3D.new()
	c.fov = 32.0
	c.near = 0.02
	get_tree().root.add_child(c)
	var f := Vector3(sin(pl.face), 0, cos(pl.face))
	var rgt := Vector3(-cos(pl.face), 0, sin(pl.face))
	var tgt: Vector3 = pl.global_position + Vector3(0, h, 0)
	c.global_position = tgt + (f * cos(ang) + rgt * sin(ang)) * dist + Vector3(0, 0.12, 0)
	c.look_at(tgt)
	c.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var hh := img.get_height()
	img.get_region(Rect2i(w / 2 - hh / 2, 0, hh, hh)).save_png(out.path_join(name))
	game.cam.make_current()
	c.queue_free()

## Расстояние от вкладыша до его места в ухе, единицы скелета.
func ear_gap(side: String) -> float:
	var pod = pl.pod
	var sk: Skeleton3D = pl.rig.skel
	var want: Transform3D = sk.get_bone_global_pose(pod.b_head) * (pod.ear_xf[side] as Transform3D)
	return (pod.buds.buds[side] as Node3D).transform.origin.distance_to(want.origin)

func count_buds() -> int:
	return pl.rig.skel.find_children("EarPods", "Node3D", false, false).size()

## Следит за скачками: телепорт — шаг за кадр, который намного больше соседних (обычное движение разгоняется плавно).
## track_max — наибольшее отношение шага к предыдущему среди шагов длиннее 0.012 единицы.
var track_prev := {}
var track_max := 0.0
var track_where := ""
var tracking := false
func _track_frame() -> void:
	if tracking:
		track()

func track(reset := false) -> void:
	var pod = pl.pod
	if reset:
		track_prev.clear()
		track_max = 0.0
		track_where = ""
	for key in ["L", "R", "dev"]:
		var node: Node3D = pod.device if key == "dev" else pod.buds.buds[key]
		if not node.visible:
			track_prev.erase(key)
			continue
		var p: Vector3 = node.transform.origin
		if track_prev.has(key):
			# шаг на секунду кадра (слой анимации ограничивает кадр 0.05 с): долгий кадр на сохранении снимка — не скачок
			var st: float = p.distance_to(track_prev[key][0]) / clampf(get_process_delta_time(), 0.004, 0.05) * 0.0083
			var last: float = track_prev[key][1]
			if last >= 0.0 and st > 0.012 and st / max(0.003, last) > track_max:   # первый шаг после появления не с чем сравнить
				track_max = st / max(0.003, last)
				track_where = "%s a=%.3f b=%.3f u=%.3f шаг %.4f после %.4f" % [key, pod.a, pod.b, pod.u, st, last]
			track_prev[key] = [p, st]
		else:
			track_prev[key] = [p, -1.0]

func _run_buds() -> void:
	var pod = pl.pod
	var sk: Skeleton3D = pl.rig.skel
	var n := 0
	while game.mode == "dlg" and n < 200:
		await tap(KEY_ENTER, 0.04)
		n += 1
	await wait(1.2)
	game.buddy.visible = false
	var yaw0: float = game.cam_yaw
	ok(count_buds() == 1, "EarPods один комплект")
	ok(pod.buds_state() == "STORED" and not pod.buds.visible, "в начале наушники убраны вместе с iPod")
	var orig: Transform3D = pl.rig.weapon.transform
	# замер скачков — ровно раз за кадр, после всей обработки, независимо от пауз проверки на снимки
	RenderingServer.frame_pre_draw.connect(_track_frame)

	# ---- первое открытие: достать iPod и надеть оба вкладыша ----
	pl.pod_force = true
	await get_tree().process_frame
	await get_tree().process_frame
	game.cam_yaw = yaw0 + PI * 0.5
	game.cam_pitch = -0.12
	var seen := []
	var miss_r := 0.0
	var miss_l := 0.0
	var reach_r := 0.0
	var gaps_l := 0.0
	track(true)
	tracking = true
	var t0 := Time.get_ticks_msec()
	var shots := 0
	var marks := {}
	while not pod.buds_in() and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
		var st: String = pod.buds_state()
		if seen.is_empty() or seen.back() != st:
			seen.append(st)
		miss_r = max(miss_r, float(pod.dbg["miss_r"]))
		miss_l = max(miss_l, float(pod.dbg["miss_l"]))
		reach_r = max(reach_r, float(pod.dbg["reach_r"]))
		for m in [["a", 0.18, "buds_1_grab_r"], ["a", 0.42, "buds_2_to_ear_r"], ["a", 0.47, "buds_3_in_ear_r"], ["a", 0.66, "buds_4_take_l"], ["a", 0.75, "buds_5_give_l"], ["b", 0.4, "buds_6_to_ear_l"], ["b", 0.63, "buds_7_in_ear_l"]]:
			var v: float = pod.a if m[0] == "a" else pod.b
			if v >= float(m[1]) and not marks.has(m[2]):
				marks[m[2]] = true
				await close_shot(String(m[2]) + "_q.png", (0.75 if m[0] == "a" else -0.75), 3.0, 1.0)   # спереди-справа для правой руки, спереди-слева для левой
				await head_shot(String(m[2]) + ".png", 1.25, 300)
		if pod.u >= 1.0 and (Time.get_ticks_msec() - t0) > shots * 160:
			shots += 1
			await head_shot("", 1.15, 300)
	if seen.back() != pod.buds_state():
		seen.append(pod.buds_state())
	print("IPOD наушники: последовательность состояний ", seen)
	ok(pod.buds_in(), "оба вкладыша надеты")
	for st in ["FIRST_GOING_IN", "FIRST_IN", "SECOND_GOING_IN", "BOTH_IN"]:
		ok(st in seen, "пройдено состояние наушников %s" % st)
	ok(seen.find("FIRST_IN") < seen.find("SECOND_GOING_IN"), "вкладыши вставляются по очереди")
	ok(reach_r < 1.0, "правая рука дотягивается: вытянута максимум на %.0f%%" % (100.0 * reach_r))
	ok(miss_r < 0.01, "щепоть правой руки там, где вкладыш: промах %.4f" % miss_r)
	ok(track_max < 3.0, "вкладыши и iPod без скачков: наибольший всплеск шага ×%.1f (%s)" % [track_max, track_where])
	_sheet("buds_on_sheet.png", 8)
	await wait(0.6)
	await head_shot("buds_on_front.png", 1.2, 320)
	await close_shot("buds_on_close_r.png", 0.6, 3.0, 1.0)
	await close_shot("buds_on_close_l.png", -0.6, 3.0, 1.0)
	game.cam_yaw = yaw0 + PI * 0.25
	await wait(0.4)
	await head_shot("buds_on_right.png", 1.2, 320)
	game.cam_yaw = yaw0 + PI * 0.75
	await wait(0.4)
	await head_shot("buds_on_left.png", 1.2, 320)

	# ---- закрыть: iPod в карман, наушники остаются, провод к карману ----
	pl.pod_force = false
	await wait(2.2)
	ok(pod.u <= 0.0 and pod.device_state() == "IN_POCKET", "iPod убран в карман")
	ok(pod.buds_in() and pod.buds.visible and pod.buds.cable.visible, "наушники остались в ушах, провод виден")
	ok(not pod.balloon_free and pl.rig.weapon.transform.is_equal_approx(orig), "балон снова в кулаке, как был")
	ok(pod.buds.split_pos.distance_to(sk.get_bone_global_pose(pod.b_sp2) * pod.split_l) < 0.06, "разветвитель на груди")
	game.cam_yaw = yaw0 + PI * 0.5
	await wait(0.4)
	await head_shot("buds_closed.png", 0.95, 420)
	await close_shot("buds_ear_right.png", PI * 0.5, 2.0, 1.2)
	await close_shot("buds_ear_left.png", -PI * 0.5, 2.0, 1.2)
	await close_shot("buds_ear_front.png", 0.0, 2.4, 1.1)
	await close_shot("buds_ear_back_r.png", PI * 0.75, 2.4, 1.1)
	game.cam_pitch = -0.12
	# бег с наушниками: крепления держатся
	var gmax := 0.0
	key(KEY_W)
	for i in 12:
		await wait(0.05)
		gmax = max(gmax, max(ear_gap("L"), ear_gap("R")))
	await head_shot("buds_run.png", 0.95, 420)
	key(KEY_W, false)
	await wait(0.5)
	ok(gmax < 0.001, "на бегу вкладыши держатся в ушах (отклонение %.4f)" % gmax)

	# ---- повторное открытие: только достаёт iPod ----
	var min_ab := 1.0
	pl.pod_force = true
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
		min_ab = min(min_ab, min(pod.a, pod.b))
	ok(min_ab >= 1.0 and pod.u >= 1.0 and not pod.balloon_free, "повторное открытие не надевает наушники заново")
	pl.pod_force = false
	await wait(2.0)

	# ---- настоящий iPod: музыка играет, пауза не снимает наушники ----
	await tap(KEY_UP)
	await wait(2.2)
	ipod._select_track(0)
	await wait(0.5)
	await tap(KEY_SPACE)
	await wait(0.3)
	ok(ipod.player.stream_paused and pod.buds_in(), "пауза трека не снимает наушники")
	await tap(KEY_SPACE)
	await tap(KEY_UP)
	await wait(2.2)
	ok(ipod.player.playing and not ipod.player.stream_paused and pod.buds_in() and pod.u <= 0.0, "iPod закрыт, музыка играет, наушники в ушах")
	ok(ipod.earbuds_in, "состояние наушников записано в настройки iPod")

	# ---- снятие при убранном iPod: достаёт, снимает, убирает ----
	pod.remove_buds()
	seen.clear()
	track(true)
	tracking = true
	t0 = Time.get_ticks_msec()
	shots = 0
	while (pod.a > 0.0 or pod.b > 0.0 or pod.u > 0.0) and Time.get_ticks_msec() - t0 < 14000:
		await get_tree().process_frame
		var st2: String = pod.buds_state() + "/" + pod.device_state()
		if seen.is_empty() or seen.back() != st2:
			seen.append(st2)
		if pod.u >= 1.0 and (Time.get_ticks_msec() - t0) > shots * 200:
			shots += 1
			await head_shot("", 1.15, 300)
	print("IPOD снятие: ", seen)
	ok(pod.buds_state() == "STORED" and pod.u <= 0.0 and not pod.buds.visible, "наушники сняты и убраны вместе с iPod")
	ok("REMOVING/IN_HAND" in seen, "снимались руками при iPod в руке")
	ok(track_max < 3.0, "снятие без скачков: наибольший всплеск шага ×%.1f (%s)" % [track_max, track_where])
	ok(not pod.balloon_free and pl.rig.weapon.transform.is_equal_approx(orig), "балон в кулаке после снятия")
	_sheet("buds_off_sheet.png", 8)
	await wait(0.3)
	ok(not ipod.earbuds_in, "в настройках: наушники сняты")

	# ---- прерывания ----
	# закрыть, пока первый вкладыш ещё не в ухе: откат
	pl.pod_force = true
	while pod.a < 0.25:
		await get_tree().process_frame
	pl.pod_force = false
	await wait(3.5)
	ok(pod.buds_state() == "STORED" and pod.u <= 0.0 and not pod.balloon_free, "закрытие до первого уха — откат: наушники на проводе, iPod в кармане")
	# закрыть, когда первый уже в ухе: довести до конца
	pl.pod_force = true
	while pod.a < 0.55:
		await get_tree().process_frame
	pl.pod_force = false
	await wait(5.0)
	ok(pod.buds_in() and pod.u <= 0.0 and not pod.balloon_free, "закрытие после первого уха — доводится: оба надеты, iPod в кармане")
	pod.remove_buds()
	await wait(9.0)
	ok(pod.buds_state() == "STORED", "снова сняты")
	# частые нажатия
	for i in 9:
		await tap(KEY_UP, 0.03)
		await wait(0.12)
	ok(count_buds() == 1 and pl.rig.skel.find_children("PodDevice", "Node3D", false, false).size() == 1, "частые нажатия ↑: iPod и наушники по одному")
	await wait(6.0)
	if ipod.opened:
		await tap(KEY_UP)
	await wait(6.0)
	ok(not pod.busy() and not ipod.captures_gameplay_input() and not pod.balloon_free, "после частых нажатий всё успокоилось (%s, %s)" % [pod.buds_state(), pod.device_state()])
	# удар посреди надевания
	if pod.buds_in():
		pod.remove_buds()
		await wait(9.0)
	await tap(KEY_UP)
	while pod.a < 0.3:
		await get_tree().process_frame
	pl.inv = 0.0
	pl.take_damage(1.0, pl.global_position + Vector3(1, 0, 0))
	await wait(3.0)
	ok(not ipod.opened and not pod.busy() and not pod.balloon_free and pod.buds_state() in ["STORED", "BOTH_IN"], "удар посреди надевания: iPod закрыт, наушники %s, руки свободны" % pod.buds_state())
	pl.hp = pl.max_hp
	# гибель посреди надевания: сразу в устойчивое состояние
	await wait(1.0)
	await tap(KEY_UP)
	while pod.a < 0.5:
		await get_tree().process_frame
	ipod.close(true)
	pod.want = false
	pod.snap()
	await get_tree().process_frame
	ok(pod.u <= 0.0 and not pod.balloon_free and pl.rig.weapon.transform.is_equal_approx(orig) and pod.buds_state() in ["STORED", "BOTH_IN"], "гибель: без анимации, балон в кулаке, наушники %s" % pod.buds_state())
	# новая глава: наушники берутся из настроек
	ipod.earbuds_in = true
	pod.set_seated(false)
	pl.pod_synced = false
	await wait(0.3)
	ok(pod.buds_in(), "после новой главы наушники снова в ушах (из настроек iPod)")
	# бой работает
	if ipod.opened:
		await tap(KEY_UP)
		await wait(2.5)
	game.cam_yaw = yaw0
	await wait(0.5)
	mouse(MOUSE_BUTTON_LEFT, Vector2(300, 300))
	await wait(0.12)
	mouse(MOUSE_BUTTON_LEFT, Vector2(300, 300), false)
	ok(pl.state == "attack", "удар балоном работает (состояние «%s»)" % pl.state)
	await wait(0.25)
	await head_shot("buds_attack.png", 0.9, 460)
	await wait(1.0)
	await _run_polish()
	print("IPOD итог: ошибок %d" % fails)
	get_tree().quit()

## Этап 3: звуки, провод, подсветка, отзывчивость, совместимость с боем и защита от ошибок.
func _run_polish() -> void:
	var pod = pl.pod
	var yaw0: float = game.cam_yaw
	if ipod.opened:
		await tap(KEY_UP)
		await wait(2.0)
	# ---- звуки по событиям анимации ----
	var c: Dictionary = pod.sfx.count
	print("IPOD звуки за проверку: ", c)
	for k in ["cloth", "grip", "slide", "bud_touch", "bud_seat", "bud_out", "cable"]:
		ok(int(c.get(k, 0)) > 0, "звук «%s» звучал по событию" % k)
	ok(pod.sfx.get_child_count() == 3 and pod.sfx.players[0].bus == "SFX", "звуки iPod: три плеера на шине SFX (мимо Bass Boost и реверберации)")
	var before: int = int(c.get("grip", 0))
	for i in 6:
		pod.sfx.play("grip")
	ok(int(pod.sfx.count.get("grip", 0)) - before == 1, "быстрые повторы одного звука не наслаиваются")
	# ---- отзывчивость: повторное открытие и закрытие ----
	if not pod.buds_in():
		pod.set_seated(true)
	var t0 := Time.get_ticks_msec()
	pl.pod_force = true
	while pod.u < 1.0 and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	var t_open := (Time.get_ticks_msec() - t0) / 1000.0
	ok(t_open < 1.0 and pod.buds_in(), "повторное открытие с наушниками: %.2f с, наушники не надеваются" % t_open)
	await wait(0.8)
	ok(pod.glow > 0.3, "экран iPod светится в руке (%.2f)" % pod.glow)
	pl.pod_force = false
	t0 = Time.get_ticks_msec()
	while pod.busy() and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	var t_close := (Time.get_ticks_msec() - t0) / 1000.0
	ok(t_close < 1.0, "закрытие: управление свободно через %.2f с" % t_close)
	ok(pod.glow < 0.05, "экран погас в кармане (%.2f)" % pod.glow)
	# подсветка разгорается плавно, без вспышки
	var g_prev := 0.0
	var g_jump := 0.0
	pl.pod_force = true
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1600:
		await get_tree().process_frame
		g_jump = max(g_jump, pod.glow - g_prev)
		g_prev = pod.glow
	ok(g_jump < 0.12, "экран разгорается плавно: наибольший прирост за кадр %.3f" % g_jump)
	pl.pod_force = false
	await wait(1.2)
	# ---- большой палец по типу нажатия ----
	await tap(KEY_UP)
	await wait(1.6)
	var kinds := {}
	for k in [KEY_D, KEY_A, KEY_ESCAPE, KEY_ENTER, KEY_S]:
		await tap(k)
		kinds[pod.tap_kind] = true
		await wait(0.15)
	print("IPOD палец: ", kinds.keys())
	ok(kinds.has("next") and kinds.has("previous") and kinds.has("menu") and kinds.has("select") and kinds.has("scroll"), "большой палец отвечает на next / previous / menu / select / scroll")
	ok(pod.u >= 1.0 and ipod.opened, "колесо листается, не дожидаясь анимаций (iPod открыт)")
	# ---- фокус кадра идёт за рукой ----
	await tap(KEY_UP)
	await wait(1.6)
	ok(game.ipod_focus < 0.01 and not game.cam_attributes.dof_blur_far_enabled and game.hud_root.modulate.a > 0.99, "после закрытия размытие и затемнение сняты")
	var f_mid := -1.0
	await tap(KEY_UP)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await get_tree().process_frame
		if f_mid < 0.0 and pod.u > 0.3 and pod.u < 0.5:
			f_mid = game.ipod_focus
	ok(f_mid > 0.0 and f_mid < 0.6 and game.ipod_focus > 0.95, "фокус растёт вместе с подъёмом руки (на полпути %.2f, в конце %.2f)" % [f_mid, game.ipod_focus])
	for i in 3:
		await tap(KEY_UP)
		await wait(0.25)
	await tap(KEY_UP)
	await wait(1.6)
	if ipod.opened:
		await tap(KEY_UP)
		await wait(1.6)
	ok(game.ipod_focus < 0.01 and game.hud_root.modulate.a > 0.99, "серия открытий: размытие и затемнение не накапливаются")
	# ---- провод: раскачка на бегу и затухание после остановки ----
	game.cam_yaw = yaw0
	await wait(0.5)
	var sway_run := 0.0
	var sway_step := 0.0
	var prev_off: Vector3 = pod.buds.dyn[1]["off"]      # от текущего положения: от нуля первый же кадр выглядел бы скачком
	for k in [KEY_W, KEY_S, KEY_A, KEY_D]:   # пробежки в разные стороны: подъезд тесный, в одну сторону можно сразу упереться в стену
		key(k)
		var tk := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tk < 450:
			await get_tree().process_frame
			var o: Vector3 = pod.buds.dyn[1]["off"]
			sway_step = max(sway_step, o.distance_to(prev_off) / clampf(get_process_delta_time(), 0.004, 0.05) * 0.0083)
			prev_off = o
			sway_run = max(sway_run, pod.buds.sway())
		key(k, false)
	await head_shot("polish_run.png", 0.95, 420)
	var sway_stop := 0.0
	for i in 4:                      # сохранение снимка подвешивает кадр — провод догоняет его за один шаг: это не дрожь
		await get_tree().process_frame
	prev_off = pod.buds.dyn[1]["off"]
	for i in 30:
		await get_tree().process_frame
		var o2: Vector3 = pod.buds.dyn[1]["off"]
		sway_step = max(sway_step, o2.distance_to(prev_off) / clampf(get_process_delta_time(), 0.004, 0.05) * 0.0083)
		prev_off = o2
	await wait(2.0)
	sway_stop = pod.buds.sway()
	ok(sway_run > 0.004, "на бегу провод раскачивается (до %.3f)" % sway_run)
	ok(sway_stop < 0.004, "после остановки успокаивается (%.4f)" % sway_stop)
	ok(sway_step < 0.012, "без дрожи: наибольший шаг смещения за кадр (при 120 к/с) %.4f" % sway_step)
	# ---- бой с наушниками: перекат, блок, удар ----
	await tap(KEY_SHIFT)      # перекат — Shift (пробел — прыжок)
	ok(pl.state == "roll" and pod.buds_in(), "перекат с наушниками")
	await wait(1.0)
	key(KEY_C)                # блок — C
	await wait(0.4)
	ok(pl.state == "block", "блок с наушниками (состояние «%s»)" % pl.state)
	key(KEY_C, false)
	await wait(0.4)
	# ---- смена размера окна и потеря фокуса посреди надевания ----
	pod.remove_buds()
	await wait(9.0)
	await tap(KEY_UP)
	while pod.a < 0.3:
		await get_tree().process_frame
	get_window().size = Vector2i(1024, 600)
	ipod.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait(0.4)
	ipod.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	get_window().size = Vector2i(1280, 720)
	while not pod.buds_in() and pod.a > 0.0:
		await get_tree().process_frame
	await wait(0.5)
	var dev_r: Rect2 = device_rect()
	ok(pod.buds_in() and ipod.opened and Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(dev_r), "окно меняло размер и теряло фокус — надевание закончено, интерфейс на экране")
	# переключение трека посреди анимации
	await tap(KEY_UP)
	await wait(0.2)
	await tap(KEY_UP)
	await tap(KEY_D)
	await wait(2.0)
	ok(pod.busy() == false or pod.u >= 1.0, "переключение трека во время анимации ничего не ломает")
	if ipod.opened:
		await tap(KEY_UP)
		await wait(1.6)
	# ---- настоящая гибель во время просмотра и возрождение ----
	await tap(KEY_UP)
	await wait(1.4)
	game.tag.down[game.tag.mate()] = true      # напарник выбыл: иначе Tag Team сменит героя и гибели не будет
	pl.inv = 0.0
	pl.take_damage(pl.hp + 50.0, pl.global_position + Vector3(1, 0, 0))
	await wait(0.2)
	ok(pl.state == "dead" and not ipod.opened and pod.u <= 0.0 and not pod.balloon_free and not pod.device.visible, "гибель во время просмотра: iPod сразу в кармане, руки свободны")
	ok(pod.buds_in() and pod.buds.visible, "наушники при гибели остались в ушах")
	await wait(2.6)
	# в обычной игре здесь окно «Пахан упал» и кнопка «Ещё раз» — жмём её
	game._retry()
	game.tag.down[game.tag.mate()] = false
	await wait(0.6)
	ok(pl.state == "move" and not game.over, "возрождение")
	var nn := 0
	while game.mode == "dlg" and nn < 200:   # глава начинает шаг заново — с разговора
		await tap(KEY_ENTER, 0.04)
		nn += 1
	await wait(1.2)
	await tap(KEY_UP)
	await wait(1.4)
	ok(ipod.opened and pod.u >= 1.0 and pod.buds_in(), "после возрождения iPod открывается, наушники на месте (открыт %s, u %.2f, наушники %s, панель %s, пауза %s, игра окончена %s)" % [ipod.opened, pod.u, pod.buds_state(), game.panel != null, get_tree().paused, game.over])
	await tap(KEY_UP)
	await wait(1.4)
	# ---- без своих файлов: только встроенный трек ----
	var only_builtin: bool = ipod.tracks.all(func(t): return not bool(t.get("local", false)))
	ok(only_builtin and ipod.tracks.size() >= 1, "без пользовательских файлов библиотека работает (%d трек)" % ipod.tracks.size())
	ok(count_buds() == 1 and pl.rig.skel.find_children("PodDevice", "Node3D", false, false).size() == 1, "в конце: по одному iPod и комплекту наушников")
	ok(pod.sfx.get_child_count() == 3, "звуковые плееры не размножились")
	ok(pod.buds.im.get_surface_count() <= 1, "геометрия провода пересобирается, а не копится (%d поверхн.)" % pod.buds.im.get_surface_count())

# ---------------- меню паузы и режим наушников (--pause) ----------------
## Короткий тестовый звук (8 с, тон 330 Гц) — чтобы проверке паузы было что импортировать и куда переключать трек
func _write_test_wav(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var rate := 22050
	var n := rate * 8
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env: float = clampf(t * 8.0, 0.0, 1.0) * clampf((8.0 - t) * 8.0, 0.0, 1.0)
		data.encode_s16(i * 2, int(sin(t * TAU * 330.0) * env * 9000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.save_to_wav(path)

func bus_db(b: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b))

## Импорт идёт в своём потоке: ждём конца (не дольше sec)
func import_done(sec := 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while ipod.importing() and Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func full_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))

func _run_pause() -> void:
	var pm = game.pause_panel
	var n := 0
	while game.mode == "dlg" and n < 200:
		await tap(KEY_ENTER, 0.04)
		n += 1
	await wait(1.2)
	# второй трек нужен для «Следующий» на странице «Музыка»: с одним встроенным переключать некуда.
	# test.wav в папке проверки клали руками; нет его — пишем свой короткий звук
	if not FileAccess.file_exists(out.path_join("test.wav")):
		_write_test_wav(out.path_join("test.wav"))
	for f in ["test.wav"]:
		if FileAccess.file_exists(out.path_join(f)):
			ipod._import_files(PackedStringArray([out.path_join(f)]))
			await import_done()
	ok(ipod.tracks.size() >= 2, "для проверки паузы в плеере не меньше двух треков (%d)" % ipod.tracks.size())
	await wait(0.3)
	ipod.repeat_mode = ipod.RepeatMode.ONE      # тестовый трек короткий: один и тот же по кругу (ALL уводил на следующий — трек «сам переключался»)
	ipod._select_track(0)
	ipod.player.stop()
	ipod.player.stream_paused = false
	await wait(0.8)
	await full_shot("pause_0_game.png")

	# ---- звук 1: iPod молчит — обычный микс ----
	var vol0: Dictionary = audio.vol.duplicate()
	var sfx0 := bus_db("SFX")
	var amb0 := bus_db("Ambient")
	var voice0 := bus_db("Voice")
	ok(audio.headphone < 0.01 and sfx0 > -20.0 and amb0 > -20.0, "iPod молчит: обычный микс (SFX %.1f, Ambient %.1f, Voice %.1f дБ)" % [sfx0, amb0, voice0])

	# ---- пауза клавишей Esc: открытие слоями ----
	var pos0: Vector3 = pl.global_position
	await tap(KEY_ESCAPE)
	ok(get_tree().paused and pm.is_open, "Esc: игра остановлена сразу, меню открывается")
	await wait(0.12)
	await full_shot("pause_1_opening.png")
	await wait(0.75)
	ok(pm.state == "open" and pm.cam_taken, "через 0,9 с камера наехала на Пахана, меню открыто")
	var all_in := true
	for l in pm.layers:
		all_in = all_in and (l[0] as CanvasItem).modulate.a > 0.98
	ok(all_in, "все слои интерфейса раскрылись")
	await full_shot("pause_2_open.png")
	# клавиши: S — вниз по вкладкам, Enter — открыть, Esc — назад, Esc — закрыть
	var s0: int = pm.sel
	await tap(KEY_S)
	ok(pm.sel == (s0 + 1) % 6, "S переключает вкладку")
	await tap(KEY_ENTER)
	await wait(0.2)
	ok(pm.card != null, "Enter открывает страницу")
	await tap(KEY_ESCAPE)
	await wait(0.2)
	ok(pm.card == null and pm.is_open and get_tree().paused, "Esc со страницы — назад к вкладкам, пауза остаётся")
	for i in 6:
		pm._select(i, false)
		pm._open_page(i)
		await wait(0.35)
		await full_shot("pause_tab_%d.png" % i)
		pm._close_card()
	# ---- развитие: покупка не двигает сюжет и не лечит ----
	game.xp = 600
	pl.hp = 50.0
	var step0: int = game.step
	var ch0: int = game.ch
	var mode0: String = game.mode
	pm._open_page(1)
	await wait(0.2)
	pm.card_sel = 0
	pm._card_activate()
	await wait(0.2)
	ok(game.xp == 350 and int(game.up["hp"]) == 1 and pl.max_hp == 120.0, "куплено «Здоровье +20»: прослушиваний %d, уровень %d, максимум %d" % [game.xp, game.up["hp"], pl.max_hp])
	ok(pl.hp == 70.0, "покупка не лечит полностью (здоровье %d)" % pl.hp)
	ok(game.step == step0 and game.ch == ch0 and game.mode == mode0 and get_tree().paused, "сюжет не сдвинулся (шаг %d, режим %s)" % [game.step, game.mode])
	pm.card_sel = 1
	pm._card_activate()
	ok(game.xp == 100 and int(game.up["dmg"]) == 1, "куплена «Сила»: осталось %d" % game.xp)
	pm.card_sel = 2
	pm._card_activate()
	ok(game.xp == 100 and int(game.up["q"]) == 0, "на ад-либ не хватает — ничего не списано")
	await full_shot("pause_tab_1_bought.png")
	pm._close_card()

	# ---- музыка в наушниках: Пахан кивает, игра приглушена ----
	ipod.earbuds_in = true
	pl.pod.set_seated(true)
	pm._open_page(4)
	await wait(0.2)
	pm.card_sel = 1
	pm._card_activate()                       # ▶ со страницы «Музыка»
	await wait(0.9)
	pm._close_card()
	ok(ipod.is_listening(), "страница «Музыка» запускает тот же плеер iPod")
	ok(audio.headphone > 0.99, "режим наушников включён (%.2f)" % audio.headphone)
	ok(bus_db("Music") < -55.0 and bus_db("SFX") < -10.0 and bus_db("SFX") > -30.0 and bus_db("Ambient") < -10.0 and bus_db("Ambient") > -35.0, "музыка локации ушла, эффекты и окружение тише, но слышны: Music %.0f, SFX %.0f, Ambient %.0f дБ" % [bus_db("Music"), bus_db("SFX"), bus_db("Ambient")])
	ok(absf(bus_db("Voice") - voice0) < 0.01, "голоса не тронуты (Voice %.1f дБ)" % bus_db("Voice"))
	ok(audio.vol == vol0, "настройки громкости игрока не изменились")
	ok(AudioServer.get_bus_index("IPod") >= 0 and not AudioServer.is_bus_mute(0), "iPod на своей шине, общий звук не выключался")
	await wait(0.5)
	await full_shot("pause_3_music.png")

	# ---- смена трека со страницы «Музыка»: тот же плеер, микс не сбрасывается ----
	var idx0: int = ipod.track_index
	pm._open_page(4)
	await wait(0.2)
	pm.card_sel = 2
	pm._card_activate()                       # «Следующий»
	await wait(0.6)
	ok(ipod.track_index != idx0 and ipod.is_listening() and audio.headphone > 0.99, "трек сменился (%d → %d), играет, режим наушников держится" % [idx0, ipod.track_index])
	pm._close_card()

	# ---- пауза трека: микс возвращается ----
	ipod.pause_toggle_play()
	await wait(1.0)
	ok(audio.headphone < 0.01 and bus_db("SFX") > -20.0, "трек на паузе: микс вернулся (SFX %.1f дБ)" % bus_db("SFX"))
	ipod.pause_toggle_play()
	await wait(0.6)

	# ---- закрытие паузы ----
	var idx1: int = ipod.track_index
	await tap(KEY_ESCAPE)
	await wait(0.9)
	ok(not get_tree().paused and not pm.is_open and not pm.cam_taken, "Esc: меню закрыто, камера отдана игре")
	ok(ipod.track_index == idx1, "после закрытия трек сам не переключился")
	ok(pl.global_position.distance_to(pos0) < 0.01, "игровой Пахан не сдвинулся (%.3f м)" % pl.global_position.distance_to(pos0))
	ok(MouseMode.want == Input.MOUSE_MODE_CAPTURED, "мышь снова захвачена игрой")
	ok(ipod.is_listening() and audio.headphone > 0.99, "после паузы музыка играет, режим наушников держится")

	# ---- диалог с музыкой в наушниках и без ----
	game.start_dialog(["N|Проверка микса в диалоге."], func(): game.mode = mode0)
	await wait(1.5)
	ok(absf(ipod.mix_volume - ipod.volume * 0.42) < 0.04, "диалог: iPod тише (%.2f из %.2f)" % [ipod.mix_volume, ipod.volume])
	ok(absf(bus_db("Voice") - voice0) < 0.01 and bus_db("SFX") < -10.0 and bus_db("SFX") > -30.0 and bus_db("Ambient") < -10.0, "диалог: голос на месте, эффекты и окружение тише")
	ipod.pause_toggle_play()
	await wait(1.4)
	ok(audio.duck < -3.0 and bus_db("Music") > -30.0 and bus_db("Music") < bus_db("Voice"), "диалог без iPod: музыка локации тише на %.1f дБ (Music %.1f дБ)" % [-audio.duck, bus_db("Music")])
	await tap(KEY_ENTER)
	await tap(KEY_ENTER)
	await wait(1.2)
	ok(game.mode == mode0 and audio.duck > -1.0, "после диалога музыка вернулась (приглушение %.1f дБ)" % audio.duck)

	# ---- наушники сняты: режим выключается ----
	ipod.pause_toggle_play()
	await wait(0.8)
	ok(audio.headphone > 0.99, "снова играет в наушниках")
	ipod.earbuds_in = false
	pl.pod.set_seated(false)
	await wait(0.9)
	ok(audio.headphone < 0.01 and bus_db("SFX") > -20.0, "наушники сняты: режим выключен, эффекты слышны")
	# открыть и закрыть ещё раз: без наушников автономной проверки нет
	await tap(KEY_ESCAPE)
	await wait(0.9)
	ok(pm.is_open and not pl.pod.buds_in(), "пауза без наушников открывается")
	pm.close()
	await wait(0.7)
	ok(not get_tree().paused, "закрытие по «Вернуться в игру»")
	# убрать за собой тестовый трек из папки iPod
	for i in range(ipod.tracks.size() - 1, -1, -1):
		if bool(ipod.tracks[i].get("local", false)):
			ipod.track_index = i
			ipod._remove_current()
	print("IPOD итог: ошибок %d" % fails)
	get_tree().quit()

# ---------------- форматы импорта (audio_import.gd) ----------------
## Собирает свои тестовые файлы (M4A AAC и ALAC, FLAC — тем же декодером Windows; M4A с тегами и обложкой,
## M4B, AIFF — здесь же), «защищённые» и чужие форматы, и импортирует всё разом: что взято, что отказано и почему,
## теги, обложка, звук, оригиналы не тронуты, имена не совпадают, игра не замирает, лишние файлы убраны.
func formats_block() -> void:
	var dir := out.path_join("форматы тест")          # кириллица и пробел в пути — нарочно
	DirAccess.make_dir_recursive_absolute(dir)
	var imp: AudioImport = ipod.importer
	var base := dir.path_join("исходник.wav")
	_write_test_wav(base)
	var made := {}
	for it in [["Трек AAC.m4a", "m4a"], ["Трек ALAC.m4a", "alac"], ["Трек FLAC.flac", "flac"]]:
		_rm(dir.path_join(it[0]))
		made[it[1]] = imp.encode_for_test(base, dir.path_join(it[0]), it[1])
	ok(bool(made["m4a"]) and bool(made["alac"]), "тестовые M4A (AAC) и M4A (ALAC) собраны декодером Windows")
	print("IPOD FLAC-кодировщик Windows: %s" % ("есть" if made["flac"] else "нет — FLAC не проверялся"))
	var aac := dir.path_join("Трек AAC.m4a")
	ok(_m4a_with_tags(aac, dir.path_join("С тегами.m4a"), "Тест Балон", "madk1d", "Облако", _png()), "M4A с тегами iTunes и обложкой собран")
	_copy_file(aac, dir.path_join("Книга.m4b"))
	_write_aiff(dir.path_join("Звук AIFF.aiff"), "AIFF тест", "Пахан")
	ok(_drm(aac, dir.path_join("Защищённый.m4a")), "M4A с меткой защиты (drms) собран")
	_copy_file(aac, dir.path_join("Купленный.m4p"))
	_bytes(dir.path_join("Старый.wma"), PackedByteArray([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11, 0xA6, 0xD9, 0x00, 0xAA, 0x00, 0x62, 0xCE, 0x6C, 1, 2, 3, 4]))
	var opus := "OggS".to_ascii_buffer()
	opus.append_array(PackedByteArray([0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 19]))
	opus.append_array("OpusHead".to_ascii_buffer())
	opus.append_array(PackedByteArray([1, 2, 0x38, 1, 0x80, 0xBB, 0, 0, 0, 0, 0]))
	_bytes(dir.path_join("Голос.ogg"), opus)
	var junk := "это просто текст, а не музыка".to_utf8_buffer()
	junk.resize(200)
	_bytes(dir.path_join("Не музыка.mp3"), junk)
	_bytes(dir.path_join("Пустой.m4a"), PackedByteArray())
	var names := ["Трек AAC.m4a", "Трек ALAC.m4a", "С тегами.m4a", "Книга.m4b", "Звук AIFF.aiff", "исходник.wav",
		"Защищённый.m4a", "Купленный.m4p", "Старый.wma", "Голос.ogg", "Не музыка.mp3", "Пустой.m4a"]
	if made["flac"]:
		names.append("Трек FLAC.flac")
	var md5 := {}
	var list := PackedStringArray()
	for n in names:
		list.append(dir.path_join(n))
		md5[n] = FileAccess.get_md5(dir.path_join(n))
	var before: int = ipod.tracks.size()
	var files0: int = DirAccess.get_files_at(ipod.USER_MUSIC_DIR).size()
	imp.results = []
	# импорт в своём потоке: кадры идут, долгих замираний нет
	var frames := 0
	var worst := 0.0
	var tp := Time.get_ticks_usec()
	ipod._import_files(list)
	var t0 := Time.get_ticks_msec()
	while ipod.importing() and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		frames += 1
		var tn := Time.get_ticks_usec()
		worst = maxf(worst, (tn - tp) / 1000.0)
		tp = tn
	await import_done()
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	ok(frames > 20 and worst < 500.0, "импорт не замораживает игру: %.1f с, кадров %d, самый долгий кадр %.0f мс" % [secs, frames, worst])
	var res := {}
	for r in imp.results:
		res[String(r[0])] = r
		print("IPOD формат: %s → %s (%s, %s)" % [r[0], r[1], r[2], r[3]])
	var want_ok := ["Трек AAC.m4a", "Трек ALAC.m4a", "С тегами.m4a", "Книга.m4b", "Звук AIFF.aiff", "исходник.wav"]
	if made["flac"]:
		want_ok.append("Трек FLAC.flac")
	for n in want_ok:
		ok(res.has(n) and String(res[n][1]) == "ok", "%s — взят (%s)" % [n, String(res[n][3]) if res.has(n) else "нет в журнале"])
	ok(res.has("Трек AAC.m4a") and String(res["Трек AAC.m4a"][3]).begins_with("AAC") and res.has("Трек ALAC.m4a") and String(res["Трек ALAC.m4a"][3]).begins_with("ALAC"), "кодек внутри M4A определён: AAC и ALAC")
	ok(res.has("Книга.m4b") and String(res["Книга.m4b"][3]).contains("M4B"), "M4B распознан как аудиокнига")
	for it in [["Защищённый.m4a", "DRM"], ["Купленный.m4p", "M4P"], ["Старый.wma", "WMA"], ["Голос.ogg", "Opus"], ["Не музыка.mp3", "не MP3"], ["Пустой.m4a", "пуст"]]:
		ok(res.has(it[0]) and String(res[it[0]][1]).contains(it[1]), "%s — отказ с причиной: «%s»" % [it[0], String(res[it[0]][1]) if res.has(it[0]) else "—"])
	ok(ipod.tracks.size() == before + want_ok.size(), "в iPod добавлено %d из %d подходящих" % [ipod.tracks.size() - before, want_ok.size()])
	ok(not ipod.import_errors.is_empty(), "отказы видны игроку (сообщения: %d)" % ipod.import_errors.size())
	# теги и обложка
	var tagged = null
	var aiff = null
	for i in range(before, ipod.tracks.size()):
		if String(ipod.tracks[i]["title"]) == "Тест Балон":
			tagged = ipod.tracks[i]
		if String(ipod.tracks[i]["title"]) == "AIFF тест":
			aiff = ipod.tracks[i]
	ok(tagged != null and String(tagged["artist"]) == "madk1d" and String(tagged["album"]) == "Облако", "теги M4A прочитаны: название, исполнитель, альбом")
	ok(tagged != null and String(tagged["cover"]) != "" and ipod._cover_for_track(tagged) != null, "обложка из M4A извлечена")
	ok(aiff != null and String(aiff["artist"]) == "Пахан", "теги AIFF прочитаны (NAME, AUTH)")
	# каждый взятый трек играет
	var played := 0
	for i in range(before, ipod.tracks.size()):
		ipod._select_track(i)
		await wait(0.45)
		if ipod.player.playing and ipod.player.stream != null and ipod.player.stream.get_length() > 1.0 and peak("IPod") > -60.0:
			played += 1
		else:
			print("IPOD не играет: %s (%s)" % [ipod.tracks[i]["title"], ipod.tracks[i]["path"]])
	ok(played == ipod.tracks.size() - before, "все взятые треки играют (%d из %d)" % [played, ipod.tracks.size() - before])
	await shot("ipod_6_formats.png")
	# оригиналы не тронуты
	var same := true
	for n in names:
		same = same and FileAccess.get_md5(dir.path_join(n)) == md5[n]
	ok(same, "исходные файлы не изменены")
	# то же имя ещё раз — новая копия, старая цела
	var first_path := ""
	for i in range(before, ipod.tracks.size()):
		if String(ipod.tracks[i].get("format", "")).begins_with("AAC") and String(ipod.tracks[i]["title"]) == "Трек AAC":
			first_path = String(ipod.tracks[i]["path"])
	var n1: int = ipod.tracks.size()
	ipod._import_files(PackedStringArray([aac]))
	await import_done()
	ok(ipod.tracks.size() == n1 + 1 and String(ipod.tracks[n1]["path"]) != first_path and FileAccess.file_exists(first_path), "тот же файл повторно — отдельная копия, прежняя не перезаписана")
	# уборка: удаляем только своё
	while ipod.tracks.size() > before:
		ipod.track_index = ipod.tracks.size() - 1
		ipod._remove_current()
	ok(DirAccess.get_files_at(ipod.USER_MUSIC_DIR).size() == files0, "после удаления тестовых треков в папке iPod — как было (%d)" % files0)
	ok(DirAccess.get_files_at(AudioImport.TMP).is_empty(), "временные файлы декодера убраны")
	ipod._select_track(0)
	await wait(0.3)

func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _bytes(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()

func _copy_file(a: String, b: String) -> void:
	_bytes(b, FileAccess.get_file_as_bytes(a))

func _png() -> PackedByteArray:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.15, 0.1))
	return img.save_png_to_buffer()

func _be32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])

func _atom(name: PackedByteArray, body: PackedByteArray) -> PackedByteArray:
	var b := _be32(body.size() + 8)
	b.append_array(name)
	b.append_array(body)
	return b

func _data_atom(kind: int, payload: PackedByteArray) -> PackedByteArray:
	var body := _be32(kind)
	body.append_array(_be32(0))
	body.append_array(payload)
	return _atom("data".to_ascii_buffer(), body)

## M4A с тегами iTunes: в конец moov (декодер Windows кладёт его последним) — udta/meta/ilst с ©nam, ©ART, ©alb, covr
func _m4a_with_tags(src: String, dst: String, title: String, artist: String, album: String, png: PackedByteArray) -> bool:
	var b := FileAccess.get_file_as_bytes(src)
	var pos := 0
	var moov := -1
	var moov_sz := 0
	while pos + 8 <= b.size():
		var sz: int = (b[pos] << 24) | (b[pos + 1] << 16) | (b[pos + 2] << 8) | b[pos + 3]
		if sz < 8:
			return false
		if b.slice(pos + 4, pos + 8).get_string_from_ascii() == "moov":
			moov = pos
			moov_sz = sz
		pos += sz
	if moov < 0 or moov + moov_sz != b.size():
		return false
	var ilst := PackedByteArray()
	for it in [["nam", title], ["ART", artist], ["alb", album]]:
		var nm := PackedByteArray([0xA9])
		nm.append_array(String(it[0]).to_ascii_buffer())
		ilst.append_array(_atom(nm, _data_atom(1, String(it[1]).to_utf8_buffer())))
	ilst.append_array(_atom("covr".to_ascii_buffer(), _data_atom(14, png)))
	var hdlr := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	hdlr.append_array("mdirappl".to_ascii_buffer())
	hdlr.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0]))
	var meta := PackedByteArray([0, 0, 0, 0])
	meta.append_array(_atom("hdlr".to_ascii_buffer(), hdlr))
	meta.append_array(_atom("ilst".to_ascii_buffer(), ilst))
	var udta := _atom("udta".to_ascii_buffer(), _atom("meta".to_ascii_buffer(), meta))
	var nsz := moov_sz + udta.size()
	var head := _be32(nsz)
	for i in 4:
		b[moov + i] = head[i]
	b.append_array(udta)
	_bytes(dst, b)
	return true

## «Защищённый» M4A: в описании дорожки кодек mp4a заменён на drms (так помечены покупки iTunes)
func _drm(src: String, dst: String) -> bool:
	var b := FileAccess.get_file_as_bytes(src)
	var key := "mp4a".to_ascii_buffer()
	for i in range(b.size() - 4, 0, -1):
		if b[i] == key[0] and b[i + 1] == key[1] and b[i + 2] == key[2] and b[i + 3] == key[3]:
			var d := "drms".to_ascii_buffer()
			for k in 4:
				b[i + k] = d[k]
			_bytes(dst, b)
			return true
	return false

## AIFF 16 бит, моно, 22 050 Гц, порядок байтов старшим первым; NAME и AUTH — теги
func _write_aiff(path: String, title: String, author: String) -> void:
	var rate := 22050
	var n := rate * 6
	var snd := PackedByteArray()
	snd.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env: float = clampf(t * 8.0, 0.0, 1.0) * clampf((6.0 - t) * 8.0, 0.0, 1.0)
		var v := int(sin(t * TAU * 440.0) * env * 9000.0) & 0xFFFF
		snd[i * 2] = (v >> 8) & 0xFF
		snd[i * 2 + 1] = v & 0xFF
	var comm := PackedByteArray([0, 1])
	comm.append_array(_be32(n))
	comm.append_array(PackedByteArray([0, 16]))
	# частота — 80-битное число с плавающей точкой: 22050 = 1.xxx × 2^14
	var e := 0
	while (1 << (e + 1)) <= rate:
		e += 1
	var ex := 16383 + e
	var mant: int = rate << (31 - e)
	comm.append_array(PackedByteArray([(ex >> 8) & 0xFF, ex & 0xFF]))
	comm.append_array(_be32(mant))
	comm.append_array(_be32(0))
	var body := "AIFF".to_ascii_buffer()
	body.append_array(_chunk("COMM".to_ascii_buffer(), comm))
	for it in [["NAME", title], ["AUTH", author]]:
		var tb := String(it[1]).to_utf8_buffer()
		if tb.size() % 2 == 1:
			tb.append(0)
		body.append_array(_chunk(String(it[0]).to_ascii_buffer(), tb))
	var ss := _be32(0)
	ss.append_array(_be32(0))
	ss.append_array(snd)
	body.append_array(_chunk("SSND".to_ascii_buffer(), ss))
	_bytes(path, _chunk("FORM".to_ascii_buffer(), body))

## Кусок AIFF: размер без заголовка (у MP4 — с заголовком)
func _chunk(name: PackedByteArray, body: PackedByteArray) -> PackedByteArray:
	var b := name.duplicate()          # AIFF: сначала имя куска, потом размер (у MP4 — наоборот)
	b.append_array(_be32(body.size()))
	b.append_array(body)
	return b
