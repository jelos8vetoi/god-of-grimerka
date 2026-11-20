extends RefCounted
## [title, effect, rarity, rank cap, minimum seconds, prerequisite, exclusion]
const CARDS := {
	"vozduh": ["Широкий размах", "VOZDUH: +15% к потере равновесия при ударе по нескольким целям за ранг.", 0, 3, 0, "", ""],
	"bottles": ["Осколки", "Водяра: попадания брошенной бутылкой снимают на 18% больше равновесия за ранг.", 0, 3, 0, "", ""],
	"tyaga": ["Усиленная тяга", "ТЯГА-812: выдув снимает на 15% больше равновесия за ранг.", 0, 3, 0, "", ""],
	"skate": ["Выше рампы", "Скейтборд: положительный подброс в ближнем бою на 10% сильнее за ранг.", 1, 2, 45, "", ""],
	"guitar": ["Фидбэк", "Гитара: тяжёлые удары в ближнем бою снимают на 15% больше равновесия за ранг.", 0, 3, 0, "", ""],
	"breaker": ["Не сбавляй", "Breaker: при потоке от 2 удары снимают на 20% больше равновесия за ранг.", 1, 2, 45, "", ""],
	"swap_hit": ["Передача импульса", "Perfect Swap: первое попадание в ближнем бою за 3 с получает +18% урона за ранг в пределах общего лимита.", 1, 2, 45, "", ""],
	"swap_swag": ["Чистая смена", "Синергия с «Передачей импульса»: Perfect Swap даёт 8 СВЭГ не чаще раза в 8 с.", 2, 1, 90, "swap_hit", ""],
	"tag_cd": ["Эстафета", "Обычная боевая смена восстанавливается на 0,3 с быстрее за ранг. Air Tag без изменений.", 0, 2, 0, "", ""],
	"tag_guard": ["Прикрытие", "После обычной смены входящий урон снижен на 15% за ранг в течение 2 с.", 1, 2, 45, "", ""],
	"air_hype": ["Воздушный резонанс", "Air Tag даёт до 6 Hype не чаще раза в 10 с, вне Overdrive.", 2, 1, 75, "", ""],
	"air_guard": ["Мягкая посадка", "Синергия с «Воздушным резонансом»: когда Air Tag даёт Hype, урон снижается на 25% на 2 с.", 3, 1, 135, "air_hype", ""],
	"duo_cd": ["Сработанная пара", "Успешный запуск Duo сокращает перезарядку поддержки на 0,5 с за ранг.", 1, 2, 45, "", ""],
	"duo_guard": ["Подстраховка", "Запуск Duo снижает входящий урон на 15% за ранг на 2,5 с.", 1, 2, 45, "", ""],
	"hype_heal": ["Второе дыхание", "Полностью завершённый Team Overdrive лечит активного героя на 8 HP за ранг, не чаще раза в 25 с.", 2, 2, 90, "", ""],
	"block": ["Крепкая стойка", "Обычный блок пропускает на 12% меньше урона за ранг. Несовместимо с «Ответным дыханием».", 0, 3, 0, "", "parry"],
	"parry": ["Ответное дыхание", "Парирование восстанавливает 4 HP за ранг не чаще раза в 8 с. Несовместимо с «Крепкой стойкой».", 2, 2, 75, "", "block"],
	"dodge": ["Ускользающий ритм", "Идеальный уклон даёт ещё 6 СВЭГ за ранг не чаще раза в 8 с.", 0, 2, 0, "", ""],
}
const RARITIES := ["Обычное", "Редкое", "Эпическое", "Легендарное"]
const WEIGHTS := [65.0, 24.0, 9.0, 2.0]
var ranks := {}
var ready_at := {}
var swap_until := -1.0
var swap_hero := ""
var guards := {}
var rng := RandomNumberGenerator.new()

func rank(id: String) -> int:
	return int(ranks.get(id, 0))

func eligible(id: String, seconds: float) -> bool:
	if not CARDS.has(id):
		return false
	var card: Array = CARDS[id]
	return seconds >= card[4] and rank(id) < card[3] and (card[5] == "" or rank(card[5]) > 0) and rank(card[6]) == 0

