## Стиль «Бутылки с водой» (Пахан): дистанция. Бутылка бьёт слабо, но мочит (замедляет), сбивает равновесие,
## прерывает слабые замахи и открывает окно для сближения и комбо балоном. Запас ограничен и восстанавливается сам.
## ЛКМ — быстрый бросок (до трёх подряд), ПКМ — удержание: прицел с траекторией, отпустил — усиленный бросок.
class_name StyleBottles

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "bottles"
	s.title = "Бутылки с водой"
	s.owner = "pahan"
	s.ready = true
	s.note = "дистанция: броски, замедление, подготовка комбо"
	s.ammo_max = 6
	s.ammo_regen = 3.0            # одна бутылка за 3 с
	s.charge_clip = "BottleAim"
	s.charge_max = 1.0
	s.chain_cd = 0.25
	s.color = Color(0.55, 0.82, 1.0)
	s.color_hot = Color(0.75, 0.92, 1.0)
	s.roles = {"idle": "BottleIdle", "combat_idle": "BottleIdle"}
	var quick := {"kind": "ranged", "clip": "BottleThrow", "duration": 0.62, "hits": [0.4], "damage": 9.0, "stagger": 22.0, "reach": 14.0, "arc": 1.6,
		"knockback": 2.0, "projectile": "bottle", "ammo": 1, "combo_from": 0.6, "recovery": 0.92, "feedback": "bt_hit",
		"extra": {"speed": 17.0, "slow": 2.5, "slow_k": 0.6}}
	var q1 := quick.duplicate(true)
	q1["id"] = "bt_quick"
	s.add(AttackData.make(q1))
	var q2 := quick.duplicate(true)
	q2["id"] = "bt_quick2"
	q2["duration"] = 0.56
	s.add(AttackData.make(q2))
	# третий подряд — с долгим завершением: спамить нельзя
	var q3 := quick.duplicate(true)
	q3["id"] = "bt_quick3"
	q3["duration"] = 0.78
	q3["recovery"] = 0.98
	s.add(AttackData.make(q3))
	# усиленный: прицел удержанием, летит быстрее, оглушает, всплеск мочит соседей
	s.add(AttackData.make({"id": "bt_power", "kind": "ranged", "title": "ОБЛИЛ", "clip": "BottleThrowHeavy", "duration": 0.7, "hits": [0.36], "damage": 16.0, "stagger": 45.0, "reach": 16.0, "arc": 1.4,
		"knockback": 4.0, "stun": 0.9, "heavy": true, "power": 1, "projectile": "bottle", "ammo": 1, "charge": true, "charge_gain": 0.6, "recovery": 0.95, "feedback": "bt_power",
		"extra": {"speed": 21.0, "slow": 3.5, "slow_k": 0.5, "splash": 2.2}}))
	# после уклонения — бросок с ходу
	var qr := quick.duplicate(true)
	qr["id"] = "bt_roll"
	qr["duration"] = 0.5
	qr["from"] = 0.2
	qr["stagger"] = 28.0
	s.add(AttackData.make(qr))
	s.links = {
		"": {"light": "bt_quick", "heavy": "bt_power"},
		"bt_quick": {"light": "bt_quick2", "heavy": "bt_power"},
		"bt_quick2": {"light": "bt_quick3", "heavy": "bt_power"},
		"bt_roll": {"light": "bt_quick2", "heavy": "bt_power"},
	}
	s.after_dodge = {"light": "bt_roll"}
	return s
