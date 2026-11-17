## Профили эффектов боя: у каждой атаки (AttackData.id) свой рисунок попадания.
## Профиль — список примитивов fx.gd ("arc" — дуга-след, "shock" — ударное кольцо, "debris" — осколки/щепки/камни,
## "streaks" — струи воздуха, "spark" — искры, "flash" — вспышка, "twirl" — вихрь по земле, "crack" — трещина),
## каждый с параметрами. Строится из данных самой атаки (вид, сила, подброс, удар в землю, вращение, дальность)
## + мотив стиля (материал оружия) + ручные правки для приёмов-подписей (OVERRIDE). Разброс по хэшу id делает
## рисунок каждой атаки своим даже у соседних ударов цепочки — проверка (--vfxcheck) требует, чтобы подписи не совпадали.
## Эффект запускает только настоящее попадание (enemy.take_hit_info → fx.attack_vfx): по промаху ничего не рисуется.
## Новая атака получает профиль сама; особый вид — строкой в OVERRIDE.
class_name VfxProfiles

## Мотив стиля: палитра (основной, кромка, «горячий») и материал оружия
const STYLE := {
	"vozduh": {"main": Color(1.0, 0.78, 0.4), "edge": Color(1.0, 0.97, 0.88), "hot": Color(1.0, 0.45, 0.15),
		"debris": "metal", "edge_k": 0.85, "grain": 0.0, "bands": 0.0, "rays": 6, "segs": 0, "waves": 0, "width": 0.55, "air": false},
	"bottles": {"main": Color(0.5, 0.86, 1.0), "edge": Color(0.9, 1.0, 1.0), "hot": Color(0.75, 0.95, 1.0),
		"debris": "glass", "edge_k": 1.0, "grain": 0.35, "bands": 0.0, "rays": 8, "segs": 0, "waves": 0, "width": 0.3, "air": false},
	"tyaga812": {"main": Color(0.78, 0.95, 1.0), "edge": Color(1.0, 1.0, 1.0), "hot": Color(1.0, 0.6, 0.3),
		"debris": "", "edge_k": 0.2, "grain": 0.0, "bands": 3.0, "rays": 0, "segs": 0, "waves": 2, "width": 0.8, "air": true},
	"skateboard": {"main": Color(1.0, 0.84, 0.3), "edge": Color(0.45, 0.9, 1.0), "hot": Color(1.0, 0.92, 0.45),
		"debris": "wood", "edge_k": 0.55, "grain": 0.2, "bands": 0.0, "rays": 4, "segs": 4, "waves": 0, "width": 0.6, "air": false},
	"guitar": {"main": Color(0.85, 0.45, 1.0), "edge": Color(1.0, 0.86, 0.45), "hot": Color(1.0, 0.85, 0.4),
		"debris": "", "edge_k": 0.5, "grain": 0.0, "bands": 5.0, "rays": 0, "segs": 0, "waves": 3, "width": 0.5, "air": false},
	"breaker": {"main": Color(1.0, 0.42, 0.75), "edge": Color(0.45, 0.92, 1.0), "hot": Color(1.0, 0.55, 0.9),
		"debris": "", "edge_k": 0.75, "grain": 0.1, "bands": 0.0, "rays": 5, "segs": 0, "waves": 0, "width": 0.25, "air": false},
}

