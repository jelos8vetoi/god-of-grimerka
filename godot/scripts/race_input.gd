## Управление гонщиком на один шаг физики. Его дают: игрок (from_actions — InputMap race_*), бот (race_ai.gd)
## или удалённый игрок по сети. Гоночная логика не знает, кто управляет: она получает только это.
## Всё, что пришло извне, проходит sanitize(): числа в пределах, без NaN — клиент не может прислать «газ ×10».
class_name RaceInput
extends RefCounted

var throttle := 0.0     # 0..1
var brake := 0.0        # 0..1
var steer := 0.0        # −1 (влево) .. 1 (вправо)
var drift := false      # держит занос
var boost := false      # держит турбо
var jump := false       # нажал прыжок в этом шаге
var item := false       # нажал «предмет» в этом шаге
var look_back := false

func sanitize() -> RaceInput:
	throttle = 0.0 if is_nan(throttle) else clampf(throttle, 0.0, 1.0)
	brake = 0.0 if is_nan(brake) else clampf(brake, 0.0, 1.0)
	steer = 0.0 if is_nan(steer) else clampf(steer, -1.0, 1.0)
	return self

## Ввод игрока. sens — чувствительность поворота из настроек гонки; стик геймпада — плавный, клавиши — полный.
static func from_actions(sens: float, jump_edge: bool, item_edge: bool) -> RaceInput:
	var r := RaceInput.new()
	r.throttle = Input.get_action_strength("race_accelerate")
	r.brake = Input.get_action_strength("race_brake")
	var st := Input.get_action_strength("race_right") - Input.get_action_strength("race_left")
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(ax) > 0.15:
		st = ax
	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if rt > 0.1:
		r.throttle = maxf(r.throttle, rt)
	var lt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if lt > 0.1:
		r.brake = maxf(r.brake, lt)
	r.steer = st * sens
	r.drift = Input.is_action_pressed("race_drift")
	r.boost = Input.is_action_pressed("race_boost")
	r.jump = jump_edge
	r.item = item_edge
	r.look_back = Input.is_action_pressed("race_look_back")
	return r.sanitize()

## компактно для сети: 4 числа (газ, тормоз и руль — байтами, флаги — битами)
func pack() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b[0] = int(roundf(throttle * 255.0))
	b[1] = int(roundf(brake * 255.0))
	b[2] = int(roundf((steer * 0.5 + 0.5) * 254.0))
	b[3] = (1 if drift else 0) | (2 if boost else 0) | (4 if jump else 0) | (8 if item else 0) | (16 if look_back else 0)
	return b

static func unpack(b: PackedByteArray) -> RaceInput:
	var r := RaceInput.new()
	if b.size() != 4:
		return r
	r.throttle = float(b[0]) / 255.0
	r.brake = float(b[1]) / 255.0
	r.steer = float(b[2]) / 254.0 * 2.0 - 1.0
	r.drift = (b[3] & 1) != 0
	r.boost = (b[3] & 2) != 0
	r.jump = (b[3] & 4) != 0
	r.item = (b[3] & 8) != 0
	r.look_back = (b[3] & 16) != 0
	return r.sanitize()
