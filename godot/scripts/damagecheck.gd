## Проверка баланса урона: -- --damagecheck=<папка>, с --resolution 1280x720. Меряет реальный урон в игре (манекены с огромным
## здоровьем, ввод ботом), а не только числа AttackData, и печатает таблицы «DMG …» для docs/DAMAGE_BALANCE.md.
## A — урон по данным (damage_for = AttackData.damage без усилений); B — усиления (ПЕРЕГРУЗ, прокачка, Perfect Swap, Tag,
## заряды скейта, гитара, Breaker) и их произведение; C — серии за 5 и 10 с (L, H, LLH), всплеск за 1 с; I — 1/3/5 целей;
## J — одна атака не бьёт одну цель дважды в кадр, нет NaN/∞; D — дуэт 9 пар; E — мобы: здоровье и время убийства;
## F — боссы: здоровье, фазы, лимит Overdrive; G — входящий урон по героям (без «убийства с одного удара»);
## H — переполнение множителей. Режимы: BASELINE (без прокачки) и ALL (вся прокачка «РАЗВИТИЕ» на 5).
## В конце «DAMAGECHECK ok» или «DAMAGECHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
var anchors: Array = []     # [манекен, точка]
const KEYS := {"vozduh": "style1", "bottles": "style2", "tyaga812": "style3", "skateboard": "style1", "guitar": "style2", "breaker": "style3"}
const HERO := {"vozduh": "pahan", "bottles": "pahan", "tyaga812": "pahan", "skateboard": "madk1d", "guitar": "madk1d", "breaker": "madk1d"}
var dps := {}               # стиль → DPS серии LLH за 10 с (для времени убийства)

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return true

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("DMG ok: " if c else "DMG ОШИБКА: ") + msg)
	if not c:
		fails += 1

func row(s: String) -> void:
	print("DMG | " + s)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _physics_process(_dt: float) -> void:
	if game != null:
		game.wave_wait = 9999.0      # пустая арена между замерами — не «волна пройдена» (иначе сюжет и диалог)
		game.step_done_t = -1.0
	# манекены стоят на месте: отбрасывание и подброс не уводят их из-под ударов
	for a in anchors:
		var d = a[0]
		if is_instance_valid(d) and d.alive():
			d.global_position = a[1]
			d.kb = Vector3.ZERO
			d.velocity = Vector3.ZERO
			d.cool = 999.0
			if d.state in ["air", "down", "getup"]:
				d.state = "chase"

func tap(a: String) -> void:
	P.auto_input = {a: "press"}
	await get_tree().physics_frame
	P.auto_input = {}
	await get_tree().physics_frame

func wait_switch() -> void:
	var n := 0
	while (P.state == "switch" or P.switch_to != "") and n < 200:
		await get_tree().physics_frame
		n += 1

func clear() -> void:
	anchors = []
	for en in game.enemies:
		if is_instance_valid(en):
			en.queue_free()
	game.enemies = []
	await frames(3)

func stage() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	game.tag.auto_assist = false
	game.buddy.wait = 999.0
	await clear()
	game.mode = "fight"
	game.pending = []
	game.waves = []

func use(sid: String) -> void:
	if P.hero != HERO[sid]:
		game.tag.tag_cd = 0.0
		game.swap_heroes()
		await frames(40)
	await wait_switch()
	for attempt in 4:
		if P.style.id == sid:
			break
		await tap(KEYS[sid])
		await wait_switch()
		await frames(20)
	ok(P.style.id == sid, "стенд: выбран стиль %s" % sid)
	# ресурсы стилей — с нуля: замер не зависит от прошлого
	P.breaker.flow = 0
	P.breaker.boost = 1.0
	P.skate.charges = 0
	P.guitar.distortion = 0.0
	P.guitar.on_beat = false
	P.flow.boost_t = 0.0
	game.tag.boost_t = 0.0
	P.global_position = Vector3(0, 0.05, 0)
	P.face = PI
	game.cam_yaw = 0.0           # камера смотрит туда же, куда герой (на манекены): удары идут по ним
	P.state = "move"
	P.inv = 9999.0
	P.rage = 0.0
	P.swag = 0.0
	if P.skate.on:
		P.skate.off()

