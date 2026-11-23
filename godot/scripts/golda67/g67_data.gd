## Данные приквела «ГОЛДА 67»: районы, комнаты, волны, фитсы, боссы. Новые числа и тексты — только сюда.
## Основа — godot/docs/golda67/SPEC.md (разделы 6, 7, 9, 10, 12) и LEVEL_DESIGN.md.
class_name G67Data
extends RefCounted

## Типы комнат (SPEC, раздел 9). Сделаны: BATTLE, ELITE, FIT, STORAGE, KIOSK, BREAK, BOSS. Не сделан: EVENT (этап 4).
const ROOM_NAMES := {"battle": "БОЙ", "ambush": "ЗАСАДА", "elite": "ЭЛИТА", "fit": "БАФ", "storage": "КЛАДОВКА", "kiosk": "ЛАРЁК", "break": "ПЕРЕДЫШКА", "boss": "БОСС", "event": "СОБЫТИЕ"}
const ROOM_HINT := {"battle": "голда и РЕСПЕКТ", "ambush": "голда и РЕСПЕКТ", "elite": "редкий баф, голда и РЕСПЕКТ", "fit": "баф на выбор", "storage": "артефакт: один из двух", "kiosk": "«ШАУРМА 67» за голду", "break": "восстановить здоровье", "boss": "Миша Минасян", "event": "необычное место двора"}
const ROOM_COLOR := {"battle": Color(0.95, 0.3, 0.25), "ambush": Color(0.95, 0.4, 0.3), "elite": Color(1.0, 0.55, 0.15), "fit": Color(1.0, 0.8, 0.2), "storage": Color(0.55, 0.75, 0.95), "kiosk": Color(0.95, 0.65, 0.3), "break": Color(0.45, 0.9, 0.55), "boss": Color(0.85, 0.15, 0.2), "event": Color(0.72, 0.58, 0.95)}

## Враги района: вид для ИИ (kind из enemy.KINDS) и облик (skin из enemy.SKINS)
const FOES := {
	"shest": {"kind": "bot", "skin": "g67_shest", "name": "Шестёрка", "golda": 4},
	"semka": {"kind": "hater", "skin": "g67_semka", "name": "Семечник", "golda": 5},
	"smotr": {"kind": "troll", "skin": "g67_smotr", "name": "Смотрящий", "golda": 18},
	# ПОДЗЕМКА (модели придут от владельца: g67_enemy_*.glb; пока заглушки на моделях двора)
	"controller": {"kind": "mod", "skin": "g67_pz_ctl", "name": "Контролёр", "golda": 8, "hp": 150.0, "dmg": 12.0, "bark": ["Z2", ["Ваш билет.", "Без билета не работаем.", "Проход по тарифу.", "Оформляем нарушение."]]},
	"promoter": {"kind": "farmer", "skin": "g67_pz_prm", "name": "Зазывала", "golda": 10, "hp": 90.0, "dmg": 8.0, "bark": ["SH", ["Акция! Только сегодня! Всегда!", "Первый проход почти бесплатный!", "Коллеги, тут безбилетный!"]],
		"moves": {"flyer": {"act": "zone", "w": 2.0, "cd": 4.0, "min": 3.0, "wind": 0.5, "rec": 0.6, "dmg": 1.0, "zr": 1.5, "delay": 0.7, "n": 1, "dmg_abs": 8.0, "slow": 1.5, "title": "ФЛАЕР"},
			"call": {"act": "summon", "w": 1.4, "cd": 12.0, "wind": 1.0, "rec": 0.8, "kinds": ["mod"], "n": 1, "cap": 2, "title": "КОЛЛЕГИ!"},
			"scare": {"act": "repel", "w": 6.0, "cd": 8.0, "max": 3.5, "cond": "close", "wind": 0.45, "rec": 0.2, "dmg": 0.0, "dmg_abs": 6.0, "r": 3.6, "title": "ОТСТУПЛЕНИЕ"}}},
	"bouncer": {"kind": "troll", "skin": "g67_pz_bnc", "name": "Вышибала турникета", "golda": 30, "hp": 520.0, "dmg": 22.0, "moves": {"punch": {"act": "melee", "w": 2.0, "max": 3.2, "wind": 0.95, "rec": 1.1, "dmg": 1.0, "r": 2.9, "half": 1.0}, "push": {"act": "slam", "w": 1.6, "cd": 5.0, "max": 3.4, "wind": 0.8, "rec": 1.2, "dmg": 0.8, "r": 3.0, "title": "ТОЛЧОК"}, "over": {"act": "slam", "w": 1.4, "cd": 7.0, "max": 3.4, "wind": 0.8, "rec": 1.4, "dmg": 1.2, "r": 3.2, "title": "СВЕРХУ"}, "rush": {"act": "charge", "w": 2.2, "cd": 8.0, "min": 4.0, "max": 14.0, "wind": 0.9, "rec": 1.4, "dmg": 1.0, "r": 9.0, "lane": 1.6, "speed": 11.0, "title": "РЫВОК"}}, "bark": ["US", ["Выход отдельно.", "Не положено.", "Створку не трогать."]]},
}

