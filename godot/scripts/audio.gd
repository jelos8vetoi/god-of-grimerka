## Менеджер звука: музыка локаций и боссов слоями, окружение, отбивки, громкость по шинам.
## Файлы делает tools/godot-music.cjs (godot/assets/music). Набор находится по имени, поэтому новая локация или босс —
## это просто новые файлы loc_<имя>_base/_drive или boss_<id>_p1/_p2/_p3/_intro/_win: код менять не нужно.
## Сам следит за игрой (локация, бой, босс и его фаза, диалог, победа, поражение) и плавно переключает состояние:
##   исследование — слой base;  бой — добавляется drive;  босс — вступление, затем p1, со второй фазы +p2, с третьей +p3;
##   диалог — музыка тише примерно на 37% (−4 дБ), окружение остаётся;  победа и поражение — отбивки.
## Одновременно звучит только один набор: старый гаснет, новый нарастает.
extends Node

const DIR := "res://assets/music/"
const BUSES := ["Music", "SFX", "Ambient", "Voice"]
const TITLES := {"Music": "Музыка", "SFX": "Эффекты", "Ambient": "Окружение", "Voice": "Голос"}
const SETTINGS := "user://grimerka_audio.json"
## одиночные звуки окружения по локациям: игра расставляет их в пространстве вокруг героя
const SHOTS := {"hall": ["drip", "creak"], "snow": ["gust"], "basement": ["drip", "creak"], "neon": ["blip", "static"], "swamp": ["bubble"],
	"glass": ["gust", "creak"], "grave": ["gust", "static", "creak"], "server": ["relay", "static"], "chart": ["cheer"], "core": ["pulse", "static"]}

## Набор звука одной локации или босса
class AudioSet extends Resource:
	var name := ""
	var stems: Array[AudioStream] = []   # слои музыки одной длины
	var bed: AudioStream                 # фон окружения
	var shots: Array[AudioStream] = []   # одиночные звуки

signal state_changed(state: String)

