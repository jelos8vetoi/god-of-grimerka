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
const PZ_CAM_LEN := 4.6
var sel_district := "dvor"
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
const SCENE_LEN := 11.0       # выход Миши: трон → встаёт → идёт по ковру → цепь за стойку → «Так и задумано.» → топот, прожекторы → бой
const SCENE_SIT := 1.6        # до этой секунды сидит (общий план арены)
const SCENE_STAND := 2.6      # с этой идёт
const SCENE_WALK := 2.6
const SCENE_CATCH := 4.8      # цепь цепляется за стойку растяжки
const SCENE_FREE := 6.2       # рывок — освободилась
const SCENE_STOP := 8.6       # дошёл и топнул
const SKIP_HOLD := 0.8
var scene_fov := 50.0
var skip_hold := 0.0
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

const MADK_SPOT := Vector3(-1.15, 1.5, -4.95)          # табурет у телевизора на площадке
const MADK_SPOT2 := Vector3(1.9, 1.5, -4.7)
const MADK_TV := Vector3(-2.58, 1.5, -5.55)
var madk_st := "sit"                  # sit / walk / stand
var madk_path: Array = []
var madk_dest := 0
var madk_t := 8.0
var madk_swap_t := 80.0
var madk_stand_t := 0.0
var madk_log: Array = []

## Жизнь madk1d в подъезде: раз в 8–15 с поднял голову / перехватил телефон / сменил позу; на возвращение Пахана кивает; раз в 60–120 с
## встаёт, идёт ко второму месту и обратно. Не идёт за героем и не покидает площадку. true — companion не делает своего.
func madk_life(b, dt: float) -> bool:
	var rig: Rig = b.rig
	var now: float = game.clock
	b.velocity = Vector3(0, b.velocity.y - 20.0 * dt, 0)
	b.foe = null
	madk_t -= dt
	madk_swap_t -= dt
	if madk_st == "walk":
		if madk_path.is_empty():
			madk_st = "stand" if madk_dest == 1 else "sit"
			madk_stand_t = randf_range(18.0, 30.0)
			madk_log.append("arrive%d" % madk_dest)
			return true
		var tgt: Vector3 = madk_path[0]
		var d := Vector3(tgt.x - b.global_position.x, 0.0, tgt.z - b.global_position.z)
		if d.length() < 0.12:
			madk_path.pop_front()
			return true
		var dir := d.normalized()
		b.global_position += dir * minf(d.length(), 1.0 * dt)
		b.face = lerp_angle(b.face, atan2(dir.x, dir.z), 1.0 - exp(-6.0 * dt))
		if rig.cur != "NWalk":
			rig.play("NWalk", 0.25)
		return true
	if madk_st == "stand":
		madk_stand_t -= dt
		var toh: Vector3 = game.player.global_position - b.global_position
		b.face = lerp_angle(b.face, atan2(toh.x, toh.z) if toh.length() < 4.0 else PI, 1.0 - exp(-4.0 * dt))
		if rig.cur != "NPhone":
			rig.play("NPhone", 0.3)
		if madk_stand_t <= 0.0:
			madk_dest = 0
			madk_path = [Vector3(MADK_SPOT.x + 0.0, 1.5, -4.2), MADK_SPOT]
			madk_st = "walk"
			madk_log.append("back")
		return true
	# сидит
	var to_tv: Vector3 = MADK_TV - b.global_position
	b.face = lerp_angle(b.face, atan2(to_tv.x, to_tv.z), 1.0 - exp(-4.0 * dt))
	if b.home_react != "" and now >= b.home_until:
		b.home_react = ""
		b.home_until = now + 1.5
		rig.play_for("MSitNod", 1.5, 0.1)
		madk_log.append("nod")
		return true
	if now >= b.home_until:
		if madk_swap_t <= 0.0:
			madk_swap_t = randf_range(60.0, 120.0)
			madk_dest = 1
			madk_path = [Vector3(MADK_SPOT.x + 0.0, 1.5, -4.2), Vector3(MADK_SPOT2.x, 1.5, -4.2), MADK_SPOT2]
			madk_st = "walk"
			madk_log.append("up")
			return true
		if madk_t <= 0.0:
			madk_t = randf_range(8.0, 15.0)
			var pick: Array = [["MSitLook", 3.0], ["MSitSwap", 2.2], ["MSitShift", 2.6]].pick_random()
			rig.play_for(String(pick[0]), float(pick[1]), 0.2)
			b.home_until = now + float(pick[1])
			madk_log.append(String(pick[0]))
		elif rig.cur != "MSitPhone":
			rig.play("MSitPhone", 0.3)
	return true

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
	await play_auto("STORY01")               # регистрация — до первого забега (STORY05 — при первом возвращении после забега)

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
	G67District.use("yard")
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
	madk_st = "sit"
	madk_path = []
	madk_t = randf_range(5.0, 10.0)
	madk_swap_t = randf_range(60.0, 120.0)
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
	world.build_hub_life()
	refresh_hints()
	events.append(["enter", "hub"])
	await game.get_tree().process_frame
	game.banner(TITLE, "ПОДЪЕЗД · РЕСПЕКТ: %d" % int(meta().get("respect", 0)), Color(1.0, 0.8, 0.2), 3.5)
	if auto_clips and int(meta().get("runs", 0)) >= 1 and not auto_played("STORY05") and clip == null and place == "hub":
		await game.get_tree().create_timer(1.2).timeout
		if is_instance_valid(self) and place == "hub" and clip == null and not auto_played("STORY05"):
			await play_auto("STORY05")       # первое обращение организатора — первое возвращение в подъезд после забега

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
func _build_pz_world() -> void:
	if ylife != null and is_instance_valid(ylife):
		ylife.free()
	ylife = null
	if duos != null and is_instance_valid(duos):
		duos.free()
	duos = null
	_swap_world(func(w: G67World): w.build_podzemka())
	krot_k = {}
	stash_nodes = {}
	world.district.hero = game.player

func _build_yard_world() -> void:
	if String(run.get("district", "dvor")) == "podzemka":
		_build_pz_world()
		return
	_swap_world(func(w: G67World): w.build_yard())
	krot_k = {}
	if world.yard != null:
		for l in world.yard.lifes:
			(l as G67Life).watcher = game.player       # жители замечают Пахана, когда он рядом и впереди
	if world.yard != null:
		world.yard.hero = game.player
	world.add_kiosk()
	world.add_residents()
	world.add_life_points()
	ylife_get()
	duos_get()
	world.add_home()
	world.build_event_props()
	_place_krot_yard()
	_build_stash()
	world.add_descent()

## Герой — у двери дома лицом во двор, камера за спиной
func _stand_at_home() -> void:
	game.cam_len = YARD_CAM_LEN
	var p = game.player
	if G67District.is_podzemka():
		game.cam_len = PZ_CAM_LEN
		p.global_position = G67Podzemka.STAIRS_TOP
		p.velocity = Vector3.ZERO
		p.face = PI
		game.cam_yaw = 0.0
		game.fx.prewarm(p.global_position)
		return
	p.global_position = G67District.pt("home") + Vector3(0, 0.05, -4.5)
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
	G67District.use("podzemka" if district_id == "podzemka" else "yard")
	_seed_yard()
	run["stash"] = _stash_plan() if district_id != "podzemka" else {"spots": [], "taken": []}
	game.buddy.visible = false
	game.buddy.global_position = Vector3(0, -50, 0)
	events.append(["run", district_id])
	unlock_clip("CL01")                      # «КАК ЗАЙТИ ВО ДВОР» — в архив после входа во ДВОР
	apply_fits()
	wind_used = false
	_build_yard_world()
	_stand_at_home()
	await enter_room({"type": "battle", "place": "gate1" if district_id == "podzemka" else "podezd"})

## Домой посреди забега: дверь подъезда во дворе (между этапами, вне боя). Забег — в сохранение (data["run"]:
## забег, этап, здоровье, состояние), в подъезде он стоит на паузе; выход во двор продолжает его с двери подъезда —
## варианты следующего этапа снова открыты. Гибель или конец забега стирают паузу (_finish_run).
func go_home() -> void:
	if busy or place != "run" or room_state != "open":
		return
	flush_coins()
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
	run["pos"] = clampi(int(run.get("pos", 0)), 0, 4)       # шесть позиций: старая запись из семи зажимается, этап считается пройденным
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
	G67District.use("podzemka" if String(run.get("district", "dvor")) == "podzemka" else "yard")
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
## Слот DOG CASINO 67: спин на экране корпуса и крупно на время игры; 67-й спин — всё поле ротвейлеры
var slot_busy := false
## Реплики и награды казино: каждые 8 проигрышей — «КАЗИНО УБИВАЕТ МОЮ ЖИЗНЬ!» всё громче; «почти» — «Да вы издеваетесь, блядь!»; 67-й — награда и ОШЕЙНИК 67 один раз
const CASINO_KILLS := ["казино убивает мою жизнь...", "КАЗИНО УБИВАЕТ МОЮ ЖИЗНЬ!", "КАЗИНО УБИВАЕТ МОЮ ЖИЗНЬ!!", "КАЗИНО УБИВАЕТ МОЮ ЖИЗНЬ!!!", "КАЗИНО УБИВАЕТ МОЮ ЖИЗНЬ!!!!!"]
var casino_losses := 0

func _casino_react(n: int, res: Dictionary, pz: G67Podzemka) -> void:
	if bool(res["jackpot"]):
		game.banner("ДААААА, БЛЯТЬ!", "ТРИ СОБАКИ!", Color(1, 0.85, 0.2), 3.0)
		var m := meta()
		if not bool(m.get("collar67", false)):
			m["collar67"] = true
			if not run.is_empty():
				take_art("collar_67")
			var arch: Array = m.get("archive", [])
			if not arch.has("casino67"):
				arch.append("casino67")
			m["archive"] = arch
			_note_new("ОШЕЙНИК 67 — запись в архиве")
		events.append(["casino_jackpot", n])
	elif bool(res.get("near", false)):
		game.toast("Да вы издеваетесь, блядь!")
		pz.dog_bark()
		events.append(["casino_near", n])
	elif int(res["gold"]) == 0:
		casino_losses += 1
		if casino_losses % 8 == 0:
			var lv := mini(casino_losses / 8 - 1, CASINO_KILLS.size() - 1)
			game.toast(CASINO_KILLS[lv])
			events.append(["casino_kills", lv])
	save()

func _slot_use(force_turbo := false) -> void:
	var pz := world.district as G67Podzemka if world != null else null
	if pz == null or pz.slot_screen == null or slot_busy:
		return
	slot_busy = true
	var m := meta()
	var n := int(m.get("casino_spins", 0)) + 1
	m["casino_spins"] = n
	var layer := CanvasLayer.new()
	layer.layer = 20
	var tr := TextureRect.new()
	tr.texture = pz.slot_vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tr)
	game.add_child(layer)
	pz.slot_screen.spin(n, Input.is_key_pressed(KEY_SHIFT) or force_turbo)
	var res: Dictionary = await pz.slot_screen.finished
	_casino_react(n, res, pz)
	if n == 66:
		_casino_accent(pz)
		await get_tree().create_timer(1.0).timeout
	if bool(res["jackpot"]):
		await get_tree().create_timer(2.5).timeout
	else:
		await get_tree().create_timer(0.8).timeout
	if int(res["gold"]) > 0 and not run.is_empty():
		run["golda"] = int(run["golda"]) + int(res["gold"])
		game.banner("СЛОТ", "+%d голды" % int(res["gold"]), Color(1, 0.85, 0.3), 1.6)
	layer.queue_free()
	slot_busy = false
	events.append(["slot", n, bool(res["jackpot"])])

var _hamster_first_enter := false
var hamster_busy := false
var bottle_busy := false
var arena: G67FortunaArena = null

## Арена FORTUNA: турникеты, зоны, касса со стеклом; создаётся с боссом, убирается с концом боя
func arena_setup(boss) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	arena = G67FortunaArena.new()
	world.add_child(arena)
	arena.build(game, self)
	arena.boss = boss
	arena.boss_pinned.connect(func():
		if boss != null and is_instance_valid(boss):
			G67Fortuna.say(boss, "pinned")
			G67Fortuna.hard_stun(boss, G67Fortuna.PIN_OPEN, "FPinned")
			game.popup(boss.global_position + Vector3(0, boss.height + 0.4, 0), "ОТКРЫТ", Color(1.0, 0.9, 0.3))
			events.append(["fortuna_pinned"]))
	arena.glass_broken.connect(func():
		if boss != null and is_instance_valid(boss) and boss.state == "special":
			G67Fortuna.say(boss, "glass")
			G67Fortuna.hard_stun(boss, G67Fortuna.CONSULT_STUN, "FStun"))
	events.append(["arena_ready"])

func arena_teardown() -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	arena = null
var reserve_charges := 0
var reserve_lb: Label = null

## Попадание бутылкой Водяры: тратит заряд «АВАРИЙНОГО ЗАПАСА 0.5» (5 на забег), шестое попадание обычное
func reserve_use() -> bool:
	if reserve_charges <= 0 or not has_art("reserve_05"):
		return false
	reserve_charges -= 1
	run["reserve"] = reserve_charges
	_reserve_hud()
	events.append(["reserve_hit", reserve_charges])
	return true

func _reserve_hud() -> void:
	if reserve_lb == null or not is_instance_valid(reserve_lb):
		var cl := CanvasLayer.new()
		cl.layer = 12
		reserve_lb = Label.new()
		reserve_lb.position = Vector2(1060, 150)
		reserve_lb.add_theme_font_size_override("font_size", 22)
		reserve_lb.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cl.add_child(reserve_lb)
		game.add_child(cl)
	reserve_lb.text = "ЗАПАС 0.5: %d / 5" % reserve_charges
	reserve_lb.visible = reserve_charges > 0

## Подбор бутылки: герой идёт за укрытие у ближайшей стены (ходьбой 1,2 с), камера стоит снаружи и смотрит на угол, звук, он выходит с этой бутылкой в руке,
## крутит крышку (жёлтый стикер на бутылке); пропуск — удержание [E]; HUD «БУТЫЛКИ: n/5» после первой
var bottle_skip := 0.0
var bottle_lb: Label = null

func _bottle_wait(sec: float) -> void:
	var t := 0.0
	while t < sec and bottle_skip < 0.7:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		bottle_skip = bottle_skip + dt if Input.is_key_pressed(KEY_E) else 0.0

func _bottle_walk(p, to: Vector3, sec: float) -> void:
	var from: Vector3 = p.global_position
	var d := to - from
	d.y = 0.0
	if d.length() > 0.05:
		p.face = atan2(d.x, d.z)
	if p.rig != null:
		p.rig.play("Run", 0.1)
	var t := 0.0
	while t < sec and bottle_skip < 0.7:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		bottle_skip = bottle_skip + dt if Input.is_key_pressed(KEY_E) else 0.0
		p.global_position = from.lerp(to, clampf(t / sec, 0.0, 1.0))
	p.global_position = to
	if p.rig != null:
		p.rig.play("Idle", 0.2)

