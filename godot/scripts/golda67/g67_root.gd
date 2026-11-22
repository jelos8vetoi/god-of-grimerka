## «ГОЛДА 67» — сюжетный roguelite-приквел (godot/docs/golda67/SPEC.md, DECISIONS.md).
## Контроллер режима: вешается на обычный game.gd (как Training), поэтому бой, стили, враги и HUD — те же, что в
## кампании; сюжет кампании не идёт, её сохранение не пишется (game._save выходит). Своё сохранение — G67Save.
##
## Сделано: хаб «ПОДЪЕЗД» и игровой цикл первого района — ДВОР: забег из семи этапов в одном дворе (герой ходит между
## ними пешком: бой → выбор следующего места → … → засада → босс Миша Минасян), волны врагов, голда забега, баффы
## семейства Миши, постоянный ларёк, заначки, РЕСПЕКТ, открытие Водяры.
## Не сделано: остальные районы, случайные события двора.
class_name Golda67
extends Node

const REACH := 1.4            # с какого расстояния предмет «под рукой»
const TITLE := "ГОЛДА 67"
const HUB_CAM_LEN := 3.2      # длина штанги камеры в подъезде (тесно), во дворе — прежние 4,6
const YARD_CAM_LEN := 4.6
const FADE_FAR := 1.3         # камера ближе этого к плечам героя — он начинает таять
const FADE_NEAR := 0.6        # на этом расстоянии прозрачность 0,75
const FADE_MAX := 0.75

var game
var world: G67World
var place := "hub"            # hub | run
var data: Dictionary = {}
var near := ""                # id предмета под рукой («» — нет)
var prompt: Label
var events: Array = []        # для проверок: ["enter", место], ["near", id], ["use", id], ["room", тип], ["clear"], ["fit", id]…
var _t := 0.0

# ---- забег
var run: Dictionary = {}      # {district, tpl, pos (индекс этапа 0…6), golda, fits, respect, rooms, kills, earned, spent, stages, stash…}
var room: Dictionary = {}     # текущий вариант этапа {type, place}
var room_state := ""          # fight | reward | open | boss | over
const HintsScript := preload("res://scripts/golda67/g67_hints.gd")
var hints                     # подсказки по ходу забега (один раз за сохранение)
var stash_nodes := {}         # индекс места заначки → монета во дворе
var dlg_hint_used := false    # строка управления в окне диалога уже показывалась в этом запуске режима
var save_recovered := ""      # основной файл сохранения был повреждён, прогресс взят из этой копии
var recovered_respect := -1   # прошлый забег оборвался в бою: засчитан поражением, столько РЕСПЕКТА он дал
var waves: Array = []
var wave_i := -1
var wave_wait := 0.0
var pending: Array = []
var spawn_cd := 0.0
var wind_used := false        # «ВТОРОЕ ДЫХАНИЕ» уже сработало в этой комнате
var base_hp := 100.0
var busy := false             # идёт переход между комнатами
var mods: G67RunMods          # game.run_mods в приквеле: артефакты внутри удара и урона
var fit_mul := 1.0            # множитель урона от фитсов и АВТОРИТЕТА (артефакты добавляются сверху, потолок DMG_CAP_ALL)
var fin_room := 0.0           # сколько уже вылечила ДОБИВАЛА в этой комнате
var cass_until := -9.0        # «Кассета 2016»: до какого времени +20 % урона
var cass_next := -9.0         # и когда сработает снова
var _last_hp := -1.0
var _last_swag := -1.0
# ---- постановка (выход босса): камеру и ввод на это время держит контроллер
const SCENE_LEN := 7.6        # выход Миши: сидит на троне → встаёт → идёт по ковру → топает → бой
const SCENE_SIT := 1.7        # до этой секунды сидит
const SCENE_WALK := 2.5       # с этой идёт
const SCENE_STOP := 5.4       # к этой дошёл
var scene_step := 0
var scene_from := Vector3.ZERO
var scene_to := Vector3.ZERO
var scene_t := -1.0           # −1 — постановки нет
var scene_boss = null
var scene_said := false

func setup(g) -> void:
	game = g
	game.feedback_fired.connect(_on_feedback)
	mods = G67RunMods.new(self)
	game.run_mods = mods
	game.player.execution.executed.connect(_on_executed)
	game.player.flow.swapped.connect(_on_swapped)
	process_mode = Node.PROCESS_MODE_ALWAYS      # подсказку [E] нужно гасить и на паузе
	data = G67Save.load_all()
	save_recovered = G67Save.recovered
	# боссы и говорящие приквела — в копию сюжета этого экземпляра игры (story.json не меняется)
	for id in G67Data.BOSSES:
		game.story["BOSS"][id] = (G67Data.BOSSES[id] as Dictionary).duplicate(true)
	for sp in G67Data.SPEAKERS:
		game.story["SPK"][sp] = (G67Data.SPEAKERS[sp] as Dictionary).duplicate()

func save() -> void:
	if game.main.user_play():          # проверки сохранение игрока не пишут
		G67Save.save_all(data)

func meta() -> Dictionary:
	return data["meta"]

## Открыт ли madk1d (управление, его стили, смена героя, дуэт, Team Hype, Overdrive) — после первой концовки
func madk_open() -> bool:
	return bool((meta().get("flags", {}) as Dictionary).get(G67Data.MADK_FLAG, false))

## madk1d нет рядом с героем: до первой концовки он ждёт в подъезде и в забег не идёт (в самом подъезде ходит рядом как житель)
func madk_away() -> bool:
	return place == "run" and not madk_open()

## madk1d — житель подъезда (до первой концовки): стоит у левой стены холла
func madk_home() -> bool:
	return place == "hub" and not madk_open()

const MADK_SPOT := Vector3(-2.3, 0.0, 2.4)

## Старт режима: хаб
func begin(_cont := false) -> void:
	game.mode = "golda67"
	game.ch = 0
	meta()["visits"] = int(meta().get("visits", 0)) + 1
	recovered_respect = _recover_broken_run()
	save()
	base_hp = game.player.max_hp
	await enter_hub()
	if save_recovered != "":
		game.toast("Сохранение было повреждено — прогресс восстановлен из резервной копии")
		save()
		save_recovered = ""
	if recovered_respect >= 0:
		game.toast("Прошлый забег оборвался в бою — засчитан как поражение. РЕСПЕКТ +%d" % recovered_respect)
	unlock_clip("V00")                       # трейлер — на телевизоре в подъезде с первого входа
	if auto_clips and not auto_played("STORY01"):
		_first_clips()                       # не ждём: переход из меню сначала открывает подъезд

## Первые ролики — после того, как шторка перехода из меню открыла подъезд и вернула цвет. Раньше begin() ждал
## их до конца, и полминуты роликов шторка висела под ними, а подъезд проявлялся уже после.
func _first_clips() -> void:
	var fx = game.main.intro_fx if game.main != null else null
	var t0 := GameClock.ms()
	while is_instance_valid(self) and GameClock.ms() - t0 < 6000 and (fx == null or bool(fx.busy) or float(fx.mono_v) > 0.02):
		await game.get_tree().process_frame
	if not is_instance_valid(self) or clip != null:
		return
	await play_auto("STORY01")               # регистрация — до первого забега
	await play_auto("STORY05")               # первое обращение организатора

func _swap_world(build: Callable) -> void:
	game._clear_fight()
	game.boss_e = null
	if game.world:
		game.world.free()
	world = G67World.new()
	game.world = world
	game.add_child(world)
	game.in_hall = false
	build.call(world)
	near = ""

func enter_hub() -> void:
	hub_back_t = 8.0 if place == "run" else 0.0
	place = "hub"
	room_state = ""
	run = {}
	game.reset_arena()
	_swap_world(func(w: G67World): w.build("g67_hub"))
	var p = game.player
	p.max_hp = hp_max()
	p.hp = p.max_hp
	p.dmg_mul = 1.0 + 0.04 * float(up("dmg"))
	p.global_position = world.spawn_pos
	p.velocity = Vector3.ZERO
	p.face = PI                  # вошёл с улицы: лицом в холл, к лестнице; камера за спиной (cam_yaw = face − PI)
	game.cam_yaw = 0.0
	game.cam_len = HUB_CAM_LEN
	game.buddy.visible = true
	game.buddy.global_position = (MADK_SPOT + Vector3(0, 0.05, 0)) if not madk_open() else (world.spawn_pos + Vector3(-1.1, 0.0, -0.7))
	game.buddy.face = PI * 0.5
	game.buddy.target = Vector3.ZERO
	if not madk_open() and not result.is_empty():
		game.buddy.home_react = "Cheer" if bool(result.get("won", false)) else "StyleSwitch"
		game.buddy.home_until = 0.0
		result = {}
	apply_styles()
	game.tutorial.on = false
	game.tutorial.persist = false
	game.fx.prewarm(p.global_position)
	_build_prompt()
	_place_krot("hub")
	_hub_marks()
	refresh_hints()
	events.append(["enter", "hub"])
	await game.get_tree().process_frame
	game.banner(TITLE, "ПОДЪЕЗД · РЕСПЕКТ: %d" % int(meta().get("respect", 0)), Color(1.0, 0.8, 0.2), 3.5)

func _build_prompt() -> void:
	if prompt != null and is_instance_valid(prompt):
		return
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.0
	prompt.anchor_right = 1.0
	prompt.anchor_top = 0.72
	prompt.anchor_bottom = 0.72
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	game.hud_root.add_child(prompt)

# ---------------------------------------------------------------- стили
## Какие стили Пахана открыты (SPEC, раздел 6): до первого босса — только Балон VOZDUH; Водяра — после победы над
## Мишей Минасяном; ТЯГА-812 — после победы над FORTUNA 812. Новых стилей нет — только три существующих.
func styles_open() -> Array:
	var fl: Dictionary = meta().get("flags", {})
	var out: Array = ["vozduh"]
	if bool(fl.get("boss_misha", false)):
		out.append("bottles")
	if bool(fl.get("boss_fortuna", false)):
		out.append("tyaga812")
	return out

## Оставить герою только открытые стили (список у Пахана общий с его записью в player.heroes — меняем на месте)
func apply_styles() -> void:
	var p = game.player
	var open := styles_open()
	var list: Array = p.heroes["pahan"]["styles"]
	list.clear()
	for s in open:
		list.append(s)
	if p.hero == "pahan":
		p.own_styles = list
		if not list.has(String(p.style.id)):
			p.set_style("vozduh")

# ---------------------------------------------------------------- забег
## Двор строится один раз на забег. Герой выходит из двери подъезда и идёт ногами, мир между этапами не пересобирается.
func _build_yard_world() -> void:
	_swap_world(func(w: G67World): w.build_yard())
	krot_k = {}
	if world.yard != null:
		for l in world.yard.lifes:
			(l as G67Life).watcher = game.player       # жители замечают Пахана, когда он рядом и впереди
	world.add_kiosk()
	world.add_home()
	_place_krot_yard()
	_build_stash()

## Герой — у двери дома лицом во двор, камера за спиной
func _stand_at_home() -> void:
	game.cam_len = YARD_CAM_LEN
	var p = game.player
	p.global_position = G67Yard.HOME_DOOR + Vector3(0, 0.05, -4.5)
	p.velocity = Vector3.ZERO
	p.face = PI
	game.cam_yaw = 0.0
	game.fx.prewarm(p.global_position)

func _seed_yard() -> void:
	G67Yard.secret_tag = bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false))      # граффити-секрет — после победы над Мишей
	G67Yard.crowd_seed = int(meta().get("runs", 0)) * 31 + int(meta().get("visits", 0)) + 1      # очередь у ларька — каждый забег другая

