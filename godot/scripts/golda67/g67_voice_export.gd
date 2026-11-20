## Выгрузка реплик главы 1 приквела для генерации озвучки (tools/golda67-voice.cjs):
##   $G --headless --path godot --script res://scripts/golda67/g67_voice_export.gd -- <файл.json>
## Пишет JSON: {"lines": [{scene, order, code, text, when, emotion, speed}, …], "speakers": G67Voice.SPEAKERS}
extends SceneTree

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://golda67_ch1_lines.json"
	var lines: Array = G67Voice.chapter1_lines()
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		print("VOICE_EXPORT не открыть ", out)
		quit(1)
		return
	f.store_string(JSON.stringify({"lines": lines, "speakers": G67Voice.SPEAKERS}, "\t"))
	f.close()
	print("VOICE_EXPORT реплик: %d → %s" % [lines.size(), out])
	quit(0)