## Точки сцены подбора: укрытие — у ближайшей стены комнаты, камера — в 4,5 м от бутылки к центру комнаты
func bottle_scene_points(n: int) -> Dictionary:
	var pos: Vector3 = G67Podzemka.fit(G67Data.PZ_BOTTLES[n - 1]["pos"] as Vector3) + Vector3(0.6, 0.0, 0.0)
	var rid := G67Podzemka.room_at(pos + Vector3(0, 0.5, 0))
	var r: Array = G67Podzemka.ROOMS[rid] if rid != "" else [pos.x - 3, pos.x + 3, pos.z - 3, pos.z + 3]
	var cen := Vector3((float(r[0]) + float(r[1])) * 0.5, 0.0, (float(r[2]) + float(r[3])) * 0.5)
	var best := Vector3.ZERO
	var bd := 1e9
	for dv in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var dist: float = (float(r[1]) - pos.x) if dv.x > 0 else ((pos.x - float(r[0])) if dv.x < 0 else ((float(r[3]) - pos.z) if dv.z > 0 else (pos.z - float(r[2]))))
		if dist < bd:
			bd = dist
			best = dv
	var cover := pos + best * clampf(bd - 0.5, 0.8, 2.6)
	var to_c := cen - pos
	to_c.y = 0.0
	var cam := pos + (to_c.normalized() if to_c.length() > 0.1 else Vector3(0, 0, 1)) * 4.5
	cam.x = clampf(cam.x, float(r[0]) + 0.4, float(r[1]) - 0.4)
	cam.z = clampf(cam.z, float(r[2]) + 0.4, float(r[3]) - 0.4)
	cam.y = 1.7
	return {"pos": pos, "cover": cover, "cam": cam, "look": (pos + cover) * 0.5 + Vector3(0, 1.1, 0)}

## Модель бутылки по высоте h (м), низ на нуле
func _bottle_model(n: int, h: float) -> Node3D:
	var holder := Node3D.new()
	var src := "res://assets/golda67/podzemka/g67_pz_bottle_%d.glb" % n
	if ResourceLoader.exists(src):
		var m: Node3D = (load(src) as PackedScene).instantiate() as Node3D
		holder.add_child(m)
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		if not first and bb.size.y > 0.001:
			var k := h / bb.size.y
			m.scale = Vector3(k, k, k)
			m.position = Vector3(-bb.get_center().x * k, -bb.position.y * k, -bb.get_center().z * k)
	else:
		var bm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = h * 0.15
		cm.bottom_radius = h * 0.2
		cm.height = h
		bm.mesh = cm
		bm.position = Vector3(0, h * 0.5, 0)
		holder.add_child(bm)
	return holder

func _bottle_hud() -> void:
	var got: int = (run.get("bottles", []) as Array).size()
	if bottle_lb == null or not is_instance_valid(bottle_lb):
		var cl := CanvasLayer.new()
		cl.layer = 12
		bottle_lb = Label.new()
		bottle_lb.position = Vector2(1060, 120)
		bottle_lb.add_theme_font_size_override("font_size", 22)
		bottle_lb.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
		cl.add_child(bottle_lb)
		game.add_child(cl)
	bottle_lb.text = "БУТЫЛКИ: %d/5" % got
	bottle_lb.visible = got > 0 and not has_art("reserve_05")

func _bottle_pick(n: int) -> void:
	if bottle_busy or run.is_empty():
		return
	var got: Array = run.get("bottles", [])
	if got.has(n):
		return
	bottle_busy = true
	bottle_skip = 0.0
	var pzb := world.district as G67Podzemka
	var node = pzb.get_node_or_null("bottle_%d" % n) if pzb != null else null
	var sc := bottle_scene_points(n)
	var p = game.player
	var frozen: bool = p.is_physics_processing()
	p.set_physics_process(false)
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 55.0
	world.add_child(cam)
	cam.global_position = sc["cam"]
	cam.look_at(sc["look"], Vector3.UP)
	cam.make_current()
	events.append(["bottle_scene", n, "walk"])
	await _bottle_walk(p, sc["cover"], 1.2)
	p.visible = false
	game.main.sfx("sfx_glass", -6.0, 0.7)
	game.toast("…")
	events.append(["bottle_scene", n, "hidden"])
	await _bottle_wait(1.0)
	if node != null:
		node.visible = false
	p.visible = true
	var hand := _bottle_model(n, 0.28)
	var st := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.06)
	st.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.88, 0.1)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.85, 0.0)
	sm.emission_energy_multiplier = 0.8
	st.material_override = sm
	st.position = Vector3(0.0, 0.12, 0.05)
	hand.add_child(st)
	p.add_child(hand)
	hand.position = Vector3(0.28, 0.95, 0.3)
	events.append(["bottle_scene", n, "out"])
	await _bottle_walk(p, sc["pos"], 1.0)
	var tw := hand.create_tween()
	tw.tween_property(hand, "rotation:y", TAU * 2.0, 0.8)
	await _bottle_wait(0.9)
	hand.queue_free()
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "bottle%d" % n)
	got.append(n)
	run["bottles"] = got
	game.toast("БУТЫЛКИ: %d/5 — %s" % [got.size(), String(G67Data.PZ_BOTTLES[n - 1]["line"])])
	events.append(["bottle", n])
	if got.size() >= 5 and pzb != null:
		pzb.open_door("tech")
		game.toast("Техпомещение открыто")
	prev.make_current() if prev != null and is_instance_valid(prev) else game.cam.make_current()
	cam.queue_free()
	p.set_physics_process(frozen)
	p.visible = true
	_bottle_hud()
	bottle_busy = false

## Финал: пять бутылок стоят в ряд на столе техпомещения, пауза 2 с, реплика, упаковка-артефакт появляется со светом сверху и медленным наездом камеры
var final_busy := false

func _reserve_final() -> void:
	if final_busy or run.is_empty() or (run.get("bottles", []) as Array).size() < 5 or has_art("reserve_05"):
		game.toast("Нужно собрать пять бутылок")
		return
	final_busy = true
	var p = game.player
	var frozen: bool = p.is_physics_processing()
	p.set_physics_process(false)
	p.visible = false
	var root := Node3D.new()
	world.add_child(root)
	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.8, 0.08, 0.8)
	table.mesh = tm
	var tmt := StandardMaterial3D.new()
	tmt.albedo_color = Color(0.4, 0.28, 0.17)
	table.material_override = tmt
	root.add_child(table)
	table.position = Vector3(34.0, 0.85, -160.0)
	for i in 5:
		var bn := _bottle_model(i + 1, 0.3)
		root.add_child(bn)
		bn.position = Vector3(33.2 + float(i) * 0.4, 0.89, -160.0)
		var stk := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.07, 0.05)
		stk.mesh = qm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(1.0, 0.88, 0.1)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stk.material_override = sm
		bn.add_child(stk)
		stk.position = Vector3(0.0, 0.14, 0.05)
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 2.5
	lamp.spot_range = 5.0
	lamp.spot_angle = 35.0
	root.add_child(lamp)
	lamp.position = Vector3(34.0, 3.2, -160.0)
	lamp.rotation_degrees = Vector3(-90, 0, 0)
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = Vector3(34.0, 1.7, -157.0)
	cam.look_at(Vector3(34.0, 1.0, -160.0), Vector3.UP)
	cam.make_current()
	events.append(["reserve_scene", "row"])
	var ctw := cam.create_tween()
	ctw.tween_property(cam, "global_position", Vector3(34.0, 1.35, -158.6), 5.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(2.0).timeout
	game.banner("БЛЯТЬ.", "Я ДЕЙСТВИТЕЛЬНО СОБРАЛ ВСЕ ПЯТЬ", Color(1, 0.9, 0.5), 3.0)
	await get_tree().create_timer(1.2).timeout
	var pack := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.5, 0.3, 0.3)
	pack.mesh = pm
	var pmt := StandardMaterial3D.new()
	pmt.albedo_color = Color(0.62, 0.66, 0.7)
	pmt.metallic = 0.1
	pmt.roughness = 0.5
	pack.material_override = pmt
	root.add_child(pack)
	pack.position = Vector3(34.0, 1.35, -160.0)
	var ptw := pack.create_tween()
	ptw.tween_property(pack, "position:y", 1.7, 1.2)
	ptw.parallel().tween_property(pack, "rotation:y", TAU, 2.4)
	events.append(["reserve_scene", "pack"])
	await get_tree().create_timer(2.4).timeout
	take_art("reserve_05")
	reserve_charges = 5
	run["reserve"] = 5
	_reserve_hud()
	_bottle_hud()
	var arch: Array = meta().get("archive", [])
	if not arch.has("reserve05"):
		arch.append("reserve05")
	meta()["archive"] = arch
	save()
	events.append(["reserve_found"])
	if prev != null and is_instance_valid(prev):
		prev.make_current()
	else:
		game.cam.make_current()
	root.queue_free()
	p.visible = true
	p.set_physics_process(frozen)
	final_busy = false
var hamster_greeted := false

## Мини-игра хомяков: оверлей на время игры; награда — ХОМЯЧЬЯ АУРА (первый раз) или голда забега по очкам (не больше 30)
func _hamster_play() -> void:
	if hamster_busy:
		return
	hamster_busy = true
	var layer := CanvasLayer.new()
	layer.layer = 30
	var hg := G67HamsterGame.new()
	layer.add_child(hg)
	game.add_child(layer)
	var pzh := world.district as G67Podzemka
	var wall = pzh.get_node_or_null("hamster_wall") if pzh != null else null
	if wall != null:
		hg.setup_3d(wall as Node3D, world)
	var frozen: bool = game.player.is_physics_processing()
	game.player.set_physics_process(false)
	var res: Dictionary = await hg.finished
	game.player.set_physics_process(frozen)
	hg.cleanup()
	if bool(res.get("closed", false)) or not res.has("score"):
		var again: Dictionary = {"score": hg.score, "skipped": hg.done and hg.t_left > 0.0}
		res = again
	layer.queue_free()
	hamster_busy = false
	var m := meta()
	if not bool(m.get("hamster_done", false)):
		m["hamster_done"] = true
		var arch: Array = m.get("archive", [])
		if not arch.has("hamsters"):
			arch.append("hamsters")
		m["archive"] = arch
		if not run.is_empty():
			take_art("hamster_aura", (run["arts"] as Array)[0] if (run["arts"] as Array).size() >= slots() else "")
		game.toast("ХОМЯЧЬЯ АУРА: +2 голды за каждого врага")
	elif not run.is_empty():
		var g := mini(30, int(res["score"]) / 10)
		run["golda"] = int(run["golda"]) + g
		run["earned"] = int(run.get("earned", 0)) + g
		game.toast("Хомяки заплатили: +%d голды" % g)
	save()
	events.append(["hamster_game", int(res["score"])])
var pz_dieg := ""
var casino_mix := 0.0

## Позиционная музыка секретных комнат через MusicDirector: хомяки (слышно с 12 м, у закрытой двери глухо), казино (до 25 м, два слоя по числу спинов)
func _pz_music_tick(dt: float) -> void:
	var pzm := world.district as G67Podzemka if world != null else null
	if pzm == null or pzm.music_casino == null:
		return
	var dir = game.main.audio.director
	var hp: Vector3 = game.player.global_position
	if not hamster_greeted and G67Podzemka.room_at(hp) == "hamster":
		hamster_greeted = true
		game.toast("Бля, я реально сюда за хомяками пришёл")
		events.append(["hamster_enter"])
	var dh := hp.distance_to(pzm.music_hamster.global_position)
	var dc := hp.distance_to(pzm.music_casino.global_position)
	var want := ""
	if dh < 12.0:
		want = "hamster"
	elif dc < 25.0:
		want = "casino"
	var fresh := false
	if want != pz_dieg:
		pz_dieg = want
		fresh = true
		if want == "hamster":
			var closed: bool = not bool(pzm.door_open_flags.get("hamster", false))
			dir.set_diegetic(load("res://assets/music/ev_g67_hamster.ogg"), pzm.music_hamster, -14.0 if closed else -3.0, 14.0)
		elif want == "casino":
			dir.set_diegetic(load("res://assets/music/ev_g67_casino_a.ogg"), pzm.music_casino, -4.0, 26.0)
		else:
			dir.stop_diegetic()
	if want == "hamster":
		dir._dieg_db = -14.0 if not bool(pzm.door_open_flags.get("hamster", false)) else -3.0
	if want == "casino":
		_casino_music(dir, pzm, dt, fresh)
	else:
		pzm.lamp_rate = 3.0

const CASINO_BAR := 3.404            # такт референса, с (кроссфейд 60–64 стартует по его границе)
var casino_cf_on := false
var casino_perc := 0.0
var casino_duck_t := 0.0

## Состояния музыки казино по счётчику спинов: 1–49 обычная; 50–59 + перкуссия и лампы живее; 60–64 кроссфейд 4 с на драйвовую по границе такта; 65–67 драйвовая; после 67-го возврат за 6 с
func _casino_music(dir, pzm: G67Podzemka, dt: float, fresh: bool) -> void:
	var n := int(meta().get("casino_spins", 0))
	if fresh:
		casino_mix = 1.0 if (n >= 60 and n <= 67) else 0.0
		casino_perc = 1.0 if (n >= 50 and n <= 59) else 0.0
		casino_cf_on = casino_mix >= 1.0
	if n >= 60 and n <= 67:
		if not casino_cf_on and fmod(dir.dieg.get_playback_position(), CASINO_BAR) < 0.12:
			casino_cf_on = true
		if casino_cf_on:
			casino_mix = move_toward(casino_mix, 1.0, dt / 4.0)
	elif n >= 68:
		casino_cf_on = false
		casino_mix = move_toward(casino_mix, 0.0, dt / 6.0)
	else:
		casino_mix = move_toward(casino_mix, 0.0, dt / 2.0)
	casino_perc = move_toward(casino_perc, 1.0 if (n >= 50 and n <= 59) else 0.0, dt / 1.5)
	pzm.lamp_rate = 7.5 if (n >= 50 and n <= 67) else 3.0
	casino_duck_t = maxf(0.0, casino_duck_t - dt)
	dir._dieg_db = -4.0 - (40.0 if casino_duck_t > 0.0 else 0.0)
	dir.set_diegetic2(load("res://assets/music/ev_g67_casino_b.ogg"), casino_mix)
	dir.set_diegetic3(load("res://assets/music/ev_g67_casino_perc.ogg"), casino_perc)

## Акцент 66-го спина: удар и пауза (музыка казино на 0,9 с глохнет)
func _casino_accent(pz: G67Podzemka) -> void:
	var pl := AudioStreamPlayer3D.new()
	pl.stream = load("res://assets/music/ev_g67_casino_accent.ogg")
	pl.bus = "MusicDiegetic"
	pl.unit_size = 5.0
	pz.music_casino.add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)
	casino_duck_t = 0.9
	events.append(["casino_accent"])