## Герой полупрозрачен, когда камера прижалась к нему (вплотную к стене или борту): плавно от 1,3 м (0) до 0,6 м (0,75)
var _fade_last := 0.0
var _fade_meshes: Array = []
var _fade_key := ""
func hero_fade() -> void:
	var p = game.player
	var head: Vector3 = p.vis_pos() + Vector3(0, 1.55, 0)
	var d: float = game.cam.global_position.distance_to(head)
	var k: float = clampf((FADE_FAR - d) / (FADE_FAR - FADE_NEAR), 0.0, 1.0) * FADE_MAX
	if k == 0.0 and _fade_last == 0.0:
		return
	var key := "%d|%s|%s" % [p.rig.get_instance_id(), String(p.hero), String(p.style.id)]
	if key != _fade_key:
		_fade_key = key
		_fade_meshes = p.rig.find_children("*", "GeometryInstance3D", true, false)       # список — один раз на смену рига и стиля
	_fade_last = k
	for gi in _fade_meshes:
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).transparency = k

## Начать забег: район ДВОР, первый этап. До первой концовки madk1d остаётся в подъезде (SPEC, раздел 3).
func start_run(district_id := "dvor") -> void:
	if busy:
		return
	place = "run"
	var gold0 := 30 * up("gold")
	run = {"district": district_id, "tpl": int(meta().get("runs", 0)) % 3, "pos": 0, "golda": gold0, "fits": {}, "respect": 0, "rooms": 0,
		"rerolls": up("reroll"), "arts": [], "kiosk": {}, "kills": 0, "earned": gold0, "spent": 0, "stages": [], "stash_n": 0}
	cass_until = -9.0
	cass_next = -9.0
	var ss := start_style()
	if game.player.hero == "pahan" and String(game.player.style.id) != ss:
		game.player.set_style(ss)
	_seed_yard()
	run["stash"] = _stash_plan()
	game.buddy.visible = false
	game.buddy.global_position = Vector3(0, -50, 0)
	events.append(["run", district_id])
	unlock_clip("CL01")                      # «КАК ЗАЙТИ ВО ДВОР» — в архив после входа во ДВОР
	apply_fits()
	wind_used = false
	_build_yard_world()
	_stand_at_home()
	await enter_room((route()[0] as Array)[0])

## Домой посреди забега: дверь подъезда во дворе (между этапами, вне боя). Забег — в сохранение (data["run"]:
## забег, этап, здоровье, состояние), в подъезде он стоит на паузе; выход во двор продолжает его с двери подъезда —
## варианты следующего этапа снова открыты. Гибель или конец забега стирают паузу (_finish_run).
func go_home() -> void:
	if busy or place != "run" or room_state != "open":
		return
	_save_run("open")
	events.append(["home"])
	game.main.ui("confirm")
	await enter_hub()
	game.toast("Забег на паузе — выход во двор продолжит его")

func paused_run() -> bool:
	return not (data.get("run", {}) as Dictionary).is_empty() and (data["run"] as Dictionary).has("room")

## Контрольная запись забега: state — open (между этапами) | fight (идёт бой). В награде (баф или артефакт ещё не взят)
## запись откатывается на этап назад: выбор можно сделать заново, ничего не выдано дважды.
func _save_run(state: String) -> void:
	if place != "run" or run.is_empty():
		return
	var rr: Dictionary = run.duplicate(true)
	var rm: Dictionary = room.duplicate(true)
	if state == "open" and room_state == "reward" and String(room.get("type", "")) in ["fit", "storage"]:
		rr["pos"] = maxi(0, int(rr["pos"]) - 1)
		rm = {"type": "battle", "place": String(room.get("place", ""))}
	var pp: Vector3 = game.player.global_position
	data["run"] = {"run": rr, "room": rm, "hp": float(game.player.hp), "state": state, "pos3": [pp.x, pp.y, pp.z]}
	save()

## Старая запись (шесть позиций, без шаблона) читается: шаблон 0, позиция не дальше шестой, этап пройден
func _migrate_run() -> void:
	if not run.has("tpl"):
		run["tpl"] = 0
	run["pos"] = clampi(int(run.get("pos", 0)), 0, 5)
	for k in ["kills", "earned", "spent", "stash_n"]:
		run[k] = int(run.get(k, 0))
	if not run.has("stages"):
		run["stages"] = []
	if not run.has("kiosk"):
		run["kiosk"] = {}
	if not run.has("stash"):
		run["stash"] = _stash_plan()

func resume_run() -> void:
	if busy or not paused_run():
		return
	busy = true
	var sv: Dictionary = data["run"]
	run = (sv["run"] as Dictionary).duplicate(true)
	room = (sv["room"] as Dictionary).duplicate(true)
	_migrate_run()
	place = "run"
	_seed_yard()
	game.buddy.visible = false
	game.buddy.global_position = Vector3(0, -50, 0)
	wind_used = false
	_build_yard_world()
	apply_fits()
	var p = game.player
	p.hp = clampf(float(sv.get("hp", p.max_hp)), 1.0, p.max_hp)
	_stand_at_home()
	events.append(["resume", int(run.get("pos", 0))])
	await game.get_tree().process_frame
	_open_gates()
	var d := district()
	game.banner("%s · %d / %d" % [String(d["name"]), int(run["pos"]) + 1, route().size()], "ЗАБЕГ ПРОДОЛЖАЕТСЯ", Color(1.0, 0.8, 0.2), 2.4)
	busy = false

## Забег оборвался в бою (выход из игры, сбой): запись с боем засчитывается поражением. Возвращает РЕСПЕКТ или −1.
func _recover_broken_run() -> int:
	var sv: Dictionary = data.get("run", {})
	if sv.is_empty() or not String(sv.get("state", "open")) in ["fight", "boss"]:
		return -1
	var got := int((sv.get("run", {}) as Dictionary).get("respect", 0))
	meta()["respect"] = int(meta().get("respect", 0)) + got
	meta()["runs"] = int(meta().get("runs", 0)) + 1
	data["run"] = {}
	events.append(["recovered", got])
	return got

## Выход в меню (game._to_menu): hub — прогресс сохранён; safe — забег вне боя встанет на паузу; fight — идёт бой
func quit_kind() -> String:
	if place != "run" or run.is_empty() or room_state == "over":
		return "hub"
	return "fight" if room_state in ["fight", "boss"] else "safe"

func quit_text() -> String:
	match quit_kind():
		"safe":
			return "Забег сохранён: этап %d из %d пройден. Продолжишь с двери подъезда." % [int(run["pos"]) + 1, route().size()]
		"fight":
			return "Идёт бой: выход засчитается как поражение. РЕСПЕКТ за пройденное (+%d) останется, голда сгорит." % int(run.get("respect", 0))
	return "Прогресс сохранён."

func on_quit() -> void:
	match quit_kind():
		"fight":
			var got := int(run.get("respect", 0))
			meta()["respect"] = int(meta().get("respect", 0)) + got
			meta()["runs"] = int(meta().get("runs", 0)) + 1
			data["run"] = {}
			room_state = "over"
			save()
			events.append(["quit", "fight", got])
		"safe":
			_save_run("open")
			events.append(["quit", "safe"])
		_:
			events.append(["quit", "hub"])

# ---------------------------------------------------------------- заначки
## Какие 5 из 12 мест двора хранят монеты в этом забеге (выбор — от crowd_seed, один и тот же при продолжении)
func _stash_plan() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = G67Yard.crowd_seed * 131 + 7
	var idx: Array = []
	for i in G67Yard.STASH.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	return {"spots": idx.slice(0, G67Yard.STASH_N), "taken": []}

## Сколько голды в заначке: 8…15, одно и то же при продолжении
func stash_gold(i: int) -> int:
	return 8 + int(absf(sin(float(G67Yard.crowd_seed * 17 + i * 31) * 12.9898) * 43758.5453)) % 8

func _build_stash() -> void:
	stash_nodes = {}
	var st: Dictionary = run.get("stash", {})
	var taken: Array = st.get("taken", [])
	for i in st.get("spots", []):
		if taken.has(i):
			continue
		var pos: Vector3 = G67Yard.STASH[int(i)]
		var coin := G67Models.spawn("g67_golda_coin", world, pos + Vector3(0, 0.55, 0), float(i), Vector3(99, 0.5, 99))
		coin.name = "stash%d" % int(i)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.82, 0.35)
		lt.light_energy = 0.6
		lt.omni_range = 3.0
		lt.position = Vector3(0, 0.2, 0)
		coin.add_child(lt)
		stash_nodes[int(i)] = coin

## Монета подбирается сама, когда герой подошёл ближе 1,2 м и боя нет
func _stash_tick(dt: float) -> void:
	if stash_nodes.is_empty():
		return
	var calm: bool = room_state in ["open", "reward"] and not busy and not game.over
	var pp: Vector3 = game.player.global_position
	for i in stash_nodes.keys():
		var n: Node3D = stash_nodes[i]
		if not is_instance_valid(n):
			stash_nodes.erase(i)
			continue
		n.rotate_y(dt * 1.8)
		if not calm or Vector2(pp.x - n.global_position.x, pp.z - n.global_position.z).length() > G67Yard.STASH_R:
			continue
		var got := add_golda(stash_gold(int(i)))
		((run["stash"] as Dictionary)["taken"] as Array).append(int(i))
		run["stash_n"] = int(run.get("stash_n", 0)) + 1
		game.popup(pp + Vector3(0, 2.2, 0), "+%d голды" % got, Color(1.0, 0.85, 0.3))
		game.main.ui("confirm")
		game.fx.twinkle(n.global_position, 10, Color(1, 0.85, 0.4), 0.7)
		n.queue_free()
		stash_nodes.erase(i)
		events.append(["stash", int(i)])

## Засада стартует сама, когда герой вошёл в прямоугольник её зоны (ужатый на 2 м)
func _ambush_tick() -> void:
	if room_state != "open" or busy or world == null:
		return
	var pp: Vector3 = game.player.global_position
	for i in world.gates.size():
		var g: Dictionary = world.gates[i]
		if not bool(g["auto"]):
			continue
		var z: Dictionary = G67Yard.zone(String((g["option"] as Dictionary).get("place", "")))
		var c: Vector3 = z["c"]
		var h: Vector2 = (z["h"] as Vector2) - Vector2(2, 2)
		if absf(pp.x - c.x) < h.x and absf(pp.z - c.z) < h.y:
			choose_gate(i)
			return

# ---------------------------------------------------------------- АВТОРИТЕТ РАЙОНА и стойка стилей
## Уровень улучшения (meta["up"]); цена следующего уровня; покупка за РЕСПЕКТ — только у работающих веток
func up(id: String) -> int:
	return int((meta().get("up", {}) as Dictionary).get(id, 0))

func up_info(id: String) -> Dictionary:
	for u in G67Data.UPGRADES:
		if String(u["id"]) == id:
			return u
	return {}

func up_cost(id: String) -> int:
	return int(G67Data.UP_COST[clampi(up(id), 0, G67Data.UP_COST.size() - 1)])

func buy_up(id: String) -> bool:
	var u := up_info(id)
	if u.is_empty() or not bool(u["live"]) or up(id) >= int(u["max"]):
		return false
	var cost := up_cost(id)
	if int(meta().get("respect", 0)) < cost:
		return false
	meta()["respect"] = int(meta()["respect"]) - cost
	var ups: Dictionary = meta().get("up", {})
	ups[id] = up(id) + 1
	meta()["up"] = ups
	save()
	events.append(["up", id, int(ups[id])])
	if place == "hub":
		var p = game.player
		p.max_hp = hp_max()
		p.hp = p.max_hp
		p.dmg_mul = 1.0 + 0.04 * float(up("dmg"))
	return true

## Здоровье героя в приквеле до фитсов: своё + «ЗДОРОВЬЕ» из АВТОРИТЕТА РАЙОНА
func hp_max() -> float:
	return base_hp + 10.0 * float(up("hp"))

## С каким стилем Пахан выходит в забег (стойка стилей); закрытый стиль не выбирается
func start_style() -> String:
	var s := String(meta().get("start_style", "vozduh"))
	return s if styles_open().has(s) else "vozduh"

