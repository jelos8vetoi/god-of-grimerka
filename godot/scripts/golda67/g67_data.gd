## Данные приквела «ГОЛДА 67»: районы, комнаты, волны, фитсы, боссы. Новые числа и тексты — только сюда.
## Основа — godot/docs/golda67/SPEC.md (разделы 6, 7, 9, 10, 12) и LEVEL_DESIGN.md.
class_name G67Data
extends RefCounted

## Типы комнат (SPEC, раздел 9). Сделаны: BATTLE, ELITE, FIT, BREAK, BOSS. Не сделаны: STORAGE, KIOSK, EVENT.
const ROOM_NAMES := {"battle": "БОЙ", "elite": "ЭЛИТА", "fit": "ФИТС", "break": "ПЕРЕДЫШКА", "boss": "БОСС"}
const ROOM_HINT := {"battle": "голда", "elite": "редкий фитс и голда", "fit": "выбор фитса", "break": "лечение", "boss": "Миша Минасян"}
const ROOM_COLOR := {"battle": Color(0.95, 0.3, 0.25), "elite": Color(1.0, 0.55, 0.15), "fit": Color(1.0, 0.8, 0.2), "break": Color(0.45, 0.9, 0.55), "boss": Color(0.85, 0.15, 0.2)}

## Враги района: вид для ИИ (kind из enemy.KINDS) и облик (skin из enemy.SKINS)
const FOES := {
	"shest": {"kind": "bot", "skin": "g67_shest", "name": "Шестёрка", "golda": 4},
	"semka": {"kind": "hater", "skin": "g67_semka", "name": "Семечник", "golda": 5},
	"smotr": {"kind": "troll", "skin": "g67_smotr", "name": "Смотрящий", "golda": 18},
}

## Район: шесть позиций до босса включительно. На позиции — варианты комнат (двери), из которых выбирает игрок.
## place — оформление двора для комнаты (G67World._deco_g67_dvor читает его).
const DISTRICTS := {
	"dvor": {
		"name": "ДВОР", "boss": "g67_misha", "unlock": "bottles", "flag": "boss_misha",
		"route": [
			[{"type": "battle", "place": "podezd"}],
			[{"type": "battle", "place": "garages"}, {"type": "fit", "place": "playground"}],
			[{"type": "elite", "place": "parking"}, {"type": "battle", "place": "playground"}],
			[{"type": "fit", "place": "garages"}, {"type": "battle", "place": "parking"}],
			[{"type": "break", "place": "gazebo"}],
			[{"type": "boss", "place": "sport"}],
		],
		## волны по позиции (0…5): список волн, волна — [[враг, сколько], …]
		"waves": {
			"battle": [
				[[["shest", 3]], [["shest", 2], ["semka", 1]]],
				[[["shest", 3], ["semka", 1]], [["shest", 3], ["semka", 2]]],
				[[["shest", 4], ["semka", 1]], [["shest", 3], ["semka", 2]]],
				[[["shest", 4], ["semka", 2]], [["shest", 4], ["semka", 2]], [["shest", 2], ["semka", 3]]],
			],
			"elite": [[["smotr", 1], ["shest", 2]], [["shest", 2], ["semka", 2]]],
		},
	},
}

## Босс первого района. Формат — как у боссов кампании (story.json → BOSS): его читает enemy._setup_boss.
## Приёмы фаз — существующие приёмы боссов; свой особый приём — enemy._special («РАЗМАХ ЦЕПЬЮ»).
const BOSSES := {
	"g67_misha": {
		"n": "МИША МИНАСЯН", "sub": "главный авторитет двора", "sp": "G1", "hp": 600, "r": 30, "spd": 116, "c": "#d9a23a", "dmg": 14, "gap": 1.6, "xp": 0,
		"phases": [["slam", "charge"], ["slam", "charge", "shock"], ["charge", "shock", "slam", "leap"]],
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
	{"id": "krot2", "title": "ЛЮСТРА", "where": "hub", "pos": Vector3(-0.9, 0, 3.4), "yaw": 0.4, "needs": "g67_chandelier", "carry": "g67_chandelier",
		"pose": "K2", "talk_clip": "K2Look", "acts": {3: "K2Show"}, "after": "walk",
		"lines": ["V|Ты чё делаешь?", "KR|Люстру снимаю.", "V|ЗАЧЕМ?!", "KR|Она на меня странно смотрела."]},
	{"id": "krot3", "title": "ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО", "where": "playground", "pos": Vector3(-9.4, 0, -10.2), "yaw": 1.1, "needs": "g67_pigeon", "pigeons": 5,
		"pose": "K3", "talk_clip": "K3", "acts": {2: "K3Point"}, "after": "stay", "feed": true,
		"lines": ["KR|Пахан, ты вообще понимаешь, кто тут главный?", "V|Ты?", "KR|Нет, голубь справа. У него три квартиры и доступ к администрации.",
			"V|Ты опять хуйню несёшь.", "KR|Тихо, он слышит. У него рилсы сливают."]},
]

## Фитсы (SPEC, раздел 10). Пока одно семейство — МИША МИНАСЯН: сила, авторитет, тяжёлые удары, бонусы за добивания.
## Эффекты — числа, которые читает Golda67 (apply_fits, on_kill, _second_wind); исходные данные стилей не меняются.
## lv — на сколько уровней можно улучшить (повторный выбор того же фитса).
const FITS := {
	"heavy_hand": {"family": "misha", "name": "ТЯЖЁЛАЯ РУКА", "desc": "Весь урон +12% за уровень.", "lv": 3, "rare": false},
	"authority": {"family": "misha", "name": "АВТОРИТЕТ", "desc": "Максимум здоровья +20 за уровень, сразу лечит на столько же.", "lv": 3, "rare": false},
	"gold_chain": {"family": "misha", "name": "ЦЕПЬ НА УДАЧУ", "desc": "Голды с врагов и комнат +25% за уровень.", "lv": 3, "rare": false},
	"finisher": {"family": "misha", "name": "ДОБИВАЛА", "desc": "Каждый поверженный враг лечит на 3 здоровья за уровень.", "lv": 3, "rare": false},
	"second_wind": {"family": "misha", "name": "ВТОРОЕ ДЫХАНИЕ", "desc": "Раз за комнату: здоровье упало ниже 30% — лечит на 25 за уровень.", "lv": 2, "rare": true},
}
const FAMILY_NAMES := {"misha": "МИША МИНАСЯН"}
const FAMILY_COLOR := {"misha": Color(0.85, 0.63, 0.23)}
const DMG_CAP := 2.0          # потолок множителя урона от фитсов

## РЕСПЕКТ (постоянная валюта, SPEC, раздел 12): за что и сколько
const RESPECT := {"room": 2, "elite": 5, "boss": 20, "boss_first": 40}
## Голда за пройденную комнату
const ROOM_GOLDA := {"battle": 12, "elite": 30, "fit": 0, "break": 0, "boss": 67}
const BREAK_HEAL := 0.45      # доля максимума здоровья

static func district(id: String) -> Dictionary:
	return DISTRICTS.get(id, DISTRICTS["dvor"])

static func waves_for(d: Dictionary, type: String, pos: int) -> Array:
	var w: Dictionary = d["waves"]
	if type == "elite":
		return w["elite"]
	var list: Array = w["battle"]
	return list[clampi(pos, 0, list.size() - 1)]