## Музыка района глохнет: в комнате казино и в 5 м от открытой рольставни; в комнате хомяков и в 6 м от открытой двери (пока звучит трек)
func pz_duck_district() -> bool:
	var pzm := world.district as G67Podzemka if world != null else null
	if pzm == null or pzm.music_casino == null or game.player == null:
		return false
	var hp: Vector3 = game.player.global_position
	if G67Podzemka.room_at(hp) == "casino" and bool(pzm.door_open_flags.get("shutter", false)):
		return true
	if bool(pzm.door_open_flags.get("shutter", false)) and hp.distance_to(Vector3(-44.25, 0.0, -122.0)) < 5.0:
		return true
	if G67Podzemka.room_at(hp) == "hamster":
		return true
	return bool(pzm.door_open_flags.get("hamster", false)) and hp.distance_to(Vector3(44.0, 0.0, -146.0)) < 6.0

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
		G67Sound.play(self, "stash")

## Засада стартует сама, когда герой вошёл в прямоугольник её зоны (ужатый на 2 м)
func _ambush_tick() -> void:
	if room_state != "open" or busy or world == null:
		return
	var pp: Vector3 = game.player.global_position
	for i in world.gates.size():
		var g: Dictionary = world.gates[i]
		if not bool(g["auto"]):
			continue
		var z: Dictionary = G67District.zone_of(String((g["option"] as Dictionary).get("place", "")))
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
	call_deferred("_place_krot_pz")
	flush_coins()
	game.player.collision_mask |= 32          # слой 6: стенка проёма ограждения держит героя, враги проходят
	_kiosk_hint()
	busy = true
	room = r
	wind_used = false
	fin_room = 0.0
	var type := String(r["type"])
	var zid := String(r.get("place", "podezd"))
	var pz := G67District.is_podzemka()
	var zone := G67District.zone_of(("arena" if pz else "sport") if type == "boss" else zid)
	if type != "event":
		game.set_arena(zone["c"], zone["h"])
	world.clear_gates()
	if type != "storage":
		world.points = world.points.filter(func(pt): return String(pt["id"]) != "storage")      # открытый бокс прошлого этапа закрыт
	var p = game.player
	if type == "boss":
		world.bound_zone("arena" if pz else "sport", pz)
		world.drop_statist()
		p.global_position = G67District.pt("boss_entry")
		p.velocity = Vector3.ZERO
		p.face = PI
		game.cam_yaw = 0.0
		game.fx.prewarm(p.global_position)
	elif type in ["battle", "elite", "ambush"]:
		if pz and int(run["pos"]) == 0:
			busy = false          # первый бой района — когда герой спустился и вошёл в зону
			var zc: Vector3 = zone["c"]
			var zh: Vector2 = zone["h"]
			while absf(game.player.global_position.x - zc.x) > zh.x - 1.5 or absf(game.player.global_position.z - zc.z) > zh.y - 1.5:
				await game.get_tree().process_frame
			busy = true
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
		"kiosk":
			run["kiosk_full"] = true            # ларёк — твой этап: доступны все ценники, первая шаурма бесплатно
			run["free_shawarma"] = true
			room_state = "reward"
			open_screen("kiosk")
		"event":
			room_state = "reward"
			_save_run("open")
			await play_event(String(r.get("ev", "")))
		"boss":
			room_state = "boss"
			var bid := String(d["boss"])
			var b = game._make_enemy("", bid, G67District.pt("boss_spot") + Vector3(0, 0.05, 0))
			game.boss_e = b
			if pz and bid == "g67_fortuna":
				arena_setup(b)
				await fortuna_intro(b)
			var bd: Dictionary = game.story["BOSS"][bid]
			game.boss_name.text = "%s — %s" % [bd["n"], bd["sub"]]
			if not pz:
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
	# вход из точек зоны (не ближе 7 м к герою); нет подходящей — любое место зоны, как раньше
	var zid := String(room.get("place", "podezd"))
	var pts: Array = []
	for sp in G67District.zone_of(zid).get("spawns", []):
		pts.append(sp[0])
	if pts.is_empty():
		pts = G67District.entry_pts(zid)
	pts.shuffle()
	for q in pts:
		if (q as Vector3).distance_to(pp) >= 7.0:
			fallback = q
			break
	if fallback == Vector3.INF:
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
	e.set_meta("no_portal", true)
	e.set_meta("spawn_ms", GameClock.ms())
	game.add_child(e)
	G67Sound.play(self, "entry", pos)
	e.cfg["dmg"] = float(e.cfg["dmg"]) * G67Data.FOE_DMG_K
	if f.has("hp"):
		e.max_hp = float(f["hp"])
		e.hp = e.max_hp
	if f.has("dmg"):
		e.cfg["dmg"] = float(f["dmg"]) * G67Data.FOE_DMG_K
	if f.has("moves"):
		e.set_meta("moves", f["moves"])
	if f.has("bark"):
		var bl: Array = (f["bark"] as Array)[1]
		get_tree().create_timer(randf_range(1.0, 3.0)).timeout.connect(func():
			if is_instance_valid(e) and e.alive() and place == "run":
				barks_get().say(e, String((f["bark"] as Array)[0]) + "|" + String(bl[randi() % bl.size()]), {"dur": 3.0}))
	if bool(run.get("snow_stun", false)):
		if wave_i <= 0:
			game.get_tree().create_timer(1.3, false).timeout.connect(func(): if is_instance_valid(e): e.stun(2.0))
		else:
			run["snow_stun"] = false
	game.fx.dust(pos + Vector3(0, 0.15, 0), 6, game.fx.DUST, 0.8)
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
		var fresh: bool = GameClock.ms() - int(e.get_meta("spawn_ms", -100000)) < 7000
		if float(_out_t[id]) > (6.0 if fresh else 1.0):          # входящий из проёма — 6 с
			var c: Vector3 = game.arena_c
			var h: Vector2 = game.arena_h
			e.global_position = Vector3(c.x + clampf(e.global_position.x - c.x, -(h.x - 1.5), h.x - 1.5), e.global_position.y, c.z + clampf(e.global_position.z - c.z, -(h.y - 1.5), h.y - 1.5))
			e.velocity = Vector3.ZERO
			_out_t.erase(id)

# ---------------------------------------------------------------- фон и случайные звуки приквела
var phone: G67Phone = null

var barks: G67Barks = null

var duos: G67Duos = null

func duos_get() -> G67Duos:
	if world == null or world.yard == null:
		return null
	if duos == null or not is_instance_valid(duos) or duos.yard != world.yard:
		if duos != null and is_instance_valid(duos):
			duos.queue_free()
		duos = G67Duos.make(self, world.yard)
		add_child(duos)
	return duos

var ylife: G67YardLife = null

var read_idx := {}

## Предметы и листки двора: реплика, звук, карточка; Пахан изредка комментирует
var hub_t := {"strip": 60.0, "sil": 40.0, "tv": 4.0, "madk": 70.0}
var hub_log: Array = []
var hub_btn_force := -1

func _hub_life_tick(dt: float) -> void:
	if world == null or world.hub_strip == null or not is_instance_valid(world.hub_strip):
		return
	for k in hub_t:
		hub_t[k] = float(hub_t[k]) - dt
	var hp: Vector3 = game.player.global_position
	if float(hub_t["tv"]) <= 0.0:
		hub_t["tv"] = 3.2
		if Vector2(hp.x - 2.3, hp.z - (-6.0)).length() < 3.5:
			G67Sound.play(self, "tv_muffled", Vector3(2.3, 2.6, -6.0), 1.0)
	if float(hub_t["strip"]) <= 0.0:
		hub_t["strip"] = randf_range(90.0, 180.0)
		world.hub_strip.visible = true
		G67Sound.play(self, "door_slam", Vector3(2.3, 2.5, -6.0), 0.5)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(world.hub_strip):
				world.hub_strip.visible = false)
		hub_log.append("door_chain")
	if float(hub_t["sil"]) <= 0.0:
		hub_t["sil"] = randf_range(50.0, 100.0)
		world.hub_sil.visible = true
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(world.hub_sil):
				world.hub_sil.visible = false)
		hub_log.append("window_silhouette")

func _life_use(id: String) -> void:
	var bk: G67Barks = barks_get()
	var y = world.yard
	var hp: Vector3 = game.player.global_position
	var mk := Node3D.new()
	add_child(mk)
	get_tree().create_timer(12.0).timeout.connect(mk.queue_free)
	match id:
		"hub_btn":
			var hm := Node3D.new()
			add_child(hm)
			hm.global_position = Vector3(2.3, 2.6, -6.0)
			get_tree().create_timer(10.0).timeout.connect(hm.queue_free)
			var outcome: int = hub_btn_force if hub_btn_force >= 0 else randi() % 3
			get_tree().create_timer(2.0).timeout.connect(func():
				match outcome:
					0:
						hub_log.append("btn_flush")
						G67Sound.play(self, "flush", Vector3(0, 4.5, -3.0), 1.0)
					1:
						hub_log.append("btn_lamp")
						for lt in world.get_children():
							if lt is OmniLight3D:
								var e0: float = (lt as OmniLight3D).light_energy
								var tw := create_tween()
								tw.tween_property(lt, "light_energy", 0.0, 0.06)
								tw.tween_interval(0.5)
								tw.tween_property(lt, "light_energy", e0, 0.1)
								break
					2:
						hub_log.append("btn_voice")
						bk.say(hm, "Z2|Я же просил.", {"force": true, "dur": 3.0})
				get_tree().create_timer(1.5).timeout.connect(func(): bk.pahan_say("hub_btn", true)))
		"intercom":
			mk.global_position = Vector3(-1.3, 1.5, 35.0)
			var seq: Array = G67LifeData.INTERCOM[randi() % 4]
			G67Sound.play(self, "intercom_beep", mk.global_position, 1.0)
			for i in seq.size():
				get_tree().create_timer(0.8 + i * 2.2).timeout.connect(func(): bk.say(mk, String(seq[i]), {"force": true, "dur": 2.4}))
			get_tree().create_timer(1.0 + seq.size() * 2.2).timeout.connect(func(): bk.pahan_say("intercom", true))
		"g_radio":
			mk.global_position = Vector3(-42.4, 0.9, 4.8)
			G67Sound.play(self, "radio_jingle", mk.global_position, 1.0)
			var rd = y.life_props.get("g67_garage_radio")
			if rd != null and is_instance_valid(rd):
				var kn: Node3D = rd.find_child("knob", true, false)
				if kn != null:
					create_tween().tween_property(kn, "rotation:z", kn.rotation.z + 1.2, 0.5)
			get_tree().create_timer(1.2).timeout.connect(func(): bk.say(mk, bk.pick("radio", G67LifeData.RADIO), {"force": true, "dur": 6.0}))
			get_tree().create_timer(7.5).timeout.connect(func(): bk.pahan_say("radio", true))
		"carpet":
			var rk: Node3D = y.carpet_rack_node
			for i in 3:
				get_tree().create_timer(i * 0.55).timeout.connect(func():
					G67Sound.play(self, "carpet_beat", Vector3(-7.0, 1.0, 3.6), 1.0)
					if rk != null and is_instance_valid(rk):
						var tw := create_tween()
						tw.tween_property(rk, "rotation:z", 0.05, 0.1)
						tw.tween_property(rk, "rotation:z", 0.0, 0.2))
			get_tree().create_timer(0.3).timeout.connect(func(): ylife_get()._snow_puff(Vector3(-7.0, 1.2, 3.8)))
			get_tree().create_timer(1.9).timeout.connect(func(): bk.pahan_say("carpet", true))
		"box":
			var bx = y.life_props.get("g67_box_nothing")
			if bx != null and is_instance_valid(bx):
				var lid: Node3D = bx.find_child("lid", true, false)
				if lid != null:
					var twl := create_tween()
					twl.tween_property(lid, "rotation:x", deg_to_rad(-100.0), 0.6)
					twl.tween_interval(2.0)
					twl.tween_property(lid, "rotation:x", 0.0, 0.5)
			G67Sound.play(self, "crash", Vector3(-40.6, 0.4, -3.2), 0.5)
			get_tree().create_timer(1.2).timeout.connect(func(): bk.pahan_say("box", true))
		"puh":
			var ph = y.life_props.get("g67_puhosos")
			if ph != null and is_instance_valid(ph):
				var hs: Node3D = ph.find_child("hose", true, false)
				if hs != null:
					var twh := create_tween()
					for i in 5:
						twh.tween_property(hs, "rotation:z", 0.08 * (1.0 if i % 2 == 0 else -1.0), 0.3)
					twh.tween_property(hs, "rotation:z", 0.0, 0.3)
			G67Sound.play(self, "vacuum", Vector3(-39.0, 0.6, 8.0), 1.0)
			get_tree().create_timer(2.6).timeout.connect(func(): bk.pahan_say("puh", true))
		_:
			var gp: Dictionary = (y.sign_groups if y != null else {}).get(id.substr(5), world.hub_groups.get(id.substr(5), {}))
			if gp.is_empty():
				return
			var cards: Array = gp["cards"]
			var k := int(read_idx.get(id, -1)) + 1
			k = k % cards.size()
			read_idx[id] = k
			G67ReadCard.open(self, game.player, String(cards[k]["text"]), String(cards[k].get("sub", "")))
			if randf() < 0.3:
				bk.pahan_say("read")
	events.append(["life_use", id])

func ylife_get() -> G67YardLife:
	if world == null or world.yard == null:
		return null
	if ylife == null or not is_instance_valid(ylife) or ylife.yard != world.yard:
		if ylife != null and is_instance_valid(ylife):
			ylife.queue_free()
		ylife = G67YardLife.make(self, world.yard)
		add_child(ylife)
	return ylife

func barks_get() -> G67Barks:
	if barks == null or not is_instance_valid(barks):
		barks = G67Barks.make(self)
		add_child(barks)
	return barks

func phone_get() -> G67Phone:
	if phone == null:
		phone = G67Phone.new()
		add_child(phone)
	return phone

var amb67: AudioStreamPlayer = null
var amb67_kind := ""
var rnd67_t := 15.0

func _g67_audio_tick(dt: float) -> void:
	var want := "loop_hub" if place == "hub" else "loop_dvor"
	if amb67 == null:
		amb67 = AudioStreamPlayer.new()
		add_child(amb67)
	if amb67_kind != want:
		amb67_kind = want
		amb67.stream = G67Sound.stream(want)
		amb67.bus = "Ambient" if AudioServer.get_bus_index("Ambient") >= 0 else "Master"
		amb67.volume_db = float(G67Sound.KINDS[want][1])
		amb67.play()
	var quiet: bool = clip != null or game.mode == "dlg" or talk_on or scene_t >= 0.0
	rnd67_t -= dt
	if rnd67_t > 0.0:
		return
	rnd67_t = randf_range(12.0, 30.0) * (1.6 if room_state == "fight" else 1.0)
	if quiet:
		return
	if place == "hub":
		G67Sound.play(self, ["door", "steps_up", "doorbell"][randi() % 3])
	else:
		var pp: Vector3 = game.player.global_position
		var a := randf() * TAU
		G67Sound.play(self, ["alarm", "dog", "pigeon", "doorbell"][randi() % 4], pp + Vector3(cos(a) * 18.0, 1.5, sin(a) * 18.0))

