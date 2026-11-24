class_name G67DvorFolk
extends Node3D
## Жители и торговцы нового двора (G67Dvor2). Данные — FOLK и TRADERS ниже: новый житель — строка данных.
## Житель стоит в своей позе (G67Life), здоровается, когда Пахан рядом, уходит от драки и возвращается, некоторые ходят по маршруту.
## Мирного можно ударить: урона, смерти и наград нет — есть реакция по характеру (temper) и память района (run["npc_hits"]):
## после трёх ударов за забег с Паханом здороваются холодно, а ударенный торговец закрывает лавку до конца забега.
## Боевую механику модуль не трогает: он только слушает сигнал combat.attack_started и смотрит, кто стоит под ударом.

const MODELS := "res://assets/golda67/"
const GREET_R := 4.6           # с какого расстояния здороваются
const HIT_R := 2.1             # дальше удар по мирному не считается
const FIGHT_R := 24.0          # бой ближе — уходят
const WALK := 1.15             # м/с, шаг
const RUN := 3.4               # м/с, бегство
const COLD_AT := 3             # столько ударов по мирным за забег — район здоровается холодно

## Пол для будущей озвучки (только Voice Studio Pro): m / f. Голоса не созданы — реплики идут пузырём.
const GENDER := {"BB": "f", "ZW": "f", "VW": "f", "TX": "m", "US": "m", "SC": "m", "Z1": "m", "Z2": "m", "DV": "m", "PT": "m", "ZH": "m"}