var main
var vol := {"Music": 0.8, "SFX": 1.0, "Ambient": 0.8, "Voice": 1.0}
var sets := {}
var cur := ""                   # имя звучащего набора
var state := ""                 # menu / explore / combat / dialogue / boss / victory / defeat
var layers: Array[AudioStreamPlayer] = []
var want: Array[float] = []     # целевая громкость слоёв 0..1
var sting: AudioStreamPlayer
var bed: AudioStreamPlayer
var bed_key := ""
var spots: Array[AudioStreamPlayer3D] = []
var shot_t := 3.0
var duck := 0.0                 # дБ, на сколько сейчас приглушена музыка
var boss_seen := ""
var dead_seen := false
var log_t := 0.0
var labels := {}
var ipod_focus_target := 0.0  # 0 — обычный микс, 1 — iPod открыт
var ipod_focus := 0.0
## Режим наушников: пока Пахан слушает iPod во вставленных EarPods, музыка локации уступает треку iPod (уходит в тишину),
## а эффекты и окружение становятся заметно тише, но слышны (бой не должен «пропадать» — раньше глушились в ноль,
## и это выглядело как сломанный звук); голоса (Voice) и сам iPod (своя шина) не трогаются.
## Это временный множитель поверх громкости игрока — в настройки не пишется.
const HP_SILENCE_DB := -60.0        # музыка локации
const HP_MUFFLE_DB := -16.0         # эффекты и окружение
const HP_IN := 0.3           # секунд на приглушение
const HP_OUT := 0.45         # и на возврат
var headphone := 0.0         # 0 — обычный микс, 1 — слышны только iPod и голоса
var headphone_on := false
var ipod_lowpass: AudioEffectLowPassFilter
var ipod_reverb: AudioEffectReverb

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	# подшины эффектов: UI (интерфейс мини-игр и меню) и Horror (скримеры) идут в SFX — ползунок «Эффекты» и режим
	# наушников действуют на них как на обычные эффекты; у Horror свой ограничитель, чтобы крик не перегружал микс
	for sub in ["UI", "Horror"]:
		if AudioServer.get_bus_index(sub) < 0:
			AudioServer.add_bus()
			var si := AudioServer.bus_count - 1
			AudioServer.set_bus_name(si, sub)
			AudioServer.set_bus_send(si, "SFX")
			if sub == "Horror":
				var lim := AudioEffectHardLimiter.new()
				lim.ceiling_db = -1.0
				AudioServer.add_bus_effect(si, lim)
	# «Phone» — голос из телефонной трубки (звонки в «5 ночей»): узкая полоса и лёгкий хрип, дальше — в Voice
	# (ползунок «Голоса» действует на него как на остальную озвучку)
	if AudioServer.get_bus_index("Phone") < 0:
		AudioServer.add_bus()
		var pi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(pi, "Phone")
		AudioServer.set_bus_send(pi, "Voice")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 420.0
		AudioServer.add_bus_effect(pi, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 3100.0
		AudioServer.add_bus_effect(pi, lp)
		var ds := AudioEffectDistortion.new()
		ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
		ds.drive = 0.22
		ds.pre_gain = 3.0
		ds.post_gain = -2.0
		AudioServer.add_bus_effect(pi, ds)
		var plim := AudioEffectHardLimiter.new()
		plim.ceiling_db = -2.0
		AudioServer.add_bus_effect(pi, plim)
	# ограничители: эффекты (скример поверх двери и шагов) и общий выход не хрипят
	var sfx_lim := AudioEffectHardLimiter.new()
	sfx_lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), sfx_lim)
	var master_lim := AudioEffectHardLimiter.new()
	master_lim.ceiling_db = -0.3
	AudioServer.add_bus_effect(0, master_lim)
	# Фокус iPod обрабатывается только на Music: голоса, SFX и окружение остаются чистыми.
	var music_bus := AudioServer.get_bus_index("Music")
	ipod_lowpass = AudioEffectLowPassFilter.new()
	ipod_lowpass.cutoff_hz = 22000.0
	ipod_reverb = AudioEffectReverb.new()
	ipod_reverb.room_size = 0.48
	ipod_reverb.damping = 0.68
	ipod_reverb.spread = 0.72
	ipod_reverb.hipass = 0.12
	ipod_reverb.dry = 1.0
	ipod_reverb.wet = 0.0
	AudioServer.add_bus_effect(music_bus, ipod_lowpass)
	AudioServer.add_bus_effect(music_bus, ipod_reverb)
	if FileAccess.file_exists(SETTINGS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if d is Dictionary:
			for b in BUSES:
				vol[b] = clampf(float(d.get(b, vol[b])), 0.0, 1.0)
	for b in BUSES:
		_apply(b)
	for p in main.sfx_pool:
		p.bus = "SFX"
	main.music.bus = "Music"
	sting = AudioStreamPlayer.new()
	sting.bus = "Music"
	add_child(sting)
	bed = AudioStreamPlayer.new()
	bed.bus = "Ambient"
	bed.volume_db = -60.0
	add_child(bed)
	for i in 3:
		var s := AudioStreamPlayer3D.new()
		s.bus = "Ambient"
		s.unit_size = 5.0
		s.max_distance = 34.0
		add_child(s)
		spots.append(s)

# ---------- громкость ----------
func _apply(b: String) -> void:
	if b != "Music":
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), linear_to_db(max(0.0001, float(vol[b]))))
	if labels.has(b):
		(labels[b] as Label).text = "%s: %d%%" % [TITLES[b], roundi(float(vol[b]) * 100.0)]

func set_volume(b: String, v: float, save := true) -> void:
	vol[b] = clampf(v, 0.0, 1.0)
	_apply(b)
	if save:
		var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(vol))

## компактные ползунки громкости для меню паузы: подпись с процентами и полоска; сохраняется, когда ползунок отпущен
func add_sliders(box: Container) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.72, 0.3)
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	for b in BUSES:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.add_theme_font_override("font", main.font)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		l.custom_minimum_size = Vector2(170, 0)
		labels[b] = l
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(vol[b])
		sl.custom_minimum_size = Vector2(230, 20)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.add_theme_stylebox_override("slider", track)
		sl.add_theme_stylebox_override("grabber_area", fill)
		sl.add_theme_stylebox_override("grabber_area_highlight", fill)
		sl.value_changed.connect(func(v: float): set_volume(b, v, false))
		sl.drag_ended.connect(func(_changed: bool): set_volume(b, float(vol[b])))
		row.add_child(l)
		row.add_child(sl)
		box.add_child(row)
		_apply(b)

