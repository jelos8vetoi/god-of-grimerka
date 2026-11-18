## Баланс урона в одном месте (подробно, с таблицами «до / после» — docs/DAMAGE_BALANCE.md, замеры — --damagecheck).
## Здесь только коэффициенты, которые раньше были рассыпаны или перемножались неявно; сама формула урона прежняя:
##   урон = AttackData.damage × ПЕРЕГРУЗ × прокачка (dmg_mul) × усиления момента (player.damage_bonus)
## Усиления момента (Perfect Swap, Tag-бонус, ресурс стиля: заряды скейта, ритм гитары, поток Breaker) складываются,
## а не перемножаются, и вместе не дают больше MOMENT_CAP — иначе три бонуса по ×1,3 давали ×2,2 и больше.
class_name Balance

const RAGE_MUL := 1.6          # ПЕРЕГРУЗ (как было)
const MOMENT_CAP := 2.0        # потолок суммы усилений момента

## Масштаб урона атак стиля (применяется к AttackData при сборке стиля, Styles._make): 1.0 — без изменений
const STYLE_DMG := {"vozduh": 0.88, "bottles": 1.0, "tyaga812": 1.8, "skateboard": 1.0, "guitar": 0.95, "breaker": 1.0}
## Атаки, которые масштаб стиля не трогает: приёмы контроля, урон в них не главное (тики втягивания ТЯГИ)
const KEEP := ["tg_suck"]
## Дополнительно для тяжёлых и завершающих ударов стиля (power ≥ 1 или heavy)
const HEAVY_DMG := {"vozduh": 0.9}

## Здоровье врагов: босс = story.json hp × BOSS_HP × game.diff_hp (было 0,75); у типов — замена KINDS.hp
const BOSS_HP := 0.95
const MOB_HP := {"mod": 140.0, "farmer": 110.0}

## Дуэт-атака (duo.gd): открытие напарника и концовка пары — иначе дуэт не сильнее обычной серии за то же время
const DUO_OPEN := 2.0
const DUO_END := 2.6

## Масштаб атаки при сборке стиля (один раз; данные стиля — это уже сбалансированные числа)
static func scale_style(s: StyleData) -> void:
	var k: float = float(STYLE_DMG.get(s.id, 1.0))
	var kh: float = float(HEAVY_DMG.get(s.id, 1.0))
	for aid in s.attacks:
		var a: AttackData = s.attacks[aid]
		if KEEP.has(String(aid)):
			continue
		a.damage = snappedf(a.damage * k * (kh if a.power >= 1 or a.heavy else 1.0), 0.1)