## temper: scold — ругает и стоит; flee — убегает; push — отталкивает; freeze — закрывается и молчит; film — снимает на телефон; laugh — смеётся
const FOLK := [
	{"id": "bab_bench", "code": "BB", "model": "g67_npc_babushka", "h": 1.5, "at": [-2.0, -104.4], "look": [-6.0, -98.0], "base": "NBag", "alts": ["NBagRest", "NScarf"], "temper": "scold", "turn": 1.0,
		"greet": ["BB|Пахан, шапку надень. Уши отморозишь — чем слушать будешь?", "BB|Опять на район? Смотри там, Миша сегодня не в духе."],
		"hit": ["BB|Ах ты ирод! Я твою мать с пелёнок знаю!", "BB|Милицию вызову! И маме твоей позвоню!"], "cold": ["BB|Иди-иди. Руки он распускает."], "fight": ["BB|Опять дерутся. Господи, прости."]},
	{"id": "bab_bag", "code": "BB", "model": "g67_npc_babushka", "h": 1.46, "tint": Color(0.82, 0.9, 1.0), "at": [-14.0, -93.5], "walk": [[-14.0, -93.5], [-34.0, -89.6]], "base": "NBag", "alts": ["NBagRest"], "temper": "scold", "turn": 1.0, "clip_walk": "NWalkBag",
		"greet": ["BB|На рынке тряпки дают. Беги, пока не разобрали.", "BB|Скользко-то как. Дворник наш опять философствует, а не чистит."],
		"hit": ["BB|Сумку! Сумку не трожь, там яйца!", "BB|Совсем молодёжь озверела!"], "cold": ["BB|Не подходи ко мне."], "fight": ["BB|Пойду-ка я другой дорогой."]},
	{"id": "school_phone", "code": "SC", "model": "g67_npc_schoolboy", "h": 1.28, "at": [6.4, -80.0], "look": [2.0, -84.0], "base": "NPhone", "alts": ["NStrap", "NStraps"], "temper": "flee",
		"greet": ["SC|Дядь Пахан, а правда, что вы Мишу сто раз уже били?", "SC|У нас физру отменили. Физрук в Подземке застрял."],
		"hit": ["SC|Ай! Я всё папе расскажу!", "SC|За что?! Я ж ничего!"], "cold": ["SC|Я с вами не разговариваю."], "fight": ["SC|О, махач! Только я отойду."]},
	{"id": "school_fan", "code": "SC", "model": "g67_npc_schoolboy", "h": 1.32, "tint": Color(1.0, 0.86, 0.8), "at": [-10.0, 104.0], "look": [6.0, 111.0], "base": "NFilm", "alts": ["NStrap"], "temper": "flee",
		"greet": ["SC|Я всё снимаю. Если Миша вас уронит — будет миллион просмотров.", "SC|Тише! Миша разминается."],
		"hit": ["SC|Телефон! Телефон не трогайте!", "SC|Это тоже снято, между прочим!"], "cold": ["SC|Вас я тоже снял. Как вы людей бьёте."], "fight": ["SC|Снимаю-снимаю, только издалека."]},
	{"id": "taxi_stop", "code": "TX", "model": "g67_npc_taxi_driver", "h": 1.7, "at": [50.0, -21.4], "look": [44.0, -30.0], "base": "NTaxiPhone", "alts": ["NCarLean", "NSmoke"], "temper": "film",
		"greet": ["TX|До Подземки не повезу. Туда вход платный, а выезд — вообще по записи.", "TX|Командир, куда едем? Никуда? Ну стой, грейся."],
		"hit": ["TX|Э! Ты номер мой запомни, я твой уже запомнил!", "TX|Всё, снимаю. В чат района пойдёт."], "cold": ["TX|С такими не езжу."], "fight": ["TX|Счётчик выключил, сам отъехал."]},
	{"id": "ushanka_gsk", "code": "US", "model": "g67_npc_ushanka", "h": 1.72, "at": [-66.0, 38.0], "look": [-60.0, 30.0], "base": "NPocketsSide", "alts": ["NSmoke", "NCross", "NIdleL"], "temper": "push",
		"greet": ["US|В сорок пятый не лезь. Там хозяин с девяносто восьмого не появлялся, и правильно делал.", "US|Балон у тебя хороший. Тяжёлый. Уважаю тяжёлое."],
		"hit": ["US|Ты чё, попутал?! Я тебя сам щас подкачаю!", "US|Руки убрал! Здесь гаражи, а не ринг!"], "cold": ["US|Проходи. Не о чем нам."], "fight": ["US|Ворота прикрою. От греха."]},
	{"id": "dvornik", "code": "DV", "model": "g67_npc_ushanka", "h": 1.68, "tint": Color(1.0, 0.78, 0.5), "at": [15.0, -70.0], "walk": [[15.0, -70.0], [20.0, -44.0]], "base": "NHips", "alts": ["NThink", "NSmoke"], "temper": "laugh",
		"greet": ["DV|Снег — он как долг. Убрал, а он опять лежит.", "DV|Ты ходи, ходи. Натопчешь — мне меньше чистить."],
		"hit": ["DV|Ха! По мне лопатой били — и то ничего.", "DV|Бей-бей. Снег от этого не растает."], "cold": ["DV|Мусор я убираю. С мусором не здороваюсь."], "fight": ["DV|После вас опять подметать."]},
	{"id": "smoker_69", "code": "Z2", "model": "g67_npc_taxi_driver", "h": 1.74, "tint": Color(0.75, 0.82, 0.95), "at": [-10.0, -39.6], "look": [-6.0, -30.0], "base": "NSmoke", "alts": ["NCross", "NThink"], "temper": "push",
		"greet": ["Z2|Сигареты есть? А если найду?.. Шучу. Нету у тебя.", "Z2|Слышал, Виталик опять всем должен. Район держится на долгах."],
		"hit": ["Z2|Ты берега-то не путай!", "Z2|Ещё раз — и я твой балон в сугроб закопаю."], "cold": ["Z2|Отойди. Курю."], "fight": ["Z2|Докурю в подъезде."]},
	{"id": "shop_man", "code": "Z1", "model": "g67_npc_ushanka", "h": 1.76, "tint": Color(0.8, 1.0, 0.85), "at": [84.6, -46.0], "look": [78.0, -40.0], "base": "NPockets", "alts": ["NIdleL", "NThink"], "temper": "freeze",
		"greet": ["Z1|«Продукты 24» закрыты на учёт. Третий год учитывают.", "Z1|Я тут жду. Кого — уже не помню."],
		"hit": ["Z1|Не надо! Я просто стою!", "Z1|Всё, всё, ухожу, только не бей."], "cold": ["Z1|…"], "fight": ["Z1|Я ничего не видел."]},
	{"id": "queue_w", "code": "ZW", "model": "g67_npc_babushka", "h": 1.56, "tint": Color(1.0, 0.85, 0.95), "at": [47.4, -15.4], "look": [44.0, -11.0], "base": "NMenu", "alts": ["NBagRest", "NScarf"], "temper": "scold",
		"greet": ["ZW|За мной будешь. Я здесь с обеда стою.", "ZW|Шаурма у него хорошая. Но вчера была лучше."],
		"hit": ["ZW|Хам! В очереди толкаться!", "ZW|Мужчина! Тут женщину бьют!"], "cold": ["ZW|Этого без очереди не пускать."], "fight": ["ZW|Очередь я запомнила, вернусь."]},
	{"id": "queue_m", "code": "Z1", "model": "g67_npc_taxi_driver", "h": 1.72, "tint": Color(0.95, 0.9, 0.75), "at": [41.2, -15.8], "look": [44.0, -11.0], "base": "NOrder", "alts": ["NEat", "NPockets"], "temper": "push",
		"greet": ["Z1|Мне двойную. Нет, тройную. Нет, давай как вчера.", "Z1|Ты за шаурмой? Бери с собой, Миша ждать не любит."],
		"hit": ["Z1|Э, полегче! Я соус пролил!", "Z1|Ты мне за шаурму теперь должен!"], "cold": ["Z1|Не стой рядом."], "fight": ["Z1|С шаурмой не дерутся."]},
	{"id": "tyre_man", "code": "US", "model": "g67_npc_ushanka", "h": 1.7, "tint": Color(0.7, 0.72, 0.8), "at": [84.0, -13.6], "look": [78.0, -20.0], "base": "NCross", "alts": ["NSmoke", "NHips"], "temper": "laugh",
		"greet": ["US|Шиномонтаж и кафе. Одной тряпкой и колёса, и столы.", "US|Балон подкачать? У меня компрессор с характером."],
		"hit": ["US|Ой, напугал. Меня домкратом прижимало.", "US|Ты бей ровнее, а то балансировку собьёшь."], "cold": ["US|Тебе не накачаю."], "fight": ["US|Кафе закрыто. Шиномонтаж тоже."]},
	{"id": "watch_79", "code": "VW", "model": "g67_npc_babushka", "h": 1.6, "tint": Color(0.86, 1.0, 0.88), "at": [28.0, 59.6], "look": [20.0, 52.0], "base": "NScarf", "alts": ["NBag", "NBagRest"], "temper": "scold", "turn": 1.2,
		"greet": ["VW|В семьдесят девятый не пущу. К кому? Нет таких.", "VW|Смотрящий ваш на диване сидит. Диван, между прочим, из моего подъезда."],
		"hit": ["VW|Я сорок лет на вахте! Меня генералы боялись!", "VW|Фамилия! Квартира! Записываю!"], "cold": ["VW|Записан. Всё про тебя записано."], "fight": ["VW|Дверь закрою на оба замка."]},
	{"id": "school_stadium", "code": "SC", "model": "g67_npc_schoolboy", "h": 1.24, "tint": Color(0.85, 0.95, 1.0), "at": [-36.0, 99.4], "walk": [[-36.0, 99.4], [-18.0, 97.6]], "base": "NStraps", "alts": ["NPhone"], "temper": "flee",
		"greet": ["SC|На стадион нельзя, там старшаки. А в коробку — тем более.", "SC|Дядь, дай балон подержать! Ну на секунду!"],
		"hit": ["SC|Мама-а!", "SC|Я маленький, меня нельзя!"], "cold": ["SC|Вы плохой."], "fight": ["SC|Бежим!"]},
]