## Волны района 2 по индексу позиции (0…3 бой, элита — PZ_ELITE); в тоннеле не больше четырёх одновременно
const PZ_WAVES := {
	0: [[["controller", 2]], [["controller", 2], ["shest", 1]]],
	1: [[["controller", 2], ["promoter", 1]], [["controller", 3], ["promoter", 1]]],
	2: [[["controller", 2], ["promoter", 1]], [["controller", 3], ["promoter", 2]], [["bouncer", 1], ["controller", 1]]],
	3: [[["controller", 2], ["promoter", 2]], [["controller", 3], ["promoter", 1]], [["controller", 2], ["promoter", 2]]],
}
const PZ_ELITE := [[["bouncer", 1]], [["bouncer", 1], ["controller", 2]], [["controller", 2], ["promoter", 2]]]

## Район: семь этапов до босса включительно. Этап — один или два варианта, каждый вариант — настоящее место двора.
## routes — три шаблона забега (по номеру забега: runs % 3); route — первый из них (для совместимости).
## waves — волны по индексу этапа (0…5): список волн, волна — [[враг, сколько], …]
## Шесть позиций района (LEVEL_DESIGN, раздел 3): типы вариантов без конкретики; сами варианты строит Golda67.route_options
const POSITIONS := [[{"type": "battle"}], [{"type": "battle"}, {"type": "fit"}, {"type": "event"}], [{"type": "elite"}, {"type": "storage"}, {"type": "event"}],
	[{"type": "kiosk"}, {"type": "event"}, {"type": "battle"}], [{"type": "break"}], [{"type": "boss"}]]
const BATTLE_PLACES := ["garages", "parking", "playground"]
const TYPE_ZONES := {"battle": ["garages", "parking", "playground"], "elite": ["garages", "parking", "playground"], "fit": ["playground"], "storage": ["garages"],
	"kiosk": ["parking"], "break": ["gazebo"], "boss": ["sport"]}
## Плейлист «Любимые треки Пахана» (PLAYLIST.md): номер, исполнитель, название
const PLAYLIST := [[1, "3g0th2002", "Когда я вырасту"], [2, "LOVV66", "Не Дай Запомнить"], [3, "Toxi$, OG Buda", "BANDZ"], [4, "OG Buda", "6AM в Будапеште"],
	[5, "OG Buda, Платина", "YTPO"], [6, "cardinparis ft. lovv66", "красивое"], [7, "королевский XVII", "vivre sa vie"], [8, "Саби Учиха", "Шары"],
	[9, "pemfi", "династия madk1d (Ultra Slowed x Редакт)"], [10, "Джон Гарик", "Arctic Rose"], [11, "Aarne, VILLIAN", "Претендент На Убийство"], [12, "Eminem", "Deja Vu"],
	[13, "blink-182", "All The Small Things"], [14, "madk1d", "перестань"], [15, "Паша Техник, FEDUK", "ГУСЬ"], [16, "H", "кроты-хомяки"], [17, "OG Buda", "Форэн Кисуля Флоу 3"]]
const EVENTS_SHORT := ["burmalda", "button"]
## «Бурмалда»: веса исходов; голда — min…max; рывок: один бесплатно, ещё два по BURMALDA_COST
const BURMALDA := [
	{"id": "junk", "w": 34, "names": ["НОСОК БЕЗ ПАРЫ", "ЧЕК НА 0 ГОЛДЫ", "КРЫШКА ОТ КАСТРЮЛИ", "ПУЛЬТ ОТ НИЧЕГО"]},
	{"id": "gold", "w": 30, "min": 15, "max": 45},
	{"id": "heal", "w": 15, "heal": 30.0},
	{"id": "art", "w": 12},
	{"id": "fit", "w": 6},
	{"id": "rare_art", "w": 3},
]
const BURMALDA_COST := 25
## «Можно. А зачем?»: шесть исходов, равные веса, один и тот же не два забега подряд
const BUTTON := ["nothing", "lights", "alarms", "shawarma", "shock", "snow"]
const EVENT_DESC := {"rags": "Тряпки, швабра и сирена: дверь в квартиру за гаражами.", "burmalda": "Автомат во дворе: дёрнул рычаг — получил что-то. Или носок.", "button": "Красная кнопка под колпаком. Нажать можно. А зачем?"}
const EVENT_NAMES := {"rags": "ТРЯПКИ! ТРЯПКИ!", "burmalda": "БУРМАЛДА", "button": "МОЖНО. А ЗАЧЕМ?"}
const MUST := {"ev_rags": "rags"}

## Подпись этапа: тип · место (у события — его название)
static func stage_title(type: String, place: String, ev := "") -> String:
	if type == "event" and ev != "":
		return String(EVENT_NAMES.get(ev, "СОБЫТИЕ"))
	return "%s · %s" % [String(ROOM_NAMES.get(type, type)), String(G67District.zone_of(place)["name"]).to_upper()]