# ---------- наборы ----------
func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st = load(path)
	if st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	return st

func get_set(nm: String) -> AudioSet:
	if sets.has(nm):
		return sets[nm]
	var s := AudioSet.new()
	s.name = nm
	for part in (["p1", "p2", "p3"] if nm.begins_with("boss_") else ["base", "drive"]):
		var st := _loop(DIR + nm + "_" + part + ".wav")
		if st:
			s.stems.append(st)
	if nm.begins_with("loc_"):
		var key := nm.substr(4)
		s.bed = _loop(DIR + "amb_" + key + ".wav")
		for sh in SHOTS.get(key, []):
			if ResourceLoader.exists(DIR + "os_" + sh + ".wav"):
				s.shots.append(load(DIR + "os_" + sh + ".wav"))
	sets[nm] = s
	return s

## переключить музыку на набор: прежний гаснет и освобождается, новый стартует всеми слоями разом (они одной длины)
func play_set(nm: String) -> void:
	if nm == cur:
		return
	cur = nm
	for p in layers:
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", -60.0, 1.4)
		tw.tween_callback(p.queue_free)
	layers = []
	want = []
	if nm == "":
		return
	for st in get_set(nm).stems:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = st
		p.volume_db = -60.0
		add_child(p)
		p.play()
		layers.append(p)
		want.append(0.0)

func stinger(file: String) -> void:
	var path := DIR + file + ".wav"
	if ResourceLoader.exists(path):
		sting.stream = load(path)
		sting.volume_db = 0.0
		sting.play()

func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)

# ---------- каждый кадр: смотрим на игру ----------
func _process(dt: float) -> void:
	var game = main.game
	var quiet: bool = main.testing() != "" and not main.audiolog
	if main.race != null and is_instance_valid(main.race) and not quiet:
		_race(dt, main.race)
		return
	if main.minigame != null and is_instance_valid(main.minigame) and not quiet:
		_minigame(dt, main.minigame)
		return
	if game == null or not is_instance_valid(game) or quiet:
		# меню: играет заглавный трек, наборы молчат
		play_set("")
		_bed("")
		_set_state("menu")
		_mix(dt, 0.0)
		return
	# заглавный трек в игре уходит
	if main.music.playing:
		main.music.volume_db = move_toward(main.music.volume_db, -60.0, dt * 22.0)      # заглавный трек меню уходит за ~2,5 с
		if main.music.volume_db <= -59.0:
			main.music.stop()
	var key: String = "hall" if game.in_hall else String(game.chapter()["th"]["deco"])      # арена, приквел и Survival идут под музыку первой главы: своих наборов loc_<deco> у них нет
	var boss = game.boss_e if (game.mode == "boss" or game.is_survival()) and is_instance_valid(game.boss_e) else null
	var ducking := 0.0
	if boss != null and boss.state != "dead":
		var id: String = boss.boss_id
		if boss_seen != id:
			boss_seen = id
			stinger("boss_" + id + "_intro")
		play_set("boss_" + id)
		_want([1.0, 1.0 if boss.phase >= 1 else 0.0, 1.0 if boss.phase >= 2 else 0.0])
		_set_state("boss")
	else:
		if boss_seen != "":
			# босс повержен: победная отбивка, музыка локации возвращается из-под неё
			stinger("boss_" + boss_seen + "_win")
			boss_seen = ""
			_set_state("victory")
		play_set("loc_" + key)
		var fighting: bool = (game.mode == "fight" or game.mode == "training") and game.enemies.any(func(e): return is_instance_valid(e) and e.state != "dead")
		_want([1.0, 1.0 if fighting else 0.0])
		if not sting.playing:
			_set_state("dialogue" if game.mode == "dlg" else ("combat" if fighting else "explore"))
	var dead: bool = game.player.state == "dead"
	if dead and not dead_seen:
		stinger("defeat")
		_set_state("defeat")
	dead_seen = dead
	if game.get_tree().paused and game.pause_panel != null and game.pause_panel.is_open:
		ducking = -6.0      # меню паузы: игра тише, но не пропадает
	if game.mode == "dlg":
		ducking = min(ducking, -4.0)      # в диалоге музыка тише примерно на 37%, но не пропадает
	if sting.playing:
		ducking = min(ducking, -7.0)
	if dead:
		ducking = -14.0
	_bed(key)
	_shots(dt, game)
	_mix(dt, ducking)
	if main.audiolog:
		log_t -= dt
		if log_t <= 0.0:
			log_t = 1.0
			print("MUSIC набор=%s состояние=%s слои=%s приглушение=%.1f дБ наушники=%.2f шины: Music %.1f SFX %.1f Ambient %.1f Voice %.1f дБ · пик музыки=%.1f дБ пик окружения=%.1f дБ" % [cur, state, str(want), duck, headphone,
				AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice")),
				AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"), 0), AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Ambient"), 0)])

