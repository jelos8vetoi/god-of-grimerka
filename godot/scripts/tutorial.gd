## Боевое обучение (TutorialManager): карточки по одной, когда механика впервые пригодилась в бою.
## Систему боя не трогает — только читает её состояние (player, combat, enemies, tag, hype) и сигналы ядра боя.
## Порядок: у карточки есть предшественник (тяжёлый — после лёгкого, блок — после уклонения…) и условие по обстановке
## (_cond: враг замахнулся рядом, враг в воздухе, над врагом ✕, СВЭГ полный…). Между карточками — пауза боя GAP,
## у «мгновенных» (воздух, добивание, босс открыт, AIR TAG) — короче, иначе момент уйдёт.
## Карточка останавливает игру, только если пауза наша (own_pause): чужую паузу (меню) не снимаем.
## Увиденные карточки — в сохранении игры (ключ "tut"); новая игра начинает обучение заново; старые сохранения без ключа — тоже.
## Повтор — из паузы, вкладка СИСТЕМА → «БОЕВЫЕ ПОДСКАЗКИ» (replay).
## Включено только в обычной игре (main.tutorial_on) и в проверке --tutorialcheck — автопроверки боя карточки не прерывают.
## Практика (по умолчанию): вместо карточек — упражнения на настоящей цели с панелью справа сверху (ниже, «практика»);
## карточки остаются в паузе (повтор) и при выключенной настройке «ПРАКТИКА В ОБУЧЕНИИ».
class_name Tutorial
extends Node

const SAVE_PATH := "user://grimerka_save.json"     # то же, что game.SAVE
const GAP := 9.0             # секунд боя между карточками
const GAP_NOW := 3.0         # у мгновенных карточек
const FIRST := 1.4           # первая карточка — через столько секунд после начала первого боя
const NOW := ["finisher", "air", "boss_open", "air_tag", "heat", "rage", "overdrive"]
## Порядок проверки: первым — то, что ценно поймать в момент; дальше — основа по шагам
const PRIORITY := ["light", "style_cur", "finisher", "air", "boss_open", "air_tag", "heat", "rage", "overdrive",
	"heavy", "combo", "dodge", "block", "charge", "throw", "adlib", "styles", "style_more", "tag", "assist", "team_moves"]
const AFTER := {
	"style_cur": "light", "heavy": "light", "combo": "heavy", "dodge": "heavy", "block": "dodge", "charge": "combo",
	"throw": "combo", "heat": "heavy", "finisher": "heavy", "air": "heavy", "adlib": "dodge", "rage": "light",
	"boss_open": "light", "overdrive": "light", "styles": "block", "style_more": "styles", "tag": "styles",
	"air_tag": "tag", "assist": "tag", "team_moves": "assist",
}
const SAFE := ["move", "block", "tyaga", "skate"]           # в этих состояниях героя карточку можно показать
const SAFE_NOW := ["move", "block", "tyaga", "skate", "attack", "air"]

var game
var on := true
var persist := true           # писать увиденное в файл сохранения (в проверках — только по просьбе)
var save_path := ""           # файл сохранения; пусто — game.SAVE
var seen := {}                # id → "introduced" (показано) / "completed" (сделано) / "skipped" (пропущено)
var card: TutorialCard
var own_pause := false
var fight_t := 0.0            # секунд боя всего
var since := GAP - FIRST      # секунд боя после прошлой карточки
var attacks := 0              # ударов начато (для «тяжёлой» и «комбо»)
var chained := 0              # ударов, продолживших серию
var shown: Array = []         # порядок показа — для проверки

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_PAUSABLE
	on = bool(g.main.tutorial_on())
	persist = g.main.testing() == ""
	var c: Combat = g.player.combat
	c.attack_started.connect(func(_a: AttackData): attacks += 1)
	c.attack_ended.connect(func(_a: AttackData, ch: bool):
		if ch:
			chained += 1)
	_practice_setup()

func total() -> int:
	return TutorialData.ORDER.size() + TutorialData.STYLES.size()

# ---------------- когда показывать ----------------
func _process(dt: float) -> void:
	var pr: bool = bool(Opts.v("practice")) if force < 0 else force == 1
	if pr != practice:
		set_practice(pr)        # настройку переключили — текущее упражнение пропущено
	if not on or card != null:
		return
	if practice:
		_practice_tick(dt)
		return
	if not fighting():
		return
	fight_t += dt
	since += dt
	if not safe(false):
		return
	var id := pick()
	if id != "":
		show_card(id)

