## Звуки «5 НОЧЕЙ», прошедшие приёмку на слух (P1): скример БАЛОНА — A2 Physical Impact, переключение камеры —
## B2 Signal Transition, MADK1D в шахте — C1 Heavy Duct Movement (событиями P0), свои звуки подъёма и опускания планшета.
## Они играют по умолчанию (APPROVED). "" — прежний звук: его и остальные варианты можно включить для сравнения в сцене
## scenes/five_nights/audio_gate.tscn (выбор лежит в user://fn_audio_gate.json; файл без пометки VERSION — выбор времён
## пробы — не читается, чтобы обычная игра не осталась на пробных настройках). Правил игры выбор не касается.
## Записи — assets/audio/fn/gate и assets/audio/fn/sfx/madk_*, источники и лицензии — docs/FIVE_NIGHTS_AUDIO_GATE.md.
class_name FNAudioGate

const DIR := "res://assets/audio/fn/gate/"
const FILE := "user://fn_audio_gate.json"
const VERSION := 2
const APPROVED := {"balon": "b", "cctv": "b", "madk1d": "a", "tablet": "a"}
const KEYS := ["balon", "cctv", "madk1d", "tablet"]
const VARIANTS := ["", "a", "b"]
const NAMES := {"": "ORIGINAL", "a": "A", "b": "B"}
## события шахты: вид → записи C1 (assets/audio/fn/sfx/madk_*) и прежние записи P0
const DUCT_NEW := {"far": "madk_far", "hit": "madk_hit", "drag": "madk_drag", "near": "madk_near", "presence": "madk_presence"}
const DUCT_OLD := {"far": "duct_far", "hit": "duct_move", "drag": "duct_move", "near": "duct_move", "presence": "rustle"}
const CAM_TAKES := 4
const CRAWL_TAKES := 3
const CAM_DB := 7.0                # та же поправка, что у прежнего «cam» (FNSound.TRIM): записи сведены под неё

static var pick := APPROVED.duplicate()
static var _loaded := false
static var _last := {}
static var _cache := {}

static func load_choice() -> void:
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if d is Dictionary and int(d.get("v", 0)) == VERSION:
		for k in KEYS:
			if d.has(k) and String(d[k]) in VARIANTS:
				pick[k] = String(d[k])

static func variant(key: String) -> String:
	if not _loaded:
		load_choice()
	return String(pick.get(key, ""))

## keep — записать выбор в файл (сцена прослушивания); без него выбор живёт до выхода из игры
static func choose(key: String, v: String, keep := true) -> void:
	_loaded = true
	pick[key] = v if v in VARIANTS else ""
	if keep:
		var f := FileAccess.open(FILE, FileAccess.WRITE)
		if f != null:
			var d := pick.duplicate()
			d["v"] = VERSION
			f.store_string(JSON.stringify(d))

static func _stream(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = load(DIR + file) if ResourceLoader.exists(DIR + file) else null
	return _cache[file]

## следующий дубль: подряд один и тот же не играет
static func _take(prefix: String, n: int, ext: String) -> AudioStream:
	var k := randi() % n
	if n > 1 and k == int(_last.get(prefix, -1)):
		k = (k + 1 + randi() % (n - 1)) % n
	_last[prefix] = k
	return _stream("%s_%d.%s" % [prefix, k + 1, ext])

## крик скримера: null — играют прежние записи
static func scream(kind: String) -> AudioStream:
	var v := variant("balon")
	return null if kind != "balon" or v == "" else _stream("balon_%s.wav" % v)

## щелчок переключения камеры: null — прежний звук
static func cam() -> AudioStream:
	var v := variant("cctv")
	return null if v == "" else _take("cam_" + v, CAM_TAKES, "wav")

## MADK1D в шахте, дубли пробы (10–11 с, с паузами): игра ими не пользуется — шахта звучит событиями (duct_id);
## нужны сцене прослушивания
static func crawl() -> AudioStream:
	var v := variant("madk1d")
	return null if v == "" else _take("crawl_" + v, CRAWL_TAKES, "ogg")

## планшет поднят (on) или опущен: null — прежний звук (щелчок камеры на другой высоте)
static func tablet(on: bool) -> AudioStream:
	return null if variant("tablet") == "" else _stream("tablet_up.wav" if on else "tablet_down.wav")

## id записей для события шахты: far / hit / drag / near / presence
static func duct_id(kind: String) -> String:
	return String((DUCT_OLD if variant("madk1d") == "" else DUCT_NEW).get(kind, kind))