func draft(seconds: float) -> Array[String]:
	var pool: Array[String] = []
	var result: Array[String] = []
	for id in CARDS:
		if eligible(id, seconds):
			pool.append(id)
	if pool.size() < 3:
		return result
	for slot in 3:
		var total := 0.0
		for id in pool:
			total += float(WEIGHTS[CARDS[id][2]])
		var roll := rng.randf_range(0.0, total)
		for i in pool.size():
			roll -= float(WEIGHTS[CARDS[pool[i]][2]])
			if roll <= 0.0 or i == pool.size() - 1:
				result.append(pool.pop_at(i))
				break
	return result

func apply(id: String, seconds: float) -> bool:
	if not eligible(id, seconds):
		return false
	ranks[id] = rank(id) + 1
	return true

func clear() -> void:
	ranks.clear()
	ready_at.clear()
	guards.clear()
	swap_until = -1.0
	swap_hero = ""

func _trigger(id: String, now: float, cooldown: float) -> bool:
	if rank(id) == 0 or now < float(ready_at.get(id, 0.0)):
		return false
	ready_at[id] = now + cooldown
	return true

func perfect_swap(game) -> void:
	swap_until = game.clock + 3.0
	swap_hero = game.player.hero
	if _trigger("swap_swag", game.clock, 8.0):
		game.player.swag = minf(100.0, game.player.swag + 8.0)

func consume_swap(now: float, hero: String) -> float:
	if hero != swap_hero:
		return 0.0
	var bonus := 0.18 * rank("swap_hit") if now <= swap_until else 0.0
	swap_until = -1.0
	return bonus

func _guard(game, id: String, reduction: float, duration: float) -> void:
	if rank(id) > 0:
		guards[id] = [game.player.hero, game.clock + duration, reduction * rank(id)]

func incoming(game) -> float:
	var reduction := 0.0
	for entry in guards.values():
		if entry[0] == game.player.hero and game.clock <= entry[1]:
			reduction = maxf(reduction, entry[2])
	return 1.0 - reduction

func tagged(game, context: String) -> void:
	if context == "air_tag":
		if not game.hype.on and game.hype.value < TeamHype.MAX and _trigger("air_hype", game.clock, 10.0):
			game.hype.value = minf(TeamHype.MAX, game.hype.value + 6.0)
			_guard(game, "air_guard", 0.25, 2.0)
		return
	if rank("tag_cd") > 0:
		game.tag.tag_cd = maxf(1.0, game.tag.tag_cd - 0.3 * rank("tag_cd"))
	_guard(game, "tag_guard", 0.15, 2.0)

func duo_started(game) -> void:
	game.tag.assist_cd -= 0.5 * rank("duo_cd")
	_guard(game, "duo_guard", 0.15, 2.5)

func overdrive_ended(game, cancelled: bool) -> void:
	if not cancelled and _trigger("hype_heal", game.clock, 25.0):
		game.player.hp = minf(game.player.max_hp, game.player.hp + 8.0 * rank("hype_heal"))

func parried(game) -> void:
	if _trigger("parry", game.clock, 8.0):
		game.player.hp = minf(game.player.max_hp, game.player.hp + 4.0 * rank("parry"))

func dodged(game) -> void:
	if _trigger("dodge", game.clock, 8.0):
		game.player.swag = minf(100.0, game.player.swag + 6.0 * rank("dodge"))

func melee_hit(hit: HitInfo, player, targets: int) -> void:
	match hit.style_id:
		"vozduh":
			if targets > 1 and rank("vozduh") > 0:
				hit.stagger *= 1.0 + 0.15 * rank("vozduh")
				hit.telemetry_effects.append("vozduh")
		"skateboard":
			if hit.launch > 0.0 and rank("skate") > 0:
				hit.launch *= 1.0 + 0.1 * rank("skate")
				hit.telemetry_effects.append("skate")
		"guitar":
			if hit.heavy and rank("guitar") > 0:
				hit.stagger *= 1.0 + 0.15 * rank("guitar")
				hit.telemetry_effects.append("guitar")
		"breaker":
			if player.breaker.flow >= 2 and rank("breaker") > 0:
				hit.stagger *= 1.0 + 0.2 * rank("breaker")
				hit.telemetry_effects.append("breaker")