## Идёт бой: враги рядом, сюжет не остановлен
func fighting() -> bool:
	if not game.mode in ["fight", "boss"]:
		return false
	for en in game.enemies:
		if is_instance_valid(en) and en.alive() and en.global_position.distance_to(game.player.global_position) < 24.0:
			return true
	return false

## Можно ли сейчас остановить игру карточкой: никаких своих сцен, меню, диалога, постановки
func safe(now: bool) -> bool:
	var p = game.player
	if game.get_tree().paused or game.paused_story() or game.intro_busy() or game.over or game.death != null or game.panel != null:
		return false
	if game.ipod != null and game.ipod.captures_gameplay_input():
		return false
	if p.switch_to != "" or p.execution.active() or game.hype.active() or game.tag.duo.active():
		return false
	return String(p.state) in (SAFE_NOW if now else SAFE)

## Первая подходящая карточка (по приоритету, с выполненным предшественником и условием); "" — пока никакой
func pick() -> String:
	for key in PRIORITY:
		var id := _resolve(key)
		if id == "" or seen.has(id):
			continue
		if AFTER.has(key) and not seen.has(AFTER[key]):
			continue
		var now: bool = key in NOW
		if since < (GAP_NOW if now else GAP):
			continue
		if now and not safe(true):
			continue
		if not now and not String(game.player.state) in SAFE:
			continue
		if _cond(key):
			return id
	return ""

## style_cur / style_more → id карточки стиля
func _resolve(key: String) -> String:
	var p = game.player
	if key == "style_cur":
		return "style_" + String(p.style.id) if TutorialData.STYLES.has(String(p.style.id)) else ""
	if key == "style_more":
		# сначала стили героя, которым играешь; после карточки «смена героя» — и второго
		for h in ([p.hero, "madk1d" if p.hero == "pahan" else "pahan"] if seen.has("tag") else [p.hero]):
			if not p.heroes.has(h):
				continue
			for sid in p.heroes[h]["styles"]:
				if TutorialData.STYLES.has(String(sid)) and not seen.has("style_" + String(sid)):
					return "style_" + String(sid)
		return ""
	return key

func _near(dist: float, fn: Callable) -> bool:
	var pp: Vector3 = game.player.global_position
	for en in game.enemies:
		if is_instance_valid(en) and en.alive() and en.global_position.distance_to(pp) < dist and fn.call(en):
			return true
	return false

func _cond(key: String) -> bool:
	var p = game.player
	match key:
		"light", "style_cur", "style_more":
			return true
		"heavy":
			return attacks >= 3 or since >= 14.0
		"combo":
			return chained >= 1 or since >= 14.0
		"dodge":
			return _near(6.0, func(en): return en.state == "wind") or since >= 20.0
		"block", "styles", "throw":
			return true
		"charge":
			return p.style.id == "tyaga812" or (p.style.attacks as Dictionary).values().any(func(a): return (a as AttackData).charge)
		"heat":
			return p.style.id == "vozduh" and p.swag >= 40.0 and _near(3.4, func(en): return not en.exec_ready())
		"finisher":
			return _near(5.0, func(en): return en.exec_ready())
		"air":
			return _near(9.0, func(en): return en.state == "air" and en.boss_id == "")
		"adlib":
			return game.buddy.cd <= 0.0 and not game.buddy.ko
		"rage":
			return p.swag >= 100.0 and p.rage <= 0.0
		"boss_open":
			return game.boss_e != null and is_instance_valid(game.boss_e) and float(game.boss_e.weak_t) > 0.0
		"overdrive":
			return game.hype.full()
		"tag":
			return game.tag.tag_block() == ""
		"air_tag":
			return game.tag.hint_kind in ["AIR TAG", "AIR RELAY"]
		"assist":
			return game.tag.assist_cd <= 0.0
		"team_moves":
			return game.tag.hint_kind == "PERFECT TAG" or since >= 25.0
	return false

# ---------------- показ ----------------
## Данные карточки по id: обычная или стиля («style_<id>»)
func content(id: String) -> Dictionary:
	if id.begins_with("style_"):
		return TutorialData.STYLES.get(id.substr(6), {})
	return TutorialData.CARDS.get(id, {})