func dummy(at: Vector3, kind := "bot"):
	var d = game._make_enemy(kind, "", at)
	d.max_hp = 1.0e9
	d.hp = 1.0e9
	d.cool = 999.0
	anchors.append([d, at])
	return d

## Серия по шаблону: L — лёгкие, H — тяжёлые, LLH — две лёгкие и тяжёлый; TG — у ТЯГИ: держать втягивание и выстрел
func run(pat: String, sec: float) -> Dictionary:
	game.dmg_log = []
	var n: int = int(sec * 60.0)
	var seq: Array = []
	match pat:
		"L":
			seq = ["attack"]
		"H":
			seq = ["heavy"]
		_:
			seq = ["attack", "attack", "heavy"]
	var k := 0
	for i in n:
		P.inv = 9999.0
		if pat == "TG":
			var c: int = i % 75
			P.auto_input = {"attack": "hold"} if c < 26 else ({"throw": "press"} if c == 28 else ({"heavy": "press"} if c == 46 else {}))
		elif i % 6 == 0:
			P.auto_input = {String(seq[k % seq.size()]): "press"}
			k += 1
		else:
			P.auto_input = {}
		if OS.get_cmdline_user_args().has("--dmgdebug") and i % 20 == 0:
			var dd = anchors[0][0] if not anchors.is_empty() else null
			print("DBG f%d st=%s cur=%s face=%.2f pos=%s d=%s dst=%s alive=%s log=%d" % [i, P.state, P.combat.cur.id if P.combat.cur != null else "-", P.face, str(P.global_position), str(dd.global_position) if dd else "-", dd.state if dd else "-", dd.alive() if dd else false, game.dmg_log.size()])
		await get_tree().physics_frame
	P.auto_input = {}
	var lg: Array = game.dmg_log
	game.dmg_log = null
	var sum := 0.0
	var at5 := 0.0
	var f0: int = int(lg[0][3]) if not lg.is_empty() else 0
	var burst := 0.0
	for i in lg.size():
		var e: Array = lg[i]
		sum += float(e[2])
		if int(e[3]) - f0 < 300:
			at5 += float(e[2])
		var w := 0.0
		for j in range(i, lg.size()):
			if int(lg[j][3]) - int(e[3]) >= 60:
				break
			w += float(lg[j][2])
		burst = maxf(burst, w)
	return {"sum": sum, "at5": at5, "hits": lg.size(), "burst": burst, "log": lg, "dps": sum / sec}

## J: одна атака не бьёт одну цель дважды в один кадр; урон конечный
func sane(lg: Array, what: String) -> void:
	var seen := {}
	var dup := 0
	var bad := 0
	for e in lg:
		var key := "%s|%d|%d" % [e[0], e[1], e[3]]
		if seen.has(key):
			dup += 1
		seen[key] = true
		if is_nan(float(e[2])) or is_inf(float(e[2])) or float(e[2]) < 0.0:
			bad += 1
	ok(dup == 0, "%s: ни одна атака не бьёт одну цель дважды за кадр (%d)" % [what, dup])
	ok(bad == 0, "%s: урон конечный и не отрицательный" % what)

func _run() -> void:
	await stage()
	if OS.get_cmdline_user_args().has("--dmgdebug2"):
		for sid in ["vozduh"]:
			dps[sid] = 50.0
		await duo_block()
		await boss_block()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--dmgdebug"):
		await use("vozduh")
		dummy(Vector3(0, 0.05, -1.6))
		await frames(70)
		var r: Dictionary = await run("L", 3.0)
		print("DBG L sum ", r["sum"])
		get_tree().quit()
		return
	for mode in ["BASELINE", "ALL"]:
		for k in game.up:
			game.up[k] = 0 if mode == "BASELINE" else 5
		game._apply_upgrades()
		row("==== РЕЖИМ %s: dmg_mul %.2f, здоровье %d ====" % [mode, P.dmg_mul, int(P.max_hp)])
		await styles_block(mode)
	for k in game.up:
		game.up[k] = 0
	game._apply_upgrades()
	await duo_block()
	await mobs_block()
	await boss_block()
	incoming_block()
	print("DAMAGECHECK ok" if fails == 0 else "DAMAGECHECK ОШИБОК: %d" % fails)
	get_tree().quit()