## Приёмы-подписи: что добавить к собранному из данных (или заменить, если "only": true)
const OVERRIDE := {
	# Балон: добивания и Heat — раскалённый металл, трещины, столб давления
	"vz_finisher": [{"p": "crack", "s": 1.4}, {"p": "shock", "s": 4.2, "rays": 10, "col": "hot", "bill": 0}],
	"vz_quake": [{"p": "crack", "s": 2.2}, {"p": "shock", "s": 6.0, "waves": 3, "col": "hot", "bill": 0}, {"p": "debris", "kind": "stone", "n": 20}],
	"vz_heat_smash": [{"p": "crack", "s": 1.8}, {"p": "flash", "s": 2.6, "tex": "magic_05", "col": "hot"}],
	"vz_heat_swing": [{"p": "arc", "len": 300, "tilt": 0, "r": 2.3, "w": 0.7, "col": "hot"}],
	"vz_heat_spike": [{"p": "shock", "s": 3.0, "rays": 12, "col": "hot"}],
	"vz_heat_finish": [{"p": "crack", "s": 2.0}, {"p": "shock", "s": 5.0, "waves": 2, "col": "hot", "bill": 0}, {"p": "flash", "s": 3.0, "tex": "star_08", "col": "edge"}],
	"vz_heat_air": [{"p": "arc", "len": 200, "tilt": 95, "r": 2.0, "w": 0.75, "col": "hot"}],
	"vz_perfect_swing": [{"p": "shock", "s": 2.6, "rays": 14, "col": "edge"}],
	"vz_perfect_launch": [{"p": "streaks", "n": 14, "up": true}],
	"vz_parry_light": [{"p": "flash", "s": 1.6, "tex": "star_06", "col": "edge"}],
	"vz_parry_heavy": [{"p": "shock", "s": 2.8, "rays": 8, "col": "edge"}],
	"vz_bottle": [{"p": "debris", "kind": "glass", "n": 16}, {"p": "spark", "n": 8, "col": "edge"}],
	# Водяра: осколки, брызги, звон
	"bt_rico": [{"p": "shock", "s": 1.8, "segs": 6, "col": "edge"}, {"p": "spark", "n": 14, "col": "edge"}],
	"bt_fan": [{"p": "debris", "kind": "glass", "n": 22}],
	"bt_power": [{"p": "shock", "s": 2.6, "waves": 1, "col": "edge"}, {"p": "debris", "kind": "glass", "n": 24}],
	"bt_crush": [{"p": "debris", "kind": "glass", "n": 26}, {"p": "flash", "s": 2.0, "tex": "star_09", "col": "edge"}],
	"bt_dsmash": [{"p": "debris", "kind": "glass", "n": 26}, {"p": "crack", "s": 0.9}],
	# ТЯГА-812: воздух, давление, нагрев
	"tg_burst": [{"p": "shock", "s": 6.5, "waves": 4, "col": "main", "bill": 0}, {"p": "streaks", "n": 24}],
	"tg_shot": [{"p": "streaks", "n": 18}, {"p": "shock", "s": 2.0, "waves": 2, "col": "edge"}],
	"tg_slam": [{"p": "crack", "s": 1.4}, {"p": "shock", "s": 4.6, "waves": 2, "col": "main", "bill": 0}],
	"tg_ram": [{"p": "streaks", "n": 16}, {"p": "shock", "s": 2.4, "rays": 6, "col": "hot"}],
	"tg_airram": [{"p": "streaks", "n": 20, "up": true}],
	"tg_suck": [{"p": "shock", "s": 2.2, "waves": 3, "col": "main", "inward": true}],
	"tg_spin": [{"p": "twirl", "s": 3.6}],
	# Скейт: щепки, колёса, шкурка
	"sk_slam": [{"p": "crack", "s": 1.2}, {"p": "debris", "kind": "wood", "n": 20}, {"p": "shock", "s": 4.0, "segs": 8, "col": "main", "bill": 0}],
	"sk_airslam": [{"p": "crack", "s": 1.3}, {"p": "shock", "s": 4.4, "segs": 4, "col": "edge", "bill": 0}],
	"sk_spin360": [{"p": "arc", "len": 340, "tilt": 0, "r": 2.2, "w": 0.4, "col": "main"}, {"p": "twirl", "s": 3.0}],
	"sk_kickflip": [{"p": "arc", "len": 260, "tilt": 90, "r": 1.0, "w": 0.6, "col": "edge"}],
	"sk_ollie": [{"p": "streaks", "n": 10, "up": true}],
	"sk_shove": [{"p": "shock", "s": 2.0, "segs": 4, "col": "edge"}],
	# Гитара: звуковые волны, аккорды, фидбэк
	"gt_chord": [{"p": "shock", "s": 4.0, "waves": 4, "col": "main"}, {"p": "shock", "s": 2.4, "segs": 12, "col": "edge"}],
	"gt_final": [{"p": "shock", "s": 6.0, "waves": 4, "col": "main", "bill": 0}, {"p": "flash", "s": 3.0, "tex": "star_08", "col": "edge"}],
	"gt_feedback": [{"p": "shock", "s": 3.4, "waves": 4, "segs": 10, "col": "main"}],
	"gt_airriff1": [{"p": "shock", "s": 2.4, "waves": 2, "col": "edge"}],
	"gt_airriff2": [{"p": "shock", "s": 2.8, "waves": 3, "col": "edge"}],
	"gt_slam": [{"p": "crack", "s": 1.2}, {"p": "shock", "s": 4.6, "waves": 3, "col": "main", "bill": 0}],
	# Breaker: удары ногами, вращения, фриз
	"br_freeze": [{"p": "shock", "s": 3.0, "rays": 10, "segs": 6, "col": "edge"}, {"p": "flash", "s": 2.2, "tex": "star_06", "col": "edge"}],
	"br_finisher": [{"p": "shock", "s": 4.2, "rays": 12, "col": "hot"}, {"p": "crack", "s": 1.0}],
	"br_windmill": [{"p": "twirl", "s": 3.4}],
	"br_heli": [{"p": "twirl", "s": 3.8}],
	"br_headspin": [{"p": "twirl", "s": 3.0}, {"p": "shock", "s": 2.6, "segs": 5, "col": "edge", "bill": 0}],
	"br_flare": [{"p": "twirl", "s": 3.2}],
	"br_handspin": [{"p": "twirl", "s": 2.8}],
	"br_airdive": [{"p": "crack", "s": 0.9}, {"p": "shock", "s": 3.6, "rays": 5, "col": "main", "bill": 0}],
	"br_cc": [{"p": "streaks", "n": 10}],
	"br_backflip": [{"p": "arc", "len": 220, "tilt": 92, "r": 1.4, "w": 0.3, "col": "edge"}],
}

