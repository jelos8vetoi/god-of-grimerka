## Точка входа: управление, меню, запуск боя, звук. Ключ --autotest=папка — прогон без игрока со скриншотами.
extends Node

const ACTIONS := {
	"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"jump": [KEY_SPACE], "roll": [KEY_SHIFT], "block": [KEY_C], "sprint": [KEY_CTRL], "adlib": [KEY_Q], "rage": [KEY_R], "heat": [KEY_E],
	"ipod": [KEY_UP],
	"throw": [KEY_F],
	"tag": [KEY_TAB], "assist": [KEY_T], "overdrive": [KEY_G],
	"style1": [KEY_1], "style2": [KEY_2], "style3": [KEY_3],
	"pause": [KEY_ESCAPE], "fullscreen": [KEY_F11], "tut_skip": [KEY_BACKSPACE], "train_panel": [KEY_F1],
}

var game: Node
var menu: Control
var music: AudioStreamPlayer
var audio                 # менеджер звука (audio.gd)
var audiolog := false     # --audiolog: печатать состояние музыки раз в секунду (и не глушить её в проверках)
var ipodcheck := ""        # --ipodcheck=<папка>: автопроверка iPod по кадрам (scripts/ipodcheck.gd)
var transcheck := ""        # --transcheck=<папка>: проверка переходов из меню в игру и паузы (scripts/transcheck.gd)
var deathcheck := ""        # --deathcheck=<папка>: проверка сцены гибели (scripts/deathcheck.gd)
var uiqa := ""              # --uiqa=<папка>: сквозная проверка всего интерфейса (scripts/uiqa.gd)
var trainingcheck := ""     # --trainingcheck=<папка>: тренировочная арена из меню (scripts/trainingcheck.gd)
var onechapter := false     # --onechapter: и в проверках только доступные игроку главы (проверка концовки первой главы)
var launcher := ""          # --launcher=<путь>: игру запустил лаунчер, обновление — через него
var ipodpause := false      # вместе с --ipodcheck: меню паузы и режим наушников (--pause)
var ipodbuds := false       # вместе с --ipodcheck: только наушники EarPods (--buds)
var ipodhand := false       # вместе с --ipodcheck: только проверка руки и позы (--hand)
var voicecheck := false   # --voicecheck: пройти диалог главы и напечатать, какие реплики заиграли
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cache := {}
var autotest := ""
var smoke := ""
var trailer := ""
var hudcheck := ""        # --hudcheck=<папка>: боевой HUD в игре (scripts/hudcheck.gd)
var execcheck := ""       # --execcheck=<папка>: реакции врагов и добивания (scripts/execcheck.gd)
var tagcheck := ""        # --tagcheck=<папка>: Tag Team (scripts/tagcheck.gd)
var flowcheck := ""       # --flowcheck=<папка>: смена стилей в бою (scripts/flowcheck.gd)
var hypecheck := ""       # --hypecheck=<папка>: Team Hype и Overdrive (scripts/hypecheck.gd)
var basecheck := ""       # --basecheck=<папка>: основа боевых анимаций (scripts/basecheck.gd)
var bottlecheck := ""     # --bottlecheck=<папка>: стиль «Водяра» (scripts/bottlecheck.gd)
var tyagacheck := ""      # --tyagacheck=<папка>: стиль «ТЯГА-812» (scripts/tyagacheck.gd)
var madkcheck := ""       # --madkcheck=<папка>: оружие madk1d — доска за спиной, гитара в двух руках (scripts/madkcheck.gd)
var duocheck := ""        # --duocheck=<папка>: дуэт-атака на [T] (scripts/duocheck.gd)
var lockcheck := ""       # --lockcheck=<папка>: захват цели (scripts/lockcheck.gd)
var movementcheck := ""   # --movementcheck=<папка>: рывок в воздухе и движение (scripts/movementcheck.gd)
var damagecheck := ""     # --damagecheck=<папка>: баланс урона (scripts/damagecheck.gd)
var aicheck := ""         # --aicheck=<папка>: ИИ врагов и боссов (scripts/aicheck.gd)
var vfxcheck := ""        # --vfxcheck=<папка>: эффекты боя по профилям атак (scripts/vfxcheck.gd)
var tutorialcheck := ""   # --tutorialcheck=<папка>: боевое обучение (scripts/tutorialcheck.gd)
var combatcheck := ""     # --combatcheck=<папка>: ядро боя в игре (scripts/combatcheck.gd)
var animlab := ""          # --animlab=<папка>: анимации в игре — сцены, листы кадров, замеры стоп (scripts/animlab.gd)
var start_ch := -1
var auto_len := 45.0
var font: Font

