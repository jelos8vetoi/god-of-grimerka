## Игровые часы для проверок. В обычной игре — те же настоящие миллисекунды, что Time.get_ticks_msec(): для игрока
## ничего не меняется. В ускоренной проверке (запуск с --fixed-fps N и ключом пользователя --clock=N, его ставит
## tools/checks.cjs) время идёт по кадрам: кадр = 1/N секунды, сколько бы он ни рисовался на самом деле. Так проверка
## бежит быстрее настоящего времени, а всё, что ждёт «три секунды», ждёт три секунды игры.
## Что брать: всё, что отмеряет игровые события (ожидания в проверках, перезарядки, защиту от двойного нажатия,
## частоту звуков). Что не брать: замеры кадров и FPS (там нужно настоящее время) и сеть (таймауты, задержка).
class_name GameClock

static var _fps := -2

## частота кадров ускоренной проверки (0 — обычное время)
static func fps() -> int:
	if _fps == -2:
		_fps = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--clock="):
				_fps = maxi(0, int(a.substr(8)))
	return _fps

static func fast() -> bool:
	return fps() > 0

static func ms() -> int:
	var f := fps()
	if f > 0:
		@warning_ignore("integer_division")
		return int(Engine.get_process_frames() * 1000 / f)
	return Time.get_ticks_msec()