const ROUTES_DVOR := [
	[
		[{"type": "battle", "place": "podezd"}],
		[{"type": "battle", "place": "garages"}, {"type": "fit", "place": "playground"}],
		[{"type": "elite", "place": "parking"}, {"type": "storage", "place": "garages"}],
		[{"type": "battle", "place": "playground"}],
		[{"type": "battle", "place": "parking"}, {"type": "break", "place": "gazebo"}],
		[{"type": "ambush", "place": "proezd"}],
		[{"type": "boss", "place": "sport"}],
	],
	[
		[{"type": "battle", "place": "podezd"}],
		[{"type": "battle", "place": "parking"}, {"type": "storage", "place": "garages"}],
		[{"type": "elite", "place": "garages"}, {"type": "fit", "place": "playground"}],
		[{"type": "battle", "place": "playground"}],
		[{"type": "battle", "place": "garages"}, {"type": "break", "place": "gazebo"}],
		[{"type": "ambush", "place": "proezd"}],
		[{"type": "boss", "place": "sport"}],
	],
	[
		[{"type": "battle", "place": "podezd"}],
		[{"type": "battle", "place": "parking"}, {"type": "fit", "place": "playground"}],
		[{"type": "elite", "place": "garages"}, {"type": "storage", "place": "garages"}],
		[{"type": "battle", "place": "playground"}],
		[{"type": "battle", "place": "garages"}, {"type": "break", "place": "gazebo"}],
		[{"type": "ambush", "place": "proezd"}],
		[{"type": "boss", "place": "sport"}],
	],
]
## Район 2 «ПОДЗЕМКА»: шесть позиций (PODZEMKA_DESIGN.md, раздел 2); места подставляет pz_option
const ROUTES_PZ := [
	[{"type": "battle", "place": "gate1"}],
	[{"type": "battle", "place": "gallery"}, {"type": "fit", "place": "gallery"}],
	[{"type": "elite", "place": "cross"}, {"type": "storage", "place": "cross"}, {"type": "battle", "place": "cross"}],
	[{"type": "kiosk", "place": "arcade"}, {"type": "battle", "place": "arcade"}],
	[{"type": "break", "place": "staff"}],
	[{"type": "boss", "place": "arena"}],
]

const DISTRICTS := {
	"dvor": {
		"name": "ДВОР", "boss": "g67_misha", "unlock": "bottles", "flag": "boss_misha",
		"routes": ROUTES_DVOR,
		"route": ROUTES_DVOR[0],
		"waves": {
			0: [[["shest", 3]], [["shest", 2], ["semka", 1]]],
			1: [[["shest", 3], ["semka", 1]], [["shest", 3], ["semka", 2]]],
			2: [[["smotr", 1], ["shest", 2]], [["shest", 2], ["semka", 2]]],
			3: [[["shest", 4], ["semka", 1]], [["shest", 3], ["semka", 2]]],
			4: [[["shest", 4], ["semka", 2]], [["shest", 4], ["semka", 2]], [["shest", 2], ["semka", 3]]],
			5: [[["shest", 3], ["semka", 1]], [["shest", 2], ["semka", 1]]],
		},
	},
	"podzemka": {
		"name": "ПОДЗЕМКА", "boss": "g67_fortuna", "unlock": "tyaga812", "flag": "boss_fortuna",
		"routes": ROUTES_PZ,
		"route": ROUTES_PZ[0],
		"music": "loc_g67_podzemka",
		"waves": {},      # TODO этап 3: свои волны (Контролёр, Зазывала, Вышибала); пока состав двора (WAVES_*)
	},
}

## Босс первого района. Формат — как у боссов кампании (story.json → BOSS): его читает enemy._setup_boss.
## Приёмы фаз — существующие приёмы боссов; свой особый приём — enemy._special («РАЗМАХ ЦЕПЬЮ»).
const BOSSES := {
	"g67_fortuna": {      # этап 5а: настоящий бой (golda67/g67_fortuna.gd, арена — g67_fortuna_arena.gd); здоровье 3000 на старт замера
		"n": "FORTUNA 812", "sub": "владелец турникетов", "sp": "FT", "hp": 2400, "r": 30, "spd": 104, "c": "#3fa34d", "dmg": 6, "gap": 1.8, "xp": 0, "armor": 0.45,      # ослаблен 2026-11-24 по решению владельца: было 3600 / 7 / 0,35 — бот-клавишник не выигрывал
		 "antract": false,
		"poise": 320, "gate": true,
		"phases": [["f_gates", "f_zone", "f_check", "f_change", "f_consult"], ["f_gates", "f_zone", "f_check", "f_change", "f_consult"], ["f_gates", "f_zone", "f_check", "f_change", "f_consult"]],
		"barks": ["Оплата на месте.", "Вводим повышенный тариф.", "Что с турникетами?! Они же на гарантии!"],
	},
	"g67_misha": {
		"n": "МИША МИНАСЯН", "sub": "главный авторитет двора", "sp": "G1", "hp": 2600, "r": 30, "spd": 116, "c": "#d9a23a", "dmg": 7, "gap": 1.6, "xp": 0, "armor": 0.7, "antract": true,      # armor — множитель урона по нему вне окон «ОТКРЫТ»
		"poise": 320, "gate": true,      # фазы не проскакивают (enemy._phase_shift); равновесие выше, чем у остальных боссов
		"phases": [["m_grab", "slam", "m_hook", "charge"], ["m_guard", "shock", "m_grab", "charge", "m_hook", "slam"], ["m_hook", "leap", "m_guard", "charge", "m_grab", "shock", "slam"]],
		"barks": ["", "Мне даже олимпийка не нужна, чтобы быть главным.", "Это не цепь зацепилась. Это контроль пространства."],
	},
}
## Фраза Миши на выходе с трона (её же озвучивает G67Voice)
const BOSS_INTRO := "На этом районе уважают только сильнейших."
const SPEAKERS := {"G1": {"n": "МИША МИНАСЯН", "c": "#d9a23a"}, "KR": {"n": "КРОТ", "c": "#c9a36b"}, "DJ": {"n": "DJ FLÜRR", "c": "#3fc7c9"}}

## madk1d в приквеле закрыт до первой сюжетной концовки (победа над Полковником Бустеренко): до неё игрок управляет
## только Паханом — нет смены героя (Tab), дуэта (T), Team Hype и Overdrive (G), ад-либа madk1d (Q). madk1d может быть
## в сценах и стоять рядом как житель. Флаг ставит первая концовка; уже открытое в сохранении не закрывается.
const MADK_FLAG := "ending1"
const MADK_LOCKED := "madk1d откроется после первой концовки — победы над Полковником Бустеренко"