func _ready() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in ACTIONS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	# захват цели (lockon.gd): СКМ — взять / отпустить, колесо — следующая / предыдущая цель
	for a in [["attack", MOUSE_BUTTON_LEFT], ["heavy", MOUSE_BUTTON_RIGHT], ["lock", MOUSE_BUTTON_MIDDLE], ["lock_next", MOUSE_BUTTON_WHEEL_DOWN], ["lock_prev", MOUSE_BUTTON_WHEEL_UP]]:
		InputMap.add_action(a[0])
		var m := InputEventMouseButton.new()
		m.button_index = a[1]
		InputMap.action_add_event(a[0], m)
	var js := InputEventJoypadButton.new()
	js.button_index = JOY_BUTTON_RIGHT_STICK            # геймпад: нажатие правого стика — захват
	InputMap.action_add_event("lock", js)
	font = load("res://assets/fonts/RussoOne-Regular.ttf")
	Opts.apply(get_window())
	# отдельная шина для голосов: их громкость не зависит от музыки и эффектов, и её можно измерить в --voicecheck
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
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
		elif arg.begins_with("--smoke="):
			smoke = arg.substr(8)
		elif arg.begins_with("--hudcheck="):
			hudcheck = arg.substr(11)
		elif arg.begins_with("--execcheck="):
			execcheck = arg.substr(12)
		elif arg.begins_with("--tagcheck="):
			tagcheck = arg.substr(11)
		elif arg.begins_with("--flowcheck="):
			flowcheck = arg.substr(12)
		elif arg.begins_with("--hypecheck="):
			hypecheck = arg.substr(12)
		elif arg.begins_with("--basecheck="):
			basecheck = arg.substr(12)
		elif arg.begins_with("--bottlecheck="):
			bottlecheck = arg.substr(14)
		elif arg.begins_with("--tyagacheck="):
			tyagacheck = arg.substr(13)
		elif arg.begins_with("--madkcheck="):
			madkcheck = arg.substr(12)
		elif arg.begins_with("--duocheck="):
			duocheck = arg.substr(11)
		elif arg.begins_with("--combatcheck="):
			combatcheck = arg.substr(14)
		elif arg.begins_with("--animlab="):
			animlab = arg.substr(10)
		elif arg.begins_with("--trailer="):
			trailer = arg.substr(10)
		elif arg.begins_with("--chapter="):
			start_ch = int(arg.substr(10)) - 1
		elif arg.begins_with("--ipodcheck="):
			ipodcheck = arg.substr(12)
			start_ch = max(start_ch, 0)
		elif arg.begins_with("--launcher="):
			launcher = arg.substr(11)
		elif arg.begins_with("--transcheck="):
			transcheck = arg.substr(13)
		elif arg.begins_with("--lockcheck="):
			lockcheck = arg.substr(12)
		elif arg.begins_with("--movementcheck="):
			movementcheck = arg.substr(16)
		elif arg.begins_with("--damagecheck="):
			damagecheck = arg.substr(14)
		elif arg.begins_with("--aicheck="):
			aicheck = arg.substr(10)
		elif arg.begins_with("--vfxcheck="):
			vfxcheck = arg.substr(11)
		elif arg.begins_with("--tutorialcheck="):
			tutorialcheck = arg.substr(16)
		elif arg.begins_with("--deathcheck="):
			deathcheck = arg.substr(13)
		elif arg.begins_with("--uiqa="):
			uiqa = arg.substr(7)
		elif arg.begins_with("--trainingcheck="):
			trainingcheck = arg.substr(16)
		elif arg == "--onechapter":
			onechapter = true
		elif arg == "--pause":
			ipodpause = true
		elif arg == "--buds":
			ipodbuds = true
		elif arg == "--hand":
			ipodhand = true
		elif arg == "--audiolog":
			audiolog = true
		elif arg == "--voicecheck":
			voicecheck = true
			audiolog = true
			start_ch = max(start_ch, 0)
		elif arg.begins_with("--seconds="):
			auto_len = float(arg.substr(10))
	audio = preload("res://scripts/audio.gd").new()
	audio.main = self
	add_child(audio)
	# автопроверки и прогоны (любые ключи, кроме запуска лаунчером) — тихо: окно без фокуса в углу, мышь не захватывается
	if Array(OS.get_cmdline_user_args()).any(func(x): return not String(x).begins_with("--launcher")):
		MouseMode.make_quiet(get_window())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--posesheet="):
			var ps = preload("res://scripts/posesheet.gd").new()
			var v := arg.substr(12).split(",")
			ps.out = v[0]
			ps.who = v[1] if v.size() > 1 else ""
			ps.seq = Array(v.slice(2))
			add_child(ps)
			return
		if arg.begins_with("--animcheck="):
			var ac = preload("res://scripts/animcheck.gd").new()
			ac.out = arg.substr(12)
			add_child(ac)
			return
	if testing() != "":
		start_game(false, max(start_ch, 0))
	elif start_ch >= 0:
		start_game(false, start_ch)
	else:
		show_menu()
		if transcheck != "":
			var tq = preload("res://scripts/transcheck.gd").new()
			tq.main = self
			tq.out = transcheck
			add_child(tq)
		if deathcheck != "":
			var dq = preload("res://scripts/deathcheck.gd").new()
			dq.main = self
			dq.out = deathcheck
			add_child(dq)
		if uiqa != "":
			var q = preload("res://scripts/uiqa.gd").new()
			q.main = self
			q.out = uiqa
			add_child(q)
		if trainingcheck != "":
			var trc = preload("res://scripts/trainingcheck.gd").new()
			trc.main = self
			trc.out = trainingcheck
			add_child(trc)

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
		Opts.put("fullscreen", not bool(Opts.v("fullscreen")), get_window())   # та же настройка, что в меню

