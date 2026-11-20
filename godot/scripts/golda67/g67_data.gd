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
		"barks": ["", "Олимпийку снимать не буду. И так справлюсь.", "Это не цепь зацепилась. Это контроль пространства."],
	},
}
const SPEAKERS := {"G1": {"n": "МИША МИНАСЯН", "c": "#d9a23a"}}

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