## Показать карточку. replay — из паузы: не отмечается увиденной заново, игра уже стоит (паузу не снимаем)
func show_card(id: String, replay := false) -> bool:
	if card != null or content(id).is_empty():
		return false
	own_pause = not game.get_tree().paused
	if own_pause:
		game.get_tree().paused = true
	if not replay:
		if state_of(id) == "":
			seen[id] = "introduced"
		shown.append(id)
		_persist()
	card = TutorialCard.new()
	card.data = content(id)
	card.replay = replay
	card.counter = "%d / %d" % [seen.size(), total()]
	card.name = "TutorialCard"
	card.closed.connect(_on_closed)
	game.hud.add_child(card)
	MouseMode.set_to(Input.MOUSE_MODE_VISIBLE)
	game.main.sfx("sfx_ui", -6.0, 0.7)
	return true

func _on_closed() -> void:
	card = null
	since = 0.0
	game.main.sfx("sfx_ui", -10.0, 1.15)
	if own_pause:
		own_pause = false
		game.get_tree().paused = false
		game.player.combat.clear_buffer()        # нажатия, сделанные, пока карточка была открыта, в бой не уходят
		if game.main.testing() == "" and game.panel == null:
			MouseMode.set_to(Input.MOUSE_MODE_CAPTURED)

## Увиденные карточки по порядку — для списка в паузе
func seen_list() -> Array:
	var out: Array = []
	for id in TutorialData.ORDER:
		if seen.has(id):
			out.append(id)
	for sid in Styles.ORDER:
		if seen.has("style_" + String(sid)):
			out.append("style_" + String(sid))
	return out

func title_of(id: String) -> String:
	return TutorialCard.fill(String(content(id).get("title", id)))

# ---------------- сохранение ----------------
## {id: состояние}. Старые сохранения — список увиденных карточек: они становятся «introduced»
func save_data() -> Dictionary:
	var out := {}
	for id in seen:
		out[id] = state_of(String(id))
	return out

func load_data(v) -> void:
	seen = {}
	if v is Array:
		for id in v:
			if not content(String(id)).is_empty():
				seen[String(id)] = "introduced"
	elif v is Dictionary:
		for id in v:
			var st: String = String(v[id])
			if not content(String(id)).is_empty() and st in ["introduced", "completed", "skipped"]:
				seen[String(id)] = st

func reset() -> void:
	seen = {}
	shown = []
	since = GAP - FIRST
	if drill_id != "":
		drill_id = ""
		_release_guard()
		if drill != null:
			drill.visible = false

## Увиденное сразу в файл сохранения: дописываем только ключ "tut" в уже существующий файл,
## остальное (глава, шаг, прокачка) не трогаем. Файла нет — запишется со следующим сохранением игры.
func _persist() -> void:
	if not persist:
		return
	var path: String = save_path if save_path != "" else SAVE_PATH
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return
	d["tut"] = save_data()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

# ---------------- практика: упражнения на настоящей цели ----------------
## Практика вместо всплывающих карточек: панель справа сверху (TutorialCard.Drill), игра не останавливается.
## Шаг засчитывает событие боя (ev) — попадание, уклонение от настоящего замаха, парирование, добивание, смена героя…
## Учебная цель (guard_e) не умирает, пока упражнение не сделано (enemy.train_guard: здоровье не ниже 5 %),
## и чаще замахивается (enemy.train_attack), если упражнение — про защиту. Пропуск — Backspace (tut_skip) или кнопка.
## Состояния: introduced — показано, completed — сделано, skipped — пропущено; повторяются только незаконченные.
const DEF_STATES := ["introduced", "completed", "skipped"]
const GAP_DRILL := 4.0          # секунд боя между упражнениями
const DEFENSE := ["dodge", "block"]
var practice := true            # практика включена (настройка «ПРАКТИКА В ОБУЧЕНИИ»)
var force := -1                 # проверки: 1 — практика, 0 — карточки, -1 — по настройке
var drill_id := ""
var drill_step := 0
var drill_n := 0
var drill: Control              # панель справа сверху
var guard_e = null
var ev_log: Array = []          # для проверок: засчитанные события боя по порядку
var chain_run := false          # следующий удар продолжает серию (attack_ended с chained)
var throw_ids := {}             # атаки, которые идут по [F] (из графа связок стиля)
var _poll := {}                 # длины журналов систем на прошлом кадре

## Упражнение пройдено или пропущено (повторять не надо)
func done(id: String) -> bool:
	return String(seen.get(id, "")) in ["completed", "skipped"]

func state_of(id: String) -> String:
	var v = seen.get(id, "")
	return "introduced" if v is bool else String(v)

func steps_of(id: String) -> Array:
	return TutorialData.DRILLS.get(id, [])