# ---------------- A, B, C, H, I, J ----------------
func styles_block(mode: String) -> void:
	for sid in Styles.ORDER:
		await use(sid)
		var s: StyleData = P.style
		# A: урон по данным
		if mode == "BASELINE":
			var wrong := 0
			for aid in s.attacks:
				var a: AttackData = s.attacks[aid]
				var d: float = P.combat.damage_for(a)
				if absf(d - a.damage) > 0.001:
					wrong += 1
			ok(wrong == 0, "A %s: без усилений урон = AttackData.damage у всех %d атак (не совпало %d)" % [sid, s.attacks.size(), wrong])
		# B, H: усиления и их произведение (ресурсы стилей — с нуля)
		P.breaker.flow = 0
		P.breaker.boost = 1.0
		P.skate.charges = 0
		P.guitar.distortion = 0.0
		P.guitar.on_beat = false
		var a0: AttackData = s.attacks.values()[0]
		P.rage = 8.0
		var r1: float = P.combat.damage_for(a0) / a0.damage
		P.rage = 0.0
		P.flow.boost_t = 1.0
		var r2: float = P.combat.damage_for(a0) / a0.damage
		P.flow.boost_t = 0.0
		game.tag.boost_t = 1.0
		var r3: float = P.combat.damage_for(a0) / a0.damage
		game.tag.boost_t = 0.0
		# всё сразу: ПЕРЕГРУЗ + Perfect Swap + Tag + максимум стиля
		P.rage = 8.0
		P.flow.boost_t = 1.0
		game.tag.boost_t = 1.0
		if sid == "skateboard":
			P.skate.charges = int(StyleSkateboard.RIDE["max_charges"])
		if sid == "guitar":
			P.guitar.distortion = 5.0
			P.guitar.on_beat = true
		if sid == "breaker":
			P.breaker.flow = 99.0
			P.breaker.boost = 1.5
		var top: float = P.combat.damage_for(a0) / a0.damage
		ok(P.damage_bonus(a0) <= Balance.MOMENT_CAP + 0.001, "H %s %s: усиления момента вместе ≤ ×%.1f (%.2f)" % [mode, sid, Balance.MOMENT_CAP, P.damage_bonus(a0)])
		P.rage = 0.0
		P.flow.boost_t = 0.0
		game.tag.boost_t = 0.0
		P.skate.charges = 0
		P.guitar.distortion = 0.0
		P.guitar.on_beat = false
		P.breaker.flow = 0.0
		P.breaker.boost = 1.0
		row("B %s %s: ПЕРЕГРУЗ ×%.2f · Perfect Swap ×%.2f · Tag ×%.2f · всё сразу ×%.2f" % [mode, sid, r1 / P.dmg_mul, r2 / P.dmg_mul, r3 / P.dmg_mul, top])
		ok(absf(r1 / P.dmg_mul - Balance.RAGE_MUL) < 0.01, "B %s: ПЕРЕГРУЗ ×%.1f ровно один раз" % [sid, Balance.RAGE_MUL])
		ok(is_finite(top) and top < 6.0, "H %s %s: все усиления вместе ×%.2f — конечно и < 6" % [mode, sid, top])
		# C: серии
		var d1 = dummy(Vector3(0, 0.05, -1.6))
		await frames(70)
		var res := {}
		for pat in (["TG", "H", "LLH"] if sid == "tyaga812" else ["L", "H", "LLH"]):
			await use(sid)
			await frames(20)
			var r: Dictionary = await run(pat, 10.0)
			res[pat] = r
			sane(r["log"], "J %s %s %s" % [mode, sid, pat])
			row("C %s %s %-3s: 10 с — %d урона, %d попаданий, DPS %.1f, за 5 с %d, всплеск за 1 с %d" % [mode, sid, pat, int(r["sum"]), int(r["hits"]), float(r["dps"]), int(r["at5"]), int(r["burst"])])
		if mode == "BASELINE":
			dps[sid] = float((res["LLH"] as Dictionary)["dps"])
		await clear()
		# I: по группе
		if mode == "BASELINE":
			var line := "I %s LLH 5 с:" % sid
			var one := 0.0
			for n in [1, 3, 5]:
				for i in n:
					var a: float = (i - (n - 1) * 0.5) * 0.45
					dummy(Vector3(sin(a) * 1.9, 0.05, -cos(a) * 1.9))
				await frames(70)
				await use(sid)
				var r2b: Dictionary = await run("LLH" if sid != "tyaga812" else "TG", 5.0)
				if n == 1:
					one = maxf(1.0, float(r2b["sum"]))
				line += " %d целей — %d (×%.2f)" % [n, int(r2b["sum"]), float(r2b["sum"]) / one]
				sane(r2b["log"], "I %s %d целей" % [sid, n])
				await clear()
			row(line)

