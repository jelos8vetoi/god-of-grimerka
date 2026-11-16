## Физический iPod в руке Пахана и проводные EarPods: слой поверх анимаций (после AnimationPlayer и инерции балона).
## Правая рука занята балоном, поэтому iPod живёт в левом кармане штанов и достаётся левой рукой.
## Доставание — функция одного числа u: 0 — в кармане, 1 — перед собой. Открытие ведёт u вверх, закрытие — вниз,
## поэтому быстрые повторные нажатия просто разворачивают движение: ни рывков, ни второго устройства.
##   0 … U_GRAB      рука идёт к карману по дуге, плечо опускается, корпус чуть наклоняется, взгляд — на карман
##   U_GRAB … U_DRAW кулак в кармане, устройство переходит из кармана в хват
##   U_DRAW … 1      рука вытаскивает iPod, запястье разворачивает экран к лицу, взгляд догоняет экран
## Наушники — ещё два числа (тоже обратимых):
##   a (правая рука): отпускает балон (он остаётся прислонённым к ноге) → берёт правый вкладыш у iPod → вставляет в правое ухо →
##                    берёт левый вкладыш → передаёт его в левую руку → возвращается к балону и снова берёт его
##   b (левая рука, с iPod): подносит левый вкладыш к левому уху, вставляет, возвращает iPod к глазам
## Через голову чиби короткие руки не дотягиваются, поэтому каждое ухо обслуживает своя рука.
## Где вкладыш, — функция a и b: до захвата он висит на проводе у iPod, между захватом и ухом — в щепоти руки, дальше — в ухе.
## На границах точка щепоти совпадает с точкой хранения или уха, поэтому крепление переключается без скачка.
## Руки решаются двухзвенным IK (плечо — локоть — кисть). Пальцы у модели сжаты в кулак и по фалангам не анимируются:
## iPod лежит на кулаке, вкладыш зажат у края кулака со стороны указательного пальца.
class_name PodHand
extends SkeletonModifier3D

enum St { STOWED, REACHING, GRABBING, DRAWING, INSPECTING, LOWERING, PUTTING_AWAY }
const NAMES := ["STOWED", "REACHING", "GRABBING", "DRAWING", "INSPECTING", "LOWERING", "PUTTING_AWAY"]
const T_OPEN := 1.25         # секунд от кармана до лица
const T_CLOSE := 0.8         # убрать — быстрее, чем достать: игрок не ждёт
const T_REOPEN := 0.8        # повторное открытие (наушники уже в ушах): только достать iPod
const U_GRAB := 0.38
const U_DRAW := 0.5
# Точки в пространстве скелета в позе привязки (x — левая рука героя, y — вверх, z — вперёд; рост модели ≈ 0.8, голова — от 0.51 до 0.97)
const POCKET := Vector3(0.108, 0.268, 0.03)    # левый карман штанов: сбоку-спереди на бедре
const OUT := Vector3(0.17, 0.36, 0.11)         # через эту точку рука выходит из кармана — в сторону от бедра
const VIEW := Vector3(0.075, 0.385, 0.15)       # кулак с iPod перед грудью, левее середины
const EYE := Vector3(0.0, 0.665, 0.17)         # между глаз (за очками), по вершинам модели
const HOLD := 0.1          # кулак держит iPod чуть ниже середины: доля высоты от центра корпуса до центра кулака
const OUT_PALM := 0.36     # и насколько корпус вынесен из ладони: кулак у модели толстый, в его середине iPod утонул бы целиком
const LOOK_NECK := 0.14     # пределы доворота шеи и головы к экрану, рад: у чиби голова огромная, сильный наклон закрывает руки
const LOOK_HEAD := 0.34
const DEV_H := 0.125                           # высота iPod (≈ 24 см при росте героя 1.85 м: вдвое крупнее настоящего — под кулаки и голову чиби, иначе его не разглядеть)
# уши: стык щеки и волос под дужкой очков (по цвету текстуры кожа лица кончается на |x| ≈ 0.16); чуть вперёд — иначе вкладыш тонет в волосах
const EAR_L := Vector3(0.17, 0.622, 0.092)
const EAR_R := Vector3(-0.17, 0.622, 0.092)
const OFFER := Vector3(0.005, 0.43, 0.165)     # куда левая рука подаёт iPod, пока правая берёт вкладыши (ближе к середине: правой иначе не дотянуться)
const SPLIT_IN := Vector3(0.0, 0.468, 0.132)   # разветвитель на груди под подбородком, когда оба вкладыша в ушах
const PINCH := 0.03                            # щепоть — край кулака со стороны указательного, от центра кулака
const T_R := 3.6             # правая рука: оба вкладыша
const T_L := 1.9             # левая рука: второй вкладыш (короче и быстрее — движения не зеркальные)
const A_GRAB_R := 0.18       # фазы правой руки (доли a)
const A_APP_R := 0.38
const A_SEAT_R := 0.46
const A_OUT_R := 0.53
const A_GRAB_L := 0.62
const A_HAND_L := 0.74
const A_START_L := 0.8       # с этого места левая рука уже несёт второй вкладыш к уху
const B_APP := 0.5           # фазы левой руки (доли b)
const B_SEAT := 0.62
const B_OUT := 0.72