## DJ FLÜRR, знакомство после уже найденного КРОТА (решение владельца): первые FLURR_INTRO реплик знакомства,
## затем связка, затем сразу диалог текущего состояния. Старые подсказки не звучат, пропущенные уходят в архив.
const FLURR_INTRO := 4
const FLURR_BRIDGE := "DJ|А ты, я слышал, уже с КРОТОМ пересёкся."

## КРОТ — десять обязательных встреч (SPEC, раздел 15). Реплики — дословно по ТЗ, менять нельзя.
## where: "hub" или зона двора; pos — место (в хабе — координаты подъезда, во дворе — координаты двора G67Yard);
## needs — модель, без которой сцену не поставить (пока её нет, встреча ждёт и не пропадает).
## talk — где встать, чтобы заговорить (по умолчанию — перед ним; у ларька он стоит лицом к окошку, подходят сбоку).
## pose — его поза на встрече (G67Poses.krot), talk_clip — пока говорит он, acts — жест на реплике с этим номером
## (строка — клип до следующего жеста, [клип, с] — короткий жест и обратно), after — после разговора: stay (остаётся
## в своей позе, говорить больше не о чем), walk (уходит, унося вещь). feed — бросает корм, голуби подбегают.
## Встречи идут по порядку: следующая появляется только после предыдущей. Увиденные — meta["seen"].
## Встреча во дворе не теряется: пока она не пройдена, маршрут забега обязательно ведёт в её зону (Golda67.route_options).
const KROT := [
	{"id": "krot1", "title": "ДРУЗЬЯ ИЗ FORBES", "where": "parking", "pos": Vector3(36.85, 0, 7.1), "yaw": PI * 0.5, "talk": Vector3(-0.3, 0, 1.3), "needs": "",
		"pose": "K1", "talk_clip": "K1Talk", "acts": {0: ["K1Nod", 1.0], 4: "K1"}, "after": "stay",
		"lines": ["KR|Пахан, брат, я тебе говорил, что у меня знакомые в Forbes?", "V|Нет.",
			"KR|Ну вот. Они мне вчера звонили, предлагали войти в список. Я отказался, у меня дела были.", "V|Какие нахуй дела?",
			"KR|Да я в очереди за шаурмой стоял. Там нельзя было выходить, я уже был следующий."]},
	{"id": "krot2", "title": "ЛЮСТРА", "where": "hub", "pos": Vector3(0.9, 0, 2.6), "yaw": 0.0, "needs": "g67_chandelier", "carry": "g67_chandelier",
		"pose": "K2", "talk_clip": "K2Look", "acts": {3: "K2Show"}, "after": "walk",
		"lines": ["V|Ты чё делаешь?", "KR|Люстру снимаю.", "V|ЗАЧЕМ?!", "KR|Она на меня странно смотрела."]},
	{"id": "krot3", "title": "ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО", "where": "playground", "pos": Vector3(-9.4, 0, -10.2), "yaw": 1.1, "needs": "g67_pigeon", "pigeons": 5,
		"pose": "K3", "talk_clip": "K3", "acts": {2: "K3Point"}, "after": "stay", "feed": true,
		"lines": ["KR|Пахан, ты вообще понимаешь, кто тут главный?", "V|Ты?", "KR|Нет, голубь справа. У него три квартиры и доступ к администрации.",
			"V|Ты опять хуйню несёшь.", "KR|Тихо, он слышит. У него рилсы сливают."]},
	{"id": "krot4", "title": "NPC", "district": "podzemka", "where": "gallery", "pos": Vector3(9.3, 0, -74.2), "yaw": PI * 0.5, "talk": Vector3(-1.3, 0, 0.2), "needs": "",
		"pose": "K4", "talk_clip": "K4Nod", "acts": {1: ["K4Nod", 1.0]}, "after": "stay", "coin": 4, "sign": "ЗАДАНИЕ: НАЙТИ 5 РУБЛЕЙ",
		"lines": ["V|Ты чё застыл?", "KR|Брат, я сегодня NPC.", "V|Чего?", "KR|У меня квест. Нужно найти пять рублей. Без этого я не могу выйти из магазина.",
			"V|Держи пять рублей.", "KR|Спасибо, легенда. Новое задание доступно через 24 часа."]},
	{"id": "krot5", "title": "АБСОЛЮТНО ТРЕЗВЫЙ", "district": "podzemka", "where": "arcade", "pos": Vector3(-41.7, 0, -110.6), "yaw": PI * 0.5, "talk": Vector3(0.2, 0, 1.2), "needs": "",
		"pose": "K5", "talk_clip": "K5Nod", "acts": {2: "K5Finger"}, "after": "stay", "cut": 2, "ding": 4,
		"lines": ["KR|Брат, я сегодня вообще трезвый. Даже мысли трезвые.", "V|Я ничего не спрашивал.", "KR|Я просто хотел сказать, что вчера выиграл у микроволновки в шахматы.",
			"V|Как можно выиграть у микроволновки в шахматы?", "KR|Она сдалась. Начала крутить."]},
]