# ---------------- D: дуэт ----------------
func duo_block() -> void:
	var D: Duo = game.tag.duo
	for pa in ["vozduh", "bottles", "tyaga812"]:
		for pb in ["skateboard", "guitar", "breaker"]:
			for lead in [pa, pb]:
				await use(lead)
				P.heroes[game.tag.mate()]["style"] = pb if lead == pa else pa
				var d = dummy(Vector3(0, 0.05, -3.0))
				await frames(70)
				game.tag.assist_cd = 0.0
				P.combat.interrupt()
				P.state = "move" if P.state != "tyaga" else P.state
				D.buf_t = -9.0
				game.tag.down = {"pahan": false, "madk1d": false}
				await frames(10)
				if OS.get_cmdline_user_args().has("--dmgdebug2"):
					print("DBG duo block=", game.tag.assist_block(), " phase=", D.phase, " buf=", D.buf_t, " st=", P.state, " hero=", P.hero, " down=", game.tag.down)
				game.dmg_log = []
				var t0 := GameClock.ms()
				await tap("assist")
				var n := 0
				while (D.active() or D.buf_t > -9.0) and n < 400:
					P.inv = 9999.0
					await get_tree().physics_frame
					n += 1
				var lg: Array = game.dmg_log
				game.dmg_log = null
				var sum := 0.0
				for e in lg:
					sum += float(e[2])
				var sec: float = n / 60.0
				var avg := 0.0
				for k in dps:
					avg += float(dps[k])
				avg /= maxf(1.0, dps.size())
				var base: float = avg * maxf(sec, 0.5)      # средняя серия стилей за то же время
				row("D %s|%s ведёт %s: %d урона за %.2f с (обычная серия за то же время ≈ %d, ×%.2f)" % [pa, pb, lead, int(sum), sec, int(base), sum / maxf(1.0, base)])
				ok(sum / maxf(1.0, base) >= 1.0 and sum / maxf(1.0, base) < 3.5, "D %s|%s (%s): дуэт не слабее средней серии того же времени и не больше ×3,5 (×%.2f)" % [pa, pb, lead, sum / maxf(1.0, base)])
				sane(lg, "D %s|%s" % [pa, pb])
				await clear()

# ---------------- E: мобы ----------------
func mobs_block() -> void:
	var avg := 0.0
	for k in dps:
		avg += float(dps[k])
	avg /= maxf(1.0, dps.size())
	row("E средний DPS серии LLH по стилям: %.1f" % avg)
	for kind in ["bot", "clipper", "hater", "troll", "ghost", "lawyer", "mod", "farmer"]:
		var c: Dictionary = Enemy_KINDS()[kind]
		var hp: float = float(Balance.MOB_HP.get(kind, c["hp"])) * float(game.diff_hp)
		var line := "E %s: здоровье %d, урон %d, броня %s —" % [kind, int(hp), int(c["dmg"]), str(Enemy_REACT().get(kind, {}).get("armor", 0))]
		var fastest := 99.0
		var slowest := 0.0
		for sid in dps:
			var ttk: float = hp / maxf(1.0, float(dps[sid]))
			fastest = minf(fastest, ttk)
			slowest = maxf(slowest, ttk)
			line += " %s %.1f с" % [sid, ttk]
		row(line)
		ok(fastest >= 0.6 and slowest <= 25.0, "E %s: время убийства от %.1f до %.1f с — не губка и не бумага" % [kind, fastest, slowest])

