## AUDIO QUALITY GATE (P1): выбор варианта трёх звуков «5 НОЧЕЙ» — скример БАЛОНА, переключение камеры, MADK1D в шахте.
## "" — прежний звук: так по умолчанию и так у игрока, пока он сам не выбрал вариант в сцене прослушивания
## scenes/five_nights/audio_gate.tscn (выбор лежит в user://fn_audio_gate.json). Правил игры выбор не касается: меняется
## только то, какая запись играет. Записи — assets/audio/fn/gate (tools/godot-fn-audio-gate.cjs), источники и лицензии —
## docs/FIVE_NIGHTS_AUDIO_GATE.md.
class_name FNAudioGate

const DIR := "res://assets/audio/fn/gate/"
const FILE := "user://fn_audio_gate.json"
const KEYS := ["balon", "cctv", "madk1d"]
const VARIANTS := ["", "a", "b"]
const NAMES := {"": "ORIGINAL", "a": "A", "b": "B"}
const CAM_TAKES := 4
const CRAWL_TAKES := 3
const CAM_DB := 7.0                # та же поправка, что у прежнего «cam» (FNSound.TRIM): записи сведены под неё

static var pick := {"balon": "", "cctv": "", "madk1d": ""}
static var _loaded := false
static var _last := {}
static var _cache := {}

static func load_choice() -> void:
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if d is Dictionary:
		for k in KEYS:
			if String(d.get(k, "")) in VARIANTS:
				pick[k] = String(d.get(k, ""))

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
			f.store_string(JSON.stringify(pick))

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

## MADK1D в шахте: null — прежний звук; иначе следующий дубль (10–11 с, с паузами)
static func crawl() -> AudioStream:
	var v := variant("madk1d")
	return null if v == "" else _take("crawl_" + v, CRAWL_TAKES, "ogg")