func _fight_tick(dt: float) -> void:
	_keep_foes_inside(dt)
	if spawn_cd > 0.0:
		spawn_cd -= dt
	if not pending.is_empty():
		if alive() < G67Data.FOES_ALIVE_MAX and spawn_cd <= 0.0:
			_spawn(pending.pop_front())
			spawn_cd = randf_range(0.8, 1.4)          # враги входят по одному-двое, а не разом
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
	var sc := fit_lv("spare_change")
	if sc > 0 and int(run["kills"]) % [5, 4, 3][sc - 1] == 0:
		add_golda(4)
		events.append(["spare_change"])
	var base_g := int(G67Data.FOES[foe]["golda"])
	if foe == "smotr":
		for k in 3:
			_drop_coin(e.global_position, int(ceil(base_g / 3.0)), true)       # у Смотрящего падают три монеты
	else:
		_drop_coin(e.global_position, base_g)
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
	var pile := int(G67Data.ROOM_GOLDA[type])
	var pn := 5 if type == "elite" else 3
	for k in pn:
		_drop_coin(game.arena_c + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2)), int(ceil(float(pile) / pn)), true)      # награда за зачистку — горкой в центре зоны
	if G67Data.STAGE_HEAL.has(type):
		_drop_wrap(float(G67Data.STAGE_HEAL[type]), game.arena_c + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(2.0, 3.0)), 0.0)
	_add_respect("elite" if type == "elite" else "battle", int(G67Data.RESPECT["elite" if type == "elite" else "room"]))
	run["rooms"] = int(run["rooms"]) + 1
	game.banner("ЧИСТО", "голда: %d" % int(run["golda"]), Color(1, 0.85, 0.3), 1.8)
	game.fx.twinkle(game.player.global_position + Vector3(0, 1.0, 0), 14, Color(1, 0.85, 0.4), 1.0)
	if type == "elite":
		room_state = "reward"
		_place_elite_hanger()
	else:
		_stage_end()

# ---------------------------------------------------------------- монеты и награда элиты
var coins: Array = []             # [{n, v, vel, land, t}] — физическая голда, упавшая с врагов
var calm_t := 0.0
var elite_hanger: Node3D = null

func _drop_coin(pos: Vector3, val: int, big := false) -> void:
	if world == null:
		return
	var n := G67Models.spawn("g67_golda_coin", world, pos + Vector3(0, 0.9, 0), randf() * TAU, Vector3(99, 0.5 if big else 0.32, 99))
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.82, 0.35)
	lt.light_energy = 0.4
	lt.omni_range = 2.0
	n.add_child(lt)
	var a := randf() * TAU
	var sp := randf_range(1.2, 2.8)
	coins.append({"n": n, "v": val, "vel": Vector3(sin(a) * sp, randf_range(3.5, 5.0), cos(a) * sp), "land": false, "t": 0.0})

func _take_coin(c: Dictionary) -> void:
	if c.has("heal"):
		game.player.hp = minf(game.player.max_hp, game.player.hp + float(c["heal"]))
		game.popup(game.player.global_position + Vector3(0, 2.2, 0), "+%d здоровья" % int(c["heal"]), Color(0.5, 1.0, 0.55))
		var nh = c["n"]
		if is_instance_valid(nh):
			nh.queue_free()
		game.main.ui("confirm")
		events.append(["wrap_taken"])
		G67Sound.play(self, "shawarma")
		return
	var got := add_golda(int(c["v"]))
	var n = c["n"]
	if is_instance_valid(n):
		game.fx.twinkle(n.global_position, 6, Color(1, 0.85, 0.4), 0.5)
		n.queue_free()
	game.popup(game.player.global_position + Vector3(0, 2.2, 0), "+%d" % got, Color(1.0, 0.85, 0.3))
	G67Sound.play(self, "coin")
	game.main.ui("confirm")

## Монеты: дуга, отскок, лежат и крутятся; подбор на 1,6 м, а через 0,6 с после боя летят к герою
func _coins_tick(dt: float) -> void:
	calm_t = calm_t + dt if room_state != "fight" else 0.0
	var pp: Vector3 = game.player.global_position
	for c in coins.duplicate():
		var n = c["n"]
		if not is_instance_valid(n):
			coins.erase(c)
			continue
		c["t"] = float(c["t"]) + dt
		if c.has("life") and float(c["t"]) > float(c["life"]):
			n.queue_free()
			coins.erase(c)
			continue
		n.rotate_y(dt * 3.0)
		if not bool(c["land"]):
			var v: Vector3 = c["vel"]
			v.y -= 14.0 * dt
			n.global_position += v * dt
			if n.global_position.y <= 0.25 and v.y < 0.0:
				n.global_position.y = 0.25
				if absf(v.y) > 2.0:
					v = Vector3(v.x * 0.5, -v.y * 0.4, v.z * 0.5)
				else:
					c["land"] = true
			c["vel"] = v
		if c.has("decor"):
			continue
		var d: float = Vector2(pp.x - n.global_position.x, pp.z - n.global_position.z).length()
		if bool(c["land"]) and ((calm_t > 0.6 and not c.has("heal")) or (c.has("heal") and d < 2.5)):
			var to: Vector3 = pp + Vector3(0, 1.0, 0) - n.global_position
			n.global_position += to.normalized() * minf(to.length(), 14.0 * dt)
		if d < 1.6 and float(c["t"]) > 0.5:
			_take_coin(c)
			coins.erase(c)

## Непобранные монеты начисляются сразу (выход, домой, конец забега): ничего не теряется и ничего не удваивается
func flush_coins() -> void:
	for c in coins:
		if not c.has("heal"):
			add_golda(int(c["v"]))
		var n = c["n"]
		if is_instance_valid(n):
			n.queue_free()
	coins = []

func _place_elite_hanger() -> void:
	var pos: Vector3 = game.arena_c + Vector3(0, 0.0, 3.0)
	elite_hanger = G67Models.spawn("g67_fit_hanger", world, pos, PI, Vector3(99, 1.9, 99))
	var hb := StaticBody3D.new()
	hb.collision_layer = 1 | 8
	var hcs := CollisionShape3D.new()
	var hbx := BoxShape3D.new()
	hbx.size = Vector3(0.9, 1.9, 0.5)
	hcs.shape = hbx
	hb.add_child(hcs)
	hb.position = Vector3(0, 0.95, 0)
	elite_hanger.add_child(hb)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.8, 0.3)
	lt.light_energy = 1.2
	lt.omni_range = 5.0
	lt.position = Vector3(0, 2.0, 0)
	elite_hanger.add_child(lt)
	world._point("elite_fit", "ВЕШАЛКА ЭЛИТЫ", "редкий баф на выбор", pos + Vector3(0, 0, 1.3))
	game.banner("ВЕШАЛКА", "редкий баф — подойди и возьми", Color(1.0, 0.8, 0.3), 2.0)
	events.append(["elite_hanger"])

# ---------------------------------------------------------------- Миша: антракт, свита, шаурма с трибуны
var retinue: Array = []

func misha_retinue(phase: int) -> void:
	retinue = []
	if world.yard != null:
		world.yard.court_k(0.4)               # антракт: свет на Мишу, по краям темнее
	var foes: Array = ["shest", "shest", "shest"] + (["semka"] if phase >= 2 else [])
	for f in foes:
		var before: int = game.enemies.size()
		_spawn(String(f))
		if game.enemies.size() > before:
			retinue.append(game.enemies[game.enemies.size() - 1])
	for k in 2:
		_drop_wrap()
	game.main.sfx("sfx_wave", -6.0)
	events.append(["retinue", phase, retinue.size()])

func retinue_dead() -> bool:
	for e in retinue:
		if is_instance_valid(e) and e.state != "dead":
			return false
	return true

## Время вышло: оставшиеся убегают за борт и исчезают у калитки
func misha_retinue_clear() -> void:
	if world.yard != null:
		world.yard.court_k(0.8)
	for e in retinue:
		if is_instance_valid(e) and e.state != "dead":
			game.enemies.erase(e)
			e.queue_free()
	retinue = []

## Зрители бросают на лёд шаурму: свёрток по дуге с трибуны, лежит 20 с, подобрать — +25 здоровья
func _drop_wrap(heal := 25.0, at := Vector3.INF, life := 20.0) -> void:
	var c: Vector3 = game.arena_c
	var from := Vector3(c.x + randf_range(-8.0, 8.0), 4.0, c.z - 9.5) if at == Vector3.INF else at + Vector3(0, 1.4, 0)
	var n := MeshInstance3D.new()
	var wl := OmniLight3D.new()
	wl.light_color = Color(1.0, 0.85, 0.4)
	wl.light_energy = 1.2
	wl.omni_range = 3.5
	wl.position = Vector3(0, 0.5, 0)
	n.add_child(wl)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.18, 0.42)
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.7, 0.4)
	n.material_override = m
	world.add_child(n)
	n.global_position = from
	var tgt := Vector3(c.x + randf_range(-5.0, 5.0), 0.2, c.z + randf_range(-4.0, 4.0)) if at == Vector3.INF else at + Vector3(randf_range(-0.4, 0.4), -1.2, 0.5)
	var ent := {"n": n, "v": 0, "heal": heal, "vel": (tgt - from) / 0.9 + Vector3(0, 4.4, 0), "land": false, "t": 0.0}
	if life > 0.0:
		ent["life"] = life                 # у шаурмы зрителей срок 20 с; свёрток за зачистку лежит, пока не начат следующий этап
	coins.append(ent)

## Шесть позиций района: типы вариантов без конкретики (для карты, паузы, итогов); сами варианты — route_options
func route() -> Array:
	return G67Data.POSITIONS

func must_seen() -> bool:
	return bool((meta().get("must", {}) as Dictionary).get("ev_rags", false))

## Типы вариантов позиции p по правилам генератора: battle, elite, fit, storage, kiosk, break, boss, event (короткое), rags
func _tokens_at(p: int, rags_taken: bool) -> Array:
	if String(run.get("district", "dvor")) == "podzemka":
		match p:
			0: return ["battle"]
			1: return ["battle", "fit"]
			2: return ["elite", "storage", "battle"]
			3: return ["kiosk", "battle"]
			4: return ["break"]
		return ["boss"]
	var unseen := not must_seen()
	match p:
		0: return ["battle"]
		1: return ["battle", "fit"] + ([] if unseen else ["event"])
		2: return ["elite", "storage"] + (["rags"] if unseen else [])
		3:
			if unseen and not rags_taken:
				return ["rags"]
			return ["kiosk", "event", "battle"]
		4: return ["break"]
	return ["boss"]

## Можно ли из этого состояния дойти до конца четвёртой позиции: боёв 2–3 (с первой), выбор бафа, обязательное
func _feasible(p: int, battles: int, fit: bool, rags_taken: bool) -> bool:
	if p >= 4:
		return battles >= 2 and battles <= 3 and fit
	for t in _tokens_at(p, rags_taken):
		var nb: int = battles + (1 if t in ["battle", "elite"] else 0)
		if nb > 3:
			continue
		if _feasible(p + 1, nb, fit or t in ["fit", "elite"], rags_taken or t == "rags"):
			return true
	return false

## Варианты следующего этапа: зависят от пройденного в этом забеге (run.stages) и от meta (обязательное «ТРЯПКИ»)
func route_options(next: int) -> Array:
	var stages: Array = run.get("stages", [])
	var battles := 0
	var fit := false
	var rags_taken := false
	var used_ev: Array = []
	for s in stages:
		var t := String(s[0])
		if t in ["battle", "elite"]:
			battles += 1
		if t in ["fit", "elite"]:
			fit = true
		if t == "event" and (s as Array).size() > 2:
			used_ev.append(String(s[2]))
			if String(s[2]) == "rags":
				rags_taken = true
	var tokens := _tokens_at(next, rags_taken)
	if next < 4:
		var ok_t: Array = []
		for t in tokens:
			var nb: int = battles + (1 if t in ["battle", "elite"] else 0)
			if nb <= 3 and _feasible(next + 1, nb, fit or t in ["fit", "elite"], rags_taken or t == "rags"):
				ok_t.append(t)
		tokens = ok_t if not ok_t.is_empty() else ["battle"]
	var tpl := int(run.get("tpl", 0))
	var runs := int(meta().get("runs", 0))
	var out: Array = []
	if String(run.get("district", "dvor")) == "podzemka":
		for t in tokens:
			out.append(G67Data.pz_option(String(t), next, tpl))
		return out
	for t in tokens:
		match String(t):
			"battle":
				out.append({"type": "battle", "place": G67Data.BATTLE_PLACES[(tpl + next) % 3]})
			"elite":
				out.append({"type": "elite", "place": G67Data.BATTLE_PLACES[(tpl + next + 1) % 3]})
			"fit":
				out.append({"type": "fit", "place": "playground"})
			"storage":
				out.append({"type": "storage", "place": "garages"})
			"kiosk":
				out.append({"type": "kiosk", "place": "parking"})
			"break":
				out.append({"type": "break", "place": "gazebo"})
			"boss":
				out.append({"type": "boss", "place": "sport"})
			"rags":
				out.append({"type": "event", "ev": "rags", "place": "evspot"})
			"event":
				var ev: String = G67Data.EVENTS_SHORT[(runs + next) % 2]
				if used_ev.has(ev):
					ev = G67Data.EVENTS_SHORT[(runs + next + 1) % 2]
				if not used_ev.has(ev):
					out.append({"type": "event", "ev": ev, "place": "evspot"})
	if out.is_empty():
		out.append({"type": "battle", "place": G67Data.BATTLE_PLACES[(tpl + next) % 3]})
	return out

## Этап пройден: награда уже выдана; мирные этапы дают РЕСПЕКТ здесь. Дальше — варианты следующего этапа.
## Событие этапа: постановка «ТРЯПКИ» — следующая передача; короткие события — части 4. Пока без постановки этап
## просто засчитывается (для «ТРЯПОК» отметка «увидено» не ставится).
func play_event(ev: String) -> void:
	events.append(["event", ev])
	if ev == "rags":
		await _play_rags()
		return
	if ev in G67Data.EVENTS_SHORT:
		run["ev_pulls"] = 0
		var sp: Vector3 = G67District.event_spots()[ev]
		world._point("ev_" + ev, String(G67Data.EVENT_NAMES[ev]), "дёрнуть рычаг" if ev == "burmalda" else "нажать кнопку", sp + (Vector3(0, 0, 1.4) if ev == "burmalda" else Vector3(0, 0, 1.0)))
		return                          # этап закроется, когда событие отыграно
	_stage_end()

var ev_idle := 0.0

func _ev_tick() -> void:
	if room_state == "reward" and String(room.get("type", "")) == "event" and String(room.get("ev", "")) == "burmalda" and int(run.get("ev_pulls", 0)) >= 1 and not ev_busy:
		var sp: Vector3 = G67District.event_spots()["burmalda"]
		ev_idle += get_physics_process_delta_time()
		if Vector2(game.player.global_position.x - sp.x, game.player.global_position.z - sp.z).length() > 3.0 or ev_idle > 6.0:
			game.toast("Автомат замолчал")
			_ev_finish()