## Торговцы: в забеге один из двух (run["trader"]). Модели — временные: существующие жители с другим оттенком.
const TRADERS := {
	"petrovich": {"code": "PT", "title": "ПЕТРОВИЧ", "model": "g67_npc_ushanka", "h": 1.74, "tint": Color(0.62, 0.56, 0.5), "at": [-54.6, 20.0], "look": [-48.0, 20.0], "base": "NHips", "alts": ["NThink", "NCross"],
		"hello": ["PT|Заходи. Что разболталось?", "PT|Опять ты. Десятку мою не видел?"], "show": ["PT|Вот это — на руку. Вот это — на спину. А это вообще на всю жизнь."],
		"buy": ["PT|Держи. Гарантия — пока не сломается.", "PT|Подтянул. Теперь не разболтается. Ну, не сразу."], "poor": ["PT|Это не цена, это себестоимость. Приходи, как наскребёшь."],
		"fight": ["PT|Ворота закрыл. Меня нет."], "bye": ["PT|Давай. И не бей этим по железу. По людям — можно."], "hit": ["PT|Ты чего?! Всё, закрыто. Иди отсюда, пока ключ на тридцать два не достал."], "closed": "Петрович закрыл ворота: «Сегодня без меня»"},
	"zhora": {"code": "ZH", "title": "ЖОРА-ПЕРЕКУП", "model": "g67_npc_taxi_driver", "h": 1.78, "tint": Color(0.42, 0.4, 0.44), "at": [94.6, 41.0], "look": [99.0, 37.0], "base": "NCarLean", "alts": ["NTaxiPhone", "NPockets"],
		"hello": ["ZH|Тихо. Ты один? Точно один? Подходи.", "ZH|О, постоянный. Для постоянных у меня отдельный багажник. Шучу. Один он."], "show": ["ZH|Последнее. Вот прям последнее. Вчера было два."],
		"buy": ["ZH|Это — для своих. Ты свой? Ну вот и будешь."], "poor": ["ZH|Без денег я только здороваюсь."],
		"fight": ["ZH|Меня тут не было."], "bye": ["ZH|Ты меня не видел. Я тебя — тем более."], "hit": ["ZH|Понял. Багажник закрыт. И ты меня точно не видел."], "closed": "Жора захлопнул багажник и сидит в машине"},
}

