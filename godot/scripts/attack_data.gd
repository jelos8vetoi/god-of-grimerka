## Одна атака как данные (Resource): всё, что ядру боя (combat.gd) нужно знать об ударе.
## Доли — от длительности атаки (0..1) и совпадают с ключами клипа в clips_*.gd.
## Таблицы атак стиля — в style_*.gd (AttackData.make({...})); можно хранить и как .tres.
class_name AttackData
extends Resource

@export var id := ""                 # уникальное имя: "vz_light1"
@export var kind := "light"          # light / heavy / launcher / slam / finisher / heat / ranged
@export var title := ""              # надпись при попадании ("ГВОЗДЬ"); пусто — без надписи
@export_group("Анимация и время")
@export var clip := ""               # клип рига
@export var duration := 0.9          # длительность атаки, с (клип играется за это время; скорость = длина клипа / duration)
@export var from := 0.0              # с какой доли начинать, если удар идёт в цепочке
@export var recovery := 0.9          # доля, после которой атака закончена и герой свободен
@export_group("Попадание")
@export var damage := 10.0
@export var stagger := 10.0          # сколько равновесия снимает у врага
@export var reach := 2.7             # дистанция, м
@export var arc := 2.6               # сектор перед героем, рад
@export var radius := 0.3            # радиус попадания оружия при detect = "sweep", м
@export var hits: Array = [0.5]      # доли клипа, когда оружие проходит цель (у серии — несколько)
@export var hit_window := 0.05       # окно попадания после каждого момента удара, доля
@export var hit_lead := 0.1         # у sweep: насколько раньше момента удара открывается хитбокс оружия, доля
@export var detect := "sector"       # sector — дистанция и сектор; sweep — ещё и путь оружия между кадрами
@export var knockback := 4.0
@export var launch := 0.0            # подброс (минус — вбить в землю)
@export var last_launch := 0.0       # подброс последним ударом серии
@export var stun := 0.0              # оглушение, с
@export var heavy := false           # тяжёлый: пробивает щит, прерывает боссов, не продолжается лёгким
@export var power := 0               # сила отклика: 0 — лёгкий, 1 — тяжёлый, 2 — добивание
@export_group("Комбо и отмены")
@export var combo_from := 0.62       # начало окна комбо: с этой доли принятый ввод запускает следующий удар
@export var combo_to := 0.9          # конец окна комбо (обычно = recovery): позже цепочка обрывается
@export var roll_from := -1.0        # с какой доли удар можно отменить перекатом (-1 — сразу после первого попадания)
@export var cooldown := 0.0          # пауза перед повторным использованием этой атаки, с
@export var charge := false          # заряжается удержанием (см. charge_clip)
@export_group("Движение и оружие")
@export var step: Array = []         # шаг в удар: [с доли, по долю, скорость м/с]
@export var spin := 0.0              # оборотов тела за удар (вертушка)
@export var slam := -1.0             # доля, когда оружие бьёт в землю
@export var scrape := -1.0           # доля, когда чиркает по земле
@export var drop := -1.0             # доля, когда после удара падает на землю
@export_group("Отклик")
@export var feedback := ""           # событие Feedback при попадании; пусто — по power
@export var sfx_swing := ""          # звук замаха; пусто — по heavy
@export var sfx_hit: Array = []      # звуки попадания [[имя, дБ, высота]]; пусто — набор стиля
@export var trail_boost := 1.0

static func make(d: Dictionary) -> AttackData:
	var a := AttackData.new()
	for k in d:
		if not (k in a):
			push_error("AttackData: нет поля " + String(k))
			continue
		a.set(k, d[k])
	if not d.has("combo_to"):
		a.combo_to = a.recovery
	return a

## копия с изменениями (заряженный удар, усиление)
func with(d: Dictionary) -> AttackData:
	var a: AttackData = duplicate()
	for k in d:
		a.set(k, d[k])
	return a

func feedback_event() -> String:
	return feedback if feedback != "" else ["hit_light", "hit_heavy", "hit_super"][clampi(power, 0, 2)]
