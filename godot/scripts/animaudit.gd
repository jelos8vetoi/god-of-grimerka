## Аудит боевых анимаций по данным проекта — без запуска игры:
##   Godot --headless --path godot --script res://scripts/animaudit.gd
## Печатает то, что есть на самом деле: сколько клипов у героя, какая роль какой клип берёт (и какие роли живут
## на запасном клипе), для каждого стиля — атаки по видам, клипы, которых нет, клипы, которыми пользуются сразу
## несколько атак, длину цепочки лёгких ударов, ответы после уклонения / парирования / блока и маршруты в воздухе.
## Строки начинаются с «AUDIT» — их удобно отбирать grep'ом. Ничего не меняет.
extends SceneTree

const MOVE_ROLES := ["start", "stop", "turn_l", "turn_r", "jump", "fall", "land"]

func _init() -> void:
	var defs := {"pahan": Poses.pahan_armed(), "madk1d": Poses.madk1d()}
	var profiles := {"pahan": PahanMoves.PROFILE, "madk1d": MadkMoves.PROFILE}
	for hero in defs:
		var d: Dictionary = defs[hero]
		print("AUDIT ===== %s: клипов %d" % [hero, d.size()])
		var own := 0
		var fallback: Array = []
		var missing: Array = []
		for role in Rig.ROLES:
			var list: Array = Rig.ROLES[role]
			var got := ""
			for c in list:
				if d.has(c):
					got = c
					break
			if got == "":
				missing.append(role)
			elif got != list[0]:
				fallback.append("%s→%s" % [role, got])
			else:
				own += 1
		print("AUDIT %s роли: своих клипов %d из %d; на запасном клипе: %s; без клипа: %s" % [hero, own, Rig.ROLES.size(), ", ".join(fallback) if fallback.size() > 0 else "нет", ", ".join(missing) if missing.size() > 0 else "нет"])
		var pr: Dictionary = (profiles[hero] as Dictionary).get("roles", {})
		var mv: Array = []
		for r in MOVE_ROLES:
			mv.append("%s=%s" % [r, pr.get(r, "—") if d.has(String(pr.get(r, ""))) else "НЕТ"])
		print("AUDIT %s перемещение: %s" % [hero, ", ".join(mv)])
		var no_ground := 0
		var no_ev := 0
		for c in d:
			var cd: Dictionary = d[c]
			if not cd.get("ground", false) and not cd.get("smooth", false) and not cd.get("loop", false):
				no_ground += 1
			if not cd.has("ev"):
				no_ev += 1
		print("AUDIT %s клипы: без привязки стоп к полу %d, без событий %d" % [hero, no_ground, no_ev])
	for id in Styles.ORDER:
		var s: StyleData = Styles.by_id(id)
		var d: Dictionary = defs[s.owner]
		var kinds := {}
		var no_clip: Array = []
		var by_clip := {}
		for aid in s.attacks:
			var a: AttackData = s.attacks[aid]
			kinds[a.kind] = int(kinds.get(a.kind, 0)) + 1
			if a.clip != "" and not d.has(a.clip) and not d.has(a.clip + "Bare"):
				no_clip.append("%s(%s)" % [aid, a.clip])
			if not by_clip.has(a.clip):
				by_clip[a.clip] = []
			(by_clip[a.clip] as Array).append(aid)
		var shared: Array = []
		for c in by_clip:
			if (by_clip[c] as Array).size() > 1:
				shared.append("%s×%d" % [c, (by_clip[c] as Array).size()])
		# цепочка лёгких: сколько ударов подряд по ЛКМ, пока не вернёмся к уже виденному
		var chain: Array = []
		var cur := ""
		while true:
			var nx: AttackData = s.next(cur, "light")
			if nx == null or chain.has(nx.id):
				break
			chain.append(nx.id)
			cur = nx.id
		# маршруты в воздухе: что доступно после подброса
		var air: Array = []
		for aid in s.attacks:
			var a2: AttackData = s.attacks[aid]
			if a2.kind == "launcher" or a2.launch > 4.0:
				var m: Dictionary = s.links.get(aid, {})
				for act in m:
					air.append("%s+%s→%s" % [aid, act, m[act]])
		var after: Array = []
		for w in s.after:
			after.append("%s:%s" % [w, ",".join((s.after[w] as Dictionary).keys())])
		print("AUDIT ===== стиль %s (%s): атак %d — %s" % [id, s.owner, s.attacks.size(), str(kinds)])
		print("AUDIT %s клипы: разных %d на %d атак; общие: %s; нет клипа: %s" % [id, by_clip.size(), s.attacks.size(), ", ".join(shared) if shared.size() > 0 else "нет", ", ".join(no_clip) if no_clip.size() > 0 else "нет"])
		print("AUDIT %s цепочка ЛКМ: %d — %s" % [id, chain.size(), " → ".join(chain)])
		print("AUDIT %s связки: узлов %d; после окон: %s; Heat: %d; после подброса: %s" % [id, s.links.size(), "; ".join(after) if after.size() > 0 else "нет", s.heat.size(), "; ".join(air) if air.size() > 0 else "нет"])
		print("AUDIT %s роли стиля: %s" % [id, str(s.roles)])
	quit()