## гонка на пылесосах: свой набор (loc_race: драйв и ударные), заглавный трек меню уходит, на паузе тише
func _race(dt: float, race) -> void:
	if main.music.playing:
		main.music.volume_db = move_toward(main.music.volume_db, -60.0, dt * 22.0)
		if main.music.volume_db <= -59.0:
			main.music.stop()
	play_set("loc_race" if ResourceLoader.exists(DIR + "loc_race_base.wav") else "loc_snow")
	_want([1.0, 1.0 if race.go or race.state == "countdown" else 0.0])
	_set_state("race" if race.state != "results" else "victory")
	_bed("")
	_mix(dt, -6.0 if race.paused else (-3.0 if race.state == "results" else 0.0))
	# последний круг: музыка чуть быстрее и выше — напряжение до финиша (после него — обратно)
	var hot: bool = race.local != null and race.laps > 1 and race.local.lap >= race.laps - 1 and not race.local.finished and race.go
	for p in layers:
		if is_instance_valid(p):
			p.pitch_scale = move_toward(p.pitch_scale, 1.07 if hot else 1.0, dt * 0.06)

## мини-игра со своей сценой: заглавный трек уходит, набор — какой попросит сама игра ("" — тишина, у неё свой звук)
func _minigame(dt: float, mg) -> void:
	if main.music.playing:
		main.music.volume_db = move_toward(main.music.volume_db, -60.0, dt * 22.0)
		if main.music.volume_db <= -59.0:
			main.music.stop()
	var nm: String = mg.music_set() if mg.has_method("music_set") else ""
	if nm != "" and not ResourceLoader.exists(DIR + nm + "_base.wav"):
		nm = ""
	play_set(nm)
	# слои: игра сама говорит, насколько громко base и drive (микрозаймы: drive — когда горит срок); по умолчанию — только base
	var lv: Array = mg.music_layers() if mg.has_method("music_layers") else [0.7, 0.0]
	_want(lv)
	_set_state("minigame")
	# фон окружения из набора amb_<имя> (у «5 ночей» свой синтез — она отдаёт "")
	_bed(String(mg.bed_set()) if mg.has_method("bed_set") else "")
	_mix(dt, 0.0)

func _want(v: Array) -> void:
	for i in want.size():
		want[i] = float(v[i]) if i < v.size() else 0.0

## Мёртвая тишина (скримеры «5 ночей»): фон и/или музыка пропадают сразу, без затухания; возвращаются плавно.
## Шины глушит только этот файл — режим просит через hush(). SFX не трогаем: через неё идёт сам крик.
var hush_amb := 0.0            # 1 — шина Ambient в тишине
var hush_mus := 0.0
var hush_hold := false
func hush(amb: bool, mus: bool) -> void:
	hush_hold = amb or mus
	if amb:
		hush_amb = 1.0
	if mus:
		hush_mus = 1.0
	if hush_hold:                                # сразу, не дожидаясь следующего кадра сведения
		if amb:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), -80.0)
		if mus:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -80.0)