## Командные приёмы (не атаки стиля): смена героя, дуэт, Overdrive — палитра пары
const TEAM := {"main": Color(1.0, 0.86, 0.45), "edge": Color(0.55, 0.85, 1.0), "hot": Color(1.0, 0.5, 0.3),
	"debris": "", "edge_k": 0.7, "grain": 0.0, "bands": 0.0, "rays": 8, "segs": 0, "waves": 1, "width": 0.5, "air": false}

static var _cache := {}

static func motif(style_id: String) -> Dictionary:
	return STYLE.get(style_id, TEAM)

## Профиль атаки: {"id", "style", "prims": [...], "sig": строка-подпись}. Кэшируется по id.
static func of(a: AttackData, style_id: String) -> Dictionary:
	var key := style_id + "/" + a.id
	if _cache.has(key):
		return _cache[key]
	var m: Dictionary = motif(style_id)
	var h: int = absi(hash(a.id))
	var r1: float = float(h % 1000) / 1000.0
	var r2: float = float((h / 1000) % 1000) / 1000.0
	var r3: float = float((h / 1000000) % 1000) / 1000.0
	var prims: Array = []
	var low: bool = String(a.extra.get("react", "")) == "knockdown" or a.id.contains("sweep") or a.id.contains("slide")
	var up: bool = a.launch > 3.0 or a.kind == "launcher" or a.id.contains("launch") or a.id.contains("upper") or a.id.contains("rise")
	var down: bool = a.slam >= 0.0 or a.launch < 0.0 or a.kind == "slam" or a.id.contains("over") or a.id.contains("smash") or a.id.contains("dive")
	var spin: bool = a.spin >= 0.75
	var ranged: bool = a.projectile != ""
	var p: int = clampi(a.power, 0, 2)
	# --- дуга-след: у всего, кроме чистых снарядов и воздуха ТЯГИ
	if not ranged and not (bool(m["air"]) and a.kind in ["ranged", "heat"]):
		var tilt: float = lerpf(-55.0, 55.0, r1)
		var span: float = 120.0 + 50.0 * p + 40.0 * r2
		var flip := 1.0 if r3 < 0.5 else -1.0
		if up:
			tilt = 88.0
			flip = -1.0
		elif down:
			tilt = 92.0
			flip = 1.0
		elif low:
			tilt = 8.0 * (1.0 if r1 < 0.5 else -1.0)
		if spin:
			span = 300.0 + 40.0 * r2
			tilt = lerpf(-12.0, 12.0, r1)
		prims.append({"p": "arc", "len": snappedf(span, 1.0), "tilt": snappedf(tilt, 1.0), "flip": flip,
			"r": snappedf(clampf(a.reach * 0.5, 0.9, 2.4) * (1.2 if spin else 1.0), 0.05), "low": low,
			"w": snappedf(clampf(float(m["width"]) + 0.12 * p + 0.1 * (r2 - 0.5), 0.12, 0.95), 0.01),
			"edge": float(m["edge_k"]), "grain": float(m["grain"]), "bands": float(m["bands"]),
			"col": "hot" if p >= 2 else "main", "dur": snappedf(0.16 + 0.04 * p + (0.08 if spin else 0.0), 0.01)})
	# --- снаряд: всплеск у цели — свой у каждого броска (размер, разрывы, эхо)
	if ranged:
		prims.append({"p": "shock", "s": snappedf(0.9 + 0.7 * r1 + 0.4 * p, 0.05), "segs": 3 + h % 6, "waves": (h / 7) % 2,
			"col": "edge", "bill": 1, "thick": snappedf(0.08 + 0.08 * r2, 0.01)})
	# --- ударное кольцо: от тяжёлых; у стиля — свои лучи, эхо и разрывы
	if p >= 1 or a.heavy:
		prims.append({"p": "shock", "s": snappedf(1.0 + 0.6 * p + 0.3 * r3, 0.05), "rays": int(m["rays"]) + (h % 3 if int(m["rays"]) > 0 else 0),
			"waves": int(m["waves"]), "segs": int(m["segs"]) + (h % 2) * 2 if int(m["segs"]) > 0 else 0,
			"col": "edge" if p == 1 else "hot", "bill": 1, "thick": snappedf(0.12 + 0.05 * p, 0.01)})
	# --- материал оружия
	match String(m["debris"]):
		"glass":
			prims.append({"p": "debris", "kind": "glass", "n": 6 + 5 * p + h % 4})
		"wood":
			if p >= 1 or r1 > 0.6:
				prims.append({"p": "debris", "kind": "wood", "n": 4 + 4 * p + h % 3})
		"metal":
			prims.append({"p": "spark", "n": 8 + 8 * p + h % 5, "col": "edge"})
	if bool(m["air"]):
		prims.append({"p": "streaks", "n": 8 + 6 * p + h % 4, "up": up})
	if style_id == "guitar" and p == 0:
		prims.append({"p": "shock", "s": snappedf(1.0 + 0.5 * r2, 0.05), "waves": 1 + h % 2, "col": "main", "bill": 1, "thick": 0.08})
	if style_id == "breaker" and (low or spin):
		prims.append({"p": "twirl", "s": snappedf(1.6 + r1, 0.05)})
	if down and p >= 1:
		prims.append({"p": "crack", "s": snappedf(0.7 + 0.3 * p, 0.05)})
	if up:
		prims.append({"p": "streaks", "n": 6 + 4 * p, "up": true})
	# --- подпись приёма
	if OVERRIDE.has(a.id):
		for o in OVERRIDE[a.id]:
			prims.append(o)
	var prof := {"id": a.id, "style": style_id, "prims": prims, "sig": style_id + ":" + str(prims)}
	_cache[key] = prof
	return prof

## Цвет примитива по ключу палитры
static func col(m: Dictionary, k: String) -> Color:
	return m.get(k, m["main"]) as Color

## Подсказка для проверки и аудита: какие стили и атаки есть
static func all_attacks() -> Array:
	var out: Array = []
	for sid in Styles.ORDER:
		var s: StyleData = Styles.by_id(sid)
		for aid in s.attacks:
			out.append([sid, s.attacks[aid]])
	return out
