## Сохранение приквела «ГОЛДА 67»: свой файл, кампания (user://grimerka_save.json) не трогается.
## meta — постоянное (РЕСПЕКТ, улучшения, сюжетные флаги, архив роликов, увиденные сцены); run — текущий забег
## (стирается гибелью). Запись: во временный файл → проверка (читается обратно) → прежний целый основной становится .bak
## (старый .bak — .bak2) → временный переименовывается в основной. Битый файл в резерв не копируется.
class_name G67Save
extends RefCounted

const PATH := "user://golda67_save.json"
const VERSION := 1
## Списки номеров-отметок и счётчики: JSON отдаёт числа дробными, а сравнения has(i) ждут целых
const INT_LISTS := ["board_read", "mail_read"]
const INT_KEYS := ["respect", "runs", "visits", "flurr"]

## Задаёт проверка: другой основной путь (свой набор файлов .bak, .bak2, .tmp рядом)
static var path_override := ""
## Проверка приквела начинает с чистого листа и файл игрока не читает (запускалка проверок подкладывает его копию)
static var clean := false
## Основной файл был, но не читался, прогресс взят из резерва: имя резервного файла (иначе «»)
static var recovered := ""

static func main_path() -> String:
	return path_override if path_override != "" else PATH

static func bak() -> String:
	return main_path() + ".bak"

static func bak2() -> String:
	return main_path() + ".bak2"

static func tmp() -> String:
	return main_path() + ".tmp"

static func blank() -> Dictionary:
	return {"v": VERSION, "meta": {"visits": 0, "respect": 0, "flags": {}, "seen": [], "archive": []}, "run": {}}

## Разобрать файл: словарь с meta или пусто
static func read_file(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if d is Dictionary and d.has("meta") and d["meta"] is Dictionary:
		return d
	return {}

## Отметки — к целым (старые сохранения с 0.0 читаются так же, как новые)
static func normalize(d: Dictionary) -> void:
	var m: Dictionary = d["meta"]
	for k in INT_LISTS:
		if m.has(k) and m[k] is Array:
			m[k] = (m[k] as Array).map(func(x): return int(x) if (x is float or x is int) else x)
	for k in INT_KEYS:
		if m.has(k) and (m[k] is float or m[k] is int):
			m[k] = int(m[k])
	if m.has("up") and m["up"] is Dictionary:
		for u in m["up"]:
			m["up"][u] = int(m["up"][u])

static func load_all() -> Dictionary:
	recovered = ""
	if clean:
		return blank()
	var main_exists := FileAccess.file_exists(main_path())
	for p in [main_path(), bak(), bak2()]:
		var d := read_file(p)
		if d.is_empty():
			continue
		var base := blank()
		for k in (d["meta"] as Dictionary):
			base["meta"][k] = d["meta"][k]
		base["run"] = d.get("run", {})
		normalize(base)
		if p != main_path() and main_exists:
			recovered = p.get_file()
		return base
	return blank()

static func exists() -> bool:
	if clean:
		return false
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(bak()) or FileAccess.file_exists(bak2())

## Запись с проверкой. true — основной файл обновлён; false — временный файл не прошёл проверку, основной не тронут.
static func save_all(d: Dictionary) -> bool:
	d["v"] = VERSION
	var f := FileAccess.open(tmp(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if read_file(tmp()).is_empty():
		DirAccess.remove_absolute(tmp())
		return false
	if not read_file(main_path()).is_empty():          # прежний основной цел — он становится резервом
		if FileAccess.file_exists(bak()):
			DirAccess.copy_absolute(bak(), bak2())
		DirAccess.copy_absolute(main_path(), bak())
	return DirAccess.rename_absolute(tmp(), main_path()) == OK or _overwrite()

static func _overwrite() -> bool:
	if FileAccess.file_exists(main_path()):
		DirAccess.remove_absolute(main_path())
	return DirAccess.rename_absolute(tmp(), main_path()) == OK

static func wipe() -> void:
	for p in [main_path(), bak(), bak2(), tmp()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