var rig: Rig
var want := false            # true — достать и смотреть, false — убрать
var u := 0.0
var state := St.STOWED
var device: Node3D
var buds: EarPods
var a := 0.0                 # правая рука и первый вкладыш
var b := 0.0                 # левая рука и второй вкладыш
var buds_want := true        # вкладыши должны быть в ушах; remove_buds() снимает
var hurry := false           # прерывание (удар): всё доигрывается или откатывается втрое быстрее
var balloon_free := false    # правая рука отпустила балон: он стоит, прислонённый к ноге
var w_store := Transform3D() # где стоит отпущенный балон, в осях таза
var w_orig := Transform3D()  # как балон сидел в кулаке
var was_want := false
var hold_out := false       # iPod держится снаружи ради наушников (довести, откатить, снять)
var clock := 0.0
var sfx: PodSfx             # тихие звуки доставания и наушников (scripts/podsfx.gd)
var glow := 0.0              # подсветка экрана настоящего iPod: 0 — погашен, 1 — интерфейс открыт
var lcd_mats: Array = []     # [материал, цвет, яркость] светящихся частей экрана
var tap_kind := ""           # каким было последнее нажатие на колесо: select / menu / next / previous / play / scroll
var frame_dt := 0.0
var pose_hold := false      # главное меню: застывшая поза — iPod у левого уха, наушники надеты, взгляд прямо
var presses := 0            # сколько раз палец нажимал на колесо (для проверки)
var tap := 0.0               # короткое движение большого пальца при нажатии на колесо
var look := Vector3.ZERO     # куда сейчас смотрит герой (точка в пространстве скелета, с отставанием)
var look_goal := Vector3.ZERO
var looking := false
var dbg := {"look": 0.0, "gap": 0.0, "reach": 0.0, "reach_r": 0.0, "miss_r": 0.0, "miss_l": 0.0}   # замеры последнего кадра
var b_hips := -1
var b_sp1 := -1
var b_sp2 := -1
var b_neck := -1
var b_head := -1
var b_lsh := -1
var b_rsh := -1
var b_arm := -1
var b_fa := -1
var b_hand := -1
var b_thumb := -1
var rb_arm := -1
var rb_fa := -1
var rb_hand := -1
var l1 := 0.1
var l2 := 0.1
var rl1 := 0.1
var rl2 := 0.1
var kl := Vector3.UP
var fl := Vector3.RIGHT
var grip_l := Vector3.ZERO
var palm_l := Vector3.FORWARD
var sgn := 1.0
var hand_inv := Basis()
var rgrip_l := Vector3.ZERO
var rsgn := 1.0
var rhand_inv := Basis()
var pinch_l := Vector3.ZERO      # щепоть в осях левой кисти
var pinch_r := Vector3.ZERO      # и правой
var pocket_l := Vector3.ZERO
var out_l := Vector3.ZERO
var view_l := Vector3.ZERO
var offer_l := Vector3.ZERO
var split_l := Vector3.ZERO
var eye_l := Vector3.ZERO
var fwd_l := Vector3.FORWARD
var rot_pocket_l := Basis()
var rot_view_l := Basis()
var rot_r_down := Basis()        # правая кисть берёт вкладыш у iPod (в осях груди)
var rot_r_ear := Basis()         # правая кисть у правого уха
var rot_r_give := Basis()        # правая кисть передаёт вкладыш левой
var rot_l_ear := Basis()         # левая кисть с iPod у левого уха
var ear_xf := {}                 # "L"/"R" → вкладыш в ухе, в осях головы
var mount := Transform3D()       # iPod в осях кисти
var pocket_dev_l := Transform3D() # iPod в кармане, в осях таза

func setup(r: Rig) -> void:
	rig = r
	var sk := rig.skel
	b_hips = rig.bone["hips"]
	b_sp1 = rig.bone["spine1"]
	b_sp2 = rig.bone["spine2"]
	b_neck = rig.bone["neck"]
	b_head = rig.bone["head"]
	b_lsh = rig.bone["lsh"]
	b_rsh = rig.bone["rsh"]
	b_arm = rig.bone["larm"]
	b_fa = rig.bone["lfa"]
	b_hand = rig.bone["lhand"]
	rb_arm = rig.bone["rarm"]
	rb_fa = rig.bone["rfa"]
	rb_hand = rig.bone["rhand"]
	b_thumb = rig._find_bone("LeftHandThumb2")
	l1 = (rig.rest_pos[b_fa] as Vector3).length()
	l2 = (rig.rest_pos[b_hand] as Vector3).length()
	rl1 = (rig.rest_pos[rb_fa] as Vector3).length()
	rl2 = (rig.rest_pos[rb_hand] as Vector3).length()
	# оси кулака в осях кисти: k — линия костяшек (от мизинца к указательному), f — от запястья к костяшкам, ладонь
	var fr := _fist(sk, "l", b_hand)
	kl = fr[0]
	fl = fr[1]
	grip_l = fr[2]
	palm_l = fr[3]
	sgn = fr[4]
	hand_inv = fr[5]
	pinch_l = grip_l + kl * PINCH
	var frr := _fist(sk, "r", rb_hand)
	rgrip_l = frr[2]
	rsgn = frr[4]
	rhand_inv = frr[5]
	pinch_r = rgrip_l + (frr[0] as Vector3) * PINCH
	var hips := sk.get_bone_global_rest(b_hips)
	var chest := sk.get_bone_global_rest(b_sp2)
	var head := sk.get_bone_global_rest(b_head)
	pocket_l = hips.affine_inverse() * POCKET
	out_l = hips.affine_inverse() * OUT
	view_l = chest.affine_inverse() * VIEW
	offer_l = chest.affine_inverse() * OFFER
	split_l = chest.affine_inverse() * SPLIT_IN
	eye_l = head.affine_inverse() * EYE
	fwd_l = head.basis.inverse() * Vector3(0, 0, 1)
	# в кармане: пальцы вниз, ладонь к бедру; перед собой: ладонь вверх и к лицу, пальцы от себя: iPod лежит на кулаке под наклоном, как телефон, в который смотрят у живота
	rot_pocket_l = hips.basis.inverse() * hand_rot(Vector3(0.1, -1, 0.25), Vector3(-1, 0, 0.1))
	# экран наклонён к лицу: устройство лежит на руке примерно под 30° к горизонту, верхний край дальше от героя
	var palm_view := Vector3(-0.05, 0.85, -0.5).normalized()
	var rv := hand_rot(Vector3(-0.25, 0.45, 0.87), palm_view)
	rot_view_l = chest.basis.inverse() * rv
	# правая кисть: к вкладышу у iPod — пальцы вперёд-вниз, ладонь вниз; у уха — пальцы вверх, ладонь к голове;
	# передаёт вкладыш — пальцы к левой руке; левая кисть с iPod у уха — пальцы вверх-вперёд, ладонь наружу, iPod снаружи головы
	rot_r_down = chest.basis.inverse() * hand_rot(Vector3(0.35, -0.45, 0.8), Vector3(0.25, -1, 0.1), "r")
	rot_r_ear = chest.basis.inverse() * hand_rot(Vector3(0.1, 1, 0.3), Vector3(1, 0, 0.15), "r")
	rot_r_give = chest.basis.inverse() * hand_rot(Vector3(0.7, 0.05, 0.7), Vector3(0, -1, 0.2), "r")
	rot_l_ear = chest.basis.inverse() * hand_rot(Vector3(-0.05, 0.9, 0.45), Vector3(1, 0, -0.1))
	# iPod в кулаке: экран — от ладони (к лицу), корпус стоит вертикально, кулак держит нижнюю треть
	var up := (Vector3.UP - palm_view * Vector3.UP.dot(palm_view)).normalized()
	var yl := (rv.inverse() * up).normalized()
	var zl := palm_l
	yl = (yl - zl * yl.dot(zl)).normalized()
	mount = Transform3D(Basis(yl.cross(zl), yl, zl), grip_l + zl * DEV_H * OUT_PALM + yl * DEV_H * HOLD)
	var pz := Vector3(1, 0, 0.25).normalized()
	var py := (Vector3.UP - pz * Vector3.UP.dot(pz)).normalized()
	pocket_dev_l = hips.affine_inverse() * Transform3D(Basis(py.cross(pz), py, pz), POCKET)
	device = _build_device(DEV_H)
	device.visible = false
	sk.add_child(device)
	sfx = PodSfx.new()
	add_child(sfx)
	buds = EarPods.new()
	buds.name = "EarPods"
	sk.add_child(buds)
	# вкладыш в ухе: отверстие динамика — внутрь головы и чуть вперёд, ножка — вниз и чуть вперёд вдоль щеки
	for side in ["L", "R"]:
		var s := 1.0 if side == "L" else -1.0
		var bb := buds.bud_basis(side, Vector3(-s, 0, 0.3), Vector3(0, -1, 0.3))
		ear_xf[side] = head.affine_inverse() * Transform3D(bb, EAR_L if side == "L" else EAR_R)