## «ТРЯПКИ! ТРЯПКИ!»: ролик EV02 (досмотрел или пропустил — событие считается увиденным), РЕСПЕКТ мирного этапа, герой у двери бокса
func _play_rags() -> void:
	var door: Vector3 = G67District.event_spots()["rags"]
	game.player.global_position = door + Vector3(0, 0.05, 1.8)
	game.player.velocity = Vector3.ZERO
	await play_clip("EV02")
	if not is_instance_valid(game) or game.golda != self:
		return
	var m: Dictionary = meta().get("must", {})
	m["ev_rags"] = true
	meta()["must"] = m
	var seen: Array = meta().get("seen", [])
	if not seen.has("ev_rags"):
		seen.append("ev_rags")
		meta()["seen"] = seen
	var arch: Array = meta().get("archive", [])
	if not arch.has("ev_rags"):
		arch.append("ev_rags")
		meta()["archive"] = arch
	save()
	game.player.global_position = door + Vector3(0, 0.05, 1.8)
	game.player.face = 0.0
	game.cam_yaw = PI
	_stage_end()

func _ev_finish() -> void:
	if room_state != "reward" or String(room.get("type", "")) != "event":
		return
	var ev := String(room.get("ev", ""))
	world.points = world.points.filter(func(pt): return String(pt["id"]) != "ev_" + ev)
	var arch: Array = meta().get("archive", [])
	if not arch.has("ev_" + ev):
		arch.append("ev_" + ev)
		meta()["archive"] = arch
		save()
	_stage_end()

var ev_busy := false

func _ev_tray_pos() -> Vector3:
	return (G67District.event_spots()["burmalda"] as Vector3) + Vector3(0, 0.3, 0.9)

## Рывок рычага: один бесплатно, ещё два по BURMALDA_COST
# ---- мини-сцены событий: камера ведёт Golda67, ввод закрыт (scene_busy), пропуск удержанием, страховка 12 с
var ev_cam := false
var ev_pos := Vector3.ZERO
var ev_look := Vector3.ZERO
var ev_fov := 50.0
var ev_skip := false
var ev_hold := 0.0
var ev_t0 := 0
var ev_last_junk := -1

func _ev_begin() -> void:
	ev_cam = true
	ev_skip = false
	ev_hold = 0.0
	ev_t0 = Time.get_ticks_msec()
	_talk_hud(true)
	game.player.velocity = Vector3.ZERO

func _ev_end() -> void:
	if not ev_cam:
		return
	ev_cam = false
	_talk_hud(false)
	game.cam.transform = Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	game.cam.fov = float(Opts.v("fov"))

func _ev_shot(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	ev_pos = pos
	ev_look = look
	ev_fov = fov

func _ev_wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not ev_skip and Time.get_ticks_msec() - ev_t0 < 12000:
		await get_tree().process_frame
		t += get_process_delta_time()

func _ev_say(line: String) -> void:
	var code := line.get_slice("|", 0)
	var text := line.substr(line.find("|") + 1)
	game._say(game.bark_b, line, 3.0)
	game.banner(text, G67Clips.speaker(code), Color(1.0, 0.9, 0.7), 2.4)
	events.append(["ev_say", line])

## Свободная точка камеры: из кандидатов — первая, от которой до цели нет геометрии (луч), и не ближе 1,3 м к герою
func _ev_free_cam(target: Vector3, cands: Array) -> Vector3:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var pp: Vector3 = game.player.global_position
	for c in cands:
		var q := PhysicsRayQueryParameters3D.create(c, target)
		q.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(q)
		var free: bool = hit.is_empty() or c.distance_to(hit["position"]) >= c.distance_to(target) - 0.35
		if free and Vector2(c.x - pp.x, c.z - pp.z).length() >= 1.3:
			return c
	return cands[cands.size() - 1]

func _ev_face(to: Vector3) -> void:
	var pp: Vector3 = game.player.global_position
	game.player.face = atan2(to.x - pp.x, to.z - pp.z)

func _ev_sparks(at: Vector3, col := Color(1.0, 0.85, 0.3), n := 40) -> void:
	var pr := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.0, 0)
	pr.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.emission_enabled = true
	mt.emission = col
	mt.emission_energy_multiplier = 3.0
	sm.material = mt
	pr.draw_pass_1 = sm
	pr.amount = n
	pr.lifetime = 0.8
	pr.one_shot = true
	pr.explosiveness = 0.9
	pr.position = at
	world.add_child(pr)
	pr.emitting = true
	get_tree().create_timer(1.5).timeout.connect(pr.queue_free)

## Рывок рычага: один бесплатно, ещё два по BURMALDA_COST; сцена: камера, реплика, барабан, выдача, реакция
func _burmalda_pull() -> void:
	if ev_busy or room_state != "reward" or String(room.get("ev", "")) != "burmalda":
		return
	var n := int(run.get("ev_pulls", 0))
	if n >= 3:
		return
	if n >= 1:
		if int(run.get("golda", 0)) < G67Data.BURMALDA_COST:
			game.toast("Нужно %d голды" % G67Data.BURMALDA_COST)
			return
		run["golda"] = int(run["golda"]) - G67Data.BURMALDA_COST
		run["spent"] = int(run.get("spent", 0)) + G67Data.BURMALDA_COST
	run["ev_pulls"] = n + 1
	ev_busy = true
	var total := 0
	for o in G67Data.BURMALDA:
		total += int(o["w"])
	var r := randi() % total
	var pick := "junk"
	for o in G67Data.BURMALDA:
		r -= int(o["w"])
		if r < 0:
			pick = String(o["id"])
			break
	await _burmalda_scene(pick, n == 0)
	ev_busy = false
	ev_idle = 0.0
	var left := 3 - int(run["ev_pulls"])
	for pt in world.points:
		if String(pt["id"]) == "ev_burmalda":
			pt["hint"] = ("ещё рывок — %d голды (осталось %d)" % [G67Data.BURMALDA_COST, left]) if left > 0 else "автомат пуст"
	if int(run["ev_pulls"]) >= 3:
		_ev_finish()

func _burmalda_scene(pick: String, first: bool) -> void:
	var L := G67Voice.EVENT_BURMALDA
	var sp: Vector3 = G67District.event_spots()["burmalda"]
	game.player.global_position = sp + Vector3(1.0, 0.05, 1.3)           # у рычага, сбоку от окна
	var pp: Vector3 = game.player.global_position
	_ev_begin()
	_ev_face(sp + Vector3(0.6, 0, 0))
	ev_arc = randf() < 0.5
	_ev_shot(sp + Vector3(1.8, 1.9, 5.0), sp + Vector3(-0.1, 1.2, 0.3), 54.0)           # автомат целиком, рычаг (справа) и герой
	await _ev_wait(0.6)
	_ev_shot(sp + Vector3(1.4, 1.7, 3.8), sp + Vector3(0.0, 1.2, 0.4), 48.0)
	if first or randf() < 0.35:
		_ev_say(L[0])
		await _ev_wait(1.8)
	var variant := randi() % 3
	var rare := pick in ["art", "rare_art", "fit"]
	world.ev_spin(2.6, pick, variant, rare)
	if game.player.rig.has_clip("Light1"):
		game.player.rig.play_for("Light1", 0.5, 0.05)
	G67Sound.play(self, "lever")
	for k in 7:
		get_tree().create_timer(0.3 + 0.33 * k, false).timeout.connect(func(): G67Sound.play(self, "drum", Vector3.INF, 0.8 + 0.07 * k))
	if variant == 2:
		_ev_sparks(sp + Vector3(0, 1.0, 0.5), Color(1.0, 0.6, 0.2), 15)       # «заело»
	await _ev_wait(2.9)
	_ev_shot(sp + Vector3(0.6, 1.6, 3.4), sp + Vector3(0.0, 0.6, 0.8), 48.0)
	_burmalda_outcome(pick)
	if rare:
		G67Sound.play(self, "respect")
		_ev_sparks(sp + Vector3(0, 2.1, 0.2), Color(1.0, 0.3, 0.85), 80)
		_ev_sparks(sp + Vector3(0, 2.1, 0.2), Color(0.4, 0.9, 1.0), 60)
	await _ev_wait(1.3)
	if pick == "junk":
		var j := randi_range(2, 3)
		if j == ev_last_junk:
			j = 5 - j
		ev_last_junk = j
		_ev_shot(sp + Vector3(-1.6, 1.6, 3.4), pp + Vector3(0, 1.2, 0), 44.0)
		_ev_say(L[j])
	else:
		_ev_say(L[1])
	await _ev_wait(1.7)
	_ev_end()

var ev_arc := false

func _junk_part(parent: Node3D, size: Vector3, pos: Vector3, col: Color, cyl := false) -> void:
	var mi := MeshInstance3D.new()
	if cyl:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x
		cm.bottom_radius = size.x
		cm.height = size.y
		mi.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

func _drop_junk(at: Vector3, idx := 0) -> void:
	var n := Node3D.new()
	match idx:
		0:
			_junk_part(n, Vector3(0.07, 0.07, 0.24), Vector3(0, 0.035, 0), Color(0.6, 0.6, 0.7))
			_junk_part(n, Vector3(0.1, 0.07, 0.08), Vector3(0.04, 0.035, 0.1), Color(0.6, 0.6, 0.7))
		1:
			_junk_part(n, Vector3(0.07, 0.01, 0.3), Vector3(0, 0.005, 0), Color(0.95, 0.93, 0.85))
		2:
			_junk_part(n, Vector3(0.14, 0.03, 0.14), Vector3(0, 0.015, 0), Color(0.55, 0.55, 0.58), true)
			_junk_part(n, Vector3(0.03, 0.04, 0.03), Vector3(0, 0.045, 0), Color(0.2, 0.2, 0.2), true)
		_:
			_junk_part(n, Vector3(0.06, 0.03, 0.2), Vector3(0, 0.015, 0), Color(0.1, 0.1, 0.12))
			_junk_part(n, Vector3(0.02, 0.01, 0.02), Vector3(0, 0.035, -0.05), Color(0.9, 0.2, 0.2))
	world.add_child(n)
	n.global_position = at + Vector3(0, 0.3, 0)
	coins.append({"n": n, "v": 0, "decor": true, "vel": Vector3(randf_range(-0.6, 0.6), 1.5, 1.8), "land": false, "t": 0.0, "life": 40.0})

func _arc_last(count: int) -> void:
	var pp: Vector3 = game.player.global_position
	for i in range(maxi(0, coins.size() - count), coins.size()):
		var n = coins[i]["n"]
		if is_instance_valid(n):
			var dv: Vector3 = pp - (n as Node3D).global_position
			dv.y = 0.0
			coins[i]["vel"] = dv.normalized() * 2.6 + Vector3(0, 4.2, 0)

func _burmalda_outcome(id: String) -> void:
	var c_before := coins.size()
	_burmalda_outcome_core(id)
	if ev_arc:
		_arc_last(coins.size() - c_before)

func _burmalda_outcome_core(id: String) -> void:
	var tray := _ev_tray_pos()
	events.append(["burmalda", id])
	G67Sound.play(self, "tray")
	match id:
		"junk":
			var names: Array = G67Data.BURMALDA[0]["names"]
			var nm_j: String = String(names[randi() % names.size()])
			game.banner(nm_j, "хлам: ничего полезного", Color(0.8, 0.8, 0.75), 2.2)
			_drop_junk(tray, names.find(nm_j))
		"gold":
			var o: Dictionary = G67Data.BURMALDA[1]
			var v := randi_range(int(o["min"]), int(o["max"]))
			for k in 3:
				_drop_coin(tray, int(ceil(v / 3.0)), true)
			game.banner("ГОЛДА", "%d из лотка" % v, Color(1, 0.85, 0.3), 2.2)
		"heal":
			_drop_wrap(30.0, tray)
			game.banner("ШАУРМА", "лечение +30 — подбери", Color(0.5, 1.0, 0.55), 2.2)
		"art", "rare_art":
			var pool: Array = storage_pool().filter(func(a): return (String(Golda67.art_info(a)["rar"]) == "редкий") == (id == "rare_art"))
			if pool.is_empty() or arts().size() >= slots():
				for k in 3:
					_drop_coin(tray, 12, true)
				game.banner("ГОЛДА", "артефакта нет — выпала голда", Color(1, 0.85, 0.3), 2.2)
			else:
				var aid := String(pool[randi() % pool.size()])
				take_art(aid)
				game.banner(String(Golda67.art_info(aid)["name"]), "артефакт из лотка", Color(0.6, 0.85, 1.0), 2.4)
		"fit":
			var fp := togo_pool()
			if fp.is_empty():
				_drop_coin(tray, 25, true)
			else:
				var fid := String(fp[randi() % fp.size()])
				var fits: Dictionary = run["fits"]
				fits[fid] = fit_lv(fid) + 1
				apply_fits(fid)
				game.banner(String(G67Data.FITS[fid]["name"]), "баф · ур. %d" % fit_lv(fid), G67Data.ROOM_COLOR["fit"], 2.4)

## Кнопка: колпак, пауза 1,2 с, исход (не тот же, что в прошлом забеге)
func _button_press() -> void:
	if ev_busy or room_state != "reward" or String(room.get("ev", "")) != "button":
		return
	ev_busy = true
	var last := String(meta().get("button_last", ""))
	var pool: Array = G67Data.BUTTON.filter(func(x): return x != last)
	var id := String(pool[randi() % pool.size()])
	meta()["button_last"] = id
	save()
	await _button_scene(id)
	ev_busy = false
	_ev_finish()