var G: Golda67
var dv: G67Dvor2
var folk: Array = []            # житель: {d, rig, life, home, yaw, state, t, cd, hit_cd, route_i, dest}
var trader := {}                # тот же вид записи + who
var log: Array = []             # для проверок: [вид, id]
var _atk_t := -1.0

func setup(g67: Golda67) -> void:
	G = g67
	dv = G.world.dvor
	for d_v in FOLK:
		var d: Dictionary = d_v
		var f := _spawn(d, String(d["id"]))
		if not f.is_empty():
			folk.append(f)
	var who := String(G.run.get("trader", ""))
	if TRADERS.has(who):
		var td: Dictionary = TRADERS[who]
		trader = _spawn(td, who)
		if not trader.is_empty():
			trader["who"] = who
			G.world._point("trader_dv", String(td["title"]), "посмотреть товар", (trader["home"] as Vector3) + _dir(float(trader["yaw"])) * 1.3)
	var cb = G.game.player.combat
	if cb != null and not cb.attack_started.is_connected(_on_attack):
		cb.attack_started.connect(_on_attack)

static func _dir(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))

func _spawn(d: Dictionary, key: String) -> Dictionary:
	var path := MODELS + String(d["model"]) + ".glb"
	if not ResourceLoader.exists(path):
		return {}
	var at: Array = d["at"]
	var home := G67Dvor2.to3(float(at[0]), float(at[1]), 0.02)
	var yaw := 0.0
	if d.has("look"):
		var lk: Array = d["look"]
		var to := G67Dvor2.to3(float(lk[0]), float(lk[1])) - home
		yaw = atan2(to.x, to.z)
	var r := Rig.new()
	add_child(r)
	r.setup(path, float(d["h"]), G67Poses.clips(), true, 1.0, String(d["model"]) + "_yd")
	r.position = home
	r.rotation.y = yaw
	if d.has("tint"):
		_tint(r, d["tint"])
	var pf := {"base": d.get("base", "Idle"), "alts": d.get("alts", []), "turn": d.get("turn", 1.8), "look_r": 8.0}
	var life := G67Life.attach(r, pf, hash(key))
	if life != null:
		life.watcher = G.game.player
	# тело: герой не проходит сквозь жителя
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = float(d["h"])
	cs.shape = cap
	cs.position.y = float(d["h"]) * 0.5
	sb.add_child(cs)
	r.add_child(sb)
	return {"d": d, "id": key, "rig": r, "life": life, "home": home, "yaw": yaw, "state": "stay", "t": 0.0, "cd": randf_range(2.0, 9.0), "hit_cd": 0.0, "route_i": 0, "dest": home, "hits": 0,
		"wait": randf_range(4.0, 10.0)}

