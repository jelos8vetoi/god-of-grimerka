## Сохранение приквела «ГОЛДА 67»: свой файл, кампания (user://grimerka_save.json) не трогается.
## meta — постоянное (РЕСПЕКТ, улучшения, сюжетные флаги, архив роликов, увиденные сцены); run — текущий забег
## (стирается гибелью). Запись — после каждого изменения, с резервной копией .bak.
class_name G67Save
extends RefCounted

const PATH := "user://golda67_save.json"
const BAK := "user://golda67_save.json.bak"
const VERSION := 1

static func blank() -> Dictionary:
	return {"v": VERSION, "meta": {"visits": 0, "respect": 0, "flags": {}, "seen": [], "archive": []}, "run": {}}

static func load_all() -> Dictionary:
	for p in [PATH, BAK]:
		if not FileAccess.file_exists(p):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary and d.has("meta"):
			var base := blank()
			for k in (d["meta"] as Dictionary):
				base["meta"][k] = d["meta"][k]
			base["run"] = d.get("run", {})
			return base
	return blank()

static func exists() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BAK)

static func save_all(d: Dictionary) -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, BAK)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		d["v"] = VERSION
		f.store_string(JSON.stringify(d))

static func wipe() -> void:
	for p in [PATH, BAK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