## Фитсы (SPEC, раздел 10). Пока одно семейство — МИША МИНАСЯН: сила, авторитет, тяжёлые удары, бонусы за добивания.
## Эффекты — числа, которые читает Golda67 (apply_fits, on_kill, _second_wind); исходные данные стилей не меняются.
## lv — на сколько уровней можно улучшить (повторный выбор того же фитса).
const FITS := {
	"heavy_hand": {"family": "misha", "name": "ТЯЖЁЛАЯ РУКА", "desc": "Весь урон +12% за уровень.", "lv": 3, "rare": false},
	"authority": {"family": "misha", "name": "АВТОРИТЕТ", "desc": "Максимум здоровья +20 за уровень, сразу лечит на столько же.", "lv": 3, "rare": false},
	"gold_chain": {"family": "misha", "name": "ЦЕПЬ НА УДАЧУ", "desc": "Голды с врагов и комнат +25% за уровень.", "lv": 3, "rare": false},
	"finisher": {"family": "misha", "name": "ДОБИВАЛА", "desc": "Поверженный враг лечит на 3 / 6 / 9 (элитный — втрое), не больше 25 / 40 / 55 за комнату; босс и призванные не считаются.", "lv": 3, "rare": false},
	"cashback": {"family": "fortuna", "name": "КЭШБЭК", "desc": "8 / 14 / 20 % потраченной в ларьке голды возвращается.", "lv": 3, "rare": false},
	"spare_change": {"family": "fortuna", "name": "СДАЧА", "desc": "Каждый 5-й / 4-й / 3-й поверженный враг роняет ещё 4 голды.", "lv": 3, "rare": false},
	"refill": {"family": "fortuna", "name": "ДОЛИВ", "desc": "Попадание бутылкой с шансом 15 / 25 / 35 % возвращает бутылку в запас.", "lv": 3, "rare": false},
	"tariff": {"family": "fortuna", "name": "ТАРИФ «ВСЁ ВКЛЮЧЕНО»", "desc": "+1 бутылка к запасу за уровень; до открытия Водяры — +6 % урона за уровень.", "lv": 3, "rare": false},
	"receipt": {"family": "fortuna", "name": "ДЛИННЫЙ ЧЕК", "desc": "За каждые 25 голды при себе +3 % / +5 % урона, не больше +30 %.", "lv": 2, "rare": true},
	"ded_jacket": {"family": "dvor", "name": "ДЕДОВСКАЯ КУРТКА", "desc": "После полученного удара следующий в течение 1,5 с слабее на 25 / 40 / 55 %.", "lv": 3, "rare": false},
	"kiosk_can": {"family": "dvor", "name": "БАНКА ИЗ ЛАРЬКА", "desc": "Приёмы стиля перезаряжаются на 10 / 20 % быстрее.", "lv": 2, "rare": false},
	"slick_soles": {"family": "dvor", "name": "СКОЛЬЗКИЕ ПОДОШВЫ", "desc": "После уклонения +15 / +25 % урона на 2 с.", "lv": 2, "rare": false},
	"garage_key": {"family": "dvor", "name": "ГАРАЖНЫЙ КЛЮЧ", "desc": "Тяжёлые удары сбивают равновесие на 25 / 50 % сильнее (по боссу — вдвое слабее).", "lv": 2, "rare": false},
	"first_hit": {"family": "dvor", "name": "ПЕРВЫЙ УДАР", "desc": "Удар по врагу с полным здоровьем +30 / +50 %; по боссу — один раз.", "lv": 2, "rare": true},
	"semki": {"family": "dvor", "name": "СЕМКИ", "desc": "Бой без полученного урона: +15 голды.", "lv": 1, "rare": false},
	"own_man": {"family": "dvor", "name": "СВОЙ ЧЕЛОВЕК", "desc": "Цены у торговцев ниже на 15 / 25 %.", "lv": 2, "rare": false},
	"district_remembers": {"family": "dvor", "name": "РАЙОН ПОМНИТ", "desc": "Каждое пройденное событие забега: +5 % урона, не больше +15 %.", "lv": 1, "rare": true},
	"warm_entry": {"family": "dvor", "name": "ТЁПЛЫЙ ПОДЪЕЗД", "desc": "Передышка лечит 65 % здоровья вместо 45 %.", "lv": 1, "rare": false},
	"second_wind": {"family": "misha", "name": "ВТОРОЕ ДЫХАНИЕ", "desc": "Раз за комнату (и в комнате босса): удар оставил меньше 30 % здоровья — лечит на 25 / 40. От смертельного не спасает.", "lv": 2, "rare": true},
}
const FAMILY_NAMES := {"misha": "МИША МИНАСЯН", "fortuna": "FORTUNA 812", "dvor": "ДВОР"}
const FAMILY_COLOR := {"misha": Color(0.85, 0.63, 0.23), "fortuna": Color(0.62, 0.85, 0.25), "dvor": Color(0.55, 0.78, 0.95)}
## Девять бафов двора (DVOR_BUFF_CATALOG.md, утверждены владельцем). Числа по уровням — здесь, эффекты — G67RunMods и Golda67.
const JACKET_T := 1.5                       # ДЕДОВСКАЯ КУРТКА: окно после полученного удара, с
const JACKET_K := [0.25, 0.40, 0.55]        # на сколько слабее следующий удар
const CAN_CD := [0.10, 0.20]                # БАНКА ИЗ ЛАРЬКА: перезарядки приёмов быстрее
const CD_FLOOR := 0.6                       # перезарядки не ниже 60 % исходных вместе со всеми эффектами
const SOLES_T := 2.0                        # СКОЛЬЗКИЕ ПОДОШВЫ: сколько держится усиление после уклонения, с
const SOLES_K := [0.15, 0.25]
const KEY_K := [0.25, 0.50]                 # ГАРАЖНЫЙ КЛЮЧ: тяжёлые сильнее сбивают равновесие (по боссу — вдвое слабее)
const FIRST_K := [0.30, 0.50]               # ПЕРВЫЙ УДАР: по врагу с полным здоровьем
const SEMKI_GOLD := 15                      # СЕМКИ: бой без полученного урона
const OWN_K := [0.15, 0.25]                 # СВОЙ ЧЕЛОВЕК: скидка у торговцев
const REMEMBER_STEP := 0.05                 # РАЙОН ПОМНИТ: за событие
const REMEMBER_CAP := 0.15
const WARM_HEAL := 0.65                     # ТЁПЛЫЙ ПОДЪЕЗД: передышка лечит столько вместо BREAK_HEAL
const DMG_CAP := 2.0          # потолок множителя урона от фитсов

