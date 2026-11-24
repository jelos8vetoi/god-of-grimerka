class_name G67DvorEvents
extends Node3D
## Пять событий нового двора (DVOR_FIVE_NEW_EVENTS.md): ХОЛОДИЛЬНИК, АРМРЕСТЛИНГ, МАШИНА В СУГРОБЕ, КЛЮЧИ, ОЧЕРЕДЬ.
## В забеге — два из пяти (PER_RUN). Реплики — из утверждённого документа. Выбора в окне диалога в игре нет, поэтому выбор
## сделан действием: согласие — взяться за дело ([E] у участника после разговора), отказ — уйти.
## Состояние события — run["ev"][id]: "" (не начато) / talk / task / done / fail; пройденное считается в run["ev_done"] (баф «РАЙОН ПОМНИТ»).
## Боя здесь нет. Числа — константы ниже.

const PER_RUN := 2
const FRIDGE_PATH := 14.0        # сколько нести, м
const FRIDGE_SLOW := 0.55        # скорость с грузом
const FRIDGE_GOLD := [30, 30, 30, 10]      # по числу «качнул»: 0, 1, 2, 3 и больше
const FRIDGE_HEAL := 25.0        # «термос»: расходников в игре нет — чай выпивается сразу
const ARM_STAKE := 20
const ARM_ROUNDS := 3
const ARM_NEED := 2
const BEAT := 0.8                # «раз» — «два» — «ДАВАЙ»
const WINDOW := 0.75             # сколько открыт момент «ДАВАЙ», с
const STUCK_TRIES := 3
const STUCK_DISCOUNT := 0.3
const CROW_STILL := 5.0          # сколько стоять у вороны
const QUEUE_T := 20.0

static var all_for_check := false          # проверка ставит все пять событий сразу