## Кулак одной руки: [k, f, центр, ладонь, знак, обратный базис] — всё в осях кисти.
func _fist(sk: Skeleton3D, side: String, hb: int) -> Array:
	var hd: Dictionary = rig.hand[side]
	var k := (hd["k"] as Vector3).normalized()
	var f := hd["f"] as Vector3
	f = (f - k * f.dot(k)).normalized()
	var hrest := sk.get_bone_global_rest(hb).basis.orthonormalized()
	var palm := hrest.inverse() * Vector3(0, -1, 0)      # в T-позе ладони смотрят вниз
	var s := 1.0 if f.cross(k).dot(palm) >= 0.0 else -1.0
	palm = f.cross(k) * s
	return [k, f, hd["grip"], palm, s, Basis(f, k, f.cross(k)).inverse()]

## Поворот кисти по двум направлениям: куда смотрят пальцы (от запястья) и куда смотрит ладонь.
func hand_rot(fingers: Vector3, palm: Vector3, side := "l") -> Basis:
	var p := palm.normalized()
	var f := (fingers - p * fingers.dot(p)).normalized()
	var k := p.cross(f) * (sgn if side == "l" else rsgn)
	return Basis(f, k, f.cross(k)) * (hand_inv if side == "l" else rhand_inv)

func _acting() -> bool:
	return (a > 0.0 and a < 1.0) or (b > 0.0 and b < 1.0)

func busy() -> bool:
	return u > 0.0 or _acting() or balloon_free

func state_name() -> String:
	return NAMES[state]

## Состояние устройства: в кармане / достаётся / в руке / убирается.
func device_state() -> String:
	if u <= 0.0:
		return "IN_POCKET"
	if u >= 1.0:
		return "IN_HAND"
	return "DRAWING" if want or hold_out else "STOWING"

## Состояние наушников: убраны / надевается первый / первый надет / надевается второй / оба надеты / снимаются.
func buds_state() -> String:
	if a <= 0.0 and b <= 0.0:
		return "STORED"
	if a >= 1.0 and b >= 1.0:
		return "BOTH_IN"
	if not buds_want:
		return "REMOVING"
	if a < A_SEAT_R:
		return "FIRST_GOING_IN"
	if a < A_GRAB_L and b <= 0.0:
		return "FIRST_IN"
	return "SECOND_GOING_IN"

func buds_in() -> bool:
	return a >= 1.0 and b >= 1.0

## Восстановить наушники без анимации (новая глава, загрузка сохранения).
func set_seated(v: bool) -> void:
	a = 1.0 if v else 0.0
	b = a
	buds_want = true

## Снять наушники: правая и левая рука вынимают их в обратном порядке и вешают на провод у iPod.
## Если iPod в кармане, Пахан сначала достаёт его, а после — убирает обратно. Горячей клавиши нет — для меню и сюжета.
func remove_buds() -> void:
	buds_want = false

## Удар: начатое доигрывается или откатывается втрое быстрее (сам iPod закрывает ipod.gd).
func interrupt() -> void:
	hurry = true

## Гибель или смена сцены: без анимации — всё в ближайшее устойчивое состояние, балон снова в кулаке.
func snap() -> void:
	if a >= A_SEAT_R:
		a = 1.0
		b = 1.0
	else:
		a = 0.0
		b = 0.0
	u = 0.0
	want = false
	hurry = false
	_release_balloon(false)
	if device:
		device.visible = false

## Центр экрана устройства в мире — туда смотрит герой и оттуда «вырастает» интерфейс.
func screen_world() -> Vector3:
	return get_skeleton().global_transform * (device.transform * Vector3(0, DEV_H * 0.23, DEV_H * 0.06))

## Большой палец на колесе: у каждого нажатия свой короткий жест (пальцы у модели отдельными фалангами не гнутся,
## но у большого пальца своя кость — её и поворачиваем; рука и iPod при этом не двигаются).
func press(kind := "select") -> void:
	tap = 1.0
	tap_kind = kind
	presses += 1

static func _ss(x0: float, x1: float, x: float) -> float:
	var t := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _turn(sk: Skeleton3D, bone_i: int, axis: Vector3, ang: float) -> void:
	if bone_i < 0 or absf(ang) < 0.00001:
		return
	var p := sk.get_bone_global_pose(bone_i)
	p.basis = Basis(axis.normalized(), ang) * p.basis
	sk.set_bone_global_pose(bone_i, p)