func set_start_style(sid: String) -> void:
	if not styles_open().has(sid):
		return
	meta()["start_style"] = sid
	save()
	events.append(["start_style", sid])
	if game.player.hero == "pahan":
		game.player.set_style(sid)

# ---------------------------------------------------------------- значки в подъезде
## Над dj flürr — «новый разговор», над телевизором — «новое» (непросмотренный ролик); КРОТ найден — карточка
var mark_talk: Sprite3D
var mark_tv: Sprite3D

func _hub_marks() -> void:
	mark_talk = null
	mark_tv = null
	if place != "hub" or world == null:
		return
	var fr = world.actors.get("g67_dj_flurr")
	if fr != null and is_instance_valid(fr):
		mark_talk = G67Icons.sprite("icon_new_talk", 0.0011)
		if mark_talk != null:
			world.add_child(mark_talk)
			mark_talk.global_position = (fr as Node3D).global_position + Vector3(0, 2.25, 0)
	var tvp := point("tv")
	if not tvp.is_empty():
		mark_tv = G67Icons.sprite("icon_new_talk", 0.0008)
		if mark_tv != null:
			world.add_child(mark_tv)
			mark_tv.global_position = Vector3(tvp["pos"]) + Vector3(0, 1.75, -0.4)
	_marks_tick()

func flurr_new() -> bool:
	return flurr_state() > int(meta().get("flurr", -1))

func clips_new() -> bool:
	for cid in G67Clips.ORDER:
		if clip_open(cid) and not clip_seen(cid):
			return true
	return false

func _marks_tick() -> void:
	if mark_talk != null and is_instance_valid(mark_talk):
		mark_talk.visible = flurr_new() and game.mode != "dlg"
	if mark_tv != null and is_instance_valid(mark_tv):
		mark_tv.visible = clips_new()