func _tint(n: Node, col: Color) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		for s in mi.get_surface_override_material_count():
			var m: Material = mi.get_active_material(s)
			if m is BaseMaterial3D:
				var m2: BaseMaterial3D = m.duplicate()
				m2.albedo_color = (m2.albedo_color * col).clamp()
				mi.set_surface_override_material(s, m2)

func _all() -> Array:
	return folk + ([trader] if not trader.is_empty() else [])

func _say(f: Dictionary, key: String, force := false) -> bool:
	var arr: Array = (f["d"] as Dictionary).get(key, [])
	if arr.is_empty():
		return false
	var b := G.barks_get()
	return b.say(f["rig"], b.pick(String(f["id"]) + key, arr), {"force": force, "fight": key in ["fight", "hit"]})

## Сдача: кто бьёт в ответ и на сколько. «push» (мужики) — сразу, «scold» (бабки, тётки) — со второго удара, сумкой.
## Остальные характеры (убегают, замирают, снимают, смеются) не дерутся. Урон проходит мимо блока, убить не может.
const HIT_BACK := {"push": 9.0, "scold": 5.0}
const HIT_BACK_T := 0.55
const HIT_BACK_R := 2.4

func _back_tick(dt: float) -> void:
	for f in _all():
		if float(f.get("back_t", 0.0)) <= 0.0:
			continue
		f["back_t"] = float(f["back_t"]) - dt
		if float(f["back_t"]) > 0.0:
			continue
		var r: Rig = f["rig"]
		var p = G.game.player
		var to: Vector3 = p.global_position - r.global_position
		to.y = 0.0
		if to.length() > HIT_BACK_R or String(p.state) in ["roll", "airdash"]:
			log.append(["back_miss", String(f["id"])])
			continue
		r.rotation.y = atan2(to.x, to.z)
		var dmg: float = minf(float(f["back_dmg"]), maxf(0.0, p.hp - 1.0))
		p.take_damage(dmg, r.global_position, null, {"unblockable": true})
		G.game.fx.dust(p.global_position + Vector3(0, 1.0, 0), 5, G.game.fx.DUST, 0.5)
		G.game.popup(p.global_position + Vector3(0, 2.2, 0), "СДАЧА", Color(1.0, 0.6, 0.3))
		G.events.append(["npc_back", String(f["id"]), dmg])
		log.append(["back", String(f["id"]), dmg])

## Что район запомнил за забег: влез без очереди, обидел Гену, заступился за школьника или прошёл мимо. Каждый скажет один раз.
const NOTES := {"queue_cut": "Это тот, без очереди.", "gena_hurt": "Это тот, что Гену обидел. Гена, между прочим, всему дому дорожку чистит.",
	"kid_saved": "Это он! Он за Лёху заступился!", "kid_passed": "Видела я, как ты мимо мальчонки прошёл. Глазастый, да не туда."}
const NOTE_WHO := {"queue_cut": ["BB", "ZW", "Z1"], "gena_hurt": ["BB"], "kid_saved": ["SC"], "kid_passed": ["BB", "BZ"]}

func _note(f: Dictionary) -> bool:
	var code := String((f["d"] as Dictionary).get("code", ""))
	for k in NOTES:
		if not bool(G.run.get(k, false)) or not (NOTE_WHO[k] as Array).has(code) or bool(f.get("note_" + String(k), false)):
			continue
		if k == "queue_cut" and (f["home"] as Vector3).distance_to(G67Dvor2.to3(-30.0, -13.0)) > 60.0:
			continue
		f["note_" + String(k)] = true
		return G.barks_get().say(f["rig"], code + "|" + String(NOTES[k]), {"force": true})
	return false