## РЕСПЕКТ (постоянная валюта, SPEC, раздел 12): за что и сколько
const RESPECT := {"room": 3, "elite": 6, "calm": 1, "boss": 20, "boss_first": 40}
## Голда за пройденную комнату
## Где герой входит в комнату (z в координатах комнаты; зона — в нуле). По умолчанию у южного края зоны; в коробке
## Миши край — это калитка в борту: герой стоял в ней, камера оставалась за бортом и Мишу заслоняла калитка.
const ENTRY_Z := {"sport": 5.0}
const ENTRY_Z_DEFAULT := 10.5
## Фитсы Миши по утверждённой таблице (APPROVALS.md, 2.1)
const FINISHER_HEAL := [3.0, 6.0, 9.0]     # ДОБИВАЛА: лечение за поверженного врага по уровню
const FINISHER_ELITE := 3.0                # элитный — втрое больше
const FINISHER_CAP := [25.0, 40.0, 55.0]   # не больше за одну комнату
const WIND_HEAL := [25.0, 40.0]            # ВТОРОЕ ДЫХАНИЕ: лечение по уровню (раз за комнату, здоровье ниже 30 %)
const WIND_AT := 0.3

## Ларёк «ШАУРМА 67» — постоянный магазин двора: товар → цена, эффект, сколько на забег (поле per_visit)
const KIOSK := [
	{"id": "shawarma", "name": "ШАУРМА", "price": 30, "per_visit": 0, "step": 5, "desc": "Восстанавливает 40 здоровья. Каждая следующая за забег дороже на 5."},
	{"id": "double", "name": "ДВОЙНАЯ ШАУРМА", "price": 55, "per_visit": 1, "desc": "Восстанавливает 40 здоровья и +15 к максимуму здоровья до конца забега."},
	{"id": "togo", "name": "С СОБОЙ", "price": 70, "per_visit": 2, "desc": "Случайный баф из тех, что ещё можно взять или улучшить (15 % — редкий)."},
]
const KIOSK_HEAL := 40.0
const KIOSK_MAXHP := 15.0
const KIOSK_RARE := 0.15

## Артефакты (APPROVALS.md, 2.3): слотов 3 (+1 за уровень «СЛОТОВ АРТЕФАКТОВ»), в кладовке — один из двух;
## событийные в кладовке не лежат; «Вторая симка» — после первой концовки, «Автотюн» — когда открыты два стиля
const ART_SLOTS := 3
const ART_EVENT := ["garlic_aura", "hamster_aura", "collar_67", "reserve_05"]
const DMG_CAP_ALL := 2.0                   # общий потолок урона от фитсов и артефактов вместе

const ROOM_GOLDA := {"battle": 20, "ambush": 20, "elite": 40, "fit": 0, "storage": 0, "kiosk": 0, "break": 0, "boss": 67, "event": 0}
const BREAK_HEAL := 0.45      # доля максимума здоровья

static func district(id: String) -> Dictionary:
	if not DISTRICTS.has(id):
		push_error("G67Data.district: неизвестный район «%s»" % id)
		return DISTRICTS["dvor"]
	return DISTRICTS[id]

## Место варианта этапа района 2 по позиции и шаблону забега
static func pz_option(t: String, pos: int, tpl: int) -> Dictionary:
	match t:
		"battle":
			var pl := ["gate1", "gallery", "cross", ("arcade" if tpl % 2 == 0 else "tunnel")]
			return {"type": "battle", "place": pl[clampi(pos, 0, 3)]}
		"elite": return {"type": "elite", "place": "cross"}
		"fit": return {"type": "fit", "place": "gallery"}
		"storage": return {"type": "storage", "place": "cross"}
		"kiosk": return {"type": "kiosk", "place": "arcade"}
		"break": return {"type": "break", "place": "staff"}
	return {"type": "boss", "place": "arena"}

## Волны боя: позиция 1 — три волны; бой на позициях 2 и 4 — три волны; элита — три волны
const WAVES_P1 := [[["shest", 3]], [["shest", 2], ["semka", 1]], [["shest", 3], ["semka", 1]]]
const WAVES_BATTLE := [[["shest", 3], ["semka", 1]], [["shest", 3], ["semka", 2]], [["shest", 3], ["semka", 2]]]
## Свёрток шаурмы за зачистку боевого этапа: лечение (подобрать; непобранный пропадает при начале следующего этапа)
const FOE_DMG_K := 0.6       # урон рядовых врагов двора и свиты Миши (сам Миша — нет); кампанию не трогает
const FOES_ALIVE_MAX := 5   # одновременно живых врагов в бою приквела
const STAGE_HEAL := {"battle": 25.0, "ambush": 25.0, "elite": 40.0}
const WAVES_ELITE := [[["smotr", 1], ["shest", 2]], [["shest", 2], ["semka", 2]], [["smotr", 1], ["semka", 2]]]