func show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	music.volume_db = -6.0
	if not music.playing:
		music.play()
	# меню целиком — scripts/menu.gd (композиция, герои, экраны загрузки, настроек и дополнительного)
	var m := Menu.new()
	m.main = self
	menu = m
	add_child(m)

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
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.9)
	sb.border_color = Color(0.95, 0.96, 0.97)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	var hv := sb.duplicate()
	hv.bg_color = Color(0.95, 0.96, 0.97)
	b.add_theme_color_override("font_hover_color", Color(0.03, 0.03, 0.035))
	b.add_theme_color_override("font_pressed_color", Color(0.03, 0.03, 0.035))
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func(): sfx("sfx_ui"); cb.call())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

## Проверка обновления: сборка знает свой коммит (data/build.json), а в описании релиза godot-build записан коммит свежей.
## Если они разные — в меню появляется кнопка, которая открывает страницу с новой версией. Без сети просто ничего не происходит.
const RELEASE_API := "https://api.github.com/repos/jelos8vetoi/god-of-grimerka/releases/tags/godot-build"
const RELEASE_URL := "https://github.com/jelos8vetoi/god-of-grimerka/releases/tag/godot-build"
## on_update получает действие «обновить»: через лаунчер, если игра запущена из него, иначе — открыть страницу релиза.
func _check_update(on_update: Callable) -> void:
	if testing() != "" or menu == null or not FileAccess.file_exists("res://data/build.json"):
		return
	var mine = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
	if not (mine is Dictionary):
		return
	var http := HTTPRequest.new()
	menu.add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		if code != 200 or not is_instance_valid(menu):
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if d is Dictionary and String(d.get("body", "")).find("`%s`" % String(mine.get("sha", ""))) < 0:
			if launcher != "" and FileAccess.file_exists(launcher):
				# лаунчер сам скачает новую сборку и снова запустит игру
				on_update.call(func():
					OS.create_process(launcher, PackedStringArray())
					get_tree().quit())
			else:
				on_update.call(func(): OS.shell_open(RELEASE_URL)))
	http.request(RELEASE_API, PackedStringArray(["User-Agent: god-of-grimerka-game"]))