func cold() -> bool:
	return int(G.run.get("npc_hits", 0)) >= COLD_AT

func trader_closed() -> bool:
	return bool((G.run.get("trade", {}) as Dictionary).get("closed", false))

# ------------------------------------------------------------------ удар по мирному
func _on_attack(_a) -> void:
	_atk_t = 0.16            # проверяем чуть позже начала замаха — когда удар доходит

func _strike() -> void:
	var p = G.game.player
	var pp: Vector3 = p.global_position
	var fw := _dir(float(p.face))
	var foe_d := 99.0             # ближайший настоящий враг под ударом: если он ближе жителя — удар предназначен ему
	for e in G.game.enemies:
		if is_instance_valid(e) and e.alive():
			var te: Vector3 = e.global_position - pp
			te.y = 0.0
			if te.length() < 3.0 and te.normalized().dot(fw) > 0.25:
				foe_d = minf(foe_d, te.length())
	for f in _all():
		var r: Rig = f["rig"]
		var to: Vector3 = r.global_position - pp
		to.y = 0.0
		if to.length() > HIT_R or to.length() > foe_d or to.normalized().dot(fw) < 0.25 or float(f["hit_cd"]) > 0.0:
			continue
		_hit(f, to.normalized())

## Ударили жителя: реакция по характеру. Ни урона, ни смерти, ни наград.
func _hit(f: Dictionary, away: Vector3) -> void:
	var d: Dictionary = f["d"]
	f["hit_cd"] = 1.2
	f["hits"] = int(f["hits"]) + 1
	G.run["npc_hits"] = int(G.run.get("npc_hits", 0)) + 1
	G.events.append(["npc_hit", String(f["id"])])
	log.append(["hit", String(f["id"])])
	G.game.fx.dust((f["rig"] as Rig).global_position + Vector3(0, 0.9, 0), 4, G.game.fx.DUST, 0.5)
	_say(f, "hit", true)
	var back: float = float(HIT_BACK.get(String(d.get("temper", "")), 0.0))
	if back > 0.0 and (String(d.get("temper", "")) != "scold" or int(f["hits"]) >= 2):
		f["back_t"] = HIT_BACK_T                 # замах: ответит, если герой не отошёл
		f["back_dmg"] = back
	var life: G67Life = f["life"]
	if f.has("who"):
		var tr: Dictionary = G.run.get("trade", {})
		tr["closed"] = true
		G.run["trade"] = tr
		if life != null:
			life.stage("NCross", 0.15)
		f["state"] = "sulk"
		f["t"] = 9999.0
		return
	match String(d.get("temper", "scold")):
		"flee":
			_go(f, (f["home"] as Vector3) + away * 13.0, RUN, "away", 16.0)
		"push":
			var p = G.game.player
			p.velocity = -away * 7.0 + Vector3(0, 2.0, 0)      # толчок, без урона
			if life != null:
				life.stage("NHips", 0.12)
			f["state"] = "sulk"
			f["t"] = 4.0
		"freeze":
			if life != null:
				life.stage("NCross", 0.12)
			f["state"] = "sulk"
			f["t"] = 7.0
		"film":
			if life != null:
				life.stage("NFilm", 0.15)
			f["state"] = "sulk"
			f["t"] = 8.0
		"laugh":
			if life != null:
				life.stage("NThink", 0.15)
			f["state"] = "sulk"
			f["t"] = 3.0
		_:                      # scold: первый раз стоит и ругает, со второго — отходит
			if int(f["hits"]) >= 2:
				_go(f, (f["home"] as Vector3) + away * 8.0, WALK * 1.4, "away", 14.0)
			else:
				if life != null:
					life.stage("NPoint", 0.15)
				f["state"] = "sulk"
				f["t"] = 4.0

