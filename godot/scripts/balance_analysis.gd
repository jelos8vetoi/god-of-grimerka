extends RefCounted

const Cards := preload("res://scripts/survival_modifiers.gd")
const Reports := preload("res://scripts/balance_lab_report.gd")

static func finding(issue: String, evidence: String, check: String, parameter: String, trial: String, confidence := "Низкая") -> Dictionary:
	return {"observation": issue, "evidence": evidence, "confidence": confidence, "verify": check, "parameter": parameter, "repeat": trial}

static func review(run: Dictionary, older: Dictionary, newer: Dictionary) -> Array:
	var notes := []
	for hero in run.get("heroes", {}).values():
		for style in hero.get("style_seconds", {}):
			var seconds := float(hero.style_seconds[style])
			if seconds < 60 or not Styles.ORDER.has(style):
				continue
			var missing := PackedStringArray()
			var data := Styles.by_id(style)
			for id in data.attacks:
				if not run.attacks.has("%s/%s/%s" % [data.owner, style, id]):
					missing.append(id)
			if not missing.is_empty():
				notes.append(finding("Приёмы без зарегистрированных событий", "%s · %.1f с · %s" % [style, seconds, ", ".join(missing)], "Повторить с опытным игроком и выполнить специальные условия приёмов.", "Окна ввода и условия комбо", "single / shield"))
	for key in run.get("attacks", {}):
		var a: Dictionary = run.attacks[key]
		if a.uses >= 5 and a.hits == 0 and a.get("control_contacts", 0) == 0:
			notes.append(finding("Нет попаданий или контактов контроля", "%s · %d применений" % [key, a.uses], "Проверить дистанцию, роль приёма и регистрацию попаданий.", "Дальность конкретной атаки", "single / group3"))
	var incoming := 0.0
	for e in run.get("enemies", {}).values():
		incoming += e.get("damage_dealt", 0)
	for id in run.get("enemies", {}):
		var e: Dictionary = run.enemies[id]
		var damage := float(e.get("damage_dealt", 0))
		if e.get("hits", 0) >= 5 and damage > incoming * 0.5:
			notes.append(finding("Один тип противника нанёс большую часть входящего урона", "%s · %.1f / %.1f HP" % [id, damage, incoming], "Сверить число противников, время контакта и защиту.", "Интервал между атаками", "endurance"))
	for id in run.get("bosses", {}):
		var e: Dictionary = run.enemies.get("boss:" + id, {})
		var wins := int(e.get("defeated", 0))
		var duration := float(run.bosses[id].get("fight_seconds", 0))
		if wins > 0 and wins == int(e.get("instances", 0)) and duration / wins < 15:
			notes.append(finding("Короткая победа над боссом", "%s · %.1f с / %d побед" % [id, duration, wins], "Повторить без карточек, сверить фазы и командный урон.", "BOSS_HP", "boss / overdrive"))
	var ranks: Dictionary = run.get("survival", {}).get("upgrades", {})
	for id in ranks:
		if Cards.CARDS.has(id) and ranks[id] > Cards.CARDS[id][3]:
			notes.append(finding("Ранг выше предела карточки", "%s · %s > %s" % [id, ranks[id], Cards.CARDS[id][3]], "Проверить версию каталога и повторную выдачу.", "Лимит ранга карточки", "survival_upgrades_test", "Высокая для текущего каталога"))
		if Cards.CARDS.has(id) and ranks[id] > 0:
			var required: String = Cards.CARDS[id][5]
			var excluded: String = Cards.CARDS[id][6]
			if (required != "" and ranks.get(required, 0) == 0) or (excluded != "" and ranks.get(excluded, 0) > 0):
				notes.append(finding("Нарушены условия сочетания карточек", "%s · набор %s" % [id, JSON.stringify(ranks)], "Сверить версию каталога и порядок выдачи.", "Совместимость карточек", "survival_upgrades_test", "Высокая для текущего каталога"))
	if not older.is_empty() and not newer.is_empty():
		for row in Reports.compare(older, newer):
			if row.percent == null or absf(row.percent) < 20.0 - 0.000001 or row.metric not in ["combo_damage", "damage_taken", "stagger_requested"]:
				continue
			notes.append(finding("Изменение результата стенда", "%s · %s · %+.1f%% · n=%d/%d" % [row.scenario_style, row.metric, row.percent, row.baseline.n, row.current.n], row.note + ". Проверить расход и роль стиля.", "Урон приёма, контроль или интервал атак", row.scenario_style))
	return notes

# Count outcomes only for completed encounters with a known terminal hit and matching difficulty/build context.
static func boss_outcomes(runs: Array, selected: Dictionary) -> Array:
	var observed := {}
	var deaths := {}
	var moves := {}
	for run in runs:
		if run.get("outcome") != "defeat" or not run.has("terminal_source") or run.terminal_source.is_empty():
			continue
		if run.get("balance_revision", "") == "" or run.balance_revision != selected.get("balance_revision"):
			continue
		if run.get("enemy_hp_scale") != selected.get("enemy_hp_scale") or run.get("survival", {}).get("upgrades", {}) != selected.get("survival", {}).get("upgrades", {}):
			continue
		for boss in run.bosses:
			observed[boss] = observed.get(boss, 0) + 1
		var boss: String = run.terminal_source.get("boss", "")
		deaths[boss] = deaths.get(boss, 0) + 1
		if boss != "":
			if not moves.has(boss):
				moves[boss] = {}
			var move: String = run.terminal_source.get("move", "")
			moves[boss][move] = moves[boss].get(move, 0) + 1
	var result := []
	for boss in observed:
		if observed[boss] >= 3 and deaths.get(boss, 0) * 2 > observed[boss]:
			result.append(finding("Босс часто наносил последний удар в выборке поражений", "%s · %d из %d поражений с этим боссом · последние приёмы %s" % [boss, deaths[boss], observed[boss], JSON.stringify(moves[boss])], "Сравнить опыт игроков, попытки с выходом, фазы и предупреждения.", "Урон и предупреждение способности", "boss"))
	return result