func _krot_card(n: int) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 54
	game.add_child(cl)
	var box := MGUI.panel(true, MGUI.GOLD, MGUI.S3)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-170, 90)
	box.custom_minimum_size = Vector2(340, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(box)
	var h := MGUI.hbox(MGUI.S3)
	box.add_child(h)
	var ic := G67Icons.rect("icon_krot_found", 64)
	if ic != null:
		h.add_child(ic)
	var v := MGUI.vbox(0)
	h.add_child(v)
	v.add_child(MGUI.label("КРОТ НАЙДЕН", "h2", MGUI.GOLD))
	v.add_child(MGUI.label("встреча %d из 10 · в архиве у телевизора" % n, "small", MGUI.TEXT_2))
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(cl.queue_free)
	events.append(["krot_card", n])

func district() -> Dictionary:
	return G67Data.district(String(run.get("district", "dvor")))

## Начать этап на месте: герой уже стоит там, где его вариант (у вешалки, у бокса, у лавки, у калитки), или в зоне боя.
## Двор не пересобирается и не сдвигается: меняются только арена боя, ограждения и награда.
func enter_room(r: Dictionary) -> void:
	busy = true
	room = r
	wind_used = false
	fin_room = 0.0
	var type := String(r["type"])
	var zid := String(r.get("place", "podezd"))
	var zone := G67Yard.zone("sport" if type == "boss" else zid)
	game.set_arena(zone["c"], zone["h"])
	world.clear_gates()
	if type != "storage":
		world.points = world.points.filter(func(pt): return String(pt["id"]) != "storage")      # открытый бокс прошлого этапа закрыт
	var p = game.player
	if type == "boss":
		world.bound_zone("sport", false)
		world.drop_statist()
		p.global_position = G67Yard.BOSS_ENTRY
		p.velocity = Vector3.ZERO
		p.face = PI
		game.cam_yaw = 0.0
		game.fx.prewarm(p.global_position)
	elif type in ["battle", "elite", "ambush"]:
		world.bound_zone(zid, true)
		_keep_inside(zone)
	events.append(["room", type])
	await game.get_tree().process_frame
	var d := district()
	game.banner("%s · %d / %d" % [String(d["name"]), int(run["pos"]) + 1, route().size()], String(G67Data.ROOM_NAMES[type]), G67Data.ROOM_COLOR[type], 2.6)
	match type:
		"battle", "elite", "ambush":
			waves = G67Data.waves_for(d, type, int(run["pos"]))
			wave_i = -1
			wave_wait = 1.4
			pending = []
			room_state = "fight"
			_save_run("fight")
		"fit":
			room_state = "reward"
			_offer_fit(false)
		"storage":
			room_state = "reward"
			_open_storage()
		"break":
			room_state = "reward"
			rest()
		"boss":
			room_state = "boss"
			var bid := String(d["boss"])
			var b = game._make_enemy("", bid, world.yard.boss_spot + Vector3(0, 0.05, 0))
			game.boss_e = b
			var bd: Dictionary = game.story["BOSS"][bid]
			game.boss_name.text = "%s — %s" % [bd["n"], bd["sub"]]
			_boss_intro(b)
			_save_run("fight")
	busy = false

## Герой вне прямоугольника зоны боя (с отступом 1,5 м) — ставится на ближайшую точку внутри
func _keep_inside(zone: Dictionary) -> void:
	var p = game.player
	var c: Vector3 = zone["c"]
	var h: Vector2 = zone["h"]
	var q: Vector3 = p.global_position
	var x: float = c.x + clampf(q.x - c.x, -(h.x - 1.5), h.x - 1.5)
	var z: float = c.z + clampf(q.z - c.z, -(h.y - 1.5), h.y - 1.5)
	if not is_equal_approx(x, q.x) or not is_equal_approx(z, q.z):
		p.global_position = Vector3(x, q.y, z)
		p.velocity = Vector3.ZERO

func _spawn(foe: String) -> void:
	var f: Dictionary = G67Data.FOES[foe]
	var pp: Vector3 = game.player.global_position
	var c: Vector3 = game.arena_c
	var h: Vector2 = game.arena_h - Vector2(1.5, 1.5)
	var pos := Vector3.ZERO
	var fallback := Vector3.INF
	for n in 20:
		pos = Vector3(c.x + randf_range(-h.x, h.x), 0, c.z + randf_range(-h.y, h.y))
		if world.blocked(pos):
			continue
		if fallback == Vector3.INF:
			fallback = pos
		if pos.distance_to(pp) >= 6.0:
			fallback = pos
			break
	if fallback != Vector3.INF:
		pos = fallback
	pos.y = 0.05
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = String(f["kind"])
	e.skin = String(f["skin"])
	e.game = game
	e.position = pos
	e.set_meta("foe", foe)
	game.add_child(e)
	e.global_position = pos
	e.face = atan2(pp.x - pos.x, pp.z - pos.z)
	game.enemies.append(e)

func alive() -> int:
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and e.state != "dead":
			n += 1
	return n

var _out_t := {}      # живой враг вне арены: сколько секунд подряд

## Страховка: враг, оказавшийся за ограждением зоны (телепорт, отскок), дольше секунды переставляется внутрь
func _keep_foes_inside(dt: float) -> void:
	for e in game.enemies:
		if not is_instance_valid(e) or e.state == "dead" or e.boss_id != "":
			continue
		var id: int = e.get_instance_id()
		if game.in_arena(e.global_position, 0.0):
			_out_t.erase(id)
			continue
		_out_t[id] = float(_out_t.get(id, 0.0)) + dt
		if float(_out_t[id]) > 1.0:
			var c: Vector3 = game.arena_c
			var h: Vector2 = game.arena_h
			e.global_position = Vector3(c.x + clampf(e.global_position.x - c.x, -(h.x - 1.5), h.x - 1.5), e.global_position.y, c.z + clampf(e.global_position.z - c.z, -(h.y - 1.5), h.y - 1.5))
			e.velocity = Vector3.ZERO
			_out_t.erase(id)

func _fight_tick(dt: float) -> void:
	_keep_foes_inside(dt)
	if spawn_cd > 0.0:
		spawn_cd -= dt
	if not pending.is_empty():
		if alive() < 7 and spawn_cd <= 0.0:
			_spawn(pending.pop_front())
			spawn_cd = 0.3
		return
	if alive() > 0:
		return
	wave_wait -= dt
	if wave_wait > 0.0:
		return
	wave_i += 1
	if wave_i >= waves.size():
		_room_cleared()
		return
	for grp in waves[wave_i]:
		for i in int(grp[1]):
			pending.append(String(grp[0]))
	pending.shuffle()
	wave_wait = 1.2
	if waves.size() > 1:
		game.toast("Волна %d / %d" % [wave_i + 1, waves.size()])
	game.main.sfx("sfx_wave", -8.0)

func gold_k() -> float:
	return 1.0 + 0.25 * float(fit_lv("gold_chain")) + (0.2 if has_art("bracelet_67") else 0.0)

## Выдать голду (с множителями); возвращает, сколько получено
func add_golda(n: int) -> int:
	var got := int(round(n * gold_k()))
	run["golda"] = int(run.get("golda", 0)) + got
	run["earned"] = int(run.get("earned", 0)) + got
	return got

func on_kill(e) -> void:
	if place != "run":
		return
	var p = game.player
	p.swag = minf(100.0, p.swag + 6.0)
	if e.boss_id != "":
		_boss_down(e)
		return
	var foe := String(e.get_meta("foe", ""))
	if not G67Data.FOES.has(foe):
		return                            # призванные боссом голды и лечения не дают
	run["kills"] = int(run.get("kills", 0)) + 1
	add_golda(int(G67Data.FOES[foe]["golda"]))
	if has_art("hamster_aura"):
		run["golda"] = int(run["golda"]) + 2
		run["earned"] = int(run.get("earned", 0)) + 2
	# ДОБИВАЛА по таблице: 3 / 6 / 9 за врага, элитный (Смотрящий) — втрое, не больше 25 / 40 / 55 за комнату
	var lv := fit_lv("finisher")
	if lv > 0:
		var heal: float = float(G67Data.FINISHER_HEAL[lv - 1]) * (G67Data.FINISHER_ELITE if foe == "smotr" else 1.0)
		heal = minf(heal, float(G67Data.FINISHER_CAP[lv - 1]) - fin_room)
		if heal > 0.0:
			fin_room += heal
			p.hp = minf(p.max_hp, p.hp + heal)

func _room_cleared() -> void:
	var type := String(room["type"])
	events.append(["clear", type])
	add_golda(int(G67Data.ROOM_GOLDA[type]))
	_add_respect("elite" if type == "elite" else "battle", int(G67Data.RESPECT["elite" if type == "elite" else "room"]))
	run["rooms"] = int(run["rooms"]) + 1
	game.banner("ЧИСТО", "голда: %d" % int(run["golda"]), Color(1, 0.85, 0.3), 1.8)
	game.fx.twinkle(game.player.global_position + Vector3(0, 1.0, 0), 14, Color(1, 0.85, 0.4), 1.0)
	if type == "elite":
		room_state = "reward"
		_offer_fit(true)
	else:
		_stage_end()

## Маршрут забега: шаблон из G67Data.DISTRICTS[..].routes по номеру забега
func route() -> Array:
	return G67Data.route_of(district(), int(run.get("tpl", 0)))

## Варианты следующего этапа — копия вариантов шаблона маршрута
func route_options(next: int) -> Array:
	return (route()[next] as Array).duplicate(true)

## Этап пройден: награда уже выдана; мирные этапы дают РЕСПЕКТ здесь. Дальше — варианты следующего этапа.
func _stage_end() -> void:
	var type := String(room.get("type", ""))
	if type in ["fit", "storage", "break"]:
		_add_respect("calm", int(G67Data.RESPECT["calm"]))
		run["rooms"] = int(run["rooms"]) + 1
	(run["stages"] as Array).append([type, String(room.get("place", ""))])
	events.append(["stage_done", type])
	_open_gates()

func _open_gates() -> void:
	var next := int(run["pos"]) + 1
	if next >= route().size():
		return
	var opts := route_options(next)
	world.open_bounds()            # ограждения боя убраны: дальше — по двору, к месту следующего этапа
	world.add_gates(opts)
	room_state = "open"
	events.append(["gates", opts.size()])
	_save_run("open")

func choose_gate(i: int) -> void:
	if busy or room_state != "open" or i < 0 or i >= world.gates.size():
		return
	var o: Dictionary = world.gates[i]["option"]
	run["pos"] = int(run["pos"]) + 1
	events.append(["gate", String(o["type"])])
	game.main.ui("confirm")
	await enter_room(o)

# ---------------------------------------------------------------- постановка: выход босса
## Миша ждёт у своей машины в дальнем конце коробки. Камера уходит от героя к нему, обходит его, он говорит своё —
## и только потом бой. Игрок в это время не управляет героем, босс не двигается.
func _boss_intro(b) -> void:
	scene_boss = b
	scene_t = 0.0
	scene_said = false
	scene_step = 0
	b.set_physics_process(false)
	# начинает на троне, лицом к воротам; выйдет по ковровой дорожке
	scene_to = b.global_position
	scene_from = Vector3(world.throne.x, b.global_position.y, world.throne.z + 0.2)
	b.global_position = scene_from
	b.face = 0.0
	b.body.rotation.y = 0.0
	b.rig.play("MSit", 0.0)
	events.append(["boss_intro"])

func scene_busy() -> bool:
	return scene_t >= 0.0 or clip != null or hub_ui != null

func owns_camera() -> bool:
	return talk_on or (scene_t >= 0.0 and scene_boss != null and is_instance_valid(scene_boss))

# ---------------------------------------------------------------- камера разговоров (talk_shots)
## План: {pos, look, fov} в мировых координатах; номер плана на реплику — talk_map. Планы строятся от положений героя и
## собеседника, сторону выбирает _talk_camera (там, где больше места); перед показом луч от середины до камеры: стена — ближе.
var talk_on := false
var talk_shots: Array = []        # список планов
var talk_map := {}                # {номер реплики: номер плана}
var talk_cur := 0
var talk_t := 1.0
var talk_pos := Vector3.ZERO
var talk_look := Vector3.ZERO
var talk_fov := 45.0
var talk_hidden := {}             # что спрятано на время разговора: узел → прежняя видимость

## Свободная доля луча от середины до камеры (1 — стен нет)
func _free_k(mid: Vector3, pos: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(mid, pos)
	q.collision_mask = 8
	var hit: Dictionary = space.intersect_ray(q)
	return 1.0 if hit.is_empty() else (hit["position"] as Vector3).distance_to(mid) / maxf(0.01, mid.distance_to(pos))

## План из двух вариантов (с одной и с другой стороны): берём тот, где меньше стен; стена на пути — камера ближе
func _plan(mid: Vector3, pos: Vector3, look: Vector3, fov: float, alt := Vector3.INF) -> Dictionary:
	if alt != Vector3.INF and _free_k(mid, alt) > _free_k(mid, pos):
		pos = alt
	var k := _free_k(mid, pos)
	if k < 1.0:
		pos = mid.lerp(pos, maxf(0.25, k * 0.9))
	return {"pos": pos, "look": look, "fov": fov}

## Составить планы разговора: kind — flurr / kiosk / chandelier / pigeons / krot; lines — реплики (код|текст)
func talk_begin(partner, kind: String, lines: Array) -> void:
	var p = game.player
	var H: Vector3 = p.global_position
	var Q: Vector3 = (partner as Node3D).global_position
	var A := Q - H
	A.y = 0.0
	A = A.normalized() if A.length() > 0.05 else Vector3.FORWARD
	var S := A.cross(Vector3.UP)
	var sd: float = game.dlg_side
	var qy := 0.95 if kind == "flurr" else 1.45          # DJ FLÜRR сидит на лавке: лицо ниже
	var M := (H + Q) * 0.5 + Vector3(0, 1.3 if kind == "flurr" else 1.4, 0)
	var Hh := H + Vector3(0, 1.45, 0)
	var Qh := Q + Vector3(0, qy, 0)
	var sep := H.distance_to(Q)
	talk_shots = [
		_plan(M, M + S * sd * (3.2 + sep * 0.6) + A * 0.8 + Vector3(0, 0.1, 0), M, 62.0, M - S * sd * (3.2 + sep * 0.6) + A * 0.8 + Vector3(0, 0.1, 0)),                       # 0 общий: оба в профиль
		_plan(M, Qh + S * sd * 1.5 - A * 0.9 + Vector3(0, 0.1, 0), Qh, 38.0, Qh - S * sd * 1.5 - A * 0.9 + Vector3(0, 0.1, 0)),                          # 1 собеседник в три четверти
		_plan(M, Qh + A * 0.9 + S * sd * 0.55 + Vector3(0, 0.25, 0), Hh, 44.0, Qh + A * 0.9 - S * sd * 0.55 + Vector3(0, 0.25, 0))]                          # 2 через плечо собеседника на Пахана
	var extra_idx := -1
	match kind:
		"kiosk":
			talk_shots.append(_plan(M, M + S * sd * (5.0 + sep * 0.6) + Vector3(0, 1.0, 0), Vector3(39.9, 1.5, 7.0), 56.0))   # 3 окно ларька и очередь
		"chandelier":
			# у колясочной с боков мешает кладка лестницы: средний и крупный планы — из-за плеча героя, КРОТ лицом в кадр
			talk_shots[1] = _plan(M, Hh - A * 1.5 + S * sd * 0.5 + Vector3(0, 0.15, 0), Qh, 38.0, Hh - A * 1.5 - S * sd * 0.5 + Vector3(0, 0.15, 0))
			talk_shots.append(_plan(M, Hh - A * 1.9 + S * sd * 0.95 + Vector3(0, 0.1, 0), Qh + Vector3(0, 0.15, 0), 38.0, Hh - A * 1.9 - S * sd * 0.95 + Vector3(0, 0.1, 0)))      # 3 крупно люстра
		"pigeons":
			talk_shots.append(_plan(M, Q + A * -2.6 + S * sd * 2.2 + Vector3(0, 0.55, 0), Q + Vector3(0, 0.35, 0), 58.0, Q + A * -2.6 - S * sd * 2.2 + Vector3(0, 0.55, 0)))   # 3 низко на голубей
	talk_map = {}
	for i in lines.size():
		var ln := String(lines[i])
		var who := ln.substr(0, ln.find("|"))
		var plan := 0 if i == 0 else (2 if who.begins_with("V") else 1)
		if kind == "kiosk" and i == lines.size() - 1:
			plan = 3
		elif kind == "chandelier" and ln.contains("странно смотрела"):
			plan = 3
		elif kind == "pigeons":
			plan = 0 if who.begins_with("V") else 1
			if ln.contains("голубь справа"):
				plan = 3
		elif kind != "flurr" and i > 0 and who.begins_with("V"):
			plan = 0
		talk_map[i] = plan
	talk_cur = int(talk_map.get(0, 0))
	var sh0: Dictionary = talk_shots[talk_cur]
	talk_pos = sh0["pos"]
	talk_look = sh0["look"]
	talk_fov = float(sh0["fov"])
	talk_t = 1.0
	talk_on = true
	_talk_hud(true)

func talk_end() -> void:
	if not talk_on:
		return
	talk_on = false
	_talk_hud(false)

## Боевой HUD, верхняя строка и значки над точками на время разговора спрятаны
func _talk_hud(hide: bool) -> void:
	if hide:
		var nodes: Array = [game.combat_hud, game.hud_root, mark_talk, prompt]
		for g in world.gates:
			nodes.append(g.get("root"))
		for n in nodes:
			if n != null and is_instance_valid(n) and "visible" in n:
				talk_hidden[n] = n.visible
				n.visible = false
	else:
		for n in talk_hidden:
			if is_instance_valid(n):
				n.visible = talk_hidden[n]
		talk_hidden = {}

func _talk_step(dt: float) -> void:
	var want := int(talk_map.get(clampi(game.dlg_i, 0, 99), talk_cur))
	if want != talk_cur and want < talk_shots.size():
		talk_cur = want
		talk_t = 0.0
	talk_t = minf(1.0, talk_t + dt / 0.35)
	var sh: Dictionary = talk_shots[talk_cur]
	var k := 1.0 - exp(-14.0 * dt) if talk_t >= 1.0 else minf(1.0, dt / 0.12)
	talk_pos = talk_pos.lerp(sh["pos"], k)
	talk_look = talk_look.lerp(sh["look"], k)
	talk_fov = lerpf(talk_fov, float(sh["fov"]), k)

## где камера в этот миг постановки
func camera() -> Transform3D:
	if talk_on:
		return Transform3D(Basis.looking_at(talk_look - talk_pos, Vector3.UP), talk_pos)
	var home: Transform3D = game.spring.global_transform * Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	var bp: Vector3 = scene_boss.global_position
	var chest: Vector3 = bp + Vector3(0, 1.45, 0)
	var k := clampf((scene_t - 0.9) / (SCENE_LEN - 1.9), 0.0, 1.0)
	var ang := lerpf(0.55, -0.4, k * k * (3.0 - 2.0 * k))            # обход от правого плеча к левому
	var dist := lerpf(6.2, 3.6, k)
	var pos: Vector3 = chest + Vector3(sin(ang) * dist, lerpf(-0.7, 0.15, k), cos(ang) * dist)
	var shot := Transform3D(Basis.looking_at(chest + Vector3(0, 0.25, 0) - pos, Vector3.UP), pos)
	var w := 1.0
	if scene_t < 0.9:
		w = scene_t / 0.9
	elif scene_t > SCENE_LEN - 1.0:
		w = clampf((SCENE_LEN - scene_t) / 1.0, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	return Transform3D(Basis(home.basis.get_rotation_quaternion().slerp(shot.basis.get_rotation_quaternion(), w)), home.origin.lerp(shot.origin, w))

func _scene_tick(dt: float) -> void:
	scene_t += dt
	if scene_boss == null or not is_instance_valid(scene_boss):
		_scene_end()
		return
	var b = scene_boss
	if scene_step == 0 and scene_t >= SCENE_SIT:
		scene_step = 1
		b.rig.play("Idle", 0.5)                    # встаёт
	if scene_step == 1 and scene_t >= SCENE_WALK:
		scene_step = 2
		b.rig.play("Run", 0.25, 0.5)               # идёт не спеша
	if scene_step == 2:
		var wk := clampf((scene_t - SCENE_WALK) / (SCENE_STOP - SCENE_WALK), 0.0, 1.0)
		b.global_position = scene_from.lerp(scene_to, wk)
		if wk >= 1.0:
			scene_step = 3
			b.rig.play_for("Stomp", 1.2, 0.12)       # встал напротив и топнул
	if scene_step == 3 and scene_t >= SCENE_STOP + 0.75:
		scene_step = 4
		game.shake(0.45)
		game.main.sfx("sfx_boom", -3.0, 0.8)
		game.fx.slam(b.global_position, 1.4, Color(game.story["BOSS"][String(b.boss_id)]["c"]))
	if not scene_said and scene_t >= SCENE_SIT + 0.2:
		scene_said = true
		var bd: Dictionary = game.story["BOSS"][String(scene_boss.boss_id)]
		game.banner(String(bd["n"]), String(bd["sub"]), Color(bd["c"]), 3.4)
		game.boss_bark(String(bd["n"]), G67Data.BOSS_INTRO, Color(bd["c"]), String(bd["sp"]))
		game.main.sfx("sfx_rage", -4.0, 0.7)
	if scene_t >= SCENE_LEN:
		_scene_end()

func _scene_end() -> void:
	scene_t = -1.0
	bark_hold = 4.0
	if scene_boss != null and is_instance_valid(scene_boss):
		scene_boss.global_position = scene_to
		scene_boss.set_physics_process(true)
		scene_boss.cool = 1.2
	scene_boss = null
	game.cam.transform = Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	events.append(["boss_fight"])

# ---------------------------------------------------------------- КРОТ
## Следующая неувиденная встреча КРОТА (они идут по порядку); {} — все из сделанных увидены
func krot_next() -> Dictionary:
	var seen: Array = meta().get("seen", [])
	for k in G67Data.KROT:
		if not seen.has(String(k["id"])):
			return k
	return {}

## Поставить КРОТА, если его очередная встреча назначена на это место и нужная для сцены модель есть.
## Встреча не пропадает: пока игрок с ним не поговорил, он стоит тут в каждом забеге.
func _place_krot(where: String) -> void:
	var k := krot_next()
	if k.is_empty() or String(k["where"]) != where:
		return
	if String(k.get("needs", "")) != "" and not G67Models.has(String(k["needs"])):
		return
	if where == "hub" and String(k["id"]) == "krot2" and int(meta().get("flurr", -1)) < 1:
		return                         # люстра — после того, как DJ FLÜRR сказал про неё (состояние 1): сначала он, потом КРОТ
	var pos: Vector3 = k["pos"] as Vector3
	var kc: Dictionary = Poses.pahan()
	kc.merge(G67Poses.krot(), true)           # позы встреч КРОТА (одна модель на все десять)
	var r: Rig = world._actor("g67_krot", G67Models.DIR + "g67_krot.glb", 1.62, pos, float(k["yaw"]), kc)
	if r == null:
		return
	krot_k = k
	krot_line = -1
	krot_feed = 0.0
	krot_life = G67Life.attach(r, {"base": String(k.get("pose", "Idle")), "alts": [], "look_r": 6.0, "turn": 1.4}, 9100)
	if krot_life != null:
		krot_life.watcher = game.player
	world._static_box(pos + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	var talk: Vector3 = k.get("talk", Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"]))) * 1.1)
	world._point("krot", "КРОТ", "поговорить", pos + talk)
	if String(k.get("carry", "")) != "":
		# держит вещь перед собой обеими руками (люстру): вещь закреплена на груди скелета — идёт вместе с ним
		var fw := Vector3(sin(float(k["yaw"])), 0, cos(float(k["yaw"])))
		var item := G67Models.spawn(String(k["carry"]), world, pos + fw * 0.46 + Vector3(0, 0.5, 0), float(k["yaw"]), Vector3(9, 0.55, 9))
		item.name = "krot_item"
		var att := BoneAttachment3D.new()
		att.bone_name = "mixamorig_Hips"
		r.skel.add_child(att)
		item.reparent(att, true)
		krot_item = item
	for i in int(k.get("pigeons", 0)):
		var a := float(i) * 1.26 + 0.4
		var pg := G67Models.spawn("g67_pigeon", world, pos + Vector3(sin(a), 0, cos(a)) * (1.2 + 0.25 * float(i % 3)), a * 2.0 + 1.0, Vector3(9, 0.3, 9))
		pg.name = "krot_pigeon%d" % i
		G67Pigeon.attach(pg, i)
	events.append(["krot_here", String(k["id"])])

## Во дворе КРОТ стоит на своём месте с постройки двора и весь забег (зоны под него не переставляются)
func _place_krot_yard() -> void:
	var k := krot_next()
	if not k.is_empty() and G67Yard.ZONES.has(String(k["where"])):
		_place_krot(String(k["where"]))

# ---------------------------------------------------------------- постановка встреч КРОТА
var krot_k := {}
var krot_life: G67Life = null
var krot_item: Node3D = null
var krot_line := -1
var krot_feed := 0.0
var krot_walk := -1.0

## Жесты КРОТА по репликам: пока идёт разговор с ним — смотрим, какая реплика на экране
func _krot_tick(dt: float) -> void:
	var kr = world.actors.get("g67_krot")
	if krot_k.is_empty():
		return
	# уходит с вещью
	if krot_walk >= 0.0:
		krot_walk += dt
		var w = world.get_node_or_null("krot_leaving")
		if w == null:
			krot_walk = -1.0
			return
		# к входной двери по прямой; героя на пути обходит (смещается в свободную сторону), исчезает за дверью
		var wp: Vector3 = (w as Node3D).global_position
		var goal := Vector3(0.0, wp.y, G67World.Z_DOOR - 0.4)
		var dirw: Vector3 = goal - wp
		dirw.y = 0.0
		var hp: Vector3 = game.player.global_position - wp
		hp.y = 0.0
		if dirw.length() < 0.2 or krot_walk > 12.0:
			w.queue_free()
			krot_item = null
			krot_walk = -1.0
			return
		dirw = dirw.normalized()
		if hp.length() < 1.6 and hp.dot(dirw) > -0.2:
			var side := Vector3(-dirw.z, 0, dirw.x)
			dirw = (dirw + side * (-1.0 if hp.dot(side) > 0.0 else 1.0) * 1.2).normalized()
		(w as Node3D).global_position += dirw * 1.15 * dt
		(w as Node3D).rotation.y = lerp_angle((w as Node3D).rotation.y, atan2(dirw.x, dirw.z), 1.0 - exp(-8.0 * dt))
		return
	if kr == null or not is_instance_valid(kr) or krot_life == null:
		return
	# люстра в руках медленно поворачивается — он её рассматривает
	if krot_item != null and is_instance_valid(krot_item) and krot_life.cur != "K2Show":
		krot_item.rotate_y(dt * 0.35)
	# корм: на взмахе руки голуби бегут к брошенным зёрнам
	if bool(krot_k.get("feed", false)) and krot_life.cur == "K3" and kr.player != null:
		var ph: float = fmod(kr.player.current_animation_position / maxf(0.01, kr.player.current_animation_length), 1.0)
		if ph >= 0.55 and krot_feed < 0.55:
			var fw: Vector3 = (kr as Node3D).global_transform.basis.z
			var spot: Vector3 = (kr as Node3D).global_position + fw * 1.4 + Vector3(fw.z, 0, -fw.x) * randf_range(-0.6, 0.6)
			for ch in world.get_children():
				if String(ch.name).begins_with("krot_pigeon"):
					var pg = ch.get_child(ch.get_child_count() - 1)
					if pg is G67Pigeon and randf() < 0.75:
						(pg as G67Pigeon).feed(world.to_local(spot))
		krot_feed = ph
	if game.mode != "dlg" or game.dlg_partner != kr:
		return
	if game.dlg_i == krot_line:
		return
	krot_line = game.dlg_i
	var acts: Dictionary = krot_k.get("acts", {})
	var line := String(game.dlg[krot_line]) if krot_line >= 0 and krot_line < game.dlg.size() else ""
	if acts.has(krot_line):
		var a = acts[krot_line]
		if a is Array:
			krot_life.stage(String(a[0]), 0.25, float(a[1]))
			get_tree().create_timer(float(a[1]), false).timeout.connect(func():
				if krot_life != null and is_instance_valid(krot_life) and game.mode == "dlg":
					krot_life.stage(String(krot_k.get("talk_clip", krot_k["pose"])), 0.4))
		else:
			krot_life.stage(String(a), 0.35)
			if String(a) == "K2Show" and krot_item != null:
				var tw := krot_item.create_tween()
				tw.tween_property(krot_item, "rotation:y", krot_item.rotation.y + PI, 0.6).set_trans(Tween.TRANS_SINE)
	elif line.begins_with("KR|"):
		if not acts.has(krot_line - 2) or not (acts[krot_line - 2] is String):
			krot_life.stage(String(krot_k.get("talk_clip", krot_k["pose"])), 0.4)

## После разговора: остаётся в своей позе (говорить больше не о чем) или уходит, унося вещь
func _krot_after(kr: Rig) -> void:
	match String(krot_k.get("after", "")):
		"walk":
			krot_life.stage("K2Walk", 0.3)
			# разворачивается и уходит к выходу на улицу, люстра остаётся в руках
			var ex := point("exit")
			var to: Vector3 = (ex["pos"] as Vector3) - kr.global_position if not ex.is_empty() else -kr.global_transform.basis.z
			kr.rotation.y = atan2(to.x, to.z)
			kr.name = "krot_leaving"
			krot_walk = 0.0
		_:
			krot_life.stage(String(krot_k.get("pose", "Idle")), 0.5)
			kr.name = "krot_after"
			krot_life.paused = false

func talk_krot() -> void:
	var k := krot_next()
	if k.is_empty() or (place == "run" and (alive() > 0 or not pending.is_empty())):
		game.toast("Сначала разберись с этими")
		return
	events.append(["krot_talk", String(k["id"])])
	var p = game.player
	var kr = world.actors.get("g67_krot")
	if kr != null and is_instance_valid(kr):
		var to: Vector3 = kr.global_position - p.global_position
		p.face = atan2(to.x, to.z)
	game.start_dialog(k["lines"], func(): _krot_done(String(k["id"])))
	_talk_camera(kr)
	var kind := "krot"
	match String(k["id"]):
		"krot1": kind = "kiosk"
		"krot2": kind = "chandelier"
		"krot3": kind = "pigeons"
	if kr != null and is_instance_valid(kr):
		talk_begin(kr, kind, k["lines"])

func _krot_done(id: String) -> void:
	talk_end()
	game.mode = "golda67"
	if place == "run":
		game.buddy.global_position = Vector3(0, -50, 0)
	var seen: Array = meta().get("seen", [])
	if not seen.has(id):
		seen.append(id)
	meta()["seen"] = seen
	var arch: Array = meta().get("archive", [])
	if not arch.has(id):
		arch.append(id)
	meta()["archive"] = arch
	save()
	events.append(["krot_seen", id])
	_krot_card(seen.size())
	_note_new("Встреча с КРОТОМ: %s — запись в архиве у телевизора" % String(krot_k.get("title", id)))
	if id == "krot3":
		unlock_clip("EXTRA01")               # «КРОТ НА ПОДКАСТЕ» — в архив после третьей встречи
	# КРОТ уходит по своим делам: без объяснений
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "krot")
	var kr = world.actors.get("g67_krot")
	if kr != null and is_instance_valid(kr):
		_krot_after(kr)
	world.actors.erase("g67_krot")
	near = ""
	game.toast("КРОТ: %d из 10" % seen.filter(func(x): return String(x).begins_with("krot")).size())

## Камера разговора: двое в профиль. Сторону выбираем ту, где больше места (у стены камера упёрлась бы в затылок).
func _talk_camera(partner) -> void:
	if partner == null or not is_instance_valid(partner):
		return
	game.dlg_partner = partner
	var p = game.player
	var mid: Vector3 = (p.global_position + (partner as Node3D).global_position) * 0.5 + Vector3(0, 1.15, 0)
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var best := -1.0
	var best_d := -1.0
	for sd in [-1.0, 1.0]:
		var yaw: float = p.face + sd * 1.35
		var to: Vector3 = mid + Vector3(sin(yaw), 0.1, cos(yaw)) * 4.6
		var q := PhysicsRayQueryParameters3D.create(mid, to)
		q.exclude = [p.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var d: float = 4.6 if hit.is_empty() else ((hit["position"] as Vector3) - mid).length()
		if d > best_d:
			best_d = d
			best = sd
	game.dlg_side = best

# ---------------------------------------------------------------- dj flürr
## Диалоги dj flürr — авторский текст владельца (docs/golda67/DJ_FLURR_SPEC.md → G67Flurr, собирает
## tools/golda67-flurr.cjs). Состояние — сколько встреч КРОТА игрок действительно завершил (0…10), а не число заходов
## в подъезд. Большой диалог состояния звучит один раз; до следующей встречи — короткие фразы по кругу.
var flurr_last := -1           # какая короткая фраза была последней (без повтора подряд)

func krot_done() -> int:
	var n := 0
	for x in (meta().get("seen", []) as Array):
		if String(x).begins_with("krot"):
			n += 1
	return clampi(n, 0, 10)

func flurr_state() -> int:
	return krot_done()

func talk_flurr() -> void:
	var n := flurr_state()
	var played := int(meta().get("flurr", -1))
	var lines: Array
	var big := n > played
	if big and played < 0 and n > 0:
		# первый разговор, а КРОТ уже встречен: короткое знакомство, связка и сразу нынешний диалог
		lines = (G67Flurr.STATES[0] as Array).slice(0, G67Data.FLURR_INTRO)
		lines.append(G67Data.FLURR_BRIDGE)
		lines.append_array(G67Flurr.STATES[n])
	elif big:
		lines = G67Flurr.STATES[n]
	else:
		var pool: Array = G67Flurr.DONE if n >= 10 else G67Flurr.WAIT
		flurr_last = (flurr_last + 1) % pool.size()
		lines = [pool[flurr_last]]
	events.append(["flurr", n, big])
	var p = game.player
	var fr = world.actors.get("g67_dj_flurr")
	if fr != null and is_instance_valid(fr):
		var to: Vector3 = fr.global_position - p.global_position
		p.face = atan2(to.x, to.z)
	game.start_dialog(lines, func(): _flurr_done(n, big))
	_talk_camera(fr)
	if fr != null and is_instance_valid(fr):
		talk_begin(fr, "flurr", lines)

func _flurr_done(n: int, big: bool) -> void:
	talk_end()
	game.mode = "golda67"
	if big:
		meta()["flurr"] = n
		# в «АРХИВ ПИЗДЕЦА» идут и этот диалог, и все пропущенные до него (их подряд не проигрываем)
		var arch: Array = meta().get("archive", [])
		for k in n + 1:
			if not arch.has("flurr%d" % k):
				arch.append("flurr%d" % k)
		meta()["archive"] = arch
		save()
	events.append(["flurr_done", n, big])
	if big and place == "hub" and not world.actors.has("g67_krot") and krot_next().get("id", "") == "krot2":
		_place_krot("hub")             # КРОТ с люстрой появляется сразу после разговора с DJ FLÜRR

# ---------------------------------------------------------------- артефакты (APPROVALS.md, 2.3)
func arts() -> Array:
	return run.get("arts", []) if not run.is_empty() else []

func has_art(id: String) -> bool:
	return arts().has(id)

## Слотов: 3 + уровень «СЛОТОВ АРТЕФАКТОВ»
func slots() -> int:
	return G67Data.ART_SLOTS + up("slots")

static func art_info(id: String) -> Dictionary:
	for a in G67Data.ARTIFACTS:
		if String(a["id"]) == id:
			return a
	return {}

## Что может лежать в кладовке: не событийные, ещё не взятые в этом забеге; «Вторая симка» — после первой концовки,
## «Автотюн» — когда открыты два стиля
func storage_pool() -> Array:
	var out: Array = []
	for a in G67Data.ARTIFACTS:
		var id := String(a["id"])
		if G67Data.ART_EVENT.has(id) or has_art(id):
			continue
		if id == "second_sim" and not madk_open():
			continue
		if id == "autotune_ring" and styles_open().size() < 2:
			continue
		out.append(id)
	return out

## Кладовка: два артефакта на выбор; их запоминает комната (вернулся из подъезда — те же два)
func storage_offer() -> Array:
	if not room.has("offer"):
		var pool := storage_pool()
		pool.shuffle()
		room["offer"] = pool.slice(0, 2)
	return room["offer"]

func _open_storage() -> void:
	if storage_offer().is_empty():
		add_golda(25)
		_stage_end()
		return
	world.add_storage()
	open_screen("storage")

## Взять артефакт (replace — какой выложить, если слоты заняты). Найденный остаётся в коллекции подъезда.
func take_art(id: String, replace := "") -> bool:
	if art_info(id).is_empty() or has_art(id):
		return false
	var a: Array = run["arts"]
	if a.size() >= slots():
		if not a.has(replace):
			return false
		a.erase(replace)
		events.append(["art_drop", replace])
		if replace == "beanie":
			apply_fits()
	a.append(id)
	var got: Array = meta().get("artifacts", [])
	if not got.has(id):
		got.append(id)
		_note_new("Артефакт «%s» — сервант на площадке подъезда" % String(art_info(id)["name"]))
		meta()["artifacts"] = got
		save()
	if id == "broken_remote":
		run["rerolls"] = int(run.get("rerolls", 0)) + 1
	events.append(["art", id])
	apply_fits(id)
	game.main.ui("confirm")
	game.banner(String(art_info(id)["name"]).to_upper(), "артефакт · %d / %d" % [a.size(), slots()], Color(0.55, 0.75, 0.95), 2.2)
	room["taken"] = true
	return true

## Уйти из кладовки — двери дальше. Не взял ничего — гараж остаётся открытым, можно вернуться к нему до ворот.
func leave_storage() -> void:
	if String(room.get("type", "")) != "storage" or world == null:
		return
	if bool(room.get("taken", false)):
		world.points = world.points.filter(func(pt): return String(pt["id"]) != "storage")
	if room_state == "reward":
		_stage_end()

## Урон героя сейчас: фитсы × артефакты по обстановке, общий потолок ×2,0
func dmg_now() -> float:
	var k := fit_mul
	if game.clock < cass_until:
		k *= 1.2
	var p = game.player
	if has_art("cracked_phone") and p.hp < p.max_hp * 0.35:
		k *= 1.25
	return minf(G67Data.DMG_CAP_ALL, k)

## Постоянные эффекты артефактов и ВОССТАНОВЛЕНИЕ АВТОРИТЕТА — каждый кадр; в подъезде всё возвращается к 1
func _art_tick(dt: float) -> void:
	var p = game.player
	var in_run := place == "run" and not run.is_empty()
	var res := float(up("res")) if in_run else 0.0
	var cd := (0.85 if has_art("sim") else 1.0) * (1.0 - 0.08 * res)
	p.combat.cd_k = cd
	p.combat.ammo_k = 1.0 - 0.08 * res
	p.speed_k = 1.08 if has_art("market_sneakers") else 1.0
	game.hype.gain_k = 1.3 if has_art("energy") else 1.0
	if not in_run:
		_last_hp = -1.0
		_last_swag = -1.0
		return
	# ад-либ (Q) — та же доля быстрее; помощь напарника на [T] — «Вторая симка» на 25 %
	if cd < 1.0 and game.buddy.cd > 0.0:
		game.buddy.cd = maxf(0.0, game.buddy.cd - dt * (1.0 / cd - 1.0))
	if has_art("second_sim") and game.tag.assist_cd > 0.0:
		game.tag.assist_cd = maxf(0.0, game.tag.assist_cd - dt / 3.0)
	# «Кассета 2016»: после полученного урона
	if _last_hp >= 0.0 and p.hp < _last_hp - 0.01 and has_art("cassette_2016") and game.clock >= cass_next:
		cass_until = game.clock + 4.0
		cass_next = game.clock + 8.0
		events.append(["cassette"])
	_last_hp = p.hp
	# «Энергетик», пока Team Hype закрыт: СВЭГ копится на 20 % быстрее
	if has_art("energy") and game.madk_locked() and _last_swag >= 0.0 and p.swag > _last_swag:
		p.swag = minf(100.0, p.swag + (p.swag - _last_swag) * 0.2)
	_last_swag = p.swag
	p.dmg_mul = dmg_now()

## «Платиновый значок»: добивание на [E] лечит на 8 и даёт 5 голды
func _on_executed(_e, _style: String, _ctx: String) -> void:
	if place == "run" and has_art("platinum_badge"):
		var p = game.player
		p.hp = minf(p.max_hp, p.hp + 8.0)
		run["golda"] = int(run.get("golda", 0)) + 5
		run["earned"] = int(run.get("earned", 0)) + 5
		events.append(["badge"])

## «Кольцо „Автотюн“»: усиление Perfect Swap — на 1 с дольше
func _on_swapped(_from: String, _to: String, perfect: bool) -> void:
	if perfect and place == "run" and has_art("autotune_ring"):
		game.player.flow.boost_t += 1.0
		events.append(["autotune"])

# ---------------------------------------------------------------- ларёк «ШАУРМА 67» (APPROVALS.md, 2.2)
## Сколько этого товара осталось на забег
func kiosk_left(id: String) -> int:
	for k in G67Data.KIOSK:
		if String(k["id"]) == id:
			if int(k["per_visit"]) <= 0:
				return 99               # без лимита: растёт цена
			return int(k["per_visit"]) - int((run.get("kiosk", {}) as Dictionary).get(id, 0))
	return 0

## Текущая цена: базовая + step за каждую уже купленную в этом забеге (шаурма: 30, 35, 40…)
func kiosk_price(id: String) -> int:
	var k := kiosk_item(id)
	if k.is_empty():
		return 0
	return int(k["price"]) + int(k.get("step", 0)) * int((run.get("kiosk", {}) as Dictionary).get(id, 0))

## Можно ли купить и почему нет («» — можно)
func kiosk_why(id: String) -> String:
	var k := kiosk_item(id)
	if k.is_empty():
		return "нет такого"
	if kiosk_left(id) <= 0:
		return "на забег всё"
	if int(run.get("golda", 0)) < kiosk_price(id):
		return "не хватает голды"
	if id == "togo" and togo_pool().is_empty():
		return "бафов больше нет"
	return ""

static func kiosk_item(id: String) -> Dictionary:
	for k in G67Data.KIOSK:
		if String(k["id"]) == id:
			return k
	return {}

## «С СОБОЙ»: баффы, которые ещё можно взять или улучшить; редкие — с шансом KIOSK_RARE
func togo_pool() -> Array:
	var out: Array = []
	for id in G67Data.FITS:
		if fit_lv(id) < int(G67Data.FITS[id]["lv"]):
			out.append(id)
	return out

## Купить товар; ответ — что получил («» — не купил)
func kiosk_buy(id: String) -> String:
	if kiosk_why(id) != "":
		return ""
	var k := kiosk_item(id)
	var paid := kiosk_price(id)
	run["golda"] = int(run["golda"]) - paid
	run["spent"] = int(run.get("spent", 0)) + paid
	var bought: Dictionary = run["kiosk"]
	bought[id] = int(bought.get(id, 0)) + 1
	var p = game.player
	var got := ""
	match id:
		"shawarma":
			p.hp = minf(p.max_hp, p.hp + G67Data.KIOSK_HEAL)
			got = "+%d здоровья" % int(G67Data.KIOSK_HEAL)
		"double":
			run["maxhp_buys"] = int(run.get("maxhp_buys", 0)) + 1
			apply_fits("double")
			p.hp = minf(p.max_hp, p.hp + G67Data.KIOSK_HEAL)
			got = "+%d здоровья, максимум +%d" % [int(G67Data.KIOSK_HEAL), int(G67Data.KIOSK_MAXHP)]
		"togo":
			var pool := togo_pool()
			var rares := pool.filter(func(f): return bool(G67Data.FITS[f]["rare"]))
			var common := pool.filter(func(f): return not bool(G67Data.FITS[f]["rare"]))
			var from: Array = rares if (not rares.is_empty() and (common.is_empty() or randf() < G67Data.KIOSK_RARE)) else common
			var fid := String(from[randi() % from.size()])
			var fits: Dictionary = run["fits"]
			fits[fid] = fit_lv(fid) + 1
			apply_fits(fid)
			got = "%s · ур. %d" % [String(G67Data.FITS[fid]["name"]), fit_lv(fid)]
			events.append(["fit", fid])
	events.append(["kiosk", id])
	return got

# ---------------------------------------------------------------- фитсы
func fit_lv(id: String) -> int:
	return int((run.get("fits", {}) as Dictionary).get(id, 0))

## Три фитса на выбор (те, что ещё можно улучшить). rare — комната элиты: редкие предлагаются первыми.
func fit_options(rare: bool) -> Array:
	var common: Array = []
	var rares: Array = []
	for id in G67Data.FITS:
		if fit_lv(id) < int(G67Data.FITS[id]["lv"]):
			if bool(G67Data.FITS[id]["rare"]):
				rares.append(id)
			else:
				common.append(id)
	common.shuffle()
	rares.shuffle()
	# «РЕДКИЕ ФИТСЫ» (АВТОРИТЕТ РАЙОНА): обычная комната с шансом 6 % за уровень предлагает редкий первым
	var rare_first := rare or randf() < 0.06 * float(up("rare"))
	var ids: Array = (rares + common) if rare_first else (common + rares)
	return ids.slice(0, 3)

const FitUIScript := preload("res://scripts/golda67/g67_fit_ui.gd")
var fit_offer: Array = []
var fit_rare := false

## Экран «ВЫБЕРИ БАФ» (G67FitUI): три бирки на вешалке и «ПЕРЕВЫБРАТЬ»
func _offer_fit(rare: bool) -> void:
	var opts := fit_options(rare)
	if opts.is_empty():
		add_golda(25)
		_stage_end()
		return
	fit_offer = opts
	fit_rare = rare
	open_screen("fit")

## Перевыбор: тратит один перевыбор, закрывает экран и открывает новый с другими бафами
func fit_reroll(rare: bool) -> void:
	if int(run.get("rerolls", 0)) <= 0:
		return
	run["rerolls"] = int(run["rerolls"]) - 1
	events.append(["reroll"])
	if hub_ui != null:
		hub_ui.close()
	_offer_fit(rare)

func take_fit(id: String) -> void:
	if not G67Data.FITS.has(id) or fit_lv(id) >= int(G67Data.FITS[id]["lv"]):
		return
	var fits: Dictionary = run["fits"]
	fits[id] = fit_lv(id) + 1
	events.append(["fit", id])
	game._close_panel()
	if hub_ui != null and hub_ui.kind == "fit":
		hub_ui.close()
	apply_fits(id)
	game.banner(String(G67Data.FITS[id]["name"]), "баф · уровень %d" % fit_lv(id), G67Data.FAMILY_COLOR["misha"], 2.2)
	game.main.ui("confirm")
	if room_state == "reward":
		_stage_end()

## Пересчитать усиления забега. Исходные данные стилей не меняются: только множитель урона героя и его здоровье.
func apply_fits(just := "") -> void:
	var p = game.player
	fit_mul = minf(G67Data.DMG_CAP, 1.0 + 0.12 * float(fit_lv("heavy_hand")) + 0.04 * float(up("dmg")))
	p.dmg_mul = dmg_now()
	var want := hp_max() + 20.0 * float(fit_lv("authority")) + (20.0 if has_art("beanie") else 0.0) + G67Data.KIOSK_MAXHP * float(run.get("maxhp_buys", 0))
	if want != p.max_hp:
		p.max_hp = want
		if just in ["authority", "beanie", "double"]:
			p.hp = minf(p.max_hp, p.hp + (20.0 if just != "double" else G67Data.KIOSK_MAXHP))
	p.hp = minf(p.hp, p.max_hp)

func _second_wind() -> void:
	var lv := fit_lv("second_wind")
	if lv <= 0 or wind_used:
		return
	var p = game.player
	if p.hp > 0.0 and p.hp < p.max_hp * G67Data.WIND_AT:
		wind_used = true
		p.hp = minf(p.max_hp, p.hp + float(G67Data.WIND_HEAL[mini(lv, G67Data.WIND_HEAL.size()) - 1]))
		game.popup(p.global_position + Vector3(0, 2.2, 0), "ВТОРОЕ ДЫХАНИЕ", G67Data.FAMILY_COLOR["misha"])
		events.append(["wind"])

# ---------------------------------------------------------------- передышка, босс, конец забега
## Передышка: герой уже у лавки в беседке — лечение сразу, этап пройден
func rest() -> void:
	if room_state != "reward" or String(room.get("type", "")) != "break":
		return
	var p = game.player
	var add: float = p.max_hp * G67Data.BREAK_HEAL
	p.hp = minf(p.max_hp, p.hp + add)
	events.append(["rest"])
	game.banner("ПЕРЕДЫШКА", "здоровье +%d" % int(add), Color(0.5, 0.95, 0.6), 2.0)
	_stage_end()

## РЕСПЕКТ забега по источникам (для экрана итогов): battle, elite, calm, boss
func _add_respect(cat: String, n: int) -> void:
	run["respect"] = int(run.get("respect", 0)) + n
	var rp: Dictionary = run.get("resp", {})
	rp[cat] = int(rp.get(cat, 0)) + n
	run["resp"] = rp

## Что открылось в этом забеге (экран итогов, блок «ОТКРЫТО»)
func _note_new(text: String) -> void:
	if place != "run" or run.is_empty():
		return
	var nw: Array = run.get("new", [])
	if not nw.has(text):
		nw.append(text)
	run["new"] = nw

func _boss_down(e) -> void:
	_crowd("win")
	var d := district()
	room_state = "over"
	game.slowmo(1.4)
	game.shake(0.8)
	game.fx.slam(e.global_position, 1.8, Color(e.boss["c"]))
	if game.boss_e == e:
		game.boss_e = null
	var fl: Dictionary = meta().get("flags", {})
	var first := not bool(fl.get(String(d["flag"]), false))
	fl[String(d["flag"])] = true
	meta()["flags"] = fl
	add_golda(int(round(float(G67Data.ROOM_GOLDA["boss"]) * (1.5 if has_art("flash_drive") else 1.0))))
	_add_respect("boss", int(G67Data.RESPECT["boss_first" if first else "boss"]) + (10 if has_art("flash_drive") else 0))
	if first:
		for t in ["Стиль «Водяра» — стойка стилей в подъезде", "Новый листок на доске объявлений", "Письмо в почтовом ящике кв. 42", "Запись «РАЙОННЫЙ ВЕСТНИК 67» — телевизор в подъезде", "Граффити «ПАХАН + MADK1D БЫЛИ ТУТ» — у двери подъезда"]:
			_note_new(t)
	events.append(["boss_down", String(d["boss"])])
	var style_name := String(Styles.by_id(String(d["unlock"])).title).to_upper()
	game.banner("МИША МИНАСЯН ПОВЕРЖЕН", ("открыт стиль: %s" % style_name) if first else "район пройден", Color(1, 0.85, 0.3), 4.0)
	_finish_run(true, 2.5)

func on_dead() -> void:
	if place != "run":
		# в подъезде погибнуть не от чего; на всякий случай — на ноги
		game.over = false
		game.player.hp = game.player.max_hp
		return
	if room_state == "over":
		return
	game.over = true
	room_state = "over"
	game.slowmo(1.0)
	events.append(["dead"])
	game.banner("ЗАБЕГ ОКОНЧЕН", "РЕСПЕКТ и открытое остаются с тобой", Color(0.9, 0.3, 0.25), 3.0)
	for en in game.enemies:       # погиб: враги замирают и больше не бьют
		if is_instance_valid(en) and en.state != "dead":
			en.set_physics_process(false)
			en.velocity = Vector3.ZERO
			en.rig.play("Idle", 0.2)
	_finish_run(false, 1.2)

const ResultUIScript := preload("res://scripts/golda67/g67_result_ui.gd")
var result: Dictionary = {}      # итоги последнего забега (экран G67ResultUI)

## Конец забега: РЕСПЕКТ — в постоянное и в сохранение ДО экрана итогов, голда сгорает, забег стирается; через delay —
## экран итогов (двор под ним), дальше «В ПОДЪЕЗД» или «НОВЫЙ ЗАБЕГ» (result_to_hub / result_new_run)
func _finish_run(won: bool, delay: float) -> void:
	var got := int(run.get("respect", 0))
	var first_win := won and bool((run.get("new", []) as Array).size() > 0 and (run["new"] as Array).has("Стиль «Водяра» — стойка стилей в подъезде"))
	meta()["respect"] = int(meta().get("respect", 0)) + got
	meta()["runs"] = int(meta().get("runs", 0)) + 1
	data["run"] = {}
	save()
	result = {"won": won, "first": first_win, "got": got, "total": int(meta()["respect"]), "parts": (run.get("resp", {}) as Dictionary).duplicate(),
		"stages": (run.get("stages", []) as Array).duplicate(true) + ([["boss", "sport"]] if won else []), "died_at": ([] if won else [String(room.get("type", "")), String(room.get("place", ""))]), "stage_n": int(run.get("pos", 0)) + (1 if won else 0), "kills": int(run.get("kills", 0)),
		"earned": int(run.get("earned", 0)), "spent": int(run.get("spent", 0)), "left": int(run.get("golda", 0)), "fits": (run.get("fits", {}) as Dictionary).duplicate(),
		"arts": (run.get("arts", []) as Array).duplicate(), "new": (run.get("new", []) as Array).duplicate(), "boss_death": not won and String(room.get("type", "")) == "boss"}
	events.append(["finish", won, got])
	await game.get_tree().create_timer(delay, true, false, true).timeout
	if not is_instance_valid(game) or game.golda != self:
		return
	game.over = false
	Engine.time_scale = 1.0
	open_screen("result")

func _after_run() -> void:
	game.over = false
	Engine.time_scale = 1.0
	var p = game.player
	p.state = "move"
	p.rage = 0.0
	p.rig.play("Idle", 0.1)

## «В ПОДЪЕЗД» на экране итогов
func result_to_hub() -> void:
	if hub_ui != null:
		hub_ui.close()
	_after_run()
	var got := int(result.get("got", 0))
	var won := bool(result.get("won", false))
	await enter_hub()
	game.toast("РЕСПЕКТ +%d" % got)
	if won and bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false)):
		unlock_clip("NEWS01")
		if auto_clips and not auto_played("NEWS01"):
			await play_auto("NEWS01")        # «РАЙОННЫЙ ВЕСТНИК 67» после первой победы над Мишей

## «НОВЫЙ ЗАБЕГ»: сразу во двор (здоровье и стиль — как при выходе из подъезда)
func result_new_run() -> void:
	if hub_ui != null:
		hub_ui.close()
	_after_run()
	if bool(result.get("won", false)) and bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false)):
		unlock_clip("NEWS01")
	await enter_hub()
	await start_run("dvor")

# ---------------------------------------------------------------- HUD и взаимодействие
## Строка вверху экрана вместо главы и задания кампании
func hud_line() -> String:
	if place == "hub" or run.is_empty():
		return "ГОЛДА 67 · ПОДЪЕЗД · РЕСПЕКТ %d" % int(meta().get("respect", 0)) + (" · ЗАБЕГ НА ПАУЗЕ" if paused_run() else "")
	var d := district()
	var s := "ГОЛДА 67 · %s %d/%d · голда %d" % [String(d["name"]), int(run["pos"]) + 1, route().size(), int(run["golda"])]
	if room_state == "fight":
		s += " · врагов: %d" % (alive() + pending.size())
	if not arts().is_empty():
		s += " · артефактов %d/%d" % [arts().size(), slots()]
	if room_state == "open" and world != null:
		s += "\n" + next_line()
	return s

## «ДАЛЬШЕ: ГАРАЖИ — бой · ДЕТСКАЯ ПЛОЩАДКА — баф»: куда можно идти после этапа
func next_line() -> String:
	var parts: Array = []
	for g in world.gates:
		var o: Dictionary = g["option"]
		var type := String(o["type"])
		if type == "boss":
			parts.append("КОРОБКА — %s" % String(G67Data.ROOM_HINT["boss"]))
		else:
			parts.append("%s — %s" % [String(G67Yard.zone(String(o.get("place", "")))["name"]).to_upper(), String(G67Data.ROOM_NAMES[type])])
	return "ДАЛЬШЕ: " + " · ".join(parts)

## Подсказки предметов подъезда по состоянию: сервант, дверь, стойка стилей, карта
func refresh_hints() -> void:
	if place != "hub" or world == null:
		return
	var n_art := (meta().get("artifacts", []) as Array).size()
	var door := "начать забег"
	var tpl := int(meta().get("runs", 0)) % 3
	if paused_run():
		var sv: Dictionary = data["run"]
		var rr: Dictionary = sv["run"]
		door = "продолжить забег · этап %d из 7 · здоровье %d из %d" % [int(rr.get("pos", 0)) + 1, int(float(sv.get("hp", game.player.max_hp))), int(game.player.max_hp)]
		tpl = int(rr.get("tpl", 0))
	for pt in world.points:
		match String(pt["id"]):
			"artifacts": pt["hint"] = ("найдено %d из %d" % [n_art, G67Data.ARTIFACTS.size()]) if n_art > 0 else "пока пусто"
			"exit": pt["hint"] = door
			"styles": pt["hint"] = String(Styles.by_id(start_style()).title)
			"routes": pt["hint"] = "ДВОР · маршрут № %d" % (tpl + 1)

func point(id: String) -> Dictionary:
	if world != null:
		for pt in world.points:
			if String(pt["id"]) == id:
				return pt
	return {}

## Музыка режима (MusicDirector): единственное место, где она решается. Состояние только читается, таймеров два:
## 8 с «эфира из телевизора» после забега и 4 с ожидания конца реплики босса после постановки.
var hub_back_t := 0.0
var bark_hold := 0.0
var last_district := "dvor"
var tv_marker: Marker3D

func _tv_node() -> Node3D:
	if tv_marker != null and is_instance_valid(tv_marker) and tv_marker.get_parent() == world:
		return tv_marker
	var pt := point("tv")
	if pt.is_empty() or world == null:
		return null
	tv_marker = Marker3D.new()
	tv_marker.name = "TvSpeaker"
	world.add_child(tv_marker)
	tv_marker.global_position = Vector3(pt["pos"]) + Vector3(0, 1.0, 0)
	return tv_marker

func music_context() -> Dictionary:
	var dir = game.main.audio.director
	var res := {"dialogue": "talk", "boss_set": ""}
	if place == "hub":
		var back := hub_back_t > 0.0
		res["ctx"] = "explore"
		res["cue"] = dir.resolve_cue("loc_g67_" + last_district, "loc_snow") if back else dir.resolve_cue("loc_g67_hub", "loc_hall")
		res["layers"] = [1.0, 0.0, 0.0]
		res["transition"] = "cross"
		var tv := _tv_node()
		if tv != null:
			res["via"] = tv
		return res
	last_district = String(run.get("district", last_district))
	var yard: String = dir.resolve_cue("loc_g67_" + last_district, "loc_snow")
	res["cue"] = yard
	res["layers"] = [1.0, 0.0, 0.0]
	res["ctx"] = "explore"
	res["transition"] = "gap"
	if room_state == "boss":
		var boss = game.boss_e
		var staging: bool = scene_t >= 0.0 or (bark_hold > 0.0 and game.bark_b.playing)
		if staging:
			res["ctx"] = "story"
			res["cue"] = ""
		elif boss != null and is_instance_valid(boss) and boss.state != "dead":
			var want := "boss_" + String(boss.boss_id)
			var set_used: String = dir.resolve_cue(want, "boss_courier")
			res["ctx"] = "boss"
			res["transition"] = "boss_in"
			if set_used != "":
				res["cue"] = set_used
				res["boss_set"] = set_used
				res["layers"] = [1.0, 1.0 if boss.phase >= 1 else 0.0, 1.0 if boss.phase >= 2 else 0.0]
	elif room_state == "over":
		res["ctx"] = "victory"
		res["transition"] = "cross"
	elif game.enemies.any(func(e): return is_instance_valid(e) and e.state != "dead"):
		res["ctx"] = "combat"
		res["layers"] = [1.0, 1.0, 0.0]
	return res

func _physics_process(dt: float) -> void:
	if game == null or world == null or not is_instance_valid(world):
		return
	if game.get_tree().paused:
		if prompt != null:
			prompt.visible = false
		return
	_t += dt
	hub_back_t = maxf(0.0, hub_back_t - dt)
	bark_hold = maxf(0.0, bark_hold - dt)
	if talk_on:
		_talk_step(dt)
	if scene_t >= 0.0:
		_scene_tick(dt)
	_marks_tick()
	_krot_tick(dt)
	_crowd_tick()
	if place == "run" and not busy and not game.over and not run.is_empty():
		if room_state == "fight":
			_fight_tick(dt)
		_stash_tick(dt)
		_ambush_tick()
		_second_wind()
	_art_tick(dt)
	if hints == null:
		hints = HintsScript.new(self)
	hints.tick(dt)
	var pp: Vector3 = game.player.global_position
	var best := ""
	var bd := REACH + (0.6 if place == "run" else 0.0)
	for pt in world.points:
		if absf(pp.y - float(pt["pos"].y)) > 1.2:
			continue                       # предмет на другом этаже
		var d: float = Vector2(pp.x - pt["pos"].x, pp.z - pt["pos"].z).length()
		if d < bd:
			bd = d
			best = String(pt["id"])
	if best != near:
		near = best
		if near != "":
			events.append(["near", near])
	if prompt != null:
		prompt.visible = near != "" and game.panel == null and game.mode != "dlg" and hub_ui == null and clip == null
		if near != "":
			var pt2 := point(near)
			prompt.text = "[E]  %s\n%s" % [String(pt2["title"]), String(pt2["hint"])]

func _unhandled_input(e: InputEvent) -> void:
	if game == null or near == "" or game.panel != null or game.get_tree().paused or busy or hub_ui != null or clip != null:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_E:
		var pl = game.player
		if place == "run" and pl.execution.can_start() and not pl.execution.pick().is_empty():
			return                     # добивание на [E] важнее предмета рядом
		use(near)
		get_viewport().set_input_as_handled()

## Взаимодействие с предметом. Экраны предметов хаба ещё не сделаны — честно говорим об этом.
func use(id: String) -> void:
	var pt := point(id)
	if pt.is_empty():
		return
	events.append(["use", id])
	if id == "exit":
		if auto_clips and not auto_played("AD01"):
			await play_auto("AD01")          # реклама турнира — перед первым выходом во ДВОР
		if paused_run():
			resume_run()
		else:
			start_run("dvor")
	elif id == "home":
		if room_state == "open":
			go_home()
		else:
			game.toast("Сначала разберись с этими")
	elif id == "tv":
		tv()
	elif id == "kiosk":
		if room_state in ["open", "reward"]:
			open_screen("kiosk")
		else:
			game.toast("Сначала разберись с этими")
	elif id == "storage":
		open_screen("storage")
	elif id == "krot":
		talk_krot()
	elif id == "flurr":
		talk_flurr()
	elif id.begins_with("gate"):
		choose_gate(int(id.substr(4)))
	elif id in ["upgrades", "styles", "artifacts", "routes", "mail"]:
		open_screen(id)
	elif id == "notices":
		open_screen("board")
	else:
		pass                                 # декорация без действия: молча

func to_menu() -> void:
	game._to_menu()

# ---------------------------------------------------------------- зрители у коробки Миши
const CROWD_HITS := ["hit_super", "vz_finisher", "vz_slam", "vz_quake", "knockdown"]
var crowd_t := -9.0
var crowd_phase := -1

func _crowd(kind: String) -> void:
	if place != "run" or world == null or world.yard == null or String(room.get("place", "")) != "sport":
		return                       # зрители видят только свою коробку
	world.yard.crowd_react(kind)
	events.append(["crowd", kind])

## Сильный удар, добивание, сбитый с ног — короткая реакция части зрителей (не чаще раза в 2,5 с)
func _on_feedback(nm: String, _pos: Vector3, power: float) -> void:
	if not (nm in CROWD_HITS or (nm == "hit_heavy" and power >= 1.2)):
		return
	if game.clock - crowd_t < 2.5:
		return
	crowd_t = game.clock
	_crowd("hit")

## Смена фазы босса — реагируют почти все
func _crowd_tick() -> void:
	var b = game.boss_e
	if b == null or not is_instance_valid(b):
		crowd_phase = -1
		return
	if crowd_phase >= 0 and int(b.phase) != crowd_phase:
		_crowd("phase")
	crowd_phase = int(b.phase)

# ---------------------------------------------------------------- ролики главы 1 (G67Clips, G67ClipPlayer)
var clip: G67ClipPlayer = null
var hub_ui = null                       # открытый экран предмета подъезда (G67Diorama или G67AuthorityUI)
## Ролики сами по ходу игры (в проверке выключено: она запускает их в своём разделе)
var auto_clips := true

func clip_seen(cid: String) -> bool:
	return (meta().get("clips_seen", []) as Array).has(cid)

## Ролик уже запускался сам (досмотрен или пропущен); у старых сохранений всё из clips_seen считается запускавшимся
func auto_played(cid: String) -> bool:
	return (meta().get("clips_auto", []) as Array).has(cid) or clip_seen(cid)

## Автозапуск: помечаем сразу и в сохранение — пропущенный ролик сам больше не повторяется (в архиве остаётся «новой записью»)
func play_auto(cid: String) -> void:
	if auto_played(cid):
		return
	var au: Array = meta().get("clips_auto", [])
	au.append(cid)
	meta()["clips_auto"] = au
	save()
	await play_clip(cid)

func clip_open(cid: String) -> bool:
	return (meta().get("archive", []) as Array).has("clip_" + cid)

func unlock_clip(cid: String) -> void:
	var arch: Array = meta().get("archive", [])
	if not arch.has("clip_" + cid):
		arch.append("clip_" + cid)
		_note_new("Запись «%s» — телевизор в подъезде" % G67Clips.title(cid))
		meta()["archive"] = arch
		save()
		events.append(["clip_open", cid])

## Показать ролик; ждать конца. Первый показ — без пропуска; после — отмечен просмотренным
func play_clip(cid: String) -> void:
	if clip != null:
		return
	unlock_clip(cid)
	game.player.velocity = Vector3.ZERO
	if prompt != null:
		prompt.visible = false
	game.voice.stop()
	game._hush()
	clip = G67ClipPlayer.open(game, cid, clip_seen(cid))
	events.append(["clip", cid])
	var cp = clip
	await cp.finished
	var was_skipped: bool = cp.skipped
	clip = null
	if was_skipped:
		events.append(["clip_skipped", cid])
		return                                # пропущенный ролик открыт в архиве, но не просмотрен: «НОВАЯ ЗАПИСЬ» остаётся
	var seen: Array = meta().get("clips_seen", [])
	if not seen.has(cid):
		seen.append(cid)
		meta()["clips_seen"] = seen
		save()

## Телевизор в подъезде: впервые — трейлер; потом — список открытых роликов (пересмотр)
func tv() -> void:
	if not clip_seen("V00"):
		await play_clip("V00")
		return
	_tv_menu()

## Экран предмета подъезда: архив, АВТОРИТЕТ РАЙОНА, стойка стилей, коллекция, карта, доска, ящики
func open_screen(what: String) -> void:
	if hub_ui != null or clip != null:
		return
	game.player.velocity = Vector3.ZERO
	if prompt != null:
		prompt.visible = false
	match what:
		"upgrades": hub_ui = G67AuthorityUI.open(self)
		"archive": hub_ui = G67ArchiveUI.open(self)
		"board": hub_ui = G67BoardUI.open(self)
		"mail": hub_ui = G67MailUI.open(self)
		"styles": hub_ui = G67StylesUI.open(self)
		"artifacts": hub_ui = G67ArtifactsUI.open(self)
		"routes": hub_ui = G67RoutesUI.open(self)
		"storage": hub_ui = G67StorageUI.open(self)
		"kiosk": hub_ui = G67KioskUI.open(self)
		"fit": hub_ui = FitUIScript.open(self, fit_offer, fit_rare)
		"result": hub_ui = ResultUIScript.open(self)
	hub_ui.closed.connect(func():
		hub_ui = null
		refresh_hints())

func _tv_menu() -> void:
	open_screen("archive")

func _tv_close() -> void:
	if hub_ui != null:
		hub_ui.close()
