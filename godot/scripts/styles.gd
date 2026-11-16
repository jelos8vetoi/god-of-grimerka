## Реестр шести боевых стилей. Готовые стили строятся из своих таблиц (style_<имя>.gd), будущие объявлены
## заглушками (ready = false): у них есть имя, владелец и характер, но нет атак — ядро боя их не запускает.
## Новый стиль: файл style_<имя>.gd с build() → строка в _make(); код ядра менять не нужно.
class_name Styles

const ORDER := ["vozduh", "bottles", "tyaga808", "skateboard", "guitar", "breaker"]
const PLANNED := {
	"bottles": ["Бутылки с водой", "pahan", "дистанция: броски, контроль и подготовка комбо"],
	"tyaga808": ["ТЯГА-808", "pahan", "пылесос: езда, притягивание, выброс воздуха"],
	"skateboard": ["Скейтборд", "madk1d", "скорость и удары доской"],
	"guitar": ["Электрогитара", "madk1d", "размашистые удары и звуковые волны"],
	"breaker": ["Breaker Style", "madk1d", "брейк: удары ногами, вращения, аэрокомбо"],
}

static var _cache := {}

static func by_id(id: String) -> StyleData:
	if not _cache.has(id):
		_cache[id] = _make(id)
	return _cache[id]

static func _make(id: String) -> StyleData:
	match id:
		"vozduh":
			return StyleVozduh.build()
	var s := StyleData.new()
	s.id = id
	if PLANNED.has(id):
		s.title = PLANNED[id][0]
		s.owner = PLANNED[id][1]
		s.note = PLANNED[id][2]
	return s

static func of(owner: String) -> Array:
	var out := []
	for id in ORDER:
		if by_id(id).owner == owner:
			out.append(by_id(id))
	return out
