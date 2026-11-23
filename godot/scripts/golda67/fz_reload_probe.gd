## Проверка перезапуска: новый процесс читает сохранение приквела и печатает, что в нём лежит (запускается из podzemkacheck._fortuna_debts)
extends SceneTree

func _init() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--p="):
			path = String(a).substr(4)
	var d: Dictionary = G67Save.read_file(path)
	var m: Dictionary = d.get("meta", {})
	var fl: Dictionary = m.get("flags", {})
	var arch: Array = m.get("archive", [])
	print("FZPROBE boss_fortuna=%s respect=%d news02=%s" % [str(fl.get("boss_fortuna", false)), int(m.get("respect", 0)), str(arch.has("clip_NEWS02"))])
	quit()
