## Автопроверка iPod: `-- --ipodcheck=<папка>`. Жмёт настоящие клавиши и кнопки мыши, снимает кадры в папку
## и печатает строки «IPOD ok / IPOD ОШИБКА». Если в папке лежат test.mp3 и test.wav — проверяет ещё и импорт.
## Звук на время проверки заглушён на общей шине: уровни меряются по шинам, слушать ничего не нужно.
extends Node

var game
var out := ""
var fails := 0
var buds_only := false     # --buds: наушники EarPods
var hand_only := false
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
	if hand_only:
		await _run_hand()
		return
	if buds_only:
		await _run_buds()
		return

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
	await wait(2.2)
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
	await wait(2.4)
	ok(not ipod.opened and not ipod.captures_gameplay_input() and not ipod.device.visible, "шесть быстрых нажатий ↑: iPod закрыт, ввод свободен")
	ok(Input.mouse_mode == mouse0 and game.ipod_focus < 0.01 and absf(game.spring.spring_length - len0) < 0.12, "после быстрых нажатий камера и мышь на месте")
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
	var prev_off := Vector3.ZERO
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
	for i in 30:
		await get_tree().process_frame
		var o2: Vector3 = pod.buds.dyn[1]["off"]
		sway_step = max(sway_step, o2.distance_to(prev_off) / clampf(get_process_delta_time(), 0.004, 0.05) * 0.0083)
		prev_off = o2
	await wait(1.6)
	sway_stop = pod.buds.sway()
	ok(sway_run > 0.004, "на бегу провод раскачивается (до %.3f)" % sway_run)
	ok(sway_stop < 0.004, "после остановки успокаивается (%.4f)" % sway_stop)
	ok(sway_step < 0.012, "без дрожи: наибольший шаг смещения за кадр (при 120 к/с) %.4f" % sway_step)
	# ---- бой с наушниками: перекат, блок, удар ----
	await tap(KEY_SPACE)
	ok(pl.state == "roll" and pod.buds_in(), "перекат с наушниками")
	await wait(1.0)
	key(KEY_SHIFT)
	await wait(0.4)
	ok(pl.state == "block", "блок с наушниками (состояние «%s»)" % pl.state)
	key(KEY_SHIFT, false)
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
	pl.inv = 0.0
	pl.take_damage(pl.hp + 50.0, pl.global_position + Vector3(1, 0, 0))
	await wait(0.2)
	ok(pl.state == "dead" and not ipod.opened and pod.u <= 0.0 and not pod.balloon_free and not pod.device.visible, "гибель во время просмотра: iPod сразу в кармане, руки свободны")
	ok(pod.buds_in() and pod.buds.visible, "наушники при гибели остались в ушах")
	await wait(2.6)
	# в обычной игре здесь окно «Пахан упал» и кнопка «Ещё раз» — жмём её
	game._retry()
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
