## Общие настройки игры: одна система для главного меню и меню паузы.
## Хранятся в user://grimerka_display.json, применяются сразу и при запуске. Громкость шин Music/SFX/Ambient/Voice
## живёт в audio.gd (user://grimerka_audio.json), громкость iPod — в ipod.gd; здесь к ним только общий список строк.
## Показываются только настройки, которые действительно работают.
class_name Opts

const PATH := "user://grimerka_display.json"
const DEFAULT := {"fullscreen": false, "vsync": true, "fps": 0, "window": 0, "fov": 62.0, "sens": 1.0, "invert_y": false, "master": 1.0, "shake": 1.0, "less_flash": false}
const FPS := [0, 30, 60, 120, 144]
const WINDOWS := [[1280, 720], [1600, 900], [1920, 1080], [2560, 1440]]
static var data := {}
static var loaded := false

static func _load() -> void:
	if loaded:
		return
	loaded = true
	data = DEFAULT.duplicate()
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			for k in DEFAULT:
				if d.has(k) and typeof(d[k]) in [TYPE_BOOL, TYPE_FLOAT, TYPE_INT]:
					data[k] = d[k]

## Значение настройки.
static func v(k: String):
	_load()
	return data.get(k, DEFAULT.get(k))

## Записать настройку, сохранить и применить.
static func put(k: String, val, w: Window = null) -> void:
	_load()
	data[k] = val
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	if w != null:
		apply(w)

## Применить всё к окну и движку (при запуске и после каждой правки).
static func apply(w: Window) -> void:
	_load()
	var full := bool(data["fullscreen"])
	var is_full := w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		w.mode = Window.MODE_FULLSCREEN if full else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(data["vsync"]) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(data["fps"])
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(data["master"]))))

## Размер окна из списка (только в оконном режиме): ставит и центрирует.
static func set_window(w: Window, i: int) -> void:
	put("window", posmod(i, WINDOWS.size()))
	if w.mode != Window.MODE_WINDOWED:
		return
	var sz := Vector2i(int(WINDOWS[int(data["window"])][0]), int(WINDOWS[int(data["window"])][1]))
	var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.size = Vector2i(mini(sz.x, scr.size.x), mini(sz.y, scr.size.y))
	w.position = scr.position + (scr.size - w.size) / 2

static func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100.0)

## Строки настроек для обоих меню. Элемент — ["#ЗАГОЛОВОК"] или [функция текста, функция изменения(направление −1/+1)].
## audio — менеджер звука (main.audio), ipod — плеер игры или null (в главном меню его нет).
static func rows(w: Window, audio, ipod) -> Array:
	_load()
	var r: Array = []
	r.append(["#ЭКРАН"])
	r.append([func(): return "ПОЛНЫЙ ЭКРАН: " + ("ВКЛ" if bool(v("fullscreen")) else "ВЫКЛ"), func(_d: int): put("fullscreen", not bool(v("fullscreen")), w)])
	r.append([func(): return "РАЗМЕР ОКНА: %d × %d%s" % [WINDOWS[int(v("window"))][0], WINDOWS[int(v("window"))][1], "" if not bool(v("fullscreen")) else "  (в окне)"], func(d: int): set_window(w, int(v("window")) + d)])
	r.append([func(): return "ВЕРТ. СИНХРОНИЗАЦИЯ: " + ("ВКЛ" if bool(v("vsync")) else "ВЫКЛ"), func(_d: int): put("vsync", not bool(v("vsync")), w)])
	r.append([func(): return "ОГРАНИЧЕНИЕ FPS: " + ("НЕТ" if int(v("fps")) == 0 else str(int(v("fps")))), func(d: int): put("fps", FPS[posmod(FPS.find(int(v("fps"))) + d, FPS.size())], w)])
	r.append(["#КАМЕРА"])
	r.append([func(): return "УГОЛ ОБЗОРА: %d°" % int(v("fov")), func(d: int): put("fov", clampf(float(v("fov")) + 2.0 * d, 50.0, 80.0))])
	r.append([func(): return "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ: " + _pct(float(v("sens"))), func(d: int): put("sens", clampf(snappedf(float(v("sens")) + 0.1 * d, 0.1), 0.3, 2.5))])
	r.append([func(): return "ИНВЕРСИЯ ПО ВЕРТИКАЛИ: " + ("ВКЛ" if bool(v("invert_y")) else "ВЫКЛ"), func(_d: int): put("invert_y", not bool(v("invert_y")))])
	r.append(["#ЭФФЕКТЫ"])
	r.append([func(): return "ТРЯСКА КАМЕРЫ: " + _pct(float(v("shake"))), func(d: int): put("shake", clampf(snappedf(float(v("shake")) + 0.25 * d, 0.25), 0.0, 1.0))])
	r.append([func(): return "МЕНЬШЕ ВСПЫШЕК: " + ("ВКЛ" if bool(v("less_flash")) else "ВЫКЛ"), func(_d: int): put("less_flash", not bool(v("less_flash")))])
	r.append(["#ЗВУК"])
	r.append([func(): return "ОБЩАЯ ГРОМКОСТЬ: " + _pct(float(v("master"))), func(d: int): put("master", clampf(snappedf(float(v("master")) + 0.05 * d, 0.05), 0.0, 1.0), w)])
	for b in [["Music", "МУЗЫКА ИГРЫ"], ["SFX", "ЭФФЕКТЫ"], ["Ambient", "ОКРУЖЕНИЕ"], ["Voice", "ГОЛОСА"]]:
		var bus: String = b[0]
		var nm: String = b[1]
		r.append([func(): return "%s: %s" % [nm, _pct(float(audio.vol[bus]))], func(d: int): audio.set_volume(bus, clampf(snappedf(float(audio.vol[bus]) + 0.05 * d, 0.05), 0.0, 1.0))])
	if ipod != null:
		r.append([func(): return "IPOD: " + _pct(float(ipod.volume)), func(d: int): ipod.pause_set_volume(snappedf(float(ipod.volume) + 0.05 * d, 0.05))])
	return r