## Ход действий с наушниками за кадр.
func _step_buds(dt: float) -> void:
	if was_want != want and want:
		buds_want = true            # каждое открытие iPod — снова слушать в наушниках
	was_want = want
	var rate := (3.0 if hurry else 1.0)
	var dir := 0
	if buds_want:
		if want and u >= 1.0 and not buds_in():
			dir = 1
		elif a >= A_SEAT_R and not buds_in():
			dir = 1                 # первый уже в ухе: доводим до конца, иначе рука повиснет у уха
			rate *= 2.5
		elif a > 0.0 and a < A_SEAT_R:
			dir = -1                # первый ещё не вставлен: откат, вкладыш возвращается на провод
			rate *= 2.0
	elif (a > 0.0 or b > 0.0) and u >= 1.0:
		dir = -1
	if dir > 0:
		a = minf(1.0, a + dt * rate / T_R)
		if a >= A_START_L:
			b = minf(1.0, b + dt * rate / T_L)
	elif dir < 0:
		if b > 0.0:
			b = maxf(0.0, b - dt * rate / T_L)
		var floor_a := A_START_L if b > 0.0 else 0.0
		if a > floor_a:
			a = maxf(floor_a, a - dt * rate / T_R)
	if not _acting():
		hurry = false

## Ключи пути: [[доля, точка или поворот], …] — плавно между соседними ключами.
static func _key(keys: Array, x: float) -> Array:
	var i := 0
	while i < keys.size() - 2 and x > float(keys[i + 1][0]):
		i += 1
	var s := _ss(float(keys[i][0]), float(keys[i + 1][0]), x)
	return [keys[i][1], keys[i + 1][1], s]

static func _path(keys: Array, x: float, arc := Vector3.ZERO) -> Vector3:
	var k := _key(keys, x)
	return (k[0] as Vector3).lerp(k[1], k[2]) + arc * sin(PI * float(k[2])) * (k[0] as Vector3).distance_to(k[1]) * 4.0

static func _rot(keys: Array, x: float) -> Quaternion:
	var k := _key(keys, x)
	return (k[0] as Quaternion).slerp(k[1], k[2])