const EVENTS := {
	"fridge": {"name": "ХОЛОДИЛЬНИК", "hint": "взяться с той стороны",
		"npc": {"code": "TL", "model": "g67_npc_ushanka", "h": 1.74, "tint": Color(0.9, 0.82, 0.7), "at": [-83.0, -111.0], "look": [-81.4, -110.2], "base": "NHips", "alts": ["NThink", "NCross"], "temper": "push",
			"greet": ["TL|Ну и стой. Стой, раз такой умный.", "TL|Сто кило. Сто кило, и ни одной ручки. Кто так делает?", "TL|Грузчики. Одно название."],
			"hit": ["TL|Ты чего! Я тебя как человека попросил!"], "cold": ["TL|Спортсмены нынче не те."], "fight": ["TL|Я за холодильником, если что."]},
		"talk": ["TL|О. Молодой человек. Ты же спортсмен?", "V|Нет.", "TL|А выглядишь как спортсмен. Тут делов на минуту. Четвёртый этаж.", "V|Четвёртый?",
			"TL|Ну до двери подъезда хотя бы. Дальше я сам. У меня сын придёт. В пятницу.", "V|А сегодня какой день?", "TL|Суббота.",
			"TL|Тридцать рублей дам. Золотых. Или термос. Термос хороший, китайский, держит."]},
	"arm": {"name": "АРМРЕСТЛИНГ", "hint": "сесть за стол: ставка 20",
		"npc": {"code": "SN", "model": "g67_npc_taxi_driver", "h": 1.8, "tint": Color(0.7, 0.8, 1.0), "at": [-16.0, -91.4], "look": [-16.0, -86.0], "base": "NCross", "alts": ["NHips", "NSmoke"], "temper": "push",
			"greet": ["SN|Следующий.", "SN|С девяносто восьмого никому. Ни-ко-му."], "hit": ["SN|Руками машешь, а за стол сесть — кишка тонка?"], "cold": ["SN|С такими не сажусь."], "fight": ["SN|Магнитофон под стол уберу."]},
		"talk": ["SN|О, с шестьдесят седьмого. Садись. Или боишься?", "V|Чего бояться?", "SN|Правую. Левую я берегу, она для серьёзных людей.", "V|И что на кону?",
			"SN|Двадцать. Выиграешь — научу, как бить, чтоб с одного раза садились. Проиграешь — двадцатка моя."]},
	"stuck": {"name": "МАШИНА В СУГРОБЕ", "hint": "упереться в багажник",
		"npc": {"code": "VT", "model": "g67_npc_taxi_driver", "h": 1.72, "tint": Color(1.0, 0.85, 0.7), "at": [105.5, -83.0], "look": [108.0, -86.0], "base": "NCarLean", "alts": ["NHips", "NTaxiPhone"], "temper": "film",
			"greet": ["VT|Ну давай. Давай, родная. Давай, я сказал!", "VT|Вот же ж... сосед. Узнаю — закопаю его самого."], "hit": ["VT|Братан, ты чего?! Я ж по-хорошему!"], "cold": ["VT|Ну и ладно. Сам. Я всю жизнь сам."], "fight": ["VT|Я в машине посижу."]},
		"talk": ["VT|Братан! Братан, толкни, а? На раз-два. Я газую — ты толкаешь.", "V|А сам чего встрял?", "VT|Это не я встрял. Это меня встряли. Сосед, джелос, место ему жалко.", "V|Место его?",
			"VT|Место общее. Он его просто почистил. Это разные вещи.", "VT|Денег нет, честно. Но я с гаражными на короткой. Скажешь, что от Виталика — скинут."]},
	"keys": {"name": "КЛЮЧИ", "hint": "спросить, что случилось",
		"npc": {"code": "BZ", "model": "g67_npc_babushka", "h": 1.5, "tint": Color(0.9, 0.84, 1.0), "at": [-104.0, -60.4], "look": [-104.0, -66.0], "base": "NBagRest", "alts": ["NScarf"], "temper": "scold", "turn": 1.0,
			"greet": ["BZ|Глазастых нынче мало."], "hit": ["BZ|Меня-то за что, ирод! Я ключи потеряла, а не совесть!"], "cold": ["BZ|Иди, иди."], "fight": ["BZ|Господи, и тут дерутся."]},
		"talk": ["BZ|Сынок. Ты глазастый?", "V|Смотря на что.", "BZ|На ключи. Связка, три ключа и брелок. Брелок — ёжик. Я вот тут шла, вот тут кормила, а вот тут уже нету.",
			"V|Может, дома оставила?", "BZ|Если б я их дома оставила, я б дома и сидела."],
		"spots": [[-98.0, -86.6, "КАЧЕЛИ", "посмотреть в снегу"], [-110.0, -80.0, "СУГРОБ", "что-то блестит"], [-88.0, -92.0, "БАКИ", "ворона. Не спугни: постой рядом"]]},
	"queue": {"name": "ОЧЕРЕДЬ", "hint": "спросить, кто последний",
		"npc": {"code": "QD", "model": "g67_npc_ushanka", "h": 1.66, "tint": Color(0.86, 0.86, 0.9), "at": [-30.0, -15.6], "look": [-30.0, -11.0], "base": "NPockets", "alts": ["NThink"], "temper": "scold",
			"greet": ["QD|А чего дают-то?", "QD|Тогда я точно стою."], "hit": ["QD|Мужчина! Тут люди с вечера!"], "cold": ["QD|Не выстоял. Молодёжь."], "fight": ["QD|Очередь не расходится. Очередь пережидает."]},
		"extra": [{"code": "QT", "model": "g67_npc_babushka", "h": 1.58, "tint": Color(1.0, 0.9, 0.8), "at": [-30.0, -14.2], "look": [-30.0, -11.0], "base": "NBag", "alts": ["NBagRest"], "temper": "scold",
				"greet": ["QT|Я с семи стою.", "QT|Я со вчерашних семи."], "hit": ["QT|Куда?! Куда он?!"], "cold": ["QT|Вот! Вот из-за таких и учёт!"], "fight": ["QT|Сумку не трогать!"]},
			{"code": "QS", "model": "g67_npc_schoolboy", "h": 1.5, "tint": Color(0.8, 0.85, 1.0), "at": [-30.0, -12.9], "look": [-30.0, -11.0], "base": "NPhone", "alts": ["NStraps"], "temper": "flee",
				"greet": ["QS|Сейчас без десяти семь.", "QS|Никто не знает."], "hit": ["QS|Да пусть идёт, там всё равно закрыто!"], "cold": ["QS|Зато честно."], "fight": ["QS|Я отойду, но я стоял!"]}],
		"talk": ["V|Кто последний?", "QD|Я. А за мной ещё женщина занимала, она отошла. И мужчина в кепке. И ещё один, но он не вернётся, я его знаю.", "V|А за чем стоим?",
			"QT|Молодой человек, вы сначала встаньте, а потом спрашивайте."],
		"chat": ["QS|Говорят, с капустой.", "QT|Кто говорит?", "QS|Я говорю. Я надеюсь.", "QD|В восьмом году тут шапки давали. Я тоже стоял.", "QD|Шапка есть. Не моего размера, но есть.",
			"QT|Очередь — это не про двигаться. Очередь — это про стоять."]},
}