func _mix(dt: float, ducking: float) -> void:
	if not hush_hold:                            # отпустили — фон возвращается за секунду с лишним, без скачка
		hush_amb = move_toward(hush_amb, 0.0, dt * 0.8)
		hush_mus = move_toward(hush_mus, 0.0, dt * 0.8)
	duck = lerpf(duck, ducking, 1.0 - exp(-3.0 * dt))
	headphone_on = listening()
	headphone = move_toward(headphone, 1.0 if headphone_on else 0.0, dt / (HP_IN if headphone_on else HP_OUT))
	var hk := headphone * headphone * (3.0 - 2.0 * headphone)
	var hp_db := HP_SILENCE_DB * hk
	for b in ["SFX", "Ambient"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), linear_to_db(max(0.0001, float(vol[b]))) + HP_MUFFLE_DB * hk - (80.0 * hush_amb * hush_amb if b == "Ambient" else 0.0))
	ipod_focus = lerpf(ipod_focus, ipod_focus_target, 1.0 - exp(-3.2 * dt))
	var focus_volume := lerpf(1.0, 0.68, ipod_focus)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(0.0001, float(vol["Music"]) * focus_volume)) + duck + hp_db - 80.0 * hush_mus * hush_mus)
	ipod_lowpass.cutoff_hz = lerpf(22000.0, 5600.0, ipod_focus)
	ipod_reverb.wet = 0.16 * ipod_focus
	ipod_reverb.dry = 1.0 - 0.08 * ipod_focus
	for i in layers.size():
		var target := linear_to_db(max(0.001, want[i]))
		layers[i].volume_db = lerpf(layers[i].volume_db, target, 1.0 - exp(-(2.5 if target > layers[i].volume_db else 1.2) * dt))

## Низкий короткий удар под надпись «ПАХАН УМЕР»: синтезируется на лету, идёт через шину Music.
var accent_p: AudioStreamPlayer
func death_accent() -> void:
	if accent_p == null:
		var rate := 22050
		var n := int(rate * 1.6)
		var bytes := PackedByteArray()
		bytes.resize(n * 2)
		var ph := 0.0
		for i in n:
			var tt := float(i) / rate
			ph += TAU * (46.0 + 30.0 * exp(-tt * 9.0)) / rate
			var v := (sin(ph) + 0.3 * sin(ph * 2.0)) * (1.0 - exp(-tt * 400.0)) * exp(-tt * 2.6) * 0.5
			bytes.encode_s16(i * 2, clampi(int(v * 32767.0), -32768, 32767))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = bytes
		accent_p = AudioStreamPlayer.new()
		accent_p.stream = w
		accent_p.bus = "Music"
		accent_p.volume_db = 4.0
		add_child(accent_p)
	if main.testing() == "":
		accent_p.play()

## Слушает ли Пахан iPod в наушниках прямо сейчас: трек выбран, играет, не на паузе, вкладыши в ушах.
func listening() -> bool:
	var game = main.game
	if game == null or not is_instance_valid(game) or game.get("ipod") == null:
		return false
	var ip = game.ipod
	if ip == null or not is_instance_valid(ip) or not ip.is_listening():
		return false
	var pl = game.get("player")
	if pl != null and is_instance_valid(pl) and pl.get("pod") != null and pl.pod_synced:
		return pl.pod.buds_in()
	return true

## фон окружения локации: плавная смена
func _bed(key: String) -> void:
	if key == bed_key:
		if key != "" and bed.volume_db < -1.0:
			bed.volume_db = move_toward(bed.volume_db, 0.0, 0.6)
		return
	bed.volume_db = move_toward(bed.volume_db, -60.0, 1.2)
	if bed.volume_db <= -59.0:
		bed_key = key
		bed.stop()
		if key != "":
			var s := get_set("loc_" + key)
			if s.bed:
				bed.stream = s.bed
				bed.play()

## одиночные звуки: в случайной точке вокруг слушателя, со случайной высотой тона и громкостью — не повторяются одинаково
func _shots(dt: float, game) -> void:
	shot_t -= dt
	if shot_t > 0.0 or bed_key == "" or get_tree().paused:
		return
	shot_t = randf_range(2.5, 7.0)
	var s := get_set("loc_" + bed_key)
	if s.shots.is_empty():
		return
	for p in spots:
		if not p.playing:
			var a := randf() * TAU
			var around: Vector3 = game.player.global_position
			p.stream = s.shots[randi() % s.shots.size()]
			p.global_position = around + Vector3(sin(a), 0, cos(a)) * randf_range(4.0, 13.0) + Vector3(0, randf_range(0.4, 2.8), 0)
			p.pitch_scale = randf_range(0.82, 1.18)
			p.volume_db = randf_range(-7.0, 0.0)
			p.play()
			return
