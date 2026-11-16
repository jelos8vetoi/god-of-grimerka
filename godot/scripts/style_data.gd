## Боевой стиль как данные (Resource): оружие, атаки и граф комбо. Ядро боя (combat.gd) одно на все стили —
## стиль отличается только этими данными. Таблицы — в style_<имя>.gd, реестр — styles.gd.
class_name StyleData
extends Resource

@export var id := ""                  # "vozduh"
@export var title := ""               # название для меню и HUD
@export var owner := "pahan"          # чей стиль: pahan / madk1d
@export var ready := false            # false — стиль объявлен, но атак ещё нет (будущие этапы)
@export var note := ""                # коротко о характере стиля
@export var weapon := {}              # {"path": модель, "side": "r", "opt": {...}} для Rig.attach; пусто — без оружия
@export var attacks := {}             # id → AttackData
## Граф комбо: из какой атаки какой ввод куда ведёт. "" — из стойки.
## {"": {"light": "vz_light1", "heavy": "vz_overhead"}, "vz_light1": {"light": "vz_light2", "heavy": "vz_nail"}}
@export var links := {}
@export var heat: Array = []          # цепочка Heat-действия: id атак подряд
@export var after_dodge := {}         # ввод сразу после уклонения: {"light": id, "heavy": id}
## Особые окна: что делает ввод сразу после события. Ключи — parry (парировал), perfect (идеальный уклон),
## block (принял удар на блок), dodge (уклонился), sprint (на бегу с рывком): {"parry": {"heavy": "vz_parry_heavy"}}
@export var after := {}
## Heat-цепочки по положению цели: "air" — цель в воздухе, "stun" — оглушена или лежит; иначе — heat
@export var heat_ctx := {}
@export var dodge_window := 0.35      # сколько секунд после уклонения действует after_dodge
@export var charge_clip := "Charge"   # клип удержания заряда
@export var charge_max := 1.2         # сколько секунд копится заряд
@export var buffer := 0.3             # сколько секунд помнится нажатие (буфер ввода)
@export var chain_cd := 0.15          # пауза перед новой цепочкой после оборванной — без спама первым ударом
@export var ammo_max := 0             # запас стиля (бутылки); 0 — стиль без запаса
@export var ammo_regen := 0.0         # секунд на восстановление единицы запаса; 0 — не восстанавливается
@export var hit_sfx: Array = []       # звуки попадания стиля по силе: [[лёгкий…], [тяжёлый…], [добивание…]], каждый — [[имя, дБ, высота]]
@export var roles := {}               # роль анимации → клип (Rig.style_map)
@export var color := Color(1.0, 0.8, 0.42)        # цвет следа и искр
@export var color_hot := Color(1.0, 0.45, 0.15)   # цвет в ПЕРЕГРУЗЕ и у добиваний

func attack(aid: String) -> AttackData:
	return attacks.get(aid, null)

## куда ведёт ввод (light / heavy) из атаки from_id ("" — из стойки); null — продолжения нет
func next(from_id: String, input: String) -> AttackData:
	var l: Dictionary = links.get(from_id, {})
	return attack(String(l.get(input, "")))

func add(a: AttackData) -> void:
	attacks[a.id] = a

## проверка данных: ссылки графа ведут к существующим атакам, окна не перепутаны; возвращает список ошибок
func problems() -> Array:
	var out := []
	for f in links:
		if f != "" and not attacks.has(f):
			out.append("граф: нет атаки %s" % f)
		for inp in links[f]:
			if not attacks.has(links[f][inp]):
				out.append("граф: %s → %s ведёт к несуществующей %s" % [f, inp, links[f][inp]])
	for w in after:
		for inp in after[w]:
			if not attacks.has(after[w][inp]):
				out.append("окно %s: %s ведёт к несуществующей %s" % [w, inp, after[w][inp]])
	for c in heat_ctx:
		for aid in heat_ctx[c]:
			if not attacks.has(aid):
				out.append("heat %s: нет атаки %s" % [c, aid])
	for aid in heat:
		if not attacks.has(aid):
			out.append("heat: нет атаки %s" % aid)
	for aid in attacks:
		var a: AttackData = attacks[aid]
		if a.id != aid:
			out.append("%s: id не совпадает с ключом" % aid)
		if a.hits.is_empty() or a.duration <= 0.0:
			out.append("%s: нет моментов попадания или длительности" % aid)
		if a.combo_from > a.combo_to or a.combo_to > 1.0:
			out.append("%s: окно комбо перепутано" % aid)
		if float(a.hits[a.hits.size() - 1]) > a.recovery:
			out.append("%s: попадание позже конца атаки" % aid)
	return out