func _practice_setup() -> void:
	var c: Combat = game.player.combat
	c.attack_hit.connect(_on_hit)
	c.attack_ended.connect(func(_a: AttackData, ch: bool): chain_run = ch)
	game.feedback_fired.connect(_on_feedback)
	game.player.execution.executed.connect(func(_e, _s, _c): emit("exec"))
	game.tag.tagged.connect(func(_h: String, move: String):
		emit("tag")
		if move == "air_tag":
			emit("air_tag")
		elif move != "" and move != "swap":
			emit("team_move"))
	game.hype.overdrive_started.connect(func(): emit("overdrive"))

## Отклик боя (feedback.gd): Perfect Dodge, парирование, удар в блок
func _on_feedback(fb: String, _pos: Vector3, _mul: float) -> void:
	if fb == "perfect_dodge":
		emit("perfect")
	elif fb == "parry" or fb == "block":
		emit(fb)

func _on_hit(a: AttackData, n: int) -> void:
	if n <= 0:
		return
	var p = game.player
	if p.style.heat.has(a.id) or a.kind == "heat":
		emit("heat")
	if float(p.combat.charged) > 0.55:
		emit("hit_charged")
	if _throw_ids().has(a.id):
		emit("hit_throw")
	var heavy: bool = a.power >= 1 or a.heavy
	emit("hit_heavy" if heavy else "hit_light")
	if chain_run:
		emit("hit_chain")
		if heavy:
			emit("hit_chain_heavy")
	if a.launch > 3.0 or a.kind == "launcher":
		emit("launch")
	if _near(4.5, func(en): return en.state == "air"):
		emit("air_hit")
	var b = game.boss_e
	if b != null and is_instance_valid(b) and float(b.weak_t) > 0.0 and b.global_position.distance_to(p.global_position) < 6.0:
		emit("boss_open_hit")

## атаки стиля, которые запускаются [F] (по графу связок)
func _throw_ids() -> Dictionary:
	var sid: String = game.player.style.id
	if not throw_ids.has(sid):
		var d := {}
		for from in game.player.style.links:
			var l = game.player.style.links[from]
			if l is Dictionary and (l as Dictionary).has("throw"):
				d[String(l["throw"])] = true
		throw_ids[sid] = d
	return throw_ids[sid]

## Журналы систем боя: что прибавилось с прошлого кадра
func _grew(key: String, arr: Array, kinds: Array) -> bool:
	var n0: int = int(_poll.get(key, arr.size()))
	_poll[key] = arr.size()
	if arr.size() < n0:
		return false
	for i in range(n0, arr.size()):
		var e = arr[i]
		if kinds.is_empty() or (e is Array and (e as Array).size() > 0 and String(e[0]) in kinds):
			return true
	return false

func _poll_events() -> void:
	var p = game.player
	if _grew("duo", game.tag.duo.events, ["end"]):
		emit("duo")
	if _grew("flow", p.flow.events, ["perfect"]):
		emit("perfect_swap")
	if _grew("flow_any", p.flow.events, []):
		emit("style")
	if _grew("rico", p.bottles.rico_log, []):
		emit("rico")
	if _grew("tyaga", p.tyaga.events, ["link"]):
		emit("tg_link")
	if _grew("tyaga_b", p.tyaga.events, ["burst"]):
		emit("hit_charged")
	if _grew("skate", p.skate.events, ["trick"]):
		emit("trick")
	if _grew("guitar", p.guitar.events, ["beat"]):
		emit("beat")
	if _grew("breaker", p.breaker.events, ["freeze", "perfect"]):
		emit("freeze")
	var st: String = String(p.state)
	var st0: String = String(_poll.get("state", st))
	_poll["state"] = st
	if st == "rage" and st0 != "rage":
		emit("rage")
	if st == "roll" and st0 != "roll" and _near(4.5, func(en): return en.state == "wind"):
		emit("dodge_wind")
	if p.tyaga.caught.size() > 0:
		emit("suck_caught")
	var cd: float = float(game.buddy.cd)
	if cd > float(_poll.get("adlib", cd)) + 1.0:
		emit("adlib")
	_poll["adlib"] = cd

## Событие боя: засчитать шаг текущего упражнения
func emit(ev: String) -> void:
	ev_log.append(ev)
	if ev_log.size() > 200:
		ev_log.pop_front()
	if drill_id == "":
		return
	var steps: Array = steps_of(drill_id)
	if drill_step >= steps.size():
		return
	var st: Dictionary = steps[drill_step]
	if String(st["ev"]) != ev:
		return
	drill_n += 1
	if drill_n >= int(st.get("n", 1)):
		drill_step += 1
		drill_n = 0
		if drill_step >= steps.size():
			finish_drill("completed")
			return
		game.main.sfx("sfx_ui", -8.0, 1.5)
	if drill != null:
		drill.call("show_step", drill_id, drill_step, drill_n, false)