func _button_scene(id: String) -> void:
	var L := G67Voice.EVENT_BUTTON
	var sp: Vector3 = G67District.event_spots()["button"]
	var p = game.player
	p.global_position = sp + Vector3(-0.9, 0.05, 0.9)                           # левее кнопки: не перекрывает её
	var pp: Vector3 = p.global_position
	_ev_begin()
	_ev_face(sp + Vector3(0, 0, 0))
	var kt := sp + Vector3(0, 1.5, 0)
	_ev_shot(_ev_free_cam(kt, [sp + Vector3(1.6, 1.9, 2.8), sp + Vector3(0.0, 1.9, 3.0), sp + Vector3(2.4, 2.0, 1.0)]), kt, 52.0)
	await _ev_wait(0.4)
	_ev_shot(_ev_free_cam(kt, [sp + Vector3(1.2, 1.7, 2.0), sp + Vector3(0.4, 1.7, 2.1), sp + Vector3(1.9, 1.8, 1.2)]), kt, 40.0)       # наезд: коробка, надписи, табличка
	world.ev_lid(true)
	G67Sound.play(self, "door")
	await _ev_wait(0.8)
	if p.rig.has_clip("Light1"):
		p.rig.play_for("Light1", 0.4, 0.05)                                        # Пахан давит кнопку
	G67Sound.play(self, "click")
	var mb := AudioServer.get_bus_index("Music")
	if mb >= 0:
		var mv := AudioServer.get_bus_volume_db(mb)
		AudioServer.set_bus_volume_db(mb, mv - 12.0)                              # пауза: музыка тише, слышен ветер
		get_tree().create_timer(1.4).timeout.connect(func(): AudioServer.set_bus_volume_db(mb, mv))
	await _ev_wait(1.4)                                                          # комедийная пауза
	var hv: Vector3 = sp + Vector3(0.7, 0.0, 0.7)
	match id:
		"alarms":
			_button_outcome(id)
			_ev_shot(pp + Vector3(-3.0, 2.4, 3.2), sp + Vector3(0, 1.6, 0), 60.0)
			for lf in world.yard.lifes:
				if is_instance_valid(lf):
					(lf as G67Life).react("RWow")
			world.yard.crowd_react("phase")
			world.yard.siren_look(sp)
			var rl := OmniLight3D.new()
			rl.light_color = Color(1.0, 0.1, 0.08)
			rl.omni_range = 30.0
			rl.position = sp + Vector3(0, 6.0, 2.0)
			rl.light_energy = 0.0
			world.add_child(rl)
			var rt := rl.create_tween().set_loops(8)
			rt.tween_property(rl, "light_energy", 6.0, 0.2)
			rt.tween_property(rl, "light_energy", 0.0, 0.2)
			get_tree().create_timer(3.6).timeout.connect(rl.queue_free)
			_ev_say(L[0])
			await _ev_wait(1.8)
			_ev_say(L[1])
			await _ev_wait(1.6)
		"snow":
			_button_outcome(id)
			var pigs: Array = []
			var away := Vector3(pp.x - sp.x, 0, pp.z - sp.z).normalized()
			p.face = atan2(away.x, away.z)                                         # Пахан смотрит от столба, на открытый снег
			for i in 6:
				var a := -1.0 + 0.4 * float(i)
				var dirv := away.rotated(Vector3.UP, a)
				var tgt := pp + dirv * (1.7 + 0.15 * (i % 2))
				var pg := G67Models.spawn("g67_pigeon", world, tgt + dirv * 6.0, atan2(-dirv.x, -dirv.z), Vector3(0.35, 0.35, 0.35))
				pigs.append(pg)
				var tw: Tween = pg.create_tween()
				tw.tween_property(pg, "position", tgt, 1.4)
			_ev_shot(pp + away * 4.2 + Vector3(2.0, 2.4, 0), pp + away * 1.5 + Vector3(0, 0.3, 0), 55.0)
			await _ev_wait(1.6)
			var side := away.cross(Vector3.UP)
			var low := _ev_free_cam(pp + away * 1.0 + Vector3(0, 0.5, 0), [pp + away * 1.0 + side * 2.6 + Vector3(0, 0.45, 0), pp + away * 1.0 - side * 2.6 + Vector3(0, 0.45, 0)])
			_ev_shot(low, pp + away * 0.9 + Vector3(0, 0.55, 0), 52.0)             # низкий план: голуби снизу смотрят на Пахана, оба в кадре
			await _ev_wait(1.3)
			_ev_shot(_ev_free_cam(pp + Vector3(0, 1.4, 0), [pp + away * 3.3 + Vector3(0, 1.1, 0), pp + away * 3.3 + away.cross(Vector3.UP) * 1.5 + Vector3(0, 1.1, 0)]), pp + Vector3(0, 1.4, 0), 44.0)       # встречный средний на Пахана
			_ev_say(L[2])
			await _ev_wait(1.6)
			for pg in pigs:
				if is_instance_valid(pg):
					var tw2: Tween = pg.create_tween()
					tw2.tween_property(pg, "position", pg.position + Vector3(0, 6.0, 0), 1.0)
					tw2.tween_callback(pg.queue_free)
			await _ev_wait(0.8)
		"shawarma":
			_ev_shot(sp + Vector3(1.5, 2.0, 2.4), sp + Vector3(0, 2.8, 0), 48.0)
			G67Sound.play(self, "click")
			_ev_face(sp + Vector3(0, 2.4, 0))                                    # смотрит на рупор
			_ev_say(L[3])
			await _ev_wait(0.9)
			_ev_shot(pp + Vector3(0.6, 1.5, 1.4), pp + Vector3(0, 1.45, 0), 40.0)
			game.player.face = atan2(pp.x + 0.6 - pp.x, 1.4)                     # ... в камеру
			await _ev_wait(0.8)
			_ev_shot(sp + Vector3(1.5, 2.0, 2.4), sp + Vector3(0, 2.8, 0), 48.0)
			_ev_face(sp + Vector3(0, 2.4, 0))                                    # ... и снова на рупор
			await _ev_wait(0.7)
			_ev_say(L[4])
			await _ev_wait(1.6)
			G67Sound.play(self, "click")
			world.ev_hatch(true)
			_button_outcome(id)
			_ev_shot(pp + Vector3(1.5, 1.6, 1.8), hv, 50.0)
			await _ev_wait(1.2)
		"lights":
			_button_outcome(id)
			G67Sound.play(self, "jingle")
			_ev_shot(sp + Vector3(2.6, 2.4, 3.2), sp + Vector3(0, 2.2, 0), 58.0)
			var lb := Label3D.new()
			lb.text = "ПОЗДРАВЛЯЕМ!"
			lb.font_size = 72
			lb.pixel_size = 0.006
			lb.outline_size = 10
			lb.modulate = Color(1.0, 0.9, 0.3)
			lb.position = sp + Vector3(0, 3.2, 0.6)
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			world.add_child(lb)
			var cf: Array = []
			for col in [Color(1, 0.2, 0.3), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.2), Color(0.5, 1.0, 0.4)]:
				var cp := GPUParticles3D.new()
				var cm := ParticleProcessMaterial.new()
				cm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				cm.emission_box_extents = Vector3(2.0, 0.1, 2.0)
				cm.direction = Vector3(0, -1, 0)
				cm.spread = 20.0
				cm.initial_velocity_min = 0.6
				cm.initial_velocity_max = 1.6
				cm.gravity = Vector3(0, -1.2, 0)
				cp.process_material = cm
				var bm := BoxMesh.new()
				bm.size = Vector3(0.1, 0.01, 0.06)
				var mt := StandardMaterial3D.new()
				mt.albedo_color = col
				mt.emission_enabled = true
				mt.emission = col
				bm.material = mt
				cp.draw_pass_1 = bm
				cp.amount = 60
				cp.lifetime = 3.0
				cp.position = sp + Vector3(0, 4.5, 0)
				world.add_child(cp)
				cp.emitting = true
				cf.append(cp)
			await _ev_wait(3.6)
			lb.queue_free()
			for cp in cf:
				cp.emitting = false
				get_tree().create_timer(3.2).timeout.connect(cp.queue_free)
			await _ev_wait(1.2)                                                       # оборвалось на полутакте: тишина
		"nothing":
			var post: Node3D = world.ev_nodes["button"]["root"]
			var base := post.position
			var tw3 := post.create_tween()
			for k in 12:
				tw3.tween_property(post, "position", base + Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05)), 0.07)
			tw3.tween_property(post, "position", base, 0.05)
			G67Sound.play(self, "chain")
			G67Sound.play(self, "relay")
			_ev_sparks(sp + Vector3(0, 1.4, 0.3))
			await _ev_wait(1.2)
			world.ev_hatch(true)
			var paper := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.5, 0.01, 0.35)
			paper.mesh = pm
			var pmt := StandardMaterial3D.new()
			pmt.albedo_color = Color(0.95, 0.93, 0.85)
			paper.material_override = pmt
			paper.position = sp + Vector3(0.8, 0.6, 0.9)
			world.add_child(paper)
			var ptw := paper.create_tween()
			ptw.tween_property(paper, "position", sp + Vector3(2.0, 0.03, 0.3), 0.7)
			var pl := Label3D.new()
			pl.text = "Пошел нахуй"
			pl.font_size = 40
			pl.pixel_size = 0.0025
			pl.modulate = Color(0.1, 0.1, 0.12)
			pl.rotation.x = -PI * 0.5
			pl.position = sp + Vector3(0.8, 0.6, 0.9)
			world.add_child(pl)
			var ltw := pl.create_tween()
			ltw.tween_property(pl, "position", sp + Vector3(2.0, 0.045, 0.3), 0.7)
			G67Sound.play(self, "tray")
			_ev_shot(sp + Vector3(1.6, 1.9, 1.3), sp + Vector3(1.4, 0.0, 0.3), 42.0)
			_button_outcome(id)
			await _ev_wait(2.6)
			get_tree().create_timer(20.0).timeout.connect(func():
				if is_instance_valid(paper):
					paper.queue_free()
				if is_instance_valid(pl):
					pl.queue_free())
		"shock":
			_button_outcome(id)
			if p.rig.has_clip("Hit"):
				p.rig.play_for("Hit", 0.8, 0.05)
			_ev_sparks(sp + Vector3(0, 1.6, 0.2), Color(0.6, 0.8, 1.0), 60)
			_ev_sparks(sp + Vector3(0, 1.7, 0.2), Color(0.5, 0.5, 0.5), 25)
			_ev_shot(pp + Vector3(1.2, 1.6, 1.6), pp + Vector3(0, 1.2, 0), 46.0)
			await _ev_wait(2.4)
	world.ev_lid(false)
	world.ev_hatch(false)
	_ev_end()

func _button_outcome(id: String) -> void:
	var p = game.player
	events.append(["button", id])
	G67Sound.play(self, {"alarms": "alarm", "shock": "relay", "shawarma": "tray", "snow": "door", "lights": "relay"}.get(id, "click"))
	match id:
		"nothing":
			game.banner("НИЧЕГО", "кнопка щёлкнула", Color(0.8, 0.8, 0.8), 2.0)
		"lights":
			game.banner("ПОЗДРАВЛЯЕМ!", "+20 голды монетами", Color(1, 0.85, 0.3), 2.4)
			for k in 4:
				_drop_coin(p.global_position + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)), 5, true)
		"alarms":
			game.banner("СИГНАЛИЗАЦИИ", "машины на парковке орут", Color(1.0, 0.5, 0.3), 2.4)
			var par: Vector3 = (G67District.zone_of("parking")["c"] as Vector3)
			for k in 3:
				var lt := OmniLight3D.new()
				lt.light_color = Color(1.0, 0.6, 0.1) if k % 2 == 0 else Color(1.0, 0.15, 0.1)
				lt.omni_range = 6.0
				lt.position = par + Vector3(-6.0 + k * 6.0, 1.2, -3.0 + k * 3.0)
				world.add_child(lt)
				var tl := lt.create_tween().set_loops(8)
				tl.tween_property(lt, "light_energy", 3.0, 0.2)
				tl.tween_property(lt, "light_energy", 0.0, 0.2)
				get_tree().create_timer(4.0).timeout.connect(lt.queue_free)
			game.main.sfx("sfx_wave", -2.0)
			_add_respect("calm", 1)
		"shawarma":
			game.banner("ЛЮК", "из люка вылетела шаурма — подбери", Color(0.5, 1.0, 0.55), 2.4)
			_drop_wrap(40.0, p.global_position + Vector3(1.2, 0, 1.2))
		"shock":
			game.banner("ТОК", "здоровье −10, СВЭГ полный", Color(1.0, 0.9, 0.3), 2.4)
			p.hp = maxf(1.0, p.hp - 10.0)
			p.swag = 100.0
			game.shake(0.6)
		"snow":
			game.banner("ГОЛУБИ ЗАПОМНИЛИ", "первая волна следующего боя — оглушена", Color(0.8, 0.9, 1.0), 2.4)
			run["snow_stun"] = true

func event_seen(ev: String) -> void:
	var m: Dictionary = meta().get("must", {})
	m["ev_" + ev] = true
	meta()["must"] = m
	var arch: Array = meta().get("archive", [])
	if not arch.has("ev_" + ev):
		arch.append("ev_" + ev)
		meta()["archive"] = arch
	save()

func _stage_end() -> void:
	var type := String(room.get("type", ""))
	if type in ["fit", "storage", "break", "kiosk", "event"]:
		_add_respect("calm", int(G67Data.RESPECT["calm"]))
		run["rooms"] = int(run["rooms"]) + 1
	(run["stages"] as Array).append([type, String(room.get("place", "")), String(room.get("ev", ""))])
	events.append(["stage_done", type])
	_open_gates()

## Подсказка у окна ларька: пока оно закрыто (позиции 1–2), говорит правду
func _kiosk_gate() -> int:
	if world == null:
		return -1
	for i in world.gates.size():
		if String((world.gates[i]["option"] as Dictionary).get("type", "")) == "kiosk":
			return i
	return -1

func _kiosk_hint() -> void:
	if world == null or run.is_empty():
		return
	for pt in world.points:
		if String(pt["id"]) == "kiosk":
			if _kiosk_gate() >= 0:
				pt["hint"] = "ЛАРЁК · твой этап: всё меню, первая шаурма бесплатно"
				continue
			pt["hint"] = "окно закрыто — откроется после второй позиции" if (int(run.get("pos", 0)) < 1 and not bool(run.get("kiosk_full", false))) else "окно ларька: шаурма за голду"

func _open_gates() -> void:
	_kiosk_hint()
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
	_talk_hud(true)
	scene_from = Vector3(world.throne.x, b.global_position.y, world.throne.z + 0.2)
	b.global_position = scene_from
	b.face = 0.0
	b.body.rotation.y = 0.0
	b.rig.play("MSit", 0.0)
	if world.yard != null:
		world.yard.court_k(0.3)
		world.yard.flood_all(0.25)
	events.append(["boss_intro"])

func scene_busy() -> bool:
	return scene_t >= 0.0 or clip != null or hub_ui != null or ev_cam

func owns_camera() -> bool:
	return talk_on or ev_cam or (scene_t >= 0.0 and scene_boss != null and is_instance_valid(scene_boss))

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
	# камера возвращается на пружину: иначе поворот плана разговора остаётся на ней, и она смотрит в стену
	game.cam.transform = Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	game.cam.fov = float(Opts.v("fov"))

## Боевой HUD, верхняя строка и значки над точками на время разговора спрятаны
func _talk_hud(hide: bool) -> void:
	if hide:
		var nodes: Array = [game.combat_hud, game.hud_root, mark_talk, prompt, game.boss_box]
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
	if ev_cam:
		return Transform3D(Basis.looking_at(ev_look - ev_pos, Vector3.UP), ev_pos)
	if talk_on:
		return Transform3D(Basis.looking_at(talk_look - talk_pos, Vector3.UP), talk_pos)
	var home: Transform3D = game.spring.global_transform * Transform3D(Basis(), Vector3(0, 0, game.spring.get_hit_length()))
	var bp: Vector3 = scene_boss.global_position
	var pos: Vector3
	var look: Vector3
	if scene_t < SCENE_SIT:
		pos = Vector3(2.0, 2.8, -31.0)                                        # общий план от калитки: трон, трибуна, ковёр
		look = Vector3(2.0, 1.6, -47.0)
		scene_fov = 58.0
	elif scene_t < SCENE_WALK:
		pos = world.throne + Vector3(2.8, 1.5, 3.4)
		look = bp + Vector3(0, 1.3, 0)
		scene_fov = 46.0
	else:
		pos = bp + Vector3(3.2, 1.5, 1.9)                                      # сбоку-спереди, ведёт его по ковру
		look = bp + Vector3(0, 1.3, 0)
		scene_fov = 48.0
	var shot := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	var w := 1.0
	if scene_t > SCENE_LEN - 1.4:
		w = clampf((SCENE_LEN - scene_t) / 1.4, 0.0, 1.0)
		scene_fov = lerpf(float(Opts.v("fov")), scene_fov, w)
	w = w * w * (3.0 - 2.0 * w)
	return Transform3D(Basis(home.basis.get_rotation_quaternion().slerp(shot.basis.get_rotation_quaternion(), w)), home.origin.lerp(shot.origin, w))