func _release_balloon(free: bool) -> void:
	if free == balloon_free or rig.weapon == null:
		return
	balloon_free = free
	if not free:
		rig.weapon.transform = w_orig

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null or device == null:
		return
	var dt: float = min(delta, 0.05)
	frame_dt = dt
	var u0 := u
	var a0 := a
	var b0 := b
	if pose_hold:
		u = 1.0
		a = 1.0
		b = B_SEAT + 0.01
		want = true
	else:
		_step_buds(dt)
	hold_out = _acting() or (not buds_want and (a > 0.0 or b > 0.0))
	if not pose_hold:
		u = move_toward(u, 1.0 if want or hold_out else 0.0, dt / (open_time() if want or hold_out else T_CLOSE))
	_sounds(u0, a0, b0)
	# подсветка экрана: разгорается, когда iPod поднят, ярче — пока открыт интерфейс; гаснет при убирании
	var g_want := (1.0 if want else 0.4) * _ss(0.62, 1.0, u)
	glow = lerpf(glow, g_want, 1.0 - exp(-(3.0 if g_want > glow else 6.0) * dt))
	_apply_glow()
	if u <= 0.0:
		state = St.STOWED
	elif u >= 1.0:
		state = St.INSPECTING
	elif want or hold_out:
		state = St.REACHING if u < U_GRAB else (St.GRABBING if u < U_DRAW else St.DRAWING)
	else:
		state = St.LOWERING if u > U_DRAW else St.PUTTING_AWAY
	var hips := sk.get_bone_global_pose(b_hips)
	if u <= 0.0:
		device.visible = false
		looking = false
		_release_balloon(false)
		_place_buds(sk, hips, Transform3D(), false, 0.0)
		return
	clock += dt
	tap = max(0.0, tap - dt * 7.0)
	var live := _ss(0.82, 1.0, u)                       # живая поза просмотра
	var bell := sin(PI * clampf(u / 0.78, 0.0, 1.0))    # наклон к карману: есть в середине, нет по краям
	var breath := sin(clock * 1.65)
	# корпус и плечи: наклон к карману, потом дыхание
	_turn(sk, b_sp1, Vector3(0, 0, 1), -0.085 * bell)
	_turn(sk, b_sp1, Vector3(1, 0, 0), 0.05 * bell + 0.035 * live)
	_turn(sk, b_sp2, Vector3(1, 0, 0), 0.014 * breath * live)
	_turn(sk, b_lsh, Vector3(0, 0, 1), -0.16 * bell + 0.012 * sin(clock * 1.65 + 0.7) * live)
	var r_on := _ss(0.0, 0.08, a) * (1.0 - _ss(0.86, 1.0, a))   # правая рука занята наушниками
	_turn(sk, b_rsh, Vector3(0, 0, 1), -0.009 * sin(clock * 1.65 + 0.7) * live * (1.0 - r_on))
	_turn(sk, b_rsh, Vector3(0, 1, 0), 0.006 * sin(clock * 0.8) * live * (1.0 - r_on))
	var ear_r_on := sin(PI * _ss(A_GRAB_R, A_OUT_R + 0.03, a))
	var reach_c := sin(PI * _ss(0.0, A_GRAB_R + 0.04, a)) + sin(PI * _ss(A_OUT_R, A_HAND_L + 0.04, a))
	_turn(sk, b_rsh, Vector3(0, 0, 1), -0.13 * ear_r_on)                  # плечо поднимается к уху
	_turn(sk, b_sp1, Vector3(0, 1, 0), 0.05 * clampf(reach_c, 0.0, 1.0))   # корпус доворачивается к iPod, когда правая тянется к нему
	_turn(sk, b_sp1, Vector3(0, 0, 1), -0.025 * ear_r_on + 0.02 * sin(PI * _ss(0.2, B_OUT, b)))   # вес — к руке у уха
	_turn(sk, b_lsh, Vector3(0, 0, 1), -0.1 * sin(PI * _ss(0.15, B_OUT + 0.05, b)))
	# голова: склоняется навстречу руке у уха (к правому плечу сильнее, к левому мягче — не зеркально)
	var tilt_r := sin(PI * _ss(A_GRAB_R + 0.05, A_OUT_R + 0.04, a)) * 0.13
	var tilt_l := sin(PI * _ss(0.25, B_OUT + 0.08, b)) * 0.085
	var hd0 := sk.get_bone_global_pose(b_head)
	_turn(sk, b_neck, hd0.basis * fwd_l, tilt_r - tilt_l)
	# взгляд: сначала на карман, потом на экран — с отставанием от руки (цель — с прошлого кадра)
	var P := hips * pocket_l
	var target := P if u < U_DRAW + 0.08 else look_goal
	if not looking:
		looking = true
		look = hd0 * eye_l + hd0.basis * fwd_l * 0.3
		target = P
	look = look.lerp(target, 1.0 - exp(-6.5 * dt))
	var lw := 0.0 if pose_hold else _ss(0.02, 0.3, u) * lerpf(0.5, 1.0, _ss(U_DRAW, 0.9, u))
	_look(sk, b_neck, 0.4, LOOK_NECK, lw)
	_look(sk, b_head, 1.0, LOOK_HEAD, lw)
	var hd2 := sk.get_bone_global_pose(b_head)
	if live > 0.0:
		_turn(sk, b_head, hd2.basis * fwd_l, 0.03 * sin(clock * 0.55) * live)
		hd2 = sk.get_bone_global_pose(b_head)
	# опорные точки на теле в текущей позе
	var chest := sk.get_bone_global_pose(b_sp2)
	var cq := chest.basis.orthonormalized()
	var O := hips * out_l
	var V := chest * view_l + Vector3(0.003 * sin(clock * 0.75), 0.004 * sin(clock * 1.1 + 1.0), 0.0) * live * (1.0 - r_on)
	var q_pocket := (hips.basis.orthonormalized() * rot_pocket_l).get_rotation_quaternion()
	var q_view := (cq * rot_view_l).get_rotation_quaternion()
	var ear := {}
	for side in ["L", "R"]:
		ear[side] = hd2 * (ear_xf[side] as Transform3D)
	var h0 := sk.get_bone_global_pose(b_hand)
	var q0 := h0.basis.get_rotation_quaternion()
	var G: Vector3
	var Q: Quaternion
	if u < U_GRAB:
		var s := _ss(0.0, 1.0, u / U_GRAB)
		G = (h0 * grip_l).lerp(P, s) + Vector3(1, 0.1, 0.45).normalized() * 0.035 * sin(PI * s)
		Q = q0.slerp(q_pocket, _ss(0.1, 0.95, s))
	elif u < U_DRAW:
		G = P + Vector3(0, -0.006, 0) * sin(PI * (u - U_GRAB) / (U_DRAW - U_GRAB))
		Q = q_pocket
	else:
		var s2 := _ss(0.0, 1.0, (u - U_DRAW) / (1.0 - U_DRAW))
		G = P.lerp(O, s2).lerp(O.lerp(V, s2), s2)
		Q = q_pocket.slerp(q_view, _ss(0.18, 0.92, s2))
	Q = Quaternion(Vector3.UP, 0.028 * sin(clock * 0.9) * live * (1.0 - r_on)) * Q
	# левая рука: подаёт iPod правой, потом несёт второй вкладыш к левому уху
	var offer := chest * offer_l
	if u >= 1.0 and (a > 0.0 or b > 0.0) and not buds_in():
		var q_l_ear := (cq * rot_l_ear).get_rotation_quaternion()
		var view_pinch := V + Basis(q_view) * (pinch_l - grip_l)
		var offer_pinch := offer + Basis(q_view) * (pinch_l - grip_l)
		var e_l: Vector3 = (ear["L"] as Transform3D).origin
		var e_app: Vector3 = e_l + Vector3(0.035, -0.012, 0.012)
		var pk := [[0.0, view_pinch], [0.15, offer_pinch], [1.0, offer_pinch]]
		var pinch_pos := _path(pk, a)
		var qk := Q
		if b > 0.0:
			var kb := [[0.0, offer_pinch], [B_APP, e_app], [B_SEAT, e_l], [B_OUT, e_app], [1.0, view_pinch]]
			pinch_pos = _path(kb, b, Vector3(0.012, 0.0, 0.006))
			qk = _rot([[0.0, q_view], [B_APP - 0.12, q_l_ear], [B_OUT, q_l_ear], [1.0, q_view]], b)
		Q = qk
		G = pinch_pos - Basis(Q) * (pinch_l - grip_l)
	_solve(sk, b_arm, b_fa, b_hand, l1, l2, grip_l, G, Q, _ss(0.0, 0.14, u), Vector3(1.0, -0.75, -0.55), "reach")
	if b_thumb >= 0 and tap > 0.0:
		var hp := sk.get_bone_global_pose(b_hand)
		var bump := sin(PI * tap)
		match tap_kind:
			"menu":        # к верху колеса
				_turn(sk, b_thumb, hp.basis * fl, 0.3 * bump)
			"next":        # вправо по колесу, нежно
				_turn(sk, b_thumb, hp.basis * kl, -0.22 * bump)
			"previous":
				_turn(sk, b_thumb, hp.basis * kl, 0.22 * bump)
			"scroll":      # по кругу — едва заметно
				_turn(sk, b_thumb, hp.basis * palm_l, -0.16 * bump)
			"play":
				_turn(sk, b_thumb, hp.basis * palm_l, -0.32 * bump)
			_:             # центральная кнопка — короткое нажатие
				_turn(sk, b_thumb, hp.basis * palm_l, -0.45 * bump)
	# устройство: в кармане — на тазе, после захвата — в кулаке
	var hand := sk.get_bone_global_pose(b_hand)
	var in_hand := _ss(U_GRAB, U_DRAW, u)
	var xf := (hips * pocket_dev_l).interpolate_with(Transform3D(hand.basis.orthonormalized(), hand.origin) * mount, in_hand)
	var show := _ss(U_GRAB - 0.05, U_GRAB + 0.05, u)
	device.visible = show > 0.0
	device.transform = Transform3D(xf.basis.scaled(Vector3.ONE * lerpf(0.35, 1.0, show)), xf.origin)
	look_goal = device.transform * Vector3(0, DEV_H * 0.23, DEV_H * 0.06)
	# правая рука: отпускает балон, вставляет первый вкладыш, передаёт второй и возвращается к балону
	var store := _storage()
	var l_pinch := hand * pinch_l
	if r_on > 0.0:
		var hr0 := sk.get_bone_global_pose(rb_hand)
		if not balloon_free and rig.weapon != null:
			w_orig = rig.weapon.transform
			w_store = hips.affine_inverse() * (hr0 * w_orig)
			_release_balloon(true)
		var home := hr0 * pinch_r
		var qh := hr0.basis.get_rotation_quaternion()
		var e_r: Vector3 = (ear["R"] as Transform3D).origin
		var e_rapp: Vector3 = e_r + Vector3(-0.04, -0.014, 0.012)
		var rd := (cq * rot_r_down).get_rotation_quaternion()
		var re := (cq * rot_r_ear).get_rotation_quaternion()
		var rg := (cq * rot_r_give).get_rotation_quaternion()
		var give := l_pinch + Vector3(-0.004, 0.0, 0.0)
		var keys := [[0.0, home], [A_GRAB_R, store["R"].origin], [A_APP_R, e_rapp], [A_SEAT_R, e_r], [A_OUT_R, e_rapp],
			[A_GRAB_L, store["L"].origin], [A_HAND_L, give], [0.9, home], [1.0, home]]
		var pr := _path(keys, a, Vector3(-0.012, 0.004, 0.008))
		var qr := _rot([[0.0, qh], [A_GRAB_R, rd], [A_APP_R, re], [A_OUT_R, re], [A_GRAB_L, rd], [A_HAND_L, rg], [0.9, qh], [1.0, qh]], a)
		var gr := pr - Basis(qr) * (pinch_r - rgrip_l)
		_solve(sk, rb_arm, rb_fa, rb_hand, rl1, rl2, rgrip_l, gr, qr, r_on, Vector3(-1.0, -0.75, -0.55), "reach_r")
		var hr := sk.get_bone_global_pose(rb_hand)
		dbg["miss_r"] = (hr * pinch_r).distance_to(pr) if r_on >= 1.0 else 0.0
		if rig.weapon != null:
			rig.weapon.transform = hr.affine_inverse() * (hips * w_store)
	else:
		_release_balloon(false)
	dbg["miss_l"] = (sk.get_bone_global_pose(b_hand) * pinch_l).distance_to((ear["L"] as Transform3D).origin) if absf(b - B_SEAT) < 0.02 else 0.0
	_place_buds(sk, hips, device.transform, true, show)
	dbg["look"] = (hd2.basis * fwd_l).normalized().angle_to((look_goal - hd2 * eye_l).normalized())
	dbg["gap"] = (sk.get_bone_global_pose(b_hand) * grip_l).distance_to(device.transform * Vector3(0, -DEV_H * HOLD, -DEV_H * OUT_PALM))

