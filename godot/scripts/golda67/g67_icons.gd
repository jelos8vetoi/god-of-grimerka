class_name G67Icons
## Значки приквела «ГОЛДА 67» — рисованные наклейки владельца (GRAPHICS_REQUESTS.md, партии 1–2).
## Файлы: res://assets/golda67/ui/<id>.png. Нет файла — null (вызывающий оставляет текст без значка).

const DIR := "res://assets/golda67/ui/"
## Тип комнаты → значок ворот
const ROOM := {"battle": "icon_room_battle", "elite": "icon_room_elite", "fit": "icon_room_fit",
	"break": "icon_room_break", "boss": "icon_room_boss", "storage": "icon_room_storage",
	"kiosk": "icon_room_kiosk", "event": "icon_room_event"}
## Фитс → значок
const FIT := {"heavy_hand": "icon_fit_heavy_hand", "authority": "icon_fit_authority",
	"gold_chain": "icon_fit_gold_chain", "finisher": "icon_fit_finisher", "second_wind": "icon_fit_second_wind"}

static var _cache := {}

static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var p := DIR + id + ".png"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[id] = t
	return t

static func room(type: String) -> Texture2D:
	return tex(String(ROOM.get(type, "")))

static func fit(id: String) -> Texture2D:
	return tex(String(FIT.get(id, "")))

## Значок в интерфейсе: квадрат size×size, не ловит мышь
static func rect(id: String, size: float) -> TextureRect:
	var t := tex(id)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Значок над предметом в мире: всегда лицом к камере, виден сквозь стены
static func sprite(id: String, px: float) -> Sprite3D:
	var t := tex(id)
	if t == null:
		return null
	var s := Sprite3D.new()
	s.texture = t
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = 2
	return s