func testing() -> String:
	return autotest + smoke + trailer + animlab + combatcheck + hudcheck + execcheck + tagcheck + flowcheck + hypecheck + basecheck + bottlecheck + tyagacheck + madkcheck + duocheck + tutorialcheck + vfxcheck + aicheck + damagecheck + movementcheck + lockcheck

## Боевое обучение: в обычной игре и в его проверке; в остальных проверках и прогонах карточки бой не прерывают
func tutorial_on() -> bool:
	if tutorialcheck != "":
		return true
	return testing() == "" and ipodcheck == "" and transcheck == "" and deathcheck == "" and uiqa == "" and trainingcheck == "" and not voicecheck

## Кинематографичный запуск из меню (NEW GAME, CONTINUE, LOAD GAME): шторка → игра создаётся за ней → мир проявляется,
## камера облетает Пахана, HUD появляется по очереди, потом управление и сюжет. Повторный вызов во время перехода игнорируется.
var intro_fx: IntroFX
func cinematic_start(from_save: bool, chapter := -1, line := "") -> void:
	if intro_fx == null:
		intro_fx = IntroFX.new()
		add_child(intro_fx)
	if intro_fx.busy or game != null:
		return
	await intro_fx.cover("WELCOME BACK" if from_save else "ENTERING THE CLOUD", line)
	if from_save:
		var d = JSON.parse_string(FileAccess.get_file_as_string("user://grimerka_save.json")) if FileAccess.file_exists("user://grimerka_save.json") else null
		if not (d is Dictionary):
			await intro_fx.fail("Сохранение не читается — начни новую игру.", show_menu)
			return
	start_game(from_save, chapter, true)
	for i in 3:
		await get_tree().process_frame
	intro_fx.reveal()

## Тренировочная арена из меню: та же шторка, что у NEW GAME, но без сюжета и без сюжетного сохранения
func cinematic_training(hero: String, style: String) -> void:
	if intro_fx == null:
		intro_fx = IntroFX.new()
		add_child(intro_fx)
	if intro_fx.busy or game != null:
		return
	await intro_fx.cover("TRAINING ARENA", "Тренировка · без сюжета и сохранения")
	await start_training(hero, style)
	for i in 3:
		await get_tree().process_frame
	intro_fx.reveal()

func start_training(hero: String, style: String) -> void:
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
	var arena := Training.new()
	game.training = arena
	game.add_child(arena)
	arena.setup(game)
	game._apply_upgrades()
	await arena.begin(hero, style)