func _practice_tick(dt: float) -> void:
	_poll_events()
	var show: bool = drill_id != "" and fighting() and not game.paused_story() and not game.intro_busy() and not game.over
	if drill != null:
		drill.visible = show or bool(drill.call("busy"))
	if drill_id != "":
		_keep_guard()
		return
	if not fighting():
		return
	fight_t += dt
	since += dt
	if since < GAP_DRILL or not safe(false):
		return
	var id := pick_drill()
	if id != "":
		start_drill(id)

## Следующее упражнение: по приоритету, после пройденного предшественника, когда обстановка позволяет
func pick_drill() -> String:
	for key in PRIORITY:
		var id := _resolve_drill(key)
		if id == "" or done(id) or steps_of(id).is_empty():
			continue
		if AFTER.has(key) and not done(String(AFTER[key])):
			continue
		if _drill_cond(key):
			return id
	return ""

func _resolve_drill(key: String) -> String:
	var p = game.player
	if key == "style_cur":
		return "style_" + String(p.style.id) if TutorialData.STYLES.has(String(p.style.id)) else ""
	if key == "style_more":
		for h in ([p.hero, "madk1d" if p.hero == "pahan" else "pahan"] if done("tag") else [p.hero]):
			if not p.heroes.has(h):
				continue
			for sid in p.heroes[h]["styles"]:
				if TutorialData.STYLES.has(String(sid)) and not done("style_" + String(sid)):
					return "style_" + String(sid)
		return ""
	return key

## Когда упражнение можно сделать: механика доступна сейчас
func _drill_cond(key: String) -> bool:
	match key:
		"air", "finisher", "dodge", "block", "throw", "styles", "team_moves", "light", "heavy", "combo", "style_cur", "style_more":
			return true
		"air_tag":
			return done("tag")
		"boss_open":
			return game.boss_e != null and is_instance_valid(game.boss_e) and game.boss_e.alive()
	return _cond(key)

func start_drill(id: String) -> void:
	drill_id = id
	drill_step = 0
	drill_n = 0
	if state_of(id) == "":
		seen[id] = "introduced"
		shown.append(id)
		_persist()
	if drill == null:
		drill = TutorialCard.Drill.new()
		drill.name = "TutorialDrill"
		game.hud.add_child(drill)
		drill.connect("skip_pressed", func(): finish_drill("skipped"))
	drill.call("open", id, content(id), steps_of(id))
	drill.call("show_step", id, 0, 0, false)
	_keep_guard()
	game.main.sfx("sfx_ui", -8.0, 0.8)

func finish_drill(state: String) -> void:
	if drill_id == "":
		return
	seen[drill_id] = state
	_persist()
	if drill != null:
		drill.call("finish", state)
	ev_log.append("drill_" + state + ":" + drill_id)
	drill_id = ""
	since = 0.0
	_release_guard()
	game.main.sfx("sfx_ui", -6.0, 1.3 if state == "completed" else 0.8)

## Учебная цель: захваченная (lockon) или ближайшая; не умирает до конца упражнения
func _keep_guard() -> void:
	var want_boss: bool = drill_id == "boss_open"
	if guard_e != null and (not is_instance_valid(guard_e) or not guard_e.alive()):
		guard_e = null
	if guard_e == null:
		var best = null
		var bd := 15.0
		if game.lock != null and game.lock.active() and (game.lock.target.boss_id != "") == want_boss:
			best = game.lock.target
		else:
			for en in game.enemies:
				if is_instance_valid(en) and en.alive() and (en.boss_id != "") == want_boss:
					var d: float = en.global_position.distance_to(game.player.global_position)
					if d < bd:
						bd = d
						best = en
		guard_e = best
	if guard_e != null:
		guard_e.train_guard = drill_id != "finisher"        # добивание должно убить — цель не держим
		guard_e.train_attack = drill_id in DEFENSE

func _release_guard() -> void:
	if guard_e != null and is_instance_valid(guard_e):
		guard_e.train_guard = false
		guard_e.train_attack = false
	guard_e = null

func _unhandled_input(e: InputEvent) -> void:
	if drill_id != "" and e.is_action_pressed("tut_skip"):
		finish_drill("skipped")
		get_viewport().set_input_as_handled()

## Пропуск обучения целиком: текущее — пропущено, дальше упражнений нет (настройка)
func set_practice(v: bool) -> void:
	practice = v
	if not v and drill_id != "":
		finish_drill("skipped")