static func Enemy_KINDS() -> Dictionary:
	return preload("res://scripts/enemy.gd").KINDS

static func Enemy_REACT() -> Dictionary:
	return preload("res://scripts/enemy.gd").REACT

# ---------------- F: боссы и Overdrive ----------------
func boss_block() -> void:
	var avg := 0.0
	for k in dps:
		avg += float(dps[k])
	avg /= maxf(1.0, dps.size())
	var bosses: Dictionary = game.story["BOSS"]
	for bid in bosses:
		var b: Dictionary = bosses[bid]
		var hp: float = float(b["hp"]) * Balance.BOSS_HP * float(game.diff_hp)
		var nph: int = (b["phases"] as Array).size()
		row("F %s: здоровье %d (%d фаз по %d), урон %d, при среднем DPS %.0f — %.0f с чистого боя" % [b["n"], int(hp), nph, int(hp / nph), int(b["dmg"]), avg, hp / maxf(1.0, avg)])
	# лимит Overdrive по боссу
	for open in [false, true]:
		await use("vozduh")
		var bn = game._make_enemy("", "courier", Vector3(0, 0.05, -3.0))
		await frames(90)
		bn.special_cd = 999.0
		bn.cool = 999.0
		if open:
			bn.weak_t = 30.0
		var hp0: float = bn.hp
		game.hype.value = TeamHype.MAX
		print("DBG hype block=", game.hype.block(), " st=", P.state)
		await tap("overdrive")
		var n := 0
		while game.hype.active() and n < 900:
			P.inv = 9999.0
			bn.cool = 999.0
			if open:
				bn.weak_t = 30.0
			await get_tree().physics_frame
			n += 1
		var lost: float = hp0 - bn.hp
		var cap: float = (TeamHype.BOSS_CAP_OPEN if open else TeamHype.BOSS_CAP) * bn.max_hp
		row("F Overdrive по боссу%s: снято %d из %d (лимит %d)" % [" (ОТКРЫТ)" if open else "", int(lost), int(bn.max_hp), int(cap)])
		ok(lost <= cap + 0.5 and lost > 0.0, "F Overdrive не обходит лимит по боссу%s" % (" (ОТКРЫТ)" if open else ""))
		await clear()

# ---------------- G: входящий урон ----------------
func incoming_block() -> void:
	var hero_hp: float = 100.0
	for kind in EnemyAI.MOVES:
		var c: Dictionary = Enemy_KINDS()[kind]
		var worst := 0.0
		var worst_id := ""
		var chain := 0.0
		for id in EnemyAI.MOVES[kind]:
			var m: Dictionary = EnemyAI.MOVES[kind][id]
			var d: float = float(m.get("dmg_abs", float(c["dmg"]) * float(m.get("dmg", 1.0)))) * float(EnemyAI.TUNE["dmg"]) * 1.25
			if String(m["act"]) == "shoot":
				d *= float(m.get("n", 1)) if not m.has("spread") else 1.0
			if d > worst:
				worst = d
				worst_id = id
		row("G %s: самый сильный приём %s — %d (%.0f%% здоровья героя, с усилением фермера)" % [kind, worst_id, int(worst), worst / hero_hp * 100.0])
		ok(worst < hero_hp * 0.4, "G %s: ни один приём не снимает 40%% здоровья героя за раз" % kind)
	var bosses: Dictionary = game.story["BOSS"]
	for bid in bosses:
		var dm: float = float(bosses[bid]["dmg"])
		var top: float = dm * 2.2 if bid == "algo" else dm * 1.5      # самые тяжёлые множители в приёмах босса
		row("G %s: обычный удар %d, самый тяжёлый приём ≈ %d (%.0f%% здоровья)" % [bosses[bid]["n"], int(dm), int(top), top / hero_hp * 100.0])
		ok(top < hero_hp * 0.6, "G %s: ни один удар босса не убивает с полного здоровья (%.0f%%)" % [bosses[bid]["n"], top / hero_hp * 100.0])