## Где висят вкладыши, пока не надеты: на проводе под iPod, ножками вверх, отверстием вбок.
func _storage() -> Dictionary:
	var d := device.transform.orthonormalized()
	var bottom := device.transform * Vector3(0, -DEV_H * 0.5, 0)
	var side := d.basis.x
	side.y = 0.0
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var sp := bottom + Vector3(0, -0.028, 0)
	var res := {"split": sp}
	for s in ["L", "R"]:
		var k := 1.0 if s == "L" else -1.0
		var pos: Vector3 = sp + Vector3(0, -0.03 - (0.004 if s == "L" else 0.0), 0) + side * 0.013 * k
		res[s] = Transform3D(buds.bud_basis(s, side * k, Vector3.UP), pos)
	return res

## Вкладыши и провод по текущим a и b. out — iPod снаружи (иначе в кармане), show — насколько он уже виден.
func _place_buds(sk: Skeleton3D, hips: Transform3D, dev: Transform3D, out: bool, show: float) -> void:
	var hd := sk.get_bone_global_pose(b_head)
	var stored := a <= 0.0 and b <= 0.0
	if not out and stored:
		buds.visible = false
		return
	buds.visible = true
	var store := _storage() if out else {}
	var xf := {}
	var shown := {}
	var hand_r := sk.get_bone_global_pose(rb_hand)
	var hand_l := sk.get_bone_global_pose(b_hand)
	var ear_r := hd * (ear_xf["R"] as Transform3D)
	var ear_l := hd * (ear_xf["L"] as Transform3D)
	# правый
	if a >= A_SEAT_R:
		xf["R"] = ear_r
	elif a >= A_GRAB_R and out:
		var s := _ss(A_GRAB_R, A_APP_R, a)
		xf["R"] = Transform3D((store["R"].basis as Basis).slerp(ear_r.basis, s), hand_r * pinch_r)
	elif out:
		xf["R"] = store["R"]
	# левый
	if b >= B_SEAT:
		xf["L"] = ear_l
	elif out and (b > 0.0 or a >= A_HAND_L):
		var s2 := _ss(0.0, B_APP, b)
		var give_b := buds.bud_basis("L", Vector3(1, 0, 0.3), Vector3(0, -1, 0.4))
		xf["L"] = Transform3D(give_b.slerp(ear_l.basis, s2), hand_l * pinch_l)
	elif out and a >= A_GRAB_L:
		var s3 := _ss(A_GRAB_L, A_HAND_L, a)
		var give_b2 := buds.bud_basis("L", Vector3(1, 0, 0.3), Vector3(0, -1, 0.4))
		xf["L"] = Transform3D((store["L"].basis as Basis).slerp(give_b2, s3), hand_r * pinch_r)
	elif out:
		xf["L"] = store["L"]
	for side in ["L", "R"]:
		if not xf.has(side):
			# iPod уже в кармане, а вкладыш не в ухе — так не бывает (snap), но и в воздухе он не висит
			xf[side] = Transform3D(Basis(), hips * pocket_l)
			shown[side] = false
		else:
			shown[side] = not (out and stored and show < 0.85)
		buds.place(side, xf[side], shown[side])
	# провод: штекер в iPod (сверху слева) или в кармане → разветвитель → ножки вкладышей
	var jack: Vector3
	var jdir: Vector3
	if out and show > 0.0:
		jack = dev * Vector3(-DEV_H * 0.6 * 0.3, DEV_H * 0.5, 0)
		jdir = dev.basis.y.normalized()
	else:
		# iPod в кармане: провод выходит из кармана спереди, вверх по животу
		jack = hips * (pocket_l + Vector3(-0.012, 0.03, 0.07))
		jdir = (hips.basis * Vector3(0, 1, 0.5)).normalized()
	var chest := sk.get_bone_global_pose(b_sp2)
	var fr := _ss(A_GRAB_R, A_SEAT_R, a)
	var fl2 := 0.4 * _ss(A_GRAB_L, A_HAND_L, a) + 0.6 * _ss(0.0, B_SEAT, b)
	var want_split: Vector3 = chest * split_l
	if out:
		want_split = (store["split"] as Vector3).lerp(chest * split_l, 0.5 * (fr + fl2))
	var ends := []
	var dirs := []
	for side in ["L", "R"]:
		var t: Transform3D = xf[side]
		ends.append(buds.stem_end(side, t))
		dirs.append((t.basis * Vector3(0, -1, 0)).normalized())
	buds.cable.visible = shown["L"] or shown["R"]
	buds.splitter.visible = buds.cable.visible
	var body := chest * sk.get_bone_global_rest(b_sp2).affine_inverse()
	buds.draw(jack, jdir, want_split, ends, dirs, out and show > 0.5, frame_dt, sk.global_transform, body)

