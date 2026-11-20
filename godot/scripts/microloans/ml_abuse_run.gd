## Запуск тестов «на взлом» экономики без окна:
##   Godot --headless --path godot --script res://scripts/microloans/ml_abuse_run.gd
## Строки «ABUSE ok / ОШИБКА», в конце — «ABUSE итог: ошибок N».
extends SceneTree

func _initialize() -> void:
	var fails := 0
	for r in MLAbuse.run():
		if not bool(r[1]):
			fails += 1
		print(("ABUSE ok: " if bool(r[1]) else "ABUSE ОШИБКА: ") + String(r[0]) + " — " + String(r[2]))
	print("ABUSE итог: ошибок %d" % fails)
	quit(1 if fails > 0 else 0)