func _scene_pos(t: float) -> Vector3:
	var f := 0.0
	if t >= SCENE_STOP:
		f = 1.0
	elif t >= SCENE_FREE:
		f = lerpf(0.55, 1.0, (t - SCENE_FREE) / (SCENE_STOP - SCENE_FREE))
	elif t >= SCENE_CATCH:
		f = 0.55
	elif t >= SCENE_WALK:
		f = 0.55 * (t - SCENE_WALK) / (SCENE_CATCH - SCENE_WALK)
	return scene_from.lerp(scene_to, f)

func _scene_tick(dt: float) -> void:
	scene_t += dt
	if scene_boss == null or not is_instance_valid(scene_boss):
		_scene_end()
		return
	var b = scene_boss
	var yard = world.yard
	if scene_step == 0 and scene_t >= SCENE_SIT:
		scene_step = 1
		b.rig.play("Idle", 0.5)                    # встаёт с трона
		_crowd("rise")
	if scene_step == 1 and scene_t >= SCENE_WALK:
		scene_step = 2
		b.rig.play("Run", 0.25, 0.5)               # идёт не спеша
	if scene_step >= 2 and scene_step < 5:
		b.global_position = _scene_pos(scene_t)
	if scene_step == 2 and scene_t >= SCENE_CATCH:
		scene_step = 3
		b.rig.play("CStuck" if b.rig.has_clip("CStuck") else "Idle", 0.15)
		var hp: Vector3 = world.hook_points[0] if not world.hook_points.is_empty() else b.global_position + Vector3(2, 0, 0)
		G67Misha._chain(game, b.global_position + Vector3(0, 1.3, 0), hp + Vector3(0, 1.3, 0), SCENE_FREE - SCENE_CATCH)
		game.shake(0.25)
		G67Sound.play(self, "chain")
	if scene_step == 3 and scene_t >= SCENE_FREE - 0.5:
		scene_step = 4
		b.rig.play_for("CYank" if b.rig.has_clip("CYank") else "Idle", 0.9, 0.05)       # рывок — цепь свободна
		_crowd("laugh")
		var bd0: Dictionary = game.story["BOSS"][String(b.boss_id)]
		game.boss_bark(String(bd0["n"]), G67Clips.L("V00", 1).get_slice("|", 1), Color(bd0["c"]), String(bd0["sp"]))        # «Так и задумано.»
	if scene_step == 4 and scene_t >= SCENE_FREE:
		scene_step = 5
		b.rig.play("Run", 0.25, 0.5)
	if scene_step == 5 and scene_t >= SCENE_STOP:
		scene_step = 6
		b.global_position = scene_to
		b.rig.play_for("Stomp", 1.2, 0.12)
		game.shake(0.45)
		game.main.sfx("sfx_boom", -3.0, 0.8)
		game.fx.slam(b.global_position, 1.4, Color(game.story["BOSS"][String(b.boss_id)]["c"]))
		var bd: Dictionary = game.story["BOSS"][String(b.boss_id)]
		game.banner(String(bd["n"]), String(bd["sub"]), Color(bd["c"]), 3.0)
		game.boss_bark(String(bd["n"]), G67Data.BOSS_INTRO, Color(bd["c"]), String(bd["sp"]))
		game.main.sfx("sfx_rage", -4.0, 0.7)
		for i in 4:
			get_tree().create_timer(0.35 * i, false).timeout.connect(func():
				if yard != null and is_instance_valid(yard):
					yard.flood_on(i)
					G67Sound.play(self, "relay", Vector3.INF, 0.9 + 0.08 * i))
		yard.court_k(0.8)
		_crowd("start")
	if scene_t >= SCENE_LEN:
		_scene_end()

## Пропуск постановки: Миша на месте боя, прожекторы включены
func _scene_skip() -> void:
	if scene_boss == null or not is_instance_valid(scene_boss):
		return
	scene_boss.global_position = scene_to
	if world.yard != null:
		for i in 4:
			world.yard.flood_on(i)
		world.yard.court_k(0.8)
	events.append(["scene_skip"])
	_scene_end()

func _scene_end() -> void:
	_talk_hud(false)
	scene_t = -1.0
	skip_hold = 0.0
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
	var dn := "podzemka" if G67District.is_podzemka() else "yard"
	for k in G67Data.KROT:
		if String(k.get("district", "yard")) != dn:
			continue
		if not seen.has(String(k["id"])):
			return k
	return {}

## Встречи КРОТА района 2: ставится по условиям позиции (G67Data.pz_krot_ok); зовётся при входе в комнату
func _place_krot_pz() -> void:
	if not G67District.is_podzemka() or not krot_k.is_empty() or run.is_empty():
		return
	var k := krot_next()
	if k.is_empty():
		return
	var seen: Array = meta().get("seen", [])
	if not G67Data.pz_krot_ok(String(k["id"]), int(run["pos"]), seen.has("krot4"), int(run.get("k4pos", -1))):
		return
	_place_krot(String(k["where"]))

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
	if not k.is_empty() and G67District.has_zone(String(k["where"])):
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
	_krot_sign(kr, dt)
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
	_krot_beat(krot_line)
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

var krot_sign_t := 0.0
var krot_sign_cd := 0.0
var krot_sign_lb: Label3D = null

## Табличка над головой КРОТА 4: 1 с при подходе героя ближе 6 м, не чаще раза в 20 с
func _krot_sign(kr, dt: float) -> void:
	var txt := String(krot_k.get("sign", ""))
	if txt == "":
		return
	krot_sign_cd = maxf(0.0, krot_sign_cd - dt)
	if krot_sign_lb != null and is_instance_valid(krot_sign_lb):
		krot_sign_t -= dt
		if krot_sign_t <= 0.0:
			krot_sign_lb.queue_free()
			krot_sign_lb = null
		return
	if krot_sign_cd <= 0.0 and game.mode != "dlg" and (game.player.global_position - (kr as Node3D).global_position).length() < 6.0:
		krot_sign_lb = Label3D.new()
		krot_sign_lb.text = txt
		krot_sign_lb.font_size = 72
		krot_sign_lb.pixel_size = 0.0065
		krot_sign_lb.modulate = Color.WHITE
		krot_sign_lb.outline_size = 22
		krot_sign_lb.outline_modulate = Color(0.02, 0.02, 0.02, 1.0)
		var bgq := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(4.4, 0.7)
		bgq.mesh = qm
		var bgm := StandardMaterial3D.new()
		bgm.albedo_color = Color(0.03, 0.03, 0.04, 0.85)
		bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bgq.material_override = bgm
		bgq.position = Vector3(0, 0, -0.01)
		krot_sign_lb.add_child(bgq)
		krot_sign_lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		krot_sign_lb.shaded = false
		world.add_child(krot_sign_lb)
		krot_sign_lb.global_position = (kr as Node3D).global_position + Vector3(0, 2.25, 0)
		krot_sign_t = 1.0
		krot_sign_cd = 20.0
		events.append(["krot_sign"])

## Постановочные биты встреч района 2 по номеру реплики: монетка КРОТУ 4; врезка с доской и «дзынь» микроволновки у КРОТА 5
func _krot_beat(i: int) -> void:
	if int(krot_k.get("coin", -9)) == i:
		game.fx.twinkle(game.player.global_position + Vector3(0, 1.2, 0.3), 12, Color(1, 0.85, 0.3), 0.8)
		game.toast("Пять рублей — из голды ничего не списано")
		events.append(["krot_coin"])
	if int(krot_k.get("cut", -9)) == i:
		_chess_cut()
		events.append(["krot_cut"])
	if int(krot_k.get("ding", -9)) == i:
		var mw = world.district.get_node_or_null("microwave") if world != null and world.district != null else null
		if mw != null:
			var plate = mw.find_child("plate", true, false)
			if plate != null:
				plate.create_tween().tween_property(plate, "rotation:y", plate.rotation.y + TAU * 3.0, 2.2)
			var lt := OmniLight3D.new()
			lt.light_color = Color(1.0, 0.9, 0.6)
			lt.light_energy = 1.2
			lt.omni_range = 2.5
			mw.add_child(lt)
			lt.position = Vector3(0, 0.2, -0.2)
			get_tree().create_timer(2.4).timeout.connect(lt.queue_free)
		game.toast("дзынь")
		events.append(["krot_ding"])

## Врезка 0,6 с: отдельная камера на доску, микроволновка стоит на месте ферзя; затем возврат игровой камеры
func _chess_cut() -> void:
	var mw = world.district.get_node_or_null("microwave") if world != null and world.district != null else null
	var board = world.district.get_node_or_null("chess") if world != null and world.district != null else null
	if mw == null or board == null:
		return
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cut := Camera3D.new()
	world.add_child(cut)
	var bp: Vector3 = (board as Node3D).global_position
	cut.global_position = bp + Vector3(0.9, 0.9, 1.0)
	cut.look_at(bp + Vector3(0.0, 0.05, 0.0), Vector3.UP)
	cut.fov = 50.0
	cut.make_current()
	await get_tree().create_timer(0.6).timeout
	if prev != null and is_instance_valid(prev):
		prev.make_current()
	cut.queue_free()

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
	if id == "krot4" and not run.is_empty():
		run["k4pos"] = int(run["pos"])
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
var step_log: Array = []

## Шаг героя в приквеле: подъезд — бетон (лестница выше пола), двор — по поверхности под ногами
func play_step(pos: Vector3) -> void:
	var kind := "step_concrete"
	if place == "hub":
		kind = "step_stairs" if pos.y > 0.45 else "step_concrete"
	else:
		kind = "step_" + String({"tile": "concrete", "puddle": "asphalt", "earth": "snow"}.get(G67District.surface(pos), G67District.surface(pos)))
	step_log.append(kind)
	if step_log.size() > 40:
		step_log.pop_front()
	G67Sound.play(self, kind)

func take_art(id: String, replace := "") -> bool:
	G67Sound.play(self, "artifact")
	if art_info(id).is_empty() or has_art(id):
		return false
	var a: Array = run["arts"]
	if a.filter(func(x): return not G67Data.ART_EVENT.has(String(x))).size() >= slots() and not G67Data.ART_EVENT.has(id):
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
	var rc := fit_lv("receipt")
	if rc > 0:
		k *= 1.0 + minf(0.30, float(int(run.get("golda", 0)) / 25) * [0.03, 0.05][rc - 1])
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
	if id == "shawarma" and bool(run.get("free_shawarma", false)) and int((run.get("kiosk", {}) as Dictionary).get("shawarma", 0)) == 0:
		return 0                          # ларёк — этап: первая шаурма бесплатно
	return int(k["price"]) + int(k.get("step", 0)) * int((run.get("kiosk", {}) as Dictionary).get(id, 0))

## Можно ли купить и почему нет («» — можно)
func kiosk_why(id: String) -> String:
	var k := kiosk_item(id)
	if k.is_empty():
		return "нет такого"
	if id in ["double", "togo"] and not bool(run.get("kiosk_full", false)):
		return "только когда ларёк — твой этап"
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
	var cb := fit_lv("cashback")
	if cb > 0:
		var back := int(round(float(paid) * [0.08, 0.14, 0.20][cb - 1]))
		run["golda"] = int(run["golda"]) + back
		events.append(["cashback", back])
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
## Бафы семейства FORTUNA предлагаются в районе 2 и в общем пуле после победы над ней
func fit_avail(id: String) -> bool:
	if String(G67Data.FITS[id]["family"]) != "fortuna":
		return true
	return String(run.get("district", "")) == "podzemka" or bool((meta().get("flags", {}) as Dictionary).get("boss_fortuna", false))

func fit_lv(id: String) -> int:
	return int((run.get("fits", {}) as Dictionary).get(id, 0))

## Три фитса на выбор (те, что ещё можно улучшить). rare — комната элиты: редкие предлагаются первыми.
func fit_options(rare: bool) -> Array:
	var common: Array = []
	var rares: Array = []
	for id in G67Data.FITS:
		if not fit_avail(id):
			continue
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
	G67Sound.play(self, "fit")
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
	var tar := 0.06 * float(fit_lv("tariff")) if not bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false)) else 0.0
	fit_mul = minf(G67Data.DMG_CAP, 1.0 + 0.12 * float(fit_lv("heavy_hand")) + 0.04 * float(up("dmg")) + tar)
	if just == "tariff":
		p.combat.ammo["bottles"] = float(p.combat.ammo_of("bottles")) + 1.0
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

## Вступление боя (PZ_BOSS_IN): первый раз полностью (~30 с), дальше коротко (6–8 с); удержание [E] — пропуск; в проверках — сжато
var fz_skip := 0.0
var fz_full := false          # проверки: проиграть вступление и финал в полную длину

func _fz_wait(sec: float) -> void:
	var t := 0.0
	while t < sec and fz_skip < 0.8:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		fz_skip = fz_skip + dt if Input.is_key_pressed(KEY_E) else 0.0

func _fz_line(who: String, text: String, sec: float) -> void:
	if fz_skip >= 0.8:
		return
	game.banner(who, text, Color(0.62, 0.85, 0.25) if who.begins_with("FORTUNA") else Color(1, 0.95, 0.8), sec)
	await _fz_wait(sec)