## Доворот кости к точке взгляда: part — какую долю поворота берёт кость, limit — предел в радианах.
func _look(sk: Skeleton3D, bone_i: int, part: float, limit: float, w: float) -> void:
	if bone_i < 0 or w <= 0.0:
		return
	var hd := sk.get_bone_global_pose(b_head)
	var from := (hd.basis * fwd_l).normalized()
	var to := (look - hd * eye_l).normalized()
	if from.dot(to) > 0.99999 or from.dot(to) < -0.99:
		return
	var q := Quaternion(from, to)
	var ang := q.get_angle()
	var k := part * w
	if ang * k > limit:
		k = limit / ang
	var p := sk.get_bone_global_pose(bone_i)
	p.basis = Basis(Quaternion.IDENTITY.slerp(q, k)) * p.basis
	sk.set_bone_global_pose(bone_i, p)

## Двухзвенный IK руки: центр кулака в точке G, поворот кисти Q; w — доля IK поверх анимации; pole — куда смотрит локоть.
func _solve(sk: Skeleton3D, ba: int, bf: int, bh: int, len1: float, len2: float, grip: Vector3, G: Vector3, Q: Quaternion, w: float, pole_dir: Vector3, tag: String) -> void:
	var ap := sk.get_bone_global_pose(ba)
	var S := ap.origin
	var W := G - Basis(Q) * grip
	var to := W - S
	var d: float = clamp(to.length(), 0.03, (len1 + len2) * 0.998)
	dbg[tag] = to.length() / (len1 + len2)
	var dir := to.normalized()
	var pole := pole_dir.normalized()
	var pp := pole - dir * pole.dot(dir)
	pp = pp.normalized() if pp.length() > 0.001 else Vector3(0, -1, 0)
	var ca: float = clamp((len1 * len1 + d * d - len2 * len2) / (2.0 * len1 * d), -1.0, 1.0)
	var E := S + dir * (len1 * ca) + pp * (len1 * sqrt(max(0.0, 1.0 - ca * ca)))
	var ga := ap.basis.get_rotation_quaternion()
	var cur_a := (ap.basis * (rig.rest_pos[bf] as Vector3)).normalized()
	ap.basis = Basis(ga.slerp(_arc(cur_a, (E - S).normalized()) * ga, w))
	sk.set_bone_global_pose(ba, ap)
	var fp := sk.get_bone_global_pose(bf)
	var gf := fp.basis.get_rotation_quaternion()
	var cur_f := (fp.basis * (rig.rest_pos[bh] as Vector3)).normalized()
	fp.basis = Basis(gf.slerp(_arc(cur_f, (S + dir * d - fp.origin).normalized()) * gf, w))
	sk.set_bone_global_pose(bf, fp)
	var hp := sk.get_bone_global_pose(bh)
	hp.basis = Basis(hp.basis.get_rotation_quaternion().slerp(Q, w))
	sk.set_bone_global_pose(bh, hp)

static func _arc(x: Vector3, y: Vector3) -> Quaternion:
	if x.dot(y) > 0.99999 or x.dot(y) < -0.9999:
		return Quaternion.IDENTITY
	return Quaternion(x, y)