func start_game(from_save := false, chapter := -1, cinematic := false) -> void:
	if menu:
		menu.queue_free()
		menu = null
	if game:
		game.queue_free()
	music.volume_db = -16.0
	if not music.playing and trailer == "":
		music.play()
	game = preload("res://scripts/game.gd").new()
	game.main = self
	add_child(game)
	if ipodcheck != "":
		var chk = preload("res://scripts/ipodcheck.gd").new()
		chk.game = game
		chk.out = ipodcheck
		chk.hand_only = ipodhand
		chk.buds_only = ipodbuds
		chk.pause_only = ipodpause
		chk.as_madk = OS.get_cmdline_user_args().has("--madk")
		add_child(chk)
	if smoke != "":
		game.auto_kill = 1.6
	game.auto_len = auto_len
	game.intro_on = cinematic
	if hudcheck != "":
		var hc = preload("res://scripts/hudcheck.gd").new()
		hc.game = game
		hc.out = hudcheck
		game.director = hc
		game.add_child(hc)
	if execcheck != "":
		var ec = preload("res://scripts/execcheck.gd").new()
		ec.game = game
		ec.out = execcheck
		game.director = ec
		game.add_child(ec)
	if tagcheck != "":
		var tc = preload("res://scripts/tagcheck.gd").new()
		tc.game = game
		tc.out = tagcheck
		game.director = tc
		game.add_child(tc)
	if flowcheck != "":
		var fc = preload("res://scripts/flowcheck.gd").new()
		fc.game = game
		fc.out = flowcheck
		game.director = fc
		game.add_child(fc)
	if hypecheck != "":
		var hc2 = preload("res://scripts/hypecheck.gd").new()
		hc2.game = game
		hc2.out = hypecheck
		game.director = hc2
		game.add_child(hc2)
	if basecheck != "":
		var bc = preload("res://scripts/basecheck.gd").new()
		bc.game = game
		bc.out = basecheck
		game.director = bc
		game.add_child(bc)
	if bottlecheck != "":
		var btc = preload("res://scripts/bottlecheck.gd").new()
		btc.game = game
		btc.out = bottlecheck
		game.director = btc
		game.add_child(btc)
	if tyagacheck != "":
		var tgc = preload("res://scripts/tyagacheck.gd").new()
		tgc.game = game
		tgc.out = tyagacheck
		game.director = tgc
		game.add_child(tgc)
	if lockcheck != "":
		var lkc = preload("res://scripts/lockcheck.gd").new()
		lkc.game = game
		lkc.out = lockcheck
		game.director = lkc
		game.add_child(lkc)
	if movementcheck != "":
		var mvc = preload("res://scripts/movementcheck.gd").new()
		mvc.game = game
		mvc.out = movementcheck
		game.director = mvc
		game.add_child(mvc)
	if damagecheck != "":
		var dmc = preload("res://scripts/damagecheck.gd").new()
		dmc.game = game
		dmc.out = damagecheck
		game.director = dmc
		game.add_child(dmc)
	if aicheck != "":
		var aic = preload("res://scripts/aicheck.gd").new()
		aic.game = game
		aic.out = aicheck
		game.director = aic
		game.add_child(aic)
	if vfxcheck != "":
		var vxc = preload("res://scripts/vfxcheck.gd").new()
		vxc.game = game
		vxc.out = vfxcheck
		game.director = vxc
		game.add_child(vxc)
	if tutorialcheck != "":
		var tuc = preload("res://scripts/tutorialcheck.gd").new()
		tuc.game = game
		tuc.out = tutorialcheck
		game.director = tuc
		game.add_child(tuc)
	if madkcheck != "":
		var mkc = preload("res://scripts/madkcheck.gd").new()
		mkc.game = game
		mkc.out = madkcheck
		game.director = mkc
		game.add_child(mkc)
	if duocheck != "":
		var dc = preload("res://scripts/duocheck.gd").new()
		dc.game = game
		dc.out = duocheck
		game.director = dc
		game.add_child(dc)
	if combatcheck != "":
		var cc = preload("res://scripts/combatcheck.gd").new()
		cc.game = game
		cc.out = combatcheck
		game.director = cc
		game.add_child(cc)
	if animlab != "":
		var lab = preload("res://scripts/animlab.gd").new()
		lab.game = game
		lab.out = animlab
		game.director = lab
		game.add_child(lab)
	if trailer != "":
		var d = preload("res://scripts/director.gd").new()
		d.game = game
		d.out = trailer
		game.director = d
		game.add_child(d)
	game.begin(from_save, chapter)