var G: Golda67
var act := ""                    # событие, которое сейчас идёт (одно)
var st := {}                     # состояние идущего события
var npcs := {}                   # id события -> запись жителя (как в G67DvorFolk)
var props := {}                  # id события -> узлы реквизита
var log: Array = []              # для проверок: [событие, что случилось]
var slow := 1.0                  # множитель скорости героя (груз) — читает Golda67._art_tick

func setup(g67: Golda67) -> void:
	G = g67
	if not G.run.has("ev"):
		var ids: Array = EVENTS.keys()
		var pick := {}
		var n0 := int(G.meta().get("runs", 0))
		for k in (ids.size() if all_for_check else PER_RUN):
			pick[String(ids[(n0 * 2 + k * 3) % ids.size()] if not all_for_check else ids[k])] = ""
		G.run["ev"] = pick
	for id in (G.run["ev"] as Dictionary):
		_place(String(id))

func state(id: String) -> String:
	return String((G.run.get("ev", {}) as Dictionary).get(id, "none"))

func _mark(id: String, s: String) -> void:
	(G.run["ev"] as Dictionary)[id] = s
	log.append([id, s])
	G.events.append(["dv_event", id, s])
	if s == "done":
		G.run["ev_done"] = int(G.run.get("ev_done", 0)) + 1
		G._add_respect("calm", int(G67Data.RESPECT["calm"]))
	if s in ["done", "fail"]:
		G.world.points = G.world.points.filter(func(pt): return not String(pt["id"]).begins_with("evdv_" + id))
		act = ""
		slow = 1.0
		G._save_run("open")

func _place(id: String) -> void:
	var d: Dictionary = EVENTS[id]
	var f: Dictionary = G.folk._spawn(d["npc"], "ev_" + id)
	if f.is_empty():
		return
	G.folk.folk.append(f)
	npcs[id] = f
	for x in (d.get("extra", []) as Array):
		var f2: Dictionary = G.folk._spawn(x, "ev_%s_%s" % [id, String((x as Dictionary)["code"])])
		if not f2.is_empty():
			G.folk.folk.append(f2)
	if state(id) in ["done", "fail"]:
		return
	(G.run["ev"] as Dictionary)[id] = ""          # незаконченное после загрузки начинается заново
	var at: Vector3 = (f["home"] as Vector3) + G67DvorFolk._dir(float(f["yaw"])) * 1.2
	G.world._point("evdv_" + id, String(d["name"]), String(d["hint"]), at)
	if id == "fridge":
		props[id] = _box((f["home"] as Vector3) + Vector3(1.5, 0.0, -0.8), Vector3(0.7, 1.7, 0.66), Color(0.93, 0.94, 0.95))