static func waves_for(_d: Dictionary, type: String, pos: int) -> Array:
	if String(_d.get("boss", "")) == "g67_fortuna":
		if type == "elite":
			return PZ_ELITE
		return PZ_WAVES.get(clampi(pos, 0, 3), PZ_WAVES[3])
	if type == "elite":
		return WAVES_ELITE
	return WAVES_P1 if pos == 0 else WAVES_BATTLE

## Шаблон маршрута забега: по номеру забега (первый забег — шаблон 0)
static func route_of(_d: Dictionary, _tpl: int) -> Array:
	return POSITIONS

# ---------------------------------------------------------------- подъезд: экраны предметов (этап 2)
## «АВТОРИТЕТ РАЙОНА» — девять веток (LEVEL_DESIGN.md, раздел 7). live — эффект уже работает; у остальных — wait:
## почему ветка пока закрыта (её система появится на своём этапе). Цена уровня — UP_COST[уровень].
## Всё дерево — 527 РЕСПЕКТА (≈ нормальное прохождение обеих линий; гринда нет).
const UPGRADES := [
	{"id": "hp", "name": "ЗДОРОВЬЕ", "max": 5, "per": "+10 к максимуму здоровья", "live": true},
	{"id": "dmg", "name": "УРОН", "max": 5, "per": "+4 % урона", "live": true},
	{"id": "res", "name": "ВОССТАНОВЛЕНИЕ", "max": 3, "per": "перезарядки и боезапас −8 %", "live": true},
	{"id": "heal", "name": "ВАРИАНТЫ ЛЕЧЕНИЯ", "max": 2, "per": "+1 вариант на передышке", "live": false, "wait": "когда владелец утвердит варианты лечения на передышке"},
	{"id": "rare", "name": "РЕДКИЕ БАФЫ", "max": 3, "per": "+6 % к шансу редкого бафа", "live": true},
	{"id": "reroll", "name": "ПОВТОРНЫЙ ВЫБОР", "max": 2, "per": "+1 перевыбор бафа за забег", "live": true},
	{"id": "slots", "name": "СЛОТЫ АРТЕФАКТОВ", "max": 2, "per": "слотов 3 → 4 → 5", "live": true},
	{"id": "gold", "name": "СТАРТОВАЯ ГОЛДА", "max": 3, "per": "+30 голды в начале забега", "live": true},
	{"id": "routes", "name": "ОТКРЫТИЕ МАРШРУТОВ", "max": 3, "per": "старт с района 2 / 3 / 4", "live": false, "wait": "когда откроются ПОДЗЕМКА, ЛЕНТА и БОТОФЕРМА"},
]
const UP_COST := [8, 15, 25, 35, 50]

## 18 артефактов (APPROVALS.md, раздел 2.3) — для коллекции; эффекты встают в игру на этапе 3
const ARTIFACTS := [
	{"id": "cassette_2016", "name": "Кассета 2016", "rar": "обычный", "desc": "+20 % урона на 4 с после полученного урона; не чаще раза в 8 с."},
	{"id": "sim", "name": "SIM-карта", "rar": "обычный", "desc": "Перезарядки приёмов стиля и ад-либа на 15 % быстрее."},
	{"id": "bracelet_67", "name": "Золотой браслет 67", "rar": "редкий", "desc": "+20 % голды за забег; складывается с «ЦЕПЬЮ НА УДАЧУ»."},
	{"id": "one_earbud", "name": "Наушники с одним рабочим ухом", "rar": "обычный", "desc": "−10 % входящего урона."},
	{"id": "energy", "name": "Энергетик", "rar": "редкий", "desc": "Team Hype копится на 30 % быстрее; пока Hype закрыт — СВЭГ на 20 % быстрее."},
	{"id": "flash_drive", "name": "Проектная флешка", "rar": "редкий", "desc": "За победу над боссом +50 % голды и +10 РЕСПЕКТА."},
	{"id": "broken_remote", "name": "Сломанный пульт", "rar": "редкий", "desc": "Один повторный выбор бафа за забег."},
	{"id": "market_sneakers", "name": "Рыночные кроссовки", "rar": "обычный", "desc": "+8 % к скорости бега."},
	{"id": "platinum_badge", "name": "Платиновый значок", "rar": "редкий", "desc": "Добивание на [E] лечит на 8 и даёт 5 голды."},
	{"id": "cracked_phone", "name": "Телефон с треснутым экраном", "rar": "обычный", "desc": "+25 % урона, пока здоровье ниже 35 %."},
	{"id": "garlic_aura", "name": "ЧЕСНОЧНАЯ АУРА", "rar": "событие", "desc": "Враги в 2,5 м наносят на 10 % меньше урона (боссы — вдвое слабее эффект)."},
	{"id": "reserve_05", "name": "АВАРИЙНЫЙ ЗАПАС 0.5", "rar": "секрет", "desc": "5 зарядов на забег: попадание бутылкой Водяры даёт всплеск 3,5 м (+60 % урона, замедление 40 % на 3 с)."},
	{"id": "hamster_aura", "name": "ХОМЯЧЬЯ АУРА", "rar": "событие", "desc": "+2 голды за каждого поверженного врага."},
	{"id": "collar_67", "name": "ОШЕЙНИК 67", "rar": "событие", "desc": "Смертельный удар оставляет 1 здоровье и даёт 2 с неуязвимости; раз за забег."},
	{"id": "beanie", "name": "Шапка-бини", "rar": "обычный", "desc": "+20 к максимуму здоровья."},
	{"id": "grillz", "name": "Грилзы", "rar": "редкий", "desc": "Парирование оглушает врага на 50 % дольше."},
	{"id": "blue_tape", "name": "Синяя изолента", "rar": "обычный", "desc": "Тяжёлые удары +15 % урона."},
	{"id": "second_sim", "name": "Вторая симка", "rar": "редкий", "desc": "Помощь напарника на [T] перезаряжается на 25 % быстрее (после первой концовки)."},
	{"id": "autotune_ring", "name": "Кольцо «Автотюн»", "rar": "редкий", "desc": "Усиление Perfect Swap длится на 1 с дольше (нужны два стиля)."},
]