# ---------- модель iPod Classic: собирается кодом, без внешних файлов ----------
func _mat(col: Color, metal := 0.0, rough := 0.5, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m

## Светящаяся часть экрана: яркость задаёт glow (_apply_glow), погашенный экран — тёмное стекло, а не белый прямоугольник.
func _lit(col: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(col, 0.0, 0.6, energy)
	lcd_mats.append([m, col, energy])
	return m

func _apply_glow() -> void:
	var dark := Color(0.06, 0.08, 0.08)
	for e in lcd_mats:
		var m: StandardMaterial3D = e[0]
		m.albedo_color = dark.lerp(e[1], 0.25 + 0.75 * glow)
		m.emission_energy_multiplier = float(e[2]) * glow

## Сколько доставать iPod: в первый раз — полностью, если наушники уже в ушах — быстрее.
func open_time() -> float:
	return T_REOPEN if buds_in() else T_OPEN

## Звуки — по переходу фаз, а не по таймерам: прозвучат ровно тогда, когда рука дошла (и в обратную сторону тоже).
func _sounds(u0: float, a0: float, b0: float) -> void:
	if sfx == null:
		return
	_cross(u0, u, 0.03, "cloth", "")
	_cross(u0, u, U_GRAB, "grip", "cloth")
	_cross(u0, u, U_DRAW, "slide", "slide")
	_cross(a0, a, A_GRAB_R, "bud_touch", "cable")
	_cross(a0, a, A_SEAT_R, "bud_seat", "bud_out")
	_cross(a0, a, A_GRAB_L, "bud_touch", "cable")
	_cross(a0, a, A_HAND_L, "cable", "bud_touch")
	_cross(b0, b, B_SEAT, "bud_seat", "bud_out")

func _cross(x0: float, x1: float, th: float, up: String, down: String) -> void:
	if x0 < th and x1 >= th and up != "":
		sfx.play(up)
	elif x0 >= th and x1 < th and down != "":
		sfx.play(down)

func _quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _disc(parent: Node3D, radius: float, thick: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = thick
	c.radial_segments = 28
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.rotation.x = PI / 2
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Пластина со скруглёнными углами и фаской по краю: лицевая и задняя стенки плюс обод.
func _slab(w: float, h: float, t: float, r: float, front: Material, back: Material) -> MeshInstance3D:
	var ring: Array = []      # [точка контура, нормаль наружу]
	for c in 4:
		var cx := (w * 0.5 - r) * (1.0 if c == 0 or c == 3 else -1.0)
		var cy := (h * 0.5 - r) * (1.0 if c < 2 else -1.0)
		for i in 6:
			var a := (c + i / 5.0) * PI * 0.5
			ring.append([Vector2(cx + cos(a) * r, cy + sin(a) * r), Vector2(cos(a), sin(a))])
	var bev := t * 0.22       # фаска: лицевая стенка чуть меньше обода
	var n := ring.size()
	var mesh := ArrayMesh.new()
	for face in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var z := t * 0.5 * (1.0 if face == 0 else -1.0)
		var nz := Vector3(0, 0, 1.0 if face == 0 else -1.0)
		for i in n:
			var a: Vector2 = ring[i][0] - (ring[i][1] as Vector2) * bev
			var b: Vector2 = ring[(i + 1) % n][0] - (ring[(i + 1) % n][1] as Vector2) * bev
			for v in [Vector2.ZERO, a, b]:
				st.set_normal(nz)
				st.add_vertex(Vector3(v.x, v.y, z))
		st.commit(mesh)
		mesh.surface_set_material(face, front if face == 0 else back)
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var p0: Vector2 = ring[i][0]
		var p1: Vector2 = ring[(i + 1) % n][0]
		var n0: Vector2 = ring[i][1]
		var n1: Vector2 = ring[(i + 1) % n][1]
		# три пояса: фаска к лицу, обод, фаска к спинке
		var rows := [[t * 0.5, bev, 0.7], [t * 0.5 - bev, 0.0, 0.0], [-t * 0.5 + bev, 0.0, 0.0], [-t * 0.5, bev, -0.7]]
		for k in 3:
			var ra: Array = rows[k]
			var rb: Array = rows[k + 1]
			var quad := [
				[p0 - n0 * float(ra[1]), n0, ra], [p1 - n1 * float(ra[1]), n1, ra],
				[p1 - n1 * float(rb[1]), n1, rb], [p0 - n0 * float(rb[1]), n0, rb]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var e: Array = quad[idx]
				var pt: Vector2 = e[0]
				var nn: Vector2 = e[1]
				var row: Array = e[2]
				side.set_normal(Vector3(nn.x, nn.y, float(row[2])).normalized())
				side.add_vertex(Vector3(pt.x, pt.y, float(row[0])))
	side.commit(mesh)
	mesh.surface_set_material(2, front)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

func _build_device(h: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PodDevice"
	var w := h * 0.6
	var t := h * 0.11
	var silver := _mat(Color(0.8, 0.82, 0.84), 0.85, 0.34)
	silver.cull_mode = BaseMaterial3D.CULL_DISABLED
	var chrome := _mat(Color(0.9, 0.91, 0.93), 0.8, 0.26)
	chrome.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(_slab(w, h, t, h * 0.07, silver, chrome))
	var z := t * 0.5
	var e := h * 0.004
	# экран: тёмная рамка, светящаяся панель, строка заголовка и выбранная строка меню
	_quad(root, Vector2(w * 0.86, h * 0.4), Vector3(0, h * 0.235, z + e), _mat(Color(0.03, 0.035, 0.04), 0.0, 0.25))
	var lcd := _lit(Color(0.82, 0.92, 0.9), 0.85)
	_quad(root, Vector2(w * 0.8, h * 0.35), Vector3(0, h * 0.235, z + e * 2.0), lcd)
	_quad(root, Vector2(w * 0.8, h * 0.05), Vector3(0, h * 0.385, z + e * 3.0), _lit(Color(0.93, 0.97, 0.96), 1.0))
	_quad(root, Vector2(w * 0.8, h * 0.06), Vector3(0, h * 0.315, z + e * 3.0), _lit(Color(0.2, 0.52, 0.8), 1.1))
	var ink := _lit(Color(0.2, 0.28, 0.3), 0.25)
	for i in 3:
		_quad(root, Vector2(w * (0.5 - 0.08 * i), h * 0.018), Vector3(-w * (0.11 + 0.04 * i), h * (0.245 - 0.06 * i), z + e * 3.0), ink)
	# колесо, центральная кнопка, метки на колесе
	var wheel_y := -h * 0.215
	_disc(root, w * 0.345, e * 2.0, Vector3(0, wheel_y, z + e), _mat(Color(0.97, 0.97, 0.96), 0.0, 0.42))
	_disc(root, w * 0.13, e * 2.0, Vector3(0, wheel_y, z + e * 2.5), _mat(Color(0.78, 0.8, 0.82), 0.6, 0.3))
	var mark := _mat(Color(0.55, 0.57, 0.6), 0.0, 0.5)
	for d in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		_quad(root, Vector2(w * 0.07, h * 0.012), Vector3(d.x * w * 0.25, wheel_y + d.y * w * 0.25, z + e * 2.2), mark)
	# мелочи корпуса: переключатель Hold и гнездо наушников сверху, разъём снизу
	var dark := _mat(Color(0.1, 0.1, 0.11), 0.3, 0.4)
	_box(root, Vector3(w * 0.16, h * 0.012, t * 0.4), Vector3(w * 0.26, h * 0.5, 0), _mat(Color(0.7, 0.72, 0.74), 0.8, 0.3))
	_box(root, Vector3(w * 0.07, h * 0.008, t * 0.45), Vector3(-w * 0.28, h * 0.5, 0), dark)
	_box(root, Vector3(w * 0.36, h * 0.008, t * 0.32), Vector3(0, -h * 0.5, 0), dark)
	return root