func _box(at: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.5
	mi.material_override = m
	add_child(mi)
	mi.global_position = at + Vector3(0, size.y * 0.5, 0)
	return mi

func _npc_say(id: String, line: String) -> void:
	if npcs.has(id):
		G.barks_get().say((npcs[id] as Dictionary)["rig"], line, {"force": true})

## [E] у точки события
func use(pid: String) -> void:
	var rest := pid.substr(5)
	var id := rest.get_slice("_", 0)
	if not EVENTS.has(id) or G.room_state != "open":
		return
	if act != "" and act != id:
		G.game.toast("Сначала закончи начатое")
		return
	var s := state(id)
	if s == "":
		_talk(id)
	elif s == "task":
		_press(id, rest)

func _talk(id: String) -> void:
	act = id
	_mark(id, "talk")
	var d: Dictionary = EVENTS[id]
	if npcs.has(id):
		G.game.dlg_partner = (npcs[id] as Dictionary)["rig"]
	G.game.start_dialog(d["talk"], func(): _begin(id))

func _retitle(id: String, title: String, hint: String) -> void:
	for pt in G.world.points:
		if String(pt["id"]) == "evdv_" + id:
			pt["title"] = title
			pt["hint"] = hint

## После разговора: дело начинается, когда игрок берётся за него
func _begin(id: String) -> void:
	if not is_instance_valid(G) or state(id) != "talk":
		return
	_mark(id, "task")
	act = id
	st = {"t": 0.0, "n": 0, "ok": 0, "phase": "wait", "wobble": 0, "step": 0}
	var f: Dictionary = npcs.get(id, {})
	match id:
		"fridge":
			_retitle(id, "ХОЛОДИЛЬНИК", "поднять и нести к двери подъезда")
		"arm":
			_retitle(id, "АРМРЕСТЛИНГ", "ставка %d: жми [E] на «ДАВАЙ»" % ARM_STAKE)
		"stuck":
			_retitle(id, "МАШИНА В СУГРОБЕ", "толкай [E] на «ДАВАЙ»")
		"keys":
			G.world.points = G.world.points.filter(func(pt): return String(pt["id"]) != "evdv_keys")
			_keys_spot(0)
			_npc_say(id, "BZ|От лавки следы. Мои. Наверное.")
		"queue":
			_retitle(id, "ОЧЕРЕДЬ", "встать в конец и стоять")
			st["phase"] = "stand"
			st["spot"] = (f["home"] as Vector3) + Vector3(0, 0, 1.6)

func _keys_spot(i: int) -> void:
	var sp: Array = EVENTS["keys"]["spots"][i]
	G.world._point("evdv_keys_%d" % i, String(sp[2]), String(sp[3]), G67Dvor2.to3(float(sp[0]), float(sp[1])))
	st["step"] = i

## [E] во время дела
func _press(id: String, rest: String) -> void:
	match id:
		"fridge":
			if String(st["phase"]) == "wait":
				st["phase"] = "carry"
				st["from"] = G.game.player.global_position
				slow = FRIDGE_SLOW
				G.world.points = G.world.points.filter(func(pt): return String(pt["id"]) != "evdv_fridge")
				_npc_say(id, "TL|Левее. Левее! Это твоё лево или моё?")
				G.game.toast("Неси к двери подъезда на запад. Не беги, не прыгай, не уклоняйся")
		"arm":
			if String(st["phase"]) == "wait":
				if int(G.run.get("golda", 0)) < ARM_STAKE:
					_npc_say(id, "SN|Приходи, когда будет на что садиться.")
					return
				G.run["golda"] = int(G.run["golda"]) - ARM_STAKE
				st["phase"] = "count"
				st["t"] = 0.0
				_npc_say(id, "SN|Раз, два — поехали.")
			else:
				_beat_press(id)
		"stuck":
			if String(st["phase"]) == "wait":
				st["phase"] = "count"
				st["t"] = 0.0
			else:
				_beat_press(id)
		"keys":
			var i := int(rest.get_slice("_", 1)) if rest.contains("_") else -1
			if i != int(st["step"]):
				return
			G.world.points = G.world.points.filter(func(pt): return String(pt["id"]) != "evdv_keys_%d" % i)
			if i == 0:
				st["mitten"] = true
				G.barks_get().say(G.game.player, "V|Варежка есть. Ключей нет.", {"force": true})
				_keys_spot(1)
			elif i == 1:
				G.barks_get().say(G.game.player, "V|Не то.", {"force": true})
				_keys_spot(2)
				st["phase"] = "crow"
				st["t"] = 0.0
				st["last"] = G.game.player.global_position
			elif i == 3:
				_keys_end()

## Нажатие в игре «раз — два — ДАВАЙ»: попал в окно — удача, раньше или позже — промах
func _beat_press(id: String) -> void:
	if String(st["phase"]) != "count" or bool(st.get("pressed", false)):
		return
	st["pressed"] = true
	var hit: bool = float(st["t"]) >= BEAT * 2.0 and float(st["t"]) <= BEAT * 2.0 + WINDOW
	st["hit"] = hit

func beat_open() -> bool:
	return act in ["arm", "stuck"] and String(st.get("phase", "")) == "count" and float(st["t"]) >= BEAT * 2.0 and float(st["t"]) <= BEAT * 2.0 + WINDOW

func _beat_tick(id: String, dt: float) -> void:
	var t0: float = float(st["t"])
	st["t"] = t0 + dt
	var t: float = float(st["t"])
	var who := "SN" if id == "arm" else "VT"
	if t0 < 0.05 and t >= 0.05:
		G.game.popup(G.game.player.global_position + Vector3(0, 2.3, 0), "РАЗ", Color(1, 1, 1))
	if t0 < BEAT and t >= BEAT:
		G.game.popup(G.game.player.global_position + Vector3(0, 2.3, 0), "ДВА", Color(1, 1, 1))
	if t0 < BEAT * 2.0 and t >= BEAT * 2.0:
		G.game.popup(G.game.player.global_position + Vector3(0, 2.4, 0), "ДАВАЙ!", Color(1.0, 0.8, 0.2))
		G.game.main.ui("confirm")
	if t < BEAT * 2.0 + WINDOW + 0.25:
		return
	var hit: bool = bool(st.get("hit", false))
	st["n"] = int(st["n"]) + 1
	st["ok"] = int(st["ok"]) + (1 if hit else 0)
	st["pressed"] = false
	st["hit"] = false
	st["t"] = -0.9           # пауза перед следующим счётом
	if id == "arm":
		_npc_say(id, (who + "|Ишь ты. Ишь ты!") if hit else (who + "|Не напрягайся так, лицо порвёшь."))
		if int(st["ok"]) >= ARM_NEED:
			_arm_end(true)
		elif int(st["n"]) - int(st["ok"]) > ARM_ROUNDS - ARM_NEED:
			_arm_end(false)
	else:
		if hit:
			_npc_say(id, who + "|Красавец! Всё, я должен. В гаражи зайдёшь — скажи: от Виталика. Они поймут.")
			G.run["discount"] = STUCK_DISCOUNT
			if String(G.run.get("trader", "")) == "" or (G.folk != null and G.folk.trader_closed()):
				G.add_golda(20)
			G.game.banner("МАШИНА В СУГРОБЕ", "от Виталика: скидка 30 % на одну покупку у торговца", Color(0.6, 0.9, 1.0), 2.6)
			_mark(id, "done")
		elif int(st["n"]) >= STUCK_TRIES:
			_npc_say(id, who + "|Ну всё. Ну всё, приехали. Сейчас весь район сбежится.")
			G.game.banner("МАШИНА В СУГРОБЕ", "села на брюхо", Color(0.8, 0.5, 0.4), 2.2)
			_mark(id, "fail")
		else:
			_npc_say(id, who + "|Да не сейчас! На «давай»! Я же говорю — «давай»!")

func _arm_end(won: bool) -> void:
	if won:
		_npc_say("arm", "SN|...Так. Это стол кривой. Ладно. Слово дал: бьёшь не рукой, бьёшь плечом.")
		G.run["golda"] = int(G.run["golda"]) + ARM_STAKE
		if G.fit_lv("heavy_hand") < int(G67Data.FITS["heavy_hand"]["lv"]):
			(G.run["fits"] as Dictionary)["heavy_hand"] = G.fit_lv("heavy_hand") + 1
			G.apply_fits("heavy_hand")
			G.events.append(["fit", "heavy_hand"])
			G.game.banner("АРМРЕСТЛИНГ", "ТЯЖЁЛАЯ РУКА · уровень %d" % G.fit_lv("heavy_hand"), Color(0.85, 0.63, 0.23), 2.6)
		else:
			G.add_golda(40)
			G.game.banner("АРМРЕСТЛИНГ", "+40 голды", Color(0.85, 0.63, 0.23), 2.6)
		_mark("arm", "done")
	else:
		_npc_say("arm", "SN|Ну вот. А говорил — чего бояться.")
		G.game.banner("АРМРЕСТЛИНГ", "ставка ушла Санычу", Color(0.8, 0.5, 0.4), 2.2)
		_mark("arm", "fail")

func _keys_end() -> void:
	_npc_say("keys", "BZ|Опять она. Я ж её кормлю, заразу. Ну спасибо, сынок. В подвале у деда верстак остался — забери, мне железки ни к чему.")
	# жетон улучшения: +1 уровень бафу с наибольшим уровнем; нечего улучшать — голда
	var best := ""
	for fid in (G.run.get("fits", {}) as Dictionary):
		if G.fit_lv(fid) < int(G67Data.FITS[fid]["lv"]) and (best == "" or G.fit_lv(fid) > G.fit_lv(best)):
			best = String(fid)
	if best != "":
		(G.run["fits"] as Dictionary)[best] = G.fit_lv(best) + 1
		G.apply_fits(best)
		G.events.append(["fit", best])
		G.game.banner("КЛЮЧИ", "жетон улучшения: %s · уровень %d" % [String(G67Data.FITS[best]["name"]), G.fit_lv(best)], Color(0.6, 0.9, 1.0), 2.8)
	else:
		G.add_golda(25)
		G.game.banner("КЛЮЧИ", "+25 голды", Color(0.6, 0.9, 1.0), 2.4)
	if bool(st.get("mitten", false)):
		G.game.player.hp = minf(G.game.player.max_hp, G.game.player.hp + FRIDGE_HEAL)
	_mark("keys", "done")

func _physics_process(dt: float) -> void:
	if G == null or act == "" or state(act) != "task" or G.place != "run":
		return
	var p = G.game.player
	var pp: Vector3 = p.global_position
	match act:
		"fridge":
			if String(st["phase"]) != "carry":
				return
			var box: MeshInstance3D = props.get("fridge")
			if is_instance_valid(box):
				box.global_position = pp + G67DvorFolk._dir(float(p.face)) * 0.75 + Vector3(0, 0.95, 0)
				box.rotation.y = float(p.face)
			st["t"] = float(st["t"]) + dt
			var rough: bool = String(p.state) in ["roll", "jump", "airdash", "slide", "attack"] or not p.is_on_floor() or p.velocity.length() > 5.2
			if rough and float(st.get("wob_cd", 0.0)) <= 0.0:
				st["wobble"] = int(st["wobble"]) + 1
				st["wob_cd"] = 1.5
				_npc_say("fridge", "TL|Не тряси, там полка стеклянная. Была.")
			st["wob_cd"] = maxf(0.0, float(st.get("wob_cd", 0.0)) - dt)
			var gone: float = pp.distance_to(st["from"])
			if int(st["wobble"]) >= 3 or gone >= FRIDGE_PATH:
				var w := mini(int(st["wobble"]), 3)
				var got: int = G.add_golda(int(FRIDGE_GOLD[w]))
				if w == 0:
					p.hp = minf(p.max_hp, p.hp + FRIDGE_HEAL)
				if is_instance_valid(box):
					box.global_position = pp + G67DvorFolk._dir(float(p.face)) * 1.1 + Vector3(0, 0.85, 0)
					if w >= 3:
						box.rotation.z = PI * 0.5
						box.global_position.y = 0.35
				_npc_say("fridge", ["TL|Вот. Вот это человек. Держи, заработал. И термос держи, чего уж.", "TL|Дребезжит что-то. Ну ладно. Оно и до тебя дребезжало.",
					"TL|Дребезжит что-то. Ну ладно. Оно и до тебя дребезжало.", "TL|Ну, зато теперь видно, что внутри. На, за старание."][w])
				G.game.banner("ХОЛОДИЛЬНИК", "+%d голды%s" % [got, " · чай из термоса: +%d здоровья" % int(FRIDGE_HEAL) if w == 0 else ""], Color(0.6, 0.9, 1.0), 2.6)
				st["w"] = w
				_mark("fridge", "done" if w < 3 else "fail")
		"arm", "stuck":
			if String(st["phase"]) == "count":
				_beat_tick(act, dt)
		"keys":
			if String(st.get("phase", "")) != "crow":
				return
			var sp: Array = EVENTS["keys"]["spots"][2]
			var crow := G67Dvor2.to3(float(sp[0]), float(sp[1]))
			if pp.distance_to(crow) > 5.0:
				st["t"] = 0.0
				return
			if String(p.state) in ["attack", "roll"]:
				G.barks_get().say(p, "V|Да ладно.", {"force": true})
				G.game.banner("КЛЮЧИ", "ворона улетела с ключами за гаражи", Color(0.8, 0.5, 0.4), 2.4)
				_npc_say("keys", "BZ|Ну и ладно. Посижу. Серёга когда-нибудь проспится.")
				_mark("keys", "fail")
				return
			if pp.distance_to(st["last"]) > 0.25:
				st["t"] = 0.0
				st["last"] = pp
			st["t"] = float(st["t"]) + dt
			if float(st["t"]) >= CROW_STILL:
				st["phase"] = "back"
				G.game.toast("Ворона бросила связку с ёжиком. Отнеси бабе Зине")
				G.world.points = G.world.points.filter(func(pt): return String(pt["id"]) != "evdv_keys_2")
				G.world._point("evdv_keys_3", "БАБА ЗИНА", "отдать ключи", (npcs["keys"]["home"] as Vector3) + G67DvorFolk._dir(float(npcs["keys"]["yaw"])) * 1.2)
				st["step"] = 3
		"queue":
			if String(st["phase"]) != "stand":
				return
			var spot: Vector3 = st["spot"]
			if Vector2(pp.x - spot.x, pp.z - spot.z).length() > 2.2:
				if float(st["t"]) > 1.0:
					_npc_say("queue", "QD|Не выстоял. Молодёжь.")
				st["t"] = 0.0
				return
			var t0: float = float(st["t"])
			st["t"] = t0 + dt
			var chat: Array = EVENTS["queue"]["chat"]
			var k := int(float(st["t"]) / 3.2)
			if k != int(t0 / 3.2) and k < chat.size():
				_npc_say("queue", String(chat[k]))
			if float(st["t"]) >= QUEUE_T:
				_npc_say("queue", "QP|Учёт.")
				G.barks_get().say(p, "V|Я на это время потратил.", {"force": true})
				G.game.banner("ОЧЕРЕДЬ", "постоял. Ничего не дали", Color(0.8, 0.8, 0.8), 2.6)
				var arch: Array = G.meta().get("archive", [])
				if not arch.has("ev_queue"):
					arch.append("ev_queue")
					G.meta()["archive"] = arch
				_mark("queue", "done")