## Районы линии 1 для карты маршрутов (SPEC, раздел 5)
const DISTRICT_LIST := [
	{"id": "dvor", "name": "ДВОР", "boss": "Миша Минасян", "flag": "boss_misha"},
	{"id": "podzemka", "name": "ПОДЗЕМКА", "boss": "FORTUNA 812", "flag": "boss_fortuna"},
	{"id": "lenta", "name": "ЛЕНТА", "boss": "Королевский XVII", "flag": "boss_korolevsky"},
	{"id": "botoferma", "name": "БОТОФЕРМА", "boss": "Полковник Бустеренко", "flag": "boss_busterenko"},
]

## «АРХИВ ПИЗДЕЦА» (HUB_DESIGN.md, раздел 5): разделы роликов; КРОТ и DJ FLÜRR — свои разделы; неоткрытое — «???»
const ARCHIVE_CLIPS := [
	["РЕКЛАМА", ["V00", "AD01"]],
	["ОБЛАКО LIVE", ["CL01", "EXTRA01"]],
	["НОВОСТИ", ["NEWS01"]],
	["СЮЖЕТ", ["STORY01", "STORY05"]],
]
const ARCHIVE_EVENTS := ["ТРЯПКИ! ТРЯПКИ!", "Бурмалда", "Можно. А зачем?"]    # события двора — появятся на этапе 4
const ARCHIVE_ENDINGS := 2

## Доска объявлений и почтовые ящики: [текст, флаг или «» — с начала]. Строки — из роликов и ТЗ, новых нет.
## [текст, флаг, вид листка] — вид только для доски объявлений: poster (афиша), tariff (машинописный лист),
## official (объявление с печатью)
const BOARD := [
	["ТУРНИР 67 · ПРИЗОВОЙ ФОНД — 67 000 ГОЛДЫ", "", "poster"],
	["ВХОД — 67 · ВЫХОД — 67 · ПОСМОТРЕТЬ НА ТУРНИКЕТ — 6,7", "", "tariff"],
	["АВТОРИТЕТ ВРЕМЕННО НЕДОСТУПЕН. ПОПРОБУЙТЕ ПОЗЖЕ.", "boss_misha", "official"],
]
## [текст, флаг, вид письма, номер ящика] — вид: flyer (листовка), ad (реклама с подписью), news (газетная вырезка)
const MAIL := [
	["Листовка: «Ты готов изменить свой район?»", "", "flyer", 31],
	["Реклама: «Авторитет — это когда даже машина тебя уважает». Подпись — Миша Минасян.", "", "ad", 36],
	["РАЙОННЫЙ ВЕСТНИК 67: «Миша Минасян временно передал звание главного авторитета ближайшему свободному человеку».", "boss_misha", "news", 42],
]
## Когда открывается то, что зависит от флага (текст причины для закрытых листков, ящиков и записей)
const FLAG_WHY := {"boss_misha": "после победы над Мишей Минасяном"}
## Когда ролик появляется в архиве (как в коде: Golda67.begin / use / start_run / _finish_run / _krot_done)
const CLIP_WHY := {
	"V00": "с первого входа в подъезд", "STORY01": "в начале приквела", "STORY05": "в начале приквела",
	"AD01": "перед первым выходом во двор", "CL01": "после первого захода во ДВОР",
	"NEWS01": "после первой победы над Мишей Минасяном", "EXTRA01": "после третьей встречи с КРОТОМ",
}

## Доступность встреч КРОТА района 2 на позиции pos забега: КРОТ 4 — после позиции 1; КРОТ 5 — после позиции 3, если КРОТ 4 пройден и не на соседней позиции
static func pz_krot_ok(id: String, pos: int, seen_krot4: bool, k4pos: int) -> bool:
	if id == "krot4":
		return pos >= 1
	if id == "krot5":
		return pos >= 3 and seen_krot4 and (k4pos < 0 or pos >= k4pos + 2)
	return false

## Пять бутылок района 2: номер → [позиция, реплика Пахана]
const PZ_BOTTLES := [
	{"n": 1, "pos": Vector3(9.4, 0, -77.5), "line": "Пригодится. Не спрашивай."},
	{"n": 2, "pos": Vector3(41.0, 0, -157.5), "line": "Аварийный запас."},
	{"n": 3, "pos": Vector3(-12.5, 0, -80.0), "line": "В хозяйстве всё пригодится."},
	{"n": 4, "pos": Vector3(-41.0, 0, -136.0), "line": "Четыре. Я уже не могу остановиться."},
	{"n": 5, "pos": Vector3(10.0, 0, -168.0), "line": "Пятая. Легенда."},
]
