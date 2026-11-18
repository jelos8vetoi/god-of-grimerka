## Боевое обучение (TutorialManager): карточки по одной, когда механика впервые пригодилась в бою.
## Систему боя не трогает — только читает её состояние (player, combat, enemies, tag, hype) и сигналы ядра боя.
## Порядок: у карточки есть предшественник (тяжёлый — после лёгкого, блок — после уклонения…) и условие по обстановке
## (_cond: враг замахнулся рядом, враг в воздухе, над врагом ✕, СВЭГ полный…). Между карточками — пауза боя GAP,
## у «мгновенных» (воздух, добивание, босс открыт, AIR TAG) — короче, иначе момент уйдёт.
## Карточка останавливает игру, только если пауза наша (own_pause): чужую паузу (меню) не снимаем.
## Увиденные карточки — в сохранении игры (ключ "tut"); новая игра начинает обучение заново; старые сохранения без ключа — тоже.
## Повтор — из паузы, вкладка СИСТЕМА → «БОЕВЫЕ ПОДСКАЗКИ» (replay).
## Включено только в обычной игре (main.tutorial_on) и в проверке --tutorialcheck — автопроверки боя карточки не прерывают.
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
var seen := {}                # id карточки → true
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

func total() -> int:
	return TutorialData.ORDER.size() + TutorialData.STYLES.size()

# ---------------- когда показывать ----------------
func _process(dt: float) -> void:
	if not on or card != null or not fighting():
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
		seen[id] = true
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
func save_data() -> Array:
	return seen.keys()

func load_data(v) -> void:
	seen = {}
	if v is Array:
		for id in v:
			if not content(String(id)).is_empty():
				seen[String(id)] = true

func reset() -> void:
	seen = {}
	shown = []
	since = GAP - FIRST

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