func _go(f: Dictionary, to: Vector3, spd: float, state: String, hold: float) -> void:
	to.y = (f["home"] as Vector3).y
	f["dest"] = to
	f["spd"] = spd
	f["state"] = state
	f["t"] = hold
	var life: G67Life = f["life"]
	if life != null:
		life.stage(String((f["d"] as Dictionary).get("clip_walk", "NWalk")), 0.2)

func _back(f: Dictionary) -> void:
	var life: G67Life = f["life"]
	if life != null:
		life.resume()
	(f["rig"] as Rig).rotation.y = float(f["yaw"])
	f["state"] = "stay"
	f["wait"] = randf_range(6.0, 12.0)

## Шаг к цели по прямой; true — дошёл
func _step(f: Dictionary, dt: float) -> bool:
	var r: Rig = f["rig"]
	var to: Vector3 = (f["dest"] as Vector3) - r.position
	to.y = 0.0
	var st: float = float(f.get("spd", WALK)) * dt
	if to.length() <= st:
		r.position = f["dest"]
		return true
	r.position += to.normalized() * st
	r.rotation.y = lerp_angle(r.rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * dt))
	return false

func _physics_process(dt: float) -> void:
	if G == null or not is_instance_valid(G.game) or G.place != "run":
		return
	_back_tick(dt)
	if _atk_t >= 0.0:
		_atk_t -= dt
		if _atk_t < 0.0:
			_strike()
	var pp: Vector3 = G.game.player.global_position
	var fight: bool = G.room_state == "fight" and G.turf != null and not G.turf.active.is_empty()
	var fc: Vector3 = (G.turf.active["c"] as Vector3) if fight else Vector3.ZERO
	for f in _all():
		var r: Rig = f["rig"]
		f["hit_cd"] = maxf(0.0, float(f["hit_cd"]) - dt)
		f["cd"] = maxf(0.0, float(f["cd"]) - dt)
		var st := String(f["state"])
		var is_tr: bool = f.has("who")
		# драка рядом: житель уходит, торговец закрывается на время боя
		if fight and st in ["stay", "walk", "pause"] and r.global_position.distance_to(fc) < FIGHT_R:
			_say(f, "fight")
			log.append(["hide", String(f["id"])])
			if is_tr:
				f["state"] = "shut"
			else:
				var away: Vector3 = r.global_position - fc
				away.y = 0.0
				away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
				_go(f, r.position + away * 11.0, RUN * 0.8, "hide", 0.0)
			continue
		match st:
			"stay":
				if not is_tr and (f["d"] as Dictionary).has("walk"):
					f["wait"] = float(f["wait"]) - dt
					if float(f["wait"]) <= 0.0:
						var route: Array = (f["d"] as Dictionary)["walk"]
						f["route_i"] = (int(f["route_i"]) + 1) % route.size()
						var w: Array = route[int(f["route_i"])]
						_go(f, G67Dvor2.to3(float(w[0]), float(w[1])), WALK, "walk", 0.0)
						continue
				if float(f["cd"]) <= 0.0 and r.global_position.distance_to(pp) < GREET_R:
					if _note(f) or _say(f, "cold" if (cold() and not is_tr) else ("hello" if is_tr else "greet")):
						f["cd"] = randf_range(22.0, 40.0)
						log.append(["greet", String(f["id"])])
					else:
						f["cd"] = 3.0
			"walk":
				if r.global_position.distance_to(pp) < 1.6:
					continue               # герой на пути — ждёт, не толкается
				if _step(f, dt):
					f["home"] = f["dest"]
					f["yaw"] = r.rotation.y
					_back(f)
			"away", "sulk":
				if st == "away":
					_step(f, dt)
				f["t"] = float(f["t"]) - dt
				if float(f["t"]) <= 0.0:
					if st == "away":
						_go(f, f["home"], WALK, "return", 0.0)
					else:
						_back(f)
			"hide":
				_step(f, dt)
				if not fight:
					_go(f, f["home"], WALK, "return", 0.0)
			"return":
				if _step(f, dt):
					_back(f)
			"shut":
				if not fight:
					f["state"] = "stay"