func fortuna_intro(boss) -> void:
	fz_skip = 0.0
	var user: bool = game.main.user_play()
	user = user or fz_full
	var full: bool = not bool(meta().get("fz_intro", false)) and user
	var p = game.player
	var frozen: bool = p.is_physics_processing()
	p.set_physics_process(false)
	boss.set_physics_process(false)
	var k := 1.0 if user else 0.12
	var scr: Array = []
	if full:
		for i in 5:
			var lb := Label3D.new()
			lb.text = "FORTUNA 812\nМЫ ЗА ВАШИ ДЕНЬГИ"
			lb.font_size = 64
			lb.pixel_size = 0.01
			lb.modulate = Color(0.1, 0.1, 0.1, 0.0)
			lb.shaded = false
			world.add_child(lb)
			lb.position = Vector3(-10.0 + float(i) * 5.0, 4.2, -188.2)
			scr.append(lb)
		await _fz_line("PA", "Уважаемые посетители, просим сохранять спокойствие. Ваше время и деньги очень важны для нас.", 3.2 * k)
		for lb in scr:
			(lb as Label3D).modulate = Color(0.75, 1.0, 0.35, 1.0)
			game.main.sfx("sfx_ui", -10.0)
			await _fz_wait(0.5 * k)
		await _fz_line("FORTUNA 812", "Добро пожаловать в кассовый комплекс. Вход вы уже оплатили. Морально.", 3.4 * k)
		var price := Label3D.new()
		price.text = "ПРАЙС\nВХОД — 8\nВЫХОД — 67\nВОПРОС — 67\nОТВЕТ — ПО ДОГОВОРЁННОСТИ\nБОЙ С ВЛАДЕЛЬЦЕМ — ПО ДОГОВОРЁННОСТИ"
		price.font_size = 48
		price.pixel_size = 0.006
		price.modulate = Color(1.0, 0.95, 0.5)
		price.shaded = false
		world.add_child(price)
		price.global_position = p.global_position + Vector3(0, 2.6, -2.2)
		await _fz_wait(3.0 * k)
		await _fz_line("ПАХАН", "Это чё, прайс на драку?", 2.0 * k)
		await _fz_line("FORTUNA 812", "Это прайс на всё. Драка — строка четырнадцать.", 2.8 * k)
		await _fz_line("ПАХАН", "А бесплатно есть что-нибудь?", 2.0 * k)
		await _fz_line("FORTUNA 812", "Консультация. Она платная.", 2.6 * k)
		await _fz_line("ПАХАН", "Я не понял, это сейчас реально происходит?", 2.4 * k)
		await _fz_line("FORTUNA 812", "Понимание — отдельный тариф.", 2.4 * k)
		price.queue_free()
		for lb in scr:
			(lb as Label3D).queue_free()
		meta()["fz_intro"] = true
		save()
	var gate := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(26.0, 3.0, 0.3)
	gate.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.27, 0.3)
	gmat.metallic = 0.6
	gate.material_override = gmat
	world.add_child(gate)
	gate.position = Vector3(0, 5.0, -169.6)
	var gb := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(26.0, 3.0, 0.5)
	gcs.shape = gbs
	gb.add_child(gcs)
	gate.add_child(gb)
	var gtw := gate.create_tween()
	gtw.tween_property(gate, "position:y", 1.5, 0.35).set_trans(Tween.TRANS_BOUNCE)
	game.main.sfx("sfx_boom", -4.0)
	if arena != null:
		arena.tablo.text = "ВЫХОД (ПЛАТНО)"
		for l in 3:
			arena.flash(l, 1.0)
			await _fz_wait(0.35 * k)
	G67Fortuna.say(boss, "start")
	await _fz_wait((1.2 if full else 2.0) * k)
	if arena != null:
		arena.tablo.text = "ТАРИФЫ"
	boss.set_physics_process(true)
	p.set_physics_process(frozen)
	events.append(["fortuna_intro", full])

## Финал (PZ_BOSS_OUT): босс не падает — пятится к выходу, створка захлопывается, «НЕДОСТАТОЧНО СРЕДСТВ», «…В долг можно?» — «Выход платный.», садится считать
func _fortuna_outro(e) -> void:
	fz_skip = 0.0
	var user: bool = game.main.user_play() or fz_full
	var k := 1.0 if user else 0.1
	var ar := arena
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 48.0
	world.add_child(cam)
	var spot := Vector3(2.0, 0.05, -176.2)
	cam.global_position = Vector3(2.0, 2.2, -171.5)
	cam.look_at(Vector3(2.0, 1.1, -177.0), Vector3.UP)
	cam.make_current()
	var p = game.player
	p.set_physics_process(false)
	if is_instance_valid(e):
		e.global_position = spot + Vector3(0, 0, -3.0)
		e.visible = true
		e.rig.play("Walk", 0.2)
		var tw: Tween = e.create_tween()
		tw.tween_property(e, "global_position", spot, 2.0 * k)
		e.face = 0.0
	await _fz_wait(2.0 * k)
	if ar != null:
		ar.set_state(0, 3, "closed")
		game.main.sfx("sfx_boom", -3.0)
		ar.tablo.text = "НЕДОСТАТОЧНО СРЕДСТВ"
	for i in 2:
		var bp := AudioStreamPlayer.new()
		bp.stream = G67Fortuna.beep()
		add_child(bp)
		bp.play()
		bp.finished.connect(bp.queue_free)
		await _fz_wait(1.0 * k)
	await _fz_wait(2.5 * k)
	await _fz_line("FORTUNA 812", "…В долг можно?", 2.4 * k)
	await _fz_line("ПАХАН", "Выход платный.", 2.2 * k)
	if is_instance_valid(e):
		e.rig.play("FSit", 0.3)
		e.set_physics_process(false)
	if ar != null:
		ar.tablo.text = "ТЯГА-812 — ВЫДАНА БЕЗ ЧЕКА"
	await _fz_wait(2.5 * k)
	if prev != null and is_instance_valid(prev):
		prev.make_current()
	else:
		game.cam.make_current()
	cam.queue_free()
	p.set_physics_process(true)
	events.append(["fortuna_outro"])

func _boss_down(e) -> void:
	_crowd("win")
	var d := district()
	room_state = "over"
	game.slowmo(1.4)
	game.shake(0.8)
	game.fx.slam(e.global_position, 1.8, Color(e.boss["c"]))
	if world.yard != null:
		world.yard.flood_all(3.0)
		get_tree().create_timer(2.0, false).timeout.connect(flood_rest)
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
	if String(d["boss"]) == "g67_fortuna":
		if first:
			for t in ["Стиль «ТЯГА-812» — стойка стилей в подъезде", "Бафы семейства FORTUNA 812 — в общем пуле", "Карта маршрутов: ПОДЗЕМКА пройдена, ЛЕНТА — скоро"]:
				_note_new(t)
			if has_method("unlock_clip"):
				unlock_clip("NEWS02")
		var out_task := func():
			await _fortuna_outro(e)
			game.banner("FORTUNA 812 ПОВЕРЖЕН", ("открыт стиль: %s" % style_name) if first else "район пройден", Color(0.62, 0.85, 0.25), 3.5)
			_finish_run(true, 2.0)
		out_task.call()
		return
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
	_crowd("lose")
	flood_rest()
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
	flush_coins()
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
	await start_run(sel_district)

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
			parts.append("%s — %s" % [String(G67District.zone_of(String(o.get("place", "")))["name"]).to_upper(), String(G67Data.ROOM_NAMES[type])])
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
		door = "продолжить забег · этап %d из 6 · здоровье %d из %d" % [int(rr.get("pos", 0)) + 1, int(float(sv.get("hp", game.player.max_hp))), int(game.player.max_hp)]
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
	var r := _music_context_base()
	if G67District.is_podzemka() and pz_duck_district():
		r["duck_db"] = -30.0
	return r

func _music_context_base() -> Dictionary:
	var dir = game.main.audio.director
	var res := {"dialogue": "talk", "boss_set": ""}
	var ph = phone_get()
	var phone_on: bool = (ph != null and ph.active()) or (game.ipod != null and game.ipod.g67_playing())
	if place == "hub":
		var back := hub_back_t > 0.0
		res["ctx"] = "explore"
		res["cue"] = dir.resolve_cue("loc_g67_" + last_district, "loc_snow") if back else dir.resolve_cue("loc_g67_hub", "loc_hall")
		res["layers"] = [1.0, 0.0, 0.0]
		res["transition"] = "cross"
		var tv := _tv_node()
		if tv != null:
			res["via"] = tv
		if phone_on:                                     # играет плейлист iPhone: музыка режима молчит
			res["ctx"] = "story"
			res["cue"] = ""
		return res
	last_district = String(run.get("district", last_district))
	var yard: String = dir.resolve_cue("loc_g67_" + last_district, "loc_snow")
	res["cue"] = yard
	res["layers"] = [1.0, 0.0, 0.0]
	res["ctx"] = "explore"
	res["transition"] = "gap"
	if room_state == "boss":
		var boss = game.boss_e
		var staging: bool = scene_t >= 0.0 or ev_cam or ev_busy or (bark_hold > 0.0 and game.bark_b.playing)
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
				var lay := [1.0, 1.0 if boss.phase >= 1 else 0.0, 1.0 if boss.phase >= 2 else 0.0]
				if boss.phase >= 2 and float(boss.get("weak_t")) > 0.0:
					lay[0] = 0.0                         # окно «ОТКРЫТ» в третьей фазе: бас уходит
				if bool(boss.get("antract")):
					lay = [1.0, 0.0, 0.0]                # антракт: тема тише, остаётся один слой
				res["layers"] = lay
	elif room_state == "over":
		res["ctx"] = "victory"
		res["transition"] = "cross"
	elif ev_cam or ev_busy:
		res["ctx"] = "story"
		res["cue"] = ""
	elif game.enemies.any(func(e): return is_instance_valid(e) and e.state != "dead"):
		res["ctx"] = "combat"
		res["layers"] = [1.0, 1.0, 0.0]
	if phone_on:                                         # плейлист главнее музыки режима и темы Миши
		res["ctx"] = "story"
		res["cue"] = ""
		res["boss_set"] = ""
	return res

func _physics_process(dt: float) -> void:
	if game == null or world == null or not is_instance_valid(world):
		return
	if place == "hub" and not game.get_tree().paused:
		_hub_life_tick(dt)
	if game.get_tree().paused:
		if prompt != null:
			prompt.visible = false
		return
	_t += dt
	hub_back_t = maxf(0.0, hub_back_t - dt)
	bark_hold = maxf(0.0, bark_hold - dt)
	if talk_on:
		_talk_step(dt)
	if ev_cam:
		var heldv := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
		ev_hold = ev_hold + dt if heldv else maxf(0.0, ev_hold - dt * 3.0)
		if ev_hold >= SKIP_HOLD:
			ev_skip = true
	if scene_t >= 0.0:
		var held := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		skip_hold = skip_hold + dt if held else maxf(0.0, skip_hold - dt * 3.0)
		if skip_hold >= SKIP_HOLD:
			skip_hold = 0.0
			_scene_skip()
		else:
			_scene_tick(dt)
	_marks_tick()
	_krot_tick(dt)
	_pz_music_tick(dt)
	_crowd_tick()
	if place == "run" and not busy and not game.over and not run.is_empty():
		if room_state == "fight":
			_fight_tick(dt)
		_stash_tick(dt)
		_coins_tick(dt)
		_ev_tick()
		_ambush_tick()
		_second_wind()
	_art_tick(dt)
	if not game.over:
		_g67_audio_tick(dt)
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
			start_run(sel_district)
	elif id == "descent":
		if bool((meta().get("flags", {}) as Dictionary).get("boss_misha", false)):
			if room_state == "open":
				data["run"] = {}
				events.append(["descent"])
				start_run("podzemka")
			else:
				game.toast("Сначала закончи этап")
		else:
			game.toast("Закрыто. Миша не разрешал")
	elif id == "home":
		if room_state == "open":
			go_home()
		else:
			game.toast("Сначала разберись с этими")
	elif id == "tv":
		tv()
	elif id == "kiosk" and _kiosk_gate() >= 0:
		use("gate%d" % _kiosk_gate())               # на позиции с вариантом ЛАРЁК окно — это вариант этапа
	elif id == "kiosk":
		if place == "run" and int(run.get("pos", 0)) < 1 and not bool(run.get("kiosk_full", false)):
			game.toast("Окно закрыто: откроется после второй позиции")
		elif room_state in ["open", "reward"]:
			open_screen("kiosk")
		else:
			game.toast("Сначала разберись с этими")
	elif id == "hub_btn" or id == "intercom" or id == "g_radio" or id == "carpet" or id == "box" or id == "puh" or id.begins_with("read_"):
		_life_use(id)
	elif id.begins_with("talk_"):
		var rr = world.yard.residents.get(id.substr(5)) if world.yard != null else null
		if rr != null:
			rr.use()
	elif id == "ev_burmalda":
		_burmalda_pull()
	elif id == "ev_button":
		_button_press()
	elif id == "slot":
		_slot_use()
	elif id.begins_with("bottle") and id.length() == 7:
		_bottle_pick(int(id.substr(6)))
	elif id == "reserve_table":
		_reserve_final()
	elif id == "hamster_game":
		_hamster_play()
	elif id == "shutter" or id == "hamster_door":
		var pzd := world.district as G67Podzemka
		if pzd != null and pzd.open_door("shutter" if id == "shutter" else "hamster"):
			game.toast("Рольставня поднимается" if id == "shutter" else "Дверь скрипит")
			if id == "hamster_door":
				var cr := AudioStreamPlayer3D.new()
				cr.stream = G67HamsterGame.synth_creak()
				cr.unit_size = 6.0
				pzd.add_child(cr)
				cr.global_position = Vector3(44.0, 1.4, -146.0)
				cr.play()
				cr.finished.connect(cr.queue_free)
				events.append(["door_creak"])
			events.append(["door_open", id])
			if id == "hamster_door":
				_hamster_first_enter = true
	elif id == "elite_fit":
		if room_state == "reward" and String(room.get("type", "")) == "elite":
			world.points = world.points.filter(func(pt): return String(pt["id"]) != "elite_fit")
			if elite_hanger != null and is_instance_valid(elite_hanger):
				elite_hanger.queue_free()
			elite_hanger = null
			_offer_fit(true)
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

var crowd_last_ms := -10000

func _crowd(kind: String) -> void:
	if kind in ["hit", "laugh"]:
		if GameClock.ms() - crowd_last_ms < 2000:
			return                       # на приёмы Миши зрители реагируют не чаще раза в 2 с
		crowd_last_ms = GameClock.ms()
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
## Смена фазы: короткое мигание прожекторов и оттенок (фаза 2 теплее, фаза 3 — красноватый акцент на двух мачтах)
func _flood_phase(ph: int) -> void:
	var y = world.yard if world != null else null
	if y == null:
		return
	y.flood_all(0.0)
	get_tree().create_timer(0.3, false).timeout.connect(func():
		if y == null or not is_instance_valid(y):
			return
		y.flood_all(1.6, Color(1.0, 0.82, 0.55) if ph == 1 else Color(1.0, 0.92, 0.75))
		if ph >= 2:
			for i in [0, 3]:
				(y.flood[i] as OmniLight3D).light_color = Color(1.0, 0.35, 0.28))

func flood_rest() -> void:
	var y = world.yard if world != null else null
	if y != null and is_instance_valid(y):
		y.court_k(0.3)
		y.flood_all(0.25)

func _crowd_tick() -> void:
	var b = game.boss_e
	if b == null or not is_instance_valid(b):
		crowd_phase = -1
		return
	if crowd_phase >= 0 and int(b.phase) != crowd_phase:
		_crowd("phase")
		_flood_phase(int(b.phase))
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

func clip_open_ev(ev: String) -> bool:
	return (meta().get("archive", []) as Array).has("ev_" + ev)

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
		"result":
			hub_ui = ResultUIScript.open(self)
			G67Sound.play(self, "respect")
	hub_ui.closed.connect(func():
		hub_ui = null
		refresh_hints()
		if what == "kiosk" and room_state == "reward" and String(room.get("type", "")) == "kiosk":
			_stage_end())

func _tv_menu() -> void:
	open_screen("archive")

func _tv_close() -> void:
	if hub_ui != null:
		hub_ui.close()
